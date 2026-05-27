# Google AdMob Setup Guide - BillBook App

## Overview

Your app already has **complete Google AdMob integration** implemented with:
- ✅ Banner ads on dashboard (free tier only)
- ✅ Interstitial ads after every 3rd invoice save (free tier only)
- ✅ Rewarded ads infrastructure ready
- ✅ Automatic tier-based ad gating (no ads for paid plans)

This guide explains how to **enable real ads** for production.

---

## Current Status

### ✅ What's Already Implemented

**Ad Types:**
- Banner ads (bottom of dashboard)
- Interstitial ads (after saving invoices)
- Rewarded ads (ready to use)

**Ad Gating:**
- Ads only show for Free tier users
- Paid subscribers (Lite, Pro, Premium) see no ads
- Web version has no ads

**Ad Service:**
- Location: `lib/services/ad_service.dart`
- Singleton pattern for app-wide access
- Preloading for faster display
- Error handling for failed ad loads

**Current Setup:**
- Using Google test ad unit IDs (safe for development)
- Fully functional - ready for testing
- Just need to replace with your real AdMob IDs

---

## Step-by-Step Setup

### Step 1: Create Google AdMob Account

1. Go to [Google AdMob](https://admob.google.com)
2. Sign in with your Google account
3. Click "Create an AdMob account"
4. Accept the AdMob policies
5. Fill in your app information:
   - **App name:** BillBook or Invoice Generator
   - **App type:** Android
   - **App category:** Business or Productivity

### Step 2: Register Your App

1. In AdMob dashboard, click "Apps" → "Add app"
2. Select "Android"
3. Enter app details:
   - **App name:** BillBook
   - **Google Play Store ID:** Your app's package ID (currently: `com.example.invoice_genreator`)
4. Click "Create"

### Step 3: Get Your AdMob App ID

After registering your app, you'll get:
- **AdMob App ID** (looks like: `ca-app-pub-xxxxxxxxxxxxxxxx`)
- Save this - you'll need it in AndroidManifest.xml

### Step 4: Create Ad Units

In your AdMob app, create 3 ad units:

#### 4A. Banner Ad Unit
1. Click "Ad units" → "Create new ad unit"
2. **Name:** Banner - Dashboard
3. **Ad type:** Banner
4. **Size:** Smart banner (320x50)
5. Create and copy the **Ad unit ID** (looks like: `ca-app-pub-3940256099942544/6300978111`)

#### 4B. Interstitial Ad Unit
1. Click "Create new ad unit"
2. **Name:** Interstitial - Invoice Save
3. **Ad type:** Interstitial (full screen)
4. Create and copy the **Ad unit ID**

#### 4C. Rewarded Ad Unit
1. Click "Create new ad unit"
2. **Name:** Rewarded - Premium Feature
3. **Ad type:** Rewarded
4. Create and copy the **Ad unit ID**

---

## Implementation

### Step 5: Update Ad Service with Your IDs

**File:** `lib/services/ad_service.dart` (lines 13-15)

Replace the test IDs with your real IDs:

```dart
// BEFORE (Test IDs):
static const _bannerId     = 'ca-app-pub-3940256099942544/6300978111';
static const _interstitialId = 'ca-app-pub-3940256099942544/1033173712';
static const _rewardedId   = 'ca-app-pub-3940256099942544/5224354917';

// AFTER (Your Real IDs):
static const _bannerId     = 'ca-app-pub-xxxxxxxxxxxxxxxx/xxxxxxxxxx';  // Your banner ID
static const _interstitialId = 'ca-app-pub-xxxxxxxxxxxxxxxx/xxxxxxxxxx';  // Your interstitial ID
static const _rewardedId   = 'ca-app-pub-xxxxxxxxxxxxxxxx/xxxxxxxxxx';  // Your rewarded ID
```

### Step 6: Update AndroidManifest.xml

**File:** `android/app/src/main/AndroidManifest.xml`

Add your AdMob App ID inside the `<application>` tag:

```xml
<application>
    <!-- Existing metadata... -->
    
    <!-- Add this (replace with your AdMob App ID) -->
    <meta-data
        android:name="com.google.android.gms.ads.APPLICATION_ID"
        android:value="ca-app-pub-xxxxxxxxxxxxxxxx~zzzzzzzzzz"/>
    
    <!-- Rest of application... -->
</application>
```

### Step 7: Update Application ID (if needed)

If your app ID is different from `com.example.invoice_genreator`:

1. **Update in AdMob:** Make sure registered app ID matches your actual app ID
2. **Update in code:** Change in `android/app/build.gradle.kts`:
   ```kotlin
   applicationId = "com.your.actual.package.name"
   ```

---

## Testing with Test IDs

### Keep Test IDs During Development

The current test IDs work perfectly for testing. You can continue developing and testing with them:

```dart
// Current test IDs (safe for development):
static const _bannerId     = 'ca-app-pub-3940256099942544/6300978111';
static const _interstitialId = 'ca-app-pub-3940256099942544/1033173712';
static const _rewardedId   = 'ca-app-pub-3940256099942544/5224354917';
```

**Benefits:**
- Google explicitly allows these for testing
- Won't get your AdMob account suspended
- Show realistic-looking ads
- Great for UI/UX testing

### When to Switch to Real IDs

**Switch to your real IDs when:**
- [ ] You've thoroughly tested ad display
- [ ] You're ready to generate revenue
- [ ] You're preparing for Play Store release
- [ ] You have paying users

---

## Ad Display Reference

### Where Ads Show

**Banner Ads:**
- Location: Dashboard screen bottom
- Frequency: Always visible (free tier)
- When: When user navigates to dashboard

**Interstitial Ads:**
- Location: Full screen overlay
- Frequency: After every 3rd invoice save
- When: User saves an invoice and reaches the threshold
- User can close: Yes (after 3-5 seconds)

**Rewarded Ads:**
- Location: Optional trigger points
- Frequency: On demand
- When: You add a rewarded ad trigger
- User must watch to completion for reward

### Ad Gating (Tier-based)

```dart
// Only Free tier users see ads
if (isFreeTier) {
    const BannerAdWidget(),  // Show banner
}

// Paid tier users (Lite, Pro, Premium) see no ads
if (tier == SubscriptionTier.free) {
    AdService.instance.onInvoiceSaved(
        isFreeTier: true,  // Show interstitial
    );
}
```

---

## Build and Deploy

### Step 8: Build APK

```bash
flutter clean
flutter pub get
flutter build apk --release
```

### Step 9: Test on Device

1. Install APK on Android device
2. Navigate to dashboard - banner ad should appear
3. Save 3 invoices - interstitial should appear after 3rd save
4. Verify no ads show for paid tier users (if you have test subscription)

### Step 10: Deploy to Play Store

1. Go to Google Play Console
2. Upload your APK to internal testing first
3. Add your real AdMob IDs to the code
4. Test thoroughly with real ads
5. Roll out to production

---

## Important Notes

⚠️ **CRITICAL: Use Test IDs During Development**
- Never use real IDs while developing
- Google will suspend accounts for "invalid traffic"
- Invalid traffic = clicking your own ads, fake impressions, etc.

✅ **Best Practice:**
- Keep test IDs until you're 100% ready to go live
- Only switch when deploying to production
- Add a build flavor to automatically use correct IDs:

```dart
// Option: Use different IDs per flavor
const isProduction = bool.fromEnvironment('production');

static const _bannerId = isProduction 
    ? 'ca-app-pub-REAL/REAL'
    : 'ca-app-pub-3940256099942544/6300978111';
```

---

## Ad Customization

### Change Interstitial Frequency

**File:** `lib/services/ad_service.dart` (line 18)

```dart
// Current: Show every 3rd save
static const _interstitialEvery = 3;

// Change to show every 5th save:
static const _interstitialEvery = 5;

// Change to show every 2nd save:
static const _interstitialEvery = 2;
```

### Add More Ad Placements

To add ads in other screens:

1. **Add to AppProvider for tier checking:**
```dart
bool isFreeTier = profile.subscriptionTier == SubscriptionTier.free;
```

2. **Add BannerAdWidget to screen:**
```dart
if (isFreeTier) const BannerAdWidget(),
```

3. **Trigger interstitial on action:**
```dart
AdService.instance.onInvoiceSaved(isFreeTier: isFreeTier);
```

### Add Rewarded Ad Feature

Example: Unlock premium feature by watching ad

```dart
// Check if rewarded ad is ready
if (AdService.instance.rewardedReady) {
    // Show button to unlock via ad
    AdService.instance.showRewarded(
        onRewarded: () {
            // User watched full ad - grant reward
            // e.g., temporary premium feature access
        },
    );
}
```

---

## Monetization Strategy

### Recommended Setup

**Free Tier Users:**
- ✅ Banner ads on all screens
- ✅ Interstitial after actions
- ✅ Rewarded ads for premium features

**Paid Tier Users (Lite, Pro, Premium):**
- ✅ NO banner ads
- ✅ NO interstitial ads
- ✅ NO ad interruptions

**Revenue Model:**
- Free users see ads → Generate impressions
- Paid users get ad-free experience → Incentive to upgrade
- Win-win for both user segments

---

## Monitoring and Analytics

### View Ad Performance

1. Go to [Google AdMob Dashboard](https://admob.google.com)
2. Click your app
3. View metrics:
   - Impressions (number of times ads shown)
   - Clicks (number of ad clicks)
   - CTR (click-through rate)
   - Earnings

### Estimated Earnings

AdMob pays based on:
- **CPM** (Cost Per Mille): ₹20-100 per 1000 impressions in India
- **CPC** (Cost Per Click): ₹2-10 per click
- **CTR** (Click-through rate): Usually 1-5%

**Example with 10,000 free users:**
- 10,000 impressions/day (if active)
- ₹30 CPM average (India)
- ~₹300/day (~₹9,000/month)

*Actual earnings vary by region, user behavior, and ad quality*

---

## Troubleshooting

### Ads Not Showing?

**Check 1: Verify Test IDs**
- If using test IDs, ads should show
- If using real IDs too early, Google may block them
- Check `ad_service.dart` for correct IDs

**Check 2: Check Ad Display Logic**
- Verify `isFreeTier` is true
- Check that tier is not "lite", "pro", or "premium"
- Look at logcat for ad load errors

**Check 3: Check AdMob Registration**
- Verify app is registered in AdMob
- Verify app ID in AndroidManifest.xml is correct
- Wait a few hours for AdMob to activate new ad units

**Check 4: Look at Logs**
```bash
flutter logs | grep -i "ad\|admob\|google"
```

### Invalid Traffic Warning?

If Google warns about invalid traffic:
- Stop clicking your own ads
- Remove from test devices if needed
- Don't artificially inflate impressions
- Only use real IDs after app is in production

### Very Low Earnings?

- Your region may have lower CPM rates
- Increase free user base
- Ensure ads are actually displaying
- Improve CTR with better placements

---

## Security & Compliance

✅ **Privacy:**
- Google AdMob handles user privacy
- Complies with GDPR, CCPA
- No additional privacy implementation needed

✅ **Ad Policies:**
- Don't click your own ads
- Don't incentivize clicks
- Don't hide ad attribution
- Ensure ads are actually from Google AdMob

✅ **User Experience:**
- Never force ads on users
- Provide ad-free option (paid subscription)
- Show ads at natural breakpoints
- Not during critical actions

---

## Next Steps

### Immediate (Today)
1. [ ] Create AdMob account
2. [ ] Register your app
3. [ ] Create 3 ad units
4. [ ] Get your ad unit IDs
5. [ ] Get your AdMob App ID

### This Week
1. [ ] Update `ad_service.dart` with your IDs
2. [ ] Update AndroidManifest.xml with App ID
3. [ ] Build APK and test
4. [ ] Verify ads display correctly
5. [ ] Test interstitial timing

### Before Production
1. [ ] Test with real IDs on internal track
2. [ ] Monitor for invalid traffic warnings
3. [ ] Check earnings in AdMob dashboard
4. [ ] Deploy to production
5. [ ] Monitor performance

---

## Reference

### Files to Modify
- `lib/services/ad_service.dart` - Ad unit IDs (lines 13-15)
- `android/app/src/main/AndroidManifest.xml` - AdMob App ID
- `android/app/build.gradle.kts` - Application ID (if needed)

### Key Classes
- `AdService` - Manages all ads
- `BannerAdWidget` - Displays banner ads
- `SubscriptionTier` - Used for ad gating

### Ad Unit Types
- **Banner** - Small (320x50) ads at bottom
- **Interstitial** - Full-screen ads between actions
- **Rewarded** - Full-screen ads for opt-in rewards

---

## Support

For AdMob help:
- [Google AdMob Documentation](https://support.google.com/admob)
- [Google Mobile Ads SDK](https://pub.dev/packages/google_mobile_ads)
- [AdMob Best Practices](https://support.google.com/admob/answer/6128738)

For implementation questions:
- Check `ad_service.dart` for code structure
- Check `banner_ad_widget.dart` for UI integration
- Review where `onInvoiceSaved()` is called

---

**Status:** ✅ Implementation Complete - Ready to Enable Real Ads  
**Next:** Create AdMob account and get your ad unit IDs  
**Time:** 30-45 minutes to fully set up
