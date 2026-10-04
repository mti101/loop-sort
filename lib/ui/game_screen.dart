import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../app_context.dart';
import '../config.dart';
import '../game/board_painter.dart';
import '../game/factory_bg.dart';
import '../game/controller.dart';
import '../game/engine.dart';
import '../services/ads.dart';
import '../services/storage.dart';
import '../theme.dart';
import 'dialogs.dart';
import 'widgets/kit.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.level});
  final int level;
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin {
  late final Ctx ctx = Ctx.I;
  late final LevelData lv = ctx.level(widget.level);
  late final GameController g;
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  bool _busyDialog = false;
  bool _hintBusy = false;
  bool _tutorialStarted = false;
  String? _tipId;
  String? _tipText;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    g = GameController(lv,
        onSound: (n) => ctx.sfx.play(n), onHaptic: (k) => ctx.sfx.haptic(k))
      ..onWin = _handleWin
      ..onStuck = _handleStuck;
    _ticker = createTicker(_tick)..start();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepare());
  }

  void _prepare() {
    if (!mounted) return;
    ctx.store.refreshLives();
    if (ctx.store.lives <= 0) {
      _askLives();
      return;
    }
    ctx.ads.preload();
    _pickTip();
  }

  Future<void> _askLives() async {
    _busyDialog = true;
    final ok = await showGameDialog<bool>(context, (_) => const NoLivesDialog(), dismissible: false);
    _busyDialog = false;
    if (!mounted) return;
    if (ok == true) {
      _pickTip();
    } else {
      _leave();
    }
  }

  void _leave() {
    if (_leaving) return;
    _leaving = true;
    Navigator.of(context).pop();
  }

  void _pickTip() {
    String? id, text;
    final n = widget.level;
    final firstMystery = ctx.levels.firstWhere((l) => l.hasMystery, orElse: () => lv).id;
    if (n == 1) {
      id = 'tap';
      text = 'Tap a slot to move blocks.';
    } else if (n == 2) {
      id = 'match';
      text = 'Match the colors and stack them nicely!';
    } else if (n == 3) {
      id = 'full';
      text = "Don't let the conveyor fill up, or you'll lose!";
    } else if (n == 4) {
      id = 'undo';
      text = 'New! The Undo booster takes back your last move.';
    } else if (n == 5) {
      id = 'plan';
      text = 'Fill each slot with one color to complete it.';
    } else if (n == 7) {
      id = 'hintb';
      text = 'New! Hint shows you a good next move.';
    } else if (n == 9) {
      id = 'beltb';
      text = 'New! Conveyor +2 adds more room on the belt.';
    } else if (n == firstMystery) {
      id = 'mystery';
      text = '? blocks reveal their color when they reach the top of a slot.';
    }
    if (id != null && !ctx.store.tipsSeen.contains(id)) {
      setState(() {
        _tipId = id;
        _tipText = text;
      });
    }
  }

  void _dismissTip() {
    final id = _tipId;
    if (id != null) ctx.store.markTip(id);
    setState(() {
      _tipId = null;
      _tipText = null;
    });
  }

  void _tick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    g.update(dt);
    if (!_tutorialStarted && g.geo != null) {
      _tutorialStarted = true;
      if (widget.level <= 5) g.autoHint();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    g.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------ input
  void _onTap(Offset p) {
    if (_busyDialog) return;
    final geo = g.geo;
    if (geo == null) return;
    final i = geo.hitSlot(p);
    if (i == null) return;
    final before = g.moves;
    g.tapSlot(i);
    if (g.moves != before) {
      if (_tipId != null) _dismissTip();
      if (widget.level <= 5) _scheduleAutoHint();
      setState(() {});
    }
  }

  void _scheduleAutoHint() {
    Future<void>.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) g.autoHint();
    });
  }

  static int _unlock(Booster b) => switch (b) {
        Booster.undo => 4,
        Booster.hint => 7,
        Booster.loop => 9,
        Booster.slot => 99,
      };

  // ------------------------------------------------------------ boosters
  Future<void> _useBooster(Booster b) async {
    if (g.status != GameStatus.playing || _busyDialog) return;
    final store = ctx.store;
    if (widget.level < _unlock(b)) {
      g.showToast('Unlocks at level ${_unlock(b)}');
      return;
    }
    if (store.countOf(b) <= 0) {
      await _offerBooster(b);
      return;
    }
    switch (b) {
      case Booster.undo:
        if (!g.canUndo) {
          g.showToast('Nothing to undo yet');
          return;
        }
        if (g.busy) return;
        store.useBooster(b);
        g.undo();
        break;
      case Booster.hint:
        if (_hintBusy) return;
        _hintBusy = true;
        final r = await g.hint();
        _hintBusy = false;
        if (r.found) store.useBooster(b);
        break;
      case Booster.loop:
        store.useBooster(b);
        g.addBeltCapacity(2);
        g.showToast('Conveyor +2!');
        break;
      case Booster.slot:
        return;
    }
    if (mounted) setState(() {});
  }

  Future<void> _offerBooster(Booster b) async {
    _busyDialog = true;
    final r = await showGameDialog<String>(context, (_) => BoosterOfferDialog(booster: b));
    _busyDialog = false;
    if (!mounted) return;
    if (r == 'ad') {
      ctx.store.addBooster(b);
      ctx.sfx.play('star');
    } else if (r == 'coins') {
      if (ctx.store.spendCoins(AppConfig.boosterPrice)) {
        ctx.store.addBooster(b);
        ctx.sfx.play('star');
      }
    }
  }

  // ------------------------------------------------------------ results
  Future<void> _handleWin() async {
    final store = ctx.store;
    final stars = g.stars;
    final coins = 20 + stars * 10 + (lv.isBoss ? 40 : 0);
    store.completeLevel(widget.level, stars);
    store.addCoins(coins);
    ctx.sfx.play('win');
    ctx.sfx.haptic(2);
    g.celebrate();
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    _busyDialog = true;
    final last = widget.level >= AppConfig.totalLevels;
    final r = await showGameDialog<String>(
        context, (_) => WinDialog(level: widget.level, stars: stars, coins: coins, last: last),
        dismissible: false);
    _busyDialog = false;
    if (!mounted) return;
    switch (r) {
      case 'next':
        await ctx.ads.maybeShowInterstitial(widget.level);
        if (!mounted) return;
        _replaceWith(widget.level + 1);
        break;
      case 'replay':
        _replaceWith(widget.level);
        break;
      default:
        _leave();
    }
  }

  void _replaceWith(int level) {
    if (_leaving) return;
    _leaving = true;
    Navigator.of(context).pushReplacement(PageRouteBuilder<void>(
      pageBuilder: (_, __, ___) => GameScreen(level: level),
      transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
      transitionDuration: const Duration(milliseconds: 250),
    ));
  }

  Future<void> _handleStuck() async {
    if (_busyDialog) return;
    ctx.sfx.play('lose');
    _busyDialog = true;
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    final r = await showGameDialog<String>(
        context, (_) => StuckDialog(deadEnd: g.deadEnd, canUndo: g.canUndo),
        dismissible: false);
    _busyDialog = false;
    if (!mounted) return;
    switch (r) {
      case 'revive':
        g.revive();
        ctx.sfx.play('star');
        setState(() {});
        break;
      case 'undo':
        ctx.store.useBooster(Booster.undo);
        g.status = GameStatus.playing;
        g.undo();
        setState(() {});
        break;
      case 'undo_free':
        // out of undo boosters: grant via coins prompt, fall back to a free undo once
        g.status = GameStatus.playing;
        g.undo();
        setState(() {});
        break;
      case 'retry':
        ctx.store.loseLife();
        if (ctx.store.lives <= 0) {
          _busyDialog = true;
          final ok = await showGameDialog<bool>(context, (_) => const NoLivesDialog(), dismissible: false);
          _busyDialog = false;
          if (!mounted) return;
          if (ok != true) {
            _leave();
            return;
          }
        }
        _replaceWith(widget.level);
        break;
      default:
        ctx.store.loseLife();
        _leave();
    }
  }

  Future<void> _pause() async {
    if (_busyDialog || g.status != GameStatus.playing) return;
    _busyDialog = true;
    final r = await showGameDialog<String>(context, (_) => const PauseDialog());
    _busyDialog = false;
    if (!mounted) return;
    switch (r) {
      case 'restart':
        _replaceWith(widget.level);
        break;
      case 'settings':
        _busyDialog = true;
        await showGameDialog<void>(context, (_) => const SettingsDialog());
        _busyDialog = false;
        break;
      case 'home':
        _leave();
        break;
    }
  }

  // ------------------------------------------------------------ build
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _pause();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF3748A6),
        body: FactoryBackdrop(
          seed: widget.level ~/ 10,
          child: SafeArea(
            child: Column(
              children: [
                _topBar(),
                Expanded(
                  child: LayoutBuilder(builder: (context, c) {
                    g.setSize(Size(c.maxWidth, c.maxHeight - (_tipText != null ? 70 : 0)));
                    return Stack(
                      children: [
                        Positioned(
                          left: 0,
                          right: 0,
                          top: 0,
                          height: c.maxHeight - (_tipText != null ? 70 : 0),
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTapDown: (d) => _onTap(d.localPosition),
                            child: RepaintBoundary(
                              child: CustomPaint(painter: BoardPainter(g), size: Size.infinite),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 12,
                          right: 12,
                          bottom: 6,
                          child: IgnorePointer(
                            ignoring: _tipText == null,
                            child: ValueListenableBuilder<String?>(
                              valueListenable: g.toast,
                              builder: (context, msg, _) {
                                if (_tipText != null) return _TipCard(text: _tipText!, onOk: _dismissTip);
                                return AnimatedOpacity(
                                  duration: const Duration(milliseconds: 160),
                                  opacity: msg == null ? 0 : 1,
                                  child: Center(child: _ToastPill(text: msg ?? '')),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ),
                _boosterBar(),
                BannerSlot(ads: ctx.ads),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 2),
      child: Row(
        children: [
          const _AvatarChip(),
          const SizedBox(width: 6),
          AnimatedBuilder(animation: g, builder: (context, _) => _BeltCounter(g: g)),
          const Spacer(),
          if (lv.isBoss)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE23B4A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Text('BOSS', style: gameText(14)),
            ),
          _LevelPlate(level: widget.level),
        ],
      ),
    );
  }

  Widget _boosterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 2, 10, 6),
      child: ListenableBuilder(
        listenable: ctx.store,
        builder: (context, _) => Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _GearButton(onTap: _pause),
            for (final b in const [Booster.undo, Booster.hint, Booster.loop])
              _BoosterPad(
                booster: b,
                count: ctx.store.countOf(b),
                unlockLevel: _unlock(b),
                level: widget.level,
                onTap: () => _useBooster(b),
              ),
          ],
        ),
      ),
    );
  }
}

class _AvatarChip extends StatelessWidget {
  const _AvatarChip();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(colors: [Color(0xFF6B82E6), Color(0xFF3D52C0)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
        border: Border.all(color: const Color(0xFF1B2766), width: 3),
      ),
      child: ClipOval(child: Transform.translate(offset: const Offset(0, 3), child: const FittedBox(fit: BoxFit.cover, child: Mascot(size: 40)))),
    );
  }
}

class _BeltCounter extends StatelessWidget {
  const _BeltCounter({required this.g});
  final GameController g;
  @override
  Widget build(BuildContext context) {
    final n = g.beltCount;
    final cap = g.beltCap;
    final frac = cap == 0 ? 0.0 : (n / cap).clamp(0.0, 1.0);
    final danger = frac >= 0.8;
    final fill = danger ? const Color(0xFFE5424F) : const Color(0xFF45C85A);
    final flash = g.capFlash;
    return Container(
      height: 32,
      width: 96,
      decoration: BoxDecoration(
        color: const Color(0xFF1B2766),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: flash > 0 ? Colors.white : const Color(0xFF5F77DE), width: 2.4),
        boxShadow: flash > 0 ? [BoxShadow(color: Colors.white.withValues(alpha: flash * 0.8), blurRadius: 10)] : null,
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(2),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: frac,
              child: Container(
                decoration: BoxDecoration(color: n == 0 ? Colors.transparent : fill, borderRadius: BorderRadius.circular(9)),
              ),
            ),
          ),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.view_stream_rounded, color: Colors.white, size: 15),
                const SizedBox(width: 5),
                Text('$n/$cap', style: gameText(17)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelPlate extends StatelessWidget {
  const _LevelPlate({required this.level});
  final int level;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 62,
      padding: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF3B4FB4), Color(0xFF2B3A94)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1B2766), width: 2.4),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('LEVEL', style: gameText(9, color: const Color(0xFF9FB2F8), spacing: 1)),
          Text('$level', style: gameText(20, height: 1)),
        ],
      ),
    );
  }
}

class _GearButton extends StatelessWidget {
  const _GearButton({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Ctx.I.sfx.play('button');
        onTap();
      },
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(colors: [Color(0xFF6F86EE), Color(0xFF3B4FB4)], center: Alignment(-0.3, -0.4)),
          border: Border.all(color: const Color(0xFF1B2766), width: 3),
          boxShadow: const [BoxShadow(color: Color(0x55000030), offset: Offset(0, 3), blurRadius: 4)],
        ),
        child: const Icon(Icons.settings_rounded, color: Color(0xFFFFB347), size: 30),
      ),
    );
  }
}

class _BoosterPad extends StatefulWidget {
  const _BoosterPad({
    required this.booster,
    required this.count,
    required this.unlockLevel,
    required this.level,
    required this.onTap,
  });
  final Booster booster;
  final int count;
  final int unlockLevel;
  final int level;
  final VoidCallback onTap;
  @override
  State<_BoosterPad> createState() => _BoosterPadState();
}

class _BoosterPadState extends State<_BoosterPad> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    final b = widget.booster;
    final locked = widget.level < widget.unlockLevel;
    final c = locked ? const Color(0xFF5367CF) : boosterColor(b);
    final dark = AppColors.shade(c, -0.25);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: () {
        Ctx.I.sfx.play('button');
        widget.onTap();
      },
      child: SizedBox(
        width: 78,
        height: 74,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 60),
              top: _down ? 3 : 0,
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(26),
                      gradient: RadialGradient(
                          colors: [AppColors.shade(c, 0.18), c, dark], stops: const [0, 0.55, 1], center: const Alignment(-0.3, -0.5), radius: 1.1),
                      border: Border.all(color: const Color(0xFF1B2766), width: 3),
                      boxShadow: [BoxShadow(color: const Color(0xFF141C58), offset: Offset(0, _down ? 1 : 4))],
                    ),
                    child: locked
                        ? const Icon(Icons.lock_rounded, color: Color(0xFFC9D4FF), size: 28)
                        : Icon(boosterIcon(b), color: Colors.white, size: 30),
                  ),
                  const SizedBox(height: 3),
                  Text(locked ? 'Lv ${widget.unlockLevel}' : boosterName(b),
                      style: gameText(12, color: const Color(0xFFD6DEFF))),
                ],
              ),
            ),
            if (!locked)
              Positioned(
                right: 6,
                top: -5,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 22),
                  height: 22,
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: widget.count > 0 ? const Color(0xFFE5424F) : AppColors.green,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: widget.count > 0
                      ? Text('${widget.count}', style: gameText(13))
                      : const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 15),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ToastPill extends StatelessWidget {
  const _ToastPill({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xEE1B2766),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.amber, width: 2),
      ),
      child: Text(text, style: gameText(18), textAlign: TextAlign.center),
    );
  }
}

class _TipCard extends StatelessWidget {
  const _TipCard({required this.text, required this.onOk});
  final String text;
  final VoidCallback onOk;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onOk,
      child: SizedBox(
        height: 64,
        child: Stack(
          children: [
            Positioned.fill(
              left: 38,
              child: Container(
                padding: const EdgeInsets.fromLTRB(36, 8, 12, 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4DF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF3C4FC0), width: 3.5),
                  boxShadow: const [BoxShadow(color: Color(0x66000030), blurRadius: 8, offset: Offset(0, 4))],
                ),
                alignment: Alignment.centerLeft,
                child: Text(text, style: const TextStyle(fontFamily: 'Lilita', fontSize: 16, height: 1.1, color: Color(0xFF3B2A1A))),
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF3C4FC0),
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: ClipOval(child: Transform.translate(offset: const Offset(0, 6), child: const FittedBox(fit: BoxFit.cover, child: Mascot(size: 64)))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
