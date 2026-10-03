import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:loopsort/game/engine.dart';

void main() {
  late List<LevelData> levels;

  setUpAll(() {
    levels = parseLevels(File('assets/levels/levels.json').readAsStringSync());
  });

  test('has 200 levels', () => expect(levels.length, 200));

  test('every stored solution wins when replayed (Python/Dart parity)', () {
    for (final lv in levels) {
      var st = initialState(lv);
      for (final i in lv.solution) {
        final ns = applyMove(lv, st, i);
        expect(ns, isNotNull, reason: 'level ${lv.id}: illegal move $i');
        st = ns!;
      }
      expect(isWin(lv, st), true, reason: 'level ${lv.id} not won');
      expect(st.tilesLeft, 0);
      expect(st.loopCount, 0);
    }
  });

  test('tile and order totals are consistent', () {
    for (final lv in levels) {
      final tiles = List<int>.filled(lv.colors, 0);
      for (final s in lv.stacks) {
        for (final c in s) {
          tiles[c]++;
        }
      }
      final need = List<int>.filled(lv.colors, 0);
      for (final o in lv.orders) {
        need[o.color] += o.need;
      }
      expect(tiles, need, reason: 'level ${lv.id}');
      for (var i = 0; i < lv.stacks.length; i++) {
        expect(lv.mystery[i].length, lv.stacks[i].length);
        expect(lv.mystery[i][0], false);
      }
    }
  });

  test('events replay to the same state as applyMove', () {
    for (final lv in levels.take(60)) {
      var st = initialState(lv);
      for (final i in lv.solution) {
        final ev = <Ev>[];
        final ns = applyMove(lv, st, i, ev)!;
        // Rebuild from events
        final loop = List<int>.from(st.loop);
        final active = List<Order?>.from(st.active);
        final stacks = [for (final s in st.stacks) List<int>.from(s)];
        for (final e in ev) {
          switch (e.type) {
            case EvType.send:
              stacks[e.stack].removeAt(0);
              if (e.slot >= 0) {
                final a = active[e.slot]!;
                active[e.slot] = Order(a.color, a.need - 1);
              } else {
                loop[e.color]++;
              }
              break;
            case EvType.absorb:
              loop[e.color]--;
              final a = active[e.slot]!;
              active[e.slot] = Order(a.color, a.need - 1);
              break;
            case EvType.complete:
              active[e.slot] = e.next;
              break;
          }
        }
        expect(loop, ns.loop, reason: 'level ${lv.id} loop');
        for (var k = 0; k < stacks.length; k++) {
          expect(stacks[k], ns.stacks[k]);
        }
        for (var k = 0; k < active.length; k++) {
          expect(active[k]?.color, ns.active[k]?.color);
          expect(active[k]?.need, ns.active[k]?.need);
        }
        st = ns;
      }
    }
  });

  test('solver finds a line from the start of early levels', () {
    for (final lv in levels.take(15)) {
      final r = solveFrom(lv, initialState(lv));
      expect(r.moves, isNotNull, reason: 'level ${lv.id}');
    }
  });

  test('overflow move is rejected', () {
    final lv = levels.first;
    var st = initialState(lv);
    st = addCapacity(st, -st.cap); // cap 0
    // any move that puts a tile on the loop must fail; moves that fully
    // deliver stay legal.
    for (var i = 0; i < st.stacks.length; i++) {
      final ns = applyMove(lv, st, i);
      if (ns != null) expect(ns.loopCount, 0);
    }
  });
}
