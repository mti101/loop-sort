import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme.dart';
import 'controller.dart';
import 'layout.dart';
import 'painting.dart';

final Paint _p = Paint()..isAntiAlias = true;

double _smooth(double a, double b, double x) {
  final t = ((x - a) / (b - a)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

class BoardPainter extends CustomPainter {
  BoardPainter(this.g) : super(repaint: g);
  final GameController g;

  @override
  void paint(Canvas canvas, Size size) {
    final geo = g.geo;
    if (geo == null) return;
    _belt(canvas, geo);
    for (final s in geo.slots) {
      _slot(canvas, geo, s);
    }
    _beltTiles(canvas, geo);
    _particles(canvas);
    for (final s in geo.slots) {
      _hintFx(canvas, geo, s);
    }
    _popups(canvas);
  }

  // ------------------------------------------------------------------ belt
  void _belt(Canvas canvas, BoardGeometry geo) {
    final path = geo.belt.toPath();
    final bw = geo.beltWidth;
    void stroke(double w, Color c, {Offset off = Offset.zero, MaskFilter? blur}) {
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = w
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = geo.belt.closed ? StrokeCap.butt : StrokeCap.round
        ..color = c
        ..maskFilter = blur;
      canvas.save();
      canvas.translate(off.dx, off.dy);
      canvas.drawPath(path, _p);
      canvas.restore();
      _p
        ..maskFilter = null
        ..style = PaintingStyle.fill;
    }

    stroke(bw * 1.9, const Color(0x55000018), off: Offset(0, bw * 0.16), blur: MaskFilter.blur(BlurStyle.normal, bw * 0.16));
    stroke(bw * 1.74, const Color(0xFF1A2468));
    stroke(bw * 1.6, const Color(0xFF6C84EA), off: Offset(0, -bw * 0.03));
    stroke(bw * 1.52, const Color(0xFF4960CC), off: Offset(0, bw * 0.015));
    stroke(bw * 1.26, const Color(0xFF2B3A98));
    stroke(bw * 1.12, const Color(0xFF111749));
    stroke(bw * 0.96, const Color(0xFF181F5E), off: Offset(0, bw * 0.05));
    // chevrons showing the flow direction
    final len = geo.belt.length;
    final step = geo.tile * 2.4;
    final n = (len / step).floor();
    final chev = Paint()
      ..color = const Color(0xFF3A4CB4)
      ..strokeWidth = bw * 0.1
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < n; i++) {
      final u = (i + 0.5) * len / n;
      final p = geo.belt.pointAt(u);
      final a = geo.belt.angleAt(u);
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(a);
      final k = bw * 0.2;
      canvas.drawPath(
          Path()
            ..moveTo(-k * 0.5, -k)
            ..lineTo(k * 0.5, 0)
            ..lineTo(-k * 0.5, k),
          chev);
      canvas.restore();
    }
    if (!geo.belt.closed) {
      // end caps of an open conveyor
      for (final end in [0.0, len]) {
        final p = geo.belt.pointAt(end == 0 ? 0.0 : len - 0.01);
        final cap = RRect.fromRectAndRadius(
            Rect.fromCenter(center: p, width: bw * 0.62, height: bw * 1.95), Radius.circular(bw * 0.2));
        canvas.drawRRect(cap.shift(Offset(0, bw * 0.06)), _p..color = const Color(0xFF141C58));
        canvas.drawRRect(
            cap,
            _p
              ..shader = ui.Gradient.linear(cap.outerRect.topLeft, cap.outerRect.bottomRight,
                  const [Color(0xFF8CA2F5), Color(0xFF4F67D8), Color(0xFF34479F)], const [0, 0.5, 1]));
        _p.shader = null;
        canvas.drawCircle(p, bw * 0.12, _p..color = const Color(0xFF1B2766));
      }
    }
    // rivets on the rail
    final riv = Paint()..color = const Color(0xFF9FB2F8);
    final rn = (len / (geo.tile * 3.2)).floor();
    for (var i = 0; i < rn; i++) {
      final u = (i + 0.25) * len / rn;
      final p = geo.belt.pointAt(u);
      final a = geo.belt.angleAt(u) + math.pi / 2;
      final off = Offset(math.cos(a), math.sin(a)) * bw * 0.84;
      canvas.drawCircle(p + off, bw * 0.045, riv);
      canvas.drawCircle(p - off, bw * 0.045, riv);
    }
  }

  // ----------------------------------------------------------------- slots
  Rect _tubeRect(SlotGeo s) {
    final a = s.base;
    final b = s.entry;
    final half = s.cross * 0.62;
    if (s.dir.dx.abs() < 0.5) {
      return Rect.fromLTRB(a.dx - half, math.min(a.dy, b.dy), a.dx + half, math.max(a.dy, b.dy));
    }
    return Rect.fromLTRB(math.min(a.dx, b.dx), a.dy - half, math.max(a.dx, b.dx), a.dy + half);
  }

  void _slot(Canvas canvas, BoardGeometry geo, SlotGeo s) {
    final d = g.slots[s.index];
    var shift = Offset.zero;
    if (d.shake > 0) {
      shift = s.perp * (math.sin(d.shake * 22) * d.shake * geo.tile * 0.1);
    }
    canvas.save();
    canvas.translate(shift.dx, shift.dy);
    final rect = _tubeRect(s);
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(geo.tile * 0.2));
    // gate connector from tube end to belt
    final tubeEnd = s.entry;
    canvas.drawLine(
        tubeEnd,
        s.gate,
        Paint()
          ..color = const Color(0xFF2A3A98).withValues(alpha: 0.9)
          ..strokeWidth = s.cross * 0.52
          ..strokeCap = StrokeCap.butt);
    canvas.drawLine(
        tubeEnd,
        s.gate,
        Paint()
          ..color = const Color(0xFF141B56)
          ..strokeWidth = s.cross * 0.36
          ..strokeCap = StrokeCap.butt);
    // shadow
    canvas.drawRRect(rr.shift(Offset(0, geo.tile * 0.08)), _p..color = const Color(0x55000020));
    // outer rim
    canvas.drawRRect(rr.inflate(geo.tile * 0.06), _p..color = const Color(0xFF5069D8));
    canvas.drawRRect(
        rr,
        _p
          ..shader = ui.Gradient.linear(rect.topCenter, rect.bottomCenter,
              const [Color(0xFF1A2260), Color(0xFF252F7E), Color(0xFF2E3A92)]));
    _p.shader = null;
    // inner top shade
    canvas.drawRRect(
        rr.deflate(geo.tile * 0.03),
        _p
          ..style = PaintingStyle.stroke
          ..strokeWidth = geo.tile * 0.05
          ..color = const Color(0xFF0D1440));
    _p.style = PaintingStyle.fill;
    // capacity ticks (subtle floor lines)
    final tick = Paint()
      ..color = const Color(0xFF3B4AAE).withValues(alpha: 0.5)
      ..strokeWidth = 1.2;
    for (var k = 1; k < s.capacity; k++) {
      final c = s.base + s.dir * (s.pad + s.along * k);
      final pp = s.perp * (s.cross * 0.4);
      canvas.drawLine(c - pp, c + pp, tick);
    }
    // entry marker
    final mp = s.entry + s.dir * (geo.tile * 0.22);
    final ang = math.atan2(s.dir.dy, s.dir.dx);
    canvas.save();
    canvas.translate(mp.dx, mp.dy);
    canvas.rotate(ang);
    final m = geo.tile * 0.16;
    canvas.drawPath(
        Path()
          ..moveTo(m, 0)
          ..lineTo(-m * 0.7, -m)
          ..lineTo(-m * 0.7, m)
          ..close(),
        _p..color = Colors.white.withValues(alpha: 0.9));
    canvas.restore();

    if (d.complete) {
      _completeBar(canvas, geo, s, d);
    } else {
      final count = d.tiles.length;
      final w = (s.dir.dx.abs() < 0.5 ? s.cross : s.along) * 0.96;
      final h = (s.dir.dx.abs() < 0.5 ? s.along : s.cross) * 0.96;
      for (var k = count - 1; k >= 0; k--) {
        var c = s.tileCenter(k, count);
        var sc = 1.0;
        if (k == 0 && d.settle > 0) sc = 1 + 0.07 * math.sin(d.settle * math.pi);
        if (d.pop > 0) sc *= 1 - 0.05 * math.sin(d.pop * math.pi);
        drawBrick(canvas, c, w, h, d.tiles[k].color, hidden: g.isHidden(s.index, k), scale: sc);
      }
    }
    canvas.restore();
  }

  void _completeBar(Canvas canvas, BoardGeometry geo, SlotGeo s, SlotDisp d) {
    final color = d.tiles.isEmpty ? 0 : d.tiles.first.color;
    final base = AppColors.tile(color);
    final a = s.base + s.dir * s.pad;
    final b = s.base + s.dir * (s.pad + s.along * s.capacity);
    final vertical = s.dir.dx.abs() < 0.5;
    final half = s.cross * 0.5;
    final rect = vertical
        ? Rect.fromLTRB(a.dx - half, math.min(a.dy, b.dy), a.dx + half, math.max(a.dy, b.dy))
        : Rect.fromLTRB(math.min(a.dx, b.dx), a.dy - half, math.max(a.dx, b.dx), a.dy + half);
    final r = Radius.circular(geo.tile * 0.2);
    final body = RRect.fromRectAndRadius(rect.deflate(geo.tile * 0.02), r);
    final lip = geo.tile * 0.1;
    if (d.flash > 0) {
      canvas.drawRRect(body.inflate(geo.tile * 0.2 * d.flash),
          _p..color = Colors.white.withValues(alpha: 0.5 * d.flash)..maskFilter = MaskFilter.blur(BlurStyle.normal, geo.tile * 0.25));
      _p.maskFilter = null;
    }
    canvas.drawRRect(body.shift(Offset(0, lip)), _p..color = AppColors.shade(base, -0.3));
    final grad = vertical
        ? ui.Gradient.linear(rect.centerLeft, rect.centerRight,
            [AppColors.shade(base, 0.22), base, AppColors.shade(base, -0.14)], [0, 0.45, 1])
        : ui.Gradient.linear(rect.topCenter, rect.bottomCenter,
            [AppColors.shade(base, 0.22), base, AppColors.shade(base, -0.14)], [0, 0.45, 1]);
    canvas.drawRRect(body, _p..shader = grad);
    _p.shader = null;
    canvas.drawRRect(
        body.deflate(geo.tile * 0.04),
        _p
          ..style = PaintingStyle.stroke
          ..strokeWidth = geo.tile * 0.05
          ..color = Colors.white.withValues(alpha: 0.28));
    _p.style = PaintingStyle.fill;
    // check mark
    final c = rect.center;
    final sz = geo.tile * 0.5;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(sz);
    canvas.drawPath(Symbols.check.shift(const Offset(0, 0.06)), _p..color = AppColors.shade(base, -0.32).withValues(alpha: 0.7));
    canvas.drawPath(Symbols.check, _p..color = Colors.white.withValues(alpha: 0.92));
    canvas.restore();
  }

  // ----------------------------------------------------------- belt tiles
  static const _slats = 6;

  void _slatsAt(Canvas canvas, BoardGeometry geo, double u, int color, double alpha, {int count = _slats}) {
    if (alpha <= 0.01) return;
    final base = AppColors.tile(color);
    final bw = geo.beltWidth;
    final sp = geo.tile * 0.085;
    final th = sp * 0.92;
    final a = (alpha * 255).round();
    for (var j = 0; j < count; j++) {
      final uj = u - j * sp;
      final p = geo.belt.pointAt(uj);
      final ang = geo.belt.angleAt(uj);
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(ang);
      final rc = Rect.fromCenter(center: Offset.zero, width: th, height: bw * 1.02);
      final rr = RRect.fromRectAndRadius(rc, Radius.circular(th * 0.4));
      canvas.drawRRect(rr.shift(const Offset(0.6, 1.4)), _p..color = Colors.black.withAlpha((a * 0.3).round()));
      canvas.drawRRect(rr, _p..color = (j.isEven ? base : AppColors.shade(base, -0.1)).withAlpha(a));
      canvas.drawRect(Rect.fromLTWH(rc.left, rc.top + 1, th * 0.45, rc.height - 2),
          _p..color = AppColors.shade(base, 0.22).withAlpha((a * 0.9).round()));
      canvas.restore();
    }
  }

  void _beltTiles(Canvas canvas, BoardGeometry geo) {
    for (final b in g.belt) {
      final color = b.tile.color;
      switch (b.phase) {
        case BPhase.lift:
          if (b.delay > 0) {
            // still sitting in its slot, drawn as part of the lift origin
            _liftBrick(canvas, geo, b, 0);
            break;
          }
          final t = Curves.easeOut.transform(b.t.clamp(0.0, 1.0));
          _liftBrick(canvas, geo, b, t);
          final gate = geo.slots[b.src].gateArc;
          _slatsAt(canvas, geo, gate, color, _smooth(0.55, 1.0, b.t));
          break;
        case BPhase.ride:
          _slatsAt(canvas, geo, b.u, color, 1);
          break;
        case BPhase.drop:
          final t = b.t.clamp(0.0, 1.0);
          final tg = geo.slots[b.target!];
          _slatsAt(canvas, geo, tg.gateArc, color, 1 - _smooth(0.0, 0.45, t));
          final e = Curves.easeIn.transform(t);
          final pos = Offset.lerp(b.dropFrom, b.dropTo, e)!;
          final vertical = tg.dir.dx.abs() < 0.5;
          final w = (vertical ? tg.cross : tg.along) * 0.96;
          final h = (vertical ? tg.along : tg.cross) * 0.96;
          final grow = _smooth(0.0, 0.7, t);
          drawBrick(canvas, pos, w, h, color, scale: 0.55 + 0.45 * grow, alpha: _smooth(0.05, 0.5, t));
          break;
      }
    }
  }

  void _liftBrick(Canvas canvas, BoardGeometry geo, BeltV b, double t) {
    final sg = geo.slots[b.src];
    final vertical = sg.dir.dx.abs() < 0.5;
    final w = (vertical ? sg.cross : sg.along) * 0.96;
    final h = (vertical ? sg.along : sg.cross) * 0.96;
    final pos = Offset.lerp(b.from, sg.gate, t)!;
    final alpha = 1 - _smooth(0.45, 0.95, t);
    drawBrick(canvas, pos, w, h, b.tile.color, scale: 1 - 0.4 * t, alpha: alpha);
  }

  // -------------------------------------------------------------- effects
  void _hintFx(Canvas canvas, BoardGeometry geo, SlotGeo s) {
    final pulse = 0.5 + 0.5 * math.sin(g.time * 6);
    if (g.hintSlot == s.index) {
      final rr = RRect.fromRectAndRadius(_tubeRect(s).inflate(geo.tile * 0.1), Radius.circular(geo.tile * 0.26));
      canvas.drawRRect(
          rr,
          _p
            ..style = PaintingStyle.stroke
            ..strokeWidth = geo.tile * (0.07 + 0.05 * pulse)
            ..color = const Color(0xFFFFE066).withValues(alpha: 0.6 + 0.4 * pulse));
      _p.style = PaintingStyle.fill;
    }
    if (g.tutorialSlot == s.index && g.status == GameStatus.playing && !g.busy) {
      _hand(canvas, geo, s);
    }
  }

  void _hand(Canvas canvas, BoardGeometry geo, SlotGeo s) {
    final t = g.time;
    final press = 0.5 + 0.5 * math.sin(t * 5);
    final c = s.center + Offset(s.cross * 0.45, s.along * 0.2 + geo.tile * 0.12 * press);
    final u = geo.tile;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(u * 0.019);
    // glove pointing up-left
    final fill = Paint()..color = Colors.white;
    final line = Paint()
      ..color = const Color(0xFF1B2766)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeJoin = StrokeJoin.round;
    final hand = Path()
      ..moveTo(-8, -30)
      ..cubicTo(-8, -38, 6, -38, 6, -30)
      ..lineTo(6, -8)
      ..cubicTo(14, -12, 22, -8, 22, -2)
      ..cubicTo(30, -4, 36, 2, 34, 8)
      ..lineTo(32, 26)
      ..cubicTo(30, 38, 20, 46, 6, 46)
      ..lineTo(-4, 46)
      ..cubicTo(-14, 46, -20, 40, -26, 30)
      ..lineTo(-34, 16)
      ..cubicTo(-38, 8, -28, 2, -22, 10)
      ..lineTo(-8, 22)
      ..close();
    canvas.drawPath(hand.shift(const Offset(2, 4)), Paint()..color = Colors.black.withValues(alpha: 0.25));
    canvas.drawPath(hand, fill);
    canvas.drawPath(hand, line);
    canvas.restore();
    // tap ripple
    canvas.drawCircle(
        s.center,
        geo.tile * (0.3 + 0.35 * press),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = Colors.white.withValues(alpha: 0.55 * (1 - press)));
  }

  void _particles(Canvas canvas) {
    for (final p in g.particles) {
      final a = (p.life.clamp(0.0, 0.5) / 0.5);
      _p.color = p.color.withValues(alpha: a);
      if (p.kind == 1) {
        canvas.drawCircle(p.p, p.size * 0.6, _p);
      } else if (p.kind == 2) {
        _star(canvas, p.p, p.size * 1.4, p.rot);
      } else {
        canvas.save();
        canvas.translate(p.p.dx, p.p.dy);
        canvas.rotate(p.rot);
        canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.55), _p);
        canvas.restore();
      }
    }
  }

  void _star(Canvas canvas, Offset c, double r, double rot) {
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final rr = i.isEven ? r : r * 0.35;
      final a = rot + i * math.pi / 4;
      final x = c.dx + math.cos(a) * rr, y = c.dy + math.sin(a) * rr;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path..close(), _p);
  }

  void _popups(Canvas canvas) {
    for (final pu in g.popups) {
      final t = pu.t;
      final rise = Curves.easeOut.transform(t.clamp(0.0, 1.0)) * 26;
      final a = t < 0.7 ? 1.0 : 1 - (t - 0.7) / 0.3;
      final sc = 0.7 + 0.3 * Curves.elasticOut.transform((t * 2.2).clamp(0.0, 1.0));
      final c = pu.pos.translate(0, -rise);
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.scale(sc);
      final tp = textPainter(pu.text, 22, color: Colors.white);
      final rr = RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: tp.width + 22, height: tp.height + 10), const Radius.circular(14));
      canvas.drawRRect(rr.inflate(3), _p..color = Colors.white.withValues(alpha: a));
      canvas.drawRRect(rr, _p..color = const Color(0xFF58C93A).withValues(alpha: a));
      canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(rr.left + 3, rr.top + 2, rr.width - 6, rr.height * 0.4), const Radius.circular(10)),
          _p..color = Colors.white.withValues(alpha: 0.25 * a));
      canvas.saveLayer(rr.outerRect.inflate(6), Paint()..color = Color.fromRGBO(255, 255, 255, a));
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(BoardPainter old) => true;
}
