import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../audio.dart';
import '../../clock.dart';
import '../../tokens.dart';
import '../../widgets/glass.dart';
import '../../widgets/gold_surface.dart';
import '../domain/civil_date.dart';
import '../domain/daybook_task.dart';
import 'daybook_place_fields.dart';

class DaybookTaskEditor extends StatefulWidget {
  const DaybookTaskEditor({
    super.key,
    required this.selectedDay,
    this.initialTask,
    this.placeSearchFactory = const ProductionDaybookPlaceSearchFactory(),
    required this.onSave,
  });

  final CivilDate selectedDay;
  final DaybookTask? initialTask;
  final DaybookPlaceSearchFactory placeSearchFactory;
  final Future<bool> Function(DaybookTask task) onSave;

  @override
  State<DaybookTaskEditor> createState() => _DaybookTaskEditorState();
}

class _DaybookTaskEditorState extends State<DaybookTaskEditor> {
  late final TextEditingController _title;
  late final TextEditingController _notes;
  late final DaybookPlaceFieldsController _place;
  late CivilDate _dueDate;
  late TimeOfDay _dueTime;
  late bool _hasTime;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final task = widget.initialTask;
    _title = TextEditingController(text: task?.title ?? '');
    _notes = TextEditingController(text: task?.notes ?? '');
    _place = DaybookPlaceFieldsController(initialPlace: task?.place);
    _dueDate = task?.dueDate ?? widget.selectedDay;
    _hasTime = task?.dueMinute != null;
    _dueTime = _timeOf(task?.dueMinute ?? 17 * 60);
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate.dateArithmeticValue,
      firstDate: DateTime.utc(2020),
      lastDate: DateTime.utc(2100, 12, 31),
      helpText: 'TASK DUE DATE',
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
      initialTime: _dueTime,
      helpText: 'TASK DUE TIME',
    );
    if (!mounted || picked == null) return;
    setState(() {
      _dueTime = picked;
      _error = null;
    });
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Add a title before keeping this task.');
      return;
    }
    if (_place.needsSavedName) {
      setState(() => _error = 'Add a saved name for this place.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    final now = Clock.now().toUtc();
    final initial = widget.initialTask;
    final task = DaybookTask(
      taskId: initial?.taskId ?? 'daybook_task_${now.microsecondsSinceEpoch}',
      title: title,
      dueDate: _dueDate,
      dueMinute: _hasTime ? _minuteOf(_dueTime) : null,
      notes: _notes.text,
      place: _place.toPlace(),
      completedAt: initial?.completedAt,
      createdAt: initial?.createdAt ?? now,
      updatedAt: now,
    );

    var saved = false;
    try {
      saved = await widget.onSave(task);
    } catch (_) {
      saved = false;
    }
    if (!mounted) return;
    if (!saved) {
      Sfx.instance.play('boing');
      setState(() {
        _saving = false;
        _error = 'Couldn’t save this task locally. Try again.';
      });
      return;
    }
    Sfx.instance.playInteraction(
      InteractionSound.place,
      material: MaterialSound.glass,
    );
    HapticFeedback.mediumImpact();
    if (Navigator.of(context).canPop()) Navigator.of(context).pop(task);
  }

  @override
  Widget build(BuildContext context) => Dialog(
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
                      widget.initialTask == null ? 'ADD A TASK' : 'EDIT TASK',
                      style: Type.label.copyWith(
                        fontSize: 12,
                        color: Palette.xpLight,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () {
                      Sfx.instance.playMaterial(MaterialSound.glass);
                      Navigator.of(context).maybePop();
                    },
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Palette.textLo,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _sectionLabel('TASK'),
              const SizedBox(height: 7),
              TextField(
                key: const ValueKey('daybook-task-title'),
                controller: _title,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() => _error = null),
                style: _inputStyle,
                decoration: _fieldDecoration('TITLE'),
              ),
              const SizedBox(height: 7),
              TextField(
                key: const ValueKey('daybook-task-notes'),
                controller: _notes,
                minLines: 2,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                style: _inputStyle,
                decoration: _fieldDecoration('NOTES'),
              ),
              const SizedBox(height: 13),
              _sectionLabel('DUE'),
              const SizedBox(height: 7),
              _PickerButton(
                key: const ValueKey('daybook-task-due-date'),
                label: 'DUE DATE',
                value: _formatDate(_dueDate),
                icon: Icons.calendar_today_outlined,
                onTap: _pickDate,
              ),
              const SizedBox(height: 7),
              Material(
                color: Palette.glassFill,
                borderRadius: BorderRadius.circular(10),
                child: SwitchListTile.adaptive(
                  key: const ValueKey('daybook-task-has-time'),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  activeTrackColor: Palette.xp.withValues(alpha: 0.52),
                  title: Text(
                    'DUE TIME',
                    style: Type.label.copyWith(
                      fontSize: Type.minLabel,
                      color: Palette.textHi,
                    ),
                  ),
                  subtitle: Text(
                    _hasTime ? _formatTime(_dueTime) : 'No set time',
                    style: Type.body.copyWith(
                      fontSize: 11.5,
                      color: Palette.textLo,
                    ),
                  ),
                  value: _hasTime,
                  onChanged: (value) => setState(() {
                    _hasTime = value;
                    _error = null;
                  }),
                ),
              ),
              if (_hasTime) ...[
                const SizedBox(height: 7),
                _PickerButton(
                  key: const ValueKey('daybook-task-due-time'),
                  label: 'DUE TIME',
                  value: _formatTime(_dueTime),
                  icon: Icons.schedule_outlined,
                  onTap: _pickTime,
                ),
              ],
              const SizedBox(height: 13),
              _sectionLabel('PLACE · OPTIONAL'),
              const SizedBox(height: 7),
              DaybookPlaceFields(
                controller: _place,
                keyPrefix: 'daybook-task-place',
                placeSearchFactory: widget.placeSearchFactory,
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  key: const ValueKey('daybook-task-error'),
                  style: Type.body.copyWith(
                    fontSize: 12,
                    color: Palette.danger,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Semantics(
                button: true,
                enabled: !_saving,
                label: _saving ? 'Saving task' : 'Keep this task',
                child: InkWell(
                  key: const ValueKey('daybook-task-save'),
                  onTap: _saving ? null : _save,
                  borderRadius: BorderRadius.circular(9),
                  child: Opacity(
                    opacity: _saving ? 0.55 : 1,
                    child: GoldSurface(
                      cut: 9,
                      glow: false,
                      textured: false,
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 48),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        child: Text(
                          _saving
                              ? 'SAVING…'
                              : widget.initialTask == null
                              ? 'KEEP THIS TASK'
                              : 'KEEP CHANGES',
                          textAlign: TextAlign.center,
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
            ],
          ),
        ),
      ),
    ),
  );
}

class _PickerButton extends StatelessWidget {
  const _PickerButton({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '$label, $value',
    child: InkWell(
      onTap: onTap,
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
            Icon(icon, size: 16, color: Palette.xpLight),
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
                      color: Palette.textHi,
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

Widget _sectionLabel(String label) => Text(
  label,
  style: Type.label.copyWith(
    fontSize: Type.minLabel,
    letterSpacing: 1.5,
    color: Palette.textLo,
  ),
);

InputDecoration _fieldDecoration(String label) => InputDecoration(
  labelText: label,
  labelStyle: Type.label.copyWith(
    fontSize: Type.minLabel,
    color: Palette.textLo,
  ),
  isDense: true,
  filled: true,
  fillColor: Palette.glassFill,
  contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 12),
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

TimeOfDay _timeOf(int minute) =>
    TimeOfDay(hour: minute ~/ 60, minute: minute % 60);

int _minuteOf(TimeOfDay time) => time.hour * 60 + time.minute;

String _formatDate(CivilDate date) =>
    '${_monthNames[date.month - 1]} ${date.day}, ${date.year}';

String _formatTime(TimeOfDay time) {
  final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${time.hour < 12 ? 'AM' : 'PM'}';
}
