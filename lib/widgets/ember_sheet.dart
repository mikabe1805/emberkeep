import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio.dart';
import '../models.dart';
import '../tokens.dart';
import 'glass.dart';

/// Where the sheet is being opened from — drives smart defaults.
enum EmberSurface { board, goal, tomorrow }

class EmberSheetConfig {
  const EmberSheetConfig({
    this.surface = EmberSurface.board,
    this.defaultStat,
    this.goalTitle,
    this.lockStat = false,
    this.accent,
  });

  final EmberSurface surface;

  /// Pre-lit life domain. Inside a goal this is the goal's domain.
  final Stat? defaultStat;

  /// Stamped on the built quest (forging inside a goal).
  final String? goalTitle;

  /// Inside a goal the domain is inherited — hide the "this trains" picker.
  final bool lockStat;

  final Color? accent;
}

/// Guess the life domain from a quest's title (always overridable under More).
/// Falls back to Home — the same default the old quick-add used.
Stat guessStat(String title) {
  final t = title.toLowerCase();
  bool has(List<String> words) => words.any(t.contains);
  if (has(const [
    'run', 'jog', 'gym', 'walk', 'stretch', 'push-up', 'pushup', 'workout',
    'lift', 'yoga', 'exercise', 'steps', 'cardio', 'plank', 'squat'
  ])) {
    return Stat.str; // BODY
  }
  if (has(const [
    'water', 'sleep', 'meal', 'eat', 'cook', 'skin', 'med', 'pill', 'floss',
    'brush', 'plant', 'pet', 'dog', 'cat', 'shower', 'hydrate', 'vitamin',
    'breathe', 'rest'
  ])) {
    return Stat.vit; // CARE
  }
  if (has(const [
    'read', 'book', 'learn', 'study', 'journal', 'reflect', 'meditate',
    'language', 'course', 'note', 'chapter', 'page'
  ])) {
    return Stat.intl; // MIND
  }
  if (has(const [
    'work', 'code', 'write', 'practice', 'project', 'design', 'draft',
    'email', 'client', 'focus', 'deep work', 'side project', 'portfolio'
  ])) {
    return Stat.foc; // CRAFT
  }
  if (has(const [
    'call', 'text', 'friend', 'family', 'reach out', 'visit', 'message',
    'date', 'hang', 'check in', 'partner', 'mom', 'dad'
  ])) {
    return Stat.soc; // PEOPLE
  }
  return Stat.dis; // HOME (clean / laundry / dishes / tidy / money / fallback)
}

/// The ONE way to make a quest, everywhere (board + goal + planner). Opens as
/// a near-empty card; advanced options hide behind "More". Returns the built
/// [Quest], or null if dismissed.
Future<Quest?> showEmberSheet(BuildContext context, EmberSheetConfig config) {
  return showModalBottomSheet<Quest>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0xCC140C06),
    builder: (_) => _EmberSheet(config: config),
  );
}

enum _Freq { everyDay, weekdays, onceWeek, onceMonth, justToday }

const _freqLabels = {
  _Freq.everyDay: 'Every day',
  _Freq.weekdays: 'Weekdays',
  _Freq.onceWeek: 'Once a week',
  _Freq.onceMonth: 'Once a month',
  _Freq.justToday: 'Just today',
};

const _dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
const _dayNames = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
];

class _EmberSheet extends StatefulWidget {
  const _EmberSheet({required this.config});
  final EmberSheetConfig config;

  @override
  State<_EmberSheet> createState() => _EmberSheetState();
}

class _EmberSheetState extends State<_EmberSheet> {
  final _title = TextEditingController();
  _Freq _freq = _Freq.everyDay;
  late int _weekday; // for onceWeek
  late int _monthDay; // for onceMonth
  int _difficulty = 4; // Small=2 · A real effort=4 · A big push=7
  Stat? _statOverride;
  bool _dread = false;
  bool _rising = false;
  bool _timed = false;
  bool _allDay = false;
  int _minutes = 10;
  bool _more = false;

  bool get _isTomorrow => widget.config.surface == EmberSurface.tomorrow;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _weekday = now.weekday;
    _monthDay = now.day.clamp(1, 28);
    _title.addListener(() => setState(() {})); // live preview + CTA enable
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Stat get _effectiveStat =>
      widget.config.defaultStat != null && widget.config.lockStat
          ? widget.config.defaultStat!
          : _statOverride ??
              (widget.config.defaultStat ?? guessStat(_title.text));

  /// Per-completion XP for the chosen difficulty (mirrors engine.xpPreview at
  /// base streak, custom-damped — honest, updates live).
  int _xpFor(int diff) {
    var earned = 10 * (0.5 + diff * 0.25);
    if (_dread) earned *= 1.35;
    earned *= 0.85; // custom quests
    return earned.round();
  }

  String get _freqPreview {
    if (_isTomorrow) return 'tomorrow ★';
    switch (_freq) {
      case _Freq.everyDay:
        return 'every day';
      case _Freq.weekdays:
        return 'weekdays';
      case _Freq.onceWeek:
        return 'every ${_dayNames[_weekday - 1]}';
      case _Freq.onceMonth:
        return 'on the ${_monthDay}th';
      case _Freq.justToday:
        return 'just today';
    }
  }

  Quest _build() {
    final title = _title.text.trim();
    final now = DateTime.now();
    var schedule = QuestSchedule.daily;
    var weekdays = const <int>[];
    int? monthDay;
    DateTime? dueDate;

    if (_isTomorrow) {
      schedule = QuestSchedule.once;
      dueDate = DateTime(now.year, now.month, now.day + 1);
    } else {
      switch (_freq) {
        case _Freq.everyDay:
          schedule = QuestSchedule.daily;
        case _Freq.weekdays:
          schedule = QuestSchedule.daily;
          weekdays = const [1, 2, 3, 4, 5];
        case _Freq.onceWeek:
          schedule = QuestSchedule.weekly;
          weekdays = [_weekday];
        case _Freq.onceMonth:
          schedule = QuestSchedule.monthly;
          monthDay = _monthDay;
        case _Freq.justToday:
          schedule = QuestSchedule.once;
          dueDate = DateTime(now.year, now.month, now.day);
      }
    }

    final timed = _timed && !_allDay;
    return Quest(
      title: title,
      stat: _effectiveStat,
      difficulty: _difficulty.clamp(1, 8),
      custom: true,
      schedule: schedule,
      weekdays: weekdays,
      monthDay: monthDay,
      dueDate: dueDate,
      allDay: _allDay,
      verification: timed ? Verification.timer : Verification.honor,
      timerMinutes: timed ? _minutes : 0,
      dread: _dread,
      rising: _rising,
      goalTitle: widget.config.goalTitle,
      priority: _isTomorrow,
    );
  }

  void _submit() {
    if (_title.text.trim().isEmpty) return;
    Sfx.instance.play('streak');
    HapticFeedback.selectionClick();
    Navigator.of(context).pop(_build());
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.config.accent ?? _effectiveStat.color;
    final ready = _title.text.trim().isNotEmpty;
    return Padding(
      padding: EdgeInsets.only(
        left: 14,
        right: 14,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 14,
      ),
      child: GlassPanel(
        tint: const Color(0xF22A211D),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(_isTomorrow ? 'FOR TOMORROW' : 'NEW QUEST',
                      style: Type.label.copyWith(fontSize: 11)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    behavior: HitTestBehavior.opaque,
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.close,
                          size: 18, color: Palette.textLo),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('ember-title'),
                controller: _title,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => FocusScope.of(context).unfocus(),
                style: Type.body.copyWith(fontSize: 17, color: Palette.textHi),
                decoration: InputDecoration(
                  hintText: 'e.g. Drink a glass of water',
                  hintStyle:
                      Type.body.copyWith(fontSize: 17, color: Palette.textLo),
                  isDense: true,
                  filled: true,
                  fillColor: Palette.glassFill,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Palette.glassEdge),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Palette.glassEdge),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: accent.withValues(alpha: 0.7)),
                  ),
                ),
              ),
              if (!_isTomorrow) ...[
                const SizedBox(height: 14),
                Text('HOW OFTEN?', style: Type.label.copyWith(fontSize: 11)),
                const SizedBox(height: 8),
                _FreqChips(
                  value: _freq,
                  accent: accent,
                  onChanged: (f) => setState(() => _freq = f),
                ),
                AnimatedSize(
                  duration: Motion.quick,
                  curve: Motion.respond,
                  alignment: Alignment.topCenter,
                  child: _freqDetail(accent),
                ),
              ],
              const SizedBox(height: 12),
              // live preview line
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle, color: _effectiveStat.color),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                        ready
                            ? '${_title.text.trim()} · $_freqPreview'
                            : 'name it above',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Type.body.copyWith(
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            color: Palette.textLo)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _more = !_more),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('More', style: Type.label.copyWith(fontSize: 11)),
                      Icon(_more ? Icons.expand_less : Icons.expand_more,
                          size: 16, color: Palette.textLo),
                    ],
                  ),
                ),
              ),
              AnimatedSize(
                duration: Motion.quick,
                curve: Motion.respond,
                alignment: Alignment.topCenter,
                child: _more ? _moreBlock(accent) : const SizedBox.shrink(),
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: _Cta(
                  label: _freq == _Freq.justToday && !_isTomorrow
                      ? 'Add to today →'
                      : 'Add →',
                  dim: !ready,
                  onTap: _submit,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _freqDetail(Color accent) {
    if (_freq == _Freq.onceWeek) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('WHICH DAY?', style: Type.label.copyWith(fontSize: 10)),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var d = 1; d <= 7; d++)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      Sfx.instance.play('tick');
                      setState(() => _weekday = d);
                    },
                    child: Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _weekday == d
                            ? accent.withValues(alpha: 0.28)
                            : Palette.glassFill,
                        border: Border.all(
                            color: _weekday == d ? accent : Palette.glassEdge),
                      ),
                      child: Text(_dayLetters[d - 1],
                          style: Type.label.copyWith(
                              fontSize: 12,
                              color:
                                  _weekday == d ? accent : Palette.textLo)),
                    ),
                  ),
              ],
            ),
          ],
        ),
      );
    }
    if (_freq == _Freq.onceMonth) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          children: [
            Text('WHICH DAY?', style: Type.label.copyWith(fontSize: 10)),
            Expanded(
              child: Slider(
                value: _monthDay.toDouble(),
                min: 1,
                max: 28,
                divisions: 27,
                activeColor: accent,
                inactiveColor: const Color(0x1FF2CD93),
                onChanged: (v) => setState(() => _monthDay = v.round()),
              ),
            ),
            SizedBox(
              width: 28,
              child: Text('$_monthDay',
                  textAlign: TextAlign.right,
                  style: Type.numerals.copyWith(fontSize: 14, color: accent)),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _moreBlock(Color accent) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('HOW BIG A LIFT?',
                  style: Type.label.copyWith(fontSize: 11)),
              const Spacer(),
              Text('+${_xpFor(_difficulty)} XP each',
                  style: Type.numerals.copyWith(fontSize: 13, color: Palette.xp)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final step in const [
                ('Small', 2),
                ('A real effort', 4),
                ('A big push', 7),
              ])
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _difficulty = step.$2),
                    child: Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: _difficulty == step.$2
                            ? Palette.xpLight.withValues(alpha: 0.2)
                            : Colors.transparent,
                        border: Border.all(
                            color: Palette.xp.withValues(
                                alpha: _difficulty == step.$2 ? 0.7 : 0.25)),
                      ),
                      child: Text(step.$1,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Type.label.copyWith(
                              fontSize: 10,
                              color: _difficulty == step.$2
                                  ? Palette.xpLight
                                  : Palette.textLo)),
                    ),
                  ),
                ),
            ],
          ),
          if (!widget.config.lockStat) ...[
            const SizedBox(height: 14),
            Text('THIS TRAINS', style: Type.label.copyWith(fontSize: 11)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final s in Stat.values)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _statOverride = s),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: _effectiveStat == s
                            ? s.color.withValues(alpha: 0.22)
                            : Colors.transparent,
                        border: Border.all(
                            color: s.color.withValues(
                                alpha: _effectiveStat == s ? 0.8 : 0.3)),
                      ),
                      child: Text(s.abbr,
                          style: Type.label
                              .copyWith(fontSize: 10, color: s.color)),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          _Toggle(
            label: 'I have to push myself for this',
            sub: 'a little courage bonus',
            value: _dread,
            color: Palette.dread,
            onChanged: (v) => setState(() => _dread = v),
          ),
          _Toggle(
            label: 'Make it harder as I get stronger',
            sub: 'starts easy, grows with you',
            value: _rising,
            color: Palette.streak,
            onChanged: (v) => setState(() => _rising = v),
          ),
          _Toggle(
            label: 'Prove it with a timer',
            sub: 'a countdown confirms you did it',
            value: _timed,
            color: Palette.verify,
            enabled: !_allDay,
            onChanged: (v) => setState(() => _timed = v),
          ),
          if (_timed && !_allDay)
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 4),
              child: Wrap(
                spacing: 6,
                children: [
                  for (final m in const [1, 5, 10, 25, 45])
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _minutes = m),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: _minutes == m
                              ? Palette.verify.withValues(alpha: 0.18)
                              : Colors.transparent,
                          border: Border.all(
                              color: Palette.verify.withValues(
                                  alpha: _minutes == m ? 0.8 : 0.3)),
                        ),
                        child: Text('${m}m',
                            style: Type.label.copyWith(
                                fontSize: 11, color: Palette.verify)),
                      ),
                    ),
                ],
              ),
            ),
          _Toggle(
            label: 'A line I hold all day',
            sub: 'a "don\'t", checked at night',
            value: _allDay,
            color: Palette.unlock,
            enabled: !_timed,
            onChanged: (v) => setState(() => _allDay = v),
          ),
        ],
      ),
    );
  }
}

class _FreqChips extends StatelessWidget {
  const _FreqChips(
      {required this.value, required this.accent, required this.onChanged});
  final _Freq value;
  final Color accent;
  final ValueChanged<_Freq> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final f in _Freq.values) ...[
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                Sfx.instance.play('tick');
                onChanged(f);
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: value == f
                      ? accent.withValues(alpha: 0.22)
                      : Palette.glassFill,
                  border: Border.all(
                      color: value == f
                          ? accent.withValues(alpha: 0.8)
                          : Palette.glassEdge),
                ),
                child: Text(_freqLabels[f]!,
                    style: Type.label.copyWith(
                        fontSize: 11,
                        color: value == f ? accent : Palette.textLo)),
              ),
            ),
            const SizedBox(width: 7),
          ],
        ],
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.label,
    required this.sub,
    required this.value,
    required this.color,
    required this.onChanged,
    this.enabled = true,
  });
  final String label;
  final String sub;
  final bool value;
  final Color color;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: Type.body
                        .copyWith(fontSize: 13.5, color: Palette.textMid)),
                Text(sub,
                    style: Type.body.copyWith(
                        fontSize: 11, color: Palette.textLo)),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: color,
            activeTrackColor: color.withValues(alpha: 0.35),
            inactiveTrackColor: Palette.glassFill,
            onChanged: enabled ? onChanged : null,
          ),
        ],
      ),
    );
  }
}

class _Cta extends StatelessWidget {
  const _Cta({required this.label, required this.onTap, this.dim = false});
  final String label;
  final VoidCallback onTap;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: Motion.quick,
        opacity: dim ? 0.45 : 1,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF2CD93), Color(0xFFC08B4F)],
            ),
            boxShadow: dim
                ? const []
                : const [
                    BoxShadow(
                        color: Palette.honeyGlow,
                        blurRadius: 18,
                        offset: Offset(0, 6)),
                  ],
          ),
          child: Text(label,
              style: Type.label
                  .copyWith(fontSize: 12, color: const Color(0xFF3A2510))),
        ),
      ),
    );
  }
}
