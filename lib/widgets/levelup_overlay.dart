import 'dart:async';

import 'package:flutter/material.dart';

import '../audio.dart';
import '../haptics.dart';
import '../tokens.dart';
import 'glass.dart';
import 'particles.dart';

/// Full-screen level-up takeover (Habitica's level-up is just a modal — this
/// is the gap we out-execute, DESIGN.md §6): dim, numeral slam, particle
/// storm scaled by significance, unlock reveal, tap to dismiss. Always
/// skippable with a tap.
class LevelUpOverlay extends StatefulWidget {
  const LevelUpOverlay({
    super.key,
    required this.level,
    this.unlock,
    this.nextUnlock,
    required this.onDismiss,
    this.onShare,
    this.reduceMotion = false,
    this.questsSince,
    this.previousLevel,
  });

  final int level;
  final String? unlock;
  final String? nextUnlock;
  final VoidCallback onDismiss;

  /// Quests finished since the last level, when the save knows it. "YOU DID
  /// IT." lands harder when it can point at what the person actually did.
  final int? questsSince;
  final int? previousLevel;

  /// Opens the share-a-moment preview. A level-up is the exact moment someone
  /// wants to show a friend, and this overlay used to dead-end at "onward" —
  /// the app's best beat, with no door out of it.
  final VoidCallback? onShare;
  final bool reduceMotion;

  @override
  State<LevelUpOverlay> createState() => _LevelUpOverlayState();
}

class _LevelUpOverlayState extends State<LevelUpOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  late final Animation<double> _dim = CurvedAnimation(
    parent: _c,
    curve: const Interval(0, 0.15, curve: Curves.easeOut),
  );
  late final Animation<double> _slam = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.1, 0.55, curve: Motion.slam),
  );
  late final Animation<double> _encouragementIn = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.08, 0.48, curve: Motion.slam),
  );
  late final Animation<double> _unlockIn = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.55, 0.8, curve: Curves.easeOutCubic),
  );

  bool _burst = false;
  bool _started = false;
  bool _still = false;
  Timer? _burstTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still =
        widget.reduceMotion || MediaQuery.disableAnimationsOf(context);
    if (_still != still) {
      _still = still;
      if (still) {
        _burstTimer?.cancel();
        _burstTimer = null;
        if (_burst) setState(() => _burst = false);
      }
    }
    if (_started) return;
    _started = true;
    Sfx.instance.play('levelup');
    // the level-up slam — heavy settling into a medium, and softened to a
    // single medium under reduce-motion (Haptics.big honors the setting)
    if (still) {
      Haptics.light();
    } else {
      Haptics.big();
    }
    _c.forward();
    // particle storm fires as the numeral lands
    if (!still) {
      _burstTimer = Timer(const Duration(milliseconds: 380), () {
        if (mounted && !_still) setState(() => _burst = true);
      });
    }
  }

  @override
  void dispose() {
    _burstTimer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final center = Offset(size.width / 2, size.height * 0.40);
    final still =
        widget.reduceMotion || MediaQuery.disableAnimationsOf(context);
    // bigger milestone, bigger storm: every 5th level celebrates harder
    final milestone = widget.level % 5 == 0;

    return OverlaySurface(
      child: Semantics(
        button: true,
        label:
            'Level ${widget.level} reached'
            '${widget.unlock == null ? '' : '. ${widget.unlock} unlocked'}',
        hint: 'Tap to continue',
        onTap: widget.onDismiss,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onDismiss,
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final dim = still ? 1.0 : _dim.value;
              final slam = still ? 1.0 : _slam.value;
              final encouragementIn = still ? 1.0 : _encouragementIn.value;
              final unlockIn = still ? 1.0 : _unlockIn.value;
              return Container(
                // Deep walnut night, lit from the numeral: warm where the
                // level glows, falling to near-black at the edges.
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.2),
                    radius: 1.05,
                    colors: [
                      const Color(0xFF3B2514).withValues(alpha: 0.93 * dim),
                      const Color(0xFF22150B).withValues(alpha: 0.95 * dim),
                      const Color(0xFF110905).withValues(alpha: 0.97 * dim),
                    ],
                    stops: const [0, 0.55, 1],
                  ),
                ),
                child: Stack(
                  children: [
                    if (_burst && !still)
                      ParticleBurst(
                        origin: center,
                        colors: const [
                          Palette.xpLight,
                          Color(0xFFFFF4D9), // cream sparkle
                          Palette.unlock,
                        ],
                        count: milestone ? 90 : 46,
                        vibrancy: milestone ? 1.0 : 0.7,
                        spread: 160,
                        reduce: false,
                      ),
                    LayoutBuilder(
                      builder: (context, constraints) => SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 24,
                        ),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: (constraints.maxHeight - 48).clamp(
                              0,
                              double.infinity,
                            ),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Opacity(
                                  opacity: dim,
                                  child: Text(
                                    'LEVEL UP',
                                    style: Type.label.copyWith(
                                      fontSize: 14,
                                      letterSpacing: 3.2,
                                      color: Palette.xpLight,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Transform.scale(
                                  scale: still
                                      ? 1
                                      : 0.58 + 0.42 * encouragementIn,
                                  child: Opacity(
                                    opacity: encouragementIn.clamp(0.0, 1.0),
                                    child: Text(
                                      'YOU DID IT.',
                                      textAlign: TextAlign.center,
                                      style: Type.display.copyWith(
                                        fontSize: 46,
                                        height: 1.05,
                                        fontWeight: FontWeight.w700,
                                        color: Palette.textHi,
                                        shadows: [
                                          Shadow(
                                            color: Palette.xpLight.withValues(
                                              alpha: 0.6,
                                            ),
                                            blurRadius: still
                                                ? 18
                                                : 30 * encouragementIn,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Transform.scale(
                                  // elasticOut overshoots past 1.0 → the numeral slams in
                                  scale: still ? 1 : 0.4 + 0.6 * slam,
                                  child: Opacity(
                                    opacity: slam.clamp(0.0, 1.0),
                                    child: SizedBox(
                                      width: 190,
                                      height: 170,
                                      child: Stack(
                                        alignment: Alignment.center,
                                        clipBehavior: Clip.none,
                                        children: [
                                          // The numeral is the light source:
                                          // its warmth spills into the room
                                          // around it, so the takeover is not
                                          // one flat sheet.
                                          IgnorePointer(
                                            child: OverflowBox(
                                              maxWidth: 420,
                                              maxHeight: 420,
                                              child: Container(
                                                width: 420,
                                                height: 420,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  gradient: RadialGradient(
                                                    colors: [
                                                      const Color(
                                                        0xFFE0A865,
                                                      ).withValues(
                                                        alpha:
                                                            0.24 *
                                                            slam.clamp(
                                                              0.0,
                                                              1.0,
                                                            ),
                                                      ),
                                                      const Color(
                                                        0xFFB8742F,
                                                      ).withValues(
                                                        alpha:
                                                            0.09 *
                                                            slam.clamp(
                                                              0.0,
                                                              1.0,
                                                            ),
                                                      ),
                                                      const Color(0x00B8742F),
                                                    ],
                                                    stops: const [0, 0.42, 1],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          Transform.rotate(
                                            angle: 0.785,
                                            child: Container(
                                              width: 104,
                                              height: 104,
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                  colors: [
                                                    Palette.xpLight.withValues(
                                                      alpha: 0.16,
                                                    ),
                                                    const Color(0x082E1C0D),
                                                  ],
                                                ),
                                                border: Border.all(
                                                  color: Palette.xpLight
                                                      .withValues(alpha: 0.34),
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Palette.honeyGlow
                                                        .withValues(
                                                          alpha: 0.35,
                                                        ),
                                                    blurRadius: 30,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          Text(
                                            '${widget.level}',
                                            style: Type.numerals.copyWith(
                                              fontSize: 120,
                                              height: 1,
                                              color: Palette.xpLight,
                                              shadows: [
                                                Shadow(
                                                  color: Palette.xpLight
                                                      .withValues(alpha: 0.7),
                                                  blurRadius: still
                                                      ? 24
                                                      : 44 * slam,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                if (widget.questsSince case final count?
                                    when count > 0) ...[
                                  const SizedBox(height: 14),
                                  Opacity(
                                    opacity: unlockIn,
                                    child: Text(
                                      _evidenceLine(count),
                                      textAlign: TextAlign.center,
                                      style: Type.body.copyWith(
                                        fontSize: 15,
                                        height: 1.35,
                                        fontStyle: FontStyle.italic,
                                        color: Palette.textMid,
                                      ),
                                    ),
                                  ),
                                ],
                                if (widget.unlock != null) ...[
                                  const SizedBox(height: 26),
                                  Opacity(
                                    opacity: unlockIn,
                                    child: Transform.translate(
                                      offset: Offset(
                                        0,
                                        still ? 0 : 16 * (1 - unlockIn),
                                      ),
                                      child: Column(
                                        children: [
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              _revealRule(),
                                              const SizedBox(width: 10),
                                              Text(
                                                'UNLOCKED',
                                                style: Type.label.copyWith(
                                                  fontSize: Type.minLabel,
                                                  letterSpacing: 2.4,
                                                  color: Palette.unlock,
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              _revealRule(flip: true),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            widget.unlock!,
                                            textAlign: TextAlign.center,
                                            style: Type.display.copyWith(
                                              fontSize: 24,
                                              color: Palette.textHi,
                                              shadows: [
                                                Shadow(
                                                  color: Palette.unlock
                                                      .withValues(
                                                        alpha: 0.35 * unlockIn,
                                                      ),
                                                  blurRadius: 16,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                                if (widget.nextUnlock != null) ...[
                                  const SizedBox(height: 14),
                                  Opacity(
                                    opacity: unlockIn * 0.8,
                                    child: Text(
                                      'NEXT · ${widget.nextUnlock}',
                                      textAlign: TextAlign.center,
                                      style: Type.label.copyWith(fontSize: 11),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 40),
                                if (widget.onShare != null) ...[
                                  Opacity(
                                    opacity: unlockIn,
                                    child: Semantics(
                                      button: true,
                                      label: 'Share this moment',
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: widget.onShare,
                                        child: Container(
                                          constraints: const BoxConstraints(
                                            minHeight: 44,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 20,
                                            vertical: 12,
                                          ),
                                          child: Wrap(
                                            alignment: WrapAlignment.center,
                                            crossAxisAlignment:
                                                WrapCrossAlignment.center,
                                            children: [
                                              const Icon(
                                                Icons.ios_share,
                                                size: 15,
                                                color: Palette.xpLight,
                                              ),
                                              const SizedBox(width: 7),
                                              Text(
                                                'SHARE THIS MOMENT',
                                                style: Type.label.copyWith(
                                                  fontSize: 11,
                                                  color: Palette.xpLight,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                ],
                                Opacity(
                                  opacity: unlockIn * 0.6,
                                  child: Text(
                                    'onward →',
                                    style: Type.label.copyWith(fontSize: 11),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  String _evidenceLine(int count) {
    final quests = count == 1 ? 'one quest' : '$count quests';
    final previous = widget.previousLevel;
    if (previous == null || previous <= 1) return '$quests since you began';
    return '$quests since level $previous';
  }

  Widget _revealRule({bool flip = false}) => Container(
    width: 28,
    height: 1,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          Palette.unlock.withValues(alpha: flip ? 0.6 : 0),
          Palette.unlock.withValues(alpha: flip ? 0 : 0.6),
        ],
      ),
    ),
  );
}
