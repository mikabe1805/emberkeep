// "Add your classes": one calm way in for any student. A calendar file, a
// calendar link, or typing them in, then a review that lets the student pick
// which repeating events are classes, then a result that names the week and
// offers class reminders. Room of Days .ics files still apply through the
// original importer (AcademicScheduleIcsImporter) inside the same review.
import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../audio.dart';
import '../../clock.dart';
import '../../daybook/services/device_time_zone.dart';
import '../../haptics.dart';
import '../../tokens.dart';
import '../../widgets/facets.dart';
import '../../widgets/glass.dart';
import '../../widgets/glass_switch.dart';
import '../../widgets/honey_button.dart';
import '../domain/academic_schedule.dart';
import '../import/academic_schedule_file_picker.dart';
import '../import/academic_schedule_ics_import.dart';
import '../import/calendar_class_finder.dart';
import '../import/calendar_link.dart';
import '../import/class_import_reminders.dart';
import '../import/device_calendar_reader.dart';
import '../import/quick_class_entry.dart';

/// Saves a finished schedule. Returns false when the local save did not work.
typedef AddClassesSave =
    Future<bool> Function(AcademicSchedule next, AcademicTerm term);

/// Where the sheet opens.
enum AddClassesStart { ways, link, quick }

/// What the student chose at the end: the day Plans should show the week of.
final class AddClassesResult {
  const AddClassesResult({required this.focusDate});
  final CivilDate focusDate;
}

Future<AddClassesResult?> showAddClassesSheet(
  BuildContext context, {
  required AcademicSchedule schedule,
  required AddClassesSave onSave,
  required AcademicScheduleFilePicker filePicker,
  TimeZoneIdProvider? timeZoneIdProvider,
  AcademicScheduleImportSource? initialSource,
  AddClassesStart start = AddClassesStart.ways,
  Future<bool> Function()? onShareStarter,
  Future<bool> Function()? requestReminderPermission,
  CalendarLinkFetcher? linkFetcher,
  DeviceCalendarReader? deviceCalendar,
}) {
  return showDialog<AddClassesResult>(
    context: context,
    barrierColor: Palette.dialogBarrier,
    builder: (_) => AddClassesSheet(
      schedule: schedule,
      onSave: onSave,
      filePicker: filePicker,
      timeZoneIdProvider: timeZoneIdProvider,
      initialSource: initialSource,
      start: start,
      onShareStarter: onShareStarter,
      requestReminderPermission: requestReminderPermission,
      linkFetcher: linkFetcher,
      deviceCalendar: deviceCalendar,
    ),
  );
}

enum _Stage { reading, ways, link, review, quick, done }

class AddClassesSheet extends StatefulWidget {
  const AddClassesSheet({
    super.key,
    required this.schedule,
    required this.onSave,
    required this.filePicker,
    this.timeZoneIdProvider,
    this.initialSource,
    this.start = AddClassesStart.ways,
    this.onShareStarter,
    this.requestReminderPermission,
    this.linkFetcher,
    this.deviceCalendar,
  });

  final AcademicSchedule schedule;
  final AddClassesSave onSave;
  final AcademicScheduleFilePicker filePicker;

  /// The phone's time zone, for calendars that give times without one and
  /// for a first typed class. Resolved only when needed.
  final TimeZoneIdProvider? timeZoneIdProvider;
  final AcademicScheduleImportSource? initialSource;
  final AddClassesStart start;

  /// Shares the editable Room of Days .ics starter. Returns false when the
  /// device could not share it.
  final Future<bool> Function()? onShareStarter;

  /// Asked only when the student turns class reminders on.
  final Future<bool> Function()? requestReminderPermission;
  final CalendarLinkFetcher? linkFetcher;

  /// The phone's own calendars (EventKit). Null until that slice ships, and
  /// then the way in appears on its own.
  final DeviceCalendarReader? deviceCalendar;

  @override
  State<AddClassesSheet> createState() => _AddClassesSheetState();
}

class _AddClassesSheetState extends State<AddClassesSheet> {
  final _scroll = ScrollController();
  final _link = TextEditingController();
  final _quickName = TextEditingController();
  final _quickPlace = TextEditingController();

  late AcademicSchedule _schedule = widget.schedule;
  _Stage _stage = _Stage.ways;
  CalendarClassImportDraft? _draft;
  AcademicScheduleImportDraft? _roomOfDays;
  String? _sourceName;
  String? _error;
  bool _busy = false;
  bool _showHelp = false;
  bool _showOthers = false;
  bool _starterShared = false;
  bool _fromLink = false;
  Future<String>? _zoneLookup;

  // Typing classes in.
  final Set<int> _quickDays = {};
  int _quickStart = 10 * 60;
  int _quickLength = 80;
  final List<String> _added = [];

  // The result.
  int _addedCourses = 0;
  AcademicTerm? _resultTerm;
  final Set<String> _written = {};
  int? _reminderOffset;
  String? _reminderNote;
  bool _askingPermission = false;

  CivilDate get _today => CivilDate.fromDateTime(Clock.now());

  @override
  void initState() {
    super.initState();
    _stage = switch (widget.start) {
      AddClassesStart.ways => _Stage.ways,
      AddClassesStart.link => _Stage.link,
      AddClassesStart.quick => _Stage.quick,
    };
    if (widget.initialSource case final source?) {
      _stage = _Stage.reading;
      _sourceName = source.name;
      unawaited(_readText(source.contents, source.name, quiet: true));
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    _link.dispose();
    _quickName.dispose();
    _quickPlace.dispose();
    super.dispose();
  }

  Future<String> _zone() => _zoneLookup ??= resolveDeviceTimeZoneId(
    discover: widget.timeZoneIdProvider,
  );

  void _toTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(0);
    });
  }

  void _go(_Stage stage) {
    Sfx.instance.playMaterial(MaterialSound.glass);
    setState(() {
      _stage = stage;
      _error = null;
      if (stage == _Stage.ways) {
        _draft = null;
        _roomOfDays = null;
      }
    });
    _toTop();
  }

  /// Every way in ends here: a file, a link, or the phone's calendar.
  Future<void> _readText(String text, String name, {bool quiet = false}) async {
    // A Room of Days file names its own zone; anything else may need the
    // phone's zone for times written without one.
    final zone = text.contains('X-ROOM-OF-DAYS-')
        ? neutralTimeZoneId
        : await _zone();
    if (!mounted) return;
    try {
      final read = ClassScheduleReader.read(
        text,
        sourceName: name,
        fallbackTimeZoneId: zone,
        today: _today,
      );
      final draft = switch (read) {
        CalendarClassesRead(:final draft) => draft,
        RoomOfDaysScheduleRead() => CalendarClassFinder.find(
          text,
          sourceName: name,
          fallbackTimeZoneId: zone,
          today: _today,
        ),
      };
      setState(() {
        _draft = draft;
        _roomOfDays = read is RoomOfDaysScheduleRead ? read.draft : null;
        _sourceName = name;
        _stage = _Stage.review;
        _showOthers = !draft.foundLikelyClasses && draft.hasCandidates;
        _error = null;
        _busy = false;
      });
      if (!quiet) {
        Sfx.instance.playInteraction(
          InteractionSound.open,
          material: MaterialSound.parchment,
        );
      }
    } on FormatException {
      setState(() {
        _busy = false;
        _stage = _Stage.ways;
        _error =
            'That file isn’t a calendar Room of Days can read. Choose an .ics file, or type your classes in.';
      });
    }
    _toTop();
  }

  Future<void> _readSource(
    Future<AcademicScheduleImportSource?> Function() open, {
    required String failure,
  }) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final source = await open();
      if (!mounted) return;
      if (source == null) {
        setState(() => _busy = false);
        return;
      }
      _fromLink = false;
      await _readText(source.contents, source.name);
    } on FormatException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = failure;
      });
    }
  }

  Future<void> _chooseFile() => _readSource(
    widget.filePicker.pick,
    failure: 'Couldn’t open that file. Try another .ics file.',
  );

  Future<void> _readDeviceCalendar() => _readSource(
    widget.deviceCalendar!.read,
    failure: 'Couldn’t read this phone’s calendar just now. Try again.',
  );

  Future<void> _readLink() async {
    if (_busy) return;
    late final CalendarLink link;
    try {
      link = CalendarLink.parse(_link.text);
    } on FormatException catch (error) {
      setState(() => _error = error.message);
      return;
    }
    final fetcher =
        widget.linkFetcher ??
        debugCalendarLinkFetcherOverride ??
        const PlatformCalendarLinkFetcher();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final text = await fetcher.fetch(link);
      if (!mounted) return;
      // The link is read once and not kept, not even in the field.
      _link.clear();
      _fromLink = true;
      await _readText(text, link.displayName);
    } on FormatException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'The calendar didn’t answer just now. Try again in a moment.';
      });
    }
  }

  Future<void> _pasteLink() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (!mounted || text == null || text.isEmpty) return;
    setState(() {
      _link.text = text;
      _error = null;
    });
  }

  Future<void> _shareStarter() async {
    final share = widget.onShareStarter;
    if (share == null) return;
    final shared = await share();
    if (!mounted) return;
    setState(() {
      _starterShared = shared;
      _error = shared
          ? null
          : 'Couldn’t share the starter file on this phone just now.';
    });
  }

  void _finish(AcademicSchedule before, AcademicSchedule next) {
    _schedule = next;
    _written.addAll(meetingSeriesWrittenBetween(before, next));
    _reminderOffset = classReminderOffsetOf(next, _written);
  }

  Future<void> _import() async {
    final draft = _draft;
    if (draft == null || _busy) return;
    if (_roomOfDays == null && draft.selected.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final updatedAt = Clock.now().toUtc();
    late final AcademicSchedule next;
    late final AcademicTerm term;
    try {
      if (_roomOfDays case final legacy?) {
        next = legacy.applyTo(_schedule, updatedAt: updatedAt);
        term = legacy.term;
      } else {
        next = draft.applyTo(_schedule, updatedAt: updatedAt);
        term = draft.term;
      }
    } on ArgumentError {
      setState(() {
        _busy = false;
        _error = 'Some of these dates don’t fit together. Try a shorter term.';
      });
      return;
    }
    final saved = await widget.onSave(next, term);
    if (!mounted) return;
    if (!saved) {
      setState(() {
        _busy = false;
        _error = 'Couldn’t save on this phone just now. Try again.';
      });
      return;
    }
    Sfx.instance.playInteraction(
      InteractionSound.place,
      material: MaterialSound.brass,
    );
    Haptics.success();
    setState(() {
      _finish(_schedule, next);
      _busy = false;
      _addedCourses =
          _roomOfDays?.courses.length ?? draft.selectedCourses.length;
      _resultTerm = term;
      _stage = _Stage.done;
    });
    _toTop();
  }

  Future<void> _addQuick() async {
    if (_busy) return;
    final entry = QuickClassEntry(
      name: _quickName.text,
      weekdays: _quickDays,
      startMinute: _quickStart,
      lengthMinutes: _quickLength,
      place: _quickPlace.text,
    );
    if (entry.problem case final problem?) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final zone = await _zone();
    if (!mounted) return;
    final term = QuickClassPlanner.termFor(_schedule, _today, timeZoneId: zone);
    final next = QuickClassPlanner.add(
      _schedule,
      entry,
      term: term,
      today: _today,
      updatedAt: Clock.now().toUtc(),
      colorIndex: _schedule.courses.length,
    );
    final saved = await widget.onSave(next, term);
    if (!mounted) return;
    if (!saved) {
      setState(() {
        _busy = false;
        _error = 'Couldn’t save on this phone just now. Try again.';
      });
      return;
    }
    Sfx.instance.playInteraction(
      InteractionSound.place,
      material: MaterialSound.glass,
    );
    Haptics.light();
    final reading = entry.reading;
    setState(() {
      _finish(_schedule, next);
      _busy = false;
      _resultTerm = term;
      _added.add(
        '${reading.codeFound ? '${reading.code} · ' : ''}${reading.title}'
        '\n${_daysLabel(entry.weekdays)} · ${_clock(entry.startMinute)}',
      );
      _quickName.clear();
      _quickPlace.clear();
      _quickDays.clear();
    });
  }

  /// The result's reminder switch. Turning it on is the only place this
  /// sheet asks for notification permission.
  Future<bool> _setReminders(bool on) async {
    if (_busy || _askingPermission) return false;
    if (on && widget.requestReminderPermission != null) {
      setState(() {
        _askingPermission = true;
        _error = null;
      });
      final granted = await widget.requestReminderPermission!();
      if (!mounted) return false;
      setState(() => _askingPermission = false);
      if (!granted) {
        setState(() {
          _reminderNote =
              'Notifications are off for Room of Days, so reminders are too. You can allow them in Settings whenever you like.';
        });
        return false;
      }
    }
    _reminderNote = null;
    return _writeReminders(on ? (_reminderOffset ?? 10) : null);
  }

  Future<bool> _writeReminders(int? offset) async {
    final term = _resultTerm;
    if (term == null || _written.isEmpty) return false;
    setState(() {
      _busy = true;
      _error = null;
    });
    final next = withClassReminders(
      _schedule,
      _written,
      offsetMinutes: offset,
      updatedAt: Clock.now().toUtc(),
    );
    final saved = await widget.onSave(next, term);
    if (!mounted) return false;
    setState(() {
      _busy = false;
      if (saved) {
        _schedule = next;
        _reminderOffset = offset;
      } else {
        _error = 'Couldn’t save on this phone just now. Try again.';
      }
    });
    return saved;
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final maxHeight =
        media.size.height -
        media.padding.vertical -
        media.viewInsets.vertical -
        24;
    final canGoBack =
        !_busy &&
        (_stage == _Stage.link ||
            _stage == _Stage.review ||
            (_stage == _Stage.quick && _added.isEmpty));
    return Dialog(
      key: const ValueKey('add-classes-sheet'),
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 520, maxHeight: maxHeight),
        child: GlassPanel(
          tint: Palette.dialogSurface,
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SheetBar(
                label: 'ADD YOUR CLASSES',
                onBack: canGoBack ? () => _go(_Stage.ways) : null,
                onClose: _busy ? null : () => Navigator.of(context).pop(),
              ),
              Flexible(
                child: ShaderMask(
                  blendMode: BlendMode.dstIn,
                  shaderCallback: _edgeFade,
                  child: SingleChildScrollView(
                    controller: _scroll,
                    padding: const EdgeInsets.only(
                      top: _fadeTop,
                      bottom: _fadeBottom,
                    ),
                    child: AnimatedSwitcher(
                      duration: Motion.quick,
                      switchInCurve: Curves.easeOutCubic,
                      child: KeyedSubtree(
                        key: ValueKey(_stage),
                        child: switch (_stage) {
                          _Stage.reading => _readingBody(),
                          _Stage.ways => _waysBody(),
                          _Stage.link => _linkBody(),
                          _Stage.review => _reviewBody(),
                          _Stage.quick => _quickBody(),
                          _Stage.done => _doneBody(),
                        },
                      ),
                    ),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 2),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    key: const ValueKey('add-classes-error'),
                    style: Type.body.copyWith(
                      fontSize: 13,
                      height: 1.35,
                      color: Palette.streak,
                    ),
                  ),
                ),
              ],
              ..._footer(),
            ],
          ),
        ),
      ),
    );
  }

  static const _fadeTop = 8.0;
  static const _fadeBottom = 12.0;

  /// Content scrolling under the sheet's bar or toward its button fades out
  /// over the scroll padding instead of stopping at a hard edge.
  static Shader _edgeFade(Rect rect) {
    if (rect.height <= (_fadeTop + _fadeBottom) * 2) {
      return const LinearGradient(
        colors: [Color(0xFF000000), Color(0xFF000000)],
      ).createShader(rect);
    }
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: const [
        Color(0x00000000),
        Color(0xFF000000),
        Color(0xFF000000),
        Color(0x00000000),
      ],
      stops: [0, _fadeTop / rect.height, 1 - _fadeBottom / rect.height, 1],
    ).createShader(rect);
  }

  // ── Opening a file from outside ──────────────────────────────────────────

  Widget _readingBody() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'FROM ${(_sourceName ?? 'calendar.ics').toUpperCase()}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Type.label.copyWith(letterSpacing: 0.8),
        ),
        const SizedBox(height: 6),
        Text(
          'Reading your calendar…',
          style: Type.display.copyWith(fontSize: 24, height: 1.12),
        ),
      ],
    ),
  );

  // ── Ways in ──────────────────────────────────────────────────────────────

  Widget _waysBody() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 4),
      Text(
        'Where are your classes now?',
        style: Type.display.copyWith(fontSize: 27, height: 1.12),
      ),
      const SizedBox(height: 6),
      Text(
        'Pick the closest. Each class then shows up on its day in Plans.',
        style: Type.body.copyWith(fontSize: 14, height: 1.4),
      ),
      const SizedBox(height: 16),
      if (widget.deviceCalendar != null) ...[
        _WayRow(
          key: const ValueKey('add-classes-device'),
          icon: Icons.phone_iphone_rounded,
          title: 'FROM THIS IPHONE’S CALENDAR',
          body: 'Classes already in your phone’s calendar, read on this phone.',
          busy: _busy,
          onTap: _readDeviceCalendar,
        ),
        const SizedBox(height: 8),
      ],
      _WayRow(
        key: const ValueKey('add-classes-file'),
        icon: Icons.upload_file_outlined,
        title: 'FROM A CALENDAR FILE',
        body: 'An .ics from your school portal, Google Calendar or Outlook.',
        busy: _busy,
        onTap: _chooseFile,
      ),
      if (!kIsWeb) ...[
        const SizedBox(height: 8),
        _WayRow(
          key: const ValueKey('add-classes-link'),
          icon: Icons.link_rounded,
          title: 'FROM A CALENDAR LINK',
          body: 'Paste a private calendar address. Room of Days reads it once.',
          onTap: () => _go(_Stage.link),
        ),
      ],
      const SizedBox(height: 8),
      _WayRow(
        key: const ValueKey('add-classes-type'),
        icon: Icons.keyboard_outlined,
        title: 'TYPE THEM IN',
        body: 'A name, the days and a time. About a minute for a whole week.',
        onTap: () => _go(_Stage.quick),
      ),
      const SizedBox(height: 14),
      _Disclosure(
        key: const ValueKey('add-classes-help'),
        label: 'WHERE DO I FIND MINE?',
        open: _showHelp,
        onTap: () => setState(() => _showHelp = !_showHelp),
      ),
      if (_showHelp) ...[
        const SizedBox(height: 4),
        const _HelpLine(
          title: 'School portal',
          body:
              'On your class schedule page, look for Export, Download or Add to calendar. Open the file in Room of Days.',
        ),
        const _HelpLine(
          title: 'Google Calendar',
          body:
              'On a computer: Settings, pick your calendar, Integrate calendar, then copy Secret address in iCal format.',
        ),
        const _HelpLine(
          title: 'Outlook',
          body:
              'Settings, Shared calendars, Publish a calendar. Choose titles and locations, then copy the ICS link.',
        ),
        const _HelpLine(
          title: 'Canvas',
          body:
              'Its calendar feed holds due dates only, so type your classes in instead.',
        ),
        if (widget.onShareStarter != null) ...[
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: _QuietLink(
              key: const ValueKey('add-classes-starter'),
              label: 'GET THE ROOM OF DAYS .ICS STARTER',
              onTap: () => unawaited(_shareStarter()),
            ),
          ),
          if (_starterShared)
            Text(
              'Starter file ready. Edit it, save it as .ics, then open it in Room of Days.',
              key: const ValueKey('add-classes-starter-ready'),
              textAlign: TextAlign.center,
              style: Type.body.copyWith(
                fontSize: 12.5,
                height: 1.4,
                color: Palette.textLo,
              ),
            ),
        ],
      ],
    ],
  );

  // ── Link ─────────────────────────────────────────────────────────────────

  Widget _linkBody() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 4),
      Text(
        'Paste your calendar link',
        style: Type.display.copyWith(fontSize: 25, height: 1.12),
      ),
      const SizedBox(height: 6),
      Text(
        'Google calls it the secret address in iCal format. Outlook calls it the ICS link.',
        style: Type.body.copyWith(fontSize: 14, height: 1.4),
      ),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
        decoration: facetedDecoration(
          cut: 9,
          color: Palette.cardGlass,
          borderColor: Palette.brass.withValues(alpha: 0.5),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('add-classes-link-field'),
                controller: _link,
                keyboardType: TextInputType.url,
                autocorrect: false,
                enableSuggestions: false,
                // Keyboards must not learn a private calendar address.
                enableIMEPersonalizedLearning: false,
                maxLines: 3,
                minLines: 1,
                onChanged: (_) => setState(() => _error = null),
                onSubmitted: (_) => _readLink(),
                style: Type.body.copyWith(
                  fontSize: 13.5,
                  height: 1.35,
                  color: Palette.textHi,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: 'https:// or webcal://',
                  hintStyle: Type.body.copyWith(
                    fontSize: 13.5,
                    color: Palette.textQuiet,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            _SmallBrass(
              key: const ValueKey('add-classes-paste'),
              label: 'PASTE',
              icon: Icons.content_paste_rounded,
              onTap: _pasteLink,
            ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Icons.lock_outline, size: 15, color: Palette.textLo),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              'This phone reads it once, straight from your calendar, and doesn’t keep the link. Only the classes you pick are saved.',
              key: const ValueKey('add-classes-link-privacy'),
              style: Type.body.copyWith(
                fontSize: 12.5,
                height: 1.4,
                color: Palette.textLo,
              ),
            ),
          ),
        ],
      ),
    ],
  );

  // ── Review ───────────────────────────────────────────────────────────────

  Widget _reviewBody() {
    final draft = _draft!;
    final legacy = _roomOfDays;
    if (!draft.hasCandidates) return _nothingFound(draft);
    final courses = draft.courses;
    final likely = [
      for (final course in courses)
        if (course.looksLikeClass || legacy != null) course,
    ];
    final others = [
      for (final course in courses)
        if (!course.looksLikeClass && legacy == null) course,
    ];
    final term = legacy?.term ?? draft.term;
    void toggle(ClassReviewCourse course) => setState(() {
      final on = !course.candidates.every(
        (item) => draft.selectedKeys.contains(item.key),
      );
      _draft = draft.withCourseSelected(course, on);
      Sfx.instance.playInteraction(
        InteractionSound.select,
        material: MaterialSound.glass,
      );
      Haptics.tap();
    });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 2),
        Text(
          'FROM ${(_sourceName ?? 'calendar.ics').toUpperCase()}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Type.label.copyWith(letterSpacing: 0.8),
        ),
        const SizedBox(height: 6),
        Text(
          legacy != null ? 'Your Room of Days file' : 'Pick your classes',
          style: Type.display.copyWith(fontSize: 26, height: 1.12),
        ),
        const SizedBox(height: 6),
        Text(
          legacy != null
              ? 'Made in the Room of Days format, so every class comes in as written.'
              : draft.titlesHidden && !draft.foundLikelyClasses
              ? 'Check the ones that are your classes.'
              : draft.foundLikelyClasses
              ? 'The ones that look like classes are checked. Tap any of them to change it.'
              : 'Nothing here looked like a class at first glance. Check the ones that are.',
          style: Type.body.copyWith(fontSize: 14, height: 1.4),
        ),
        if (draft.titlesHidden) ...[
          const SizedBox(height: 10),
          const _Note(
            key: ValueKey('add-classes-busy-only'),
            icon: Icons.visibility_off_outlined,
            text:
                'This calendar shows only busy times, so there are no class names. In Outlook, publish it with titles and locations, then paste the new link.',
          ),
        ],
        const SizedBox(height: 12),
        _TermRow(
          term: term,
          openEnded: legacy == null && draft.usesSeasonEnd,
          onChangeEnd: legacy == null ? _pickTermEnd : null,
          meetings:
              legacy?.projectedOccurrenceCount ??
              draft.projectedOccurrenceCount,
        ),
        if (legacy == null)
          for (final other in draft.otherTerms)
            _OtherTermLine(
              key: ValueKey('add-classes-term-${other.index}'),
              choice: other,
              onTap: () {
                Sfx.instance.playInteraction(
                  InteractionSound.navigate,
                  material: MaterialSound.parchment,
                );
                setState(() {
                  _draft = draft.withActiveTerm(other.index);
                  _showOthers = !_draft!.foundLikelyClasses;
                });
                _toTop();
              },
            ),
        const SizedBox(height: 10),
        for (final course in likely) ...[
          _CourseRow(
            key: ValueKey('add-classes-course-${course.key}'),
            course: course,
            selected:
                legacy != null ||
                course.candidates.every(
                  (item) => draft.selectedKeys.contains(item.key),
                ),
            enabled: legacy == null,
            onTap: () => toggle(course),
          ),
          const SizedBox(height: 7),
        ],
        if (others.isNotEmpty) ...[
          const SizedBox(height: 6),
          _Disclosure(
            key: const ValueKey('add-classes-others'),
            label: draft.foundLikelyClasses
                ? 'PROBABLY NOT CLASSES · ${others.length}'
                : 'REPEATING EVENTS · ${others.length}',
            open: _showOthers,
            onTap: () => setState(() => _showOthers = !_showOthers),
          ),
          if (_showOthers)
            for (final course in others) ...[
              const SizedBox(height: 7),
              _CourseRow(
                key: ValueKey('add-classes-course-${course.key}'),
                course: course,
                selected: course.candidates.every(
                  (item) => draft.selectedKeys.contains(item.key),
                ),
                enabled: true,
                quiet: true,
                onTap: () => toggle(course),
              ),
            ],
        ],
        if (_leftOutLine(draft) case final line?) ...[
          const SizedBox(height: 12),
          Text(
            line,
            style: Type.body.copyWith(
              fontSize: 12.5,
              height: 1.35,
              color: Palette.textLo,
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _pickTermEnd() async {
    final draft = _draft;
    if (draft == null) return;
    final term = draft.term;
    final picked = await showDatePicker(
      context: context,
      initialDate: term.endDate.dateArithmeticValue,
      firstDate: term.startDate.dateArithmeticValue,
      lastDate: term.startDate.addDays(366).dateArithmeticValue,
      helpText: 'LAST DAY OF CLASSES',
    );
    if (!mounted || picked == null) return;
    setState(() => _draft = draft.withTermEnd(CivilDate.fromDateTime(picked)));
  }

  Widget _nothingFound(CalendarClassImportDraft draft) {
    final bits = <String>[
      if (draft.deadlineCount > 0) _count(draft.deadlineCount, 'due date'),
      if (draft.oneTimeCount > 0) _count(draft.oneTimeCount, 'one-time event'),
      if (draft.allDayCount > 0) _count(draft.allDayCount, 'all-day event'),
    ];
    final canvas =
        (draft.calendarName ?? '').toLowerCase().contains('canvas') ||
        draft.deadlineCount > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 2),
        Text(
          'FROM ${(_sourceName ?? 'calendar.ics').toUpperCase()}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Type.label.copyWith(letterSpacing: 0.8),
        ),
        const SizedBox(height: 6),
        Text(
          'No weekly classes here',
          style: Type.display.copyWith(fontSize: 26, height: 1.12),
        ),
        const SizedBox(height: 8),
        Text(
          [
            if (bits.isNotEmpty) 'It holds ${_joinAnd(bits)}.',
            canvas
                ? 'Canvas feeds carry assignments and due dates. Class meeting times live in your school portal.'
                : 'Class times are usually in your school portal’s schedule export.',
          ].join(' '),
          style: Type.body.copyWith(fontSize: 14, height: 1.45),
        ),
        const SizedBox(height: 12),
        const _Note(
          icon: Icons.schedule_rounded,
          text:
              'Typing them in takes about a minute: a name, the days and a start time.',
        ),
      ],
    );
  }

  String? _leftOutLine(CalendarClassImportDraft draft) {
    final bits = <String>[
      if (draft.oneTimeCount > 0) _count(draft.oneTimeCount, 'one-time event'),
      if (draft.allDayCount > 0) _count(draft.allDayCount, 'all-day event'),
      if (draft.deadlineCount > 0) _count(draft.deadlineCount, 'due date'),
      if (draft.otherRepeatingCount > 0)
        draft.otherRepeatingCount == 1
            ? '1 event that repeats in another way'
            : '${draft.otherRepeatingCount} events that repeat in other ways',
    ];
    if (bits.isEmpty) return null;
    return 'Also in this calendar and left as they are: ${_joinAnd(bits)}.';
  }

  // ── Typing them in ───────────────────────────────────────────────────────

  Widget _quickBody() {
    final existing = _schedule.termFor(_today);
    final season = seasonAround(_today);
    final termLine = existing != null
        ? '${existing.name} · through ${_monthDay(existing.endDate)}'
        : '${season.name} ${_today.year} · from this week through ${_monthDay(season.end)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_added.isNotEmpty) ...[
          Text(
            'ADDED · ${_added.length}',
            style: Type.label.copyWith(color: Palette.success),
          ),
          const SizedBox(height: 6),
          for (final line in _added) ...[
            _AddedRow(text: line),
            const SizedBox(height: 6),
          ],
          const SizedBox(height: 8),
        ] else ...[
          const SizedBox(height: 4),
          Text(
            'One class at a time',
            style: Type.display.copyWith(fontSize: 25, height: 1.12),
          ),
          const SizedBox(height: 6),
          Text(
            'Write it the way you say it. “CS 206 Discrete Structures” or just “Bio lab”.',
            style: Type.body.copyWith(fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 14),
        ],
        const _FieldLabel('CLASS'),
        const SizedBox(height: 6),
        _GlassField(
          fieldKey: const ValueKey('add-classes-quick-name'),
          controller: _quickName,
          hint: 'e.g. CS 206 Discrete Structures',
          onChanged: () => setState(() => _error = null),
        ),
        const SizedBox(height: 12),
        const _FieldLabel('DAYS'),
        const SizedBox(height: 6),
        Row(
          children: [
            for (var day = 1; day <= 7; day++)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: day == 7 ? 0 : 5),
                  child: _DayChip(
                    key: ValueKey('add-classes-day-$day'),
                    label: const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][day - 1],
                    semantic: _dayNames[day - 1],
                    selected: _quickDays.contains(day),
                    onTap: () => setState(() {
                      _quickDays.contains(day)
                          ? _quickDays.remove(day)
                          : _quickDays.add(day);
                      _error = null;
                      Haptics.tap();
                    }),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _FieldLabel('STARTS'),
                  const SizedBox(height: 6),
                  _TimeTile(
                    key: const ValueKey('add-classes-quick-start'),
                    label: _clock(_quickStart),
                    onTap: _pickStart,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Padding(
              padding: const EdgeInsets.only(bottom: 13),
              child: Text(
                'ENDS ${_clock(_quickStart + _quickLength)}',
                style: Type.label.copyWith(color: Palette.textMid),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const _FieldLabel('LENGTH IN MINUTES'),
        const SizedBox(height: 6),
        Row(
          children: [
            for (final minutes in quickClassLengths)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: minutes == quickClassLengths.last ? 0 : 6,
                  ),
                  child: _DayChip(
                    key: ValueKey('add-classes-length-$minutes'),
                    label: '$minutes',
                    semantic: '$minutes minutes',
                    selected: _quickLength == minutes,
                    onTap: () => setState(() {
                      _quickLength = minutes;
                      Haptics.tap();
                    }),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        const _FieldLabel('WHERE · OPTIONAL'),
        const SizedBox(height: 6),
        _GlassField(
          fieldKey: const ValueKey('add-classes-quick-place'),
          controller: _quickPlace,
          hint: 'Building and room',
          onChanged: () {},
        ),
        const SizedBox(height: 12),
        Text(
          termLine,
          style: Type.body.copyWith(fontSize: 12.5, color: Palette.textLo),
        ),
      ],
    );
  }

  Future<void> _pickStart() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _quickStart ~/ 60, minute: _quickStart % 60),
      helpText: 'CLASS STARTS',
    );
    if (!mounted || picked == null) return;
    setState(() => _quickStart = picked.hour * 60 + picked.minute);
  }

  // ── Done ─────────────────────────────────────────────────────────────────

  ClassOccurrence? _nextClass() {
    final now = Clock.now().toUtc();
    final upcoming = [
      for (final item in _schedule.occurrences)
        if (item.state != OccurrenceState.cancelled &&
            item.tombstonedAt == null &&
            item.endInstant.isAfter(now) &&
            !(_schedule.courseById(item.courseId)?.archived ?? true))
          item,
    ]..sort((a, b) => a.startInstant.compareTo(b.startInstant));
    return upcoming.firstOrNull;
  }

  /// The week the result shows (and SEE MY WEEK opens): the week of the next
  /// class, so a term that starts later still shows real classes.
  CivilDate _focusDate() => _nextClass()?.date ?? _today;

  Widget _doneBody() {
    final term = _resultTerm;
    final next = _nextClass();
    final course = next == null ? null : _schedule.courseById(next.courseId);
    final focus = next?.date ?? _today;
    final weekStart = focus.startOfWeek(DateTime.monday);
    final thisWeek = _today.startOfWeek(DateTime.monday);
    final weekLabel = weekStart == thisWeek
        ? 'THIS WEEK'
        : weekStart == thisWeek.addDays(7)
        ? 'NEXT WEEK'
        : 'WEEK OF ${_monthDay(weekStart).toUpperCase()}';
    final days = [for (var i = 0; i < 7; i++) weekStart.addDays(i)];
    final counts = [
      for (final day in days)
        _schedule
            .occurrencesOn(day)
            .where(
              (item) =>
                  item.state != OccurrenceState.cancelled &&
                  item.tombstonedAt == null &&
                  !(_schedule.courseById(item.courseId)?.archived ?? true),
            )
            .length,
    ];
    final showWeekend = counts[5] > 0 || counts[6] > 0;
    final courses = _added.isNotEmpty ? null : _addedCourses;
    final startsNow =
        next != null && !next.startInstant.isAfter(Clock.now().toUtc());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 6),
        Text(
          courses != null
              ? '${_count(courses, 'course')} in Plans'
              : '${_count(_added.length, 'class', plural: 'classes')} in Plans',
          style: Type.display.copyWith(fontSize: 28, height: 1.1),
        ),
        const SizedBox(height: 8),
        if (term != null)
          Text(
            next != null && course != null
                ? startsNow
                      ? '${term.name}, through ${_monthDay(term.endDate)}. ${course.title} is on right now.'
                      : '${term.name}, through ${_monthDay(term.endDate)}. Your next class is ${course.title}, ${_weekdayLong(next.date, _today)} at ${_clock(next.localStartMinute)}.'
                : '${term.name}, through ${_monthDay(term.endDate)}.',
            key: const ValueKey('add-classes-result-line'),
            style: Type.body.copyWith(fontSize: 14.5, height: 1.45),
          ),
        const SizedBox(height: 16),
        Container(
          key: const ValueKey('add-classes-week'),
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
          decoration: facetedDecoration(
            cut: 10,
            color: Palette.cardGlass,
            borderColor: Palette.brass.withValues(alpha: 0.44),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 10),
                child: Text(
                  weekLabel,
                  style: Type.label.copyWith(color: Palette.xpLight),
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < (showWeekend ? 7 : 5); i++)
                    Expanded(
                      child: _WeekDay(
                        label: _dayShort[i],
                        count: counts[i],
                        today: days[i] == _today,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        if (_written.isNotEmpty) ...[
          const SizedBox(height: 10),
          _ReminderChoice(
            offset: _reminderOffset,
            note: _reminderNote,
            enabled: !_busy && !_askingPermission,
            onChanged: _setReminders,
            onOffsetChanged: (minutes) => unawaited(_writeReminders(minutes)),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          'To move or cancel a single class, open its day in Plans.',
          style: Type.body.copyWith(
            fontSize: 12.5,
            height: 1.4,
            color: Palette.textLo,
          ),
        ),
      ],
    );
  }

  // ── Footer ───────────────────────────────────────────────────────────────

  List<Widget> _footer() {
    Widget primary(
      String label,
      IconData icon,
      VoidCallback onTap, {
      bool enabled = true,
      Key? key,
    }) => HoneyButton(
      key: key,
      label: label,
      icon: icon,
      enabled: enabled && !_busy,
      expand: true,
      onTap: onTap,
    );
    switch (_stage) {
      case _Stage.reading || _Stage.ways:
        return const [];
      case _Stage.link:
        return [
          const SizedBox(height: 4),
          primary(
            _busy ? 'READING…' : 'READ THIS CALENDAR',
            Icons.event_available_outlined,
            _readLink,
            enabled: _link.text.trim().isNotEmpty,
            key: const ValueKey('add-classes-read-link'),
          ),
        ];
      case _Stage.review:
        final draft = _draft!;
        if (!draft.hasCandidates) {
          return [
            const SizedBox(height: 4),
            primary(
              'TYPE THEM IN',
              Icons.keyboard_outlined,
              () => _go(_Stage.quick),
              key: const ValueKey('add-classes-type-instead'),
            ),
            const SizedBox(height: 4),
            _QuietLink(
              key: const ValueKey('add-classes-try-another'),
              label: 'TRY ANOTHER CALENDAR',
              onTap: () => _go(_Stage.ways),
            ),
          ];
        }
        final count =
            _roomOfDays?.courses.length ?? draft.selectedCourses.length;
        return [
          const SizedBox(height: 4),
          primary(
            _busy
                ? 'ADDING…'
                : count == 0
                ? 'PICK AT LEAST ONE'
                : 'ADD ${count == 1 ? '1 COURSE' : '$count COURSES'}',
            Icons.calendar_month_outlined,
            _import,
            enabled: count > 0,
            key: const ValueKey('add-classes-confirm'),
          ),
          if (count == 0 && draft.titlesHidden) ...[
            const SizedBox(height: 4),
            _QuietLink(
              key: const ValueKey('add-classes-new-link'),
              label: _fromLink ? 'PASTE A NEW LINK' : 'TRY ANOTHER CALENDAR',
              onTap: () => _go(_fromLink ? _Stage.link : _Stage.ways),
            ),
          ],
        ];
      case _Stage.quick:
        return [
          const SizedBox(height: 4),
          primary(
            _busy ? 'ADDING…' : 'ADD THIS CLASS',
            Icons.add_rounded,
            _addQuick,
            key: const ValueKey('add-classes-quick-add'),
          ),
          if (_added.isNotEmpty) ...[
            const SizedBox(height: 4),
            _QuietLink(
              key: const ValueKey('add-classes-quick-done'),
              label: 'THAT’S ALL OF THEM',
              onTap: () => _go(_Stage.done),
            ),
          ],
        ];
      case _Stage.done:
        return [
          const SizedBox(height: 4),
          primary(
            'SEE MY WEEK',
            Icons.view_week_outlined,
            () => Navigator.of(
              context,
            ).pop(AddClassesResult(focusDate: _focusDate())),
            key: const ValueKey('add-classes-see-week'),
          ),
        ];
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pieces
// ─────────────────────────────────────────────────────────────────────────────

class _SheetBar extends StatelessWidget {
  const _SheetBar({required this.label, this.onBack, this.onClose});
  final String label;
  final VoidCallback? onBack;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: Row(
      children: [
        if (onBack != null)
          IconButton(
            key: const ValueKey('add-classes-back'),
            tooltip: 'Back',
            onPressed: onBack,
            icon: const Icon(
              Icons.chevron_left_rounded,
              color: Palette.textMid,
            ),
          ),
        Expanded(
          // One line at any text size: the bar shrinks its label instead
          // of growing into the content below it.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              maxLines: 1,
              style: Type.label.copyWith(fontSize: 12, color: Palette.xpLight),
            ),
          ),
        ),
        IconButton(
          key: const ValueKey('add-classes-close'),
          tooltip: 'Close',
          onPressed: onClose,
          icon: const Icon(Icons.close_rounded, color: Palette.textLo),
        ),
      ],
    ),
  );
}

class _WayRow extends StatelessWidget {
  const _WayRow({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
    this.busy = false,
  });
  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '$title. $body',
    excludeSemantics: true,
    child: InkWell(
      onTap: busy ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        constraints: const BoxConstraints(minHeight: 74),
        padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
        decoration: facetedDecoration(
          cut: 10,
          color: Palette.cardGlass,
          borderColor: Palette.brass.withValues(alpha: 0.48),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: facetedDecoration(
                cut: 8,
                color: Palette.xp.withValues(alpha: 0.08),
                borderColor: Palette.brass.withValues(alpha: 0.5),
              ),
              child: Icon(icon, size: 19, color: Palette.xpLight),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    busy ? 'OPENING…' : title,
                    style: Type.label.copyWith(color: Palette.textHi),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    body,
                    style: Type.body.copyWith(fontSize: 13, height: 1.35),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: Palette.textLo,
            ),
          ],
        ),
      ),
    ),
  );
}

class _Disclosure extends StatelessWidget {
  const _Disclosure({
    super.key,
    required this.label,
    required this.open,
    required this.onTap,
  });
  final String label;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    expanded: open,
    label: label,
    excludeSemantics: true,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Row(
          children: [
            Expanded(
              child: Container(
                height: 1,
                color: Palette.brass.withValues(alpha: 0.28),
              ),
            ),
            const SizedBox(width: 9),
            Flexible(
              flex: 4,
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: Type.label.copyWith(color: Palette.textMid),
              ),
            ),
            const SizedBox(width: 3),
            AnimatedRotation(
              turns: open ? 0.5 : 0,
              duration: Motion.quick,
              child: const Icon(
                Icons.expand_more_rounded,
                size: 18,
                color: Palette.textLo,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Container(
                height: 1,
                color: Palette.brass.withValues(alpha: 0.28),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _HelpLine extends StatelessWidget {
  const _HelpLine({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$title  ',
            style: Type.body.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Palette.textHi,
            ),
          ),
          TextSpan(text: body),
        ],
      ),
      style: Type.body.copyWith(fontSize: 13, height: 1.4),
    ),
  );
}

class _QuietLink extends StatelessWidget {
  const _QuietLink({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Center(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Type.label.copyWith(color: Palette.textMid),
          ),
        ),
      ),
    ),
  );
}

class _SmallBrass extends StatelessWidget {
  const _SmallBrass({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        constraints: const BoxConstraints(minHeight: 44, minWidth: 64),
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: facetedDecoration(
          cut: 7,
          color: Palette.xp.withValues(alpha: 0.08),
          borderColor: Palette.brass.withValues(alpha: 0.62),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Palette.xpLight),
            const SizedBox(width: 4),
            Text(label, style: Type.label.copyWith(color: Palette.xpLight)),
          ],
        ),
      ),
    ),
  );
}

class _Note extends StatelessWidget {
  const _Note({super.key, required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(11, 10, 11, 10),
    decoration: facetedDecoration(
      cut: 8,
      color: Palette.cardGlass,
      borderColor: Palette.glassEdge,
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 16, color: Palette.textMid),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            style: Type.body.copyWith(fontSize: 13, height: 1.4),
          ),
        ),
      ],
    ),
  );
}

class _TermRow extends StatelessWidget {
  const _TermRow({
    required this.term,
    required this.openEnded,
    required this.meetings,
    this.onChangeEnd,
  });
  final AcademicTerm term;
  final bool openEnded;
  final int meetings;
  final VoidCallback? onChangeEnd;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('add-classes-term'),
    padding: const EdgeInsets.fromLTRB(12, 10, 8, 6),
    decoration: facetedDecoration(
      cut: 9,
      color: Palette.xp.withValues(alpha: 0.06),
      borderColor: Palette.brass.withValues(alpha: 0.5),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                term.name,
                style: Type.display.copyWith(fontSize: 18),
              ),
            ),
            if (meetings > 0)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(
                  meetings == 1 ? '1 MEETING' : '$meetings MEETINGS',
                  style: Type.label.copyWith(color: Palette.xpLight),
                ),
              ),
          ],
        ),
        // The dates and CHANGE END share a line when they fit; at large
        // text CHANGE END moves under the dates instead of squeezing them.
        SizedBox(
          width: double.infinity,
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 30),
                child: Align(
                  widthFactor: 1,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${_monthDay(term.startDate)} to ${_monthDay(term.endDate)}',
                    style: Type.body.copyWith(
                      fontSize: 13,
                      color: Palette.textMid,
                    ),
                  ),
                ),
              ),
              if (onChangeEnd != null)
                Semantics(
                  button: true,
                  label: 'Change the last day of classes',
                  excludeSemantics: true,
                  child: InkWell(
                    key: const ValueKey('add-classes-term-end'),
                    onTap: onChangeEnd,
                    borderRadius: BorderRadius.circular(6),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: 44,
                        minWidth: 44,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Center(
                          widthFactor: 1,
                          child: Text(
                            'CHANGE END',
                            style: Type.label.copyWith(color: Palette.textMid),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (openEnded) ...[
          Text(
            'Some of these had no end date, so they stop ${_monthDay(term.endDate)}.',
            style: Type.body.copyWith(fontSize: 12, color: Palette.textLo),
          ),
          const SizedBox(height: 6),
        ],
      ],
    ),
  );
}

/// "Also here: Spring 2026": another term in the same calendar, one tap away
/// and never checked on its own.
class _OtherTermLine extends StatelessWidget {
  const _OtherTermLine({super.key, required this.choice, required this.onTap});
  final ClassTermChoice choice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final courses = choice.likelyCourseCount == 1
        ? '1 course'
        : '${choice.likelyCourseCount} courses';
    return Semantics(
      button: true,
      label: 'Also here: ${choice.name}, $courses. Show those instead.',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Also here: ${choice.name}, $courses.',
                    style: Type.body.copyWith(
                      fontSize: 13,
                      height: 1.35,
                      color: Palette.textMid,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'SHOW THOSE',
                  style: Type.label.copyWith(color: Palette.xpLight),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CourseRow extends StatelessWidget {
  const _CourseRow({
    super.key,
    required this.course,
    required this.selected,
    required this.enabled,
    required this.onTap,
    this.quiet = false,
  });
  final ClassReviewCourse course;
  final bool selected;
  final bool enabled;
  final bool quiet;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lines = [
      for (final item in course.candidates)
        '${_daysLabel(item.weekdays)} · ${_clock(item.startMinute)} · '
            '${item.lengthMinutes} MIN'
            '${item.name.kind == MeetingKind.lecture || quiet ? '' : ' · ${item.name.kind.label.toUpperCase()}'}'
            '${item.intervalWeeks == 2 ? ' · EVERY OTHER WEEK' : ''}',
    ];
    final place = course.candidates
        .map((item) => item.location)
        .whereType<String>()
        .firstOrNull;
    return Semantics(
      button: enabled,
      checked: selected,
      label: '${course.title}. ${lines.join('. ')}',
      excludeSemantics: true,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(11),
        child: AnimatedContainer(
          duration: Motion.quick,
          padding: const EdgeInsets.fromLTRB(11, 11, 12, 11),
          decoration: facetedDecoration(
            cut: 9,
            color: selected
                ? Palette.cardGlass
                : Palette.cardGlass.withValues(alpha: 0.45),
            borderColor: selected
                ? Palette.brass.withValues(alpha: 0.62)
                : Palette.glassEdge,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: _Check(on: selected),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (course.codeFound)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          course.section == null
                              ? course.code
                              : '${course.code} · ${course.section}',
                          style: Type.label.copyWith(
                            color: selected ? Palette.xpLight : Palette.textLo,
                          ),
                        ),
                      ),
                    Text(
                      course.title,
                      style: Type.body.copyWith(
                        fontSize: 15,
                        height: 1.25,
                        fontWeight: FontWeight.w600,
                        color: selected || !quiet
                            ? Palette.textHi
                            : Palette.textMid,
                      ),
                    ),
                    const SizedBox(height: 5),
                    for (final line in lines)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          line,
                          style: Type.label.copyWith(
                            letterSpacing: 0.6,
                            color: Palette.textMid,
                          ),
                        ),
                      ),
                    if (place != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          place.split(',').first,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Type.body.copyWith(
                            fontSize: 12.5,
                            color: Palette.textLo,
                          ),
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
}

/// The review's check: the app's open completion ring, closed when picked.
class _Check extends StatelessWidget {
  const _Check({required this.on});
  final bool on;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: Motion.quick,
    width: 24,
    height: 24,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: on ? Palette.xp.withValues(alpha: 0.16) : Colors.transparent,
      border: Border.all(
        color: on ? Palette.xpLight : Palette.textLo.withValues(alpha: 0.6),
        width: on ? 1.6 : 1.2,
      ),
    ),
    child: on
        ? const Icon(Icons.check_rounded, size: 15, color: Palette.xpLight)
        : null,
  );
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: Type.label.copyWith(color: Palette.textLo));
}

class _GlassField extends StatelessWidget {
  const _GlassField({
    required this.fieldKey,
    required this.controller,
    required this.hint,
    required this.onChanged,
  });
  final Key fieldKey;
  final TextEditingController controller;
  final String hint;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
    decoration: facetedDecoration(
      cut: 8,
      color: Palette.cardGlass,
      borderColor: Palette.brass.withValues(alpha: 0.46),
    ),
    child: TextField(
      key: fieldKey,
      controller: controller,
      textCapitalization: TextCapitalization.words,
      onChanged: (_) => onChanged(),
      style: Type.body.copyWith(fontSize: 15, color: Palette.textHi),
      decoration: InputDecoration(
        border: InputBorder.none,
        hintText: hint,
        hintStyle: Type.body.copyWith(fontSize: 15, color: Palette.textQuiet),
      ),
    ),
  );
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    super.key,
    required this.label,
    required this.semantic,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final String semantic;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: semantic,
    excludeSemantics: true,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: Motion.quick,
        constraints: const BoxConstraints(minHeight: 44, minWidth: 36),
        alignment: Alignment.center,
        padding: EdgeInsets.zero,
        decoration: facetedDecoration(
          cut: 7,
          color: selected
              ? Palette.xp.withValues(alpha: 0.15)
              : Colors.transparent,
          borderColor: selected
              ? Palette.xpLight.withValues(alpha: 0.62)
              : Palette.glassEdge,
        ),
        child: Center(
          child: Text(
            label,
            maxLines: 1,
            style: Type.label.copyWith(
              fontSize: 13,
              color: selected ? Palette.xpLight : Palette.textLo,
            ),
          ),
        ),
      ),
    ),
  );
}

class _TimeTile extends StatelessWidget {
  const _TimeTile({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Class starts at $label',
    excludeSemantics: true,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        constraints: const BoxConstraints(minHeight: 46),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.centerLeft,
        decoration: facetedDecoration(
          cut: 8,
          color: Palette.cardGlass,
          borderColor: Palette.brass.withValues(alpha: 0.46),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: Type.numerals.copyWith(
                fontSize: 19,
                color: Palette.textHi,
              ),
            ),
            const Spacer(),
            const Icon(Icons.schedule_rounded, size: 17, color: Palette.textLo),
          ],
        ),
      ),
    ),
  );
}

class _AddedRow extends StatelessWidget {
  const _AddedRow({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final parts = text.split('\n');
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 9, 12, 9),
      decoration: facetedDecoration(
        cut: 8,
        color: Palette.cardGlass,
        borderColor: Palette.glassEdge,
      ),
      child: Row(
        children: [
          const _Check(on: true),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  parts.first,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Type.body.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Palette.textHi,
                  ),
                ),
                if (parts.length > 1)
                  Text(
                    parts[1],
                    style: Type.label.copyWith(letterSpacing: 0.6),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekDay extends StatelessWidget {
  const _WeekDay({
    required this.label,
    required this.count,
    required this.today,
  });
  final String label;
  final int count;
  final bool today;

  @override
  Widget build(BuildContext context) => Semantics(
    label: count == 0
        ? '$label, no classes'
        : '$label, ${count == 1 ? '1 class' : '$count classes'}',
    excludeSemantics: true,
    child: Column(
      children: [
        Text(
          label,
          style: Type.label.copyWith(
            fontSize: Type.minLabel,
            letterSpacing: 0.6,
            color: today ? Palette.xpLight : Palette.textLo,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 46,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              for (var i = 0; i < count.clamp(0, 4); i++)
                Container(
                  width: 22,
                  height: 7,
                  margin: const EdgeInsets.only(top: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: Palette.xp.withValues(alpha: 0.22),
                    border: Border.all(
                      color: Palette.xpLight.withValues(alpha: 0.55),
                      width: 0.8,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 24,
          child: Center(
            child: Text(
              count == 0 ? 'free' : '$count',
              style: count == 0
                  ? Type.body.copyWith(fontSize: 12, color: Palette.textQuiet)
                  : Type.numerals.copyWith(fontSize: 15, color: Palette.textHi),
            ),
          ),
        ),
      ],
    ),
  );
}

/// The result's class-reminder choice, off until the student turns it on.
class _ReminderChoice extends StatelessWidget {
  const _ReminderChoice({
    required this.offset,
    required this.enabled,
    this.note,
    required this.onChanged,
    required this.onOffsetChanged,
  });

  /// Minutes before each class, or null when reminders are off.
  final int? offset;

  /// Why reminders are still off after the student asked for them.
  final String? note;
  final bool enabled;
  final Future<bool> Function(bool on) onChanged;
  final ValueChanged<int> onOffsetChanged;

  @override
  Widget build(BuildContext context) {
    final on = offset != null;
    return Container(
      key: const ValueKey('add-classes-reminders'),
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: facetedDecoration(
        cut: 9,
        color: Palette.cardGlass,
        borderColor: Palette.brass.withValues(alpha: 0.38),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CLASS REMINDERS',
                      style: Type.label.copyWith(color: Palette.xpLight),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      on
                          ? 'A quiet note $offset minutes before each of these classes.'
                          : note ??
                                'A quiet note before each class. Off unless you turn it on.',
                      key: const ValueKey('add-classes-reminder-line'),
                      style: Type.body.copyWith(
                        fontSize: 12.5,
                        height: 1.35,
                        color: Palette.textMid,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IgnorePointer(
                ignoring: !enabled,
                child: Opacity(
                  opacity: enabled ? 1 : 0.55,
                  child: GlassSwitch(
                    key: const ValueKey('add-classes-reminder-switch'),
                    value: on,
                    semanticLabel: 'Class reminders',
                    onChangeAccepted: onChanged,
                  ),
                ),
              ),
            ],
          ),
          if (on) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                for (final minutes in classReminderOffsets)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: minutes == classReminderOffsets.last ? 0 : 6,
                      ),
                      child: _DayChip(
                        key: ValueKey('add-classes-reminder-$minutes'),
                        label: '$minutes MIN',
                        semantic: '$minutes minutes before',
                        selected: offset == minutes,
                        onTap: () {
                          if (!enabled || offset == minutes) return;
                          Haptics.tap();
                          onOffsetChanged(minutes);
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// The calm doorway Plans shows when there are no classes yet.
class AddClassesDoorway extends StatelessWidget {
  const AddClassesDoorway({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Your classes. Add them once and each one shows up on its day.',
    excludeSemantics: true,
    child: InkWell(
      key: const ValueKey('add-classes-doorway'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
        decoration: facetedDecoration(
          cut: 12,
          color: Palette.cardGlass,
          borderColor: Palette.brass.withValues(alpha: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: facetedDecoration(
                cut: 8,
                color: Palette.xp.withValues(alpha: 0.08),
                borderColor: Palette.brass.withValues(alpha: 0.5),
              ),
              child: const Icon(
                Icons.school_outlined,
                size: 20,
                color: Palette.xpLight,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'YOUR CLASSES',
                    style: Type.label.copyWith(color: Palette.xpLight),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Add them once and each one shows up on its day.',
                    style: Type.body.copyWith(fontSize: 13.5, height: 1.35),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.chevron_right_rounded,
              size: 22,
              color: Palette.textLo,
            ),
          ],
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Words
// ─────────────────────────────────────────────────────────────────────────────

const _dayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];
const _dayShort = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _daysLabel(Set<int> days) {
  if (days.length == 5 && days.every((day) => day <= DateTime.friday)) {
    return 'WEEKDAYS';
  }
  return (days.toList()..sort()).map((day) => _dayShort[day - 1]).join(' ');
}

String _clock(int minute) {
  final m = minute % (24 * 60);
  final hour = m ~/ 60;
  final h12 = hour % 12 == 0 ? 12 : hour % 12;
  final mm = (m % 60).toString().padLeft(2, '0');
  return '$h12:$mm ${hour < 12 ? 'AM' : 'PM'}';
}

String _monthDay(CivilDate date) => '${_months[date.month - 1]} ${date.day}';

String _weekdayLong(CivilDate date, CivilDate today) {
  if (date == today) return 'today';
  if (date == today.addDays(1)) return 'tomorrow';
  final away = date.dateArithmeticValue
      .difference(today.dateArithmeticValue)
      .inDays;
  if (away > 1 && away < 7) return _dayNames[date.weekday - 1];
  return '${_dayNames[date.weekday - 1]}, ${_monthDay(date)}';
}

String _count(int value, String noun, {String? plural}) =>
    '$value ${value == 1 ? noun : (plural ?? '${noun}s')}';

String _joinAnd(List<String> parts) {
  if (parts.length <= 1) return parts.join();
  return '${parts.sublist(0, parts.length - 1).join(', ')} and ${parts.last}';
}
