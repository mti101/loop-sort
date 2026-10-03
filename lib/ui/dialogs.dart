import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_context.dart';
import '../config.dart';
import '../services/storage.dart';
import '../theme.dart';
import 'widgets/kit.dart';

// ---------------------------------------------------------------- helpers

String boosterName(Booster b) {
  switch (b) {
    case Booster.undo:
      return 'Undo';
    case Booster.hint:
      return 'Hint';
    case Booster.loop:
      return 'Loop +2';
    case Booster.slot:
      return 'Extra Order';
  }
}

IconData boosterIcon(Booster b) {
  switch (b) {
    case Booster.undo:
      return Icons.undo_rounded;
    case Booster.hint:
      return Icons.lightbulb_rounded;
    case Booster.loop:
      return Icons.all_inclusive_rounded;
    case Booster.slot:
      return Icons.add_box_rounded;
  }
}

Color boosterColor(Booster b) {
  switch (b) {
    case Booster.undo:
      return AppColors.blue;
    case Booster.hint:
      return AppColors.amber;
    case Booster.loop:
      return AppColors.green;
    case Booster.slot:
      return const Color(0xFFA66CFF);
  }
}

String boosterDesc(Booster b) {
  switch (b) {
    case Booster.undo:
      return 'Take back your last move';
    case Booster.hint:
      return 'Shows a winning move';
    case Booster.loop:
      return 'Adds 2 spaces to the loop';
    case Booster.slot:
      return 'Opens one more order slot';
  }
}

void snack(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(msg, style: gameText(18)),
      backgroundColor: AppColors.panel,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
}

/// Plays a rewarded ad; returns true when the reward was earned.
Future<bool> watchAd(BuildContext context) async {
  final ads = Ctx.I.ads;
  if (!ads.rewardedReady) {
    ads.preload();
    snack(context, 'No ad available right now. Try again in a moment.');
    return false;
  }
  final ok = await ads.showRewarded();
  if (!ok && context.mounted) snack(context, 'Watch the full ad to get the reward.');
  return ok;
}

Future<void> openUrl(String url) async {
  try {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {}
}

// ---------------------------------------------------------------- frame

class DialogFrame extends StatelessWidget {
  const DialogFrame({super.key, required this.title, required this.child, this.onClose, this.width = 330, this.titleColor});
  final String title;
  final Widget child;
  final VoidCallback? onClose;
  final double width;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: SizedBox(
        width: width,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 26),
              child: Panel(
                padding: const EdgeInsets.fromLTRB(18, 38, 18, 20),
                child: child,
              ),
            ),
            Positioned(
              top: 0,
              left: 30,
              right: 30,
              child: Container(
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: const LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFFC857), AppColors.amberDark]),
                  border: Border.all(color: const Color(0xFF8A5200), width: 3),
                  boxShadow: const [BoxShadow(color: Color(0x66000000), offset: Offset(0, 4))],
                ),
                child: OutlinedText(title, size: 28, outline: const Color(0xFF6B3F00), shadowDepth: 2),
              ),
            ),
            if (onClose != null)
              Positioned(
                right: -4,
                top: 22,
                child: RoundIconButton(icon: Icons.close_rounded, onTap: onClose!, color: AppColors.red, size: 38),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- settings

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key});
  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  @override
  Widget build(BuildContext context) {
    final ctx = Ctx.I;
    final store = ctx.store;
    return DialogFrame(
      title: 'SETTINGS',
      onClose: () => Navigator.of(context).pop(),
      child: ListenableBuilder(
        listenable: Listenable.merge([store, ctx.iap]),
        builder: (context, _) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ToggleRow(
              icon: Icons.volume_up_rounded,
              label: 'Sound',
              value: store.sound,
              onChanged: (v) {
                store.setSound(v);
                ctx.sfx.enabled = v;
              },
            ),
            const SizedBox(height: 10),
            _ToggleRow(
              icon: Icons.vibration_rounded,
              label: 'Vibration',
              value: store.haptics,
              onChanged: (v) {
                store.setHaptics(v);
                ctx.sfx.hapticsEnabled = v;
              },
            ),
            const SizedBox(height: 16),
            if (!store.adsRemoved)
              GameButton(
                label: 'REMOVE ADS',
                sub: ctx.iap.priceLabel.isEmpty ? null : ctx.iap.priceLabel,
                color: AppColors.amber,
                height: 56,
                fontSize: 22,
                onTap: () async {
                  await ctx.iap.buyRemoveAds();
                  if (context.mounted && ctx.iap.message != null) snack(context, ctx.iap.message!);
                },
              ),
            if (!store.adsRemoved) const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: GameButton(
                    label: 'RESTORE',
                    color: AppColors.blue,
                    height: 46,
                    fontSize: 17,
                    onTap: () async {
                      await ctx.iap.restore();
                      if (context.mounted && ctx.iap.message != null) snack(context, ctx.iap.message!);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GameButton(
                    label: 'PRIVACY',
                    color: AppColors.blue,
                    height: 46,
                    fontSize: 17,
                    onTap: () => openUrl(AppConfig.privacyUrl),
                  ),
                ),
              ],
            ),
            if (ctx.ads.privacyOptionsRequired) ...[
              const SizedBox(height: 10),
              GameButton(
                label: 'AD PRIVACY CHOICES',
                color: const Color(0xFF4B7C93),
                height: 44,
                fontSize: 16,
                onTap: () => ctx.ads.showPrivacyOptions(),
              ),
            ],
            const SizedBox(height: 14),
            Text('${AppConfig.appName} v1.0.0', style: gameText(14, color: AppColors.textDim)),
            Text('by ${AppConfig.companyName}', style: gameText(13, color: AppColors.textDim)),
          ],
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({required this.icon, required this.label, required this.value, required this.onChanged});
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(color: AppColors.panelDark, borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          Icon(icon, color: AppColors.textDim),
          const SizedBox(width: 10),
          Text(label, style: gameText(22)),
          const Spacer(),
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 56,
            height: 30,
            padding: const EdgeInsets.all(3),
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            decoration: BoxDecoration(
                color: value ? AppColors.green : const Color(0xFF3A5568), borderRadius: BorderRadius.circular(15)),
            child: Container(decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), width: 24),
          ),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------- shop

class ShopDialog extends StatelessWidget {
  const ShopDialog({super.key});
  @override
  Widget build(BuildContext context) {
    final ctx = Ctx.I;
    final store = ctx.store;
    return DialogFrame(
      title: 'SHOP',
      width: 340,
      onClose: () => Navigator.of(context).pop(),
      child: ListenableBuilder(
        listenable: Listenable.merge([store, ctx.ads, ctx.iap]),
        builder: (context, _) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(alignment: Alignment.centerRight, child: CoinBadge(store: store)),
            const SizedBox(height: 10),
            _ShopRow(
              leading: const CoinIcon(size: 34),
              title: 'Free coins',
              sub: 'Watch a short video',
              trailing: GameButton(
                label: '+60',
                icon: Icons.play_circle_fill_rounded,
                color: AppColors.green,
                height: 44,
                width: 104,
                fontSize: 20,
                onTap: () async {
                  if (await watchAd(context)) {
                    store.addCoins(60);
                    ctx.sfx.play('coin');
                  }
                },
              ),
            ),
            for (final b in Booster.values)
              _ShopRow(
                leading: BoosterBubble(b, size: 38),
                title: '${boosterName(b)}  x${store.countOf(b)}',
                sub: boosterDesc(b),
                trailing: GameButton(
                  label: '${AppConfig.boosterPrice}',
                  iconWidget: const CoinIcon(size: 20),
                  color: AppColors.amber,
                  height: 44,
                  width: 104,
                  fontSize: 20,
                  enabled: store.coins >= AppConfig.boosterPrice,
                  onTap: () {
                    if (store.spendCoins(AppConfig.boosterPrice)) {
                      store.addBooster(b);
                      ctx.sfx.play('star');
                    }
                  },
                ),
              ),
            _ShopRow(
              leading: const HeartIcon(size: 34),
              title: 'Full lives',
              sub: '${store.lives}/${AppConfig.maxLives}',
              trailing: GameButton(
                label: '${AppConfig.lifePrice}',
                iconWidget: const CoinIcon(size: 20),
                color: AppColors.red,
                height: 44,
                width: 104,
                fontSize: 20,
                enabled: store.coins >= AppConfig.lifePrice && store.lives < AppConfig.maxLives,
                onTap: () {
                  if (store.spendCoins(AppConfig.lifePrice)) {
                    store.addLife(AppConfig.maxLives);
                    ctx.sfx.play('star');
                  }
                },
              ),
            ),
            if (!store.adsRemoved)
              _ShopRow(
                leading: const Icon(Icons.block_rounded, color: AppColors.amber, size: 34),
                title: 'Remove ads',
                sub: 'One-time purchase',
                trailing: GameButton(
                  label: ctx.iap.priceLabel.isEmpty ? 'BUY' : ctx.iap.priceLabel,
                  color: AppColors.blue,
                  height: 44,
                  width: 104,
                  fontSize: 18,
                  onTap: () => ctx.iap.buyRemoveAds(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ShopRow extends StatelessWidget {
  const _ShopRow({required this.leading, required this.title, required this.sub, required this.trailing});
  final Widget leading;
  final String title;
  final String sub;
  final Widget trailing;
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
      decoration: BoxDecoration(color: AppColors.panelDark, borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        SizedBox(width: 40, child: Center(child: leading)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: gameText(18), overflow: TextOverflow.ellipsis),
            Text(sub, style: gameText(13, color: AppColors.textDim), overflow: TextOverflow.ellipsis),
          ]),
        ),
        trailing,
      ]),
    );
  }
}

class BoosterBubble extends StatelessWidget {
  const BoosterBubble(this.b, {super.key, this.size = 44});
  final Booster b;
  final double size;
  @override
  Widget build(BuildContext context) {
    final c = boosterColor(b);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c,
        borderRadius: BorderRadius.circular(size * 0.3),
        border: Border.all(color: AppColors.shade(c, -0.22), width: 3),
      ),
      child: Icon(boosterIcon(b), color: Colors.white, size: size * 0.6),
    );
  }
}

// ---------------------------------------------------------------- daily

class DailyReward {
  final String label;
  final int coins;
  final Map<Booster, int> boosters;
  const DailyReward(this.label, this.coins, [this.boosters = const {}]);
}

const dailyRewards = <DailyReward>[
  DailyReward('50', 50),
  DailyReward('80', 80),
  DailyReward('Undo', 0, {Booster.undo: 1}),
  DailyReward('120', 120),
  DailyReward('Hint x2', 0, {Booster.hint: 2}),
  DailyReward('180', 180),
  DailyReward('Mega', 250, {Booster.loop: 1, Booster.slot: 1}),
];

class DailyDialog extends StatefulWidget {
  const DailyDialog({super.key});
  @override
  State<DailyDialog> createState() => _DailyDialogState();
}

class _DailyDialogState extends State<DailyDialog> {
  bool _claimed = false;

  void _grant(DailyReward r, {int mult = 1}) {
    final store = Ctx.I.store;
    if (r.coins > 0) store.addCoins(r.coins * mult);
    r.boosters.forEach((b, n) => store.addBooster(b, n * mult));
    Ctx.I.sfx.play('coin');
  }

  @override
  Widget build(BuildContext context) {
    final store = Ctx.I.store;
    final available = store.dailyAvailable && !_claimed;
    final next = store.dailyNextStreak; // 1..7
    final shown = _claimed ? store.dailyStreak : next;
    return DialogFrame(
      title: 'DAILY GIFT',
      width: 340,
      onClose: () => Navigator.of(context).pop(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (var i = 0; i < 7; i++)
                _DayCell(
                  day: i + 1,
                  reward: dailyRewards[i],
                  state: (i + 1) < shown || (_claimed && (i + 1) == shown)
                      ? 2
                      : ((i + 1) == shown ? 1 : 0),
                  wide: i == 6,
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (available) ...[
            GameButton(
              label: 'CLAIM',
              height: 56,
              fontSize: 26,
              onTap: () {
                final r = dailyRewards[next - 1];
                store.claimDaily();
                _grant(r);
                setState(() => _claimed = true);
              },
            ),
          ] else if (_claimed) ...[
            GameButton(
              label: 'DOUBLE IT',
              icon: Icons.play_circle_fill_rounded,
              color: AppColors.amber,
              height: 52,
              fontSize: 22,
              onTap: () async {
                if (await watchAd(context)) {
                  _grant(dailyRewards[store.dailyStreak - 1]);
                  if (context.mounted) Navigator.of(context).pop();
                }
              },
            ),
            const SizedBox(height: 8),
            GameButton(label: 'OK', color: AppColors.blue, height: 46, fontSize: 20, onTap: () => Navigator.of(context).pop()),
          ] else
            Text('Come back tomorrow for your next gift!', textAlign: TextAlign.center, style: gameText(18, color: AppColors.textDim)),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day, required this.reward, required this.state, this.wide = false});
  final int day;
  final DailyReward reward;
  final int state; // 0 future, 1 today, 2 claimed
  final bool wide;
  @override
  Widget build(BuildContext context) {
    final w = wide ? 150.0 : 66.0;
    final today = state == 1;
    return Container(
      width: w,
      height: 82,
      decoration: BoxDecoration(
        color: today ? const Color(0xFF2A5B73) : AppColors.panelDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: today ? AppColors.amber : AppColors.panelEdge.withAlpha(120), width: today ? 3 : 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Day $day', style: gameText(13, color: AppColors.textDim)),
          const SizedBox(height: 4),
          if (state == 2)
            const Icon(Icons.check_circle_rounded, color: AppColors.green, size: 32)
          else if (reward.coins > 0 && reward.boosters.isEmpty)
            const CoinIcon(size: 30)
          else
            Icon(wide ? Icons.card_giftcard_rounded : boosterIcon(reward.boosters.keys.first),
                color: wide ? AppColors.amber : boosterColor(reward.boosters.keys.first), size: 30),
          const SizedBox(height: 2),
          Text(wide ? '250 + boosters' : reward.label, style: gameText(14)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- lives

class NoLivesDialog extends StatefulWidget {
  const NoLivesDialog({super.key});
  @override
  State<NoLivesDialog> createState() => _NoLivesDialogState();
}

class _NoLivesDialogState extends State<NoLivesDialog> {
  Timer? _t;
  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      Ctx.I.store.refreshLives();
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = Ctx.I.store;
    final ok = store.lives > 0;
    return DialogFrame(
      title: 'NO LIVES',
      onClose: () => Navigator.of(context).pop(false),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            HeartIcon(size: 44, filled: false),
            SizedBox(width: 6),
            HeartIcon(size: 44, filled: false),
            SizedBox(width: 6),
            HeartIcon(size: 44, filled: false),
          ]),
          const SizedBox(height: 10),
          if (ok)
            Text('You have ${store.lives} lives!', style: gameText(22))
          else
            Text('Next life in ${formatTime(store.secondsToNextLife)}', style: gameText(22)),
          const SizedBox(height: 16),
          if (ok)
            GameButton(label: 'PLAY', height: 54, onTap: () => Navigator.of(context).pop(true))
          else ...[
            GameButton(
              label: 'REFILL',
              iconWidget: const CoinIcon(size: 22),
              sub: '${AppConfig.lifePrice} coins',
              color: AppColors.amber,
              height: 62,
              fontSize: 24,
              enabled: store.coins >= AppConfig.lifePrice,
              onTap: () {
                if (store.spendCoins(AppConfig.lifePrice)) {
                  store.addLife(AppConfig.maxLives);
                  Navigator.of(context).pop(true);
                }
              },
            ),
            const SizedBox(height: 10),
            GameButton(
              label: '+1 LIFE',
              icon: Icons.play_circle_fill_rounded,
              color: AppColors.green,
              height: 54,
              fontSize: 24,
              onTap: () async {
                if (await watchAd(context)) {
                  store.addLife(1);
                  if (context.mounted) Navigator.of(context).pop(true);
                }
              },
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- level results

class WinDialog extends StatefulWidget {
  const WinDialog({super.key, required this.level, required this.stars, required this.coins, required this.last});
  final int level;
  final int stars;
  final int coins;
  final bool last;
  @override
  State<WinDialog> createState() => _WinDialogState();
}

class _WinDialogState extends State<WinDialog> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))..forward();
  bool _doubled = false;

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < widget.stars; i++) {
      Future.delayed(Duration(milliseconds: 350 + i * 280), () {
        if (mounted) Ctx.I.sfx.play('star');
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctx = Ctx.I;
    return DialogFrame(
      title: widget.last ? 'ALL DONE!' : 'LEVEL ${widget.level}',
      width: 330,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final shown = (_c.value * 4.2).floor().clamp(0, widget.stars);
              return StarsRow(count: shown, size: 62);
            },
          ),
          const SizedBox(height: 6),
          OutlinedText('SOLVED!', size: 34, color: AppColors.green, outline: const Color(0xFF0B3A22)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            decoration: BoxDecoration(color: AppColors.panelDark, borderRadius: BorderRadius.circular(18)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const CoinIcon(size: 34),
              const SizedBox(width: 10),
              Text('+${_doubled ? widget.coins * 2 : widget.coins}', style: gameText(32, color: AppColors.amber)),
            ]),
          ),
          const SizedBox(height: 16),
          if (!_doubled)
            GameButton(
              label: 'x2 COINS',
              icon: Icons.play_circle_fill_rounded,
              color: AppColors.amber,
              height: 52,
              fontSize: 22,
              onTap: () async {
                if (await watchAd(context)) {
                  ctx.store.addCoins(widget.coins);
                  ctx.sfx.play('coin');
                  setState(() => _doubled = true);
                }
              },
            ),
          if (!_doubled) const SizedBox(height: 10),
          GameButton(
            label: widget.last ? 'HOME' : 'NEXT',
            height: 60,
            fontSize: 28,
            onTap: () => Navigator.of(context).pop(widget.last ? 'home' : 'next'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: GameButton(
                    label: 'REPLAY',
                    color: AppColors.blue,
                    height: 42,
                    fontSize: 16,
                    onTap: () => Navigator.of(context).pop('replay')),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GameButton(
                    label: 'HOME',
                    color: AppColors.blue,
                    height: 42,
                    fontSize: 16,
                    onTap: () => Navigator.of(context).pop('home')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class StuckDialog extends StatelessWidget {
  const StuckDialog({super.key, required this.deadEnd, required this.canUndo});
  final bool deadEnd;
  final bool canUndo;
  @override
  Widget build(BuildContext context) {
    final ctx = Ctx.I;
    return DialogFrame(
      title: deadEnd ? 'DEAD END' : 'LOOP FULL',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Mascot(size: 100, mood: 1),
          Text(
            deadEnd ? 'No way to win from here.' : 'No moves left. The loop is jammed!',
            textAlign: TextAlign.center,
            style: gameText(20),
          ),
          const SizedBox(height: 14),
          GameButton(
            label: 'REVIVE',
            icon: Icons.play_circle_fill_rounded,
            sub: '+3 loop space',
            color: AppColors.green,
            height: 62,
            fontSize: 24,
            onTap: () async {
              if (await watchAd(context) && context.mounted) Navigator.of(context).pop('revive');
            },
          ),
          const SizedBox(height: 10),
          if (canUndo)
            GameButton(
              label: 'UNDO MOVE',
              icon: Icons.undo_rounded,
              color: AppColors.blue,
              height: 50,
              fontSize: 22,
              onTap: () {
                if (ctx.store.countOf(Booster.undo) > 0) {
                  Navigator.of(context).pop('undo');
                } else {
                  Navigator.of(context).pop('undo_free');
                }
              },
            ),
          if (canUndo) const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: GameButton(
                    label: 'RETRY',
                    sub: '-1 life',
                    color: AppColors.red,
                    height: 52,
                    fontSize: 20,
                    onTap: () => Navigator.of(context).pop('retry')),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GameButton(
                    label: 'HOME',
                    sub: '-1 life',
                    color: const Color(0xFF4B7C93),
                    height: 52,
                    fontSize: 20,
                    onTap: () => Navigator.of(context).pop('home')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class PauseDialog extends StatelessWidget {
  const PauseDialog({super.key});
  @override
  Widget build(BuildContext context) {
    return DialogFrame(
      title: 'PAUSED',
      onClose: () => Navigator.of(context).pop('resume'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GameButton(label: 'RESUME', height: 60, fontSize: 28, onTap: () => Navigator.of(context).pop('resume')),
          const SizedBox(height: 10),
          GameButton(label: 'RESTART', color: AppColors.amber, height: 50, fontSize: 22, onTap: () => Navigator.of(context).pop('restart')),
          const SizedBox(height: 10),
          GameButton(label: 'SETTINGS', color: AppColors.blue, height: 50, fontSize: 22, onTap: () => Navigator.of(context).pop('settings')),
          const SizedBox(height: 10),
          GameButton(label: 'HOME', color: const Color(0xFF4B7C93), height: 50, fontSize: 22, onTap: () => Navigator.of(context).pop('home')),
        ],
      ),
    );
  }
}

class BoosterOfferDialog extends StatelessWidget {
  const BoosterOfferDialog({super.key, required this.booster});
  final Booster booster;
  @override
  Widget build(BuildContext context) {
    final store = Ctx.I.store;
    return DialogFrame(
      title: boosterName(booster).toUpperCase(),
      onClose: () => Navigator.of(context).pop('close'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BoosterBubble(booster, size: 72),
          const SizedBox(height: 10),
          Text(boosterDesc(booster), textAlign: TextAlign.center, style: gameText(20)),
          const SizedBox(height: 4),
          Text("You're out of these!", style: gameText(16, color: AppColors.textDim)),
          const SizedBox(height: 16),
          GameButton(
            label: 'FREE',
            icon: Icons.play_circle_fill_rounded,
            sub: 'Watch a video',
            color: AppColors.green,
            height: 60,
            fontSize: 24,
            onTap: () async {
              if (await watchAd(context) && context.mounted) Navigator.of(context).pop('ad');
            },
          ),
          const SizedBox(height: 10),
          GameButton(
            label: '${AppConfig.boosterPrice}',
            iconWidget: const CoinIcon(size: 22),
            color: AppColors.amber,
            height: 52,
            fontSize: 24,
            enabled: store.coins >= AppConfig.boosterPrice,
            onTap: () => Navigator.of(context).pop('coins'),
          ),
        ],
      ),
    );
  }
}
