import 'package:flutter/material.dart';

import '../../tokens.dart';
import '../../widgets/facets.dart';
import '../../widgets/glass.dart';
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
  });

  final AcademicScheduleFilePicker filePicker;
  final SaveAcademicScheduleImport onImport;

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
      final draft = AcademicScheduleIcsImporter.parse(
        source.contents,
        sourceName: source.name,
      );
      setState(() {
        _sourceName = source.name;
        _draft = draft;
        _reading = false;
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
    final saved = await widget.onImport(draft);
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
                  _ImportEmptyState(reading: _reading, onChoose: _pickFile)
                else
                  _ImportReview(
                    sourceName: _sourceName ?? 'class-schedule.ics',
                    draft: draft,
                    saving: _saving,
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
  const _ImportEmptyState({required this.reading, required this.onChoose});

  final bool reading;
  final VoidCallback onChoose;

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
    ],
  );
}

class _ImportReview extends StatelessWidget {
  const _ImportReview({
    required this.sourceName,
    required this.draft,
    required this.saving,
    required this.onChooseAnother,
    required this.onImport,
  });

  final String sourceName;
  final AcademicScheduleImportDraft draft;
  final bool saving;
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
        child: TextButton.icon(
          key: const ValueKey('academic-import-choose-another'),
          onPressed: saving ? null : onChooseAnother,
          icon: const Icon(Icons.swap_horiz_rounded, size: 18),
          label: const Text('CHOOSE ANOTHER FILE'),
          style: TextButton.styleFrom(
            foregroundColor: Palette.textMid,
            minimumSize: const Size(44, 44),
            textStyle: Type.label.copyWith(fontSize: Type.minLabel),
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
