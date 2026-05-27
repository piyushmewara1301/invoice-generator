import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
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
      // Firebase must already be initialized before calling this
      _firestore = FirebaseFirestore.instance;
      _initialized = true;
    } catch (e) {
      print('Error initializing Firestore: $e');
    }
  }

  /// Save subscription to Firestore and local cache
  Future<void> saveSubscription(
    String userId,
    SubscriptionTier tier,
    DateTime? expiryDate,
  ) async {
    try {
      if (!_initialized) await initialize();

      if (tier == SubscriptionTier.free) {
        // Free tier: no expiry
        await _firestore.collection('subscriptions').doc(userId).set({
          'uid': userId,
          'tier': _tierToString(tier),
          'expiryDate': null,
          'purchaseDate': FieldValue.serverTimestamp(),
          'status': 'active',
        }, SetOptions(merge: true));
        
        await _saveLocalSubscription(userId, tier, null);
      } else {
        // Paid tier: save with expiry date (1 year from now if not provided)
        final finalExpiryDate = expiryDate ?? DateTime.now().add(const Duration(days: 365));
        
        await _firestore.collection('subscriptions').doc(userId).set({
          'uid': userId,
          'tier': _tierToString(tier),
          'expiryDate': Timestamp.fromDate(finalExpiryDate),
          'purchaseDate': FieldValue.serverTimestamp(),
          'status': 'active',
        }, SetOptions(merge: true));
        
        await _saveLocalSubscription(userId, tier, finalExpiryDate);
      }
    } catch (e) {
      print('Error saving subscription: $e');
      rethrow;
    }
  }

  /// Fetch subscription from Firestore
  Future<Map<String, dynamic>?> fetchSubscriptionStatus(String userId) async {
    try {
      if (!_initialized) await initialize();

      final doc = await _firestore
          .collection('subscriptions')
          .doc(userId)
          .get();

      if (!doc.exists) return null;

      return doc.data();
    } catch (e) {
      print('Error fetching subscription: $e');
      return null;
    }
  }

  /// Check and sync expiry daily. Auto-demote if expired.
  Future<SubscriptionTier> checkAndSyncExpiry(
    String userId,
    SubscriptionTier currentTier,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCheckedStr = prefs.getString('subscription_last_checked_$userId');

      // Check only if > 1 day since last check
      if (lastCheckedStr != null) {
        final lastChecked = DateTime.parse(lastCheckedStr);
        final hoursSinceCheck = DateTime.now().difference(lastChecked).inHours;
        if (hoursSinceCheck < 24) {
          // Use local cache, don't sync
          return _getLocalTier(userId);
        }
      }

      // Fetch from Firestore
      final remoteData = await fetchSubscriptionStatus(userId);
      if (remoteData == null) {
        // No subscription found, set to free
        await _setFreeAndClear(userId, prefs);
        return SubscriptionTier.free;
      }

      final remoteTier = _stringToTier(remoteData['tier'] as String? ?? 'free');
      final remoteExpiryTs = remoteData['expiryDate'] as Timestamp?;
      final remoteExpiryDate = remoteExpiryTs?.toDate();

      // Check if subscription expired
      if (remoteTier != SubscriptionTier.free && remoteExpiryDate != null) {
        if (DateTime.now().isAfter(remoteExpiryDate)) {
          // Subscription expired, demote to free
          await saveSubscription(userId, SubscriptionTier.free, null);
          await _setFreeAndClear(userId, prefs);
          return SubscriptionTier.free;
        }
      }

      // Subscription still valid
      await _saveLocalSubscription(userId, remoteTier, remoteExpiryDate);
      await prefs.setString(
        'subscription_last_checked_$userId',
        DateTime.now().toIso8601String(),
      );

      return remoteTier;
    } catch (e) {
      print('Error in checkAndSyncExpiry: $e');
      // Return local tier on error
      return _getLocalTier(userId);
    }
  }

  /// Check if user can upgrade from current tier to target tier
  bool canUpgradeTo(
    SubscriptionTier currentTier,
    SubscriptionTier targetTier,
  ) {
    // Can't downgrade or stay at same tier
    if (targetTier == currentTier) return false;

    switch (currentTier) {
      case SubscriptionTier.free:
        // Can upgrade to any tier from free
        return true;

      case SubscriptionTier.lite:
        // Can upgrade to Pro or Premium, not back to Free
        return targetTier == SubscriptionTier.pro ||
            targetTier == SubscriptionTier.premium;

      case SubscriptionTier.pro:
        // Can only upgrade to Premium, not downgrade to Lite/Free
        return targetTier == SubscriptionTier.premium;

      case SubscriptionTier.premium:
        // Cannot downgrade from Premium
        return false;
    }
  }

  /// Get local subscription tier
  SubscriptionTier _getLocalTier(String userId) {
    // Note: This is simplified - normally would query SharedPreferences
    // In practice, the app_provider maintains this state
    return SubscriptionTier.free;
  }

  /// Save to local SharedPreferences
  Future<void> _saveLocalSubscription(
    String userId,
    SubscriptionTier tier,
    DateTime? expiryDate,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('subscription_tier_$userId', _tierToString(tier));

    if (expiryDate != null) {
      await prefs.setString(
        'subscription_expiry_$userId',
        expiryDate.toIso8601String(),
      );
    } else {
      await prefs.remove('subscription_expiry_$userId');
    }

    await prefs.setString(
      'subscription_last_checked_$userId',
      DateTime.now().toIso8601String(),
    );
  }

  /// Set to free and clear expiry
  Future<void> _setFreeAndClear(String userId, SharedPreferences prefs) async {
    await prefs.setString('subscription_tier_$userId', 'free');
    await prefs.remove('subscription_expiry_$userId');
    await prefs.setString(
      'subscription_last_checked_$userId',
      DateTime.now().toIso8601String(),
    );
  }

  /// Convert tier to string for Firestore
  String _tierToString(SubscriptionTier tier) {
    return tier.toString().split('.').last;
  }

  /// Convert string to tier
  SubscriptionTier _stringToTier(String tierStr) {
    switch (tierStr.toLowerCase()) {
      case 'lite':
        return SubscriptionTier.lite;
      case 'pro':
        return SubscriptionTier.pro;
      case 'premium':
        return SubscriptionTier.premium;
      default:
        return SubscriptionTier.free;
    }
  }

  /// Get stored expiry date for display
  Future<DateTime?> getExpiryDate(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final expiryStr = prefs.getString('subscription_expiry_$userId');
    if (expiryStr == null) return null;

    try {
      return DateTime.parse(expiryStr);
    } catch (_) {
      return null;
    }
  }
}
