import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../audio.dart';
import '../../clock.dart';
import '../../daybook/adapters/campus_place_adapter.dart';
import '../../daybook/data/daybook_preferences.dart';
import '../../daybook/domain/daybook_place.dart';
import '../../daybook/domain/daybook_task.dart';
import '../../daybook/presentation/daybook_range_projection.dart';
import '../../daybook/services/directions_launcher.dart';
import '../../daybook/widgets/daybook_place_fields.dart';
import '../../daybook/widgets/daybook_rows.dart';
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
typedef OpenAcademicStudyPlanner = Future<void> Function(AcademicWorkItem item);
typedef ToggleAcademicStudyBlock =
    Future<void> Function(AcademicStudyBlock block);
typedef SaveAcademicStudyPlan =
    Future<bool> Function(
      AcademicStudyPlan plan,
      List<AcademicStudyBlock> blocks,
    );
typedef UpdateAcademicTransitionBuffer =
    Future<bool> Function(ClassOccurrence occurrence, int minutes);
typedef MoveAcademicOccurrence =
    Future<bool> Function(
      ClassOccurrence occurrence,
      CivilDate date,
      int startMinute,
      int endMinute,
    );
typedef ChangeAcademicOccurrence =
    Future<bool> Function(ClassOccurrence occurrence);
typedef OpenAcademicOccurrenceAdjuster =
    Future<void> Function(ClassOccurrence occurrence);
typedef ToggleDaybookTask =
    Future<void> Function(DaybookTask task, bool completed);
typedef OpenDaybookActions = Future<void> Function(DaybookActionTarget target);
typedef CompleteQuestPlan = void Function(String questTitle, Offset anchor);

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
    final largeText = MediaQuery.textScalerOf(context).scale(12.5) >= 18.75;
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
                  Icons.calendar_month_outlined,
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
                      'DAYBOOK',
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
                                'Events, tasks, classes, and places in one view',
                      maxLines: largeText ? 2 : 1,
                      overflow: largeText
                          ? TextOverflow.clip
                          : TextOverflow.ellipsis,
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
                semanticLabel: 'Add an event, task, class, assignment, or exam',
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

class DaybookSpanPanel extends StatelessWidget {
  const DaybookSpanPanel({
    super.key,
    required this.mode,
    required this.selectedDay,
    required this.daybook,
    required this.schedule,
    required this.now,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
    required this.onSelectDay,
    required this.onOpenNotebook,
    required this.onOpenDaybookActions,
    required this.onToggleTask,
    required this.onToggleWork,
    required this.onOpenStudyPlanner,
    required this.onToggleStudyBlock,
    required this.onUpdateTransitionBuffer,
    required this.onOpenOccurrenceAdjuster,
    required this.directionsLauncher,
    required this.daybookPreferences,
    this.selectedDaySummaryBuilder,
    this.selectedDayHeaderBuilder,
    this.onCompleteQuestPlan,
  });

  final AcademicCalendarMode mode;
  final DateTime selectedDay;
  final DaybookRange daybook;
  final AcademicSchedule schedule;
  final DateTime now;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;
  final ValueChanged<DateTime> onSelectDay;
  final OpenAcademicNotebook onOpenNotebook;
  final OpenDaybookActions onOpenDaybookActions;
  final ToggleDaybookTask onToggleTask;
  final ToggleAcademicWork onToggleWork;
  final OpenAcademicStudyPlanner onOpenStudyPlanner;
  final ToggleAcademicStudyBlock onToggleStudyBlock;
  final UpdateAcademicTransitionBuffer onUpdateTransitionBuffer;
  final OpenAcademicOccurrenceAdjuster onOpenOccurrenceAdjuster;
  final DirectionsLauncher directionsLauncher;
  final DaybookPreferences daybookPreferences;
  final Widget Function(DaybookDay day)? selectedDaySummaryBuilder;
  final Widget Function(DaybookDay day)? selectedDayHeaderBuilder;
  final CompleteQuestPlan? onCompleteQuestPlan;

  @override
  Widget build(BuildContext context) {
    final selected = CivilDate.fromDateTime(selectedDay);
    final term = schedule.termFor(selected) ?? schedule.latestTerm;
    final first = daybook.first;
    final last = daybook.last;
    final count = daybook.days.length;
    final selectedDayData = daybook.dayOn(selected);
    final selectedHeader = selectedDayHeaderBuilder?.call(selectedDayData);
    final selectedSummary = selectedDaySummaryBuilder?.call(selectedDayData);
    final detailsStayWithDay = mode == AcademicCalendarMode.day;

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
          if (!detailsStayWithDay && selectedSummary != null) ...[
            const SizedBox(height: 8),
            selectedSummary,
            const SizedBox(height: 8),
            const _AcademicRule(strength: 0.42),
          ],
          for (var index = 0; index < count; index++) ...[
            // Multi-day rows keep the same 44px date control before and after
            // selection. Their changing overview lives above the list, so a
            // tap never swaps the control underneath the person's finger.
            DaybookAgendaDay(
              day: daybook.dayOn(first.addDays(index)),
              selected: first.addDays(index) == selected,
              today: first.addDays(index) == CivilDate.fromDateTime(now),
              schedule: schedule,
              onSelectDay: onSelectDay,
              onOpenNotebook: onOpenNotebook,
              onOpenDaybookActions: onOpenDaybookActions,
              onToggleTask: onToggleTask,
              onToggleWork: onToggleWork,
              onOpenStudyPlanner: onOpenStudyPlanner,
              onToggleStudyBlock: onToggleStudyBlock,
              onUpdateTransitionBuffer: onUpdateTransitionBuffer,
              onOpenOccurrenceAdjuster: onOpenOccurrenceAdjuster,
              directionsLauncher: directionsLauncher,
              daybookPreferences: daybookPreferences,
              onCompleteQuestPlan: onCompleteQuestPlan,
              header: first.addDays(index) == selected ? selectedHeader : null,
              beforeEntries:
                  detailsStayWithDay && first.addDays(index) == selected
                  ? selectedSummary
                  : null,
            ),
            if (index != count - 1) const _AcademicRule(strength: 0.42),
          ],
        ],
      ),
    );
  }
}

class DaybookAgendaDay extends StatelessWidget {
  const DaybookAgendaDay({
    super.key,
    required this.day,
    required this.selected,
    required this.today,
    required this.schedule,
    required this.onSelectDay,
    required this.onOpenNotebook,
    required this.onOpenDaybookActions,
    required this.onToggleTask,
    required this.onToggleWork,
    required this.onOpenStudyPlanner,
    required this.onToggleStudyBlock,
    required this.onUpdateTransitionBuffer,
    required this.onOpenOccurrenceAdjuster,
    required this.directionsLauncher,
    required this.daybookPreferences,
    this.onCompleteQuestPlan,
    this.header,
    this.beforeEntries,
    this.compact = false,
  });

  final DaybookDay day;
  final bool selected;
  final bool today;
  final AcademicSchedule schedule;
  final ValueChanged<DateTime> onSelectDay;
  final OpenAcademicNotebook onOpenNotebook;
  final OpenDaybookActions onOpenDaybookActions;
  final ToggleDaybookTask onToggleTask;
  final ToggleAcademicWork onToggleWork;
  final OpenAcademicStudyPlanner onOpenStudyPlanner;
  final ToggleAcademicStudyBlock onToggleStudyBlock;
  final UpdateAcademicTransitionBuffer onUpdateTransitionBuffer;
  final OpenAcademicOccurrenceAdjuster onOpenOccurrenceAdjuster;
  final DirectionsLauncher directionsLauncher;
  final DaybookPreferences daybookPreferences;
  final CompleteQuestPlan? onCompleteQuestPlan;
  final Widget? header;
  final Widget? beforeEntries;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final date = day.date;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 6 : 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header ??
              Semantics(
                key: ValueKey('daybook-day-control-$date'),
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
                              _dayCountLabel(day.entries),
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
          if (beforeEntries != null) ...[
            const SizedBox(height: 2),
            beforeEntries!,
            const SizedBox(height: 8),
          ],
          if (day.entries.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
              child: Text(
                'Nothing held for this day yet.',
                style: Type.body.copyWith(
                  fontSize: 12.5,
                  fontStyle: FontStyle.italic,
                  color: Palette.textLo,
                ),
              ),
            )
          else
            DaybookAgendaEntries(
              day: day,
              schedule: schedule,
              onOpenNotebook: onOpenNotebook,
              onOpenDaybookActions: onOpenDaybookActions,
              onToggleTask: onToggleTask,
              onToggleWork: onToggleWork,
              onOpenStudyPlanner: onOpenStudyPlanner,
              onToggleStudyBlock: onToggleStudyBlock,
              onUpdateTransitionBuffer: onUpdateTransitionBuffer,
              onOpenOccurrenceAdjuster: onOpenOccurrenceAdjuster,
              directionsLauncher: directionsLauncher,
              daybookPreferences: daybookPreferences,
              onCompleteQuestPlan: onCompleteQuestPlan,
            ),
        ],
      ),
    );
  }
}

class DaybookAgendaEntries extends StatelessWidget {
  const DaybookAgendaEntries({
    super.key,
    required this.day,
    required this.schedule,
    required this.onOpenNotebook,
    required this.onOpenDaybookActions,
    required this.onToggleTask,
    required this.onToggleWork,
    required this.onOpenStudyPlanner,
    required this.onToggleStudyBlock,
    required this.onUpdateTransitionBuffer,
    required this.onOpenOccurrenceAdjuster,
    required this.directionsLauncher,
    required this.daybookPreferences,
    this.onCompleteQuestPlan,
    this.showNotices = true,
  });

  final DaybookDay day;
  final AcademicSchedule schedule;
  final OpenAcademicNotebook onOpenNotebook;
  final OpenDaybookActions onOpenDaybookActions;
  final ToggleDaybookTask onToggleTask;
  final ToggleAcademicWork onToggleWork;
  final OpenAcademicStudyPlanner onOpenStudyPlanner;
  final ToggleAcademicStudyBlock onToggleStudyBlock;
  final UpdateAcademicTransitionBuffer onUpdateTransitionBuffer;
  final OpenAcademicOccurrenceAdjuster onOpenOccurrenceAdjuster;
  final DirectionsLauncher directionsLauncher;
  final DaybookPreferences daybookPreferences;
  final CompleteQuestPlan? onCompleteQuestPlan;
  final bool showNotices;

  @override
  Widget build(BuildContext context) {
    final academicConflicts = [
      for (final conflict in day.summary.conflicts)
        if (conflict.leftDisplayKey.startsWith('class:') &&
            conflict.rightDisplayKey.startsWith('class:'))
          conflict,
    ];
    final otherConflicts = [
      for (final conflict in day.summary.conflicts)
        if (!conflict.leftDisplayKey.startsWith('class:') ||
            !conflict.rightDisplayKey.startsWith('class:'))
          conflict,
    ];
    final transitionEntries = [
      for (final entry in day.entries)
        if (entry.sourceKind == DaybookSourceKind.classOccurrence &&
            entry.transitionPressure)
          entry,
    ];
    final sections =
        <(DaybookSection, String)>[
              (DaybookSection.allDay, 'ALL DAY'),
              (DaybookSection.timed, 'SCHEDULE'),
              (DaybookSection.due, 'DUE'),
              (DaybookSection.focus, 'TODAY’S FOCUS'),
              (DaybookSection.stillOpen, 'STILL OPEN'),
            ]
            .where(
              (section) =>
                  day.entries.any((entry) => entry.section == section.$1),
            )
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showNotices && academicConflicts.isNotEmpty) ...[
          _DaybookConflictNotice(
            date: day.date,
            conflicts: academicConflicts,
            academic: true,
          ),
          const SizedBox(height: 7),
        ],
        if (showNotices && otherConflicts.isNotEmpty) ...[
          _DaybookConflictNotice(date: day.date, conflicts: otherConflicts),
          const SizedBox(height: 7),
        ],
        if (showNotices && transitionEntries.isNotEmpty) ...[
          _ProjectedTransitionNotice(
            date: day.date,
            entries: transitionEntries,
          ),
          const SizedBox(height: 7),
        ],
        for (
          var sectionIndex = 0;
          sectionIndex < sections.length;
          sectionIndex++
        ) ...[
          if (sectionIndex > 0)
            const Divider(height: 17, color: Color(0x2EE7C47E)),
          Text(
            sections[sectionIndex].$2,
            style: Type.label.copyWith(
              fontSize: Type.minLabel,
              letterSpacing: 1.7,
              color: sections[sectionIndex].$1 == DaybookSection.stillOpen
                  ? Palette.xp
                  : Palette.xpLight,
            ),
          ),
          const SizedBox(height: 7),
          for (final entry in day.entries)
            if (entry.section == sections[sectionIndex].$1)
              _DaybookProjectionEntryRow(
                key: ValueKey('daybook-entry-${entry.displayKey}'),
                entry: entry,
                day: day,
                schedule: schedule,
                onOpenNotebook: onOpenNotebook,
                onOpenDaybookActions: onOpenDaybookActions,
                onToggleTask: onToggleTask,
                onToggleWork: onToggleWork,
                onOpenStudyPlanner: onOpenStudyPlanner,
                onToggleStudyBlock: onToggleStudyBlock,
                onUpdateTransitionBuffer: onUpdateTransitionBuffer,
                onOpenOccurrenceAdjuster: onOpenOccurrenceAdjuster,
                directionsLauncher: directionsLauncher,
                daybookPreferences: daybookPreferences,
                onCompleteQuestPlan: onCompleteQuestPlan,
              ),
        ],
      ],
    );
  }
}

class _DaybookProjectionEntryRow extends StatelessWidget {
  const _DaybookProjectionEntryRow({
    super.key,
    required this.entry,
    required this.day,
    required this.schedule,
    required this.onOpenNotebook,
    required this.onOpenDaybookActions,
    required this.onToggleTask,
    required this.onToggleWork,
    required this.onOpenStudyPlanner,
    required this.onToggleStudyBlock,
    required this.onUpdateTransitionBuffer,
    required this.onOpenOccurrenceAdjuster,
    required this.directionsLauncher,
    required this.daybookPreferences,
    this.onCompleteQuestPlan,
  });

  final DaybookEntry entry;
  final DaybookDay day;
  final AcademicSchedule schedule;
  final OpenAcademicNotebook onOpenNotebook;
  final OpenDaybookActions onOpenDaybookActions;
  final ToggleDaybookTask onToggleTask;
  final ToggleAcademicWork onToggleWork;
  final OpenAcademicStudyPlanner onOpenStudyPlanner;
  final ToggleAcademicStudyBlock onToggleStudyBlock;
  final UpdateAcademicTransitionBuffer onUpdateTransitionBuffer;
  final OpenAcademicOccurrenceAdjuster onOpenOccurrenceAdjuster;
  final DirectionsLauncher directionsLauncher;
  final DaybookPreferences daybookPreferences;
  final CompleteQuestPlan? onCompleteQuestPlan;

  @override
  Widget build(BuildContext context) {
    final conflict = day.summary.conflicts.any(
      (item) =>
          item.leftDisplayKey == entry.displayKey ||
          item.rightDisplayKey == entry.displayKey,
    );
    final classAction = entry.action is AcademicOccurrenceAction;
    final classActions = classAction
        ? _OccurrenceActions(
            occurrenceKey: entry.sourceId,
            courseCode: entry.title,
            onOpenNotebook: _openNotebook,
            onAdjust: entry.adjustable ? _openOccurrenceAdjuster : null,
          )
        : null;
    final daybookActions = switch (entry.action) {
      DaybookEventAction() => DaybookRowActionsButton(
        key: ValueKey('daybook-event-actions-${entry.sourceId}'),
        title: entry.title,
        onTap: _openDaybookActions,
      ),
      DaybookTaskAction() => DaybookRowActionsButton(
        key: ValueKey('daybook-task-actions-${entry.sourceId}'),
        title: entry.title,
        onTap: _openDaybookActions,
      ),
      _ => null,
    };
    final sourceActions = classActions ?? daybookActions;
    final directionsAction = switch (entry.place) {
      final place?
          when place.hasGoogleDestination || place.hasAppleDestination =>
        DaybookDirectionsAction(
          place: place,
          launcher: directionsLauncher,
          preferences: daybookPreferences,
        ),
      _ => null,
    };
    final actions = sourceActions == null && directionsAction == null
        ? null
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ?sourceActions,
              if (sourceActions != null && directionsAction != null)
                const SizedBox(height: 2),
              ?directionsAction,
            ],
          );
    final footer = switch (entry.action) {
      AcademicOccurrenceAction() when entry.transitionPressure => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TIGHT TURNAROUND',
            key: ValueKey('academic-transition-${entry.sourceId}'),
            style: Type.label.copyWith(
              fontSize: Type.minLabel,
              color: Palette.xp,
            ),
          ),
          const SizedBox(height: 7),
          _TransitionBufferButton(
            occurrenceKey: entry.sourceId,
            courseCode: entry.title,
            transitionBufferMinutes: entry.transitionBufferMinutes ?? 10,
            onSetTransitionBuffer: _setTransitionBuffer,
          ),
        ],
      ),
      AcademicWorkAction() when !entry.completed => _ProjectedStudyPlanAction(
        workId: entry.sourceId,
        title: entry.title,
        plannedMinutes: entry.plannedStudyMinutes,
        targetMinutes: entry.targetStudyMinutes,
        onTap: _openStudyPlanner,
      ),
      _ => null,
    };
    final toggle = switch (entry.action) {
      DaybookTaskAction() => _ProjectedCompletionButton(
        key: ValueKey('daybook-task-toggle-${entry.sourceId}'),
        title: entry.title,
        completed: entry.completed,
        accent: _entryAccent(entry),
        icon: Icons.check_rounded,
        onTap: _toggleTask,
      ),
      AcademicWorkAction() => _ProjectedCompletionButton(
        key: ValueKey('academic-work-toggle-${entry.sourceId}'),
        title: entry.title,
        completed: entry.completed,
        accent: _entryAccent(entry),
        icon: Icons.assignment_outlined,
        onTap: _toggleWork,
      ),
      AcademicStudyAction() => _ProjectedCompletionButton(
        key: ValueKey('academic-study-toggle-${entry.sourceId}'),
        title: 'study ${entry.title}',
        completed: entry.completed,
        accent: _entryAccent(entry),
        icon: Icons.menu_book_rounded,
        onTap: _toggleStudyBlock,
      ),
      QuestPlanAction() when day.date == CivilDate.fromDateTime(Clock.now()) =>
        _ProjectedCompletionButton(
          key: ValueKey('quest-plan-toggle-${entry.sourceId}'),
          title: entry.title,
          completed: entry.completed,
          accent: _entryAccent(entry),
          icon: Icons.check_rounded,
          onTapAt: !entry.completed && onCompleteQuestPlan != null
              ? _completeQuestPlan
              : null,
          canReopen: false,
        ),
      _ => null,
    };
    return _ProjectedDaybookEntryRow(
      key: _sourceRowKey(entry),
      entry: entry,
      conflict: conflict,
      leading: toggle,
      actions: actions,
      footer: footer,
    );
  }

  Future<void> _openDaybookActions() => onOpenDaybookActions(entry.action);

  Future<void> _toggleTask() async {
    final action = entry.action as DaybookTaskAction;
    final task = schedule.tasks
        .where((item) => item.taskId == action.taskId)
        .firstOrNull;
    if (task != null) await onToggleTask(task, !entry.completed);
  }

  void _completeQuestPlan(Offset anchor) {
    final action = entry.action as QuestPlanAction;
    onCompleteQuestPlan?.call(action.questTitle, anchor);
  }

  Future<void> _toggleWork() async {
    final action = entry.action as AcademicWorkAction;
    final item = schedule.workItems
        .where((candidate) => candidate.workId == action.workId)
        .firstOrNull;
    if (item != null) await onToggleWork(item);
  }

  Future<void> _openStudyPlanner() async {
    final action = entry.action as AcademicWorkAction;
    final item = schedule.workItems
        .where((candidate) => candidate.workId == action.workId)
        .firstOrNull;
    if (item != null) await onOpenStudyPlanner(item);
  }

  Future<void> _toggleStudyBlock() async {
    final action = entry.action as AcademicStudyAction;
    final block = schedule.studyBlocks
        .where((candidate) => candidate.studyBlockId == action.studyBlockId)
        .firstOrNull;
    if (block != null) await onToggleStudyBlock(block);
  }

  Future<void> _openNotebook() async {
    final occurrence = _actionOccurrence();
    if (occurrence != null) await onOpenNotebook(occurrence);
  }

  Future<void> _openOccurrenceAdjuster() async {
    final occurrence = _actionOccurrence();
    if (occurrence != null) await onOpenOccurrenceAdjuster(occurrence);
  }

  Future<void> _setTransitionBuffer(int minutes) async {
    final occurrence = _actionOccurrence();
    if (occurrence != null) {
      await onUpdateTransitionBuffer(occurrence, minutes);
    }
  }

  ClassOccurrence? _actionOccurrence() {
    final action = entry.action as AcademicOccurrenceAction;
    return schedule.occurrenceByKey(action.occurrenceKey);
  }
}

class _ProjectedDaybookEntryRow extends StatelessWidget {
  const _ProjectedDaybookEntryRow({
    super.key,
    required this.entry,
    required this.conflict,
    required this.leading,
    required this.actions,
    required this.footer,
  });

  final DaybookEntry entry;
  final bool conflict;
  final Widget? leading;
  final Widget? actions;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final accent = _entryAccent(entry);
    final largeText = MediaQuery.textScalerOf(context).scale(14) >= 21;
    final expandQuestTitle =
        largeText && entry.sourceKind == DaybookSourceKind.questPlan;
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (entry.sourceLabel != null)
          Text(
            entry.sourceLabel!,
            style: Type.label.copyWith(
              fontSize: Type.minLabel,
              letterSpacing: 0.8,
              color: entry.completed || entry.cancelled
                  ? Palette.textLo
                  : accent,
            ),
          ),
        if (entry.sourceLabel == null ||
            !entry.sourceLabel!.startsWith(entry.title)) ...[
          if (entry.sourceLabel != null) const SizedBox(height: 2),
          Text(
            entry.title,
            maxLines: expandQuestTitle ? null : (largeText ? 3 : 2),
            overflow: largeText ? TextOverflow.clip : TextOverflow.ellipsis,
            style: Type.body.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: entry.completed || entry.cancelled
                  ? Palette.textLo
                  : Palette.textHi,
              decoration: entry.completed || entry.cancelled
                  ? TextDecoration.lineThrough
                  : null,
            ),
          ),
        ],
        const SizedBox(height: 2),
        Wrap(
          spacing: 7,
          runSpacing: 3,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              _projectedEntryTiming(entry),
              style: Type.label.copyWith(
                fontSize: Type.minLabel,
                color: entry.cancelled ? Palette.textLo : Palette.xpLight,
              ),
            ),
            if (entry.moved)
              Text(
                'MOVED',
                style: Type.label.copyWith(
                  fontSize: Type.minLabel,
                  color: Palette.xpLight,
                ),
              ),
            if (entry.cancelled)
              Text(
                'CANCELLED',
                style: Type.label.copyWith(
                  fontSize: Type.minLabel,
                  color: Palette.textLo,
                ),
              ),
            if (conflict)
              Text(
                'OVERLAP',
                key: ValueKey('academic-overlap-${entry.sourceId}'),
                style: Type.label.copyWith(
                  fontSize: Type.minLabel,
                  color: Palette.danger,
                ),
              ),
          ],
        ),
        if (entry.place != null ||
            (entry.supportingText != null &&
                entry.sourceKind != DaybookSourceKind.studyBlock)) ...[
          const SizedBox(height: 2),
          Text(
            [
              if (entry.place != null) entry.place!.savedName,
              if (entry.supportingText != null &&
                  entry.sourceKind != DaybookSourceKind.studyBlock)
                entry.supportingText!,
            ].join(' · '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Type.body.copyWith(fontSize: 12.5, color: Palette.textMid),
          ),
        ],
        if (footer != null) ...[const SizedBox(height: 7), footer!],
      ],
    );
    final icon = Icon(
      _entryIcon(entry),
      size: 20,
      color: entry.completed || entry.cancelled ? Palette.textLo : accent,
    );
    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        leading ?? Padding(padding: const EdgeInsets.all(12), child: icon),
        const SizedBox(width: 5),
        Expanded(child: details),
        if (!largeText && actions != null) ...[
          const SizedBox(width: 6),
          actions!,
        ],
      ],
    );
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: _projectedEntrySemantics(entry),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 7),
        padding: const EdgeInsets.fromLTRB(9, 8, 10, 8),
        decoration: facetedDecoration(
          cut: 9,
          color: accent.withValues(
            alpha: entry.completed || entry.cancelled ? 0.03 : 0.06,
          ),
          borderColor: accent.withValues(
            alpha: entry.completed || entry.cancelled ? 0.17 : 0.34,
          ),
        ),
        child: largeText && actions != null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  content,
                  const SizedBox(height: 6),
                  Align(alignment: Alignment.centerRight, child: actions!),
                ],
              )
            : content,
      ),
    );
  }
}

class _ProjectedCompletionButton extends StatelessWidget {
  const _ProjectedCompletionButton({
    super.key,
    required this.title,
    required this.completed,
    required this.accent,
    required this.icon,
    this.onTap,
    this.onTapAt,
    this.canReopen = true,
  }) : assert(onTap == null || onTapAt == null);

  final String title;
  final bool completed;
  final Color accent;
  final IconData icon;
  final VoidCallback? onTap;
  final ValueChanged<Offset>? onTapAt;
  final bool canReopen;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null || onTapAt != null;
    void activate() {
      onTap?.call();
      final callback = onTapAt;
      if (callback == null) return;
      final box = context.findRenderObject() as RenderBox?;
      final anchor = box == null || !box.hasSize
          ? Offset.zero
          : box.localToGlobal(box.size.center(Offset.zero));
      callback(anchor);
    }

    return Semantics(
      button: enabled,
      enabled: enabled,
      checked: completed,
      label: completed && (!enabled || !canReopen)
          ? '$title complete'
          : completed
          ? 'Mark $title open'
          : 'Mark $title complete',
      child: InkWell(
        onTap: enabled ? activate : null,
        customBorder: const CircleBorder(),
        child: SizedBox.square(
          dimension: 44,
          child: Center(
            child: Container(
              width: 27,
              height: 27,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: completed
                    ? accent.withValues(alpha: 0.82)
                    : Colors.transparent,
                border: Border.all(color: completed ? accent : Palette.textLo),
              ),
              child: Icon(
                completed ? Icons.check_rounded : icon,
                size: 16,
                color: completed ? const Color(0xFF17100C) : accent,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProjectedStudyPlanAction extends StatelessWidget {
  const _ProjectedStudyPlanAction({
    required this.workId,
    required this.title,
    required this.plannedMinutes,
    required this.targetMinutes,
    required this.onTap,
  });

  final String workId;
  final String title;
  final int? plannedMinutes;
  final int? targetMinutes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasPlan = targetMinutes != null;
    return Semantics(
      button: true,
      label: hasPlan
          ? 'Review study plan for $title'
          : 'Plan study time for $title',
      child: InkWell(
        key: ValueKey('academic-plan-study-$workId'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 9),
          decoration: facetedDecoration(
            cut: 7,
            color: Palette.xp.withValues(alpha: 0.06),
            borderColor: Palette.brass.withValues(alpha: 0.44),
          ),
          child: Row(
            children: [
              const Icon(Icons.schedule_rounded, size: 16, color: Palette.xp),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  hasPlan
                      ? '${plannedMinutes ?? 0} / $targetMinutes MIN PLANNED'
                      : 'PLAN STUDY TIME',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Type.label.copyWith(
                    fontSize: Type.minLabel,
                    letterSpacing: 0.55,
                    color: Palette.xpLight,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 17,
                color: Palette.xpLight,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Key? _sourceRowKey(DaybookEntry entry) => switch (entry.sourceKind) {
  DaybookSourceKind.classOccurrence => ValueKey(
    'academic-occurrence-${entry.sourceId}',
  ),
  DaybookSourceKind.academicWork => ValueKey('academic-work-${entry.sourceId}'),
  DaybookSourceKind.studyBlock => ValueKey(
    'academic-study-block-${entry.sourceId}',
  ),
  _ => null,
};

Color _entryAccent(DaybookEntry entry) => Color(
  entry.accentColorValue ??
      switch (entry.sourceKind) {
        DaybookSourceKind.event => 0xFFE7C47E,
        DaybookSourceKind.task => 0xFFCFA766,
        DaybookSourceKind.classOccurrence ||
        DaybookSourceKind.academicWork ||
        DaybookSourceKind.studyBlock => 0xFF8AAFC6,
        DaybookSourceKind.questPlan => 0xFFE0B763,
      },
);

IconData _entryIcon(DaybookEntry entry) => switch (entry.sourceKind) {
  DaybookSourceKind.event => Icons.event_outlined,
  DaybookSourceKind.task => Icons.check_circle_outline_rounded,
  DaybookSourceKind.classOccurrence => Icons.school_outlined,
  DaybookSourceKind.academicWork => Icons.assignment_outlined,
  DaybookSourceKind.studyBlock => Icons.menu_book_rounded,
  DaybookSourceKind.questPlan => Icons.auto_awesome_mosaic_outlined,
};

String _projectedEntryTiming(DaybookEntry entry) => switch (entry.section) {
  DaybookSection.allDay => 'ALL DAY',
  DaybookSection.timed =>
    '${_projectedTime(entry.startMinute!)}–${_projectedTime(entry.endMinute!)}'
        '${entry.sourceKind == DaybookSourceKind.studyBlock && entry.supportingText != null ? ' · ${entry.supportingText}' : ''}',
  DaybookSection.due =>
    entry.startMinute == null
        ? 'DUE'
        : 'DUE ${_projectedTime(entry.startMinute!)}',
  DaybookSection.focus => 'CHOSEN FOR TODAY',
  DaybookSection.stillOpen =>
    entry.startMinute == null
        ? 'DUE'
        : 'DUE ${_projectedTime(entry.startMinute!)}',
};

String _projectedEntrySemantics(DaybookEntry entry) {
  final parts = <String>[
    entry.title,
    switch (entry.section) {
      DaybookSection.allDay => 'all day',
      DaybookSection.timed => 'schedule',
      DaybookSection.due => 'due',
      DaybookSection.focus => 'today’s focus',
      DaybookSection.stillOpen => 'still open',
    },
    if (entry.section == DaybookSection.timed)
      '${_projectedTime(entry.startMinute!)} to ${_projectedTime(entry.endMinute!)}'
    else if (entry.startMinute != null)
      _projectedTime(entry.startMinute!),
    if (entry.moved) 'moved',
    if (entry.cancelled) 'cancelled',
    if (entry.completed) 'completed',
    if (entry.place != null) entry.place!.savedName,
  ];
  return parts.join(', ');
}

String _projectedTime(int minute) =>
    minute == 24 * 60 ? '12:00 AM' : formatAcademicTime(minute);

class _DaybookConflictNotice extends StatelessWidget {
  const _DaybookConflictNotice({
    required this.date,
    required this.conflicts,
    this.academic = false,
  });

  final CivilDate date;
  final List<DaybookConflict> conflicts;
  final bool academic;

  @override
  Widget build(BuildContext context) => Container(
    key: ValueKey('${academic ? 'academic' : 'daybook'}-conflicts-$date'),
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
    decoration: facetedDecoration(
      cut: 9,
      color: Palette.danger.withValues(alpha: 0.055),
      borderColor: Palette.danger.withValues(alpha: 0.42),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.call_split_rounded, size: 18, color: Palette.danger),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                conflicts.length == 1
                    ? academic
                          ? 'TWO CLASSES SHARE THIS TIME'
                          : 'TWO PLANS SHARE THIS TIME'
                    : 'PLANS SHARE THIS TIME',
                style: Type.label.copyWith(
                  fontSize: Type.minLabel,
                  color: Palette.danger,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                conflicts.length == 1
                    ? '${conflicts.first.message}. Both are still kept.'
                    : '${conflicts.length} overlaps are sharing this day. Everything is still kept.',
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
  );
}

class _ProjectedTransitionNotice extends StatelessWidget {
  const _ProjectedTransitionNotice({required this.date, required this.entries});

  final CivilDate date;
  final List<DaybookEntry> entries;

  @override
  Widget build(BuildContext context) => Container(
    key: ValueKey('academic-transitions-$date'),
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
    decoration: facetedDecoration(
      cut: 9,
      color: Palette.xp.withValues(alpha: 0.055),
      borderColor: Palette.brass.withValues(alpha: 0.42),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.directions_walk_rounded, size: 18, color: Palette.xp),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'A TIGHT TURNAROUND',
                style: Type.label.copyWith(
                  fontSize: Type.minLabel,
                  color: Palette.xp,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${entries.map((entry) => entry.title).toSet().join(' and ')} have less transition time than requested. Both classes are still kept.',
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
  );
}

class AcademicOccurrenceRow extends StatelessWidget {
  const AcademicOccurrenceRow({
    super.key,
    required this.occurrence,
    required this.course,
    this.transitionBufferMinutes = 10,
    this.conflict = false,
    this.transitionPressure = false,
    required this.onOpenNotebook,
    required this.onSetTransitionBuffer,
    this.onAdjust,
  });

  final ClassOccurrence occurrence;
  final AcademicCourse? course;
  final int transitionBufferMinutes;
  final bool conflict;
  final bool transitionPressure;
  final VoidCallback onOpenNotebook;
  final ValueChanged<int> onSetTransitionBuffer;
  final VoidCallback? onAdjust;

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
        '${stateLabel?.toLowerCase() ?? 'scheduled'}, $reminderLabel'
        '${conflict ? ', overlaps another class' : ''}'
        '${transitionPressure ? ', has a tight transition' : ''}, '
        '${transitionBufferMinutes == 0 ? 'no transition buffer' : '$transitionBufferMinutes minute transition buffer'}';
    final largeText = MediaQuery.textScalerOf(context).scale(14) >= 14 * 1.5;
    final mark = Padding(
      padding: const EdgeInsets.only(top: 2),
      child: _CourseMark(
        kind: occurrence.kind,
        color: occurrence.state == OccurrenceState.cancelled
            ? Palette.textLo
            : accent,
        size: 25,
      ),
    );
    final details = _AcademicOccurrenceDetails(
      occurrence: occurrence,
      code: code,
      accent: accent,
      stateLabel: stateLabel,
      enabledReminders: enabledReminders,
      conflict: conflict,
      transitionPressure: transitionPressure,
      transitionBufferMinutes: transitionBufferMinutes,
      onSetTransitionBuffer: onSetTransitionBuffer,
    );
    final actions = _OccurrenceActions(
      occurrenceKey: occurrence.occurrenceKey,
      courseCode: code,
      onOpenNotebook: onOpenNotebook,
      onAdjust: onAdjust,
    );

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
        child: largeText
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      mark,
                      const SizedBox(width: 9),
                      Expanded(child: details),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Align(alignment: Alignment.centerRight, child: actions),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  mark,
                  const SizedBox(width: 9),
                  Expanded(child: details),
                  const SizedBox(width: 6),
                  actions,
                ],
              ),
      ),
    );
  }
}

class _AcademicOccurrenceDetails extends StatelessWidget {
  const _AcademicOccurrenceDetails({
    required this.occurrence,
    required this.code,
    required this.accent,
    required this.stateLabel,
    required this.enabledReminders,
    required this.conflict,
    required this.transitionPressure,
    required this.transitionBufferMinutes,
    required this.onSetTransitionBuffer,
  });

  final ClassOccurrence occurrence;
  final String code;
  final Color accent;
  final String? stateLabel;
  final List<AcademicReminder> enabledReminders;
  final bool conflict;
  final bool transitionPressure;
  final int transitionBufferMinutes;
  final ValueChanged<int> onSetTransitionBuffer;

  @override
  Widget build(BuildContext context) => Column(
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
              stateLabel!,
              style: Type.label.copyWith(
                fontSize: Type.minLabel,
                color: occurrence.state == OccurrenceState.cancelled
                    ? Palette.textLo
                    : Palette.xpLight,
              ),
            ),
          if (conflict)
            Text(
              'OVERLAP',
              key: ValueKey('academic-overlap-${occurrence.occurrenceKey}'),
              style: Type.label.copyWith(
                fontSize: Type.minLabel,
                color: Palette.danger,
              ),
            ),
          if (transitionPressure)
            Text(
              'TIGHT TURNAROUND',
              key: ValueKey('academic-transition-${occurrence.occurrenceKey}'),
              style: Type.label.copyWith(
                fontSize: Type.minLabel,
                color: Palette.xp,
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
        style: Type.body.copyWith(fontSize: 12.5, color: Palette.textMid),
      ),
      if (transitionPressure) ...[
        const SizedBox(height: 7),
        _TransitionBufferButton(
          occurrenceKey: occurrence.occurrenceKey,
          courseCode: code,
          transitionBufferMinutes: transitionBufferMinutes,
          onSetTransitionBuffer: onSetTransitionBuffer,
        ),
      ],
    ],
  );
}

class AcademicConflictNotice extends StatelessWidget {
  const AcademicConflictNotice({
    super.key,
    required this.conflicts,
    required this.schedule,
  });

  final List<AcademicMeetingConflict> conflicts;
  final AcademicSchedule schedule;

  @override
  Widget build(BuildContext context) {
    String codeFor(ClassOccurrence item) =>
        schedule.courseById(item.courseId)?.code ?? 'CLASS';
    final first = conflicts.first;
    final detail = conflicts.length == 1
        ? '${codeFor(first.first)} and ${codeFor(first.second)} share '
              '${formatAcademicTime(first.overlapStartMinute)}–'
              '${formatAcademicTime(first.overlapEndMinute)}.'
        : '${conflicts.length} class overlaps are sharing this day.';
    return Semantics(
      container: true,
      label: 'Schedule overlap. $detail Both classes are still kept.',
      child: Container(
        key: ValueKey('academic-conflicts-${first.date}'),
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
        decoration: facetedDecoration(
          cut: 9,
          color: Palette.danger.withValues(alpha: 0.055),
          borderColor: Palette.danger.withValues(alpha: 0.42),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(
                Icons.call_split_rounded,
                size: 18,
                color: Palette.danger,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    conflicts.length == 1
                        ? 'TWO CLASSES SHARE THIS TIME'
                        : '${conflicts.length} TIMES NEED A LOOK',
                    style: Type.label.copyWith(
                      fontSize: Type.minLabel,
                      letterSpacing: 1.1,
                      color: Palette.danger,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$detail Both stay on your daybook.',
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

class AcademicTransitionNotice extends StatelessWidget {
  const AcademicTransitionNotice({
    super.key,
    required this.pressures,
    required this.schedule,
  });

  final List<AcademicTransitionPressure> pressures;
  final AcademicSchedule schedule;

  @override
  Widget build(BuildContext context) {
    String codeFor(ClassOccurrence item) =>
        schedule.courseById(item.courseId)?.code ?? 'CLASS';
    final first = pressures.first;
    final detail = pressures.length == 1
        ? '${codeFor(first.before)} ends ${first.gapMinutes} min before '
              '${codeFor(first.after)}; your buffer is ${first.requestedMinutes} min.'
        : '${pressures.length} transitions have less room than requested.';
    return Semantics(
      container: true,
      label: 'Tight class transition. $detail Class times are unchanged.',
      child: Container(
        key: ValueKey('academic-transitions-${first.date}'),
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
        decoration: facetedDecoration(
          cut: 9,
          color: Palette.xp.withValues(alpha: 0.045),
          borderColor: Palette.brass.withValues(alpha: 0.46),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(
                Icons.directions_walk_rounded,
                size: 18,
                color: Palette.xp,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pressures.length == 1
                        ? 'A TIGHT TURNAROUND'
                        : '${pressures.length} TIGHT TURNAROUNDS',
                    style: Type.label.copyWith(
                      fontSize: Type.minLabel,
                      letterSpacing: 1.1,
                      color: Palette.xp,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$detail Class times stay exactly as entered.',
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

class AcademicWorkRow extends StatelessWidget {
  const AcademicWorkRow({
    super.key,
    required this.item,
    required this.course,
    required this.studyPlan,
    required this.plannedStudyMinutes,
    required this.onToggle,
    required this.onPlanStudy,
  });

  final AcademicWorkItem item;
  final AcademicCourse? course;
  final AcademicStudyPlan? studyPlan;
  final int plannedStudyMinutes;
  final VoidCallback onToggle;
  final VoidCallback onPlanStudy;

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
    final studyState = studyPlan == null
        ? 'no study time planned'
        : '$plannedStudyMinutes of ${studyPlan!.totalMinutes} study minutes planned';
    return Semantics(
      container: true,
      label:
          '$code ${item.kind.label}, ${item.title}, ${item.dueDate}, $time, $state, $studyState',
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
                  if (!item.completed) ...[
                    const SizedBox(height: 7),
                    Semantics(
                      button: true,
                      label: studyPlan == null
                          ? 'Plan study time for ${item.title}'
                          : 'Review study plan for ${item.title}',
                      child: InkWell(
                        key: ValueKey('academic-plan-study-${item.workId}'),
                        onTap: onPlanStudy,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 44),
                          padding: const EdgeInsets.symmetric(horizontal: 9),
                          decoration: facetedDecoration(
                            cut: 7,
                            color: Palette.xp.withValues(alpha: 0.06),
                            borderColor: Palette.brass.withValues(alpha: 0.44),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.schedule_rounded,
                                size: 16,
                                color: Palette.xp,
                              ),
                              const SizedBox(width: 7),
                              Expanded(
                                child: Text(
                                  studyPlan == null
                                      ? 'PLAN STUDY TIME'
                                      : '$plannedStudyMinutes / ${studyPlan!.totalMinutes} MIN PLANNED',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Type.label.copyWith(
                                    fontSize: Type.minLabel,
                                    letterSpacing: 0.55,
                                    color: Palette.xpLight,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right_rounded,
                                size: 17,
                                color: Palette.xpLight,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AcademicStudyBlockRow extends StatelessWidget {
  const AcademicStudyBlockRow({
    super.key,
    required this.block,
    required this.item,
    required this.course,
    required this.onToggle,
  });

  final AcademicStudyBlock block;
  final AcademicWorkItem? item;
  final AcademicCourse? course;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final accent = Color(course?.colorValue ?? 0xFF8AAFC6);
    final code = course?.code ?? 'COURSE';
    final title = item?.title ?? 'Study block';
    return Semantics(
      container: true,
      label:
          '$code study block for $title, ${formatAcademicTime(block.startMinute)} to ${formatAcademicTime(block.endMinute)}, ${block.completed ? 'completed' : 'not completed'}',
      child: Container(
        key: ValueKey('academic-study-block-${block.studyBlockId}'),
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 7),
        padding: const EdgeInsets.fromLTRB(9, 8, 10, 8),
        decoration: facetedDecoration(
          cut: 9,
          color: accent.withValues(alpha: block.completed ? 0.03 : 0.055),
          borderColor: accent.withValues(alpha: block.completed ? 0.16 : 0.30),
        ),
        child: Row(
          children: [
            Semantics(
              button: true,
              checked: block.completed,
              label:
                  '${block.completed ? 'Mark incomplete' : 'Mark complete'}: study $title',
              child: InkWell(
                key: ValueKey('academic-study-toggle-${block.studyBlockId}'),
                onTap: onToggle,
                borderRadius: BorderRadius.circular(22),
                child: SizedBox.square(
                  dimension: 44,
                  child: Center(
                    child: Container(
                      width: 25,
                      height: 25,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: block.completed
                            ? accent.withValues(alpha: 0.85)
                            : Colors.transparent,
                        border: Border.all(
                          color: block.completed ? accent : Palette.textLo,
                        ),
                      ),
                      child: block.completed
                          ? const Icon(
                              Icons.check_rounded,
                              size: 17,
                              color: Color(0xFF17100C),
                            )
                          : Icon(
                              Icons.menu_book_rounded,
                              size: 14,
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
                    '$code · STUDY',
                    style: Type.label.copyWith(
                      fontSize: Type.minLabel,
                      letterSpacing: 0.8,
                      color: block.completed ? Palette.textLo : accent,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Type.body.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: block.completed ? Palette.textLo : Palette.textHi,
                      decoration: block.completed
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${formatAcademicTime(block.startMinute)}–${formatAcademicTime(block.endMinute)} · ${block.durationMinutes} min',
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

class AcademicOccurrenceAdjustDialog extends StatefulWidget {
  const AcademicOccurrenceAdjustDialog({
    super.key,
    required this.schedule,
    required this.occurrence,
    required this.onMove,
    required this.onCancel,
    required this.onRestore,
  });

  final AcademicSchedule schedule;
  final ClassOccurrence occurrence;
  final MoveAcademicOccurrence onMove;
  final ChangeAcademicOccurrence onCancel;
  final ChangeAcademicOccurrence onRestore;

  @override
  State<AcademicOccurrenceAdjustDialog> createState() =>
      _AcademicOccurrenceAdjustDialogState();
}

class _AcademicOccurrenceAdjustDialogState
    extends State<AcademicOccurrenceAdjustDialog> {
  late CivilDate _date;
  late TimeOfDay _start;
  late TimeOfDay _end;
  bool _editingMove = false;
  bool _saving = false;
  String? _error;

  AcademicCourse? get _course =>
      widget.schedule.courseById(widget.occurrence.courseId);

  AcademicTerm? get _term {
    final course = _course;
    if (course == null) return null;
    return widget.schedule.terms
        .where((term) => term.termId == course.termId)
        .firstOrNull;
  }

  bool get _hasOpenStudyPlans {
    final openWorkIds = {
      for (final item in widget.schedule.workItems)
        if (!item.completed && item.tombstonedAt == null) item.workId,
    };
    return widget.schedule.studyPlans.any(
      (plan) => openWorkIds.contains(plan.workId),
    );
  }

  @override
  void initState() {
    super.initState();
    _date = widget.occurrence.date;
    _start = _timeOfDay(widget.occurrence.localStartMinute);
    _end = _timeOfDay(widget.occurrence.localEndMinute);
  }

  Future<void> _pickDate() async {
    final term = _term;
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.dateArithmeticValue,
      firstDate: term?.startDate.dateArithmeticValue ?? DateTime.utc(2020),
      lastDate: term?.endDate.dateArithmeticValue ?? DateTime.utc(2100, 12, 31),
      helpText: 'MOVE THIS CLASS TO',
    );
    if (!mounted || picked == null) return;
    setState(() {
      _date = CivilDate.fromDateTime(picked);
      _error = null;
    });
  }

  Future<void> _pickTime({required bool start}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: start ? _start : _end,
      helpText: start ? 'NEW CLASS START' : 'NEW CLASS END',
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

  Future<void> _move() async {
    final startMinute = _minuteOf(_start);
    final endMinute = _minuteOf(_end);
    if (endMinute <= startMinute) {
      setState(() => _error = 'Class end needs to be after its start.');
      return;
    }
    if (_date == widget.occurrence.date &&
        startMinute == widget.occurrence.localStartMinute &&
        endMinute == widget.occurrence.localEndMinute) {
      setState(() => _error = 'Choose a new date or time for this class.');
      return;
    }
    await _save(
      () => widget.onMove(widget.occurrence, _date, startMinute, endMinute),
    );
  }

  Future<void> _save(Future<bool> Function() change) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final saved = await change();
    if (!mounted) return;
    if (!saved) {
      Sfx.instance.play('boing');
      setState(() {
        _saving = false;
        _error = 'Couldn’t save this class change locally. Try again.';
      });
      return;
    }
    Sfx.instance.play('streak');
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final occurrence = widget.occurrence;
    final code = _course?.code ?? 'CLASS';
    final adjusted = occurrence.userAdjusted;
    final studyNote = _hasOpenStudyPlans
        ? 'Only this class changes; the weekly class stays intact. Open study blocks will refit, while completed study stays put.'
        : 'Only this class changes. The weekly class stays intact.';
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
                        'ADJUST THIS CLASS',
                        style: Type.label.copyWith(
                          fontSize: 12,
                          color: Palette.xpLight,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Palette.textLo,
                      ),
                    ),
                  ],
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(11, 10, 11, 10),
                  decoration: facetedDecoration(
                    cut: 9,
                    color: Color(
                      _course?.colorValue ?? 0xFF8AAFC6,
                    ).withValues(alpha: 0.07),
                    borderColor: Palette.brass.withValues(alpha: 0.38),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$code · ${occurrence.kind.label.toUpperCase()}',
                        style: Type.label.copyWith(
                          fontSize: Type.minLabel,
                          color: Palette.xpLight,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_formatAcademicDate(occurrence.date)} · '
                        '${formatAcademicTime(occurrence.localStartMinute)}–'
                        '${formatAcademicTime(occurrence.localEndMinute)}',
                        style: Type.body.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: occurrence.state == OccurrenceState.cancelled
                              ? Palette.textLo
                              : Palette.textHi,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        studyNote,
                        key: const ValueKey('academic-adjust-study-note'),
                        style: Type.body.copyWith(
                          fontSize: 12.5,
                          color: Palette.textMid,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_editingMove) ...[
                  const SizedBox(height: 14),
                  _SectionLabel('NEW DATE & TIME'),
                  const SizedBox(height: 7),
                  _DateButton(
                    label: 'DATE',
                    date: _date,
                    enabled: !_saving,
                    onTap: _pickDate,
                  ),
                  const SizedBox(height: 7),
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
                  _OccurrenceDialogAction(
                    key: const ValueKey('academic-occurrence-move-save'),
                    label: _saving ? 'SAVING…' : 'MOVE THIS CLASS',
                    icon: Icons.event_available_rounded,
                    onTap: _saving ? null : _move,
                    primary: true,
                  ),
                  const SizedBox(height: 7),
                  _OccurrenceDialogAction(
                    label: 'BACK',
                    icon: Icons.arrow_back_rounded,
                    onTap: _saving
                        ? null
                        : () => setState(() {
                            _editingMove = false;
                            _error = null;
                          }),
                  ),
                ] else ...[
                  const SizedBox(height: 14),
                  if (occurrence.state != OccurrenceState.cancelled) ...[
                    _OccurrenceDialogAction(
                      key: const ValueKey('academic-occurrence-move'),
                      label: 'MOVE THIS CLASS',
                      icon: Icons.event_available_rounded,
                      onTap: _saving
                          ? null
                          : () => setState(() {
                              _editingMove = true;
                              _error = null;
                            }),
                      primary: true,
                    ),
                    const SizedBox(height: 7),
                    _OccurrenceDialogAction(
                      key: const ValueKey('academic-occurrence-cancel'),
                      label: 'CANCEL THIS CLASS',
                      icon: Icons.event_busy_rounded,
                      onTap: _saving
                          ? null
                          : () =>
                                _save(() => widget.onCancel(widget.occurrence)),
                      danger: true,
                    ),
                  ],
                  if (adjusted) ...[
                    if (occurrence.state != OccurrenceState.cancelled)
                      const SizedBox(height: 7),
                    _OccurrenceDialogAction(
                      key: const ValueKey('academic-occurrence-restore'),
                      label: occurrence.state == OccurrenceState.cancelled
                          ? 'RESTORE THIS CLASS'
                          : 'RESTORE ORIGINAL TIME',
                      icon: Icons.restore_rounded,
                      onTap: _saving
                          ? null
                          : () => _save(
                              () => widget.onRestore(widget.occurrence),
                            ),
                    ),
                  ],
                ],
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    key: const ValueKey('academic-occurrence-adjust-error'),
                    style: Type.body.copyWith(
                      fontSize: 12,
                      color: Palette.danger,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OccurrenceDialogAction extends StatelessWidget {
  const _OccurrenceDialogAction({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.primary = false,
    this.danger = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool primary;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final foreground = primary
        ? Palette.onHoney
        : danger
        ? Palette.danger
        : Palette.xpLight;
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label.toLowerCase(),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Opacity(
          opacity: onTap == null ? 0.52 : 1,
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 46),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: primary
                ? null
                : facetedDecoration(
                    cut: 8,
                    color: danger
                        ? Palette.danger.withValues(alpha: 0.045)
                        : Palette.xp.withValues(alpha: 0.055),
                    borderColor: danger
                        ? Palette.danger.withValues(alpha: 0.42)
                        : Palette.brass.withValues(alpha: 0.42),
                  ),
            child: primary
                ? GoldSurface(
                    cut: 8,
                    glow: false,
                    textured: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(icon, size: 18, color: foreground),
                          const SizedBox(width: 7),
                          Flexible(
                            child: Text(
                              label,
                              textAlign: TextAlign.center,
                              style: Type.label.copyWith(
                                fontSize: 11.5,
                                letterSpacing: 0.9,
                                color: foreground,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: 18, color: foreground),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: Type.label.copyWith(
                            fontSize: 11.5,
                            letterSpacing: 0.9,
                            color: foreground,
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

class AddAcademicMeetingDialog extends StatefulWidget {
  const AddAcademicMeetingDialog({
    super.key,
    required this.schedule,
    required this.selectedDay,
    this.initialPlace,
    this.placeSearchFactory = const ProductionDaybookPlaceSearchFactory(),
    required this.onSave,
  });

  final AcademicSchedule schedule;
  final DateTime selectedDay;
  final CampusPlace? initialPlace;
  final DaybookPlaceSearchFactory placeSearchFactory;
  final SaveAcademicMeeting onSave;

  @override
  State<AddAcademicMeetingDialog> createState() =>
      _AddAcademicMeetingDialogState();
}

class _AddAcademicMeetingDialogState extends State<AddAcademicMeetingDialog> {
  final _termName = TextEditingController();
  final _courseCode = TextEditingController();
  final _courseTitle = TextEditingController();
  late final CampusPlace _originalPlace;
  late final DaybookPlaceFieldsController _placeFields;

  late AcademicTerm _term;
  late bool _newTerm;
  late CivilDate _termStart;
  late CivilDate _termEnd;
  MeetingKind _kind = MeetingKind.lecture;
  late Set<int> _weekdays;
  TimeOfDay _start = const TimeOfDay(hour: 10, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 11, minute: 15);
  int _transitionBufferMinutes = 10;
  int _colorIndex = 0;
  String? _error;
  bool _saving = false;

  List<MeetingSeries> get _matchingTimeSeries {
    final startMinute = _start.hour * 60 + _start.minute;
    final endMinute = _end.hour * 60 + _end.minute;
    if (_weekdays.isEmpty || endMinute <= startMinute) return const [];
    return [
      for (final series in widget.schedule.meetingSeries)
        if (series.tombstonedAt == null &&
            series.weekdays.any(_weekdays.contains) &&
            series.firstDate.compareTo(_termEnd) <= 0 &&
            series.lastDate.compareTo(_termStart) >= 0 &&
            startMinute < series.localEndMinute &&
            series.localStartMinute < endMinute)
          series,
    ];
  }

  List<({MeetingSeries series, int gapMinutes, int requestedMinutes})>
  get _tightTransitionSeries {
    final startMinute = _start.hour * 60 + _start.minute;
    final endMinute = _end.hour * 60 + _end.minute;
    if (_weekdays.isEmpty || endMinute <= startMinute) return const [];
    return [
      for (final series in widget.schedule.meetingSeries)
        if (series.tombstonedAt == null &&
            series.weekdays.any(_weekdays.contains) &&
            series.firstDate.compareTo(_termEnd) <= 0 &&
            series.lastDate.compareTo(_termStart) >= 0 &&
            (endMinute <= series.localStartMinute ||
                series.localEndMinute <= startMinute))
          if ((
                series: series,
                gapMinutes: endMinute <= series.localStartMinute
                    ? series.localStartMinute - endMinute
                    : startMinute - series.localEndMinute,
                requestedMinutes: math.max(
                  _transitionBufferMinutes,
                  series.transitionBufferMinutes,
                ),
              )
              case final pressure
              when pressure.requestedMinutes > 0 &&
                  pressure.gapMinutes < pressure.requestedMinutes)
            pressure,
    ];
  }

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
    _originalPlace =
        widget.initialPlace ?? CampusPlace(label: 'Location not set');
    _placeFields = DaybookPlaceFieldsController(
      initialPlace: widget.initialPlace == null
          ? null
          : CampusPlaceDaybookAdapter.fromCampusPlace(_originalPlace),
    );
  }

  @override
  void dispose() {
    _termName.dispose();
    _courseCode.dispose();
    _courseTitle.dispose();
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
    final building = _clean(_placeFields.building);
    final room = _clean(_placeFields.room);
    final placeParts = <String>[?building, ?room];
    final routingText = _clean(_placeFields.routingText);
    final fallbackName = placeParts.isNotEmpty
        ? placeParts.join(' ')
        : routingText;
    final editedPlace = _placeFields.toPlace(fallbackSavedName: fallbackName);
    final place = editedPlace == null
        ? CampusPlaceDaybookAdapter.toCampusPlace(
            DaybookPlace(savedName: 'Location not set'),
            original: _originalPlace,
            destinationIntent: _placeFields.destinationIntent,
          )
        : CampusPlaceDaybookAdapter.toCampusPlace(
            editedPlace,
            original: _originalPlace,
            destinationIntent: _placeFields.destinationIntent,
          );
    final series = MeetingSeries(
      meetingSeriesId: AcademicIds.create('series'),
      courseId: course.courseId,
      kind: _kind,
      weekdays: _weekdays,
      localStartMinute: startMinute,
      localEndMinute: endMinute,
      transitionBufferMinutes: _transitionBufferMinutes,
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
                if (_matchingTimeSeries.isNotEmpty) ...[
                  const SizedBox(height: 9),
                  _SchedulePressurePreview(
                    key: const ValueKey('academic-class-overlap-preview'),
                    series: _matchingTimeSeries,
                    schedule: widget.schedule,
                  ),
                ],
                if (_matchingTimeSeries.isEmpty &&
                    _tightTransitionSeries.isNotEmpty) ...[
                  const SizedBox(height: 9),
                  _ScheduleTransitionPreview(
                    key: const ValueKey('academic-class-transition-preview'),
                    pressure: _tightTransitionSeries.first,
                    schedule: widget.schedule,
                  ),
                ],
                const SizedBox(height: 13),
                _SectionLabel('TIME AROUND CLASS'),
                const SizedBox(height: 7),
                Text(
                  'How much room should the daybook leave for walking or resetting?',
                  style: Type.body.copyWith(
                    fontSize: 12.5,
                    color: Palette.textMid,
                  ),
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final minutes in const [0, 5, 10, 15, 20, 30])
                      _SelectChip(
                        label: minutes == 0 ? 'NONE' : '$minutes MIN',
                        selected: _transitionBufferMinutes == minutes,
                        onTap: () =>
                            setState(() => _transitionBufferMinutes = minutes),
                      ),
                  ],
                ),
                const SizedBox(height: 13),
                _SectionLabel('PLACE'),
                const SizedBox(height: 7),
                DaybookPlaceFields(
                  controller: _placeFields,
                  keyPrefix: 'academic-place',
                  savedNameKey: const ValueKey('academic-saved-name'),
                  routingTextKey: const ValueKey('academic-routing-text'),
                  buildingKey: const ValueKey('academic-building'),
                  roomKey: const ValueKey('academic-room'),
                  placeSearchFactory: widget.placeSearchFactory,
                ),
                const SizedBox(height: 5),
                Text(
                  'Leave every place field blank to keep this as “Location not set.”',
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

class AcademicStudyPlannerDialog extends StatefulWidget {
  const AcademicStudyPlannerDialog({
    super.key,
    required this.schedule,
    required this.item,
    required this.onSave,
    this.planningStartDate,
  });

  final AcademicSchedule schedule;
  final AcademicWorkItem item;
  final SaveAcademicStudyPlan onSave;
  final CivilDate? planningStartDate;

  @override
  State<AcademicStudyPlannerDialog> createState() =>
      _AcademicStudyPlannerDialogState();
}

class _AcademicStudyPlannerDialogState
    extends State<AcademicStudyPlannerDialog> {
  late int _totalMinutes;
  late int _sessionMinutes;
  late TimeOfDay _dailyStart;
  late TimeOfDay _dailyEnd;
  AcademicStudySuggestion? _suggestion;
  String? _error;
  bool _saving = false;

  AcademicCourse? get _course =>
      widget.schedule.courseById(widget.item.courseId);

  @override
  void initState() {
    super.initState();
    final existing = widget.schedule.studyPlanFor(widget.item.workId);
    _totalMinutes =
        existing?.totalMinutes ??
        (widget.item.kind == AcademicWorkKind.exam ? 180 : 120);
    _sessionMinutes = existing?.sessionMinutes ?? 45;
    _dailyStart = _timeOfDay(existing?.dailyStartMinute ?? 9 * 60);
    _dailyEnd = _timeOfDay(existing?.dailyEndMinute ?? 20 * 60);
    _suggest();
  }

  void _suggest() {
    try {
      final suggestion = widget.schedule.suggestStudyBlocks(
        workId: widget.item.workId,
        totalMinutes: _totalMinutes,
        sessionMinutes: _sessionMinutes,
        dailyStartMinute: _minuteOf(_dailyStart),
        dailyEndMinute: _minuteOf(_dailyEnd),
        now: Clock.now(),
        planningStartDate: widget.planningStartDate,
      );
      _suggestion = suggestion;
      _error =
          suggestion.blocks.isEmpty && suggestion.remainingTargetMinutes > 0
          ? 'There isn’t an open study slot before this deadline in those hours.'
          : null;
    } on ArgumentError {
      _suggestion = null;
      _error = 'Choose study hours with at least fifteen minutes between them.';
    }
  }

  void _change(VoidCallback update) {
    setState(() {
      update();
      _suggest();
    });
  }

  Future<void> _pickHours({required bool start}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: start ? _dailyStart : _dailyEnd,
      helpText: start ? 'EARLIEST STUDY TIME' : 'LATEST STUDY TIME',
    );
    if (!mounted || picked == null) return;
    _change(() {
      if (start) {
        _dailyStart = picked;
      } else {
        _dailyEnd = picked;
      }
    });
  }

  Future<void> _save() async {
    final suggestion = _suggestion;
    if (suggestion == null || suggestion.blocks.isEmpty) return;
    final existing = widget.schedule.studyPlanFor(widget.item.workId);
    setState(() {
      _saving = true;
      _error = null;
    });
    final saved = await widget.onSave(
      AcademicStudyPlan(
        workId: widget.item.workId,
        totalMinutes: _totalMinutes,
        sessionMinutes: _sessionMinutes,
        dailyStartMinute: _minuteOf(_dailyStart),
        dailyEndMinute: _minuteOf(_dailyEnd),
        revision: (existing?.revision ?? 0) + 1,
        updatedAt: Clock.now().toUtc(),
      ),
      suggestion.blocks,
    );
    if (!mounted) return;
    if (!saved) {
      Sfx.instance.play('boing');
      setState(() {
        _saving = false;
        _error = 'Couldn’t save these study blocks locally. Try again.';
      });
      return;
    }
    Sfx.instance.play('streak');
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final suggestion = _suggestion;
    final code = _course?.code ?? 'COURSE';
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
                        'PLAN STUDY TIME',
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
                Text(
                  '$code · ${widget.item.title}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Type.display.copyWith(
                    fontSize: 20,
                    color: Palette.textHi,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Choose the effort. The daybook finds open time before ${_formatAcademicDate(widget.item.dueDate)} and leaves every class exactly where it is.',
                  style: Type.body.copyWith(
                    fontSize: 12.5,
                    color: Palette.textMid,
                  ),
                ),
                const SizedBox(height: 14),
                _SectionLabel('TOTAL EFFORT'),
                const SizedBox(height: 7),
                _ChoiceGrid(
                  children: [
                    for (final minutes in const [60, 90, 120, 180, 240, 360])
                      _SelectChip(
                        label: _durationLabel(minutes),
                        selected: _totalMinutes == minutes,
                        onTap: () => _change(() => _totalMinutes = minutes),
                      ),
                  ],
                ),
                const SizedBox(height: 13),
                _SectionLabel('SESSION LENGTH'),
                const SizedBox(height: 7),
                _ChoiceGrid(
                  children: [
                    for (final minutes in const [25, 30, 45, 60, 90])
                      _SelectChip(
                        label: '$minutes MIN',
                        selected: _sessionMinutes == minutes,
                        onTap: () => _change(() => _sessionMinutes = minutes),
                      ),
                  ],
                ),
                const SizedBox(height: 13),
                _SectionLabel('USABLE HOURS'),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Expanded(
                      child: _TimeButton(
                        label: 'EARLIEST',
                        time: _dailyStart,
                        onTap: () => _pickHours(start: true),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: _TimeButton(
                        label: 'LATEST',
                        time: _dailyEnd,
                        onTap: () => _pickHours(start: false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 13),
                _StudySuggestionPreview(
                  key: const ValueKey('academic-study-suggestion-preview'),
                  suggestion: suggestion,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    key: const ValueKey('academic-study-plan-error'),
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
                    key: const ValueKey('academic-study-plan-save'),
                    onTap:
                        _saving ||
                            suggestion == null ||
                            suggestion.blocks.isEmpty
                        ? null
                        : _save,
                    child: Opacity(
                      opacity:
                          _saving ||
                              suggestion == null ||
                              suggestion.blocks.isEmpty
                          ? 0.5
                          : 1,
                      child: GoldSurface(
                        cut: 9,
                        glow: false,
                        textured: false,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                            child: Text(
                              _saving
                                  ? 'SAVING…'
                                  : widget.schedule.studyPlanFor(
                                          widget.item.workId,
                                        ) ==
                                        null
                                  ? 'KEEP THESE BLOCKS'
                                  : 'REPLACE OPEN BLOCKS',
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

class _StudySuggestionPreview extends StatelessWidget {
  const _StudySuggestionPreview({super.key, required this.suggestion});

  final AcademicStudySuggestion? suggestion;

  @override
  Widget build(BuildContext context) {
    final value = suggestion;
    if (value == null) return const SizedBox.shrink();
    return Semantics(
      container: true,
      label:
          '${value.blocks.length} suggested study blocks, ${value.scheduledMinutes} minutes scheduled, ${value.unscheduledMinutes} minutes still needing room',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(11, 10, 11, 9),
        decoration: facetedDecoration(
          cut: 9,
          color: Palette.xp.withValues(alpha: 0.05),
          borderColor: Palette.brass.withValues(alpha: 0.44),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value.fullyScheduled
                  ? '${value.blocks.length} OPEN ${value.blocks.length == 1 ? 'BLOCK' : 'BLOCKS'} FOUND'
                  : '${_durationLabel(value.unscheduledMinutes)} STILL NEEDS ROOM',
              style: Type.label.copyWith(
                fontSize: Type.minLabel,
                letterSpacing: 1.0,
                color: value.fullyScheduled ? Palette.xp : Palette.danger,
              ),
            ),
            if (value.completedMinutes > 0) ...[
              const SizedBox(height: 3),
              Text(
                '${_durationLabel(value.completedMinutes)} already completed stays in the record.',
                style: Type.body.copyWith(fontSize: 12, color: Palette.textMid),
              ),
            ],
            if (value.blocks.isNotEmpty) ...[
              const SizedBox(height: 7),
              for (final block in value.blocks.take(6))
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        size: 15,
                        color: Palette.xp,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          '${_formatAcademicDate(block.date)} · ${formatAcademicTime(block.startMinute)}–${formatAcademicTime(block.endMinute)}',
                          style: Type.body.copyWith(
                            fontSize: 12.5,
                            color: Palette.textHi,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (value.blocks.length > 6)
                Text(
                  '+${value.blocks.length - 6} more blocks',
                  style: Type.body.copyWith(
                    fontSize: 12,
                    color: Palette.textMid,
                  ),
                ),
            ],
            const SizedBox(height: 3),
            Text(
              'Nothing is added until you keep this plan.',
              style: Type.body.copyWith(fontSize: 11.5, color: Palette.textLo),
            ),
          ],
        ),
      ),
    );
  }
}

class _SchedulePressurePreview extends StatelessWidget {
  const _SchedulePressurePreview({
    super.key,
    required this.series,
    required this.schedule,
  });

  final List<MeetingSeries> series;
  final AcademicSchedule schedule;

  @override
  Widget build(BuildContext context) {
    final first = series.first;
    final course = schedule.courseById(first.courseId);
    final more = series.length - 1;
    final detail =
        '${course?.code ?? 'Another class'} runs '
        '${formatAcademicTime(first.localStartMinute)}–'
        '${formatAcademicTime(first.localEndMinute)}'
        '${more > 0 ? ', plus $more more' : ''}.';
    return Semantics(
      container: true,
      liveRegion: true,
      label: 'Schedule overlap preview. $detail You can still keep this class.',
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
        decoration: facetedDecoration(
          cut: 8,
          color: Palette.danger.withValues(alpha: 0.05),
          borderColor: Palette.danger.withValues(alpha: 0.38),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.call_split_rounded,
              size: 18,
              color: Palette.danger,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'THIS TIME ALREADY HAS A CLASS\n',
                      style: Type.label.copyWith(
                        fontSize: Type.minLabel,
                        letterSpacing: 0.9,
                        color: Palette.danger,
                      ),
                    ),
                    TextSpan(
                      text:
                          '$detail It can still be kept if that is intentional.',
                      style: Type.body.copyWith(
                        fontSize: 12.5,
                        color: Palette.textMid,
                      ),
                    ),
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

class _ScheduleTransitionPreview extends StatelessWidget {
  const _ScheduleTransitionPreview({
    super.key,
    required this.pressure,
    required this.schedule,
  });

  final ({MeetingSeries series, int gapMinutes, int requestedMinutes}) pressure;
  final AcademicSchedule schedule;

  @override
  Widget build(BuildContext context) {
    final course = schedule.courseById(pressure.series.courseId);
    final detail =
        '${course?.code ?? 'Another class'} leaves ${pressure.gapMinutes} min; '
        'your buffer is ${pressure.requestedMinutes} min.';
    return Semantics(
      container: true,
      liveRegion: true,
      label: 'Tight transition preview. $detail Class times are unchanged.',
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
        decoration: facetedDecoration(
          cut: 8,
          color: Palette.xp.withValues(alpha: 0.045),
          borderColor: Palette.brass.withValues(alpha: 0.46),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.directions_walk_rounded,
              size: 18,
              color: Palette.xp,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'TIGHT TURNAROUND\n',
                      style: Type.label.copyWith(
                        fontSize: Type.minLabel,
                        letterSpacing: 0.9,
                        color: Palette.xp,
                      ),
                    ),
                    TextSpan(
                      text:
                          '$detail Class times stay unchanged. Keep it if that timing is real.',
                      style: Type.body.copyWith(
                        fontSize: 12.5,
                        color: Palette.textMid,
                      ),
                    ),
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
  Widget build(BuildContext context) {
    final compact =
        MediaQuery.textScalerOf(context).scale(Type.minLabel) >=
        Type.minLabel * 1.5;
    final visibleLabel = compact
        ? switch (mode) {
            AcademicCalendarMode.month => 'MON',
            AcademicCalendarMode.week => 'WK',
            AcademicCalendarMode.threeDay => '3D',
            AcademicCalendarMode.day => 'DAY',
          }
        : mode.label;
    return Semantics(
      button: true,
      selected: selected,
      label: '${mode.label} calendar view',
      child: InkWell(
        key: ValueKey('academic-mode-${mode.name}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 44,
          decoration: facetedDecoration(
            cut: 7,
            gradient: selected
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF3B3325), Color(0xFF211A16)],
                  )
                : null,
            color: selected ? null : Colors.transparent,
            borderColor: selected
                ? Palette.brassLit.withValues(alpha: 0.78)
                : Palette.glassEdge,
            borderWidth: selected ? 1.15 : 1,
          ),
          child: Stack(
            alignment: Alignment.center,
            fit: StackFit.expand,
            children: [
              Center(
                child: Text(
                  visibleLabel,
                  maxLines: 1,
                  style: Type.label.copyWith(
                    fontSize: Type.minLabel,
                    letterSpacing: 0.7,
                    color: selected ? Palette.xpLight : Palette.textLo,
                  ),
                ),
              ),
              if (selected)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: SizedBox(
                    key: ValueKey('academic-selected-folio-tab-${mode.name}'),
                    width: 22,
                    height: 3,
                    child: DecoratedBox(
                      decoration: facetedDecoration(
                        cut: 1.5,
                        gradient: const LinearGradient(
                          colors: [Palette.brassLit, Palette.brass],
                        ),
                        borderColor: Palette.brassDeep,
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

class _OccurrenceActions extends StatelessWidget {
  const _OccurrenceActions({
    required this.occurrenceKey,
    required this.courseCode,
    required this.onOpenNotebook,
    required this.onAdjust,
  });

  final String occurrenceKey;
  final String courseCode;
  final VoidCallback onOpenNotebook;
  final VoidCallback? onAdjust;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minWidth: 56, minHeight: 44),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _OccurrenceActionButton(
          key: ValueKey('open-notebook-$occurrenceKey'),
          semanticLabel: 'Open $courseCode notebook',
          label: 'NOTES',
          icon: Icons.edit_note_rounded,
          onTap: onOpenNotebook,
        ),
        if (onAdjust != null) ...[
          const SizedBox(height: 1),
          _OccurrenceActionButton(
            key: ValueKey('academic-adjust-occurrence-$occurrenceKey'),
            semanticLabel: 'Adjust this $courseCode class only',
            label: 'ADJUST',
            icon: Icons.event_repeat_rounded,
            onTap: onAdjust!,
            quiet: true,
          ),
        ],
      ],
    ),
  );
}

class _OccurrenceActionButton extends StatelessWidget {
  const _OccurrenceActionButton({
    super.key,
    required this.semanticLabel,
    required this.label,
    required this.icon,
    required this.onTap,
    this.quiet = false,
  });

  final String semanticLabel;
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool quiet;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: semanticLabel,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 56, minHeight: 44),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: quiet ? Palette.textMid : Palette.xpLight,
              ),
              Text(
                label,
                style: Type.label.copyWith(
                  fontSize: Type.minLabel,
                  letterSpacing: 0.45,
                  color: quiet ? Palette.textMid : Palette.xpLight,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _TransitionBufferButton extends StatelessWidget {
  const _TransitionBufferButton({
    required this.occurrenceKey,
    required this.courseCode,
    required this.transitionBufferMinutes,
    required this.onSetTransitionBuffer,
  });

  final String occurrenceKey;
  final String courseCode;
  final int transitionBufferMinutes;
  final ValueChanged<int> onSetTransitionBuffer;

  @override
  Widget build(BuildContext context) => PopupMenuButton<int>(
    key: ValueKey('academic-buffer-menu-$occurrenceKey'),
    tooltip: 'Set transition buffer for $courseCode',
    color: Palette.card,
    initialValue: transitionBufferMinutes,
    onSelected: onSetTransitionBuffer,
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints(minHeight: 44),
    position: PopupMenuPosition.under,
    child: Semantics(
      button: true,
      label:
          'Set transition buffer for $courseCode. Current buffer $transitionBufferMinutes minutes',
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Palette.xp.withValues(alpha: 0.08),
            border: Border.all(color: Palette.xp.withValues(alpha: 0.38)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 120;
              return Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 7 : 10,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.directions_walk_rounded,
                      size: 17,
                      color: Palette.xp,
                    ),
                    SizedBox(width: compact ? 4 : 7),
                    Expanded(
                      child: Text(
                        transitionBufferMinutes == 0
                            ? 'NONE'
                            : compact
                            ? '$transitionBufferMinutes MIN'
                            : '$transitionBufferMinutes MIN BUFFER',
                        maxLines: compact ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                        style: Type.label.copyWith(
                          fontSize: Type.minLabel,
                          letterSpacing: compact ? 0.25 : 0.55,
                          color: Palette.xpLight,
                        ),
                      ),
                    ),
                    if (!compact) ...[
                      const SizedBox(width: 3),
                      const Icon(
                        Icons.expand_more_rounded,
                        size: 17,
                        color: Palette.xpLight,
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    ),
    itemBuilder: (context) => [
      for (final minutes in const [0, 5, 10, 15, 20, 30])
        PopupMenuItem<int>(
          value: minutes,
          child: Row(
            children: [
              Icon(
                minutes == transitionBufferMinutes
                    ? Icons.check_rounded
                    : Icons.directions_walk_rounded,
                size: 18,
                color: minutes == transitionBufferMinutes
                    ? Palette.xp
                    : Palette.textLo,
              ),
              const SizedBox(width: 9),
              Text(
                minutes == 0 ? 'No buffer' : '$minutes min buffer',
                style: Type.body.copyWith(color: Palette.textHi),
              ),
            ],
          ),
        ),
    ],
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
    excludeSemantics: true,
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

class _ChoiceGrid extends StatelessWidget {
  const _ChoiceGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final textScale = MediaQuery.textScalerOf(context).scale(1);
      final columns = constraints.maxWidth < 330 || textScale > 1.35 ? 2 : 3;
      const gap = 6.0;
      final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
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

TimeOfDay _timeOfDay(int minute) =>
    TimeOfDay(hour: minute ~/ 60, minute: minute % 60);

int _minuteOf(TimeOfDay time) => time.hour * 60 + time.minute;

String _durationLabel(int minutes) {
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  if (hours == 0) return '$minutes MIN';
  if (remainder == 0) return '$hours HR${hours == 1 ? '' : 'S'}';
  return '$hours HR $remainder MIN';
}

String _formatAcademicDate(CivilDate date) =>
    '${_monthNames[date.month - 1]} ${date.day}';

String formatAcademicTime(int minute) {
  final hour24 = minute ~/ 60;
  final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
  final minutes = (minute % 60).toString().padLeft(2, '0');
  final suffix = hour24 < 12 ? 'AM' : 'PM';
  return '$hour12:$minutes $suffix';
}

String _dayCountLabel(List<DaybookEntry> entries) {
  final scheduled = entries
      .where(
        (entry) =>
            entry.section == DaybookSection.allDay ||
            entry.section == DaybookSection.timed,
      )
      .length;
  final due = entries
      .where(
        (entry) =>
            entry.section == DaybookSection.due ||
            entry.section == DaybookSection.stillOpen,
      )
      .length;
  final focus = entries
      .where((entry) => entry.section == DaybookSection.focus)
      .length;
  final parts = <String>[];
  if (scheduled > 0) {
    parts.add('$scheduled ${scheduled == 1 ? 'PLAN' : 'PLANS'}');
  }
  if (due > 0) parts.add('$due DUE');
  if (focus > 0) parts.add('$focus FOCUS');
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
  if (timeZoneId == null || timeZoneId.trim().isEmpty) return 'LOCAL TIME';
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
