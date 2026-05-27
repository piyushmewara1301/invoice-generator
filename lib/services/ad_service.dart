import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Manages all AdMob ads for the free tier.
///
/// BEFORE RELEASE: replace the test IDs below with your real ad unit IDs
/// from the AdMob console (admob.google.com). Also replace the App ID in
/// AndroidManifest.xml with your real Application ID.
class AdService {
  AdService._();
  static final AdService instance = AdService._();

  // ── Ad unit IDs (Google test IDs — replace before release) ──────────────
  static const _bannerId     = 'ca-app-pub-3940256099942544/6300978111';
  static const _interstitialId = 'ca-app-pub-3940256099942544/1033173712';
  static const _rewardedId   = 'ca-app-pub-3940256099942544/5224354917';

  // Show interstitial every N invoice saves on the free tier.
  static const _interstitialEvery = 3;

  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;
  int _invoiceSaveCount = 0;
  bool _initialized = false;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_initialized) return;
    await MobileAds.instance.initialize();
    _initialized = true;
    _loadInterstitial();
    _loadRewarded();
  }

  // ── Banner ────────────────────────────────────────────────────────────────

  /// Creates and starts loading a new BannerAd. The caller owns the lifecycle
  /// and must call [BannerAd.dispose] when done.
  BannerAd createBanner({
    void Function()? onLoaded,
    void Function()? onFailed,
  }) {
    return BannerAd(
      adUnitId: _bannerId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => onLoaded?.call(),
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          onFailed?.call();
        },
      ),
    )..load();
  }

  // ── Interstitial ──────────────────────────────────────────────────────────

  void _loadInterstitial() {
    InterstitialAd.load(
      adUnitId: _interstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _interstitialAd = null;
              _loadInterstitial(); // preload next
            },
            onAdFailedToShowFullScreenContent: (ad, _) {
              ad.dispose();
              _interstitialAd = null;
              _loadInterstitial();
            },
          );
        },
        onAdFailedToLoad: (_) => _interstitialAd = null,
      ),
    );
  }

  /// Call after every invoice save. Shows an interstitial every 3rd save
  /// (free tier only — pass [isFreeTier] = false to skip).
  void onInvoiceSaved({required bool isFreeTier}) {
    if (!isFreeTier) return;
    _invoiceSaveCount++;
    if (_invoiceSaveCount % _interstitialEvery == 0) {
      _interstitialAd?.show();
    }
  }

  // ── Rewarded ──────────────────────────────────────────────────────────────

  void _loadRewarded() {
    RewardedAd.load(
      adUnitId: _rewardedId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _rewardedAd = null;
              _loadRewarded();
            },
            onAdFailedToShowFullScreenContent: (ad, _) {
              ad.dispose();
              _rewardedAd = null;
              _loadRewarded();
            },
          );
        },
        onAdFailedToLoad: (_) => _rewardedAd = null,
      ),
    );
  }

  /// Shows a rewarded ad. [onRewarded] is called only if the user watches
  /// the full ad. Returns false if no ad is ready.
  bool showRewarded({required void Function() onRewarded}) {
    if (_rewardedAd == null) return false;
    _rewardedAd!.show(
      onUserEarnedReward: (_, reward) => onRewarded(),
    );
    return true;
  }

  bool get rewardedReady => _rewardedAd != null;
}
