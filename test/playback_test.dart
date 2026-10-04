import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loopsort/game/board_painter.dart';
import 'package:loopsort/game/controller.dart';
import 'package:loopsort/game/engine.dart';
import 'package:loopsort/game/layout.dart';

const _size = Size(360, 560);

void _paint(GameController g) {
  final rec = ui.PictureRecorder();
  BoardPainter(g).paint(Canvas(rec), _size);
  rec.endRecording().dispose();
}

void _settle(GameController g, {int max = 900}) {
  for (var k = 0; k < max && g.busy; k++) {
    g.update(1 / 60);
  }
}

List<List<int>> _display(GameController g) => [
      for (final s in g.slots) [for (final t in s.tiles) t.color]
    ];

void main() {
  late List<LevelData> levels;
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    levels = parseLevels(File('assets/levels/levels.json').readAsStringSync());
  });

  test('geometry: gates are ordered along the belt for every level', () {
    for (final lv in levels) {
      final geo = BoardGeometry.build(lv, _size);
      expect(geo.slots.length, lv.slotCount);
      // gate arcs must increase with slot index (cyclically, one wrap at most)
      var wraps = 0;
      for (var i = 0; i < geo.slots.length; i++) {
        final a = geo.slots[i].gateArc;
        final b = geo.slots[(i + 1) % geo.slots.length].gateArc;
        if (b < a) wraps++;
      }
      expect(wraps, lessThanOrEqualTo(1), reason: 'level ${lv.id} (${lv.layout}) slot order vs belt arcs');
      for (final s in geo.slots) {
        expect(geo.bounds.inflate(4).contains(s.base), isTrue, reason: 'level ${lv.id} slot outside bounds');
      }
    }
  });

  test('headless playback of every level ends in a won, consistent view', () {
    for (final lv in levels) {
      final g = GameController(lv);
      g.setSize(_size);
      var won = false;
      g.onWin = () => won = true;
      var n = 0;
      for (final m in lv.solution) {
        g.tapSlot(m);
        _settle(g);
        expect(_display(g), g.state.slots, reason: 'level ${lv.id} after tap $n: display != logic');
        if (n++ % 3 == 0) _paint(g);
      }
      for (var k = 0; k < 300 && !won; k++) {
        g.update(1 / 60);
      }
      expect(won, true, reason: 'level ${lv.id} did not reach win state');
      expect(g.status, GameStatus.won);
      expect(g.belt, isEmpty, reason: 'level ${lv.id} belt not empty');
      expect(g.moves, lv.solution.length);
      g.dispose();
    }
  });

  test('undo restores state and view', () {
    for (final lv in levels.where((l) => l.id % 9 == 4)) {
      final g = GameController(lv);
      g.setSize(_size);
      final start = _display(g);
      g.tapSlot(lv.solution.first);
      _settle(g);
      expect(g.canUndo, true);
      g.undo();
      expect(_display(g), start, reason: 'level ${lv.id}');
      expect(g.belt, isEmpty);
      expect(g.moves, 0);
      _paint(g);
      g.dispose();
    }
  });

  test('belt capacity booster raises the limit', () {
    final lv = levels[5];
    final g = GameController(lv);
    g.setSize(_size);
    final c = g.beltCap;
    g.addBeltCapacity(2);
    expect(g.beltCap, c + 2);
    g.dispose();
  });
}
