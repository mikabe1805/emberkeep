// The weekend door: how the Quests room and its board invite you into the
// fight.
//
// On Saturday and Sunday the door is lit: "Join the fight!" with the week's
// monster at it. After the weekend's win it reads "Fight again" and says the
// next one is practice. During the week the Doorway only mentions what is
// coming, quietly: "This weekend: the Fog · weak to Intellect".
library;

import 'package:flutter/material.dart';

import '../../audio.dart' show InteractionSound, MaterialSound;
import '../../clock.dart';
import '../../engine.dart';
import '../../tokens.dart';
import '../../widgets/pressable.dart';
import '../brawl_loot.dart';
import '../weekly_training.dart';
import 'brawl_setup.dart';

/// "The Couch Troll is at the door".
String brawlDoorLine(WeeklyMonster monster) =>
    '${brawlMonsterOf(monster).def.the} is at the door';

/// The lit band for the weekend: tapping it opens the fight.
class BrawlDoorBand extends StatefulWidget {
  const BrawlDoorBand({
    super.key,
    required this.state,
    required this.onOpen,
    this.now,
    this.reduceMotion = false,
  });

  final GameState state;
  final VoidCallback onOpen;

  /// The moment to read (the app passes nothing and gets [Clock.now]).
  final DateTime? now;
  final bool reduceMotion;

  @override
  State<BrawlDoorBand> createState() => _BrawlDoorBandState();
}

class _BrawlDoorBandState extends State<BrawlDoorBand>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  @override
  void initState() {
    super.initState();
    if (!widget.reduceMotion) _glow.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(BrawlDoorBand old) {
    super.didUpdateWidget(old);
    if (widget.reduceMotion) {
      _glow.stop();
    } else if (!_glow.isAnimating) {
      _glow.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final now = widget.now ?? Clock.now();
        if (!brawlDoorOpen(now)) return const SizedBox.shrink();
        final monster = monsterOfTheWeek(now);
        final won = widget.state.brawlWonThisWeek(now);
        // At large text the door keeps to its title, so it stays a small
        // thing under the HUD; the words below it are still spoken.
        final compact = MediaQuery.textScalerOf(context).scale(1) > 1.3;
        final title = won ? 'Fight again' : 'Join the fight!';
        final sub = won
            ? 'Just for practice. This weekend’s chest is already yours.'
            : brawlDoorLine(monster);
        return Pressable(
          key: const Key('brawl-door'),
          pressDepth: 1,
          edgeColor: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          material: MaterialSound.brass,
          interactionSound: InteractionSound.select,
          semanticLabel: '$title. $sub',
          semanticHint: 'Opens the weekend fight',
          onTapUp: (_) => widget.onOpen(),
          child: AnimatedBuilder(
            animation: _glow,
            builder: (context, child) {
              final k = widget.reduceMotion ? 0.5 : _glow.value;
              return DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xF2573A22), Color(0xF22A1B12)],
                  ),
                  border: Border.all(
                    color: Palette.xp.withValues(alpha: 0.55 + 0.25 * k),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(
                        0xFFFFB45A,
                      ).withValues(alpha: 0.16 + 0.14 * k),
                      blurRadius: 14 + 8 * k,
                    ),
                  ],
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: RadialGradient(
                      center: const Alignment(-0.88, 0.1),
                      radius: 0.75,
                      colors: [
                        const Color(
                          0xFFFFB45A,
                        ).withValues(alpha: 0.30 + 0.12 * k),
                        const Color(0x00FFB45A),
                      ],
                    ),
                  ),
                  child: child,
                ),
              );
            },
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 64),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
                child: Row(
                  children: [
                    const ExcludeSemantics(
                      child: SizedBox(
                        width: 36,
                        height: 44,
                        child: CustomPaint(painter: _DoorGlyph()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ExcludeSemantics(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              key: const Key('brawl-door-title'),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'EBGaramond',
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                height: 1.05,
                                color: Palette.textHi,
                              ),
                            ),
                            if (!compact) ...[
                              const SizedBox(height: 2),
                              Text(
                                sub,
                                key: const Key('brawl-door-sub'),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'EBGaramond',
                                  fontSize: 15.5,
                                  fontStyle: FontStyle.italic,
                                  fontWeight: FontWeight.w500,
                                  height: 1.15,
                                  color: Palette.textMid,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const ExcludeSemantics(
                      child: Icon(
                        Icons.chevron_right_rounded,
                        size: 26,
                        color: Palette.xpLight,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A doorway with light spilling out of it.
class _DoorGlyph extends CustomPainter {
  const _DoorGlyph();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final frame = RRect.fromRectAndCorners(
      Rect.fromLTWH(3, 3, w - 6, h - 3),
      topLeft: const Radius.circular(14),
      topRight: const Radius.circular(14),
    );
    canvas.drawRRect(frame, Paint()..color = const Color(0xFF2A170D));
    final inner = RRect.fromRectAndCorners(
      Rect.fromLTWH(6, 6, w - 12, h - 6),
      topLeft: const Radius.circular(11),
      topRight: const Radius.circular(11),
    );
    canvas.drawRRect(
      inner,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFDCA0), Color(0xFFF3B068), Color(0xFFD98A4A)],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );
    canvas.drawPath(
      Path()
        ..moveTo(6, 8)
        ..lineTo(14, 11)
        ..lineTo(14, h - 2)
        ..lineTo(6, h)
        ..close(),
      Paint()..color = const Color(0xFF6A3F27),
    );
    canvas.drawCircle(
      Offset(w / 2 + 3, h * 0.62),
      2,
      Paint()..color = const Color(0xFFFFF1C8),
    );
  }

  @override
  bool shouldRepaint(_DoorGlyph old) => false;
}

/// The quiet line that says what is coming at the weekend, shown on the
/// Doorway during the week.
class BrawlWeekendPreview extends StatelessWidget {
  const BrawlWeekendPreview({super.key, this.now});

  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final line = weekendPreviewLine(now ?? Clock.now());
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          const ExcludeSemantics(
            child: Icon(
              Icons.door_front_door_outlined,
              size: 15,
              color: Palette.textLo,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              line,
              key: const Key('brawl-preview'),
              style: const TextStyle(
                fontFamily: 'EBGaramond',
                fontSize: 15,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w500,
                height: 1.15,
                color: Palette.textLo,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
