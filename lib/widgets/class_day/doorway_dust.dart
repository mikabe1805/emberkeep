// Dust in the light: a few dozen slow motes living inside the sunbeams (or,
// at dusk, drifting near the wall lantern). They are born inside a shaft, fade
// in, wander, and fade out; where the shaft's light is brightest they show.
// They never leave the beam and never look like confetti.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'doorway_art.dart';
import 'doorway_light.dart';

class _Mote {
  double x = -50;
  double y = -50;
  double vx = 0;
  double vy = 0;
  double r = 1;
  double a = 0;
  double base = 1;
  int beam = 0;
  double age = 0;
  double life = 0;
  double phase = 0;
}

class DoorwayDust {
  DoorwayDust({int? seed}) : _random = math.Random(seed ?? 20261010) {
    for (final m in _motes) {
      m.phase = _random.nextDouble() * 6;
    }
    for (final m in _lamp) {
      m.phase = _random.nextDouble() * 6;
    }
  }

  static const beamMotes = 54;
  static const lampMotes = 10;

  final math.Random _random;
  final List<_Mote> _motes = List.generate(beamMotes, (_) => _Mote());
  final List<_Mote> _lamp = List.generate(lampMotes, (_) => _Mote());

  /// The lit air of the midday and the golden beam (null until decoded).
  final List<DoorwayBeamMask?> masks = [null, null];

  double _rand(double a, double b) => a + _random.nextDouble() * (b - a);

  void _spawn(_Mote m, DoorwayLights w) {
    final total = w.sun;
    final k = _random.nextDouble() < w.golden / (total == 0 ? 1 : total)
        ? 1
        : 0;
    final births = masks[k]?.births ?? const <Offset>[];
    if (births.isEmpty) {
      m.life = 0;
      return;
    }
    final c = births[_random.nextInt(births.length)];
    m
      ..x = c.dx + _rand(-2, 2)
      ..y = c.dy + _rand(-2, 2)
      ..beam = k
      ..vx = _rand(-2.2, 1.2)
      ..vy = _rand(-3, -0.3)
      ..r = _rand(0.55, 1.5)
      ..base = _rand(0.45, 1)
      ..a = 0
      ..age = 0
      ..life = _rand(9000, 22000)
      ..phase = _random.nextDouble() * 6;
  }

  void _spawnLamp(_Mote m) {
    final an = _rand(0, 6.28);
    final rr = _rand(8, 62);
    m
      ..x = doorwayLantern.dx + math.cos(an) * rr * 0.9
      ..y = doorwayLantern.dy + math.sin(an) * rr * 1.1
      ..vx = _rand(-1.5, 1.5)
      ..vy = _rand(-2.5, -0.4)
      ..r = _rand(0.5, 1.1)
      ..base = _rand(0.3, 0.8)
      ..a = 0
      ..age = 0
      ..life = _rand(8000, 16000)
      ..phase = _random.nextDouble() * 6;
  }

  /// Moves the motes by [dtMs] milliseconds. [gust] (0 to 1) pushes them along
  /// the beam for a breath; [beamK] is the beam's brightness now.
  void step(double dtMs, DoorwayLights w, double beamK, {double gust = 0}) {
    final ds = dtMs / 1000;
    final active = (beamMotes * math.min(1.0, w.sun)).round();
    for (var i = 0; i < _motes.length; i++) {
      final m = _motes[i];
      if (i >= active) {
        m.a *= 0.9;
        if (m.a < 0.01) continue;
      } else if (m.life <= 0 || m.age > m.life) {
        _spawn(m, w);
        if (m.life <= 0) continue;
      }
      m.age += dtMs;
      m.phase += ds * 0.6;
      m.x += (m.vx + math.sin(m.phase * 1.3) * 1.2 + gust * 0.94 * 34) * ds;
      m.y += (m.vy + math.cos(m.phase) * 0.9 + gust * 0.34 * 34) * ds;
      final lit =
          math.max(
            (masks[0]?.at(m.x, m.y) ?? 0) * w.midday,
            (masks[1]?.at(m.x, m.y) ?? 0) * w.golden,
          ) *
          math.min(1.3, beamK);
      var target =
          (i < active ? ((lit - 0.12) / 0.4).clamp(0.0, 1.0) : 0.0) * m.base;
      final fadeEnd = ((m.life - m.age) / 1500).clamp(0.0, 1.0);
      final fadeIn = (m.age / 1200).clamp(0.0, 1.0);
      target *= fadeEnd * fadeIn;
      m.a += (target - m.a) * math.min(1.0, dtMs / 260);
      if (target == 0 && m.a < 0.02 && m.age > 1500) m.age = m.life + 1;
    }
    final near = (lampMotes * w.evening).round();
    for (var i = 0; i < _lamp.length; i++) {
      final m = _lamp[i];
      if (i >= near) {
        m.a *= 0.9;
        if (m.a < 0.01) continue;
      } else if (m.life <= 0 || m.age > m.life) {
        _spawnLamp(m);
      }
      m.age += dtMs;
      m.phase += ds * 0.5;
      m.x += (m.vx + math.sin(m.phase * 1.2)) * ds;
      m.y += (m.vy + math.cos(m.phase) * 0.8) * ds;
      final target =
          (i < near ? 1.0 : 0.0) *
          m.base *
          (m.age / 1500).clamp(0.0, 1.0) *
          ((m.life - m.age) / 1500).clamp(0.0, 1.0) *
          0.8;
      m.a += (target - m.a) * math.min(1.0, dtMs / 300);
    }
  }

  /// How many motes show now (for tests).
  int get visible =>
      _motes.where((m) => m.a >= 0.012).length +
      _lamp.where((m) => m.a >= 0.012).length;

  void paint(Canvas canvas) {
    void dot(_Mote m, Color color) {
      if (m.a < 0.012) return;
      final alpha = math.min(1.0, m.a * 1.1);
      final center = Offset(m.x, m.y);
      final r = m.r * 2.1;
      // A soft dot: a wide faint halo, a brighter middle, a small warm core.
      for (final (scale, weight) in const [
        (1.0, 0.09),
        (0.55, 0.22),
        (0.26, 0.6),
      ]) {
        canvas.drawCircle(
          center,
          r * scale,
          Paint()..color = color.withValues(alpha: weight * alpha),
        );
      }
    }

    const cream = Color(0xFFFFEECE);
    const amber = Color(0xFFFFCE8A);
    for (final m in _motes) {
      dot(m, cream);
    }
    for (final m in _lamp) {
      dot(m, amber);
    }
  }
}

/// Paints the dust over the wall.
class DoorwayDustPainter extends CustomPainter {
  DoorwayDustPainter({required this.dust, required Listenable repaint})
    : super(repaint: repaint);

  final DoorwayDust dust;

  @override
  void paint(Canvas canvas, Size size) => dust.paint(canvas);

  @override
  bool shouldRepaint(DoorwayDustPainter old) => old.dust != dust;
}
