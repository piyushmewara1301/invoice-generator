# Troubleshooting Guide - Google Play Billing Integration

## Common Issues & Solutions -

### 🔴 Issue 1: "Products not found on Google Play"

**Error Message**:
```
Print log: "Products not found on Google Play: [com.billbook.subscription.lite.yearly]"
```

**Causes**:
1. Product IDs in Play Console don't match `billing_service.dart`
2. Products are not in "Active" state
3. New products haven't propagated (takes a few hours)
4. Wrong app/project in Play Console

**Solutions**:
1. **Verify product IDs match exactly**:
   - Go to Google Play Console → Your App → Monetize → Subscriptions
   - Copy the exact Product ID
   - Paste into `lib/services/billing_service.dart` line 17-21
   - Check for spaces or typos!

2. **Check product status**:
   - Go to Play Console → Subscriptions
   - Each product should show "Active" status
   - If "Draft", publish the product
   - If "Inactive", reactivate it

3. **Wait for propagation**:
   - New products can take 2-4 hours to become available
   - Try again after a few hours
   - In the meantime, test with test product IDs (add `.test` suffix)

4. **Verify correct app**:
   - Ensure you're in the correct app in Play Console
   - App ID should match your `android/app/build.gradle.kts` → `applicationId`
   - (Currently: `com.example.invoice_genreator`)

**Verification Steps**:
```bash
# Check what the app is trying to load
flutter logs | grep "Products not found"
flutter logs | grep "loading products"
```

---

### 🔴 Issue 2: "In-app purchase not available"

**Error Message**:
```
Exception: In-app purchase not available
```

**Causes**:
1. Running on wrong platform (web/iOS instead of Android)
2. Running on emulator without Google Play Services
3. Device not signed into Google Play account
4. Google Play Services outdated
5. Google Play Billing not enabled for app

**Solutions**:
1. **Test on Android device only**:
   - In-app purchases only work on Android (Google Play)
   - Not supported on: web, iOS, Android emulators
   - Use a real Android phone or tablet

2. **Verify device has Google Play Services**:
   - Go to Settings → Apps → Google Play Services
   - Should be installed and up-to-date
   - If missing/old, go to Play Store and update

3. **Sign in with Google account**:
   - Go to Settings → Accounts
   - Make sure Google account is added
   - The account should have Google Play access
   - (For testing, use your test account)

4. **Check app signing**:
   - Ensure APK is signed with the correct signing key
   - The key used to sign the app in Play Console must match
   - Unsigned or differently-signed APKs won't access IAP

5. **Enable billing in Play Console**:
   - Go to Play Console → Your App → Setup → Billing
   - Ensure billing address is set up
   - Ensure no warnings about billing setup

**Verification Steps**:
```bash
# Check device has Google Play Services
adb shell pm list packages | grep google

# Check if IAP is available
flutter logs | grep "IAP available"
```

---

### 🔴 Issue 3: Products Load But Purchase Button Does Nothing

**Behavior**: 
- Products show correctly
- Click "Upgrade Now"
- Purchase dialog appears
- Click "Subscribe"
- Nothing happens

**Causes**:
1. `buyNonConsumable()` call fails silently
2. No error handling configured
3. Product details are null

**Solutions**:
1. **Check logcat for errors**:
   ```bash
   flutter logs | grep -A5 "Error purchasing"
   ```

2. **Verify product exists**:
   - In `plan_screen.dart`, check that `getProduct(tier)` returns non-null
   - Add debug logs in `_PurchaseDialogState._handlePurchase()`

3. **Check purchase stream listener**:
   - Verify listener in `BillingService._listenToPurchaseUpdates()` is active
   - Check that `_handlePurchaseUpdates()` is being called

4. **Temporarily add debug logging**:
   ```dart
   // In BillingService.purchaseSubscription()
   print('DEBUG: Attempting purchase for tier: $tier');
   print('DEBUG: Product ID: $productId');
   print('DEBUG: Product: $product');
   
   try {
     await _iap.buyNonConsumable(productDetails: product);
     print('DEBUG: Purchase initiated');
   } catch (e) {
     print('DEBUG: Purchase error: $e');
     rethrow;
   }
   ```

---

### 🔴 Issue 4: Purchase Completes But Tier Doesn't Update

**Behavior**:
- Purchase dialog shows success
- Plan screen goes back to "Upgrade Now" buttons
- Tier still shows as "Free"
- Verification status doesn't change

**Causes**:
1. `_handleSuccessfulPurchase()` not being called
2. Purchase stream listener not active
3. `completePurchase()` called before status update
4. Subscription tier not saved to SharedPreferences
5. App cache not cleared

**Solutions**:
1. **Force app restart**:
   - Completely close app
   - Wait 5 seconds
   - Reopen app
   - Check if tier was restored from purchases list
   - This tells you if purchase was actually saved

2. **Add debug logging**:
   ```dart
   // In BillingService._handleSuccessfulPurchase()
   print('DEBUG: Purchase successful for: ${purchase.productID}');
   print('DEBUG: Purchase status: ${purchase.status}');
   print('DEBUG: Saving receipt...');
   await _savePurchaseReceipt(purchase);
   print('DEBUG: Receipt saved');
   ```

3. **Check purchase list**:
   - In `PlanScreen`, add temporary debug widget:
   ```dart
   Text('Active purchases: ${_getActivePurchases().length}')
   ```

4. **Verify stream is listening**:
   - Check that `_listenToPurchaseUpdates()` was called in `initialize()`
   - Confirm no exceptions in stream listener

5. **Clear app cache and retry**:
   ```bash
   flutter clean
   flutter pub get
   flutter run --release
   ```

---

### 🔴 Issue 5: Test Account Keeps Showing "Coming Soon"

**Behavior**:
- Using test account
- Products load
- Purchase completes
- But buttons still show "Coming Soon"

**Causes**:
1. Billing service not initialized
2. `initializeBilling()` not called in `main.dart`
3. Purchase stream not active
4. Purchase not being recognized

**Solutions**:
1. **Verify billing initialization in main.dart**:
   ```dart
   // Should be in main() function:
   if (!kIsWeb) await BillingService().initialize();
   ```

2. **Add debug logging in main.dart**:
   ```dart
   print('DEBUG: Initializing billing service...');
   if (!kIsWeb) {
     await BillingService().initialize();
     print('DEBUG: Billing initialized');
   }
   ```

3. **Check app lifecycle**:
   - Billing should initialize once during app startup
   - Not on every screen navigation
   - If app is hot-reloaded, billing state might be lost

4. **Force full app rebuild**:
   ```bash
   flutter clean
   flutter run
   ```

---

### 🔴 Issue 6: Purchases Restored But Tier Shows as Free

**Behavior**:
- User had paid subscription last month
- Reinstalled app
- Purchase restored (shows in logs)
- But subscription tier shows as Free
- Features still locked

**Causes**:
1. Subscription expired (yearly billing)
2. User's subscription cancelled
3. `getHighestSubscribedTier()` logic issue
4. AppProvider not syncing with BillingService

**Solutions**:
1. **Check subscription status in Play Store**:
   - On device: Go to Play Store → Account → Subscriptions
   - Verify subscription is still "Active"
   - Not "Cancelled" or "Expired"

2. **Verify expiry date**:
   - Yearly subscriptions renew every 12 months
   - If purchase was >12 months ago, it may have expired
   - Check billing date in Play Store

3. **Test restoration logic**:
   - In `BillingService.getHighestSubscribedTier()`:
   ```dart
   print('DEBUG: Checking tier for premium: ${hasActiveSubscription(SubscriptionTier.premium)}');
   print('DEBUG: Checking tier for pro: ${hasActiveSubscription(SubscriptionTier.pro)}');
   print('DEBUG: Checking tier for lite: ${hasActiveSubscription(SubscriptionTier.lite)}');
   print('DEBUG: Final tier: ${getHighestSubscribedTier()}');
   ```

4. **Sync AppProvider after restore**:
   - In `AppProvider.load()`, call:
   ```dart
   // After loading local data
   final billing = BillingService();
   final syncedTier = billing.getHighestSubscribedTier();
   if (syncedTier != _profile.subscriptionTier) {
     _profile.subscriptionTier = syncedTier;
     await _saveLocal();
   }
   ```

---

### 🔴 Issue 7: Google Play Dialog Won't Open

**Behavior**:
- Click "Subscribe" button
- Loading spinner shows
- Nothing happens for 30 seconds
- Times out or shows error

**Causes**:
1. Google Play Services not running
2. Product details are null
3. Network connectivity issue
4. Device not signed into Play Store
5. Authorization issue

**Solutions**:
1. **Verify Google Play Services running**:
   ```bash
   adb shell pm list packages | grep "com.android.vending"
   adb shell pm list packages | grep "com.google.android.gms"
   ```

2. **Check device is signed in**:
   - Go to Play Store app
   - Click profile icon → Account
   - Should show your Google account
   - If not, sign in first

3. **Test network connectivity**:
   - Open any Play Store page
   - If that works, network is fine
   - If not, connect to WiFi/mobile data

4. **Check product details before purchase**:
   ```dart
   // In _PurchaseDialogState.build()
   print('DEBUG: Product details: $product');
   if (product == null) {
     return AlertDialog(
       title: Text('Error'),
       content: Text('Product not found'),
     );
   }
   ```

5. **Add timeout handling**:
   ```dart
   Future<void> _handlePurchase() async {
     try {
       final appProvider = context.read<AppProvider>();
       await appProvider.purchaseSubscription(widget.tier)
         .timeout(const Duration(minutes: 2), onTimeout: () {
           throw Exception('Purchase timed out');
         });
     } catch (e) {
       setState(() => _error = 'Error: $e');
     }
   }
   ```

---

### 🟡 Issue 8: Test Mode Purchases Working But Production Doesn't

**Behavior**:
- Purchase works with `.test` product IDs
- After removing `.test` suffix
- Same error occurs

**Likely Causes**:
1. Production product IDs don't exist or aren't Active
2. Differences between test and production setups
3. Build not properly updated

**Solutions**:
1. **Verify production products exist**:
   - Go to Play Console → Subscriptions
   - Make sure non-test products exist
   - All should be "Active"

2. **Clear app data before testing**:
   ```bash
   adb shell pm clear com.example.invoice_genreator
   flutter run
   ```

3. **Rebuild APK completely**:
   ```bash
   flutter clean
   flutter pub get
   flutter build apk --release
   adb install -r build/app/outputs/flutter-apk/app-release.apk
   ```

4. **Double-check product IDs**:
   - Manually type product IDs from Play Console
   - Don't copy-paste to avoid invisible characters
   - Verify exact match:
   ```dart
   // Before (test)
   SubscriptionTier.lite: 'com.billbook.subscription.lite.yearly.test',
   // After (production)
   SubscriptionTier.lite: 'com.billbook.subscription.lite.yearly',
   ```

---

## 📊 Debug Checklist

When troubleshooting, check in order:

1. **Check logs**:
   ```bash
   flutter logs
   flutter logs | grep -i "billing\|purchase\|iap"
   ```

2. **Verify device**:
   - Real Android device (not emulator)
   - Google Play Services installed
   - Signed into Google account

3. **Verify Play Console**:
   - Correct app selected
   - Products exist and are Active
   - Product IDs match code exactly

4. **Verify code**:
   - Product IDs in `billing_service.dart`
   - `initializeBilling()` called in `main.dart`
   - No syntax errors in modified files

5. **Test with test products**:
   - Always start with `.test` products
   - These don't charge money
   - Good for validating setup

6. **Clear everything and retry**:
   ```bash
   flutter clean
   adb shell pm clear com.example.invoice_genreator
   flutter pub get
   flutter run --release
   ```

---

## 📞 Still Need Help?

1. Check the other documentation files:
   - `PAYMENT_GATEWAY_SETUP.md` - Full setup guide
   - `BILLING_INTEGRATION_SUMMARY.md` - Implementation details
   - `QUICK_START_BILLING.md` - Quick reference

2. Review the code:
   - `lib/services/billing_service.dart` - Main implementation
   - `lib/screens/settings/plan_screen.dart` - UI code
   - Check inline comments for explanations

3. Check official docs:
   - [Google Play Billing Docs](https://developer.android.com/google/play/billing)
   - [In-App Purchase Package](https://pub.dev/packages/in_app_purchase)
   - [Flutter Monetization Docs](https://docs.flutter.dev/monetization/in-app-purchases)

---

**Remember**: Always test with test products first! They don't charge money and let you validate your setup safely.
