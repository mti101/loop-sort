/// Central, easy-to-edit configuration.
///
/// Ad unit IDs can be supplied at build time with --dart-define, e.g.
///   flutter build appbundle --dart-define=ADMOB_BANNER=ca-app-pub-xxx/yyy ...
/// The AdMob *app* ID lives in AndroidManifest.xml (CI swaps it in from the
/// ADMOB_APP_ID secret).
class AppConfig {
  static const String appName = 'Loop Sort';
  static const String packageId = 'com.absolutejoy.loop.puzzle.sort.game';
  static const String companyName = 'Terafort';
  static const String supportEmail = 'support@terafort.com';

  /// Hosted privacy policy (GitHub Pages from /docs once enabled).
  static const String privacyUrl = 'https://mti101.github.io/loop-sort/privacy.html';
  static const String storeUrl =
      'https://play.google.com/store/apps/details?id=com.absolutejoy.loop.puzzle.sort.game';

  /// Non-consumable in-app product (create the same ID in Play Console).
  static const String removeAdsProductId = 'remove_ads';

  static const int totalLevels = 200;
  static const int maxLives = 5;
  static const int lifeRegenMinutes = 25;
  static const int startCoins = 150;
  static const int startBoosters = 2;
  static const int boosterPrice = 120;
  static const int lifePrice = 90;

  // Ads pacing
  static const int interstitialFirstLevel = 6;
  static const int interstitialEveryLevels = 2;
  static const int interstitialMinSeconds = 75;
}

class AdIds {
  // Google's official sample IDs (always safe, never earn revenue).
  static const String testBanner = 'ca-app-pub-3940256099942544/6300978111';
  static const String testInterstitial = 'ca-app-pub-3940256099942544/1033173712';
  static const String testRewarded = 'ca-app-pub-3940256099942544/5224354917';

  static const String banner =
      String.fromEnvironment('ADMOB_BANNER', defaultValue: testBanner);
  static const String interstitial =
      String.fromEnvironment('ADMOB_INTERSTITIAL', defaultValue: testInterstitial);
  static const String rewarded =
      String.fromEnvironment('ADMOB_REWARDED', defaultValue: testRewarded);

  static bool get usingTestIds => banner == testBanner;
}
