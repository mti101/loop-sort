import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:loopsort/game/engine.dart';

List<LevelData> load() => parseLevels(File('assets/levels/levels.json').readAsStringSync());

void main() {
  final levels = load();

  test('has 200 levels', () => expect(levels.length, 200));

  test('every stored solution wins when replayed (Python/Dart parity)', () {
    for (final lv in levels) {
      var st = initialState(lv);
      for (final m in lv.solution) {
        expect(legalMoves(lv, st).contains(m), isTrue, reason: 'level ${lv.id} illegal move $m');
        st = applyMove(lv, st, m).state;
      }
      expect(isWin(lv, st), isTrue, reason: 'level ${lv.id} not won');
    }
  });

  test('tile counts are consistent', () {
    for (final lv in levels) {
      final counts = <int, int>{};
      for (final s in lv.slots) {
        expect(s.length <= lv.capacity, isTrue, reason: 'level ${lv.id}');
        for (final c in s) {
          counts[c] = (counts[c] ?? 0) + 1;
        }
      }
      expect(counts.length, lv.colors, reason: 'level ${lv.id}');
      for (final n in counts.values) {
        expect(n, lv.capacity, reason: 'level ${lv.id} colour count');
      }
      expect(lv.slots.length >= lv.colors, isTrue);
    }
  });

  test('applyMove drop list is consistent with the resulting state', () {
    for (final lv in levels.take(40)) {
      var st = initialState(lv);
      for (final m in lv.solution) {
        final before = st.belt.length;
        final r = applyMove(lv, st, m);
        expect(r.drops.length + r.stayIndices.length, before + r.run);
        st = r.state;
      }
    }
  });

  test('overfull belt move is rejected', () {
    final lv = levels.first.withBeltCap(1);
    expect(legalMoves(lv, initialState(lv)).isEmpty, isTrue);
  });

  test('solver finds a line from the start of early levels', () {
    for (final lv in levels.take(12)) {
      final r = solveFrom(lv, initialState(lv));
      expect(r.moves, isNotNull, reason: 'level ${lv.id}');
    }
  });
}
