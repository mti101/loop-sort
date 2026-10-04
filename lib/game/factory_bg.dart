import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Painted "magic factory" wall: blue panels, pipes, gauges and robot arms.
/// Rendered once per size into a Picture, then replayed (cheap).
class FactoryBackdrop extends StatefulWidget {
  const FactoryBackdrop({super.key, this.seed = 1, this.child});
  final int seed;
  final Widget? child;
  @override
  State<FactoryBackdrop> createState() => _FactoryBackdropState();
}

class _FactoryBackdropState extends State<FactoryBackdrop> {
  ui.Picture? _pic;
  Size _size = Size.zero;

  @override
  void dispose() {
    _pic?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final size = Size(c.maxWidth, c.maxHeight);
      if (_pic == null || _size != size) {
        _pic?.dispose();
        final rec = ui.PictureRecorder();
        paintFactory(Canvas(rec), size, widget.seed);
        _pic = rec.endRecording();
        _size = size;
      }
      return CustomPaint(painter: _PicPainter(_pic!), size: size, child: widget.child);
    });
  }
}

class _PicPainter extends CustomPainter {
  _PicPainter(this.pic);
  final ui.Picture pic;
  @override
  void paint(Canvas canvas, Size size) => canvas.drawPicture(pic);
  @override
  bool shouldRepaint(_PicPainter old) => old.pic != pic;
}

final Paint _f = Paint()..isAntiAlias = true;

void paintFactory(Canvas canvas, Size s, int seed) {
  final w = s.width, h = s.height;
  final rnd = math.Random(seed * 977 + 5);
  // wall
  final rect = Offset.zero & s;
  canvas.drawRect(
      rect,
      _f
        ..shader = ui.Gradient.linear(Offset.zero, Offset(0, h),
            const [Color(0xFF3A4EAE), Color(0xFF4259BE), Color(0xFF3748A6), Color(0xFF2B3A90)], const [0, 0.35, 0.75, 1]));
  _f.shader = null;
  // panel seams
  final seam = Paint()
    ..color = const Color(0xFF2C3C94).withValues(alpha: 0.55)
    ..strokeWidth = 2;
  final seamHi = Paint()
    ..color = const Color(0xFF6277D6).withValues(alpha: 0.35)
    ..strokeWidth = 1.2;
  final cols = 3;
  for (var i = 1; i < cols; i++) {
    final x = w * i / cols;
    canvas.drawLine(Offset(x, 0), Offset(x, h), seam);
    canvas.drawLine(Offset(x + 1.6, 0), Offset(x + 1.6, h), seamHi);
  }
  final rows = (h / 260).round().clamp(2, 5);
  for (var j = 1; j < rows; j++) {
    final y = h * j / rows;
    canvas.drawLine(Offset(0, y), Offset(w, y), seam);
    canvas.drawLine(Offset(0, y + 1.6), Offset(w, y + 1.6), seamHi);
  }
  // soft light pool in the middle
  canvas.drawRect(
      rect,
      _f
        ..shader = ui.Gradient.radial(Offset(w / 2, h * 0.42), h * 0.55,
            [const Color(0x30FFFFFF), const Color(0x00FFFFFF)]));
  _f.shader = null;
  // header band (HUD zone)
  final head = Rect.fromLTWH(0, 0, w, h * 0.075);
  canvas.drawRect(
      head,
      _f
        ..shader = ui.Gradient.linear(head.topCenter, head.bottomCenter,
            [const Color(0xFF263480), const Color(0xFF31419A)]));
  _f.shader = null;
  canvas.drawLine(head.bottomLeft, head.bottomRight, Paint()..color = const Color(0xFF1C2866)..strokeWidth = 3);
  // ceiling vents / lights
  for (var i = 0; i < 6; i++) {
    final x = w * (0.1 + i * 0.16) + rnd.nextDouble() * 6;
    _lamp(canvas, Offset(x, head.height * 0.35), w * 0.012, i % 3);
  }
  // pipes
  _pipeV(canvas, w * 0.045, h * 0.075, h * 0.30, w * 0.032);
  _pipeH(canvas, w * 0.045, w * 0.17, h * 0.30, w * 0.032);
  _valve(canvas, Offset(w * 0.105, h * 0.30), w * 0.034);
  _pipeV(canvas, w * 0.955, h * 0.075, h * 0.46, w * 0.034);
  _gauge(canvas, Offset(w * 0.955, h * 0.36), w * 0.045);
  _pipeH(canvas, w * 0.86, w * 0.955, h * 0.46, w * 0.034);
  // lower pipes
  _pipeV(canvas, w * 0.06, h * 0.66, h * 0.84, w * 0.034);
  _pipeH(canvas, w * 0.06, w * 0.2, h * 0.66, w * 0.034);
  _gauge(canvas, Offset(w * 0.06, h * 0.72), w * 0.04);
  _pipeV(canvas, w * 0.94, h * 0.62, h * 0.86, w * 0.034);
  _pipeH(canvas, w * 0.8, w * 0.94, h * 0.62, w * 0.034);
  _valve(canvas, Offset(w * 0.87, h * 0.62), w * 0.03);
  // machines and arms
  _machine(canvas, Rect.fromLTWH(w * 0.11, h * 0.105, w * 0.16, h * 0.05));
  _arm(canvas, Offset(w * 0.86, h * 0.2), w * 0.11, -0.5);
  _arm(canvas, Offset(w * 0.1, h * 0.52), w * 0.09, 0.4);
  _machine(canvas, Rect.fromLTWH(w * 0.76, h * 0.755, w * 0.16, h * 0.045));
  // floor vents
  for (var i = 0; i < 3; i++) {
    _vent(canvas, Rect.fromCenter(center: Offset(w * (0.38 + i * 0.12), h * 0.835), width: w * 0.09, height: h * 0.022));
  }
  // vignette
  canvas.drawRect(
      rect,
      _f
        ..shader = ui.Gradient.radial(Offset(w / 2, h / 2), h * 0.75,
            [const Color(0x00000000), const Color(0x55101A55)], [0.6, 1.0]));
  _f.shader = null;
}

void _lamp(Canvas c, Offset p, double r, int kind) {
  final col = [const Color(0xFFFFC44A), const Color(0xFF6BE58F), const Color(0xFFFF6B6B)][kind];
  c.drawCircle(p, r * 1.5, _f..color = const Color(0xFF1B2766));
  c.drawCircle(p, r, _f..color = col);
  c.drawCircle(p.translate(-r * 0.3, -r * 0.3), r * 0.35, _f..color = Colors.white.withValues(alpha: 0.7));
}

void _pipeH(Canvas c, double x0, double x1, double y, double t) {
  final r = Rect.fromLTRB(math.min(x0, x1), y - t / 2, math.max(x0, x1), y + t / 2);
  c.drawRRect(RRect.fromRectAndRadius(r.inflate(2), Radius.circular(t * 0.4)), _f..color = const Color(0xFF1F2C78));
  c.drawRRect(
      RRect.fromRectAndRadius(r, Radius.circular(t * 0.35)),
      _f
        ..shader = ui.Gradient.linear(r.topCenter, r.bottomCenter,
            const [Color(0xFF5B72D4), Color(0xFF8AA0F0), Color(0xFF4A60C4), Color(0xFF34479F)], const [0, 0.25, 0.65, 1]));
  _f.shader = null;
  for (final x in [r.left + t * 0.35, r.right - t * 0.35]) {
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(x, y), width: t * 0.5, height: t * 1.3), Radius.circular(3)),
        _f..color = const Color(0xFF2B3A92));
  }
}

void _pipeV(Canvas c, double x, double y0, double y1, double t) {
  final r = Rect.fromLTRB(x - t / 2, math.min(y0, y1), x + t / 2, math.max(y0, y1));
  c.drawRRect(RRect.fromRectAndRadius(r.inflate(2), Radius.circular(t * 0.4)), _f..color = const Color(0xFF1F2C78));
  c.drawRRect(
      RRect.fromRectAndRadius(r, Radius.circular(t * 0.35)),
      _f
        ..shader = ui.Gradient.linear(r.centerLeft, r.centerRight,
            const [Color(0xFF5B72D4), Color(0xFF8AA0F0), Color(0xFF4A60C4), Color(0xFF34479F)], const [0, 0.25, 0.65, 1]));
  _f.shader = null;
  for (final yy in [r.top + t * 0.9, r.bottom - t * 0.9]) {
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(x, yy), width: t * 1.3, height: t * 0.5), Radius.circular(3)),
        _f..color = const Color(0xFF2B3A92));
  }
}

void _valve(Canvas c, Offset p, double r) {
  c.drawCircle(p, r, _f..color = const Color(0xFF1F2C78));
  c.drawCircle(p, r * 0.85, _f..color = const Color(0xFF8E7CF0));
  c.drawCircle(p, r * 0.5, _f..color = const Color(0xFF5546C2));
  final sp = Paint()
    ..color = const Color(0xFFD9D0FF)
    ..strokeWidth = r * 0.16
    ..strokeCap = StrokeCap.round;
  for (var i = 0; i < 4; i++) {
    final a = i * math.pi / 2 + 0.4;
    c.drawLine(p, p + Offset(math.cos(a), math.sin(a)) * r * 0.78, sp);
  }
  c.drawCircle(p, r * 0.16, _f..color = const Color(0xFFFFC44A));
}

void _gauge(Canvas c, Offset p, double r) {
  c.drawCircle(p, r, _f..color = const Color(0xFF1F2C78));
  c.drawCircle(p, r * 0.86, _f..color = const Color(0xFF9FB1F5));
  c.drawCircle(p, r * 0.7, _f..color = const Color(0xFFEFF2FF));
  final tick = Paint()
    ..color = const Color(0xFF5B6BC0)
    ..strokeWidth = 1.4;
  for (var i = 0; i < 9; i++) {
    final a = math.pi * 0.8 + i * math.pi * 1.4 / 8;
    c.drawLine(p + Offset(math.cos(a), math.sin(a)) * r * 0.5, p + Offset(math.cos(a), math.sin(a)) * r * 0.65, tick);
  }
  c.drawLine(p, p + Offset(math.cos(-0.6), math.sin(-0.6)) * r * 0.55,
      Paint()
        ..color = const Color(0xFFE23B4A)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round);
  c.drawCircle(p, r * 0.1, _f..color = const Color(0xFF283680));
}

void _machine(Canvas c, Rect r) {
  final rr = RRect.fromRectAndRadius(r, Radius.circular(r.height * 0.22));
  c.drawRRect(rr.inflate(2), _f..color = const Color(0xFF1F2C78));
  c.drawRRect(
      rr,
      _f
        ..shader = ui.Gradient.linear(r.topCenter, r.bottomCenter,
            const [Color(0xFF7D93EE), Color(0xFF5A70D0), Color(0xFF3F54B0)], const [0, 0.5, 1]));
  _f.shader = null;
  final scr = Rect.fromLTWH(r.left + r.width * 0.1, r.top + r.height * 0.22, r.width * 0.5, r.height * 0.56);
  c.drawRRect(RRect.fromRectAndRadius(scr, const Radius.circular(3)), _f..color = const Color(0xFF16205F));
  for (var i = 0; i < 4; i++) {
    c.drawRect(Rect.fromLTWH(scr.left + 3 + i * scr.width * 0.23, scr.bottom - 4 - (i + 1) * scr.height * 0.14, scr.width * 0.13, (i + 1) * scr.height * 0.14),
        _f..color = [const Color(0xFF6BE58F), const Color(0xFF6BE58F), const Color(0xFFFFC44A), const Color(0xFFFF6B6B)][i]);
  }
  c.drawCircle(Offset(r.right - r.width * 0.2, r.center.dy), r.height * 0.2, _f..color = const Color(0xFFFFC44A));
}

void _arm(Canvas c, Offset base, double len, double tilt) {
  final t = len * 0.16;
  c.drawOval(Rect.fromCenter(center: base.translate(0, t * 0.6), width: t * 3.2, height: t * 1.1), _f..color = const Color(0xFF1F2C78));
  c.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: base, width: t * 2.6, height: t * 1.3), Radius.circular(t * 0.5)),
      _f..color = const Color(0xFF6C84E8));
  final a1 = -math.pi / 2 + tilt;
  final j1 = base + Offset(math.cos(a1), math.sin(a1)) * len * 0.55;
  final a2 = a1 + 1.1;
  final j2 = j1 + Offset(math.cos(a2), math.sin(a2)) * len * 0.5;
  for (final seg in [(base, j1), (j1, j2)]) {
    c.drawLine(seg.$1, seg.$2, Paint()..color = const Color(0xFF1F2C78)..strokeWidth = t * 1.5..strokeCap = StrokeCap.round);
    c.drawLine(seg.$1, seg.$2, Paint()..color = const Color(0xFF7D93EE)..strokeWidth = t..strokeCap = StrokeCap.round);
  }
  c.drawCircle(j1, t * 0.75, _f..color = const Color(0xFFFFB347));
  c.drawCircle(j2, t * 0.65, _f..color = const Color(0xFFFFB347));
  final claw = Paint()
    ..color = const Color(0xFFFFB347)
    ..strokeWidth = t * 0.45
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;
  final a3 = a2 + 0.3;
  c.drawArc(Rect.fromCircle(center: j2 + Offset(math.cos(a3), math.sin(a3)) * t, radius: t), a3 - 1.2, 2.4, false, claw);
}

void _vent(Canvas c, Rect r) {
  c.drawRRect(RRect.fromRectAndRadius(r.inflate(3), const Radius.circular(4)), _f..color = const Color(0xFF2A3A92));
  c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(3)), _f..color = const Color(0xFF1C2770));
  final n = 4;
  for (var i = 0; i < n; i++) {
    final y = r.top + r.height * (i + 0.7) / (n + 0.4);
    c.drawLine(Offset(r.left + 4, y), Offset(r.right - 4, y), Paint()..color = const Color(0xFF4C60C4)..strokeWidth = 1.5);
  }
}
