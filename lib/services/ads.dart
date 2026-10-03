import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config.dart';
import 'storage.dart';

/// AdMob wrapper: UMP consent, interstitials, rewarded ads and banners.
class AdsService extends ChangeNotifier {
  AdsService(this.store);
  final Store store;

  bool _initStarted = false;
  bool canRequestAds = false;
  bool privacyOptionsRequired = false;

  InterstitialAd? _interstitial;
  RewardedAd? _rewarded;
  bool _loadingInterstitial = false;
  bool _loadingRewarded = false;
  int _interRetry = 0;
  int _rewRetry = 0;
  DateTime _lastInterstitial = DateTime.fromMillisecondsSinceEpoch(0);

  bool get adsEnabled => !store.adsRemoved;
  bool get rewardedReady => _rewarded != null;

  /// Runs the Google UMP consent flow, then initialises the SDK.
  Future<void> init() async {
    if (_initStarted) return;
    _initStarted = true;
    try {
      await _runConsent().timeout(const Duration(seconds: 12), onTimeout: () {});
    } catch (e) {
      debugPrint('Consent flow error: $e');
    }
    try {
      canRequestAds = await ConsentInformation.instance.canRequestAds();
    } catch (_) {
      canRequestAds = false;
    }
    if (!canRequestAds) {
      notifyListeners();
      return;
    }
    try {
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(maxAdContentRating: MaxAdContentRating.pg),
      );
      await MobileAds.instance.initialize();
    } catch (e) {
      debugPrint('MobileAds init error: $e');
    }
    notifyListeners();
    _loadRewarded();
    if (adsEnabled) _loadInterstitial();
  }

  Future<void> _runConsent() async {
    final done = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () async {
        try {
          await ConsentForm.loadAndShowConsentFormIfRequired((FormError? e) {
            if (!done.isCompleted) done.complete();
          });
        } catch (_) {
          if (!done.isCompleted) done.complete();
        }
      },
      (FormError e) {
        if (!done.isCompleted) done.complete();
      },
    );
    await done.future;
    try {
      final st = await ConsentInformation.instance.getPrivacyOptionsRequirementStatus();
      privacyOptionsRequired = st == PrivacyOptionsRequirementStatus.required;
    } catch (_) {}
  }

  /// Lets players change their consent choice (required by GDPR/UMP).
  Future<void> showPrivacyOptions() async {
    try {
      await ConsentForm.showPrivacyOptionsForm((FormError? e) {});
    } catch (_) {}
  }

  // ------------------------------------------------------------ interstitial
  void _loadInterstitial() {
    if (!canRequestAds || _interstitial != null || _loadingInterstitial || !adsEnabled) return;
    _loadingInterstitial = true;
    InterstitialAd.load(
      adUnitId: AdIds.interstitial,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitial = ad;
          _loadingInterstitial = false;
          _interRetry = 0;
        },
        onAdFailedToLoad: (err) {
          _interstitial = null;
          _loadingInterstitial = false;
          _interRetry = (_interRetry + 1).clamp(1, 6);
          Future.delayed(Duration(seconds: 8 * _interRetry), _loadInterstitial);
        },
      ),
    );
  }

  /// Call after a level is won. Shows an interstitial when pacing allows.
  /// Returns when the ad is closed (or immediately if none was shown).
  Future<void> maybeShowInterstitial(int levelJustWon) async {
    if (!adsEnabled || !canRequestAds) return;
    store.bumpInterstitialCounter();
    if (levelJustWon < AppConfig.interstitialFirstLevel) return;
    if (store.levelsSinceInterstitial < AppConfig.interstitialEveryLevels) return;
    final since = DateTime.now().difference(_lastInterstitial).inSeconds;
    if (since < AppConfig.interstitialMinSeconds) return;
    final ad = _interstitial;
    if (ad == null) {
      _loadInterstitial();
      return;
    }
    final done = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        _interstitial = null;
        _lastInterstitial = DateTime.now();
        store.resetInterstitialCounter();
        _loadInterstitial();
        if (!done.isCompleted) done.complete();
      },
      onAdFailedToShowFullScreenContent: (a, e) {
        a.dispose();
        _interstitial = null;
        _loadInterstitial();
        if (!done.isCompleted) done.complete();
      },
    );
    _interstitial = null;
    try {
      await ad.show();
    } catch (_) {
      if (!done.isCompleted) done.complete();
    }
    await done.future.timeout(const Duration(minutes: 2), onTimeout: () {});
  }

  // ------------------------------------------------------------ rewarded
  void _loadRewarded() {
    if (!canRequestAds || _rewarded != null || _loadingRewarded) return;
    _loadingRewarded = true;
    RewardedAd.load(
      adUnitId: AdIds.rewarded,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewarded = ad;
          _loadingRewarded = false;
          _rewRetry = 0;
          notifyListeners();
        },
        onAdFailedToLoad: (err) {
          _rewarded = null;
          _loadingRewarded = false;
          _rewRetry = (_rewRetry + 1).clamp(1, 6);
          notifyListeners();
          Future.delayed(Duration(seconds: 6 * _rewRetry), _loadRewarded);
        },
      ),
    );
  }

  /// Shows a rewarded ad. Resolves true only if the user earned the reward.
  Future<bool> showRewarded() async {
    final ad = _rewarded;
    if (ad == null) {
      _loadRewarded();
      return false;
    }
    final result = Completer<bool>();
    var earned = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        _rewarded = null;
        _lastInterstitial = DateTime.now(); // don't stack an interstitial right after
        _loadRewarded();
        notifyListeners();
        if (!result.isCompleted) result.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (a, e) {
        a.dispose();
        _rewarded = null;
        _loadRewarded();
        notifyListeners();
        if (!result.isCompleted) result.complete(false);
      },
    );
    _rewarded = null;
    try {
      await ad.show(onUserEarnedReward: (view, reward) {
        earned = true;
      });
    } catch (_) {
      if (!result.isCompleted) result.complete(false);
    }
    return result.future.timeout(const Duration(minutes: 3), onTimeout: () => earned);
  }

  /// Make sure an ad is on its way when a screen is about to offer one.
  void preload() {
    _loadRewarded();
    _loadInterstitial();
  }
}

/// Adaptive banner that collapses to nothing when there is no fill or the
/// player removed ads.
class BannerSlot extends StatefulWidget {
  const BannerSlot({super.key, required this.ads});
  final AdsService ads;

  @override
  State<BannerSlot> createState() => _BannerSlotState();
}

class _BannerSlotState extends State<BannerSlot> {
  BannerAd? _ad;
  bool _loaded = false;
  bool _loading = false;
  int _width = 0;

  @override
  void initState() {
    super.initState();
    widget.ads.addListener(_onAds);
    widget.ads.store.addListener(_onAds);
  }

  void _onAds() {
    if (!mounted) return;
    if (widget.ads.store.adsRemoved) {
      _ad?.dispose();
      _ad = null;
      _loaded = false;
      setState(() {});
      return;
    }
    _maybeLoad();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybeLoad();
  }

  Future<void> _maybeLoad() async {
    if (_loading || _ad != null) return;
    if (!widget.ads.canRequestAds || widget.ads.store.adsRemoved) return;
    final w = MediaQuery.of(context).size.width.truncate();
    _loading = true;
    _width = w;
    AdSize? size;
    try {
      size = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(w);
    } catch (_) {}
    if (!mounted) return;
    if (size == null) {
      _loading = false;
      return;
    }
    final ad = BannerAd(
      adUnitId: AdIds.banner,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (a) {
          if (!mounted) {
            a.dispose();
            return;
          }
          setState(() {
            _loaded = true;
            _loading = false;
          });
        },
        onAdFailedToLoad: (a, e) {
          a.dispose();
          if (mounted) {
            setState(() {
              _ad = null;
              _loaded = false;
              _loading = false;
            });
          }
          Future.delayed(const Duration(seconds: 30), () {
            if (mounted) _maybeLoad();
          });
        },
      ),
    );
    _ad = ad;
    ad.load();
  }

  @override
  void dispose() {
    widget.ads.removeListener(_onAds);
    widget.ads.store.removeListener(_onAds);
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (!_loaded || ad == null || widget.ads.store.adsRemoved) {
      return const SizedBox.shrink();
    }
    return Container(
      alignment: Alignment.center,
      width: ad.size.width.toDouble(),
      height: ad.size.height.toDouble(),
      child: AdWidget(ad: ad),
    );
  }
}
