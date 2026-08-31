import 'dart:async';
import 'dart:math' show min, pi, sin;
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart' show ValueListenable, kIsWeb;
import 'package:flutter/material.dart';

import '../audio.dart';
import '../clock.dart';
import '../content/quest_companion_copy.dart';
import '../models.dart';
import '../tokens.dart';
import 'day_picker.dart' show weekdayLabel;
import 'facets.dart';
import 'gold_surface.dart';
import 'notes_sheet.dart' show relativeWhen;
import 'pressable.dart';

/// A quest row from the approved room-backed board.
///
/// The leading quest is allowed to become a generous game object with a
/// luminous completion control. Everything after it returns to a compact,
/// scan-friendly row. Both states share one material, one border language,
/// one title treatment, and one XP badge.
class QuestCard extends StatefulWidget {
  const QuestCard({
    super.key,
    required this.quest,
    required this.done,
    required this.xpPreview,
    required this.onComplete,
    this.onManage,
    this.onEncore,
    this.deskFinish,
    this.reduceMotion = false,
    this.featured = false,
    this.lightDirection,
    this.scrollPosition,
    this.featuredAnchor,
  });

  /// Set on whichever card is currently [featured], so the board can measure it
  /// and keep its action out from under the reward rail.
  final GlobalKey? featuredAnchor;

  final Quest quest;
  final bool done;
  final int xpPreview;
  final void Function(Offset globalTapPosition) onComplete;
  final VoidCallback? onManage;
  final VoidCallback? onEncore;
  final Color? deskFinish;
  final bool reduceMotion;
  final bool featured;
  final ValueListenable<Offset>? lightDirection;
  final ValueListenable<double>? scrollPosition;

  @override
  State<QuestCard> createState() => _QuestCardState();
}

class _QuestCardState extends State<QuestCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _squash = AnimationController(
    vsync: this,
    duration: Motion.ack,
  );
  final GlobalKey _ringKey = GlobalKey();
  Timer? _encoreTimer;
  Timer? _completionSettleTimer;
  late bool _showEncore = widget.done;
  bool _holdResolvedFeature = false;

  @override
  void didUpdateWidget(QuestCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.done && widget.done) {
      _encoreTimer?.cancel();
      _completionSettleTimer?.cancel();
      _showEncore = false;
      // Let the hero action physically resolve before it banks into the compact
      // list. The old card vanished into a row on the same frame as the tap,
      // which made an otherwise rich completion feel like a layout jump.
      // Reduced Motion still receives the resolved state, just without travel.
      _holdResolvedFeature = oldWidget.featured;
      if (_holdResolvedFeature) {
        _completionSettleTimer = Timer(const Duration(milliseconds: 760), () {
          if (mounted) setState(() => _holdResolvedFeature = false);
        });
      }
      _encoreTimer = Timer(const Duration(milliseconds: 620), () {
        if (mounted) setState(() => _showEncore = true);
      });
    } else if (oldWidget.done && !widget.done) {
      _encoreTimer?.cancel();
      _completionSettleTimer?.cancel();
      _showEncore = false;
      _holdResolvedFeature = false;
    }
  }

  void _handleTap(Offset globalPosition) {
    if (widget.done) return;
    final still =
        widget.reduceMotion || MediaQuery.disableAnimationsOf(context);
    if (!still) {
      _squash.forward(from: 0).then((_) => _squash.reverse());
    }
    final box = _ringKey.currentContext?.findRenderObject() as RenderBox?;
    final origin = box == null
        ? globalPosition
        : box.localToGlobal(box.size.center(Offset.zero));
    widget.onComplete(origin);
  }

  @override
  void dispose() {
    _encoreTimer?.cancel();
    _completionSettleTimer?.cancel();
    _squash.dispose();
    super.dispose();
  }

  static String _difficultyWord(int difficulty) {
    if (difficulty <= 2) return 'easy';
    if (difficulty <= 4) return 'solid';
    if (difficulty <= 6) return 'tough';
    return 'epic';
  }

  @override
  Widget build(BuildContext context) {
    final quest = widget.quest;
    final done = widget.done;
    final opensJournal = quest.journalPrompt != null;
    final isMain = quest.priorityOn(Clock.now());
    final mastery = quest.masteryTier;
    final masterySemantics = quest.masteryCompletions == 0
        ? ''
        : ', ${quest.masteryCompletions} completions${mastery == QuestMasteryTier.unmarked ? '' : ', ${mastery.label.toLowerCase()} mastery'}';
    final riseSemantics = quest.rising && quest.canRise
        ? ', rise progress ${quest.riseProgress} of ${Quest.risesAt}'
        : '';
    final featured = widget.featured && !done;
    final resolvedFeature = done && _holdResolvedFeature;
    final heroLayout = featured || resolvedFeature;
    final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.25;
    final still =
        widget.reduceMotion ||
        (MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    final desk = widget.deskFinish;
    final base = desk == null
        ? const Color(0xF21A1512)
        : Color.lerp(
            const Color(0xF21A1512),
            desk.withValues(alpha: 0.86),
            0.10,
          )!;
    // The featured frame is a quiet brass rule, not a second bright surface —
    // the action is the only thing on the board allowed to be luminous.
    final edge = featured
        ? const Color(0xFFA97A41)
        : done
        ? const Color(0xFF806747)
        : const Color(0xFF51463B);

    return LayoutBuilder(
      builder: (context, constraints) {
        final largePhoneType = largeText && constraints.maxWidth <= 360;
        return AnimatedBuilder(
          key: widget.featuredAnchor,
          animation: _squash,
          builder: (context, child) => Transform.scale(
            scaleX: 1 + 0.008 * _squash.value,
            scaleY: 1 - 0.045 * _squash.value,
            child: child,
          ),
          child: AnimatedSize(
            // AnimatedSize cannot use an exactly-zero controller duration while
            // a lazy sliver is laying itself out (it completes synchronously and
            // re-dirties that same render object). One millisecond is visually
            // parked while preserving the reduced-motion contract.
            duration: still ? const Duration(milliseconds: 1) : Motion.settle,
            curve: Motion.respond,
            alignment: Alignment.topCenter,
            child: Pressable(
              enabled: !done,
              semanticLabel:
                  '${quest.displayTitle}, ${done
                      ? 'completed'
                      : opensJournal
                      ? 'Open Journal, ${widget.xpPreview} XP'
                      : '${_difficultyWord(quest.difficulty)}, ${widget.xpPreview} XP'}$masterySemantics$riseSemantics',
              semanticHint: done
                  ? (widget.onManage == null ? null : 'Use Manage to edit')
                  : '${opensJournal ? 'Activate to open a dedicated Journal entry' : 'Activate to complete'}${widget.onManage == null ? '' : '; use Manage to edit'}',
              onTapUp: _handleTap,
              onLongPress: widget.onManage,
              // The card delegates sound to the accepted outcome. A normal clear
              // owns the full contact-to-detent completion voice; Journal,
              // workout, timer, and all-day paths voice the surface they actually
              // open. Keeping this press silent prevents a second generic clasp
              // and guarantees that a cancelled scroll never makes a sound.
              soundEnabled: false,
              material: MaterialSound.wood,
              interactionSound: InteractionSound.open,
              shape: const FacetedBorder(cut: 11),
              child: AnimatedContainer(
                duration: Motion.settle,
                curve: Motion.respond,
                decoration: facetedDecoration(
                  cut: 11,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      done
                          ? Color.lerp(base, const Color(0xFFB78A50), 0.055)!
                          : Color.lerp(base, const Color(0xFF4B3627), 0.12)!,
                      base,
                      const Color(0xFF100D0B),
                    ],
                    stops: const [0, 0.54, 1],
                  ),
                  borderColor: edge,
                  borderWidth: featured
                      ? 1.35
                      : (resolvedFeature ? 1.15 : 1.05),
                  shadows: [
                    const BoxShadow(
                      color: Color(0x8A090605),
                      blurRadius: 14,
                      offset: Offset(0, 6),
                    ),
                    if (featured)
                      BoxShadow(
                        color: Palette.xp.withValues(alpha: 0.10),
                        blurRadius: 22,
                        offset: const Offset(0, 6),
                      ),
                  ],
                ),
                child: ClipPath(
                  clipper: const FacetedClipper(cut: 11),
                  child: Stack(
                    children: [
                      if (heroLayout)
                        Positioned(
                          top: 42,
                          right: -4,
                          width: 208,
                          height: 112,
                          child: IgnorePointer(
                            child: Opacity(
                              opacity: done ? 0.30 : 1,
                              child: _QuestCategoryVignette(
                                stat: quest.stat,
                                lightDirection: featured
                                    ? widget.lightDirection
                                    : null,
                                scrollPosition: featured
                                    ? widget.scrollPosition
                                    : null,
                                reduceMotion: widget.reduceMotion,
                              ),
                            ),
                          ),
                        ),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  const Color(0x18FFD493),
                                  Colors.transparent,
                                  Colors.transparent,
                                  const Color(0x3D000000),
                                ],
                                stops: const [0, 0.24, 0.72, 1],
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (featured)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: _QuestCardGleam(
                              lightDirection: widget.lightDirection,
                              scrollPosition: widget.scrollPosition,
                              reduceMotion: widget.reduceMotion,
                            ),
                          ),
                        ),
                      Positioned(
                        left: 18,
                        right: 18,
                        top: 1,
                        child: IgnorePointer(
                          child: Container(
                            height: 1,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Color(0x00FFE3AD),
                                  Color(0xA8FFE3AD),
                                  Color(0x20FFE3AD),
                                  Color(0x00FFE3AD),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (heroLayout)
                        Positioned.fill(
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: IgnorePointer(
                              child: DecoratedBox(
                                decoration: facetedDecoration(
                                  cut: 8,
                                  color: Colors.transparent,
                                  borderColor: done
                                      ? const Color(0x3DBF9560)
                                      : const Color(0x66FFD38A),
                                  borderWidth: 0.7,
                                ),
                              ),
                            ),
                          ),
                        ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          heroLayout ? 15 : 14,
                          heroLayout ? 14 : 13,
                          heroLayout ? 15 : 12,
                          heroLayout ? 13 : 13,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: heroLayout ? 106 : 46,
                              ),
                              child: Transform.translate(
                                offset: Offset.zero,
                                child: Row(
                                  children: [
                                    _CheckRing(
                                      key: _ringKey,
                                      stat: quest.stat,
                                      done: done,
                                      reduceMotion: widget.reduceMotion,
                                      accent: featured ? Palette.xpLight : null,
                                      size: heroLayout ? 54 : 40,
                                      showReadyCheck: featured,
                                      masteryTier: mastery,
                                      // Only the featured open orbit carries reactive
                                      // light. Repainting every compact ring on every
                                      // sensor sample made long boards needlessly
                                      // expensive and made ordinary rows look restless.
                                      lightDirection: featured
                                          ? widget.lightDirection
                                          : null,
                                      scrollPosition: featured
                                          ? widget.scrollPosition
                                          : null,
                                    ),
                                    SizedBox(width: heroLayout ? 12 : 10),
                                    Expanded(
                                      child: _QuestTitleBlock(
                                        quest: quest,
                                        done: done,
                                        isMain: isMain,
                                        featured: heroLayout,
                                        compactLargeType: largePhoneType,
                                      ),
                                    ),
                                    if (quest.dread) ...[
                                      const SizedBox(width: 5),
                                      Icon(
                                        Icons.thunderstorm_rounded,
                                        size: heroLayout ? 20 : 18,
                                        color: done
                                            ? Palette.dread.withValues(
                                                alpha: 0.38,
                                              )
                                            : Palette.dread,
                                      ),
                                    ],
                                    const SizedBox(width: 8),
                                    if (!largePhoneType &&
                                        done &&
                                        widget.onEncore != null &&
                                        _showEncore)
                                      _EncoreButton(onTap: widget.onEncore!)
                                    else if (!largePhoneType)
                                      _XpChip(
                                        xp: widget.xpPreview,
                                        dim: done,
                                        featured: heroLayout,
                                      ),
                                    if (!heroLayout) ...[
                                      const SizedBox(width: 5),
                                      Icon(
                                        Icons.chevron_right_rounded,
                                        size: 19,
                                        color: Palette.textLo.withValues(
                                          alpha: 0.72,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            if (heroLayout && largePhoneType) ...[
                              const SizedBox(height: 6),
                              Align(
                                alignment: Alignment.centerRight,
                                child: _XpChip(
                                  xp: widget.xpPreview,
                                  dim: done,
                                  featured: true,
                                ),
                              ),
                            ],
                            if (heroLayout) ...[
                              const SizedBox(height: 10),
                              IgnorePointer(
                                child: AnimatedSwitcher(
                                  duration: still
                                      ? Duration.zero
                                      : const Duration(milliseconds: 260),
                                  switchInCurve: Motion.respond,
                                  switchOutCurve: Curves.easeInCubic,
                                  child: done
                                      ? const _ResolvedQuestPlate(
                                          key: ValueKey('quest-resolved-plate'),
                                        )
                                      : _CompleteQuestButton(
                                          key: const ValueKey(
                                            'quest-complete-plate',
                                          ),
                                          opensJournal: opensJournal,
                                          lightDirection: widget.lightDirection,
                                          scrollPosition: widget.scrollPosition,
                                          reduceMotion: widget.reduceMotion,
                                        ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: 0,
                        child: IgnorePointer(
                          child: Container(
                            height: 2,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  heroLayout && !done
                                      ? const Color(0xFF754117)
                                      : resolvedFeature
                                      ? const Color(0xFF51391F)
                                      : const Color(0xFF2B211C),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _QuestTitleBlock extends StatelessWidget {
  const _QuestTitleBlock({
    required this.quest,
    required this.done,
    required this.isMain,
    required this.featured,
    required this.compactLargeType,
  });

  final Quest quest;
  final bool done;
  final bool isMain;
  final bool featured;
  final bool compactLargeType;

  @override
  Widget build(BuildContext context) {
    final companion = featured
        ? questCompanionCopy(quest: quest, day: Clock.now())
        : null;
    final chips = <Widget>[
      if (quest.journalPrompt != null)
        const _MetaChip(Icons.menu_book_rounded, 'JOURNAL', Palette.xpLight),
      if (quest.workout)
        _MetaChip(Icons.fitness_center_rounded, 'GUIDED', quest.stat.color),
      if (isMain) const _MetaChip(Icons.star_rounded, 'MAIN', Palette.xpLight),
      if (quest.allDay)
        const _MetaChip(Icons.nightlight_round, 'ALL DAY', Palette.unlock),
      if (quest.rising && quest.canRise)
        _MetaChip(
          Icons.trending_up_rounded,
          '${quest.riseProgress}/${Quest.risesAt}',
          Palette.streak,
        ),
      if (!done && quest.bonus)
        const _MetaChip(Icons.bolt_rounded, 'BONUS · TODAY', Palette.streak)
      else if (!done && quest.isEvent)
        _eventChip(quest)
      else if (!done &&
          quest.schedule == QuestSchedule.weekly &&
          quest.weekdays.isNotEmpty)
        _weeklyChip(quest)
      else if (!done && quest.schedule == QuestSchedule.once)
        const _MetaChip(Icons.push_pin_outlined, 'UNTIL DONE', Palette.info)
      else if (!done && quest.schedule != QuestSchedule.daily)
        _MetaChip(null, quest.schedule.label, Palette.xpLight),
      if (quest.verification == Verification.timer)
        _MetaChip(
          Icons.timer_outlined,
          '${quest.effectiveTimerMinutes}M PROOF',
          Palette.verify,
        ),
    ];

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          quest.displayTitle,
          maxLines: compactLargeType ? 3 : (featured || done ? 2 : 1),
          overflow: TextOverflow.ellipsis,
          style: Type.display.copyWith(
            fontSize: featured ? 20 : 15.5,
            height: 1.08,
            fontWeight: FontWeight.w500,
            color: done ? Palette.textMid : Palette.textHi,
          ),
        ),
        if (chips.isNotEmpty) ...[
          const SizedBox(height: 5),
          Wrap(
            spacing: 9,
            runSpacing: 3,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: chips,
          ),
        ],
        if (featured && quest.masteryTier != QuestMasteryTier.unmarked) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(
                Icons.workspace_premium_outlined,
                size: 11,
                color: Color(0xFFC99A5D),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  '${quest.masteryTier.label} · ${quest.masteryCompletions}×',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Type.label.copyWith(
                    fontSize: Type.minLabel,
                    letterSpacing: 0.45,
                    color: const Color(0xFFC99A5D),
                  ),
                ),
              ),
            ],
          ),
        ],
        if (featured && quest.latestNote != null) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(
                Icons.sticky_note_2_outlined,
                size: 11,
                color: Palette.textLo,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  '${quest.latestNote!.text} · ${relativeWhen(quest.latestNote!.at)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Type.label.copyWith(
                    fontSize: Type.minLabel,
                    letterSpacing: 0.15,
                    color: Palette.textLo,
                  ),
                ),
              ),
            ],
          ),
        ] else if (featured && quest.ladderHint != null) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Flexible(
                child: Text(
                  quest.ladderHint!.replaceAll('📈', '').trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Type.label.copyWith(
                    fontSize: Type.minLabel,
                    letterSpacing: 0.2,
                    color: Palette.textLo,
                  ),
                ),
              ),
              if (quest.ladderHint!.contains('📈')) ...[
                const SizedBox(width: 4),
                const Icon(
                  Icons.trending_up_rounded,
                  size: 12,
                  color: Palette.textLo,
                ),
              ],
            ],
          ),
        ] else if (featured && companion != null) ...[
          const SizedBox(height: 4),
          Text(
            companion,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Type.body.copyWith(
              fontSize: 12,
              height: 1.2,
              fontStyle: FontStyle.italic,
              color: Palette.textLo,
            ),
          ),
        ],
      ],
    );
  }

  static Widget _eventChip(Quest quest) {
    final now = Clock.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final overdue = quest.dueDate!.isBefore(startOfToday);
    return _MetaChip(
      null,
      overdue
          ? 'OPEN SINCE ${_shortWeekday(quest.dueDate!.weekday)}'
          : 'DUE TODAY',
      overdue ? Palette.streak : Palette.xpLight,
      maxWidth: overdue ? 108 : null,
    );
  }

  static String _shortWeekday(int weekday) =>
      const ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'][weekday - 1];

  static Widget _weeklyChip(Quest quest) {
    final anchor = quest.weekdays.reduce(min);
    final lingering = Clock.now().weekday > anchor;
    return _MetaChip(
      lingering ? Icons.east_rounded : null,
      lingering ? 'OPEN THIS WEEK' : weekdayLabel(quest.weekdays).toUpperCase(),
      lingering ? Palette.info : Palette.xpLight,
      maxWidth: lingering ? 100 : null,
    );
  }
}

/// One authored still-life per quest category. Each scene uses the same walnut,
/// parchment and candlelight language as the approved card, while its props do
/// the category-identification work that a flat colour block otherwise would.
///
/// The artwork itself never loops. It drifts by at most a couple of pixels in
/// response to the same scroll/tilt signal as the card's material highlight.
class _QuestCategoryVignette extends StatelessWidget {
  const _QuestCategoryVignette({
    required this.stat,
    required this.lightDirection,
    required this.scrollPosition,
    required this.reduceMotion,
  });

  final Stat stat;
  final ValueListenable<Offset>? lightDirection;
  final ValueListenable<double>? scrollPosition;
  final bool reduceMotion;

  String get _asset => switch (stat) {
    Stat.str => 'assets/quest/category-body-v2.webp',
    Stat.vit => 'assets/quest/category-care-v2.webp',
    Stat.intl => 'assets/quest/category-mind-v2.webp',
    Stat.foc => 'assets/quest/category-craft-v2.webp',
    Stat.soc => 'assets/quest/category-people-v2.webp',
    Stat.dis => 'assets/quest/category-home-v2.webp',
  };

  @override
  Widget build(BuildContext context) {
    final still =
        reduceMotion || (MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    return AnimatedBuilder(
      // The vignette is already softly masked artwork. Its sub-pixel drift
      // cost a blur + shader recomposite on every browser scroll update while
      // adding almost no visible information, so web keeps its finished still.
      animation: kIsWeb
          ? const AlwaysStoppedAnimation<double>(0)
          : Listenable.merge([?lightDirection, ?scrollPosition]),
      builder: (context, _) {
        final light = still || kIsWeb
            ? Offset.zero
            : lightDirection?.value ?? Offset.zero;
        final scroll = still || kIsWeb ? 0.0 : scrollPosition?.value ?? 0.0;
        final drift = still ? 0.0 : sin(scroll * 0.0042);
        return ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Colors.transparent,
              Color(0xD9000000),
              Colors.black,
              Color(0xF0000000),
              Colors.transparent,
            ],
            stops: [0, 0.22, 0.43, 0.94, 1],
          ).createShader(bounds),
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 0.9, sigmaY: 0.9),
            child: Transform.translate(
              offset: Offset(
                light.dx * 2.6 + drift * 1.1,
                light.dy * 1.6 - drift * 0.45,
              ),
              child: Opacity(
                opacity: 0.52,
                child: Image.asset(
                  _asset,
                  fit: BoxFit.contain,
                  alignment: Alignment.bottomRight,
                  filterQuality: FilterQuality.medium,
                  excludeFromSemantics: true,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

double _polishPhase({
  required ValueListenable<Offset>? lightDirection,
  required ValueListenable<double>? scrollPosition,
  required bool still,
}) {
  if (still) return 0.22;
  final light = lightDirection?.value ?? Offset.zero;
  final raw =
      0.22 +
      (scrollPosition?.value ?? 0) * 0.00092 +
      light.dx * 0.110 -
      light.dy * 0.040;
  final wrapped = raw % 1.0;
  return wrapped < 0 ? wrapped + 1 : wrapped;
}

Offset _polishLight(
  ValueListenable<Offset>? lightDirection, {
  required bool still,
}) => still ? Offset.zero : lightDirection?.value ?? Offset.zero;

/// A shared film of warm light over the featured card keeps its border, ring
/// and action in one material world. The edge sheen changes only when the user
/// scrolls or moves the device; there is no self-performing sparkle loop.
class _QuestCardGleam extends StatelessWidget {
  const _QuestCardGleam({
    required this.lightDirection,
    required this.scrollPosition,
    required this.reduceMotion,
  });

  final ValueListenable<Offset>? lightDirection;
  final ValueListenable<double>? scrollPosition;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final still =
        reduceMotion || (MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    return AnimatedBuilder(
      animation: Listenable.merge([?lightDirection, ?scrollPosition]),
      builder: (context, _) => CustomPaint(
        painter: _QuestCardGleamPainter(
          phase: _polishPhase(
            lightDirection: lightDirection,
            scrollPosition: scrollPosition,
            still: still,
          ),
          light: _polishLight(lightDirection, still: still),
        ),
      ),
    );
  }
}

class _QuestCardGleamPainter extends CustomPainter {
  const _QuestCardGleamPainter({required this.phase, required this.light});

  final double phase;
  final Offset light;

  @override
  void paint(Canvas canvas, Size size) {
    final lightAt = Offset(
      size.width * (0.30 + light.dx * 0.12),
      size.height * (0.10 + light.dy * 0.07),
    );
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader =
            RadialGradient(
              colors: const [
                Color(0x0DFFD69A),
                Color(0x03FFD69A),
                Color(0x00FFD69A),
              ],
              stops: const [0, 0.46, 1],
            ).createShader(
              Rect.fromCircle(center: lightAt, radius: size.width * 0.58),
            ),
    );

    final x = size.width * (0.06 + phase * 0.88);
    final edge = Rect.fromCenter(
      center: Offset(x, 1.1),
      width: 52,
      height: 1.7,
    );
    canvas.drawRect(
      edge,
      Paint()
        ..blendMode = BlendMode.screen
        ..shader = const LinearGradient(
          colors: [
            Color(0x00FFE5A7),
            Color(0x18FFE5A7),
            Color(0x74FFF0C2),
            Color(0x14FFE5A7),
            Color(0x00FFE5A7),
          ],
          stops: [0, 0.32, 0.5, 0.68, 1],
        ).createShader(edge),
    );
  }

  @override
  bool shouldRepaint(_QuestCardGleamPainter old) =>
      old.phase != phase || old.light != light;
}

/// The featured Quest's primary action.
///
/// Ordinary completion keeps the board's single luminous [GoldSurface]. A
/// Journal doorway belongs to the book it opens instead: a quieter oxblood
/// bookplate with aged-brass hardware. That distinction makes the action feel
/// attached to the Quest card instead of resembling a shop button pasted onto
/// it, while its depth and clear label keep it unmistakably actionable.
class _CompleteQuestButton extends StatelessWidget {
  const _CompleteQuestButton({
    super.key,
    required this.opensJournal,
    required this.lightDirection,
    required this.scrollPosition,
    required this.reduceMotion,
  });

  final bool opensJournal;
  final ValueListenable<Offset>? lightDirection;
  final ValueListenable<double>? scrollPosition;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    if (opensJournal) {
      return const _JournalQuestBookplate();
    }
    return SizedBox(
      height: 48,
      child: GoldSurface(
        cut: 10,
        light: lightDirection,
        scroll: scrollPosition,
        reduceMotion: reduceMotion,
        child: const GoldLabel(text: 'MARK COMPLETE'),
      ),
    );
  }
}

/// A restrained book-cloth doorway for a Quest-authored Journal page.
///
/// This intentionally has no moving reflection. The outer under-lip, inset
/// double rule, spine-mounted seal and page-edge cue do the physical work, so
/// the control remains a finished object when motion is parked. Its loose
/// height allows the label to wrap safely at 2x text size while preserving a
/// minimum 52 logical-pixel tap target.
class _JournalQuestBookplate extends StatelessWidget {
  const _JournalQuestBookplate();

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      key: const ValueKey('journal-quest-bookplate'),
      constraints: const BoxConstraints(
        minWidth: 220,
        maxWidth: 260,
        minHeight: 52,
      ),
      child: DecoratedBox(
        decoration: facetedDecoration(
          cut: 9,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF43251E), Color(0xFF2C1916), Color(0xFF170E0C)],
            stops: [0, 0.48, 1],
          ),
          borderColor: const Color(0xFFA07843),
          borderWidth: 1.15,
          shadows: const [
            BoxShadow(
              color: Color(0xB30A0604),
              blurRadius: 0,
              offset: Offset(0, 3),
            ),
            BoxShadow(
              color: Color(0x2E9A6734),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: ClipPath(
          clipper: const FacetedClipper(cut: 9),
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: DecoratedBox(
                      decoration: facetedDecoration(
                        cut: 6.5,
                        color: Colors.transparent,
                        borderColor: const Color(0x6BC09A61),
                        borderWidth: 0.65,
                      ),
                    ),
                  ),
                ),
              ),
              const Positioned(
                left: 48,
                right: 22,
                top: 1,
                child: _BookplateRule(
                  colors: [
                    Color(0x00F1D6A1),
                    Color(0x8AF1D6A1),
                    Color(0x24F1D6A1),
                    Color(0x00F1D6A1),
                  ],
                ),
              ),
              const Positioned(
                left: 52,
                right: 24,
                bottom: 3,
                child: _BookplateRule(
                  colors: [
                    Color(0x006C4527),
                    Color(0x886C4527),
                    Color(0x336C4527),
                    Color(0x006C4527),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 7, 9, 7),
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    const _JournalBookSeal(),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'OPEN JOURNAL',
                        maxLines: 2,
                        softWrap: true,
                        overflow: TextOverflow.visible,
                        textAlign: TextAlign.center,
                        style: Type.label.copyWith(
                          fontSize: 12,
                          height: 1.12,
                          letterSpacing: 1.45,
                          color: const Color(0xFFF0D8A8),
                          shadows: const [
                            Shadow(
                              color: Color(0xB30D0806),
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    const _JournalPageEdgeCue(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JournalBookSeal extends StatelessWidget {
  const _JournalBookSeal();

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 36,
      child: DecoratedBox(
        decoration: facetedDecoration(
          cut: 6,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2B1A15), Color(0xFF130C0A)],
          ),
          borderColor: const Color(0xFF9D7542),
          borderWidth: 1,
          shadows: const [
            BoxShadow(
              color: Color(0x8A080503),
              blurRadius: 0,
              offset: Offset(1, 2),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const Padding(
              padding: EdgeInsets.all(3),
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  shape: FacetedBorder(
                    cut: 3.5,
                    side: BorderSide(color: Color(0x4DF1D6A1), width: 0.6),
                  ),
                ),
              ),
            ),
            const Center(
              child: Icon(
                Icons.menu_book_rounded,
                size: 19,
                color: Color(0xFFE4BE7E),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JournalPageEdgeCue extends StatelessWidget {
  const _JournalPageEdgeCue();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      height: 30,
      child: Stack(
        alignment: Alignment.centerRight,
        children: [
          Positioned(
            left: 1,
            top: 7,
            bottom: 7,
            child: Container(width: 1, color: const Color(0x5CC9A36B)),
          ),
          Positioned(
            left: 4,
            top: 9,
            bottom: 9,
            child: Container(width: 1, color: const Color(0x3DF0D7A1)),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            size: 19,
            color: Color(0xFFBF935A),
          ),
        ],
      ),
    );
  }
}

class _BookplateRule extends StatelessWidget {
  const _BookplateRule({required this.colors});

  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(gradient: LinearGradient(colors: colors)),
      child: const SizedBox(height: 1),
    );
  }
}

/// The honey action cools into quiet resolved metal before the card banks.
/// Keeping the same plate geometry makes completion feel remembered; lowering
/// its value keeps the next open quest as the only luminous action.
class _ResolvedQuestPlate extends StatelessWidget {
  const _ResolvedQuestPlate({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: DecoratedBox(
        decoration: facetedDecoration(
          cut: 10,
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF5A4024), Color(0xFF372719), Color(0xFF211710)],
            stops: [0, 0.48, 1],
          ),
          borderColor: const Color(0xFF8D6B3E),
          borderWidth: 1,
          shadows: const [
            BoxShadow(
              color: Color(0xA30A0705),
              blurRadius: 0,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const Positioned(
              left: 18,
              right: 18,
              top: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0x00F3D59C),
                      Color(0x7AF3D59C),
                      Color(0x18F3D59C),
                      Color(0x00F3D59C),
                    ],
                  ),
                ),
                child: SizedBox(height: 1),
              ),
            ),
            Center(
              child: Text(
                'QUEST COMPLETE',
                style: Type.label.copyWith(
                  fontSize: 11.5,
                  letterSpacing: 1.75,
                  color: const Color(0xFFE1C58E),
                  shadows: const [
                    Shadow(color: Color(0xB30F0A07), offset: Offset(0, -1)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckRing extends StatefulWidget {
  const _CheckRing({
    super.key,
    required this.stat,
    required this.done,
    required this.size,
    this.reduceMotion = false,
    this.accent,
    this.showReadyCheck = false,
    this.masteryTier = QuestMasteryTier.unmarked,
    this.lightDirection,
    this.scrollPosition,
  });

  final Stat stat;
  final bool done;
  final double size;
  final bool reduceMotion;
  final Color? accent;
  final bool showReadyCheck;
  final QuestMasteryTier masteryTier;
  final ValueListenable<Offset>? lightDirection;
  final ValueListenable<double>? scrollPosition;

  @override
  State<_CheckRing> createState() => _CheckRingState();
}

class _CheckRingState extends State<_CheckRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _resolve = AnimationController(
    vsync: this,
    // Matched to the 460 ms longer-settle completion master so the ring
    // finishes resolving as the sound finishes settling.
    duration: const Duration(milliseconds: 460),
  );

  @override
  void initState() {
    super.initState();
    if (widget.done) _resolve.value = 1;
  }

  @override
  void didUpdateWidget(_CheckRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.done && widget.done) {
      final still =
          widget.reduceMotion || MediaQuery.disableAnimationsOf(context);
      if (still) {
        _resolve.value = 1;
      } else {
        _resolve.forward(from: 0);
      }
    } else if (oldWidget.done && !widget.done) {
      _resolve.value = 0;
    }
  }

  @override
  void dispose() {
    _resolve.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still =
        widget.reduceMotion ||
        (MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    return AnimatedBuilder(
      animation: Listenable.merge([
        _resolve,
        ?widget.lightDirection,
        ?widget.scrollPosition,
      ]),
      builder: (context, _) {
        final light = _polishLight(widget.lightDirection, still: still);
        final shine = _polishPhase(
          lightDirection: widget.lightDirection,
          scrollPosition: widget.scrollPosition,
          still: still,
        );
        return SizedBox.square(
          dimension: widget.size,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                key: const ValueKey('quest-check-draw'),
                painter: _CheckRingPainter(
                  stat: widget.stat,
                  done: widget.done,
                  progress: _resolve.value,
                  accent: widget.accent,
                  showReadyCheck: widget.showReadyCheck,
                  masteryTier: widget.masteryTier,
                  shine: shine,
                  light: light,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CheckRingPainter extends CustomPainter {
  const _CheckRingPainter({
    required this.stat,
    required this.done,
    required this.progress,
    required this.showReadyCheck,
    required this.masteryTier,
    required this.shine,
    required this.light,
    this.accent,
  });

  final Stat stat;
  final bool done;
  final double progress;
  final Color? accent;
  final bool showReadyCheck;
  final QuestMasteryTier masteryTier;
  final double shine;
  final Offset light;

  Color get _hue => accent ?? stat.color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide * (showReadyCheck ? 0.42 : 0.39);
    final resolved = Curves.easeOutBack.transform(progress);
    final ready = showReadyCheck && !done;
    _paintMasteryOrbit(canvas, size, center, radius);
    if (ready) {
      final orbit = Rect.fromCircle(center: center, radius: radius);
      // A wider break at 4 o'clock than before, so the silhouette reads OPEN at
      // a glance. Closed-plus-a-check was the tell that made the ready control
      // look like an already-completed token.
      const gapCenter = pi * 0.28;
      const gap = pi * 0.36;
      const orbitStart = gapCenter + gap / 2;
      const orbitSweep = pi * 2 - gap;

      // The centre is the card, not another disc — only a whisper of contact
      // shadow, so the ring reads as jewellery mounted into the surface.
      canvas.drawCircle(
        center,
        radius - size.width * 0.055,
        Paint()
          ..shader = RadialGradient(
            center: Alignment(-0.30 + light.dx * 0.10, -0.34 + light.dy * 0.08),
            colors: const [
              Color(0x00120C08),
              Color(0x33120C08),
              Color(0x7A0C0806),
            ],
            stops: const [0, 0.62, 1],
          ).createShader(orbit),
      );
      canvas.drawArc(
        orbit,
        orbitStart,
        orbitSweep,
        false,
        Paint()
          ..color = const Color(0x44000000)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.2
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.2),
      );
      // A fine drawn wire, not a fat bezel. Its brightest point tracks the
      // shared light field; nothing here moves on a timer.
      canvas.drawArc(
        orbit,
        orbitStart,
        orbitSweep,
        false,
        Paint()
          ..shader = SweepGradient(
            transform: GradientRotation(shine * pi * 2 + light.dx * 0.16),
            colors: const [
              Color(0xFF7A4C24),
              Color(0xFFE3BE7C),
              Color(0xFF95602E),
              Color(0xFFF0D69C),
              Color(0xFF7A4C24),
            ],
          ).createShader(orbit)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - 1.55),
        orbitStart + 0.06,
        orbitSweep - 0.12,
        false,
        Paint()
          ..color = const Color(0x4DFFE7B0)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.6
          ..strokeCap = StrokeCap.round,
      );
    } else if (done) {
      final closure = Curves.easeOutCubic.transform(progress.clamp(0.0, 1.0));
      final orbit = Rect.fromCircle(center: center, radius: radius);
      canvas.drawCircle(
        center,
        radius + 1.1,
        Paint()
          ..color = const Color(0x2B9E6E36)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.4),
      );
      // The card remains visible through the centre. Completion closes and
      // warms the orbit; it does not replace it with a filled reward token.
      canvas.drawCircle(
        center,
        radius - 2.2,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.38, -0.46),
            radius: 1.12,
            colors: const [
              Color(0x18C89A58),
              Color(0x081B130E),
              Color(0x1F100B08),
            ],
            stops: const [0, 0.58, 1],
          ).createShader(orbit),
      );
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = const Color(0xA30A0705)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.4,
      );
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = const Color(0xFF6A4B2D)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2,
      );
      canvas.drawArc(
        orbit,
        -pi / 2,
        pi * 2 * closure,
        false,
        Paint()
          ..shader = const SweepGradient(
            transform: GradientRotation(-0.48),
            colors: [
              Color(0xFF7B542C),
              Color(0xFFE0BD78),
              Color(0xFF9B6B38),
              Color(0xFFF0D8A0),
              Color(0xFF7B542C),
            ],
          ).createShader(orbit)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(
        center,
        radius - 2.0,
        Paint()
          ..color = const Color(0x4DF0D7A1)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5,
      );
    } else {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-0.34, -0.42),
            radius: 1.1,
            colors: [Color(0x331E1713), Color(0xFF17120F), Color(0xFF0E0B09)],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = _hue.withValues(alpha: 0.88)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - 1.15),
        3.45,
        1.55,
        false,
        Paint()
          ..color = const Color(0xB8FFF0BD)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round,
      );
    }

    if (!done && !showReadyCheck) return;
    final check = Path();
    if (ready) {
      // A clasp hooked onto the outside of the break, the way the approved
      // target draws it — the short arm starts inside the orbit, the joint sits
      // on the wire, the long arm hangs past it. A centred check inside a ring
      // is the completed state and must not be borrowed here.
      check
        ..moveTo(size.width * 0.672, size.height * 0.706)
        ..lineTo(size.width * 0.752, size.height * 0.856)
        ..lineTo(size.width * 0.942, size.height * 0.590);
    } else {
      check
        ..moveTo(size.width * 0.29, size.height * 0.51)
        ..lineTo(size.width * 0.44, size.height * 0.65)
        ..lineTo(size.width * 0.72, size.height * 0.35);
    }
    final metric = check.computeMetrics().first;
    final fraction = done ? resolved.clamp(0.0, 1.0) : 1.0;
    final visibleCheck = metric.extractPath(0, metric.length * fraction);
    canvas.drawPath(
      visibleCheck,
      Paint()
        ..color = done ? const Color(0xD10A0705) : const Color(0xB3231207)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * (ready ? 0.062 : (done ? 0.068 : 0.105))
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      visibleCheck,
      Paint()
        ..color = done ? const Color(0xFFE5C98F) : const Color(0xFFDCB477)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * (ready ? 0.038 : (done ? 0.034 : 0.060))
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _paintMasteryOrbit(
    Canvas canvas,
    Size size,
    Offset center,
    double radius,
  ) {
    if (masteryTier == QuestMasteryTier.unmarked) return;
    final level = masteryTier.index;
    final outerRadius = min(
      size.shortestSide / 2 - 1.8,
      radius + size.shortestSide * (showReadyCheck ? 0.052 : 0.075),
    );
    final orbit = Rect.fromCircle(center: center, radius: outerRadius);

    // The ornament is accumulated brasswork, not a second progress meter.
    // It is completely still and adds one authored layer at each threshold.
    if (level >= QuestMasteryTier.gilded.index) {
      canvas.drawCircle(
        center,
        outerRadius,
        Paint()
          ..color = const Color(0x59110B07)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2,
      );
      canvas.drawCircle(
        center,
        outerRadius,
        Paint()
          ..shader = const SweepGradient(
            transform: GradientRotation(-0.62),
            colors: [
              Color(0xFF76502B),
              Color(0xFFD5AA68),
              Color(0xFF8B5D31),
              Color(0xFFE8CB8F),
              Color(0xFF76502B),
            ],
          ).createShader(orbit)
          ..style = PaintingStyle.stroke
          ..strokeWidth = level >= QuestMasteryTier.masterwork.index
              ? 1.15
              : 0.8,
      );
    }
    if (level >= QuestMasteryTier.masterwork.index) {
      canvas.drawCircle(
        center,
        outerRadius - 2.0,
        Paint()
          ..color = const Color(0x80E8CB8F)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.55,
      );
    }

    final marks = switch (masteryTier) {
      QuestMasteryTier.kept => 1,
      QuestMasteryTier.practiced => 4,
      QuestMasteryTier.gilded => 8,
      QuestMasteryTier.masterwork => 12,
      QuestMasteryTier.unmarked => 0,
    };
    for (var i = 0; i < marks; i++) {
      final angle = -pi / 2 + (pi * 2 * i / marks);
      final at = center + Offset.fromDirection(angle, outerRadius);
      final longMark = level >= QuestMasteryTier.gilded.index;
      final halfLength =
          size.shortestSide *
          (level >= QuestMasteryTier.masterwork.index && i.isEven
              ? 0.044
              : longMark
              ? 0.032
              : 0.024);
      if (marks == 1 ||
          (level >= QuestMasteryTier.masterwork.index && i == 0)) {
        final half =
            size.shortestSide *
            (level >= QuestMasteryTier.masterwork.index ? 0.070 : 0.060);
        final diamondAt =
            center + Offset.fromDirection(angle, outerRadius - half * 0.55);
        final diamond = Path()
          ..moveTo(diamondAt.dx, diamondAt.dy - half)
          ..lineTo(diamondAt.dx + half * 0.72, diamondAt.dy)
          ..lineTo(diamondAt.dx, diamondAt.dy + half)
          ..lineTo(diamondAt.dx - half * 0.72, diamondAt.dy)
          ..close();
        canvas.drawPath(
          diamond,
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF0D59B), Color(0xFF8D5D30)],
            ).createShader(diamond.getBounds()),
        );
        canvas.drawPath(
          diamond,
          Paint()
            ..color = const Color(0xB3472D18)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.65,
        );
      } else if (longMark) {
        final inward = at - Offset.fromDirection(angle, halfLength);
        final outward = at + Offset.fromDirection(angle, halfLength);
        canvas.drawLine(
          inward,
          outward,
          Paint()
            ..color = const Color(0xFFCA9A59)
            ..strokeWidth = size.shortestSide * 0.022
            ..strokeCap = StrokeCap.round,
        );
      } else {
        canvas.drawCircle(
          at,
          size.shortestSide * 0.031,
          Paint()..color = const Color(0xFFD1A463),
        );
        canvas.drawCircle(
          at,
          size.shortestSide * 0.031,
          Paint()
            ..color = const Color(0x9950331D)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.6,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_CheckRingPainter old) =>
      old.stat != stat ||
      old.done != done ||
      old.progress != progress ||
      old.accent != accent ||
      old.showReadyCheck != showReadyCheck ||
      old.masteryTier != masteryTier ||
      old.shine != shine ||
      old.light != light;
}

class _MetaChip extends StatelessWidget {
  const _MetaChip(this.icon, this.text, this.color, {this.maxWidth});

  final IconData? icon;
  final String text;
  final Color color;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 3),
        ],
        Text(
          text,
          style: Type.label.copyWith(
            fontSize: Type.minLabel,
            letterSpacing: 0.72,
            color: color,
          ),
        ),
      ],
    );
    // Compact metadata is the one bounded text role allowed to shrink. Keep
    // truthful metadata readable on narrow cards instead of letting a long
    // all-caps chip force the whole Quest row past its edge. At larger text
    // sizes the source text has already grown, so scaleDown only gives back the
    // few pixels the card cannot hold; it does not impose a fixed text scale.
    final fitted = FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: content,
    );
    if (maxWidth == null) return fitted;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth!),
      child: fitted,
    );
  }
}

class _XpChip extends StatelessWidget {
  const _XpChip({required this.xp, required this.dim, required this.featured});

  final int xp;
  final bool dim;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    final alpha = dim ? 0.42 : 1.0;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: featured ? 10 : 7,
        vertical: featured ? 6 : 5,
      ),
      decoration: facetedDecoration(
        cut: featured ? 7 : 6,
        // A dark plaque with a brass rim. Filling it with honey made a second
        // gold surface compete with the action on the same card.
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Palette.xp.withValues(alpha: 0.15 * alpha),
            const Color(0xFF3A2311).withValues(alpha: 0.86 * alpha),
          ],
        ),
        borderColor: Palette.brass.withValues(alpha: 0.92 * alpha),
        borderWidth: 0.9,
      ),
      child: Text(
        '+$xp XP',
        maxLines: 1,
        style: Type.numerals.copyWith(
          fontSize: featured ? 15.5 : 13.5,
          color: Palette.xp.withValues(alpha: alpha),
        ),
      ),
    );
  }
}

class _EncoreButton extends StatelessWidget {
  const _EncoreButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 42, minWidth: 48),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: facetedDecoration(
          cut: 7,
          color: Palette.streak.withValues(alpha: 0.08),
          borderColor: Palette.streak.withValues(alpha: 0.52),
        ),
        child: const Icon(Icons.bolt_rounded, size: 18, color: Palette.streak),
      ),
    );
  }
}
