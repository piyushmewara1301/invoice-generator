import 'dart:async';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/invoice.dart';
import '../models/client.dart';
import '../models/business_profile.dart';
import '../models/business_info.dart';
import '../models/subscription_limits.dart';
import '../models/reminder_settings.dart';
import '../services/drive_service.dart';
import '../services/encryption_service.dart';
import '../services/reminder_service.dart';
import '../services/verification_service.dart';
import '../services/billing_service.dart';
import '../services/firestore_subscription_service.dart';

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

  // ── Multiple-business state ───────────────────────────────────────────────
  List<BusinessInfo> _businessList = [];
  String _activeBusinessId = 'default';

  // Cross-business count caches (for combined limit enforcement).
  // Active business is always kept in sync; inactive businesses are loaded
  // from prefs once during _loadLocal and updated on switch/create/delete.
  final Map<String, int> _bizClientCount = {};
  final Map<String, int> _bizMonthlyInvCount = {};

  List<Invoice> get invoices => List.unmodifiable(_invoices);
  List<Client> get clients => List.unmodifiable(_clients);
  BusinessProfile get profile => _profile;
  bool get loaded => _loaded;
  bool get syncing => _syncing;
  bool get needsOnboarding => !_onboardingComplete;
  String? get lastSyncError => _lastSyncError;
  List<BusinessInfo> get businesses => List.unmodifiable(_businessList);
  String get activeBusinessId => _activeBusinessId;
  ReminderSettings get reminderSettings => _reminderSettings;

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
    if (tierPrefs.getString(_tierCacheKey(_activeBusinessId)) == null && _userEmail != null) {
      await _refreshSubscriptionTier().catchError((_) {});
    } else {
      _refreshSubscriptionTier().catchError((_) {});
    }

    // Best-effort: check verification status in background.
    _checkVerificationStatus().catchError((_) {});
    // Push latest stats so admin dashboard stays current.
    _pushStats().catchError((_) {});
  }

  /// Detaches Drive (on sign-out) and clears local cache + encryption key.
  Future<void> detachDriveAndClear() async {
    _drive = null;
    _invoices = [];
    _clients = [];
    _profile = BusinessProfile();
    _onboardingComplete = false;
    await _clearLocal();
    await _enc.clearKey();
    notifyListeners();
  }

  Future<void> _syncFromDrive() async {
    if (_drive == null) return;
    _syncing = true;
    notifyListeners();
    try {
      final raw = await _drive!.loadData();
      if (raw != null) {
        // ── Decrypt ──────────────────────────────────────────────────────
        // Use decrypt() (not decryptSafe) so a key mismatch throws rather than
        // silently returning the raw ciphertext, which would cause a JSON parse
        // error that we'd then confuse for a "no data" state.
        final String json;
        try {
          json = _enc.isReady ? _enc.decrypt(raw) : raw;
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
        // Re-apply the cached tier — Drive data can lag behind Firestore/IAP.
        _applyTierCache(prefs);
        await _saveLocal();
      } else {
        // No Drive file found.
        // Only push if we actually have local data to back up.
        // ⚠ NEVER push empty data — that would destroy any pre-existing Drive
        // content (e.g. when web localStorage is blank on a returning user).
        if (_profile.name.isNotEmpty ||
            _invoices.isNotEmpty ||
            _clients.isNotEmpty) {
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
  String _pKey(String id)  => 'profile_$id';
  String _iKey(String id)  => 'invoices_$id';
  String _cKey(String id)  => 'clients_$id';

  Future<void> _loadLocal() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      // ── Migrate old single-business format on first run ────────────────
      final hasBusinessList = prefs.containsKey('business_list');
      if (!hasBusinessList) {
        // Copy legacy keys to scoped keys so nothing is lost.
        final legacyProfile  = prefs.getString('profile');
        final legacyInvoices = prefs.getString('invoices');
        final legacyClients  = prefs.getString('clients');
        if (legacyProfile != null)  await prefs.setString(_pKey('default'), legacyProfile);
        if (legacyInvoices != null) await prefs.setString(_iKey('default'), legacyInvoices);
        if (legacyClients != null)  await prefs.setString(_cKey('default'), legacyClients);
        // Seed business list with a placeholder; name will be filled from profile below.
        await prefs.setString('business_list', jsonEncode([{'id': 'default', 'name': ''}]));
        await prefs.setString('active_business_id', 'default');
      }

      // ── Load business list ─────────────────────────────────────────────
      _activeBusinessId = prefs.getString('active_business_id') ?? 'default';
      final listRaw = prefs.getString('business_list');
      if (listRaw != null) {
        _businessList = (jsonDecode(listRaw) as List)
            .map((e) => BusinessInfo.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      if (_businessList.isEmpty) {
        _businessList = [BusinessInfo(id: 'default', name: '')];
      }

      // ── Load active business data ──────────────────────────────────────
      await _loadBusinessData(_activeBusinessId, prefs);
      // ── Load counts for all inactive businesses ────────────────────────
      await _loadAllBusinessCounts(prefs);
      // ── One-time migration: account-level tier → per-business ──────────
      await _migrateAccountTierToBusinesses(prefs);
    } catch (_) {
      // Corrupted local data — start fresh; Drive sync will restore it.
    }
    _applyTierCache(prefs);
  }

  Future<void> _loadBusinessData(String id, SharedPreferences prefs) async {
    final profileRaw = prefs.getString(_pKey(id));
    if (profileRaw != null) {
      final json = _enc.decryptSafe(profileRaw);
      _profile = BusinessProfile.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } else {
      _profile = BusinessProfile();
    }
    final invoicesRaw = prefs.getString(_iKey(id));
    if (invoicesRaw != null) {
      final json = _enc.decryptSafe(invoicesRaw);
      _invoices = (jsonDecode(json) as List)
          .map((e) => Invoice.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      _invoices = [];
    }
    final clientsRaw = prefs.getString(_cKey(id));
    if (clientsRaw != null) {
      final json = _enc.decryptSafe(clientsRaw);
      _clients = (jsonDecode(json) as List)
          .map((e) => Client.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      _clients = [];
    }
    // Keep the stub name in sync with the actual profile name.
    final stub = _businessList.firstWhere((b) => b.id == id,
        orElse: () => BusinessInfo(id: id, name: ''));
    if (_profile.name.isNotEmpty && stub.name != _profile.name) {
      stub.name = _profile.name;
      await _saveBusinessList(prefs);
    }
    _syncActiveCounts();
  }

  /// Updates the in-memory count maps for the currently active business.
  /// Call this after any mutation to invoices or clients.
  void _syncActiveCounts() {
    final now = DateTime.now();
    _bizClientCount[_activeBusinessId] = _clients.length;
    _bizMonthlyInvCount[_activeBusinessId] = _invoices
        .where((i) =>
            i.invoiceDate.year == now.year &&
            i.invoiceDate.month == now.month)
        .length;
  }

  /// Loads client and invoice counts from prefs for every business that is
  /// NOT currently active (active business is covered by _syncActiveCounts).
  Future<void> _loadAllBusinessCounts(SharedPreferences prefs) async {
    final now = DateTime.now();
    for (final biz in _businessList) {
      if (biz.id == _activeBusinessId) continue;
      try {
        final clientsRaw = prefs.getString(_cKey(biz.id));
        if (clientsRaw != null) {
          final json = _enc.decryptSafe(clientsRaw);
          final list = (jsonDecode(json) as List)
              .map((e) => Client.fromJson(e as Map<String, dynamic>))
              .toList();
          _bizClientCount[biz.id] = list.length;
        } else {
          _bizClientCount[biz.id] = 0;
        }

        final invoicesRaw = prefs.getString(_iKey(biz.id));
        if (invoicesRaw != null) {
          final json = _enc.decryptSafe(invoicesRaw);
          final list = (jsonDecode(json) as List)
              .map((e) => Invoice.fromJson(e as Map<String, dynamic>))
              .toList();
          _bizMonthlyInvCount[biz.id] = list
              .where((i) =>
                  i.invoiceDate.year == now.year &&
                  i.invoiceDate.month == now.month)
              .length;
        } else {
          _bizMonthlyInvCount[biz.id] = 0;
        }
      } catch (_) {
        _bizClientCount[biz.id] = 0;
        _bizMonthlyInvCount[biz.id] = 0;
      }
    }
  }

  /// One-time migration: copies the old account-level `subscription_tier_v2`
  /// key into each business's per-business key, then removes the old key.
  /// After this runs once, the old key is gone and the new keys take over.
  Future<void> _migrateAccountTierToBusinesses(SharedPreferences prefs) async {
    const legacyKey = 'subscription_tier_v2';
    final legacy = prefs.getString(legacyKey);
    if (legacy == null) return; // already migrated or fresh install
    for (final biz in _businessList) {
      final newKey = _tierCacheKey(biz.id);
      if (!prefs.containsKey(newKey)) {
        await prefs.setString(newKey, legacy);
      }
    }
    await prefs.remove(legacyKey);
  }

  Future<void> _saveLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final id = _activeBusinessId;
    await prefs.setString(_iKey(id),
        _enc.encrypt(jsonEncode(_invoices.map((e) => e.toJson()).toList())));
    await prefs.setString(_cKey(id),
        _enc.encrypt(jsonEncode(_clients.map((e) => e.toJson()).toList())));
    await prefs.setString(
        _pKey(id), _enc.encrypt(jsonEncode(_profile.toJson())));
    // Keep stub name in sync.
    final stub = _businessList.firstWhere((b) => b.id == id,
        orElse: () => BusinessInfo(id: id, name: ''));
    if (_profile.name.isNotEmpty && stub.name != _profile.name) {
      stub.name = _profile.name;
      await _saveBusinessList(prefs);
    }
  }

  Future<void> _saveBusinessList(SharedPreferences prefs) async {
    await prefs.setString(
        'business_list',
        jsonEncode(_businessList.map((b) => b.toJson()).toList()));
  }

  Future<void> _clearLocal() async {
    final prefs = await SharedPreferences.getInstance();
    // Remove data for every business.
    for (final b in _businessList) {
      await prefs.remove(_pKey(b.id));
      await prefs.remove(_iKey(b.id));
      await prefs.remove(_cKey(b.id));
    }
    await prefs.remove('business_list');
    await prefs.remove('active_business_id');
    await prefs.remove('onboardingComplete');
    await prefs.remove('subscription_tier_v2'); // legacy key
  }

  // ── Public business management API ────────────────────────────────────────

  /// Switch the active business. Saves the current business first.
  Future<void> switchBusiness(String id) async {
    if (id == _activeBusinessId) return;
    await _saveLocal(); // persist current before switching
    _activeBusinessId = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_business_id', id);
    await _loadBusinessData(id, prefs);
    _applyTierCache(prefs);
    notifyListeners();
  }

  /// Creates a new empty business and switches to it immediately.
  Future<void> createBusiness(String name) async {
    final id = _uuid.v4();
    final info = BusinessInfo(id: id, name: name);
    _businessList.add(info);
    await _saveLocal(); // save current first
    _activeBusinessId = id;
    _invoices = [];
    _clients = [];
    _profile = BusinessProfile()..name = name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_business_id', id);
    await _saveLocal();
    await _saveBusinessList(prefs);
    notifyListeners();
  }

  /// Deletes a business and all its data. Cannot delete the last business.
  Future<bool> deleteBusiness(String id) async {
    if (_businessList.length <= 1) return false; // must keep at least one
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pKey(id));
    await prefs.remove(_iKey(id));
    await prefs.remove(_cKey(id));
    _businessList.removeWhere((b) => b.id == id);
    _bizClientCount.remove(id);
    _bizMonthlyInvCount.remove(id);
    await _saveBusinessList(prefs);
    // If we deleted the active business, switch to the first remaining.
    if (_activeBusinessId == id) {
      _activeBusinessId = _businessList.first.id;
      await prefs.setString('active_business_id', _activeBusinessId);
      await _loadBusinessData(_activeBusinessId, prefs);
      _applyTierCache(prefs);
    }
    notifyListeners();
    return true;
  }

  Future<void> _pushToDrive() async {
    if (_drive == null) return;
    // Hard guard: never overwrite Drive with a completely empty payload.
    // This is the last line of defence against accidental data destruction
    // when local state happens to be blank (e.g. on web before first sync).
    if (_profile.name.isEmpty &&
        _invoices.isEmpty &&
        _clients.isEmpty) {
      return;
    }
    final payload = jsonEncode({
      'profile': _profile.toJson(),
      'invoices': _invoices.map((e) => e.toJson()).toList(),
      'clients': _clients.map((e) => e.toJson()).toList(),
    });
    await _drive!.saveData(_enc.encrypt(payload));
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
    final stored = prefs.getString(_tierCacheKey(_activeBusinessId));
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
        _activeBusinessId,
        _profile.subscriptionTier,
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tierCacheKey(_activeBusinessId), verified.name);
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

      if (remote.index < _profile.subscriptionTier.index) {
        final expiry = _profile.subscriptionExpiryDate;
        if (expiry != null && expiry.isAfter(DateTime.now())) {
          return;
        }
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tierCacheKey(_activeBusinessId), remote.name);
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

  /// Number of invoices created in the current calendar month across ALL businesses.
  int get monthlyInvoiceCount =>
      _bizMonthlyInvCount.values.fold(0, (a, b) => a + b);

  /// Total clients across ALL businesses.
  int get totalClientCount =>
      _bizClientCount.values.fold(0, (a, b) => a + b);

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
    if (totalClientCount >= cap) {
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
            _activeBusinessId,
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
        await billing.saveSubscriptionWithExpiry(_userEmail!, tier, _activeBusinessId);
      }

      // Update local subscription and persist to the per-business tier cache
      // so future Drive syncs / profile reloads never overwrite this paid tier.
      _profile.subscriptionTier = tier;
      _profile.subscriptionExpiryDate =
          DateTime.now().add(const Duration(days: 365));
      await _saveLocal();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tierCacheKey(_activeBusinessId), tier.name);
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
    _syncActiveCounts();
    notifyListeners();
    _save().catchError((_) {});
    ReminderService.scheduleForInvoice(invoice, _reminderSettings)
        .catchError((_) {});
  }

  Future<void> deleteInvoice(String id) async {
    _invoices.removeWhere((i) => i.id == id);
    _syncActiveCounts();
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
    _syncActiveCounts();
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
    _syncActiveCounts();
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
