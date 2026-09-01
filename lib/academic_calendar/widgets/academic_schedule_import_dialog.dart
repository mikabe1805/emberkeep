import 'dart:async';

import 'package:flutter/material.dart';

import '../../platform/share_stub.dart'
    if (dart.library.js_interop) '../../platform/share_web.dart';
import '../../tokens.dart';
import '../../widgets/facets.dart';
import '../../widgets/glass.dart';
import '../../widgets/glass_switch.dart';
import '../../widgets/honey_button.dart';
import '../domain/academic_schedule.dart';
import '../import/academic_schedule_file_picker.dart';
import '../import/academic_schedule_ics_import.dart';

typedef SaveAcademicScheduleImport =
    Future<bool> Function(AcademicScheduleImportDraft draft);

final class AcademicScheduleImportDialog extends StatefulWidget {
  const AcademicScheduleImportDialog({
    super.key,
    required this.filePicker,
    required this.onImport,
    this.initialSource,
    this.requestReminderPermission,
  });

  final AcademicScheduleFilePicker filePicker;
  final SaveAcademicScheduleImport onImport;
  final AcademicScheduleImportSource? initialSource;

  /// Called only after the person explicitly turns class reminders on.
  final Future<bool> Function()? requestReminderPermission;

  @override
  State<AcademicScheduleImportDialog> createState() =>
      _AcademicScheduleImportDialogState();
}

class _AcademicScheduleImportDialogState
    extends State<AcademicScheduleImportDialog> {
  final ScrollController _scrollController = ScrollController();
  AcademicScheduleImportDraft? _draft;
  String? _sourceName;
  String? _error;
  bool _reading = false;
  bool _saving = false;
  bool _requestingReminderPermission = false;
  AcademicScheduleImportReminderChoice _reminderChoice =
      AcademicScheduleImportReminderChoice.unchanged;
  int _reminderOffsetMinutes = 10;

  @override
  void initState() {
    super.initState();
    if (widget.initialSource case final source?) {
      try {
        _acceptSource(source);
      } on FormatException {
        _error =
            'That file isn’t a Room of Days class schedule yet. Start with the editable .ics file or choose another.';
      }
    }
  }

  void _acceptSource(AcademicScheduleImportSource source) {
    final draft = AcademicScheduleIcsImporter.parse(
      source.contents,
      sourceName: source.name,
    );
    _sourceName = source.name;
    _draft = draft;
    _reading = false;
    _reminderChoice = AcademicScheduleImportReminderChoice.unchanged;
    _reminderOffsetMinutes = 10;
  }

  Future<void> _pickFile() async {
    if (_reading || _saving) return;
    setState(() {
      _reading = true;
      _error = null;
    });

    try {
      final source = await widget.filePicker.pick();
      if (!mounted) return;
      if (source == null) {
        setState(() => _reading = false);
        return;
      }
      setState(() {
        _acceptSource(source);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) _scrollController.jumpTo(0);
      });
    } on FormatException {
      if (!mounted) return;
      setState(() {
        _draft = null;
        _sourceName = null;
        _reading = false;
        _error =
            'That file isn’t a Room of Days class schedule yet. Choose the .ics file made for this import.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _draft = null;
        _sourceName = null;
        _reading = false;
        _error = 'Couldn’t read that schedule. Try another .ics file.';
      });
    }
  }

  Future<void> _shareStarter() async {
    final shared = await shareCalendarFile(
      buildRoomOfDaysAcademicScheduleTemplate(),
      'room-of-days-class-schedule-starter.ics',
    );
    if (!mounted) return;
    if (!shared) {
      setState(() {
        _error = 'Couldn’t share the starter file on this device.';
      });
      return;
    }
    ScaffoldMessenger.maybeOf(context)
      ?..clearSnackBars()
      ..showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Palette.card,
          content: Text(
            'Starter file ready — edit it, save it as .ics, then open it in Room of Days.',
          ),
        ),
      );
  }

  Future<void> _setReminderChoice(
    AcademicScheduleImportReminderChoice choice,
  ) async {
    if (_saving || _requestingReminderPermission) return;
    if (choice != AcademicScheduleImportReminderChoice.on) {
      setState(() {
        _reminderChoice = choice;
        _error = null;
      });
      return;
    }
    setState(() {
      _requestingReminderPermission = true;
      _error = null;
    });
    final granted = await widget.requestReminderPermission?.call() ?? true;
    if (!mounted) return;
    setState(() {
      _requestingReminderPermission = false;
      if (granted) {
        _reminderChoice = AcademicScheduleImportReminderChoice.on;
      } else {
        _reminderChoice = AcademicScheduleImportReminderChoice.off;
        _error =
            'Class reminders stayed off — allow notifications in system settings when you’re ready.';
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    final draft = _draft;
    if (draft == null || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final saved = await widget.onImport(
      draft.withReminderChoice(
        _reminderChoice,
        offsetMinutes: _reminderOffsetMinutes,
      ),
    );
    if (!mounted) return;
    if (!saved) {
      setState(() {
        _saving = false;
        _error = 'Couldn’t save this schedule locally. Try again.';
      });
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final draft = _draft;
    final media = MediaQuery.of(context);
    final maxHeight =
        media.size.height -
        media.padding.vertical -
        media.viewInsets.vertical -
        32;
    return Dialog(
      key: const ValueKey('academic-import-review'),
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 520, maxHeight: maxHeight),
        child: GlassPanel(
          tint: Palette.dialogSurface,
          padding: const EdgeInsets.fromLTRB(18, 15, 18, 18),
          child: SingleChildScrollView(
            controller: _scrollController,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'IMPORT CLASS SCHEDULE',
                        style: Type.label.copyWith(
                          fontSize: 12,
                          color: Palette.xpLight,
                        ),
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('academic-import-cancel'),
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
                Text(
                  draft == null
                      ? 'Choose a Room of Days .ics class file. Nothing is added until you review it.'
                      : 'Check the term and every course before Room of Days changes your calendar.',
                  style: Type.body.copyWith(
                    fontSize: 13,
                    color: Palette.textMid,
                  ),
                ),
                const SizedBox(height: 14),
                if (draft == null)
                  _ImportEmptyState(
                    reading: _reading,
                    onChoose: _pickFile,
                    onShareStarter: _shareStarter,
                  )
                else
                  _ImportReview(
                    sourceName: _sourceName ?? 'class-schedule.ics',
                    draft: draft,
                    saving: _saving || _requestingReminderPermission,
                    reminderChoice: _reminderChoice,
                    reminderOffsetMinutes: _reminderOffsetMinutes,
                    onReminderChoiceChanged: (choice) =>
                        unawaited(_setReminderChoice(choice)),
                    onReminderOffsetChanged: (offset) =>
                        setState(() => _reminderOffsetMinutes = offset),
                    onChooseAnother: _pickFile,
                    onImport: _import,
                  ),
                if (_error != null) ...[
                  const SizedBox(height: 11),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _error!,
                      key: const ValueKey('academic-import-error'),
                      style: Type.body.copyWith(
                        fontSize: 12.5,
                        color: Palette.danger,
                      ),
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

class _ImportEmptyState extends StatelessWidget {
  const _ImportEmptyState({
    required this.reading,
    required this.onChoose,
    required this.onShareStarter,
  });

  final bool reading;
  final VoidCallback onChoose;
  final VoidCallback onShareStarter;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Container(
        padding: const EdgeInsets.all(13),
        decoration: facetedDecoration(
          cut: 10,
          color: Palette.cardGlass,
          borderColor: Palette.brass.withValues(alpha: 0.44),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.calendar_month_outlined,
              size: 22,
              color: Palette.xpLight,
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ONE-WAY IMPORT',
                    style: Type.label.copyWith(
                      fontSize: Type.minLabel,
                      color: Palette.textHi,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Classes are copied into your local academic schedule. This does not connect or change the source calendar.',
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
      const SizedBox(height: 14),
      HoneyButton(
        key: const ValueKey('academic-import-choose'),
        label: reading ? 'READING…' : 'CHOOSE .ICS FILE',
        icon: Icons.upload_file_outlined,
        enabled: !reading,
        expand: true,
        glow: false,
        onTap: onChoose,
      ),
      const SizedBox(height: 8),
      Semantics(
        button: true,
        label: 'Get an editable Room of Days class schedule starter file',
        child: InkWell(
          key: const ValueKey('academic-import-share-starter'),
          onTap: reading ? null : onShareStarter,
          borderRadius: BorderRadius.circular(10),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.code_rounded,
                    size: 18,
                    color: Palette.xpLight,
                  ),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      'GET EDITABLE STARTER FILE',
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      style: Type.label.copyWith(
                        fontSize: 11,
                        color: Palette.xpLight,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      Text(
        'For a class that meets more than once a week, keep the commas in BYDAY=MO,WE,FR.',
        textAlign: TextAlign.center,
        style: Type.body.copyWith(
          fontSize: 11,
          height: 1.3,
          color: Palette.textLo,
        ),
      ),
    ],
  );
}

class _ImportReview extends StatelessWidget {
  const _ImportReview({
    required this.sourceName,
    required this.draft,
    required this.saving,
    required this.reminderChoice,
    required this.reminderOffsetMinutes,
    required this.onReminderChoiceChanged,
    required this.onReminderOffsetChanged,
    required this.onChooseAnother,
    required this.onImport,
  });

  final String sourceName;
  final AcademicScheduleImportDraft draft;
  final bool saving;
  final AcademicScheduleImportReminderChoice reminderChoice;
  final int reminderOffsetMinutes;
  final ValueChanged<AcademicScheduleImportReminderChoice>
  onReminderChoiceChanged;
  final ValueChanged<int> onReminderOffsetChanged;
  final VoidCallback onChooseAnother;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey('academic-import-courses'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        sourceName,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Type.label.copyWith(
          fontSize: Type.minLabel,
          color: Palette.textLo,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        draft.term.name,
        style: Type.display.copyWith(fontSize: 24, color: Palette.textHi),
      ),
      const SizedBox(height: 3),
      Text(
        _dateRange(draft.term.startDate, draft.term.endDate),
        style: Type.label.copyWith(
          fontSize: Type.minLabel,
          letterSpacing: 1.2,
          color: Palette.textMid,
        ),
      ),
      const SizedBox(height: 11),
      _ClassReminderChoice(
        choice: reminderChoice,
        offsetMinutes: reminderOffsetMinutes,
        enabled: !saving,
        onChoiceChanged: onReminderChoiceChanged,
        onOffsetChanged: onReminderOffsetChanged,
      ),
      const SizedBox(height: 11),
      Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
        decoration: facetedDecoration(
          cut: 9,
          color: Palette.xp.withValues(alpha: 0.07),
          borderColor: Palette.brass.withValues(alpha: 0.52),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${draft.courses.length} COURSES · ${draft.meetingSeriesCount} WEEKLY MEETINGS',
              style: Type.label.copyWith(
                fontSize: Type.minLabel,
                color: Palette.xpLight,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${draft.projectedOccurrenceCount} class meetings after calendar exceptions',
              style: Type.body.copyWith(fontSize: 12.5, color: Palette.textMid),
            ),
            const SizedBox(height: 3),
            Text(
              'ONE-WAY IMPORT · SAVED ON THIS DEVICE',
              style: Type.label.copyWith(
                fontSize: Type.minLabel,
                letterSpacing: 0.8,
                color: Palette.textLo,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 11),
      Container(
        decoration: facetedDecoration(
          cut: 9,
          color: Palette.cardGlass,
          borderColor: Palette.brass.withValues(alpha: 0.38),
        ),
        child: Column(
          children: [
            for (var index = 0; index < draft.courses.length; index++) ...[
              if (index > 0)
                Divider(
                  height: 1,
                  color: Palette.brass.withValues(alpha: 0.24),
                ),
              _ImportedCourseRow(course: draft.courses[index]),
            ],
          ],
        ),
      ),
      if (draft.warnings.isNotEmpty) ...[
        const SizedBox(height: 11),
        Container(
          key: const ValueKey('academic-import-warning'),
          padding: const EdgeInsets.all(11),
          decoration: facetedDecoration(
            cut: 8,
            color: Palette.streak.withValues(alpha: 0.07),
            borderColor: Palette.streak.withValues(alpha: 0.38),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CHECK BEFORE IMPORTING',
                style: Type.label.copyWith(
                  fontSize: Type.minLabel,
                  color: Palette.streak,
                ),
              ),
              const SizedBox(height: 4),
              for (final warning in draft.warnings)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '· $warning',
                    style: Type.body.copyWith(
                      fontSize: 12,
                      color: Palette.textMid,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: TextButton.icon(
            key: const ValueKey('academic-import-choose-another'),
            onPressed: saving ? null : onChooseAnother,
            icon: const Icon(Icons.swap_horiz_rounded, size: 18),
            label: const Text(
              'CHOOSE ANOTHER FILE',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            style: TextButton.styleFrom(
              foregroundColor: Palette.textMid,
              minimumSize: const Size(44, 44),
              textStyle: Type.label.copyWith(fontSize: Type.minLabel),
            ),
          ),
        ),
      ),
      const SizedBox(height: 5),
      HoneyButton(
        key: const ValueKey('academic-import-confirm'),
        label: saving ? 'IMPORTING…' : 'IMPORT SCHEDULE',
        icon: Icons.calendar_month_outlined,
        enabled: !saving,
        expand: true,
        onTap: onImport,
      ),
    ],
  );
}

class _ClassReminderChoice extends StatelessWidget {
  const _ClassReminderChoice({
    required this.choice,
    required this.offsetMinutes,
    required this.enabled,
    required this.onChoiceChanged,
    required this.onOffsetChanged,
  });

  final AcademicScheduleImportReminderChoice choice;
  final int offsetMinutes;
  final bool enabled;
  final ValueChanged<AcademicScheduleImportReminderChoice> onChoiceChanged;
  final ValueChanged<int> onOffsetChanged;

  @override
  Widget build(BuildContext context) {
    final remindersOn = choice == AcademicScheduleImportReminderChoice.on;
    return Container(
      key: const ValueKey('academic-import-reminders'),
      padding: const EdgeInsets.fromLTRB(12, 9, 10, 10),
      decoration: facetedDecoration(
        cut: 9,
        color: Palette.cardGlass,
        borderColor: Palette.brass.withValues(alpha: 0.38),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CLASS REMINDERS',
                      style: Type.label.copyWith(
                        fontSize: Type.minLabel,
                        color: Palette.xpLight,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      remindersOn
                          ? 'Room of Days will remind you before each class.'
                          : choice == AcademicScheduleImportReminderChoice.off
                          ? 'No class reminders will be added from this import.'
                          : 'Off unless you turn it on. Re-import keeps reminders you already chose.',
                      style: Type.body.copyWith(
                        fontSize: 12.5,
                        color: Palette.textMid,
                      ),
                    ),
                  ],
                ),
              ),
              IgnorePointer(
                ignoring: !enabled,
                child: Opacity(
                  opacity: enabled ? 1 : 0.55,
                  child: GlassSwitch(
                    key: const ValueKey('academic-import-reminder-switch'),
                    value: remindersOn,
                    semanticLabel: 'Class reminders',
                    onChanged: (value) => onChoiceChanged(
                      value
                          ? AcademicScheduleImportReminderChoice.on
                          : AcademicScheduleImportReminderChoice.off,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (remindersOn) ...[
            const SizedBox(height: 7),
            DropdownButtonFormField<int>(
              key: const ValueKey('academic-import-reminder-offset'),
              initialValue: offsetMinutes,
              isExpanded: true,
              dropdownColor: Palette.dialogSurface,
              style: Type.body.copyWith(fontSize: 13, color: Palette.textHi),
              decoration: InputDecoration(
                labelText: 'REMIND ME',
                labelStyle: Type.label.copyWith(
                  fontSize: Type.minLabel,
                  color: Palette.textLo,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: Palette.brass.withValues(alpha: 0.42),
                  ),
                ),
              ),
              items: const [10, 15, 30]
                  .map(
                    (minutes) => DropdownMenuItem<int>(
                      value: minutes,
                      child: Text('$minutes minutes before'),
                    ),
                  )
                  .toList(),
              onChanged: enabled
                  ? (minutes) {
                      if (minutes != null) onOffsetChanged(minutes);
                    }
                  : null,
            ),
          ],
        ],
      ),
    );
  }
}

class _ImportedCourseRow extends StatelessWidget {
  const _ImportedCourseRow({required this.course});

  final AcademicScheduleImportCourse course;

  @override
  Widget build(BuildContext context) {
    final section = course.section == null
        ? ''
        : ' · SECTION ${course.section}';
    final meetings = course.meetingSeriesCount == 1
        ? '1 WEEKLY MEETING'
        : '${course.meetingSeriesCount} WEEKLY MEETINGS';
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${course.code}$section',
            style: Type.label.copyWith(
              fontSize: Type.minLabel,
              letterSpacing: 0.8,
              color: Palette.xpLight,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            course.title,
            style: Type.body.copyWith(fontSize: 13.5, color: Palette.textHi),
          ),
          const SizedBox(height: 3),
          Text(
            meetings,
            style: Type.label.copyWith(
              fontSize: Type.minLabel,
              letterSpacing: 0.7,
              color: Palette.textLo,
            ),
          ),
        ],
      ),
    );
  }
}

const _months = <String>[
  'JAN',
  'FEB',
  'MAR',
  'APR',
  'MAY',
  'JUN',
  'JUL',
  'AUG',
  'SEP',
  'OCT',
  'NOV',
  'DEC',
];

String _dateRange(CivilDate start, CivilDate end) {
  final first = '${_months[start.month - 1]} ${start.day}';
  final last = '${_months[end.month - 1]} ${end.day}';
  if (start.year == end.year) return '$first – $last, ${end.year}';
  return '$first, ${start.year} – $last, ${end.year}';
}
