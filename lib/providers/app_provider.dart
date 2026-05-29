import 'dart:async';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/invoice.dart';
import '../models/client.dart';
import '../models/business_profile.dart';
import '../models/subscription_limits.dart';
import '../models/reminder_settings.dart';
import '../services/drive_service.dart';
import '../services/encryption_service.dart';
import '../services/reminder_service.dart';
import '../services/verification_service.dart';
import '../services/billing_service.dart';
import '../services/firestore_subscription_service.dart';
import '../services/employee_service.dart';
import '../models/employee.dart';
import '../models/employee_pairing.dart';
import '../services/pairing_service.dart';

/// Per-business tier cache key. Written by every authoritative tier source
/// (Firestore, VerificationService, IAP purchase). Re-applied after every
/// profile load so Drive data can never silently overwrite a confirmed tier.
String _tierCacheKey(String businessId) => 'subscription_tier_v3_$businessId';

class AppProvider extends ChangeNotifier with WidgetsBindingObserver {
  AppProvider(this._enc) {
    WidgetsBinding.instance.addObserver(this);
  }

  final _uuid = const Uuid();
  final EncryptionService _enc;

  List<Invoice> _invoices = [];
  List<Client> _clients = [];
  BusinessProfile _profile = BusinessProfile();
  DriveService? _drive;
  String? _userEmail;
  bool _loaded = false;
  bool _syncing = false;
  bool _onboardingComplete = false;
  ReminderSettings _reminderSettings = ReminderSettings();
  DateTime? _lastStatsPush;
  DateTime? _lastTierCheck;
  String? _lastSyncError;

  static const _kBusinessId = 'default';

  // ── Dual-role: owner + employee of another business ───────────────────────
  String? _employeeOwnerEmail;
  Employee? _activeEmployeeRecord;

  // ── Employee mode: accessing owner's Drive via QR pairing ────────────────
  EmployeePairing? _pairing;
  EncryptionService? _pairingEnc;

  List<Invoice> get invoices => List.unmodifiable(_invoices);
  List<Client> get clients => List.unmodifiable(_clients);
  BusinessProfile get profile => _profile;
  bool get loaded => _loaded;
  bool get syncing => _syncing;
  bool get needsOnboarding => !_onboardingComplete;
  String? get lastSyncError => _lastSyncError;
  ReminderSettings get reminderSettings => _reminderSettings;

  /// True when the signed-in user is also a team member of another business.
  bool get isAlsoEmployee =>
      _employeeOwnerEmail != null && _activeEmployeeRecord != null;

  /// The owner email of the business where this user is an employee.
  String? get employeeOwnerEmail => _employeeOwnerEmail;

  /// The employee record for this user within another owner's business.
  Employee? get employeeRecord => _activeEmployeeRecord;

  /// True when the app is currently viewing an owner's data as an employee.
  bool get isEmployeeMode => _pairing != null;

  /// The active pairing (non-null only in employee mode).
  EmployeePairing? get activePairing => _pairing;

  List<Invoice> get draftInvoices =>
      _invoices.where((i) => i.status == InvoiceStatus.draft).toList();
  List<Invoice> get sentInvoices =>
      _invoices.where((i) => i.status == InvoiceStatus.sent).toList();
  List<Invoice> get paidInvoices =>
      _invoices.where((i) => i.status == InvoiceStatus.paid).toList();
  List<Invoice> get overdueInvoices =>
      _invoices.where((i) => i.isOverdue).toList();

  double get totalRevenue =>
      paidInvoices.fold(0.0, (sum, i) => sum + i.grandTotal);
  double get totalOutstanding => _invoices
      .where((i) =>
          i.status != InvoiceStatus.paid && i.status != InvoiceStatus.cancelled)
      .fold(0.0, (sum, i) => sum + i.amountRemaining);

  /// Called once at startup — loads from local SharedPreferences.
  Future<void> load() async {
    // Restore employee pairing before loading local data so key helpers
    // can use the correct prefix from the very first read.
    _pairing = await PairingService.load();
    if (_pairing != null) {
      _pairingEnc = EncryptionService.withKey(_pairing!.encKey);
    }

    await _loadLocal();
    final prefs = await SharedPreferences.getInstance();
    _onboardingComplete = prefs.getBool('onboardingComplete') ?? false;
    // Existing users (data already in prefs but no onboarding flag) skip onboarding.
    if (!_onboardingComplete && _profile.name.isNotEmpty) {
      _onboardingComplete = true;
      await prefs.setBool('onboardingComplete', true);
    }
    _reminderSettings = await ReminderSettings.load();
    _loaded = true;
    notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Re-checks tier (and verification) whenever the app returns to foreground.
  /// Throttled to once per 60 s so rapid app-switches don't spam Firestore.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (_userEmail == null) return;
    final now = DateTime.now();
    if (_lastTierCheck != null &&
        now.difference(_lastTierCheck!).inSeconds < 60) {
      return;
    }
    _lastTierCheck = now;
    _refreshSubscriptionTier().catchError((_) {});
    _checkVerificationStatus().catchError((_) {});
  }

  Future<void> completeOnboarding() async {
    _onboardingComplete = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboardingComplete', true);
    notifyListeners();
  }

  /// Attaches a Drive service, resolves the encryption key (all 4 states),
  /// then syncs data from Drive. Safe to call from both main.dart and
  /// login_screen.dart — key management is centralised here.
  Future<void> attachDriveAndSync(DriveService drive,
      {String? userEmail}) async {
    // Prevent a second concurrent sync from running.
    if (_syncing) return;

    _drive = drive;
    _userEmail = userEmail;
    _lastSyncError = null;

    // ── Employee mode: skip all key management; use pairing key ──────────
    if (isEmployeeMode) {
      await _syncFromDrive();
      _detectEmployeeRole().catchError((_) {});
      return;
    }

    // ── Key management ────────────────────────────────────────────────────
    // Wrapped in its own try-catch so a key-fetch failure doesn't silently
    // leave _drive set but unusable, or worse generate a brand-new key that
    // would lock the user out of their existing encrypted data.
    try {
      final hasLocal = _enc.isReady;
      final driveKey = await drive.loadKey();

      if (!hasLocal && driveKey != null) {
        // New device / reinstall — restore key from Drive backup.
        await _enc.loadFromDriveKey(driveKey);
      } else if (!hasLocal && driveKey == null) {
        // Truly first-ever install — generate a key and back it up immediately.
        final newKey = await _enc.generateAndStore();
        await drive.saveKey(newKey);
      } else if (hasLocal && driveKey == null) {
        // Local key exists but Drive backup is missing — re-upload it.
        await drive.saveKey(_enc.keyBase64!);
      }
      // hasLocal && driveKey != null → all good, nothing to do.
    } catch (e) {
      // Key management failed (network error, Drive permission issue, etc.).
      // Do NOT generate a new key — that would permanently lock out existing data.
      // Surface the error and abort; the user can retry by signing in again.
      _lastSyncError = 'Could not load encryption key: $e';
      _drive = null;
      notifyListeners();
      return;
    }

    await _syncFromDrive();

    // ── Subscription tier resolution ─────────────────────────────────────────
    // Priority (highest wins):
    //   1. Firestore subscription doc (IAP expiry) — authoritative for paid users
    //   2. VerificationService (admin override)    — can upgrade; limited downgrade
    //   3. subscription_tier_v2 cache              — survives Drive/profile overwrites
    //   4. Profile data from Drive/prefs           — lowest; can be stale
    //
    // Firestore expiry runs inline on sign-in so the UI never renders a stale tier.
    // Admin check runs in background; it can upgrade freely but cannot downgrade
    // a user who still has an active IAP expiry date.
    if (_userEmail != null) {
      await _syncFirestoreSubscription().catchError((_) {});
    }

    final tierPrefs = await SharedPreferences.getInstance();
    if (tierPrefs.getString(_tierCacheKey(_kBusinessId)) == null && _userEmail != null) {
      await _refreshSubscriptionTier().catchError((_) {});
    } else {
      _refreshSubscriptionTier().catchError((_) {});
    }

    // Best-effort: check verification status in background.
    _checkVerificationStatus().catchError((_) {});
    // Push latest stats so admin dashboard stays current.
    _pushStats().catchError((_) {});
    // Detect if this user is also an employee of another business.
    _detectEmployeeRole().catchError((_) {});
  }

  /// Detaches Drive (on sign-out) and clears local cache + encryption key.
  Future<void> detachDriveAndClear() async {
    _drive = null;
    _invoices = [];
    _clients = [];
    _profile = BusinessProfile();
    _onboardingComplete = false;
    _employeeOwnerEmail = null;
    _activeEmployeeRecord = null;
    _pairing = null;
    _pairingEnc = null;
    await _clearLocal();
    await _enc.clearKey();
    await PairingService.clear();
    notifyListeners();
  }

  /// Checks whether the signed-in user is also an employee in another
  /// business. Populates [_employeeOwnerEmail] and [_activeEmployeeRecord].
  Future<void> _detectEmployeeRole() async {
    final email = _userEmail;
    if (email == null) return;
    final ownerEmail = await EmployeeService.findOwnerEmail(email);
    if (ownerEmail == null) {
      if (_employeeOwnerEmail != null) {
        _employeeOwnerEmail = null;
        _activeEmployeeRecord = null;
        notifyListeners();
      }
      return;
    }
    final record = await EmployeeService.fetchEmployee(ownerEmail, email);
    _employeeOwnerEmail = ownerEmail;
    _activeEmployeeRecord = record;
    notifyListeners();
  }

  Future<void> _syncFromDrive() async {
    if (_drive == null) return;
    _syncing = true;
    _lastSyncError = null; // always reset so stale errors don't linger
    notifyListeners();
    try {
      // In employee mode: read from the owner's shared file using its ID.
      // In owner mode: read from the standard named file in the app folder.
      final String? raw;
      if (isEmployeeMode && _pairing != null) {
        raw = await _drive!.loadDataByFileId(_pairing!.fileId);
      } else {
        raw = await _drive!.loadData();
      }

      // Choose the encryption service: pairing key for employees, own key for owners.
      final encSvc = (isEmployeeMode && _pairingEnc != null) ? _pairingEnc! : _enc;

      if (raw != null) {
        // ── Decrypt ──────────────────────────────────────────────────────
        // Use decrypt() (not decryptSafe) so a key mismatch throws rather than
        // silently returning the raw ciphertext, which would cause a JSON parse
        // error that we'd then confuse for a "no data" state.
        final String json;
        try {
          json = encSvc.isReady ? encSvc.decrypt(raw) : raw;
        } catch (e) {
          // Decryption failed — key mismatch or corrupt file.
          // Keep local data and surface the error; do NOT overwrite Drive.
          _lastSyncError = 'decryption_failed';
          return;
        }

        // ── Parse ─────────────────────────────────────────────────────────
        final Map<String, dynamic> data;
        try {
          data = jsonDecode(json) as Map<String, dynamic>;
        } catch (e) {
          _lastSyncError = 'parse_failed';
          return;
        }

        _applyData(data);
        final prefs = await SharedPreferences.getInstance();
        // Existing user re-signing in — Drive data has their profile, skip onboarding.
        if (!_onboardingComplete && _profile.name.isNotEmpty) {
          _onboardingComplete = true;
          await prefs.setBool('onboardingComplete', true);
        }
        // Re-apply the cached tier (owner mode only) — Drive data can lag behind
        // Firestore/IAP. In employee mode we honour the tier that came from the
        // owner's Drive file; we must not overwrite it with the employee's own cache.
        if (!isEmployeeMode) {
          _applyTierCache(prefs);
        }
        await _saveLocal();
      } else {
        // No Drive file found.
        // In employee mode this means the owner's file is empty — do NOT push
        // the employee's in-memory data there. The employee has no data yet and
        // must wait for the owner to save something to Drive first.
        // In owner mode, push local data to seed a fresh Drive file.
        if (!isEmployeeMode &&
            (_profile.name.isNotEmpty ||
                _invoices.isNotEmpty ||
                _clients.isNotEmpty)) {
          await _pushToDrive();
        }
      }
    } catch (e) {
      // Network / API failure — keep using local data, don't touch Drive.
      _lastSyncError = 'network: $e';
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  void _applyData(Map<String, dynamic> data) {
    if (data['profile'] != null) {
      _profile =
          BusinessProfile.fromJson(data['profile'] as Map<String, dynamic>);
    }
    if (data['invoices'] != null) {
      _invoices = (data['invoices'] as List)
          .map((e) => Invoice.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    if (data['clients'] != null) {
      _clients = (data['clients'] as List)
          .map((e) => Client.fromJson(e as Map<String, dynamic>))
          .toList();
    }
  }

  // ── Business-scoped storage key helpers ──────────────────────────────────
  // In employee mode we use an 'emp_' prefix so the employee's cached copy
  // of the owner's data never overwrites the employee's own business data.
  String _pKey(String id)  => isEmployeeMode ? 'emp_profile_$id' : 'profile_$id';
  String _iKey(String id)  => isEmployeeMode ? 'emp_invoices_$id' : 'invoices_$id';
  String _cKey(String id)  => isEmployeeMode ? 'emp_clients_$id' : 'clients_$id';

  Future<void> _loadLocal() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      // Legacy key migration (owner mode only — never pollute emp_ keys with
      // the employee's own data or copy old unscoped keys under emp_ prefix).
      if (!isEmployeeMode) {
        // Migrate unscoped legacy keys to scoped keys on first run.
        if (!prefs.containsKey(_pKey(_kBusinessId)) &&
            !prefs.containsKey(_iKey(_kBusinessId)) &&
            !prefs.containsKey(_cKey(_kBusinessId))) {
          final legacyProfile  = prefs.getString('profile');
          final legacyInvoices = prefs.getString('invoices');
          final legacyClients  = prefs.getString('clients');
          if (legacyProfile != null)  await prefs.setString(_pKey(_kBusinessId), legacyProfile);
          if (legacyInvoices != null) await prefs.setString(_iKey(_kBusinessId), legacyInvoices);
          if (legacyClients != null)  await prefs.setString(_cKey(_kBusinessId), legacyClients);
        }
        // One-time migration: copy old account-level tier key to the scoped key.
        const legacyTierKey = 'subscription_tier_v2';
        final legacyTier = prefs.getString(legacyTierKey);
        if (legacyTier != null) {
          if (!prefs.containsKey(_tierCacheKey(_kBusinessId))) {
            await prefs.setString(_tierCacheKey(_kBusinessId), legacyTier);
          }
          await prefs.remove(legacyTierKey);
        }
      }
      await _loadBusinessData(prefs);
    } catch (_) {
      // Corrupted local data — start fresh; Drive sync will restore it.
    }
    // Apply tier cache only in owner mode — in employee mode the tier comes
    // from the owner's Drive file and must not be overwritten by the
    // employee's own subscription cache.
    if (!isEmployeeMode) {
      _applyTierCache(prefs);
    }
  }

  Future<void> _loadBusinessData(SharedPreferences prefs) async {
    final profileRaw = prefs.getString(_pKey(_kBusinessId));
    if (profileRaw != null) {
      final json = _enc.decryptSafe(profileRaw);
      _profile = BusinessProfile.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } else {
      _profile = BusinessProfile();
    }
    final invoicesRaw = prefs.getString(_iKey(_kBusinessId));
    if (invoicesRaw != null) {
      final json = _enc.decryptSafe(invoicesRaw);
      _invoices = (jsonDecode(json) as List)
          .map((e) => Invoice.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      _invoices = [];
    }
    final clientsRaw = prefs.getString(_cKey(_kBusinessId));
    if (clientsRaw != null) {
      final json = _enc.decryptSafe(clientsRaw);
      _clients = (jsonDecode(json) as List)
          .map((e) => Client.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      _clients = [];
    }
  }

  Future<void> _saveLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_iKey(_kBusinessId),
        _enc.encrypt(jsonEncode(_invoices.map((e) => e.toJson()).toList())));
    await prefs.setString(_cKey(_kBusinessId),
        _enc.encrypt(jsonEncode(_clients.map((e) => e.toJson()).toList())));
    await prefs.setString(
        _pKey(_kBusinessId), _enc.encrypt(jsonEncode(_profile.toJson())));
  }

  Future<void> _clearLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pKey(_kBusinessId));
    await prefs.remove(_iKey(_kBusinessId));
    await prefs.remove(_cKey(_kBusinessId));
    await prefs.remove('business_list');
    await prefs.remove('active_business_id');
    await prefs.remove('onboardingComplete');
    await prefs.remove('subscription_tier_v2');
  }

  Future<void> _pushToDrive() async {
    if (_drive == null) return;
    if (_profile.name.isEmpty && _invoices.isEmpty && _clients.isEmpty) return;
    final payload = jsonEncode({
      'profile': _profile.toJson(),
      'invoices': _invoices.map((e) => e.toJson()).toList(),
      'clients': _clients.map((e) => e.toJson()).toList(),
    });
    if (isEmployeeMode && _pairing != null && _pairingEnc != null) {
      await _drive!.saveDataByFileId(_pairing!.fileId, _pairingEnc!.encrypt(payload));
    } else {
      await _drive!.saveData(_enc.encrypt(payload));
    }
  }

  /// Persists data to local storage and Drive in the background.
  /// Must NOT be awaited from CRUD methods — call with unawaited() so
  /// notifyListeners() fires before the heavy I/O work begins.
  Future<void> _save() async {
    await _saveLocal();
    _pushToDrive().catchError((_) {});
    _pushStats().catchError((_) {});
  }

  /// Pushes anonymised stats at most once every 60 seconds.
  Future<void> _pushStats() async {
    final email = _userEmail;
    if (email == null) return;
    final now = DateTime.now();
    if (_lastStatsPush != null &&
        now.difference(_lastStatsPush!).inSeconds < 60) {
      return;
    }
    _lastStatsPush = now;
    await VerificationService.pushStats(
      userEmail: email,
      businessId: _kBusinessId,
      businessName: _profile.name,
      invoiceCount: _invoices.length,
      clientCount: _clients.length,
    );
  }

  Future<void> _checkVerificationStatus() async {
    await refreshVerificationStatus();
  }

  /// Reads the per-business tier cache and applies it to the active profile.
  /// Called after every profile load so Drive data can never silently
  /// overwrite a tier that was already authoritatively confirmed.
  void _applyTierCache(SharedPreferences prefs) {
    final stored = prefs.getString(_tierCacheKey(_kBusinessId));
    if (stored == null) return;
    final tier = SubscriptionTier.values.firstWhere(
      (e) => e.name == stored,
      orElse: () => _profile.subscriptionTier,
    );
    _profile.subscriptionTier = tier;
  }

  /// Checks the Firestore subscription document for the active business.
  /// Writes the verified tier to the per-business cache so it survives
  /// Drive syncs and profile reloads.
  Future<void> _syncFirestoreSubscription() async {
    final userId = _userEmail;
    if (userId == null) return;
    try {
      final svc = FirestoreSubscriptionService();
      await svc.initialize();
      final verified = await svc.checkAndSyncExpiry(
        userId,
        _kBusinessId,
        _profile.subscriptionTier,
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tierCacheKey(_kBusinessId), verified.name);
      if (verified != _profile.subscriptionTier) {
        _profile.subscriptionTier = verified;
        await _saveLocal();
        notifyListeners();
      }
    } catch (_) {
      // Firestore unavailable — keep current tier, never downgrade on error.
    }
  }

  /// Fetches the admin-override tier from VerificationService and applies it
  /// to the currently active business.
  ///
  /// Upgrade rule  — always apply a higher tier from the admin.
  /// Downgrade rule — only apply free if the active business's IAP subscription
  ///   has actually expired (subscriptionExpiryDate is null or in the past).
  Future<void> _refreshSubscriptionTier() async {
    final email = _userEmail;
    if (email == null) return;
    try {
      final remote = await VerificationService.fetchSubscriptionTier(email);
      if (remote == null) return;

      final prefs = await SharedPreferences.getInstance();

      // Per-business model: an admin upgrade (remote > current) is only applied
      // if this business already has an explicit tier cache key — meaning it was
      // either migrated from the old account-level tier or explicitly purchased.
      // Newly created free businesses have no key yet and must remain free until
      // an IAP purchase is made for them specifically.
      // Downgrade protection: if the admin tier is lower than the current tier,
      // only allow the downgrade if there is no active IAP subscription.
      if (remote.index < _profile.subscriptionTier.index) {
        final expiry = _profile.subscriptionExpiryDate;
        if (expiry != null && expiry.isAfter(DateTime.now())) return;
      }

      await prefs.setString(_tierCacheKey(_kBusinessId), remote.name);
      if (remote != _profile.subscriptionTier) {
        _profile.subscriptionTier = remote;
        await _saveLocal();
        _pushToDrive().catchError((_) {});
        notifyListeners();
      }
    } catch (_) {}
  }

  /// Re-checks verification status from Firestore.
  /// Accepts an [emailOverride] so callers that know the email can use it
  /// even if [_userEmail] was never cached (e.g. after a cold restart).
  /// Returns true if the fetch succeeded (regardless of whether status changed).
  Future<bool> refreshVerificationStatus({String? emailOverride}) async {
    final email = emailOverride ?? _userEmail;
    if (email == null) return false;
    _userEmail ??= email; // cache for future background calls
    try {
      final remote = await VerificationService.fetchStatus(email);
      if (remote == null) return false;
      if (remote != _profile.verificationStatus) {
        _profile.verificationStatus = remote;
        await _saveLocal();
        _pushToDrive().catchError((_) {});
        notifyListeners();
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Subscription limit checks ────────────────────────────────────

  int get monthlyInvoiceCount {
    final now = DateTime.now();
    return _invoices
        .where((i) =>
            i.invoiceDate.year == now.year && i.invoiceDate.month == now.month)
        .length;
  }

  /// Returns a [LimitInfo] if the user has hit a limit, null if they're within it.
  LimitInfo? checkInvoiceLimit() {
    final tier = _profile.subscriptionTier;
    final cap = SubscriptionLimits.monthlyInvoices[tier]!;
    if (cap == -1) return null;
    if (monthlyInvoiceCount >= cap) {
      return LimitInfo.numeric(LimitType.monthlyInvoices, cap);
    }
    return null;
  }

  LimitInfo? checkClientLimit() {
    final tier = _profile.subscriptionTier;
    final cap = SubscriptionLimits.clients[tier]!;
    if (cap == -1) return null;
    if (_clients.length >= cap) {
      return LimitInfo.numeric(LimitType.clients, cap);
    }
    return null;
  }

  LimitInfo? checkServiceItemLimit() {
    final tier = _profile.subscriptionTier;
    final cap = SubscriptionLimits.serviceItems[tier]!;
    if (cap == -1) return null;
    if (_profile.serviceItems.length >= cap) {
      return LimitInfo.numeric(LimitType.serviceItems, cap);
    }
    return null;
  }

  /// Returns a [LimitInfo] if [feature] is not available on the current tier.
  LimitInfo? checkFeature(LimitType feature) {
    final tier = _profile.subscriptionTier;
    if (SubscriptionLimits.canUse(tier, feature)) return null;
    return LimitInfo.feature(feature, tier);
  }

  // ── Google Play Billing Integration ──────────────────────────────

  /// Initialize billing service and load available products
  Future<void> initializeBilling() async {
    try {
      final billing = BillingService();
      await billing.initialize();
      await billing.loadProducts();
      
      // Check and sync subscription expiry with Firestore
      final userId = _userEmail;
      final firestoreService = FirestoreSubscriptionService();
      try {
        await firestoreService.initialize();
        if (userId != null) {
          final syncedTier = await firestoreService.checkAndSyncExpiry(
            userId,
            _kBusinessId,
            _profile.subscriptionTier,
          );
          if (syncedTier != _profile.subscriptionTier) {
            _profile.subscriptionTier = syncedTier;
            await _saveLocal();
            notifyListeners();
          }
        }
      } catch (e) {
        print('Error syncing subscription expiry: $e');
      }

      // NOTE: Do NOT sync from IAP here. _purchases is always empty at this
      // point because restorePurchases() only triggers the stream — the actual
      // purchase data arrives asynchronously via purchaseStream. Calling
      // getHighestSubscribedTier() now would always return free and overwrite
      // the Firestore-verified tier we just set above.
    } catch (e) {
      print('Error initializing billing: $e');
    }
  }

  /// Purchase a subscription tier
  Future<void> purchaseSubscription(SubscriptionTier tier) async {
    try {
      if (!canUpgradeTo(tier)) {
        throw Exception('Cannot upgrade to this tier from ${_profile.subscriptionTier}');
      }

      final billing = BillingService();
      await billing.purchaseSubscription(tier);
      
      // Save subscription with expiry to Firestore for the active business.
      if (_userEmail != null) {
        await billing.saveSubscriptionWithExpiry(_userEmail!, tier, _kBusinessId);
      }

      // Update local subscription and persist to the per-business tier cache
      // so future Drive syncs / profile reloads never overwrite this paid tier.
      _profile.subscriptionTier = tier;
      _profile.subscriptionExpiryDate =
          DateTime.now().add(const Duration(days: 365));
      await _saveLocal();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tierCacheKey(_kBusinessId), tier.name);
      notifyListeners();
    } catch (e) {
      print('Error purchasing subscription: $e');
      rethrow;
    }
  }

  /// Check if user can upgrade to target tier from current tier
  bool canUpgradeTo(SubscriptionTier targetTier) {
    final firestoreService = FirestoreSubscriptionService();
    return firestoreService.canUpgradeTo(
      _profile.subscriptionTier,
      targetTier,
    );
  }

  /// Get subscription expiry date
  DateTime? getSubscriptionExpiryDate() {
    return _profile.subscriptionExpiryDate;
  }

  /// Check if user has active subscription for a tier
  bool hasActiveSubscription(SubscriptionTier tier) {
    final billing = BillingService();
    return billing.hasActiveSubscription(tier);
  }

  /// Get the highest tier user is subscribed to
  SubscriptionTier getHighestSubscribedTier() {
    final billing = BillingService();
    return billing.getHighestSubscribedTier();
  }

  // ── Invoice helpers ──────────────────────────────────────────────

  String generateInvoiceNumber() {
    final num = _profile.nextInvoiceNumber.toString().padLeft(4, '0');
    return '${_profile.invoicePrefix}$num';
  }

  /// Returns an unsaved in-memory invoice. Nothing is persisted until
  /// [saveInvoice] is called. The counter only increments on first save.
  Invoice buildNewInvoice() {
    return Invoice(
      id: _uuid.v4(),
      invoiceNumber: generateInvoiceNumber(),
      invoiceDate: DateTime.now(),
      dueDate: DateTime.now(),
      currency: _profile.currency,
    );
  }

  Future<void> saveInvoice(Invoice invoice) async {
    final idx = _invoices.indexWhere((i) => i.id == invoice.id);
    if (idx != -1) {
      _invoices[idx] = invoice;
    } else {
      _profile.nextInvoiceNumber++;
      _invoices.insert(0, invoice);
    }
    notifyListeners();
    _save().catchError((_) {});
    ReminderService.scheduleForInvoice(invoice, _reminderSettings)
        .catchError((_) {});
  }

  Future<void> deleteInvoice(String id) async {
    _invoices.removeWhere((i) => i.id == id);
    notifyListeners();
    _save().catchError((_) {});
    ReminderService.cancelForInvoice(id).catchError((_) {});
  }

  Future<void> updateInvoiceStatus(String id, InvoiceStatus status) async {
    final idx = _invoices.indexWhere((i) => i.id == id);
    if (idx != -1) {
      _invoices[idx].status = status;
      notifyListeners();
      _save().catchError((_) {});
      // Cancel reminders when paid or cancelled; re-schedule otherwise
      // (e.g. reverting draft → sent keeps reminders active).
      final invoice = _invoices[idx];
      if (status == InvoiceStatus.paid ||
          status == InvoiceStatus.cancelled) {
        ReminderService.cancelForInvoice(id).catchError((_) {});
      } else {
        ReminderService.scheduleForInvoice(invoice, _reminderSettings)
            .catchError((_) {});
      }
    }
  }

  // ── Client helpers ────────────────────────────────────────────────

  Future<Client> addClient(Client client) async {
    _clients.add(client);
    notifyListeners();
    _save().catchError((_) {});
    return client;
  }

  Future<void> updateClient(Client client) async {
    final idx = _clients.indexWhere((c) => c.id == client.id);
    if (idx != -1) {
      _clients[idx] = client;
      notifyListeners();
      _save().catchError((_) {});
    }
  }

  Future<void> deleteClient(String id) async {
    _clients.removeWhere((c) => c.id == id);
    notifyListeners();
    _save().catchError((_) {});
  }

  String newClientId() => _uuid.v4();

  // ── Profile helpers ───────────────────────────────────────────────

  Future<void> updateProfile(BusinessProfile profile) async {
    _profile = profile;
    notifyListeners();
    _save().catchError((_) {});
  }

  // ── Reminder settings ─────────────────────────────────────────────

  Future<void> updateReminderSettings(ReminderSettings settings) async {
    _reminderSettings = settings;
    await settings.save();
    // Re-schedule every active invoice with the new rules.
    ReminderService.rescheduleAll(_invoices, _reminderSettings)
        .catchError((_) {});
    notifyListeners();
  }

  // ── CSV import ────────────────────────────────────────────────────

  /// Saves a batch of invoices (and their clients) produced by [parseCsv].
  /// New clients are added to the client list if not already present.
  Future<void> bulkImportInvoices(List<Invoice> invoices) async {
    for (final invoice in invoices) {
      // Add client if not already tracked.
      if (invoice.client != null) {
        final exists = _clients.any((c) => c.id == invoice.client!.id);
        if (!exists) _clients.add(invoice.client!);
      }
      final idx = _invoices.indexWhere((i) => i.invoiceNumber == invoice.invoiceNumber);
      if (idx == -1) {
        _invoices.insert(0, invoice);
      }
    }
    notifyListeners();
    _save().catchError((_) {});
    // Schedule reminders for every newly imported invoice.
    for (final invoice in invoices) {
      ReminderService.scheduleForInvoice(invoice, _reminderSettings)
          .catchError((_) {});
    }
  }

  // ── Employee pairing (owner side) ────────────────────────────────────────

  /// Shares the owner's Drive data file with [employeeEmail] and returns the
  /// pairing QR string that the employee will scan.
  /// Must be called on the owner's account (not in employee mode).
  Future<String> generatePairingQr(String employeeEmail) async {
    assert(!isEmployeeMode, 'Only an owner can generate a pairing QR');
    if (_drive == null) throw Exception('Drive not connected');
    final keyB64 = _enc.keyBase64;
    if (keyB64 == null) throw Exception('Encryption key not ready');
    final fileId = await _drive!.shareDataFileWith(employeeEmail);
    final pairing = EmployeePairing(
      ownerEmail: _userEmail!,
      fileId: fileId,
      encKey: keyB64,
    );
    return pairing.toQrString();
  }

  /// Revokes an employee's access to the owner's Drive file.
  Future<void> revokeEmployeeAccess(String employeeEmail) async {
    if (_drive == null) return;
    await _drive!.revokeDataFileAccess(employeeEmail);
  }

  // ── Employee pairing (employee side) ─────────────────────────────────────

  /// Applies a scanned [pairing] and re-syncs from Drive using the owner's file.
  /// The employee's own key and data are preserved — they're stored under
  /// un-prefixed keys and will be available when they switch back.
  ///
  /// Returns null on success, or a non-null error string if the sync failed.
  /// The pairing is always persisted so the employee doesn't need to re-scan
  /// after fixing an auth/scope issue.
  Future<String?> applyPairing(EmployeePairing pairing) async {
    _pairing = pairing;
    _pairingEnc = EncryptionService.withKey(pairing.encKey);
    await PairingService.save(pairing);
    // Load from emp_-prefixed cache so in-memory state reflects the owner's
    // previously cached data (empty on first connection) rather than the
    // employee's own data that was in memory before pairing.
    await _loadLocal();
    notifyListeners();
    if (_drive != null) {
      await _syncFromDrive();
    }
    // Surface any sync error so the caller can guide the user.
    return _lastSyncError;
  }

  /// Disconnects from the owner's business and restores the employee's own data.
  Future<void> disconnectPairing() async {
    _pairing = null;
    _pairingEnc = null;
    await PairingService.clear();
    // Clear any emp_-prefixed cached data.
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('emp_profile_$_kBusinessId');
    await prefs.remove('emp_invoices_$_kBusinessId');
    await prefs.remove('emp_clients_$_kBusinessId');
    // Restore the employee's own data.
    await _loadLocal();
    notifyListeners();
    if (_drive != null) {
      await _syncFromDrive();
    }
  }

  // ── CSV export ────────────────────────────────────────────────────

  bool get hasDrive => _drive != null;

  Future<String?> uploadCsv(String filename, String csvContent) async {
    if (_drive == null) return null;
    try {
      return await _drive!.uploadCsvFile(filename, csvContent);
    } catch (_) {
      return null;
    }
  }
}
