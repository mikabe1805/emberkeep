import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio.dart';
import '../clock.dart';
import '../engine.dart';
import '../models.dart';
import '../tokens.dart';
import '../widgets/detail_header.dart';
import '../widgets/ember_sheet.dart';
import '../widgets/glass.dart';
import '../widgets/notes_sheet.dart';

/// A goal's "character sheet" (round-20): tap an adopted goal to open this —
/// a progress ring, the cool stats being kept track of, the quests serving the
/// goal, and a quiet way to abandon it. Read-only; completion lives on the
/// Quests board. The page accent is the goal's stat colour (honey once achieved).
class GoalDetailScreen extends StatelessWidget {
  const GoalDetailScreen({
    super.key,
    required this.goal,
    required this.state,
    required this.quests,
    required this.onRemoveGoal,
    required this.onPersist,
    required this.onAddQuest,
  });

  final Goal goal;
  final GameState state;

  /// The live board quests — the ones serving this goal are filtered by title.
  final List<Quest> quests;
  final void Function(Goal goal) onRemoveGoal;

  /// Persists the save after a journal edit.
  final VoidCallback onPersist;

  /// Adds a quest — used by the journal's "make this a quest".
  final bool Function(Quest quest) onAddQuest;

  Color get _accent => goal.complete ? Palette.xpLight : goal.stat.color;

  /// The ring fill: a true 0→1 finish-line for ACHIEVE; for BECOME, the fill
  /// within the current tier (toward the next milestone) so it ascends rather
  /// than sitting near-full forever.
  /// Start-of-current-tier progress (0 before the first milestone). The ring
  /// and the centre number share this so the arc and the digits always agree.
  int get _tierBase => goal.milestones == 0 ? 0 : goal.target ~/ 2;

  double get _ringValue {
    if (goal.complete) return 1;
    if (goal.kind == GoalKind.achieve) return goal.fraction;
    final span = goal.target - _tierBase;
    if (span <= 0) return 0;
    return ((goal.progress - _tierBase) / span).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final related = quests
        .where((q) => q.goalTitle == goal.title)
        .toList(growable: false);
    final now = Clock.now();
    final todayKey = Days.key(now);
    // a quest hidden "just for today" can't be done today, so keep it out of the
    // DONE-TODAY denominator (it still shows in the list as a goal member).
    final activeToday = related
        .where((q) => q.snoozedDay != todayKey)
        .toList(growable: false);
    final doneToday = activeToday.where((q) => q.doneFor(now)).length;
    final days = goal.startedDay == null
        ? null
        : math.max(1, now.difference(Days.parse(goal.startedDay!)).inDays + 1);

    return Scaffold(
      backgroundColor: Palette.parchment,
      body: WarmBackground(
        themeId: state.canvasTheme,
        child: SafeArea(
          child: Column(
            children: [
              DetailHeader(
                title: goal.title,
                accent: _accent,
                pill: goal.complete
                    ? 'ACHIEVED'
                    : (goal.kind == GoalKind.become ? 'BECOME' : 'ACHIEVE'),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                  children: [
                    _heroRing(),
                    const SizedBox(height: 16),
                    _statTiles(
                      context,
                      related.length,
                      doneToday,
                      activeToday.length,
                      days,
                    ),
                    const SizedBox(height: 16),
                    JournalPanel(
                      title: goal.title,
                      accent: _accent,
                      subtitle: 'the journey, in your words',
                      emptyPreview:
                          'Reflect on the journey — what’s changed, what’s '
                          'hard, what you’re proud of.',
                      emptyHint:
                          'No entries yet. Reflect on the journey — '
                          'what’s changed, what’s hard, what you’re proud of.',
                      read: () => goal.notes,
                      onAdd: (text) {
                        final mark = goal.complete
                            ? 'done'
                            : goal.kind == GoalKind.achieve
                            ? '${goal.progress}/${goal.target}'
                            : goal.milestones == 0
                            ? 'starting out'
                            : 'milestone ${goal.milestones}';
                        goal.notes = goal.notes.withNote(
                          text,
                          DateTime.now(),
                          context: mark,
                        );
                        onPersist();
                      },
                      onDelete: (n) {
                        goal.notes = goal.notes.without(n);
                        onPersist();
                      },
                      onMakeQuest: (text) async {
                        // turn a reflection into a quest that serves this goal
                        final q = await showEmberSheet(
                          context,
                          EmberSheetConfig(
                            surface: EmberSurface.goal,
                            defaultTitle: text,
                            defaultStat: goal.stat,
                            lockStat: true,
                            goalTitle: goal.title,
                            accent: _accent,
                          ),
                        );
                        if (q != null) onAddQuest(q);
                      },
                    ),
                    const SizedBox(height: 16),
                    _relatedPanel(
                      context,
                      related,
                      now,
                      doneToday,
                      activeToday.length,
                    ),
                    const SizedBox(height: 22),
                    _abandonLink(context),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── hero: the progress ring ───────────────────────────────────────
  Widget _heroRing() {
    final caption = goal.complete
        ? 'ACHIEVED · ${goal.achievedDay ?? ''}'.trim()
        : (goal.kind == GoalKind.achieve
              ? 'TOWARD THE FINISH LINE'
              : 'TOWARD MILESTONE ${goal.milestones + 1}');
    final capIcon = goal.complete
        ? Icons.emoji_events
        : (goal.kind == GoalKind.achieve ? Icons.flag : Icons.all_inclusive);
    return GlassPanel(
      blur: true,
      glow: true,
      padding: const EdgeInsets.symmetric(vertical: 26),
      child: Column(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 900),
            curve: Motion.barCurve,
            builder: (_, t, _) => SizedBox(
              width: 170,
              height: 170,
              child: CustomPaint(
                painter: _RingPainter(
                  value: _ringValue * t,
                  color: _accent,
                  complete: goal.complete,
                ),
                child: Center(
                  child: goal.complete
                      ? Icon(
                          Icons.emoji_events,
                          size: 46,
                          color: Palette.xpLight,
                        )
                      : FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${((goal.progress - _tierBase) * t).round()}',
                                style: Type.numerals.copyWith(
                                  fontSize: 46,
                                  color: _accent,
                                ),
                              ),
                              Text(
                                '/ ${goal.target - _tierBase}',
                                style: Type.label.copyWith(fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(capIcon, size: 13, color: _accent.withValues(alpha: 0.85)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  caption,
                  overflow: TextOverflow.ellipsis,
                  style: Type.label.copyWith(fontSize: 11),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── the cool stats ────────────────────────────────────────────────
  Widget _statTiles(
    BuildContext context,
    int active,
    int doneToday,
    int doneDenom,
    int? days,
  ) {
    final tiles = <Widget>[
      _tile(
        context,
        'QUESTS COMPLETED',
        '${goal.progress}',
        Icons.check_circle_outline,
      ),
      _tile(
        context,
        'DONE TODAY',
        '$doneToday / $doneDenom',
        Icons.local_fire_department,
      ),
      _tile(context, 'ACTIVE QUESTS', '$active', Icons.bolt),
      if (goal.kind == GoalKind.become)
        _tile(
          context,
          'MILESTONES REACHED',
          '${goal.milestones}',
          Icons.all_inclusive,
        )
      else
        _tile(
          context,
          'TO THE FINISH',
          goal.complete
              ? 'DONE'
              : '${(goal.target - goal.progress).clamp(0, goal.target)}',
          Icons.flag,
        ),
      _tile(
        context,
        'DAYS ON THE JOURNEY',
        days == null ? '—' : '$days',
        Icons.wb_twilight,
      ),
    ];
    return Wrap(spacing: 12, runSpacing: 12, children: tiles);
  }

  Widget _tile(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    final w = (MediaQuery.sizeOf(context).width - 32 - 12) / 2;
    return SizedBox(
      width: w,
      child: GlassPanel(
        radius: 14,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: _accent),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                maxLines: 1,
                style: Type.numerals.copyWith(fontSize: 22, color: _accent),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Type.label.copyWith(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  // ── quests serving this goal ──────────────────────────────────────
  Widget _relatedPanel(
    BuildContext context,
    List<Quest> related,
    DateTime now,
    int doneToday,
    int denom,
  ) {
    final sorted = [...related]
      ..sort((a, b) {
        final ad = a.doneFor(now) ? 1 : 0;
        final bd = b.doneFor(now) ? 1 : 0;
        return ad.compareTo(bd); // undone first, handled-today sink lower
      });
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'QUESTS SERVING THIS GOAL',
                  overflow: TextOverflow.ellipsis,
                  style: Type.label.copyWith(fontSize: 11),
                ),
              ),
              const SizedBox(width: 8),
              if (related.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: _accent.withValues(alpha: 0.14),
                    border: Border.all(color: _accent.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    '$doneToday / $denom TODAY',
                    style: Type.label.copyWith(fontSize: 11, color: _accent),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (sorted.isEmpty)
            Text(
              'No quests feed this goal right now — take some on to fuel it.',
              style: Type.body.copyWith(
                fontSize: 13.5,
                fontStyle: FontStyle.italic,
                color: Palette.textLo,
              ),
            )
          else
            for (final q in sorted) _questRow(q, q.doneFor(now)),
        ],
      ),
    );
  }

  Widget _questRow(Quest q, bool done) {
    return Opacity(
      opacity: done ? 0.6 : 1,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: q.stat.color,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    q.displayTitle,
                    overflow: TextOverflow.ellipsis,
                    style: Type.body.copyWith(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: Palette.textHi,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Wrap(
                    spacing: 5,
                    runSpacing: 5,
                    children: [
                      _chip(q.schedule.label),
                      if (q.timerMinutes > 0)
                        _chip('⏱ ${q.timerMinutes}M', Palette.verify),
                      if (q.allDay) _chip('CHECKS AT NIGHT', Palette.unlock),
                      if (q.dread) _chip('COUNTS EXTRA', Palette.dread),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              done ? Icons.check_circle : Icons.circle_outlined,
              size: 18,
              color: done
                  ? Palette.success
                  : q.stat.color.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, [Color? color]) {
    final c = color ?? Palette.textLo;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withValues(alpha: 0.4)),
      ),
      child: Text(label, style: Type.label.copyWith(fontSize: 11, color: c)),
    );
  }

  // ── abandon (the existing two-step warm confirm) ──────────────────
  Widget _abandonLink(BuildContext context) {
    // Deliberately understated and gated behind a long-press — quitting a goal
    // shouldn't feel like a casual one-tap button (owner feedback).
    final label = goal.complete ? 'hold to retire' : 'hold to abandon';
    return Center(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: () => _confirmAbandon(context),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Text(
            label,
            style: Type.label.copyWith(
              fontSize: 9,
              color: Palette.textLo.withValues(alpha: 0.32),
            ),
          ),
        ),
      ),
    );
  }

  void _confirmAbandon(BuildContext context) {
    Sfx.instance.play('tick');
    HapticFeedback.selectionClick();
    var armed = false;
    showDialog(
      context: context,
      barrierColor: const Color(0xCC140C06),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => Dialog(
          backgroundColor: Colors.transparent,
          child: GlassPanel(
            tint: const Color(0xF22A211D),
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Abandon “${goal.title}”?',
                  textAlign: TextAlign.center,
                  style: Type.display.copyWith(fontSize: 17),
                ),
                const SizedBox(height: 6),
                Text(
                  'The goal and every quest serving it leave the board.',
                  textAlign: TextAlign.center,
                  style: Type.body.copyWith(
                    fontSize: 13.5,
                    color: Palette.textMid,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(ctx).pop(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0xFFF6D9A2),
                              Color(0xFFEFC074),
                              Color(0xFFC08B4F),
                            ],
                          ),
                        ),
                        child: Text(
                          'KEEP IT',
                          style: Type.label.copyWith(
                            fontSize: 11,
                            color: const Color(0xFF3A2510),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () {
                        if (!armed) {
                          Sfx.instance.play('tick');
                          setDialog(() => armed = true);
                          return;
                        }
                        Sfx.instance.play('boing');
                        Navigator.of(ctx).pop(); // close confirm
                        onRemoveGoal(goal);
                        Navigator.of(context).maybePop(); // leave the detail
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: const Color(
                              0xFFE89090,
                            ).withValues(alpha: armed ? 1 : 0.5),
                          ),
                        ),
                        child: Text(
                          armed ? 'TAP AGAIN' : 'ABANDON',
                          style: Type.label.copyWith(
                            fontSize: 11,
                            color: const Color(0xFFE89090),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The hero progress ring — a faint honey track with a stat→honey sweep arc,
/// starting at 12 o'clock. Round cap, animated fill.
class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.value,
    required this.color,
    required this.complete,
  });
  final double value;
  final Color color;
  final bool complete;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - 12) / 2;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 11
        ..color = const Color(0x1FF2CD93),
    );
    if (value <= 0) return;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        transform: const GradientRotation(-math.pi / 2),
        colors: complete
            ? const [Palette.xpLight, Palette.xpLight]
            : [color, Palette.xpLight],
      ).createShader(rect);
    canvas.drawArc(rect, -math.pi / 2, value * 2 * math.pi, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.color != color || old.complete != complete;
}
