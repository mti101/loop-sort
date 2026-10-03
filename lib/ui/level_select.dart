import 'package:flutter/material.dart';

import '../app_context.dart';
import '../config.dart';
import '../theme.dart';
import 'dialogs.dart';
import 'game_screen.dart';
import 'widgets/kit.dart';

class LevelSelectScreen extends StatefulWidget {
  const LevelSelectScreen({super.key});
  @override
  State<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends State<LevelSelectScreen> {
  late final ScrollController _sc;
  static const cols = 4;

  @override
  void initState() {
    super.initState();
    final row = ((Ctx.I.store.maxLevel - 1) ~/ cols);
    _sc = ScrollController(initialScrollOffset: (row * 96.0 - 160).clamp(0, 99999).toDouble());
  }

  @override
  void dispose() {
    _sc.dispose();
    super.dispose();
  }

  Future<void> _open(int level) async {
    final store = Ctx.I.store;
    if (level > store.maxLevel) {
      snack(context, 'Finish level ${store.maxLevel} first!');
      return;
    }
    store.refreshLives();
    if (store.lives <= 0) {
      final ok = await showGameDialog<bool>(context, (_) => const NoLivesDialog());
      if (ok != true || !mounted) return;
    }
    if (!mounted) return;
    await Navigator.of(context).push(PageRouteBuilder<void>(
      pageBuilder: (_, __, ___) => GameScreen(level: level),
      transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
      transitionDuration: const Duration(milliseconds: 250),
    ));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final store = Ctx.I.store;
    return Scaffold(
      body: GameBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                child: Row(
                  children: [
                    RoundIconButton(icon: Icons.arrow_back_rounded, onTap: () => Navigator.of(context).pop(), size: 44),
                    const Expanded(child: Center(child: OutlinedText('LEVELS', size: 34))),
                    Container(
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                          color: const Color(0xFF0B2230),
                          borderRadius: BorderRadius.circular(19),
                          border: Border.all(color: AppColors.panelEdge, width: 2)),
                      child: Row(children: [
                        const Icon(Icons.star_rounded, color: AppColors.amber, size: 24),
                        const SizedBox(width: 4),
                        Text('${store.totalStars}', style: gameText(20)),
                      ]),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: GridView.builder(
                  controller: _sc,
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 20),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    mainAxisExtent: 84,
                  ),
                  itemCount: AppConfig.totalLevels,
                  itemBuilder: (context, i) {
                    final n = i + 1;
                    return _LevelCell(
                      level: n,
                      unlocked: n <= store.maxLevel,
                      current: n == store.maxLevel,
                      stars: store.starsFor(n),
                      boss: Ctx.I.level(n).isBoss,
                      onTap: () => _open(n),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LevelCell extends StatelessWidget {
  const _LevelCell({
    required this.level,
    required this.unlocked,
    required this.current,
    required this.stars,
    required this.boss,
    required this.onTap,
  });
  final int level;
  final bool unlocked;
  final bool current;
  final int stars;
  final bool boss;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final base = !unlocked
        ? const Color(0xFF3C5A6B)
        : current
            ? AppColors.amber
            : (stars > 0 ? AppColors.blue : const Color(0xFF3E86B5));
    final dark = AppColors.shade(base, -0.22);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: base,
          border: Border.all(color: dark, width: 3),
          boxShadow: [BoxShadow(color: dark, offset: const Offset(0, 4))],
          gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppColors.shade(base, 0.1), base]),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!unlocked)
              const Icon(Icons.lock_rounded, color: Colors.white60, size: 30)
            else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (boss) const Icon(Icons.whatshot_rounded, color: AppColors.red, size: 20),
                  OutlinedText('$level', size: 28, outline: dark, outlineWidth: 5, shadowDepth: 1),
                ],
              ),
              const SizedBox(height: 2),
              StarsRow(count: stars, size: 16),
            ],
          ],
        ),
      ),
    );
  }
}
