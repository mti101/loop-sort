import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_context.dart';
import 'game/engine.dart';
import 'services/storage.dart';
import 'theme.dart';
import 'ui/splash.dart';

Future<void> main() async {
  await runZonedGuarded(_boot, (e, st) => debugPrint('Unhandled: $e\n$st'));
}

Future<void> _boot() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (d) => debugPrint('FlutterError: ${d.exceptionAsString()}');
  ui.PlatformDispatcher.instance.onError = (e, st) {
    debugPrint('PlatformError: $e\n$st');
    return true;
  };
  try {
    await _start();
  } catch (e, st) {
    // Never leave the player on a blank screen: show what went wrong.
    runApp(_FatalScreen('$e\n\n$st'));
  }
}

class _FatalScreen extends StatelessWidget {
  const _FatalScreen(this.msg);
  final String msg;
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFF0A1C27),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Text('Startup error\n\n$msg',
                  style: const TextStyle(color: Colors.white, fontSize: 12)),
            ),
          ),
        ),
      );
}

Future<void> _start() async {
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  final store = await Store.load();
  final levels = parseLevels(await rootBundle.loadString('assets/levels/levels.json'));
  Ctx.I = Ctx(store, levels);
  runApp(const LoopSortApp());
}

class LoopSortApp extends StatelessWidget {
  const LoopSortApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Loop Sort',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const SplashScreen(),
    );
  }
}
