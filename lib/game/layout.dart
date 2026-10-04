import 'dart:math' as math;
import 'dart:ui';

import 'engine.dart';

/// Piecewise-linear belt path with smooth (rounded) corners baked in.
class BeltPath {
  BeltPath(this.pts, this.closed) {
    final n = pts.length;
    cum = List<double>.filled(n + 1, 0);
    for (var i = 0; i < n; i++) {
      final a = pts[i];
      final b = pts[(i + 1) % n];
      cum[i + 1] = cum[i] + ((closed || i < n - 1) ? (b - a).distance : 0);
    }
    length = cum[n];
  }

  final List<Offset> pts;
  final bool closed;
  late final List<double> cum;
  late final double length;

  double wrap(double u) {
    if (length <= 0) return 0;
    var r = u % length;
    if (r < 0) r += length;
    return r;
  }

  int _seg(double u) {
    var lo = 0, hi = pts.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (cum[mid] <= u) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return math.min(lo, closed ? pts.length - 1 : pts.length - 2);
  }

  Offset pointAt(double u) {
    u = wrap(u);
    final i = _seg(u);
    final a = pts[i];
    final b = pts[(i + 1) % pts.length];
    final l = cum[i + 1] - cum[i];
    final t = l <= 0 ? 0.0 : (u - cum[i]) / l;
    return Offset.lerp(a, b, t)!;
  }

  double angleAt(double u) {
    u = wrap(u);
    final i = _seg(u);
    final a = pts[i];
    final b = pts[(i + 1) % pts.length];
    return math.atan2(b.dy - a.dy, b.dx - a.dx);
  }

  /// Arc position of the point nearest to [p].
  double project(Offset p) {
    var best = double.infinity;
    var bestU = 0.0;
    final segs = closed ? pts.length : pts.length - 1;
    for (var i = 0; i < segs; i++) {
      final a = pts[i];
      final b = pts[(i + 1) % pts.length];
      final ab = b - a;
      final l2 = ab.dx * ab.dx + ab.dy * ab.dy;
      var t = l2 <= 0 ? 0.0 : (((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / l2);
      t = t.clamp(0.0, 1.0);
      final q = a + ab * t;
      final d = (p - q).distanceSquared;
      if (d < best) {
        best = d;
        bestU = cum[i] + (cum[i + 1] - cum[i]) * t;
      }
    }
    return bestU;
  }

  Path toPath() {
    final p = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      p.lineTo(pts[i].dx, pts[i].dy);
    }
    if (closed) p.close();
    return p;
  }
}

/// Rounds the corners of a polygon (or polyline) with circular-ish arcs.
List<Offset> roundedPolygon(List<Offset> poly, double radius, {bool closed = true, int steps = 7}) {
  final out = <Offset>[];
  final n = poly.length;
  for (var i = 0; i < n; i++) {
    if (!closed && (i == 0 || i == n - 1)) {
      out.add(poly[i]);
      continue;
    }
    final prev = poly[(i - 1 + n) % n];
    final cur = poly[i];
    final next = poly[(i + 1) % n];
    final v1 = prev - cur;
    final v2 = next - cur;
    final l1 = v1.distance, l2 = v2.distance;
    final r = math.min(radius, math.min(l1, l2) * 0.5);
    final a = cur + v1 / l1 * r;
    final b = cur + v2 / l2 * r;
    for (var k = 0; k <= steps; k++) {
      final t = k / steps;
      // quadratic bezier a -> cur -> b
      final p = a * ((1 - t) * (1 - t)) + cur * (2 * (1 - t) * t) + b * (t * t);
      out.add(p);
    }
  }
  return out;
}

class SlotGeo {
  SlotGeo({
    required this.index,
    required this.base,
    required this.dir,
    required this.along,
    required this.cross,
    required this.capacity,
    required this.gateArc,
    required this.gate,
    required this.pad,
  });
  final int index;
  final Offset base; // centre of the base end
  final Offset dir; // unit vector from base toward the belt-facing end
  final double along; // size of one tile along dir
  final double cross; // tile width across
  final int capacity;
  final double gateArc;
  final Offset gate; // point on the belt
  final double pad;

  double get length => pad * 2 + along * capacity;
  Offset get entry => base + dir * length;
  Offset get perp => Offset(-dir.dy, dir.dx);

  /// Centre of the tile at [indexFromTop] when the stack has [count] tiles.
  Offset tileCenter(int indexFromTop, int count) =>
      base + dir * (pad + along * (count - 1 - indexFromTop + 0.5));

  /// Centre of the tile that would be added on top of a stack of [count].
  Offset nextCenter(int count) => base + dir * (pad + along * (count + 0.5));

  Offset get center => base + dir * (length / 2);

  bool hit(Offset p, double slack) {
    final d = p - center;
    final u = d.dx * dir.dx + d.dy * dir.dy;
    final v = d.dx * perp.dx + d.dy * perp.dy;
    return u.abs() <= length / 2 + slack && v.abs() <= cross / 2 + 0.2 * cross + slack;
  }
}

class BoardGeometry {
  BoardGeometry(this.level, this.tile, this.belt, this.slots, this.bounds, this.beltWidth);
  final LevelData level;
  final double tile; // pixel size of a tile cross-section
  final BeltPath belt;
  final List<SlotGeo> slots;
  final Rect bounds; // pixels, relative to the board box
  final double beltWidth;

  int? hitSlot(Offset p) {
    for (final s in slots) {
      if (s.hit(p, tile * 0.12)) return s.index;
    }
    return null;
  }

  static BoardGeometry build(LevelData lv, Size area, {double maxTile = 74}) {
    final u = _unit(lv);
    // measure extents in unit space
    var r = Rect.fromPoints(u.belt.pts.first, u.belt.pts.first);
    for (final p in u.belt.pts) {
      r = r.expandToInclude(Rect.fromCenter(center: p, width: 0.001, height: 0.001));
    }
    r = r.inflate(0.75);
    for (final s in u.slots) {
      final a = s.base;
      final b = s.entry;
      r = r.expandToInclude(Rect.fromPoints(a, b).inflate(s.cross * 0.7));
    }
    final scale = math.min(area.width / r.width, area.height / r.height).clamp(8.0, maxTile);
    final off = Offset(area.width / 2 - r.center.dx * scale, area.height / 2 - r.center.dy * scale);
    Offset tf(Offset p) => p * scale + off;
    final belt = BeltPath([for (final p in u.belt.pts) tf(p)], u.belt.closed);
    final slots = <SlotGeo>[];
    for (final s in u.slots) {
      final base = tf(s.base);
      final arc = belt.project(tf(s.entry));
      slots.add(SlotGeo(
        index: s.index,
        base: base,
        dir: s.dir,
        along: s.along * scale,
        cross: s.cross * scale,
        capacity: s.capacity,
        gateArc: arc,
        gate: belt.pointAt(arc),
        pad: s.pad * scale,
      ));
    }
    final bounds = Rect.fromLTWH(r.left * scale + off.dx, r.top * scale + off.dy, r.width * scale, r.height * scale);
    return BoardGeometry(lv, scale, belt, slots, bounds, scale * 0.95);
  }
}

class _US {
  _US(this.index, this.base, this.dir, this.along, this.cross, this.capacity, this.pad);
  final int index;
  final Offset base;
  final Offset dir;
  final double along, cross, pad;
  final int capacity;
  Offset get entry => base + dir * (pad * 2 + along * capacity);
}

class _UL {
  _UL(this.belt, this.slots);
  final BeltPath belt;
  final List<_US> slots;
}

const _gap = 1.62; // centre distance of neighbouring slots (tile widths)
const _vAlong = 0.82; // tile thickness along a vertical stack
const _hAlong = 1.0;
const _pad = 0.14;

BeltPath _shape(String shape, List<Offset> rect, {double r = 1.3}) {
  // rect = [TR, TL, BL, BR] (CCW on screen: top edge flows left)
  final tr = rect[0], tl = rect[1], bl = rect[2], br = rect[3];
  List<Offset> poly;
  switch (shape) {
    case 'oct':
      final c = math.min((tr.dx - tl.dx), (bl.dy - tl.dy)) * 0.2;
      poly = [
        tr + Offset(-c, 0), tl + Offset(c, 0), tl + Offset(0, c), bl + Offset(0, -c),
        bl + Offset(c, 0), br + Offset(-c, 0), br + Offset(0, -c), tr + Offset(0, c),
      ];
      return BeltPath(roundedPolygon(poly, 0.55), true);
    case 'tear': // narrower top
      final inset = (tr.dx - tl.dx) * 0.16;
      poly = [tr + Offset(-inset, 0), tl + Offset(inset, 0), bl, br];
      return BeltPath(roundedPolygon(poly, r * 1.1), true);
    case 'pill':
      return BeltPath(roundedPolygon([tr, tl, bl, br], (bl.dy - tl.dy) * 0.5), true);
    default:
      return BeltPath(roundedPolygon([tr, tl, bl, br], r), true);
  }
}

_UL _unit(LevelData lv) {
  final S = lv.slotCount;
  final C = lv.capacity;
  switch (lv.layout) {
    case 'bar':
      return _bar(S, C);
    case 'ring':
      return _ring(lv.shape, S, C);
    case 'rows':
      return _rows(lv.shape, S, C);
    case 'split':
      return _split(lv.shape, S, C);
    case 'dual':
      return _dual(S, C);
  }
  return _ring('round', S, C);
}

_UL _bar(int S, int C) {
  final tube = C * _vAlong + _pad * 2;
  final W = (S - 1) / 2 * _gap + 1.5;
  const by = -1.5;
  final slots = <_US>[];
  for (var i = 0; i < S; i++) {
    final x = ((S - 1) / 2 - i) * _gap;
    slots.add(_US(i, Offset(x, tube), const Offset(0, -1), _vAlong, 1.0, C, _pad));
  }
  return _UL(BeltPath([Offset(W, by), Offset(-W, by)], false), slots);
}

_UL _ring(String shape, int S, int C) {
  final tube = C * _vAlong + _pad * 2;
  final R = (S - 1) / 2 * _gap + 1.55;
  const top = -1.35;
  final bot = tube + 1.35;
  final slots = <_US>[];
  for (var i = 0; i < S; i++) {
    final x = ((S - 1) / 2 - i) * _gap;
    slots.add(_US(i, Offset(x, tube), const Offset(0, -1), _vAlong, 1.0, C, _pad));
  }
  if (shape == 'bump' && S >= 3) {
    final rm = math.max(0.9, (S - 1) / 2 * _gap - 0.2);
    final poly = [
      Offset(R, -0.62), Offset(rm + 0.4, -0.62), Offset(rm + 0.4, top - 0.3), Offset(-rm - 0.4, top - 0.3),
      Offset(-rm - 0.4, -0.62), Offset(-R, -0.62), Offset(-R, bot), Offset(R, bot),
    ];
    return _UL(BeltPath(roundedPolygon(poly, 0.7), true), slots);
  }
  final belt = _shape(shape, [Offset(R, top), Offset(-R, top), Offset(-R, bot), Offset(R, bot)]);
  return _UL(belt, slots);
}

_UL _rows(String shape, int S, int C) {
  final tube = C * _hAlong + _pad * 2;
  const rowGap = 1.32;
  final slots = <_US>[];
  for (var i = 0; i < S; i++) {
    final y = i * rowGap;
    slots.add(_US(i, Offset(tube / 2, y), const Offset(-1, 0), _hAlong, 0.94, C, _pad));
  }
  final left = -tube / 2 - 1.35;
  final right = tube / 2 + 1.35;
  final top = -1.25;
  final bot = (S - 1) * rowGap + 1.25;
  final belt = _shape(shape, [Offset(right, top), Offset(left, top), Offset(left, bot), Offset(right, bot)], r: 1.2);
  return _UL(belt, slots);
}

_UL _split(String shape, int S, int C) {
  final tube = C * _vAlong + _pad * 2;
  final nTop = (S + 1) ~/ 2;
  final nBot = S - nTop;
  final g = _gap;
  final w = math.max(nTop, nBot) * g;
  final R = w / 2 + 0.9;
  const ringTop = 1.0;
  const ringH = 2.7;
  final slots = <_US>[];
  // top slots (entry at bottom, pointing down), indices 0..nTop-1 right -> left
  for (var k = 0; k < nTop; k++) {
    final x = nTop == 1 ? 0.0 : ((nTop - 1) / 2 - k) * g * (w / (nTop * g)) * 0.98;
    slots.add(_US(k, Offset(x, ringTop - 0.75 - tube), const Offset(0, 1), _vAlong, 1.0, C, _pad));
  }
  for (var k = 0; k < nBot; k++) {
    final x = nBot == 1 ? 0.0 : (k - (nBot - 1) / 2) * g * (w / (nBot * g)) * 0.98;
    slots.add(_US(nTop + k, Offset(x, ringTop + ringH + 0.75 + tube), const Offset(0, -1), _vAlong, 1.0, C, _pad));
  }
  final belt = _shape(shape, [Offset(R, ringTop), Offset(-R, ringTop), Offset(-R, ringTop + ringH), Offset(R, ringTop + ringH)], r: 1.2);
  return _UL(belt, slots);
}

_UL _dual(int S, int C) {
  final tube = C * _vAlong + _pad * 2;
  const step = 0.84;
  final slots = <_US>[];
  for (var i = 0; i < S; i++) {
    final x = ((S - 1) / 2 - i) * step;
    if (i.isEven) {
      slots.add(_US(i, Offset(x, -0.95 - tube), const Offset(0, 1), _vAlong, 1.0, C, _pad));
    } else {
      slots.add(_US(i, Offset(x, 0.95 + tube), const Offset(0, -1), _vAlong, 1.0, C, _pad));
    }
  }
  final W = (S - 1) / 2 * step + 1.6;
  return _UL(BeltPath([Offset(W, 0), Offset(-W, 0)], false), slots);
}
