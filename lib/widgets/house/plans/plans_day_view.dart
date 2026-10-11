// The day: the left page's day rows (MON to SUN, today marked, the chosen day
// pointed at) and the right page's day (its date, ADD, the day's cards, PLAN
// QUEST, what was done and written that day).
library;

import 'package:flutter/material.dart';

import '../../../academic_calendar/domain/academic_schedule.dart';
import '../../../academic_calendar/widgets/academic_calendar_sections.dart'
    show formatAcademicTime;
import '../../../academic_calendar/widgets/add_classes_sheet.dart'
    show AddClassesDoorway;
import '../../../audio.dart';
import '../../../daybook/presentation/daybook_range_projection.dart';
import '../../../models.dart';
import '../../../tokens.dart';
import '../../../journal_media.dart' as media;
import 'plans_actions.dart';
import 'plans_cards.dart';
import 'plans_dates.dart';
import 'plans_glass.dart';

// ─────────────────────────────────────────────────────────────────────────────
// The left page
// ─────────────────────────────────────────────────────────────────────────────

/// The day rows on the left page. Tapping a row turns the page to that day.
class PlansDayTabs extends StatelessWidget {
  const PlansDayTabs({
    super.key,
    required this.days,
    required this.selected,
    required this.today,
    required this.onSelect,
  });

  final List<CivilDate> days;
  final CivilDate selected;
  final CivilDate today;
  final ValueChanged<CivilDate> onSelect;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final rowHeight = box.maxHeight / days.length;
        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            children: [
              for (var i = 0; i < days.length; i++)
                _DayTab(
                  date: days[i],
                  first: i == 0,
                  minHeight: rowHeight,
                  selected: days[i] == selected,
                  today: days[i] == today,
                  onTap: () => onSelect(days[i]),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _DayTab extends StatelessWidget {
  const _DayTab({
    required this.date,
    required this.first,
    required this.minHeight,
    required this.selected,
    required this.today,
    required this.onTap,
  });

  final CivilDate date;
  final bool first;
  final double minHeight;
  final bool selected;
  final bool today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false
        ? Duration.zero
        : const Duration(milliseconds: 300);
    final spoken = plansSpokenDate(
      DateTime(date.year, date.month, date.day),
      today: today,
    );
    final line = BorderSide(color: PlansInk.rule, width: 0.6);
    return Semantics(
      key: ValueKey('daybook-day-control-$date'),
      button: true,
      selected: selected,
      label: spoken,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          Sfx.instance.playMaterial(MaterialSound.parchment);
          onTap();
        },
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: first ? line : BorderSide.none, bottom: line),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: AnimatedOpacity(
                  duration: still,
                  opacity: selected ? 1 : 0,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0x26D9A55B), Color(0x00D9A55B)],
                        stops: [0, 0.85],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 13,
                top: 0,
                bottom: 0,
                child: Center(
                  child: AnimatedOpacity(
                    duration: still,
                    opacity: selected ? 1 : 0,
                    child: const SizedBox(
                      width: 8,
                      height: 10,
                      child: CustomPaint(painter: _Pointer()),
                    ),
                  ),
                ),
              ),
              Container(
                constraints: BoxConstraints(minHeight: minHeight),
                padding: const EdgeInsets.fromLTRB(28, 3, 8, 3),
                alignment: Alignment.centerLeft,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plansWeekdayShort[date.weekday - 1],
                      style: const TextStyle(
                        fontFamily: PlansInk.serif,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        height: 1,
                        letterSpacing: 1.9,
                        color: PlansInk.ink,
                        shadows: [
                          Shadow(
                            color: Color(0x40FFFFFF),
                            offset: Offset(0, 0.4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${plansMonthShort[date.month - 1]} ${date.day}',
                      style: const TextStyle(
                        fontFamily: PlansInk.serif,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                        height: 1,
                        letterSpacing: 1.3,
                        color: PlansInk.muted,
                      ),
                    ),
                    if (today) ...[
                      const SizedBox(height: 3),
                      const Text(
                        'TODAY',
                        style: TextStyle(
                          fontFamily: PlansInk.mono,
                          fontWeight: FontWeight.w600,
                          fontSize: Type.minLabel,
                          height: 1,
                          letterSpacing: 0.9,
                          color: PlansInk.brass,
                        ),
                      ),
                    ],
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

class _Pointer extends CustomPainter {
  const _Pointer();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawShadow(path, const Color(0x59462615), 1.5, false);
    canvas.drawPath(path, Paint()..color = PlansInk.brass);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// Under the rows: the term, and the way back to today.
class PlansLeftFoot extends StatelessWidget {
  const PlansLeftFoot({
    super.key,
    required this.arrows,
    required this.termName,
    required this.zoneLabel,
    required this.loading,
    required this.showToday,
    required this.onToday,
  });

  /// The arrows that turn the page back and forward.
  final Widget arrows;
  final String? termName;

  /// "LOCAL TIME" or "CAMPUS TIME": whose clock the times are on.
  final String zoneLabel;
  final bool loading;
  final bool showToday;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    final label = loading
        ? 'Opening your schedule…'
        : (termName == null || termName!.trim().isEmpty)
        ? null
        : termName!;
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Two 44 pt arrows side by side: on a page narrower than that they
          // shrink together rather than run off it.
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: arrows,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 0, 6, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (label != null)
                  Text(
                    loading ? label : label.toUpperCase(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: loading ? PlansInk.serif : PlansInk.mono,
                      fontStyle: loading ? FontStyle.italic : FontStyle.normal,
                      fontWeight: FontWeight.w600,
                      fontSize: loading ? 14 : Type.minLabel,
                      letterSpacing: loading ? 0.3 : 0.6,
                      color: PlansInk.muted,
                    ),
                  ),
                Text(
                  zoneLabel,
                  style: const TextStyle(
                    fontFamily: PlansInk.mono,
                    fontWeight: FontWeight.w600,
                    fontSize: Type.minLabel,
                    letterSpacing: 0.6,
                    color: PlansInk.muted,
                  ),
                ),
                if (showToday)
                  Semantics(
                    button: true,
                    label: 'Back to today',
                    excludeSemantics: true,
                    onTap: onToday,
                    child: GestureDetector(
                      key: const ValueKey('calendar-back-to-today'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        Sfx.instance.playMaterial(MaterialSound.parchment);
                        onToday();
                      },
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 44),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          // It starts at the page's own margin, left of the
                          // term, so the whole of BACK TO TODAY fits a line.
                          child: Transform.translate(
                            offset: const Offset(-14, 0),
                            child: const Text(
                              'BACK TO TODAY',
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.visible,
                              style: TextStyle(
                                fontFamily: PlansInk.mono,
                                fontWeight: FontWeight.w700,
                                fontSize: Type.minLabel,
                                letterSpacing: 0.4,
                                color: PlansInk.brass,
                              ),
                            ),
                          ),
                        ),
                      ),
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

// ─────────────────────────────────────────────────────────────────────────────
// The right page
// ─────────────────────────────────────────────────────────────────────────────

/// ADD, in ink on the paper.
class PlansAddButton extends StatelessWidget {
  const PlansAddButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Add an event, task, class, assignment, or exam',
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        key: const ValueKey('academic-add-class'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 52, minHeight: 44),
          child: Center(
            child: Container(
              height: 30,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(7),
                color: const Color(0x4DFFFAEE),
                border: Border.all(color: const Color(0x574A372A), width: 0.75),
              ),
              child: const Text(
                '+ ADD',
                style: TextStyle(
                  fontFamily: PlansInk.mono,
                  fontWeight: FontWeight.w600,
                  fontSize: Type.minLabel,
                  letterSpacing: 1.4,
                  height: 1,
                  color: Color(0xFF574739),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The right page's heading: the date, and ADD.
class PlansPageHeading extends StatelessWidget {
  const PlansPageHeading({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.onAdd,
    this.extra,
    this.spoken,
    this.compact = false,
  });

  final String eyebrow;
  final String title;

  /// What a screen reader says for the heading (the day's shape, say).
  final String? spoken;

  /// Keeps the date and the controls on one row whatever the text size (the
  /// month's heading, which has a fixed place above its grid).
  final bool compact;
  final VoidCallback onAdd;

  /// Controls that sit beside ADD (the month's arrows).
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final large = !compact && plansTextScale(context) >= 1.5;
    Widget titleText({bool large = false}) => Text(
      title,
      maxLines: large ? 3 : 1,
      overflow: large ? TextOverflow.ellipsis : null,
      style: const TextStyle(
        fontFamily: PlansInk.serif,
        fontWeight: FontWeight.w500,
        fontSize: 24,
        height: 1.04,
        letterSpacing: 0.5,
        color: PlansInk.ink,
      ),
    );
    final words = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          eyebrow,
          maxLines: compact ? 1 : 2,
          overflow: compact ? TextOverflow.ellipsis : null,
          style: const TextStyle(
            fontFamily: PlansInk.mono,
            fontWeight: FontWeight.w600,
            fontSize: Type.minLabel,
            height: 1.1,
            letterSpacing: 1.9,
            color: PlansInk.muted,
          ),
        ),
        const SizedBox(height: 3),
        Semantics(
          header: true,
          label: spoken,
          child: compact
              ? FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: titleText(),
                )
              : titleText(large: large),
        ),
      ],
    );
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ?extra,
        PlansAddButton(onTap: onAdd),
      ],
    );
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0x42533E2D), width: 0.6),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(5, 0, 2, 2),
        child: large
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  words,
                  Align(alignment: Alignment.centerRight, child: actions),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(child: words),
                  actions,
                ],
              ),
      ),
    );
  }
}

/// The right page for one day.
class PlansDayPage extends StatelessWidget {
  const PlansDayPage({
    super.key,
    required this.day,
    required this.now,
    required this.schedule,
    required this.actions,
    required this.completions,
    required this.reflections,
    required this.journalEntries,
    required this.classStatus,
    required this.loading,
  });

  final DaybookDay day;
  final DateTime now;
  final AcademicSchedule schedule;
  final PlansActions actions;
  final int completions;
  final int reflections;
  final List<Note> journalEntries;

  /// "NOW" / "IN 12 MIN" / "NEXT" for the class that is in session or next,
  /// by occurrence key.
  final Map<String, ({String label, bool active})> classStatus;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final date = DateTime(day.date.year, day.date.month, day.date.day);
    final today = CivilDate.fromDateTime(now) == day.date;
    final past = date.isBefore(DateTime(now.year, now.month, now.day));
    final entries = day.entries;
    final academicConflicts = [
      for (final c in day.summary.conflicts)
        if (c.leftDisplayKey.startsWith('class:') &&
            c.rightDisplayKey.startsWith('class:'))
          c,
    ];
    final otherConflicts = [
      for (final c in day.summary.conflicts)
        if (!c.leftDisplayKey.startsWith('class:') ||
            !c.rightDisplayKey.startsWith('class:'))
          c,
    ];
    final transition = [
      for (final e in entries)
        if (e.sourceKind == DaybookSourceKind.classOccurrence &&
            e.transitionPressure)
          e,
    ];
    final hasCourses = schedule.courses.any((c) => !c.archived);
    final spoken = plansSpokenDate(date, today: today);
    // The day's cards in their sections. A heading names a section when the
    // day has more than one, and always for the chosen focus and what is still
    // open: those say something the card does not.
    final groups =
        <
          ({
            DaybookSection section,
            String? heading,
            List<DaybookEntry> entries,
          })
        >[];
    const names = {
      DaybookSection.allDay: 'ALL DAY',
      DaybookSection.timed: 'SCHEDULE',
      DaybookSection.due: 'DUE',
      DaybookSection.focus: 'TODAY’S FOCUS',
      DaybookSection.stillOpen: 'STILL OPEN',
    };
    final present = [
      for (final section in DaybookSection.values)
        if (entries.any((e) => e.section == section)) section,
    ];
    for (final section in present) {
      final always =
          section == DaybookSection.focus ||
          section == DaybookSection.stillOpen;
      groups.add((
        section: section,
        heading: always || present.length > 1 ? names[section] : null,
        entries: [
          for (final e in entries)
            if (e.section == section) e,
        ],
      ));
    }

    final children = <Widget>[
      if (academicConflicts.isNotEmpty)
        _Notice(
          key: ValueKey('academic-conflicts-${day.date}'),
          icon: Icons.call_split_rounded,
          heading: academicConflicts.length == 1
              ? 'TWO CLASSES SHARE THIS TIME'
              : 'PLANS SHARE THIS TIME',
          body: academicConflicts.length == 1
              ? '${academicConflicts.first.message}. Both are still kept.'
              : '${academicConflicts.length} overlaps are sharing this day. Everything is still kept.',
          color: const Color(0xFFF0B0A0),
        ),
      if (otherConflicts.isNotEmpty)
        _Notice(
          key: ValueKey('daybook-conflicts-${day.date}'),
          icon: Icons.call_split_rounded,
          heading: otherConflicts.length == 1
              ? 'TWO PLANS SHARE THIS TIME'
              : 'PLANS SHARE THIS TIME',
          body: otherConflicts.length == 1
              ? '${otherConflicts.first.message}. Both are still kept.'
              : '${otherConflicts.length} overlaps are sharing this day. Everything is still kept.',
          color: const Color(0xFFF0B0A0),
        ),
      if (transition.isNotEmpty)
        _Notice(
          key: ValueKey('academic-transitions-${day.date}'),
          icon: Icons.directions_walk_rounded,
          heading: 'A TIGHT TURNAROUND',
          body:
              '${transition.map((e) => e.title).toSet().join(' and ')} have less transition time than requested. Both classes are still kept.',
          color: PlansInk.ringDone,
        ),
      for (final group in groups) ...[
        if (group.heading != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(5, 4, 5, 7),
            child: Text(
              group.heading!,
              style: TextStyle(
                fontFamily: PlansInk.mono,
                fontWeight: FontWeight.w600,
                fontSize: Type.minLabel,
                letterSpacing: 1.7,
                color: group.section == DaybookSection.stillOpen
                    ? PlansInk.brass
                    : PlansInk.muted,
              ),
            ),
          ),
        for (final entry in group.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: PlansEntryCard(
              key: _cardKey(entry),
              entry: entry,
              day: day,
              schedule: schedule,
              actions: actions,
              first: identical(entry, entries.first),
              status: classStatus[entry.sourceId],
            ),
          ),
      ],
      if (!past)
        Padding(
          padding: const EdgeInsets.only(top: 2, bottom: 6),
          child: Semantics(
            button: true,
            label: 'Plan a one-off Quest for $spoken',
            excludeSemantics: true,
            onTap: actions.onPlanQuest,
            child: PlansPress(
              onTap: actions.onPlanQuest,
              child: PlansGlass(
                child: Container(
                  key: const ValueKey('calendar-plan-selected-day'),
                  constraints: const BoxConstraints(minHeight: 44),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  child: const Text(
                    'PLAN QUEST',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: PlansInk.mono,
                      fontWeight: FontWeight.w600,
                      fontSize: Type.minLabel,
                      letterSpacing: 2.0,
                      color: PlansInk.cream,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(5, 8, 5, 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'DAY SHAPE',
              style: TextStyle(
                fontFamily: PlansInk.mono,
                fontWeight: FontWeight.w600,
                fontSize: Type.minLabel,
                letterSpacing: 1.9,
                color: PlansInk.muted,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              plansDayShape(day.summary),
              style: const TextStyle(
                fontFamily: PlansInk.serif,
                fontStyle: FontStyle.italic,
                fontSize: 15,
                height: 1.2,
                color: PlansInk.muted,
              ),
            ),
          ],
        ),
      ),
      if (completions > 0 || reflections > 0)
        Padding(
          padding: const EdgeInsets.fromLTRB(5, 10, 5, 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (completions > 0)
                _Done(
                  icon: Icons.check_circle_outline_rounded,
                  text:
                      '$completions quest${completions == 1 ? '' : 's'} completed',
                ),
              if (reflections > 0)
                _Done(
                  icon: Icons.auto_stories_outlined,
                  text:
                      '$reflections reflection${reflections == 1 ? '' : 's'} kept',
                ),
            ],
          ),
        ),
      if (journalEntries.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: _JournalLines(
            key: ValueKey('journal-lines-${day.date}'),
            entries: journalEntries,
            onOpen: actions.onOpenJournal,
          ),
        ),
      if (!loading && !hasCourses)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: AddClassesDoorway(onTap: actions.onAddClasses),
        ),
    ];

    return ListView(
      key: const ValueKey('plans-day-list'),
      padding: const EdgeInsets.fromLTRB(1, 10, 2, 40),
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      children: children,
    );
  }

  static Key? _cardKey(DaybookEntry entry) => switch (entry.sourceKind) {
    DaybookSourceKind.classOccurrence => ValueKey(
      'academic-occurrence-${entry.sourceId}',
    ),
    DaybookSourceKind.academicWork => ValueKey(
      'academic-work-${entry.sourceId}',
    ),
    DaybookSourceKind.studyBlock => ValueKey(
      'academic-study-block-${entry.sourceId}',
    ),
    _ => ValueKey('daybook-entry-${entry.displayKey}'),
  };
}

/// The day's shape in a sentence: how many fixed plans, when the first is,
/// what is due.
String plansDayShape(DaybookDaySummary summary) {
  final facts = <String>[];
  if (summary.fixedPlanCount > 0) {
    if (summary.firstTimedStartMinute == null && summary.fixedPlanCount == 1) {
      facts.add('1 all-day plan');
    } else if (summary.fixedPlanCount == 1) {
      facts.add(
        '1 fixed plan · ${formatAcademicTime(summary.firstTimedStartMinute!)}',
      );
    } else if (summary.firstTimedStartMinute != null) {
      facts.add(
        '${summary.fixedPlanCount} fixed plans · first at ${formatAcademicTime(summary.firstTimedStartMinute!)}',
      );
    } else {
      facts.add('${summary.fixedPlanCount} fixed plans');
    }
  }
  if (summary.deadlineCount > 0) {
    facts.add(
      '${summary.deadlineCount} deadline${summary.deadlineCount == 1 ? '' : 's'}',
    );
  }
  if (summary.focusCount > 0) {
    facts.add(
      summary.focusCount == 1
          ? '1 focus'
          : '${summary.focusCount} focus choices',
    );
  }
  return facts.isEmpty ? 'No fixed plans.' : facts.join(' · ');
}

class _Notice extends StatelessWidget {
  const _Notice({
    super.key,
    required this.icon,
    required this.heading,
    required this.body,
    required this.color,
  });

  final IconData icon;
  final String heading;
  final String body;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: PlansGlass(
      soft: true,
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  heading,
                  style: TextStyle(
                    fontFamily: PlansInk.mono,
                    fontWeight: FontWeight.w600,
                    fontSize: Type.minLabel,
                    letterSpacing: 0.9,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12.5,
                    height: 1.3,
                    color: PlansInk.creamSoft,
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

class _Done extends StatelessWidget {
  const _Done({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: PlansInk.brass),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontFamily: PlansInk.serif,
              fontSize: 16,
              height: 1.15,
              color: PlansInk.ink,
            ),
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// What was written that day
// ─────────────────────────────────────────────────────────────────────────────

class _JournalLines extends StatefulWidget {
  const _JournalLines({super.key, required this.entries, required this.onOpen});

  final List<Note> entries;
  final ValueChanged<Note> onOpen;

  @override
  State<_JournalLines> createState() => _JournalLinesState();
}

class _JournalLinesState extends State<_JournalLines> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final shown = _expanded ? widget.entries : widget.entries.take(2);
    final hidden = widget.entries.length - 2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(5, 0, 5, 7),
          child: Text(
            'JOURNAL',
            style: TextStyle(
              fontFamily: PlansInk.mono,
              fontWeight: FontWeight.w600,
              fontSize: Type.minLabel,
              letterSpacing: 1.9,
              color: PlansInk.muted,
            ),
          ),
        ),
        for (final entry in shown)
          _JournalLine(entry: entry, onTap: () => widget.onOpen(entry)),
        if (hidden > 0)
          Semantics(
            button: true,
            expanded: _expanded,
            label: _expanded
                ? 'Show fewer journal entries'
                : 'Show $hidden more journal ${hidden == 1 ? "entry" : "entries"} from this day',
            excludeSemantics: true,
            onTap: () => setState(() => _expanded = !_expanded),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _expanded = !_expanded),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Row(
                    children: [
                      Icon(
                        _expanded
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        size: 18,
                        color: PlansInk.brass,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          _expanded
                              ? 'SHOW FEWER'
                              : '+ $hidden MORE ON THIS DAY',
                          style: const TextStyle(
                            fontFamily: PlansInk.mono,
                            fontWeight: FontWeight.w700,
                            fontSize: Type.minLabel,
                            letterSpacing: 0.9,
                            color: PlansInk.brass,
                          ),
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

class _JournalLine extends StatelessWidget {
  const _JournalLine({required this.entry, required this.onTap});

  final Note entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final preview = entry.text.trim().isEmpty
        ? '${entry.images.length} photo${entry.images.length == 1 ? '' : 's'}'
        : entry.text.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Semantics(
        button: true,
        label: 'Read journal entry. $preview',
        excludeSemantics: true,
        onTap: onTap,
        child: PlansPress(
          key: ValueKey('calendar-journal-entry-${entry.id}'),
          onTap: onTap,
          child: PlansGlass(
            soft: true,
            padding: const EdgeInsets.all(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (entry.images.isNotEmpty) ...[
                    SizedBox.square(
                      dimension: 46,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: media.image(entry.images.first, maxHeight: 46),
                      ),
                    ),
                    const SizedBox(width: 9),
                  ] else ...[
                    const SizedBox.square(
                      dimension: 28,
                      child: Icon(
                        Icons.menu_book_outlined,
                        size: 18,
                        color: PlansInk.creamSoft,
                      ),
                    ),
                    const SizedBox(width: 5),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          preview,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: PlansInk.serif,
                            fontSize: 15,
                            height: 1.2,
                            color: PlansInk.cream,
                          ),
                        ),
                        if (entry.images.length > 1) ...[
                          const SizedBox(height: 3),
                          Text(
                            '${entry.images.length} PHOTOS',
                            style: const TextStyle(
                              fontFamily: PlansInk.mono,
                              fontWeight: FontWeight.w600,
                              fontSize: Type.minLabel,
                              color: PlansInk.creamDim,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: PlansInk.creamDim,
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

/// A small round arrow in ink, for turning a week or a month.
class PlansArrow extends StatelessWidget {
  const PlansArrow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    onTap: onTap,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox.square(
        dimension: 44,
        child: Center(
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0x574A372A), width: 0.75),
              color: const Color(0x33FFFAEE),
            ),
            child: Icon(icon, size: 20, color: PlansInk.ink),
          ),
        ),
      ),
    ),
  );
}
