import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio.dart';
import '../content/messages.dart';
import '../engine.dart';
import '../models.dart';
import '../tokens.dart';
import 'glass.dart';

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
  late final String _line = RewardMessages.night(Random());

  /// Lines logged as "not today" this session — shown warm, never red
  /// (AVE-safe: a slip is data, not failure).
  final Set<Quest> _slipped = {};

  void _finish() {
    widget.state.closeNight(); // stamps the night + arms tomorrow's morning
    widget.onPersist();
    Sfx.instance.play('streak');
    HapticFeedback.mediumImpact();
    widget.onClose();
  }

  /// What tomorrow already holds: recurring quests scheduled on that day
  /// (round-7: weekday/month-day aware) and events due by tomorrow.
  List<Quest> _tomorrowQuests() {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return [
      for (final q in widget.quests)
        if (q.isEvent
            ? (q.lastDoneDay == null &&
                !q.dueDate!.isAfter(DateTime(
                    tomorrow.year, tomorrow.month, tomorrow.day, 23, 59)))
            : (q.scheduledOn(tomorrow) && !q.doneFor(tomorrow)))
          q,
    ];
  }

  @override
  Widget build(BuildContext context) {
    return OverlaySurface(
      child: Container(
        color: const Color(0xF7140E08), // deepest walnut night
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: AnimatedSwitcher(
              duration: Motion.settle,
              child: _step == 0 ? _recap(context) : _planner(context),
            ),
          ),
        ),
      ),
    );
  }

  /// All-day abstention quests still unconfirmed today. A "hide just for
  /// today" snooze excludes them — a line you chose to skip is never offered
  /// for reward at night.
  List<Quest> _openAllDay() {
    final now = DateTime.now();
    final today = Days.key(now);
    return [
      for (final q in widget.quests)
        if (q.allDay &&
            q.snoozedDay != today &&
            !q.doneFor(now) &&
            !_slipped.contains(q))
          q,
    ];
  }

  /// Shame-free slip logging: no XP, no loss, no red — tomorrow is fresh.
  void _logSlip(Quest q) {
    Sfx.instance.play('tick');
    setState(() => _slipped.add(q));
  }

  /// Rising quests that have earned a climb (5 holds since last rise).
  List<Quest> _readyToRise() =>
      [for (final q in widget.quests) if (q.readyToRise) q];

  /// A forward pull for tomorrow — the streak that continues, the goal that's
  /// nearly there. End the night on anticipation, not just accounting
  /// (RESEARCH-momentum.md §7). Empty when there's nothing warm to tease.
  Widget _tomorrowHook(GameState s) {
    final hooks = <String>[];
    if (s.streakDays > 0) {
      hooks.add('keep the fire: day ${s.streakDays + 1} tomorrow 🔥');
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
      hooks.add('“${near.title}” is $bestGap quest${bestGap == 1 ? "" : "s"} from a milestone');
    }
    if (hooks.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: GlassPanel(
        glow: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('WAITING FOR TOMORROW',
                style: Type.label.copyWith(fontSize: 9, color: Palette.streak)),
            const SizedBox(height: 6),
            for (final h in hooks)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(h,
                    style: Type.body.copyWith(
                        fontSize: 12.5, color: Palette.textMid)),
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
      if (q.canRise) q.rung++;
      q.difficulty = (q.difficulty + 1).clamp(1, q.custom ? 8 : 10);
      q.risingStreak = 0;
    });
    widget.onPersist();
  }

  void _notYet(Quest q) {
    Sfx.instance.play('tick');
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
    Sfx.instance.play('complete');
    HapticFeedback.mediumImpact();
    setState(() {});
  }

  // ── step 1: the day, replayed ─────────────────────────────────────
  Widget _recap(BuildContext context) {
    final s = widget.state;
    final today = Days.key(DateTime.now());
    final done = s.history[today] ?? 0;
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
                s.playerName == null
                    ? 'Goodnight'
                    : 'Goodnight, ${s.playerName}',
                style: Type.display.copyWith(fontSize: 30))),
        const SizedBox(height: 6),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(_line,
                textAlign: TextAlign.center,
                style: Type.body.copyWith(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: Palette.textLo)),
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
                    const Icon(Icons.nightlight_round,
                        size: 13, color: Palette.unlock),
                    const SizedBox(width: 6),
                    Text('HOW DID THE ALL-DAY LINE GO?',
                        style: Type.label.copyWith(
                            fontSize: 9, color: Palette.unlock)),
                  ],
                ),
                const SizedBox(height: 4),
                Text('only count what truly held — a slip is data, not failure',
                    style: Type.body.copyWith(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: Palette.textLo)),
                const SizedBox(height: 10),
                for (final q in openAllDay)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(q.title,
                              style: Type.body.copyWith(
                                  fontSize: 13.5, color: Palette.textHi)),
                        ),
                        Text('+${widget.state.xpPreview(q)} XP',
                            style: Type.numerals.copyWith(
                                fontSize: 11, color: Palette.xp)),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _confirmAllDay(q),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 11, vertical: 6),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                  color: Palette.success
                                      .withValues(alpha: 0.6)),
                            ),
                            child: Text('HELD IT',
                                style: Type.label.copyWith(
                                    fontSize: 9, color: Palette.success)),
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => _logSlip(q),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 11, vertical: 6),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                  color: Palette.textLo
                                      .withValues(alpha: 0.4)),
                            ),
                            child: Text('NOT TODAY',
                                style: Type.label.copyWith(fontSize: 9)),
                          ),
                        ),
                      ],
                    ),
                  ),
                for (final q in _slipped)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.spa_outlined,
                            size: 13, color: Palette.textLo),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                              '${q.title} — logged. you did your best today; tomorrow’s line is fresh.',
                              style: Type.body.copyWith(
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                  color: Palette.textLo)),
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
                    const Icon(Icons.trending_up,
                        size: 14, color: Palette.streak),
                    const SizedBox(width: 6),
                    Text('READY TO RISE?',
                        style: Type.label.copyWith(
                            fontSize: 9, color: Palette.streak)),
                  ],
                ),
                const SizedBox(height: 4),
                Text('you’ve held these ${Quest.risesAt} times — the next rung is yours if you want it',
                    style: Type.body.copyWith(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: Palette.textLo)),
                const SizedBox(height: 10),
                for (final q in risers)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(q.displayTitle,
                                  style: Type.body.copyWith(
                                      fontSize: 13.5, color: Palette.textHi)),
                              if (q.canRise)
                                Text('→ ${q.ladder![q.rung + 1]}',
                                    style: Type.body.copyWith(
                                        fontSize: 11,
                                        color: Palette.streak)),
                            ],
                          ),
                        ),
                        if (!q.canRise)
                          Text('d${q.difficulty} → d${(q.difficulty + 1).clamp(1, q.custom ? 8 : 10)}',
                              style: Type.numerals.copyWith(
                                  fontSize: 11, color: Palette.streak)),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _rise(q),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 11, vertical: 6),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              gradient: const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Color(0xFFF2CD93),
                                  Color(0xFFC08B4F)
                                ],
                              ),
                            ),
                            child: Text('RISE',
                                style: Type.label.copyWith(
                                    fontSize: 9,
                                    color: const Color(0xFF3A2510))),
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => _notYet(q),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 11, vertical: 6),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                  color: Palette.textLo
                                      .withValues(alpha: 0.4)),
                            ),
                            child: Text('NOT YET',
                                style: Type.label.copyWith(fontSize: 9)),
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

        // XP count-up — the day's number, made physical
        GlassPanel(
          child: Column(
            children: [
              Text('TODAY YOU EARNED', style: Type.label.copyWith(fontSize: 9)),
              const SizedBox(height: 6),
              TweenAnimationBuilder<int>(
                tween: IntTween(begin: 0, end: s.todayXp),
                duration: const Duration(milliseconds: 1100),
                curve: Curves.easeOutCubic,
                builder: (_, v, _) => Text('+$v XP',
                    style: Type.numerals
                        .copyWith(fontSize: 44, color: Palette.xpLight)),
              ),
              Text(
                  '$done quest${done == 1 ? "" : "s"} · streak day ${s.streakDays}'
                  '${s.bestStreak > s.streakDays ? " · best ${s.bestStreak}" : ""}'
                  '${s.streakShields > 0 ? " · 🛡️${s.streakShields}" : ""}',
                  style: Type.body
                      .copyWith(fontSize: 12, color: Palette.textLo)),
              const SizedBox(height: 12),
              MomentumStrip(history: s.history),
              if (s.todayStats.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final e in s.todayStats.entries)
                      _PopIn(
                        delayMs: 500 + 140 * s.todayStats.keys
                            .toList()
                            .indexOf(e.key),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                                color: e.key.color.withValues(alpha: 0.6)),
                          ),
                          child: Text('+${e.value} ${e.key.abbr}',
                              style: Type.numerals.copyWith(
                                  fontSize: 12, color: e.key.color)),
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
                Text('YOUR GOALS, CLOSER',
                    style: Type.label.copyWith(fontSize: 9)),
                const SizedBox(height: 10),
                for (final g in s.goals.take(4)) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(g.title,
                            overflow: TextOverflow.ellipsis,
                            style: Type.body.copyWith(
                                fontSize: 13, color: Palette.textHi)),
                      ),
                      Text('${g.progress}/${g.target}',
                          style: Type.numerals
                              .copyWith(fontSize: 11, color: g.stat.color)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: g.fraction),
                    duration: const Duration(milliseconds: 1200),
                    curve: Curves.easeInOutCubic,
                    builder: (_, v, _) => ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: v,
                        minHeight: 7,
                        backgroundColor: const Color(0x1FF2CD93),
                        color: g.stat.color,
                      ),
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
                Text('CLEARED TODAY', style: Type.label.copyWith(fontSize: 9)),
                const SizedBox(height: 8),
                for (final t in s.todayQuestTitles.take(8))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Row(
                      children: [
                        const Icon(Icons.check,
                            size: 13, color: Palette.success),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(t,
                              overflow: TextOverflow.ellipsis,
                              style: Type.body.copyWith(
                                  fontSize: 13, color: Palette.textMid)),
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
              Sfx.instance.play('tick');
              setState(() => _step = 1);
            },
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: _finish,
            child: Text('just sleep',
                style: Type.label.copyWith(fontSize: 10)),
          ),
        ),
      ],
    );
  }

  // ── step 2: tomorrow, planned ────────────────────────────────────
  Widget _planner(BuildContext context) {
    final tomorrow = _tomorrowQuests();
    return ListView(
      key: const ValueKey('planner'),
      children: [
        const SizedBox(height: 18),
        Center(
            child:
                Text('Tomorrow', style: Type.display.copyWith(fontSize: 28))),
        const SizedBox(height: 4),
        Center(
          child: Text('star what matters most — the morning leads with it',
              style: Type.body.copyWith(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Palette.textLo)),
        ),
        const SizedBox(height: 16),
        GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ALREADY ON THE BOARD',
                  style: Type.label.copyWith(fontSize: 9)),
              const SizedBox(height: 8),
              for (final q in tomorrow)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle, color: q.stat.color),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(q.displayTitle,
                            overflow: TextOverflow.ellipsis,
                            style: Type.body.copyWith(
                                fontSize: 13.5, color: Palette.textHi)),
                      ),
                      Text(q.bonus ? 'BONUS' : (q.isEvent ? 'DUE' : q.schedule.label),
                          style: Type.label.copyWith(fontSize: 7.5)),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          Sfx.instance.play('tick');
                          HapticFeedback.selectionClick();
                          setState(() => q.priority = !q.priority);
                        },
                        child: Icon(
                          q.priority ? Icons.star : Icons.star_border,
                          size: 20,
                          color: q.priority ? Palette.xpLight : Palette.textLo,
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
        Center(child: _BigButton(label: 'GOODNIGHT 🌙', onTap: _finish)),
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
  final _title = TextEditingController();
  Stat _stat = Stat.foc;
  final List<String> _added = [];

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _add() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      Sfx.instance.play('boing');
      return;
    }
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final ok = widget.onAdd(Quest(
      title: title,
      stat: _stat,
      difficulty: 4,
      schedule: QuestSchedule.once,
      dueDate: DateTime(tomorrow.year, tomorrow.month, tomorrow.day),
      priority: true,
    ));
    if (ok) {
      Sfx.instance.play('streak');
      setState(() {
        _added.add(title);
        _title.clear();
      });
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
          Text('ADD A QUEST FOR TOMORROW',
              style: Type.label.copyWith(fontSize: 9)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _title,
                  style: Type.body
                      .copyWith(fontSize: 14, color: Palette.textHi),
                  decoration: InputDecoration(
                    hintText: 'e.g. Call the dentist',
                    hintStyle: Type.body
                        .copyWith(fontSize: 14, color: Palette.textLo),
                    isDense: true,
                    filled: true,
                    fillColor: Palette.glassFill,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: Palette.glassEdge),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _add,
                child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFF2CD93), Color(0xFFC08B4F)],
                    ),
                  ),
                  child: const Icon(Icons.add,
                      size: 18, color: Color(0xFF3A2510)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (final s in Stat.values)
                Padding(
                  padding: const EdgeInsets.only(right: 5),
                  child: GestureDetector(
                    onTap: () => setState(() => _stat = s),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: _stat == s
                            ? s.color.withValues(alpha: 0.22)
                            : Colors.transparent,
                        border: Border.all(
                            color: s.color
                                .withValues(alpha: _stat == s ? 0.8 : 0.3)),
                      ),
                      child: Text(s.abbr,
                          style: Type.label
                              .copyWith(fontSize: 8, color: s.color)),
                    ),
                  ),
                ),
            ],
          ),
          for (final t in _added)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  const Icon(Icons.star, size: 12, color: Palette.xpLight),
                  const SizedBox(width: 6),
                  Text(t,
                      style: Type.body
                          .copyWith(fontSize: 12, color: Palette.textMid)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The morning briefing: greet, lead with the starred MAIN quests, show the
/// XP on the table, send them off with a clear head.
class MorningFlow extends StatelessWidget {
  const MorningFlow({
    super.key,
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
            Text('SO CLOSE', style: Type.label.copyWith(fontSize: 9)),
            const SizedBox(height: 8),
            for (final g in near)
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  children: [
                    Icon(Icons.flag, size: 12, color: g.stat.color),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(g.title,
                          overflow: TextOverflow.ellipsis,
                          style: Type.body.copyWith(
                              fontSize: 13, color: Palette.textHi)),
                    ),
                    Text('${g.target - g.progress} to go',
                        style: Type.label
                            .copyWith(fontSize: 8, color: g.stat.color)),
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
    final now = DateTime.now();
    final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final today = Days.key(now);
    final open = [
      for (final q in quests)
        // a "hide just for today" snooze drops it from the morning brief too
        if (q.snoozedDay != today &&
            !q.doneFor(now) &&
            (!q.isEvent || !q.dueDate!.isAfter(endOfToday)))
          q,
    ];
    final main = open.where((q) => q.priority && !q.allDay).toList();
    final side = open.where((q) => !q.priority && !q.allDay).toList();
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
              const SizedBox(height: 18),
              const Center(
                child:
                    Icon(Icons.wb_twilight, size: 40, color: Palette.streak),
              ),
              const SizedBox(height: 10),
              Center(
                  child: Text(
                      state.playerName == null
                          ? 'Good morning'
                          : 'Good morning, ${state.playerName}',
                      style: Type.display.copyWith(fontSize: 30))),
              const SizedBox(height: 6),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(line,
                      textAlign: TextAlign.center,
                      style: Type.body.copyWith(
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          color: Palette.textLo)),
                ),
              ),
              const SizedBox(height: 20),
              GlassPanel(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text('ON THE TABLE',
                            style: Type.label.copyWith(fontSize: 8)),
                        Text('+$potential XP',
                            style: Type.numerals.copyWith(
                                fontSize: 22, color: Palette.xpLight)),
                      ],
                    ),
                    Column(
                      children: [
                        Text('STREAK', style: Type.label.copyWith(fontSize: 8)),
                        Text('${state.streakDays}🔥',
                            style: Type.numerals.copyWith(
                                fontSize: 22, color: Palette.streak)),
                        if (state.streakShields > 0)
                          Text('🛡️ ${state.streakShields}',
                              style: Type.label.copyWith(
                                  fontSize: 8, color: Palette.verify)),
                      ],
                    ),
                    Column(
                      children: [
                        Text('QUESTS', style: Type.label.copyWith(fontSize: 8)),
                        Text('${open.length}',
                            style: Type.numerals.copyWith(fontSize: 22)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              GlassPanel(child: MomentumStrip(history: state.history)),
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
                          const Icon(Icons.star,
                              size: 13, color: Palette.xpLight),
                          const SizedBox(width: 6),
                          Text('MAIN QUESTS',
                              style: Type.label.copyWith(
                                  fontSize: 9, color: Palette.xpLight)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      for (final q in main)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Container(
                                width: 9,
                                height: 9,
                                decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: q.stat.color),
                              ),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Text(q.displayTitle,
                                    style: Type.body.copyWith(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: Palette.textHi)),
                              ),
                              Text('+${state.xpPreview(q)} XP',
                                  style: Type.numerals.copyWith(
                                      fontSize: 12, color: Palette.xp)),
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
                          const Icon(Icons.nightlight_round,
                              size: 12, color: Palette.unlock),
                          const SizedBox(width: 6),
                          Text('HOLD THE LINE TODAY',
                              style: Type.label.copyWith(
                                  fontSize: 9, color: Palette.unlock)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      for (final q in allDay)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: q.stat.color),
                              ),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Text(q.title,
                                    style: Type.body.copyWith(
                                        fontSize: 13,
                                        color: Palette.textMid)),
                              ),
                              Text('CHECKS TONIGHT',
                                  style:
                                      Type.label.copyWith(fontSize: 7)),
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
                          fontSize: 13, color: Palette.textMid)),
                ),
              ],
              const SizedBox(height: 20),
              Center(child: _BigButton(label: "LET'S GO ☀️", onTap: onClose)),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

/// Last-7-days momentum: a row of day dots sized + lit by that day's
/// completions, today ringed. Shared by the night recap and morning brief.
class MomentumStrip extends StatelessWidget {
  const MomentumStrip({super.key, required this.history});
  final Map<String, int> history;

  static const _dow = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 6; i >= 0; i--)
          Builder(builder: (_) {
            final day = now.subtract(Duration(days: i));
            final n = history[Days.key(day)] ?? 0;
            final isToday = i == 0;
            final lit = n > 0;
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
                              alpha: (0.4 + 0.15 * n).clamp(0.4, 1.0))
                          : Palette.glassFill,
                      border: Border.all(
                        color: isToday
                            ? Palette.xp
                            : lit
                                ? Palette.xpLight.withValues(alpha: 0.6)
                                : Palette.glassEdge,
                        width: isToday ? 1.6 : 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(_dow[(day.weekday - 1) % 7],
                      style: Type.label.copyWith(
                          fontSize: 7,
                          color: isToday ? Palette.xp : Palette.textLo)),
                ],
              ),
            );
          }),
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
      curve: Interval(delayMs / (delayMs + 300), 1.0,
          curve: Curves.easeOutBack),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF2CD93), Color(0xFFC08B4F)],
          ),
          boxShadow: const [
            BoxShadow(
                color: Palette.honeyGlow, blurRadius: 18, offset: Offset(0, 6)),
          ],
        ),
        child: Text(label,
            style: Type.label
                .copyWith(fontSize: 11, color: const Color(0xFF3A2510))),
      ),
    );
  }
}
