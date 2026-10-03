import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';
import 'engine.dart';
import 'layout.dart';

enum GameStatus { playing, won, stuck }

class SlotView {
  SlotView(this.color, this.need, this.total, this.gen);
  int color;
  int need;
  int total;
  int gen;
  double appear = 0; // pop-in 0..1
  double pulse = 0; // delivery pulse
  double flash = 0; // completion flash
  int? ghostColor; // colour of the order that just completed in this slot
  double ghostT = 0; // 1 -> 0 completion animation
  bool empty = false;
}

class LoopTile {
  LoopTile(this.color, this.pos);
  int color;
  double pos; // animated bay index
  double pop = 0;
}

class Flight {
  Flight({
    required this.color,
    required this.from,
    required this.toSlot,
    required this.toBay,
    required double delay,
    required this.dur,
    this.slotGen = 0,
    this.onArrive,
  }) : t = -delay;
  final int color;
  final Offset from;
  int toSlot; // -1 => loop
  int toBay;
  double t;
  final double dur;
  int slotGen;
  VoidCallback? onArrive;
  bool done = false;
  bool get toLoop => toSlot < 0;
}

class Particle {
  Particle(this.p, this.v, this.life, this.color, this.size, this.kind);
  Offset p;
  Offset v;
  double life;
  final double maxLife = 1;
  Color color;
  double size;
  int kind; // 0 square, 1 circle, 2 star
  double rot = 0;
  double get t => (life).clamp(0.0, 1.0);
}

class HintResult {
  final bool found;
  const HintResult(this.found);
}

class GameController extends ChangeNotifier {
  GameController(this.lv, {this.onSound, this.onHaptic}) {
    state = initialState(lv);
    _resetView();
  }

  final LevelData lv;
  final void Function(String name)? onSound;
  final void Function(int kind)? onHaptic; // 0 light, 1 medium, 2 heavy

  late GameState state;
  final List<GameState> history = [];
  int moves = 0;
  final List<int> moveLog = [];
  GameStatus status = GameStatus.playing;
  bool deadEnd = false;
  bool revived = false;

  // --- layout
  BoardLayout? layout;
  Size _lastSize = Size.zero;

  void setSize(Size s) {
    if (s == _lastSize && layout != null) return;
    _lastSize = s;
    var maxDepth = 1;
    for (final st in lv.stacks) {
      if (st.length > maxDepth) maxDepth = st.length;
    }
    layout = BoardLayout(s, stackCount: lv.stacks.length, maxDepth: maxDepth);
  }

  // --- display model
  late List<List<int>> dStacks;
  late List<LoopTile> dLoop;
  late List<SlotView> dSlots;
  int dQi = 0;
  int dDone = 0;
  int dCap = 0;
  int _slotGen = 1;
  int pendingLoopFlights = 0;
  final List<Flight> flights = [];
  final List<Particle> particles = [];
  final List<Ev> _queue = [];
  double _evTimer = 0;

  double phase = 0;
  double time = 0;
  double loopFlash = 0;
  final Map<int, double> shake = {};
  final Map<int, double> pop = {}; // stack pop on tap
  int hintStack = -1;
  double hintTimer = 0;
  double winTimer = -1;
  double capGrow = 0;

  // toast
  final ValueNotifier<String?> toast = ValueNotifier<String?>(null);
  Timer? _toastTimer;

  VoidCallback? onWin;
  VoidCallback? onStuck;

  void showToast(String msg, {int ms = 1800}) {
    toast.value = msg;
    _toastTimer?.cancel();
    _toastTimer = Timer(Duration(milliseconds: ms), () => toast.value = null);
  }

  void _resetView() {
    flights.clear();
    _queue.clear();
    pendingLoopFlights = 0;
    dStacks = [for (final s in state.stacks) List<int>.from(s)];
    dLoop = [];
    var idx = 0;
    for (var c = 0; c < state.loop.length; c++) {
      for (var k = 0; k < state.loop[c]; k++) {
        dLoop.add(LoopTile(c, idx.toDouble()));
        idx++;
      }
    }
    dSlots = [];
    for (final a in state.active) {
      if (a == null) {
        final sv = SlotView(0, 0, 0, _slotGen++)..empty = true;
        dSlots.add(sv);
      } else {
        dSlots.add(SlotView(a.color, a.need, a.total, _slotGen++)..appear = 1);
      }
    }
    dQi = state.qi;
    dDone = state.done;
    dCap = state.cap;
    hintStack = -1;
  }

  // ------------------------------------------------------------ input
  /// Run length shown to the player for stack [i] (front run).
  int runLength(int i) => frontRun(dStacks[i]);

  bool isStackLocked(int i) => dDone < lv.locks[i];

  void tapStack(int i) {
    if (status != GameStatus.playing) return;
    if (i < 0 || i >= state.stacks.length) return;
    if (state.stacks[i].isEmpty) return;
    if (state.done < lv.locks[i]) {
      _shake(i);
      final need = lv.locks[i] - state.done;
      showToast('Locked! Complete $need more order${need == 1 ? '' : 's'}');
      onSound?.call('error');
      onHaptic?.call(1);
      return;
    }
    final ev = <Ev>[];
    final ns = applyMove(lv, state, i, ev);
    if (ns == null) {
      _shake(i);
      loopFlash = 1;
      showToast('The loop is full!');
      onSound?.call('error');
      onHaptic?.call(1);
      return;
    }
    history.add(state);
    moveLog.add(i);
    moves++;
    state = ns;
    deadEnd = false;
    hintStack = -1;
    pop[i] = 1;
    onSound?.call('tap');
    onHaptic?.call(0);
    _queue.addAll(ev);
  }

  void _shake(int i) => shake[i] = 1;

  // ------------------------------------------------------------ boosters
  bool get canUndo => history.isNotEmpty && status == GameStatus.playing;

  bool undo() {
    if (!canUndo) return false;
    state = history.removeLast();
    if (moves > 0) moves--;
    if (moveLog.isNotEmpty) moveLog.removeLast();
    deadEnd = false;
    _resetView();
    onSound?.call('button');
    return true;
  }

  bool addLoopCapacity(int extra) {
    state = addCapacity(state, extra);
    history.clear();
    dCap = state.cap;
    capGrow = 1;
    onSound?.call('star');
    return true;
  }

  bool addOrderSlot() {
    if (state.qi >= lv.orders.length) return false;
    final o = lv.orders[state.qi];
    final ev = <Ev>[];
    final ns = addSlot(lv, state, ev);
    if (ns == null) return false;
    state = ns;
    history.clear();
    dSlots.add(SlotView(o.color, o.need, o.total, _slotGen++));
    dQi++;
    _queue.addAll(ev);
    onSound?.call('star');
    return true;
  }

  /// Tutorial helper: point at the next move of the stored solution while the
  /// player is still on it.
  void autoHint() {
    final sol = lv.solution;
    if (moveLog.length >= sol.length) {
      hintStack = -1;
      return;
    }
    for (var k = 0; k < moveLog.length; k++) {
      if (moveLog[k] != sol[k]) {
        hintStack = -1;
        return;
      }
    }
    hintStack = sol[moveLog.length];
    hintTimer = 3600;
  }

  Future<HintResult> hint() async {
    if (status != GameStatus.playing) return const HintResult(false);
    final st = state;
    final level = lv;
    final r = await Isolate.run(() => solveFrom(level, st, budget: 120000));
    if (st != state) return const HintResult(false);
    int? pick;
    if (r.moves != null && r.moves!.isNotEmpty) {
      pick = r.moves!.first;
    } else if (r.budgetExceeded) {
      final legal = legalMoves(lv, state);
      if (legal.isNotEmpty) pick = legal.first;
    }
    if (pick == null) {
      showToast('No winning line from here. Try Undo!', ms: 2400);
      return const HintResult(false);
    }
    hintStack = pick;
    hintTimer = 6;
    return const HintResult(true);
  }

  /// Rewarded revive after a stuck state: more room on the loop.
  void revive() {
    revived = true;
    state = addCapacity(state, 3);
    history.clear();
    dCap = state.cap;
    capGrow = 1;
    status = GameStatus.playing;
    deadEnd = false;
    _deadChecked = '';
  }

  // ------------------------------------------------------------ playback
  String _deadChecked = '';
  bool _solving = false;

  Offset bayPoint(double bay) {
    final L = layout!;
    return L.loopPoint(phase + bay / math.max(1, dCap));
  }

  void update(double dt) {
    final L = layout;
    if (L == null) return;
    dt = dt.clamp(0.0, 0.05).toDouble();
    time += dt;
    phase += dt * 0.04;
    if (phase > 1000) phase -= 1000;
    loopFlash = math.max(0, loopFlash - dt * 2.2);
    capGrow = math.max(0, capGrow - dt * 1.6);
    if (hintTimer > 0) {
      hintTimer -= dt;
      if (hintTimer <= 0) hintStack = -1;
    }
    for (final k in shake.keys.toList()) {
      final v = shake[k]! - dt * 3.2;
      if (v <= 0) {
        shake.remove(k);
      } else {
        shake[k] = v;
      }
    }
    for (final k in pop.keys.toList()) {
      final v = pop[k]! - dt * 5;
      if (v <= 0) {
        pop.remove(k);
      } else {
        pop[k] = v;
      }
    }

    // events
    _evTimer -= dt;
    while (_queue.isNotEmpty && _evTimer <= 0) {
      final e = _queue.removeAt(0);
      _startEvent(e, L);
    }

    // flights
    for (final f in flights) {
      f.t += dt;
      if (!f.done && f.t >= f.dur) {
        f.done = true;
        f.onArrive?.call();
      }
    }
    flights.removeWhere((f) => f.done);

    // loop tiles ease to their bay index
    for (var i = 0; i < dLoop.length; i++) {
      final lt = dLoop[i];
      lt.pos += (i - lt.pos) * math.min(1.0, dt * 9);
      if (lt.pop > 0) lt.pop = math.max(0, lt.pop - dt * 4);
    }

    // slots
    for (final s in dSlots) {
      if (s.ghostT > 0) s.ghostT = math.max(0, s.ghostT - dt * 1.7);
      if (s.appear < 1 && s.ghostT < 0.55) s.appear = math.min(1, s.appear + dt * 3.2);
      if (s.pulse > 0) s.pulse = math.max(0, s.pulse - dt * 5);
    }

    // particles
    for (final p in particles) {
      p.life -= dt * 1.25;
      p.v = Offset(p.v.dx * (1 - dt * 0.8), p.v.dy + 520 * dt);
      p.p += p.v * dt;
      p.rot += dt * 6;
    }
    particles.removeWhere((p) => p.life <= 0);

    // end-of-playback checks
    final idle = _queue.isEmpty && flights.isEmpty;
    if (status == GameStatus.playing && idle) {
      if (isWin(lv, state)) {
        if (winTimer < 0) winTimer = 0.55;
        winTimer -= dt;
        if (winTimer <= 0) {
          status = GameStatus.won;
          onWin?.call();
        }
      } else {
        final legal = legalMoves(lv, state);
        if (legal.isEmpty) {
          status = GameStatus.stuck;
          onStuck?.call();
        } else if (_deadChecked != state.key && !_solving && lv.id >= 6) {
          _checkDeadEnd();
        }
      }
    }
    notifyListeners();
  }

  Future<void> _checkDeadEnd() async {
    final st = state;
    final key = st.key;
    _solving = true;
    try {
      final level = lv;
      final r = await Isolate.run(() => solveFrom(level, st, budget: 60000));
      if (key == state.key) {
        _deadChecked = key;
        if (r.moves == null && !r.budgetExceeded && status == GameStatus.playing) {
          deadEnd = true;
          status = GameStatus.stuck;
          onStuck?.call();
        }
      }
    } catch (_) {
      _deadChecked = key;
    }
    _solving = false;
  }

  void _burst(Offset at, Color c, {int n = 14, double power = 220}) {
    final rnd = math.Random();
    for (var i = 0; i < n; i++) {
      final a = rnd.nextDouble() * math.pi * 2;
      final sp = power * (0.35 + rnd.nextDouble() * 0.8);
      particles.add(Particle(at, Offset(math.cos(a) * sp, math.sin(a) * sp - 120), 0.7 + rnd.nextDouble() * 0.5,
          i % 3 == 0 ? Colors.white : AppColors.shade(c, rnd.nextDouble() * 0.2), 3 + rnd.nextDouble() * 4, i % 3));
    }
  }

  void _startEvent(Ev e, BoardLayout L) {
    switch (e.type) {
      case EvType.send:
        _evTimer += 0.105;
        final stack = dStacks[e.stack];
        if (stack.isEmpty) return;
        final c = stack.removeAt(0);
        // Position of the tile that just left (before removal it was index 0).
        final from = L.stackTileCenter(e.stack, 0);
        if (e.slot >= 0) {
          final gen = e.slot < dSlots.length ? dSlots[e.slot].gen : -1;
          final slot = e.slot;
          flights.add(Flight(
            color: c,
            from: from,
            toSlot: slot,
            toBay: 0,
            delay: 0,
            dur: 0.36,
            slotGen: gen,
            onArrive: () => _arriveSlot(slot, gen),
          ));
        } else {
          final bay = dLoop.length + pendingLoopFlights;
          pendingLoopFlights++;
          late Flight f;
          f = Flight(
            color: c,
            from: from,
            toSlot: -1,
            toBay: bay,
            delay: 0,
            dur: 0.42,
            onArrive: () {
              if (f.toLoop) {
                pendingLoopFlights = math.max(0, pendingLoopFlights - 1);
                dLoop.add(LoopTile(c, math.min(f.toBay.toDouble(), dLoop.length.toDouble()))..pop = 1);
              }
            },
          );
          flights.add(f);
        }
        onSound?.call('send');
        break;
      case EvType.absorb:
        _evTimer += 0.09;
        final slot = e.slot;
        final gen = slot < dSlots.length ? dSlots[slot].gen : -1;
        var idx = dLoop.indexWhere((t) => t.color == e.color);
        if (idx >= 0) {
          final lt = dLoop.removeAt(idx);
          final from = bayPoint(lt.pos);
          flights.add(Flight(
            color: e.color,
            from: from,
            toSlot: slot,
            toBay: 0,
            delay: 0,
            dur: 0.4,
            slotGen: gen,
            onArrive: () => _arriveSlot(slot, gen),
          ));
        } else {
          // The tile is still flying to the loop: redirect that flight.
          for (final f in flights) {
            if (f.toLoop && f.color == e.color && !f.done) {
              pendingLoopFlights = math.max(0, pendingLoopFlights - 1);
              f.toSlot = slot;
              f.slotGen = gen;
              f.onArrive = () => _arriveSlot(slot, gen);
              break;
            }
          }
        }
        break;
      case EvType.complete:
        _evTimer += 0.12;
        final slot = e.slot;
        if (slot >= dSlots.length) return;
        final old = dSlots[slot];
        final nx = e.next;
        final nv = nx == null
            ? (SlotView(0, 0, 0, _slotGen++)
              ..empty = true
              ..appear = 1)
            : SlotView(nx.color, nx.need, nx.total, _slotGen++);
        nv.ghostColor = old.color;
        nv.ghostT = 1;
        dSlots[slot] = nv;
        dDone++;
        if (nx != null) dQi++;
        final at = layout!.slotRect(slot, dSlots.length).center;
        _burst(at, AppColors.tile(old.color), n: 18);
        onSound?.call('complete');
        onHaptic?.call(1);
        break;
    }
  }

  void _arriveSlot(int slot, int gen) {
    if (slot >= dSlots.length) return;
    final s = dSlots[slot];
    if (s.gen != gen) return;
    if (s.need > 0) s.need--;
    s.pulse = 1;
    onSound?.call('deliver');
    final at = layout!.slotTileCenter(slot, dSlots.length);
    _burst(at, AppColors.tile(s.color), n: 4, power: 110);
  }

  // ------------------------------------------------------------ results
  int get stars {
    final par = lv.solution.length;
    if (moves <= (par * 1.15).ceil()) return 3;
    if (moves <= (par * 1.7).ceil()) return 2;
    return 1;
  }

  int get ordersDone => dDone;
  int get ordersTotal => lv.orders.length;

  /// Spawns a celebration at the board centre (used on win).
  void celebrate() {
    final L = layout;
    if (L == null) return;
    for (var i = 0; i < 5; i++) {
      _burst(Offset(L.size.width * (0.15 + 0.175 * i), L.size.height * 0.35),
          AppColors.tile(i), n: 18, power: 320);
    }
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    toast.dispose();
    super.dispose();
  }
}
