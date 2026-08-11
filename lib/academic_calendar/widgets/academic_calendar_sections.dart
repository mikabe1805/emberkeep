import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../audio.dart';
import '../../clock.dart';
import '../../tokens.dart';
import '../../widgets/facets.dart';
import '../../widgets/glass.dart';
import '../../widgets/gold_surface.dart';
import '../data/academic_calendar_preferences.dart';
import '../domain/academic_schedule.dart';

typedef OpenAcademicNotebook =
    Future<void> Function(ClassOccurrence occurrence);

typedef SaveAcademicMeeting =
    Future<bool> Function(
      AcademicTerm term,
      AcademicCourse course,
      MeetingSeries series,
    );

typedef SaveAcademicWork = Future<bool> Function(AcademicWorkItem item);
typedef ToggleAcademicWork = Future<void> Function(AcademicWorkItem item);

enum AcademicAddTarget { classMeeting, assignment, exam }

class AcademicCalendarHeader extends StatelessWidget {
  const AcademicCalendarHeader({
    super.key,
    required this.mode,
    required this.termName,
    required this.loading,
    required this.onModeChanged,
    required this.onAddAcademic,
  });

  final AcademicCalendarMode mode;
  final String? termName;
  final bool loading;
  final ValueChanged<AcademicCalendarMode> onModeChanged;
  final VoidCallback onAddAcademic;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: facetedDecoration(
                  cut: 8,
                  color: Palette.xp.withValues(alpha: 0.09),
                  borderColor: Palette.brass.withValues(alpha: 0.46),
                ),
                child: const Icon(
                  Icons.school_outlined,
                  size: 17,
                  color: Palette.xpLight,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ACADEMIC DAYBOOK',
                      style: Type.label.copyWith(
                        fontSize: Type.minLabel,
                        letterSpacing: 1.5,
                        color: Palette.xpLight,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      loading
                          ? 'Opening your schedule…'
                          : termName ??
                                'Classes, rooms, and notes in one place',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Type.body.copyWith(
                        fontSize: 12.5,
                        color: Palette.textLo,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _BrassAction(
                key: const ValueKey('academic-add-class'),
                label: 'ADD',
                semanticLabel: 'Add a class, assignment, or exam',
                icon: Icons.add_rounded,
                onTap: onAddAcademic,
              ),
            ],
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              for (final candidate in AcademicCalendarMode.values)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: candidate == AcademicCalendarMode.day ? 0 : 4,
                    ),
                    child: _ModeCell(
                      mode: candidate,
                      selected: candidate == mode,
                      onTap: () => onModeChanged(candidate),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class AcademicAddChoiceDialog extends StatelessWidget {
  const AcademicAddChoiceDialog({super.key});

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    insetPadding: const EdgeInsets.all(16),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: GlassPanel(
        tint: Palette.dialogSurface,
        padding: const EdgeInsets.fromLTRB(18, 15, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'ADD TO YOUR DAYBOOK',
                    style: Type.label.copyWith(
                      fontSize: 12,
                      color: Palette.xpLight,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: Palette.textLo),
                ),
              ],
            ),
            Text(
              'Keep the class itself, or something the class asks of you.',
              style: Type.body.copyWith(fontSize: 13, color: Palette.textMid),
            ),
            const SizedBox(height: 12),
            _AcademicAddChoice(
              key: const ValueKey('academic-add-choice-class'),
              icon: Icons.calendar_view_week_outlined,
              title: 'CLASS',
              subtitle: 'A weekly lecture, lab, or recitation',
              onTap: () =>
                  Navigator.of(context).pop(AcademicAddTarget.classMeeting),
            ),
            const SizedBox(height: 7),
            _AcademicAddChoice(
              key: const ValueKey('academic-add-choice-assignment'),
              icon: Icons.assignment_outlined,
              title: 'ASSIGNMENT',
              subtitle: 'Course work with a due date and time',
              onTap: () =>
                  Navigator.of(context).pop(AcademicAddTarget.assignment),
            ),
            const SizedBox(height: 7),
            _AcademicAddChoice(
              key: const ValueKey('academic-add-choice-exam'),
              icon: Icons.quiz_outlined,
              title: 'EXAM',
              subtitle: 'A test, midterm, or final on your calendar',
              onTap: () => Navigator.of(context).pop(AcademicAddTarget.exam),
            ),
          ],
        ),
      ),
    ),
  );
}

class _AcademicAddChoice extends StatelessWidget {
  const _AcademicAddChoice({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '$title, $subtitle',
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: Container(
        constraints: const BoxConstraints(minHeight: 58),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: facetedDecoration(
          cut: 9,
          color: Palette.xp.withValues(alpha: 0.07),
          borderColor: Palette.brass.withValues(alpha: 0.42),
        ),
        child: Row(
          children: [
            Icon(icon, size: 21, color: Palette.xpLight),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Type.label.copyWith(
                      fontSize: Type.minLabel,
                      letterSpacing: 1.1,
                      color: Palette.textHi,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Type.body.copyWith(
                      fontSize: 12.5,
                      color: Palette.textMid,
                    ),
                  ),
                ],
              ),
            ),
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

class AcademicDoorway extends StatelessWidget {
  const AcademicDoorway({
    super.key,
    required this.occurrences,
    required this.schedule,
    required this.now,
    required this.active,
    required this.onOpenNotebook,
  });

  final List<ClassOccurrence> occurrences;
  final AcademicSchedule schedule;
  final DateTime now;
  final bool active;
  final OpenAcademicNotebook onOpenNotebook;

  @override
  Widget build(BuildContext context) {
    if (occurrences.isEmpty) return const SizedBox.shrink();
    final occurrence = occurrences.first;
    final course = schedule.courseById(occurrence.courseId);
    if (course == null) return const SizedBox.shrink();
    final beforeStart = now.toUtc().isBefore(occurrence.startInstant);
    final status = active
        ? beforeStart
              ? 'READY IN ${_minutesUntil(now, occurrence.startInstant)} MIN'
              : 'IN CLASS'
        : 'NEXT CLASS · ${_relativeDate(occurrence.date, now)}';
    final accent = Color(course.colorValue);

    return Container(
      key: const ValueKey('academic-now-next'),
      padding: const EdgeInsets.fromLTRB(13, 11, 11, 11),
      decoration: facetedDecoration(
        cut: 13,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: active ? 0.18 : 0.10),
            const Color(0xA619110D),
          ],
        ),
        borderColor: accent.withValues(alpha: active ? 0.65 : 0.36),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _CourseMark(kind: occurrence.kind, color: accent, size: 31),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status,
                  style: Type.label.copyWith(
                    fontSize: Type.minLabel,
                    letterSpacing: 1.4,
                    color: active ? Palette.xpLight : Palette.textLo,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${course.code} · ${occurrence.kind.label}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Type.body.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Palette.textHi,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${formatAcademicTime(occurrence.localStartMinute)}–'
                  '${formatAcademicTime(occurrence.localEndMinute)} · '
                  '${occurrence.place.shortLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Type.body.copyWith(
                    fontSize: 12.5,
                    color: Palette.textMid,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _BrassAction(
            key: const ValueKey('academic-doorway-open-notebook'),
            label: 'NOTES',
            semanticLabel: 'Open ${course.code} notebook',
            icon: Icons.edit_note_rounded,
            onTap: () => onOpenNotebook(occurrence),
          ),
          if (occurrences.length > 1)
            PopupMenuButton<ClassOccurrence>(
              tooltip: 'Choose an active class',
              color: Palette.card,
              icon: const Icon(
                Icons.expand_more_rounded,
                color: Palette.xpLight,
              ),
              onSelected: onOpenNotebook,
              itemBuilder: (context) => [
                for (final other in occurrences)
                  PopupMenuItem(
                    value: other,
                    child: Text(
                      '${schedule.courseById(other.courseId)?.code ?? 'CLASS'} · '
                      '${formatAcademicTime(other.localStartMinute)}',
                      style: Type.body.copyWith(color: Palette.textHi),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class AcademicSpanPanel extends StatelessWidget {
  const AcademicSpanPanel({
    super.key,
    required this.mode,
    required this.selectedDay,
    required this.schedule,
    required this.now,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
    required this.onSelectDay,
    required this.onOpenNotebook,
    required this.onToggleWork,
  });

  final AcademicCalendarMode mode;
  final DateTime selectedDay;
  final AcademicSchedule schedule;
  final DateTime now;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;
  final ValueChanged<DateTime> onSelectDay;
  final OpenAcademicNotebook onOpenNotebook;
  final ToggleAcademicWork onToggleWork;

  @override
  Widget build(BuildContext context) {
    final selected = CivilDate.fromDateTime(selectedDay);
    final term = schedule.termFor(selected) ?? schedule.latestTerm;
    final first = switch (mode) {
      AcademicCalendarMode.week => selected.startOfWeek(
        term?.weekStartsOn ?? DateTime.monday,
      ),
      AcademicCalendarMode.threeDay || AcademicCalendarMode.day => selected,
      AcademicCalendarMode.month => selected,
    };
    final count = mode.spanDays;
    final last = first.addDays(count - 1);

    return GlassPanel(
      key: ValueKey('academic-${mode.name}-view'),
      blur: true,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _SpanChevron(
                icon: Icons.chevron_left,
                label: 'Previous ${mode.label.toLowerCase()}',
                onTap: onPrevious,
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      _rangeLabel(first, last),
                      textAlign: TextAlign.center,
                      style: Type.display.copyWith(
                        fontSize: 15,
                        letterSpacing: 1.7,
                        color: Palette.textHi,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _timeZoneLabel(term?.timeZoneId),
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
              _SpanChevron(
                icon: Icons.chevron_right,
                label: 'Next ${mode.label.toLowerCase()}',
                onTap: onNext,
              ),
            ],
          ),
          if (!CivilDate.fromDateTime(now).isWithin(first, last))
            Center(
              child: TextButton(
                onPressed: onToday,
                child: Text(
                  'BACK TO TODAY',
                  style: Type.label.copyWith(
                    fontSize: Type.minLabel,
                    color: Palette.xpLight,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 4),
          const _AcademicRule(),
          for (var index = 0; index < count; index++) ...[
            AcademicAgendaDay(
              date: first.addDays(index),
              selected: first.addDays(index) == selected,
              today: first.addDays(index) == CivilDate.fromDateTime(now),
              schedule: schedule,
              onSelectDay: onSelectDay,
              onOpenNotebook: onOpenNotebook,
              onToggleWork: onToggleWork,
            ),
            if (index != count - 1) const _AcademicRule(strength: 0.42),
          ],
        ],
      ),
    );
  }
}

class AcademicAgendaDay extends StatelessWidget {
  const AcademicAgendaDay({
    super.key,
    required this.date,
    required this.selected,
    required this.today,
    required this.schedule,
    required this.onSelectDay,
    required this.onOpenNotebook,
    required this.onToggleWork,
    this.compact = false,
  });

  final CivilDate date;
  final bool selected;
  final bool today;
  final AcademicSchedule schedule;
  final ValueChanged<DateTime> onSelectDay;
  final OpenAcademicNotebook onOpenNotebook;
  final ToggleAcademicWork onToggleWork;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final occurrences = schedule.occurrencesOn(date);
    final workItems = schedule.workItemsOn(date);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 6 : 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            button: true,
            selected: selected,
            label:
                '${_weekdayNames[date.weekday - 1]} ${date.day}'
                '${today ? ', today' : ''}',
            child: InkWell(
              onTap: () =>
                  onSelectDay(DateTime(date.year, date.month, date.day)),
              borderRadius: BorderRadius.circular(9),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                '${_weekdayNames[date.weekday - 1]} ${date.day}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Type.label.copyWith(
                                  fontSize: Type.minLabel,
                                  letterSpacing: 1.25,
                                  color: today || selected
                                      ? Palette.xpLight
                                      : Palette.textMid,
                                ),
                              ),
                            ),
                            if (today) ...[
                              const SizedBox(width: 6),
                              Text(
                                'TODAY',
                                style: Type.label.copyWith(
                                  fontSize: Type.minLabel,
                                  color: Palette.xp,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          _dayCountLabel(occurrences.length, workItems.length),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          style: Type.label.copyWith(
                            fontSize: Type.minLabel,
                            color: Palette.textLo,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (occurrences.isEmpty && workItems.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
              child: Text(
                'No classes or course work.',
                style: Type.body.copyWith(
                  fontSize: 12.5,
                  fontStyle: FontStyle.italic,
                  color: Palette.textLo,
                ),
              ),
            )
          else ...[
            for (final occurrence in occurrences)
              AcademicOccurrenceRow(
                occurrence: occurrence,
                course: schedule.courseById(occurrence.courseId),
                onOpenNotebook: () => onOpenNotebook(occurrence),
              ),
            for (final item in workItems)
              AcademicWorkRow(
                item: item,
                course: schedule.courseById(item.courseId),
                onToggle: () => onToggleWork(item),
              ),
          ],
        ],
      ),
    );
  }
}

class AcademicOccurrenceRow extends StatelessWidget {
  const AcademicOccurrenceRow({
    super.key,
    required this.occurrence,
    required this.course,
    required this.onOpenNotebook,
  });

  final ClassOccurrence occurrence;
  final AcademicCourse? course;
  final VoidCallback onOpenNotebook;

  @override
  Widget build(BuildContext context) {
    final accent = Color(course?.colorValue ?? 0xFF8AAFC6);
    final code = course?.code ?? 'CLASS';
    final stateLabel = switch (occurrence.state) {
      OccurrenceState.scheduled => null,
      OccurrenceState.moved => 'MOVED',
      OccurrenceState.cancelled => 'CANCELLED',
    };
    final enabledReminders = occurrence.reminders
        .where((reminder) => reminder.enabled)
        .toList();
    final reminderLabel = enabledReminders.isEmpty
        ? 'reminders off'
        : '${enabledReminders.first.offsetMinutes} minute reminder';
    final semantics =
        '$code, ${occurrence.kind.label}, '
        '${occurrence.date}, '
        '${formatAcademicTime(occurrence.localStartMinute)} to '
        '${formatAcademicTime(occurrence.localEndMinute)}, '
        '${occurrence.place.shortLabel}, '
        '${stateLabel?.toLowerCase() ?? 'scheduled'}, $reminderLabel';

    return Semantics(
      label: semantics,
      container: true,
      child: Container(
        key: ValueKey('academic-occurrence-${occurrence.occurrenceKey}'),
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 7),
        padding: const EdgeInsets.fromLTRB(10, 9, 8, 8),
        decoration: facetedDecoration(
          cut: 10,
          color: occurrence.state == OccurrenceState.cancelled
              ? Palette.glassFill.withValues(alpha: 0.42)
              : accent.withValues(alpha: 0.075),
          borderColor: occurrence.state == OccurrenceState.cancelled
              ? Palette.textLo.withValues(alpha: 0.30)
              : accent.withValues(alpha: 0.30),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: _CourseMark(
                kind: occurrence.kind,
                color: occurrence.state == OccurrenceState.cancelled
                    ? Palette.textLo
                    : accent,
                size: 25,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 7,
                    runSpacing: 3,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '$code · ${occurrence.kind.shortLabel}',
                        style: Type.label.copyWith(
                          fontSize: Type.minLabel,
                          color: occurrence.state == OccurrenceState.cancelled
                              ? Palette.textLo
                              : accent,
                        ),
                      ),
                      if (stateLabel != null)
                        Text(
                          stateLabel,
                          style: Type.label.copyWith(
                            fontSize: Type.minLabel,
                            color: occurrence.state == OccurrenceState.cancelled
                                ? Palette.textLo
                                : Palette.xpLight,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${formatAcademicTime(occurrence.localStartMinute)}–'
                    '${formatAcademicTime(occurrence.localEndMinute)}',
                    style: Type.body.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: occurrence.state == OccurrenceState.cancelled
                          ? Palette.textLo
                          : Palette.textHi,
                      decoration: occurrence.state == OccurrenceState.cancelled
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${occurrence.place.shortLabel} · '
                    '${enabledReminders.isEmpty ? 'reminders off' : '${enabledReminders.first.offsetMinutes} min reminder'}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Type.body.copyWith(
                      fontSize: 12.5,
                      color: Palette.textMid,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            _NotebookButton(
              occurrenceKey: occurrence.occurrenceKey,
              courseCode: code,
              onTap: onOpenNotebook,
            ),
          ],
        ),
      ),
    );
  }
}

class AcademicWorkRow extends StatelessWidget {
  const AcademicWorkRow({
    super.key,
    required this.item,
    required this.course,
    required this.onToggle,
  });

  final AcademicWorkItem item;
  final AcademicCourse? course;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final accent = Color(course?.colorValue ?? 0xFF8AAFC6);
    final code = course?.code ?? 'COURSE';
    final time = item.dueMinute == null
        ? 'No time set'
        : item.kind == AcademicWorkKind.exam
        ? 'At ${formatAcademicTime(item.dueMinute!)}'
        : 'Due ${formatAcademicTime(item.dueMinute!)}';
    final state = item.completed ? 'completed' : 'not completed';
    return Semantics(
      container: true,
      label:
          '$code ${item.kind.label}, ${item.title}, ${item.dueDate}, $time, $state',
      child: Container(
        key: ValueKey('academic-work-${item.workId}'),
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 7),
        padding: const EdgeInsets.fromLTRB(9, 8, 10, 8),
        decoration: facetedDecoration(
          cut: 9,
          color: accent.withValues(alpha: item.completed ? 0.035 : 0.065),
          borderColor: accent.withValues(alpha: item.completed ? 0.18 : 0.34),
        ),
        child: Row(
          children: [
            Semantics(
              button: true,
              checked: item.completed,
              label:
                  '${item.completed ? 'Mark incomplete' : 'Mark complete'}: ${item.title}',
              child: InkWell(
                key: ValueKey('academic-work-toggle-${item.workId}'),
                onTap: onToggle,
                borderRadius: BorderRadius.circular(22),
                child: SizedBox.square(
                  dimension: 44,
                  child: Center(
                    child: Container(
                      width: 25,
                      height: 25,
                      decoration: BoxDecoration(
                        shape: item.kind == AcademicWorkKind.exam
                            ? BoxShape.rectangle
                            : BoxShape.circle,
                        borderRadius: item.kind == AcademicWorkKind.exam
                            ? BorderRadius.circular(6)
                            : null,
                        color: item.completed
                            ? accent.withValues(alpha: 0.85)
                            : Colors.transparent,
                        border: Border.all(
                          color: item.completed ? accent : Palette.textLo,
                        ),
                      ),
                      child: item.completed
                          ? const Icon(
                              Icons.check_rounded,
                              size: 17,
                              color: Color(0xFF17100C),
                            )
                          : Icon(
                              item.kind == AcademicWorkKind.exam
                                  ? Icons.quiz_outlined
                                  : Icons.assignment_outlined,
                              size: 15,
                              color: accent,
                            ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$code · ${item.kind.shortLabel}',
                    style: Type.label.copyWith(
                      fontSize: Type.minLabel,
                      letterSpacing: 0.8,
                      color: item.completed ? Palette.textLo : accent,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Type.body.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: item.completed ? Palette.textLo : Palette.textHi,
                      decoration: item.completed
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$time${item.details == null ? '' : ' · ${item.details}'}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Type.body.copyWith(
                      fontSize: 12.5,
                      color: Palette.textMid,
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

class AddAcademicMeetingDialog extends StatefulWidget {
  const AddAcademicMeetingDialog({
    super.key,
    required this.schedule,
    required this.selectedDay,
    required this.onSave,
  });

  final AcademicSchedule schedule;
  final DateTime selectedDay;
  final SaveAcademicMeeting onSave;

  @override
  State<AddAcademicMeetingDialog> createState() =>
      _AddAcademicMeetingDialogState();
}

class _AddAcademicMeetingDialogState extends State<AddAcademicMeetingDialog> {
  final _termName = TextEditingController();
  final _courseCode = TextEditingController();
  final _courseTitle = TextEditingController();
  final _building = TextEditingController();
  final _room = TextEditingController();

  late AcademicTerm _term;
  late bool _newTerm;
  late CivilDate _termStart;
  late CivilDate _termEnd;
  MeetingKind _kind = MeetingKind.lecture;
  late Set<int> _weekdays;
  TimeOfDay _start = const TimeOfDay(hour: 10, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 11, minute: 15);
  int _colorIndex = 0;
  String? _error;
  bool _saving = false;

  static const _courseColors = <({int value, String label})>[
    (value: 0xFF8AAFC6, label: 'Dusk blue'),
    (value: 0xFF9CBC88, label: 'Moss'),
    (value: 0xFFDD9A72, label: 'Terracotta'),
    (value: 0xFFAE9AC4, label: 'Lilac'),
    (value: 0xFF93A7E0, label: 'Periwinkle'),
    (value: 0xFFC79355, label: 'Aged bronze'),
  ];

  @override
  void initState() {
    super.initState();
    final selected = CivilDate.fromDateTime(widget.selectedDay);
    final existing = widget.schedule.termFor(selected);
    _newTerm = existing == null;
    _term = existing ?? _defaultTerm(selected);
    _termName.text = _term.name;
    _termStart = _term.startDate;
    _termEnd = _term.endDate;
    _weekdays = {selected.weekday};
    _colorIndex = widget.schedule.courses.length % _courseColors.length;
  }

  @override
  void dispose() {
    _termName.dispose();
    _courseCode.dispose();
    _courseTitle.dispose();
    _building.dispose();
    _room.dispose();
    super.dispose();
  }

  Future<void> _pickTermDate({required bool start}) async {
    final initial = (start ? _termStart : _termEnd).dateArithmeticValue;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.utc(2020),
      lastDate: DateTime.utc(2100, 12, 31),
      helpText: start ? 'TERM START' : 'TERM END',
    );
    if (!mounted || picked == null) return;
    final date = CivilDate.fromDateTime(picked);
    setState(() {
      if (start) {
        _termStart = date;
        if (_termEnd.compareTo(date) < 0) _termEnd = date;
      } else {
        _termEnd = date;
        if (_termStart.compareTo(date) > 0) _termStart = date;
      }
      _error = null;
    });
  }

  Future<void> _pickTime({required bool start}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: start ? _start : _end,
      helpText: start ? 'CLASS START' : 'CLASS END',
    );
    if (!mounted || picked == null) return;
    setState(() {
      if (start) {
        _start = picked;
      } else {
        _end = picked;
      }
      _error = null;
    });
  }

  Future<void> _save() async {
    final code = _courseCode.text.trim();
    final title = _courseTitle.text.trim();
    final termName = _termName.text.trim();
    final startMinute = _start.hour * 60 + _start.minute;
    final endMinute = _end.hour * 60 + _end.minute;
    final existingCourse = _matchingCourse;
    if (termName.isEmpty ||
        code.isEmpty ||
        (title.isEmpty && existingCourse == null)) {
      setState(() => _error = 'Add a term name, course code, and course name.');
      return;
    }
    if (_weekdays.isEmpty) {
      setState(() => _error = 'Choose at least one class day.');
      return;
    }
    if (endMinute <= startMinute) {
      setState(() => _error = 'Class end needs to be after its start.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });

    final updatedAt = Clock.now().toUtc();
    final term = AcademicTerm(
      termId: _term.termId,
      name: termName,
      startDate: _termStart,
      endDate: _termEnd,
      timeZoneId: _term.timeZoneId,
      weekStartsOn: _term.weekStartsOn,
    );
    final color = _courseColors[_colorIndex];
    final course =
        existingCourse ??
        AcademicCourse(
          courseId: AcademicIds.create('course'),
          termId: term.termId,
          code: code.toUpperCase(),
          title: title,
          colorValue: color.value,
          colorLabel: color.label,
        );
    final building = _clean(_building.text);
    final room = _clean(_room.text);
    final placeParts = <String>[?building, ?room];
    final place = CampusPlace(
      label: placeParts.isEmpty ? 'Location not set' : placeParts.join(' '),
      building: building,
      room: room,
    );
    final series = MeetingSeries(
      meetingSeriesId: AcademicIds.create('series'),
      courseId: course.courseId,
      kind: _kind,
      weekdays: _weekdays,
      localStartMinute: startMinute,
      localEndMinute: endMinute,
      firstDate: term.startDate,
      lastDate: term.endDate,
      timeZoneId: term.timeZoneId,
      place: place,
      reminders: [
        AcademicReminder(
          reminderId: AcademicIds.create('reminder'),
          offsetMinutes: 10,
        ),
      ],
      updatedAt: updatedAt,
    );

    final saved = await widget.onSave(term, course, series);
    if (!mounted) return;
    if (!saved) {
      Sfx.instance.play('boing');
      setState(() {
        _saving = false;
        _error = 'Couldn’t save this class locally. Try again.';
      });
      return;
    }
    Sfx.instance.play('streak');
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final matchingCourse = _matchingCourse;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: GlassPanel(
          tint: Palette.dialogSurface,
          padding: const EdgeInsets.fromLTRB(18, 15, 18, 18),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'ADD A WEEKLY CLASS',
                        style: Type.label.copyWith(
                          fontSize: 12,
                          color: Palette.xpLight,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Palette.textLo,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                _SectionLabel('TERM'),
                const SizedBox(height: 7),
                TextField(
                  key: const ValueKey('academic-term-name'),
                  controller: _termName,
                  enabled: _newTerm,
                  textCapitalization: TextCapitalization.words,
                  style: _inputStyle,
                  decoration: _fieldDecoration('e.g. Fall 2026'),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Expanded(
                      child: _DateButton(
                        label: 'START',
                        date: _termStart,
                        enabled: _newTerm,
                        onTap: () => _pickTermDate(start: true),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: _DateButton(
                        label: 'END',
                        date: _termEnd,
                        enabled: _newTerm,
                        onTap: () => _pickTermDate(start: false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 13),
                _SectionLabel('COURSE'),
                const SizedBox(height: 7),
                Row(
                  children: [
                    SizedBox(
                      width: 112,
                      child: TextField(
                        key: const ValueKey('academic-course-code'),
                        controller: _courseCode,
                        textCapitalization: TextCapitalization.characters,
                        onChanged: (_) => setState(() => _error = null),
                        style: _inputStyle,
                        decoration: _fieldDecoration('ECE 345'),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: TextField(
                        key: const ValueKey('academic-course-title'),
                        controller: _courseTitle,
                        textCapitalization: TextCapitalization.words,
                        onChanged: (_) => setState(() => _error = null),
                        style: _inputStyle,
                        decoration: _fieldDecoration('Linear Systems'),
                      ),
                    ),
                  ],
                ),
                if (matchingCourse != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'This meeting will join ${matchingCourse.code} instead of creating a duplicate course.',
                      style: Type.body.copyWith(
                        fontSize: 11.5,
                        color: Palette.info,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    for (var index = 0; index < _courseColors.length; index++)
                      Semantics(
                        button: true,
                        selected: index == _colorIndex,
                        label: _courseColors[index].label,
                        child: InkWell(
                          onTap: () => setState(() => _colorIndex = index),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(_courseColors[index].value),
                              border: Border.all(
                                color: index == _colorIndex
                                    ? Palette.textHi
                                    : Palette.glassEdge,
                                width: index == _colorIndex ? 2 : 1,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 13),
                _SectionLabel('WEEKLY MEETING'),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  children: [
                    for (final kind in MeetingKind.values)
                      _SelectChip(
                        label: kind.shortLabel,
                        selected: _kind == kind,
                        onTap: () => setState(() => _kind = kind),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (var day = 1; day <= 7; day++)
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: day == 7 ? 0 : 4),
                          child: _SelectChip(
                            label: _weekdayLetters[day - 1],
                            selected: _weekdays.contains(day),
                            onTap: () => setState(() {
                              _weekdays.contains(day)
                                  ? _weekdays.remove(day)
                                  : _weekdays.add(day);
                              _error = null;
                            }),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _TimeButton(
                        label: 'START',
                        time: _start,
                        onTap: () => _pickTime(start: true),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: _TimeButton(
                        label: 'END',
                        time: _end,
                        onTap: () => _pickTime(start: false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 13),
                _SectionLabel('PLACE'),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const ValueKey('academic-building'),
                        controller: _building,
                        textCapitalization: TextCapitalization.words,
                        style: _inputStyle,
                        decoration: _fieldDecoration('Building'),
                      ),
                    ),
                    const SizedBox(width: 7),
                    SizedBox(
                      width: 104,
                      child: TextField(
                        key: const ValueKey('academic-room'),
                        controller: _room,
                        textCapitalization: TextCapitalization.characters,
                        style: _inputStyle,
                        decoration: _fieldDecoration('Room'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  'Leave both blank to keep this as “Location not set.”',
                  style: Type.body.copyWith(
                    fontSize: 11.5,
                    color: Palette.textLo,
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    key: const ValueKey('academic-class-error'),
                    style: Type.body.copyWith(
                      fontSize: 12,
                      color: Palette.danger,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: GestureDetector(
                    onTap: _saving ? null : _save,
                    child: Opacity(
                      opacity: _saving ? 0.55 : 1,
                      child: GoldSurface(
                        cut: 9,
                        glow: false,
                        textured: false,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                            child: Text(
                              _saving ? 'SAVING…' : 'KEEP THIS CLASS',
                              style: Type.label.copyWith(
                                fontSize: 12,
                                letterSpacing: 1.2,
                                color: Palette.onHoney,
                              ),
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
        ),
      ),
    );
  }

  AcademicCourse? get _matchingCourse {
    final code = _courseCode.text.trim().toLowerCase();
    if (code.isEmpty) return null;
    for (final course in widget.schedule.courses) {
      if (course.termId == _term.termId && course.code.toLowerCase() == code) {
        return course;
      }
    }
    return null;
  }
}

class AddAcademicWorkDialog extends StatefulWidget {
  const AddAcademicWorkDialog({
    super.key,
    required this.schedule,
    required this.selectedDay,
    required this.initialKind,
    required this.onSave,
  });

  final AcademicSchedule schedule;
  final DateTime selectedDay;
  final AcademicWorkKind initialKind;
  final SaveAcademicWork onSave;

  @override
  State<AddAcademicWorkDialog> createState() => _AddAcademicWorkDialogState();
}

class _AddAcademicWorkDialogState extends State<AddAcademicWorkDialog> {
  final _title = TextEditingController();
  final _details = TextEditingController();

  late AcademicWorkKind _kind;
  late CivilDate _dueDate;
  late TimeOfDay _time;
  String? _courseId;
  String? _error;
  bool _saving = false;

  List<AcademicCourse> get _courses => [
    for (final course in widget.schedule.courses)
      if (!course.archived) course,
  ]..sort((left, right) => left.code.compareTo(right.code));

  @override
  void initState() {
    super.initState();
    _kind = widget.initialKind;
    _time = _kind == AcademicWorkKind.exam
        ? const TimeOfDay(hour: 10, minute: 0)
        : const TimeOfDay(hour: 23, minute: 59);
    final selected = CivilDate.fromDateTime(widget.selectedDay);
    final courses = _courses;
    AcademicCourse? initialCourse;
    for (final course in courses) {
      final term = _termForCourse(course);
      if (term != null && selected.isWithin(term.startDate, term.endDate)) {
        initialCourse = course;
        break;
      }
    }
    initialCourse ??= courses.isEmpty ? null : courses.first;
    _courseId = initialCourse?.courseId;
    _dueDate = _dateInsideCourse(selected, initialCourse);
  }

  @override
  void dispose() {
    _title.dispose();
    _details.dispose();
    super.dispose();
  }

  AcademicTerm? _termForCourse(AcademicCourse course) {
    for (final term in widget.schedule.terms) {
      if (term.termId == course.termId) return term;
    }
    return null;
  }

  AcademicCourse? get _course {
    for (final course in _courses) {
      if (course.courseId == _courseId) return course;
    }
    return null;
  }

  CivilDate _dateInsideCourse(CivilDate preferred, AcademicCourse? course) {
    if (course == null) return preferred;
    final term = _termForCourse(course);
    if (term == null) return preferred;
    if (preferred.compareTo(term.startDate) < 0) return term.startDate;
    if (preferred.compareTo(term.endDate) > 0) return term.endDate;
    return preferred;
  }

  void _selectCourse(AcademicCourse course) {
    setState(() {
      _courseId = course.courseId;
      _dueDate = _dateInsideCourse(_dueDate, course);
      _error = null;
    });
  }

  Future<void> _pickDate() async {
    final course = _course;
    final term = course == null ? null : _termForCourse(course);
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate.dateArithmeticValue,
      firstDate: term?.startDate.dateArithmeticValue ?? DateTime.utc(2020),
      lastDate: term?.endDate.dateArithmeticValue ?? DateTime.utc(2100, 12, 31),
      helpText: _kind == AcademicWorkKind.exam ? 'EXAM DATE' : 'DUE DATE',
    );
    if (!mounted || picked == null) return;
    setState(() {
      _dueDate = CivilDate.fromDateTime(picked);
      _error = null;
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
      helpText: _kind == AcademicWorkKind.exam ? 'EXAM TIME' : 'DUE TIME',
    );
    if (!mounted || picked == null) return;
    setState(() {
      _time = picked;
      _error = null;
    });
  }

  Future<void> _save() async {
    final course = _course;
    final title = _title.text.trim();
    if (course == null) {
      setState(() => _error = 'Add a class before adding its course work.');
      return;
    }
    if (title.isEmpty) {
      setState(() => _error = 'Give this ${_kind.label.toLowerCase()} a name.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final saved = await widget.onSave(
      AcademicWorkItem(
        workId: AcademicIds.create('work'),
        courseId: course.courseId,
        kind: _kind,
        title: title,
        dueDate: _dueDate,
        dueMinute: _time.hour * 60 + _time.minute,
        details: _clean(_details.text),
        updatedAt: Clock.now().toUtc(),
      ),
    );
    if (!mounted) return;
    if (!saved) {
      Sfx.instance.play('boing');
      setState(() {
        _saving = false;
        _error = 'Couldn’t save this locally. Try again.';
      });
      return;
    }
    Sfx.instance.play('streak');
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final courses = _courses;
    final label = _kind.label.toUpperCase();
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: GlassPanel(
          tint: Palette.dialogSurface,
          padding: const EdgeInsets.fromLTRB(18, 15, 18, 18),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'ADD AN $label',
                        style: Type.label.copyWith(
                          fontSize: 12,
                          color: Palette.xpLight,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Palette.textLo,
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 7,
                  children: [
                    for (final kind in AcademicWorkKind.values)
                      _SelectChip(
                        label: kind.label.toUpperCase(),
                        selected: kind == _kind,
                        onTap: () => setState(() {
                          _kind = kind;
                          _error = null;
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 13),
                _SectionLabel('COURSE'),
                const SizedBox(height: 7),
                if (courses.isEmpty)
                  Text(
                    'Add a class first, then its assignments and exams can stay attached to it.',
                    style: Type.body.copyWith(
                      fontSize: 13,
                      color: Palette.textMid,
                    ),
                  )
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final course in courses)
                        _SelectChip(
                          label: course.code,
                          selected: course.courseId == _courseId,
                          onTap: () => _selectCourse(course),
                        ),
                    ],
                  ),
                const SizedBox(height: 13),
                _SectionLabel(label),
                const SizedBox(height: 7),
                TextField(
                  key: const ValueKey('academic-work-title'),
                  controller: _title,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => setState(() => _error = null),
                  style: _inputStyle,
                  decoration: _fieldDecoration(
                    _kind == AcademicWorkKind.exam
                        ? 'Midterm 1'
                        : 'Problem set 4',
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _DateButton(
                        label: _kind == AcademicWorkKind.exam
                            ? 'DATE'
                            : 'DUE DATE',
                        date: _dueDate,
                        enabled: courses.isNotEmpty,
                        onTap: _pickDate,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: _TimeButton(
                        label: _kind == AcademicWorkKind.exam
                            ? 'TIME'
                            : 'DUE TIME',
                        time: _time,
                        onTap: _pickTime,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  key: const ValueKey('academic-work-details'),
                  controller: _details,
                  minLines: 2,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  style: _inputStyle,
                  decoration: _fieldDecoration(
                    'Details or chapters (optional)',
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    key: const ValueKey('academic-work-error'),
                    style: Type.body.copyWith(
                      fontSize: 12,
                      color: Palette.danger,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: GestureDetector(
                    key: const ValueKey('academic-work-save'),
                    onTap: _saving ? null : _save,
                    child: Opacity(
                      opacity: _saving ? 0.55 : 1,
                      child: GoldSurface(
                        cut: 9,
                        glow: false,
                        textured: false,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                            child: Text(
                              _saving ? 'SAVING…' : 'KEEP THIS $label',
                              style: Type.label.copyWith(
                                fontSize: 12,
                                letterSpacing: 1.1,
                                color: Palette.onHoney,
                              ),
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
        ),
      ),
    );
  }
}

class _ModeCell extends StatelessWidget {
  const _ModeCell({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final AcademicCalendarMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: '${mode.label} calendar view',
    child: InkWell(
      key: ValueKey('academic-mode-${mode.name}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        alignment: Alignment.center,
        decoration: facetedDecoration(
          cut: 7,
          color: selected
              ? Palette.xp.withValues(alpha: 0.13)
              : Colors.transparent,
          borderColor: selected
              ? Palette.xpLight.withValues(alpha: 0.54)
              : Palette.glassEdge,
        ),
        child: Text(
          mode.label,
          maxLines: 1,
          style: Type.label.copyWith(
            fontSize: Type.minLabel,
            letterSpacing: 0.7,
            color: selected ? Palette.xpLight : Palette.textLo,
          ),
        ),
      ),
    ),
  );
}

class _NotebookButton extends StatelessWidget {
  const _NotebookButton({
    required this.occurrenceKey,
    required this.courseCode,
    required this.onTap,
  });

  final String occurrenceKey;
  final String courseCode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Open $courseCode notebook',
    child: InkWell(
      key: ValueKey('open-notebook-$occurrenceKey'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 54, minHeight: 44),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.edit_note_rounded,
                size: 19,
                color: Palette.xpLight,
              ),
              Text(
                'NOTES',
                style: Type.label.copyWith(
                  fontSize: Type.minLabel,
                  letterSpacing: 0.5,
                  color: Palette.xpLight,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _BrassAction extends StatelessWidget {
  const _BrassAction({
    super.key,
    required this.label,
    required this.semanticLabel,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String semanticLabel;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: semanticLabel,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        constraints: const BoxConstraints(minHeight: 44, minWidth: 58),
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: facetedDecoration(
          cut: 7,
          color: Palette.xp.withValues(alpha: 0.08),
          borderColor: Palette.brass.withValues(alpha: 0.68),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: Palette.xpLight),
            const SizedBox(width: 4),
            Text(
              label,
              style: Type.label.copyWith(
                fontSize: Type.minLabel,
                letterSpacing: 0.7,
                color: Palette.xpLight,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SpanChevron extends StatelessWidget {
  const _SpanChevron({
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
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: SizedBox(
        width: 44,
        height: 44,
        child: Center(
          child: Container(
            width: 28,
            height: 28,
            decoration: facetedDecoration(
              cut: 7,
              color: Palette.xp.withValues(alpha: 0.08),
              borderColor: Palette.brass.withValues(alpha: 0.48),
            ),
            child: Icon(icon, size: 19, color: Palette.xpLight),
          ),
        ),
      ),
    ),
  );
}

class _CourseMark extends StatelessWidget {
  const _CourseMark({
    required this.kind,
    required this.color,
    required this.size,
  });

  final MeetingKind kind;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final shape = switch (kind) {
      MeetingKind.lecture => BoxShape.circle,
      MeetingKind.lab ||
      MeetingKind.recitation ||
      MeetingKind.studio ||
      MeetingKind.officeHours => BoxShape.rectangle,
    };
    final rotation = kind == MeetingKind.recitation ? math.pi / 4 : 0.0;
    final radius = switch (kind) {
      MeetingKind.lab => 2.0,
      MeetingKind.studio => 7.0,
      MeetingKind.officeHours => 12.0,
      _ => 0.0,
    };
    final boxSize = kind == MeetingKind.recitation ? size * 0.70 : size;
    return SizedBox.square(
      dimension: size,
      child: Center(
        child: Transform.rotate(
          angle: rotation,
          child: Container(
            width: boxSize,
            height: boxSize,
            decoration: BoxDecoration(
              shape: shape,
              borderRadius: shape == BoxShape.rectangle
                  ? BorderRadius.circular(radius)
                  : null,
              color: color.withValues(alpha: 0.16),
              border: Border.all(color: color.withValues(alpha: 0.88)),
            ),
            child: rotation == 0
                ? Center(
                    child: Text(
                      kind.shortLabel.characters.first,
                      style: Type.label.copyWith(
                        fontSize: Type.minLabel,
                        color: color,
                      ),
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

class _AcademicRule extends StatelessWidget {
  const _AcademicRule({this.strength = 1});
  final double strength;

  @override
  Widget build(BuildContext context) => Container(
    height: 1,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          Palette.brass.withValues(alpha: 0),
          Palette.brass.withValues(alpha: 0.52 * strength),
          Palette.brass.withValues(alpha: 0),
        ],
      ),
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: Type.label.copyWith(
      fontSize: Type.minLabel,
      letterSpacing: 1.5,
      color: Palette.textLo,
    ),
  );
}

class _SelectChip extends StatelessWidget {
  const _SelectChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: label,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        constraints: const BoxConstraints(minHeight: 38, minWidth: 38),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: facetedDecoration(
          cut: 7,
          color: selected
              ? Palette.xp.withValues(alpha: 0.14)
              : Colors.transparent,
          borderColor: selected
              ? Palette.xpLight.withValues(alpha: 0.58)
              : Palette.glassEdge,
        ),
        child: Text(
          label,
          style: Type.label.copyWith(
            fontSize: Type.minLabel,
            color: selected ? Palette.xpLight : Palette.textLo,
          ),
        ),
      ),
    ),
  );
}

class _DateButton extends StatelessWidget {
  const _DateButton({
    required this.label,
    required this.date,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final CivilDate date;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _PickerButton(
    label: label,
    value: '${_monthNames[date.month - 1]} ${date.day}, ${date.year}',
    enabled: enabled,
    icon: Icons.calendar_today_outlined,
    onTap: onTap,
  );
}

class _TimeButton extends StatelessWidget {
  const _TimeButton({
    required this.label,
    required this.time,
    required this.onTap,
  });

  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _PickerButton(
    label: label,
    value: formatAcademicTime(time.hour * 60 + time.minute),
    enabled: true,
    icon: Icons.schedule_outlined,
    onTap: onTap,
  );
}

class _PickerButton extends StatelessWidget {
  const _PickerButton({
    required this.label,
    required this.value,
    required this.enabled,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final bool enabled;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: enabled,
    label: '$label, $value',
    child: InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Palette.glassFill,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Palette.glassEdge),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: enabled ? Palette.xpLight : Palette.textLo,
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Type.label.copyWith(
                      fontSize: Type.minLabel,
                      color: Palette.textLo,
                    ),
                  ),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Type.body.copyWith(
                      fontSize: 12.5,
                      color: enabled ? Palette.textHi : Palette.textMid,
                    ),
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

AcademicTerm _defaultTerm(CivilDate selected) {
  late final String season;
  late final CivilDate first;
  late final CivilDate last;
  if (selected.month <= 5) {
    season = 'Spring';
    first = CivilDate(selected.year, 1, 1);
    last = CivilDate(selected.year, 5, 31);
  } else if (selected.month <= 8) {
    season = 'Summer';
    first = CivilDate(selected.year, 5, 1);
    last = CivilDate(selected.year, 8, 31);
  } else {
    season = 'Fall';
    first = CivilDate(selected.year, 8, 1);
    last = CivilDate(selected.year, 12, 31);
  }
  return AcademicTerm(
    termId: AcademicIds.create('term'),
    name: '$season ${selected.year}',
    startDate: first,
    endDate: last,
    timeZoneId: 'America/New_York',
  );
}

InputDecoration _fieldDecoration(String hint) => InputDecoration(
  hintText: hint,
  hintStyle: Type.body.copyWith(fontSize: 14, color: Palette.textLo),
  isDense: true,
  filled: true,
  fillColor: Palette.glassFill,
  contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: const BorderSide(color: Palette.glassEdge),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: const BorderSide(color: Palette.glassEdge),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(color: Palette.xpLight.withValues(alpha: 0.72)),
  ),
);

final _inputStyle = Type.body.copyWith(fontSize: 14, color: Palette.textHi);

String formatAcademicTime(int minute) {
  final hour24 = minute ~/ 60;
  final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
  final minutes = (minute % 60).toString().padLeft(2, '0');
  final suffix = hour24 < 12 ? 'AM' : 'PM';
  return '$hour12:$minutes $suffix';
}

String _dayCountLabel(int classes, int workItems) {
  final parts = <String>[];
  if (classes > 0) {
    parts.add('$classes ${classes == 1 ? 'CLASS' : 'CLASSES'}');
  }
  if (workItems > 0) parts.add('$workItems DUE');
  return parts.isEmpty ? 'QUIET DAY' : parts.join(' · ');
}

String _rangeLabel(CivilDate first, CivilDate last) {
  if (first == last) {
    return '${_monthNames[first.month - 1].toUpperCase()} ${first.day}, ${first.year}';
  }
  if (first.year == last.year && first.month == last.month) {
    return '${_monthNames[first.month - 1].toUpperCase()} '
        '${first.day}–${last.day}, ${first.year}';
  }
  return '${_monthNames[first.month - 1].substring(0, 3).toUpperCase()} '
      '${first.day}–${_monthNames[last.month - 1].substring(0, 3).toUpperCase()} '
      '${last.day}, ${last.year}';
}

String _relativeDate(CivilDate date, DateTime now) {
  final today = CivilDate.fromDateTime(now);
  if (date == today) return 'TODAY';
  if (date == today.addDays(1)) return 'TOMORROW';
  return '${_weekdayNames[date.weekday - 1]} ${date.day}';
}

String _timeZoneLabel(String? timeZoneId) {
  if (timeZoneId == null || timeZoneId.trim().isEmpty) return 'CAMPUS TIME';
  final city = timeZoneId.split('/').last.replaceAll('_', ' ').toUpperCase();
  return '$city · CAMPUS TIME';
}

int _minutesUntil(DateTime now, DateTime start) {
  final difference = start.difference(now.toUtc());
  return math.max(1, (difference.inSeconds / 60).ceil());
}

String? _clean(String value) {
  final clean = value.trim();
  return clean.isEmpty ? null : clean;
}

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

const _weekdayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
