import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_context.dart';
import 'game/engine.dart';
import 'services/storage.dart';
import 'theme.dart';
import 'ui/splash.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
