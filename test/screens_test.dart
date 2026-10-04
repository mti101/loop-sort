import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loopsort/app_context.dart';
import 'package:loopsort/game/board_painter.dart';
import 'package:loopsort/game/engine.dart';
import 'package:loopsort/game/layout.dart';
import 'package:loopsort/services/storage.dart';
import 'package:loopsort/theme.dart';
import 'package:loopsort/ui/dialogs.dart';
import 'package:loopsort/ui/game_screen.dart';
import 'package:loopsort/ui/home_screen.dart';
import 'package:loopsort/ui/level_select.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget app(Widget home) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: home,
    );

Future<void> shot(WidgetTester tester, String name) async {
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final font = FontLoader('Lilita')
      ..addFont(Future.value(ByteData.view(File('assets/fonts/LilitaOne-Regular.ttf').readAsBytesSync().buffer)));
    await font.load();
    final root = Platform.environment['FLUTTER_ROOT'] ?? '';
    final mi = File('$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (mi.existsSync()) {
      final icons = FontLoader('MaterialIcons')
        ..addFont(Future.value(ByteData.view(mi.readAsBytesSync().buffer)));
      await icons.load();
    }
  });

  Future<void> setup(WidgetTester tester, {Map<String, Object> prefs = const {}}) async {
    SharedPreferences.setMockInitialValues(prefs);
    final store = await Store.load();
    final levels = parseLevels(File('assets/levels/levels.json').readAsStringSync());
    Ctx.I = Ctx(store, levels);
    Ctx.I.sfx.enabled = false;
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('home screen', (tester) async {
    await setup(tester, prefs: {'dailyLastDay': Store.dayIndex(DateTime.now())});
    await tester.pumpWidget(app(const HomeScreen()));
    await tester.pump(const Duration(milliseconds: 600));
    await shot(tester, '01_home');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('level select', (tester) async {
    await setup(tester, prefs: {'maxLevel': 23, 'stars': '{"1":3,"2":3,"3":2,"4":3,"5":1,"6":3,"7":2,"8":3,"9":3,"10":3,"11":2,"12":3,"13":3,"14":1,"15":3,"16":3,"17":2,"18":3,"19":3,"20":2,"21":3,"22":1}'});
    await tester.pumpWidget(app(const LevelSelectScreen()));
    await tester.pump(const Duration(milliseconds: 300));
    await shot(tester, '02_levels');
    await tester.pumpWidget(const SizedBox());
  });

  for (final n in [1, 2, 3, 4, 5, 12, 40, 100, 180]) {
    testWidgets('game level $n', (tester) async {
      await setup(tester, prefs: {
        'maxLevel': 200,
        'tips': n <= 5 ? <String>[] : ['tap', 'match', 'full', 'undo', 'plan', 'hintb', 'beltb', 'mystery']
      });
      await tester.pumpWidget(app(GameScreen(level: n)));
      await tester.pump(const Duration(milliseconds: 700));
      await shot(tester, '10_game_L${n}_start');
      final lv = Ctx.I.level(n);
      final boardFinder = find.byWidgetPredicate((w) => w is CustomPaint && w.painter is BoardPainter);
      final box = tester.getRect(boardFinder);
      final geo = BoardGeometry.build(lv, box.size);
      for (var k = 0; k < 2 && k < lv.solution.length; k++) {
        final c = geo.slots[lv.solution[k]].center;
        await tester.tapAt(box.topLeft + c);
        await tester.pump(const Duration(milliseconds: 650));
      }
      await shot(tester, '11_game_L${n}_moves');
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    });
  }

  testWidgets('dialogs', (tester) async {
    await setup(tester);
    final dialogs = <String, Widget>{
      '20_dialog_win': const WinDialog(level: 12, stars: 3, coins: 60, last: false),
      '21_dialog_stuck': const StuckDialog(deadEnd: false, canUndo: true),
      '22_dialog_shop': const ShopDialog(),
      '23_dialog_daily': const DailyDialog(),
      '24_dialog_settings': const SettingsDialog(),
      '25_dialog_pause': const PauseDialog(),
      '26_dialog_booster': const BoosterOfferDialog(booster: Booster.hint),
    };
    for (final e in dialogs.entries) {
      await tester.pumpWidget(app(Scaffold(
        body: Container(
          color: const Color(0xFF0A1C27),
          alignment: Alignment.center,
          child: e.value,
        ),
      )));
      await tester.pump(const Duration(milliseconds: 1600));
      await shot(tester, e.key);
    }
    await tester.pumpWidget(const SizedBox());
  });
}
