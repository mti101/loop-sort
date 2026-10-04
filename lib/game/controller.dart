import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';
import 'engine.dart';
import 'layout.dart';

enum GameStatus { playing, won, stuck }

class VTile {
  VTile(this.id, this.color, {this.hidden = false});
  final int id;
  final int color;
  bool hidden;
}

class SlotDisp {
  final List<VTile> tiles = []; // top first
  double flash = 0; // completion flash 1 -> 0
  bool complete = false;
  double pop = 0; // tap squash
  double shake = 0;
  int incoming = 0; // tiles currently dropping toward this slot
  double settle = 0; // landing bounce
}

/// A tile travelling on the conveyor. It is drawn as a ribbon of thin slats:
/// slat j sits at belt coordinate (h - j*sp). While the head is behind the
/// source gate the slats are still streaming out of the slot ("emerging");
/// after the head passes the target gate they stream into that slot.
class BeltV {
  BeltV(this.tile, this.src, {required this.from, required this.h, required this.colLen, required this.a0});
  final VTile tile;
  final int src;
  final Offset from; // where the brick sat in its slot
  double h; // head coordinate along the belt (unwrapped while emerging)
  final double colLen; // gate -> brick distance
  double? a0; // source gate arc while emerging, null once fully on the belt
  int? target;
  double rem = 0; // belt distance from head to the target gate
  double past = 0; // distance the head has travelled beyond the target gate
  Offset dropTo = Offset.zero;
  double colT = 0; // gate -> landing spot distance
  bool get diverting => target != null && past > 0;
}

class Particle {
  Particle(this.p, this.v, this.life, this.color, this.size, this.kind);
  Offset p;
  Offset v;
  double life;
  Color color;
  double size;
  int kind; // 0 square, 1 circle, 2 star
  double rot = 0;
}

class Popup {
  Popup(this.text, this.pos, this.color);
  final String text;
  final Offset pos;
  final Color color;
  double t = 0;
}

class _Snap {
  _Snap(this.state, this.slots, this.belt, this.cap);
  final GameState state;
  final List<List<VTile>> slots;
  final List<VTile> belt;
  final int cap;
}

class HintResult {
  const HintResult(this.found);
  final bool found;
}

class FrameTick extends ChangeNotifier {
  void tick() => notifyListeners();
}

class GameController extends ChangeNotifier {
  GameController(LevelData level, {this.onSound, this.onHaptic}) : base = level, lv = level {
    _reset();
  }

  final LevelData base;
  LevelData lv; // beltCap may grow via booster
  final void Function(String name)? onSound;
  final void Function(int kind)? onHaptic;

  late GameState state;
  final List<_Snap> _history = [];
  int moves = 0;
  GameStatus status = GameStatus.playing;
  bool deadEnd = false;
  bool revived = false;

  // geometry
  BoardGeometry? geo;
  Size _lastSize = Size.zero;

  // display model
  late List<SlotDisp> slots;
  final List<BeltV> belt = [];
  final List<Particle> particles = [];
  final List<Popup> popups = [];
  int _ids = 1;
  double time = 0;
  double capFlash = 0;
  int hintSlot = -1;
  double hintTimer = 0;
  double winTimer = -1;
  bool _notified = false;
  bool _solveBusy = false;
  int tutorialSlot = -1;

  /// Fires every animated frame; only the board painter listens to it.
  final FrameTick frame = FrameTick();

  final ValueNotifier<String?> toast = ValueNotifier<String?>(null);
  Timer? _toastTimer;
  VoidCallback? onWin;
  VoidCallback? onStuck;

  bool get canUndo => _history.isNotEmpty;
  int get beltCount => belt.where((b) => !b.diverting).length;
  int get beltCap => lv.beltCap;
  int get completeCount => slots.where((s) => s.complete).length;

  /// True while tiles are being lifted or are on their way to a slot.
  bool get busy => belt.any((b) => b.a0 != null || b.target != null);

  void showToast(String msg, {int ms = 1700}) {
    toast.value = msg;
    _toastTimer?.cancel();
    _toastTimer = Timer(Duration(milliseconds: ms), () => toast.value = null);
  }

  void setSize(Size s) {
    if (s == _lastSize && geo != null) return;
    _lastSize = s;
    geo = BoardGeometry.build(lv, s);
    // keep circulating tiles inside the (possibly new) path length
    _ribbon(geo!);
    for (final b in belt) {
      if (b.a0 == null && !b.diverting) b.h = geo!.belt.wrap(b.h);
    }
  }

  // ribbon metrics: every tile occupies [tileLen] of belt made of [slatN] slats
  double tileLen = 100;
  int slatN = 10;
  double slatSp = 10;

  void _ribbon(BoardGeometry g) {
    final cap = lv.beltCap;
    tileLen = (g.belt.length / (cap + 0.4)).clamp(g.tile * 0.55, g.tile * 2.2);
    slatN = (tileLen / (g.tile * 0.135)).round().clamp(5, 22);
    slatSp = tileLen / slatN;
  }

  void _reset() {
    state = initialState(lv);
    belt.clear();
    particles.clear();
    popups.clear();
    slots = [];
    for (var i = 0; i < lv.slotCount; i++) {
      final d = SlotDisp();
      final src = lv.slots[i];
      for (var k = 0; k < src.length; k++) {
        d.tiles.add(VTile(_ids++, src[k], hidden: lv.mystery[i][k]));
      }
      d.complete = isComplete(src, lv.capacity);
      slots.add(d);
    }
    hintSlot = -1;
    tutorialSlot = -1;
  }

  // -------------------------------------------------------------- input
  int runLength(int i) => runLen([for (final t in slots[i].tiles) t.color]);

  bool isHidden(int slot, int index) {
    final t = slots[slot].tiles[index];
    return t.hidden && index >= runLength(slot);
  }

  void tapSlot(int i) {
    if (status != GameStatus.playing) return;
    if (i < 0 || i >= slots.length) return;
    final d = slots[i];
    if (busy) return;
    if (d.tiles.isEmpty || d.complete) {
      _shake(i);
      return;
    }
    final ls = legalMoves(lv, state);
    if (!ls.contains(i)) {
      _shake(i);
      capFlash = 1;
      showToast('Conveyor is full!');
      onSound?.call('error');
      onHaptic?.call(1);
      return;
    }
    _history.add(_Snap(
      state,
      [for (final s in slots) List<VTile>.of(s.tiles)],
      [for (final b in belt) b.tile],
      lv.beltCap,
    ));
    final res = applyMove(lv, state, i);
    state = res.state;
    moves++;
    hintSlot = -1;
    tutorialSlot = -1;
    onSound?.call('send');
    onHaptic?.call(0);
    d.pop = 1;
    final g = geo;
    // lift the run
    final r = res.run;
    final count = d.tiles.length;
    final lifted = <BeltV>[];
    if (g != null) _ribbon(g);
    for (var k = 0; k < r; k++) {
      final tile = d.tiles[k];
      tile.hidden = false;
      final sg = g?.slots[i];
      final from = sg == null ? Offset.zero : sg.tileCenter(k, count);
      final a0 = sg?.gateArc ?? 0.0;
      final col = sg == null ? 0.0 : (from - sg.gate).distance;
      final c0 = sg == null ? 0.0 : (sg.tileCenter(0, count) - sg.gate).distance;
      // tile k starts streaming out once its predecessor ribbon has cleared
      final h0 = a0 - c0 - k * tileLen;
      lifted.add(BeltV(tile, i, from: from, h: h0, colLen: col, a0: a0));
    }
    d.tiles.removeRange(0, r);
    // tile order matches the logical belt: old tiles first, then the new run
    final order = <BeltV>[...belt, ...lifted];
    belt.addAll(lifted);
    for (final dp in res.drops) {
      if (dp.beltIndex >= order.length) continue;
      final bv = order[dp.beltIndex];
      bv.target = dp.slot;
      _setDistance(bv);
    }
    notifyListeners();
  }

  double _speed() {
    final g = geo;
    if (g == null) return 400;
    return (g.belt.length / 2.4).clamp(300.0, 700.0);
  }

  void _setDistance(BeltV b) {
    final g = geo;
    if (g == null || b.target == null) return;
    final arc = g.slots[b.target!].gateArc;
    final from = b.a0 ?? g.belt.wrap(b.h);
    var d = (arc - from) % g.belt.length;
    if (d < 0) d += g.belt.length;
    if (b.a0 != null && b.src == b.target && d < 1) d = g.belt.length;
    if (b.a0 == null && d < slatSp * 0.5) d += g.belt.length;
    b.rem = d;
    b.past = 0;
  }

  void _shake(int i) {
    slots[i].shake = 1;
    onSound?.call('error');
    onHaptic?.call(1);
  }

  // ------------------------------------------------------------ boosters
  Future<void> undo() async {
    if (_history.isEmpty || busy) return;
    final s = _history.removeLast();
    state = s.state;
    lv = base.withBeltCap(s.cap);
    moves = math.max(0, moves - 1);
    for (var i = 0; i < slots.length; i++) {
      slots[i]
        ..tiles.clear()
        ..tiles.addAll(s.slots[i])
        ..complete = isComplete([for (final t in s.slots[i]) t.color], lv.capacity)
        ..flash = 0;
    }
    belt.clear();
    final g = geo;
    if (g != null) _ribbon(g);
    for (var k = 0; k < s.belt.length; k++) {
      final b = BeltV(s.belt[k], 0, from: Offset.zero, h: 0, colLen: 0, a0: null);
      b.h = g == null ? 0 : g.belt.wrap(g.belt.length * 0.35 - k * tileLen);
      belt.add(b);
    }
    status = GameStatus.playing;
    _notified = false;
    hintSlot = -1;
    onSound?.call('button');
    notifyListeners();
  }

  void addBeltCapacity(int n) {
    lv = lv.withBeltCap(lv.beltCap + n);
    capFlash = 1;
    onSound?.call('star');
    notifyListeners();
  }

  Future<HintResult> hint() async {
    if (busy) return const HintResult(false);
    final lvc = lv;
    final st = state;
    final r = await Isolate.run(() => solveFrom(lvc, st, budget: 80000));
    final m = r.moves;
    if (m == null || m.isEmpty) {
      showToast(r.exhausted ? 'No solution from here - try Undo' : 'No hint found');
      return const HintResult(false);
    }
    hintSlot = m.first;
    hintTimer = 4.5;
    onSound?.call('star');
    return const HintResult(true);
  }

  /// Gives the player a little more room when stuck (rewarded revive).
  void revive() {
    revived = true;
    status = GameStatus.playing;
    _notified = false;
    lv = lv.withBeltCap(lv.beltCap + 3);
    capFlash = 1;
    deadEnd = false;
    notifyListeners();
  }

  /// First move of a solution, shown by the tutorial hand.
  Future<void> autoHint() async {
    if (busy || status != GameStatus.playing) return;
    final lvc = lv;
    final st = state;
    final r = await Isolate.run(() => solveFrom(lvc, st, budget: 30000));
    if (r.moves != null && r.moves!.isNotEmpty && status == GameStatus.playing && !busy) {
      tutorialSlot = r.moves!.first;
    }
  }

  int get stars {
    final par = base.par;
    if (moves <= (par * 1.15).ceil()) return 3;
    if (moves <= (par * 1.7).ceil()) return 2;
    return 1;
  }

  // ------------------------------------------------------------ update
  void update(double dt) {
    dt = dt.clamp(0.0, 0.05);
    time += dt;
    final g = geo;
    for (final s in slots) {
      if (s.flash > 0) s.flash = math.max(0, s.flash - dt * 1.1);
      if (s.pop > 0) s.pop = math.max(0, s.pop - dt * 5);
      if (s.shake > 0) s.shake = math.max(0, s.shake - dt * 3.2);
      if (s.settle > 0) s.settle = math.max(0, s.settle - dt * 6);
    }
    if (capFlash > 0) capFlash = math.max(0, capFlash - dt * 1.6);
    if (hintTimer > 0) {
      hintTimer -= dt;
      if (hintTimer <= 0) hintSlot = -1;
    }
    if (g != null) _updateBelt(g, dt);
    _updateFx(dt);
    _checkEnd(dt);
    final animating = belt.isNotEmpty ||
        particles.isNotEmpty ||
        popups.isNotEmpty ||
        capFlash > 0 ||
        hintSlot >= 0 ||
        tutorialSlot >= 0 ||
        slots.any((s) => s.flash > 0 || s.pop > 0 || s.shake > 0 || s.settle > 0);
    if (animating) frame.tick();
  }

  /// Belt coordinate of the last slat of [b] that is physically on the belt.
  double _tailX(BeltV b, BoardGeometry g) {
    final n1 = (slatN - 1) * slatSp;
    if (b.target != null && b.past > 0) {
      return g.slots[b.target!].gateArc + b.past - n1;
    }
    if (b.a0 != null) return math.max(b.h - n1, b.a0!);
    return b.h - n1;
  }

  void _updateBelt(BoardGeometry g, double dt) {
    final v = _speed();
    final len = g.belt.length;
    final sp = slatSp;
    final step = v * dt;
    if (belt.isEmpty) return;
    double wrapd(double x) {
      var r = x % len;
      if (r < 0) r += len;
      return r;
    }

    // riders that occupy the belt
    final riders = <BeltV>[];
    for (final b in belt) {
      if (b.target != null && b.past - (slatN - 1) * sp >= 0) continue; // fully diverted
      riders.add(b);
    }
    final n1 = (slatN - 1) * sp;
    bool sameRun(BeltV x, BeltV y) => x.a0 != null && y.a0 != null && x.a0 == y.a0;

    Map<BeltV, double> moves(Map<BeltV, double> lm) {
      final out = <BeltV, double>{};
      for (final b in belt) {
        if (b.diverting) {
          out[b] = step;
          continue;
        }
        final hx = b.a0 != null ? math.max(b.h, b.a0!) : b.h;
        var gapRaw = double.infinity;
        var gapBelt = double.infinity;
        for (final o in riders) {
          if (identical(o, b)) continue;
          final lmo = lm[o] ?? 0;
          if (sameRun(o, b)) {
            if (o.h > b.h) gapRaw = math.min(gapRaw, o.h - n1 - b.h - sp + lmo);
            continue;
          }
          var fd = wrapd(_tailX(o, g) - hx);
          if (fd > len - sp) fd = 0;
          gapBelt = math.min(gapBelt, fd - sp + lmo);
        }
        final mRaw = math.min(step, math.max(0.0, gapRaw));
        double m;
        if (b.a0 != null && b.h < b.a0!) {
          final colRoom = b.a0! - b.h;
          m = mRaw <= colRoom ? mRaw : colRoom + math.min(mRaw - colRoom, math.max(0.0, gapBelt));
        } else {
          m = math.min(mRaw, math.max(0.0, gapBelt));
        }
        out[b] = m;
      }
      return out;
    }

    final move1 = moves(const {});
    final move2 = moves(move1);
    for (final b in belt) {
      move2[b] = math.max(move2[b] ?? 0, move1[b] ?? 0);
    }

    for (final b in List<BeltV>.of(belt)) {
      final m = move2[b] ?? 0;
      final hOld = b.h;
      b.h += m;
      // belt distance covered by the head
      var beltMove = m;
      if (b.a0 != null) {
        beltMove = math.max(0.0, b.h - math.max(hOld, b.a0!));
        if (b.h - (slatN - 1) * sp >= b.a0!) {
          b.h = wrapd(b.h);
          b.a0 = null;
        }
      } else {
        b.h = wrapd(b.h);
      }
      if (b.target != null) {
        if (b.past > 0) {
          b.past += m;
        } else {
          b.rem -= beltMove;
          if (b.rem <= 0) {
            b.past = -b.rem + 0.001;
            b.rem = 0;
            final tg = g.slots[b.target!];
            final d = slots[b.target!];
            b.dropTo = tg.nextCenter(d.tiles.length + d.incoming);
            b.colT = (b.dropTo - tg.gate).distance;
            d.incoming++;
            notifyListeners();
          }
        }
        if (b.past > 0 && b.past - (slatN - 1) * sp >= b.colT) _land(g, b);
      }
    }
  }

  void _land(BoardGeometry g, BeltV b) {
    final d = slots[b.target!];
    d.incoming--;
    d.tiles.insert(0, b.tile);
    d.settle = 1;
    belt.remove(b);
    notifyListeners();
    onSound?.call('deliver');
    onHaptic?.call(0);
    _burst(g.slots[b.target!].nextCenter(d.tiles.length - 1), b.tile.color, 5, 0.6);
    final cols = [for (final t in d.tiles) t.color];
    if (!d.complete && isComplete(cols, lv.capacity)) {
      d.complete = true;
      d.flash = 1;
      _celebrateSlot(g, b.target!, b.tile.color);
    }
  }

  void _celebrateSlot(BoardGeometry g, int i, int color) {
    onSound?.call('complete');
    onHaptic?.call(1);
    final c = g.slots[i].center;
    _burst(c, color, 22, 1.2, confetti: true);
    const words = ['Nice!', 'Good!', 'Great!', 'Cool!', 'Sweet!'];
    popups.add(Popup(words[(time * 7).floor() % words.length], c, AppColors.tile(color)));
  }

  void _burst(Offset c, int color, int n, double power, {bool confetti = false}) {
    final rnd = math.Random();
    for (var k = 0; k < n; k++) {
      final a = rnd.nextDouble() * math.pi * 2;
      final sp = (60 + rnd.nextDouble() * 220) * power;
      final col = confetti
          ? AppColors.tiles[rnd.nextInt(AppColors.tiles.length)]
          : AppColors.shade(AppColors.tile(color), 0.12);
      particles.add(Particle(
        c,
        Offset(math.cos(a) * sp, math.sin(a) * sp - (confetti ? 120 : 40)),
        0.55 + rnd.nextDouble() * 0.6,
        col,
        confetti ? 4 + rnd.nextDouble() * 5 : 2.5 + rnd.nextDouble() * 3,
        confetti ? (rnd.nextBool() ? 0 : 1) : 2,
      )..rot = rnd.nextDouble() * 6);
    }
  }

  void celebrate() {
    final g = geo;
    if (g == null) return;
    for (final s in g.slots) {
      _burst(s.center, 0, 18, 1.4, confetti: true);
    }
  }

  void _updateFx(double dt) {
    for (final p in particles) {
      p.life -= dt;
      p.v = Offset(p.v.dx * (1 - 1.5 * dt), p.v.dy + 520 * dt);
      p.p += p.v * dt;
      p.rot += dt * 6;
    }
    particles.removeWhere((p) => p.life <= 0);
    for (final p in popups) {
      p.t += dt;
    }
    popups.removeWhere((p) => p.t > 1.0);
  }

  // ------------------------------------------------------------ end states
  void _checkEnd(double dt) {
    if (status != GameStatus.playing || _notified) return;
    if (belt.any((b) => b.a0 != null || b.target != null)) return;
    if (isWin(lv, state)) {
      winTimer = winTimer < 0 ? 0 : winTimer + dt;
      if (winTimer > 0.35) {
        status = GameStatus.won;
        _notified = true;
        onWin?.call();
      }
      return;
    }
    winTimer = -1;
    if (legalMoves(lv, state).isEmpty) {
      status = GameStatus.stuck;
      _notified = true;
      deadEnd = true;
      onStuck?.call();
      return;
    }
    _checkDeadEnd();
  }

  String? _lastChecked;
  Future<void> _checkDeadEnd() async {
    if (_solveBusy) return;
    final k = state.key;
    if (_lastChecked == k) return;
    _lastChecked = k;
    _solveBusy = true;
    final lvc = lv;
    final st = state;
    try {
      final r = await Isolate.run(() => solveFrom(lvc, st, budget: 40000));
      if (_lastChecked == k && r.exhausted && r.moves == null && status == GameStatus.playing) {
        deadEnd = true;
        showToast('Dead end! Use Undo', ms: 2600);
      } else {
        deadEnd = false;
      }
    } catch (_) {}
    _solveBusy = false;
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    frame.dispose();
    toast.dispose();
    super.dispose();
  }
}
