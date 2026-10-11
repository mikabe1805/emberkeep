import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../academic_calendar/data/academic_calendar_preferences.dart';
import '../academic_calendar/data/academic_schedule_repository.dart';
import '../academic_calendar/domain/academic_schedule.dart';
import '../academic_calendar/import/academic_schedule_file_picker.dart';
import '../academic_calendar/import/academic_schedule_file_inbox.dart';
import '../academic_calendar/import/academic_schedule_ics_import.dart';
import '../academic_calendar/import/calendar_link.dart';
import '../academic_calendar/import/device_calendar_reader.dart';
import '../academic_calendar/services/notebook_handoff.dart';
import '../academic_calendar/widgets/academic_calendar_sections.dart';
import '../academic_calendar/widgets/add_classes_sheet.dart';
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
import '../platform/share_stub.dart'
    if (dart.library.js_interop) '../platform/share_web.dart';
import '../tokens.dart';
import '../widgets/domain_hint.dart';
import '../widgets/facets.dart';
import '../widgets/glass.dart';
import '../widgets/honey_button.dart';
import '../widgets/house/plans/plans_actions.dart';
import '../widgets/house/plans/plans_room.dart';
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

/// The Plans page: the daybook (see widgets/house/plans/). Month, week and day
/// are three spreads of one open book; a day's classes, plans, work and notes
/// are on its page. This state owns the schedule and every change to it.
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
    this.academicScheduleFileInbox,
    this.requestReminderPermission,
    this.calendarLinkFetcher,
    this.deviceCalendarReader,
    this.onScheduleChanged,
    this.addClassesRequestId = 0,
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
  final AcademicScheduleFileInbox? academicScheduleFileInbox;

  /// Notification permission is requested only from the explicit
  /// class-reminder switch that follows an import.
  final Future<bool> Function()? requestReminderPermission;

  /// Reads a pasted calendar link; null uses the device fetch.
  final CalendarLinkFetcher? calendarLinkFetcher;

  /// The phone's own calendars (iOS EventKit). Null until that slice ships;
  /// when set, the Add your classes sheet offers it as a way in.
  final DeviceCalendarReader? deviceCalendarReader;
  final ValueChanged<AcademicSchedule>? onScheduleChanged;

  /// A one-shot request to open the Add your classes sheet (the Quests
  /// board's "Add your classes" row). Each new id opens it once.
  final int addClassesRequestId;
  final DaybookPlaceSearchFactory placeSearchFactory;

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late DateTime _month;
  late DateTime _selected;
  late CivilDate _threeDayStart;
  late final AcademicScheduleRepository _scheduleRepository;
  late final AcademicCalendarPreferences _calendarPreferences;
  late final NotebookHandoff _notebookHandoff;
  late final DirectionsLauncher _directionsLauncher;
  late final DaybookPreferences _daybookPreferences;
  late final AcademicScheduleFilePicker _academicScheduleFilePicker;
  AcademicSchedule _academicSchedule = AcademicSchedule.empty();
  AcademicCalendarMode _academicMode = AcademicCalendarMode.day;
  bool _academicLoading = true;

  /// Completes once the saved schedule has loaded. Adding classes waits on
  /// it, so nothing is ever built on the empty schedule Plans starts with.
  late final Future<void> _academicLoad;
  bool _academicImportOpen = false;
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
    widget.academicScheduleFileInbox?.addListener(
      _onIncomingAcademicScheduleFile,
    );
    _academicLoad = _loadAcademicCalendar();
    unawaited(_academicLoad);
    _acceptAddClassesRequest();
  }

  int _handledAddClassesRequest = 0;

  void _acceptAddClassesRequest() {
    final id = widget.addClassesRequestId;
    if (id <= 0 || id == _handledAddClassesRequest) return;
    _handledAddClassesRequest = id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_showAddClasses());
    });
  }

  @override
  void didUpdateWidget(covariant CalendarPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _acceptAddClassesRequest();
    if (oldWidget.academicScheduleFileInbox ==
        widget.academicScheduleFileInbox) {
      return;
    }
    oldWidget.academicScheduleFileInbox?.removeListener(
      _onIncomingAcademicScheduleFile,
    );
    widget.academicScheduleFileInbox?.addListener(
      _onIncomingAcademicScheduleFile,
    );
    _onIncomingAcademicScheduleFile();
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
    widget.onScheduleChanged?.call(schedule);
    _onIncomingAcademicScheduleFile();
  }

  void _onIncomingAcademicScheduleFile() {
    if (!mounted || _academicLoading || _academicImportOpen) return;
    final inbox = widget.academicScheduleFileInbox;
    if (inbox == null || !inbox.isNotEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_drainAcademicScheduleFiles());
    });
  }

  Future<void> _drainAcademicScheduleFiles() async {
    if (_academicImportOpen || !mounted) return;
    final inbox = widget.academicScheduleFileInbox;
    final source = inbox?.takeNext();
    if (source == null) return;
    await _showAddClasses(initialSource: source);
    if (mounted && (inbox?.isNotEmpty ?? false)) {
      _onIncomingAcademicScheduleFile();
    }
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
    // The day view shows its whole week on the left page, so it projects the
    // week; three days is its own window.
    if (_academicMode == AcademicCalendarMode.threeDay) {
      return (_threeDayStart, _threeDayStart.addDays(2));
    }
    final first = selected.startOfWeek(
      (_academicSchedule.termFor(selected) ?? _academicSchedule.latestTerm)
              ?.weekStartsOn ??
          DateTime.monday,
    );
    return (first, first.addDays(6));
  }

  @override
  void dispose() {
    widget.academicScheduleFileInbox?.removeListener(
      _onIncomingAcademicScheduleFile,
    );
    super.dispose();
  }

  void _reportScheduleChange(AcademicSchedule schedule) {
    widget.onScheduleChanged?.call(schedule);
  }

  Future<bool> _saveDaybookEvent(DaybookEvent event) async {
    late final AcademicSchedule next;
    try {
      next = _academicSchedule.putEvent(event);
    } on ArgumentError {
      return false;
    }
    if (!await _scheduleRepository.save(next)) return false;
    _reportScheduleChange(next);
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
    _reportScheduleChange(next);
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
    _reportScheduleChange(next);
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
    _reportScheduleChange(next);
    if (!mounted) return;
    Sfx.instance.playInteraction(InteractionSound.place);
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
    _reportScheduleChange(next);
    if (mounted) {
      setState(() => _academicSchedule = next);
      _persistAcademicView();
    }
    return true;
  }

  /// Saves what the Add your classes sheet builds (an import, a typed class,
  /// or a reminder choice) on the schedule Plans holds right now, and keeps
  /// the selected day inside its term.
  Future<AddClassesSaved?> _saveAddedClasses(AddClassesChange change) async {
    await _academicLoad;
    final before = _academicSchedule;
    final step = change(before);
    final next = step.next;
    final term = step.term;
    if (!await _scheduleRepository.save(next)) return null;
    _reportScheduleChange(next);
    final saved = AddClassesSaved(before: before, next: next, term: term);
    if (!mounted) return saved;

    final selected = CivilDate.fromDateTime(_selected);
    setState(() {
      _academicSchedule = next;
      if (!selected.isWithin(term.startDate, term.endDate)) {
        _selected = DateTime(
          term.startDate.year,
          term.startDate.month,
          term.startDate.day,
        );
        _month = DateTime(_selected.year, _selected.month);
        _threeDayStart = term.startDate;
      }
    });
    _persistAcademicView();
    return saved;
  }

  /// SEE MY WEEK: the WEEK view on the week the sheet showed.
  void _showWeekOf(CivilDate date) {
    _recordViewInteraction();
    setState(() {
      _academicMode = AcademicCalendarMode.week;
      _selected = DateTime(date.year, date.month, date.day);
      _month = DateTime(date.year, date.month);
      _threeDayStart = date;
    });
    _persistAcademicView();
  }

  Future<bool> _saveAcademicWork(AcademicWorkItem item) async {
    late final AcademicSchedule next;
    try {
      next = _academicSchedule.putWorkItem(item);
    } on ArgumentError {
      return false;
    }
    if (!await _scheduleRepository.save(next)) return false;
    _reportScheduleChange(next);
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
    _reportScheduleChange(next);
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
    _reportScheduleChange(next);
    if (!mounted) return;
    Sfx.instance.playInteraction(InteractionSound.place);
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
    _reportScheduleChange(next);
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
    _reportScheduleChange(next);
    if (!mounted) return false;
    Sfx.instance.playInteraction(InteractionSound.place);
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
    _reportScheduleChange(next);
    if (!mounted) return;
    Sfx.instance.playInteraction(InteractionSound.place);
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

  bool _toggleKeepsake(Note entry) {
    final pinned = !widget.state.memoryPins.contains(entry.id);
    widget.state.setMemoryPinned(entry.id, pinned);
    Sfx.instance.play(pinned ? 'streak' : 'tick');
    HapticFeedback.selectionClick();
    return pinned;
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
          keepsakePinned: widget.state.memoryPins.contains(entry.id),
          onToggleKeepsake: _toggleKeepsake,
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

  /// Who is in session now, or coming next, by occurrence key: the card of
  /// that class says so.
  Map<String, ({String label, bool active})> _classStatus(DateTime now) {
    final active = _academicSchedule.doorwayOccurrences(now);
    final status = <String, ({String label, bool active})>{};
    if (active.isNotEmpty) {
      for (final occurrence in active) {
        final before = now.toUtc().isBefore(occurrence.startInstant);
        final minutes = math.max(
          1,
          (occurrence.startInstant.difference(now.toUtc()).inSeconds / 60)
              .ceil(),
        );
        status[occurrence.occurrenceKey] = (
          label: before ? 'READY IN $minutes MIN' : 'IN CLASS',
          active: true,
        );
      }
    } else if (_academicSchedule.nextOccurrence(now) case final next?) {
      final today = CivilDate.fromDateTime(now);
      final when = next.date == today
          ? 'TODAY'
          : next.date == today.addDays(1)
          ? 'TOMORROW'
          : '${_weekdayNames[next.date.weekday - 1]} ${next.date.day}';
      status[next.occurrenceKey] = (label: 'NEXT CLASS · $when', active: false);
    }
    return status;
  }

  PlansActions get _plansActions => PlansActions(
    onMode: _setAcademicMode,
    onSelectDay: _selectDay,
    onMoveSpan: _moveAcademicSpan,
    onToday: _goToday,
    onAdd: () => unawaited(_showAddDaybook(context)),
    onPlanQuest: () => _showAddEvent(context),
    onAddClasses: () => unawaited(_showAddClasses()),
    onOpenJournal: (note) => unawaited(_openJournal(note)),
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
  );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final now = Clock.now();
        final bounds = _visibleDaybookBounds();
        final daybook = DaybookRangeProjection.build(
          schedule: _academicSchedule,
          quests: widget.quests,
          first: bounds.$1,
          last: bounds.$2,
          now: now,
        );
        final selectedTerm =
            _academicSchedule.termFor(CivilDate.fromDateTime(_selected)) ??
            _academicSchedule.latestTerm;
        return PlansRoom(
          mode: _academicMode,
          selected: _selected,
          month: _month,
          now: now,
          schedule: _academicSchedule,
          daybook: daybook,
          termName: selectedTerm?.name,
          zoneLabel: (selectedTerm?.timeZoneId ?? '').trim().isEmpty
              ? 'LOCAL TIME'
              : 'CAMPUS TIME',
          loading: _academicLoading,
          actions: _plansActions,
          completionsOn: (day) => widget.state.history[Days.key(day)] ?? 0,
          reflectionsOn: _reflectionsOn,
          journalOn: _journalOn,
          classStatus: _classStatus(now),
          parallax: widget.parallax,
          reduceMotion: widget.state.reduceMotion,
        );
      },
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

  /// The one way classes come in: the Plans doorway, the ADD menu, and every
  /// .ics opened from Mail, Files or Safari. Room of Days files still apply
  /// through the original importer inside the sheet's review.
  Future<void> _showAddClasses({
    AcademicScheduleImportSource? initialSource,
  }) async {
    if (_academicImportOpen || !mounted) return;
    _academicImportOpen = true;
    AddClassesResult? result;
    try {
      // The sheet shows (and builds on) the saved schedule, never the empty
      // one Plans holds while it is still opening.
      try {
        await _academicLoad;
      } catch (_) {
        return;
      }
      if (!mounted) return;
      result = await showAddClassesSheet(
        context,
        schedule: _academicSchedule,
        filePicker: _academicScheduleFilePicker,
        timeZoneIdProvider: widget.timeZoneIdProvider,
        initialSource: initialSource,
        requestReminderPermission: widget.requestReminderPermission,
        linkFetcher: widget.calendarLinkFetcher,
        deviceCalendar: widget.deviceCalendarReader,
        onSave: _saveAddedClasses,
        onShareStarter: () => shareCalendarFile(
          buildRoomOfDaysAcademicScheduleTemplate(),
          'room-of-days-class-schedule-starter.ics',
        ),
      );
    } finally {
      _academicImportOpen = false;
    }
    if (result != null && mounted) _showWeekOf(result.focusDate);
    _onIncomingAcademicScheduleFile();
  }

  Future<void> _showAddDaybook(BuildContext context) async {
    Sfx.instance.playMaterial(MaterialSound.glass);
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
        await _showAddClasses();
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
    Sfx.instance.playInteraction(
      InteractionSound.select,
      material: MaterialSound.stone,
    );
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
    Sfx.instance.playInteraction(
      InteractionSound.place,
      material: MaterialSound.glass,
    );
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
                'START WITH A DAY SHAPE, OR NAME YOUR OWN',
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
                child: HoneyButton(
                  label: 'PLAN IT',
                  soundEnabled: false,
                  onTap: _add,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
