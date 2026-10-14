// The weekend brawl's painted paper dolls: the fighter, the Couch Troll and the
// Fog, as trees of named parts that clips write rotation, offset and scale to.
//
// A port of the prototype's rig.js. Animation never touches shapes: a pose is
// five numbers per part (rotation, x, y, scale x, scale y), clips blend
// poses, and every part has an art function that paints it around its own
// pivot. To paint with image parts later, swap the functions in [brawlArt]
// and keep everything else.
library;

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

const double _tau = math.pi * 2;

double _clamp(double v, double a, double b) => v < a ? a : (v > b ? b : v);

// ------------------------------------------------------------------ palettes

const Map<String, Color> kFighterPalette = {
  'skin': Color(0xFFF2C9A0),
  'skinShade': Color(0xFFD9A97E),
  'hair': Color(0xFF4A2F1A),
  'tunic': Color(0xFFE5C07A),
  'tunicShade': Color(0xFFC99A55),
  'belt': Color(0xFF815230),
  'shorts': Color(0xFF6F8F8C),
  'shortsShade': Color(0xFF5A7775),
  'boot': Color(0xFF3A2616),
  'bootShade': Color(0xFF2B1B10),
  'glove': Color(0xFFFFF1D6),
  'gloveShade': Color(0xFFE3CFA8),
  'scarf': Color(0xFFD88A8A),
  'scarfShade': Color(0xFFB96E6E),
  'eye': Color(0xFF2A1A10),
  'cheek': Color(0xFFE59B8E),
  'mouth': Color(0xFF8A4A3A),
};

/// The two friends' colors: the fighter's palette with their own clothes.
final List<Map<String, Color>> kFriendPalettes = [
  {
    ...kFighterPalette,
    'tunic': Color(0xFF8FAE8A),
    'tunicShade': Color(0xFF6F8A6B),
    'shorts': Color(0xFF8A6A4A),
    'shortsShade': Color(0xFF6E5238),
    'scarf': Color(0xFFF3E6C8),
    'scarfShade': Color(0xFFD6C6A0),
    'hair': Color(0xFF2E2118),
    'skin': Color(0xFFE7B58C),
    'skinShade': Color(0xFFC99872),
  },
  {
    ...kFighterPalette,
    'tunic': Color(0xFFC98A94),
    'tunicShade': Color(0xFFA86B76),
    'shorts': Color(0xFF4F5F7A),
    'shortsShade': Color(0xFF3E4C63),
    'scarf': Color(0xFFE5C07A),
    'scarfShade': Color(0xFFC99A55),
    'hair': Color(0xFFC9A56A),
    'skin': Color(0xFFF6D3B3),
    'skinShade': Color(0xFFDDB391),
  },
];

const Map<String, Color> kTrollPalette = {
  'skin': Color(0xFF7E9C8B),
  'skinShade': Color(0xFF5F7C6E),
  'skinLight': Color(0xFFA8C2AB),
  'belly': Color(0xFFBCCDB0),
  'spot': Color(0xFF69877A),
  'ear': Color(0xFF8DAA97),
  'earIn': Color(0xFFC99A9A),
  'sofa': Color(0xFFA85F5F),
  'sofaDark': Color(0xFF7E4448),
  'sofaLight': Color(0xFFC37C78),
  'wood': Color(0xFF4A2F1A),
  'pillow': Color(0xFFE5C07A),
  'pillowDark': Color(0xFFC99A55),
  'tassel': Color(0xFFF3E6C8),
  'straw': Color(0xFFC9A56A),
  'eyeW': Color(0xFFF3EEDD),
  'pupil': Color(0xFF2A1A10),
  'cheek': Color(0xFFD88A8A),
  'tusk': Color(0xFFF3E6C8),
  'quilt': Color(0xFF6F8F8C),
  'quiltDark': Color(0xFF4F6F6C),
  'quiltLine': Color(0xFFE5C896),
};

const Map<String, Color> kFogPalette = {
  'cloud': Color(0xFFCDD7E1),
  'cloudLight': Color(0xFFF3F7FA),
  'cloudDark': Color(0xFF9FAEBD),
  'cloudRain': Color(0xFF8B97A8),
  'eyeW': Color(0xFFFBFCFD),
  'pupil': Color(0xFF2B3442),
  'cheek': Color(0xFFE8B7BC),
  'mouth': Color(0xFFB77C86),
};

Color brawlMix(Color base, double flash, [Color to = const Color(0xFFFFFFFF)]) {
  final q = (_clamp(flash, 0, 1) * 12).round();
  if (q == 0) return base;
  return Color.lerp(base, to, q / 12)!;
}

// ------------------------------------------------------------------ a pen

/// A canvas and one reusable paint, so the art functions read like the
/// prototype's drawing calls without allocating a paint for every shape.
class BrawlPen {
  Canvas cv = _scratch;
  final Paint p = Paint()..isAntiAlias = true;

  static final Canvas _scratch = Canvas(PictureRecorder());

  void fillRR(double x, double y, double w, double h, double r, Color c) {
    r = math.min(r, math.min(w / 2, h / 2));
    p
      ..style = PaintingStyle.fill
      ..shader = null
      ..color = c;
    cv.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r)),
      p,
    );
  }

  void fillEll(
    double cx,
    double cy,
    double rx,
    double ry,
    Color c, [
    double rot = 0,
  ]) {
    p
      ..style = PaintingStyle.fill
      ..shader = null
      ..color = c;
    if (rot == 0) {
      cv.drawOval(Rect.fromLTRB(cx - rx, cy - ry, cx + rx, cy + ry), p);
    } else {
      cv.save();
      cv.translate(cx, cy);
      cv.rotate(rot);
      cv.drawOval(Rect.fromLTRB(-rx, -ry, rx, ry), p);
      cv.restore();
    }
  }

  void fillCircle(double cx, double cy, double r, Color c) {
    p
      ..style = PaintingStyle.fill
      ..shader = null
      ..color = c;
    cv.drawCircle(Offset(cx, cy), r, p);
  }

  void fillPath(Path path, Color c) {
    p
      ..style = PaintingStyle.fill
      ..shader = null
      ..color = c;
    cv.drawPath(path, p);
  }

  void strokePath(
    Path path,
    Color c,
    double w, {
    StrokeCap cap = StrokeCap.round,
    StrokeJoin join = StrokeJoin.round,
  }) {
    p
      ..style = PaintingStyle.stroke
      ..shader = null
      ..color = c
      ..strokeWidth = w
      ..strokeCap = cap
      ..strokeJoin = join;
    cv.drawPath(path, p);
    p.style = PaintingStyle.fill;
  }

  void line(
    double x1,
    double y1,
    double x2,
    double y2,
    double w,
    Color c, {
    StrokeCap cap = StrokeCap.round,
  }) {
    p
      ..style = PaintingStyle.stroke
      ..shader = null
      ..color = c
      ..strokeWidth = w
      ..strokeCap = cap;
    cv.drawLine(Offset(x1, y1), Offset(x2, y2), p);
    p.style = PaintingStyle.fill;
  }

  /// A circular arc from [a0] to [a1] (clockwise, as a canvas arc is).
  void arc(
    double cx,
    double cy,
    double r,
    double a0,
    double a1,
    Color c,
    double w,
  ) {
    var sweep = a1 - a0;
    while (sweep <= 0) {
      sweep += _tau;
    }
    strokePath(
      Path()
        ..addArc(Rect.fromCircle(center: Offset(cx, cy), radius: r), a0, sweep),
      c,
      w,
    );
  }

  /// A filled circular wedge (arc then closed by its chord).
  void fillArc(double cx, double cy, double r, double a0, double a1, Color c) {
    var sweep = a1 - a0;
    while (sweep <= 0) {
      sweep += _tau;
    }
    fillPath(
      Path()
        ..addArc(Rect.fromCircle(center: Offset(cx, cy), radius: r), a0, sweep),
      c,
    );
  }

  /// A dashed straight line.
  void dashed(
    double x1,
    double y1,
    double x2,
    double y2,
    double on,
    double off,
    double w,
    Color c,
  ) {
    final dx = x2 - x1, dy = y2 - y1;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len <= 0) return;
    final ux = dx / len, uy = dy / len;
    for (var d = 0.0; d < len; d += on + off) {
      final e = math.min(d + on, len);
      line(
        x1 + ux * d,
        y1 + uy * d,
        x1 + ux * e,
        y1 + uy * e,
        w,
        c,
        cap: StrokeCap.butt,
      );
    }
  }
}

// ------------------------------------------------------------------ rigs

class RigPart {
  RigPart(this.n, this.p, this.x, this.y, this.z, this.a);
  final String n;
  final String? p;
  final double x;
  final double y;
  final int z;
  final String? a;
  int pi = -1;
}

class Rig {
  Rig(this.name, List<RigPart> parts)
    : parts = parts,
      n = parts.length,
      idx = {for (var i = 0; i < parts.length; i++) parts[i].n: i},
      rest = Float32List(parts.length * 5),
      m = Float64List(parts.length * 6),
      order = List<int>.generate(parts.length, (i) => i) {
    for (final part in parts) {
      part.pi = part.p == null ? -1 : idx[part.p]!;
    }
    order.sort((a, b) {
      final c = parts[a].z.compareTo(parts[b].z);
      return c != 0 ? c : a.compareTo(b);
    });
    for (var i = 0; i < n; i++) {
      rest[i * 5 + 3] = 1;
      rest[i * 5 + 4] = 1;
    }
  }

  final String name;
  final List<RigPart> parts;
  final int n;
  final Map<String, int> idx;
  final List<int> order;
  final Float32List rest;
  final Float64List m;
}

/// A dense pose from a sparse spec `{part: [r, x, y, sx, sy]}` on [base].
Float32List poseFrom(
  Rig rig,
  Map<String, List<double?>> spec, [
  Float32List? base,
]) {
  final p = Float32List.fromList(base ?? rig.rest);
  spec.forEach((k, v) {
    final i = rig.idx[k];
    if (i == null) throw StateError('rig ${rig.name} has no part $k');
    for (var j = 0; j < v.length; j++) {
      final value = v[j];
      if (value != null) p[i * 5 + j] = value;
    }
  });
  return p;
}

typedef Ease = double Function(double u);

final Map<String, Ease> brawlEase = {
  'lin': (u) => u,
  'out': (u) => 1 - math.pow(1 - u, 3).toDouble(),
  'in': (u) => u * u * u,
  'io': (u) =>
      u < 0.5 ? 4 * u * u * u : 1 - math.pow(-2 * u + 2, 3).toDouble() / 2,
  'snap': (u) => 1 - math.pow(1 - u, 5).toDouble(),
  'back': (u) {
    const c1 = 1.9, c3 = c1 + 1;
    return 1 + c3 * math.pow(u - 1, 3) + c1 * math.pow(u - 1, 2);
  },
  'soft': (u) => u * u * (3 - 2 * u),
};

class ClipKey {
  const ClipKey(this.t, this.pose, [this.ease = 'out']);
  final double t;
  final Float32List pose;
  final String ease;
}

class Clip {
  const Clip(this.dur, this.keys);
  final double dur;
  final List<ClipKey> keys;

  void eval(double t, Float32List out) {
    final n = keys.length;
    if (t <= keys.first.t) {
      out.setAll(0, keys.first.pose);
      return;
    }
    if (t >= keys[n - 1].t) {
      out.setAll(0, keys[n - 1].pose);
      return;
    }
    var i = 0;
    while (i < n - 2 && t > keys[i + 1].t) {
      i++;
    }
    final a = keys[i], b = keys[i + 1];
    final u = (t - a.t) / (b.t - a.t);
    final e = brawlEase[b.ease]!(u);
    final pa = a.pose, pb = b.pose;
    for (var k = 0; k < out.length; k++) {
      out[k] = pa[k] + (pb[k] - pa[k]) * e;
    }
  }
}

void _addTo(
  Float32List p,
  Rig rig,
  String name, [
  double r = 0,
  double x = 0,
  double y = 0,
  double sx = 0,
  double sy = 0,
]) {
  final i = rig.idx[name]! * 5;
  p[i] += r;
  p[i + 1] += x;
  p[i + 2] += y;
  p[i + 3] += sx;
  p[i + 4] += sy;
}

final Rig rigFighter = Rig('fighter', [
  RigPart('root', null, 0, 0, 0, null),
  RigPart('hips', 'root', 0, -21, 4, 'hips'),
  RigPart('torso', 'hips', 0, -2, 5, 'torso'),
  RigPart('scarf', 'torso', -4, -16, 3, 'scarf'),
  RigPart('head', 'torso', 1, -16, 7, 'head'),
  RigPart('hair', 'head', -1, -22, 8, 'hair'),
  RigPart('armB', 'torso', -5, -13, 1, 'armB'),
  RigPart('foreB', 'armB', 0, 8, 1, 'foreB'),
  RigPart('armF', 'torso', 6, -13, 9, 'armF'),
  RigPart('foreF', 'armF', 0, 8, 10, 'foreF'),
  RigPart('legB', 'hips', -3, 3, 2, 'legB'),
  RigPart('shinB', 'legB', 0, 8, 2, 'shinB'),
  RigPart('legF', 'hips', 3, 3, 6, 'legF'),
  RigPart('shinF', 'legF', 0, 8, 6, 'shinF'),
]);

final Rig rigTroll = Rig('troll', [
  RigPart('root', null, 0, 0, 0, null),
  RigPart('couch', 'root', 0, 0, 1, 'couch'),
  RigPart('legB', 'root', 18, -34, 3, 'legB'),
  RigPart('body', 'root', 0, -30, 4, 'body'),
  RigPart('armB', 'body', 34, -62, 3, 'armB'),
  RigPart('foreB', 'armB', 0, 20, 3, 'foreB'),
  RigPart('head', 'body', -4, -76, 6, 'head'),
  RigPart('legF', 'root', -22, -34, 7, 'legF'),
  RigPart('pillow', 'body', -4, -28, 8, 'pillow'),
  RigPart('armF', 'body', -34, -62, 9, 'armF'),
  RigPart('foreF', 'armF', 0, 20, 9, 'foreF'),
  RigPart('blanket', 'root', 0, -30, 11, 'blanket'),
  RigPart('armrest', 'root', 0, 0, 12, 'armrest'),
]);

final Rig rigFog = Rig('fog', [
  RigPart('root', null, 0, 0, 0, null),
  RigPart('cloud', 'root', 0, -72, 1, null),
  RigPart('wispL', 'cloud', -26, 36, 1, 'wisp'),
  RigPart('wispC', 'cloud', 0, 42, 1, 'wisp'),
  RigPart('wispR', 'cloud', 26, 36, 1, 'wisp'),
  RigPart('puffBL', 'cloud', -20, 18, 2, 'puffBL'),
  RigPart('puffBR', 'cloud', 22, 20, 2, 'puffBR'),
  RigPart('puffL', 'cloud', -40, 6, 3, 'puffL'),
  RigPart('puffR', 'cloud', 41, 7, 3, 'puffR'),
  RigPart('puffT', 'cloud', 2, -27, 4, 'puffT'),
  RigPart('puffTL', 'cloud', -27, -16, 4, 'puffTL'),
  RigPart('puffTR', 'cloud', 27, -15, 4, 'puffTR'),
  RigPart('puffC', 'cloud', 0, 0, 5, 'puffC'),
  RigPart('face', 'cloud', -6, 4, 8, 'face'),
]);

// ------------------------------------------------------------------ art options

/// What the art functions read: the palette, a time, and the face and the
/// flags a monster shows. Written by the scene each frame.
class ArtOpts {
  ArtOpts(this.pal);

  Map<String, Color> pal;
  double t = 0;
  double flash = 0;
  String face = 'normal';
  double blink = 0;

  /// The Troll's and the Fog's eyelids (0 open, 1 shut). Null is the
  /// character's default.
  double? lid;
  double bubble = 0;
  double cover = 0;
  double mouthO = 0;
  double brow = 0;
  double lookX = -1;
  double lookY = 0;
  double rain = 0;
  double? mouth;

  Color c(String k) => brawlMix(pal[k]!, flash);
}

// ------------------------------------------------------------------ fighter art

typedef ArtFn = void Function(BrawlPen g, ArtOpts o);

Path _path() => Path();

final Map<String, ArtFn> _fighterArt = {
  'hips': (g, o) => g.fillRR(-8.5, -3, 17, 10.5, 4.2, o.c('shorts')),
  'torso': (g, o) {
    g.fillRR(-9, -17, 18, 19, 7, o.c('tunic'));
    g.fillRR(-9, -3, 18, 5, 2.5, o.c('tunicShade'));
    g.fillRR(-9.4, -5, 18.8, 3, 1.5, o.c('belt'));
    g.fillEll(
      -3.6,
      -12,
      2.4,
      4.6,
      const Color.fromRGBO(255, 246, 222, 0.38),
      0.25,
    );
  },
  'scarf': (g, o) {
    final w = math.sin(o.t * 7 + 0.5) * 1.6;
    final w2 = math.sin(o.t * 7 + 1.6) * 2.4;
    g.fillPath(
      _path()
        ..moveTo(1, -1)
        ..quadraticBezierTo(-9, 1.5 + w, -17, 4 + w2)
        ..lineTo(-18, 8 + w2)
        ..quadraticBezierTo(-9, 5 + w, 0, 4)
        ..close(),
      o.c('scarfShade'),
    );
    g.fillPath(
      _path()
        ..moveTo(1, -2)
        ..quadraticBezierTo(-8, 0 + w, -15, 2 + w2)
        ..lineTo(-15.5, 5.5 + w2)
        ..quadraticBezierTo(-8, 3 + w, 1, 3)
        ..close(),
      o.c('scarf'),
    );
  },
  'head': _fighterHead,
  'hair': (g, o) {
    final c = o.c('hair');
    g.strokePath(
      _path()
        ..moveTo(0, 1)
        ..cubicTo(-1, -4, 3, -8, 7, -6),
      c,
      2.3,
    );
    g.strokePath(
      _path()
        ..moveTo(-3, 1.5)
        ..cubicTo(-6, -2, -5, -6, -1.5, -7),
      c,
      2.3,
    );
  },
  'armB': _limbA(true),
  'armF': _limbA(false),
  'foreB': _foreA(true),
  'foreF': _foreA(false),
  'legB': _legA(true),
  'legF': _legA(false),
  'shinB': _shinA(true),
  'shinF': _shinA(false),
};

void _fighterHead(BrawlPen g, ArtOpts o) {
  g.fillEll(-11, -10.5, 3, 3.6, o.c('skinShade'));
  g.fillEll(0, -11.5, 12.2, 11.6, o.c('skin'));
  final cheek = o.c('cheek').withValues(alpha: 0.55);
  g.fillEll(3.4, -5.6, 2.5, 1.6, cheek);
  g.fillEll(10, -6, 2.2, 1.5, cheek);
  g.fillPath(
    _path()
      ..moveTo(-12.4, -11)
      ..cubicTo(-13.4, -24.5, -1, -28, 7.5, -24.6)
      ..cubicTo(11.5, -23, 12.8, -19, 12.4, -15.2)
      ..cubicTo(8.4, -18.6, 3.5, -18.2, -1.5, -17.2)
      ..cubicTo(-6.5, -16.6, -10.5, -14.4, -12.4, -11)
      ..close(),
    o.c('hair'),
  );
  final eye = o.c('eye');
  final f = o.face;
  final blink = o.blink > 0.5;
  if (f == 'hit') {
    g.strokePath(
      _path()
        ..moveTo(1.6, -12)
        ..lineTo(4.8, -10.2)
        ..lineTo(1.6, -8.4)
        ..moveTo(10.8, -12)
        ..lineTo(7.8, -10.2)
        ..lineTo(10.8, -8.4),
      eye,
      1.5,
    );
  } else if (f == 'happy') {
    g.arc(3.2, -9.4, 2.1, math.pi * 1.1, math.pi * 1.9, eye, 1.5);
    g.arc(9, -9.4, 2.1, math.pi * 1.1, math.pi * 1.9, eye, 1.5);
  } else if (blink) {
    g.line(1.4, -9.6, 5, -9.6, 1.5, eye);
    g.line(7.2, -9.6, 10.8, -9.6, 1.5, eye);
  } else {
    g.fillEll(3.3, -9.6, 1.9, 2.7, eye);
    g.fillEll(9, -9.6, 1.9, 2.7, eye);
    const white = Color(0xFFFFFFFF);
    g.fillEll(3.9, -10.6, 0.75, 0.9, white);
    g.fillEll(9.6, -10.6, 0.75, 0.9, white);
  }
  final mouth = o.c('mouth');
  if (f == 'effort' || f == 'blow') {
    final r = f == 'blow' ? 2.2 : 2.5;
    g.fillEll(7.6, -4.2, r, f == 'blow' ? 2.2 : 2.9, mouth);
  } else if (f == 'happy') {
    g.fillArc(7, -5.6, 2.9, 0.1, math.pi - 0.1, mouth);
  } else if (f == 'hit') {
    g.line(5.6, -4, 9.4, -4.6, 1.3, mouth);
  } else if (f == 'puff') {
    final ck = o.c('cheek');
    g.fillEll(5, -5, 4.4, 3.8, ck);
    g.fillEll(11, -5.4, 3.2, 3.2, ck);
  } else {
    g.arc(7, -6.3, 2.2, 0.25, math.pi - 0.25, mouth, 1.3);
  }
}

ArtFn _limbA(bool shade) =>
    (g, o) => g.line(0, 0, 0, 7.5, 6.2, o.c(shade ? 'tunicShade' : 'tunic'));

ArtFn _foreA(bool shade) => (g, o) {
  g.line(0, 0, 0, 5.4, 4.6, o.c(shade ? 'skinShade' : 'skin'));
  g.fillEll(0, 8.6, 4.5, 4.4, o.c(shade ? 'gloveShade' : 'glove'));
  g.line(-2.6, 9.6, 2.6, 9.6, 0.9, const Color.fromRGBO(138, 74, 58, 0.35));
};

ArtFn _legA(bool shade) => (g, o) {
  g.line(0, 0, 0, 7.6, 6.4, o.c(shade ? 'skinShade' : 'skin'));
  g.line(0, -0.5, 0, 2.6, 7.6, o.c(shade ? 'shortsShade' : 'shorts'));
};

ArtFn _shinA(bool shade) => (g, o) {
  g.line(0, 0, 0, 5.6, 5.4, o.c(shade ? 'skinShade' : 'skin'));
  g.fillRR(-3.6, 4.4, 11.6, 6.4, 3.2, o.c(shade ? 'bootShade' : 'boot'));
  g.fillRR(-2.6, 5, 8, 1.5, 0.8, const Color.fromRGBO(255, 240, 210, 0.25));
};

// ------------------------------------------------------------------ troll art

Color _tc(ArtOpts o, String k) => brawlMix(o.pal[k]!, o.flash * 0.25);

final Map<String, ArtFn> _trollArt = {
  'couch': (g, o) {
    g.fillRR(-70, -92, 140, 66, 22, _tc(o, 'sofaDark'));
    g.fillRR(-64, -88, 128, 10, 5, const Color.fromRGBO(255, 230, 190, 0.10));
    for (final x in const [-62.0, -30.0, 30.0, 62.0]) {
      g.fillRR(x - 5, -8, 11, 9, 3, _tc(o, 'wood'));
    }
    g.fillRR(-78, -18, 156, 14, 6, _tc(o, 'sofaDark'));
    g.fillRR(-80, -38, 160, 26, 13, _tc(o, 'sofa'));
    g.fillRR(-72, -36, 144, 6, 3, _tc(o, 'sofaLight').withValues(alpha: 0.5));
    final seam = _tc(o, 'sofaDark').withValues(alpha: 0.5);
    g.line(-26, -35, -26, -15, 1.4, seam);
    g.line(26, -35, 26, -15, 1.4, seam);
  },
  'armrest': (g, o) {
    g.fillRR(-94, -60, 28, 52, 14, _tc(o, 'sofa'));
    g.fillRR(-90, -56, 8, 36, 4, _tc(o, 'sofaLight').withValues(alpha: 0.55));
    g.fillRR(66, -60, 28, 52, 14, _tc(o, 'sofa'));
    g.fillRR(84, -56, 7, 42, 3.5, _tc(o, 'sofaDark').withValues(alpha: 0.5));
  },
  'body': (g, o) {
    final skin = o.c('skin');
    g.fillEll(0, -40, 54, 47, skin);
    g.fillEll(-30, -62, 22, 18, skin);
    g.fillEll(30, -62, 22, 18, skin);
    g.fillEll(-8, -28, 33, 28, o.c('belly'));
    g.fillEll(30, -34, 14, 22, o.c('skinShade').withValues(alpha: 0.5), 0.3);
    final spot = o.c('spot');
    g.fillEll(32, -52, 5, 3.4, spot, 0.4);
    g.fillEll(38, -38, 3.6, 2.6, spot);
    g.fillEll(24, -66, 4, 2.6, spot, -0.2);
    g.arc(
      0,
      -40,
      50,
      math.pi * 1.05,
      math.pi * 1.4,
      const Color.fromRGBO(255, 244, 217, 0.35),
      2.4,
    );
  },
  'legB': (g, o) {
    g.fillRR(-10, 0, 20, 24, 9, o.c('skinShade'));
    g.fillEll(-3, 25, 14, 8, o.c('skinShade'));
  },
  'legF': (g, o) {
    g.fillRR(-11, 0, 22, 25, 10, o.c('skin'));
    g.fillEll(-6, 26, 15, 8.5, o.c('skin'));
    g.fillEll(-9, 24, 6, 3, o.c('skinLight').withValues(alpha: 0.5));
  },
  'armF': (g, o) => g.fillRR(-12, -6, 24, 34, 12, o.c('skin')),
  'armB': (g, o) => g.fillRR(-12, -6, 24, 34, 12, o.c('skinShade')),
  'foreF': (g, o) {
    g.fillEll(0, 6, 12, 13, o.c('skin'));
    g.fillEll(-4, 2, 4, 5, o.c('skinLight').withValues(alpha: 0.5));
  },
  'foreB': (g, o) => g.fillEll(0, 6, 12, 13, o.c('skinShade')),
  'pillow': (g, o) {
    g.fillRR(-26, -13, 52, 30, 11, o.c('pillowDark'));
    g.fillRR(-26, -15, 52, 28, 11, o.c('pillow'));
    g.fillRR(-20, -12, 24, 6, 3, const Color.fromRGBO(255, 246, 222, 0.4));
    final tassel = o.c('tassel');
    for (final p in const [
      [-27.0, -15.0],
      [27.0, -15.0],
      [-27.0, 15.0],
      [27.0, 15.0],
    ]) {
      g.fillEll(p[0], p[1], 3.2, 3.2, tassel);
    }
    final line = o.c('pillowDark');
    g.line(-9, 0, 9, 0, 1.2, line);
    g.line(0, -8, 0, 8, 1.2, line);
  },
  'head': _trollHead,
  'blanket': (g, o) {
    final k = _clamp(o.cover, 0, 1);
    if (k <= 0.01) return;
    g.cv.save();
    g.cv.scale(1, k);
    g.fillRR(-62, -50, 124, 62, 16, o.c('quiltDark'));
    g.fillRR(-62, -52, 124, 58, 16, o.c('quilt'));
    final ln = o.c('quiltLine').withValues(alpha: 0.8);
    for (var x = -42.0; x <= 42; x += 21) {
      g.dashed(x, -48, x, 4, 5, 4, 1.6, ln);
    }
    for (var y = -36.0; y <= -8; y += 14) {
      g.dashed(-58, y, 58, y, 5, 4, 1.6, ln);
    }
    g.fillRR(-62, -54, 124, 9, 4.5, o.c('quiltLine'));
    g.cv.restore();
  },
};

void _trollHead(BrawlPen g, ArtOpts o) {
  final ear = o.c('ear');
  g.fillPath(
    _path()
      ..moveTo(-26, -26)
      ..quadraticBezierTo(-42, -40, -34, -14)
      ..close(),
    ear,
  );
  g.fillPath(
    _path()
      ..moveTo(26, -28)
      ..quadraticBezierTo(46, -44, 36, -16)
      ..close(),
    ear,
  );
  g.fillPath(
    _path()
      ..moveTo(-28, -25)
      ..quadraticBezierTo(-37, -33, -33, -19)
      ..close(),
    o.c('earIn'),
  );
  g.fillEll(0, -20, 33, 27, o.c('skin'));
  g.fillEll(-10, -34, 14, 7, o.c('skinLight').withValues(alpha: 0.45), -0.2);
  final straw = o.c('straw');
  for (final s in const [
    [-6.0, -44.0, -12.0, -58.0],
    [2.0, -45.0, 3.0, -62.0],
    [9.0, -43.0, 18.0, -55.0],
  ]) {
    g.strokePath(
      _path()
        ..moveTo(s[0], s[1])
        ..quadraticBezierTo(
          (s[0] + s[2]) / 2 - 3,
          (s[1] + s[3]) / 2,
          s[2],
          s[3],
        ),
      straw,
      3.2,
    );
  }
  final cheek = o.c('cheek').withValues(alpha: 0.5);
  g.fillEll(-24, -10, 6, 4, cheek);
  g.fillEll(12, -9, 6, 4, cheek);
  g.fillEll(-27, -15, 9, 8, o.c('skinLight'));
  g.fillEll(-29, -12, 6, 4, o.c('skinShade').withValues(alpha: 0.35));
  final lid = _clamp(o.lid ?? 0.55, 0, 1);
  const eyes = [
    [-12.0, -23.0],
    [9.0, -23.0],
  ];
  final pupil = o.c('pupil');
  for (var i = 0; i < 2; i++) {
    final ex = eyes[i][0], ey = eyes[i][1];
    if (lid > 0.96) {
      g.arc(ex, ey - 1, 5.5, 0.15, math.pi - 0.15, pupil, 2.2);
    } else {
      g.fillEll(ex, ey, 7.4, 6.6, o.c('eyeW'));
      final lx = _clamp(o.lookX == 0 ? -1 : o.lookX, -1.4, 1.4);
      g.fillEll(ex + lx * 1.6 - 1.5, ey + 1.4 + lid * 1.2, 3.1, 3.5, pupil);
      g.fillEll(
        ex + lx * 1.6 - 2.4,
        ey + 0.2 + lid * 1.2,
        1,
        1,
        const Color(0xFFFFFFFF),
      );
      final skin = o.c('skin');
      g.fillPath(
        _path()
          ..addArc(
            Rect.fromLTRB(ex - 8.4, ey - 7.6, ex + 8.4, ey + 7.6),
            math.pi,
            math.pi,
          )
          ..lineTo(ex + 8.4, ey - 7.6 + lid * 15.2)
          ..lineTo(ex - 8.4, ey - 7.6 + lid * 15.2)
          ..close(),
        skin,
      );
      g.line(
        ex - 7.4,
        ey - 7.6 + lid * 15.2,
        ex + 7.4,
        ey - 7.6 + lid * 15.2,
        1.5,
        o.c('skinShade'),
        cap: StrokeCap.butt,
      );
    }
  }
  final bz = o.brow;
  final brow = o.c('skinShade');
  g.strokePath(
    _path()
      ..moveTo(-19, -34 + bz)
      ..lineTo(-7, -32 - bz)
      ..moveTo(4, -32 - bz)
      ..lineTo(16, -34 + bz),
    brow,
    2.6,
  );
  if (o.mouthO > 0) {
    g.fillEll(-14, -2, 5, 5.4 * o.mouthO, pupil);
  } else {
    g.arc(-14, -4, 7, 0.25, math.pi - 0.25, pupil, 2);
  }
  final tusk = o.c('tusk');
  g.fillPath(
    _path()
      ..moveTo(-23, -3)
      ..lineTo(-19.5, 4)
      ..lineTo(-17, -3)
      ..close(),
    tusk,
  );
  g.fillPath(
    _path()
      ..moveTo(-11, -3)
      ..lineTo(-8.5, 3.5)
      ..lineTo(-5.5, -3.4)
      ..close(),
    tusk,
  );
  if (o.bubble > 0.02) {
    final br = 3 + 9 * o.bubble;
    g.fillEll(
      -31 - br * 0.5,
      -12,
      br,
      br,
      const Color.fromRGBO(243, 247, 250, 0.28),
    );
    g.strokePath(
      Path()..addOval(
        Rect.fromCircle(center: Offset(-31 - br * 0.5, -12), radius: br),
      ),
      const Color.fromRGBO(243, 247, 250, 0.9),
      1.8,
    );
    g.fillEll(
      -31 - br * 0.5 - br * 0.3,
      -12 - br * 0.35,
      br * 0.22,
      br * 0.22,
      const Color.fromRGBO(255, 255, 255, 0.8),
    );
  }
}

// ------------------------------------------------------------------ fog art

final Map<String, Paint> _puffPaints = {};

Paint _puffPaint(double r, bool rain, double alpha) {
  final qa = (alpha * 10).round();
  final key = '$r|$rain|$qa';
  final cached = _puffPaints[key];
  if (cached != null) return cached;
  final cols = rain
      ? const [Color(0xFFB9C3D0), Color(0xFF8B97A8), Color(0xFF6E7A8C)]
      : const [Color(0xFFF6F9FB), Color(0xFFCDD7E1), Color(0xFFA9B7C6)];
  final a = qa / 10;
  final paint = Paint()
    ..isAntiAlias = true
    ..shader = Gradient.radial(
      Offset.zero,
      r,
      [for (final c in cols) c.withValues(alpha: a)],
      const [0, 0.55, 1],
      TileMode.clamp,
      null,
      Offset(-r * 0.28, -r * 0.34),
      r * 0.1,
    );
  return _puffPaints[key] = paint;
}

void _drawPuff(BrawlPen g, ArtOpts o, double r) {
  g.cv.drawCircle(Offset.zero, r, _puffPaint(r, false, 1));
  final rain = _clamp(o.rain, 0, 1);
  if (rain > 0.02) g.cv.drawCircle(Offset.zero, r, _puffPaint(r, true, rain));
  if (o.flash > 0.02) {
    g.fillCircle(
      0,
      0,
      r - 0.5,
      const Color(0xFFFFFFFF).withValues(alpha: _clamp(o.flash, 0, 1) * 0.85),
    );
  }
}

final Map<String, ArtFn> _fogArt = {
  'puffBL': (g, o) => _drawPuff(g, o, 25),
  'puffBR': (g, o) => _drawPuff(g, o, 26),
  'puffL': (g, o) => _drawPuff(g, o, 23),
  'puffR': (g, o) => _drawPuff(g, o, 24),
  'puffT': (g, o) => _drawPuff(g, o, 26),
  'puffTL': (g, o) => _drawPuff(g, o, 22),
  'puffTR': (g, o) => _drawPuff(g, o, 23),
  'puffC': (g, o) => _drawPuff(g, o, 34),
  'wisp': (g, o) => g.fillEll(
    0,
    6,
    6.5,
    10,
    o.rain > 0.3
        ? const Color.fromRGBO(139, 151, 168, 0.9)
        : const Color.fromRGBO(214, 223, 232, 0.92),
  ),
  'face': (g, o) {
    final lx = o.lookX, ly = o.lookY;
    final lid = o.lid ?? 0;
    final cheek = const Color.fromRGBO(232, 183, 188, 0.65);
    g.fillEll(-22, 12, 6, 3.8, cheek);
    g.fillEll(20, 12, 6, 3.8, cheek);
    for (var i = 0; i < 2; i++) {
      final ex = i == 1 ? 11.0 : -13.0, ey = -2.0;
      g.fillEll(ex, ey, 9, 10.4, const Color(0xFFFBFCFD));
      g.strokePath(
        Path()..addOval(Rect.fromLTRB(ex - 9, ey - 10.4, ex + 9, ey + 10.4)),
        const Color.fromRGBO(139, 151, 168, 0.7),
        1.2,
      );
      final px = ex + _clamp(lx, -1, 1) * 3.6;
      final py = ey + _clamp(ly, -1, 1) * 3.6 + 1;
      g.fillEll(px, py, 4.8, 5.4, const Color(0xFF2B3442));
      const white = Color(0xFFFFFFFF);
      g.fillEll(px - 1.5, py - 2, 1.7, 1.7, white);
      g.fillEll(px + 1.7, py + 1.6, 0.8, 0.8, white);
      if (lid > 0.02) {
        g.fillPath(
          _path()
            ..addArc(
              Rect.fromLTRB(ex - 10, ey - 11.4, ex + 10, ey + 11.4),
              math.pi,
              math.pi,
            )
            ..lineTo(ex + 10, ey - 11.4 + lid * 22.8)
            ..lineTo(ex - 10, ey - 11.4 + lid * 22.8)
            ..close(),
          const Color(0xFFCDD7E1),
        );
      }
    }
    final m = o.mouth ?? 0.5;
    g.fillEll(-2, 16, 3.2 + m * 1.6, 2.4 + m * 3, const Color(0xFFB77C86));
    g.fillEll(-3, 15, 1, 1, const Color.fromRGBO(255, 255, 255, 0.35));
  },
};

/// The art table for each rig.
final Map<String, Map<String, ArtFn>> brawlArt = {
  'fighter': _fighterArt,
  'troll': _trollArt,
  'fog': _fogArt,
};

// ------------------------------------------------------------------ clips

/// Poses and keyframed clips for the fighter (and for friends, who share
/// them). Names match [BrawlFighterAnim].
class FighterClips {
  FighterClips._() {
    final r = rigFighter;
    Float32List p(Map<String, List<double?>> s, [Float32List? b]) =>
        poseFrom(r, s, b);
    guard = p({
      'hips': [0, 0, 1],
      'torso': [0.06],
      'head': [0.04],
      'hair': [0.1],
      'scarf': [0.2],
      'armF': [-0.95],
      'foreF': [-1.85],
      'armB': [-0.55],
      'foreB': [-2.0],
      'legF': [-0.22],
      'shinF': [0.42],
      'legB': [0.2],
      'shinB': [0.4],
    });
    poses['guard'] = guard;
    poses['jump'] = p({
      'root': [0, 0, 0, 0.94, 1.1],
      'hips': [0, 0, 0],
      'torso': [0.04],
      'head': [-0.06],
      'armF': [-2.3],
      'foreF': [-0.4],
      'armB': [-2.0],
      'foreB': [-0.5],
      'legF': [-0.7],
      'shinF': [1.2],
      'legB': [0.35],
      'shinB': [1.0],
      'scarf': [0.7],
    });
    poses['fall'] = p({
      'root': [0, 0, 0, 1.04, 0.96],
      'torso': [0.02],
      'head': [0.1],
      'armF': [-1.7],
      'foreF': [-0.5],
      'armB': [-1.3],
      'foreB': [-0.7],
      'legF': [-0.35],
      'shinF': [0.55],
      'legB': [0.5],
      'shinB': [0.7],
      'scarf': [-0.5],
    });
    final jabHit = p({
      'hips': [0, 6, 1],
      'torso': [0.26],
      'head': [0.1],
      'armF': [-1.6, 0, 0, 1, 1.14],
      'foreF': [-0.06, 0, 0, 1, 1.32],
      'legF': [-0.55],
      'shinF': [0.7],
    }, guard);
    clips['jab'] = Clip(0.25, [
      ClipKey(0, guard),
      ClipKey(
        0.022,
        p({
          'hips': [0, -2, 1],
          'torso': [-0.14],
          'head': [0.0],
          'armF': [-0.5],
          'foreF': [-2.5],
        }, guard),
        'out',
      ),
      ClipKey(0.052, jabHit, 'snap'),
      ClipKey(0.11, jabHit, 'lin'),
      ClipKey(0.25, guard, 'io'),
    ]);
    final crossHit = p({
      'hips': [0, 7, 1],
      'torso': [0.34],
      'head': [0.12],
      'armB': [-1.65, 0, 0, 1, 1.14],
      'foreB': [-0.05, 0, 0, 1, 1.32],
      'armF': [-0.6],
      'foreF': [-2.0],
      'legB': [0.12],
      'legF': [-0.5],
      'shinF': [0.7],
    }, guard);
    clips['cross'] = Clip(0.26, [
      ClipKey(0, guard),
      ClipKey(
        0.022,
        p({
          'hips': [0, -2, 1],
          'torso': [-0.2],
          'armB': [-0.1],
          'foreB': [-2.6],
          'armF': [-1.1],
          'foreF': [-1.6],
        }, guard),
        'out',
      ),
      ClipKey(0.052, crossHit, 'snap'),
      ClipKey(0.115, crossHit, 'lin'),
      ClipKey(0.26, guard, 'io'),
    ]);
    final kickHit = p({
      'hips': [0, 3, 2],
      'torso': [-0.5],
      'head': [-0.15],
      'armF': [-1.9],
      'foreF': [-0.6],
      'armB': [0.2],
      'foreB': [-0.5],
      'legF': [-1.62, 0, 0, 1, 1.22],
      'shinF': [-0.05, 0, 0, 1, 1.35],
      'legB': [0.2],
      'shinB': [0.4],
    }, guard);
    clips['kick'] = Clip(0.33, [
      ClipKey(0, guard),
      ClipKey(
        0.03,
        p({
          'hips': [0, -1, 2],
          'torso': [-0.32],
          'head': [-0.1],
          'armF': [-1.4],
          'foreF': [-1.0],
          'armB': [-1.0],
          'foreB': [-1.6],
          'legF': [-0.1],
          'shinF': [1.6],
          'legB': [0.25],
          'shinB': [0.5],
        }, guard),
        'out',
      ),
      ClipKey(0.07, kickHit, 'snap'),
      ClipKey(0.14, kickHit, 'lin'),
      ClipKey(0.33, guard, 'io'),
    ]);
    final upperHit = p({
      'root': [0, 0, -6, 0.96, 1.06],
      'hips': [0, -2, 0],
      'torso': [-0.22],
      'head': [-0.22],
      'armF': [-3.0, 0, 0, 1, 1.2],
      'foreF': [-0.1, 0, 0, 1, 1.25],
      'armB': [-1.2],
      'foreB': [-1.0],
      'legF': [-0.2],
      'shinF': [0.3],
      'legB': [0.3],
      'shinB': [0.9],
    }, guard);
    final upperHold = p({
      'root': [0, 0, -9, 0.96, 1.06],
      'hips': [0, -2, 0],
      'torso': [-0.22],
      'head': [-0.22],
      'armF': [-3.0, 0, 0, 1, 1.2],
      'foreF': [-0.1, 0, 0, 1, 1.25],
      'armB': [-1.2],
      'foreB': [-1.0],
      'legF': [-0.2],
      'shinF': [0.3],
      'legB': [0.3],
      'shinB': [0.9],
    }, guard);
    clips['upper'] = Clip(0.41, [
      ClipKey(0, guard),
      ClipKey(
        0.04,
        p({
          'hips': [0, 9, 1],
          'torso': [0.3],
          'head': [0.15],
          'armF': [-0.2],
          'foreF': [-0.4],
          'armB': [-0.7],
          'foreB': [-1.9],
          'legF': [-0.6],
          'shinF': [1.0],
          'legB': [0.5],
          'shinB': [1.0],
        }, guard),
        'out',
      ),
      ClipKey(0.085, upperHit, 'snap'),
      ClipKey(0.17, upperHold, 'lin'),
      ClipKey(0.41, guard, 'io'),
    ]);
    poses['dive'] = p({
      'hips': [-0.95, 0, 1],
      'torso': [0.25],
      'head': [0.1],
      'armF': [-2.3],
      'foreF': [-0.4],
      'armB': [-2.0],
      'foreB': [-0.5],
      'legF': [0.05],
      'shinF': [0.0],
      'legB': [0.7],
      'shinB': [1.3],
      'scarf': [0.9],
    });
    clips['diveLand'] = Clip(0.16, [
      ClipKey(
        0,
        p({
          'root': [0, 0, 0, 1.18, 0.78],
          'hips': [0, 0, 6],
          'torso': [0.5],
          'armF': [-0.4],
          'foreF': [-0.4],
          'armB': [-0.2],
          'foreB': [-0.5],
          'legF': [-0.7],
          'shinF': [1.5],
          'legB': [0.5],
          'shinB': [1.5],
        }),
      ),
      ClipKey(0.16, guard, 'out'),
    ]);
    poses['chargeSlam'] = p({
      'hips': [0, 0, 6],
      'torso': [-0.12],
      'head': [-0.14],
      'armF': [-2.95],
      'foreF': [-0.08],
      'armB': [-2.8],
      'foreB': [-0.12],
      'legF': [-0.55],
      'shinF': [1.2],
      'legB': [0.5],
      'shinB': [1.2],
      'scarf': [0.3],
    });
    poses['slamRise'] = p({
      'root': [0, 0, 0, 0.92, 1.12],
      'torso': [-0.15],
      'head': [-0.2],
      'armF': [-3.05],
      'foreF': [-0.05],
      'armB': [-2.9],
      'foreB': [-0.05],
      'legF': [-0.2],
      'shinF': [0.6],
      'legB': [0.2],
      'shinB': [0.7],
      'scarf': [0.8],
    });
    poses['slamFall'] = p({
      'root': [0, 0, 0, 0.9, 1.14],
      'hips': [0.1, 0, 0],
      'torso': [0.55],
      'head': [0.2],
      'armF': [-0.3],
      'foreF': [-0.1],
      'armB': [-0.1],
      'foreB': [-0.1],
      'legF': [-0.9],
      'shinF': [0.9],
      'legB': [-0.4],
      'shinB': [0.8],
      'scarf': [-0.9],
    });
    clips['slamLand'] = Clip(0.34, [
      ClipKey(
        0,
        p({
          'root': [0, 0, 0, 1.14, 0.86],
          'hips': [0, 0, 7],
          'torso': [0.5],
          'head': [0.16],
          'armF': [-0.25],
          'foreF': [-0.1],
          'armB': [-0.1],
          'foreB': [-0.1],
          'legF': [-0.8],
          'shinF': [1.5],
          'legB': [0.6],
          'shinB': [1.6],
        }),
      ),
      ClipKey(
        0.12,
        p({
          'root': [0, 0, 0, 1.1, 0.9],
          'hips': [0, 0, 6],
          'torso': [0.5],
          'head': [0.16],
          'armF': [-0.25],
          'foreF': [-0.1],
          'armB': [-0.1],
          'foreB': [-0.1],
          'legF': [-0.8],
          'shinF': [1.5],
          'legB': [0.6],
          'shinB': [1.6],
        }),
        'lin',
      ),
      ClipKey(0.34, guard, 'io'),
    ]);
    final castHit = p({
      'hips': [0, 3, 1],
      'torso': [0.2],
      'head': [0.02],
      'armF': [-1.55],
      'foreF': [-0.05],
      'armB': [-1.45],
      'foreB': [-0.05],
      'legF': [-0.4],
      'shinF': [0.6],
    }, guard);
    clips['cast'] = Clip(0.30, [
      ClipKey(0, guard),
      ClipKey(
        0.05,
        p({
          'hips': [0, -1, 1],
          'torso': [-0.18],
          'armF': [-0.9],
          'foreF': [-2.3],
          'armB': [-0.8],
          'foreB': [-2.2],
        }, guard),
        'out',
      ),
      ClipKey(0.11, castHit, 'snap'),
      ClipKey(0.2, castHit, 'lin'),
      ClipKey(0.30, guard, 'io'),
    ]);
    final callHold = p({
      'torso': [0.1],
      'armB': [-3.0],
      'foreB': [-0.45],
      'armF': [-1.5],
      'foreF': [-0.05],
      'head': [-0.1],
    }, guard);
    clips['call'] = Clip(0.36, [
      ClipKey(0, guard),
      ClipKey(
        0.06,
        p({
          'torso': [-0.1],
          'armB': [-2.9],
          'foreB': [-0.3],
          'armF': [-0.6],
          'foreF': [-1.6],
        }, guard),
        'out',
      ),
      ClipKey(0.14, callHold, 'snap'),
      ClipKey(0.36, callHold, 'lin'),
    ]);
    poses['superWind'] = p({
      'hips': [0, 0, 5],
      'torso': [-0.1],
      'head': [-0.2],
      'armF': [0.4],
      'foreF': [-1.9],
      'armB': [0.2],
      'foreB': [-2.0],
      'legF': [-0.6],
      'shinF': [1.2],
      'legB': [0.6],
      'shinB': [1.2],
      'scarf': [0.4],
    });
    final blastHold = p({
      'root': [0, 0, -3, 0.94, 1.08],
      'hips': [0, -2, 0],
      'torso': [-0.28],
      'head': [-0.3],
      'armF': [-3.05],
      'foreF': [-0.05],
      'armB': [-2.3],
      'foreB': [-0.6],
      'legF': [-0.1],
      'shinF': [0.25],
      'legB': [0.2],
      'shinB': [0.5],
      'scarf': [0.8],
    }, guard);
    clips['superBlast'] = Clip(0.5, [
      ClipKey(
        0,
        p({
          'hips': [0, 4, 0],
          'torso': [0.3],
          'armF': [-0.3],
          'foreF': [-0.3],
          'armB': [-0.6],
          'foreB': [-1.6],
          'legF': [-0.6],
          'shinF': [1.0],
          'legB': [0.5],
          'shinB': [1.0],
        }, guard),
      ),
      ClipKey(0.07, blastHold, 'snap'),
      ClipKey(0.5, blastHold, 'lin'),
    ]);
    poses['hurt'] = p({
      'torso': [-0.5],
      'head': [-0.35],
      'hips': [0, -2, 0],
      'armF': [0.5],
      'foreF': [-0.5],
      'armB': [0.7],
      'foreB': [-0.4],
      'legF': [-0.1],
      'shinF': [0.5],
      'legB': [0.5],
      'shinB': [0.8],
      'scarf': [0.9],
    });
    final downEnd = p({
      'root': [-1.52, -5, -12],
      'hips': [0, 0, 6],
      'torso': [-0.1],
      'head': [-0.1],
      'armF': [-0.4],
      'foreF': [-0.4],
      'armB': [-1.2],
      'foreB': [-0.3],
      'legF': [-0.3],
      'shinF': [0.3],
      'legB': [0.1],
      'shinB': [0.3],
      'scarf': [0.3],
    });
    clips['down'] = Clip(0.34, [
      ClipKey(0, poses['hurt']!),
      ClipKey(0.30, downEnd, 'out'),
    ]);
    clips['getup'] = Clip(0.35, [
      ClipKey(0, downEnd),
      ClipKey(
        0.16,
        p({
          'root': [-0.5, 0, -2],
          'hips': [0, 0, 8],
          'torso': [0.5],
          'head': [0.2],
          'armF': [-0.5],
          'foreF': [-1.0],
          'armB': [-0.3],
          'foreB': [-1.0],
          'legF': [-0.8],
          'shinF': [1.5],
          'legB': [0.6],
          'shinB': [1.6],
        }),
        'out',
      ),
      ClipKey(0.35, guard, 'back'),
    ]);
    poses['victory'] = p({
      'hips': [0, 0, 0],
      'torso': [-0.1],
      'head': [-0.15],
      'armF': [-2.75],
      'foreF': [-0.3],
      'armB': [-2.7],
      'foreB': [-0.3],
      'legF': [-0.15],
      'shinF': [0.3],
      'legB': [0.18],
      'shinB': [0.3],
      'scarf': [0.6],
    });
    final tossHold = p({
      'torso': [0.3],
      'head': [0.1],
      'armF': [-1.4],
      'foreF': [-0.05],
      'armB': [-1.3],
      'foreB': [-0.05],
      'hips': [0, 3, 2],
    }, guard);
    clips['finToss'] = Clip(0.8, [
      ClipKey(0, guard),
      ClipKey(
        0.15,
        p({
          'torso': [-0.25],
          'armF': [-2.4],
          'foreF': [-0.2],
          'armB': [-2.3],
          'foreB': [-0.2],
          'hips': [0, -1, 1],
        }, guard),
        'out',
      ),
      ClipKey(0.35, tossHold, 'snap'),
      ClipKey(0.8, tossHold, 'lin'),
    ]);
    clips['inhale'] = Clip(0.45, [
      ClipKey(0, guard),
      ClipKey(
        0.4,
        p({
          'torso': [-0.36],
          'head': [-0.32],
          'armF': [-0.3],
          'foreF': [-0.8],
          'armB': [-0.1],
          'foreB': [-0.9],
          'hips': [0, -2, 0],
        }, guard),
        'out',
      ),
    ]);
  }

  static final FighterClips instance = FighterClips._();

  late final Float32List guard;
  final Map<String, Float32List> poses = {};
  final Map<String, Clip> clips = {};
}

bool _fighterProcedural(
  Float32List pose,
  String name,
  double t,
  double ph,
  double charge,
) {
  final r = rigFighter, fc = FighterClips.instance, g = fc.guard;
  switch (name) {
    case 'idle':
      pose.setAll(0, g);
      final b = math.sin(t * 7.2);
      _addTo(pose, r, 'hips', 0, 0, b * 1.1 + 0.6);
      _addTo(pose, r, 'torso', math.sin(t * 7.2 + 0.5) * 0.025);
      _addTo(pose, r, 'armF', math.sin(t * 7.2 + 1) * 0.06);
      _addTo(pose, r, 'foreF', math.sin(t * 7.2 + 1.4) * 0.07);
      _addTo(pose, r, 'head', math.sin(t * 3.6) * 0.03);
      _addTo(pose, r, 'scarf', math.sin(t * 4) * 0.12);
      _addTo(pose, r, 'hair', math.sin(t * 5) * 0.12);
    case 'run' || 'runBack':
      pose.setAll(0, g);
      final back = name == 'runBack';
      final s = math.sin(ph), c = math.cos(ph);
      final sw = back ? 0.62 : 0.85;
      _addTo(pose, r, 'hips', 0, 0, 1 - c.abs() * 2.6);
      _addTo(pose, r, 'torso', back ? -0.05 : 0.16 + c * 0.03);
      _addTo(pose, r, 'legF', -0.1 + s * sw);
      _addTo(pose, r, 'shinF', 0.5 + math.max(0.0, -s) * 1.0 - 0.3);
      _addTo(pose, r, 'legB', 0.05 - s * sw);
      _addTo(pose, r, 'shinB', 0.4 + math.max(0.0, s) * 1.0 - 0.3);
      _addTo(pose, r, 'armF', -0.2 - s * 0.5 * (back ? 0.5 : 1));
      _addTo(pose, r, 'armB', 0.1 + s * 0.5 * (back ? 0.5 : 1));
      _addTo(pose, r, 'scarf', back ? -0.25 : 0.55 + s * 0.12);
      _addTo(pose, r, 'hair', back ? -0.1 : 0.4);
    case 'superFlurry':
      pose.setAll(0, g);
      final k = math.sin(t * 78), k2 = math.sin(t * 78 + math.pi);
      _addTo(pose, r, 'hips', 0, 4, 0);
      _addTo(pose, r, 'torso', 0.15 + k * 0.1);
      pose[r.idx['armF']! * 5] = -1.1 - math.max(0.0, k) * 0.5;
      pose[r.idx['foreF']! * 5] = -0.9 + math.max(0.0, k) * 0.85;
      pose[r.idx['armB']! * 5] = -1.1 - math.max(0.0, k2) * 0.5;
      pose[r.idx['foreB']! * 5] = -0.9 + math.max(0.0, k2) * 0.85;
      _addTo(pose, r, 'scarf', 0.6);
    case 'pat':
      pose.setAll(0, g);
      final p = math.sin(t * 13);
      _addTo(pose, r, 'torso', 0.3);
      _addTo(pose, r, 'hips', 0, 3, 2);
      pose[r.idx['armF']! * 5] = -1.1 + p * 0.18;
      pose[r.idx['foreF']! * 5] = -0.25 + p * 0.35;
      _addTo(pose, r, 'head', 0.1 + math.sin(t * 4) * 0.05);
    case 'blow':
      pose.setAll(0, g);
      final k = _clamp(t / 0.25, 0, 1);
      _addTo(pose, r, 'torso', 0.32 * k - 0.1);
      _addTo(pose, r, 'hips', 0, 4 * k, 2);
      _addTo(pose, r, 'head', 0.1);
      pose[r.idx['armF']! * 5] = -0.6;
      pose[r.idx['foreF']! * 5] = -0.5;
      pose[r.idx['armB']! * 5] = -0.4;
      pose[r.idx['foreB']! * 5] = -0.6;
      _addTo(pose, r, 'scarf', 0.9 + math.sin(t * 20) * 0.15);
    case 'victory':
      pose.setAll(0, fc.poses['victory']!);
      final b = math.sin(t * 6).abs();
      _addTo(pose, r, 'root', 0, 0, -b * 5);
      _addTo(pose, r, 'scarf', math.sin(t * 8) * 0.2);
    case 'wave':
      pose.setAll(0, g);
      final w = math.sin(t * 16);
      _addTo(pose, r, 'hips', 0, 0, 0.5 + math.sin(t * 8).abs() * 1.2);
      pose[r.idx['armB']! * 5] = -2.85 + w * 0.12;
      pose[r.idx['foreB']! * 5] = -0.3 + w * 0.5;
      _addTo(pose, r, 'torso', -0.06);
      _addTo(pose, r, 'scarf', 0.2);
    case 'chargeSlam':
      pose.setAll(0, fc.poses['chargeSlam']!);
      final sh = math.sin(t * 60) * (0.6 + charge * 1.4);
      _addTo(pose, r, 'root', 0, sh, 0);
      _addTo(pose, r, 'hips', 0, 0, charge * 2);
    default:
      return false;
  }
  return true;
}

void _trollProcedural(Float32List pose, String name, double t, double dur) {
  final r = rigTroll;
  pose.setAll(0, r.rest);
  final br = math.sin(t * 2.0);
  int ix(String n) => r.idx[n]! * 5;
  // Resting: arms folded on the belly, feet dangling.
  pose[ix('armF')] = 0.15;
  pose[ix('foreF')] = -1.6;
  pose[ix('armB')] = -0.15;
  pose[ix('foreB')] = 1.5;
  pose[ix('legF')] = math.sin(t * 1.3) * 0.05;
  pose[ix('legB')] = math.sin(t * 1.3 + 1) * 0.05;
  pose[ix('pillow') + 1] = -6;
  pose[ix('pillow') + 2] = 6;
  _addTo(pose, r, 'body', 0, 0, 0, 0, br * 0.025);
  _addTo(pose, r, 'head', math.sin(t * 1.0) * 0.04 + br * 0.015, 0, br * 0.8);
  final out = brawlEase['out']!, snap = brawlEase['snap']!;
  switch (name) {
    case 'telegraph':
      final k = _clamp(t / (dur <= 0 ? 1.2 : dur), 0, 1);
      final e = out(_clamp(k * 1.6, 0, 1));
      final sh = math.sin(t * 38) * 0.012 * k;
      pose[ix('armF')] = 0.15 + (2.95 - 0.15) * e + sh;
      pose[ix('foreF')] = -1.6 + 1.4 * e;
      pose[ix('armB')] = -0.15 + (-2.95 + 0.15) * e - sh;
      pose[ix('foreB')] = 1.5 - 1.3 * e;
      pose[ix('pillow') + 1] = -6 + 2 * e;
      pose[ix('pillow') + 2] = 6 - 118 * e;
      pose[ix('pillow')] = -0.1 * e;
      _addTo(pose, r, 'body', 0.12 * e, 4 * e, 0, 0, 0.06 * e);
      _addTo(pose, r, 'head', -0.2 * e, 0, -4 * e);
      _addTo(pose, r, 'legF', -0.2 * e);
      _addTo(pose, r, 'legB', 0.1 * e);
    case 'strike':
      final k = _clamp(t / 0.18, 0, 1), e = snap(k);
      pose[ix('armF')] = 2.95 + (0.35 - 2.95) * e;
      pose[ix('foreF')] = -0.2 + 0.1 * e;
      pose[ix('armB')] = -2.95 + (-0.35 + 2.95) * e;
      pose[ix('foreB')] = 0.2;
      pose[ix('pillow') + 1] = -4 + (-62) * e;
      pose[ix('pillow') + 2] = -112 + (112 + 24) * e;
      pose[ix('pillow')] = -0.1 + 1.0 * e;
      _addTo(pose, r, 'body', -0.11 * e, -10 * e, 0, 0.06 * e, -0.09 * e);
      _addTo(pose, r, 'head', 0.1 * e, -4 * e, 4 * e);
      if (t > 0.18) {
        final s = _clamp((t - 0.18) / 0.3, 0, 1);
        _addTo(pose, r, 'body', 0.11 * out(s) * 0.6, 10 * out(s) * 0.6);
      }
    case 'recover':
      final k = _clamp(t / 0.9, 0, 1);
      pose[ix('pillow') + 1] = -66 * (1 - k) - 6 * k;
      pose[ix('pillow') + 2] = 24 * (1 - k) + 6 * k;
      pose[ix('pillow')] = 1.0 * (1 - k);
      pose[ix('armF')] = 0.35 + (0.15 - 0.35) * k;
      pose[ix('foreF')] = -0.1 + (-1.6 + 0.1) * k;
      pose[ix('armB')] = -0.35 + (-0.15 + 0.35) * k;
      pose[ix('foreB')] = 0.2 + (1.5 - 0.2) * k;
      _addTo(pose, r, 'head', 0.08 * (1 - k), 0, 2 * (1 - k));
    case 'daze':
      final s = math.sin(t * 3.2);
      _addTo(pose, r, 'body', s * 0.07, s * 3, 0, 0, 0.03 * math.sin(t * 6.4));
      _addTo(pose, r, 'head', -s * 0.16 + 0.1, 0, 4);
      pose[ix('armF')] = 0.55 + s * 0.1;
      pose[ix('foreF')] = -0.5;
      pose[ix('armB')] = -0.55 - s * 0.1;
      pose[ix('foreB')] = 0.5;
    case 'nap':
      final sn = math.sin(t * 1.3);
      _addTo(pose, r, 'body', 0.04, 3, 0, 0, sn * 0.03);
      _addTo(pose, r, 'head', 0.16 + sn * 0.02, 5, 8);
    default:
      break;
  }
}

void _fogProcedural(Float32List pose, String name, double t, double dur) {
  final r = rigFog;
  pose.setAll(0, r.rest);
  double ph(int i) => t * 1.6 + i * 1.7;
  const names = [
    'puffBL',
    'puffBR',
    'puffL',
    'puffR',
    'puffT',
    'puffTL',
    'puffTR',
    'puffC',
  ];
  var sc = 1.0, jit = 0.0;
  if (name == 'telegraph') {
    final k = _clamp(t / (dur <= 0 ? 1.5 : dur), 0, 1);
    sc = 1 + 0.18 * brawlEase['out']!(k);
    jit = k;
  } else if (name == 'strike') {
    sc = 1.18 - 0.1 * _clamp(t / 0.5, 0, 1);
    jit = 0.5;
  } else if (name == 'recover') {
    sc = 1.08 - 0.08 * _clamp(t / 0.9, 0, 1);
  } else if (name == 'daze') {
    sc = 0.9 + math.sin(t * 2.4) * 0.03;
  }
  for (var i = 0; i < names.length; i++) {
    final id = r.idx[names[i]]! * 5;
    pose[id + 1] += math.sin(ph(i)) * 1.8 + math.sin(t * 45 + i) * jit * 1.2;
    pose[id + 2] += math.cos(ph(i) * 1.1) * 1.6;
    final s = sc * (1 + math.sin(ph(i) + 1) * 0.035);
    pose[id + 3] = s;
    pose[id + 4] = s;
  }
  const wisps = ['wispL', 'wispC', 'wispR'];
  for (var i = 0; i < 3; i++) {
    final id = r.idx[wisps[i]]! * 5;
    pose[id] = math.sin(t * 2.2 + i * 1.3) * 0.28;
    pose[id + 4] = 1 + math.sin(t * 2.8 + i) * 0.12;
  }
  final f = r.idx['face']! * 5;
  pose[f + 2] += math.sin(t * 1.7) * 1.2;
  if (name == 'daze') pose[f] = math.sin(t * 3) * 0.12;
}

// ------------------------------------------------------------------ actor

const Map<String, double> _blend = {
  'guard': 0.05,
  'jab': 0.025,
  'cross': 0.025,
  'kick': 0.03,
  'upper': 0.035,
  'idle': 0.1,
  'run': 0.08,
  'runBack': 0.08,
  'jump': 0.05,
  'fall': 0.1,
  'dive': 0.04,
  'diveLand': 0.03,
  'slamLand': 0.02,
  'slamRise': 0.04,
  'slamFall': 0.05,
  'cast': 0.04,
  'call': 0.05,
  'hurt': 0.03,
  'down': 0.04,
  'getup': 0.04,
  'superWind': 0.06,
  'superFlurry': 0.04,
  'superBlast': 0.03,
  'chargeSlam': 0.06,
  'victory': 0.08,
  'finToss': 0.06,
  'pat': 0.08,
  'inhale': 0.06,
  'blow': 0.05,
};

/// A rig instance with blending between clips. [kind] is 'fighter', 'troll'
/// or 'fog'.
class RigActor {
  RigActor(this.rig, this.kind, Map<String, Color> pal)
    : o = ArtOpts(pal),
      pose = Float32List(rig.n * 5),
      _from = Float32List(rig.n * 5),
      _last = Float32List(rig.n * 5),
      _tmp = Float32List(rig.n * 5),
      art = brawlArt[kind]! {
    _from.setAll(0, rig.rest);
    _last.setAll(0, rig.rest);
    pose.setAll(0, rig.rest);
  }

  final Rig rig;
  final String kind;
  final ArtOpts o;
  final Float32List pose;
  final Float32List _from;
  final Float32List _last;
  final Float32List _tmp;
  final Map<String, ArtFn> art;
  String _name = '';
  double _blendDur = 0.06;

  /// The run cycle's phase, advanced by the scene.
  double phase = 0;

  double _atX = 0, _atY = 0, _atS = 1, _atFlip = 1;

  static final Float64List _m4 = _identity4();

  /// Poses the rig for [name] at [animT]. Returns [pose].
  Float32List update(
    String name,
    double animT, {
    double? time,
    double? blend,
    double charge = 0,
    double dur = 1.2,
  }) {
    if (name != _name) {
      _from.setAll(0, _last);
      _name = name;
      _blendDur = blend ?? _blend[name] ?? 0.08;
    }
    o.t = time ?? animT;
    final tgt = _tmp;
    if (kind == 'fighter') {
      final fc = FighterClips.instance;
      if (!_fighterProcedural(tgt, name, animT, phase, charge)) {
        final clip = fc.clips[name];
        final still = fc.poses[name];
        if (clip != null) {
          clip.eval(animT, tgt);
        } else if (still != null) {
          tgt.setAll(0, still);
        } else {
          tgt.setAll(0, fc.guard);
        }
      }
    } else if (kind == 'troll') {
      _trollProcedural(tgt, name, animT, dur);
    } else {
      _fogProcedural(tgt, name, animT, dur);
    }
    final b = _blendDur > 0 ? _clamp(animT / _blendDur, 0, 1) : 1.0;
    if (b >= 1) {
      pose.setAll(0, tgt);
    } else {
      final e = b * b * (3 - 2 * b);
      for (var i = 0; i < pose.length; i++) {
        pose[i] = _from[i] + (tgt[i] - _from[i]) * e;
      }
    }
    _last.setAll(0, pose);
    return pose;
  }

  void _solve() {
    final m = rig.m, parts = rig.parts;
    for (var i = 0; i < rig.n; i++) {
      final pt = parts[i], k = i * 5;
      final r = pose[k], co = math.cos(r), si = math.sin(r);
      final sx = pose[k + 3], sy = pose[k + 4];
      final la = co * sx, lb = si * sx, lc = -si * sy, ld = co * sy;
      final le = pt.x + pose[k + 1], lf = pt.y + pose[k + 2];
      final j = i * 6;
      if (pt.pi < 0) {
        m[j] = la;
        m[j + 1] = lb;
        m[j + 2] = lc;
        m[j + 3] = ld;
        m[j + 4] = le;
        m[j + 5] = lf;
      } else {
        final q = pt.pi * 6;
        final pa = m[q], pb = m[q + 1], pc = m[q + 2], pd = m[q + 3];
        final pe = m[q + 4], pf = m[q + 5];
        m[j] = pa * la + pc * lb;
        m[j + 1] = pb * la + pd * lb;
        m[j + 2] = pa * lc + pc * ld;
        m[j + 3] = pb * lc + pd * ld;
        m[j + 4] = pa * le + pc * lf + pe;
        m[j + 5] = pb * le + pd * lf + pf;
      }
    }
  }

  /// Draws the rig with its ground contact at ([x], [y]), scaled by [s];
  /// [flip] -1 mirrors it.
  void draw(BrawlPen g, double x, double y, double s, double flip) {
    _atX = x;
    _atY = y;
    _atS = s;
    _atFlip = flip;
    _solve();
    final cv = g.cv, m = rig.m;
    cv.save();
    cv.translate(x, y);
    cv.scale(s * flip, s);
    for (final i in rig.order) {
      final fn = art[rig.parts[i].a];
      if (fn == null) continue;
      final j = i * 6;
      _m4[0] = m[j];
      _m4[1] = m[j + 1];
      _m4[4] = m[j + 2];
      _m4[5] = m[j + 3];
      _m4[12] = m[j + 4];
      _m4[13] = m[j + 5];
      cv.save();
      cv.transform(_m4);
      fn(g, o);
      cv.restore();
    }
    cv.restore();
  }

  /// A point in screen space for a local point of a named part (after a
  /// [draw]).
  Offset pt(String part, double lx, double ly) {
    final i = rig.idx[part]! * 6, m = rig.m;
    final rx = m[i] * lx + m[i + 2] * ly + m[i + 4];
    final ry = m[i + 1] * lx + m[i + 3] * ly + m[i + 5];
    return Offset(_atX + rx * _atS * _atFlip, _atY + ry * _atS);
  }
}

Float64List _identity4() {
  final m = Float64List(16);
  m[10] = 1;
  m[15] = 1;
  return m;
}

/// The 'back' ease is used by getting up; keep a reference so it is not
/// tree-shaken away if the table changes.
double brawlEaseOutBack(double u) => brawlEase['back']!(u);
