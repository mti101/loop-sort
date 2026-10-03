import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// Tiny pooled sound-effect player. Every call is failure-tolerant: audio is
/// never allowed to crash or block the game.
class Sfx {
  Sfx._();
  static final Sfx instance = Sfx._();

  static const names = [
    'tap', 'button', 'send', 'deliver', 'complete', 'coin', 'win', 'lose', 'error', 'star'
  ];
  final Map<String, AudioPool> _pools = {};
  bool enabled = true;
  bool hapticsEnabled = true;
  bool _ready = false;
  final Map<String, int> _lastPlay = {};

  Future<void> init() async {
    if (_ready) return;
    for (final n in names) {
      try {
        _pools[n] = await AudioPool.createFromAsset(path: 'audio/$n.wav', maxPlayers: 3);
      } catch (_) {}
    }
    _ready = true;
  }

  Future<void> play(String name, {double volume = 1.0}) async {
    if (!enabled) return;
    final pool = _pools[name];
    if (pool == null) return;
    // Throttle identical sounds that fire in the same few milliseconds.
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - (_lastPlay[name] ?? 0) < 45) return;
    _lastPlay[name] = now;
    try {
      await pool.start(volume: volume);
    } catch (_) {}
  }

  void haptic(int kind) {
    if (!hapticsEnabled) return;
    try {
      switch (kind) {
        case 0:
          HapticFeedback.selectionClick();
          break;
        case 1:
          HapticFeedback.lightImpact();
          break;
        default:
          HapticFeedback.mediumImpact();
      }
    } catch (_) {}
  }
}
