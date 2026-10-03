import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Geometry of the game board for a given canvas size.
class BoardLayout {
  BoardLayout(this.size, {required this.stackCount, required this.maxDepth}) {
    _compute();
  }

  final Size size;
  final int stackCount;
  final int maxDepth;

  late Rect ordersRect;
  late Rect queueRect;
  late Rect loopRect;
  late Rect stacksRect;
  late double colW;
  late double tile; // stack tile size
  late double loopTile;
  late double beltWidth;
  late Rect trackRect; // centre-line of the belt (stadium)
  late double trackR;
  late double trackA; // half length of straight sections
  late double perim;
  late Offset trackCenter;

  void _compute() {
    final w = size.width, h = size.height;
    const pad = 12.0;
    final ordersH = (h * 0.175).clamp(86.0, 120.0).toDouble();
    ordersRect = Rect.fromLTWH(pad, 4, w - pad * 2, ordersH);
    queueRect = Rect.fromLTWH(pad, ordersRect.bottom + 4, w - pad * 2, 24);
    final loopH = (h * 0.235).clamp(116.0, 188.0).toDouble();
    loopRect = Rect.fromLTWH(pad, queueRect.bottom + 4, w - pad * 2, loopH);
    stacksRect = Rect.fromLTRB(pad, loopRect.bottom + 8, w - pad, h - 4);

    colW = stacksRect.width / stackCount;
    final byW = colW * 0.82;
    final byH = (stacksRect.height - 16) / (maxDepth * 1.07 + 0.1);
    tile = math.min(byW, byH).clamp(18.0, 62.0).toDouble();

    loopTile = (loopRect.height * 0.28).clamp(22.0, 38.0).toDouble();
    beltWidth = loopTile + 12;
    trackCenter = loopRect.center;
    trackR = (loopRect.height - beltWidth) / 2 - 2;
    trackA = math.max(12.0, (loopRect.width - 2 * trackR - beltWidth) / 2 - 4);
    perim = 4 * trackA + 2 * math.pi * trackR;
    trackRect = Rect.fromCenter(
        center: trackCenter, width: 2 * trackA + 2 * trackR, height: 2 * trackR);
  }

  // ------------------------------------------------------------ orders
  Rect slotRect(int j, int n) {
    const gap = 8.0;
    final sw = (ordersRect.width - gap * (n - 1)) / n;
    return Rect.fromLTWH(ordersRect.left + j * (sw + gap), ordersRect.top, sw, ordersRect.height);
  }

  double slotTileSize(int n) {
    final r = slotRect(0, n);
    return math.min(r.height * 0.42, r.width * 0.4);
  }

  Offset slotTileCenter(int j, int n) {
    final r = slotRect(j, n);
    final t = slotTileSize(n);
    return Offset(r.left + r.width * 0.33, r.top + r.height * 0.40);
  }

  // ------------------------------------------------------------ loop
  /// Point on the belt centre-line for parameter [s] (wraps, 0 = top centre,
  /// clockwise).
  Offset loopPoint(double s) {
    var d = (s - s.floorToDouble()) * perim;
    final cx = trackCenter.dx, cy = trackCenter.dy;
    final a = trackA, r = trackR;
    if (d < a) return Offset(cx + d, cy - r);
    d -= a;
    if (d < math.pi * r) {
      final th = -math.pi / 2 + d / r;
      return Offset(cx + a + r * math.cos(th), cy + r * math.sin(th));
    }
    d -= math.pi * r;
    if (d < 2 * a) return Offset(cx + a - d, cy + r);
    d -= 2 * a;
    if (d < math.pi * r) {
      final th = math.pi / 2 + d / r;
      return Offset(cx - a + r * math.cos(th), cy + r * math.sin(th));
    }
    d -= math.pi * r;
    return Offset(cx - a + d, cy - r);
  }

  // ------------------------------------------------------------ stacks
  Rect stackRect(int i) =>
      Rect.fromLTWH(stacksRect.left + colW * i + 3, stacksRect.top, colW - 6, stacksRect.height);

  double get tileStep => tile * 1.07;

  Offset stackTileCenter(int i, int k) => Offset(
      stacksRect.left + colW * (i + 0.5), stacksRect.top + 10 + tileStep * (k + 0.5));

  int? stackAt(Offset p) {
    if (p.dy < stacksRect.top - 26) return null;
    for (var i = 0; i < stackCount; i++) {
      final r = stackRect(i);
      if (p.dx >= r.left - 2 && p.dx <= r.right + 2) return i;
    }
    return null;
  }
}
