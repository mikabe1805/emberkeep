import 'package:flutter/material.dart';

import '../content/quest_desk_styles.dart';
import '../tokens.dart';
import 'facets.dart';

/// The Quest page's full-sized view of permanent progress.
///
/// The approved tapestry remains the artwork. The muted full scene is always
/// visible as the future pattern; the completed cloth is revealed from the
/// bottom as levels are earned. A quest completion can relight the frontier,
/// but only a level changes how much is permanently woven.
class QuestTapestryPanel extends StatelessWidget {
  const QuestTapestryPanel({
    super.key,
    required this.level,
    required this.generation,
    required this.look,
    this.reduceMotion = false,
    this.height = 104,
  });

  final int level;
  final int generation;
  final QuestDeskLook look;
  final bool reduceMotion;
  final double height;

  @override
  Widget build(BuildContext context) {
    final woven = ((level + 2) / 36).clamp(0.12, 1.0);
    final still = reduceMotion || MediaQuery.disableAnimationsOf(context);
    return Semantics(
      container: true,
      excludeSemantics: true,
      label:
          'The Woven Dawn, ${(woven * 100).round()} percent permanently woven',
      child: TweenAnimationBuilder<double>(
        key: ValueKey('tapestry-frontier-$generation'),
        tween: Tween(begin: 0, end: 1),
        duration: still ? Duration.zero : const Duration(milliseconds: 760),
        curve: Curves.easeOutCubic,
        builder: (context, arrival, _) => ClipPath(
          clipper: const FacetedClipper(cut: 10),
          child: SizedBox(
            height: height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const _TapestryScene(muted: true),
                ClipRect(
                  clipper: _VerticalProgressClipper(woven, bottomInset: 30),
                  child: const _TapestryScene(),
                ),
                CustomPaint(
                  painter: _TapestryFrontierPainter(
                    woven: woven,
                    arrival: arrival,
                    brass: look.brass,
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    height: 30,
                    padding: const EdgeInsets.symmetric(horizontal: 9),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0x00120A14),
                          const Color(0xF0140B15),
                        ],
                      ),
                      border: Border(
                        top: BorderSide(
                          color: look.brass.withValues(alpha: 0.30),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          'THE WOVEN DAWN',
                          style: Type.label.copyWith(
                            fontSize: Type.minLabel,
                            color: Palette.textHi,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Spacer(),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              'PERMANENT · ${(woven * 100).round()}% WOVEN',
                              maxLines: 1,
                              style: Type.label.copyWith(
                                fontSize: Type.minLabel,
                                color: look.brass,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TapestryScene extends StatelessWidget {
  const _TapestryScene({this.muted = false});

  final bool muted;

  @override
  Widget build(BuildContext context) {
    final art = Image.asset(
      'assets/brand/morrow-tapestry-wide-v2.webp',
      fit: BoxFit.cover,
      alignment: Alignment.center,
      filterQuality: FilterQuality.high,
      excludeFromSemantics: true,
    );
    if (!muted) return art;
    return ColorFiltered(
      colorFilter: const ColorFilter.mode(
        Color(0xFF675A70),
        BlendMode.modulate,
      ),
      child: Opacity(opacity: 0.72, child: art),
    );
  }
}

class _VerticalProgressClipper extends CustomClipper<Rect> {
  const _VerticalProgressClipper(this.progress, {this.bottomInset = 0});

  final double progress;
  final double bottomInset;

  @override
  Rect getClip(Size size) {
    final clothHeight = (size.height - bottomInset).clamp(0.0, size.height);
    final height = clothHeight * progress.clamp(0.0, 1.0);
    return Rect.fromLTWH(0, clothHeight - height, size.width, height);
  }

  @override
  bool shouldReclip(_VerticalProgressClipper oldClipper) =>
      oldClipper.progress != progress || oldClipper.bottomInset != bottomInset;
}

class _TapestryFrontierPainter extends CustomPainter {
  const _TapestryFrontierPainter({
    required this.woven,
    required this.arrival,
    required this.brass,
  });

  final double woven;
  final double arrival;
  final Color brass;

  @override
  void paint(Canvas canvas, Size size) {
    final y = (size.height - 30) * (1 - woven);
    final glow = (1 - arrival).clamp(0.0, 1.0);
    final path = Path()..moveTo(0, y);
    for (var x = 0.0; x < size.width; x += 12) {
      path.lineTo(x + 6, y + 1.4);
      path.lineTo(x + 12, y - 1.1);
    }
    if (glow > 0) {
      canvas.drawPath(
        path,
        Paint()
          ..color = brass.withValues(alpha: 0.30 * glow)
          ..strokeWidth = 7
          ..style = PaintingStyle.stroke
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = brass.withValues(alpha: 0.54 + 0.42 * glow)
        ..strokeWidth = 1.25
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_TapestryFrontierPainter old) =>
      old.woven != woven || old.arrival != arrival || old.brass != brass;
}

/// The completion's connective tissue: XP leaves the checked quest and lands
/// on the live XP rail. This is intentionally one authored gesture rather
/// than a second confetti system.
class QuestCompletionStitch extends StatefulWidget {
  const QuestCompletionStitch({
    super.key,
    required this.origin,
    required this.destination,
    required this.xp,
    required this.statColor,
    required this.onDone,
    this.reduceMotion = false,
  });

  final Offset origin;
  final Offset destination;
  final int xp;
  final Color statColor;
  final VoidCallback onDone;
  final bool reduceMotion;

  @override
  State<QuestCompletionStitch> createState() => _QuestCompletionStitchState();
}

class _QuestCompletionStitchState extends State<QuestCompletionStitch>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(
        vsync: this,
        duration: widget.reduceMotion
            ? const Duration(milliseconds: 240)
            : const Duration(milliseconds: 880),
      )..addStatusListener((status) {
        if (status == AnimationStatus.completed) widget.onDone();
      });

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          key: const ValueKey('quest-completion-stitch'),
          painter: _CompletionStitchPainter(
            progress: _controller.value,
            origin: widget.origin,
            destination: widget.destination,
            xp: widget.xp,
            statColor: widget.statColor,
            reduceMotion: widget.reduceMotion,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    ),
  );
}

class _CompletionStitchPainter extends CustomPainter {
  const _CompletionStitchPainter({
    required this.progress,
    required this.origin,
    required this.destination,
    required this.xp,
    required this.statColor,
    required this.reduceMotion,
  });

  final double progress;
  final Offset origin;
  final Offset destination;
  final int xp;
  final Color statColor;
  final bool reduceMotion;

  @override
  void paint(Canvas canvas, Size size) {
    final from = Offset(
      origin.dx.clamp(18.0, size.width - 18),
      origin.dy.clamp(18.0, size.height - 18),
    );
    final to = Offset(
      destination.dx.clamp(24.0, size.width - 24),
      destination.dy.clamp(54.0, size.height - 70),
    );
    final path = Path()
      ..moveTo(from.dx, from.dy)
      ..cubicTo(
        from.dx + (to.dx - from.dx) * 0.34,
        from.dy - 168,
        to.dx - (to.dx - from.dx) * 0.26,
        to.dy + 154,
        to.dx,
        to.dy,
      );
    final metric = path.computeMetrics().first;
    final travel = reduceMotion
        ? 1.0
        : Curves.easeInOutCubic.transform(progress.clamp(0.0, 1.0));
    final partial = metric.extractPath(0, metric.length * travel);
    final glowPaint = Paint()
      ..color = Palette.xpLight.withValues(alpha: 0.22 * (1 - progress))
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    final threadPaint = Paint()
      ..shader = LinearGradient(
        colors: [statColor, Palette.xpLight, Palette.xp],
        // The thread leaves in the domain's colour and becomes XP on the way —
        // but on an even split half the wire was the domain hue, and for MIND
        // or CRAFT that is a long cold line drawn across a warm board. Turn it
        // honey early: the domain reads at the tail, the flight reads as gold.
        stops: const [0.0, 0.22, 1.0],
      ).createShader(Rect.fromPoints(from, to))
      ..strokeWidth = 1.55
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(partial, glowPaint);
    canvas.drawPath(partial, threadPaint);

    final head = metric.getTangentForOffset(metric.length * travel)?.position;
    if (head != null && progress < 0.94) {
      canvas.drawCircle(
        head,
        2.4 + 2.0 * (1 - progress),
        Paint()
          ..color = Palette.xpLight
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }

    if (!reduceMotion && progress < 0.48) {
      final ripple = Curves.easeOut.transform((progress / 0.48).clamp(0, 1));
      for (var i = 0; i < 3; i++) {
        final delayed = (ripple - i * 0.12).clamp(0.0, 1.0);
        if (delayed <= 0) continue;
        canvas.drawCircle(
          from,
          21 + delayed * (23 + i * 6),
          Paint()
            ..color = statColor.withValues(alpha: 0.22 * (1 - delayed))
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2,
        );
      }
    }

    final labelAlpha = progress < 0.16
        ? (progress / 0.16).clamp(0.0, 1.0)
        : progress > 0.72
        ? ((1 - progress) / 0.28).clamp(0.0, 1.0)
        : 1.0;
    final labelAnchor = Offset(
      (from.dx + 145).clamp(70.0, size.width - 70),
      from.dy - 45,
    );
    final text = TextPainter(
      text: TextSpan(
        text: '+$xp XP',
        style: Type.numerals.copyWith(
          fontSize: 17,
          color: Palette.xpLight.withValues(alpha: labelAlpha),
          shadows: const [Shadow(color: Palette.warmShadow, blurRadius: 8)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(
      canvas,
      labelAnchor.translate(-text.width / 2, -text.height - 9),
    );

    if (progress > 0.72) {
      final settle = ((progress - 0.72) / 0.28).clamp(0.0, 1.0);
      final arrival = Paint()
        ..color = Palette.xpLight.withValues(alpha: 1 - settle)
        ..strokeWidth = 1.3
        ..strokeCap = StrokeCap.round;
      final radius = 3 + settle * 5;
      final diamond = Path()
        ..moveTo(to.dx, to.dy - radius)
        ..lineTo(to.dx + radius, to.dy)
        ..lineTo(to.dx, to.dy + radius)
        ..lineTo(to.dx - radius, to.dy)
        ..close();
      canvas.drawPath(diamond, arrival..style = PaintingStyle.stroke);
      canvas.drawCircle(
        to,
        1.6 + settle * 1.2,
        Paint()..color = Palette.xpLight.withValues(alpha: 1 - settle),
      );
    }
  }

  @override
  bool shouldRepaint(_CompletionStitchPainter old) =>
      old.progress != progress ||
      old.origin != origin ||
      old.destination != destination ||
      old.xp != xp ||
      old.statColor != statColor ||
      old.reduceMotion != reduceMotion;
}

/// The Quests HUD's XP rail. Its woven texture is a quiet brand material, not
/// a second progression metaphor: the number and semantics remain plain XP.
class WovenXpBar extends StatelessWidget {
  const WovenXpBar({
    super.key,
    required this.progress,
    required this.generation,
    required this.look,
    this.reduceMotion = false,
    this.height = 16,
  });

  final double progress;
  final int generation;
  final QuestDeskLook look;
  final bool reduceMotion;
  final double height;

  @override
  Widget build(BuildContext context) {
    final still = reduceMotion || MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label:
          '${(progress.clamp(0.0, 1.0) * 100).round()} percent to next level',
      child: TweenAnimationBuilder<double>(
        key: ValueKey(generation),
        tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
        duration: still ? Duration.zero : Motion.barFill,
        curve: Motion.barCurve,
        builder: (context, value, _) => Row(
          children: [
            _Diamond(color: look.brass, size: height * 1.20),
            Expanded(
              child: ClipPath(
                clipper: FacetedClipper(cut: height * 0.36),
                child: SizedBox(
                  height: height,
                  child: LayoutBuilder(
                    builder: (context, constraints) => Stack(
                      fit: StackFit.expand,
                      children: [
                        _TapestryStrip(
                          tint: Color.lerp(look.future, Colors.white, 0.48)!,
                        ),
                        Positioned.fill(
                          child: ClipRect(
                            clipper: _ProgressClipper(value),
                            child: _TapestryStrip(
                              tint: Color.lerp(look.brass, Colors.white, 0.08)!,
                              luminous: true,
                            ),
                          ),
                        ),
                        CustomPaint(
                          painter: _WeftGridPainter(
                            progress: value,
                            future: look.future,
                            brass: look.brass,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            _Diamond(color: look.brass, size: height * 1.20),
          ],
        ),
      ),
    );
  }
}

class _ProgressClipper extends CustomClipper<Rect> {
  const _ProgressClipper(this.progress);

  final double progress;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width * progress.clamp(0.0, 1.0), size.height);

  @override
  bool shouldReclip(_ProgressClipper oldClipper) =>
      oldClipper.progress != progress;
}

class _TapestryStrip extends StatelessWidget {
  const _TapestryStrip({required this.tint, this.luminous = false});

  final Color tint;
  final bool luminous;

  @override
  Widget build(BuildContext context) => ColorFiltered(
    // The full source remains opaque on both sides of the frontier. A lighter
    // modulate keeps the future legible; screen-lighting turns completed rows
    // into warm brass without replacing their real woven detail.
    colorFilter: ColorFilter.mode(
      tint,
      luminous ? BlendMode.screen : BlendMode.modulate,
    ),
    child: Image.asset(
      'assets/brand/morrow-tapestry-wide-v2.webp',
      fit: BoxFit.cover,
      alignment: const Alignment(0, -0.52),
      filterQuality: FilterQuality.high,
      excludeFromSemantics: true,
    ),
  );
}

class _Diamond extends StatelessWidget {
  const _Diamond({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: Icon(Icons.diamond, color: color, size: size),
  );
}

class _WeftGridPainter extends CustomPainter {
  const _WeftGridPainter({
    required this.progress,
    required this.future,
    required this.brass,
  });

  final double progress;
  final Color future;
  final Color brass;

  @override
  void paint(Canvas canvas, Size size) {
    final row = Paint()
      ..color = Colors.white.withValues(alpha: 0.13)
      ..strokeWidth = 0.7;
    for (var y = 2.0; y < size.height; y += 3.2) {
      canvas.drawLine(Offset.zero.translate(0, y), Offset(size.width, y), row);
    }

    final edgeX = (size.width * progress).clamp(0.0, size.width);
    if (edgeX <= 1 || edgeX >= size.width - 1) return;
    final frontier = Paint()
      ..color = brass.withValues(alpha: 0.92)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (var y = 1.5; y < size.height; y += 4.2) {
      canvas.drawLine(
        Offset(edgeX - 1.8, y),
        Offset(edgeX + 1.8, y + 1.4),
        frontier,
      );
    }
  }

  @override
  bool shouldRepaint(_WeftGridPainter old) =>
      old.progress != progress || old.future != future || old.brass != brass;
}

/// A structural strip used on the Quests HUD. Level progress rises from the
/// bottom while the complete future pattern remains visible above it.
class QuestDeskSelvedge extends StatelessWidget {
  const QuestDeskSelvedge({
    super.key,
    required this.level,
    required this.look,
    this.width = 8,
  });

  final int level;
  final QuestDeskLook look;
  final double width;

  @override
  Widget build(BuildContext context) {
    final woven = ((level + 2) / 36).clamp(0.12, 1.0);
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          _VerticalTapestry(tint: look.future),
          Align(
            alignment: Alignment.bottomCenter,
            heightFactor: woven,
            child: FractionallySizedBox(
              heightFactor: woven,
              alignment: Alignment.bottomCenter,
              child: _VerticalTapestry(tint: look.textile),
            ),
          ),
          Center(
            child: Container(
              width: 1,
              color: look.brass.withValues(alpha: 0.52),
            ),
          ),
        ],
      ),
    );
  }
}

class _VerticalTapestry extends StatelessWidget {
  const _VerticalTapestry({required this.tint});

  final Color tint;

  @override
  Widget build(BuildContext context) => ColorFiltered(
    colorFilter: ColorFilter.mode(tint, BlendMode.modulate),
    child: Image.asset(
      'assets/brand/morrowloom-icon-runtime-v2.webp',
      fit: BoxFit.cover,
      alignment: Alignment.center,
      filterQuality: FilterQuality.high,
      excludeFromSemantics: true,
    ),
  );
}

/// Compact steady-state affordance for choosing an owned Quest Desk look.
class QuestDeskStyleButton extends StatelessWidget {
  const QuestDeskStyleButton({
    super.key,
    required this.look,
    required this.onTap,
    this.compact = false,
  });

  final QuestDeskLook look;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final content = compact
        ? SizedBox.square(
            dimension: 54,
            child: DecoratedBox(
              decoration: facetedDecoration(
                cut: 10,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.lerp(const Color(0xFF3A2A1C), look.wood, 0.16)!,
                    const Color(0xFF17110E),
                  ],
                ),
                borderColor: look.brass.withValues(alpha: 0.58),
                borderWidth: 1.1,
              ),
              child: Center(
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: look.brass,
                  size: 26,
                ),
              ),
            ),
          )
        : Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: facetedDecoration(
              cut: 7,
              color: Color.lerp(const Color(0xD9241A15), look.wood, 0.20),
              borderColor: look.brass.withValues(alpha: 0.40),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipPath(
                  clipper: const FacetedClipper(cut: 4),
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [look.textile, look.wood],
                      ),
                      border: Border.all(
                        color: look.brass.withValues(alpha: 0.70),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    look.name.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Type.label.copyWith(
                      fontSize: Type.minLabel,
                      color: Palette.textHi,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right,
                  size: 15,
                  color: Palette.textLo,
                ),
              ],
            ),
          );
    return Semantics(
      button: true,
      label: 'Quest Desk style, ${look.name}',
      child: Tooltip(
        message: 'Quest Desk · ${look.name}',
        child: InkWell(
          customBorder: FacetedBorder(cut: compact ? 10 : 7),
          onTap: onTap,
          child: content,
        ),
      ),
    );
  }
}
