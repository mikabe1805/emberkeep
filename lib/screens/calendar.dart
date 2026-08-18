import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../academic_calendar/data/academic_calendar_preferences.dart';
import '../academic_calendar/data/academic_schedule_repository.dart';
import '../academic_calendar/domain/academic_schedule.dart';
import '../academic_calendar/services/notebook_handoff.dart';
import '../academic_calendar/widgets/academic_calendar_sections.dart';
import '../audio.dart';
import '../clock.dart';
import '../daybook/domain/daybook_event.dart';
import '../daybook/domain/daybook_task.dart';
import '../daybook/presentation/daybook_range_projection.dart';
import '../daybook/widgets/daybook_add_choice_dialog.dart';
import '../daybook/widgets/daybook_event_editor.dart';
import '../daybook/widgets/daybook_task_editor.dart';
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

/// The Plans page: a warm month calendar. One brass day-weight mark answers
/// the month view's useful question at a glance: how much of this day is
/// spoken for? Tap a day to read the actual classes, plans, work, and notes.
class CalendarPage extends StatefulWidget {
  const CalendarPage({
    super.key,
    required this.state,
    required this.quests,
    required this.onAdd,
    this.parallax = const AlwaysStoppedAnimation(Offset.zero),
    this.lightDirection,
    this.scheduleRepository,
    this.calendarPreferences,
    this.notebookHandoff,
  });

  final GameState state;
  final List<Quest> quests;
  final bool Function(Quest) onAdd;
  final ValueListenable<Offset> parallax;
  final ValueListenable<Offset>? lightDirection;
  final AcademicScheduleRepository? scheduleRepository;
  final AcademicCalendarPreferences? calendarPreferences;
  final NotebookHandoff? notebookHandoff;

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late DateTime _month;
  late DateTime _selected;
  late final AcademicScheduleRepository _scheduleRepository;
  late final AcademicCalendarPreferences _calendarPreferences;
  late final NotebookHandoff _notebookHandoff;
  AcademicSchedule _academicSchedule = AcademicSchedule.empty();
  AcademicCalendarMode _academicMode = AcademicCalendarMode.month;
  bool _academicLoading = true;

  @override
  void initState() {
    super.initState();
    final now = Clock.now();
    _month = DateTime(now.year, now.month);
    _selected = DateTime(now.year, now.month, now.day);
    _scheduleRepository =
        widget.scheduleRepository ?? LocalAcademicScheduleRepository();
    _calendarPreferences =
        widget.calendarPreferences ?? LocalAcademicCalendarPreferences();
    _notebookHandoff =
        widget.notebookHandoff ?? UrlLauncherNotebookHandoff.configured();
    unawaited(_loadAcademicCalendar());
  }

  Future<void> _loadAcademicCalendar() async {
    final scheduleFuture = _scheduleRepository.load();
    final preferencesFuture = _calendarPreferences.load();
    final schedule = await scheduleFuture;
    final preferences = await preferencesFuture;
    if (!mounted) return;
    DateTime? restoredDate;
    if (preferences.selectedDate case final raw?) {
      try {
        final civil = CivilDate.parse(raw);
        restoredDate = DateTime(civil.year, civil.month, civil.day);
      } on FormatException {
        // A stale view preference never makes academic content unreadable.
      }
    }
    setState(() {
      _academicSchedule = schedule;
      _academicMode = preferences.mode;
      if (restoredDate != null) {
        _selected = restoredDate;
        _month = DateTime(restoredDate.year, restoredDate.month);
      }
      _academicLoading = false;
    });
  }

  void _persistAcademicView() {
    unawaited(
      _calendarPreferences.save(
        AcademicCalendarViewState(
          mode: _academicMode,
          selectedDate: CivilDate.fromDateTime(_selected).toString(),
        ),
      ),
    );
  }

  void _selectDay(DateTime day) {
    setState(() {
      _selected = DateTime(day.year, day.month, day.day);
      _month = DateTime(day.year, day.month);
    });
    _persistAcademicView();
  }

  void _setAcademicMode(AcademicCalendarMode mode) {
    if (_academicMode == mode) return;
    Sfx.instance.play('tick');
    setState(() {
      _academicMode = mode;
      _month = DateTime(_selected.year, _selected.month);
    });
    _persistAcademicView();
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
    _persistAcademicView();
  }

  void _moveAcademicSpan(int direction) {
    if (_academicMode == AcademicCalendarMode.month) {
      _moveMonth(direction);
      return;
    }
    final next = CivilDate.fromDateTime(
      _selected,
    ).addDays(direction * _academicMode.spanDays);
    _selectDay(DateTime(next.year, next.month, next.day));
  }

  void _goToday() {
    final now = Clock.now();
    setState(() {
      _month = DateTime(now.year, now.month);
      _selected = DateTime(now.year, now.month, now.day);
    });
    _persistAcademicView();
  }

  (CivilDate, CivilDate) _visibleDaybookBounds() {
    final selected = CivilDate.fromDateTime(_selected);
    if (_academicMode == AcademicCalendarMode.month) {
      return (
        CivilDate(_month.year, _month.month, 1),
        CivilDate(
          _month.year,
          _month.month,
          DateTime(_month.year, _month.month + 1, 0).day,
        ),
      );
    }
    final first = _academicMode == AcademicCalendarMode.week
        ? selected.startOfWeek(
            (_academicSchedule.termFor(selected) ??
                        _academicSchedule.latestTerm)
                    ?.weekStartsOn ??
                DateTime.monday,
          )
        : selected;
    return (first, first.addDays(_academicMode.spanDays - 1));
  }

  Future<bool> _saveDaybookEvent(DaybookEvent event) async {
    late final AcademicSchedule next;
    try {
      next = _academicSchedule.putEvent(event);
    } on ArgumentError {
      return false;
    }
    if (!await _scheduleRepository.save(next)) return false;
    if (mounted) setState(() => _academicSchedule = next);
    return true;
  }

  Future<bool> _saveDaybookTask(DaybookTask task) async {
    late final AcademicSchedule next;
    try {
      next = _academicSchedule.putTask(task);
    } on ArgumentError {
      return false;
    }
    if (!await _scheduleRepository.save(next)) return false;
    if (mounted) setState(() => _academicSchedule = next);
    return true;
  }

  Future<void> _toggleDaybookTask(DaybookTask task, bool completed) async {
    final updatedAt = Clock.now().toUtc();
    late final AcademicSchedule next;
    try {
      next = _academicSchedule.putTask(
        completed
            ? task.complete(at: updatedAt)
            : task.undoCompletion(at: updatedAt),
      );
    } on ArgumentError {
      return;
    }
    if (!await _scheduleRepository.save(next)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Palette.card,
          content: Text(
            "Couldn't update this task locally. Try again.",
            style: Type.body.copyWith(color: Palette.textHi),
          ),
        ),
      );
      return;
    }
    if (!mounted) return;
    Sfx.instance.play('tick');
    setState(() => _academicSchedule = next);
  }

  Future<bool> _saveAcademicMeeting(
    AcademicTerm term,
    AcademicCourse course,
    MeetingSeries series,
  ) async {
    late final AcademicSchedule next;
    try {
      next = _academicSchedule.putMeeting(
        term: term,
        course: course,
        series: series,
        updatedAt: Clock.now().toUtc(),
      );
    } on ArgumentError {
      return false;
    }
    if (!await _scheduleRepository.save(next)) return false;
    if (mounted) {
      setState(() => _academicSchedule = next);
      _persistAcademicView();
    }
    return true;
  }

  Future<bool> _saveAcademicWork(AcademicWorkItem item) async {
    late final AcademicSchedule next;
    try {
      next = _academicSchedule.putWorkItem(item);
    } on ArgumentError {
      return false;
    }
    if (!await _scheduleRepository.save(next)) return false;
    if (mounted) setState(() => _academicSchedule = next);
    return true;
  }

  Future<bool> _saveAcademicStudyPlan(
    AcademicStudyPlan plan,
    List<AcademicStudyBlock> blocks,
  ) async {
    late final AcademicSchedule next;
    try {
      next = _academicSchedule.putStudyPlan(plan: plan, blocks: blocks);
    } on ArgumentError {
      return false;
    }
    if (!await _scheduleRepository.save(next)) return false;
    if (mounted) setState(() => _academicSchedule = next);
    return true;
  }

  Future<void> _toggleAcademicStudyBlock(AcademicStudyBlock block) async {
    late final AcademicSchedule next;
    try {
      next = _academicSchedule.setStudyBlockCompleted(
        studyBlockId: block.studyBlockId,
        completed: !block.completed,
        updatedAt: Clock.now().toUtc(),
      );
    } on ArgumentError {
      return;
    }
    if (!await _scheduleRepository.save(next)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Palette.card,
          content: Text(
            "Couldn't update this study block locally. Try again.",
            style: Type.body.copyWith(color: Palette.textHi),
          ),
        ),
      );
      return;
    }
    if (!mounted) return;
    Sfx.instance.play('tick');
    setState(() => _academicSchedule = next);
  }

  Future<void> _showAcademicStudyPlanner(AcademicWorkItem item) async {
    Sfx.instance.play('tick');
    await showDialog<void>(
      context: context,
      barrierColor: Palette.dialogBarrier,
      builder: (_) => AcademicStudyPlannerDialog(
        schedule: _academicSchedule,
        item: item,
        onSave: _saveAcademicStudyPlan,
      ),
    );
  }

  Future<bool> _moveAcademicOccurrence(
    ClassOccurrence occurrence,
    CivilDate date,
    int startMinute,
    int endMinute,
  ) => _changeAcademicOccurrence(
    (updatedAt) => _academicSchedule.moveOccurrence(
      occurrenceKey: occurrence.occurrenceKey,
      date: date,
      startMinute: startMinute,
      endMinute: endMinute,
      updatedAt: updatedAt,
    ),
  );

  Future<bool> _cancelAcademicOccurrence(ClassOccurrence occurrence) =>
      _changeAcademicOccurrence(
        (updatedAt) => _academicSchedule.cancelOccurrence(
          occurrenceKey: occurrence.occurrenceKey,
          updatedAt: updatedAt,
        ),
      );

  Future<bool> _restoreAcademicOccurrence(ClassOccurrence occurrence) =>
      _changeAcademicOccurrence(
        (updatedAt) => _academicSchedule.restoreOccurrence(
          occurrenceKey: occurrence.occurrenceKey,
          updatedAt: updatedAt,
        ),
      );

  Future<bool> _changeAcademicOccurrence(
    AcademicSchedule Function(DateTime updatedAt) change,
  ) async {
    late final AcademicSchedule next;
    try {
      next = change(Clock.now().toUtc());
    } on ArgumentError {
      return false;
    }
    if (!await _scheduleRepository.save(next)) return false;
    if (mounted) setState(() => _academicSchedule = next);
    return true;
  }

  Future<void> _showAcademicOccurrenceAdjuster(
    ClassOccurrence occurrence,
  ) async {
    Sfx.instance.play('tick');
    await showDialog<void>(
      context: context,
      barrierColor: Palette.dialogBarrier,
      builder: (_) => AcademicOccurrenceAdjustDialog(
        schedule: _academicSchedule,
        occurrence: occurrence,
        onMove: _moveAcademicOccurrence,
        onCancel: _cancelAcademicOccurrence,
        onRestore: _restoreAcademicOccurrence,
      ),
    );
  }

  Future<bool> _updateAcademicTransitionBuffer(
    ClassOccurrence occurrence,
    int minutes,
  ) async {
    final series = _academicSchedule.meetingSeriesById(
      occurrence.meetingSeriesId,
    );
    if (series == null) return false;
    final course = _academicSchedule.courseById(series.courseId);
    if (course == null) return false;
    final term = _academicSchedule.terms
        .where((term) => term.termId == course.termId)
        .firstOrNull;
    if (term == null) return false;

    final updatedAt = Clock.now().toUtc();
    final updatedSeries = MeetingSeries(
      meetingSeriesId: series.meetingSeriesId,
      courseId: series.courseId,
      kind: series.kind,
      weekdays: series.weekdays,
      localStartMinute: series.localStartMinute,
      localEndMinute: series.localEndMinute,
      transitionBufferMinutes: minutes,
      intervalWeeks: series.intervalWeeks,
      firstDate: series.firstDate,
      lastDate: series.lastDate,
      timeZoneId: series.timeZoneId,
      place: series.place,
      reminders: series.reminders,
      revision: series.revision + 1,
      updatedAt: updatedAt,
      tombstonedAt: series.tombstonedAt,
    );
    final next = _academicSchedule.putMeeting(
      term: term,
      course: course,
      series: updatedSeries,
      updatedAt: updatedAt,
    );
    if (!await _scheduleRepository.save(next)) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Palette.card,
          content: Text(
            "Couldn't update this class buffer locally. Try again.",
            style: Type.body.copyWith(color: Palette.textHi),
          ),
        ),
      );
      return false;
    }
    if (!mounted) return false;
    Sfx.instance.play('tick');
    setState(() => _academicSchedule = next);
    return true;
  }

  Future<void> _toggleAcademicWork(AcademicWorkItem item) async {
    late final AcademicSchedule next;
    try {
      next = _academicSchedule.setWorkItemCompleted(
        workId: item.workId,
        completed: !item.completed,
        updatedAt: Clock.now().toUtc(),
      );
    } on ArgumentError {
      return;
    }
    if (!await _scheduleRepository.save(next)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Palette.card,
          content: Text(
            'Couldn’t update this course item locally. Try again.',
            style: Type.body.copyWith(color: Palette.textHi),
          ),
        ),
      );
      return;
    }
    if (!mounted) return;
    Sfx.instance.play('tick');
    setState(() => _academicSchedule = next);
  }

  Future<void> _openNotebook(ClassOccurrence occurrence) async {
    final course = _academicSchedule.courseById(occurrence.courseId);
    if (course == null) return;
    Sfx.instance.play('tick');
    final result = await _notebookHandoff.open(
      NotebookHandoffIntent(
        courseId: occurrence.courseId,
        occurrenceKey: occurrence.occurrenceKey,
        notebookId: course.notebookId,
        courseCode: course.code,
        courseTitle: course.title,
        occurrenceDate: occurrence.date.toString(),
        startMinute: occurrence.localStartMinute,
        endMinute: occurrence.localEndMinute,
        meetingKind: occurrence.kind.name,
        place: occurrence.place.shortLabel,
        courseColorValue: course.colorValue,
      ),
    );
    if (!mounted || result == NotebookHandoffResult.opened) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Palette.card,
        content: Text(
          result == NotebookHandoffResult.unavailable
              ? 'The notebook app isn’t available here yet. Your class is still safely kept.'
              : 'The notebook couldn’t open this time. Your class is still safely kept.',
          style: Type.body.copyWith(color: Palette.textHi),
        ),
      ),
    );
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

  String? _starterFor(Note entry) {
    final source = entry.sourceQuestKey;
    if (source == null || source.isEmpty) return null;
    for (final quest in widget.quests) {
      if (quest.title == source) return quest.journalPrompt?.starter;
    }
    return null;
  }

  Future<void> _openJournal(Note entry) {
    Sfx.instance.play('tick');
    final night = entry.night;
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => JournalEntryScreen(
          initial: entry,
          accent: Palette.xp,
          themeId: widget.state.canvasTheme,
          reduceMotion: widget.state.reduceMotion,
          heading:
              'Journal · ${_monthNames[entry.at.month - 1]} ${entry.at.day}',
          starter: _starterFor(entry),
          trace: entry.trace,
          initiallyEditing: false,
          onEditRequested: night == null
              ? null
              : (readerContext) async {
                  final data = await showNightReflectionSheet(
                    readerContext,
                    initial: night,
                    reduceMotion: widget.state.reduceMotion,
                  );
                  if (!readerContext.mounted || data == null) return;
                  widget.state.updateNightJournalEntry(entry, data);
                  if (readerContext.mounted) {
                    Navigator.of(readerContext).pop();
                  }
                },
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
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final now = Clock.now();
        final firstWeekday = DateTime(_month.year, _month.month, 1).weekday;
        final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
        final bounds = _visibleDaybookBounds();
        final daybook = DaybookRangeProjection.build(
          schedule: _academicSchedule,
          quests: widget.quests,
          first: bounds.$1,
          last: bounds.$2,
          now: now,
        );
        final activeClasses = _academicSchedule.doorwayOccurrences(now);
        final nextClass = _academicSchedule.nextOccurrence(now);
        final doorwayClasses = activeClasses.isNotEmpty
            ? activeClasses
            : nextClass == null
            ? const <ClassOccurrence>[]
            : <ClassOccurrence>[nextClass];
        final selectedCivil = CivilDate.fromDateTime(_selected);
        final selectedTerm =
            _academicSchedule.termFor(selectedCivil) ??
            _academicSchedule.latestTerm;

        return LuxePageList(
          assetPath: 'assets/pages/plans-desk-v2.webp',
          title: 'Plans',
          subtitle: 'your days, held in one place',
          icon: Icons.calendar_month_outlined,
          parallax: widget.parallax,
          reduceMotion: widget.state.reduceMotion,
          children: [
            AcademicCalendarHeader(
              mode: _academicMode,
              termName: selectedTerm?.name,
              loading: _academicLoading,
              onModeChanged: _setAcademicMode,
              onAddAcademic: () => _showAddDaybook(context),
            ),
            if (doorwayClasses.isNotEmpty) ...[
              const SizedBox(height: 10),
              AcademicDoorway(
                occurrences: doorwayClasses,
                schedule: _academicSchedule,
                now: now,
                active: activeClasses.isNotEmpty,
                onOpenNotebook: _openNotebook,
              ),
            ],
            const SizedBox(height: 12),
            if (_academicMode == AcademicCalendarMode.month) ...[
              // ── month folio ──────────────────────────────────────
              // The calendar is the largest single plane in the app, so it is
              // built like the bound month-folio in the approved target: a
              // book-cloth board, a brass-ruled masthead, then the dated page
              // inset into it. A flat panel this size read as an empty block.
              _MonthFolio(
                key: const ValueKey('academic-month-folio'),
                month: _month,
                now: now,
                firstWeekday: firstWeekday,
                daysInMonth: daysInMonth,
                onPrevious: () => _moveMonth(-1),
                onNext: () => _moveMonth(1),
                onToday: _goToday,
                dayCell: (day) => _dayCell(day, daysInMonth, now, daybook),
              ),
            ] else ...[
              DaybookSpanPanel(
                mode: _academicMode,
                selectedDay: _selected,
                daybook: daybook,
                schedule: _academicSchedule,
                now: now,
                onPrevious: () => _moveAcademicSpan(-1),
                onNext: () => _moveAcademicSpan(1),
                onToday: _goToday,
                onSelectDay: _selectDay,
                onOpenNotebook: _openNotebook,
                onToggleTask: _toggleDaybookTask,
                onToggleWork: _toggleAcademicWork,
                onOpenStudyPlanner: _showAcademicStudyPlanner,
                onToggleStudyBlock: _toggleAcademicStudyBlock,
                onUpdateTransitionBuffer: _updateAcademicTransitionBuffer,
                onOpenOccurrenceAdjuster: _showAcademicOccurrenceAdjuster,
              ),
            ],
            const SizedBox(height: 14),

            // ── selected day panel ───────────────────────────────
            _DayPanel(
              day: _selected,
              completions: widget.state.history[Days.key(_selected)] ?? 0,
              reflections: _reflectionsOn(_selected),
              journalEntries: _journalOn(_selected),
              daybookDay: daybook.dayOn(CivilDate.fromDateTime(_selected)),
              showDaybookEntries: _academicMode == AcademicCalendarMode.month,
              academicSchedule: _academicSchedule,
              now: now,
              onPlan: () => _showAddEvent(context),
              onOpenJournal: _openJournal,
              onOpenNotebook: _openNotebook,
              onToggleTask: _toggleDaybookTask,
              onToggleWork: _toggleAcademicWork,
              onOpenStudyPlanner: _showAcademicStudyPlanner,
              onToggleStudyBlock: _toggleAcademicStudyBlock,
              onUpdateTransitionBuffer: _updateAcademicTransitionBuffer,
              onOpenOccurrenceAdjuster: _showAcademicOccurrenceAdjuster,
              lightDirection: widget.lightDirection ?? widget.parallax,
            ),
          ],
        );
      },
    );
  }

  Widget _dayCell(
    int day,
    int daysInMonth,
    DateTime now,
    DaybookRange daybook,
  ) {
    if (day < 1 || day > daysInMonth) {
      return const SizedBox.expand();
    }
    final date = DateTime(_month.year, _month.month, day);
    final daybookDay = daybook.dayOn(CivilDate.fromDateTime(date));
    final isToday = Days.sameDay(date, now);
    final isSelected = Days.sameDay(date, _selected);
    final done = widget.state.history[Days.key(date)] ?? 0;
    final journalEntries = _journalOn(date);

    final spoken = StringBuffer(
      '${_monthNames[date.month - 1]} ${date.day}, ${date.year}',
    );
    if (isToday) spoken.write(', today');
    spoken.write(', ${_spokenDayWeight(daybookDay.summary.weight)}');
    spoken.write(', ${daybookDay.summary.semanticLabel}');
    if (done > 0) {
      spoken.write(', $done quest${done == 1 ? '' : 's'} completed');
    }
    final transitionPressures = _academicSchedule.transitionPressuresOn(
      CivilDate.fromDateTime(date),
    );
    if (transitionPressures.isNotEmpty) {
      spoken.write(
        ', ${transitionPressures.length} tight class transition${transitionPressures.length == 1 ? '' : 's'}',
      );
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
      onTap: () => _selectDay(date),
      child: GestureDetector(
        excludeFromSemantics: true,
        onTap: () {
          Sfx.instance.play('tick');
          _selectDay(date);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dayPlate(day, date, isToday, isSelected, daybookDay.summary),
            // The folio names today under its date, the way the target does —
            // the honey plate alone doesn't say WHICH kind of mark it is.
            SizedBox(
              key: isToday
                  ? ValueKey(
                      'month-today-label-${CivilDate.fromDateTime(date)}',
                    )
                  : null,
              height: 12,
              child: isToday
                  ? Center(
                      child: Text(
                        'TODAY',
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        // A seven-column month cell is truly bounded metadata;
                        // its full spoken date remains available in Semantics.
                        textScaler: TextScaler.noScaling,
                        style: Type.label.copyWith(
                          fontSize: Type.minLabel,
                          height: 1,
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
    DaybookDaySummary summary,
  ) {
    final keyDate = CivilDate.fromDateTime(date).toString();
    return Container(
      key: isSelected ? ValueKey('month-selected-wash-$keyDate') : null,
      height: 43,
      margin: const EdgeInsets.all(1.5),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (isSelected)
            DecoratedBox(
              decoration: facetedDecoration(
                cut: 7,
                gradient: LinearGradient(
                  colors: [
                    Palette.xpLight.withValues(alpha: 0.18),
                    Palette.xp.withValues(alpha: 0.055),
                  ],
                ),
                borderColor: Colors.transparent,
                borderWidth: 0,
              ),
            ),
          Column(
            children: [
              SizedBox(
                height: 30,
                child: Center(
                  child: Container(
                    key: isToday
                        ? ValueKey('month-today-marker-$keyDate')
                        : null,
                    width: 30,
                    height: 30,
                    decoration: isToday
                        ? facetedDecoration(
                            cut: 6,
                            gradient: const LinearGradient(
                              colors: [Color(0x36FFE4A1), Color(0x0FE7B66C)],
                            ),
                            borderColor: Palette.xp.withValues(alpha: 0.85),
                          )
                        : null,
                    alignment: Alignment.center,
                    child: Text(
                      '$day',
                      // Keep the compact month numeral inside its fixed folio
                      // plate at large system text. The complete date is
                      // exposed by Semantics.
                      textScaler: TextScaler.noScaling,
                      style: Type.numerals.copyWith(
                        fontSize: 13,
                        color: isToday
                            ? Palette.xp
                            : isSelected
                            ? Palette.textHi
                            : Palette.textMid,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 13,
                child:
                    summary.weight == DaybookDayWeight.none &&
                        !summary.hasDeadline
                    ? null
                    : Center(
                        child: _MonthDayWeightMark(
                          key: ValueKey('academic-month-weight-$keyDate'),
                          weight: summary.weight,
                          hasDeadline: summary.hasDeadline,
                          deadlineKey: ValueKey(
                            'academic-month-deadline-$keyDate',
                          ),
                        ),
                      ),
              ),
            ],
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

  Future<void> _showAddDaybook(BuildContext context) async {
    Sfx.instance.play('tick');
    final target = await showDialog<DaybookAddTarget>(
      context: context,
      barrierColor: Palette.dialogBarrier,
      builder: (_) => const DaybookAddChoiceDialog(),
    );
    if (!mounted || !context.mounted || target == null) return;
    Sfx.instance.play('tick');
    switch (target) {
      case DaybookAddTarget.event:
        await showDialog<void>(
          context: context,
          barrierColor: Palette.dialogBarrier,
          builder: (_) => DaybookEventEditor(
            selectedDay: CivilDate.fromDateTime(_selected),
            onSave: _saveDaybookEvent,
          ),
        );
      case DaybookAddTarget.task:
        await showDialog<void>(
          context: context,
          barrierColor: Palette.dialogBarrier,
          builder: (_) => DaybookTaskEditor(
            selectedDay: CivilDate.fromDateTime(_selected),
            onSave: _saveDaybookTask,
          ),
        );
      case DaybookAddTarget.classMeeting:
        await showDialog<void>(
          context: context,
          barrierColor: Palette.dialogBarrier,
          builder: (_) => AddAcademicMeetingDialog(
            schedule: _academicSchedule,
            selectedDay: _selected,
            onSave: _saveAcademicMeeting,
          ),
        );
      case DaybookAddTarget.assignment || DaybookAddTarget.exam:
        await showDialog<void>(
          context: context,
          barrierColor: Palette.dialogBarrier,
          builder: (_) => AddAcademicWorkDialog(
            schedule: _academicSchedule,
            selectedDay: _selected,
            initialKind: target == DaybookAddTarget.exam
                ? AcademicWorkKind.exam
                : AcademicWorkKind.assignment,
            onSave: _saveAcademicWork,
          ),
        );
    }
  }
}

String _spokenDayWeight(DaybookDayWeight weight) => switch (weight) {
  DaybookDayWeight.none => 'open day',
  DaybookDayWeight.light => 'lightly scheduled day',
  DaybookDayWeight.moderate => 'moderately scheduled day',
  DaybookDayWeight.full => 'heavily scheduled day',
};

/// The month deliberately carries only one visual sentence per date. Height
/// means scheduled weight; the small diamond at the tick's crown means that
/// something is due. Specific categories belong in the selected-day panel.
class _MonthDayWeightMark extends StatelessWidget {
  const _MonthDayWeightMark({
    super.key,
    required this.weight,
    required this.hasDeadline,
    required this.deadlineKey,
  });

  final DaybookDayWeight weight;
  final bool hasDeadline;
  final Key deadlineKey;

  @override
  Widget build(BuildContext context) {
    final tickHeight = switch (weight) {
      DaybookDayWeight.none => 0.0,
      DaybookDayWeight.light => 6.0,
      DaybookDayWeight.moderate => 8.0,
      DaybookDayWeight.full => 10.0,
    };
    final ink = switch (weight) {
      DaybookDayWeight.none => Colors.transparent,
      DaybookDayWeight.light => Palette.xp.withValues(alpha: 0.65),
      DaybookDayWeight.moderate => Palette.xp.withValues(alpha: 0.82),
      DaybookDayWeight.full => Palette.xp.withValues(alpha: 0.96),
    };

    return SizedBox(
      width: 9,
      height: 13,
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.hardEdge,
        children: [
          Container(
            width: 3,
            height: tickHeight,
            decoration: BoxDecoration(
              color: ink,
              borderRadius: BorderRadius.circular(1.5),
            ),
          ),
          if (hasDeadline)
            Positioned(
              bottom: (tickHeight - 3).clamp(3.0, 7.0),
              child: SizedBox.square(
                dimension: 6,
                child: Center(
                  child: Transform.rotate(
                    angle: 0.785398,
                    child: Container(
                      key: deadlineKey,
                      width: 4.2,
                      height: 4.2,
                      color: Palette.brassLit.withValues(alpha: 0.94),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
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

class _MonthFolio extends StatelessWidget {
  const _MonthFolio({
    super.key,
    required this.month,
    required this.now,
    required this.firstWeekday,
    required this.daysInMonth,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
    required this.dayCell,
  });

  final DateTime month;
  final DateTime now;
  final int firstWeekday;
  final int daysInMonth;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;
  final Widget Function(int day) dayCell;

  int get _weekCount => ((firstWeekday - 1 + daysInMonth + 6) ~/ 7);

  @override
  Widget build(BuildContext context) => GlassPanel(
    blur: true,
    padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
    child: Column(
      children: [
        Row(
          children: [
            _Chevron(
              icon: Icons.chevron_left,
              label: 'Previous month',
              onTap: onPrevious,
            ),
            Expanded(
              child: Center(
                child: Text(
                  '${_monthNames[month.month - 1].toUpperCase()} ${month.year}',
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
              onTap: onNext,
            ),
          ],
        ),
        if (month.year != now.year || month.month != now.month)
          TextButton(
            onPressed: onToday,
            child: Text(
              'BACK TO TODAY',
              style: Type.label.copyWith(
                fontSize: Type.minLabel,
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
            padding: const EdgeInsets.fromLTRB(5, 10, 5, 8),
            child: Column(
              children: [
                Row(
                  children: [
                    for (var index = 0; index < 7; index++)
                      Expanded(
                        child: Center(
                          child: Text(
                            const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][index],
                            style: Type.label.copyWith(
                              fontSize: 11,
                              letterSpacing: 1.4,
                              color: index >= 5
                                  ? Palette.brass
                                  : Palette.textLo,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 7),
                const _FolioRule(strength: 0.55),
                const SizedBox(height: 5),
                for (var week = 0; week < _weekCount; week++)
                  SizedBox(
                    height: 62,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var column = 0; column < 7; column++)
                          Expanded(
                            child: dayCell(
                              week * 7 + column - (firstWeekday - 1) + 1,
                            ),
                          ),
                      ],
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
    void activate() {
      Sfx.instance.play('tick');
      onTap();
    }

    return Semantics(
      button: true,
      label: label,
      onTap: activate,
      child: GestureDetector(
        excludeFromSemantics: true,
        onTap: activate,
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
    required this.daybookDay,
    required this.showDaybookEntries,
    required this.academicSchedule,
    required this.now,
    required this.onPlan,
    required this.onOpenJournal,
    required this.onOpenNotebook,
    required this.onToggleTask,
    required this.onToggleWork,
    required this.onOpenStudyPlanner,
    required this.onToggleStudyBlock,
    required this.onUpdateTransitionBuffer,
    required this.onOpenOccurrenceAdjuster,
    required this.lightDirection,
  });

  final DateTime day;
  final int completions;
  final int reflections;
  final List<Note> journalEntries;
  final DaybookDay daybookDay;
  final bool showDaybookEntries;
  final AcademicSchedule academicSchedule;
  final DateTime now;
  final VoidCallback onPlan;
  final ValueChanged<Note> onOpenJournal;
  final OpenAcademicNotebook onOpenNotebook;
  final ToggleDaybookTask onToggleTask;
  final ToggleAcademicWork onToggleWork;
  final OpenAcademicStudyPlanner onOpenStudyPlanner;
  final ToggleAcademicStudyBlock onToggleStudyBlock;
  final UpdateAcademicTransitionBuffer onUpdateTransitionBuffer;
  final OpenAcademicOccurrenceAdjuster onOpenOccurrenceAdjuster;
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
          if (showDaybookEntries && daybookDay.entries.isNotEmpty)
            DaybookAgendaEntries(
              day: daybookDay,
              schedule: academicSchedule,
              onOpenNotebook: onOpenNotebook,
              onToggleTask: onToggleTask,
              onToggleWork: onToggleWork,
              onOpenStudyPlanner: onOpenStudyPlanner,
              onToggleStudyBlock: onToggleStudyBlock,
              onUpdateTransitionBuffer: onUpdateTransitionBuffer,
              onOpenOccurrenceAdjuster: onOpenOccurrenceAdjuster,
            ),
          if (showDaybookEntries &&
              daybookDay.entries.isNotEmpty &&
              (completions > 0 || reflections > 0 || journalEntries.isNotEmpty))
            const Divider(height: 17, color: Color(0x2EE7C47E)),
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
                fontSize: Type.minLabel,
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
          if (daybookDay.entries.isEmpty &&
              completions == 0 &&
              reflections == 0 &&
              journalEntries.isEmpty)
            Text(
              isPast ? 'A quiet day.' : 'Nothing planned for this day yet.',
              style: Type.body.copyWith(
                fontSize: 13.5,
                fontStyle: FontStyle.italic,
                color: Palette.textLo,
              ),
            ),
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
                          fontSize: Type.minLabel,
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
      label: 'Read journal entry. $preview',
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
                          fontSize: Type.minLabel,
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
                  fontSize: Type.minLabel,
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
                                    fontSize: Type.minLabel,
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
                      gradient: Palette.honeyGradient,
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
                        color: Palette.onHoney,
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
