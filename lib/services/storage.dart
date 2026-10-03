import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';

enum Booster { undo, hint, loop, slot }

/// All persistent player data. Wrap every access: storage can fail.
class Store extends ChangeNotifier {
  Store._(this._p);
  final SharedPreferences? _p;

  static Future<Store> load() async {
    SharedPreferences? p;
    try {
      p = await SharedPreferences.getInstance();
    } catch (_) {}
    final s = Store._(p);
    s._read();
    return s;
  }

  // --- state
  int maxLevel = 1; // highest unlocked level
  Map<int, int> stars = {};
  int coins = AppConfig.startCoins;
  int lives = AppConfig.maxLives;
  int lifeRefillAt = 0; // ms epoch when next life regenerates (0 = full)
  Map<Booster, int> boosters = {
    for (final b in Booster.values) b: AppConfig.startBoosters
  };
  bool sound = true;
  bool haptics = true;
  bool adsRemoved = false;
  int dailyLastDay = -1;
  int dailyStreak = 0;
  int levelsSinceInterstitial = 0;
  int totalWins = 0;
  Set<String> tipsSeen = {};
  bool consentAsked = false;

  void _read() {
    final p = _p;
    if (p == null) return;
    try {
      maxLevel = p.getInt('maxLevel') ?? 1;
      final st = p.getString('stars');
      if (st != null) {
        final m = jsonDecode(st) as Map<String, dynamic>;
        stars = {for (final e in m.entries) int.parse(e.key): e.value as int};
      }
      coins = p.getInt('coins') ?? AppConfig.startCoins;
      lives = p.getInt('lives') ?? AppConfig.maxLives;
      lifeRefillAt = p.getInt('lifeRefillAt') ?? 0;
      for (final b in Booster.values) {
        boosters[b] = p.getInt('b_${b.name}') ?? AppConfig.startBoosters;
      }
      sound = p.getBool('sound') ?? true;
      haptics = p.getBool('haptics') ?? true;
      adsRemoved = p.getBool('adsRemoved') ?? false;
      dailyLastDay = p.getInt('dailyLastDay') ?? -1;
      dailyStreak = p.getInt('dailyStreak') ?? 0;
      levelsSinceInterstitial = p.getInt('lsi') ?? 0;
      totalWins = p.getInt('totalWins') ?? 0;
      tipsSeen = (p.getStringList('tips') ?? const []).toSet();
      consentAsked = p.getBool('consentAsked') ?? false;
    } catch (_) {}
    refreshLives();
  }

  Future<void> save() async {
    final p = _p;
    if (p == null) return;
    try {
      await p.setInt('maxLevel', maxLevel);
      await p.setString(
          'stars', jsonEncode({for (final e in stars.entries) '${e.key}': e.value}));
      await p.setInt('coins', coins);
      await p.setInt('lives', lives);
      await p.setInt('lifeRefillAt', lifeRefillAt);
      for (final b in Booster.values) {
        await p.setInt('b_${b.name}', boosters[b] ?? 0);
      }
      await p.setBool('sound', sound);
      await p.setBool('haptics', haptics);
      await p.setBool('adsRemoved', adsRemoved);
      await p.setInt('dailyLastDay', dailyLastDay);
      await p.setInt('dailyStreak', dailyStreak);
      await p.setInt('lsi', levelsSinceInterstitial);
      await p.setInt('totalWins', totalWins);
      await p.setStringList('tips', tipsSeen.toList());
      await p.setBool('consentAsked', consentAsked);
    } catch (_) {}
  }

  void _changed() {
    notifyListeners();
    save();
  }

  // --- coins
  void addCoins(int n) {
    coins += n;
    _changed();
  }

  bool spendCoins(int n) {
    if (coins < n) return false;
    coins -= n;
    _changed();
    return true;
  }

  // --- boosters
  int countOf(Booster b) => boosters[b] ?? 0;

  void addBooster(Booster b, [int n = 1]) {
    boosters[b] = countOf(b) + n;
    _changed();
  }

  bool useBooster(Booster b) {
    if (countOf(b) <= 0) return false;
    boosters[b] = countOf(b) - 1;
    _changed();
    return true;
  }

  // --- lives
  int get nowMs => DateTime.now().millisecondsSinceEpoch;

  void refreshLives() {
    if (lives >= AppConfig.maxLives) {
      lifeRefillAt = 0;
      return;
    }
    final step = AppConfig.lifeRegenMinutes * 60 * 1000;
    var changed = false;
    while (lives < AppConfig.maxLives && lifeRefillAt != 0 && nowMs >= lifeRefillAt) {
      lives++;
      lifeRefillAt += step;
      changed = true;
    }
    if (lives >= AppConfig.maxLives) lifeRefillAt = 0;
    if (changed) _changed();
  }

  /// Seconds until next life (0 if full).
  int get secondsToNextLife {
    if (lives >= AppConfig.maxLives || lifeRefillAt == 0) return 0;
    final d = lifeRefillAt - nowMs;
    return d <= 0 ? 0 : (d / 1000).ceil();
  }

  void loseLife() {
    if (lives <= 0) return;
    if (lives >= AppConfig.maxLives) {
      lifeRefillAt = nowMs + AppConfig.lifeRegenMinutes * 60 * 1000;
    }
    lives--;
    _changed();
  }

  void addLife([int n = 1]) {
    lives = (lives + n).clamp(0, AppConfig.maxLives);
    if (lives >= AppConfig.maxLives) lifeRefillAt = 0;
    _changed();
  }

  // --- progress
  int starsFor(int level) => stars[level] ?? 0;
  int get totalStars => stars.values.fold(0, (a, b) => a + b);

  void completeLevel(int level, int starCount) {
    if (starCount > starsFor(level)) stars[level] = starCount;
    if (level >= maxLevel && level < AppConfig.totalLevels) maxLevel = level + 1;
    totalWins++;
    _changed();
  }

  // --- settings
  void setSound(bool v) {
    sound = v;
    _changed();
  }

  void setHaptics(bool v) {
    haptics = v;
    _changed();
  }

  void setAdsRemoved(bool v) {
    adsRemoved = v;
    _changed();
  }

  // --- daily reward
  static int dayIndex(DateTime t) =>
      DateTime(t.year, t.month, t.day).millisecondsSinceEpoch ~/ 86400000;

  bool get dailyAvailable => dailyLastDay != dayIndex(DateTime.now());

  /// Streak that will apply if claimed now (1..7).
  int get dailyNextStreak {
    final today = dayIndex(DateTime.now());
    if (dailyLastDay == today - 1) return (dailyStreak % 7) + 1;
    return 1;
  }

  void claimDaily() {
    dailyStreak = dailyNextStreak;
    dailyLastDay = dayIndex(DateTime.now());
    _changed();
  }

  // --- misc
  void markTip(String id) {
    tipsSeen.add(id);
    _changed();
  }

  void setConsentAsked() {
    consentAsked = true;
    _changed();
  }

  void bumpInterstitialCounter() {
    levelsSinceInterstitial++;
    save();
  }

  void resetInterstitialCounter() {
    levelsSinceInterstitial = 0;
    save();
  }
}
