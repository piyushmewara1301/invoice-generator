# Quick Ads Setup - 5 Minute Guide

## You Already Have Ads! 🎉

Your app has **complete Google AdMob integration**:
- ✅ Banner ads (dashboard)
- ✅ Interstitial ads (after saves)
- ✅ Rewarded ads (ready to use)
- ✅ Tier-based gating (free only)

Currently using **Google's test IDs** (safe for development).

---

## 3 Steps to Enable Real Ads

### Step 1: Create AdMob Account (10 min)
1. Go to https://admob.google.com
2. Create account
3. Register your Android app
4. Create 3 ad units:
   - Banner ad
   - Interstitial ad
   - Rewarded ad

### Step 2: Get Your Ad IDs (5 min)
Copy your 3 ad unit IDs from AdMob dashboard:
```
Banner ID:        ca-app-pub-xxxxxxxx/xxxxxxxx
Interstitial ID:  ca-app-pub-xxxxxxxx/xxxxxxxx
Rewarded ID:      ca-app-pub-xxxxxxxx/xxxxxxxx
```

Also get:
```
AdMob App ID: ca-app-pub-xxxxxxxx~xxxxxxxxxx
```

### Step 3: Update Your Code (5 min)

**File 1:** `lib/services/ad_service.dart` (lines 13-15)
```dart
static const _bannerId     = 'YOUR_BANNER_ID_HERE';
static const _interstitialId = 'YOUR_INTERSTITIAL_ID_HERE';
static const _rewardedId   = 'YOUR_REWARDED_ID_HERE';
```

**File 2:** `android/app/src/main/AndroidManifest.xml`

Add inside `<application>` tag:
```xml
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="YOUR_ADMOB_APP_ID"/>
```

---

## Done! ✅

Build and test:
```bash
flutter run
```

**Banner ads** will show on dashboard (free users only)
**Interstitial ads** will show after 3rd invoice save

---

## Test with Safe IDs First

Want to test before going live?

Keep the test IDs during development:
```dart
static const _bannerId     = 'ca-app-pub-3940256099942544/6300978111';
static const _interstitialId = 'ca-app-pub-3940256099942544/1033173712';
static const _rewardedId   = 'ca-app-pub-3940256099942544/5224354917';
```

These Google test IDs:
- ✅ Show realistic ads
- ✅ Are safe to use
- ✅ Won't get you banned
- ✅ Great for testing

Switch to your real IDs only when deploying to production.

---

## Key Info

| Item | Where |
|------|-------|
| Ad IDs to change | `lib/services/ad_service.dart` lines 13-15 |
| App ID to add | `android/app/src/main/AndroidManifest.xml` |
| App ID to verify | `android/app/build.gradle.kts` applicationId |
| Banner location | Dashboard bottom |
| Interstitial trigger | After 3rd invoice save |
| Ad gating | Free tier only |

---

## For Full Details

See: `ADS_SETUP_GUIDE.md` (comprehensive guide)

---

Done in 5 minutes! 🚀
