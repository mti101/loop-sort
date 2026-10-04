import 'package:flutter/material.dart';

import '../app_context.dart';
import '../config.dart';
import '../theme.dart';
import 'dialogs.dart';
import 'game_screen.dart';
import 'level_select.dart';
import 'widgets/kit.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);
  bool _dailyShown = false;

  Ctx get ctx => Ctx.I;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (ctx.store.dailyAvailable && !_dailyShown) {
        _dailyShown = true;
        await Future<void>.delayed(const Duration(milliseconds: 500));
        if (mounted) _openDaily();
      }
    });
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _play() async {
    final store = ctx.store;
    store.refreshLives();
    if (store.lives <= 0) {
      final ok = await showGameDialog<bool>(context, (_) => const NoLivesDialog());
      if (ok != true || !mounted) return;
    }
    if (!mounted) return;
    await Navigator.of(context).push(_route(GameScreen(level: store.maxLevel)));
    if (mounted) setState(() {});
  }

  PageRoute<void> _route(Widget w) => PageRouteBuilder<void>(
        pageBuilder: (_, __, ___) => w,
        transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 250),
      );

  Future<void> _openDaily() async {
    await showGameDialog<void>(context, (_) => const DailyDialog());
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final store = ctx.store;
    return Scaffold(
      body: GameBackground(
        child: SafeArea(
          child: ListenableBuilder(
            listenable: store,
            builder: (context, _) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Row(
                    children: [
                      LivesBadge(store: store, onTap: () => showGameDialog<void>(context, (_) => const NoLivesDialog())),
                      const Spacer(),
                      CoinBadge(store: store, onTap: () => showGameDialog<void>(context, (_) => const ShopDialog())),
                    ],
                  ),
                ),
                const Spacer(flex: 2),
                const LogoMark(scale: 1.1),
                const SizedBox(height: 4),
                const HeroArt(width: 290),
                const Spacer(flex: 2),
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, child) => Transform.scale(scale: 1 + 0.03 * _pulse.value, child: child),
                  child: GameButton(
                    label: 'PLAY',
                    sub: 'Level ${store.maxLevel}',
                    width: 250,
                    height: 82,
                    fontSize: 42,
                    onTap: _play,
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _HomeIcon(icon: Icons.grid_view_rounded, label: 'Levels', color: AppColors.blue, onTap: () async {
                      await Navigator.of(context).push(_route(const LevelSelectScreen()));
                      if (mounted) setState(() {});
                    }),
                    const SizedBox(width: 14),
                    _HomeIcon(icon: Icons.card_giftcard_rounded, label: 'Daily', color: AppColors.amber, badge: store.dailyAvailable, onTap: _openDaily),
                    const SizedBox(width: 14),
                    _HomeIcon(icon: Icons.storefront_rounded, label: 'Shop', color: AppColors.green, onTap: () => showGameDialog<void>(context, (_) => const ShopDialog())),
                    const SizedBox(width: 14),
                    _HomeIcon(icon: Icons.settings_rounded, label: 'Settings', color: const Color(0xFF5C8AA3), onTap: () => showGameDialog<void>(context, (_) => const SettingsDialog())),
                  ],
                ),
                const Spacer(),
                Text('${AppConfig.appName} by ${AppConfig.companyName}', style: gameText(12, color: AppColors.textDim.withAlpha(140))),
                const SizedBox(height: 6),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeIcon extends StatelessWidget {
  const _HomeIcon({required this.icon, required this.label, required this.color, required this.onTap, this.badge = false});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool badge;
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        RoundIconButton(icon: icon, onTap: onTap, color: color, size: 58, badge: badge),
        const SizedBox(height: 2),
        Text(label, style: gameText(13, color: AppColors.textDim)),
      ],
    );
  }
}
