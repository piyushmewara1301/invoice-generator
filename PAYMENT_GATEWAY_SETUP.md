# Google Play Billing Integration Setup Guide

## Overview
This guide explains how to configure and test the Google Play Billing integration for subscription payments in the BillBook invoice generator app.

## What's Been Implemented

### 1. **Billing Service** (`lib/services/billing_service.dart`)
- Handles all Google Play In-App Purchase operations
- Manages subscription lifecycle (purchase, restore, validation)
- Stores purchase receipts locally for backend verification
- Provides methods to check subscription status

### 2. **AppProvider Integration** (`lib/providers/app_provider.dart`)
- Added `initializeBilling()` - Initialize billing service on app launch
- Added `purchaseSubscription(tier)` - Trigger purchase flow
- Added `hasActiveSubscription(tier)` - Check if user has active subscription
- Added `getHighestSubscribedTier()` - Get user's current subscription level

### 3. **Updated UI** (`lib/screens/settings/plan_screen.dart`)
- Replaced "Coming Soon" buttons with functional "Upgrade Now" buttons
- Added purchase dialog with pricing information
- Shows loading state during purchase
- Displays error messages if purchase fails
- Updated billing note to indicate purchases are now live

### 4. **Subscription Tiers**
- **Lite**: ₹249/year (₹29/month equivalent)
- **Pro**: ₹699/year (₹79/month equivalent)
- **Premium**: ₹1299/year (₹149/month equivalent)

## Setup Instructions

### Step 1: Add Dependency (Already Done)
The `in_app_purchase` package is already added to `pubspec.yaml`. Run:
```bash
flutter pub get
```

### Step 2: Configure Google Play Store Product IDs
In `lib/services/billing_service.dart`, update the product IDs to match your Google Play Store configuration:

```dart
static const Map<SubscriptionTier, String> googlePlayProductIds = {
  SubscriptionTier.lite: 'com.billbook.subscription.lite.yearly',      // Change to your product ID
  SubscriptionTier.pro: 'com.billbook.subscription.pro.yearly',        // Change to your product ID
  SubscriptionTier.premium: 'com.billbook.subscription.premium.yearly', // Change to your product ID
};
```

### Step 3: Create Google Play Store Products
1. Go to [Google Play Console](https://play.google.com/console)
2. Select your BillBook app
3. Navigate to **Monetize → Subscriptions**
4. Create 3 subscription products with these IDs:
   - `com.billbook.subscription.lite.yearly`
   - `com.billbook.subscription.pro.yearly`
   - `com.billbook.subscription.premium.yearly`
5. Set prices to match (₹249, ₹699, ₹1299)
6. Set billing period to **Yearly** (12 months)

### Step 4: Configure Android Build
The app already has Android support. Ensure your `android/app/build.gradle.kts` includes:
```kotlin
minSdk = 21  // Google Play Billing requires API 21+
```

### Step 5: Update Application ID (if needed)
If your app ID is different from `com.example.invoice_genreator`, update:
- `android/app/build.gradle.kts` → `applicationId`
- `AndroidManifest.xml` → `package` attribute
- Product IDs in `billing_service.dart`

### Step 6: Initialize Billing in App Launch
Update `lib/main.dart` to initialize billing after app provider is ready:

```dart
// In main() function, after AppProvider is created:
if (!kIsWeb) {
  await appProvider.initializeBilling();
}
```

### Step 7: Handle Purchase Updates (Optional Backend)
For production, you should validate receipts on your backend:
1. Retrieve receipt with: `await billing.getReceiptForBackendValidation(tier)`
2. Send to Google Play API for verification
3. Store verified subscription in your database

## Testing

### Test with Test Products
1. In Google Play Console, create test subscriptions (same IDs with `.test` suffix)
2. Use test product IDs in development build
3. Add test accounts in **Settings → License Testing**

### Manual Testing Steps
1. Build and run the app on Android device
2. Go to **Settings → Subscription Plans**
3. Click "Upgrade Now" on any plan
4. Verify purchase dialog appears
5. Click "Subscribe" to begin purchase flow
6. Complete payment (use test cards in test mode)
7. Verify subscription tier changes after successful purchase

### Common Issues

**Issue**: "Products not found on Google Play"
- **Solution**: Verify product IDs match exactly in Play Console and `billing_service.dart`

**Issue**: "In-app purchase not available"
- **Solution**: Ensure you're testing on Android device (not web), and app is signed with Google Play signing key

**Issue**: Purchases complete but tier doesn't update
- **Solution**: Check that `_handleSuccessfulPurchase()` is being called in the purchase stream listener

## Product ID Mapping

Create these products in Google Play Console:

| Tier | Product ID | Price | Period |
|------|-----------|-------|--------|
| Lite | `com.billbook.subscription.lite.yearly` | ₹249 | 1 Year |
| Pro | `com.billbook.subscription.pro.yearly` | ₹699 | 1 Year |
| Premium | `com.billbook.subscription.premium.yearly` | ₹1299 | 1 Year |

## Receipt Validation (Backend)

For production security, validate receipts server-side:

```bash
# Verify receipt with Google Play API
curl -X POST https://androidpublisher.googleapis.com/androidpublisher/v3/applications/{packageName}/purchases/subscriptions/{subscriptionId}/tokens/{purchaseToken}/acknowledge \
  -H "Authorization: Bearer {access_token}"
```

## Next Steps

1. **Run** `flutter pub get` to install the `in_app_purchase` package
2. **Create** product IDs in Google Play Console
3. **Update** product IDs in `billing_service.dart`
4. **Add** billing initialization to `main.dart`
5. **Test** with test products before going live
6. **Deploy** to Play Store internal testing track
7. **Validate** receipts on backend (recommended)

## References

- [In-App Purchase Package](https://pub.dev/packages/in_app_purchase)
- [Google Play Billing Docs](https://developer.android.com/google/play/billing/integrate)
- [Flutter In-App Purchase Guide](https://docs.flutter.dev/monetization/in-app-purchases)
- [Google Play Console](https://play.google.com/console)

## Support

For issues with billing implementation:
1. Check `BillingService.printDebug()` logs
2. Verify product IDs in Play Console
3. Ensure app is signed with correct signing key
4. Test with Google Play test products first
