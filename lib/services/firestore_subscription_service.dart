import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/business_profile.dart';

class FirestoreSubscriptionService {
  static final FirestoreSubscriptionService _instance =
      FirestoreSubscriptionService._internal();

  factory FirestoreSubscriptionService() => _instance;
  FirestoreSubscriptionService._internal();

  late FirebaseFirestore _firestore;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      _firestore = FirebaseFirestore.instance;
      _initialized = true;
    } catch (e) {
      print('Error initializing Firestore: $e');
    }
  }

  // ── Key helpers ────────────────────────────────────────────────────────────

  /// Firestore document id for a (user, business) pair.
  String _docId(String userId, String businessId) =>
      '${userId}__$businessId';

  /// SharedPreferences key for the tier cache — shared with AppProvider.
  String _tierKey(String businessId) => 'subscription_tier_v3_$businessId';

  String _expiryKey(String businessId) => 'subscription_expiry_$businessId';

  String _checkedKey(String userId, String businessId) =>
      'subscription_last_checked_${userId}_$businessId';

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Save subscription for a specific business to Firestore and local cache.
  Future<void> saveSubscription(
    String userId,
    String businessId,
    SubscriptionTier tier,
    DateTime? expiryDate,
  ) async {
    try {
      if (!_initialized) await initialize();

      if (tier == SubscriptionTier.free) {
        await _firestore
            .collection('subscriptions')
            .doc(_docId(userId, businessId))
            .set({
          'uid': userId,
          'businessId': businessId,
          'tier': _tierToString(tier),
          'expiryDate': null,
          'purchaseDate': FieldValue.serverTimestamp(),
          'status': 'active',
        }, SetOptions(merge: true));

        await _saveLocalSubscription(userId, businessId, tier, null);
      } else {
        final finalExpiry =
            expiryDate ?? DateTime.now().add(const Duration(days: 365));

        await _firestore
            .collection('subscriptions')
            .doc(_docId(userId, businessId))
            .set({
          'uid': userId,
          'businessId': businessId,
          'tier': _tierToString(tier),
          'expiryDate': Timestamp.fromDate(finalExpiry),
          'purchaseDate': FieldValue.serverTimestamp(),
          'status': 'active',
        }, SetOptions(merge: true));

        await _saveLocalSubscription(userId, businessId, tier, finalExpiry);
      }
    } catch (e) {
      print('Error saving subscription: $e');
      rethrow;
    }
  }

  /// Fetch raw subscription doc for a specific business.
  Future<Map<String, dynamic>?> fetchSubscriptionStatus(
      String userId, String businessId) async {
    try {
      if (!_initialized) await initialize();
      final doc = await _firestore
          .collection('subscriptions')
          .doc(_docId(userId, businessId))
          .get();
      if (!doc.exists) return null;
      return doc.data();
    } catch (e) {
      print('Error fetching subscription: $e');
      return null;
    }
  }

  /// Check and sync expiry for a specific business. Auto-demotes if expired.
  /// Throttled to once per 24 hours per (user, business) pair.
  Future<SubscriptionTier> checkAndSyncExpiry(
    String userId,
    String businessId,
    SubscriptionTier currentTier,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final checkedKey = _checkedKey(userId, businessId);
      final lastCheckedStr = prefs.getString(checkedKey);

      if (lastCheckedStr != null) {
        final lastChecked = DateTime.parse(lastCheckedStr);
        if (DateTime.now().difference(lastChecked).inHours < 24) {
          final cached = prefs.getString(_tierKey(businessId));
          return cached != null ? _stringToTier(cached) : currentTier;
        }
      }

      final remoteData = await fetchSubscriptionStatus(userId, businessId);
      if (remoteData == null) {
        // No Firestore doc yet — trust local tier, don't demote.
        return currentTier;
      }

      final remoteTier = _stringToTier(remoteData['tier'] as String? ?? 'free');
      final remoteExpiryTs = remoteData['expiryDate'] as Timestamp?;
      final remoteExpiry = remoteExpiryTs?.toDate();

      if (remoteTier != SubscriptionTier.free && remoteExpiry != null) {
        if (DateTime.now().isAfter(remoteExpiry)) {
          await saveSubscription(userId, businessId, SubscriptionTier.free, null);
          await _setFreeAndClear(userId, businessId, prefs);
          return SubscriptionTier.free;
        }
      }

      await _saveLocalSubscription(userId, businessId, remoteTier, remoteExpiry);
      await prefs.setString(checkedKey, DateTime.now().toIso8601String());
      return remoteTier;
    } catch (e) {
      print('Error in checkAndSyncExpiry: $e');
      return currentTier;
    }
  }

  /// Whether upgrading from [current] to [target] is a valid transition.
  bool canUpgradeTo(SubscriptionTier currentTier, SubscriptionTier targetTier) {
    if (targetTier == currentTier) return false;
    switch (currentTier) {
      case SubscriptionTier.free:
        return true;
      case SubscriptionTier.lite:
        return targetTier == SubscriptionTier.pro ||
            targetTier == SubscriptionTier.premium;
      case SubscriptionTier.pro:
        return targetTier == SubscriptionTier.premium;
      case SubscriptionTier.premium:
        return false;
    }
  }

  /// Stored expiry date for a specific business.
  Future<DateTime?> getExpiryDate(String userId, String businessId) async {
    final prefs = await SharedPreferences.getInstance();
    final expiryStr = prefs.getString(_expiryKey(businessId));
    if (expiryStr == null) return null;
    try {
      return DateTime.parse(expiryStr);
    } catch (_) {
      return null;
    }
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  Future<void> _saveLocalSubscription(
    String userId,
    String businessId,
    SubscriptionTier tier,
    DateTime? expiryDate,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tierKey(businessId), _tierToString(tier));
    if (expiryDate != null) {
      await prefs.setString(_expiryKey(businessId), expiryDate.toIso8601String());
    } else {
      await prefs.remove(_expiryKey(businessId));
    }
    await prefs.setString(
        _checkedKey(userId, businessId), DateTime.now().toIso8601String());
  }

  Future<void> _setFreeAndClear(
      String userId, String businessId, SharedPreferences prefs) async {
    await prefs.setString(_tierKey(businessId), 'free');
    await prefs.remove(_expiryKey(businessId));
    await prefs.setString(
        _checkedKey(userId, businessId), DateTime.now().toIso8601String());
  }

  String _tierToString(SubscriptionTier tier) =>
      tier.toString().split('.').last;

  SubscriptionTier _stringToTier(String s) {
    switch (s.toLowerCase()) {
      case 'lite':    return SubscriptionTier.lite;
      case 'pro':     return SubscriptionTier.pro;
      case 'premium': return SubscriptionTier.premium;
      default:        return SubscriptionTier.free;
    }
  }
}
