import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';
import 'controller.dart';
import 'engine.dart';
import 'layout.dart';
import 'painting.dart';

double _easeOutBack(double t) {
  const c1 = 1.70158;
  const c3 = c1 + 1;
  final x = t - 1;
  return 1 + c3 * x * x * x + c1 * x * x;
}

class BoardPainter extends CustomPainter {
  BoardPainter(this.g) : super(repaint: g);
  final GameController g;

  final Paint _fill = Paint()..isAntiAlias = true;
  final Paint _stroke = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke;

  @override
  bool shouldRepaint(covariant BoardPainter oldDelegate) => oldDelegate.g != g;

  @override
  void paint(Canvas canvas, Size size) {
    final L = g.layout;
    if (L == null) return;
    _drawOrders(canvas, L);
    _drawQueue(canvas, L);
    _drawLoop(canvas, L);
    _drawStacks(canvas, L);
    _drawFlights(canvas, L);
    _drawParticles(canvas);
  }

  // ------------------------------------------------------------ orders
  void _drawOrders(Canvas c, BoardLayout L) {
    final n = g.dSlots.length;
    for (var j = 0; j < n; j++) {
      final s = g.dSlots[j];
      final r = L.slotRect(j, n);
      final rr = RRect.fromRectAndRadius(r, const Radius.circular(18));
      if (s.empty) {
        drawPlate(c, rr, AppColors.panelDark.withAlpha(120), edge: AppColors.panelEdge.withAlpha(70), edgeW: 2);
        drawText(c, '✓', r.center, 26, color: AppColors.green.withAlpha(150));
      } else {
        final appear = _easeOutBack(s.appear.clamp(0.0, 1.0));
        final scale = (0.55 + 0.45 * appear) * (1 + 0.06 * s.pulse);
        c.save();
        c.translate(r.center.dx, r.center.dy);
        c.scale(scale);
        c.translate(-r.center.dx, -r.center.dy);
        _card(c, L, j, n, r, rr, s.color, s.need, s.total, s.pulse);
        c.restore();
      }
      final gc = s.ghostColor;
      if (gc != null && s.ghostT > 0) {
        final t = s.ghostT;
        final sc = 1 + 0.14 * (1 - t);
        c.save();
        c.translate(r.center.dx, r.center.dy);
        c.scale(sc);
        c.translate(-r.center.dx, -r.center.dy);
        c.saveLayer(r.inflate(12), Paint()..color = Color.fromRGBO(255, 255, 255, t.clamp(0.0, 1.0)));
        final col = AppColors.tile(gc);
        drawPlate(c, rr, const Color(0xFF123242), edge: col, edgeW: 3, depth: 4);
        c.drawRRect(rr, _fill..color = Colors.white.withAlpha(120));
        c.save();
        c.translate(r.center.dx, r.center.dy);
        c.scale(r.height * 0.5);
        c.drawPath(Symbols.check, _fill..color = AppColors.greenDark);
        c.restore();
        c.restore();
        c.restore();
      }
    }
  }

  void _card(Canvas c, BoardLayout L, int j, int n, Rect r, RRect rr, int color, int need, int total, double pulse) {
    final col = AppColors.tile(color);
    drawPlate(c, rr, const Color(0xFF123242), edge: col, edgeW: 3, depth: 4);
    c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(r.left + 3, r.top + 3, r.width - 6, r.height * 0.58), const Radius.circular(15)),
        _fill..color = col.withAlpha(34));
    final ts = L.slotTileSize(n);
    drawTile(c, L.slotTileCenter(j, n), ts, color, scale: 1 + 0.08 * pulse);
    final numC = Offset(r.left + r.width * 0.72, r.top + r.height * 0.42);
    drawText(c, '$need', numC, math.min(r.height * 0.42, 40), color: Colors.white, shadow: const Color(0x66000000));
    final tot = math.max(1, total);
    final pipS = math.min(14.0, (r.width - 24) / tot - 3);
    final rowW = tot * (pipS + 3) - 3;
    var px = r.center.dx - rowW / 2;
    final py = r.bottom - 17;
    final done = total - need;
    for (var k = 0; k < tot; k++) {
      final pr = RRect.fromRectAndRadius(Rect.fromLTWH(px, py - pipS / 2, pipS, pipS), Radius.circular(pipS * 0.3));
      c.drawRRect(pr, _fill..color = k < done ? col : const Color(0xFF2B4A5C));
      px += pipS + 3;
    }
  }

  void _drawQueue(Canvas c, BoardLayout L) {
    final r = L.queueRect;
    drawText(c, 'NEXT', Offset(r.left + 22, r.center.dy), 13, color: AppColors.textDim);
    var x = r.left + 52;
    var q = g.dQi;
    final total = g.lv.orders.length;
    while (q < total && x + 58 < r.right - 62) {
      final o = g.lv.orders[q];
      drawTile(c, Offset(x + 10, r.center.dy - 1), 20, o.color);
      drawText(c, '×${o.need}', Offset(x + 35, r.center.dy), 13, color: AppColors.textDim);
      x += 58;
      q++;
    }
    final left = total - g.dDone;
    drawText(c, '$left left', Offset(r.right - 28, r.center.dy), 13, color: AppColors.amber);
  }

  // ------------------------------------------------------------ loop
  void _drawLoop(Canvas c, BoardLayout L) {
    final rr = RRect.fromRectAndRadius(L.trackRect, Radius.circular(L.trackR));
    final belt = L.beltWidth;
    final count = g.dLoop.length + g.pendingLoopFlights;
    final danger = count >= g.dCap - 1 && g.dCap > 0;
    final flash = g.loopFlash;

    _stroke.strokeWidth = belt + 20;
    c.drawRRect(rr.shift(const Offset(0, 4)), _stroke..color = const Color(0xFF071820));
    _stroke.strokeWidth = belt + 18;
    final railColor = Color.lerp(const Color(0xFF2F7090), AppColors.red, flash)!;
    c.drawRRect(rr, _stroke..color = railColor);
    _stroke.strokeWidth = belt + 10;
    c.drawRRect(rr, _stroke..color = const Color(0xFF0E2A38));
    _stroke.strokeWidth = belt;
    c.drawRRect(rr, _stroke..color = const Color(0xFF173F52));

    // tread marks (moving)
    const marks = 64;
    final off = (g.time * 0.18) % 1.0;
    for (var i = 0; i < marks; i++) {
      final s = (i + off) / marks;
      final p = L.loopPoint(s);
      final p2 = L.loopPoint(s + 0.002);
      final d = p2 - p;
      final len = d.distance;
      if (len == 0) continue;
      final nrm = Offset(-d.dy / len, d.dx / len) * (belt * 0.46);
      _stroke.strokeWidth = 2;
      c.drawLine(p - nrm, p + nrm, _stroke..color = const Color(0x1AFFFFFF));
    }

    // bays
    final cap = math.max(1, g.dCap);
    for (var k = 0; k < cap; k++) {
      final p = L.loopPoint(g.phase + k / cap);
      final empty = k >= g.dLoop.length;
      final bayR = RRect.fromRectAndRadius(
          Rect.fromCenter(center: p, width: L.loopTile * 0.94, height: L.loopTile * 0.94),
          Radius.circular(L.loopTile * 0.22));
      if (empty) {
        c.drawRRect(bayR, _fill..color = const Color(0x22000000));
        _stroke.strokeWidth = 1.6;
        c.drawRRect(bayR, _stroke..color = Colors.white.withAlpha(k < cap ? 40 : 0));
      }
    }

    // tiles on the loop
    for (final lt in g.dLoop) {
      final p = L.loopPoint(g.phase + lt.pos / cap);
      final sc = 1.0 + 0.25 * math.sin(lt.pop * math.pi);
      drawTile(c, p, L.loopTile * 0.94, lt.color, scale: sc);
    }

    // centre read-out
    final ctr = L.trackCenter;
    final grow = 1 + 0.2 * math.sin(g.capGrow * math.pi);
    drawText(c, 'LOOP', ctr.translate(0, -L.trackR * 0.46), 13, color: AppColors.textDim);
    final col = count >= g.dCap
        ? AppColors.red
        : (danger ? AppColors.amber : Colors.white);
    drawText(c, '$count/${g.dCap}', ctr.translate(0, L.trackR * 0.1), 30 * grow,
        color: col, shadow: const Color(0x66000000));
    if (flash > 0) {
      drawText(c, 'FULL', ctr.translate(0, L.trackR * 0.62), 14, color: AppColors.red.withAlpha((flash * 255).round()));
    }
  }

  // ------------------------------------------------------------ stacks
  void _drawStacks(Canvas c, BoardLayout L) {
    final lv = g.lv;
    for (var i = 0; i < lv.stacks.length; i++) {
      final shakeV = g.shake[i] ?? 0;
      final dx = math.sin(g.time * 70) * 6 * shakeV;
      final r = L.stackRect(i).shift(Offset(dx, 0));
      final plate = RRect.fromRectAndRadius(r, const Radius.circular(14));
      final locked = g.isStackLocked(i);
      c.drawRRect(plate, _fill..color = const Color(0x55061821));
      _stroke.strokeWidth = 2;
      c.drawRRect(plate, _stroke..color = Colors.white.withAlpha(22));

      final st = g.dStacks[i];
      final off = lv.stacks[i].length - st.length;
      final run = frontRun(st);
      final popV = g.pop[i] ?? 0;

      if (st.isNotEmpty && !locked) {
        final top = L.stackTileCenter(i, 0).dy - L.tile / 2 - 4;
        final bot = L.stackTileCenter(i, run - 1).dy + L.tile / 2 + 6;
        final hl = RRect.fromRectAndRadius(
            Rect.fromLTRB(r.left + 3, top, r.right - 3, bot), const Radius.circular(12));
        c.drawRRect(hl, _fill..color = Colors.white.withAlpha(16));
        _stroke.strokeWidth = 2;
        c.drawRRect(hl, _stroke..color = Colors.white.withAlpha(70));
      }

      for (var k = st.length - 1; k >= 0; k--) {
        final center = L.stackTileCenter(i, k).translate(dx, 0);
        final mystery = lv.mystery[i][off + k] && k >= run;
        final sc = (k < run && popV > 0) ? 1 + 0.12 * math.sin(popV * math.pi) : 1.0;
        drawTile(c, center, L.tile, st[k], hidden: mystery, scale: sc, dim: locked ? 0.55 : 0);
      }

      if (locked) {
        final need = lv.locks[i] - g.dDone;
        final lc = Offset(r.center.dx + dx, L.stackTileCenter(i, 0).dy + L.tile * 0.3);
        _drawLock(c, lc, L.tile * 0.9, need);
      }

      if (g.hintStack == i && !locked) {
        final pulse = 0.5 + 0.5 * math.sin(g.time * 8);
        final fc = L.stackTileCenter(i, 0).translate(dx, 0);
        _stroke.strokeWidth = 3 + 2 * pulse;
        c.drawRRect(
            RRect.fromRectAndRadius(Rect.fromCenter(center: fc, width: L.tile * 1.18, height: L.tile * 1.18),
                Radius.circular(L.tile * 0.28)),
            _stroke..color = AppColors.amber.withAlpha((150 + 105 * pulse).round()));
        final by = fc.dy - L.tile * 0.95 - 6 * pulse;
        final arrow = Path()
          ..moveTo(fc.dx, by + 12)
          ..lineTo(fc.dx - 11, by - 4)
          ..lineTo(fc.dx + 11, by - 4)
          ..close();
        c.drawPath(arrow, _fill..color = AppColors.amber);
      }
    }
  }

  void _drawLock(Canvas c, Offset ctr, double size, int need) {
    final body = RRect.fromRectAndRadius(
        Rect.fromCenter(center: ctr.translate(0, size * 0.1), width: size * 0.8, height: size * 0.62),
        Radius.circular(size * 0.14));
    _stroke.strokeWidth = size * 0.13;
    c.drawArc(Rect.fromCenter(center: ctr.translate(0, -size * 0.16), width: size * 0.46, height: size * 0.5),
        math.pi, math.pi, false, _stroke..color = const Color(0xFFDDE8EE));
    c.drawRRect(body, _fill..color = AppColors.amber);
    drawText(c, '$need', body.center, size * 0.42, color: const Color(0xFF5A3A00));
  }

  // ------------------------------------------------------------ flights
  void _drawFlights(Canvas c, BoardLayout L) {
    for (final f in g.flights) {
      if (f.t < 0) continue;
      final p = (f.t / f.dur).clamp(0.0, 1.0);
      final to = f.toLoop
          ? g.bayPoint(f.toBay.toDouble())
          : L.slotTileCenter(f.toSlot.clamp(0, math.max(0, g.dSlots.length - 1)), g.dSlots.length);
      final e = Curves.easeInOutCubic.transform(p);
      final arc = math.sin(math.pi * p) * 34;
      final pos = Offset.lerp(f.from, to, e)!.translate(0, -arc);
      final endSize = f.toLoop ? L.loopTile * 0.94 : L.slotTileSize(g.dSlots.length);
      final size = L.tile + (endSize - L.tile) * e;
      drawTile(c, pos, size, f.color, glow: true);
    }
  }

  void _drawParticles(Canvas c) {
    for (final p in g.particles) {
      final a = (p.t * 255).round().clamp(0, 255);
      _fill.color = p.color.withAlpha(a);
      switch (p.kind) {
        case 0:
          c.save();
          c.translate(p.p.dx, p.p.dy);
          c.rotate(p.rot);
          c.drawRect(Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6), _fill);
          c.restore();
          break;
        case 1:
          c.drawCircle(p.p, p.size * 0.5, _fill);
          break;
        default:
          c.save();
          c.translate(p.p.dx, p.p.dy);
          c.rotate(p.rot);
          c.scale(p.size * 1.6);
          c.drawPath(Symbols.paths[3], _fill);
          c.restore();
      }
    }
  }
}
