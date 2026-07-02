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
import '../models/partial_payment.dart';
import '../models/project.dart';
import '../models/stock_transfer.dart';
import '../utils/csv_importer.dart' show BulkInvoiceSpec, InventoryImportPreview, parseInventoryCsv;
import '../services/series_counter_service.dart';
import '../models/daily_sale.dart';
import '../data/db/app_database.dart';
import '../data/db/json_collection_store.dart';
import '../data/db/connection/connection.dart';
import '../data/db/daos/items_dao.dart' show ServiceItemMatch;
import '../data/migration/legacy_data_migrator.dart';

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
  AppProvider(this._enc, this._db) {
    WidgetsBinding.instance.addObserver(this);
    _initCaches();
  }

  final _uuid = const Uuid();
  final EncryptionService _enc;
  AppDatabase _db;

  /// Local Drift database — clients and the service-item catalog.
  AppDatabase get db => _db;

  List<Invoice> _invoices = [];

  /// In-memory mirror of the `clients` table, kept in sync via a Drift
  /// stream so existing call sites can keep reading a plain list. Writes go
  /// through [_db.clientsDao] first; this list is updated immediately after
  /// for synchronous consistency, then reconfirmed by the stream.
  List<Client> _clients = [];

  /// In-memory mirror of the `service_items`/`product_variants`/`item_stock`
  /// tables — replaces the old `BusinessProfile.serviceItems`. See [_clients].
  List<ServiceItem> _itemsCache = [];

  StreamSubscription<List<Client>>? _clientsCacheSub;
  StreamSubscription<List<ServiceItem>>? _itemsCacheSub;

  void _initCaches() {
    _clientsCacheSub = _db.clientsDao.watchAllForCache().listen((rows) {
      _clients = rows;
      notifyListeners();
    });
    _itemsCacheSub = _db.itemsDao.watchAllForCache().listen((rows) {
      _itemsCache = rows;
      notifyListeners();
    });
  }

  /// Local Drift database file name for the current mode — owner and each
  /// paired employee identity get their own file so clients/items never
  /// collide on a device used for both roles. Mirrors the `_iKey`/`_cKey`
  /// SharedPreferences prefix convention.
  String _dbNameFor(bool employeeMode) =>
      employeeMode ? 'emp_$_kBusinessId' : _kBusinessId;

  String get _dbBusinessId => _dbNameFor(isEmployeeMode);

  /// Resolves which Drift database file to open at startup, before
  /// [AppProvider] exists — based on whether this device has a saved
  /// employee pairing.
  static Future<String> resolveDbBusinessId() async {
    final pairing = await PairingService.load();
    return pairing != null ? 'emp_$_kBusinessId' : _kBusinessId;
  }

  /// Opens the local Drift database for this device at startup, called from
  /// `main.dart` before [AppProvider] is constructed. On a device that was
  /// already paired as an employee before owner/employee data was split into
  /// separate database files, this also performs a one-time copy so the
  /// employee's offline cache isn't suddenly empty (see
  /// [migrateToEmployeeDbIfNeeded]).
  static Future<AppDatabase> openInitialDatabase() async {
    final businessId = await resolveDbBusinessId();
    if (businessId != _kBusinessId) {
      await migrateToEmployeeDbIfNeeded();
    }
    return openAppDatabase(businessId);
  }

  /// Closes the current Drift database and opens the one for [businessId],
  /// re-subscribing the in-memory client/item caches to it. Called when
  /// employee pairing is applied or disconnected so the owner's and the
  /// paired employee's clients/items live in separate local files.
  Future<void> _reopenDb(String businessId) async {
    await _clientsCacheSub?.cancel();
    await _itemsCacheSub?.cancel();
    await _db.close();
    _db = openAppDatabase(businessId);
    _initCaches();
  }

  BusinessProfile _profile = BusinessProfile();
  DriveService? _drive;
  String? _userEmail;
  bool _loaded = false;
  bool _syncing = false;
  bool _onboardingComplete = false;
  ReminderSettings _reminderSettings = ReminderSettings();
  /// Item+variant IDs that have already fired a low-stock alert this session.
  /// Cleared when stock rises back above threshold, preventing notification spam.
  final Set<String> _lowStockNotified = {};
  DateTime? _lastStatsPush;
  DateTime? _lastTierCheck;
  String? _lastSyncError;

  /// True while local changes exist that have not yet been confirmed pushed
  /// to Drive — drives the "pending sync" badge in the UI.
  bool _pendingUpload = false;
  /// Timestamp of the last successful push to Drive.
  DateTime? _lastSyncedAt;
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
  List<Project> _projects = [];
  List<TimeEntry> _timeEntries = [];
  List<DailySale> _dailySales = [];
  List<StockTransfer> _stockTransfers = [];
  List<ShopInfo> _registeredShops = [];

  // Per-row Drift-backed stores for the collections above. Each in-memory
  // list stays the source of truth for the UI; every mutation also persists
  // through the matching store so saves no longer rewrite a full JSON blob.
  late final _expensesStore = JsonCollectionStore<Expense>(() => _db, 'expenses',
      toJson: (e) => e.toJson(), fromJson: Expense.fromJson, idOf: (e) => e.id);
  late final _purchaseBillsStore = JsonCollectionStore<PurchaseBill>(
      () => _db, 'purchase_bills',
      toJson: (b) => b.toJson(), fromJson: PurchaseBill.fromJson, idOf: (b) => b.id);
  late final _recurringSchedulesStore = JsonCollectionStore<RecurringSchedule>(
      () => _db, 'recurring_schedules',
      toJson: (s) => s.toJson(), fromJson: RecurringSchedule.fromJson, idOf: (s) => s.id);
  late final _projectsStore = JsonCollectionStore<Project>(() => _db, 'projects',
      toJson: (p) => p.toJson(), fromJson: Project.fromJson, idOf: (p) => p.id);
  late final _timeEntriesStore = JsonCollectionStore<TimeEntry>(() => _db, 'time_entries',
      toJson: (t) => t.toJson(), fromJson: TimeEntry.fromJson, idOf: (t) => t.id);
  late final _dailySalesStore = JsonCollectionStore<DailySale>(() => _db, 'daily_sales',
      toJson: (d) => d.toJson(), fromJson: DailySale.fromJson, idOf: (d) => d.id);
  late final _stockTransfersStore = JsonCollectionStore<StockTransfer>(
      () => _db, 'stock_transfers',
      toJson: (t) => t.toJson(), fromJson: StockTransfer.fromJson, idOf: (t) => t.id);
  late final _registeredShopsStore = JsonCollectionStore<ShopInfo>(
      () => _db, 'registered_shops',
      toJson: (s) => s.toJson(), fromJson: ShopInfo.fromJson, idOf: (s) => s.shopId);

  static const _kBusinessId = 'default';
  static const _kShopIdKey = 'shop_id_v1';
  static const _kShopNameKey = 'shop_name_v1';

  /// Unique ID for this device/shop instance. Generated once on first launch.
  String? _shopId;

  /// Human-readable label for this device/location (e.g. "Main Branch").
  /// Stored per-device in SharedPreferences. Falls back to business profile name.
  String? _shopName;

  /// Owner-only: when non-null, the app filters invoice/sales views to this
  /// shop. null = show all shops. Set by [setOwnerShopFilter].
  String? _ownerShopFilter;

  String? get ownerShopFilter => _ownerShopFilter;

  void setOwnerShopFilter(String? shopId) {
    _ownerShopFilter = shopId;
    notifyListeners();
  }

  // ── Dual-role: owner + employee of another business ───────────────────────
  String? _employeeOwnerEmail;
  Employee? _activeEmployeeRecord;

  // ── Employee mode: accessing owner's Drive via QR pairing ────────────────
  EmployeePairing? _pairing;
  EncryptionService? _pairingEnc;
  DateTime? _lastRevocationCheck;

  List<Invoice> get invoices {
    // Employee with a specific shop restriction: show only their shop's invoices.
    if (isEmployeeMode) {
      final empShopId = _pairing?.shopId;
      final allShops = _activeEmployeeRecord?.accessAllShops ?? false;
      if (empShopId != null && !allShops) {
        return List.unmodifiable(
            _invoices.where((i) => i.shopId == null || i.shopId == empShopId));
      }
    }
    // Owner with a voluntary shop filter.
    if (!isEmployeeMode && _ownerShopFilter != null) {
      return List.unmodifiable(
          _invoices.where((i) => i.shopId == null || i.shopId == _ownerShopFilter));
    }
    return List.unmodifiable(_invoices);
  }

  /// True when any invoice/quotation/challan/credit-note is still awaiting a
  /// real series number from Firestore (created offline, not yet pushed).
  bool get hasPendingNumbers => _invoices.any((i) => i.pendingNumber);

  List<Client> get clients {
    final sorted = [..._clients]
      ..sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
    return List.unmodifiable(sorted);
  }

  /// In-memory copy of the service-item catalog (replaces the old
  /// `profile.serviceItems`). Backed by [_db.itemsDao] — see [_initCaches].
  List<ServiceItem> get serviceItems => List.unmodifiable(_itemsCache);

  BusinessProfile get profile => _profile;
  bool get loaded => _loaded;
  bool get syncing => _syncing;
  bool get needsOnboarding => !_onboardingComplete;
  String? get lastSyncError => _lastSyncError;

  /// True when local changes are queued but not yet confirmed pushed to Drive.
  bool get pendingUpload => _pendingUpload;
  /// When the most recent push to Drive completed successfully.
  DateTime? get lastSyncedAt => _lastSyncedAt;
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

  List<Project> get projects => List.unmodifiable(_projects);
  List<TimeEntry> get timeEntries => List.unmodifiable(_timeEntries);
  List<DailySale> get dailySales {
    final days = _profile.employeeDailySalesVisibilityDays;
    if (isEmployeeMode && days != null && days > 0) {
      final cutoff = DateTime.now().subtract(Duration(days: days));
      final cutoffDate = DateTime(cutoff.year, cutoff.month, cutoff.day);
      return List.unmodifiable(
          _dailySales.where((d) => !d.date.isBefore(cutoffDate)));
    }
    return List.unmodifiable(_dailySales);
  }

  // Convenience getters for the two document types
  List<Invoice> get quotations =>
      _invoices.where((i) => i.isQuotation).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<Invoice> get invoicesOnly =>
      _invoices.where((i) => !i.isQuotation && !i.isCreditNote).toList();

  /// Returns real invoices (not quotations/credit notes) whose [invoiceDate]
  /// falls on [date], applying the same shop filter as [invoices].
  List<Invoice> invoicesForDate(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return invoices.where((inv) {
      if (inv.isQuotation || inv.isCreditNote) return false;
      final id = DateTime(
          inv.invoiceDate.year, inv.invoiceDate.month, inv.invoiceDate.day);
      return id == d;
    }).toList();
  }

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
    _clientsCacheSub?.cancel();
    _itemsCacheSub?.cancel();
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
    if (isEmployeeMode) _checkPairingRevoked().catchError((_) => false);
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
      registerShop().catchError((_) {});
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
    // Ensure this device's shop is registered so other shops can see it
    // (e.g. as a destination for stock transfers/returns).
    registerShop().catchError((_) {});
    // Auto-generate any recurring invoices that fell due since last open.
    generateDueRecurringInvoices().catchError((_) {});
  }

  /// Detaches Drive (on sign-out) and clears local cache + encryption key.
  Future<void> detachDriveAndClear() async {
    _stopTierListener();
    _drive = null;
    final wasEmployeeMode = isEmployeeMode;
    _invoices = [];
    _clients = [];
    _itemsCache = [];
    await _db.clientsDao.replaceAll([]);
    await _db.itemsDao.replaceAll([]);
    await _db.invoicesDao.replaceAll([]);
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
    _projects = [];
    _timeEntries = [];
    _dailySales = [];
    _stockTransfers = [];
    _registeredShops = [];
    await _expensesStore.replaceAll([]);
    await _purchaseBillsStore.replaceAll([]);
    await _recurringSchedulesStore.replaceAll([]);
    await _projectsStore.replaceAll([]);
    await _timeEntriesStore.replaceAll([]);
    await _dailySalesStore.replaceAll([]);
    await _stockTransfersStore.replaceAll([]);
    await _registeredShopsStore.replaceAll([]);
    await _clearLocal();
    await _enc.clearKey();
    await PairingService.clear();
    if (wasEmployeeMode) {
      // Switch back to (and clear) this device's own Drift database so the
      // next sign-in doesn't see a stale paired-employee dataset.
      await _reopenDb(_dbNameFor(false));
      await _db.clientsDao.replaceAll([]);
      await _db.itemsDao.replaceAll([]);
    }
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

  /// Checks whether the owner has deleted or deactivated this employee's
  /// Firestore record. If so, forces a disconnect so the employee immediately
  /// loses access without needing to manually scan again or restart the app.
  ///
  /// Returns true if access was revoked (caller should stop the current sync).
  /// Returns false on network error — gives benefit of the doubt rather than
  /// accidentally locking out an employee during a connectivity blip.
  ///
  /// Throttled to once per 60 s so repeated syncs don't spam Firestore.
  /// Set to a non-null message when the employee was kicked out mid-session
  /// so the UI can show a one-time dialog. Cleared after it is read.
  String? _revocationMessage;
  String? get revocationMessage => _revocationMessage;
  void clearRevocationMessage() => _revocationMessage = null;

  Future<bool> _checkPairingRevoked() async {
    if (!isEmployeeMode || _pairing == null || _userEmail == null) return false;
    final now = DateTime.now();
    if (_lastRevocationCheck != null &&
        now.difference(_lastRevocationCheck!).inSeconds < 60) {
      return false;
    }
    _lastRevocationCheck = now;
    try {
      final record = await EmployeeService.fetchEmployee(
          _pairing!.ownerEmail, _userEmail!);
      if (record == null || !record.isActive) {
        final ownerEmail = _pairing!.ownerEmail;
        _revocationMessage = record == null
            ? 'Your access to $ownerEmail\'s account has been removed by the owner.'
            : 'Your access to $ownerEmail\'s account has been deactivated by the owner.';
        await disconnectPairing();
        return true;
      }
      _activeEmployeeRecord = record;
    } catch (_) {
      // Network error — do not revoke on connectivity blips.
    }
    return false;
  }

  Future<void> _syncFromDrive() async {
    if (_drive == null) return;
    // Verify pairing is still valid before accessing the owner's Drive file.
    if (await _checkPairingRevoked()) return;
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

        await _applyData(data);
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
      _lastSyncedAt = DateTime.now();
      _pendingUpload = false;
    } catch (e) {
      // Network / API failure — keep using local data, don't touch Drive.
      _lastSyncError = 'network: $e';
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  Future<void> _applyData(Map<String, dynamic> data) async {
    final profileJson = data['profile'] as Map<String, dynamic>?;
    if (profileJson != null) {
      _profile = BusinessProfile.fromJson(profileJson);
    }
    if (data['invoices'] != null) {
      _invoices = (data['invoices'] as List)
          .map((e) => Invoice.fromJson(e as Map<String, dynamic>))
          .toList();
      await _db.invoicesDao.replaceAll(_invoices);
    }
    if (data['clients'] != null) {
      _clients = (data['clients'] as List)
          .map((e) => Client.fromJson(e as Map<String, dynamic>))
          .toList();
      await _db.clientsDao.replaceAll(_clients);
    }
    // 'serviceItems' is the new top-level key; fall back to the legacy
    // location inside the profile blob for payloads written before this
    // migration (or a fresh install syncing from an old device).
    final rawItems = data['serviceItems'] ??
        (profileJson != null
            ? BusinessProfile.extractLegacyServiceItems(profileJson)
            : null);
    if (rawItems != null) {
      _itemsCache = rawItems is List<ServiceItem>
          ? rawItems
          : (rawItems as List)
              .map((e) => ServiceItem.fromJson(e as Map<String, dynamic>))
              .toList();
      await _db.itemsDao.replaceAll(_itemsCache);
    }
    if (data['expenses'] != null) {
      _expenses = (data['expenses'] as List)
          .map((e) => Expense.fromJson(e as Map<String, dynamic>))
          .toList();
      await _expensesStore.replaceAll(_expenses);
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
      await _recurringSchedulesStore.replaceAll(_recurringSchedules);
    }
    if (data['purchaseBills'] != null) {
      _purchaseBills = (data['purchaseBills'] as List)
          .map((e) => PurchaseBill.fromJson(e as Map<String, dynamic>))
          .toList();
      await _purchaseBillsStore.replaceAll(_purchaseBills);
    }
    if (data['projects'] != null) {
      _projects = (data['projects'] as List)
          .map((e) => Project.fromJson(e as Map<String, dynamic>))
          .toList();
      await _projectsStore.replaceAll(_projects);
    }
    if (data['timeEntries'] != null) {
      _timeEntries = (data['timeEntries'] as List)
          .map((e) => TimeEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      await _timeEntriesStore.replaceAll(_timeEntries);
    }
    if (data['stockTransfers'] != null) {
      try {
        _stockTransfers = (data['stockTransfers'] as List)
            .map((e) => StockTransfer.fromJson(e as Map<String, dynamic>))
            .toList();
        await _stockTransfersStore.replaceAll(_stockTransfers);
      } catch (_) {}
    }
    if (data['registeredShops'] != null) {
      try {
        _registeredShops = (data['registeredShops'] as List)
            .map((e) => ShopInfo.fromJson(e as Map<String, dynamic>))
            .toList();
        await _registeredShopsStore.replaceAll(_registeredShops);
      } catch (_) {}
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

  /// Builds the full Drive payload JSON string (unencrypted). Clients and
  /// service items are read from the local Drift database, which is the
  /// source of truth for those two collections.
  Future<String> _buildPayload() async {
    final clients = await _db.clientsDao.allForExport();
    final items = await _db.itemsDao.allForExport();
    final invoices = await _db.invoicesDao.allForExport();
    final expenses = await _expensesStore.allForExport();
    final purchaseBills = await _purchaseBillsStore.allForExport();
    final recurringSchedules = await _recurringSchedulesStore.allForExport();
    final projects = await _projectsStore.allForExport();
    final timeEntries = await _timeEntriesStore.allForExport();
    final stockTransfers = await _stockTransfersStore.allForExport();
    final registeredShops = await _registeredShopsStore.allForExport();
    return jsonEncode({
        'version': _dataVersion,
        'lastSavedBy': _userEmail ?? '',
        'lastSavedAt': DateTime.now().toIso8601String(),
        'profile': _profile.toJson(),
        'invoices': invoices.map((e) => e.toJson()).toList(),
        'clients': clients.map((e) => e.toJson()).toList(),
        'serviceItems': items.map((e) => e.toJson()).toList(),
        'expenses': expenses.map((e) => e.toJson()).toList(),
        'customExpenseCategories': _customExpenseCategories,
        'recurringSchedules':
            recurringSchedules.map((s) => s.toJson()).toList(),
        'purchaseBills': purchaseBills.map((b) => b.toJson()).toList(),
        'projects': projects.map((p) => p.toJson()).toList(),
        'timeEntries': timeEntries.map((t) => t.toJson()).toList(),
        'opLog': _opLog.map((e) => e.toJson()).toList(),
        if (stockTransfers.isNotEmpty)
          'stockTransfers': stockTransfers.map((t) => t.toJson()).toList(),
        if (registeredShops.isNotEmpty)
          'registeredShops': registeredShops.map((s) => s.toJson()).toList(),
      });
  }

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
  Future<void> _mergeWithRemote(
      Map<String, dynamic> remoteData, List<OpEntry> remoteOpLog) async {
    final allOps = _mergeOpLogs(_opLog, remoteOpLog);

    final deletedInvoiceIds = allOps
        .where((op) => op.opType == 'deleteInvoice')
        .map((op) => op.entityId)
        .toSet();
    final deletedClientIds = allOps
        .where((op) => op.opType == 'deleteClient')
        .map((op) => op.entityId)
        .toSet();
    final deletedItemIds = allOps
        .where((op) => op.opType == 'deleteServiceItem')
        .map((op) => op.entityId)
        .toSet();
    final deletedExpenseIds = allOps
        .where((op) => op.opType == 'deleteExpense')
        .map((op) => op.entityId)
        .toSet();

    // Merge invoices — keep latest version per ID
    final localInvoices = await _db.invoicesDao.allForExport();
    final remoteInvoices = (remoteData['invoices'] as List? ?? [])
        .map((e) => Invoice.fromJson(e as Map<String, dynamic>))
        .toList();
    final invoiceMap = <String, Invoice>{};
    for (final inv in [...localInvoices, ...remoteInvoices]) {
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
    await _db.invoicesDao.replaceAll(_invoices);

    // Merge clients — keep latest version per ID
    final localClients = await _db.clientsDao.allForExport();
    final remoteClients = (remoteData['clients'] as List? ?? [])
        .map((e) => Client.fromJson(e as Map<String, dynamic>))
        .toList();
    final clientMap = <String, Client>{};
    for (final c in [...localClients, ...remoteClients]) {
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
    await _db.clientsDao.replaceAll(_clients);

    // Merge service items — keep latest version per ID. Falls back to the
    // legacy in-profile location for older remote payloads.
    final localItems = await _db.itemsDao.allForExport();
    final remoteItemsRaw = remoteData['serviceItems'] ??
        BusinessProfile.extractLegacyServiceItems(
            remoteData['profile'] as Map<String, dynamic>? ?? const {});
    final remoteItems = (remoteItemsRaw as List)
        .map((e) => ServiceItem.fromJson(e as Map<String, dynamic>))
        .toList();
    final itemMap = <String, ServiceItem>{};
    for (final it in [...localItems, ...remoteItems]) {
      if (deletedItemIds.contains(it.id)) continue;
      final existing = itemMap[it.id];
      if (existing == null) {
        itemMap[it.id] = it;
      } else {
        final t1 = existing.lastEditedAt ?? DateTime(2020);
        final t2 = it.lastEditedAt ?? DateTime(2020);
        if (t2.isAfter(t1)) itemMap[it.id] = it;
      }
    }
    _itemsCache = itemMap.values.toList();
    await _db.itemsDao.replaceAll(_itemsCache);

    // Merge expenses — last-write-wins per ID
    final localExpenses = await _expensesStore.allForExport();
    final remoteExpenses = (remoteData['expenses'] as List? ?? [])
        .map((e) => Expense.fromJson(e as Map<String, dynamic>))
        .toList();
    final expenseMap = <String, Expense>{};
    for (final ex in [...localExpenses, ...remoteExpenses]) {
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
    await _expensesStore.replaceAll(_expenses);

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
          await _mergeWithRemote(remoteData, remoteOpLog);
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
    await write(await _buildPayload());
  }

  // ── Business-scoped storage key helpers ──────────────────────────────────
  // In employee mode we use an 'emp_' prefix so the employee's cached copy
  // of the owner's data never overwrites the employee's own business data.
  String _pKey(String id)  => isEmployeeMode ? 'emp_profile_$id' : 'profile_$id';
  String _iKey(String id)  => isEmployeeMode ? 'emp_invoices_$id' : 'invoices_$id';
  String _cKey(String id)  => isEmployeeMode ? 'emp_clients_$id' : 'clients_$id';
  String _exKey(String id) => isEmployeeMode ? 'emp_expenses_$id' : 'expenses_$id';
  String _pbKey(String id) => isEmployeeMode ? 'emp_purchase_bills_$id' : 'purchase_bills_$id';
  String _projKey(String id) => 'projects_$id';
  String _teKey(String id) => 'time_entries_$id';

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
    Map<String, dynamic>? profileJson;
    final profileRaw = prefs.getString(_pKey(_kBusinessId));
    if (profileRaw != null) {
      final json = _enc.decryptSafe(profileRaw);
      profileJson = jsonDecode(json) as Map<String, dynamic>;
      _profile = BusinessProfile.fromJson(profileJson);
    } else {
      _profile = BusinessProfile();
    }
    // Legacy invoices blob — read here only to seed the one-time Drift
    // migration below; invoices are loaded from the local database.
    List<Invoice> legacyInvoices = [];
    final invoicesRaw = prefs.getString(_iKey(_kBusinessId));
    if (invoicesRaw != null) {
      final json = _enc.decryptSafe(invoicesRaw);
      legacyInvoices = (jsonDecode(json) as List)
          .map((e) => Invoice.fromJson(e as Map<String, dynamic>))
          .toList();
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
    // Legacy expenses blob — read here only to seed the one-time Drift
    // migration below; expenses are loaded from the local database.
    List<Expense> legacyExpenses = [];
    final expensesRaw = prefs.getString(_exKey(_kBusinessId));
    if (expensesRaw != null) {
      try {
        final json = _enc.decryptSafe(expensesRaw);
        legacyExpenses = (jsonDecode(json) as List)
            .map((e) => Expense.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}
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
    // Legacy blobs for the remaining collections — read here only to seed
    // the one-time Drift migrations below; loaded from the local database
    // afterwards.
    List<PurchaseBill> legacyPurchaseBills = [];
    final pbRaw = prefs.getString(_pbKey(_kBusinessId));
    if (pbRaw != null) {
      try {
        final json = _enc.decryptSafe(pbRaw);
        legacyPurchaseBills = (jsonDecode(json) as List)
            .map((e) => PurchaseBill.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }
    List<RecurringSchedule> legacyRecurringSchedules = [];
    final recurringRaw = prefs.getString('recurring_$_kBusinessId');
    if (recurringRaw != null) {
      try {
        legacyRecurringSchedules =
            (jsonDecode(_enc.decryptSafe(recurringRaw)) as List)
                .map((e) =>
                    RecurringSchedule.fromJson(e as Map<String, dynamic>))
                .toList();
      } catch (_) {}
    }
    List<Project> legacyProjects = [];
    final projRaw = prefs.getString(_projKey(_kBusinessId));
    if (projRaw != null) {
      try {
        legacyProjects = (jsonDecode(_enc.decryptSafe(projRaw)) as List)
            .map((e) => Project.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }
    List<TimeEntry> legacyTimeEntries = [];
    final teRaw = prefs.getString(_teKey(_kBusinessId));
    if (teRaw != null) {
      try {
        legacyTimeEntries = (jsonDecode(_enc.decryptSafe(teRaw)) as List)
            .map((e) => TimeEntry.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }
    List<DailySale> legacyDailySales = [];
    final dsRaw = prefs.getString('daily_sales_$_kBusinessId');
    if (dsRaw != null) {
      try {
        legacyDailySales = (jsonDecode(_enc.decryptSafe(dsRaw)) as List)
            .map((e) => DailySale.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }

    // Pre-load shopId so getOrCreateShopId() can return synchronously after load.
    _shopId = prefs.getString(_kShopIdKey);
    if (_shopId == null) {
      _shopId = _uuid.v4();
      await prefs.setString(_kShopIdKey, _shopId!);
    }

    // Per-device shop display name (optional, falls back to business profile name).
    _shopName = prefs.getString(_kShopNameKey);

    // One-time migration: copy clients (from the legacy prefs blob) and the
    // service-item catalog (from the legacy profile blob) into the local
    // Drift database, then load both from there going forward.
    final legacyItems = profileJson != null
        ? BusinessProfile.extractLegacyServiceItems(profileJson)
        : <ServiceItem>[];
    await LegacyDataMigrator.migrateIfNeeded(
      db: _db,
      clients: _clients,
      serviceItems: legacyItems,
      prefs: prefs,
      businessId: _dbBusinessId,
    );
    _clients = await _db.clientsDao.allForExport();
    _itemsCache = await _db.itemsDao.allForExport();

    // One-time migration: copy invoices (from the legacy prefs blob) into the
    // local Drift database, then load from there going forward.
    await LegacyDataMigrator.migrateInvoicesIfNeeded(
      db: _db,
      invoices: legacyInvoices,
      prefs: prefs,
      businessId: _dbBusinessId,
    );
    _invoices = await _db.invoicesDao.allForExport()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // One-time migrations: copy the remaining JSON-blob collections into the
    // local Drift database, then load each from there going forward.
    await LegacyDataMigrator.migrateCollectionIfNeeded(
      store: _expensesStore,
      items: legacyExpenses,
      prefs: prefs,
      flagKey: 'expenses_migrated_to_drift_v1_$_dbBusinessId',
    );
    _expenses = await _expensesStore.allForExport()
      ..sort((a, b) => b.date.compareTo(a.date));

    await LegacyDataMigrator.migrateCollectionIfNeeded(
      store: _purchaseBillsStore,
      items: legacyPurchaseBills,
      prefs: prefs,
      flagKey: 'purchase_bills_migrated_to_drift_v1_$_dbBusinessId',
    );
    _purchaseBills = await _purchaseBillsStore.allForExport()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    await LegacyDataMigrator.migrateCollectionIfNeeded(
      store: _recurringSchedulesStore,
      items: legacyRecurringSchedules,
      prefs: prefs,
      flagKey: 'recurring_schedules_migrated_to_drift_v1_$_dbBusinessId',
    );
    _recurringSchedules = await _recurringSchedulesStore.allForExport()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    await LegacyDataMigrator.migrateCollectionIfNeeded(
      store: _projectsStore,
      items: legacyProjects,
      prefs: prefs,
      flagKey: 'projects_migrated_to_drift_v1_$_dbBusinessId',
    );
    _projects = await _projectsStore.allForExport()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    await LegacyDataMigrator.migrateCollectionIfNeeded(
      store: _timeEntriesStore,
      items: legacyTimeEntries,
      prefs: prefs,
      flagKey: 'time_entries_migrated_to_drift_v1_$_dbBusinessId',
    );
    _timeEntries = await _timeEntriesStore.allForExport()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    await LegacyDataMigrator.migrateCollectionIfNeeded(
      store: _dailySalesStore,
      items: legacyDailySales,
      prefs: prefs,
      flagKey: 'daily_sales_migrated_to_drift_v1_$_dbBusinessId',
    );
    _dailySales = await _dailySalesStore.allForExport()
      ..sort((a, b) => b.date.compareTo(a.date));

    // Migrate stock recorded before per-shop tracking existed onto this device's shop.
    await _migrateLegacyStock();

    // Legacy blobs for stock transfers / registered shops — read here only
    // to seed the one-time Drift migrations below.
    List<StockTransfer> legacyStockTransfers = [];
    final transfersRaw = prefs.getString('stock_transfers_$_kBusinessId');
    if (transfersRaw != null) {
      try {
        legacyStockTransfers =
            (jsonDecode(_enc.decryptSafe(transfersRaw)) as List)
                .map((e) => StockTransfer.fromJson(e as Map<String, dynamic>))
                .toList();
      } catch (_) {}
    }
    await LegacyDataMigrator.migrateCollectionIfNeeded(
      store: _stockTransfersStore,
      items: legacyStockTransfers,
      prefs: prefs,
      flagKey: 'stock_transfers_migrated_to_drift_v1_$_dbBusinessId',
    );
    _stockTransfers = await _stockTransfersStore.allForExport();

    List<ShopInfo> legacyRegisteredShops = [];
    final shopsRaw = prefs.getString('registered_shops_$_kBusinessId');
    if (shopsRaw != null) {
      try {
        legacyRegisteredShops =
            (jsonDecode(_enc.decryptSafe(shopsRaw)) as List)
                .map((e) => ShopInfo.fromJson(e as Map<String, dynamic>))
                .toList();
      } catch (_) {}
    }
    await LegacyDataMigrator.migrateCollectionIfNeeded(
      store: _registeredShopsStore,
      items: legacyRegisteredShops,
      prefs: prefs,
      flagKey: 'registered_shops_migrated_to_drift_v1_$_dbBusinessId',
    );
    _registeredShops = await _registeredShopsStore.allForExport();

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
    // Invoices, clients, the service-item catalog, and the 8 collections
    // below live in the local Drift database (see _db.invoicesDao /
    // _db.clientsDao / _db.itemsDao / the *Store fields) and are no longer
    // duplicated here.
    await prefs.remove(_iKey(_kBusinessId));
    await prefs.remove(_cKey(_kBusinessId));
    await prefs.remove(_exKey(_kBusinessId));
    await prefs.remove(_pbKey(_kBusinessId));
    await prefs.remove('recurring_$_kBusinessId');
    await prefs.remove(_projKey(_kBusinessId));
    await prefs.remove(_teKey(_kBusinessId));
    await prefs.remove('daily_sales_$_kBusinessId');
    await prefs.remove('stock_transfers_$_kBusinessId');
    await prefs.remove('registered_shops_$_kBusinessId');
    await prefs.setString(
        _pKey(_kBusinessId), _enc.encrypt(jsonEncode(_profile.toJson())));
    await prefs.setString(
      'expense_cats_$_kBusinessId',
      jsonEncode(_customExpenseCategories),
    );
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
    await prefs.remove('daily_sales_$_kBusinessId');
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

    // Assign real sequential numbers to any offline-created documents before
    // writing to Drive, so the shared file never contains pending numbers.
    await _assignPendingNumbersIfNeeded();

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

  /// Contacts the Firestore atomic counter and replaces every in-memory
  /// invoice whose [Invoice.pendingNumber] is true with a real sequential
  /// number before the Drive payload is written.
  ///
  /// Silently no-ops when offline or Firestore is unavailable — the invoices
  /// keep their temporary numbers and will be assigned on the next successful
  /// push.
  Future<void> _assignPendingNumbersIfNeeded() async {
    final email = _userEmail;
    if (email == null) return;

    final pending = _invoices.where((i) => i.pendingNumber).toList();
    if (pending.isEmpty) return;

    // Chronological order so number assignment matches creation order.
    pending.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    // Employees share the owner's counter namespace.
    final counterOwner =
        isEmployeeMode ? (_employeeOwnerEmail ?? email) : email;

    try {
      final assignments = await SeriesCounterService().assignPendingNumbers(
        ownerEmail: counterOwner,
        invoicePrefix: _profile.invoicePrefix,
        quotationPrefix: _profile.quotationPrefix,
        challanPrefix: _profile.challanPrefix,
        pending: pending,
        seedCounters: {
          'invoice':    _profile.nextInvoiceNumber,
          'quotation':  _profile.nextQuotationNumber,
          'challan':    _profile.nextChallanNumber,
          'creditNote': _profile.nextCreditNoteNumber,
        },
      );

      if (assignments.isEmpty) return;

      final changed = <Invoice>[];
      for (int i = 0; i < _invoices.length; i++) {
        final assigned = assignments[_invoices[i].id];
        if (assigned != null) {
          _invoices[i].invoiceNumber = assigned;
          _invoices[i].pendingNumber = false;
          changed.add(_invoices[i]);
        }
      }
      await _db.invoicesDao.upsertAll(changed);

      notifyListeners();
      await _saveLocal();
    } catch (_) {
      // Firestore unavailable — keep pending flag, retry on next push.
    }
  }

  /// Persists data to local storage and Drive in the background.
  /// Must NOT be awaited from CRUD methods — call with unawaited() so
  /// notifyListeners() fires before the heavy I/O work begins.
  Future<void> _save() async {
    if (_drive != null && !_pendingUpload) {
      _pendingUpload = true;
      notifyListeners();
    }
    await _saveLocal();
    if (_drive != null) {
      try {
        await _pushToDrive();
        _pendingUpload = false;
        _lastSyncedAt = DateTime.now();
      } catch (_) {
        // Stays pending — will retry on the next save or app foreground.
      }
      notifyListeners();
    }
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

  Future<LimitInfo?> checkClientLimit() async {
    final tier = _profile.subscriptionTier;
    final cap = SubscriptionLimits.clients[tier]!;
    if (cap == -1) return null;
    if (await _db.clientsDao.count() >= cap) {
      return LimitInfo.numeric(LimitType.clients, cap);
    }
    return null;
  }

  Future<LimitInfo?> checkServiceItemLimit() async {
    final tier = _profile.subscriptionTier;
    final cap = SubscriptionLimits.serviceItems[tier]!;
    if (cap == -1) return null;
    if (await _db.itemsDao.countItems() >= cap) {
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
    // Stamp with current shop context:
    // - in employee mode: use the pairing's shopId
    // - in owner mode: use the owner's shopId (device identifier)
    final stampShopId = isEmployeeMode ? _pairing?.shopId : _shopId;
    return Invoice(
      id: _uuid.v4(),
      invoiceNumber: generateInvoiceNumber(),
      invoiceDate: DateTime.now(),
      dueDate: DateTime.now(),
      currency: _profile.currency,
      pendingNumber: true,
      shopId: stampShopId,
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
      pendingNumber: true,
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
    await _db.invoicesDao.upsert(copy);
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
      invoice.pendingNumber = true;
      // Increment local counter to keep temp numbers unique across offline docs.
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
    await _db.invoicesDao.upsert(invoice);
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
      await _restoreStockForInvoice(invoice);
    } catch (_) {}
    _invoices.removeWhere((i) => i.id == id);
    await _db.invoicesDao.deleteById(id);
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
      await _db.invoicesDao.upsert(_invoices[idx]);
      _appendOp('updateInvoiceStatus', id,
          '${_invoices[idx].invoiceNumber}→${status.name}');
      notifyListeners();
      _save().catchError((_) {});
      final invoice = _invoices[idx];
      // Deduct stock when sent/paid; restore if cancelled or moved back to draft.
      if (status == InvoiceStatus.sent || status == InvoiceStatus.paid) {
        await _deductStockForInvoice(invoice);
      } else if (status == InvoiceStatus.cancelled ||
          status == InvoiceStatus.draft) {
        await _restoreStockForInvoice(invoice);
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

  // ── Bulk status update ────────────────────────────────────────────

  /// Updates [ids] to [status] in a single notifyListeners + save pass.
  ///
  /// For [InvoiceStatus.paid], pass [paymentDate] and optionally [paymentMethodId]
  /// / [paymentMethodName] to record a full PartialPayment on each invoice.
  /// Invoices that are already [status] are silently skipped.
  /// Returns the count of invoices actually changed.
  Future<int> bulkUpdateStatus(
    Set<String> ids,
    InvoiceStatus status, {
    DateTime? paymentDate,
    String? paymentMethodId,
    String? paymentMethodName,
  }) async {
    if (!_hasPermission(AppPermission.markInvoicePaid)) {
      throw PermissionDeniedException('invoice status');
    }
    final now = DateTime.now();
    int changed = 0;
    final changedInvoices = <Invoice>[];

    for (final id in ids) {
      final idx = _invoices.indexWhere((i) => i.id == id);
      if (idx == -1) continue;
      final inv = _invoices[idx];
      if (inv.status == status) continue;

      if (status == InvoiceStatus.paid) {
        // Record a full payment covering the remaining balance.
        final remaining = inv.amountRemaining;
        if (remaining > 0) {
          inv.payments.add(PartialPayment(
            id: _uuid.v4(),
            date: paymentDate ?? now,
            amount: remaining,
            paymentMethodId: paymentMethodId,
            paymentMethodName: paymentMethodName,
          ));
        }
        inv.paymentMethodId = paymentMethodId ?? inv.paymentMethodId;
        inv.paymentMethodName = paymentMethodName ?? inv.paymentMethodName;
      }

      inv.status = status;
      inv.lastEditedBy = _userEmail ?? '';
      inv.lastEditedAt = now;
      _appendOp('bulkUpdateStatus', id, '${inv.invoiceNumber}→${status.name}');
      changedInvoices.add(inv);

      if (status == InvoiceStatus.sent || status == InvoiceStatus.paid) {
        await _deductStockForInvoice(inv);
      } else if (status == InvoiceStatus.cancelled || status == InvoiceStatus.draft) {
        await _restoreStockForInvoice(inv);
      }

      if (status == InvoiceStatus.paid || status == InvoiceStatus.cancelled) {
        ReminderService.cancelForInvoice(id).catchError((_) {});
      } else {
        ReminderService.scheduleForInvoice(inv, _reminderSettings).catchError((_) {});
      }

      changed++;
    }

    if (changed > 0) {
      await _db.invoicesDao.upsertAll(changedInvoices);
      notifyListeners();
      _save().catchError((_) {});
    }
    return changed;
  }

  // ── Credit limit ──────────────────────────────────────────────────

  /// Effective credit limit for [client]: their individual limit takes precedence;
  /// falls back to the global default from the business profile; null if neither is set.
  double? effectiveCreditLimit(Client client) =>
      client.creditLimit ?? _profile.defaultCreditLimit;

  /// Current outstanding balance for [clientId]: sum of amountRemaining on
  /// all non-cancelled, non-quotation, non-credit-note invoices.
  double clientOutstanding(String clientId) => _invoices
      .where((i) =>
          i.client?.id == clientId &&
          !i.isQuotation &&
          !i.isCreditNote &&
          !i.isDeliveryChallan &&
          i.status != InvoiceStatus.cancelled &&
          i.status != InvoiceStatus.paid)
      .fold(0.0, (acc, i) => acc + i.amountRemaining);

  // ── Approval workflow ─────────────────────────────────────────────

  /// Invoices pending manager approval.
  List<Invoice> get pendingApprovalInvoices => _invoices
      .where((i) => i.status == InvoiceStatus.pendingApproval)
      .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  /// Staff submits an invoice for manager review. Sets status to pendingApproval.
  Future<void> submitForApproval(String id) async {
    if (!_hasPermission(AppPermission.sendInvoice)) {
      throw PermissionDeniedException('invoice approval');
    }
    final idx = _invoices.indexWhere((i) => i.id == id);
    if (idx == -1) return;
    _invoices[idx].status = InvoiceStatus.pendingApproval;
    _invoices[idx].approvedBy = null;
    _invoices[idx].approvedAt = null;
    _invoices[idx].approvalNotes = null;
    _invoices[idx].lastEditedBy = _userEmail ?? '';
    _invoices[idx].lastEditedAt = DateTime.now();
    await _db.invoicesDao.upsert(_invoices[idx]);
    _appendOp('submitForApproval', id, _invoices[idx].invoiceNumber);
    notifyListeners();
    _save().catchError((_) {});
  }

  /// Manager approves an invoice. Sets status to sent and fires share sheet.
  Future<void> approveInvoice(String id, {String? notes}) async {
    if (!_hasPermission(AppPermission.approveInvoice)) {
      throw PermissionDeniedException('invoice approval');
    }
    final idx = _invoices.indexWhere((i) => i.id == id);
    if (idx == -1) return;
    _invoices[idx].status = InvoiceStatus.sent;
    _invoices[idx].approvedBy = _userEmail ?? '';
    _invoices[idx].approvedAt = DateTime.now();
    _invoices[idx].approvalNotes = notes;
    _invoices[idx].lastEditedBy = _userEmail ?? '';
    _invoices[idx].lastEditedAt = DateTime.now();
    await _db.invoicesDao.upsert(_invoices[idx]);
    _appendOp('approveInvoice', id, _invoices[idx].invoiceNumber);
    notifyListeners();
    _save().catchError((_) {});
    _deductStockForInvoice(_invoices[idx]);
    ReminderService.scheduleForInvoice(_invoices[idx], _reminderSettings)
        .catchError((_) {});
  }

  /// Manager rejects an invoice. Sets status back to draft with notes.
  Future<void> rejectInvoice(String id, {required String reason}) async {
    if (!_hasPermission(AppPermission.approveInvoice)) {
      throw PermissionDeniedException('invoice approval');
    }
    final idx = _invoices.indexWhere((i) => i.id == id);
    if (idx == -1) return;
    _invoices[idx].status = InvoiceStatus.draft;
    _invoices[idx].approvedBy = _userEmail ?? '';
    _invoices[idx].approvedAt = DateTime.now();
    _invoices[idx].approvalNotes = reason;
    _invoices[idx].lastEditedBy = _userEmail ?? '';
    _invoices[idx].lastEditedAt = DateTime.now();
    await _db.invoicesDao.upsert(_invoices[idx]);
    _appendOp('rejectInvoice', id, _invoices[idx].invoiceNumber);
    notifyListeners();
    _save().catchError((_) {});
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
    await _db.clientsDao.upsert(client);
    _clients = [..._clients, client];
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
    await _db.clientsDao.upsert(client);
    final idx = _clients.indexWhere((c) => c.id == client.id);
    if (idx != -1) {
      _clients[idx] = client;
    } else {
      _clients = [..._clients, client];
    }
    _appendOp('updateClient', client.id, client.displayName);
    notifyListeners();
    _save().catchError((_) {});
  }

  Future<void> deleteClient(String id) async {
    if (!_hasPermission(AppPermission.deleteClient)) {
      throw PermissionDeniedException('clients');
    }
    String label = id;
    try {
      label = _clients.firstWhere((c) => c.id == id).displayName;
    } catch (_) {}
    await _db.clientsDao.deleteById(id);
    _clients = _clients.where((c) => c.id != id).toList();
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

  /// Adds a new item to the catalog.
  Future<ServiceItem> addServiceItem(ServiceItem item) async {
    item.lastEditedAt = DateTime.now();
    await _db.itemsDao.upsert(item);
    _itemsCache = [..._itemsCache, item];
    _appendOp('createServiceItem', item.id, item.name);
    notifyListeners();
    _save().catchError((_) {});
    return item;
  }

  /// Updates a single service item in-place by ID. Used by the inventory screen
  /// for quick quantity adjustments without rebuilding the whole catalog.
  Future<void> updateServiceItem(ServiceItem updated) async {
    final idx = _itemsCache.indexWhere((s) => s.id == updated.id);
    if (idx == -1) return;
    updated.lastEditedAt = DateTime.now();
    await _db.itemsDao.upsert(updated);
    _itemsCache = [..._itemsCache];
    _itemsCache[idx] = updated;
    _appendOp('updateServiceItem', updated.id, updated.name);
    notifyListeners();
    _save().catchError((_) {});
    _checkLowStockAlerts([updated]);
  }

  /// Removes an item from the catalog.
  Future<void> deleteServiceItem(String id) async {
    String label = id;
    try {
      label = _itemsCache.firstWhere((s) => s.id == id).name;
    } catch (_) {}
    await _db.itemsDao.deleteById(id);
    _itemsCache = _itemsCache.where((s) => s.id != id).toList();
    _appendOp('deleteServiceItem', id, label);
    notifyListeners();
    _save().catchError((_) {});
  }

  /// Returns the [ServiceItem] (and matched variant, if any) whose barcode
  /// equals [barcode], via an indexed point lookup — does not require the
  /// full catalog to be loaded in memory.
  Future<ServiceItemMatch?> findByBarcode(String barcode) async {
    if (barcode.isEmpty) return null;
    return _db.itemsDao.findByBarcode(barcode);
  }

  /// One-time migration: moves stock recorded before per-shop tracking
  /// existed (stored under [kLegacyShopKey]) onto this device's own shop.
  Future<void> _migrateLegacyStock() async {
    final myShopId = _shopId;
    if (myShopId == null) return;
    final changedItems = <ServiceItem>[];
    for (final item in _itemsCache) {
      bool changed = false;
      if (item.stockByShop.containsKey(kLegacyShopKey)) {
        final qty = item.stockByShop.remove(kLegacyShopKey)!;
        item.stockByShop[myShopId] = (item.stockByShop[myShopId] ?? 0) + qty;
        changed = true;
      }
      for (final v in item.variants) {
        if (v.stockByShop.containsKey(kLegacyShopKey)) {
          final qty = v.stockByShop.remove(kLegacyShopKey)!;
          v.stockByShop[myShopId] = (v.stockByShop[myShopId] ?? 0) + qty;
          changed = true;
        }
      }
      if (changed) changedItems.add(item);
    }
    if (changedItems.isNotEmpty) {
      for (final item in changedItems) {
        await _db.itemsDao.upsert(item);
      }
      _save().catchError((_) {});
    }
  }

  /// Shops registered for this account, including this device's own shop
  /// (always present, listed first). Synchronous and always up to date.
  List<ShopInfo> get allShops {
    final selfId = _shopId;
    final list = <ShopInfo>[];
    if (selfId != null) {
      final existing = _registeredShops.where((s) => s.shopId == selfId);
      list.add(ShopInfo(
        shopId: selfId,
        shopName: currentShopName,
        lastSeen: existing.isEmpty ? null : existing.first.lastSeen,
      ));
    }
    list.addAll(_registeredShops.where((s) => s.shopId != selfId));
    return list;
  }

  /// Updates the stock on hand for an item or a specific variant, at [shopId].
  /// Adds [qtyReceived] to the current stock on hand for [itemId] (or its
  /// [variantId]) at [shopId] — used when new stock arrives from a supplier.
  Future<void> receiveStock(String itemId, double qtyReceived,
      {String? variantId, required String shopId}) async {
    if (qtyReceived <= 0) return;
    final idx = _itemsCache.indexWhere((s) => s.id == itemId);
    if (idx == -1) return;
    final item = _itemsCache[idx];
    final current = variantId != null
        ? item.variants.firstWhere((v) => v.id == variantId).stockFor(shopId)
        : item.stockFor(shopId);
    await updateItemStock(itemId, current + qtyReceived,
        variantId: variantId, shopId: shopId);
  }

  Future<void> updateItemStock(String itemId, double newQty,
      {String? variantId, required String shopId}) async {
    final idx = _itemsCache.indexWhere((s) => s.id == itemId);
    if (idx == -1) return;
    final item = _itemsCache[idx];
    if (variantId != null) {
      final vi = item.variants.indexWhere((v) => v.id == variantId);
      if (vi == -1) return;
      item.variants[vi].stockByShop[shopId] = newQty;
    } else {
      item.stockByShop[shopId] = newQty;
    }
    item.lastEditedAt = DateTime.now();
    await _db.itemsDao.upsert(item);
    notifyListeners();
    _save().catchError((_) {});
    _checkLowStockAlerts([item]);
  }

  /// Checks [items] for low-stock conditions and fires a push notification the
  /// first time each item (or variant) crosses below its threshold.  Clears the
  /// "already notified" flag when stock recovers so future drops alert again.
  void _checkLowStockAlerts(List<ServiceItem> items) {
    if (!_profile.lowStockAlertsEnabled) return;

    for (final item in items) {
      if (item.hasVariants) {
        for (final v in item.variants) {
          if (!v.isTrackingStock || v.lowStockThreshold == null) continue;
          final key = '${item.id}:${v.id}';
          final low = v.isLowStockFor(_shopId);
          if (low && !_lowStockNotified.contains(key)) {
            _lowStockNotified.add(key);
            ReminderService.notifyLowStock(item, variant: v).catchError((_) {});
          } else if (!low) {
            _lowStockNotified.remove(key);
          }
        }
      } else {
        if (!item.trackStock || item.lowStockThreshold == null) continue;
        final key = '${item.id}:';
        final low = item.isLowStockFor(_shopId);
        if (low && !_lowStockNotified.contains(key)) {
          _lowStockNotified.add(key);
          ReminderService.notifyLowStock(item).catchError((_) {});
        } else if (!low) {
          _lowStockNotified.remove(key);
        }
      }
    }
  }

  // ── Stock transfers ────────────────────────────────────────────────────────

  /// Returns the unique shop ID for this device. Always available after load()
  /// because _shopId is pre-loaded in _loadBusinessData.
  Future<String> getOrCreateShopId() async {
    if (_shopId != null) return _shopId!;
    final prefs = await SharedPreferences.getInstance();
    _shopId = prefs.getString(_kShopIdKey);
    if (_shopId == null) {
      _shopId = _uuid.v4();
      await prefs.setString(_kShopIdKey, _shopId!);
    }
    return _shopId!;
  }

  /// Synchronous getter — valid after load() completes.
  String? get currentShopId => _shopId;

  /// The shop this device is operating as: the employee's paired shop, or the
  /// owner's own shop. Use this to look up per-shop payment method config.
  String? get activeShopId =>
      isEmployeeMode ? (_pairing?.shopId ?? _shopId) : _shopId;

  /// Display name for this device/location. Falls back to business profile name.
  String get currentShopName =>
      (_shopName != null && _shopName!.trim().isNotEmpty)
          ? _shopName!.trim()
          : (_profile.name.trim().isNotEmpty ? _profile.name : 'My Shop');

  /// Saves a custom display name for this device/shop, then re-registers so
  /// other devices see the updated name immediately.
  Future<void> setShopName(String name) async {
    final trimmed = name.trim();
    final prefs = await SharedPreferences.getInstance();
    if (trimmed.isEmpty) {
      await prefs.remove(_kShopNameKey);
      _shopName = null;
    } else {
      await prefs.setString(_kShopNameKey, trimmed);
      _shopName = trimmed;
    }
    notifyListeners();
    await registerShop();
  }

  /// Shop ids whose incoming transfers should be visible to the current
  /// user: the owner (or an employee with [Employee.accessAllShops]) sees
  /// transfers for every registered shop, while a shop-restricted employee
  /// only sees transfers for their own paired shop.
  Set<String> get _visibleShopIds {
    if (isEmployeeMode && !(_activeEmployeeRecord?.accessAllShops ?? false)) {
      final shopId = _pairing?.shopId ?? _shopId;
      return {?shopId};
    }
    return allShops.map((s) => s.shopId).toSet();
  }

  /// Pending transfers destined for any shop visible to the current user
  /// (used directly by UI via watch).
  List<StockTransfer> get incomingTransfers {
    final ids = _visibleShopIds;
    if (ids.isEmpty) return [];
    return _stockTransfers
        .where((t) => ids.contains(t.toShopId) && t.status == TransferStatus.pending)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Registers / updates this device's shop entry in the shared data store.
  Future<void> registerShop() async {
    final shopId = await getOrCreateShopId();
    final shopName = currentShopName;
    final idx = _registeredShops.indexWhere((s) => s.shopId == shopId);
    final entry = ShopInfo(shopId: shopId, shopName: shopName, lastSeen: DateTime.now());
    if (idx == -1) {
      _registeredShops.add(entry);
    } else {
      _registeredShops[idx] = entry;
    }
    await _registeredShopsStore.upsert(entry);
    await _save();
    notifyListeners();
  }

  /// Returns shops registered under this account other than the current device.
  Future<List<ShopInfo>> getLinkedShops() async {
    final shopId = await getOrCreateShopId();
    return _registeredShops.where((s) => s.shopId != shopId).toList();
  }

  /// Pre-registers a new branch/shop entry that isn't tied to a device yet.
  /// The owner can then share access for it to assign employees, or a new
  /// device can later "claim" it during pairing.
  Future<ShopInfo> addShop(String name) async {
    final trimmed = name.trim();
    final entry = ShopInfo(
      shopId: _uuid.v4(),
      shopName: trimmed.isEmpty ? 'New Shop' : trimmed,
    );
    _registeredShops.add(entry);
    await _registeredShopsStore.upsert(entry);
    await _save();
    notifyListeners();
    return entry;
  }

  /// Renames a registered shop entry (owner's own device or a pre-registered branch).
  Future<void> renameShop(String shopId, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final idx = _registeredShops.indexWhere((s) => s.shopId == shopId);
    if (idx == -1) return;
    _registeredShops[idx] = ShopInfo(
      shopId: shopId,
      shopName: trimmed,
      lastSeen: _registeredShops[idx].lastSeen,
    );
    await _registeredShopsStore.upsert(_registeredShops[idx]);
    if (shopId == _shopId) {
      await setShopName(trimmed);
      return;
    }
    await _save();
    notifyListeners();
  }

  /// Removes a pre-registered branch entry that has never been claimed by a device.
  Future<void> removeShop(String shopId) async {
    if (shopId == _shopId) return;
    _registeredShops.removeWhere((s) => s.shopId == shopId);
    await _registeredShopsStore.deleteById(shopId);
    await _save();
    notifyListeners();
  }

  /// Sets the payment method ids shown in Daily Sales "Money Received" for [shopId].
  /// Pass an empty list to reset to the default (all payment methods).
  Future<void> setShopPaymentMethods(
      String shopId, List<String> ids) async {
    final updated = Map<String, List<String>>.from(_profile.shopPaymentMethodIds);
    if (ids.isEmpty) {
      updated.remove(shopId);
    } else {
      updated[shopId] = ids;
    }
    _profile = _profile.copyWith(shopPaymentMethodIds: updated);
    await _save();
    notifyListeners();
  }

  /// History of all transfers from/to any shop visible to the current user.
  Future<List<StockTransfer>> getTransferHistory() async {
    await getOrCreateShopId();
    final ids = _visibleShopIds;
    return (_stockTransfers
        .where((t) => ids.contains(t.fromShopId) || ids.contains(t.toShopId))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt)));
  }

  /// Creates a transfer and immediately deducts stock from this shop.
  Future<void> sendStockTransfer({
    required String toShopId,
    required String toShopName,
    required List<TransferItem> items,
    String? note,
  }) async {
    final shopId = await getOrCreateShopId();
    final shopName = currentShopName;

    final transfer = StockTransfer(
      id: _uuid.v4(),
      ownerEmail: _userEmail ?? '',
      fromShopId: shopId,
      fromShopName: shopName,
      toShopId: toShopId,
      toShopName: toShopName,
      items: items,
      status: TransferStatus.pending,
      createdAt: DateTime.now(),
      note: note,
    );

    _stockTransfers.add(transfer);
    await _stockTransfersStore.upsert(transfer);

    // Deduct stock from this shop immediately
    for (final ti in items) {
      final idx = _itemsCache.indexWhere((s) => s.id == ti.itemId);
      if (idx == -1) continue;
      final item = _itemsCache[idx];
      if (ti.variantId != null) {
        final vi = item.variants.indexWhere((v) => v.id == ti.variantId);
        if (vi == -1) continue;
        final current = item.variants[vi].stockFor(shopId);
        await updateItemStock(ti.itemId,
            (current - ti.quantity).clamp(0, double.infinity),
            variantId: ti.variantId, shopId: shopId);
      } else if (item.isTrackingStock) {
        final current = item.stockFor(shopId);
        await updateItemStock(ti.itemId,
            (current - ti.quantity).clamp(0, double.infinity),
            shopId: shopId);
      }
    }

    await _save();
    notifyListeners();
  }

  /// Accepts an incoming transfer — adds items to this shop's stock.
  Future<void> acceptStockTransfer(StockTransfer transfer) async {
    final idx = _stockTransfers.indexWhere((t) => t.id == transfer.id);
    if (idx != -1) {
      _stockTransfers[idx] = transfer.copyWith(
          status: TransferStatus.accepted, respondedAt: DateTime.now());
      await _stockTransfersStore.upsert(_stockTransfers[idx]);
    }
    final toShopId = transfer.toShopId;
    for (final ti in transfer.items) {
      final idx2 = _itemsCache.indexWhere((s) => s.id == ti.itemId);
      if (idx2 == -1) continue;
      final item = _itemsCache[idx2];
      if (ti.variantId != null) {
        final vi = item.variants.indexWhere((v) => v.id == ti.variantId);
        if (vi == -1) continue;
        final current = item.variants[vi].stockFor(toShopId);
        await updateItemStock(ti.itemId, current + ti.quantity,
            variantId: ti.variantId, shopId: toShopId);
      } else if (item.isTrackingStock) {
        final current = item.stockFor(toShopId);
        await updateItemStock(ti.itemId, current + ti.quantity, shopId: toShopId);
      }
    }
    await _save();
    notifyListeners();
  }

  /// Rejects an incoming transfer (stock stays with sender).
  Future<void> rejectStockTransfer(StockTransfer transfer) async {
    final idx = _stockTransfers.indexWhere((t) => t.id == transfer.id);
    if (idx != -1) {
      _stockTransfers[idx] = transfer.copyWith(
          status: TransferStatus.rejected, respondedAt: DateTime.now());
      await _stockTransfersStore.upsert(_stockTransfers[idx]);
    }
    await _save();
    notifyListeners();
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
    final inserted = <Invoice>[];
    for (final invoice in invoices) {
      if (invoice.client != null) {
        final exists = _clients.any((c) => c.id == invoice.client!.id);
        if (!exists) {
          final client = invoice.client!;
          client.createdBy ??= actor;
          client.lastEditedBy = actor;
          client.lastEditedAt = now;
          await _db.clientsDao.upsert(client);
          _clients = [..._clients, client];
        }
      }
      final idx = _invoices.indexWhere(
          (i) => i.invoiceNumber == invoice.invoiceNumber);
      if (idx == -1) {
        invoice.createdBy ??= actor;
        invoice.lastEditedBy = actor;
        invoice.lastEditedAt = now;
        _invoices.insert(0, invoice);
        inserted.add(invoice);
        _appendOp('createInvoice', invoice.id, invoice.invoiceNumber);
      }
    }
    await _db.invoicesDao.upsertAll(inserted);
    notifyListeners();
    _save().catchError((_) {});
    for (final invoice in invoices) {
      ReminderService.scheduleForInvoice(invoice, _reminderSettings)
          .catchError((_) {});
    }
  }

  /// Imports inventory items from a CSV string.
  /// New items are added; existing items (matched by name, case-insensitive) are updated.
  Future<InventoryImportPreview> bulkImportInventory(String csvContent) async {
    final preview = parseInventoryCsv(
      csvContent,
      existingItems: List.of(_itemsCache),
      shopId: await getOrCreateShopId(),
    );
    if (preview.items.isEmpty) return preview;

    final now = DateTime.now();
    for (final imported in preview.items) {
      imported.lastEditedAt = now;
      final idx = _itemsCache
          .indexWhere((s) => s.name.toLowerCase() == imported.name.toLowerCase());
      await _db.itemsDao.upsert(imported);
      if (idx >= 0) {
        _itemsCache[idx] = imported;
      } else {
        _itemsCache.add(imported);
      }
      _appendOp(idx >= 0 ? 'updateServiceItem' : 'createServiceItem',
          imported.id, imported.name);
    }
    notifyListeners();
    _save().catchError((_) {});
    return preview;
  }

  /// Creates new auto-numbered invoices from [BulkInvoiceSpec] rows.
  /// Invoice numbers are assigned sequentially by [generateInvoiceNumber].
  /// One [notifyListeners] + [_save] fires at the end — not per invoice.
  Future<void> bulkGenerateInvoices({
    required List<BulkInvoiceSpec> specs,
    required DateTime invoiceDate,
    required DateTime dueDate,
    required InvoiceStatus status,
  }) async {
    if (!_hasPermission(AppPermission.createInvoice)) {
      throw PermissionDeniedException('invoices');
    }
    final actor = _userEmail ?? '';
    final now = DateTime.now();
    final generated = <Invoice>[];

    for (final spec in specs) {
      // Reuse an existing client matched by name+email, or create a new one.
      Client existing;
      final emailLower = spec.clientEmail.toLowerCase();
      final nameLower = spec.clientName.toLowerCase();
      final match = _clients.where((c) {
        final nameMatch = c.name.toLowerCase() == nameLower;
        final emailMatch =
            spec.clientEmail.isEmpty || c.email.toLowerCase() == emailLower;
        return nameMatch && emailMatch;
      }).firstOrNull;

      if (match != null) {
        existing = match;
      } else {
        existing = Client(
          id: _uuid.v4(),
          name: spec.clientName,
          email: spec.clientEmail,
          phone: spec.clientPhone,
        );
        _clients.add(existing);
      }

      final invoice = Invoice(
        id: _uuid.v4(),
        invoiceNumber: generateInvoiceNumber(),
        pendingNumber: true,
        invoiceDate: invoiceDate,
        dueDate: dueDate,
        status: status,
        client: existing,
        items: [
          LineItem(
            description: spec.itemDescription,
            rate: spec.amount,
            taxPercent: spec.taxPercent,
          ),
        ],
        notes: spec.notes,
        createdBy: actor,
        lastEditedBy: actor,
        lastEditedAt: now,
      );
      _profile.nextInvoiceNumber++;
      _invoices.insert(0, invoice);
      _appendOp('createInvoice', invoice.id, invoice.invoiceNumber);
      generated.add(invoice);
    }

    if (generated.isNotEmpty) {
      await _db.invoicesDao.upsertAll(generated);
      notifyListeners();
      _save().catchError((_) {});
      for (final inv in generated) {
        if (inv.status != InvoiceStatus.paid &&
            inv.status != InvoiceStatus.cancelled) {
          ReminderService.scheduleForInvoice(inv, _reminderSettings)
              .catchError((_) {});
        }
      }
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
    await _expensesStore.upsert(expense);
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
      await _expensesStore.upsert(expense);
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
    await _expensesStore.deleteById(id);
    _appendOp('deleteExpense', id, label);
    notifyListeners();
    _save().catchError((_) {});
  }

  // ── Daily sales (stock mode) ──────────────────────────────────────────────

  String newDailySaleId() => _uuid.v4();

  Future<void> saveDailySale(DailySale sale) async {
    final idx = _dailySales.indexWhere((d) => d.id == sale.id);
    final DailySale saved;
    if (idx >= 0) {
      saved = sale.copyWith(updatedAt: DateTime.now());
      _dailySales[idx] = saved;
    } else {
      saved = sale;
      _dailySales.insert(0, saved);
    }
    _dailySales.sort((a, b) => b.date.compareTo(a.date));
    await _dailySalesStore.upsert(saved);
    notifyListeners();
    _save().catchError((_) {});
  }

  Future<void> deleteDailySale(String id) async {
    _dailySales.removeWhere((d) => d.id == id);
    await _dailySalesStore.deleteById(id);
    notifyListeners();
    _save().catchError((_) {});
  }

  DailySale? get todaysSale {
    final today = DateTime.now();
    try {
      return _dailySales.firstWhere((d) =>
          d.date.year == today.year &&
          d.date.month == today.month &&
          d.date.day == today.day);
    } catch (_) {
      return null;
    }
  }

  // ── Purchase bills ────────────────────────────────────────────────────────

  String newPurchaseBillId() => _uuid.v4();

  Future<void> addPurchaseBill(PurchaseBill bill) async {
    bill.createdBy ??= _userEmail;
    bill.lastEditedBy = _userEmail;
    bill.lastEditedAt = DateTime.now();
    _purchaseBills.insert(0, bill);
    await _purchaseBillsStore.upsert(bill);
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
      await _purchaseBillsStore.upsert(bill);
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
    await _purchaseBillsStore.deleteById(id);
    _appendOp('deletePurchaseBill', id, label);
    notifyListeners();
    _save().catchError((_) {});
    ReminderService.cancelForBill(id).catchError((_) {});
  }

  // ── Recurring schedules ───────────────────────────────────────────────────

  Future<void> addRecurringSchedule(RecurringSchedule schedule) async {
    _recurringSchedules.insert(0, schedule);
    await _recurringSchedulesStore.upsert(schedule);
    notifyListeners();
    _save().catchError((_) {});
  }

  Future<void> updateRecurringSchedule(RecurringSchedule schedule) async {
    final idx =
        _recurringSchedules.indexWhere((s) => s.id == schedule.id);
    if (idx != -1) {
      _recurringSchedules[idx] = schedule;
      await _recurringSchedulesStore.upsert(schedule);
      notifyListeners();
      _save().catchError((_) {});
    }
  }

  Future<void> deleteRecurringSchedule(String id) async {
    _recurringSchedules.removeWhere((s) => s.id == id);
    await _recurringSchedulesStore.deleteById(id);
    notifyListeners();
    _save().catchError((_) {});
  }

  /// Called on every app start (from [attachDriveAndSync]).  Generates
  /// invoices for any schedule whose [nextGenerationDate] has passed.
  /// Catches up multiple missed periods (e.g. app offline for 3 months
  /// → 3 invoices generated), capped at 24 per schedule per run.
  Future<void> generateDueRecurringInvoices() async {
    final now = DateTime.now();
    bool anyGenerated = false;
    final generated = <Invoice>[];
    final changedSchedules = <RecurringSchedule>[];

    for (final schedule in _recurringSchedules) {
      if (!schedule.isActive) continue;

      // Deactivate expired schedules
      if (schedule.endDate != null && now.isAfter(schedule.endDate!)) {
        schedule.isActive = false;
        anyGenerated = true;
        changedSchedules.add(schedule);
        continue;
      }

      if (!now.isAfter(schedule.nextGenerationDate)) continue;

      // Catch-up loop: generate one invoice per missed period, up to 24.
      int catchUp = 0;
      while (now.isAfter(schedule.nextGenerationDate) && catchUp < 24) {
        // Don't generate past the end date
        if (schedule.endDate != null &&
            schedule.nextGenerationDate.isAfter(schedule.endDate!)) {
          schedule.isActive = false;
          break;
        }

        final invoice =
            _buildInvoiceFromSchedule(schedule, schedule.nextGenerationDate, now);
        _profile.nextInvoiceNumber++;
        _invoices.insert(0, invoice);
        generated.add(invoice);
        _appendOp('createInvoice', invoice.id,
            '${invoice.invoiceNumber} [auto-recurring]');

        schedule.generatedCount++;
        schedule.nextGenerationDate =
            schedule.frequency.nextDate(schedule.nextGenerationDate);
        catchUp++;
        anyGenerated = true;
      }
      if (catchUp > 0 || !schedule.isActive) {
        changedSchedules.add(schedule);
      }
    }

    if (anyGenerated) {
      await _db.invoicesDao.upsertAll(generated);
      await _recurringSchedulesStore.upsertAll(changedSchedules);
      notifyListeners();
      _save().catchError((_) {});
    }
  }

  /// Immediately generates one invoice for [scheduleId] using today as the
  /// invoice date, then advances [nextGenerationDate] if it was in the past.
  Future<void> generateScheduleNow(String scheduleId) async {
    final schedule =
        _recurringSchedules.where((s) => s.id == scheduleId).firstOrNull;
    if (schedule == null) return;

    final now = DateTime.now();
    final invoice = _buildInvoiceFromSchedule(schedule, now, now);
    _profile.nextInvoiceNumber++;
    _invoices.insert(0, invoice);
    await _db.invoicesDao.upsert(invoice);
    _appendOp('createInvoice', invoice.id,
        '${invoice.invoiceNumber} [manual-recurring]');

    schedule.generatedCount++;
    // Advance next date only when it was already overdue
    if (now.isAfter(schedule.nextGenerationDate)) {
      schedule.nextGenerationDate = schedule.frequency.nextDate(now);
    }
    await _recurringSchedulesStore.upsert(schedule);

    notifyListeners();
    _save().catchError((_) {});
  }

  // Shared factory used by both auto-generation and manual generation.
  Invoice _buildInvoiceFromSchedule(
      RecurringSchedule schedule, DateTime invoiceDate, DateTime now) {
    final client =
        _clients.where((c) => c.id == schedule.clientId).firstOrNull;
    return Invoice(
      id: _uuid.v4(),
      invoiceNumber: generateInvoiceNumber(),
      pendingNumber: true,
      invoiceDate: invoiceDate,
      dueDate: invoiceDate.add(Duration(days: schedule.daysTillDue)),
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
  }

  // ── Project & Time Entry helpers ──────────────────────────────────────────

  Future<void> addProject(Project project) async {
    _projects.insert(0, project);
    await _projectsStore.upsert(project);
    notifyListeners();
    _save().catchError((_) {});
  }

  Future<void> updateProject(Project project) async {
    final idx = _projects.indexWhere((p) => p.id == project.id);
    if (idx != -1) {
      _projects[idx] = project;
      await _projectsStore.upsert(project);
      notifyListeners();
      _save().catchError((_) {});
    }
  }

  Future<void> deleteProject(String id) async {
    _projects.removeWhere((p) => p.id == id);
    // Orphaned time entries become unlinked — keep them so history is preserved.
    await _projectsStore.deleteById(id);
    notifyListeners();
    _save().catchError((_) {});
  }

  Future<void> addTimeEntry(TimeEntry entry) async {
    _timeEntries.insert(0, entry);
    await _timeEntriesStore.upsert(entry);
    notifyListeners();
    _save().catchError((_) {});
  }

  Future<void> updateTimeEntry(TimeEntry entry) async {
    final idx = _timeEntries.indexWhere((t) => t.id == entry.id);
    if (idx != -1) {
      _timeEntries[idx] = entry;
      await _timeEntriesStore.upsert(entry);
      notifyListeners();
      _save().catchError((_) {});
    }
  }

  Future<void> deleteTimeEntry(String id) async {
    _timeEntries.removeWhere((t) => t.id == id);
    await _timeEntriesStore.deleteById(id);
    notifyListeners();
    _save().catchError((_) {});
  }

  /// Generates a draft [Invoice] from the given [entries], groups them
  /// according to [grouping], marks each entry as billed, and saves everything.
  ///
  /// Returns the generated invoice so the caller can navigate to it.
  Future<Invoice> generateInvoiceFromTimeEntries({
    required Project project,
    required List<TimeEntry> entries,
    required TimeEntryGrouping grouping,
  }) async {
    if (!_hasPermission(AppPermission.createInvoice)) {
      throw PermissionDeniedException('invoices');
    }
    if (entries.isEmpty) throw ArgumentError('entries must not be empty');

    final List<LineItem> items;
    switch (grouping) {
      case TimeEntryGrouping.byEntry:
        items = entries
            .map((e) => LineItem(
                  description:
                      '${e.memberName} — ${e.description}',
                  quantity: e.hours,
                  rate: e.hourlyRate,
                  unit: 'hr',
                ))
            .toList();
      case TimeEntryGrouping.byMember:
        final byMember = <String, List<TimeEntry>>{};
        for (final e in entries) {
          byMember.putIfAbsent(e.memberName, () => []).add(e);
        }
        items = byMember.entries.map((me) {
          final totalHours = me.value.fold(0.0, (s, t) => s + t.hours);
          // Weighted-average rate across entries for this member.
          final avgRate = me.value.fold(0.0, (s, t) => s + t.hours * t.hourlyRate) /
              totalHours;
          return LineItem(
            description: '${me.key} — Professional Services',
            quantity: totalHours,
            rate: avgRate,
            unit: 'hr',
          );
        }).toList();
      case TimeEntryGrouping.total:
        final totalHours = entries.fold(0.0, (s, e) => s + e.hours);
        final totalAmount = entries.fold(0.0, (s, e) => s + e.billableAmount);
        items = [
          LineItem(
            description: '${project.name} — Professional Services',
            quantity: totalHours,
            rate: totalHours > 0 ? totalAmount / totalHours : 0,
            unit: 'hr',
          ),
        ];
    }

    final client = _clients.where((c) => c.id == project.clientId).firstOrNull;
    final now = DateTime.now();

    final invoice = Invoice(
      id: _uuid.v4(),
      invoiceNumber: generateInvoiceNumber(),
      pendingNumber: true,
      invoiceDate: now,
      dueDate: now.add(const Duration(days: 30)),
      client: client,
      currency: project.currency,
      items: items,
      status: InvoiceStatus.draft,
      createdBy: _userEmail ?? '',
      lastEditedBy: _userEmail ?? '',
      lastEditedAt: now,
    );

    _profile.nextInvoiceNumber++;
    _invoices.insert(0, invoice);
    await _db.invoicesDao.upsert(invoice);
    _appendOp('createInvoice', invoice.id, '${invoice.invoiceNumber} [timesheet]');

    // Mark every entry as billed and link back to the invoice.
    final changedEntries = <TimeEntry>[];
    for (int i = 0; i < _timeEntries.length; i++) {
      if (entries.any((e) => e.id == _timeEntries[i].id)) {
        _timeEntries[i] = _timeEntries[i].copyWith(
          isBilled: true,
          invoiceId: invoice.id,
        );
        changedEntries.add(_timeEntries[i]);
      }
    }
    await _timeEntriesStore.upsertAll(changedEntries);

    notifyListeners();
    _save().catchError((_) {});
    ReminderService.scheduleForInvoice(invoice, _reminderSettings)
        .catchError((_) {});
    return invoice;
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
      quotation.pendingNumber = true;
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
    await _db.invoicesDao.upsert(quotation);
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
      ..pendingNumber = true
      ..invoiceDate = DateTime.now()
      ..dueDate = DateTime.now().add(const Duration(days: 30));
    _profile.nextInvoiceNumber++;
    _invoices.insert(0, invoice);
    await _db.invoicesDao.upsert(invoice);
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
      pendingNumber: true,
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
      ..pendingNumber = true
      ..invoiceDate = DateTime.now()
      ..dueDate = DateTime.now().add(const Duration(days: 30));
    _profile.nextInvoiceNumber++;
    _invoices.insert(0, invoice);
    _invoices[idx].challanLinkedInvoiceId = invoice.id;
    await _db.invoicesDao.upsertAll([invoice, _invoices[idx]]);
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
      pendingNumber: true,
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
    await _db.invoicesDao.upsert(cn);
    _appendOp('createInvoice', cn.id, cn.invoiceNumber);
    notifyListeners();
    _save().catchError((_) {});
    return cn;
  }

  // ── Inventory stock deduction / restoration ───────────────────────────────

  /// Deducts sold quantities from service-item stock when an invoice is
  /// marked as sent or paid. Idempotent — skips if already deducted.
  Future<void> _deductStockForInvoice(Invoice invoice) async {
    if (invoice.isQuotation || invoice.isCreditNote) return;
    if (invoice.stockDeducted) return; // already deducted — avoid double-hit
    final shopKey = invoice.shopId ?? _shopId;
    if (shopKey == null) return;
    final affected = <ServiceItem>[];
    for (final lineItem in invoice.items) {
      final idx = _itemsCache.indexWhere(
          (si) => si.name.toLowerCase() == lineItem.description.toLowerCase());
      if (idx == -1) continue;
      final si = _itemsCache[idx];
      if (si.hasVariants || !si.isTrackingStock) continue;
      final current = si.stockByShop[shopKey] ?? 0;
      si.stockByShop[shopKey] =
          (current - lineItem.quantity).clamp(0, double.infinity);
      si.lastEditedAt = DateTime.now();
      await _db.itemsDao.upsert(si);
      affected.add(si);
    }
    if (affected.isNotEmpty) {
      invoice.stockDeducted = true;
      _save().catchError((_) {});
      // Check after deduction — items may have crossed below threshold.
      _checkLowStockAlerts(affected);
    }
  }

  /// Restores stock quantities when a previously deducted invoice is
  /// cancelled or deleted. Only runs if stock was actually deducted.
  Future<void> _restoreStockForInvoice(Invoice invoice) async {
    if (!invoice.stockDeducted) return;
    final shopKey = invoice.shopId ?? _shopId;
    if (shopKey == null) return;
    bool changed = false;
    for (final lineItem in invoice.items) {
      final idx = _itemsCache.indexWhere(
          (si) => si.name.toLowerCase() == lineItem.description.toLowerCase());
      if (idx == -1) continue;
      final si = _itemsCache[idx];
      if (si.hasVariants || !si.isTrackingStock) continue;
      si.stockByShop[shopKey] = (si.stockByShop[shopKey] ?? 0) + lineItem.quantity;
      si.lastEditedAt = DateTime.now();
      await _db.itemsDao.upsert(si);
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
  /// [shopId] / [shopName] restrict the employee to a single shop.
  /// Pass null for both to grant full access across all shops.
  Future<String> generatePairingQr(String employeeEmail,
      {String? shopId, String? shopName}) async {
    assert(!isEmployeeMode, 'Only an owner can generate a pairing QR');
    if (_drive == null) throw Exception('Drive not connected');
    final keyB64 = _enc.keyBase64;
    if (keyB64 == null) throw Exception('Encryption key not ready');
    final fileId = await _drive!.shareDataFileWith(employeeEmail);
    final pairing = EmployeePairing(
      ownerEmail: _userEmail!,
      fileId: fileId,
      encKey: keyB64,
      shopId: shopId,
      shopName: shopName,
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
    // Switch to the employee-mode Drift database so the paired owner's
    // clients/items don't overwrite this device's own business data.
    await _reopenDb(_dbNameFor(true));
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
    // Wipe the paired owner's data from the employee-mode Drift database
    // before switching away from it, so no stale data lingers if this device
    // pairs with a different owner later.
    await _db.clientsDao.replaceAll([]);
    await _db.itemsDao.replaceAll([]);
    await _db.invoicesDao.replaceAll([]);
    await _expensesStore.replaceAll([]);
    await _purchaseBillsStore.replaceAll([]);
    await _recurringSchedulesStore.replaceAll([]);
    await _projectsStore.replaceAll([]);
    await _timeEntriesStore.replaceAll([]);
    await _dailySalesStore.replaceAll([]);
    await _stockTransfersStore.replaceAll([]);
    await _registeredShopsStore.replaceAll([]);
    _pairing = null;
    _pairingEnc = null;
    await PairingService.clear();
    // Clear any emp_-prefixed cached data.
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('emp_profile_$_kBusinessId');
    await prefs.remove('emp_invoices_$_kBusinessId');
    await prefs.remove('emp_clients_$_kBusinessId');
    // Switch back to this device's own Drift database.
    await _reopenDb(_dbNameFor(false));
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
