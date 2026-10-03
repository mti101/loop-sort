import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../app_context.dart';
import '../config.dart';
import '../game/board_painter.dart';
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
    final firstLock = ctx.levels.firstWhere((l) => l.hasLocks, orElse: () => lv).id;
    if (n == 1) {
      id = 'tap';
      text = 'Tap a stack to send its front tiles to the loop. Fill the orders at the top!';
    } else if (n == 2) {
      id = 'loop';
      text = 'Matching tiles jump straight into an order. The rest ride the loop, which has limited room.';
    } else if (n == 4) {
      id = 'plan';
      text = "Plan ahead! Don't clog the loop with colours you don't need yet.";
    } else if (n == 5) {
      id = 'boosters';
      text = 'Stuck? Boosters help: Undo, Hint, more loop space, or an extra order slot.';
    } else if (n == firstMystery) {
      id = 'mystery';
      text = '? tiles reveal their colour when they reach the front of a stack.';
    } else if (n == firstLock) {
      id = 'lock';
      text = 'Locked stacks open after you complete enough orders.';
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
    if (!_tutorialStarted && g.layout != null) {
      _tutorialStarted = true;
      if (widget.level <= 2) g.autoHint();
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
    final L = g.layout;
    if (L == null) return;
    final i = L.stackAt(p);
    if (i == null) return;
    final before = g.moves;
    g.tapStack(i);
    if (g.moves != before) {
      if (_tipId != null) _dismissTip();
      if (widget.level <= 2) g.autoHint();
      setState(() {});
    }
  }

  // ------------------------------------------------------------ boosters
  Future<void> _useBooster(Booster b) async {
    if (g.status != GameStatus.playing || _busyDialog) return;
    final store = ctx.store;
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
        g.addLoopCapacity(2);
        g.showToast('+2 loop space!');
        break;
      case Booster.slot:
        if (g.state.qi >= lv.orders.length) {
          g.showToast('No more orders to add');
          return;
        }
        if (g.addOrderSlot()) {
          store.useBooster(b);
          g.showToast('Extra order slot!');
        }
        break;
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
        context, (_) => StuckDialog(deadEnd: g.deadEnd, canUndo: g.history.isNotEmpty),
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
        body: GameBackground(
          child: SafeArea(
            child: Column(
              children: [
                _topBar(),
                Expanded(
                  child: LayoutBuilder(builder: (context, c) {
                    g.setSize(Size(c.maxWidth, c.maxHeight));
                    return Stack(
                      children: [
                        Positioned.fill(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTapDown: (d) => _onTap(d.localPosition),
                            child: RepaintBoundary(
                              child: CustomPaint(painter: BoardPainter(g), size: Size.infinite),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: 10,
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
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
      child: Row(
        children: [
          RoundIconButton(icon: Icons.pause_rounded, onTap: _pause, size: 44),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedText('LEVEL ${widget.level}', size: 28),
                Text(
                  lv.isBoss ? 'BOSS LEVEL' : 'Moves ${g.moves}',
                  style: gameText(14, color: lv.isBoss ? AppColors.red : AppColors.textDim),
                ),
              ],
            ),
          ),
          LivesBadge(store: ctx.store),
        ],
      ),
    );
  }

  Widget _boosterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 6),
      child: ListenableBuilder(
        listenable: ctx.store,
        builder: (context, _) => Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (final b in Booster.values)
              _BoosterButton(booster: b, count: ctx.store.countOf(b), onTap: () => _useBooster(b)),
          ],
        ),
      ),
    );
  }
}

class _BoosterButton extends StatefulWidget {
  const _BoosterButton({required this.booster, required this.count, required this.onTap});
  final Booster booster;
  final int count;
  final VoidCallback onTap;
  @override
  State<_BoosterButton> createState() => _BoosterButtonState();
}

class _BoosterButtonState extends State<_BoosterButton> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    final b = widget.booster;
    final c = boosterColor(b);
    final dark = AppColors.shade(c, -0.22);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: () {
        ctx().sfx.play('button');
        widget.onTap();
      },
      child: SizedBox(
        width: 76,
        height: 78,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 60),
              top: _down ? 4 : 0,
              child: Column(
                children: [
                  Container(
                    width: 58,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: LinearGradient(
                          begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppColors.shade(c, 0.1), c]),
                      border: Border.all(color: dark, width: 3),
                      boxShadow: [BoxShadow(color: dark, offset: Offset(0, _down ? 1 : 4))],
                    ),
                    child: Icon(boosterIcon(b), color: Colors.white, size: 32),
                  ),
                  const SizedBox(height: 4),
                  Text(boosterName(b), style: gameText(12, color: AppColors.textDim)),
                ],
              ),
            ),
            Positioned(
              right: 4,
              top: -6,
              child: Container(
                constraints: const BoxConstraints(minWidth: 24),
                height: 24,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: widget.count > 0 ? const Color(0xFF0B2230) : AppColors.green,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: widget.count > 0
                    ? Text('${widget.count}', style: gameText(14))
                    : const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Ctx ctx() => Ctx.I;
}

class _ToastPill extends StatelessWidget {
  const _ToastPill({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xE60B2230),
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
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
        decoration: BoxDecoration(
          color: const Color(0xF2123242),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.amber, width: 3),
          boxShadow: const [BoxShadow(color: Color(0x88000000), blurRadius: 14, offset: Offset(0, 6))],
        ),
        child: Row(
          children: [
            const Mascot(size: 54, mood: 0),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: gameText(17, height: 1.15))),
            const SizedBox(width: 8),
            const Icon(Icons.check_circle_rounded, color: AppColors.green, size: 30),
          ],
        ),
      ),
    );
  }
}
