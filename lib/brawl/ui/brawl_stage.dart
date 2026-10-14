// The brawl's stage: a warm dusk sky, hills, a hedge and fence, the porch with
// a lit door and a plant, and a dark espresso floor. A port of the prototype's
// stage.js.
//
// The still layers are recorded once into pictures when the size is known and
// replayed with parallax every frame; the sky, the glows, the floor and the
// small living things (stars, clouds, dust motes, the plant) are painted live
// from cached gradients. Every light here is painted as light, not tinted over
// the picture.
library;

import 'dart:math' as math;
import 'dart:ui';

import 'brawl_art.dart' show BrawlPen;

const double _tau = math.pi * 2;

Color _hex(int rgb, [double a = 1]) =>
    Color.fromRGBO((rgb >> 16) & 255, (rgb >> 8) & 255, rgb & 255, a);

class BrawlStage {
  BrawlStage(this.w, this.h, this.groundY) {
    _build();
  }

  /// The logical width the world is drawn at (393).
  final double w;
  final double h;
  final double groundY;

  late final Picture _far;
  late final Picture _mid;
  late final Picture _house;
  late final Paint _sky;
  late final Paint _floor;
  late final Paint _vignette;
  late final List<_Mote> _motes;
  final Paint _p = Paint()..isAntiAlias = true;
  final BrawlPen _pen = BrawlPen();

  Picture _record(
    double pw,
    double ph,
    void Function(BrawlPen g, double w, double h) fn,
  ) {
    final rec = PictureRecorder();
    final g = BrawlPen()..cv = Canvas(rec);
    fn(g, pw, ph);
    return rec.endRecording();
  }

  void _build() {
    _far = _record(w + 90, groundY, _drawFar);
    _mid = _record(w + 180, groundY, _drawMid);
    _house = _record(310, groundY, _drawHouse);
    _sky = Paint()
      ..shader = Gradient.linear(
        Offset(0, -30),
        Offset(0, groundY),
        [
          _hex(0x221424),
          _hex(0x5b2f37),
          _hex(0xa65649),
          _hex(0xdd8d58),
          _hex(0xf5bb74),
          _hex(0xffd9a3),
        ],
        const [0, 0.28, 0.5, 0.68, 0.84, 1],
      );
    final fh = h - groundY + 40;
    _floor = Paint()
      ..shader = Gradient.linear(
        Offset(0, groundY),
        Offset(0, groundY + fh),
        [_hex(0x4a2f1d), _hex(0x35201a), _hex(0x231510), _hex(0x130b07)],
        const [0, 0.08, 0.5, 1],
      );
    _vignette = Paint()
      ..shader = Gradient.radial(
        Offset(w / 2, h * 0.52),
        h * 0.78,
        [_hex(0x0a0502, 0), _hex(0x0a0502, 0.55)],
        const [0, 1],
        TileMode.clamp,
        null,
        Offset(w / 2, h * 0.52),
        h * 0.28,
      );
    final rnd = math.Random(11);
    _motes = [
      for (var i = 0; i < 26; i++)
        _Mote(
          rnd.nextDouble() * 460,
          rnd.nextDouble() * groundY,
          0.6 + rnd.nextDouble() * 1.6,
          rnd.nextDouble() * _tau,
          4 + rnd.nextDouble() * 10,
        ),
    ];
  }

  // ---------------------------------------------------------------- layers

  void _hill(
    BrawlPen g,
    double w,
    double baseY,
    double amp,
    double f,
    double ph,
    double bottom,
    Color c,
  ) {
    final path = Path()..moveTo(0, bottom);
    for (var x = 0.0; x <= w; x += 6) {
      path.lineTo(
        x,
        baseY -
            amp *
                (math.sin(x * f + ph) * 0.6 +
                    math.sin(x * f * 2.3 + ph * 1.7) * 0.3 +
                    0.5),
      );
    }
    path
      ..lineTo(w, bottom)
      ..close();
    g.fillPath(path, c);
  }

  void _tree(
    BrawlPen g,
    double x,
    double base,
    double s,
    Color col,
    Color trunk,
  ) {
    g.cv.drawRect(
      Rect.fromLTWH(x - 2 * s, base - 22 * s, 4 * s, 22 * s),
      _p
        ..style = PaintingStyle.fill
        ..shader = null
        ..color = trunk,
    );
    for (final c in const [
      [0.0, -34.0, 15.0],
      [-11.0, -26.0, 11.0],
      [11.0, -27.0, 12.0],
      [0.0, -46.0, 11.0],
    ]) {
      g.fillCircle(x + c[0] * s, base + c[1] * s, c[2] * s, col);
    }
  }

  void _rect(BrawlPen g, double x, double y, double w, double h, Color c) {
    g.cv.drawRect(
      Rect.fromLTWH(x, y, w, h),
      _p
        ..style = PaintingStyle.fill
        ..shader = null
        ..color = c,
    );
  }

  void _drawFar(BrawlPen g, double pw, double ph) {
    final sx = pw * 0.72, sy = ph - 62;
    g.cv.drawRect(
      Rect.fromLTWH(0, 0, pw, ph),
      Paint()
        ..shader = Gradient.radial(
          Offset(sx, sy),
          190,
          [_hex(0xffe2a0, 0.85), _hex(0xffbe6e, 0.38), _hex(0xffaa5a, 0)],
          const [0, 0.25, 1],
          TileMode.clamp,
          null,
          Offset(sx, sy),
          6,
        ),
    );
    g.fillCircle(sx, sy, 30, _hex(0xffe6b0));
    _hill(g, pw, ph - 28, 46, 0.011, 0.4, ph, _hex(0x8a4a43));
    _hill(g, pw, ph - 14, 38, 0.016, 2.2, ph, _hex(0x6e3a3d));
    final cottage = _hex(0x4a2a2e);
    g.fillRR(28, ph - 58, 42, 28, 2, cottage);
    g.fillPath(
      Path()
        ..moveTo(22, ph - 56)
        ..lineTo(49, ph - 76)
        ..lineTo(76, ph - 56)
        ..close(),
      cottage,
    );
    _rect(g, 40, ph - 50, 8, 9, _hex(0xffd28a));
    _rect(g, 53, ph - 50, 6, 9, _hex(0xffd28a, 0.5));
    _tree(g, 120, ph - 18, 0.9, _hex(0x4a2a2e), _hex(0x3a2024));
    _tree(g, 150, ph - 14, 0.7, _hex(0x4e2d30), _hex(0x3a2024));
    _tree(g, pw - 84, ph - 18, 1.05, _hex(0x4a2a2e), _hex(0x3a2024));
    _tree(g, pw - 40, ph - 16, 0.8, _hex(0x512f32), _hex(0x3a2024));
    _hill(g, pw, ph - 4, 26, 0.02, 4.1, ph, _hex(0x3d2227));
  }

  void _drawMid(BrawlPen g, double pw, double ph) {
    final hb = ph - 4;
    final hedge = _hex(0x2d3320);
    for (var x = -10.0; x < pw + 10; x += 13) {
      g.fillCircle(x, hb - 26 - ((x * 7) % 9), 17 + ((x * 3) % 5), hedge);
    }
    _rect(g, 0, hb - 30, pw, 34, hedge);
    final leaf = _hex(0x7a8e4e, 0.32);
    for (var x = 4.0; x < pw; x += 19) {
      g.fillCircle(x, hb - 38 - ((x * 5) % 7), 6, leaf);
    }
    const bl = [0xD88A8A, 0xE5C896, 0xF3E6C8];
    for (var x = 8.0; x < pw; x += 23) {
      g.fillCircle(
        x + ((x * 11) % 9),
        hb - 22 - ((x * 13) % 14),
        1.8,
        _hex(bl[(x / 23).floor() % 3]),
      );
    }
    _rect(g, 0, hb - 22, pw, 3, _hex(0x5a3a28));
    _rect(g, 0, hb - 8, pw, 3, _hex(0x5a3a28));
    for (var x = 4.0; x < pw; x += 14) {
      g.fillPath(
        Path()
          ..moveTo(x, hb - 40)
          ..lineTo(x + 4, hb - 46)
          ..lineTo(x + 8, hb - 40)
          ..lineTo(x + 8, hb + 2)
          ..lineTo(x, hb + 2)
          ..close(),
        _hex(0x74492f),
      );
      _rect(g, x, hb - 40, 2, 42, _hex(0xffd696, 0.22));
    }
    const lx = 118.0;
    _rect(g, lx - 2, hb - 96, 4, 98, _hex(0x3a2416));
    g.fillRR(lx - 9, hb - 112, 18, 18, 4, _hex(0x4a2f1a));
    g.cv.drawRect(
      Rect.fromLTWH(lx - 70, hb - 175, 140, 140),
      Paint()
        ..shader = Gradient.radial(
          const Offset(lx, 0).translate(0, hb - 103),
          64,
          [_hex(0xffd68c, 0.9), _hex(0xffbe6e, 0.28), _hex(0xffbe6e, 0)],
          const [0, 0.3, 1],
          TileMode.clamp,
          null,
          const Offset(lx, 0).translate(0, hb - 103),
          2,
        ),
    );
    g.fillRR(lx - 5, hb - 108, 10, 11, 3, _hex(0xffe3a8));
  }

  void _drawHouse(BrawlPen g, double pw, double ph) {
    final top = ph - 218;
    g.cv.drawRect(
      Rect.fromLTWH(22, top, pw - 22, ph - top),
      Paint()
        ..shader = Gradient.linear(Offset(0, top), Offset(0, ph), [
          _hex(0x6a4430),
          _hex(0x4b2f20),
        ]),
    );
    for (var y = top + 12; y < ph; y += 13) {
      _rect(g, 22, y, pw - 22, 2, _hex(0x140a04, 0.28));
      _rect(g, 22, y + 2, pw - 22, 1.5, _hex(0xffd696, 0.07));
    }
    _rect(g, 14, top - 8, pw - 14, 24, _hex(0x2f1d12));
    _rect(g, 14, top - 8, pw - 14, 3, _hex(0xffd696, 0.14));
    _rect(g, 22, top + 16, pw - 22, 14, _hex(0x0f0804, 0.35));
    _rect(g, 14, top - 8, 14, ph - top + 8, _hex(0x7a4d33));
    _rect(g, 14, top - 8, 3, ph - top + 8, _hex(0xffd696, 0.2));
    _rect(g, 10, top + 14, 22, 8, _hex(0x5a3a28));
    _rect(g, 10, ph - 14, 22, 14, _hex(0x5a3a28));
    // window with curtains and warm light
    final wx = 70.0, wy = ph - 172;
    g.fillRR(wx - 4, wy - 4, 56, 66, 4, _hex(0x2f1d12));
    g.cv.drawRect(
      Rect.fromLTWH(wx, wy, 48, 58),
      Paint()
        ..shader = Gradient.linear(Offset(0, wy), Offset(0, wy + 58), [
          _hex(0xffe3a8),
          _hex(0xf0a85e),
        ]),
    );
    final curtain = _hex(0x823c32, 0.55);
    g.fillPath(
      Path()
        ..moveTo(wx, wy)
        ..lineTo(wx + 16, wy)
        ..quadraticBezierTo(wx + 8, wy + 30, wx + 14, wy + 58)
        ..lineTo(wx, wy + 58)
        ..close(),
      curtain,
    );
    g.fillPath(
      Path()
        ..moveTo(wx + 48, wy)
        ..lineTo(wx + 32, wy)
        ..quadraticBezierTo(wx + 40, wy + 30, wx + 34, wy + 58)
        ..lineTo(wx + 48, wy + 58)
        ..close(),
      curtain,
    );
    _rect(g, wx + 22, wy, 4, 58, _hex(0x2f1d12));
    _rect(g, wx, wy + 26, 48, 4, _hex(0x2f1d12));
    g.fillRR(wx - 8, wy + 60, 64, 7, 2, _hex(0x4a2f1a));
    // the door
    const dx = 180.0, dw = 88.0, dh = 150.0;
    final dtop = ph - dh;
    g.fillRR(dx - dw / 2 - 9, dtop - 14, dw + 18, dh + 14, 4, _hex(0x2a170d));
    g.fillRR(dx - dw / 2 - 5, dtop - 8, dw + 10, dh + 8, 3, _hex(0x3a2314));
    g.cv.drawRect(
      Rect.fromLTWH(dx - dw / 2, dtop, dw, dh),
      Paint()
        ..shader = Gradient.linear(
          Offset(0, dtop),
          Offset(0, ph),
          [_hex(0xffdca0), _hex(0xf3b068), _hex(0xd98a4a)],
          const [0, 0.6, 1],
        ),
    );
    _rect(g, dx - dw / 2, ph - 18, dw, 18, _hex(0x7a3c32, 0.55));
    _rect(g, dx + 14, ph - 70, 3, 52, _hex(0x6a3a2a));
    g.fillCircle(dx + 15.5, ph - 74, 10, _hex(0xffeec4));
    g.fillPath(
      Path()
        ..moveTo(dx - dw / 2, dtop)
        ..lineTo(dx - dw / 2 + 20, dtop + 7)
        ..lineTo(dx - dw / 2 + 20, ph - 5)
        ..lineTo(dx - dw / 2, ph)
        ..close(),
      _hex(0x6a3f27),
    );
    _rect(g, dx - dw / 2 + 2, dtop + 6, 4, dh - 14, _hex(0xffd696, 0.15));
    g.fillCircle(dx - dw / 2 + 14, ph - 62, 2.4, _hex(0xE5C896));
    g.fillRR(dx - 22, dtop - 40, 44, 22, 4, _hex(0xffd7a0));
    _rect(g, dx - 1, dtop - 40, 2, 22, _hex(0x2a170d));
    _rect(g, pw - 14, top - 8, 14, ph - top + 8, _hex(0x7a4d33));
    _rect(g, pw - 14, top - 8, 3, ph - top + 8, _hex(0xffd696, 0.2));
    _rect(g, 22, ph - 4, pw - 22, 4, _hex(0x2f1d12));
  }

  // ---------------------------------------------------------------- the plant

  /// The porch plant: [k] 0 thirsty and drooping, 1 lush with a flower.
  void drawPlant(Canvas c, double x, double y, double k, double t) {
    final droop = 1 - k, sway = math.sin(t * 1.4) * 0.03;
    final g = _pen..cv = c;
    c.save();
    c.translate(x, y);
    g.fillPath(
      Path()
        ..moveTo(-14, -26)
        ..lineTo(14, -26)
        ..lineTo(11, 0)
        ..lineTo(-11, 0)
        ..close(),
      _hex(0x9a5a36),
    );
    g.fillRR(-16, -32, 32, 9, 3, _hex(0xb86f44));
    _rect(g, -12, -24, 4, 20, _hex(0xffd696, 0.22));
    g.fillEll(0, -31, 12, 3, _hex(0x3a2416));
    const leaves = [
      [-1.0, 0.9, 30.0],
      [1.0, 0.8, 34.0],
      [-1.0, 0.45, 40.0],
      [1.0, 0.4, 42.0],
      [0.0, 0.05, 46.0],
    ];
    for (var i = 0; i < leaves.length; i++) {
      final l = leaves[i];
      final side = l[0], lift = l[1];
      final ang =
          side * (0.35 + droop * 1.0) * (1.2 - lift * 0.6) + sway * (i + 1);
      final len = (l[2] - 12) * (0.75 + k * 0.4);
      c.save();
      c.translate(0, -31);
      c.rotate(ang);
      g.strokePath(
        Path()
          ..moveTo(0, 0)
          ..quadraticBezierTo(side * 2, -len * 0.5, side * droop * 12, -len),
        k > 0.5 ? _hex(0x6F8A6B) : _hex(0x8a8a58),
        2.4,
      );
      g.fillEll(
        side * droop * 12,
        -len,
        8.5,
        4.6,
        k > 0.5 ? _hex(0x7E9C74) : _hex(0x97945f),
        side * (0.5 + droop * 0.9),
      );
      c.restore();
    }
    if (k > 0.55) {
      final f = math.min(1.0, (k - 0.55) / 0.45);
      final ry = -31 - 52 * (0.8 + 0.2 * f);
      c.save();
      c.translate(0, ry);
      c.scale(f, f);
      for (var i = 0; i < 6; i++) {
        c.save();
        c.rotate(i * math.pi / 3 + sway);
        g.fillEll(0, -7, 4.6, 7.4, _hex(0xD88A8A));
        c.restore();
      }
      g.fillCircle(0, 0, 4.2, _hex(0xF3E6C8));
      c.restore();
    }
    c.restore();
  }

  // ---------------------------------------------------------------- the whole stage

  /// Paints the stage for a camera at [camX], at time [t]. [plantK] is how
  /// well the plant is doing, [haze] how much mist hangs over the porch.
  void draw(
    Canvas c,
    double camX,
    double t, {
    double plantK = 0.7,
    double haze = 0,
    double doorGlow = 1,
  }) {
    final gy = groundY;
    final cx = camX;
    c.drawRect(Rect.fromLTRB(-40, -40, w + 40, gy + 1), _sky);
    // a few stars in the dark top of the sky
    for (var i = 0; i < 16; i++) {
      final sx = (i * 97) % w, sy = 8.0 + (i * 53) % 90;
      final a = 0.25 + 0.3 * (0.5 + 0.5 * math.sin(t * 1.3 + i * 2.1));
      c.drawRect(
        Rect.fromLTWH(sx - cx * 0.05, sy, 1.6, 1.6),
        _p
          ..style = PaintingStyle.fill
          ..shader = null
          ..color = _hex(0xFFF1D6, (a * (1 - sy / 120)).clamp(0.0, 1.0)),
      );
    }
    // slow streaks of cloud
    _p.color = const Color.fromRGBO(255, 196, 150, 0.20);
    for (var i = 0; i < 3; i++) {
      final x = ((i * 190 + t * (4 + i * 2)) % (w + 240)) - 120 - cx * 0.1;
      final y = 70.0 + i * 52;
      c.drawOval(
        Rect.fromCenter(
          center: Offset(x, y),
          width: (78 - i * 9) * 2,
          height: (7 - i) * 2,
        ),
        _p,
      );
      c.drawOval(
        Rect.fromCenter(center: Offset(x + 46, y - 6), width: 88, height: 12),
        _p,
      );
    }
    c.save();
    c.translate(-45 - cx * 0.18, 0);
    c.drawPicture(_far);
    c.restore();
    c.save();
    c.translate(-90 - cx * 0.5, 0);
    c.drawPicture(_mid);
    c.restore();
    c.save();
    c.translate(170 - cx, 0);
    c.drawPicture(_house);
    c.restore();
    // warm light pooling from the door onto the floor
    _p
      ..blendMode = BlendMode.plus
      ..shader = Gradient.radial(
        Offset(350 - cx, gy - 40),
        150,
        [_hex(0xffc478, 0.32 * doorGlow), _hex(0xffc478, 0)],
        const [0, 1],
        TileMode.clamp,
        null,
        Offset(350 - cx, gy - 40),
        10,
      );
    c.drawRect(Rect.fromLTWH(350 - cx - 150, gy - 190, 300, 230), _p);
    _p
      ..shader = null
      ..blendMode = BlendMode.srcOver;
    drawPlant(c, 212 - cx, gy, plantK, t);
    // floor
    final fh = h - gy + 40;
    c.drawRect(Rect.fromLTWH(-40, gy, w + 80, fh), _floor);
    _rect(_pen..cv = c, -40, gy, w + 80, 1.6, _hex(0xffd696, 0.32));
    _rect(_pen, -40, gy + 1.6, w + 80, 6, _hex(0xffd696, 0.07));
    final vp = w * 0.5;
    final seams = Path();
    final lights = Path();
    for (var wx = -60.0; wx <= 560; wx += 44) {
      final xt = wx - cx, xb = vp + (xt - vp) * 1.9;
      seams
        ..moveTo(xt, gy + 2)
        ..lineTo(xb, gy + fh);
      final xt2 = wx - cx + 2, xb2 = vp + (xt2 - vp) * 1.9;
      lights
        ..moveTo(xt2, gy + 2)
        ..lineTo(xb2, gy + fh);
    }
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = _hex(0x0a0502, 0.55);
    c.drawPath(seams, _p);
    _p
      ..strokeWidth = 1
      ..color = _hex(0xffd696, 0.06);
    c.drawPath(lights, _p);
    _p
      ..strokeWidth = 1.2
      ..color = _hex(0x0a0502, 0.4);
    for (final d in const [16.0, 44.0, 90.0]) {
      c.drawLine(Offset(-40, gy + d), Offset(w + 40, gy + d), _p);
    }
    _p.style = PaintingStyle.fill;
    // doormat
    _pen.fillPath(
      Path()
        ..moveTo(318 - cx, gy + 3)
        ..lineTo(382 - cx, gy + 3)
        ..lineTo(392 - cx, gy + 15)
        ..lineTo(308 - cx, gy + 15)
        ..close(),
      _hex(0x6a4a2c),
    );
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = _hex(0xe5c896, 0.35);
    c.drawLine(Offset(321 - cx, gy + 5.5), Offset(379 - cx, gy + 5.5), _p);
    c.drawLine(Offset(316 - cx, gy + 9), Offset(384 - cx, gy + 9), _p);
    _p.style = PaintingStyle.fill;
    // lantern light on the floor
    c.save();
    c.translate(350 - cx, gy + 8);
    c.scale(1, 0.14);
    _p
      ..blendMode = BlendMode.plus
      ..shader = Gradient.radial(
        Offset.zero,
        140,
        [_hex(0xffbe6e, 0.2 * doorGlow), _hex(0xffbe6e, 0)],
        const [0, 1],
      );
    c.drawRect(const Rect.fromLTRB(-140, -408, 140, 392), _p);
    c.restore();
    _p
      ..shader = null
      ..blendMode = BlendMode.srcOver;
    // dust motes drifting in the warm light
    for (final m in _motes) {
      final x = (m.x + math.sin(t * 0.3 + m.p) * 14 + t * 2 * (m.v / 10)) % 460;
      final y = (m.y - t * m.v * 0.4 + 2000) % gy;
      final near = math.max(0.0, 1 - (x - 350).abs() / 190);
      final a = (0.12 + 0.34 * near) * (0.6 + 0.4 * math.sin(t * 1.7 + m.p));
      _p.color = _hex(0xFFE3B0, a.clamp(0.0, 1.0));
      c.drawCircle(Offset(x - cx, y), m.s, _p);
    }
    // fog weather: drifting mist banks low over the porch
    if (haze > 0) {
      _p.color = Color.fromRGBO(196, 208, 222, 0.10 * haze);
      c.drawRect(Rect.fromLTRB(-40, -40, w + 40, gy + 1), _p);
      for (var i = 0; i < 4; i++) {
        final bx = ((i * 130 + t * (7 + i * 3)) % (w + 360)) - 180;
        final by = gy - 18 - i * 22;
        _p.color = Color.fromRGBO(214, 224, 235, 0.12 * haze);
        c.drawOval(
          Rect.fromCenter(
            center: Offset(bx, by),
            width: 320,
            height: 34 + i * 6,
          ),
          _p,
        );
      }
    }
  }

  void drawVignette(Canvas c) =>
      c.drawRect(Rect.fromLTWH(0, 0, w, h), _vignette);
}

class _Mote {
  _Mote(this.x, this.y, this.s, this.p, this.v);
  final double x, y, s, p, v;
}
