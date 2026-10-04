// Loop Sort puzzle engine v2. Mirrors tools/levelgen/engine.py exactly.
//
// Slots hold stacks of tiles (index 0 = top, the end next to the belt).
// Tapping a slot lifts its top same-colour run onto a looping conveyor.
// Slot i sits at belt position i; the belt flows i -> i+1 -> ... -> 0.
// A belt tile drops into the first slot it passes whose top colour matches
// (or that is empty) and that is not full. A full single-colour slot is
// complete. Win: every tile is in a complete slot. Lose: no legal move.

import 'dart:convert';

class LevelData {
  LevelData({
    required this.id,
    required this.layout,
    required this.shape,
    required this.capacity,
    required this.beltCap,
    required this.colors,
    required this.slots,
    required this.mystery,
    required this.solution,
    required this.par,
    required this.tag,
    required this.winRate,
  });

  final int id;
  final String layout; // bar | ring | rows | split | dual
  final String shape; // round | oct | bump | pill | tear
  final int capacity; // slot capacity (tiles)
  final int beltCap; // belt capacity (tiles)
  final int colors;
  final List<List<int>> slots; // top first
  final List<List<bool>> mystery;
  final List<int> solution;
  final int par;
  final String tag;
  final double winRate;

  LevelData withBeltCap(int cap) => LevelData(
        id: id, layout: layout, shape: shape, capacity: capacity, beltCap: cap, colors: colors,
        slots: slots, mystery: mystery, solution: solution, par: par, tag: tag, winRate: winRate);

  int get slotCount => slots.length;
  bool get hasMystery => mystery.any((m) => m.any((b) => b));
  bool get isBoss => tag == 'boss';
  bool get isBreather => tag == 'breather';
  int get tileCount => slots.fold(0, (a, s) => a + s.length);

  factory LevelData.fromJson(Map<String, dynamic> j) {
    final slots = [for (final s in j['slots'] as List) [for (final c in s as List) c as int]];
    final mys = [for (final s in j['mys'] as List) [for (final c in s as List) (c as int) != 0]];
    return LevelData(
      id: j['n'] as int,
      layout: j['layout'] as String,
      shape: j['shape'] as String,
      capacity: j['C'] as int,
      beltCap: j['cap'] as int,
      colors: j['K'] as int,
      slots: slots,
      mystery: mys,
      solution: [for (final m in j['sol'] as List) m as int],
      par: (j['par'] as int?) ?? (j['sol'] as List).length,
      tag: (j['tag'] as String?) ?? '',
      winRate: (j['wr'] as num?)?.toDouble() ?? 1.0,
    );
  }
}

List<LevelData> parseLevels(String json) {
  final list = jsonDecode(json) as List;
  return [for (final j in list) LevelData.fromJson(j as Map<String, dynamic>)];
}

class BeltTile {
  const BeltTile(this.color, this.next);
  final int color;
  final int next; // gate (slot index) it reaches next
}

class GameState {
  GameState(this.slots, this.belt);
  final List<List<int>> slots;
  final List<BeltTile> belt;

  String get key {
    final sb = StringBuffer();
    for (final s in slots) {
      sb.write(s.join(','));
      sb.write('|');
    }
    sb.write('#');
    for (final b in belt) {
      sb.write('${b.color}.${b.next},');
    }
    return sb.toString();
  }
}

/// One tile leaving the belt into a slot (index refers to the belt list
/// that existed before settling: old tiles first, then the new run).
class Drop {
  const Drop(this.beltIndex, this.slot);
  final int beltIndex;
  final int slot;
}

class MoveResult {
  MoveResult(this.state, this.run, this.drops, this.stayIndices);
  final GameState state;
  final int run; // number of tiles lifted
  final List<Drop> drops;
  final List<int> stayIndices; // pre-settle belt indices still riding (in order)
}

bool isComplete(List<int> s, int cap) {
  if (s.length != cap) return false;
  for (final c in s) {
    if (c != s[0]) return false;
  }
  return true;
}

int runLen(List<int> s) {
  if (s.isEmpty) return 0;
  var n = 1;
  while (n < s.length && s[n] == s[0]) {
    n++;
  }
  return n;
}

bool accepts(List<int> s, int c, int cap) {
  if (s.length >= cap) return false;
  return s.isEmpty || s[0] == c;
}

GameState initialState(LevelData lv) =>
    GameState([for (final s in lv.slots) List<int>.of(s)], const []);

bool isWin(LevelData lv, GameState st) {
  if (st.belt.isNotEmpty) return false;
  for (final s in st.slots) {
    if (s.isNotEmpty && !isComplete(s, lv.capacity)) return false;
  }
  return true;
}

List<int> legalMoves(LevelData lv, GameState st) {
  final free = lv.beltCap - st.belt.length;
  final out = <int>[];
  for (var i = 0; i < st.slots.length; i++) {
    final s = st.slots[i];
    if (s.isEmpty || isComplete(s, lv.capacity)) continue;
    if (runLen(s) <= free) out.add(i);
  }
  return out;
}

bool canTap(LevelData lv, GameState st, int i) => legalMoves(lv, st).contains(i);

/// Applies tapping slot [i]. Returns drops for animation.
MoveResult applyMove(LevelData lv, GameState st, int i) {
  final n = st.slots.length;
  final slots = [for (final s in st.slots) List<int>.of(s)];
  final r = runLen(slots[i]);
  final run = slots[i].sublist(0, r);
  slots[i] = slots[i].sublist(r);
  final nxt = (i + 1) % n;
  // belt entries: [color, next, originalIndex]
  var belt = <List<int>>[
    for (var k = 0; k < st.belt.length; k++) [st.belt[k].color, st.belt[k].next, k],
    for (var k = 0; k < r; k++) [run[k], nxt, st.belt.length + k],
  ];
  final drops = <Drop>[];
  var idle = 0;
  while (belt.isNotEmpty && idle < n) {
    var dropped = false;
    final nb = <List<int>>[];
    for (final t in belt) {
      final g = t[1];
      if (accepts(slots[g], t[0], lv.capacity)) {
        slots[g].insert(0, t[0]);
        drops.add(Drop(t[2], g));
        dropped = true;
      } else {
        t[1] = (g + 1) % n;
        nb.add(t);
      }
    }
    belt = nb;
    idle = dropped ? 0 : idle + 1;
  }
  return MoveResult(
    GameState(slots, [for (final t in belt) BeltTile(t[0], t[1])]),
    r,
    drops,
    [for (final t in belt) t[2]],
  );
}

class SolveResult {
  const SolveResult(this.moves, this.exhausted);
  final List<int>? moves; // a winning line, or null
  final bool exhausted; // true when null means "provably unsolvable"
}

/// Depth-first solver used for hints and dead-end detection.
SolveResult solveFrom(LevelData lv, GameState st, {int budget = 60000}) {
  final seen = <String>{};
  var nodes = 0;
  List<int>? dfs(GameState s) {
    if (isWin(lv, s)) return <int>[];
    final k = s.key;
    if (!seen.add(k)) return null;
    if (++nodes > budget) throw _Budget();
    final cand = <(int, int, GameState)>[];
    for (final m in legalMoves(lv, s)) {
      final ns = applyMove(lv, s, m).state;
      if (seen.contains(ns.key)) continue;
      var h = ns.belt.length;
      for (final sl in ns.slots) {
        if (sl.isNotEmpty && !isComplete(sl, lv.capacity)) h++;
      }
      cand.add((h, m, ns));
    }
    cand.sort((a, b) => a.$1.compareTo(b.$1));
    for (final c in cand) {
      final r = dfs(c.$3);
      if (r != null) return [c.$2, ...r];
    }
    return null;
  }

  try {
    final r = dfs(st);
    return SolveResult(r, r == null);
  } on _Budget {
    return const SolveResult(null, false);
  }
}

class _Budget implements Exception {}
