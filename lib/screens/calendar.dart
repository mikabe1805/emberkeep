import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../academic_calendar/data/academic_calendar_preferences.dart';
import '../academic_calendar/data/academic_schedule_repository.dart';
import '../academic_calendar/domain/academic_schedule.dart';
import '../academic_calendar/import/academic_schedule_file_picker.dart';
import '../academic_calendar/import/academic_schedule_ics_import.dart';
import '../academic_calendar/services/notebook_handoff.dart';
import '../academic_calendar/widgets/academic_calendar_sections.dart';
import '../academic_calendar/widgets/academic_schedule_import_dialog.dart';
import '../audio.dart';
import '../clock.dart';
import '../daybook/data/daybook_preferences.dart';
import '../daybook/domain/daybook_event.dart';
import '../daybook/domain/daybook_task.dart';
import '../daybook/presentation/daybook_range_projection.dart';
import '../daybook/services/device_time_zone.dart';
import '../daybook/services/directions_launcher.dart';
import '../daybook/widgets/daybook_add_choice_dialog.dart';
import '../daybook/widgets/daybook_event_actions.dart';
import '../daybook/widgets/daybook_event_editor.dart';
import '../daybook/widgets/daybook_place_fields.dart';
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
    this.onCompleteQuest,
    this.parallax = const AlwaysStoppedAnimation(Offset.zero),
    this.lightDirection,
    this.scheduleRepository,
    this.calendarPreferences,
    this.notebookHandoff,
    this.directionsLauncher,
    this.daybookPreferences,
    this.timeZoneIdProvider,
    this.academicScheduleFilePicker,
    this.placeSearchFactory = const ProductionDaybookPlaceSearchFactory(),
  });

  final GameState state;
  final List<Quest> quests;
  final bool Function(Quest) onAdd;
  final void Function(Quest quest, Offset anchor)? onCompleteQuest;
  final ValueListenable<Offset> parallax;
  final ValueListenable<Offset>? lightDirection;
  final AcademicScheduleRepository? scheduleRepository;
  final AcademicCalendarPreferences? calendarPreferences;
  final NotebookHandoff? notebookHandoff;
  final DirectionsLauncher? directionsLauncher;
  final DaybookPreferences? daybookPreferences;
  final TimeZoneIdProvider? timeZoneIdProvider;
  final AcademicScheduleFilePicker? academicScheduleFilePicker;
  final DaybookPlaceSearchFactory placeSearchFactory;

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late DateTime _month;
  late DateTime _selected;
  late CivilDate _threeDayStart;
  final ScrollController _calendarScroll = ScrollController();
  late final AcademicScheduleRepository _scheduleRepository;
  late final AcademicCalendarPreferences _calendarPreferences;
  late final NotebookHandoff _notebookHandoff;
  late final DirectionsLauncher _directionsLauncher;
  late final DaybookPreferences _daybookPreferences;
  late final AcademicScheduleFilePicker _academicScheduleFilePicker;
  AcademicSchedule _academicSchedule = AcademicSchedule.empty();
  AcademicCalendarMode _academicMode = AcademicCalendarMode.month;
  bool _academicLoading = true;
  int _viewInteractionRevision = 0;
  Future<void> _viewSaveTail = Future<void>.value();

  @override
  void initState() {
    super.initState();
    final now = Clock.now();
    _month = DateTime(now.year, now.month);
    _selected = DateTime(now.year, now.month, now.day);
    _threeDayStart = CivilDate.fromDateTime(_selected);
    _scheduleRepository =
        widget.scheduleRepository ?? LocalAcademicScheduleRepository();
    _calendarPreferences =
        widget.calendarPreferences ?? LocalAcademicCalendarPreferences();
    _notebookHandoff =
        widget.notebookHandoff ?? UrlLauncherNotebookHandoff.configured();
    _directionsLauncher =
        widget.directionsLauncher ?? const ExternalDirectionsLauncher();
    _daybookPreferences =
        widget.daybookPreferences ?? LocalDaybookPreferences();
    _academicScheduleFilePicker =
        widget.academicScheduleFilePicker ??
        const PlatformAcademicScheduleFilePicker();
    unawaited(_loadAcademicCalendar());
  }

  Future<void> _loadAcademicCalendar() async {
    final scheduleFuture = _scheduleRepository.load();
    final preferencesFuture = _calendarPreferences.load();
    final schedule = await scheduleFuture;
    final preferences = await preferencesFuture;
    if (!mounted) return;
    DateTime? restoredDate;
    CivilDate? restoredThreeDayStart;
    if (preferences.selectedDate case final raw?) {
      try {
        final civil = CivilDate.parse(raw);
        restoredDate = DateTime(civil.year, civil.month, civil.day);
      } on FormatException {
        // A stale view preference never makes academic content unreadable.
      }
    }
    if (preferences.threeDayStartDate case final raw?) {
      try {
        restoredThreeDayStart = CivilDate.parse(raw);
      } on FormatException {
        // The selected date remains a safe backwards-compatible anchor.
      }
    }
    setState(() {
      _academicSchedule = schedule;
      // A person can touch Plans before local preferences finish loading.
      // That immediate choice is more current than the delayed snapshot.
      if (_viewInteractionRevision == 0) {
        _academicMode = preferences.mode;
        if (restoredDate != null) {
          _selected = restoredDate;
          _month = DateTime(restoredDate.year, restoredDate.month);
          final restoredSelected = CivilDate.fromDateTime(restoredDate);
          _threeDayStart =
              restoredThreeDayStart != null &&
                  restoredSelected.isWithin(
                    restoredThreeDayStart,
                    restoredThreeDayStart.addDays(
                      AcademicCalendarMode.threeDay.spanDays - 1,
                    ),
                  )
              ? restoredThreeDayStart
              : restoredSelected;
        }
      }
      _academicLoading = false;
    });
  }

  void _persistAcademicView() {
    final snapshot = AcademicCalendarViewState(
      mode: _academicMode,
      selectedDate: CivilDate.fromDateTime(_selected).toString(),
      threeDayStartDate: _threeDayStart.toString(),
    );
    // Preference writes are deliberately non-blocking, but serialize them so
    // a slow earlier write cannot land after a newer day or mode choice.
    _viewSaveTail = _viewSaveTail
        .catchError((_) {})
        .then<void>((_) => _calendarPreferences.save(snapshot));
  }

  void _recordViewInteraction() => _viewInteractionRevision++;

  void _selectDay(DateTime day) {
    _recordViewInteraction();
    final selected = CivilDate.fromDateTime(day);
    setState(() {
      _selected = DateTime(day.year, day.month, day.day);
      _month = DateTime(day.year, day.month);
      if (_academicMode == AcademicCalendarMode.threeDay &&
          !selected.isWithin(
            _threeDayStart,
            _threeDayStart.addDays(AcademicCalendarMode.threeDay.spanDays - 1),
          )) {
        _threeDayStart = selected;
      }
    });
    _persistAcademicView();
  }

  void _setAcademicMode(AcademicCalendarMode mode) {
    // Even choosing the already-visible mode is an explicit preference. It
    // must win over a delayed local restore just like a mode change does.
    _recordViewInteraction();
    if (_academicMode == mode) return;
    // switching month/week/day is a page turn, not a glass tap
    Sfx.instance.playInteraction(
      InteractionSound.navigate,
      material: MaterialSound.parchment,
    );
    setState(() {
      _academicMode = mode;
      _month = DateTime(_selected.year, _selected.month);
      if (mode == AcademicCalendarMode.threeDay) {
        _threeDayStart = CivilDate.fromDateTime(_selected);
      }
    });
    _persistAcademicView();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_calendarScroll.hasClients) _calendarScroll.jumpTo(0);
    });
  }

  void _moveMonth(int delta) {
    _recordViewInteraction();
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
    // A three-day spread keeps its visible window contiguous even after the
    // person chooses its second or third day. Otherwise "Next 3 days" can
    // overlap the current spread or skip the days immediately after it.
    final next = _academicMode == AcademicCalendarMode.threeDay
        ? _threeDayStart.addDays(direction * _academicMode.spanDays)
        : CivilDate.fromDateTime(
            _selected,
          ).addDays(direction * _academicMode.spanDays);
    _selectDay(DateTime(next.year, next.month, next.day));
  }

  void _goToday() {
    final now = Clock.now();
    _recordViewInteraction();
    setState(() {
      _month = DateTime(now.year, now.month);
      _selected = DateTime(now.year, now.month, now.day);
      if (_academicMode == AcademicCalendarMode.threeDay) {
        _threeDayStart = CivilDate.fromDateTime(_selected);
      }
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
    final first = switch (_academicMode) {
      AcademicCalendarMode.week => selected.startOfWeek(
        (_academicSchedule.termFor(selected) ?? _academicSchedule.latestTerm)
                ?.weekStartsOn ??
            DateTime.monday,
      ),
      AcademicCalendarMode.threeDay => _threeDayStart,
      _ => selected,
    };
    return (first, first.addDays(_academicMode.spanDays - 1));
  }

  @override
  void dispose() {
    _calendarScroll.dispose();
    super.dispose();
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

  Future<bool> _applyDaybookMutation(
    AcademicSchedule Function(AcademicSchedule schedule) change,
  ) async {
    late final AcademicSchedule next;
    try {
      next = change(_academicSchedule);
    } on ArgumentError {
      return false;
    }
    if (!await _scheduleRepository.save(next)) return false;
    if (mounted) setState(() => _academicSchedule = next);
    return true;
  }

  Future<bool> _deleteDaybookEvent(String eventId) =>
      _applyDaybookMutation((schedule) => schedule.deleteEvent(eventId));

  Future<bool> _deleteDaybookTask(String taskId) =>
      _applyDaybookMutation((schedule) => schedule.deleteTask(taskId));

  Future<bool> _moveDaybookEventOccurrence(
    DaybookEvent event,
    DaybookEventOccurrence occurrence,
    DaybookEvent candidate,
  ) => _applyDaybookMutation(
    (schedule) => schedule.moveEventOccurrence(
      eventId: event.eventId,
      occurrenceKey: occurrence.occurrenceKey,
      startDate: candidate.startDate,
      endDate: candidate.endDate,
      startMinute: candidate.startMinute,
      endMinute: candidate.endMinute,
      updatedAt: candidate.updatedAt,
    ),
  );

  Future<bool> _cancelDaybookEventOccurrence(
    DaybookEvent event,
    DaybookEventOccurrence occurrence,
  ) => _applyDaybookMutation(
    (schedule) => schedule.cancelEventOccurrence(
      eventId: event.eventId,
      occurrenceKey: occurrence.occurrenceKey,
      updatedAt: Clock.now().toUtc(),
    ),
  );

  Future<bool> _restoreDaybookEventOccurrence(
    DaybookEvent event,
    DaybookEventOccurrence occurrence,
  ) => _applyDaybookMutation(
    (schedule) => schedule.restoreEventOccurrence(
      eventId: event.eventId,
      occurrenceKey: occurrence.occurrenceKey,
      updatedAt: Clock.now().toUtc(),
    ),
  );

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
    Sfx.instance.playMaterial(MaterialSound.parchment);
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

  Future<bool> _saveAcademicScheduleImport(
    AcademicScheduleImportDraft draft,
  ) async {
    late final AcademicSchedule next;
    try {
      next = draft.applyTo(_academicSchedule, updatedAt: Clock.now().toUtc());
    } on ArgumentError {
      return false;
    } on FormatException {
      return false;
    }
    if (!await _scheduleRepository.save(next)) return false;
    if (!mounted) return true;

    final selected = CivilDate.fromDateTime(_selected);
    setState(() {
      _academicSchedule = next;
      if (!selected.isWithin(draft.term.startDate, draft.term.endDate)) {
        _selected = draft.term.startDate.dateArithmeticValue;
        _month = DateTime(_selected.year, _selected.month);
        _threeDayStart = draft.term.startDate;
      }
    });
    _persistAcademicView();
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
    Sfx.instance.playMaterial(MaterialSound.parchment);
    setState(() => _academicSchedule = next);
  }

  Future<void> _showAcademicStudyPlanner(AcademicWorkItem item) async {
    Sfx.instance.playMaterial(MaterialSound.glass);
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
    Sfx.instance.playMaterial(MaterialSound.glass);
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
    Sfx.instance.playMaterial(MaterialSound.parchment);
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
    Sfx.instance.playMaterial(MaterialSound.parchment);
    setState(() => _academicSchedule = next);
  }

  Future<void> _openNotebook(ClassOccurrence occurrence) async {
    final course = _academicSchedule.courseById(occurrence.courseId);
    if (course == null) return;
    Sfx.instance.playMaterial(MaterialSound.parchment);
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
    Sfx.instance.playMaterial(MaterialSound.parchment);
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

  void _completeQuestPlan(String questTitle, Offset anchor) {
    final complete = widget.onCompleteQuest;
    if (complete == null) return;
    Quest? quest;
    for (final candidate in widget.quests) {
      if (candidate.title == questTitle) {
        quest = candidate;
        break;
      }
    }
    if (quest == null || quest.doneFor(Clock.now())) return;
    complete(quest, anchor);
    if (mounted) setState(() {});
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
        final selectedCompletions =
            widget.state.history[Days.key(_selected)] ?? 0;
        final selectedReflections = _reflectionsOn(_selected);
        final selectedJournalEntries = _journalOn(_selected);
        final selectedHasHistory =
            selectedCompletions > 0 ||
            selectedReflections > 0 ||
            selectedJournalEntries.isNotEmpty;

        return LuxePageList(
          assetPath: 'assets/pages/plans-conservatory-v2.webp',
          title: 'Plans',
          subtitle: 'your days, held in one place',
          icon: Icons.calendar_month_outlined,
          parallax: widget.parallax,
          reduceMotion: widget.state.reduceMotion,
          scrollController: _calendarScroll,
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
                selected: _selected,
                now: now,
                daybook: daybook,
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
                onOpenDaybookActions: _showDaybookActions,
                onToggleTask: _toggleDaybookTask,
                onToggleWork: _toggleAcademicWork,
                onOpenStudyPlanner: _showAcademicStudyPlanner,
                onToggleStudyBlock: _toggleAcademicStudyBlock,
                onUpdateTransitionBuffer: _updateAcademicTransitionBuffer,
                onOpenOccurrenceAdjuster: _showAcademicOccurrenceAdjuster,
                directionsLauncher: _directionsLauncher,
                daybookPreferences: _daybookPreferences,
                onCompleteQuestPlan: widget.onCompleteQuest == null
                    ? null
                    : _completeQuestPlan,
                selectedDayHeaderBuilder: (day) => _SelectedDayHeader(
                  day: DateTime(day.date.year, day.date.month, day.date.day),
                  now: now,
                  onPlan: () => _showAddEvent(context),
                  onToday: _goToday,
                  onSelect: () => _selectDay(
                    DateTime(day.date.year, day.date.month, day.date.day),
                  ),
                  lightDirection: widget.lightDirection ?? widget.parallax,
                  spanStyle: true,
                ),
                selectedDaySummaryBuilder: (day) =>
                    _DayShapeSummary(summary: day.summary),
              ),
            ],
            if (_academicMode == AcademicCalendarMode.month ||
                selectedHasHistory) ...[
              const SizedBox(height: 14),

              // Month owns the complete selected-day folio. Span modes already
              // keep the date, plan action, Day Shape, and agenda together;
              // this continuation carries only history and journal material.
              _DayPanel(
                day: _selected,
                completions: selectedCompletions,
                reflections: selectedReflections,
                journalEntries: selectedJournalEntries,
                daybookDay: daybook.dayOn(CivilDate.fromDateTime(_selected)),
                showDaybookEntries: _academicMode == AcademicCalendarMode.month,
                showDayShape: _academicMode == AcademicCalendarMode.month,
                showHeader: _academicMode == AcademicCalendarMode.month,
                academicSchedule: _academicSchedule,
                now: now,
                onPlan: () => _showAddEvent(context),
                onOpenJournal: _openJournal,
                onOpenNotebook: _openNotebook,
                onOpenDaybookActions: _showDaybookActions,
                onToggleTask: _toggleDaybookTask,
                onToggleWork: _toggleAcademicWork,
                onOpenStudyPlanner: _showAcademicStudyPlanner,
                onToggleStudyBlock: _toggleAcademicStudyBlock,
                onCompleteQuestPlan: widget.onCompleteQuest == null
                    ? null
                    : _completeQuestPlan,
                onUpdateTransitionBuffer: _updateAcademicTransitionBuffer,
                onOpenOccurrenceAdjuster: _showAcademicOccurrenceAdjuster,
                directionsLauncher: _directionsLauncher,
                daybookPreferences: _daybookPreferences,
                lightDirection: widget.lightDirection ?? widget.parallax,
              ),
            ],
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
    final keyDate = CivilDate.fromDateTime(date).toString();
    final daybookDay = daybook.dayOn(CivilDate.fromDateTime(date));
    final isToday = Days.sameDay(date, now);
    final isSelected = Days.sameDay(date, _selected);
    final done = widget.state.history[Days.key(date)] ?? 0;
    final journalEntries = _journalOn(date);

    final spoken = StringBuffer(
      _monthDaySemanticLabel(date, daybookDay.summary, isToday: isToday),
    );
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
      hint: isSelected
          ? 'Showing this day below the calendar'
          : 'Show this day below the calendar',
      excludeSemantics: true,
      onTap: () => _selectDay(date),
      child: GestureDetector(
        key: ValueKey('academic-month-day-$keyDate'),
        excludeFromSemantics: true,
        behavior: HitTestBehavior.opaque,
        onTap: () {
          Sfx.instance.playMaterial(MaterialSound.parchment);
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
                      child: Container(
                        key: ValueKey('month-today-clip-$keyDate'),
                        height: 10,
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: facetedDecoration(
                          cut: 2,
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xCC9A6B3C), Color(0xCC5A3A20)],
                          ),
                          borderColor: Palette.brassLit.withValues(alpha: 0.5),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'TODAY',
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          // A seven-column month cell is truly bounded metadata;
                          // its full spoken date remains available in Semantics.
                          textScaler: TextScaler.noScaling,
                          style: Type.label.copyWith(
                            fontSize: 7,
                            height: 1,
                            letterSpacing: 0.75,
                            color: Palette.brassLit,
                          ),
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
                        !summary.hasDeadline &&
                        summary.focusCount == 0
                    ? null
                    : Center(
                        child: _MonthDayWeightMark(
                          key:
                              summary.weight == DaybookDayWeight.none &&
                                  !summary.hasDeadline
                              ? null
                              : ValueKey('academic-month-weight-$keyDate'),
                          weight: summary.weight,
                          hasDeadline: summary.hasDeadline,
                          deadlineKey: ValueKey(
                            'academic-month-deadline-$keyDate',
                          ),
                          hasFocus: summary.focusCount > 0,
                          focusKey: ValueKey('academic-month-focus-$keyDate'),
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
    Sfx.instance.playMaterial(MaterialSound.brass);
    showDialog(
      context: context,
      barrierColor: const Color(0xCC140C06),
      builder: (_) => _AddEventDialog(day: _selected, onAdd: widget.onAdd),
    );
  }

  Future<void> _showAddDaybook(BuildContext context) async {
    Sfx.instance.playMaterial(MaterialSound.parchment);
    final target = await showDialog<DaybookAddTarget>(
      context: context,
      barrierColor: Palette.dialogBarrier,
      builder: (_) => const DaybookAddChoiceDialog(),
    );
    if (!mounted || !context.mounted || target == null) return;
    Sfx.instance.playMaterial(MaterialSound.glass);
    switch (target) {
      case DaybookAddTarget.event:
        await showDialog<void>(
          context: context,
          barrierColor: Palette.dialogBarrier,
          builder: (_) => DaybookEventEditor(
            selectedDay: CivilDate.fromDateTime(_selected),
            timeZoneIdProvider: widget.timeZoneIdProvider,
            placeSearchFactory: widget.placeSearchFactory,
            onSave: _saveDaybookEvent,
          ),
        );
      case DaybookAddTarget.task:
        await showDialog<void>(
          context: context,
          barrierColor: Palette.dialogBarrier,
          builder: (_) => DaybookTaskEditor(
            selectedDay: CivilDate.fromDateTime(_selected),
            placeSearchFactory: widget.placeSearchFactory,
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
            placeSearchFactory: widget.placeSearchFactory,
            onSave: _saveAcademicMeeting,
          ),
        );
      case DaybookAddTarget.importClasses:
        await showDialog<void>(
          context: context,
          barrierColor: Palette.dialogBarrier,
          builder: (_) => AcademicScheduleImportDialog(
            filePicker: _academicScheduleFilePicker,
            onImport: _saveAcademicScheduleImport,
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

  Future<void> _showDaybookActions(DaybookActionTarget target) async {
    switch (target) {
      case DaybookEventAction():
        final event = _academicSchedule.events
            .where((item) => item.eventId == target.eventId)
            .firstOrNull;
        if (event == null) return;
        final separator = target.occurrenceKey.lastIndexOf('@');
        if (separator < 0) return;
        final originalDate = CivilDate.parse(
          target.occurrenceKey.substring(separator + 1),
        );
        final occurrence = event
            .occurrenceFor(originalDate)
            .copyWith(occurrenceKey: target.occurrenceKey);
        await _showDaybookEventActions(event, occurrence);
      case DaybookTaskAction():
        final task = _academicSchedule.tasks
            .where((item) => item.taskId == target.taskId)
            .firstOrNull;
        if (task != null) await _showDaybookTaskActions(task);
      default:
        return;
    }
  }

  Future<void> _showDaybookEventActions(
    DaybookEvent event,
    DaybookEventOccurrence occurrence,
  ) async {
    DaybookEventScope? scope;
    if (event.weeklyRule != null) {
      scope = await showDialog<DaybookEventScope>(
        context: context,
        barrierColor: Palette.dialogBarrier,
        builder: (_) => DaybookEventScopeDialog(title: event.title),
      );
      if (!mounted || scope == null) return;
    }
    final command = await showDialog<DaybookEventCommand>(
      context: context,
      barrierColor: Palette.dialogBarrier,
      builder: (_) => DaybookEventActionsDialog(
        title: event.title,
        scope: scope,
        restorable: occurrence.state != DaybookEventOccurrenceState.scheduled,
      ),
    );
    if (!mounted || command == null) return;
    switch (command) {
      case DaybookEventCommand.edit:
        await showDialog<void>(
          context: context,
          barrierColor: Palette.dialogBarrier,
          builder: (_) => DaybookEventEditor(
            selectedDay: occurrence.startDate,
            initialEvent: scope == DaybookEventScope.thisEvent
                ? event.copyWith(weeklyRule: null, exceptions: const [])
                : event,
            initialOccurrence: scope == DaybookEventScope.thisEvent
                ? occurrence
                : null,
            occurrenceMoveOnly: scope == DaybookEventScope.thisEvent,
            timeZoneIdProvider: widget.timeZoneIdProvider,
            placeSearchFactory: widget.placeSearchFactory,
            onSave: scope == DaybookEventScope.thisEvent
                ? (candidate) =>
                      _moveDaybookEventOccurrence(event, occurrence, candidate)
                : _saveDaybookEvent,
          ),
        );
      case DaybookEventCommand.delete:
        await _confirmDaybookMutation(
          heading: scope == DaybookEventScope.entireSeries
              ? 'DELETE SERIES'
              : 'DELETE EVENT',
          message: scope == DaybookEventScope.entireSeries
              ? 'Remove ${event.title} and every generated occurrence?'
              : 'Remove ${event.title} from your Daybook?',
          confirmLabel: scope == DaybookEventScope.entireSeries
              ? 'DELETE SERIES'
              : 'DELETE EVENT',
          confirmKey: const ValueKey('daybook-confirm-delete-event'),
          errorMessage: "Couldn’t delete this event locally. Try again.",
          onConfirm: () => _deleteDaybookEvent(event.eventId),
        );
      case DaybookEventCommand.cancel:
        await _confirmDaybookMutation(
          heading: 'CANCEL EVENT',
          message: 'Cancel only this occurrence of ${event.title}?',
          confirmLabel: 'CANCEL EVENT',
          confirmKey: const ValueKey('daybook-confirm-cancel-event'),
          errorMessage: "Couldn’t cancel this event locally. Try again.",
          onConfirm: () => _cancelDaybookEventOccurrence(event, occurrence),
        );
      case DaybookEventCommand.restore:
        await _confirmDaybookMutation(
          heading: 'RESTORE EVENT',
          message: 'Return this occurrence of ${event.title}?',
          confirmLabel: 'RESTORE EVENT',
          confirmKey: const ValueKey('daybook-confirm-restore-event'),
          errorMessage: "Couldn’t restore this event locally. Try again.",
          danger: false,
          onConfirm: () => _restoreDaybookEventOccurrence(event, occurrence),
        );
    }
  }

  Future<void> _showDaybookTaskActions(DaybookTask task) async {
    final command = await showDialog<DaybookTaskCommand>(
      context: context,
      barrierColor: Palette.dialogBarrier,
      builder: (_) => DaybookTaskActionsDialog(title: task.title),
    );
    if (!mounted || command == null) return;
    switch (command) {
      case DaybookTaskCommand.edit:
        await showDialog<void>(
          context: context,
          barrierColor: Palette.dialogBarrier,
          builder: (_) => DaybookTaskEditor(
            selectedDay: task.dueDate,
            initialTask: task,
            placeSearchFactory: widget.placeSearchFactory,
            onSave: _saveDaybookTask,
          ),
        );
      case DaybookTaskCommand.delete:
        await _confirmDaybookMutation(
          heading: 'DELETE TASK',
          message: 'Remove ${task.title} from your Daybook?',
          confirmLabel: 'DELETE TASK',
          confirmKey: const ValueKey('daybook-confirm-delete-task'),
          errorMessage: "Couldn’t delete this task locally. Try again.",
          onConfirm: () => _deleteDaybookTask(task.taskId),
        );
    }
  }

  Future<void> _confirmDaybookMutation({
    required String heading,
    required String message,
    required String confirmLabel,
    required Key confirmKey,
    required String errorMessage,
    required Future<bool> Function() onConfirm,
    bool danger = true,
  }) => showDialog<void>(
    context: context,
    barrierColor: Palette.dialogBarrier,
    builder: (_) => DaybookMutationDialog(
      heading: heading,
      message: message,
      confirmLabel: confirmLabel,
      confirmKey: confirmKey,
      errorMessage: errorMessage,
      onConfirm: onConfirm,
      danger: danger,
    ),
  );
}

String _monthDaySemanticLabel(
  DateTime date,
  DaybookDaySummary summary, {
  required bool isToday,
}) {
  final facts = <String>[
    '${_monthNames[date.month - 1]} ${date.day}, ${date.year}',
    if (isToday) 'today',
    summary.scheduledMinutes == 0
        ? 'no timed plans'
        : '${summary.scheduledMinutes} scheduled minutes',
  ];
  if (summary.fixedPlanCount == 0) {
    facts.add('no fixed plans');
  } else if (summary.scheduledMinutes == 0) {
    facts.add(
      '${summary.fixedPlanCount} all-day plan${summary.fixedPlanCount == 1 ? '' : 's'}',
    );
  } else {
    facts.add(
      '${summary.fixedPlanCount} fixed plan${summary.fixedPlanCount == 1 ? '' : 's'}',
    );
  }
  facts.add(
    summary.deadlineCount == 0
        ? 'no active deadlines'
        : '${summary.deadlineCount} active deadline${summary.deadlineCount == 1 ? '' : 's'}',
  );
  facts.add(
    summary.focusCount == 0
        ? 'no active focus choices'
        : '${summary.focusCount} active focus choice${summary.focusCount == 1 ? '' : 's'}',
  );
  return facts.join(', ');
}

/// The month deliberately carries only one visual sentence per date. Height
/// means scheduled weight; the small diamond at the tick's crown means that
/// something is due; the quiet unlock point names an intentional focus. Specific
/// categories belong in the selected-day panel.
class _MonthDayWeightMark extends StatelessWidget {
  const _MonthDayWeightMark({
    super.key,
    required this.weight,
    required this.hasDeadline,
    required this.deadlineKey,
    required this.hasFocus,
    required this.focusKey,
  });

  final DaybookDayWeight weight;
  final bool hasDeadline;
  final Key deadlineKey;
  final bool hasFocus;
  final Key focusKey;

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
          if (hasFocus)
            Positioned(
              bottom: 0,
              left: tickHeight > 0 ? null : 3,
              right: tickHeight > 0 ? 0 : null,
              child: Container(
                key: focusKey,
                width: 3,
                height: 3,
                decoration: const BoxDecoration(
                  color: Palette.unlock,
                  shape: BoxShape.circle,
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
    required this.selected,
    required this.now,
    required this.daybook,
    required this.firstWeekday,
    required this.daysInMonth,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
    required this.dayCell,
  });

  final DateTime month;
  final DateTime selected;
  final DateTime now;
  final DaybookRange daybook;
  final int firstWeekday;
  final int daysInMonth;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;
  final Widget Function(int day) dayCell;

  int get _weekCount => ((firstWeekday - 1 + daysInMonth + 6) ~/ 7);

  @override
  Widget build(BuildContext context) {
    final summary = _MonthFolioSummary.from(
      daybook,
      firstWeekday: firstWeekday,
      weekCount: _weekCount,
    );
    final selectedIsToday = Days.sameDay(selected, now);
    final selectedContext =
        '${_weekdayNames[selected.weekday - 1].substring(0, 3)} '
        '${selected.day} · ${selectedIsToday ? 'TODAY' : 'BACK TO TODAY'}';
    final monthHeading = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '${_monthNames[month.month - 1].toUpperCase()} ${month.year}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Type.display.copyWith(
            fontSize: 16,
            letterSpacing: 2.4,
            color: Palette.textHi,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          selectedContext,
          key: const ValueKey('month-selected-context'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textScaler: TextScaler.noScaling,
          style: Type.label.copyWith(
            fontSize: Type.minLabel,
            letterSpacing: 1.1,
            color: selectedIsToday ? Palette.textLo : Palette.xpLight,
          ),
        ),
      ],
    );
    final monthHeadingHitArea = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Center(child: monthHeading),
    );
    final interactiveHeading = selectedIsToday
        ? Semantics(
            key: const ValueKey('month-selected-context-control'),
            header: true,
            label:
                '${_monthNames[month.month - 1]} ${month.year}, $selectedContext',
            excludeSemantics: true,
            child: monthHeadingHitArea,
          )
        : Semantics(
            key: const ValueKey('month-selected-context-control'),
            button: true,
            header: true,
            label:
                '${_monthNames[month.month - 1]} ${month.year}, '
                '${_weekdayNames[selected.weekday - 1]} ${selected.day} selected. Back to today',
            onTap: onToday,
            excludeSemantics: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onToday,
              child: monthHeadingHitArea,
            ),
          );

    return GlassPanel(
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
              Expanded(child: interactiveHeading),
              _Chevron(
                icon: Icons.chevron_right,
                label: 'Next month',
                onTap: onNext,
              ),
            ],
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
                      // The target spends the calendar's lower edge on a
                      // truthful month index. Tightening the rows keeps that
                      // index in the same physical folio instead of turning it
                      // into another card below the fold, while preserving a
                      // comfortable full-cell touch target.
                      height: 58,
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
                  const SizedBox(height: 2),
                  const _FolioRule(strength: 0.48),
                  const SizedBox(height: 6),
                  _MonthSummaryRail(summary: summary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

final class _MonthFolioSummary {
  const _MonthFolioSummary({
    required this.taskCount,
    required this.eventCount,
    required this.classCount,
    required this.weekPlanCounts,
  });

  factory _MonthFolioSummary.from(
    DaybookRange daybook, {
    required int firstWeekday,
    required int weekCount,
  }) {
    final tasks = <String>{};
    final events = <String>{};
    final classes = <String>{};
    final weeklyPlans = List.generate(weekCount, (_) => <String>{});

    for (final day in daybook.days.values) {
      final week = (firstWeekday - 1 + day.date.day - 1) ~/ 7;
      for (final entry in day.entries) {
        if (entry.cancelled) continue;
        switch (entry.sourceKind) {
          case DaybookSourceKind.task:
            tasks.add(entry.displayKey);
            weeklyPlans[week].add(
              '${entry.sourceKind.name}:${entry.displayKey}',
            );
          case DaybookSourceKind.event:
            events.add(entry.displayKey);
            weeklyPlans[week].add(
              '${entry.sourceKind.name}:${entry.displayKey}',
            );
          case DaybookSourceKind.classOccurrence:
            classes.add(entry.displayKey);
            weeklyPlans[week].add(
              '${entry.sourceKind.name}:${entry.displayKey}',
            );
          case DaybookSourceKind.academicWork:
          case DaybookSourceKind.studyBlock:
          case DaybookSourceKind.questPlan:
            break;
        }
      }
    }

    return _MonthFolioSummary(
      taskCount: tasks.length,
      eventCount: events.length,
      classCount: classes.length,
      weekPlanCounts: [for (final plans in weeklyPlans) plans.length],
    );
  }

  final int taskCount;
  final int eventCount;
  final int classCount;
  final List<int> weekPlanCounts;
}

class _MonthSummaryRail extends StatelessWidget {
  const _MonthSummaryRail({required this.summary});

  final _MonthFolioSummary summary;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey('month-summary-rail'),
      height: 24,
      child: Row(
        children: [
          Expanded(
            child: _MonthSummaryMetric(
              metricKey: const ValueKey('month-summary-tasks'),
              value: summary.taskCount,
              label: 'TASKS',
            ),
          ),
          const _MonthSummaryDivider(),
          Expanded(
            child: _MonthSummaryMetric(
              metricKey: const ValueKey('month-summary-events'),
              value: summary.eventCount,
              label: 'EVENTS',
            ),
          ),
          const _MonthSummaryDivider(),
          Expanded(
            child: _MonthSummaryMetric(
              metricKey: const ValueKey('month-summary-classes'),
              value: summary.classCount,
              label: 'CLASSES',
            ),
          ),
          const _MonthSummaryDivider(),
          Expanded(child: _MonthWeekRhythm(counts: summary.weekPlanCounts)),
        ],
      ),
    );
  }
}

class _MonthSummaryMetric extends StatelessWidget {
  const _MonthSummaryMetric({
    required this.metricKey,
    required this.value,
    required this.label,
  });

  final Key metricKey;
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final displayLabel = value == 1
        ? switch (label) {
            'TASKS' => 'TASK',
            'EVENTS' => 'EVENT',
            'CLASSES' => 'CLASS',
            _ => label,
          }
        : label;
    final spokenLabel = displayLabel.toLowerCase();
    return Semantics(
      label: '$value $spokenLabel this month',
      excludeSemantics: true,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text.rich(
          key: metricKey,
          TextSpan(
            children: [
              TextSpan(
                text: '$value ',
                style: Type.numerals.copyWith(
                  fontSize: 11,
                  color: Palette.textMid,
                ),
              ),
              TextSpan(
                text: displayLabel,
                style: Type.label.copyWith(
                  fontSize: 8.5,
                  letterSpacing: 0.9,
                  color: Palette.textLo,
                ),
              ),
            ],
          ),
          maxLines: 1,
          textScaler: TextScaler.noScaling,
        ),
      ),
    );
  }
}

class _MonthSummaryDivider extends StatelessWidget {
  const _MonthSummaryDivider();

  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 18,
    color: Palette.brass.withValues(alpha: 0.38),
  );
}

class _MonthWeekRhythm extends StatelessWidget {
  const _MonthWeekRhythm({required this.counts});

  final List<int> counts;

  @override
  Widget build(BuildContext context) {
    final activeWeeks = counts.where((count) => count > 0).length;
    final maxCount = counts.fold<int>(
      0,
      (value, count) => count > value ? count : value,
    );
    return Semantics(
      key: const ValueKey('month-summary-rhythm'),
      label:
          '$activeWeeks of ${counts.length} calendar weeks contain plans this month',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var index = 0; index < counts.length; index++) ...[
              if (index > 0)
                Expanded(
                  child: Container(
                    height: 1,
                    color: Palette.textLo.withValues(alpha: 0.38),
                  ),
                ),
              _MonthWeekDot(
                strength: counts[index] == 0 || maxCount == 0
                    ? 0
                    : counts[index] / maxCount,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MonthWeekDot extends StatelessWidget {
  const _MonthWeekDot({required this.strength});

  final double strength;

  @override
  Widget build(BuildContext context) {
    final active = strength > 0;
    return Container(
      width: active ? 5 : 4,
      height: active ? 5 : 4,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active
            ? Palette.xp.withValues(alpha: 0.5 + (strength * 0.5))
            : Colors.transparent,
        border: Border.all(
          color: active
              ? Palette.xpLight.withValues(alpha: 0.62)
              : Palette.textLo.withValues(alpha: 0.45),
          width: 0.75,
        ),
      ),
    );
  }
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
      Sfx.instance.playMaterial(MaterialSound.brass);
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

class _SelectedDayHeader extends StatelessWidget {
  const _SelectedDayHeader({
    required this.day,
    required this.now,
    required this.onPlan,
    required this.lightDirection,
    this.onSelect,
    this.onToday,
    this.spanStyle = false,
  });

  final DateTime day;
  final DateTime now;
  final VoidCallback onPlan;
  final ValueListenable<Offset> lightDirection;
  final VoidCallback? onSelect;
  final VoidCallback? onToday;
  final bool spanStyle;

  @override
  Widget build(BuildContext context) {
    final isToday = Days.sameDay(day, now);
    final isPast = day.isBefore(DateTime(now.year, now.month, now.day));
    final largeText = MediaQuery.textScalerOf(context).scale(11.5) >= 17.25;
    final labelStyle = Type.label.copyWith(
      fontSize: 11.5,
      letterSpacing: 1.5,
      color: isToday ? Palette.xpLight : Palette.textMid,
    );
    final spoken =
        '${_weekdayNames[day.weekday - 1]} ${day.day}'
        '${isToday ? ', today' : ''}';
    Widget visualDayLabel() => spanStyle
        ? Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 2,
            children: [
              Text(
                '${_weekdayNames[day.weekday - 1]} ${day.day}',
                style: labelStyle,
              ),
              if (isToday)
                Text(
                  'TODAY',
                  style: Type.label.copyWith(
                    fontSize: Type.minLabel,
                    color: Palette.xp,
                  ),
                ),
            ],
          )
        : Text(
            '${_weekdayNames[day.weekday - 1]} ${day.day}'
            '${isToday ? " · TODAY" : " · ${_monthNames[day.month - 1].toUpperCase()}"}',
            maxLines: largeText ? 2 : 1,
            overflow: largeText ? TextOverflow.clip : TextOverflow.ellipsis,
            style: labelStyle,
          );
    final dayLabel = onSelect == null
        ? Semantics(
            header: true,
            label: spoken,
            excludeSemantics: true,
            child: visualDayLabel(),
          )
        : Semantics(
            key: ValueKey('daybook-day-control-${CivilDate.fromDateTime(day)}'),
            button: true,
            selected: true,
            header: true,
            label: spoken,
            onTap: onSelect,
            excludeSemantics: true,
            child: InkWell(
              onTap: onSelect,
              borderRadius: BorderRadius.circular(9),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: visualDayLabel(),
                ),
              ),
            ),
          );
    final planAction = isPast
        ? null
        : Semantics(
            button: true,
            label: 'Add a plan for $spoken',
            onTap: onPlan,
            child: GestureDetector(
              key: const ValueKey('calendar-plan-selected-day'),
              excludeFromSemantics: true,
              behavior: HitTestBehavior.opaque,
              onTap: onPlan,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                child: Center(
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
              ),
            ),
          );
    final todayAction = isToday || onToday == null
        ? null
        : TextButton(
            key: const ValueKey('calendar-back-to-today'),
            onPressed: onToday,
            style: TextButton.styleFrom(
              minimumSize: const Size(44, 44),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'TODAY',
              style: Type.label.copyWith(
                fontSize: Type.minLabel,
                letterSpacing: 1.0,
                color: Palette.xpLight,
              ),
            ),
          );
    final actions = Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      runSpacing: 4,
      children: [?todayAction, ?planAction],
    );

    if (largeText) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          dayLabel,
          if (todayAction != null || planAction != null) ...[
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerRight, child: actions),
          ],
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: dayLabel),
        if (todayAction != null || planAction != null) actions,
      ],
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
    required this.showDayShape,
    required this.showHeader,
    required this.academicSchedule,
    required this.now,
    required this.onPlan,
    required this.onOpenJournal,
    required this.onOpenNotebook,
    required this.onOpenDaybookActions,
    required this.onToggleTask,
    required this.onToggleWork,
    required this.onOpenStudyPlanner,
    required this.onToggleStudyBlock,
    required this.onCompleteQuestPlan,
    required this.onUpdateTransitionBuffer,
    required this.onOpenOccurrenceAdjuster,
    required this.directionsLauncher,
    required this.daybookPreferences,
    required this.lightDirection,
  });

  final DateTime day;
  final int completions;
  final int reflections;
  final List<Note> journalEntries;
  final DaybookDay daybookDay;
  final bool showDaybookEntries;
  final bool showDayShape;
  final bool showHeader;
  final AcademicSchedule academicSchedule;
  final DateTime now;
  final VoidCallback onPlan;
  final ValueChanged<Note> onOpenJournal;
  final OpenAcademicNotebook onOpenNotebook;
  final OpenDaybookActions onOpenDaybookActions;
  final ToggleDaybookTask onToggleTask;
  final ToggleAcademicWork onToggleWork;
  final OpenAcademicStudyPlanner onOpenStudyPlanner;
  final ToggleAcademicStudyBlock onToggleStudyBlock;
  final CompleteQuestPlan? onCompleteQuestPlan;
  final UpdateAcademicTransitionBuffer onUpdateTransitionBuffer;
  final OpenAcademicOccurrenceAdjuster onOpenOccurrenceAdjuster;
  final DirectionsLauncher directionsLauncher;
  final DaybookPreferences daybookPreferences;
  final ValueListenable<Offset> lightDirection;

  @override
  Widget build(BuildContext context) {
    final hasContentBeforeJournal =
        showHeader ||
        showDayShape ||
        (showDaybookEntries && daybookDay.entries.isNotEmpty) ||
        completions > 0 ||
        reflections > 0;
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showHeader) ...[
            _SelectedDayHeader(
              day: day,
              now: now,
              onPlan: onPlan,
              lightDirection: lightDirection,
            ),
            const SizedBox(height: 9),
          ],
          if (showDayShape) ...[
            _DayShapeSummary(summary: daybookDay.summary),
            const SizedBox(height: 12),
          ],
          if (showDaybookEntries && daybookDay.entries.isNotEmpty)
            DaybookAgendaEntries(
              day: daybookDay,
              schedule: academicSchedule,
              onOpenNotebook: onOpenNotebook,
              onOpenDaybookActions: onOpenDaybookActions,
              onToggleTask: onToggleTask,
              onToggleWork: onToggleWork,
              onOpenStudyPlanner: onOpenStudyPlanner,
              onToggleStudyBlock: onToggleStudyBlock,
              onCompleteQuestPlan: onCompleteQuestPlan,
              onUpdateTransitionBuffer: onUpdateTransitionBuffer,
              onOpenOccurrenceAdjuster: onOpenOccurrenceAdjuster,
              directionsLauncher: directionsLauncher,
              daybookPreferences: daybookPreferences,
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
            if (hasContentBeforeJournal)
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
        ],
      ),
    );
  }
}

class _DayShapeSummary extends StatelessWidget {
  const _DayShapeSummary({required this.summary});

  final DaybookDaySummary summary;

  @override
  Widget build(BuildContext context) {
    final facts = <String>[];
    if (summary.fixedPlanCount > 0) {
      if (summary.firstTimedStartMinute == null &&
          summary.fixedPlanCount == 1) {
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
    final body = facts.isEmpty ? 'No fixed plans.' : facts.join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1, thickness: 1, color: Color(0x46E7C47E)),
        const SizedBox(height: 8),
        Text(
          'DAY SHAPE',
          style: Type.label.copyWith(
            fontSize: Type.minLabel,
            letterSpacing: 1.7,
            color: Palette.xpLight,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          body,
          style: Type.body.copyWith(fontSize: 13.5, color: Palette.textMid),
        ),
      ],
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
    Sfx.instance.playMaterial(MaterialSound.parchment);
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
