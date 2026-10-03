// Loop Sort puzzle engine. Mirrors tools/levelgen/engine.py exactly.
// A unit test replays the stored solution of every level through this code.

import 'dart:convert';

class Order {
  final int color;
  final int need;
  const Order(this.color, this.need);
}

class LevelData {
  final int id;
  final int colors;
  final int cap;
  final int slots;
  final List<List<int>> stacks; // front first
  final List<List<bool>> mystery; // same shape as stacks
  final List<int> locks;
  final List<Order> orders;
  final List<int> solution;
  final String tag;
  final double winRate;

  const LevelData({
    required this.id,
    required this.colors,
    required this.cap,
    required this.slots,
    required this.stacks,
    required this.mystery,
    required this.locks,
    required this.orders,
    required this.solution,
    required this.tag,
    required this.winRate,
  });

  factory LevelData.fromJson(Map<String, dynamic> j) {
    final st = (j['stacks'] as List).cast<Map<String, dynamic>>();
    return LevelData(
      id: j['id'] as int,
      colors: j['colors'] as int,
      cap: j['cap'] as int,
      slots: j['slots'] as int,
      stacks: [for (final s in st) (s['t'] as List).cast<int>().toList()],
      mystery: [
        for (final s in st) [for (final m in (s['m'] as List)) (m as int) == 1]
      ],
      locks: [for (final s in st) s['lock'] as int],
      orders: [
        for (final o in (j['orders'] as List))
          Order((o as List)[0] as int, o[1] as int)
      ],
      solution: (j['sol'] as List).cast<int>().toList(),
      tag: (j['tag'] ?? '') as String,
      winRate: ((j['wr'] ?? 0) as num).toDouble(),
    );
  }

  int get totalTiles => stacks.fold(0, (a, s) => a + s.length);
  bool get hasMystery => mystery.any((m) => m.contains(true));
  bool get hasLocks => locks.any((l) => l > 0);
  bool get isBoss => tag == 'boss';
}

List<LevelData> parseLevels(String jsonText) {
  final list = jsonDecode(jsonText) as List;
  return [for (final e in list) LevelData.fromJson(e as Map<String, dynamic>)];
}

class GameState {
  final List<List<int>> stacks;
  final List<int> loop; // tile count per colour
  final List<Order?> active;
  final int qi; // next queue index
  final int done; // completed orders
  final int cap;

  const GameState({
    required this.stacks,
    required this.loop,
    required this.active,
    required this.qi,
    required this.done,
    required this.cap,
  });

  int get loopCount {
    var n = 0;
    for (final c in loop) {
      n += c;
    }
    return n;
  }

  int get tilesLeft {
    var n = 0;
    for (final s in stacks) {
      n += s.length;
    }
    return n;
  }

  String get key {
    final b = StringBuffer();
    for (final s in stacks) {
      b.writeAll(s);
      b.write('|');
    }
    b.writeAll(loop, ',');
    b.write('|');
    for (final a in active) {
      b.write(a == null ? 'x' : '${a.color}:${a.need}');
      b.write(',');
    }
    b.write('|$qi|$done|$cap');
    return b.toString();
  }
}

enum EvType { send, absorb, complete }

/// Playback events emitted by [applyMove] so the UI can animate a move.
class Ev {
  final EvType type;
  final int stack; // send: source stack
  final int color; // send/absorb
  final int slot; // send: target slot or -1 (loop); absorb/complete: slot
  final Order? next; // complete: replacement order (null = slot empties)
  const Ev._(this.type, this.stack, this.color, this.slot, this.next);
  const Ev.send(int stack, int color, int slot)
      : this._(EvType.send, stack, color, slot, null);
  const Ev.absorb(int color, int slot)
      : this._(EvType.absorb, -1, color, slot, null);
  const Ev.complete(int slot, Order? next)
      : this._(EvType.complete, -1, -1, slot, next);
}

GameState initialState(LevelData lv) {
  final n = lv.slots < lv.orders.length ? lv.slots : lv.orders.length;
  return GameState(
    stacks: [for (final s in lv.stacks) List<int>.from(s)],
    loop: List<int>.filled(lv.colors, 0),
    active: [for (var i = 0; i < n; i++) lv.orders[i]],
    qi: n,
    done: 0,
    cap: lv.cap,
  );
}

bool isWin(LevelData lv, GameState st) => st.done == lv.orders.length;

int frontRun(List<int> s) {
  if (s.isEmpty) return 0;
  final c = s[0];
  var n = 1;
  while (n < s.length && s[n] == c) {
    n++;
  }
  return n;
}

bool isLocked(LevelData lv, GameState st, int i) => st.done < lv.locks[i];

/// Returns (qi, done) after absorbing loop tiles into active orders.
(int, int) _settle(LevelData lv, List<int> loop, List<Order?> active, int qi,
    int done, List<Ev>? ev) {
  var changed = true;
  while (changed) {
    changed = false;
    for (var j = 0; j < active.length; j++) {
      final a = active[j];
      if (a == null) continue;
      final c = a.color;
      var need = a.need;
      if (loop[c] > 0) {
        final take = loop[c] < need ? loop[c] : need;
        loop[c] -= take;
        need -= take;
        active[j] = Order(c, need);
        changed = true;
        if (ev != null) {
          for (var t = 0; t < take; t++) {
            ev.add(Ev.absorb(c, j));
          }
        }
        if (need == 0) {
          done += 1;
          Order? next;
          if (qi < lv.orders.length) {
            next = lv.orders[qi];
            qi += 1;
          }
          active[j] = next;
          ev?.add(Ev.complete(j, next));
        }
      }
    }
  }
  return (qi, done);
}

/// Applies a tap on stack [i]. Returns null if the move is illegal.
/// When [ev] is given it receives the playback events (only valid when the
/// result is non-null).
GameState? applyMove(LevelData lv, GameState st, int i, [List<Ev>? ev]) {
  final s = st.stacks[i];
  if (s.isEmpty || st.done < lv.locks[i]) return null;
  final c = s[0];
  final n = frontRun(s);
  final loop = List<int>.from(st.loop);
  final active = List<Order?>.from(st.active);
  var qi = st.qi;
  var done = st.done;
  for (var t = 0; t < n; t++) {
    var delivered = false;
    for (var j = 0; j < active.length; j++) {
      final a = active[j];
      if (a != null && a.color == c && a.need > 0) {
        final need = a.need - 1;
        active[j] = Order(c, need);
        ev?.add(Ev.send(i, c, j));
        delivered = true;
        if (need == 0) {
          done += 1;
          Order? next;
          if (qi < lv.orders.length) {
            next = lv.orders[qi];
            qi += 1;
          }
          active[j] = next;
          ev?.add(Ev.complete(j, next));
          final r = _settle(lv, loop, active, qi, done, ev);
          qi = r.$1;
          done = r.$2;
        }
        break;
      }
    }
    if (!delivered) {
      loop[c] += 1;
      ev?.add(Ev.send(i, c, -1));
    }
  }
  var total = 0;
  for (final x in loop) {
    total += x;
  }
  if (total > st.cap) return null;
  final newStacks = <List<int>>[];
  for (var k = 0; k < st.stacks.length; k++) {
    newStacks.add(k == i ? s.sublist(n) : st.stacks[k]);
  }
  return GameState(
      stacks: newStacks, loop: loop, active: active, qi: qi, done: done, cap: st.cap);
}

List<int> legalMoves(LevelData lv, GameState st) {
  final out = <int>[];
  for (var i = 0; i < st.stacks.length; i++) {
    if (applyMove(lv, st, i) != null) out.add(i);
  }
  return out;
}

/// Booster: extra order slot. Pulls the next queued order (if any) and lets
/// the loop absorb into it. Returns null when there is nothing left to add.
GameState? addSlot(LevelData lv, GameState st, [List<Ev>? ev]) {
  if (st.qi >= lv.orders.length) return null;
  final loop = List<int>.from(st.loop);
  final active = List<Order?>.from(st.active);
  active.add(lv.orders[st.qi]);
  final r = _settle(lv, loop, active, st.qi + 1, st.done, ev);
  return GameState(
      stacks: st.stacks, loop: loop, active: active, qi: r.$1, done: r.$2, cap: st.cap);
}

GameState addCapacity(GameState st, int extra) => GameState(
    stacks: st.stacks,
    loop: st.loop,
    active: st.active,
    qi: st.qi,
    done: st.done,
    cap: st.cap + extra);

// ---------------------------------------------------------------- solver

class SolveResult {
  final List<int>? moves;
  final bool budgetExceeded;
  const SolveResult(this.moves, this.budgetExceeded);
}

class _Budget implements Exception {}

class _Solver {
  final LevelData lv;
  final int budget;
  final Set<String> dead = {};
  int nodes = 0;
  _Solver(this.lv, this.budget);

  List<int>? solve(GameState st) {
    if (isWin(lv, st)) return const [];
    final k = st.key;
    if (dead.contains(k)) return null;
    nodes++;
    if (nodes > budget) throw _Budget();
    final moves = <(int, GameState)>[];
    for (var i = 0; i < st.stacks.length; i++) {
      final ns = applyMove(lv, st, i);
      if (ns != null) moves.add((i, ns));
    }
    final base = st.tilesLeft;
    moves.sort((a, b) {
      final da = a.$2.tilesLeft - base;
      final db = b.$2.tilesLeft - base;
      if (da != db) return da.compareTo(db);
      return a.$2.loopCount.compareTo(b.$2.loopCount);
    });
    for (final m in moves) {
      final r = solve(m.$2);
      if (r != null) return [m.$1, ...r];
    }
    dead.add(k);
    return null;
  }
}

/// Finds a winning line from [st] (used for hints). Pure; safe in an isolate.
SolveResult solveFrom(LevelData lv, GameState st, {int budget = 150000}) {
  final s = _Solver(lv, budget);
  try {
    return SolveResult(s.solve(st), false);
  } on _Budget {
    return const SolveResult(null, true);
  }
}
