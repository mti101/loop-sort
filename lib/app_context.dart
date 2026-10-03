import 'game/engine.dart';
import 'services/ads.dart';
import 'services/audio.dart';
import 'services/iap.dart';
import 'services/storage.dart';

/// Global singletons (kept simple on purpose: one game, one set of services).
class Ctx {
  Ctx(this.store, this.levels) {
    ads = AdsService(store);
    iap = IapService(store);
  }
  final Store store;
  final List<LevelData> levels;
  late final AdsService ads;
  late final IapService iap;
  final Sfx sfx = Sfx.instance;

  static late Ctx I;

  LevelData level(int n) => levels[(n - 1).clamp(0, levels.length - 1)];
}
