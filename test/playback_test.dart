import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loopsort/game/board_painter.dart';
import 'package:loopsort/game/controller.dart';
import 'package:loopsort/game/engine.dart';

void main() {
  late List<LevelData> levels;
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    levels = parseLevels(File('assets/levels/levels.json').readAsStringSync());
  });

  void paintOnce(GameController g, Size size) {
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    BoardPainter(g).paint(canvas, size);
    rec.endRecording().dispose();
  }

  test('headless playback of every level ends in a won, consistent view', () {
    const size = Size(360, 560);
    for (final lv in levels) {
      final g = GameController(lv);
      g.setSize(size);
      var won = false;
      g.onWin = () => won = true;
      var frames = 0;
      for (final i in lv.solution) {
        g.tapStack(i);
        // let the animation breathe a few frames between taps
        for (var k = 0; k < 6; k++) {
          g.update(1 / 60);
          frames++;
          if (frames % 25 == 0) paintOnce(g, size);
        }
      }
      for (var k = 0; k < 600 && !won; k++) {
        g.update(1 / 60);
        if (k % 40 == 0) paintOnce(g, size);
      }
      expect(won, true, reason: 'level ${lv.id} did not reach win state');
      expect(g.status, GameStatus.won);
      expect(g.dLoop.length, 0, reason: 'level ${lv.id} loop not empty');
      for (final s in g.dStacks) {
        expect(s, isEmpty, reason: 'level ${lv.id}');
      }
      expect(g.moves, lv.solution.length);
      g.dispose();
    }
  });

  test('display model matches logic state after each settled move', () {
    const size = Size(360, 560);
    for (final lv in levels.where((l) => l.id % 7 == 0)) {
      final g = GameController(lv);
      g.setSize(size);
      for (final i in lv.solution) {
        g.tapStack(i);
        for (var k = 0; k < 160; k++) {
          g.update(1 / 60);
        }
        if (g.status == GameStatus.won) break;
        expect(g.dLoop.length, g.state.loopCount, reason: 'level ${lv.id} loop');
        for (var s = 0; s < g.dStacks.length; s++) {
          expect(g.dStacks[s], g.state.stacks[s], reason: 'level ${lv.id} stack $s');
        }
        for (var j = 0; j < g.state.active.length; j++) {
          final a = g.state.active[j];
          if (a == null) {
            expect(g.dSlots[j].empty, true);
          } else {
            expect(g.dSlots[j].need, a.need, reason: 'level ${lv.id} slot $j');
          }
        }
        expect(g.dDone, g.state.done);
      }
      g.dispose();
    }
  });

  test('undo restores state and view', () {
    final lv = levels[9];
    final g = GameController(lv);
    g.setSize(const Size(360, 560));
    g.tapStack(lv.solution[0]);
    for (var k = 0; k < 120; k++) {
      g.update(1 / 60);
    }
    expect(g.moves, 1);
    expect(g.undo(), true);
    expect(g.moves, 0);
    for (var s = 0; s < g.dStacks.length; s++) {
      expect(g.dStacks[s], lv.stacks[s]);
    }
    g.dispose();
  });

  test('extra slot and extra capacity boosters keep view in sync', () {
    final lv = levels[20];
    final g = GameController(lv);
    g.setSize(const Size(360, 560));
    final slotsBefore = g.dSlots.length;
    expect(g.addOrderSlot(), true);
    for (var k = 0; k < 200; k++) {
      g.update(1 / 60);
    }
    expect(g.dSlots.length, slotsBefore + 1);
    expect(g.state.active.length, slotsBefore + 1);
    g.addLoopCapacity(2);
    expect(g.dCap, lv.cap + 2);
    g.dispose();
  });
}
