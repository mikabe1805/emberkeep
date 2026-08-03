import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio.dart';
import '../clock.dart';
import '../engine.dart';
import '../journal_media.dart' as media;
import '../models.dart';
import '../tokens.dart';
import '../widgets/domain_hint.dart';
import '../widgets/facets.dart';
import '../widgets/glass.dart';
import '../widgets/gold_surface.dart';
import '../widgets/luxe_depth.dart';
import '../widgets/night_reflection_sheet.dart';
import 'journal_entry.dart';

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

const _weekdayNames = [
  'MONDAY',
  'TUESDAY',
  'WEDNESDAY',
  'THURSDAY',
  'FRIDAY',
  'SATURDAY',
  'SUNDAY',
];

/// The Plans page: a warm month calendar. Honey tallies = your completion
/// history; stat-colored diamonds = upcoming events/long-term goals. Tap a
/// day to see or plan it. (Push reminders arrive with the phone build —
/// due quests surface on the Quests page meanwhile.)
class CalendarPage extends StatefulWidget {
  const CalendarPage({
    super.key,
    required this.state,
    required this.quests,
    required this.onAdd,
    this.parallax = const AlwaysStoppedAnimation(Offset.zero),
    this.lightDirection,
  });

  final GameState state;
  final List<Quest> quests;
  final bool Function(Quest) onAdd;
  final ValueListenable<Offset> parallax;
  final ValueListenable<Offset>? lightDirection;

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late DateTime _month;
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    final now = Clock.now();
    _month = DateTime(now.year, now.month);
    _selected = DateTime(now.year, now.month, now.day);
  }

  void _moveMonth(int delta) {
    final next = DateTime(_month.year, _month.month + delta);
    final lastDay = DateTime(next.year, next.month + 1, 0).day;
    setState(() {
      _month = next;
      _selected = DateTime(
        next.year,
        next.month,
        _selected.day.clamp(1, lastDay).toInt(),
      );
    });
  }

  void _goToday() {
    final now = Clock.now();
    setState(() {
      _month = DateTime(now.year, now.month);
      _selected = DateTime(now.year, now.month, now.day);
    });
  }

  List<Quest> _eventsOn(DateTime day) => [
    for (final q in widget.quests)
      if (q.dueDate != null && Days.sameDay(q.dueDate!, day)) q,
  ];

  List<Quest> _questsOn(DateTime day) {
    final dayKey = Days.key(day);
    final isToday = Days.sameDay(day, Clock.now());
    final quests = <Quest>[
      for (final q in widget.quests)
        if (q.snoozedDay != dayKey &&
            (q.dueDate != null
                ? Days.sameDay(q.dueDate!, day)
                : q.schedule != QuestSchedule.once
                ? q.scheduledOn(day)
                : isToday))
          q,
    ];
    quests.sort((a, b) {
      final priority = (b.priorityOn(day) ? 1 : 0).compareTo(
        a.priorityOn(day) ? 1 : 0,
      );
      if (priority != 0) return priority;
      final completion = (a.doneFor(day) ? 1 : 0).compareTo(
        b.doneFor(day) ? 1 : 0,
      );
      if (completion != 0) return completion;
      return b.difficulty.compareTo(a.difficulty);
    });
    return quests;
  }

  int _reflectionsOn(DateTime day) {
    var count = widget.state.journal
        .where((n) => Days.sameDay(n.at, day))
        .length;
    for (final stat in Stat.values) {
      count += widget.state
          .notesFor(stat)
          .where((n) => Days.sameDay(n.at, day))
          .length;
    }
    for (final goal in widget.state.goals) {
      count += goal.notes.where((n) => Days.sameDay(n.at, day)).length;
    }
    for (final quest in widget.quests) {
      count += quest.log.where((n) => Days.sameDay(n.at, day)).length;
    }
    return count;
  }

  List<Note> _journalOn(DateTime day) {
    final key = Days.key(day);
    final entries = [
      for (final note in widget.state.journal)
        if ((note.trace?.day ?? Days.key(note.at)) == key) note,
    ]..sort((a, b) => b.at.compareTo(a.at));
    return entries;
  }

  Future<void> _openJournal(Note entry) {
    Sfx.instance.play('tick');
    final night = entry.night;
    if (night != null) {
      return showNightReflectionSheet(
        context,
        initial: night,
        reduceMotion: widget.state.reduceMotion,
      ).then((data) {
        if (!mounted || data == null) return;
        widget.state.updateNightJournalEntry(entry, data);
      });
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => JournalEntryScreen(
          initial: entry,
          accent: Palette.xp,
          themeId: widget.state.canvasTheme,
          reduceMotion: widget.state.reduceMotion,
          heading:
              'Journal · ${_monthNames[entry.at.month - 1]} ${entry.at.day}',
          trace: entry.trace,
          commit: (payload, existing, markEdited) {
            final source = existing ?? entry;
            final updated = source.copyWith(
              text: payload.text,
              rich: payload.rich,
              images: payload.images,
              editedAt: markEdited ? Clock.now() : null,
            );
            widget.state.setJournal(widget.state.journal.replacing(updated));
            return updated;
          },
          onDelete: (note) {
            for (final image in note.images) {
              media.delete(image);
            }
            widget.state.setJournal(widget.state.journal.without(note));
          },
        ),
      ),
    );
    return Future<void>.value();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final now = Clock.now();
        final firstWeekday = DateTime(_month.year, _month.month, 1).weekday;
        final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;

        return LuxePageList(
          assetPath: 'assets/pages/plans-desk-v2.webp',
          title: 'Plans',
          subtitle: 'your days, held in one place',
          icon: Icons.calendar_month_outlined,
          parallax: widget.parallax,
          reduceMotion: widget.state.reduceMotion,
          children: [
            // ── month folio ──────────────────────────────────────
            // The calendar is the largest single plane in the app, so it is
            // built like the bound month-folio in the approved target: a
            // book-cloth board, a brass-ruled masthead, then the dated page
            // inset into it. A flat panel this size read as an empty block.
            GlassPanel(
              blur: true,
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                children: [
                  Row(
                    children: [
                      _Chevron(
                        icon: Icons.chevron_left,
                        label: 'Previous month',
                        onTap: () => _moveMonth(-1),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            '${_monthNames[_month.month - 1].toUpperCase()} ${_month.year}',
                            style: Type.display.copyWith(
                              fontSize: 16,
                              letterSpacing: 2.4,
                              color: Palette.textHi,
                            ),
                          ),
                        ),
                      ),
                      _Chevron(
                        icon: Icons.chevron_right,
                        label: 'Next month',
                        onTap: () => _moveMonth(1),
                      ),
                    ],
                  ),
                  if (_month.year != now.year || _month.month != now.month)
                    TextButton(
                      onPressed: _goToday,
                      child: Text(
                        'BACK TO TODAY',
                        style: Type.label.copyWith(
                          fontSize: 9.5,
                          color: Palette.xpLight,
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),
                  const _FolioRule(),
                  const SizedBox(height: 8),
                  DecoratedBox(
                    decoration: _folioPage,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              for (var i = 0; i < 7; i++)
                                Expanded(
                                  child: Center(
                                    child: Text(
                                      const [
                                        'M',
                                        'T',
                                        'W',
                                        'T',
                                        'F',
                                        'S',
                                        'S',
                                      ][i],
                                      style: Type.label.copyWith(
                                        fontSize: 11,
                                        letterSpacing: 1.4,
                                        color: i >= 5
                                            ? Palette.brass
                                            : Palette.textLo,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          const _FolioRule(strength: 0.55),
                          const SizedBox(height: 3),
                          for (
                            var week = 0;
                            week * 7 - (firstWeekday - 1) < daysInMonth;
                            week++
                          )
                            Row(
                              children: [
                                for (var col = 0; col < 7; col++)
                                  Expanded(
                                    child: _dayCell(
                                      week * 7 + col - (firstWeekday - 1) + 1,
                                      daysInMonth,
                                      now,
                                    ),
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── selected day panel ───────────────────────────────
            _DayPanel(
              day: _selected,
              completions: widget.state.history[Days.key(_selected)] ?? 0,
              reflections: _reflectionsOn(_selected),
              journalEntries: _journalOn(_selected),
              quests: _questsOn(_selected),
              now: now,
              onPlan: () => _showAddEvent(context),
              onOpenJournal: _openJournal,
              lightDirection: widget.lightDirection ?? widget.parallax,
            ),
          ],
        );
      },
    );
  }

  Widget _dayCell(int day, int daysInMonth, DateTime now) {
    if (day < 1 || day > daysInMonth) {
      return ConstrainedBox(constraints: const BoxConstraints(minHeight: 55));
    }
    final date = DateTime(_month.year, _month.month, day);
    final isToday = Days.sameDay(date, now);
    final isSelected = Days.sameDay(date, _selected);
    final done = widget.state.history[Days.key(date)] ?? 0;
    final events = _eventsOn(date);
    final journalEntries = _journalOn(date);

    final spoken = StringBuffer(
      '${_monthNames[date.month - 1]} ${date.day}, ${date.year}',
    );
    if (isToday) spoken.write(', today');
    if (done > 0) {
      spoken.write(', $done quest${done == 1 ? '' : 's'} completed');
    }
    if (events.isNotEmpty) {
      spoken.write(', ${events.length} plan${events.length == 1 ? '' : 's'}');
    }
    if (journalEntries.isNotEmpty) {
      spoken.write(
        ', ${journalEntries.length} journal entr${journalEntries.length == 1 ? 'y' : 'ies'}',
      );
    }
    return Semantics(
      button: true,
      selected: isSelected,
      label: spoken.toString(),
      onTap: () => setState(() => _selected = date),
      child: GestureDetector(
        excludeFromSemantics: true,
        onTap: () {
          Sfx.instance.play('tick');
          setState(() => _selected = date);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dayPlate(
              day,
              date,
              isToday,
              isSelected,
              done,
              events,
              journalEntries.length,
            ),
            // The folio names today under its date, the way the target does —
            // the honey plate alone doesn't say WHICH kind of mark it is.
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 12),
              child: isToday
                  ? Center(
                      child: Text(
                        'TODAY',
                        style: Type.label.copyWith(
                          fontSize: 8,
                          letterSpacing: 0.9,
                          color: Palette.xp.withValues(alpha: 0.85),
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _dayPlate(
    int day,
    DateTime date,
    bool isToday,
    bool isSelected,
    int done,
    List<Quest> events,
    int journalEntries,
  ) {
    return Container(
      constraints: const BoxConstraints(minHeight: 43),
      margin: const EdgeInsets.all(1.5),
      decoration: facetedDecoration(
        cut: 7,
        gradient: isSelected
            ? LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Palette.xpLight.withValues(alpha: 0.22),
                  Palette.xp.withValues(alpha: 0.07),
                ],
              )
            : null,
        borderColor: isToday
            ? Palette.xp.withValues(alpha: 0.85)
            : isSelected
            ? Palette.xpLight.withValues(alpha: 0.55)
            : Colors.transparent,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$day',
            style: Type.numerals.copyWith(
              fontSize: 13,
              color: isToday
                  ? Palette.xp
                  : done > 0
                  ? Palette.textHi
                  : Palette.textMid,
            ),
          ),
          const SizedBox(height: 2),
          SizedBox(
            height: 10,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // One brass pip whose size carries the day's haul. It was a
                // glowing blob whose halo bled into the neighbouring dates;
                // a hard-edged dot is the mark the folio actually wants.
                if (done > 0)
                  Container(
                    width: 3.6 + (done.clamp(1, 9)) * 0.42,
                    height: 3.6 + (done.clamp(1, 9)) * 0.42,
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Palette.xpLight.withValues(
                        alpha: (0.46 + 0.06 * done).clamp(0.46, 0.95),
                      ),
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
                if (journalEntries > 0)
                  Padding(
                    padding: const EdgeInsets.only(left: 1.5),
                    child: Icon(
                      Icons.menu_book_outlined,
                      size: 8,
                      color: Palette.xpLight.withValues(alpha: 0.9),
                    ),
                  ),
              ],
            ),
          ),
        ],
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

/// The dated page inset into the folio board — a shade darker than the board,
/// warmer at the top lip where the desk candle reaches it.
final _folioPage = facetedDecoration(
  cut: 10,
  gradient: const LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x33241A12), Color(0x4D14100D)],
  ),
  borderColor: Palette.brass.withValues(alpha: 0.30),
  borderWidth: 0.9,
);

/// A brass hairline that fades at both ends — the folio's ruled divisions.
class _FolioRule extends StatelessWidget {
  const _FolioRule({this.strength = 1});
  final double strength;

  @override
  Widget build(BuildContext context) => Container(
    height: 1,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          Palette.brass.withValues(alpha: 0),
          Palette.brass.withValues(alpha: 0.62 * strength),
          Palette.brass.withValues(alpha: 0.62 * strength),
          Palette.brass.withValues(alpha: 0),
        ],
        stops: const [0, 0.14, 0.86, 1],
      ),
    ),
  );
}

class _Chevron extends StatelessWidget {
  const _Chevron({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        excludeFromSemantics: true,
        onTap: () {
          Sfx.instance.play('tick');
          onTap();
        },
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: SizedBox.square(
              dimension: 28,
              child: DecoratedBox(
                decoration: agedBrassPlate(cut: 7, strength: 0.8),
                child: Icon(icon, size: 19, color: Palette.xpLight),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DayPanel extends StatelessWidget {
  const _DayPanel({
    required this.day,
    required this.completions,
    required this.reflections,
    required this.journalEntries,
    required this.quests,
    required this.now,
    required this.onPlan,
    required this.onOpenJournal,
    required this.lightDirection,
  });

  final DateTime day;
  final int completions;
  final int reflections;
  final List<Note> journalEntries;
  final List<Quest> quests;
  final DateTime now;
  final VoidCallback onPlan;
  final ValueChanged<Note> onOpenJournal;
  final ValueListenable<Offset> lightDirection;

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
                // "26.7.2026" was a raw numeric locale dump in the one place
                // the design speaks a date out loud. The approved target reads
                // THURSDAY 30 · TODAY.
                child: Text(
                  '${_weekdayNames[day.weekday - 1]} ${day.day}'
                  '${Days.sameDay(day, now) ? " · TODAY" : " · ${_monthNames[day.month - 1].toUpperCase()}"}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Type.label.copyWith(
                    fontSize: 11.5,
                    letterSpacing: 1.5,
                    color: Days.sameDay(day, now)
                        ? Palette.xpLight
                        : Palette.textMid,
                  ),
                ),
              ),
              if (!isPast)
                GestureDetector(
                  onTap: onPlan,
                  child: GoldSurface(
                    cut: 7,
                    glow: false,
                    textured: false,
                    light: lightDirection,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 8,
                      ),
                      child: Text(
                        '+ PLAN',
                        style: Type.label.copyWith(
                          fontSize: 11,
                          letterSpacing: 1.2,
                          color: Palette.onHoney,
                          shadows: const [
                            Shadow(
                              color: Color(0x59FFEBBE),
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ),
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
                  const Icon(
                    Icons.check_circle,
                    size: 14,
                    color: Palette.success,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '$completions quest${completions == 1 ? "" : "s"} completed',
                      style: Type.body.copyWith(
                        fontSize: 13,
                        color: Palette.textMid,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (reflections > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.auto_stories_outlined,
                    size: 14,
                    color: Palette.xpLight,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '$reflections reflection${reflections == 1 ? "" : "s"} kept',
                      style: Type.body.copyWith(
                        fontSize: 13,
                        color: Palette.textMid,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (journalEntries.isNotEmpty) ...[
            const Divider(height: 18, color: Color(0x2EE7C47E)),
            Text(
              'JOURNAL',
              style: Type.label.copyWith(
                fontSize: 10,
                letterSpacing: 1.7,
                color: Palette.xpLight,
              ),
            ),
            const SizedBox(height: 7),
            _JournalDayEntries(
              key: ValueKey(Days.key(day)),
              entries: journalEntries,
              onOpenJournal: onOpenJournal,
            ),
          ],
          if (quests.isEmpty && completions == 0 && reflections == 0)
            Text(
              isPast ? 'A quiet day.' : 'Nothing planned for this day yet.',
              style: Type.body.copyWith(
                fontSize: 13.5,
                fontStyle: FontStyle.italic,
                color: Palette.textLo,
              ),
            ),
          if (quests.isNotEmpty) ...[
            if (completions > 0 || reflections > 0 || journalEntries.isNotEmpty)
              const Divider(height: 17, color: Color(0x2EE7C47E)),
            for (final quest in quests.take(4))
              _PlannedQuestRow(quest: quest, day: day),
            if (quests.length > 4)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 44),
                child: Text(
                  '+ ${quests.length - 4} MORE ON THE QUEST BOARD',
                  style: Type.label.copyWith(
                    fontSize: 9.5,
                    color: Palette.textLo,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _JournalDayEntries extends StatefulWidget {
  const _JournalDayEntries({
    super.key,
    required this.entries,
    required this.onOpenJournal,
  });

  final List<Note> entries;
  final ValueChanged<Note> onOpenJournal;

  @override
  State<_JournalDayEntries> createState() => _JournalDayEntriesState();
}

class _JournalDayEntriesState extends State<_JournalDayEntries> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final shown = _expanded ? widget.entries : widget.entries.take(2);
    final hidden = widget.entries.length - 2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in shown)
          _JournalDayEntry(
            entry: entry,
            onTap: () => widget.onOpenJournal(entry),
          ),
        if (hidden > 0)
          Semantics(
            button: true,
            expanded: _expanded,
            label: _expanded
                ? 'Show fewer journal entries'
                : 'Show $hidden more journal ${hidden == 1 ? "entry" : "entries"} from this day',
            child: InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: BorderRadius.circular(10),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _expanded
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        size: 18,
                        color: Palette.xpLight,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _expanded ? 'SHOW FEWER' : '+ $hidden MORE ON THIS DAY',
                        style: Type.label.copyWith(
                          fontSize: 9.5,
                          color: Palette.xpLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _JournalDayEntry extends StatelessWidget {
  const _JournalDayEntry({required this.entry, required this.onTap});

  final Note entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final preview = entry.text.trim().isEmpty
        ? '${entry.images.length} photo${entry.images.length == 1 ? '' : 's'}'
        : entry.text.trim();
    return Semantics(
      button: true,
      label: 'Open journal entry. $preview',
      child: InkWell(
        key: ValueKey('calendar-journal-entry-${entry.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 7),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Palette.glassFill,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Palette.glassEdge),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (entry.images.isNotEmpty) ...[
                SizedBox.square(
                  dimension: 50,
                  child: media.image(entry.images.first, maxHeight: 50),
                ),
                const SizedBox(width: 10),
              ] else ...[
                const SizedBox.square(
                  dimension: 34,
                  child: Icon(
                    Icons.menu_book_outlined,
                    size: 19,
                    color: Palette.xpLight,
                  ),
                ),
                const SizedBox(width: 7),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      preview,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Type.body.copyWith(
                        fontSize: 13,
                        height: 1.3,
                        color: Palette.textHi,
                      ),
                    ),
                    if (entry.images.length > 1) ...[
                      const SizedBox(height: 3),
                      Text(
                        '${entry.images.length} PHOTOS',
                        style: Type.label.copyWith(
                          fontSize: 9,
                          color: Palette.textLo,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 5),
              const Icon(
                Icons.chevron_right_rounded,
                size: 19,
                color: Palette.textLo,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlannedQuestRow extends StatelessWidget {
  const _PlannedQuestRow({required this.quest, required this.day});

  final Quest quest;
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final done = quest.doneFor(day);
    final timing = quest.dueDate != null
        ? 'PLANNED FOR THIS DAY'
        : quest.schedule.label;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: done
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFF4D99E),
                        Color(0xFFC28B47),
                        Color(0xFF70502D),
                      ],
                    )
                  : null,
              color: done ? null : const Color(0x3A120E0C),
              border: Border.all(
                color: done ? const Color(0xFFF3D49A) : const Color(0x997E705E),
                width: 1.2,
              ),
              boxShadow: done
                  ? const [
                      BoxShadow(
                        color: Color(0x3DE8B865),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: done
                ? const Icon(
                    Icons.check_rounded,
                    size: 19,
                    color: Color(0xFF3B2916),
                  )
                : Icon(quest.stat.icon, size: 15, color: quest.stat.color),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quest.displayTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Type.body.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: done ? Palette.textMid : Palette.textHi,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  '${quest.stat.abbr}  ·  $timing',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Type.label.copyWith(
                    fontSize: 9,
                    color: quest.stat.color.withValues(alpha: 0.82),
                  ),
                ),
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

  static const _presets =
      <
        ({
          String label,
          String title,
          Stat stat,
          double difficulty,
          IconData icon,
        })
      >[
        (
          label: 'FOCUS BLOCK',
          title: 'One focused block',
          stat: Stat.foc,
          difficulty: 4,
          icon: Icons.center_focus_strong,
        ),
        (
          label: 'MOVE GENTLY',
          title: 'Move for ten minutes',
          stat: Stat.vit,
          difficulty: 3,
          icon: Icons.directions_walk,
        ),
        (
          label: 'RESET SPACE',
          title: 'Reset one small space',
          stat: Stat.dis,
          difficulty: 3,
          icon: Icons.auto_awesome,
        ),
        (
          label: 'REACH OUT',
          title: 'Reach out to someone',
          stat: Stat.soc,
          difficulty: 3,
          icon: Icons.waving_hand_outlined,
        ),
      ];

  void _usePreset(
    ({String label, String title, Stat stat, double difficulty, IconData icon})
    preset,
  ) {
    Sfx.instance.play('tick');
    HapticFeedback.selectionClick();
    setState(() {
      _title.text = preset.title;
      _title.selection = TextSelection.collapsed(offset: _title.text.length);
      _stat = preset.stat;
      _difficulty = preset.difficulty;
      _error = null;
    });
  }

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
    final ok = widget.onAdd(
      Quest(
        title: title,
        stat: _stat,
        // a self-entered plan is a custom quest: same 0.85x anti-abuse damping
        // and the documented d8 cap as the unified add sheet (never a fatter
        // payout just for being typed on the calendar).
        difficulty: _difficulty.round().clamp(1, 8),
        schedule: QuestSchedule.once,
        dueDate: widget.day,
        custom: true,
      ),
    );
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
      child: SingleChildScrollView(
        child: GlassPanel(
          tint: const Color(0xF22A211D),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PLAN FOR ${_weekdayNames[widget.day.weekday - 1]} '
                '${widget.day.day} ${_monthNames[widget.day.month - 1].toUpperCase()}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Type.label.copyWith(fontSize: 11),
              ),
              const SizedBox(height: 10),
              Text(
                'START WITH A DAY SHAPE — OR NAME YOUR OWN',
                style: Type.label.copyWith(
                  fontSize: 9.5,
                  color: Palette.textLo,
                ),
              ),
              const SizedBox(height: 7),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final preset in _presets)
                      Padding(
                        padding: const EdgeInsets.only(right: 7),
                        child: GestureDetector(
                          onTap: () => _usePreset(preset),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 7,
                            ),
                            decoration: facetedDecoration(
                              cut: 7,
                              color: preset.stat.color.withValues(alpha: 0.10),
                              borderColor: preset.stat.color.withValues(
                                alpha: 0.34,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  preset.icon,
                                  size: 13,
                                  color: preset.stat.color,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  preset.label,
                                  style: Type.label.copyWith(
                                    fontSize: 9.5,
                                    color: preset.stat.color,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _title,
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                style: Type.body.copyWith(fontSize: 15, color: Palette.textHi),
                decoration: InputDecoration(
                  hintText: 'e.g. Finish the essay draft',
                  hintStyle: Type.body.copyWith(
                    fontSize: 15,
                    color: Palette.textLo,
                  ),
                  errorText: _error,
                  errorStyle: Type.body.copyWith(
                    fontSize: 11,
                    color: const Color(0xFFE89090),
                  ),
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
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: facetedDecoration(
                          cut: 6,
                          color: _stat == s
                              ? s.color.withValues(alpha: 0.22)
                              : Colors.transparent,
                          borderColor: s.color.withValues(
                            alpha: _stat == s ? 0.8 : 0.3,
                          ),
                        ),
                        child: Text(
                          s.abbr,
                          style: Type.label.copyWith(
                            fontSize: 11,
                            color: s.color,
                          ),
                        ),
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
                  Text(
                    'd${_difficulty.round()}',
                    style: Type.label.copyWith(fontSize: 11, color: Palette.xp),
                  ),
                ],
              ),
              Slider(
                value: _difficulty,
                min: 1,
                max: 8,
                divisions: 7,
                activeColor: Palette.xp,
                inactiveColor: const Color(0x1FF2CD93),
                onChanged: (v) => setState(() => _difficulty = v),
              ),
              Center(
                child: GestureDetector(
                  onTap: _add,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 26,
                      vertical: 11,
                    ),
                    decoration: facetedDecoration(
                      cut: 9,
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFFF6D9A2),
                          Color(0xFFEFC074),
                          Color(0xFFC08B4F),
                        ],
                      ),
                      shadows: const [
                        BoxShadow(
                          color: Palette.honeyGlow,
                          blurRadius: 16,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Text(
                      'PLAN IT',
                      style: Type.label.copyWith(
                        fontSize: 11,
                        color: const Color(0xFF3A2510),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
