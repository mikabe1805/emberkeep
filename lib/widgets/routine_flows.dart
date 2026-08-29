import 'dart:math';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio.dart';
import '../clock.dart';
import '../content/creature_skins.dart';
import '../content/day_planning.dart';
import '../content/messages.dart';
import '../engine.dart';
import '../models.dart';
import '../storage.dart';
import '../tokens.dart';
import 'ember_flame_icon.dart';
import 'ember_sheet.dart';
import 'facets.dart';
import 'glass.dart';
import 'gold_surface.dart';
import 'honey_button.dart';
import 'night_reflection_sheet.dart';
import 'routine_ledger.dart';

/// The night routine (round-5): goodnight → animated recap of today's haul
/// (XP up, stats up, goal bars inching toward full) → plan tomorrow (star
/// MAIN quests, add one-time quests) → sleep. Closing stamps the day so the
/// morning briefing knows to greet you.
class NightFlow extends StatefulWidget {
  const NightFlow({
    super.key,
    required this.state,
    required this.quests,
    required this.onAdd,
    required this.onPersist,
    required this.onClose,
  });

  final GameState state;
  final List<Quest> quests;
  final bool Function(Quest) onAdd;
  final VoidCallback onPersist;
  final VoidCallback onClose;

  @override
  State<NightFlow> createState() => _NightFlowState();
}

class _NightFlowState extends State<NightFlow> {
  int _step = 0;
  bool _closing = false;
  bool _showAllFinished = false;
  late final String _line = RewardMessages.night(Random());

  /// Lines logged as "not today" this session — shown warm, never red
  /// (AVE-safe: a slip is data, not failure).
  final Set<Quest> _slipped = {};

  bool get _reduceMotion =>
      widget.state.reduceMotion ||
      (MediaQuery.maybeDisableAnimationsOf(context) ?? false);

  bool get _hasNightPage => widget.state.nightDraftNote?.night != null;

  Future<void> _keepNightReflection() async {
    final s = widget.state;
    final data = await showNightReflectionSheet(
      context,
      initial: s.nightDraftNote?.night,
      reduceMotion: _reduceMotion,
    );
    if (data == null || !mounted) return;
    s.saveNightJournal(data, s.nightJournalTrace(widget.quests));
    widget.onPersist();
    Storage.logEvent('night_reflection', [
      if (data.reflection?.trim().isNotEmpty ?? false) 0,
      if (data.normalizedGratitudes.isNotEmpty) 1,
      if (data.discovery?.trim().isNotEmpty ?? false) 2,
      if (data.tomorrowMessage?.trim().isNotEmpty ?? false) 3,
    ]);
    setState(() {});
  }

  Future<void> _finish() async {
    if (_closing) return;
    setState(() => _closing = true);
    Sfx.instance.playAfterContact('streak');
    HapticFeedback.mediumImpact();
    if (!_reduceMotion) {
      await Future<void>.delayed(const Duration(milliseconds: 430));
    }
    if (!mounted) return;
    widget.state.finalizeNightJournal(
      widget.state.nightJournalTrace(widget.quests),
    );
    widget.state.closeNight(); // stamps the night + arms tomorrow's morning
    widget.onPersist();
    widget.onClose();
  }

  /// What tomorrow already holds: recurring quests scheduled on that day
  /// (round-7: weekday/month-day aware) and events due by tomorrow.
  List<Quest> _tomorrowQuests() {
    final tomorrow = Days.afterNight(Clock.now());
    return planningQuestsForDay(
      widget.quests,
      tomorrow,
    ).where((quest) => !quest.allDay).toList();
  }

  List<Quest> _orderedPriorities(List<Quest> quests, DateTime day) {
    final sourceOrder = <Quest, int>{
      for (var index = 0; index < quests.length; index++) quests[index]: index,
    };
    final chosen = quests.where((quest) => quest.priorityOn(day)).toList()
      ..sort((a, b) {
        final byRank = a.priorityRankOn(day).compareTo(b.priorityRankOn(day));
        if (byRank != 0) return byRank;
        return sourceOrder[a]!.compareTo(sourceOrder[b]!);
      });
    return chosen.take(3).toList();
  }

  void _normalizePriorityRanks(List<Quest> quests, DateTime day) {
    final chosen = _orderedPriorities(quests, day);
    for (var index = 0; index < chosen.length; index++) {
      chosen[index].priorityRank = index + 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _step == 0 ? 'Close the ledger' : 'Mark tomorrow';
    return RoutineLedgerScaffold(
      time: RoutineTime.night,
      title: title,
      dateLabel: _routineDateLabel(Days.nightDate(Clock.now())),
      dismissLabel: 'NOT YET',
      onDismiss: () {
        Sfx.instance.playMaterial(MaterialSound.glass);
        widget.onClose();
      },
      reduceMotion: _reduceMotion,
      scrollKey: const ValueKey('recap'),
      builder: (context, parallax, light, scroll, entrance) {
        return RoutineLedgerPage(
          time: RoutineTime.night,
          parallax: parallax,
          light: light,
          scroll: scroll,
          entrance: entrance,
          closing: _closing,
          primaryLabel: _step == 0 ? 'CLOSE THE DAY' : 'KEEP THESE THREE',
          onPrimary: _step == 0
              ? _finish
              : () {
                  setState(() => _step = 0);
                },
          secondaryLabel: _step == 0
              ? (_hasNightPage ? 'edit tonight’s page' : 'reflect · optional')
              : 'back to recap',
          onSecondary: _step == 0
              ? _keepNightReflection
              : () {
                  setState(() => _step = 0);
                },
          child: AnimatedSwitcher(
            duration: _reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 460),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              if (_reduceMotion) {
                return FadeTransition(opacity: animation, child: child);
              }
              final turn = Tween<double>(
                begin: -0.13,
                end: 0,
              ).animate(animation);
              return FadeTransition(
                opacity: animation,
                child: AnimatedBuilder(
                  animation: turn,
                  child: child,
                  builder: (context, page) => Transform(
                    alignment: Alignment.centerLeft,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.0012)
                      ..rotateY(turn.value),
                    child: page,
                  ),
                ),
              );
            },
            child: _step == 0 ? _ledgerRecap(context) : _ledgerPlanner(context),
          ),
        );
      },
    );
  }

  Widget _ledgerRecap(BuildContext context) {
    final s = widget.state;
    final done = s.nightCompletionCount;
    final statGains = s.nightStatGains.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final shownGains = statGains.take(3).toList();
    final openAllDay = _openAllDay();
    final risers = _readyToRise();
    final tomorrow = _tomorrowQuests();
    final selected = _orderedPriorities(tomorrow, Days.afterNight(Clock.now()));

    return LayoutBuilder(
      builder: (context, bounds) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final accessibilityText = textScale > 1.15;
        final veryLargeText = textScale >= 1.75;
        final compact = bounds.maxWidth < 300 || accessibilityText;
        final tomorrowTray = _LedgerTomorrowTray(
          selected: selected,
          compact: compact,
          onTap: () {
            Sfx.instance.play('tick_warm');
            HapticFeedback.selectionClick();
            setState(() => _step = 1);
          },
        );

        return SizedBox.expand(
          key: const ValueKey('ledger-recap'),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: Column(
                  children: [
                    LedgerSectionTitle(
                      label: 'WHAT MOVED',
                      morning: false,
                      color: Palette.brassLit.withValues(alpha: 0.76),
                    ),
                    SizedBox(height: compact ? 4 : 13),
                    TweenAnimationBuilder<int>(
                      tween: IntTween(begin: 0, end: s.nightXp),
                      duration: _reduceMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 1050),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) => Text(
                        '+$value XP',
                        style: Type.numerals.copyWith(
                          fontSize: compact ? 34 : 42,
                          height: 1,
                          color: Palette.xpLight,
                          shadows: const [
                            Shadow(
                              color: Color(0x5AE0A865),
                              blurRadius: 12,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: compact ? 5 : 12),
                    if (statGains.isEmpty)
                      Text(
                        'the quiet days still count',
                        style: LedgerType.body.copyWith(
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          color: Palette.textLo,
                        ),
                      )
                    else
                      SizedBox(
                        height: compact ? 47 : 58,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (
                              var index = 0;
                              index < shownGains.length;
                              index++
                            ) ...[
                              Expanded(
                                child: _LedgerStatGain(
                                  stat: shownGains[index].key,
                                  gain: shownGains[index].value,
                                  morning: false,
                                  compact: compact,
                                ),
                              ),
                              if (index != shownGains.length - 1)
                                Container(
                                  width: 1,
                                  height: compact ? 33 : 42,
                                  color: Palette.brass.withValues(alpha: 0.34),
                                ),
                            ],
                          ],
                        ),
                      ),
                    SizedBox(height: compact ? 7 : 14),
                    LedgerSectionTitle(
                      label:
                          '${_ledgerCountWord(done)} THREAD${done == 1 ? '' : 'S'} FINISHED',
                      morning: false,
                    ),
                    SizedBox(height: compact ? 3 : 6),
                    _FinishedThreadsLedger(
                      titles: s.nightQuestTitles,
                      expanded: _showAllFinished,
                      onExpand: () => setState(() => _showAllFinished = true),
                      onCollapse: () =>
                          setState(() => _showAllFinished = false),
                      compact: compact,
                    ),
                    if (risers.isNotEmpty)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => _showRisers(context, risers),
                          style: TextButton.styleFrom(
                            minimumSize: const Size(44, 32),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            foregroundColor: Palette.streak,
                          ),
                          icon: const Icon(Icons.trending_up_rounded, size: 14),
                          label: Text(
                            '${risers.length} ready to rise',
                            style: Type.label.copyWith(
                              fontSize: Type.minLabel,
                              color: Palette.streak,
                            ),
                          ),
                        ),
                      )
                    else
                      SizedBox(height: compact ? 3 : 6),
                    if (openAllDay.isNotEmpty) ...[
                      _AllDayLedgerLine(
                        quest: openAllDay.first,
                        xp: s.xpPreview(openAllDay.first),
                        onHeld: () => _confirmAllDay(openAllDay.first),
                        onNotToday: () => _logSlip(openAllDay.first),
                        remaining: openAllDay.length - 1,
                        compact: compact,
                      ),
                      SizedBox(height: compact ? 4 : 10),
                    ],
                    if (compact) ...[
                      const Spacer(),
                      SizedBox(
                        height: veryLargeText
                            ? 180
                            : (accessibilityText ? 84 : 92),
                        child: tomorrowTray,
                      ),
                    ],
                  ],
                ),
              ),
              if (!compact)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 126,
                  child: tomorrowTray,
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _ledgerPlanner(BuildContext context) {
    final tomorrowDay = Days.afterNight(Clock.now());
    final tomorrowKey = Days.key(tomorrowDay);
    final tomorrow = _tomorrowQuests();
    final ordered = _orderedPriorities(tomorrow, tomorrowDay);
    final chosenCount = ordered.length;

    return SizedBox.expand(
      key: const ValueKey('ledger-planner'),
      child: Column(
        children: [
          LedgerSectionTitle(
            label: 'KEEP THREE CLOSE · ${chosenCount.clamp(0, 3)}/3',
            morning: false,
            color: Palette.brassLit.withValues(alpha: 0.76),
          ),
          const SizedBox(height: 6),
          Text(
            'These become the first page you see tomorrow.',
            textAlign: TextAlign.center,
            style: LedgerType.body.copyWith(
              fontSize: 12.5,
              height: 1.25,
              fontStyle: FontStyle.italic,
              color: Palette.textLo,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: tomorrow.isEmpty
                ? Center(
                    child: Text(
                      'Tomorrow is still open.',
                      style: LedgerType.body.copyWith(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: Palette.textLo,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    physics: const BouncingScrollPhysics(),
                    itemCount: tomorrow.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final quest = tomorrow[index];
                      final selected = quest.priorityOn(tomorrowDay);
                      return _LedgerChoiceRow(
                        quest: quest,
                        selected: selected,
                        rank: selected ? ordered.indexOf(quest) + 1 : null,
                        onTap: () {
                          if (!selected && chosenCount >= 3) {
                            Sfx.instance.play('boing');
                            HapticFeedback.lightImpact();
                            return;
                          }
                          Sfx.instance.play(selected ? 'tick' : 'tick_warm');
                          HapticFeedback.selectionClick();
                          setState(() {
                            if (selected) {
                              quest.priority = false;
                              quest.priorityDay = null;
                              quest.priorityRank = null;
                            } else {
                              quest.priority = false;
                              quest.priorityDay = tomorrowKey;
                              quest.priorityRank = chosenCount + 1;
                            }
                            _normalizePriorityRanks(tomorrow, tomorrowDay);
                          });
                          widget.onPersist();
                        },
                      );
                    },
                  ),
          ),
          const SizedBox(height: 7),
          TextButton.icon(
            onPressed: _addTomorrowQuest,
            style: TextButton.styleFrom(
              foregroundColor: Palette.xpLight,
              minimumSize: const Size(44, 38),
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            icon: const Icon(Icons.add_rounded, size: 16),
            label: Text(
              'ADD A THREAD FOR TOMORROW',
              style: Type.label.copyWith(
                fontSize: Type.minLabel,
                color: Palette.xpLight,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addTomorrowQuest() async {
    final quest = await showEmberSheet(
      context,
      EmberSheetConfig(
        surface: EmberSurface.tomorrow,
        targetDay: Days.afterNight(Clock.now()),
      ),
    );
    if (quest == null || !mounted) return;
    if (widget.onAdd(quest)) {
      Sfx.instance.play('streak');
      HapticFeedback.selectionClick();
      widget.onPersist();
      setState(() {});
    } else {
      Sfx.instance.play('boing');
      HapticFeedback.lightImpact();
    }
  }

  Future<void> _showRisers(BuildContext context, List<Quest> risers) {
    return showDialog<void>(
      context: context,
      barrierColor: Palette.dialogBarrier,
      builder: (dialogContext) => Dialog(
        backgroundColor: Palette.dialogSurface,
        shape: const FacetedBorder(cut: 14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ready to rise', style: Type.display.copyWith(fontSize: 24)),
              const SizedBox(height: 5),
              Text(
                'You have held these long enough to choose a new rung.',
                style: Type.body.copyWith(fontSize: 13, color: Palette.textLo),
              ),
              const SizedBox(height: 14),
              for (final quest in risers)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        quest.displayTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Type.body.copyWith(
                          fontSize: 14,
                          color: Palette.textHi,
                        ),
                      ),
                      if (quest.canRise)
                        Text(
                          'next · ${quest.ladder![quest.rung + 1]}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Type.body.copyWith(
                            fontSize: 12,
                            color: Palette.streak,
                          ),
                        ),
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          FilledButton(
                            onPressed: () {
                              Navigator.of(dialogContext).pop();
                              _rise(quest);
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: Palette.xp,
                              foregroundColor: Palette.onHoney,
                            ),
                            child: const Text('RISE'),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () {
                              Navigator.of(dialogContext).pop();
                              _notYet(quest);
                            },
                            child: const Text('NOT YET'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// All-day abstention quests still unconfirmed today. A "hide just for
  /// today" snooze excludes them — a line you chose to skip is never offered
  /// for reward at night.
  List<Quest> _openAllDay() {
    final now = Clock.now();
    final night = Days.nightDate(now);
    // Confirming a previous day's all-day line would credit the completion to
    // the new calendar day. Keep the after-midnight recap honest and read-only.
    if (!Days.sameDay(now, night)) return const [];
    final endOfToday = DateTime(night.year, night.month, night.day, 23, 59, 59);
    final today = Days.key(night);
    return [
      for (final q in widget.quests)
        if (q.allDay &&
            q.snoozedDay != today &&
            !q.doneFor(night) &&
            (q.isEvent
                ? !q.dueDate!.isAfter(endOfToday)
                : q.scheduledOn(night)) &&
            !_slipped.contains(q))
          q,
    ];
  }

  /// Shame-free slip logging: no XP, no loss, no red — tomorrow is fresh.
  void _logSlip(Quest q) {
    Sfx.instance.playInteraction(InteractionSound.select);
    setState(() => _slipped.add(q));
  }

  /// Rising quests that have earned a climb (5 holds since last rise).
  List<Quest> _readyToRise() => [
    for (final q in widget.quests)
      if (q.readyToRise) q,
  ];

  /// A forward pull for tomorrow — the streak that continues, the goal that's
  /// nearly there. End the night on anticipation, not just accounting
  /// (RESEARCH-momentum.md §7). Empty when there's nothing warm to tease.
  Widget _tomorrowHook(GameState s) {
    final hooks = <String>[];
    if (s.streakDays > 0) {
      hooks.add('continue the rhythm: day ${s.streakDays + 1} tomorrow');
    }
    Goal? near;
    var bestGap = 1 << 30;
    for (final g in s.goals) {
      if (g.complete) continue;
      final gap = g.target - g.progress;
      if (gap > 0 && gap < bestGap) {
        bestGap = gap;
        near = g;
      }
    }
    if (near != null && bestGap <= 5) {
      hooks.add(
        '“${near.title}” is $bestGap quest${bestGap == 1 ? "" : "s"} from a milestone',
      );
    }
    if (hooks.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: GlassPanel(
        glow: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'WAITING FOR TOMORROW',
              style: Type.label.copyWith(fontSize: 11, color: Palette.streak),
            ),
            const SizedBox(height: 6),
            for (final h in hooks)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  h,
                  style: Type.body.copyWith(
                    fontSize: 13.5,
                    color: Palette.textMid,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _rise(Quest q) {
    Sfx.instance.play('levelup');
    HapticFeedback.mediumImpact();
    setState(() {
      // climb the concrete ladder when there's a rung left (the visible
      // prescription advances, e.g. 5 → 8 push-ups); difficulty rises with it
      if (q.canRise) {
        q.rung++;
        q.difficulty = (q.difficulty + 1).clamp(1, q.custom ? 8 : 10);
      }
      q.risingStreak = 0;
    });
    widget.onPersist();
  }

  void _notYet(Quest q) {
    Sfx.instance.playMaterial(MaterialSound.glass);
    // ask again after a couple more honest completions — never nag
    setState(() => q.risingStreak = Quest.risesAt - 2);
    widget.onPersist();
  }

  /// The honest close-out: confirming an all-day line commits its reward
  /// immediately (compact — the recap numbers absorb it live).
  void _confirmAllDay(Quest q) {
    final s = widget.state;
    final bundle = s.roll(q);
    s.commit(bundle);
    widget.onPersist();
    Sfx.instance.playCompletionAccepted(transitionId: q);
    HapticFeedback.mediumImpact();
    setState(() {});
  }

  // ── step 1: the day, replayed ─────────────────────────────────────
  // ignore: unused_element
  Widget _recap(BuildContext context) {
    final s = widget.state;
    final done = s.nightCompletionCount;
    final openAllDay = _openAllDay();
    final risers = _readyToRise();
    return ListView(
      key: const ValueKey('recap'),
      children: [
        const SizedBox(height: 18),
        const Center(
          child: Icon(Icons.nightlight_round, size: 40, color: Palette.xpLight),
        ),
        const SizedBox(height: 10),
        Center(
          child: Text(
            s.playerName == null ? 'Goodnight' : 'Goodnight, ${s.playerName}',
            style: Type.display.copyWith(fontSize: 30),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              _line,
              textAlign: TextAlign.center,
              style: Type.body.copyWith(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: Palette.textLo,
              ),
            ),
          ),
        ),
        const SizedBox(height: 22),

        // ── the all-day line: confirmed only now, honestly ─────────
        if (openAllDay.isNotEmpty) ...[
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.nightlight_round,
                      size: 13,
                      color: Palette.unlock,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'HOW DID THE ALL-DAY LINE GO?',
                      style: Type.label.copyWith(
                        fontSize: 11,
                        color: Palette.unlock,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'only count what truly held — a slip is data, not failure',
                  style: Type.body.copyWith(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: Palette.textLo,
                  ),
                ),
                const SizedBox(height: 10),
                for (final q in openAllDay)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                q.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Type.body.copyWith(
                                  fontSize: 13.5,
                                  color: Palette.textHi,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '+${widget.state.xpPreview(q)} XP',
                              style: Type.numerals.copyWith(
                                fontSize: 11,
                                color: Palette.xp,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () => _confirmAllDay(q),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 11,
                                  vertical: 6,
                                ),
                                decoration: facetedDecoration(
                                  cut: 7,
                                  color: Colors.transparent,
                                  borderColor: Palette.success.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                                child: Text(
                                  'HELD IT',
                                  style: Type.label.copyWith(
                                    fontSize: 11,
                                    color: Palette.success,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () => _logSlip(q),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 11,
                                  vertical: 6,
                                ),
                                decoration: facetedDecoration(
                                  cut: 7,
                                  color: Colors.transparent,
                                  borderColor: Palette.textLo.withValues(
                                    alpha: 0.4,
                                  ),
                                ),
                                child: Text(
                                  'NOT TODAY',
                                  style: Type.label.copyWith(fontSize: 11),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                for (final q in _slipped)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.spa_outlined,
                          size: 13,
                          color: Palette.textLo,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            '${q.title} — logged. you did your best today; tomorrow’s line is fresh.',
                            style: Type.body.copyWith(
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                              color: Palette.textLo,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // ── ready to rise: you've outgrown a rung ───────────────────
        if (risers.isNotEmpty) ...[
          GlassPanel(
            glow: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.trending_up,
                      size: 14,
                      color: Palette.streak,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'READY TO RISE?',
                      style: Type.label.copyWith(
                        fontSize: 11,
                        color: Palette.streak,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'you’ve held these ${Quest.risesAt} times — the next rung is yours if you want it',
                  style: Type.body.copyWith(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: Palette.textLo,
                  ),
                ),
                const SizedBox(height: 10),
                for (final q in risers)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    q.displayTitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Type.body.copyWith(
                                      fontSize: 13.5,
                                      color: Palette.textHi,
                                    ),
                                  ),
                                  if (q.canRise)
                                    Text(
                                      '→ ${q.ladder![q.rung + 1]}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Type.body.copyWith(
                                        fontSize: 11,
                                        color: Palette.streak,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (!q.canRise) ...[
                              const SizedBox(width: 8),
                              Text(
                                'd${q.difficulty} → d${(q.difficulty + 1).clamp(1, q.custom ? 8 : 10)}',
                                style: Type.numerals.copyWith(
                                  fontSize: 11,
                                  color: Palette.streak,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () => _rise(q),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 11,
                                  vertical: 6,
                                ),
                                decoration: facetedDecoration(
                                  cut: 7,
                                  gradient: Palette.honeyGradient,
                                ),
                                child: Text(
                                  'RISE',
                                  style: Type.label.copyWith(
                                    fontSize: 11,
                                    color: Palette.onHoney,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () => _notYet(q),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 11,
                                  vertical: 6,
                                ),
                                decoration: facetedDecoration(
                                  cut: 7,
                                  color: Colors.transparent,
                                  borderColor: Palette.textLo.withValues(
                                    alpha: 0.4,
                                  ),
                                ),
                                child: Text(
                                  'NOT YET',
                                  style: Type.label.copyWith(fontSize: 11),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // XP count-up — the day's number, made physical
        GlassPanel(
          child: Column(
            children: [
              Text(
                'TODAY YOU EARNED',
                style: Type.label.copyWith(fontSize: 11),
              ),
              const SizedBox(height: 6),
              TweenAnimationBuilder<int>(
                tween: IntTween(begin: 0, end: s.nightXp),
                duration: const Duration(milliseconds: 1100),
                curve: Curves.easeOutCubic,
                builder: (_, v, _) => Text(
                  '+$v XP',
                  style: Type.numerals.copyWith(
                    fontSize: 44,
                    color: Palette.xpLight,
                  ),
                ),
              ),
              Text(
                '$done quest${done == 1 ? "" : "s"} · streak day ${s.streakDays}'
                '${s.bestStreak > s.streakDays ? " · best ${s.bestStreak}" : ""}'
                '${s.streakFreezes > 0 ? " · ${s.streakFreezes} freezes ready" : ""}',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Type.body.copyWith(fontSize: 13, color: Palette.textLo),
              ),
              const SizedBox(height: 12),
              MomentumStrip(history: s.history, frozenDays: s.frozenStreakDays),
              if (s.nightStatGains.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final e in s.nightStatGains.entries)
                      _PopIn(
                        delayMs:
                            500 +
                            140 * s.nightStatGains.keys.toList().indexOf(e.key),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: facetedDecoration(
                            cut: 6,
                            color: Colors.transparent,
                            borderColor: e.key.color.withValues(alpha: 0.6),
                          ),
                          child: Text(
                            '+${e.value} ${e.key.abbr}',
                            style: Type.numerals.copyWith(
                              fontSize: 12,
                              color: e.key.color,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),

        // goal bars inching toward full
        if (s.goals.isNotEmpty)
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'YOUR GOALS, CLOSER',
                  style: Type.label.copyWith(fontSize: 11),
                ),
                const SizedBox(height: 10),
                for (final g in s.goals.take(4)) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          g.title,
                          overflow: TextOverflow.ellipsis,
                          style: Type.body.copyWith(
                            fontSize: 13,
                            color: Palette.textHi,
                          ),
                        ),
                      ),
                      Text(
                        '${g.progress}/${g.target}',
                        style: Type.numerals.copyWith(
                          fontSize: 11,
                          color: g.stat.color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: g.fraction),
                    duration: const Duration(milliseconds: 1200),
                    curve: Curves.easeInOutCubic,
                    builder: (_, v, _) => FacetedMeter(
                      value: v,
                      height: 7,
                      background: Palette.railTrack,
                      color: g.stat.color,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        if (done > 0) ...[
          const SizedBox(height: 12),
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CLEARED TODAY', style: Type.label.copyWith(fontSize: 11)),
                const SizedBox(height: 8),
                for (final t in s.nightQuestTitles.take(8))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check,
                          size: 13,
                          color: Palette.success,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            t,
                            overflow: TextOverflow.ellipsis,
                            style: Type.body.copyWith(
                              fontSize: 13,
                              color: Palette.textMid,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        _tomorrowHook(s),
        const SizedBox(height: 18),
        Center(
          child: _BigButton(
            label: 'PLAN TOMORROW →',
            onTap: () {
              setState(() => _step = 1);
            },
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: _finish,
            child: Text('just sleep', style: Type.label.copyWith(fontSize: 11)),
          ),
        ),
      ],
    );
  }

  // ── step 2: tomorrow, planned ────────────────────────────────────
  // ignore: unused_element
  Widget _planner(BuildContext context) {
    final tomorrow = _tomorrowQuests();
    final tomorrowDay = Days.afterNight(Clock.now());
    final tomorrowKey = Days.key(tomorrowDay);
    final chosenCount = tomorrow.where((q) => q.priorityOn(tomorrowDay)).length;
    return ListView(
      key: const ValueKey('planner'),
      children: [
        const SizedBox(height: 18),
        Center(
          child: Text('Tomorrow', style: Type.display.copyWith(fontSize: 28)),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            'choose up to three — the morning leads with them',
            style: Type.body.copyWith(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: Palette.textLo,
            ),
          ),
        ),
        const SizedBox(height: 16),
        GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ALREADY ON THE BOARD · ${chosenCount.clamp(0, 3)}/3 MAIN',
                style: Type.label.copyWith(fontSize: 11),
              ),
              const SizedBox(height: 8),
              for (final q in tomorrow)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Transform.rotate(
                        angle: 0.785,
                        child: Container(
                          width: 7,
                          height: 7,
                          color: q.stat.color,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          q.displayTitle,
                          overflow: TextOverflow.ellipsis,
                          style: Type.body.copyWith(
                            fontSize: 13.5,
                            color: Palette.textHi,
                          ),
                        ),
                      ),
                      Flexible(
                        child: Text(
                          q.bonus
                              ? 'BONUS'
                              : (q.isEvent ? 'DUE' : q.schedule.label),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Type.label.copyWith(fontSize: 11),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          final selected = q.priorityOn(tomorrowDay);
                          if (!selected && chosenCount >= 3) {
                            Sfx.instance.play('boing');
                            HapticFeedback.lightImpact();
                            return;
                          }
                          Sfx.instance.playMaterial(MaterialSound.glass);
                          HapticFeedback.selectionClick();
                          setState(() {
                            if (selected) {
                              q.priority = false;
                              q.priorityDay = null;
                            } else {
                              q.priority = false;
                              q.priorityDay = tomorrowKey;
                            }
                          });
                          // persist NOW — backing out via "NOT YET" is a
                          // supported exit and must not drop tonight's stars
                          widget.onPersist();
                        },
                        child: Icon(
                          q.priorityOn(tomorrowDay)
                              ? Icons.star
                              : Icons.star_border,
                          size: 20,
                          color: q.priorityOn(tomorrowDay)
                              ? Palette.xpLight
                              : Palette.textLo,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _TomorrowAdder(onAdd: widget.onAdd),
        const SizedBox(height: 18),
        Center(
          child: _BigButton(label: 'GOODNIGHT 🌙', onTap: _finish),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// Quick one-time quest for tomorrow, right from the night planner.
class _TomorrowAdder extends StatefulWidget {
  const _TomorrowAdder({required this.onAdd});
  final bool Function(Quest) onAdd;

  @override
  State<_TomorrowAdder> createState() => _TomorrowAdderState();
}

class _TomorrowAdderState extends State<_TomorrowAdder> {
  final List<String> _added = [];

  void _add() async {
    final q = await showEmberSheet(
      context,
      EmberSheetConfig(
        surface: EmberSurface.tomorrow,
        targetDay: Days.afterNight(Clock.now()),
      ),
    );
    if (q == null) return;
    final ok = widget.onAdd(q);
    if (ok) {
      Sfx.instance.play('streak');
      setState(() => _added.add(q.title));
    } else {
      Sfx.instance.play('boing');
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TOMORROW, PLANNED', style: Type.label.copyWith(fontSize: 11)),
          for (final t in _added)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  const Icon(Icons.star, size: 14, color: Palette.xpLight),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      t,
                      overflow: TextOverflow.ellipsis,
                      style: Type.body.copyWith(
                        fontSize: 13,
                        color: Palette.textMid,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _add,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              alignment: Alignment.center,
              decoration: facetedDecoration(
                cut: 10,
                color: Palette.glassFill,
                borderColor: Palette.glassEdge,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add, size: 16, color: Palette.xpLight),
                  const SizedBox(width: 8),
                  Text(
                    'Add a quest for tomorrow',
                    style: Type.body.copyWith(
                      fontSize: 14,
                      color: Palette.textMid,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The morning briefing: greet, lead with the starred MAIN quests, show the
/// XP on the table, send them off with a clear head.
class MorningFlow extends StatefulWidget {
  const MorningFlow({
    super.key,
    required this.state,
    required this.quests,
    required this.onClose,
    this.onDismiss,
  });

  final GameState state;
  final List<Quest> quests;
  final VoidCallback onClose;
  final VoidCallback? onDismiss;

  @override
  State<MorningFlow> createState() => _MorningFlowState();
}

class _MorningFlowState extends State<MorningFlow> {
  late EnergyWeather _weather;
  bool _closing = false;

  bool get _reduceMotion =>
      widget.state.reduceMotion ||
      (MediaQuery.maybeDisableAnimationsOf(context) ?? false);

  @override
  void initState() {
    super.initState();
    final currentDay = widget.state.energyWeatherDay == Days.key(Clock.now());
    _weather = currentDay ? widget.state.energyWeather : EnergyWeather.steady;
  }

  List<Quest> _openQuests(DateTime now) {
    final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final today = Days.key(now);
    return [
      for (final quest in widget.quests)
        if (quest.snoozedDay != today &&
            !quest.doneFor(now) &&
            (quest.isEvent
                ? !quest.dueDate!.isAfter(endOfToday)
                : quest.scheduledOn(now)))
          quest,
    ];
  }

  List<Quest> _leadQuests(List<Quest> open, DateTime now) {
    if (_weather == EnergyWeather.low) {
      final byTitle = {for (final quest in open) quest.title: quest};
      final saved = [
        for (final title in widget.state.lowFlameQuestTitles)
          if (byTitle[title] case final Quest quest) quest,
      ];
      if (saved.isNotEmpty) return saved.take(3).toList();
      return suggestedLowFlameQuests(open, now);
    }

    final main =
        open.where((quest) => quest.priorityOn(now) && !quest.allDay).toList()
          ..sort((a, b) {
            final byRank = a
                .priorityRankOn(now)
                .compareTo(b.priorityRankOn(now));
            if (byRank != 0) return byRank;
            return open.indexOf(a).compareTo(open.indexOf(b));
          });
    final side = open
        .where((quest) => !quest.priorityOn(now) && !quest.allDay)
        .toList();
    return [...main, ...side].take(3).toList();
  }

  void _chooseWeather(EnergyWeather weather, List<Quest> open, DateTime now) {
    if (_weather == weather) return;
    Sfx.instance.play(weather == EnergyWeather.low ? 'tick_warm' : 'tick');
    HapticFeedback.selectionClick();
    setState(() {
      _weather = weather;
      widget.state.setEnergyWeather(weather);
      if (weather == EnergyWeather.low) {
        widget.state.setLowFlameQuests(
          suggestedLowFlameQuests(open, now).map((quest) => quest.title),
        );
      }
    });
  }

  Future<void> _finish() async {
    if (_closing) return;
    setState(() => _closing = true);
    Sfx.instance.playAfterContact('tick_lift');
    HapticFeedback.mediumImpact();
    if (!_reduceMotion) {
      await Future<void>.delayed(const Duration(milliseconds: 430));
    }
    if (mounted) widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final now = Clock.now();
    final open = _openQuests(now);
    final lead = _leadQuests(open, now);
    final allDay = open.where((quest) => quest.allDay).length;
    final nearby = open
        .where((quest) => !quest.allDay && !lead.contains(quest))
        .length;
    final selfMessage = widget.state.morningSelfMessage;

    return RoutineLedgerScaffold(
      time: RoutineTime.morning,
      title: 'Open the day',
      dateLabel: _routineDateLabel(now),
      dismissLabel: 'LATER',
      onDismiss: () {
        Sfx.instance.playMaterial(MaterialSound.glass);
        (widget.onDismiss ?? widget.onClose)();
      },
      reduceMotion: _reduceMotion,
      scrollKey: const ValueKey('morning-ledger'),
      builder: (context, parallax, light, scroll, entrance) {
        return RoutineLedgerPage(
          time: RoutineTime.morning,
          parallax: parallax,
          light: light,
          scroll: scroll,
          entrance: entrance,
          closing: _closing,
          primaryLabel: 'OPEN THE DAY',
          onPrimary: _finish,
          child: SizedBox.expand(
            key: const ValueKey('morning-ledger-content'),
            child: Column(
              children: [
                LedgerSectionTitle(
                  label: _weather == EnergyWeather.low
                      ? 'YOUR GENTLE THREE'
                      : 'YOUR THREE',
                  morning: true,
                  color: LedgerInk.pageGold,
                ),
                if (selfMessage case final message?) ...[
                  const SizedBox(height: 8),
                  _TomorrowSelfCard(message: message),
                  const SizedBox(height: 8),
                ] else
                  const SizedBox(height: 8),
                Expanded(
                  flex: 6,
                  child: lead.isEmpty
                      ? _EmptyMorningPage(onOpen: _finish)
                      : Column(
                          children: [
                            Expanded(
                              flex: 5,
                              child: _MorningLeadQuest(
                                quest: lead.first,
                                xp: widget.state.xpPreview(lead.first),
                                onBegin: _finish,
                                compact: true,
                              ),
                            ),
                            for (var index = 1; index < 3; index++)
                              Expanded(
                                flex: 4,
                                child: _MorningQuestLine(
                                  quest: index < lead.length
                                      ? lead[index]
                                      : null,
                                  xp: index < lead.length
                                      ? widget.state.xpPreview(lead[index])
                                      : null,
                                  compact: true,
                                ),
                              ),
                          ],
                        ),
                ),
                SizedBox(height: selfMessage == null ? 23 : 10),
                const LedgerSectionTitle(
                  label: 'TODAY FEELS',
                  morning: true,
                  color: LedgerInk.pageGold,
                ),
                SizedBox(height: selfMessage == null ? 9 : 5),
                Row(
                  children: [
                    for (final weather in EnergyWeather.values)
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: weather == EnergyWeather.bright ? 0 : 5,
                          ),
                          child: _CapacityLedgerTab(
                            weather: weather,
                            selected: _weather == weather,
                            light: light,
                            scroll: scroll,
                            onTap: () => _chooseWeather(weather, open, now),
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: selfMessage == null ? 14 : 6),
                Text(
                  _weather == EnergyWeather.low
                      ? 'A smaller flame is still a flame.'
                      : 'You can change this anytime.',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LedgerType.body.copyWith(
                    fontSize: 12,
                    height: 1.1,
                    fontStyle: FontStyle.italic,
                    color: LedgerInk.quiet,
                  ),
                ),
                SizedBox(height: selfMessage == null ? 26 : 12),
                _MorningFootnote(
                  nearby: nearby,
                  allDay: allDay,
                  weather: _weather,
                  // The chevron beside "N side quests waiting" promises a
                  // destination — honour it: close the brief onto the board
                  // where they actually wait.
                  onOpen: nearby > 0 ? _finish : null,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Kept temporarily as a behavior reference while the ledger implementation is
// proven against the routine regression suite.
// ignore: unused_element
class _LegacyMorningFlow extends StatelessWidget {
  const _LegacyMorningFlow({
    required this.state,
    required this.quests,
    required this.onClose,
  });

  final GameState state;
  final List<Quest> quests;
  final VoidCallback onClose;

  /// Goals within a few completions of a milestone/finish — a little "so
  /// close" pull to start the day with.
  List<Widget> _goalNudges(GameState s) {
    final near = [
      for (final g in s.goals)
        if (!g.complete && g.target - g.progress <= 3 && g.target > g.progress)
          g,
    ];
    if (near.isEmpty) return const [];
    return [
      const SizedBox(height: 12),
      GlassPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SO CLOSE', style: Type.label.copyWith(fontSize: 11)),
            const SizedBox(height: 8),
            for (final g in near)
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  children: [
                    Icon(Icons.flag, size: 12, color: g.stat.color),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        g.title,
                        overflow: TextOverflow.ellipsis,
                        style: Type.body.copyWith(
                          fontSize: 13,
                          color: Palette.textHi,
                        ),
                      ),
                    ),
                    Text(
                      '${g.target - g.progress} to go',
                      style: Type.label.copyWith(
                        fontSize: 11,
                        color: g.stat.color,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final now = Clock.now();
    final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final today = Days.key(now);
    final open = [
      for (final q in quests)
        // a "hide just for today" snooze drops it from the morning brief too
        if (q.snoozedDay != today &&
            !q.doneFor(now) &&
            (q.isEvent ? !q.dueDate!.isAfter(endOfToday) : q.scheduledOn(now)))
          q,
    ];
    final main = open.where((q) => q.priorityOn(now) && !q.allDay).toList();
    final side = open.where((q) => !q.priorityOn(now) && !q.allDay).toList();
    final allDay = open.where((q) => q.allDay).toList();
    final potential = open.fold<int>(0, (sum, q) => sum + state.xpPreview(q));
    final line = RewardMessages.morning(Random());

    return OverlaySurface(
      child: Container(
        color: const Color(0xF7191210),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: ListView(
              children: [
                // a quiet way out — mornings are sometimes a sprint, and the
                // sun icon in the header reopens the brief any time today
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onClose,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text(
                        'LATER',
                        style: Type.label.copyWith(
                          fontSize: 12,
                          color: Palette.textLo,
                        ),
                      ),
                    ),
                  ),
                ),
                const Center(
                  child: Icon(
                    Icons.wb_twilight,
                    size: 40,
                    color: Palette.streak,
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    state.playerName == null
                        ? 'Good morning'
                        : 'Good morning, ${state.playerName}',
                    style: Type.display.copyWith(fontSize: 30),
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      line,
                      textAlign: TextAlign.center,
                      style: Type.body.copyWith(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: Palette.textLo,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                GlassPanel(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              'ON THE TABLE',
                              style: Type.label.copyWith(fontSize: 11),
                            ),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                '+$potential XP',
                                maxLines: 1,
                                style: Type.numerals.copyWith(
                                  fontSize: 22,
                                  color: Palette.xpLight,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              'STREAK',
                              style: Type.label.copyWith(fontSize: 11),
                            ),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${state.streakDays}',
                                    maxLines: 1,
                                    style: Type.numerals.copyWith(
                                      fontSize: 22,
                                      color: Palette.streak,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  EmberFlameIcon(
                                    size: 22,
                                    color: flameHueFor(state),
                                  ),
                                ],
                              ),
                            ),
                            if (state.streakFreezes > 0)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.ac_unit_rounded,
                                    size: 12,
                                    color: Palette.info,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    '${state.streakFreezes} READY',
                                    style: Type.label.copyWith(
                                      fontSize: 11,
                                      color: Palette.info,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              'QUESTS',
                              style: Type.label.copyWith(fontSize: 11),
                            ),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                '${open.length}',
                                maxLines: 1,
                                style: Type.numerals.copyWith(fontSize: 22),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                GlassPanel(
                  child: MomentumStrip(
                    history: state.history,
                    frozenDays: state.frozenStreakDays,
                  ),
                ),
                ..._goalNudges(state),
                if (main.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  GlassPanel(
                    glow: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.star,
                              size: 13,
                              color: Palette.xpLight,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'MAIN QUESTS',
                              style: Type.label.copyWith(
                                fontSize: 11,
                                color: Palette.xpLight,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        for (final q in main)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Transform.rotate(
                                  angle: 0.785,
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    color: q.stat.color,
                                  ),
                                ),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: Text(
                                    q.displayTitle,
                                    style: Type.body.copyWith(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Palette.textHi,
                                    ),
                                  ),
                                ),
                                Text(
                                  '+${state.xpPreview(q)} XP',
                                  style: Type.numerals.copyWith(
                                    fontSize: 12,
                                    color: Palette.xp,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                if (allDay.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  GlassPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.nightlight_round,
                              size: 12,
                              color: Palette.unlock,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'HOLD THE LINE TODAY',
                              style: Type.label.copyWith(
                                fontSize: 11,
                                color: Palette.unlock,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        for (final q in allDay)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 5),
                            child: Row(
                              children: [
                                Transform.rotate(
                                  angle: 0.785,
                                  child: Container(
                                    width: 6,
                                    height: 6,
                                    color: q.stat.color,
                                  ),
                                ),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: Text(
                                    q.title,
                                    style: Type.body.copyWith(
                                      fontSize: 13,
                                      color: Palette.textMid,
                                    ),
                                  ),
                                ),
                                Text(
                                  'CHECKS TONIGHT',
                                  style: Type.label.copyWith(fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                if (side.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  GlassPanel(
                    child: Text(
                      '${side.length} side quest${side.length == 1 ? "" : "s"} for bonus XP along the way',
                      style: Type.body.copyWith(
                        fontSize: 13,
                        color: Palette.textMid,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Center(
                  child: _BigButton(label: "LET'S GO ☀️", onTap: onClose),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TomorrowSelfCard extends StatelessWidget {
  const _TomorrowSelfCard({required this.message});

  final String message;

  void _openFullMessage(BuildContext context) {
    Sfx.instance.playMaterial(MaterialSound.glass);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0xB8120D09),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
        child: GlassPanel(
          tint: const Color(0xF5E6D2A8),
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FROM LAST NIGHT',
                  style: LedgerType.smallCaps.copyWith(
                    fontSize: 10,
                    letterSpacing: 1.25,
                    color: LedgerInk.pageGold,
                  ),
                ),
                const SizedBox(height: 10),
                SelectableText(
                  message,
                  style: LedgerType.body.copyWith(
                    fontSize: 18,
                    height: 1.35,
                    fontStyle: FontStyle.italic,
                    color: LedgerInk.dark,
                  ),
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    child: const Text('CLOSE'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      label: 'Message from last night: $message. Open the full message.',
      onTap: () => _openFullMessage(context),
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          shape: const FacetedBorder(cut: 7),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _openFullMessage(context),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(9, 6, 7, 6),
              decoration: const ShapeDecoration(
                color: Color(0x147A5735),
                shape: FacetedBorder(
                  cut: 7,
                  side: BorderSide(color: Color(0x5C8D6A3E)),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Icon(
                      Icons.mail_outline_rounded,
                      size: 13,
                      color: LedgerInk.pageGold,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'FROM LAST NIGHT',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: LedgerType.smallCaps.copyWith(
                            fontSize: 8.5,
                            letterSpacing: 1.25,
                            color: LedgerInk.pageGold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          message,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: LedgerType.body.copyWith(
                            fontSize: 11.5,
                            height: 1.08,
                            fontStyle: FontStyle.italic,
                            color: LedgerInk.dark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.open_in_full_rounded,
                      size: 10,
                      color: LedgerInk.pageGold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _routineDateLabel(DateTime date) {
  const weekdays = [
    'MONDAY',
    'TUESDAY',
    'WEDNESDAY',
    'THURSDAY',
    'FRIDAY',
    'SATURDAY',
    'SUNDAY',
  ];
  const months = [
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ];
  return '${weekdays[date.weekday - 1]} · ${months[date.month - 1]} ${date.day}';
}

String _ledgerCountWord(int count) => switch (count) {
  0 => 'NO',
  1 => 'ONE',
  2 => 'TWO',
  3 => 'THREE',
  4 => 'FOUR',
  5 => 'FIVE',
  6 => 'SIX',
  7 => 'SEVEN',
  8 => 'EIGHT',
  9 => 'NINE',
  10 => 'TEN',
  11 => 'ELEVEN',
  12 => 'TWELVE',
  _ => '$count',
};

class _LedgerStatGain extends StatelessWidget {
  const _LedgerStatGain({
    required this.stat,
    required this.gain,
    required this.morning,
    required this.compact,
  });

  final Stat stat;
  final int gain;
  final bool morning;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    // The night source treats the three gains as one engraved brass
    // instrument. Domain color returns on parchment in the morning, where it
    // reads like ink rather than three unrelated neon accents.
    final ink = morning ? stat.color : Palette.brassLit;
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(stat.icon, size: compact ? 24 : 30, color: ink),
            SizedBox(width: compact ? 6 : 9),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stat.abbr,
                  style: Type.label.copyWith(
                    fontSize: Type.minLabel,
                    letterSpacing: 1.25,
                    color: ink,
                  ),
                ),
                Text(
                  '+$gain',
                  style: Type.numerals.copyWith(
                    fontSize: compact ? 15.5 : 19,
                    height: 1.05,
                    color: ink,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LedgerThreadLine extends StatelessWidget {
  const _LedgerThreadLine({
    required this.title,
    required this.morning,
    required this.compact,
  });

  final String title;
  final bool morning;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ink = morning ? LedgerInk.dark : Palette.textMid;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 2 : 5.5),
      child: Row(
        children: [
          Container(
            width: compact ? 15 : 17,
            height: compact ? 15 : 17,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: morning
                  ? const Color(0x0F51653E)
                  : const Color(0x1810150D),
              border: Border.all(
                color: const Color(0xFF879359).withValues(alpha: 0.88),
                width: 1,
              ),
            ),
            child: Icon(
              Icons.check_rounded,
              size: compact ? 9.5 : 11,
              color: const Color(0xFFAAB47A),
            ),
          ),
          SizedBox(width: compact ? 6 : 8),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: LedgerType.body.copyWith(
                fontSize: compact ? 12.5 : 15.5,
                height: 1.08,
                fontWeight: FontWeight.w600,
                color: ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FinishedThreadsLedger extends StatelessWidget {
  const _FinishedThreadsLedger({
    required this.titles,
    required this.expanded,
    required this.onExpand,
    required this.onCollapse,
    required this.compact,
  });

  final List<String> titles;
  final bool expanded;
  final VoidCallback onExpand;
  final VoidCallback onCollapse;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final collapsedCount = 3;
    final visible = titles.take(collapsedCount).toList();
    final remaining = titles.length - visible.length;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final largeText = textScale > 1.15;
    final height = compact
        ? (textScale >= 1.75 ? 132.0 : (largeText ? 94.0 : 82.0))
        : 112.0;

    if (titles.isEmpty) {
      return SizedBox(
        height: height,
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Nothing had to be proven today.',
              style: LedgerType.body.copyWith(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: Palette.textLo,
              ),
            ),
          ),
        ),
      );
    }

    Widget moreButton(String label, VoidCallback onPressed) => Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: Palette.xpLight,
          minimumSize: const Size(44, 25),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          label,
          style: LedgerType.body.copyWith(
            fontSize: compact ? 11.5 : 13,
            fontWeight: FontWeight.w600,
            fontStyle: FontStyle.italic,
            color: Palette.xpLight,
          ),
        ),
      ),
    );

    return SizedBox(
      height: height,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: expanded
            ? ListView(
                key: const ValueKey('all-finished-threads'),
                padding: EdgeInsets.zero,
                physics: const BouncingScrollPhysics(),
                children: [
                  for (final title in titles)
                    _LedgerThreadLine(
                      title: title,
                      morning: false,
                      compact: compact,
                    ),
                  moreButton('show fewer', onCollapse),
                ],
              )
            : Column(
                key: const ValueKey('finished-thread-summary'),
                children: [
                  for (final title in visible)
                    _LedgerThreadLine(
                      title: title,
                      morning: false,
                      compact: compact,
                    ),
                  if (remaining > 0)
                    moreButton('and $remaining more!', onExpand),
                ],
              ),
      ),
    );
  }
}

class _AllDayLedgerLine extends StatelessWidget {
  const _AllDayLedgerLine({
    required this.quest,
    required this.xp,
    required this.onHeld,
    required this.onNotToday,
    required this.remaining,
    required this.compact,
  });

  final Quest quest;
  final int xp;
  final VoidCallback onHeld;
  final VoidCallback onNotToday;
  final int remaining;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        compact ? 4 : 7,
        compact ? 5 : 5,
        compact ? 3 : 5,
        compact ? 5 : 5,
      ),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Palette.brass.withValues(alpha: 0.34)),
          bottom: BorderSide(color: Palette.brass.withValues(alpha: 0.34)),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, bounds) {
          final questCopy = Row(
            children: [
              const Icon(
                Icons.nightlight_round,
                size: 19,
                color: Color(0xFFD6C38C),
              ),
              SizedBox(width: compact ? 6 : 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      compact ? 'ALL-DAY LINE' : 'ALL-DAY LINE · +$xp XP',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Type.label.copyWith(
                        fontSize: Type.minLabel,
                        letterSpacing: 1.0,
                        color: Palette.textLo,
                      ),
                    ),
                    Text(
                      quest.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: LedgerType.body.copyWith(
                        fontSize: compact ? 11.5 : 14,
                        height: 1.05,
                        fontWeight: FontWeight.w600,
                        color: Palette.textHi,
                      ),
                    ),
                    if (remaining > 0)
                      Text(
                        '$remaining more tonight',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Type.label.copyWith(
                          fontSize: Type.minLabel,
                          color: Palette.textLo,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
          // FittedBox is the escape valve for floor-size action labels on a
          // narrow large-text phone — the pair scales down together instead
          // of running out of the ledger line.
          final actions = FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _LedgerMiniAction(label: 'HELD', onTap: onHeld, warm: true),
                const SizedBox(width: 3),
                _LedgerMiniAction(label: 'NOT TODAY', onTap: onNotToday),
              ],
            ),
          );
          if (bounds.maxWidth < 235) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                questCopy,
                const SizedBox(height: 4),
                Align(alignment: Alignment.centerRight, child: actions),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: questCopy),
              const SizedBox(width: 5),
              Flexible(child: actions),
            ],
          );
        },
      ),
    );
  }
}

class _LedgerMiniAction extends StatelessWidget {
  const _LedgerMiniAction({
    required this.label,
    required this.onTap,
    this.warm = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool warm;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        customBorder: const FacetedBorder(cut: 5),
        child: Container(
          constraints: BoxConstraints(
            minHeight: 30,
            minWidth: label == 'HELD' ? 48 : 72,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 7),
          alignment: Alignment.center,
          decoration: ShapeDecoration(
            color: warm ? const Color(0x1F78834F) : Colors.transparent,
            shape: FacetedBorder(
              cut: 5,
              side: BorderSide(
                color: warm
                    ? const Color(0xFF8F9A61).withValues(alpha: 0.82)
                    : Palette.textLo.withValues(alpha: 0.34),
              ),
            ),
          ),
          child: Text(
            label,
            style: Type.label.copyWith(
              fontSize: Type.minLabel,
              letterSpacing: 0.4,
              color: warm ? const Color(0xFFB9C08A) : Palette.textLo,
            ),
          ),
        ),
      ),
    );
  }
}

class _LedgerTomorrowTray extends StatelessWidget {
  const _LedgerTomorrowTray({
    required this.selected,
    required this.onTap,
    required this.compact,
  });

  final List<Quest> selected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final veryLargeText = MediaQuery.textScalerOf(context).scale(1) >= 1.75;
    final semanticLabel =
        'Mark tomorrow, ${selected.length} of 3 priorities selected'
        '${selected.isEmpty ? '' : ': ${selected.map((quest) => quest.displayTitle).join(', ')}'}';
    if (compact && veryLargeText) {
      return Semantics(
        button: true,
        label: semanticLabel,
        child: Material(
          color: Colors.transparent,
          shape: const FacetedBorder(
            cut: 8,
            side: BorderSide(color: Color(0x997B603F)),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'MARK TOMORROW',
                    textAlign: TextAlign.center,
                    style: Type.label.copyWith(
                      fontSize: Type.minLabel,
                      letterSpacing: 1.2,
                      color: Palette.xpLight,
                    ),
                  ),
                  const SizedBox(height: 5),
                  for (var index = 0; index < 3; index++)
                    Expanded(
                      child: Row(
                        children: [
                          SizedBox(
                            width: 18,
                            child: Text(
                              '${index + 1}',
                              style: LedgerType.display.copyWith(
                                fontSize: 16,
                                color: index < selected.length
                                    ? Palette.brassLit
                                    : Palette.brass,
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              index < selected.length
                                  ? selected[index].displayTitle
                                  : 'Choose one',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: LedgerType.body.copyWith(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: index < selected.length
                                    ? Palette.textMid
                                    : Palette.textLo,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: Colors.transparent,
        child: LayoutBuilder(
          builder: (context, bounds) {
            final trayHeight = min(
              bounds.maxHeight * 0.78,
              bounds.maxWidth / 3.58,
            );
            return InkWell(
              onTap: onTap,
              customBorder: const FacetedBorder(cut: 8),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    height: trayHeight,
                    child: Image.asset(
                      'assets/routine/top-three-tray-v2.webp',
                      fit: BoxFit.fill,
                      filterQuality: FilterQuality.high,
                      excludeFromSemantics: true,
                    ),
                  ),
                  Positioned(
                    left: bounds.maxWidth * 0.29,
                    right: bounds.maxWidth * 0.29,
                    top: trayHeight * 0.035,
                    height: trayHeight * 0.18,
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'MARK TOMORROW',
                          style: LedgerType.smallCaps.copyWith(
                            fontSize: Type.minLabel,
                            letterSpacing: 1.55,
                            color: Palette.xpLight,
                            shadows: const [
                              Shadow(
                                color: Color(0x78000000),
                                blurRadius: 1,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 4,
                    right: 4,
                    top: trayHeight * 0.24,
                    height: trayHeight * 0.66,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var index = 0; index < 3; index++)
                          Expanded(
                            child: _TomorrowTrayEntry(
                              index: index + 1,
                              quest: index < selected.length
                                  ? selected[index]
                                  : null,
                              compact: compact,
                            ),
                          ),
                      ],
                    ),
                  ),
                  for (
                    var index = 0;
                    index < selected.length && index < 3;
                    index++
                  )
                    Positioned(
                      left:
                          bounds.maxWidth * ((index + 0.5) / 3) -
                          (compact ? 11 : 13.5),
                      top: trayHeight * 0.75,
                      width: compact ? 22 : 27,
                      height: compact ? 29 : 36,
                      child: _PriorityRibbon(index: index),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

String _priorityRibbonAsset(int index) => switch (index) {
  0 => 'assets/routine/priority-ribbon-plum-v2.webp',
  1 => 'assets/routine/priority-ribbon-blue-v2.webp',
  _ => 'assets/routine/priority-ribbon-umber-v2.webp',
};

class _PriorityRibbon extends StatelessWidget {
  const _PriorityRibbon({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final asset = _priorityRibbonAsset(index);
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        Transform.translate(
          offset: const Offset(0, 1.4),
          child: Opacity(
            opacity: 0.52,
            child: ColorFiltered(
              colorFilter: const ColorFilter.mode(
                Color(0xFF090503),
                BlendMode.srcIn,
              ),
              child: Image.asset(
                asset,
                fit: BoxFit.fill,
                filterQuality: FilterQuality.medium,
                excludeFromSemantics: true,
              ),
            ),
          ),
        ),
        Image.asset(
          asset,
          fit: BoxFit.fill,
          filterQuality: FilterQuality.high,
          excludeFromSemantics: true,
        ),
      ],
    );
  }
}

class _TomorrowTrayEntry extends StatelessWidget {
  const _TomorrowTrayEntry({
    required this.index,
    required this.quest,
    required this.compact,
  });

  final int index;
  final Quest? quest;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final chosen = quest != null;
    final horizontal = compact ? 3.0 : 5.0;
    return LayoutBuilder(
      builder: (context, bounds) => Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontal),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Positioned.fill(
              child: Column(
                children: [
                  Text(
                    '$index',
                    style: LedgerType.display.copyWith(
                      fontSize: compact ? 24 : 30,
                      height: 0.86,
                      color: chosen ? Palette.brassLit : Palette.brass,
                      shadows: const [
                        Shadow(
                          color: Color(0x73000000),
                          blurRadius: 1,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: compact ? 2 : 4),
                  Expanded(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Text(
                        chosen ? quest!.displayTitle : 'Choose one',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: LedgerType.body.copyWith(
                          fontSize: compact ? 9.5 : 12.5,
                          height: 1.02,
                          fontWeight: FontWeight.w600,
                          fontStyle: chosen
                              ? FontStyle.normal
                              : FontStyle.italic,
                          color: chosen ? Palette.textMid : Palette.textLo,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LedgerChoiceRow extends StatelessWidget {
  const _LedgerChoiceRow({
    required this.quest,
    required this.selected,
    required this.rank,
    required this.onTap,
  });

  final Quest quest;
  final bool selected;
  final int? rank;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${selected ? 'Unmark' : 'Mark'} ${quest.displayTitle}',
      child: Material(
        color: Colors.transparent,
        shape: const FacetedBorder(cut: 7),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            constraints: const BoxConstraints(minHeight: 50),
            padding: const EdgeInsets.fromLTRB(9, 6, 8, 6),
            decoration: ShapeDecoration(
              color: selected
                  ? const Color(0x3D8A4E2C)
                  : const Color(0x1C1B120E),
              shape: FacetedBorder(
                cut: 7,
                side: BorderSide(
                  color: selected
                      ? Palette.brassLit.withValues(alpha: 0.62)
                      : Palette.brass.withValues(alpha: 0.34),
                ),
              ),
            ),
            child: Row(
              children: [
                _LedgerSelectionSeal(selected: selected, rank: rank),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        quest.displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: LedgerType.body.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Palette.textHi,
                        ),
                      ),
                      Text(
                        '${quest.stat.abbr} · ${quest.isEvent ? 'DUE' : quest.schedule.label}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Type.label.copyWith(
                          fontSize: Type.minLabel,
                          color: quest.stat.color,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(quest.stat.icon, size: 17, color: quest.stat.color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LedgerSelectionSeal extends StatelessWidget {
  const _LedgerSelectionSeal({required this.selected, required this.rank});

  final bool selected;
  final int? rank;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: 29,
      height: 29,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: selected
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFD4AD70),
                  Color(0xFF996431),
                  Color(0xFF573418),
                ],
              )
            : null,
        color: selected ? null : const Color(0x24130D09),
        border: Border.all(
          color: selected ? Palette.brassLit : Palette.brass,
          width: selected ? 1.2 : 0.8,
        ),
        boxShadow: selected
            ? const [
                BoxShadow(
                  color: Color(0x4D000000),
                  blurRadius: 5,
                  offset: Offset(0, 2),
                ),
                BoxShadow(
                  color: Color(0x24F3DDAE),
                  blurRadius: 5,
                  offset: Offset(-1, -1),
                ),
              ]
            : null,
      ),
      child: selected
          ? Center(
              child: Text(
                '${rank ?? 1}',
                style: LedgerType.display.copyWith(
                  fontSize: 19,
                  height: 0.9,
                  color: const Color(0xFF2D1B12),
                  shadows: const [
                    Shadow(color: Color(0x64F8DFAE), offset: Offset(0, 1)),
                  ],
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}

class _MorningLeadQuest extends StatelessWidget {
  const _MorningLeadQuest({
    required this.quest,
    required this.xp,
    required this.onBegin,
    required this.compact,
  });

  final Quest quest;
  final int xp;
  final VoidCallback onBegin;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Begin here, ${quest.displayTitle}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onBegin,
          child: Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: compact ? 6 : 11,
                right: 5,
                top: 0,
                bottom: 0,
                child: Row(
                  children: [
                    Icon(
                      quest.stat.icon,
                      size: compact ? 24 : 31,
                      color: LedgerInk.dark.withValues(alpha: 0.88),
                    ),
                    SizedBox(width: compact ? 7 : 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                '1',
                                style: LedgerType.display.copyWith(
                                  fontSize: compact ? 12.5 : 15,
                                  height: 0.9,
                                  color: LedgerInk.pageGold,
                                ),
                              ),
                              SizedBox(width: compact ? 4 : 5),
                              Text(
                                'BEGIN HERE',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: LedgerType.smallCaps.copyWith(
                                  fontSize: compact ? 7.5 : 9,
                                  height: 1,
                                  letterSpacing: compact ? 1.05 : 1.3,
                                  color: LedgerInk.pageGold,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: compact ? 1 : 2),
                          Text(
                            quest.displayTitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: LedgerType.display.copyWith(
                              fontSize: compact ? 16 : 21,
                              height: 1.06,
                              color: LedgerInk.dark,
                            ),
                          ),
                          SizedBox(height: compact ? 2 : 4),
                          Row(
                            children: [
                              Icon(
                                quest.stat.icon,
                                size: compact ? 10.5 : 12,
                                color: quest.stat.color,
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  '${quest.stat.abbr} · +$xp XP',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Type.label.copyWith(
                                    fontSize: Type.minLabel,
                                    color: quest.stat.color,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: compact ? 5 : 10,
                right: 0,
                bottom: 0,
                height: 1,
                child: ColoredBox(
                  color: LedgerInk.rule.withValues(alpha: 0.72),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MorningQuestLine extends StatelessWidget {
  const _MorningQuestLine({
    required this.quest,
    required this.xp,
    required this.compact,
  });

  final Quest? quest;
  final int? xp;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(compact ? 6 : 11, 5, compact ? 5 : 9, 5),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: LedgerInk.rule.withValues(alpha: 0.65)),
        ),
      ),
      child: Row(
        children: [
          Icon(
            quest?.stat.icon ?? Icons.bookmark_border_rounded,
            size: compact ? 23 : 31,
            color: quest?.stat.color ?? LedgerInk.quiet,
          ),
          SizedBox(width: compact ? 8 : 13),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quest?.displayTitle ?? 'Leave room for what arrives',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LedgerType.body.copyWith(
                    fontSize: compact ? 15 : 19,
                    height: 1.05,
                    fontStyle: quest == null
                        ? FontStyle.italic
                        : FontStyle.normal,
                    color: quest == null ? LedgerInk.quiet : LedgerInk.dark,
                  ),
                ),
                if (quest != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        quest!.stat.icon,
                        size: 11,
                        color: quest!.stat.color,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          '${quest!.stat.abbr} · +$xp XP',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Type.label.copyWith(
                            fontSize: Type.minLabel,
                            color: quest!.stat.color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CapacityLedgerTab extends StatelessWidget {
  const _CapacityLedgerTab({
    required this.weather,
    required this.selected,
    required this.light,
    required this.scroll,
    required this.onTap,
  });

  final EnergyWeather weather;
  final bool selected;
  final ValueListenable<Offset> light;
  final ValueListenable<double> scroll;
  final VoidCallback onTap;

  String get _label => switch (weather) {
    EnergyWeather.low => 'LOW',
    EnergyWeather.steady => 'STEADY',
    EnergyWeather.bright => 'BRIGHT',
  };

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Today feels $_label',
      child: Material(
        color: Colors.transparent,
        shape: const FacetedBorder(cut: 5),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 48,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 230),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: selected
                  ? GoldSurface(
                      key: ValueKey('selected-${weather.name}'),
                      cut: 5,
                      light: light,
                      scroll: scroll,
                      glow: false,
                      textured: true,
                      child: _CapacityLedgerLabel(
                        label: _label,
                        selected: true,
                      ),
                    )
                  : DecoratedBox(
                      key: ValueKey('idle-${weather.name}'),
                      decoration: ShapeDecoration(
                        color: const Color(0x0F7A5735),
                        shape: FacetedBorder(
                          cut: 5,
                          side: BorderSide(color: LedgerInk.rule),
                        ),
                      ),
                      child: _CapacityLedgerLabel(
                        label: _label,
                        selected: false,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CapacityLedgerLabel extends StatelessWidget {
  const _CapacityLedgerLabel({required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: Text(
            label,
            style: LedgerType.smallCaps.copyWith(
              fontSize: 10.5,
              letterSpacing: 1.1,
              color: selected ? Palette.onHoney : LedgerInk.mid,
              shadows: selected
                  ? const [
                      Shadow(color: Color(0x73FFE2AE), offset: Offset(0, 1)),
                    ]
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _MorningFootnote extends StatelessWidget {
  const _MorningFootnote({
    required this.nearby,
    required this.allDay,
    required this.weather,
    this.onOpen,
  });

  final int nearby;
  final int allDay;
  final EnergyWeather weather;

  /// Tapping the line (and its chevron) goes to the waiting quests. The
  /// chevron only appears when there is somewhere to go — an arrow that
  /// leads nowhere reads as a broken control.
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      if (weather == EnergyWeather.low) 'these three are sheltered',
      if (nearby > 0) '$nearby side quest${nearby == 1 ? '' : 's'} waiting',
      if (nearby == 0 && allDay > 0)
        '$allDay all-day line${allDay == 1 ? '' : 's'}',
    ];
    final copy = parts.isEmpty ? 'The page is yours.' : parts.join(' · ');
    final row = Row(
      children: [
        const Icon(Icons.group_outlined, size: 18, color: LedgerInk.pageGold),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            copy,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: LedgerType.body.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: LedgerInk.mid,
            ),
          ),
        ),
        if (onOpen != null)
          const Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: LedgerInk.pageGold,
          ),
      ],
    );
    if (onOpen == null) return row;
    return Semantics(
      button: true,
      label: '$copy. Open the quest board.',
      onTap: onOpen,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onOpen,
        child: row,
      ),
    );
  }
}

class _EmptyMorningPage extends StatelessWidget {
  const _EmptyMorningPage({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onOpen,
      customBorder: const FacetedBorder(cut: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        alignment: Alignment.center,
        decoration: const ShapeDecoration(
          color: Color(0x147A5735),
          shape: FacetedBorder(
            cut: 8,
            side: BorderSide(color: Color(0x4D7A5A36)),
          ),
        ),
        child: Text(
          'An open page is a real kind of morning.',
          textAlign: TextAlign.center,
          style: LedgerType.body.copyWith(
            fontSize: 14,
            fontStyle: FontStyle.italic,
            color: LedgerInk.mid,
          ),
        ),
      ),
    );
  }
}

/// Last-7-days momentum: active days glow, frozen days hold a small snowflake,
/// and today is ringed. Shared by the night recap and morning brief.
class MomentumStrip extends StatelessWidget {
  const MomentumStrip({
    super.key,
    required this.history,
    this.frozenDays = const <String>{},
  });
  final Map<String, int> history;
  final Set<String> frozenDays;

  static const _dow = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final now = Clock.now();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 6; i >= 0; i--)
          Builder(
            builder: (_) {
              final day = now.subtract(Duration(days: i));
              final n = history[Days.key(day)] ?? 0;
              final isToday = i == 0;
              final lit = n > 0;
              final frozen = !lit && frozenDays.contains(Days.key(day));
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: lit
                            ? Palette.xpLight.withValues(
                                alpha: (0.4 + 0.15 * n).clamp(0.4, 1.0),
                              )
                            : frozen
                            ? Palette.info.withValues(alpha: 0.12)
                            : Palette.glassFill,
                        border: Border.all(
                          color: isToday
                              ? Palette.xp
                              : lit
                              ? Palette.xpLight.withValues(alpha: 0.6)
                              : frozen
                              ? Palette.info.withValues(alpha: 0.78)
                              : Palette.glassEdge,
                          width: isToday ? 1.6 : 1,
                        ),
                      ),
                      child: frozen
                          ? const Icon(
                              Icons.ac_unit_rounded,
                              size: 10,
                              color: Palette.info,
                            )
                          : null,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _dow[(day.weekday - 1) % 7],
                      style: Type.label.copyWith(
                        fontSize: 11,
                        color: isToday ? Palette.xp : Palette.textLo,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}

class _PopIn extends StatelessWidget {
  const _PopIn({required this.delayMs, required this.child});
  final int delayMs;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: delayMs + 300),
      curve: Interval(
        delayMs / (delayMs + 300),
        1.0,
        curve: Curves.easeOutBack,
      ),
      builder: (_, v, c) => Opacity(
        opacity: v.clamp(0.0, 1.0),
        child: Transform.scale(scale: 0.6 + 0.4 * v, child: c),
      ),
      child: child,
    );
  }
}

class _BigButton extends StatelessWidget {
  const _BigButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return HoneyButton(label: label, onTap: onTap, glow: true);
  }
}
