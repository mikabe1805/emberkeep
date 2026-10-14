// The weekend brawl's effects: pooled particles, attack smears, rings,
// floating numbers and lightning, plus the little drawing helpers (outlined
// text, icons) the HUD shares. A port of the prototype's fx.js.
//
// Positions are world x (the camera subtracts its own) and screen y, which
// grows down. Nothing here allocates per frame beyond a path or two: the pool
// is fixed, text is laid out once per distinct string and kept.
library;

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/painting.dart'
    show
        FontStyle,
        FontWeight,
        TextBaseline,
        TextDirection,
        TextPainter,
        TextSpan,
        TextStyle;

const double _tau = math.pi * 2;

double _clamp(double v, double a, double b) => v < a ? a : (v > b ? b : v);

const String kBrawlSerif = 'EBGaramond';
const String kBrawlMono = 'JetBrainsMono';

// ------------------------------------------------------------------ text

class _Label {
  _Label(this.fill, this.stroke);
  final TextPainter fill;
  final TextPainter? stroke;
}

/// Laid-out text, remembered by what it says and how it looks.
abstract final class BrawlText {
  static final Map<String, _Label> _cache = {};

  static _Label _label(
    String text,
    double size,
    Color fill,
    FontWeight weight,
    String family,
    bool italic,
    Color? stroke,
    double strokeW,
  ) {
    final key =
        '$text|${size.toStringAsFixed(1)}|${fill.toARGB32()}|${weight.value}'
        '|$family|$italic|${stroke?.toARGB32()}|${strokeW.toStringAsFixed(1)}';
    final hit = _cache[key];
    if (hit != null) return hit;
    if (_cache.length > 500) _cache.clear();
    TextPainter make(TextStyle style) => TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    final base = TextStyle(
      fontFamily: family,
      fontSize: size,
      fontWeight: weight,
      fontStyle: italic ? FontStyle.italic : FontStyle.normal,
      height: 1,
    );
    final label = _Label(
      make(base.copyWith(color: fill)),
      stroke == null
          ? null
          : make(
              base.copyWith(
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = strokeW
                  ..strokeJoin = StrokeJoin.round
                  ..color = stroke,
              ),
            ),
    );
    return _cache[key] = label;
  }

  /// Draws [text] with its baseline at [y]. [align] is -1 left, 0 centre, 1
  /// right. Returns the width.
  static double draw(
    Canvas c,
    String text,
    double x,
    double y, {
    double size = 14,
    Color fill = const Color(0xFFFFF4D9),
    FontWeight weight = FontWeight.w800,
    String family = kBrawlSerif,
    bool italic = false,
    int align = 0,
    Color? stroke,
    double strokeW = 3,
    double alpha = 1,
  }) {
    final l = _label(text, size, fill, weight, family, italic, stroke, strokeW);
    final w = l.fill.width;
    final base = l.fill.computeDistanceToActualBaseline(
      TextBaseline.alphabetic,
    );
    final ox = x - (align == 0 ? w / 2 : (align > 0 ? w : 0));
    final oy = y - base;
    final layer = alpha < 0.99;
    if (layer) {
      c.saveLayer(
        Rect.fromLTWH(ox - 8, oy - 8, w + 16, l.fill.height + 16),
        Paint()..color = Color.fromRGBO(0, 0, 0, _clamp(alpha, 0, 1)),
      );
    }
    l.stroke?.paint(c, Offset(ox, oy));
    l.fill.paint(c, Offset(ox, oy));
    if (layer) c.restore();
    return w;
  }

  static final Map<String, _Label> _gold = {};

  /// The announcer's word: a dark outline and a gold gradient through the
  /// letters, centred on x 0 with its baseline at y 0 of the current canvas.
  /// [kind] 0 is plain gold, 1 bright, 2 hot.
  static void drawGold(Canvas c, String text, double size, int kind) {
    final key = '$text|$size|$kind';
    var l = _gold[key];
    if (l == null) {
      final colors = switch (kind) {
        2 => const [Color(0xFFFFF4D9), Color(0xFFFFD25A), Color(0xFFE58A32)],
        1 => const [Color(0xFFFFFFFF), Color(0xFFFFE3A0), Color(0xFFF2B04A)],
        _ => const [Color(0xFFFFF9E8), Color(0xFFF6D089), Color(0xFFC9893A)],
      };
      final stops = kind == 1 ? const [0.0, 0.45, 1.0] : const [0.0, 0.5, 1.0];
      final base = TextStyle(
        fontFamily: kBrawlSerif,
        fontSize: size,
        fontWeight: FontWeight.w800,
        height: 1,
      );
      TextPainter make(TextStyle style) => TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      final probe = make(base);
      final baseline = probe.computeDistanceToActualBaseline(
        TextBaseline.alphabetic,
      );
      l = _Label(
        make(
          base.copyWith(
            foreground: Paint()
              ..shader = Gradient.linear(
                Offset(0, -size * 0.7 + baseline),
                Offset(0, size * 0.1 + baseline),
                colors,
                stops,
              ),
          ),
        ),
        make(
          base.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = size * 0.2
              ..strokeJoin = StrokeJoin.round
              ..color = const Color(0xFF2A1608),
          ),
        ),
      );
      _gold[key] = l;
    }
    final w = l.fill.width;
    final base = l.fill.computeDistanceToActualBaseline(
      TextBaseline.alphabetic,
    );
    final o = Offset(-w / 2, -base);
    l.stroke!.paint(c, o);
    l.fill.paint(c, o);
  }

  /// The width [text] takes.
  static double width(
    String text,
    double size, {
    FontWeight weight = FontWeight.w800,
    String family = kBrawlSerif,
    bool italic = false,
  }) => _label(
    text,
    size,
    const Color(0xFFFFFFFF),
    weight,
    family,
    italic,
    null,
    0,
  ).fill.width;
}

// ------------------------------------------------------------------ shapes

Path star4Path(double x, double y, double r, double rot) {
  final path = Path();
  for (var i = 0; i < 8; i++) {
    final a = rot + i * math.pi / 4;
    final rr = i.isOdd ? r * 0.3 : r;
    final px = x + math.cos(a) * rr, py = y + math.sin(a) * rr;
    if (i == 0) {
      path.moveTo(px, py);
    } else {
      path.lineTo(px, py);
    }
  }
  return path..close();
}

Path _crescent(
  double cx,
  double cy,
  double r,
  double a0,
  double a1,
  double w,
  double grow,
) {
  const n = 12;
  final aEnd = a0 + (a1 - a0) * grow;
  double width(double u) =>
      w * math.pow(math.sin(math.pi * math.min(1.0, 0.12 + 0.88 * u)), 0.8);
  final path = Path();
  for (var i = 0; i <= n; i++) {
    final u = i / n, a = a0 + (aEnd - a0) * u;
    final rr = r + width(u) * 0.5;
    final px = cx + math.cos(a) * rr, py = cy + math.sin(a) * rr;
    if (i == 0) {
      path.moveTo(px, py);
    } else {
      path.lineTo(px, py);
    }
  }
  for (var i = n; i >= 0; i--) {
    final u = i / n, a = a0 + (aEnd - a0) * u;
    final rr = r - width(u) * 0.5;
    path.lineTo(cx + math.cos(a) * rr, cy + math.sin(a) * rr);
  }
  return path..close();
}

/// The six glyphs on the buttons, drawn around ([x], [y]) in a box of [s].
void brawlIcon(
  Canvas c,
  String name,
  double x,
  double y,
  double s,
  Color col, [
  double lw = 2,
]) {
  c.save();
  c.translate(x, y);
  c.scale(s / 24, s / 24);
  c.translate(-12, -12);
  final fill = Paint()
    ..isAntiAlias = true
    ..color = col;
  final line = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeWidth = lw
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = col;
  RRect rr(double a, double b, double w, double h, double r) =>
      RRect.fromRectAndRadius(Rect.fromLTWH(a, b, w, h), Radius.circular(r));
  switch (name) {
    case 'fist':
      c.drawRRect(rr(5.5, 9.5, 13, 9, 3.6), line);
      c.drawPath(
        Path()
          ..moveTo(9, 9.5)
          ..lineTo(9, 7.6)
          ..moveTo(12.2, 9.5)
          ..lineTo(12.2, 6.4)
          ..moveTo(15.4, 9.5)
          ..lineTo(15.4, 7.6)
          ..moveTo(5.5, 14)
          ..lineTo(3.8, 14),
        line,
      );
    case 'bolt':
      c.drawPath(
        Path()
          ..moveTo(13, 3)
          ..lineTo(5.5, 13.6)
          ..lineTo(10.8, 13.6)
          ..lineTo(9.8, 21)
          ..lineTo(18.5, 10)
          ..lineTo(13.1, 10)
          ..close(),
        fill,
      );
    case 'friends':
      c.drawCircle(const Offset(9, 8.5), 3, line);
      c.drawCircle(const Offset(16.6, 9.4), 2.4, line);
      c.drawPath(
        Path()
          ..moveTo(3.5, 19.5)
          ..quadraticBezierTo(4.2, 14.6, 9, 14.6)
          ..quadraticBezierTo(13.8, 14.6, 14.5, 19.5)
          ..moveTo(14.7, 14.6)
          ..quadraticBezierTo(19.6, 14, 20.7, 19),
        line,
      );
    case 'super':
      c.drawPath(
        Path()
          ..moveTo(12, 2.5)
          ..lineTo(14.4, 9.6)
          ..lineTo(21.5, 12)
          ..lineTo(14.4, 14.4)
          ..lineTo(12, 21.5)
          ..lineTo(9.6, 14.4)
          ..lineTo(2.5, 12)
          ..lineTo(9.6, 9.6)
          ..close(),
        fill,
      );
    case 'lock':
      c.drawRRect(rr(6, 11, 12, 9, 2.6), line);
      c.drawPath(
        Path()
          ..moveTo(8.6, 11)
          ..lineTo(8.6, 8.4)
          ..arcTo(
            Rect.fromCircle(center: const Offset(12, 8.4), radius: 3.4),
            math.pi,
            math.pi,
            false,
          )
          ..lineTo(15.4, 11),
        line,
      );
    case 'sparkle':
      c.drawPath(
        Path()
          ..moveTo(12, 2)
          ..quadraticBezierTo(12.8, 11.2, 22, 12)
          ..quadraticBezierTo(12.8, 12.8, 12, 22)
          ..quadraticBezierTo(11.2, 12.8, 2, 12)
          ..quadraticBezierTo(11.2, 11.2, 12, 2),
        fill,
      );
  }
  c.restore();
}

// ------------------------------------------------------------------ particles

enum FxKind { dust, spark, star, puff, drop, text, plus, conf }

class _Part {
  bool on = false;
  FxKind type = FxKind.dust;
  double x = 0, y = 0, vx = 0, vy = 0, t = 0, life = 1;
  double size = 1, size1 = 1;
  Color col = const Color(0xFFFFFFFF);
  double grav = 0, drag = 0, rot = 0, vr = 0, a0 = 1;
  String text = '';
  bool front = true, add = false;
}

enum SmearKind { streak, arc, burst, speed }

class Smear {
  Smear.streak({
    required this.x,
    required this.y,
    this.ang = 0,
    required this.len,
    required this.w,
    this.off = 0,
    this.dir = 1,
    this.delay = 0,
    this.life = 0.14,
    this.a = 0.9,
    this.col = const Color(0xFFFFF4D9),
  }) : kind = SmearKind.streak,
       t = -delay;

  Smear.arc({
    required this.x,
    required this.y,
    required this.r,
    required this.a0,
    required this.a1,
    required this.w,
    this.delay = 0,
    this.life = 0.14,
    this.a = 0.9,
    this.col = const Color(0xFFFFF4D9),
  }) : kind = SmearKind.arc,
       t = -delay;

  Smear.burst({
    required this.x,
    required this.y,
    required this.r,
    this.rot = 0,
    this.life = 0.14,
    this.big = false,
  }) : kind = SmearKind.burst,
       t = 0;

  Smear.speed({
    required this.x,
    required this.y,
    required this.dx,
    required this.dy,
    required this.w,
    this.life = 0.2,
    this.delay = 0,
    this.a = 0.9,
    this.col = const Color(0xFFFFF4D9),
  }) : kind = SmearKind.speed,
       t = -delay;

  final SmearKind kind;
  double x = 0, y = 0;
  double ang = 0, len = 0, w = 0, off = 0, dir = 1;
  double r = 0, a0 = 0, a1 = 0, rot = 0;
  double dx = 0, dy = 0;
  double delay = 0, life = 0.14, a = 0.9;
  bool big = false;
  Color col = const Color(0xFFFFF4D9);
  double t;
}

class _Ring {
  _Ring(
    this.x,
    this.y,
    this.r0,
    this.r1,
    this.life,
    this.col,
    this.w,
    this.flat,
  );
  final double x, y, r0, r1, life, w, flat;
  final Color col;
  double t = 0;
}

class _Num {
  _Num({
    required this.x,
    required this.y,
    required this.text,
    required this.life,
    required this.size,
    required this.col,
    required this.vy,
    required this.pop,
    required this.crit,
    required this.vx,
    required this.tag,
  });
  double x, y;
  final String text;
  double t = 0;
  final double life, size, vy, pop, vx;
  final Color col;
  final bool crit;
  final String tag;
}

class _Arc {
  _Arc(this.x1, this.y1, this.x2, this.y2, this.life, this.col, this.seed);
  final double x1, y1, x2, y2, life, seed;
  final Color col;
  double t = 0;
}

/// The effects of one fight.
class BrawlFx {
  BrawlFx(this.rnd);

  final math.Random rnd;
  static const int _max = 420;
  final List<_Part> _pool = List.generate(_max, (_) => _Part());
  int _head = 0;
  final List<Smear> _smears = [];
  final List<_Ring> _rings = [];
  final List<_Num> _nums = [];
  final List<_Arc> _bolts = [];

  final Paint _p = Paint()..isAntiAlias = true;

  int get liveParticles => _pool.where((p) => p.on).length;
  int get liveNumbers => _nums.length;

  void reset() {
    for (final p in _pool) {
      p.on = false;
    }
    _smears.clear();
    _rings.clear();
    _nums.clear();
    _bolts.clear();
  }

  void part(
    FxKind type,
    double x,
    double y,
    double vx,
    double vy,
    double life,
    double size,
    Color col, {
    double? size1,
    double grav = 0,
    double drag = 0,
    double rot = 0,
    double vr = 0,
    double a = 1,
    String text = '',
    bool front = true,
    bool add = false,
  }) {
    _Part? p;
    for (var k = 0; k < _max; k++) {
      final q = _pool[(_head + k) % _max];
      if (!q.on) {
        p = q;
        _head = (_head + k + 1) % _max;
        break;
      }
    }
    if (p == null) {
      p = _pool[_head];
      _head = (_head + 1) % _max;
    }
    p
      ..on = true
      ..type = type
      ..x = x
      ..y = y
      ..vx = vx
      ..vy = vy
      ..t = 0
      ..life = life
      ..size = size
      ..size1 = size1 ?? size
      ..col = col
      ..grav = grav
      ..drag = drag
      ..rot = rot
      ..vr = vr
      ..a0 = a
      ..text = text
      ..front = front
      ..add = add;
  }

  void ring(
    double x,
    double y,
    double r0,
    double r1,
    double life,
    Color col, [
    double w = 3,
    double flat = 1,
  ]) => _rings.add(_Ring(x, y, r0, r1, life, col, w, flat));

  void smear(Smear s) => _smears.add(s);

  void num(
    double x,
    double y,
    String text, {
    double life = 0.85,
    double size = 22,
    Color col = const Color(0xFFFFF4D9),
    double vy = -74,
    double pop = 1.5,
    bool crit = false,
    double vx = 0,
    String tag = '',
  }) {
    _nums.add(
      _Num(
        x: x,
        y: y,
        text: text,
        life: life,
        size: size,
        col: col,
        vy: vy,
        pop: pop,
        crit: crit,
        vx: vx,
        tag: tag,
      ),
    );
    if (_nums.length > 40) _nums.removeAt(0);
  }

  void arc(double x1, double y1, double x2, double y2, [double life = 0.2]) =>
      _bolts.add(
        _Arc(
          x1,
          y1,
          x2,
          y2,
          life,
          const Color(0xFFBFF3EE),
          rnd.nextDouble() * 100,
        ),
      );

  void update(double dt) {
    for (final p in _pool) {
      if (!p.on) continue;
      p.t += dt;
      if (p.t >= p.life) {
        p.on = false;
        continue;
      }
      if (p.drag != 0) {
        final k = math.max(0.0, 1 - p.drag * dt);
        p.vx *= k;
        p.vy *= k;
      }
      p.vy += p.grav * dt;
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.rot += p.vr * dt;
    }
    for (var i = _smears.length - 1; i >= 0; i--) {
      final s = _smears[i];
      s.t += dt;
      if (s.t >= s.life) _smears.removeAt(i);
    }
    for (var i = _rings.length - 1; i >= 0; i--) {
      final r = _rings[i];
      r.t += dt;
      if (r.t >= r.life) _rings.removeAt(i);
    }
    for (var i = _nums.length - 1; i >= 0; i--) {
      final n = _nums[i];
      n.t += dt;
      n.y += n.vy * dt * math.max(0.15, 1 - n.t / n.life * 0.9);
      n.x += n.vx * dt;
      if (n.t >= n.life) _nums.removeAt(i);
    }
    for (var i = _bolts.length - 1; i >= 0; i--) {
      final b = _bolts[i];
      b.t += dt;
      if (b.t >= b.life) _bolts.removeAt(i);
    }
  }

  /// Layer 0: dust and mist that sit behind the characters.
  void drawBack(Canvas c, double camX) {
    for (final p in _pool) {
      if (p.on && !p.front) _drawPart(c, p, camX);
    }
  }

  /// Layer 1: everything bright, in front.
  void drawFront(Canvas c, double camX) {
    for (final p in _pool) {
      if (p.on && p.front && !p.add) _drawPart(c, p, camX);
    }
    for (final r in _rings) {
      final u = r.t / r.life, e = 1 - math.pow(1 - u, 3).toDouble();
      final rr = r.r0 + (r.r1 - r.r0) * e;
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = r.w * (1 - u * 0.7)
        ..color = r.col.withValues(alpha: r.col.a * (1 - u) * 0.9);
      c.drawOval(
        Rect.fromCenter(
          center: Offset(r.x - camX, r.y),
          width: rr * 2,
          height: rr * 2 * r.flat,
        ),
        _p,
      );
    }
    _p
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.plus;
    for (final p in _pool) {
      if (p.on && p.front && p.add) _drawPart(c, p, camX);
    }
    for (final s in _smears) {
      if (s.t < 0) continue;
      _drawSmear(c, s, camX);
    }
    for (final b in _bolts) {
      final u = b.t / b.life;
      final pts = <Offset>[Offset(b.x1 - camX, b.y1)];
      const n = 6;
      for (var k = 1; k < n; k++) {
        final f = k / n;
        pts.add(
          Offset(
            b.x1 -
                camX +
                (b.x2 - b.x1) * f +
                math.sin(b.seed + k * 7 + b.t * 60) * 7,
            b.y1 + (b.y2 - b.y1) * f + math.cos(b.seed + k * 5 + b.t * 50) * 7,
          ),
        );
      }
      pts.add(Offset(b.x2 - camX, b.y2));
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (var k = 1; k < pts.length; k++) {
        path.lineTo(pts[k].dx, pts[k].dy);
      }
      _p
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 3.2 * (1 - u * 0.5)
        ..color = b.col.withValues(alpha: 1 - u);
      c.drawPath(path, _p);
      _p
        ..strokeWidth = 1.2
        ..color = const Color(0xFFFFFFFF).withValues(alpha: 1 - u);
      c.drawPath(path, _p);
    }
    _p
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.srcOver;
  }

  void _drawSmear(Canvas c, Smear s, double camX) {
    final u = s.t / s.life, x = s.x - camX, y = s.y;
    switch (s.kind) {
      case SmearKind.streak:
        c.save();
        c.translate(x, y);
        c.rotate(s.ang);
        final len = s.len * (0.55 + 0.45 * math.min(1.0, u * 3));
        final w = s.w * (1 - u * 0.6);
        _p
          ..style = PaintingStyle.fill
          ..color = s.col.withValues(alpha: (1 - u) * s.a);
        c.drawPath(
          Path()
            ..moveTo(s.dir * s.off, 0)
            ..quadraticBezierTo(
              s.dir * (len * 0.5),
              -w,
              s.dir * (len + s.off),
              0,
            )
            ..quadraticBezierTo(s.dir * (len * 0.5), w * 0.6, s.dir * s.off, 0),
          _p,
        );
        c.restore();
      case SmearKind.arc:
        _p
          ..style = PaintingStyle.fill
          ..color = s.col.withValues(alpha: (1 - u) * s.a);
        c.drawPath(
          _crescent(
            x,
            y,
            s.r,
            s.a0,
            s.a1,
            s.w * (1 - u * 0.5),
            math.min(1.0, u * 3.2 + 0.25),
          ),
          _p,
        );
      case SmearKind.burst:
        final r = s.r * (0.35 + 0.65 * math.min(1.0, u * 2.4));
        final a = 1 - u;
        _p
          ..style = PaintingStyle.fill
          ..shader = Gradient.radial(
            Offset(x, y),
            r,
            [
              Color.fromRGBO(255, 255, 255, 0.95 * a),
              Color.fromRGBO(255, 238, 190, 0.5 * a),
              Color.fromRGBO(255, 220, 150, 0),
            ],
            const [0, 0.4, 1],
          );
        c.drawCircle(Offset(x, y), r, _p);
        _p
          ..shader = null
          ..color = const Color(0xFFFFFFFF).withValues(alpha: a);
        c.drawPath(
          star4Path(x, y, r * (s.big ? 1.25 : 0.95) * (1 - u * 0.4), s.rot),
          _p,
        );
      case SmearKind.speed:
        _p
          ..style = PaintingStyle.stroke
          ..strokeWidth = s.w
          ..strokeCap = StrokeCap.round
          ..color = s.col.withValues(alpha: (1 - u) * s.a);
        c.drawLine(
          Offset(x, y),
          Offset(x + s.dx * (1 - u * 0.3), y + s.dy * (1 - u * 0.3)),
          _p,
        );
        _p.style = PaintingStyle.fill;
    }
  }

  void _drawPart(Canvas c, _Part p, double camX) {
    final u = p.t / p.life, x = p.x - camX, y = p.y;
    final a = (p.a0 * (1 - u)).clamp(0.0, 1.0);
    final saved = _p.blendMode;
    _p
      ..shader = null
      ..style = PaintingStyle.fill
      ..blendMode = p.add ? BlendMode.plus : BlendMode.srcOver;
    switch (p.type) {
      case FxKind.dust:
        _p.color = p.col.withValues(alpha: a * 0.55);
        c.drawCircle(Offset(x, y), p.size + (p.size1 - p.size) * u, _p);
      case FxKind.puff:
        _p.color = p.col.withValues(alpha: a * 0.7);
        c.drawCircle(Offset(x, y), p.size + (p.size1 - p.size) * u, _p);
      case FxKind.spark:
        _p
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = p.size * (1 - u * 0.5)
          ..color = p.col.withValues(alpha: a);
        c.drawLine(
          Offset(x, y),
          Offset(x - p.vx * 0.045, y - p.vy * 0.045),
          _p,
        );
        _p.style = PaintingStyle.fill;
      case FxKind.star:
        _p.color = p.col.withValues(alpha: a);
        c.drawPath(star4Path(x, y, p.size * (1 - u * 0.5) + 1, p.rot), _p);
      case FxKind.drop:
        _p.color = p.col.withValues(alpha: a);
        c.drawCircle(Offset(x, y + 1), p.size, _p);
        c.drawPath(
          Path()
            ..moveTo(x - p.size, y + 1)
            ..lineTo(x, y - p.size * 2.2)
            ..lineTo(x + p.size, y + 1)
            ..close(),
          _p,
        );
      case FxKind.text:
        BrawlText.draw(
          c,
          p.text,
          x,
          y,
          size: p.size + (p.size1 - p.size) * u,
          fill: p.col,
          stroke: const Color.fromRGBO(30, 14, 6, 0.7),
          strokeW: 3,
          alpha: a,
        );
      case FxKind.plus:
        _p.color = p.col.withValues(alpha: a);
        c.drawRect(
          Rect.fromLTWH(x - p.size, y - p.size * 0.3, p.size * 2, p.size * 0.6),
          _p,
        );
        c.drawRect(
          Rect.fromLTWH(x - p.size * 0.3, y - p.size, p.size * 0.6, p.size * 2),
          _p,
        );
      case FxKind.conf:
        _p.color = p.col.withValues(alpha: a);
        c.save();
        c.translate(x, y);
        c.rotate(p.rot);
        c.drawRect(
          Rect.fromLTWH(-p.size, -p.size * 0.5, p.size * 2, p.size),
          _p,
        );
        c.restore();
    }
    _p.blendMode = saved;
  }

  /// Floating damage numbers, over everything in the world.
  void drawNums(Canvas c, double camX) {
    for (final n in _nums) {
      final u = n.t / n.life;
      final pop = u < 0.14 ? n.pop - (n.pop - 1) * (u / 0.14) : 1.0;
      final alpha = u > 0.65 ? 1 - (u - 0.65) / 0.35 : 1.0;
      c.save();
      c.translate(n.x - camX, n.y);
      c.scale(pop, pop);
      BrawlText.draw(
        c,
        n.text,
        0,
        0,
        size: n.size,
        fill: n.col,
        stroke: const Color.fromRGBO(30, 14, 6, 0.92),
        strokeW: math.max(3.5, n.size * 0.2),
        alpha: alpha,
      );
      final tag = n.crit && n.tag.isEmpty ? 'CRIT' : n.tag;
      if (tag.isNotEmpty) {
        BrawlText.draw(
          c,
          tag,
          0,
          -n.size * 0.82,
          size: (n.size * 0.42).roundToDouble(),
          fill: n.crit ? const Color(0xFFFFE8A8) : n.col,
          weight: FontWeight.w700,
          family: kBrawlMono,
          stroke: const Color.fromRGBO(30, 14, 6, 0.92),
          strokeW: 3,
          alpha: alpha,
        );
      }
      c.restore();
    }
  }
}

// Kept for callers that only need the constant.
const double brawlTau = _tau;
