import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  static bool _initialized = false;

  // TEST IDs
  static const String _testBannerId = 'ca-app-pub-3940256099942544/6300978111';
  static const String _testInterstitialId =
      'ca-app-pub-3940256099942544/1033173712';
  static const String _testRewardedId =
      'ca-app-pub-3940256099942544/5224354917';
  static const String _testRewardedInterstitialId =
      'ca-app-pub-3940256099942544/5354046379';

  // REAL IDs (replace before publishing)
  static const String _realBannerId = 'YOUR_REAL_BANNER_ID';
  static const String _realInterstitialId = 'YOUR_REAL_INTERSTITIAL_ID';
  static const String _realRewardedId = 'YOUR_REAL_REWARDED_ID';
  static const String _realRewardedInterstitialId =
      'YOUR_REAL_REWARDED_INTERSTITIAL_ID';

  static String get _bannerId => kDebugMode ? _testBannerId : _realBannerId;
  static String get _interstitialId =>
      kDebugMode ? _testInterstitialId : _realInterstitialId;
  static String get _rewardedId =>
      kDebugMode ? _testRewardedId : _realRewardedId;
  static String get _rewardedInterstitialId =>
      kDebugMode ? _testRewardedInterstitialId : _realRewardedInterstitialId;

  static InterstitialAd? _interstitialAd;
  static RewardedAd? _rewardedAd;
  static RewardedInterstitialAd? _rewardedInterstitialAd;

  static bool _interstitialLoaded = false;
  static bool _rewardedLoaded = false;
  static bool _rewardedInterstitialLoaded = false;
  static bool _isLoadingInterstitial = false;
  static bool _isLoadingRewarded = false;
  static bool _isLoadingRewardedInterstitial = false;

  static bool get isInitialized => _initialized;
  static bool get isInterstitialLoaded => _interstitialLoaded;
  static bool get isRewardedLoaded => _rewardedLoaded;
  static bool get isRewardedInterstitialLoaded => _rewardedInterstitialLoaded;

  // ══════════════════════════════
  // INITIALIZATION
  // ══════════════════════════════

  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      await MobileAds.instance.initialize();
      _initialized = true;
      debugPrint('✅ AdMob initialized');

      MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(
          testDeviceIds: ['705CA0E04E8D94B5478E06470652171A'],
        ),
      );

      Future.delayed(const Duration(seconds: 2), loadInterstitial);
      Future.delayed(const Duration(seconds: 4), loadRewardedInterstitial);
      Future.delayed(const Duration(seconds: 6), loadRewarded);
    } catch (e) {
      debugPrint('❌ AdMob init error: $e');
    }
  }

  // ══════════════════════════════
  // BANNER AD
  // ══════════════════════════════

  static BannerAd? createBannerAd({
    VoidCallback? onLoaded,
    VoidCallback? onFailed,
  }) {
    if (!_initialized) {
      onFailed?.call();
      return null;
    }

    final ad = BannerAd(
      adUnitId: _bannerId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('✅ Banner loaded (id: ${ad.hashCode})');
          onLoaded?.call();
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('❌ Banner failed: ${error.message}');
          ad.dispose();
          onFailed?.call();
        },
      ),
    );
    ad.load();
    return ad;
  }

  // ══════════════════════════════
  // INTERSTITIAL AD
  // ══════════════════════════════

  static void loadInterstitial() {
    if (!_initialized || _isLoadingInterstitial || _interstitialLoaded) return;
    _isLoadingInterstitial = true;

    InterstitialAd.load(
      adUnitId: _interstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _interstitialLoaded = true;
          _isLoadingInterstitial = false;
          debugPrint('✅ Interstitial loaded');
        },
        onAdFailedToLoad: (error) {
          _interstitialLoaded = false;
          _isLoadingInterstitial = false;
          Future.delayed(const Duration(seconds: 60), () {
            if (_initialized) loadInterstitial();
          });
        },
      ),
    );
  }

  static void showInterstitial({required VoidCallback onDone}) {
    if (!_initialized || !_interstitialLoaded || _interstitialAd == null) {
      loadInterstitial();
      onDone();
      return;
    }

    bool done = false;
    void finish() {
      if (!done) {
        done = true;
        onDone();
      }
    }

    Timer(const Duration(seconds: 8), finish);

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        _interstitialLoaded = false;
        loadInterstitial();
        finish();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _interstitialAd = null;
        _interstitialLoaded = false;
        loadInterstitial();
        finish();
      },
    );

    try {
      _interstitialAd!.show();
    } catch (e) {
      finish();
    }
  }

  // ══════════════════════════════
  // REWARDED INTERSTITIAL AD (Game Over Ad)
  // This is the "game-playing" style video ad
  // Shows automatically, user can earn bonus
  // ══════════════════════════════

  static void loadRewardedInterstitial() {
    if (!_initialized ||
        _isLoadingRewardedInterstitial ||
        _rewardedInterstitialLoaded) return;
    _isLoadingRewardedInterstitial = true;

    RewardedInterstitialAd.load(
      adUnitId: _rewardedInterstitialId,
      request: const AdRequest(),
      rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedInterstitialAd = ad;
          _rewardedInterstitialLoaded = true;
          _isLoadingRewardedInterstitial = false;
          debugPrint('✅ Rewarded Interstitial loaded');
        },
        onAdFailedToLoad: (error) {
          _rewardedInterstitialLoaded = false;
          _isLoadingRewardedInterstitial = false;
          debugPrint('❌ Rewarded Interstitial failed: ${error.message}');
          Future.delayed(const Duration(seconds: 45), () {
            if (_initialized) loadRewardedInterstitial();
          });
        },
      ),
    );
  }

  static void showRewardedInterstitial({
    required VoidCallback onDone,
    VoidCallback? onReward,
  }) {
    if (!_initialized ||
        !_rewardedInterstitialLoaded ||
        _rewardedInterstitialAd == null) {
      // Fallback to regular interstitial
      if (_interstitialLoaded && _interstitialAd != null) {
        showInterstitial(onDone: onDone);
      } else {
        loadRewardedInterstitial();
        onDone();
      }
      return;
    }

    bool done = false;
    bool rewarded = false;

    void finish() {
      if (!done) {
        done = true;
        if (rewarded) onReward?.call();
        onDone();
      }
    }

    // Safety timeout - never get stuck
    Timer(const Duration(seconds: 35), finish);

    _rewardedInterstitialAd!.fullScreenContentCallback =
        FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        debugPrint('🎬 Rewarded Interstitial showing');
      },
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('✅ Rewarded Interstitial dismissed');
        ad.dispose();
        _rewardedInterstitialAd = null;
        _rewardedInterstitialLoaded = false;
        loadRewardedInterstitial();
        finish();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('❌ Rewarded Interstitial show failed: ${error.message}');
        ad.dispose();
        _rewardedInterstitialAd = null;
        _rewardedInterstitialLoaded = false;
        loadRewardedInterstitial();
        finish();
      },
    );

    try {
      _rewardedInterstitialAd!.show(
        onUserEarnedReward: (ad, reward) {
          debugPrint('🎁 User earned reward: ${reward.amount} ${reward.type}');
          rewarded = true;
        },
      );
    } catch (e) {
      debugPrint('❌ Rewarded Interstitial show error: $e');
      finish();
    }
  }

  // ══════════════════════════════
  // REWARDED AD (for Tips/Undo)
  // ══════════════════════════════

  static void loadRewarded() {
    if (!_initialized || _isLoadingRewarded || _rewardedLoaded) return;
    _isLoadingRewarded = true;

    RewardedAd.load(
      adUnitId: _rewardedId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _rewardedLoaded = true;
          _isLoadingRewarded = false;
          debugPrint('✅ Rewarded loaded');
        },
        onAdFailedToLoad: (error) {
          _rewardedLoaded = false;
          _isLoadingRewarded = false;
          Future.delayed(const Duration(seconds: 60), () {
            if (_initialized) loadRewarded();
          });
        },
      ),
    );
  }

  static Future<bool> showRewarded({
    required VoidCallback onReward,
    VoidCallback? onDone,
  }) async {
    if (!_initialized || !_rewardedLoaded || _rewardedAd == null) {
      loadRewarded();
      onDone?.call();
      return false;
    }

    final completer = Completer<bool>();
    bool rewarded = false;
    bool done = false;

    void finish() {
      if (!done) {
        done = true;
        if (rewarded) onReward();
        onDone?.call();
        if (!completer.isCompleted) completer.complete(rewarded);
      }
    }

    Timer(const Duration(seconds: 30), finish);

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        _rewardedLoaded = false;
        loadRewarded();
        finish();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedAd = null;
        _rewardedLoaded = false;
        loadRewarded();
        finish();
      },
    );

    try {
      _rewardedAd!.show(
        onUserEarnedReward: (ad, reward) {
          rewarded = true;
        },
      );
    } catch (e) {
      finish();
    }

    return completer.future;
  }

  static void dispose() {
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
    _rewardedInterstitialAd?.dispose();
    _interstitialAd = null;
    _rewardedAd = null;
    _rewardedInterstitialAd = null;
  }
}