# Quick Start Guide - Google Play Billing Integration

## 🎯 TL;DR - Get Started in 5 Minutes

### 1. Install Dependencies
```bash
flutter pub get
```

### 2. Create Google Play Products
Create 3 subscription products in [Google Play Console](https://play.google.com/console):
- `com.billbook.subscription.lite.yearly` → ₹249/year
- `com.billbook.subscription.pro.yearly` → ₹699/year  
- `com.billbook.subscription.premium.yearly` → ₹1299/year

### 3. Build & Test
```bash
flutter run  # On Android device only
```
Go to Settings → Subscription Plans → Click "Upgrade Now"

---

## 📂 File Structure

```
lib/
├── services/
│   └── billing_service.dart         (← NEW: Handles all IAP operations)
├── providers/
│   └── app_provider.dart            (← UPDATED: Added billing methods)
├── screens/settings/
│   └── plan_screen.dart             (← UPDATED: Added purchase UI)
└── main.dart                        (← UPDATED: Initialize billing)

pubspec.yaml                         (← UPDATED: Added in_app_purchase)
```

---

## 🔌 API Reference

### BillingService
```dart
final billing = BillingService();

// Initialize on app startup
await billing.initialize();

// Load available products from Play Store
await billing.loadProducts();

// Initiate purchase
await billing.purchaseSubscription(SubscriptionTier.pro);

// Check subscription status
bool isPro = billing.hasActiveSubscription(SubscriptionTier.pro);

// Get highest subscription tier
final tier = billing.getHighestSubscribedTier();

// Get receipt for backend validation
final receipt = await billing.getReceiptForBackendValidation(SubscriptionTier.pro);
```

### AppProvider
```dart
final appProvider = context.read<AppProvider>();

// Initialize billing (called in main.dart)
await appProvider.initializeBilling();

// Purchase subscription
await appProvider.purchaseSubscription(SubscriptionTier.pro);

// Check if user has active subscription
bool hasLite = appProvider.hasActiveSubscription(SubscriptionTier.lite);

// Get highest subscribed tier
final tier = appProvider.getHighestSubscribedTier();
```

---

## 🧪 Testing

### Using Test Products
1. In Google Play Console, use test product IDs:
   - `com.billbook.subscription.lite.yearly.test`
   - `com.billbook.subscription.pro.yearly.test`
   - `com.billbook.subscription.premium.yearly.test`

2. Update `billing_service.dart`:
```dart
static const Map<SubscriptionTier, String> googlePlayProductIds = {
  SubscriptionTier.lite: 'com.billbook.subscription.lite.yearly.test',    // Test ID
  SubscriptionTier.pro: 'com.billbook.subscription.pro.yearly.test',
  SubscriptionTier.premium: 'com.billbook.subscription.premium.yearly.test',
};
```

3. Add test account in Google Play Console → Settings → License Testing

### Test Cards
When testing with Google Play, use test cards provided by Google.

---

## 🔐 Product ID Configuration

**File**: `lib/services/billing_service.dart` (Line 17-21)

```dart
static const Map<SubscriptionTier, String> googlePlayProductIds = {
  SubscriptionTier.lite: 'com.billbook.subscription.lite.yearly',
  SubscriptionTier.pro: 'com.billbook.subscription.pro.yearly',
  SubscriptionTier.premium: 'com.billbook.subscription.premium.yearly',
};
```

⚠️ **These must exactly match your Google Play Console product IDs!**

---

## 📊 Subscription Tiers

| Tier | ID | Price | Features |
|------|----|----|----------|
| Free | (N/A) | ₹0 | 5 invoices/mo, 10 clients, 1 template |
| Lite | `lite.yearly` | ₹249/yr | 50 invoices/mo, 50 clients, 3 templates, Drive sync |
| Pro | `pro.yearly` | ₹699/yr | Unlimited invoices, multi-currency, custom prefix |
| Premium | `premium.yearly` | ₹1299/yr | Everything + recurring invoices, 3 profiles, analytics |

---

## 🔄 Purchase Flow

```
User clicks "Upgrade Now"
         ↓
Purchase dialog shows (pricing, terms)
         ↓
User clicks "Subscribe"
         ↓
Google Play dialog opens
         ↓
User completes payment
         ↓
IAP stream receives purchase
         ↓
Receipt saved locally
         ↓
Subscription tier updated
         ↓
Success message shown
```

---

## ⚠️ Common Issues & Solutions

### Products not loading
```
Error: "Products not found on Google Play"
Fix: Verify product IDs match exactly in Play Console & billing_service.dart
     Check products are in "Active" state
     Wait a few hours for new products to propagate
```

### Purchase dialog not showing
```
Error: "In-app purchase not available"
Fix: Ensure testing on Android device (not web/emulator without Play Services)
     Check app is signed with correct signing key
     Verify device is signed into Google Play account
```

### Tier not updating
```
Error: Subscription purchased but tier shows as Free
Fix: Check _handleSuccessfulPurchase() is called
     Verify purchase stream listener is active
     Ensure completePurchase() is called
```

---

## 📱 Android Configuration

Your app is already configured for Android. If needed:

**`android/app/build.gradle.kts`**
```kotlin
android {
    minSdk = 21  // Google Play Billing requires API 21+
    targetSdk = 36
}
```

---

## 🚀 Deployment Checklist

- [ ] Create products in Google Play Console
- [ ] Update product IDs if different from defaults
- [ ] Test on real Android device
- [ ] Test all subscription tiers
- [ ] Test purchase restoration on app restart
- [ ] Test with test products first
- [ ] Verify receipts on backend (optional but recommended)
- [ ] Enable backend validation for production
- [ ] Deploy to Play Store internal testing track
- [ ] Monitor purchase errors in logs
- [ ] Release to production

---

## 📚 For More Details

- **Full Setup Guide**: See `PAYMENT_GATEWAY_SETUP.md`
- **Implementation Summary**: See `BILLING_INTEGRATION_SUMMARY.md`
- **In-App Purchase Docs**: https://pub.dev/packages/in_app_purchase
- **Google Play Billing**: https://developer.android.com/google/play/billing

---

## 🎓 Key Concepts

**In-App Purchase (IAP)**: Google Play mechanism for selling digital goods/subscriptions

**Subscription**: Auto-renewing product billed annually (12 months)

**Product ID**: Unique identifier in Play Console (e.g., `com.billbook.subscription.lite.yearly`)

**Purchase Token**: Google Play's proof of purchase, used for validation

**Receipt**: Encrypted data containing purchase info, validated on backend

**Tier**: Subscription level (Free, Lite, Pro, Premium)

---

## 💬 Questions?

Refer to the detailed guides:
1. **PAYMENT_GATEWAY_SETUP.md** - Complete setup instructions
2. **BILLING_INTEGRATION_SUMMARY.md** - What was implemented and next steps
