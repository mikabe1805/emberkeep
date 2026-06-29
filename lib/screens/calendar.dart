import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio.dart';
import '../engine.dart';
import '../models.dart';
import '../tokens.dart';
import '../widgets/domain_hint.dart';
import '../widgets/glass.dart';

/// The Plans page: a warm month calendar. Honey dots = your completion
/// history; stat-colored diamonds = upcoming events/long-term goals. Tap a
/// day to see or plan it. (Push reminders arrive with the phone build —
/// due quests surface on the Quests page meanwhile.)
class CalendarPage extends StatefulWidget {
  const CalendarPage({
    super.key,
    required this.state,
    required this.quests,
    required this.onAdd,
  });

  final GameState state;
  final List<Quest> quests;
  final bool Function(Quest) onAdd;

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late DateTime _month;
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _selected = DateTime(now.year, now.month, now.day);
  }

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  List<Quest> _eventsOn(DateTime day) => [
        for (final q in widget.quests)
          if (q.dueDate != null && Days.sameDay(q.dueDate!, day)) q,
      ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final now = DateTime.now();
        final firstWeekday = DateTime(_month.year, _month.month, 1).weekday;
        final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 130),
          children: [
            Text('Plans', style: Type.display.copyWith(fontSize: 30)),
            const SizedBox(height: 4),
            Text('your story, laid out in days',
                style: Type.body.copyWith(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: Palette.textLo)),
            const SizedBox(height: 16),

            // ── month grid ───────────────────────────────────────
            GlassPanel(
              blur: true,
              child: Column(
                children: [
                  Row(
                    children: [
                      _Chevron(
                        icon: Icons.chevron_left,
                        onTap: () => setState(() => _month =
                            DateTime(_month.year, _month.month - 1)),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                              '${_monthNames[_month.month - 1]} ${_month.year}',
                              style: Type.display.copyWith(fontSize: 17)),
                        ),
                      ),
                      _Chevron(
                        icon: Icons.chevron_right,
                        onTap: () => setState(() => _month =
                            DateTime(_month.year, _month.month + 1)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      for (final d in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                        Expanded(
                          child: Center(
                            child: Text(d,
                                style: Type.label.copyWith(fontSize: 11)),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  for (var week = 0;
                      week * 7 - (firstWeekday - 1) < daysInMonth;
                      week++)
                    Row(
                      children: [
                        for (var col = 0; col < 7; col++)
                          Expanded(
                            child: _dayCell(
                                week * 7 + col - (firstWeekday - 1) + 1,
                                daysInMonth,
                                now),
                          ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── selected day panel ───────────────────────────────
            _DayPanel(
              day: _selected,
              completions: widget.state.history[Days.key(_selected)] ?? 0,
              events: _eventsOn(_selected),
              now: now,
              onPlan: () => _showAddEvent(context),
            ),
          ],
        );
      },
    );
  }

  Widget _dayCell(int day, int daysInMonth, DateTime now) {
    if (day < 1 || day > daysInMonth) return const SizedBox(height: 44);
    final date = DateTime(_month.year, _month.month, day);
    final isToday = Days.sameDay(date, now);
    final isSelected = Days.sameDay(date, _selected);
    final done = widget.state.history[Days.key(date)] ?? 0;
    final events = _eventsOn(date);

    return GestureDetector(
      onTap: () {
        Sfx.instance.play('tick');
        setState(() => _selected = date);
      },
      child: Container(
        height: 44,
        margin: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: isSelected
              ? Palette.xpLight.withValues(alpha: 0.16)
              : Colors.transparent,
          border: Border.all(
            color: isToday
                ? Palette.xp.withValues(alpha: 0.8)
                : isSelected
                    ? Palette.xpLight.withValues(alpha: 0.5)
                    : Colors.transparent,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('$day',
                style: Type.numerals.copyWith(
                    fontSize: 13,
                    color: isToday ? Palette.xp : Palette.textMid)),
            const SizedBox(height: 2),
            SizedBox(
              height: 11,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // one ember whose heat (size + glow) scales with the day's
                  // haul — a 12-quest day burns hotter than a 3-quest one
                  if (done > 0)
                    Container(
                      width: 4.0 + (done.clamp(1, 9)) * 0.7,
                      height: 4.0 + (done.clamp(1, 9)) * 0.7,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Palette.xpLight
                            .withValues(alpha: (0.45 + 0.07 * done).clamp(0.45, 1.0)),
                        boxShadow: [
                          BoxShadow(
                            color: Palette.honeyGlow.withValues(
                                alpha: (0.12 * done).clamp(0.0, 0.7)),
                            blurRadius: 2.0 + done.clamp(0, 8) * 0.8,
                          ),
                        ],
                      ),
                    ),
                  // stat-colored diamonds: planned events
                  for (final e in events.take(2))
                    Transform.rotate(
                      angle: 0.785,
                      child: Container(
                        width: 4.5,
                        height: 4.5,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        color: e.stat.color,
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

  void _showAddEvent(BuildContext context) {
    Sfx.instance.play('tick');
    showDialog(
      context: context,
      barrierColor: const Color(0xCC140C06),
      builder: (_) => _AddEventDialog(day: _selected, onAdd: widget.onAdd),
    );
  }
}

class _Chevron extends StatelessWidget {
  const _Chevron({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Sfx.instance.play('tick');
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 22, color: Palette.textLo),
      ),
    );
  }
}

class _DayPanel extends StatelessWidget {
  const _DayPanel({
    required this.day,
    required this.completions,
    required this.events,
    required this.now,
    required this.onPlan,
  });

  final DateTime day;
  final int completions;
  final List<Quest> events;
  final DateTime now;
  final VoidCallback onPlan;

  @override
  Widget build(BuildContext context) {
    final isPast = day.isBefore(DateTime(now.year, now.month, now.day));
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                    '${day.day}.${day.month}.${day.year}'
                    '${Days.sameDay(day, now) ? " · TODAY" : ""}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Type.label.copyWith(fontSize: 11)),
              ),
              if (!isPast)
                GestureDetector(
                  onTap: onPlan,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFF6D9A2), Color(0xFFEFC074), Color(0xFFC08B4F)],
                      ),
                    ),
                    child: Text('+ PLAN',
                        style: Type.label.copyWith(
                            fontSize: 11, color: const Color(0xFF3A2510))),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (completions > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.check_circle,
                      size: 14, color: Palette.success),
                  const SizedBox(width: 6),
                  Text(
                      '$completions quest${completions == 1 ? "" : "s"} completed',
                      style: Type.body.copyWith(
                          fontSize: 13, color: Palette.textMid)),
                ],
              ),
            ),
          if (events.isEmpty && completions == 0)
            Text(
                isPast
                    ? 'A quiet day.'
                    : 'Nothing planned yet — every empty day is a side quest waiting.',
                style: Type.body.copyWith(
                    fontSize: 13.5,
                    fontStyle: FontStyle.italic,
                    color: Palette.textLo)),
          for (final e in events)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Transform.rotate(
                    angle: 0.785,
                    child:
                        Container(width: 7, height: 7, color: e.stat.color),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(e.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Type.body.copyWith(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: e.doneFor(now)
                                ? Palette.textLo
                                : Palette.textHi,
                            decoration: e.doneFor(now)
                                ? TextDecoration.lineThrough
                                : null)),
                  ),
                  Text('d${e.difficulty}',
                      style: Type.label.copyWith(fontSize: 11)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Plan an event / long-term goal on the selected day. Completing it from
/// the Quests page pays XP like any quest and feeds the Keeper-of-Plans
/// achievement.
class _AddEventDialog extends StatefulWidget {
  const _AddEventDialog({required this.day, required this.onAdd});
  final DateTime day;
  final bool Function(Quest) onAdd;

  @override
  State<_AddEventDialog> createState() => _AddEventDialogState();
}

class _AddEventDialogState extends State<_AddEventDialog> {
  final _title = TextEditingController();
  Stat _stat = Stat.dis;
  double _difficulty = 4;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _add() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      Sfx.instance.play('boing');
      setState(() => _error = 'name your plan first');
      return;
    }
    final ok = widget.onAdd(Quest(
      title: title,
      stat: _stat,
      difficulty: _difficulty.round(),
      schedule: QuestSchedule.once,
      dueDate: widget.day,
    ));
    if (!ok) {
      Sfx.instance.play('boing');
      setState(() => _error = 'already on your quest list');
      return;
    }
    Sfx.instance.play('streak');
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: GlassPanel(
        tint: const Color(0xF22A211D),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'PLAN FOR ${widget.day.day}.${widget.day.month}.${widget.day.year}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Type.label.copyWith(fontSize: 11)),
            const SizedBox(height: 10),
            TextField(
              controller: _title,
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              style: Type.body.copyWith(fontSize: 15, color: Palette.textHi),
              decoration: InputDecoration(
                hintText: 'e.g. Finish the essay draft',
                hintStyle:
                    Type.body.copyWith(fontSize: 15, color: Palette.textLo),
                errorText: _error,
                errorStyle: Type.body
                    .copyWith(fontSize: 11, color: const Color(0xFFE89090)),
                filled: true,
                fillColor: Palette.glassFill,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Palette.glassEdge),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final s in Stat.values)
                  GestureDetector(
                    onTap: () => setState(() => _stat = s),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
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
                              .copyWith(fontSize: 11, color: s.color)),
                    ),
                  ),
              ],
            ),
            DomainHint(_stat),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('DIFFICULTY', style: Type.label.copyWith(fontSize: 11)),
                Text('d${_difficulty.round()}',
                    style: Type.label.copyWith(fontSize: 11, color: Palette.xp)),
              ],
            ),
            Slider(
              value: _difficulty,
              min: 1,
              max: 10,
              divisions: 9,
              activeColor: Palette.xp,
              inactiveColor: const Color(0x1FF2CD93),
              onChanged: (v) => setState(() => _difficulty = v),
            ),
            Center(
              child: GestureDetector(
                onTap: _add,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 26, vertical: 11),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFF6D9A2), Color(0xFFEFC074), Color(0xFFC08B4F)],
                    ),
                    boxShadow: const [
                      BoxShadow(
                          color: Palette.honeyGlow,
                          blurRadius: 16,
                          offset: Offset(0, 5)),
                    ],
                  ),
                  child: Text('PLAN IT',
                      style: Type.label.copyWith(
                          fontSize: 11, color: const Color(0xFF3A2510))),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
