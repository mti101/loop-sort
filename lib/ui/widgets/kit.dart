import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app_context.dart';
import '../../game/factory_bg.dart';
import '../../game/painting.dart';
import '../../theme.dart';

/// Text with a thick outline (cartoon style).
class OutlinedText extends StatelessWidget {
  const OutlinedText(this.text,
      {super.key,
      this.size = 24,
      this.color = Colors.white,
      this.outline = const Color(0xFF0B2230),
      this.outlineWidth,
      this.align = TextAlign.center,
      this.shadowDepth = 3});
  final String text;
  final double size;
  final Color color;
  final Color outline;
  final double? outlineWidth;
  final TextAlign align;
  final double shadowDepth;

  @override
  Widget build(BuildContext context) {
    final ow = outlineWidth ?? math.max(3.0, size * 0.16);
    return Stack(
      alignment: Alignment.center,
      children: [
        Text(text,
            textAlign: align,
            style: TextStyle(
              fontFamily: kFont,
              fontSize: size,
              height: 1.05,
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = ow
                ..strokeJoin = StrokeJoin.round
                ..color = outline,
              shadows: [Shadow(color: outline, offset: Offset(0, shadowDepth))],
            )),
        Text(text,
            textAlign: align,
            style: TextStyle(fontFamily: kFont, fontSize: size, height: 1.05, color: color)),
      ],
    );
  }
}

/// Chunky 3D button.
class GameButton extends StatefulWidget {
  const GameButton({
    super.key,
    required this.label,
    required this.onTap,
    this.color = AppColors.green,
    this.dark,
    this.height = 56,
    this.width,
    this.fontSize = 24,
    this.icon,
    this.iconWidget,
    this.enabled = true,
    this.sub,
  });
  final String label;
  final VoidCallback? onTap;
  final Color color;
  final Color? dark;
  final double height;
  final double? width;
  final double fontSize;
  final IconData? icon;
  final Widget? iconWidget;
  final bool enabled;
  final String? sub;

  @override
  State<GameButton> createState() => _GameButtonState();
}

class _GameButtonState extends State<GameButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final base = widget.enabled ? widget.color : const Color(0xFF55707E);
    final dark = widget.enabled ? (widget.dark ?? AppColors.shade(widget.color, -0.2)) : const Color(0xFF3A4F5B);
    final depth = _down ? 1.0 : 5.0;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.enabled ? (_) => setState(() => _down = true) : null,
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.enabled
          ? () {
              Ctx.I.sfx.play('button');
              Ctx.I.sfx.haptic(0);
              widget.onTap?.call();
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 60),
        width: widget.width,
        height: widget.height + 5,
        padding: EdgeInsets.only(top: 5 - depth),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.height * 0.34),
            color: dark,
          ),
          child: Container(
            margin: EdgeInsets.only(bottom: depth),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.height * 0.34),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.shade(base, 0.1), base],
              ),
              border: Border.all(color: Colors.white.withAlpha(60), width: 1.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.iconWidget != null) ...[widget.iconWidget!, const SizedBox(width: 8)],
                if (widget.icon != null) ...[
                  Icon(widget.icon, color: Colors.white, size: widget.fontSize * 1.1),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        OutlinedText(widget.label,
                            size: widget.fontSize,
                            outline: AppColors.shade(dark, -0.12),
                            outlineWidth: widget.fontSize * 0.2,
                            shadowDepth: 2),
                        if (widget.sub != null)
                          Text(widget.sub!, style: gameText(widget.fontSize * 0.5, color: Colors.white70)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RoundIconButton extends StatefulWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.color = AppColors.blue,
    this.size = 46,
    this.badge,
  });
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  final double size;
  final bool? badge;

  @override
  State<RoundIconButton> createState() => _RoundIconButtonState();
}

class _RoundIconButtonState extends State<RoundIconButton> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    final dark = AppColors.shade(widget.color, -0.22);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: () {
        Ctx.I.sfx.play('button');
        widget.onTap();
      },
      child: SizedBox(
        width: widget.size,
        height: widget.size + 4,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: _down ? 3 : 0,
              child: Container(
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color,
                  border: Border.all(color: dark, width: 3),
                  boxShadow: [BoxShadow(color: dark, offset: Offset(0, _down ? 1 : 4))],
                  gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [AppColors.shade(widget.color, 0.12), widget.color]),
                ),
                child: Icon(widget.icon, color: Colors.white, size: widget.size * 0.55),
              ),
            ),
            if (widget.badge == true)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                      color: AppColors.red, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.color});
  final Widget child;
  final EdgeInsets padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.panel,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.panelEdge, width: 3),
        boxShadow: const [BoxShadow(color: Color(0x88000000), blurRadius: 18, offset: Offset(0, 8))],
      ),
      child: child,
    );
  }
}

class CoinBadge extends StatelessWidget {
  const CoinBadge({super.key, required this.store, this.onTap});
  final dynamic store;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store as Listenable,
      builder: (context, _) {
        return GestureDetector(
          onTap: onTap,
          child: Container(
            height: 38,
            padding: const EdgeInsets.only(left: 4, right: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0B2230),
              borderRadius: BorderRadius.circular(19),
              border: Border.all(color: AppColors.panelEdge, width: 2),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const CoinIcon(size: 28),
              const SizedBox(width: 6),
              Text('${store.coins}', style: gameText(20)),
              if (onTap != null) ...[
                const SizedBox(width: 6),
                const Icon(Icons.add_circle, color: AppColors.green, size: 20),
              ],
            ]),
          ),
        );
      },
    );
  }
}

class CoinIcon extends StatelessWidget {
  const CoinIcon({super.key, this.size = 24});
  final double size;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFFE27A), Color(0xFFFFA800)]),
        border: Border.all(color: const Color(0xFFC77700), width: size * 0.09),
      ),
      alignment: Alignment.center,
      child: Text('\$', style: TextStyle(fontFamily: kFont, fontSize: size * 0.62, color: const Color(0xFF9A5A00), height: 1.0)),
    );
  }
}

class HeartIcon extends StatelessWidget {
  const HeartIcon({super.key, this.size = 26, this.filled = true});
  final double size;
  final bool filled;
  @override
  Widget build(BuildContext context) {
    return Icon(Icons.favorite, size: size, color: filled ? AppColors.red : const Color(0xFF3A5568));
  }
}

class LivesBadge extends StatelessWidget {
  const LivesBadge({super.key, required this.store, this.onTap});
  final dynamic store;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store as Listenable,
      builder: (context, _) {
        final secs = store.secondsToNextLife as int;
        return GestureDetector(
          onTap: onTap,
          child: Container(
            height: 38,
            padding: const EdgeInsets.only(left: 8, right: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0B2230),
              borderRadius: BorderRadius.circular(19),
              border: Border.all(color: AppColors.panelEdge, width: 2),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const HeartIcon(size: 24),
              const SizedBox(width: 4),
              Text('${store.lives}', style: gameText(20)),
              if (secs > 0) ...[
                const SizedBox(width: 6),
                Text(formatTime(secs), style: gameText(14, color: AppColors.textDim)),
              ],
            ]),
          ),
        );
      },
    );
  }
}

String formatTime(int secs) {
  final m = secs ~/ 60;
  final s = secs % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

class StarsRow extends StatelessWidget {
  const StarsRow({super.key, required this.count, this.size = 40, this.of = 3});
  final int count;
  final double size;
  final int of;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < of; i++)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: size * 0.04),
            child: Transform.translate(
              offset: Offset(0, i == 1 ? -size * 0.12 : 0),
              child: Icon(Icons.star_rounded,
                  size: size, color: i < count ? AppColors.amber : const Color(0xFF2E5368)),
            ),
          ),
      ],
    );
  }
}

/// Animated pop-in dialog.
Future<T?> showGameDialog<T>(BuildContext context, WidgetBuilder builder,
    {bool dismissible = true}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: dismissible,
    barrierLabel: 'dialog',
    barrierColor: const Color(0xB3041016),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (ctx, a, b) => SafeArea(child: Center(child: builder(ctx))),
    transitionBuilder: (ctx, a, b, child) {
      final curved = CurvedAnimation(parent: a, curve: Curves.easeOutBack, reverseCurve: Curves.easeIn);
      return FadeTransition(
        opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
        child: ScaleTransition(scale: Tween<double>(begin: 0.8, end: 1).animate(curved), child: child),
      );
    },
  );
}

/// Static, cached background with a soft industrial feel.
class GameBackground extends StatelessWidget {
  const GameBackground({super.key, this.child});
  final Widget? child;
  @override
  Widget build(BuildContext context) => FactoryBackdrop(child: child);
}

class _BgPainter extends CustomPainter {
  const _BgPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final dot = Paint()..color = const Color(0x0DFFFFFF);
    const step = 34.0;
    for (var y = step / 2; y < size.height; y += step) {
      for (var x = step / 2 + ((y / step).floor().isEven ? 0 : step / 2); x < size.width; x += step) {
        canvas.drawCircle(Offset(x, y), 1.8, dot);
      }
    }
    // pipes in the corners
    final pipe = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..color = const Color(0x1AFFFFFF);
    final p = Path()
      ..moveTo(-10, size.height * 0.12)
      ..lineTo(size.width * 0.18, size.height * 0.12)
      ..quadraticBezierTo(size.width * 0.26, size.height * 0.12, size.width * 0.26, size.height * 0.05)
      ..lineTo(size.width * 0.26, -10);
    canvas.drawPath(p, pipe);
    final p2 = Path()
      ..moveTo(size.width + 10, size.height * 0.2)
      ..lineTo(size.width * 0.86, size.height * 0.2)
      ..quadraticBezierTo(size.width * 0.8, size.height * 0.2, size.width * 0.8, size.height * 0.27)
      ..lineTo(size.width * 0.8, size.height * 0.34);
    canvas.drawPath(p2, pipe);
    final cap = Paint()..color = const Color(0x22FFFFFF);
    canvas.drawCircle(Offset(size.width * 0.26, size.height * 0.05), 11, cap);
    canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.34), 11, cap);
    // vignette
    final vg = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 1.1,
        colors: const [Color(0x00000000), Color(0x66000000)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, vg);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Our own mascot: "Bolt" the little sorting robot.
class Mascot extends StatefulWidget {
  const Mascot({super.key, this.size = 140, this.mood = 0});
  final double size;
  final int mood; // 0 happy, 1 sad, 2 thinking
  @override
  State<Mascot> createState() => _MascotState();
}

class _MascotState extends State<Mascot> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => CustomPaint(
        size: Size(widget.size, widget.size * 1.1),
        painter: MascotPainter(_c.value, widget.mood),
      ),
    );
  }
}

class MascotPainter extends CustomPainter {
  MascotPainter(this.t, this.mood);
  final double t;
  final int mood;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final bob = math.sin(t * math.pi * 2) * w * 0.02;
    canvas.save();
    canvas.translate(w / 2, size.height / 2 + bob);
    final u = w / 100;
    final p = Paint()..isAntiAlias = true;

    // shadow
    canvas.drawOval(Rect.fromCenter(center: Offset(0, 52 * u - bob), width: 56 * u, height: 8 * u),
        p..color = const Color(0x44000000));
    // body
    final body = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(0, 28 * u), width: 46 * u, height: 36 * u), Radius.circular(12 * u));
    canvas.drawRRect(body.shift(Offset(0, 3 * u)), p..color = const Color(0xFFC77700));
    canvas.drawRRect(body, p..color = AppColors.amber);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(0, 30 * u), width: 22 * u, height: 14 * u), Radius.circular(5 * u)),
        p..color = const Color(0xFFFFE08A));
    for (var i = 0; i < 3; i++) {
      canvas.drawCircle(Offset((-6 + i * 6) * u, 30 * u), 2.2 * u,
          p..color = AppColors.tile(i == 0 ? 0 : (i == 1 ? 3 : 2)));
    }
    // arms
    final armP = p..color = const Color(0xFF2F7090);
    final wave = mood == 0 ? math.sin(t * math.pi * 4) * 0.25 : 0.0;
    canvas.save();
    canvas.translate(-25 * u, 20 * u);
    canvas.rotate(0.5 + wave);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(-4 * u, 0, 8 * u, 20 * u), Radius.circular(4 * u)), armP);
    canvas.restore();
    canvas.save();
    canvas.translate(25 * u, 20 * u);
    canvas.rotate(-0.5);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(-4 * u, 0, 8 * u, 20 * u), Radius.circular(4 * u)), armP);
    canvas.restore();
    // head
    final head = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(0, -14 * u), width: 64 * u, height: 50 * u), Radius.circular(18 * u));
    canvas.drawRRect(head.shift(Offset(0, 3 * u)), p..color = const Color(0xFF1B5670));
    canvas.drawRRect(head, p..color = const Color(0xFF2F8DB3));
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(-26 * u, -34 * u, 52 * u, 14 * u), Radius.circular(8 * u)),
        p..color = const Color(0x33FFFFFF));
    // face screen
    final face = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(0, -12 * u), width: 50 * u, height: 34 * u), Radius.circular(12 * u));
    canvas.drawRRect(face, p..color = const Color(0xFF0B2230));
    // eyes
    final blink = (t % 0.5) < 0.02 ? 0.15 : 1.0;
    final eyeH = (mood == 1 ? 7 : 10) * u * blink;
    final eyeC = mood == 1 ? const Color(0xFF8FB4FF) : const Color(0xFF58F0FF);
    for (final dx in [-9.0, 9.0]) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset(dx * u, -15 * u), width: 8 * u, height: eyeH), Radius.circular(4 * u)),
          p..color = eyeC);
    }
    // mouth
    final m = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.6 * u
      ..color = eyeC;
    final mp = Path();
    if (mood == 1) {
      mp.moveTo(-6 * u, -2 * u);
      mp.quadraticBezierTo(0, -7 * u, 6 * u, -2 * u);
    } else if (mood == 2) {
      mp.moveTo(-5 * u, -4 * u);
      mp.lineTo(5 * u, -4 * u);
    } else {
      mp.moveTo(-7 * u, -5 * u);
      mp.quadraticBezierTo(0, 2 * u, 7 * u, -5 * u);
    }
    canvas.drawPath(mp, m);
    // antenna
    final an = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 * u
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF1B5670);
    canvas.drawLine(Offset(0, -39 * u), Offset(0, -50 * u), an);
    final glow = 0.6 + 0.4 * math.sin(t * math.pi * 6);
    canvas.drawCircle(Offset(0, -53 * u), 6 * u, p..color = AppColors.red.withAlpha((180 + 75 * glow).round()));
    canvas.drawCircle(Offset(-2 * u, -55 * u), 2 * u, p..color = Colors.white.withAlpha(180));
    // ears
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(-37 * u, -20 * u, 6 * u, 14 * u), Radius.circular(3 * u)),
        p..color = AppColors.amber);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(31 * u, -20 * u, 6 * u, 14 * u), Radius.circular(3 * u)),
        p..color = AppColors.amber);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant MascotPainter old) => old.t != t || old.mood != mood;
}

/// The "LOOP SORT" logo lock-up.
class LogoMark extends StatelessWidget {
  const LogoMark({super.key, this.scale = 1});
  final double scale;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300 * scale,
      height: 150 * scale,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(child: CustomPaint(painter: _LogoTilesPainter())),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedText('LOOP', size: 74 * scale, color: AppColors.amber, outline: const Color(0xFF3A2200), shadowDepth: 6 * scale),
              Transform.translate(
                offset: Offset(0, -6 * scale),
                child: OutlinedText('SORT', size: 56 * scale, color: Colors.white, outline: const Color(0xFF0B2230), shadowDepth: 5 * scale),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LogoTilesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    void tile(double fx, double fy, double s, double rot, int c) {
      canvas.save();
      canvas.translate(size.width * fx, size.height * fy);
      canvas.rotate(rot);
      drawTile(canvas, Offset.zero, s, c);
      canvas.restore();
    }

    tile(0.03, 0.2, size.width * 0.13, -0.3, 1);
    tile(0.97, 0.12, size.width * 0.12, 0.35, 0);
    tile(0.06, 0.88, size.width * 0.11, 0.25, 2);
    tile(0.95, 0.86, size.width * 0.14, -0.25, 4);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
