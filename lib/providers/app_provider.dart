import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
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
import '../services/review_service.dart';
import '../models/op_entry.dart';
import '../models/expense.dart';
import '../models/purchase_bill.dart';
import '../models/recurring_schedule.dart';
import '../models/line_item.dart';

/// Thrown when an employee attempts an action their role doesn't permit.
class PermissionDeniedException implements Exception {
  final String resource;
  const PermissionDeniedException(this.resource);
  @override
  String toString() => 'No permission to modify $resource';
}

/// Per-business tier cache key. Written by every authoritative tier source
/// (Firestore, VerificationService, IAP purchase). Re-applied after every
/// profile load so Drive data can never silently overwrite a confirmed tier.
String _tierCacheKey(String businessId) => 'subscription_tier_v3_$businessId';

/// Separate cache for the Firestore-confirmed verification status.
/// Same rationale as [_tierCacheKey]: Drive sync must never silently
/// revert a verified business back to unverified.
String _verCacheKey(String businessId) => 'verification_status_v1_$businessId';

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
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _tierListener;

  // ── Optimistic locking + audit log ──────────────────────────────────────────
  /// Monotonically increasing version stored in every Drive payload.
  /// On write: read Drive version → merge if remote is ahead → write remote+1.
  int _dataVersion = 0;

  /// Append-only log of the last 500 CRUD operations.
  /// Used for the audit trail and as the authoritative source for deletions
  /// during conflict-merge so a delete always beats a concurrent edit.
  List<OpEntry> _opLog = [];

  List<Expense> _expenses = [];
  List<String> _customExpenseCategories = [];
  List<RecurringSchedule> _recurringSchedules = [];
  List<PurchaseBill> _purchaseBills = [];

  static const _kBusinessId = 'default';

  // ── Dual-role: owner + employee of another business ───────────────────────
  String? _employeeOwnerEmail;
  Employee? _activeEmployeeRecord;

  // ── Employee mode: accessing owner's Drive via QR pairing ────────────────
  EmployeePairing? _pairing;
  EncryptionService? _pairingEnc;

  List<Invoice> get invoices => List.unmodifiable(_invoices);
  List<Client> get clients {
    final sorted = [..._clients]
      ..sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
    return List.unmodifiable(sorted);
  }
  BusinessProfile get profile => _profile;
  bool get loaded => _loaded;
  bool get syncing => _syncing;
  bool get needsOnboarding => !_onboardingComplete;
  String? get lastSyncError => _lastSyncError;
  ReminderSettings get reminderSettings => _reminderSettings;

  /// Read-only view of the operation log, newest first.
  List<OpEntry> get opLog => List.unmodifiable(_opLog);

  List<Expense> get expenses => List.unmodifiable(_expenses);

  /// Predefined categories plus any user-created ones, in display order.
  List<String> get customExpenseCategories =>
      List.unmodifiable(_customExpenseCategories);

  List<RecurringSchedule> get recurringSchedules =>
      List.unmodifiable(_recurringSchedules);

  List<PurchaseBill> get purchaseBills => List.unmodifiable(_purchaseBills);

  List<RecurringSchedule> get activeRecurringSchedules =>
      _recurringSchedules.where((s) => s.isActive).toList();

  // Convenience getters for the two document types
  List<Invoice> get quotations =>
      _invoices.where((i) => i.isQuotation).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<Invoice> get invoicesOnly =>
      _invoices.where((i) => !i.isQuotation && !i.isCreditNote).toList();

  List<Invoice> get creditNotes =>
      _invoices.where((i) => i.isCreditNote).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));


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
    // Run both tier sources in parallel with silent=true, then do ONE
    // notifyListeners() at the end — prevents the UI from flickering through
    // multiple tier values as each async source resolves independently.
    //
    // Priority (highest wins):
    //   1. Firestore subscription doc (IAP expiry) — authoritative for paid users
    //   2. VerificationService (admin override)    — can upgrade; limited downgrade
    //   3. Tier cache (prefs)                      — survives Drive/profile overwrites
    //   4. Profile data from Drive/prefs           — lowest; can be stale
    if (_userEmail != null) {
      final tierBefore = _profile.subscriptionTier;
      // Run sequentially — IAP check first, admin override second.
      // Sequential order ensures admin always wins if both sources disagree.
      // Parallel Future.wait caused a race where _syncFirestoreSubscription
      // could finish last and overwrite an admin-granted tier with free.
      await _syncFirestoreSubscription(silent: true).catchError((_) {});
      await _refreshSubscriptionTier(silent: true).catchError((_) {});
      // Single notification after both sources have resolved.
      if (_profile.subscriptionTier != tierBefore) {
        await _saveLocal();
        notifyListeners();
      }
      // Start real-time listener so admin tier changes reflect instantly
      // while the user is actively using the app, without waiting for foreground.
      _startTierListener();
    }

    // Best-effort: check verification status in background.
    _checkVerificationStatus().catchError((_) {});
    // Push latest stats so admin dashboard stays current.
    _pushStats().catchError((_) {});
    // Detect if this user is also an employee of another business.
    _detectEmployeeRole().catchError((_) {});
    // Auto-generate any recurring invoices that fell due since last open.
    generateDueRecurringInvoices().catchError((_) {});
  }

  /// Detaches Drive (on sign-out) and clears local cache + encryption key.
  Future<void> detachDriveAndClear() async {
    _stopTierListener();
    _drive = null;
    _invoices = [];
    _clients = [];
    _profile = BusinessProfile();
    _onboardingComplete = false;
    _employeeOwnerEmail = null;
    _activeEmployeeRecord = null;
    _pairing = null;
    _pairingEnc = null;
    _dataVersion = 0;
    _opLog = [];
    _expenses = [];
    _customExpenseCategories = [];
    _recurringSchedules = [];
    _purchaseBills = [];
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
        // Re-apply the cached tier and verification status (owner mode only) —
        // Drive data can lag behind Firestore. In employee mode we honour what
        // came from the owner's Drive file; never overwrite with the employee's cache.
        if (!isEmployeeMode) {
          _applyTierCache(prefs);
          _applyVerificationCache(prefs);
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
    if (data['expenses'] != null) {
      _expenses = (data['expenses'] as List)
          .map((e) => Expense.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    if (data['customExpenseCategories'] != null) {
      _customExpenseCategories = (data['customExpenseCategories'] as List)
          .map((e) => e as String)
          .toList();
    }
    if (data['recurringSchedules'] != null) {
      _recurringSchedules = (data['recurringSchedules'] as List)
          .map((e) =>
              RecurringSchedule.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    if (data['purchaseBills'] != null) {
      _purchaseBills = (data['purchaseBills'] as List)
          .map((e) => PurchaseBill.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    // Graceful fallback for data written before this feature was added.
    _dataVersion = (data['version'] as int?) ?? 0;
    _opLog = _parseOpLog(data['opLog']);
  }

  // ── Optimistic locking helpers ────────────────────────────────────────────

  /// Returns true if the current actor is allowed to perform [p].
  /// Public permission check used by UI widgets to show/hide controls.
  /// Owners always return true.  Employees are checked against their record;
  /// while the Firestore record is still loading, staff defaults apply.
  bool canDo(AppPermission permission) => _hasPermission(permission);

  /// Owners always pass. Employees fall back to staff defaults while their
  /// Firestore record is still loading.
  bool _hasPermission(AppPermission p) {
    if (!isEmployeeMode) return true;
    final record = _activeEmployeeRecord;
    if (record == null) {
      return roleDefaultPermissions[EmployeeRole.staff]!.contains(p);
    }
    return record.can(p);
  }

  /// Prepends a new entry to [_opLog], capped at 500 entries.
  void _appendOp(String opType, String entityId, String entityLabel) {
    _opLog.insert(
      0,
      OpEntry(
        id: _uuid.v4(),
        actorEmail: _userEmail ?? 'unknown',
        timestamp: DateTime.now(),
        opType: opType,
        entityId: entityId,
        entityLabel: entityLabel,
      ),
    );
    if (_opLog.length > 500) _opLog = _opLog.sublist(0, 500);
  }

  /// Builds the full Drive payload JSON string (unencrypted).
  String _buildPayload() => jsonEncode({
        'version': _dataVersion,
        'lastSavedBy': _userEmail ?? '',
        'lastSavedAt': DateTime.now().toIso8601String(),
        'profile': _profile.toJson(),
        'invoices': _invoices.map((e) => e.toJson()).toList(),
        'clients': _clients.map((e) => e.toJson()).toList(),
        'expenses': _expenses.map((e) => e.toJson()).toList(),
        'customExpenseCategories': _customExpenseCategories,
        'recurringSchedules':
            _recurringSchedules.map((s) => s.toJson()).toList(),
        'purchaseBills': _purchaseBills.map((b) => b.toJson()).toList(),
        'opLog': _opLog.map((e) => e.toJson()).toList(),
      });

  /// Safely parses a raw opLog value from JSON, returning [] on any error.
  List<OpEntry> _parseOpLog(dynamic raw) {
    if (raw == null) return [];
    try {
      return (raw as List)
          .map((e) => OpEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Merges [remoteData] into local state using last-write-wins per entity.
  /// Deletions recorded in the combined op log are always honoured, so a
  /// concurrent delete always beats a concurrent edit for the same record.
  void _mergeWithRemote(
      Map<String, dynamic> remoteData, List<OpEntry> remoteOpLog) {
    final allOps = _mergeOpLogs(_opLog, remoteOpLog);

    final deletedInvoiceIds = allOps
        .where((op) => op.opType == 'deleteInvoice')
        .map((op) => op.entityId)
        .toSet();
    final deletedClientIds = allOps
        .where((op) => op.opType == 'deleteClient')
        .map((op) => op.entityId)
        .toSet();
    final deletedExpenseIds = allOps
        .where((op) => op.opType == 'deleteExpense')
        .map((op) => op.entityId)
        .toSet();

    // Merge invoices — keep latest version per ID
    final remoteInvoices = (remoteData['invoices'] as List? ?? [])
        .map((e) => Invoice.fromJson(e as Map<String, dynamic>))
        .toList();
    final invoiceMap = <String, Invoice>{};
    for (final inv in [..._invoices, ...remoteInvoices]) {
      if (deletedInvoiceIds.contains(inv.id)) continue;
      final existing = invoiceMap[inv.id];
      if (existing == null) {
        invoiceMap[inv.id] = inv;
      } else {
        final t1 = existing.lastEditedAt ?? existing.createdAt;
        final t2 = inv.lastEditedAt ?? inv.createdAt;
        if (t2.isAfter(t1)) invoiceMap[inv.id] = inv;
      }
    }
    _invoices = invoiceMap.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // Merge clients — keep latest version per ID
    final remoteClients = (remoteData['clients'] as List? ?? [])
        .map((e) => Client.fromJson(e as Map<String, dynamic>))
        .toList();
    final clientMap = <String, Client>{};
    for (final c in [..._clients, ...remoteClients]) {
      if (deletedClientIds.contains(c.id)) continue;
      final existing = clientMap[c.id];
      if (existing == null) {
        clientMap[c.id] = c;
      } else {
        final t1 = existing.lastEditedAt ?? DateTime(2020);
        final t2 = c.lastEditedAt ?? DateTime(2020);
        if (t2.isAfter(t1)) clientMap[c.id] = c;
      }
    }
    _clients = clientMap.values.toList();

    // Merge expenses — last-write-wins per ID
    final remoteExpenses = (remoteData['expenses'] as List? ?? [])
        .map((e) => Expense.fromJson(e as Map<String, dynamic>))
        .toList();
    final expenseMap = <String, Expense>{};
    for (final ex in [..._expenses, ...remoteExpenses]) {
      if (deletedExpenseIds.contains(ex.id)) continue;
      final existing = expenseMap[ex.id];
      if (existing == null) {
        expenseMap[ex.id] = ex;
      } else {
        final t1 = existing.lastEditedAt ?? existing.createdAt;
        final t2 = ex.lastEditedAt ?? ex.createdAt;
        if (t2.isAfter(t1)) expenseMap[ex.id] = ex;
      }
    }
    _expenses = expenseMap.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    // Merge custom categories — union, preserve insertion order
    final remoteCats = (remoteData['customExpenseCategories'] as List? ?? [])
        .map((e) => e as String)
        .toList();
    final seen = <String>{..._customExpenseCategories};
    for (final cat in remoteCats) {
      if (seen.add(cat)) _customExpenseCategories.add(cat);
    }
  }

  /// Unions two op logs, deduplicates by ID, and sorts newest-first.
  /// Result is capped at 500 entries.
  List<OpEntry> _mergeOpLogs(List<OpEntry> a, List<OpEntry> b) {
    final seen = <String>{};
    final merged = <OpEntry>[];
    for (final op in [...a, ...b]) {
      if (seen.add(op.id)) merged.add(op);
    }
    merged.sort((x, y) => y.timestamp.compareTo(x.timestamp));
    return merged.length > 500 ? merged.sublist(0, 500) : merged;
  }

  /// Read-check-write with conflict merge for a single Drive file.
  /// [read] fetches the raw (encrypted) string; [write] saves the payload.
  /// [encSvc] is used for decrypt/encrypt of that file.
  Future<void> _syncVersionAndWrite({
    required Future<String?> Function() read,
    required Future<void> Function(String) write,
    required EncryptionService encSvc,
  }) async {
    final raw = await read();
    if (raw != null) {
      try {
        final json = encSvc.isReady ? encSvc.decrypt(raw) : raw;
        final remoteData = jsonDecode(json) as Map<String, dynamic>;
        final remoteVersion = (remoteData['version'] as int?) ?? 0;
        final remoteOpLog = _parseOpLog(remoteData['opLog']);
        if (remoteVersion > _dataVersion) {
          // Remote is ahead — someone else saved while we were working.
          // Merge their changes into local state before writing.
          _mergeWithRemote(remoteData, remoteOpLog);
          _opLog = _mergeOpLogs(_opLog, remoteOpLog);
          notifyListeners();
        }
        _dataVersion = remoteVersion + 1;
      } catch (_) {
        _dataVersion++;
      }
    } else {
      _dataVersion++;
    }
    await write(_buildPayload());
  }

  // ── Business-scoped storage key helpers ──────────────────────────────────
  // In employee mode we use an 'emp_' prefix so the employee's cached copy
  // of the owner's data never overwrites the employee's own business data.
  String _pKey(String id)  => isEmployeeMode ? 'emp_profile_$id' : 'profile_$id';
  String _iKey(String id)  => isEmployeeMode ? 'emp_invoices_$id' : 'invoices_$id';
  String _cKey(String id)  => isEmployeeMode ? 'emp_clients_$id' : 'clients_$id';
  String _exKey(String id) => isEmployeeMode ? 'emp_expenses_$id' : 'expenses_$id';
  String _pbKey(String id) => isEmployeeMode ? 'emp_purchase_bills_$id' : 'purchase_bills_$id';

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
    // Apply tier and verification caches only in owner mode — in employee mode
    // both come from the owner's Drive file and must not be overwritten by the
    // employee's own cached values.
    if (!isEmployeeMode) {
      _applyTierCache(prefs);
      _applyVerificationCache(prefs);
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
    final expensesRaw = prefs.getString(_exKey(_kBusinessId));
    if (expensesRaw != null) {
      try {
        final json = _enc.decryptSafe(expensesRaw);
        _expenses = (jsonDecode(json) as List)
            .map((e) => Expense.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        _expenses = [];
      }
    } else {
      _expenses = [];
    }
    final catsRaw = prefs.getString('expense_cats_$_kBusinessId');
    if (catsRaw != null) {
      try {
        _customExpenseCategories =
            (jsonDecode(catsRaw) as List).map((e) => e as String).toList();
      } catch (_) {
        _customExpenseCategories = [];
      }
    }
    final pbRaw = prefs.getString(_pbKey(_kBusinessId));
    if (pbRaw != null) {
      try {
        final json = _enc.decryptSafe(pbRaw);
        _purchaseBills = (jsonDecode(json) as List)
            .map((e) => PurchaseBill.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        _purchaseBills = [];
      }
    } else {
      _purchaseBills = [];
    }
    final recurringRaw = prefs.getString('recurring_$_kBusinessId');
    if (recurringRaw != null) {
      try {
        _recurringSchedules = (jsonDecode(_enc.decryptSafe(recurringRaw)) as List)
            .map((e) =>
                RecurringSchedule.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        _recurringSchedules = [];
      }
    }
    _dataVersion = prefs.getInt('data_version_$_kBusinessId') ?? 0;
    final opLogRaw = prefs.getString('op_log_$_kBusinessId');
    if (opLogRaw != null) {
      try {
        _opLog = _parseOpLog(jsonDecode(_enc.decryptSafe(opLogRaw)));
      } catch (_) {
        _opLog = [];
      }
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
    await prefs.setString(
      _exKey(_kBusinessId),
      _enc.encrypt(jsonEncode(_expenses.map((e) => e.toJson()).toList())),
    );
    await prefs.setString(
      'expense_cats_$_kBusinessId',
      jsonEncode(_customExpenseCategories),
    );
    if (_recurringSchedules.isNotEmpty) {
      await prefs.setString(
        'recurring_$_kBusinessId',
        _enc.encrypt(jsonEncode(
            _recurringSchedules.map((s) => s.toJson()).toList())),
      );
    }
    if (_purchaseBills.isNotEmpty) {
      await prefs.setString(
        _pbKey(_kBusinessId),
        _enc.encrypt(jsonEncode(
            _purchaseBills.map((b) => b.toJson()).toList())),
      );
    }
    await prefs.setInt('data_version_$_kBusinessId', _dataVersion);
    if (_opLog.isNotEmpty) {
      await prefs.setString(
        'op_log_$_kBusinessId',
        _enc.encrypt(jsonEncode(_opLog.map((e) => e.toJson()).toList())),
      );
    }
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
    await prefs.remove(_exKey(_kBusinessId));
    await prefs.remove('expense_cats_$_kBusinessId');
    await prefs.remove('recurring_$_kBusinessId');
    await prefs.remove(_pbKey(_kBusinessId));
    await prefs.remove('data_version_$_kBusinessId');
    await prefs.remove('op_log_$_kBusinessId');
    await prefs.remove('biz_snapshots_$_kBusinessId');
    // Clear subscription caches so the next login always does a fresh Firestore
    // check rather than returning a stale (possibly 'free') throttled result.
    await prefs.remove(_tierCacheKey(_kBusinessId));
    await prefs.remove(_verCacheKey(_kBusinessId));
    await prefs.remove('subscription_expiry_$_kBusinessId');
    if (_userEmail != null) {
      await prefs.remove('subscription_last_checked_${_userEmail}_$_kBusinessId');
    }
  }

  Future<void> _pushToDrive() async {
    final drive = _drive;
    if (drive == null) return;
    if (_profile.name.isEmpty && _invoices.isEmpty && _clients.isEmpty) return;

    final pairing = _pairing;
    final pairingEnc = _pairingEnc;
    if (isEmployeeMode && pairing != null && pairingEnc != null) {
      // Employee mode: optimistic lock against the owner's shared file.
      await _syncVersionAndWrite(
        read: () => drive.loadDataByFileId(pairing.fileId),
        write: (payload) =>
            drive.saveDataByFileId(pairing.fileId, pairingEnc.encrypt(payload)),
        encSvc: pairingEnc,
      );
    } else {
      // Owner mode: optimistic lock against the standard named file.
      await _syncVersionAndWrite(
        read: () => drive.loadData(),
        write: (payload) => drive.saveData(_enc.encrypt(payload)),
        encSvc: _enc,
      );
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

  /// Reads the per-business verification cache and applies it to the active
  /// profile. Mirrors [_applyTierCache]: Drive sync must never silently revert
  /// a Firestore-confirmed verified status back to unverified.
  void _applyVerificationCache(SharedPreferences prefs) {
    final stored = prefs.getString(_verCacheKey(_kBusinessId));
    if (stored == null) return;
    final status = VerificationStatus.values.firstWhere(
      (e) => e.name == stored,
      orElse: () => _profile.verificationStatus,
    );
    _profile.verificationStatus = status;
  }

  /// Syncs the IAP subscription tier from Firestore's subscriptions collection.
  /// [silent] suppresses the individual notifyListeners() call so the caller
  /// can batch multiple tier sources and notify once.
  Future<void> _syncFirestoreSubscription({bool silent = false}) async {
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
      final cachedName = prefs.getString(_tierCacheKey(_kBusinessId));
      final existing = cachedName != null
          ? SubscriptionTier.values.firstWhere(
              (e) => e.name == cachedName,
              orElse: () => SubscriptionTier.free)
          : SubscriptionTier.free;
      // Downgrade protection: never silently overwrite a non-expired paid tier
      // with free — neither in cache NOR in the in-memory profile.
      // A downgrade is only applied when the subscription has genuinely expired.
      final isDowngrade = verified.index < existing.index;
      final hasExpiredSub = _profile.subscriptionExpiryDate != null &&
          _profile.subscriptionExpiryDate!.isBefore(DateTime.now());
      if (!isDowngrade || hasExpiredSub) {
        await prefs.setString(_tierCacheKey(_kBusinessId), verified.name);
        if (verified != _profile.subscriptionTier) {
          _profile.subscriptionTier = verified;
          await _saveLocal();
          if (!silent) notifyListeners();
        }
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
  /// Fetches the admin-override tier from VerificationService.
  /// [silent] suppresses the individual notifyListeners() call so the caller
  /// can batch multiple tier sources and notify once.
  Future<void> _refreshSubscriptionTier({bool silent = false}) async {
    final email = _userEmail;
    if (email == null) return;
    try {
      final remote = await VerificationService.fetchSubscriptionTier(email);
      if (remote == null) return;

      final prefs = await SharedPreferences.getInstance();

      // Admin overrides are always authoritative — no downgrade protection here.
      // Downgrade protection only applies in _syncFirestoreSubscription (IAP path).

      await prefs.setString(_tierCacheKey(_kBusinessId), remote.name);
      if (remote != _profile.subscriptionTier) {
        _profile.subscriptionTier = remote;
        if (remote != SubscriptionTier.free) {
          final adminExpiry = DateTime.now().add(const Duration(days: 365));
          _profile.subscriptionExpiryDate = adminExpiry;
          // Persist to subscriptions so checkAndSyncExpiry finds a valid
          // non-expired doc and never demotes this admin-granted tier.
          FirestoreSubscriptionService()
              .saveSubscription(email, _kBusinessId, remote, adminExpiry)
              .catchError((_) {});
        } else {
          _profile.subscriptionExpiryDate = null;
          // Clear the subscriptions collection so _syncFirestoreSubscription
          // doesn't restore the old paid tier on the next foreground check.
          FirestoreSubscriptionService()
              .saveSubscription(email, _kBusinessId, SubscriptionTier.free, null)
              .catchError((_) {});
        }
        await _saveLocal();
        _pushToDrive().catchError((_) {});
        if (!silent) notifyListeners();
      }
    } catch (_) {}
  }

  /// Starts a Firestore real-time listener on `verifications/{email}`.
  /// Fires immediately when the admin changes the subscription tier, so the
  /// client app updates without waiting for the next app foreground event.
  void _startTierListener() {
    _stopTierListener();
    final email = _userEmail;
    if (email == null) return;
    try {
      _tierListener = FirebaseFirestore.instance
          .collection('verifications')
          .doc(email)
          .snapshots()
          .listen((snap) async {
        if (!snap.exists) return;
        final data = snap.data();
        if (data == null) return;
        final tierStr = data['subscriptionTier'] as String?;
        if (tierStr == null) return;
        final remote = SubscriptionTier.values.firstWhere(
          (e) => e.name.toLowerCase() == tierStr.toLowerCase(),
          orElse: () => _profile.subscriptionTier,
        );
        // Admin overrides are always authoritative — no downgrade protection.
        if (remote == _profile.subscriptionTier) return;
        final userEmail = _userEmail;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_tierCacheKey(_kBusinessId), remote.name);
        _profile.subscriptionTier = remote;
        if (remote != SubscriptionTier.free) {
          final adminExpiry = DateTime.now().add(const Duration(days: 365));
          _profile.subscriptionExpiryDate = adminExpiry;
          if (userEmail != null) {
            FirestoreSubscriptionService()
                .saveSubscription(userEmail, _kBusinessId, remote, adminExpiry)
                .catchError((_) {});
          }
        } else {
          _profile.subscriptionExpiryDate = null;
          // Clear the subscriptions collection so _syncFirestoreSubscription
          // doesn't restore the old paid tier on the next foreground check.
          if (userEmail != null) {
            FirestoreSubscriptionService()
                .saveSubscription(
                    userEmail, _kBusinessId, SubscriptionTier.free, null)
                .catchError((_) {});
          }
        }
        await _saveLocal();
        _pushToDrive().catchError((_) {});
        notifyListeners();
      }, onError: (_) {});
    } catch (_) {}
  }

  void _stopTierListener() {
    _tierListener?.cancel();
    _tierListener = null;
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
      // Persist the Firestore-confirmed status so Drive syncs can never
      // silently revert a verified business back to unverified.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_verCacheKey(_kBusinessId), remote.name);
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

  LimitInfo? checkPaymentMethodLimit() {
    final tier = _profile.subscriptionTier;
    final cap = SubscriptionLimits.paymentMethods[tier]!;
    if (cap == -1) return null;
    if (_profile.paymentMethods.length >= cap) {
      return LimitInfo.numeric(LimitType.paymentMethods, cap);
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
      // NOTE: Do NOT call checkAndSyncExpiry here — it already ran inline during
      // attachDriveAndSync with a single batched notifyListeners(). Calling it
      // again here would hit the 24h throttle (returning stale cached tier) and
      // could incorrectly overwrite the tier that was just confirmed from Firestore.
      //
      // Also do NOT sync from IAP purchases here — _purchases is always empty at
      // this point because restorePurchases() only triggers the stream; actual
      // purchase data arrives asynchronously. Calling getHighestSubscribedTier()
      // now would always return free and overwrite the Firestore-verified tier.
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
      const bizId = _kBusinessId;
      if (_userEmail != null) {
        await billing.saveSubscriptionWithExpiry(_userEmail!, tier, bizId);
      }

      // Update local subscription and persist to the per-business tier cache
      // so future Drive syncs / profile reloads never overwrite this paid tier.
      _profile.subscriptionTier = tier;
      _profile.subscriptionExpiryDate =
          DateTime.now().add(const Duration(days: 365));
      await _saveLocal();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tierCacheKey(bizId), tier.name);
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

  String generateQuotationNumber() {
    final num = _profile.nextQuotationNumber.toString().padLeft(4, '0');
    return '${_profile.quotationPrefix}$num';
  }

  String generateChallanNumber() {
    final num = _profile.nextChallanNumber.toString().padLeft(4, '0');
    return '${_profile.challanPrefix}$num';
  }

  String generateCreditNoteNumber() {
    final num = _profile.nextCreditNoteNumber.toString().padLeft(4, '0');
    return 'CN-$num';
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

  /// Creates a draft copy of [id] with a new invoice number and today's date.
  Future<Invoice> duplicateInvoice(String id) async {
    final orig = _invoices.firstWhere((i) => i.id == id);
    // Duplicate preserves the document type and uses the matching counter.
    final String newNumber;
    if (orig.isQuotation) {
      newNumber = generateQuotationNumber();
      _profile.nextQuotationNumber++;
    } else if (orig.isDeliveryChallan) {
      newNumber = generateChallanNumber();
      _profile.nextChallanNumber++;
    } else {
      newNumber = generateInvoiceNumber();
      _profile.nextInvoiceNumber++;
    }
    final copy = Invoice(
      id: _uuid.v4(),
      invoiceNumber: newNumber,
      client: orig.client,
      invoiceDate: DateTime.now(),
      dueDate: DateTime.now().add(const Duration(days: 30)),
      items: orig.items.map((i) => i.copy()).toList(),
      status: InvoiceStatus.draft,
      isQuotation: orig.isQuotation,
      quotationStatus: orig.isQuotation ? QuotationStatus.draft : null,
      isDeliveryChallan: orig.isDeliveryChallan,
      subject: orig.subject,
      notes: orig.notes,
      terms: orig.terms,
      globalDiscountPercent: orig.globalDiscountPercent,
      globalDiscountFlat: orig.globalDiscountFlat,
      currency: orig.currency,
      template: orig.template,
      paymentMethodId: orig.paymentMethodId,
      paymentMethodName: orig.paymentMethodName,
      placeOfSupply: orig.placeOfSupply,
      reverseCharge: orig.reverseCharge,
      customFields: orig.customFields.map((f) => f.copy()).toList(),
      createdBy: _userEmail ?? '',
    );
    _invoices.insert(0, copy);
    _appendOp('createInvoice', copy.id, '${copy.invoiceNumber} [copy]');
    notifyListeners();
    _save().catchError((_) {});
    return copy;
  }

  Future<void> saveInvoice(Invoice invoice) async {
    final idx = _invoices.indexWhere((i) => i.id == invoice.id);
    final isNew = idx == -1;
    if (!_hasPermission(
        isNew ? AppPermission.createInvoice : AppPermission.editInvoice)) {
      throw PermissionDeniedException('invoices');
    }
    final actor = _userEmail ?? '';
    final now = DateTime.now();
    if (isNew) {
      invoice.createdBy ??= actor;
      // Increment the counter that matches the document type being saved.
      if (invoice.isQuotation) {
        _profile.nextQuotationNumber++;
      } else if (invoice.isDeliveryChallan) {
        _profile.nextChallanNumber++;
      } else if (!invoice.isCreditNote) {
        // Credit notes manage their own counter in issueCreditNote().
        _profile.nextInvoiceNumber++;
      }
      _invoices.insert(0, invoice);
    } else {
      _invoices[idx] = invoice;
    }
    invoice.lastEditedBy = actor;
    invoice.lastEditedAt = now;
    // Recompute status from recorded payments — ensures partial payments that
    // collectively cover the invoice total always result in InvoiceStatus.paid.
    if (!invoice.isQuotation &&
        !invoice.isCreditNote &&
        !invoice.isDeliveryChallan &&
        invoice.status != InvoiceStatus.cancelled &&
        invoice.grandTotal > 0) {
      if (invoice.amountPaid >= invoice.grandTotal - 0.01) {
        invoice.status = InvoiceStatus.paid;
      } else if (invoice.amountPaid > 0) {
        invoice.status = InvoiceStatus.partiallyPaid;
      }
    }
    _appendOp(
        isNew ? 'createInvoice' : 'updateInvoice', invoice.id, invoice.invoiceNumber);
    notifyListeners();
    _save().catchError((_) {});
    if (invoice.status == InvoiceStatus.paid ||
        invoice.status == InvoiceStatus.cancelled) {
      ReminderService.cancelForInvoice(invoice.id).catchError((_) {});
    } else {
      ReminderService.scheduleForInvoice(invoice, _reminderSettings)
          .catchError((_) {});
    }
    if (isNew && !invoice.isDeliveryChallan && !invoice.isQuotation &&
        !invoice.isCreditNote) {
      ReviewService.onInvoiceSaved().catchError((_) {});
    }
  }

  Future<void> deleteInvoice(String id) async {
    if (!_hasPermission(AppPermission.deleteInvoice)) {
      throw PermissionDeniedException('invoices');
    }
    String label = id;
    try {
      final invoice = _invoices.firstWhere((i) => i.id == id);
      label = invoice.invoiceNumber;
      _restoreStockForInvoice(invoice);
    } catch (_) {}
    _invoices.removeWhere((i) => i.id == id);
    _appendOp('deleteInvoice', id, label);
    notifyListeners();
    _save().catchError((_) {});
    ReminderService.cancelForInvoice(id).catchError((_) {});
  }

  Future<void> updateInvoiceStatus(String id, InvoiceStatus status) async {
    if (!_hasPermission(AppPermission.markInvoicePaid)) {
      throw PermissionDeniedException('invoice status');
    }
    final idx = _invoices.indexWhere((i) => i.id == id);
    if (idx != -1) {
      _invoices[idx].status = status;
      _invoices[idx].lastEditedBy = _userEmail ?? '';
      _invoices[idx].lastEditedAt = DateTime.now();
      _appendOp('updateInvoiceStatus', id,
          '${_invoices[idx].invoiceNumber}→${status.name}');
      notifyListeners();
      _save().catchError((_) {});
      final invoice = _invoices[idx];
      // Deduct stock when sent/paid; restore if cancelled or moved back to draft.
      if (status == InvoiceStatus.sent || status == InvoiceStatus.paid) {
        _deductStockForInvoice(invoice);
      } else if (status == InvoiceStatus.cancelled ||
          status == InvoiceStatus.draft) {
        _restoreStockForInvoice(invoice);
      }
      // Cancel reminders when paid or cancelled; re-schedule otherwise.
      if (status == InvoiceStatus.paid || status == InvoiceStatus.cancelled) {
        ReminderService.cancelForInvoice(id).catchError((_) {});
      } else {
        ReminderService.scheduleForInvoice(invoice, _reminderSettings)
            .catchError((_) {});
      }
    }
  }

  // ── Client helpers ────────────────────────────────────────────────

  Future<Client> addClient(Client client) async {
    if (!_hasPermission(AppPermission.createClient)) {
      throw PermissionDeniedException('clients');
    }
    final now = DateTime.now();
    client.createdBy ??= _userEmail;
    client.lastEditedBy = _userEmail;
    client.lastEditedAt = now;
    _clients.add(client);
    _appendOp('createClient', client.id, client.displayName);
    notifyListeners();
    _save().catchError((_) {});
    return client;
  }

  Future<void> updateClient(Client client) async {
    if (!_hasPermission(AppPermission.editClient)) {
      throw PermissionDeniedException('clients');
    }
    client.lastEditedBy = _userEmail;
    client.lastEditedAt = DateTime.now();
    final idx = _clients.indexWhere((c) => c.id == client.id);
    if (idx != -1) {
      _clients[idx] = client;
      _appendOp('updateClient', client.id, client.displayName);
      notifyListeners();
      _save().catchError((_) {});
    }
  }

  Future<void> deleteClient(String id) async {
    if (!_hasPermission(AppPermission.deleteClient)) {
      throw PermissionDeniedException('clients');
    }
    String label = id;
    try {
      label = _clients.firstWhere((c) => c.id == id).displayName;
    } catch (_) {}
    _clients.removeWhere((c) => c.id == id);
    _appendOp('deleteClient', id, label);
    notifyListeners();
    _save().catchError((_) {});
  }

  String newClientId() => _uuid.v4();

  // ── Profile helpers ───────────────────────────────────────────────

  Future<void> updateProfile(BusinessProfile profile) async {
    // Subscription and verification fields are managed exclusively by
    // Firestore/IAP and VerificationService — never by settings screens.
    // Restoring them here means no screen can accidentally drop a paid tier
    // or verified badge regardless of which fields it copies from the profile.
    profile.subscriptionTier = _profile.subscriptionTier;
    profile.subscriptionExpiryDate = _profile.subscriptionExpiryDate;
    profile.subscriptionLastCheckedDate = _profile.subscriptionLastCheckedDate;
    profile.verificationStatus = _profile.verificationStatus;
    profile.verificationNotes = _profile.verificationNotes;
    profile.verificationSubmittedAt = _profile.verificationSubmittedAt;
    _profile = profile;
    notifyListeners();
    _save().catchError((_) {});
  }

  /// Updates a single service item in-place by ID. Used by the inventory screen
  /// for quick quantity adjustments without rebuilding the whole profile.
  void updateServiceItem(ServiceItem updated) {
    final idx =
        _profile.serviceItems.indexWhere((s) => s.id == updated.id);
    if (idx == -1) return;
    _profile.serviceItems[idx] = updated;
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
    if (!_hasPermission(AppPermission.createInvoice)) {
      throw PermissionDeniedException('invoices');
    }
    final actor = _userEmail ?? '';
    final now = DateTime.now();
    for (final invoice in invoices) {
      if (invoice.client != null) {
        final exists = _clients.any((c) => c.id == invoice.client!.id);
        if (!exists) _clients.add(invoice.client!);
      }
      final idx = _invoices.indexWhere(
          (i) => i.invoiceNumber == invoice.invoiceNumber);
      if (idx == -1) {
        invoice.createdBy ??= actor;
        invoice.lastEditedBy = actor;
        invoice.lastEditedAt = now;
        _invoices.insert(0, invoice);
        _appendOp('createInvoice', invoice.id, invoice.invoiceNumber);
      }
    }
    notifyListeners();
    _save().catchError((_) {});
    for (final invoice in invoices) {
      ReminderService.scheduleForInvoice(invoice, _reminderSettings)
          .catchError((_) {});
    }
  }

  // ── Expense helpers ───────────────────────────────────────────────────────

  /// Adds a custom expense category if it doesn't already exist (case-insensitive).
  Future<void> addExpenseCategory(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final already = _customExpenseCategories
        .any((c) => c.toLowerCase() == trimmed.toLowerCase());
    if (already) return;
    _customExpenseCategories.add(trimmed);
    notifyListeners();
    _save().catchError((_) {});
  }

  /// Only owners and managers (who have [AppPermission.manageItems]) can
  /// create, edit, or delete expenses — staff and viewers cannot.
  bool _canManageExpenses() =>
      !isEmployeeMode || _hasPermission(AppPermission.manageItems);

  Future<void> addExpense(Expense expense) async {
    if (!_canManageExpenses()) throw PermissionDeniedException('expenses');
    expense.createdBy ??= _userEmail;
    expense.lastEditedBy = _userEmail;
    expense.lastEditedAt = DateTime.now();
    _expenses.insert(0, expense);
    _appendOp('createExpense', expense.id, expense.title);
    notifyListeners();
    _save().catchError((_) {});
  }

  Future<void> updateExpense(Expense expense) async {
    if (!_canManageExpenses()) throw PermissionDeniedException('expenses');
    expense.lastEditedBy = _userEmail;
    expense.lastEditedAt = DateTime.now();
    final idx = _expenses.indexWhere((e) => e.id == expense.id);
    if (idx != -1) {
      _expenses[idx] = expense;
      _appendOp('updateExpense', expense.id, expense.title);
      notifyListeners();
      _save().catchError((_) {});
    }
  }

  Future<void> deleteExpense(String id) async {
    if (!_canManageExpenses()) throw PermissionDeniedException('expenses');
    String label = id;
    try {
      label = _expenses.firstWhere((e) => e.id == id).title;
    } catch (_) {}
    _expenses.removeWhere((e) => e.id == id);
    _appendOp('deleteExpense', id, label);
    notifyListeners();
    _save().catchError((_) {});
  }

  // ── Purchase bills ────────────────────────────────────────────────────────

  String newPurchaseBillId() => _uuid.v4();

  Future<void> addPurchaseBill(PurchaseBill bill) async {
    bill.createdBy ??= _userEmail;
    bill.lastEditedBy = _userEmail;
    bill.lastEditedAt = DateTime.now();
    _purchaseBills.insert(0, bill);
    _appendOp('createPurchaseBill', bill.id, bill.vendorName);
    notifyListeners();
    _save().catchError((_) {});
    ReminderService.scheduleForBill(bill, _reminderSettings).catchError((_) {});
  }

  Future<void> updatePurchaseBill(PurchaseBill bill) async {
    bill.lastEditedBy = _userEmail;
    bill.lastEditedAt = DateTime.now();
    final idx = _purchaseBills.indexWhere((b) => b.id == bill.id);
    if (idx != -1) {
      _purchaseBills[idx] = bill;
      _appendOp('updatePurchaseBill', bill.id, bill.vendorName);
      notifyListeners();
      _save().catchError((_) {});
      // Re-schedule (or cancel) whenever the bill is updated — respects
      // the current reminderEnabled flag and status.
      ReminderService.scheduleForBill(bill, _reminderSettings).catchError((_) {});
    }
  }

  Future<void> deletePurchaseBill(String id) async {
    String label = id;
    try { label = _purchaseBills.firstWhere((b) => b.id == id).vendorName; } catch (_) {}
    _purchaseBills.removeWhere((b) => b.id == id);
    _appendOp('deletePurchaseBill', id, label);
    notifyListeners();
    _save().catchError((_) {});
    ReminderService.cancelForBill(id).catchError((_) {});
  }

  // ── Recurring schedules ───────────────────────────────────────────────────

  Future<void> addRecurringSchedule(RecurringSchedule schedule) async {
    _recurringSchedules.insert(0, schedule);
    notifyListeners();
    _save().catchError((_) {});
  }

  Future<void> updateRecurringSchedule(RecurringSchedule schedule) async {
    final idx =
        _recurringSchedules.indexWhere((s) => s.id == schedule.id);
    if (idx != -1) {
      _recurringSchedules[idx] = schedule;
      notifyListeners();
      _save().catchError((_) {});
    }
  }

  Future<void> deleteRecurringSchedule(String id) async {
    _recurringSchedules.removeWhere((s) => s.id == id);
    notifyListeners();
    _save().catchError((_) {});
  }

  /// Called on every app start (from [attachDriveAndSync]).  Generates
  /// invoices for any schedule whose [nextGenerationDate] has passed.
  Future<void> generateDueRecurringInvoices() async {
    final now = DateTime.now();
    bool anyGenerated = false;

    for (final schedule in _recurringSchedules) {
      if (!schedule.isActive) continue;
      // Deactivate expired schedules
      if (schedule.endDate != null && now.isAfter(schedule.endDate!)) {
        schedule.isActive = false;
        anyGenerated = true;
        continue;
      }
      if (!now.isAfter(schedule.nextGenerationDate)) continue;

      // Resolve the client from our clients list
      final client = _clients
          .where((c) => c.id == schedule.clientId)
          .firstOrNull;

      // Build the auto-generated invoice
      final invoiceDate = schedule.nextGenerationDate;
      final dueDate =
          invoiceDate.add(Duration(days: schedule.daysTillDue));
      final invoice = Invoice(
        id: _uuid.v4(),
        invoiceNumber: generateInvoiceNumber(),
        invoiceDate: invoiceDate,
        dueDate: dueDate,
        client: client,
        currency: schedule.currency,
        items: schedule.items
            .map((item) => LineItem(
                  description: item.description,
                  quantity: item.quantity,
                  rate: item.rate,
                  taxPercent: item.taxPercent,
                  discountPercent: item.discountPercent,
                  unit: item.unit,
                  hsnSac: item.hsnSac,
                  category: item.category,
                ))
            .toList(),
        globalDiscountPercent: schedule.globalDiscountPercent,
        globalDiscountFlat: schedule.globalDiscountFlat,
        notes: schedule.notes,
        terms: schedule.terms,
        paymentMethodId: schedule.paymentMethodId,
        paymentMethodName: schedule.paymentMethodName,
        recurringScheduleId: schedule.id,
        createdBy: _userEmail ?? '',
        lastEditedBy: _userEmail ?? '',
        lastEditedAt: now,
      );

      _profile.nextInvoiceNumber++;
      _invoices.insert(0, invoice);
      _appendOp('createInvoice', invoice.id,
          '${invoice.invoiceNumber} [auto-recurring]');

      // Advance the schedule to the next period
      schedule.generatedCount++;
      schedule.nextGenerationDate =
          schedule.frequency.nextDate(schedule.nextGenerationDate);

      anyGenerated = true;
    }

    if (anyGenerated) {
      notifyListeners();
      _save().catchError((_) {});
    }
  }

  // ── Quotation helpers ─────────────────────────────────────────────────────

  Future<void> saveQuotation(Invoice quotation) async {
    final isNew = !_invoices.any((i) => i.id == quotation.id);
    if (!_hasPermission(AppPermission.createInvoice)) {
      throw PermissionDeniedException('quotations');
    }
    final actor = _userEmail ?? '';
    final now = DateTime.now();
    if (isNew) {
      quotation.isQuotation = true;
      quotation.quotationStatus ??= QuotationStatus.draft;
      quotation.createdBy = actor;
      _profile.nextQuotationNumber++;
      _invoices.insert(0, quotation);
      _appendOp('createInvoice', quotation.id, quotation.invoiceNumber);
    } else {
      _invoices[_invoices.indexWhere((i) => i.id == quotation.id)] =
          quotation;
      _appendOp('updateInvoice', quotation.id, quotation.invoiceNumber);
    }
    quotation.lastEditedBy = actor;
    quotation.lastEditedAt = now;
    notifyListeners();
    _save().catchError((_) {});
  }

  /// Converts an approved quotation into a live invoice.
  Future<Invoice> convertQuotationToInvoice(String quotationId) async {
    final idx = _invoices.indexWhere((i) => i.id == quotationId);
    if (idx == -1) throw Exception('Quotation not found');
    final q = _invoices[idx];
    final invoice = q.copy()
      ..isQuotation = false
      ..quotationStatus = null
      ..status = InvoiceStatus.draft
      ..invoiceNumber = generateInvoiceNumber()
      ..invoiceDate = DateTime.now()
      ..dueDate = DateTime.now().add(const Duration(days: 30));
    _profile.nextInvoiceNumber++;
    _invoices.insert(0, invoice);
    _appendOp('createInvoice', invoice.id,
        '${invoice.invoiceNumber} [from quotation]');
    notifyListeners();
    _save().catchError((_) {});
    return invoice;
  }

  // ── Delivery challans ─────────────────────────────────────────────────────

  Invoice buildNewChallan() {
    return Invoice(
      id: _uuid.v4(),
      invoiceNumber: generateChallanNumber(),
      invoiceDate: DateTime.now(),
      dueDate: DateTime.now(),
      currency: _profile.currency,
      isDeliveryChallan: true,
    );
  }

  /// Converts a delivery challan into a regular invoice.
  Future<Invoice> convertChallanToInvoice(String challanId) async {
    final idx = _invoices.indexWhere((i) => i.id == challanId);
    if (idx == -1) throw Exception('Challan not found');
    final challan = _invoices[idx];
    final invoice = challan.copy()
      ..isDeliveryChallan = false
      ..challanLinkedInvoiceId = challanId
      ..status = InvoiceStatus.draft
      ..invoiceNumber = generateInvoiceNumber()
      ..invoiceDate = DateTime.now()
      ..dueDate = DateTime.now().add(const Duration(days: 30));
    _profile.nextInvoiceNumber++;
    _invoices.insert(0, invoice);
    _invoices[idx].challanLinkedInvoiceId = invoice.id;
    _appendOp('createInvoice', invoice.id,
        '${invoice.invoiceNumber} [from challan]');
    notifyListeners();
    _save().catchError((_) {});
    return invoice;
  }

  // ── Credit notes ──────────────────────────────────────────────────────────

  /// Issues a credit note against [linkedInvoiceId].
  /// Creates a new Invoice prefilled with the original's items, tagged as
  /// a credit note, and numbered with the CN- prefix.
  /// Returns true if a credit note already exists for [invoiceId].
  bool hasCreditNote(String invoiceId) =>
      _invoices.any((i) => i.isCreditNote && i.creditNoteLinkedInvoiceId == invoiceId);

  Future<Invoice> issueCreditNote({
    required String linkedInvoiceId,
    required String reason,
  }) async {
    if (hasCreditNote(linkedInvoiceId)) {
      throw StateError('A credit note already exists for this invoice.');
    }
    final original = _invoices.firstWhere((i) => i.id == linkedInvoiceId);
    final cn = Invoice(
      id: _uuid.v4(),
      invoiceNumber: generateCreditNoteNumber(),
      invoiceDate: DateTime.now(),
      dueDate: DateTime.now(),
      client: original.client,
      currency: original.currency,
      isCreditNote: true,
      creditNoteLinkedInvoiceId: linkedInvoiceId,
      notes: 'Credit Note for ${original.invoiceNumber}. Reason: $reason',
      items: original.items
          .map((item) => LineItem(
                description: item.description,
                quantity: item.quantity,
                rate: item.rate,
                taxPercent: item.taxPercent,
                discountPercent: item.discountPercent,
                unit: item.unit,
                hsnSac: item.hsnSac,
                category: item.category,
              ))
          .toList(),
      createdBy: _userEmail ?? '',
    );
    _profile.nextCreditNoteNumber++;
    _invoices.insert(0, cn);
    _appendOp('createInvoice', cn.id, cn.invoiceNumber);
    notifyListeners();
    _save().catchError((_) {});
    return cn;
  }

  // ── Inventory stock deduction / restoration ───────────────────────────────

  /// Deducts sold quantities from service-item stock when an invoice is
  /// marked as sent or paid. Idempotent — skips if already deducted.
  void _deductStockForInvoice(Invoice invoice) {
    if (invoice.isQuotation || invoice.isCreditNote) return;
    if (invoice.stockDeducted) return; // already deducted — avoid double-hit
    bool changed = false;
    for (final lineItem in invoice.items) {
      final idx = _profile.serviceItems.indexWhere(
          (si) => si.name.toLowerCase() == lineItem.description.toLowerCase());
      if (idx == -1) continue;
      final si = _profile.serviceItems[idx];
      if (!si.isTrackingStock) continue;
      si.quantityOnHand =
          (si.quantityOnHand! - lineItem.quantity).clamp(0, double.infinity);
      changed = true;
    }
    if (changed) {
      invoice.stockDeducted = true;
      _save().catchError((_) {});
    }
  }

  /// Restores stock quantities when a previously deducted invoice is
  /// cancelled or deleted. Only runs if stock was actually deducted.
  void _restoreStockForInvoice(Invoice invoice) {
    if (!invoice.stockDeducted) return;
    bool changed = false;
    for (final lineItem in invoice.items) {
      final idx = _profile.serviceItems.indexWhere(
          (si) => si.name.toLowerCase() == lineItem.description.toLowerCase());
      if (idx == -1) continue;
      final si = _profile.serviceItems[idx];
      if (!si.isTrackingStock) continue;
      si.quantityOnHand = (si.quantityOnHand ?? 0) + lineItem.quantity;
      changed = true;
    }
    if (changed) {
      invoice.stockDeducted = false;
      _save().catchError((_) {});
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
