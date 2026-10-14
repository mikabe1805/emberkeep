// Small pieces the versus and victory screens share: the dark backdrop, a pane
// of warm glass, the little caps label, and the animated portraits.
library;

import 'dart:math' as math;
import 'dart:ui' as ui show Gradient;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../tokens.dart';
import '../core/brawl_core.dart';
import 'brawl_art.dart';

/// The page behind the versus and victory screens: warm espresso falling to
/// near black, with a low glow where the stage's door would be.
class BrawlBackdrop extends StatelessWidget {
  const BrawlBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF2B1B14), Color(0xFF1B100B), Color(0xFF130B07)],
        stops: [0, 0.45, 1],
      ),
    ),
    child: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.75),
          radius: 0.9,
          colors: [Color(0x33FFB46E), Color(0x00FFB46E)],
        ),
      ),
      child: child,
    ),
  );
}

/// One pane of warm glass: a dark brown tint, a brass hairline, a little light
/// along the top. [hot] lights a pane that carries this week's training.
class BrawlGlassCard extends StatelessWidget {
  const BrawlGlassCard({
    super.key,
    required this.child,
    this.hot = false,
    this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 14),
    this.radius = 18,
  });

  final Widget child;
  final bool hot;
  final EdgeInsets padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final edge = hot
        ? const Color(0xFFE0A865).withValues(alpha: 0.62)
        : const Color(0xFFE5C896).withValues(alpha: 0.2);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: edge, width: hot ? 1.2 : 1),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: hot
              ? const [Color(0xE64A3220), Color(0xF028190F)]
              : const [Color(0xDD3A281C), Color(0xEE20150F)],
        ),
        boxShadow: hot
            ? [
                BoxShadow(
                  color: const Color(0xFFE0A865).withValues(alpha: 0.16),
                  blurRadius: 14,
                ),
              ]
            : null,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// A small mono caps label ("YOUR STATS").
class BrawlCaps extends StatelessWidget {
  const BrawlCaps(this.text, {super.key, this.color, this.header = true});

  final String text;
  final Color? color;
  final bool header;

  @override
  Widget build(BuildContext context) => Semantics(
    header: header,
    child: Text(
      text,
      style: Type.label.copyWith(
        fontSize: Type.minLabel,
        letterSpacing: 2.2,
        color: color ?? const Color(0xFFE5C896),
      ),
    ),
  );
}

/// The serif the fight's words use (EB Garamond, as the Doorway does).
TextStyle brawlSerif(
  double size, {
  FontWeight weight = FontWeight.w600,
  Color color = Palette.textHi,
  bool italic = false,
  double height = 1.1,
}) => TextStyle(
  fontFamily: 'EBGaramond',
  fontSize: size,
  fontWeight: weight,
  fontStyle: italic ? FontStyle.italic : FontStyle.normal,
  color: color,
  height: height,
);

// ------------------------------------------------------------------ portraits

enum BrawlPortraitKind { fighter, troll, fog }

/// A rig, idling, in a small window. Ticks about 30 times a second unless
/// Reduce Motion asks it to hold still.
class BrawlPortrait extends StatefulWidget {
  const BrawlPortrait({
    super.key,
    required this.kind,
    required this.rank,
    this.reduceMotion = false,
    this.height = 236,
  });

  final BrawlPortraitKind kind;

  /// 0 to 3: the monster's grandeur (a crown at the top rank).
  final int rank;
  final bool reduceMotion;
  final double height;

  @override
  State<BrawlPortrait> createState() => _BrawlPortraitState();
}

class _BrawlPortraitState extends State<BrawlPortrait>
    with SingleTickerProviderStateMixin {
  final ValueNotifier<double> _time = ValueNotifier(0.7);
  late final Ticker _ticker;
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      if ((elapsed - _last).inMilliseconds < 33) return;
      _last = elapsed;
      _time.value = 0.7 + elapsed.inMicroseconds / 1e6;
    });
    if (!widget.reduceMotion) _ticker.start();
  }

  @override
  void didUpdateWidget(BrawlPortrait old) {
    super.didUpdateWidget(old);
    if (widget.reduceMotion && _ticker.isActive) {
      _ticker.stop();
    } else if (!widget.reduceMotion && !_ticker.isActive) {
      _ticker.start();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: RepaintBoundary(
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: CustomPaint(
          painter: _PortraitPainter(
            time: _time,
            kind: widget.kind,
            rank: widget.rank,
          ),
        ),
      ),
    ),
  );
}

class _PortraitPainter extends CustomPainter {
  _PortraitPainter({required this.time, required this.kind, required this.rank})
    : super(repaint: time) {
    actor = switch (kind) {
      BrawlPortraitKind.fighter => RigActor(
        rigFighter,
        'fighter',
        kFighterPalette,
      ),
      BrawlPortraitKind.troll => RigActor(rigTroll, 'troll', kTrollPalette),
      BrawlPortraitKind.fog => RigActor(rigFog, 'fog', kFogPalette),
    };
  }

  final ValueListenable<double> time;
  final BrawlPortraitKind kind;
  final int rank;
  late final RigActor actor;
  final BrawlPen _pen = BrawlPen();

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value, w = size.width, h = size.height;
    final warm = switch (kind) {
      BrawlPortraitKind.fog => const Color.fromRGBO(190, 210, 230, 0.28),
      BrawlPortraitKind.troll => const Color.fromRGBO(255, 170, 110, 0.24),
      BrawlPortraitKind.fighter => const Color.fromRGBO(255, 196, 120, 0.26),
    };
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(w * 0.5, h * 0.42),
          h * 0.8,
          [warm, warm.withValues(alpha: 0)],
          const [0, 1],
          TileMode.clamp,
          null,
          Offset(w * 0.5, h * 0.46),
          6,
        ),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w / 2, h - 44),
        width: w * 0.76,
        height: 18,
      ),
      Paint()..color = const Color.fromRGBO(10, 5, 2, 0.38),
    );
    final g = _pen..cv = canvas;
    final o = actor.o;
    switch (kind) {
      case BrawlPortraitKind.fighter:
        o
          ..face = 'normal'
          ..blink = (t % 3.4) > 3.28 ? 1 : 0;
        actor.update('idle', t);
        actor.draw(g, w * 0.55, h - 78, 2.0, 1);
      case BrawlPortraitKind.troll:
        final sc = 0.8 * (0.94 + 0.04 * rank) * 1.0;
        o
          ..flash = 0
          ..lid =
              0.55 + 0.4 * math.pow(math.max(0.0, math.sin(t * 0.9 - 1.2)), 6)
          ..bubble = 0.3 + 0.3 * math.sin(t * 1.3)
          ..cover = 0
          ..mouthO = 0
          ..brow = 0;
        actor.update('idle', t);
        actor.draw(g, w * 0.5, h - 78, sc, 1);
        if (rank >= 3) _crown(canvas, w * 0.5, h - 78 - 138 * sc - 6);
      case BrawlPortraitKind.fog:
        final sc = 1.12 * (0.94 + 0.04 * rank) * 1.0;
        o
          ..flash = 0
          ..rain = 0
          ..lid = 0
          ..lookX = 0.6
          ..lookY = 0.1
          ..mouth = 0.5;
        actor.update('idle', t);
        actor.draw(g, w * 0.5, h - 78, sc, 1);
        if (rank >= 3) _crown(canvas, w * 0.5, h - 78 - 130 * sc - 6);
    }
  }

  void _crown(Canvas c, double x, double y) {
    c.save();
    c.translate(x, y);
    c.drawPath(
      Path()
        ..moveTo(-14, 0)
        ..lineTo(-14, -12)
        ..lineTo(-7, -5)
        ..lineTo(0, -14)
        ..lineTo(7, -5)
        ..lineTo(14, -12)
        ..lineTo(14, 0)
        ..close(),
      Paint()..color = const Color(0xFFE5C896),
    );
    c.restore();
  }

  @override
  bool shouldRepaint(_PortraitPainter old) =>
      old.kind != kind || old.rank != rank;
}

/// A level and a monster's rank as the card reads them.
String brawlRankLine(BrawlMonster monster, int level) =>
    'LV $level / ${brawlMonsterTitle(monster, level).toUpperCase()}';
