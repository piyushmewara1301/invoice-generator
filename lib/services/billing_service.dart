import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../models/subscription_limits.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firestore_subscription_service.dart';

class BillingService with ChangeNotifier {
  static final BillingService _instance = BillingService._internal();

  factory BillingService() {
    return _instance;
  }

  BillingService._internal();

  static const Map<SubscriptionTier, String> googlePlayProductIds = {
    SubscriptionTier.lite:       'com.billbook.subscription.lite.yearly',
    SubscriptionTier.pro:        'com.billbook.subscription.pro.yearly',
    SubscriptionTier.premium:    'com.billbook.subscription.premium.yearly',
    SubscriptionTier.enterprise: 'com.billbook.subscription.enterprise.yearly',
  };

  final InAppPurchase _iap = InAppPurchase.instance;
  bool _available = false;
  List<ProductDetails> _products = [];
  List<PurchaseDetails> _purchases = [];

  bool get isAvailable => _available;
  List<ProductDetails> get products => List.unmodifiable(_products);
  List<PurchaseDetails> get purchases => List.unmodifiable(_purchases);

  StreamSubscription<List<PurchaseDetails>>? _purchaseStream;
  final _purchaseController =
      StreamController<PurchaseDetails>.broadcast();

  Stream<PurchaseDetails> get purchaseStream => _purchaseController.stream;

  /// Initialize IAP and listen to purchase updates
  Future<void> initialize() async {
    if (!Platform.isAndroid) {
      _available = false;
      return;
    }

    _available = await _iap.isAvailable();

    if (_available) {
      await _restorePurchases();
      _listenToPurchaseUpdates();
    }

    notifyListeners();
  }

  /// Listen for purchase updates (both new and restored)
  void _listenToPurchaseUpdates() {
    _purchaseStream = _iap.purchaseStream.listen(
      (purchaseDetailsList) {
        _handlePurchaseUpdates(purchaseDetailsList);
      },
      onError: (error) {
        print('Error in purchase stream: $error');
      },
    );
  }

  /// Handle incoming purchase updates
  void _handlePurchaseUpdates(List<PurchaseDetails> purchaseDetailsList) {
    for (final purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        print('Purchase pending: ${purchaseDetails.productID}');
      } else if (purchaseDetails.status == PurchaseStatus.error) {
        print('Purchase error: ${purchaseDetails.error}');
      } else if (purchaseDetails.status == PurchaseStatus.purchased ||
          purchaseDetails.status == PurchaseStatus.restored) {
        _handleSuccessfulPurchase(purchaseDetails);
      }

      if (purchaseDetails.pendingCompletePurchase) {
        _iap.completePurchase(purchaseDetails);
      }
    }
  }

  /// Handle successful purchase
  Future<void> _handleSuccessfulPurchase(PurchaseDetails purchase) async {
    print('Purchase successful: ${purchase.productID}');
    // Store purchase receipt locally
    await _savePurchaseReceipt(purchase);
    _purchaseController.add(purchase);
    _purchases.add(purchase);
    notifyListeners();
  }

  /// Restore previous purchases on app launch
  Future<void> _restorePurchases() async {
    try {
      await _iap.restorePurchases();
      print('Purchases restored');
    } catch (e) {
      print('Error restoring purchases: $e');
    }
  }

  /// Query available products from Google Play
  Future<void> loadProducts() async {
    if (!_available) return;

    try {
      final productIdSet = googlePlayProductIds.values.toSet();
      final response = await _iap.queryProductDetails(productIdSet);

      _products = response.productDetails;
      notifyListeners();

      if (response.notFoundIDs.isNotEmpty) {
        print('Products not found on Google Play: ${response.notFoundIDs}');
      }
    } catch (e) {
      print('Error loading products: $e');
    }
  }

  /// Get product details for a specific tier
  ProductDetails? getProduct(SubscriptionTier tier) {
    final productId = googlePlayProductIds[tier];
    if (productId == null) return null;

    try {
      return _products.firstWhere((p) => p.id == productId);
    } catch (e) {
      return null;
    }
  }

  /// Initiate purchase for a subscription tier
  Future<void> purchaseSubscription(SubscriptionTier tier) async {
    if (!_available) {
      throw Exception('In-app purchase not available');
    }

    final productId = googlePlayProductIds[tier];
    if (productId == null) {
      throw Exception('Product ID not configured for tier: $tier');
    }

    final product = getProduct(tier);
    if (product == null) {
      throw Exception('Product not found: $productId');
    }

    try {
      // For subscriptions, use buyNonConsumable with PurchaseParam
      final purchaseParam = PurchaseParam(productDetails: product);
      await _iap.buyNonConsumable(purchaseParam: purchaseParam);
      // The stream listener will handle the purchase updates
    } catch (e) {
      print('Error purchasing subscription: $e');
      rethrow;
    }
  }

  /// Check if user has active subscription for a tier
  bool hasActiveSubscription(SubscriptionTier tier) {
    if (tier == SubscriptionTier.free) return true;

    final productId = googlePlayProductIds[tier];
    if (productId == null) return false;

    try {
      return _purchases.any((p) =>
          p.productID == productId &&
          (p.status == PurchaseStatus.purchased ||
              p.status == PurchaseStatus.restored));
    } catch (e) {
      return false;
    }
  }

  /// Get the highest tier user is subscribed to
  SubscriptionTier getHighestSubscribedTier() {
    for (final tier in [
      SubscriptionTier.enterprise,
      SubscriptionTier.premium,
      SubscriptionTier.pro,
      SubscriptionTier.lite,
    ]) {
      if (hasActiveSubscription(tier)) return tier;
    }
    return SubscriptionTier.free;
  }

  /// Save purchase receipt locally for backend validation
  Future<void> _savePurchaseReceipt(PurchaseDetails purchase) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (Platform.isAndroid) {
        final androidDetails = purchase.verificationData;
        await prefs.setString(
          'purchase_receipt_${purchase.productID}',
          androidDetails.serverVerificationData,
        );
        if (purchase.purchaseID != null) {
          await prefs.setString(
            'purchase_token_${purchase.productID}',
            purchase.purchaseID!,
          );
        }
      }
    } catch (e) {
      print('Error saving purchase receipt: $e');
    }
  }

  /// Get saved receipt for backend validation
  Future<String?> getReceiptForBackendValidation(SubscriptionTier tier) async {
    try {
      final productId = googlePlayProductIds[tier];
      if (productId == null) return null;

      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('purchase_receipt_$productId');
    } catch (e) {
      print('Error retrieving receipt: $e');
      return null;
    }
  }

  /// Save subscription with expiry date to Firestore for a specific business.
  Future<void> saveSubscriptionWithExpiry(
    String userId,
    SubscriptionTier tier,
    String businessId,
  ) async {
    try {
      final expiryDate = DateTime.now().add(const Duration(days: 365));
      await FirestoreSubscriptionService().saveSubscription(
        userId,
        businessId,
        tier,
        expiryDate,
      );
    } catch (e) {
      print('Error saving subscription with expiry: $e');
      // Continue even if Firestore fails - use local storage
    }
  }

  /// Cleanup
  @override
  void dispose() {
    _purchaseController.close();
    _purchaseStream?.cancel();
    super.dispose();
  }
}
