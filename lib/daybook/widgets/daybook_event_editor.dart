import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../audio.dart';
import '../../clock.dart';
import '../../tokens.dart';
import '../../widgets/facets.dart';
import '../../widgets/glass.dart';
import '../../widgets/gold_surface.dart';
import '../domain/civil_date.dart';
import '../domain/daybook_event.dart';
import 'daybook_place_fields.dart';

class DaybookEventEditor extends StatefulWidget {
  const DaybookEventEditor({
    super.key,
    required this.selectedDay,
    this.initialEvent,
    this.initialOccurrence,
    required this.onSave,
  });

  final CivilDate selectedDay;
  final DaybookEvent? initialEvent;
  final DaybookEventOccurrence? initialOccurrence;
  final Future<bool> Function(DaybookEvent event) onSave;

  @override
  State<DaybookEventEditor> createState() => _DaybookEventEditorState();
}

class _DaybookEventEditorState extends State<DaybookEventEditor> {
  late final TextEditingController _title;
  late final TextEditingController _notes;
  late final TextEditingController _interval;
  late final DaybookPlaceFieldsController _place;
  late CivilDate _startDate;
  late CivilDate _endDate;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late bool _allDay;
  late bool _weekly;
  late Set<int> _weekdays;
  late bool _hasRecurrenceEnd;
  late CivilDate _recurrenceEnd;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final event = widget.initialEvent;
    final occurrence = widget.initialOccurrence;
    _title = TextEditingController(text: event?.title ?? '');
    _notes = TextEditingController(text: event?.notes ?? '');
    _interval = TextEditingController(
      text: (event?.weeklyRule?.intervalWeeks ?? 1).toString(),
    );
    _place = DaybookPlaceFieldsController(initialPlace: event?.place);
    _allDay = occurrence?.allDay ?? event?.allDay ?? true;
    _startDate =
        occurrence?.startDate ?? event?.startDate ?? widget.selectedDay;
    _endDate =
        occurrence?.endDate ?? event?.endDate ?? widget.selectedDay.addDays(1);
    _startTime = _timeOf(
      occurrence?.startMinute ?? event?.startMinute ?? 9 * 60,
    );
    _endTime = _timeOf(occurrence?.endMinute ?? event?.endMinute ?? 10 * 60);
    _weekly = event?.weeklyRule != null;
    _weekdays = {
      ...?event?.weeklyRule?.weekdays,
      if (event?.weeklyRule == null) _startDate.weekday,
    };
    _hasRecurrenceEnd = event?.weeklyRule?.endsOn != null;
    _recurrenceEnd = event?.weeklyRule?.endsOn ?? _startDate.addDays(84);
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    _interval.dispose();
    super.dispose();
  }

  Future<void> _pickDate(_EventDateField field) async {
    final initial = switch (field) {
      _EventDateField.start => _startDate,
      _EventDateField.end => _endDate,
      _EventDateField.recurrenceEnd => _recurrenceEnd,
    };
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.dateArithmeticValue,
      firstDate: DateTime.utc(2020),
      lastDate: DateTime.utc(2100, 12, 31),
      helpText: switch (field) {
        _EventDateField.start => 'EVENT START',
        _EventDateField.end => 'EVENT END',
        _EventDateField.recurrenceEnd => 'REPEAT UNTIL',
      },
    );
    if (!mounted || picked == null) return;
    final date = CivilDate.fromDateTime(picked);
    setState(() {
      switch (field) {
        case _EventDateField.start:
          _startDate = date;
          if (_endDate.compareTo(date) < 0 || (_allDay && _endDate == date)) {
            _endDate = _allDay ? date.addDays(1) : date;
          }
        case _EventDateField.end:
          _endDate = date;
        case _EventDateField.recurrenceEnd:
          _recurrenceEnd = date;
      }
      _error = null;
    });
  }

  Future<void> _pickTime({required bool start}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: start ? _startTime : _endTime,
      helpText: start ? 'EVENT START' : 'EVENT END',
    );
    if (!mounted || picked == null) return;
    setState(() {
      if (start) {
        _startTime = picked;
      } else {
        _endTime = picked;
      }
      _error = null;
    });
  }

  void _setAllDay(bool value) {
    setState(() {
      _allDay = value;
      if (value && _endDate.compareTo(_startDate) <= 0) {
        _endDate = _startDate.addDays(1);
      } else if (!value && _endDate == _startDate.addDays(1)) {
        _endDate = _startDate;
      }
      _error = null;
    });
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Add a title before keeping this event.');
      return;
    }
    if (_place.needsSavedName) {
      setState(() => _error = 'Add a saved name for this place.');
      return;
    }
    if (_weekly && _weekdays.isEmpty) {
      setState(
        () => _error = 'Choose at least one weekday for a weekly event.',
      );
      return;
    }
    final intervalWeeks = int.tryParse(_interval.text.trim());
    if (_weekly && (intervalWeeks == null || intervalWeeks < 1)) {
      setState(() => _error = 'Use an interval of one week or more.');
      return;
    }
    if (_allDay && _endDate.compareTo(_startDate) <= 0) {
      setState(() => _error = 'Event end needs to be after its start.');
      return;
    }
    final startMinute = _minuteOf(_startTime);
    final endMinute = _minuteOf(_endTime);
    if (!_allDay &&
        (_endDate.compareTo(_startDate) < 0 ||
            _endDate.compareTo(_startDate.addDays(1)) > 0 ||
            (_endDate == _startDate && endMinute <= startMinute))) {
      setState(() => _error = 'Event end needs to be after its start.');
      return;
    }
    if (_weekly &&
        _hasRecurrenceEnd &&
        _recurrenceEnd.compareTo(_startDate) < 0) {
      setState(() => _error = 'Repeat end needs to be on or after the start.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    final now = Clock.now().toUtc();
    final initial = widget.initialEvent;
    final event = DaybookEvent(
      eventId:
          initial?.eventId ?? 'daybook_event_${now.microsecondsSinceEpoch}',
      title: title,
      startDate: _startDate,
      endDate: _endDate,
      timeZoneId: initial?.timeZoneId ?? 'America/New_York',
      allDay: _allDay,
      startMinute: _allDay ? null : startMinute,
      endMinute: _allDay ? null : endMinute,
      notes: _notes.text,
      place: _place.toPlace(),
      weeklyRule: _weekly
          ? WeeklyEventRule(
              weekdays: _weekdays,
              intervalWeeks: intervalWeeks!,
              endsOn: _hasRecurrenceEnd ? _recurrenceEnd : null,
            )
          : null,
      exceptions: initial?.exceptions ?? const [],
      createdAt: initial?.createdAt ?? now,
      updatedAt: now,
    );

    var saved = false;
    try {
      saved = await widget.onSave(event);
    } catch (_) {
      saved = false;
    }
    if (!mounted) return;
    if (!saved) {
      Sfx.instance.play('boing');
      setState(() {
        _saving = false;
        _error = 'Couldn’t save this event locally. Try again.';
      });
      return;
    }
    Sfx.instance.play('streak');
    HapticFeedback.mediumImpact();
    if (Navigator.of(context).canPop()) Navigator.of(context).pop(event);
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
              _editorHeader(
                context,
                widget.initialEvent == null ? 'ADD AN EVENT' : 'EDIT EVENT',
              ),
              const SizedBox(height: 6),
              _sectionLabel('EVENT'),
              const SizedBox(height: 7),
              TextField(
                key: const ValueKey('daybook-event-title'),
                controller: _title,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() => _error = null),
                style: _inputStyle,
                decoration: _fieldDecoration('TITLE'),
              ),
              const SizedBox(height: 7),
              TextField(
                key: const ValueKey('daybook-event-notes'),
                controller: _notes,
                minLines: 2,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                style: _inputStyle,
                decoration: _fieldDecoration('NOTES'),
              ),
              const SizedBox(height: 10),
              _toggleTile(
                key: const ValueKey('daybook-event-all-day'),
                title: 'ALL DAY',
                subtitle: 'Keep this event above the timed day.',
                value: _allDay,
                onChanged: _setAllDay,
              ),
              const SizedBox(height: 12),
              _sectionLabel('WHEN'),
              const SizedBox(height: 7),
              _PickerPair(
                first: _PickerButton(
                  key: const ValueKey('daybook-event-start-date'),
                  label: 'START DATE',
                  value: _formatDate(_startDate),
                  icon: Icons.calendar_today_outlined,
                  onTap: () => _pickDate(_EventDateField.start),
                ),
                second: _PickerButton(
                  key: const ValueKey('daybook-event-end-date'),
                  label: _allDay ? 'END DATE · EXCLUSIVE' : 'END DATE',
                  value: _formatDate(_endDate),
                  icon: Icons.event_outlined,
                  onTap: () => _pickDate(_EventDateField.end),
                ),
              ),
              if (!_allDay) ...[
                const SizedBox(height: 7),
                _PickerPair(
                  first: _PickerButton(
                    key: const ValueKey('daybook-event-start-time'),
                    label: 'START TIME',
                    value: _formatTime(_startTime),
                    icon: Icons.schedule_outlined,
                    onTap: () => _pickTime(start: true),
                  ),
                  second: _PickerButton(
                    key: const ValueKey('daybook-event-end-time'),
                    label: 'END TIME',
                    value: _formatTime(_endTime),
                    icon: Icons.schedule_outlined,
                    onTap: () => _pickTime(start: false),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              _toggleTile(
                key: const ValueKey('daybook-event-weekly'),
                title: 'REPEAT WEEKLY',
                subtitle: 'Use the same days each interval.',
                value: _weekly,
                onChanged: (value) => setState(() {
                  _weekly = value;
                  _error = null;
                }),
              ),
              if (_weekly) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (var weekday = 1; weekday <= 7; weekday++)
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: weekday == 7 ? 0 : 4),
                          child: _WeekdayChip(
                            key: ValueKey('daybook-event-weekday-$weekday'),
                            label: _weekdayLabels[weekday - 1],
                            selected: _weekdays.contains(weekday),
                            onTap: () => setState(() {
                              _weekdays.contains(weekday)
                                  ? _weekdays.remove(weekday)
                                  : _weekdays.add(weekday);
                              _error = null;
                            }),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 7),
                TextField(
                  key: const ValueKey('daybook-event-interval'),
                  controller: _interval,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: _inputStyle,
                  decoration: _fieldDecoration('INTERVAL WEEKS'),
                ),
                const SizedBox(height: 7),
                _toggleTile(
                  key: const ValueKey('daybook-event-has-recurrence-end'),
                  title: 'REPEAT UNTIL',
                  subtitle: _hasRecurrenceEnd
                      ? _formatDate(_recurrenceEnd)
                      : 'No end date',
                  value: _hasRecurrenceEnd,
                  onChanged: (value) => setState(() {
                    _hasRecurrenceEnd = value;
                    _error = null;
                  }),
                ),
                if (_hasRecurrenceEnd) ...[
                  const SizedBox(height: 7),
                  _PickerButton(
                    key: const ValueKey('daybook-event-recurrence-end'),
                    label: 'LAST DATE',
                    value: _formatDate(_recurrenceEnd),
                    icon: Icons.event_available_outlined,
                    onTap: () => _pickDate(_EventDateField.recurrenceEnd),
                  ),
                ],
              ],
              const SizedBox(height: 13),
              _sectionLabel('PLACE · OPTIONAL'),
              const SizedBox(height: 7),
              DaybookPlaceFields(
                controller: _place,
                keyPrefix: 'daybook-event-place',
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  key: const ValueKey('daybook-event-error'),
                  style: Type.body.copyWith(
                    fontSize: 12,
                    color: Palette.danger,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              _SaveButton(
                key: const ValueKey('daybook-event-save'),
                saving: _saving,
                label: widget.initialEvent == null
                    ? 'KEEP THIS EVENT'
                    : 'KEEP CHANGES',
                onTap: _save,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

enum _EventDateField { start, end, recurrenceEnd }

Widget _editorHeader(BuildContext context, String title) => Row(
  children: [
    Expanded(
      child: Text(
        title,
        style: Type.label.copyWith(fontSize: 12, color: Palette.xpLight),
      ),
    ),
    IconButton(
      tooltip: 'Close',
      onPressed: () => Navigator.of(context).maybePop(),
      icon: const Icon(Icons.close_rounded, color: Palette.textLo),
    ),
  ],
);

Widget _sectionLabel(String label) => Text(
  label,
  style: Type.label.copyWith(
    fontSize: Type.minLabel,
    letterSpacing: 1.5,
    color: Palette.textLo,
  ),
);

Widget _toggleTile({
  required Key key,
  required String title,
  required String subtitle,
  required bool value,
  required ValueChanged<bool> onChanged,
}) => Material(
  color: Palette.glassFill,
  borderRadius: BorderRadius.circular(10),
  child: SwitchListTile.adaptive(
    key: key,
    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    activeTrackColor: Palette.xp.withValues(alpha: 0.52),
    title: Text(
      title,
      style: Type.label.copyWith(
        fontSize: Type.minLabel,
        color: Palette.textHi,
      ),
    ),
    subtitle: Text(
      subtitle,
      style: Type.body.copyWith(fontSize: 11.5, color: Palette.textLo),
    ),
    value: value,
    onChanged: onChanged,
  ),
);

class _WeekdayChip extends StatelessWidget {
  const _WeekdayChip({
    super.key,
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
        constraints: const BoxConstraints(minHeight: 44, minWidth: 38),
        alignment: Alignment.center,
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
                    maxLines: 2,
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

class _PickerPair extends StatelessWidget {
  const _PickerPair({required this.first, required this.second});

  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final textScale = MediaQuery.textScalerOf(context).scale(1);
      if (constraints.maxWidth < 340 || textScale > 1.35) {
        return Column(children: [first, const SizedBox(height: 7), second]);
      }
      return Row(
        children: [
          Expanded(child: first),
          const SizedBox(width: 7),
          Expanded(child: second),
        ],
      );
    },
  );
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({
    super.key,
    required this.saving,
    required this.label,
    required this.onTap,
  });

  final bool saving;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: !saving,
    label: saving ? 'Saving event' : label.toLowerCase(),
    child: InkWell(
      onTap: saving ? null : onTap,
      borderRadius: BorderRadius.circular(9),
      child: Opacity(
        opacity: saving ? 0.55 : 1,
        child: GoldSurface(
          cut: 9,
          glow: false,
          textured: false,
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Text(
              saving ? 'SAVING…' : label,
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
  );
}

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

const _weekdayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
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
