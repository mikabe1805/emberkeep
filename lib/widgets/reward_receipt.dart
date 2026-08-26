import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio.dart';
import '../content/cosmetics.dart';
import '../content/creature_skins.dart';
import '../content/evidence.dart';
import '../engine.dart';
import '../haptics.dart';
import '../models.dart';
import '../tokens.dart';
import 'ember_flame_icon.dart';
import 'facets.dart';
import 'glass.dart';
import 'pressable.dart';
import 'quick_reflection_sheet.dart';

/// The "receipt of rewards": a vertical stack of color-coded bubbles popping
/// in one by one near the completed quest — one tap can deliver 2–6 distinct
/// micro-rewards, each with its own color, icon and sound layer
/// (Habitica's best pattern, modernized — DESIGN.md §3).
///
/// The +Stat bubble is tappable when an unread evidence card is waiting
/// (DESIGN.md §5) — tap opens a bite-sized "why this works" card.
class RewardReceipt extends StatefulWidget {
  const RewardReceipt({
    super.key,
    required this.bundle,
    required this.anchor,
    required this.onDone,
    this.state,
    this.onReflect,
  });

  final RewardBundle bundle;

  /// Global position of the completing tap; bubbles rise above it.
  final Offset anchor;
  final VoidCallback onDone;

  /// When set, enables the evidence-card tap on the +Stat bubble.
  final GameState? state;

  /// Saves one optional, day-attached line without forcing a full journal
  /// detour in the middle of the completion reward.
  final ValueChanged<String>? onReflect;

  @override
  State<RewardReceipt> createState() => _RewardReceiptState();
}

class _Bubble {
  _Bubble(
    this.text,
    this.icon,
    this.color,
    this.sound, {
    this.haptic = false,
    this.wide = false,
    this.hero = false,
    this.evidence = false,
  });
  final String text;
  final IconData icon;
  final Color color;
  final String? sound;
  final bool haptic;
  final bool wide;
  final bool hero;
  final bool evidence;
}

class _RewardReceiptState extends State<RewardReceipt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final List<_Bubble> _bubbles;
  final List<Timer> _feedbackTimers = [];
  bool _heldForSheet = false;
  bool _reflectionSaved = false;
  bool _started = false;
  bool _still = false;

  @override
  void initState() {
    super.initState();
    final b = widget.bundle;
    final state = widget.state;
    final projectedXp = state == null ? null : state.xp + b.xp;
    final nextLevel = state == null ? null : state.level + 1;
    final nextLevelCost = nextLevel == null ? null : state!.xpNeeded(nextLevel);
    final levelProgress = projectedXp == null || nextLevelCost == null
        ? null
        : projectedXp >= nextLevelCost
        ? 'LEVEL $nextLevel READY'
        : '${nextLevelCost - projectedXp} XP · LEVEL $nextLevel';
    _bubbles = [
      if (b.firstOfDay)
        _Bubble(
          'FIRST WIN TODAY',
          Icons.wb_twilight_rounded,
          Palette.streak,
          'streak',
        ),
      _Bubble(
        '+${b.xp} XP${b.embers > 0 ? ' · +${b.embers} Glimmers' : ''}',
        Icons.bolt,
        Palette.xp,
        null,
        hero: true,
      ),
      // per-stat pitched blip (§8: pitch varies by stat) — tappable when
      // an unread evidence card waits behind it (DESIGN §5)
      _Bubble(
        '+${b.statGain} ${b.stat.abbr}${b.hasEvidence ? ' · WHY' : ''}',
        Icons.trending_up,
        b.stat.color,
        'stat_${b.stat.index}',
        evidence: b.hasEvidence,
      ),
      if (b.verifiedMult != null)
        _Bubble(
          'VERIFIED ×${b.verifiedMult!.toStringAsFixed(1)}',
          Icons.verified,
          Palette.verify,
          null,
        ),
      if (b.streakMult != null)
        _Bubble(
          'STREAK ×${b.streakMult!.toStringAsFixed(1)}',
          Icons.link_rounded,
          Palette.streak,
          'streak',
        ),
      if (b.comebackMult != null)
        _Bubble(
          'WELCOME BACK ×${b.comebackMult!.toStringAsFixed(1)}',
          Icons.replay_rounded,
          Palette.streak,
          'streak',
        ),
      if (b.shieldHeld)
        _Bubble(
          'STREAK FROZEN · ${b.freezesUsed} ${b.freezesUsed == 1 ? "DAY" : "DAYS"} HELD',
          Icons.ac_unit_rounded,
          Palette.info,
          'streak',
        ),
      if (b.freezeEarned)
        _Bubble(
          'FREEZE BANKED · ${b.freezeBalanceAfter} READY',
          Icons.ac_unit_rounded,
          Palette.info,
          'streak',
        ),
      if (b.critMult != null)
        _Bubble(
          'CRITICAL! ×${b.critMult!.toStringAsFixed(1)}',
          Icons.flash_on,
          Palette.unlock,
          'crit',
          haptic: true,
          hero: true,
        ),
      if (b.loot != null)
        _Bubble(
          '${(cosmeticFor(b.loot)?.rarity ?? Rarity.common) == Rarity.rare ? "RARE" : "LOOT"} · ${b.loot}',
          Icons.card_giftcard,
          rarityColor(cosmeticFor(b.loot)?.rarity ?? Rarity.common),
          'loot',
          hero: true,
        ),
      // the personal voice — last, wider, no sound (DESIGN.md §11.2)
      if (levelProgress != null)
        _Bubble(levelProgress, Icons.upgrade_rounded, Palette.xpLight, null),
      _Bubble(b.message, Icons.favorite, b.stat.color, null, wide: true),
    ];

    final total =
        Motion.bubbleLife +
        Motion.bubbleStagger * _bubbles.length +
        (widget.onReflect == null
            ? Duration.zero
            : const Duration(milliseconds: 700));
    _c = AnimationController(vsync: this, duration: total)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed && !_heldForSheet) {
          widget.onDone();
        }
      });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still =
        (widget.state?.reduceMotion ?? false) ||
        MediaQuery.disableAnimationsOf(context);
    if (_still != still) {
      _still = still;
      if (still) {
        for (final timer in _feedbackTimers) {
          timer.cancel();
        }
        _feedbackTimers.clear();
      }
    }
    if (_started) return;
    _started = true;
    _scheduleFeedback();
    _c.forward();
  }

  void _scheduleFeedback() {
    // sound/haptic layers fire on each bubble's entrance beat
    for (var i = 0; i < _bubbles.length; i++) {
      final bubble = _bubbles[i];
      if (bubble.sound == null && !bubble.haptic) continue;
      final timer = Timer(Motion.bubbleStagger * i, () {
        if (!mounted) return;
        if (bubble.sound != null) Sfx.instance.play(bubble.sound!);
        if (bubble.haptic) {
          if (_still || Haptics.reduceMotion) {
            HapticFeedback.lightImpact();
          } else {
            HapticFeedback.heavyImpact();
            Future.delayed(const Duration(milliseconds: 90), () {
              if (mounted) HapticFeedback.mediumImpact();
            });
          }
        }
      });
      _feedbackTimers.add(timer);
    }
  }

  void _openEvidence() {
    final card = evidenceForStat(widget.bundle.stat);
    final s = widget.state;
    if (card == null || s == null) return;
    _c.stop();
    setState(() => _heldForSheet = true);
    s.markEvidenceSeen([card.title]);
    Sfx.instance.playInteraction(
      InteractionSound.select,
      material: MaterialSound.stone,
    );
    Haptics.tap();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: GlassPanel(
            tint: const Color(0xF22A211D),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'WHY THIS WORKS',
                  style: Type.label.copyWith(fontSize: 11, color: Palette.info),
                ),
                const SizedBox(height: 8),
                Text(
                  card.title,
                  style: Type.display.copyWith(
                    fontSize: 20,
                    color: Palette.textHi,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  card.text,
                  style: Type.body.copyWith(
                    fontSize: 14,
                    height: 1.45,
                    color: Palette.textMid,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  card.source,
                  style: Type.label.copyWith(
                    fontSize: Type.minLabel,
                    color: Palette.textLo,
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'GOT IT',
                      style: Type.label.copyWith(color: Palette.xp),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).whenComplete(() {
      if (!mounted) return;
      setState(() => _heldForSheet = false);
      if (_c.status == AnimationStatus.completed) {
        widget.onDone();
      } else {
        _c.forward();
      }
    });
  }

  Future<void> _openReflection() async {
    final onReflect = widget.onReflect;
    if (onReflect == null || _reflectionSaved || _heldForSheet) return;
    _c.stop();
    setState(() => _heldForSheet = true);
    final text = await showQuickReflectionSheet(
      context,
      title: 'What made this work?',
      prompt:
          'A trick, person, place, or mood you may want the next time this '
          'quest comes around.',
      attached: widget.bundle.questTitle,
    );
    if (!mounted) return;
    if (text != null) onReflect(text);
    setState(() {
      if (text != null) _reflectionSaved = true;
      _heldForSheet = false;
    });
    if (_c.status == AnimationStatus.completed) {
      if (_reflectionSaved) {
        Future<void>.delayed(const Duration(milliseconds: 520), () {
          if (mounted) widget.onDone();
        });
      } else {
        widget.onDone();
      }
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    for (final timer in _feedbackTimers) {
      timer.cancel();
    }
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final totalMs = _c.duration!.inMilliseconds.toDouble();
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final still =
        (widget.state?.reduceMotion ?? false) ||
        MediaQuery.disableAnimationsOf(context);
    return Positioned(
      left: 12,
      right: 12,
      bottom: 96 + safeBottom,
      child: OverlaySurface(
        child: Semantics(
          liveRegion: true,
          label:
              'Quest complete. ${widget.bundle.xp} XP earned. '
              '${widget.bundle.message}',
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final elapsed = _c.value * totalMs;
              final enter = Curves.easeOutCubic.transform(
                (elapsed / 320).clamp(0.0, 1.0),
              );
              final exit = _heldForSheet
                  ? 0.0
                  : ((elapsed - (totalMs - 430)) / 430).clamp(0.0, 1.0);
              final opacity = still
                  ? (_heldForSheet ? 0.0 : 1.0)
                  : (enter * (1 - exit)).clamp(0.0, 1.0);
              final receipt = ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 520,
                  // Compact phones need a little more vertical room now that
                  // the optional Journal door is part of the receipt. This
                  // still leaves the completed quest visible above it.
                  maxHeight:
                      screen.height * (screen.height < 700 ? 0.46 : 0.34),
                ),
                child: GlassPanel(
                  glow: true,
                  tint: const Color(0xF21B1511),
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: _receiptBody(still ? totalMs : elapsed),
                ),
              );
              return IgnorePointer(
                ignoring: _heldForSheet,
                child: Opacity(
                  opacity: opacity,
                  child: still
                      ? receipt
                      : Transform.translate(
                          offset: Offset(0, (1 - enter) * 22 + exit * 14),
                          child: receipt,
                        ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _receiptBody(double elapsedMs) {
    final visibleCount =
        1 +
        (elapsedMs / Motion.bubbleStagger.inMilliseconds)
            .floor()
            .clamp(0, _bubbles.length - 1)
            .toInt();
    final rewards = [
      for (final bubble in _bubbles.take(visibleCount))
        if (!bubble.wide) bubble,
    ];
    final message = _bubbles.lastWhere((bubble) => bubble.wide);
    _Bubble? hero;
    for (final bubble in rewards) {
      if (bubble.hero) {
        hero = bubble;
        break;
      }
    }
    final compact = [
      for (final bubble in rewards)
        if (!identical(bubble, hero)) bubble,
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            FacetMedallion(
              size: 38,
              accent: Palette.xp,
              glow: true,
              child: const Icon(
                Icons.done_rounded,
                size: 20,
                color: Palette.xpLight,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'QUEST COMPLETE',
                    style: Type.label.copyWith(
                      fontSize: Type.minLabel,
                      color: Palette.xpLight,
                      letterSpacing: 1.7,
                    ),
                  ),
                  if (hero != null)
                    Text(
                      hero.text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Type.numerals.copyWith(
                        fontSize: 19,
                        color: hero.color,
                      ),
                    ),
                ],
              ),
            ),
            // Was 8.5 pt in textLo — the smallest, lowest-contrast string in
            // the app, sitting beside its brightest numeral.
            Text(
              'SWIPE TO UNDO',
              style: Type.label.copyWith(
                fontSize: Type.minLabel,
                color: Palette.textMid,
              ),
            ),
          ],
        ),
        if (compact.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final bubble in compact.take(5)) _receiptChip(bubble),
            ],
          ),
        ],
        const SizedBox(height: 9),
        Text(
          message.text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Type.body.copyWith(
            fontSize: 12,
            height: 1.25,
            fontStyle: FontStyle.italic,
            color: Palette.textMid,
          ),
        ),
        if (widget.onReflect != null) ...[
          const SizedBox(height: 9),
          Semantics(
            button: !_reflectionSaved,
            label: _reflectionSaved
                ? 'One line kept in Journal'
                : 'Keep one line about this quest in Journal',
            child: Pressable(
              enabled: !_reflectionSaved,
              material: MaterialSound.parchment,
              pressDepth: 2,
              edgeColor: Colors.transparent,
              semanticLabel: _reflectionSaved
                  ? 'One line kept in Journal'
                  : 'Keep one line in Journal',
              onTapUp: _reflectionSaved ? null : (_) => _openReflection(),
              child: Container(
                constraints: const BoxConstraints(minHeight: 38),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: facetedDecoration(
                  cut: 7,
                  color: (_reflectionSaved ? Palette.success : Palette.xp)
                      .withValues(alpha: 0.07),
                  borderColor:
                      (_reflectionSaved ? Palette.success : Palette.brass)
                          .withValues(alpha: 0.42),
                ),
                child: Row(
                  children: [
                    Icon(
                      _reflectionSaved
                          ? Icons.bookmark_added_rounded
                          : Icons.history_edu_rounded,
                      size: 16,
                      color: _reflectionSaved
                          ? Palette.success
                          : Palette.xpLight,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _reflectionSaved
                            ? 'ONE LINE KEPT IN JOURNAL'
                            : 'KEEP ONE LINE  ·  OPTIONAL',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Type.label.copyWith(
                          fontSize: Type.minLabel,
                          color: _reflectionSaved
                              ? Palette.success
                              : Palette.xpLight,
                        ),
                      ),
                    ),
                    if (!_reflectionSaved)
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: Palette.textLo,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _receiptChip(_Bubble bubble) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: facetedDecoration(
        cut: 6,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            bubble.color.withValues(alpha: 0.18),
            bubble.color.withValues(alpha: 0.045),
          ],
        ),
        borderColor: bubble.color.withValues(alpha: 0.48),
        borderWidth: 0.8,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          emberkeepIcon(
            bubble.icon,
            size: 13,
            color: bubble.color,
            flameHue: widget.state == null
                ? emberFlameDefaultHue
                : flameHueFor(widget.state!),
          ),
          const SizedBox(width: 5),
          Text(
            bubble.text,
            style: Type.label.copyWith(
              fontSize: Type.minLabel,
              color: bubble.color,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
    if (!bubble.evidence) return IgnorePointer(child: chip);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _openEvidence,
      child: chip,
    );
  }
}
