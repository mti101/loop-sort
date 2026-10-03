import 'dart:async';

import 'package:flutter/material.dart';

import '../app_context.dart';
import '../theme.dart';
import 'home_screen.dart';
import 'widgets/kit.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final ctx = Ctx.I;
    ctx.sfx.enabled = ctx.store.sound;
    ctx.sfx.hapticsEnabled = ctx.store.haptics;
    final started = DateTime.now();
    try {
      await ctx.sfx.init();
    } catch (_) {}
    unawaited(ctx.iap.init());
    try {
      // Shows the consent form on first launch where required.
      await ctx.ads.init().timeout(const Duration(seconds: 16), onTimeout: () {});
    } catch (_) {}
    final spent = DateTime.now().difference(started).inMilliseconds;
    if (spent < 1400) await Future<void>.delayed(Duration(milliseconds: 1400 - spent));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(PageRouteBuilder<void>(
      pageBuilder: (_, __, ___) => const HomeScreen(),
      transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
      transitionDuration: const Duration(milliseconds: 400),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: GameBackground(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LogoMark(scale: 1.15),
              SizedBox(height: 10),
              Mascot(size: 140),
              SizedBox(height: 26),
              SizedBox(
                width: 150,
                child: LinearProgressIndicator(
                  minHeight: 8,
                  borderRadius: BorderRadius.all(Radius.circular(6)),
                  color: AppColors.amber,
                  backgroundColor: Color(0xFF0B2230),
                ),
              ),
              SizedBox(height: 10),
              Text('Loading...', style: TextStyle(fontFamily: kFont, fontSize: 16, color: AppColors.textDim)),
            ],
          ),
        ),
      ),
    );
  }
}
