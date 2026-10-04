import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Unit symbol paths (fit in a [-0.5, 0.5] box) – one per tile colour so the
/// game stays readable for colour-blind players.
class Symbols {
  static final List<Path> paths = [
    _heart(), // 0 red
    _drop(), // 1 blue
    _leaf(), // 2 green
    _star(), // 3 yellow
    _bolt(), // 4 violet
    _moon(), // 5 orange
    _flower(), // 6 pink
  ];

  static Path of(int c) => paths[c % paths.length];

  static Path _star() {
    final p = Path();
    const n = 5;
    for (var i = 0; i < n * 2; i++) {
      final r = i.isEven ? 0.5 : 0.22;
      final a = -math.pi / 2 + i * math.pi / n;
      final x = r * math.cos(a), y = r * math.sin(a);
      if (i == 0) {
        p.moveTo(x, y);
      } else {
        p.lineTo(x, y);
      }
    }
    return p..close();
  }

  static Path _heart() {
    final p = Path();
    p.moveTo(0, 0.45);
    p.cubicTo(-0.75, -0.05, -0.35, -0.6, 0, -0.2);
    p.cubicTo(0.35, -0.6, 0.75, -0.05, 0, 0.45);
    return p..close();
  }

  static Path _drop() {
    final p = Path();
    p.moveTo(0, -0.5);
    p.cubicTo(0.1, -0.25, 0.42, 0.0, 0.42, 0.18);
    p.arcToPoint(const Offset(-0.42, 0.18), radius: const Radius.circular(0.42), clockwise: true);
    p.cubicTo(-0.42, 0.0, -0.1, -0.25, 0, -0.5);
    return p..close();
  }

  static Path _leaf() {
    final p = Path();
    p.moveTo(-0.42, 0.42);
    p.cubicTo(-0.55, -0.1, -0.1, -0.5, 0.45, -0.45);
    p.cubicTo(0.5, 0.1, 0.1, 0.5, -0.42, 0.42);
    return p..close();
  }

  static Path _bolt() {
    final p = Path();
    p.moveTo(0.12, -0.5);
    p.lineTo(-0.3, 0.06);
    p.lineTo(-0.04, 0.06);
    p.lineTo(-0.14, 0.5);
    p.lineTo(0.32, -0.12);
    p.lineTo(0.05, -0.12);
    return p..close();
  }

  static Path _moon() {
    final outer = Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: 0.46));
    final cut = Path()..addOval(Rect.fromCircle(center: const Offset(0.2, -0.12), radius: 0.4));
    return Path.combine(PathOperation.difference, outer, cut);
  }

  static Path _flower() {
    final p = Path();
    for (var i = 0; i < 5; i++) {
      final a = -math.pi / 2 + i * 2 * math.pi / 5;
      p.addOval(Rect.fromCircle(center: Offset(0.22 * math.cos(a), 0.22 * math.sin(a)), radius: 0.22));
    }
    p.addOval(Rect.fromCircle(center: Offset.zero, radius: 0.2));
    return p;
  }

  static final Path check = Path()
    ..moveTo(-0.38, 0.02)
    ..lineTo(-0.12, 0.3)
    ..lineTo(0.4, -0.3)
    ..lineTo(0.28, -0.4)
    ..lineTo(-0.12, 0.06)
    ..lineTo(-0.27, -0.1)
    ..close();
}

final Map<String, TextPainter> _tpCache = {};

TextPainter textPainter(String text, double size,
    {Color color = Colors.white, Color? stroke, double strokeWidth = 0}) {
  final key = '$text|${size.round()}|${color.toARGB32()}|${stroke?.toARGB32()}|$strokeWidth';
  var tp = _tpCache[key];
  if (tp == null) {
    if (_tpCache.length > 400) _tpCache.clear();
    tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: kFont,
          fontSize: size,
          color: color,
          height: 1.0,
          foreground: null,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    _tpCache[key] = tp;
  }
  return tp;
}

void drawText(Canvas canvas, String text, Offset center, double size,
    {Color color = Colors.white, Color? shadow, double alpha = 1}) {
  if (shadow != null) {
    final sp = textPainter(text, size, color: shadow);
    sp.paint(canvas, center - Offset(sp.width / 2, sp.height / 2) + Offset(0, size * 0.07));
  }
  final tp = textPainter(text, size, color: color);
  if (alpha < 1) {
    canvas.saveLayer(
        Rect.fromCenter(center: center, width: tp.width + 8, height: tp.height + 8),
        Paint()..color = Color.fromRGBO(255, 255, 255, alpha));
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
    canvas.restore();
  } else {
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }
}

final Paint _p = Paint()..isAntiAlias = true;

/// Draws a glossy 3D brick centred on [c] with outer size [w] x [h].
void drawBrick(Canvas canvas, Offset c, double w, double h, int color,
    {bool hidden = false, double scale = 1, double alpha = 1, double dim = 0, bool glow = false}) {
  if (alpha <= 0.01) return;
  w *= scale;
  h *= scale;
  final base = hidden ? AppColors.hidden : AppColors.tile(color);
  final dark = AppColors.shade(base, -0.22);
  final deep = AppColors.shade(base, -0.34);
  final light = AppColors.shade(base, 0.2);
  final a = (alpha * 255).round().clamp(0, 255);
  final thick = h * 0.13;
  final r = math.min(w, h) * 0.2;
  final face = Rect.fromCenter(center: c.translate(0, -thick * 0.45), width: w, height: h - thick);
  final body = RRect.fromRectAndRadius(face, Radius.circular(r));
  final side = RRect.fromRectAndRadius(face.shift(Offset(0, thick)), Radius.circular(r));

  if (glow) {
    canvas.drawRRect(body.inflate(w * 0.12),
        _p..color = Colors.white.withAlpha((a * 0.4).round())..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.16));
    _p.maskFilter = null;
  }
  // contact shadow
  canvas.drawRRect(side.shift(Offset(0, h * 0.035)).inflate(w * 0.01), _p..color = Colors.black.withAlpha((a * 0.30).round()));
  // thickness (bottom lip)
  canvas.drawRRect(side, _p..color = deep.withAlpha(a));
  // face gradient
  _p.shader = ui.Gradient.linear(face.topCenter, face.bottomCenter,
      [light.withAlpha(a), base.withAlpha(a), dark.withAlpha(a)], [0.0, 0.42, 1.0]);
  canvas.drawRRect(body, _p);
  _p.shader = null;
  // bevel highlight (top-left) and inner shade (bottom-right)
  canvas.drawRRect(
      body.deflate(w * 0.03),
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.045
        ..shader = ui.Gradient.linear(face.topLeft, face.bottomRight,
            [Colors.white.withAlpha((a * 0.55).round()), Colors.white.withAlpha(0), Colors.black.withAlpha((a * 0.22).round())],
            [0.0, 0.5, 1.0]));
  _p
    ..shader = null
    ..style = PaintingStyle.fill;
  // gloss streak
  final gloss = Path()
    ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(face.left + w * 0.1, face.top + h * 0.07, w * 0.8, (h - thick) * 0.26), Radius.circular(r * 0.7)));
  canvas.drawPath(gloss, _p..color = Colors.white.withAlpha((a * 0.26).round()));

  final fc = face.center;
  if (hidden) {
    final tp = textPainter('?', math.min(w, h) * 0.66, color: const Color(0xFFA9BBF0));
    canvas.saveLayer(face.inflate(4), Paint()..color = Color.fromRGBO(255, 255, 255, alpha));
    tp.paint(canvas, fc - Offset(tp.width / 2, tp.height / 2));
    canvas.restore();
  } else {
    final sz = math.min(w, h) * 0.56;
    canvas.save();
    canvas.translate(fc.dx, fc.dy);
    canvas.scale(sz);
    // embossed: dark offset, light symbol
    canvas.drawPath(Symbols.of(color).shift(const Offset(0.0, 0.05)), _p..color = deep.withAlpha((a * 0.6).round()));
    canvas.drawPath(Symbols.of(color), _p..color = Colors.white.withAlpha((a * 0.94).round()));
    canvas.restore();
  }
  if (dim > 0) {
    canvas.drawRRect(body, _p..color = const Color(0xFF0A1440).withAlpha((dim * 170).round()));
  }
}

/// Square-ish convenience wrapper (used by dialogs and badges).
void drawTile(Canvas canvas, Offset c, double size, int color,
    {bool hidden = false, double scale = 1, double alpha = 1, double dim = 0, bool glow = false}) {
  drawBrick(canvas, c, size, size, color, hidden: hidden, scale: scale, alpha: alpha, dim: dim, glow: glow);
}


/// Stacked rounded rectangle "button-like" panel used by the board.
void drawPlate(Canvas canvas, RRect rr, Color fill, {Color? edge, double edgeW = 2, double depth = 0}) {
  if (depth > 0) {
    canvas.drawRRect(rr.shift(Offset(0, depth)), _p..color = AppColors.shade(fill, -0.12));
  }
  canvas.drawRRect(rr, _p..color = fill);
  if (edge != null) {
    canvas.drawRRect(
        rr,
        _p
          ..style = PaintingStyle.stroke
          ..strokeWidth = edgeW
          ..color = edge);
    _p.style = PaintingStyle.fill;
  }
}

Paint fillPaint(Color c) => Paint()
  ..isAntiAlias = true
  ..color = c;

ui.Shader? verticalGradient(Rect r, Color a, Color b) =>
    ui.Gradient.linear(r.topCenter, r.bottomCenter, [a, b]);
