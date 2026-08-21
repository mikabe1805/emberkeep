import 'package:flutter/material.dart';

import '../audio.dart';
import '../clock.dart';
import '../content/ladders.dart';
import '../models.dart';
import '../tokens.dart';
import 'domain_hint.dart';
import 'facets.dart';
import 'glass.dart';
import 'honey_button.dart';

/// Where the sheet is being opened from — drives smart defaults.
enum EmberSurface { board, goal, tomorrow }

class EmberSheetConfig {
  const EmberSheetConfig({
    this.surface = EmberSurface.board,
    this.defaultStat,
    this.goalTitle,
    this.lockStat = false,
    this.accent,
    this.defaultTitle,
    this.targetDay,
  });

  final EmberSurface surface;

  /// Pre-fills the quest name — e.g. when turning a journal reflection ("call
  /// Mom") straight into a quest (round-29 notes-with-consequence loop-closer).
  final String? defaultTitle;

  /// Explicit calendar target for a night-ledger "tomorrow". This matters
  /// after midnight, when tomorrow-after-sleep is the current calendar date.
  final DateTime? targetDay;

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
    'run',
    'jog',
    'gym',
    'walk',
    'stretch',
    'push-up',
    'pushup',
    'workout',
    'lift',
    'yoga',
    'exercise',
    'steps',
    'cardio',
    'plank',
    'squat',
  ])) {
    return Stat.str; // BODY
  }
  if (has(const [
    'water',
    'sleep',
    'meal',
    'eat',
    'cook',
    'skin',
    'med',
    'pill',
    'floss',
    'brush',
    'plant',
    'pet',
    'dog',
    'cat',
    'shower',
    'hydrate',
    'vitamin',
    'breathe',
    'rest',
  ])) {
    return Stat.vit; // CARE
  }
  if (has(const [
    'read',
    'book',
    'learn',
    'study',
    'journal',
    'reflect',
    'meditate',
    'language',
    'course',
    'note',
    'chapter',
    'page',
  ])) {
    return Stat.intl; // MIND
  }
  if (has(const [
    'work',
    'code',
    'write',
    'practice',
    'project',
    'design',
    'draft',
    'email',
    'client',
    'focus',
    'deep work',
    'side project',
    'portfolio',
  ])) {
    return Stat.foc; // CRAFT
  }
  if (has(const [
    'call',
    'text',
    'friend',
    'family',
    'reach out',
    'visit',
    'message',
    'date',
    'hang',
    'check in',
    'partner',
    'mom',
    'dad',
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

enum _Freq { everyDay, weekdays, onceWeek, onceMonth, justToday, untilDone }

const _freqLabels = {
  _Freq.everyDay: 'Every day',
  _Freq.weekdays: 'Certain days',
  _Freq.onceWeek: 'Once a week',
  _Freq.onceMonth: 'Once a month',
  _Freq.justToday: 'Just today',
  _Freq.untilDone: 'Until it’s done',
};

const _dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
const _dayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];
const _dayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Human label for a custom set of weekdays: "every day" / "weekdays" /
/// "weekends" / "Mon · Wed · Fri".
String _customDaysLabel(Set<int> days) {
  if (days.isEmpty || days.length == 7) return 'every day';
  if (days.length == 5 && !days.contains(6) && !days.contains(7)) {
    return 'weekdays';
  }
  if (days.length == 2 && days.contains(6) && days.contains(7)) {
    return 'weekends';
  }
  final sorted = days.toList()..sort();
  return sorted.map((d) => _dayShort[d - 1]).join(' · ');
}

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
  // for the "Certain days" custom pattern (e.g. a Mon/Wed/Fri habit); defaults
  // to the classic weekdays set so that preset is still one tap away.
  final Set<int> _customDays = {1, 2, 3, 4, 5};
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
    final now = Clock.now();
    _weekday = now.weekday;
    _monthDay = now.day.clamp(1, 28);
    _title.text = widget.config.defaultTitle ?? ''; // pre-fill (journal→quest)
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
      : _statOverride ?? (widget.config.defaultStat ?? guessStat(_title.text));

  /// Per-completion XP for the chosen difficulty (mirrors engine.xpPreview at
  /// base streak, custom-damped — honest, updates live).
  int _xpFor(int diff) {
    var earned = 10 * (0.5 + diff * 0.25);
    if (_dread) earned *= 1.35;
    earned *= 0.85; // custom quests
    return earned.round();
  }

  /// 1 -> "1st", 2 -> "2nd", 21 -> "21st", 11-13 -> "th" (never "21th").
  String _ordinal(int n) {
    if (n % 100 >= 11 && n % 100 <= 13) return '${n}th';
    switch (n % 10) {
      case 1:
        return '${n}st';
      case 2:
        return '${n}nd';
      case 3:
        return '${n}rd';
      default:
        return '${n}th';
    }
  }

  String get _freqPreview {
    if (_isTomorrow) return 'tomorrow ★';
    switch (_freq) {
      case _Freq.everyDay:
        return 'every day';
      case _Freq.weekdays:
        return _customDaysLabel(_customDays);
      case _Freq.onceWeek:
        return 'every ${_dayNames[_weekday - 1]}';
      case _Freq.onceMonth:
        return 'on the ${_ordinal(_monthDay)}';
      case _Freq.justToday:
        return 'just today';
      case _Freq.untilDone:
        return 'until it’s done';
    }
  }

  Quest _build() {
    final title = _title.text.trim();
    final now = Clock.now();
    var schedule = QuestSchedule.daily;
    var weekdays = const <int>[];
    int? monthDay;
    DateTime? dueDate;

    if (_isTomorrow) {
      schedule = QuestSchedule.once;
      final target = widget.config.targetDay;
      dueDate = target == null
          ? DateTime(now.year, now.month, now.day + 1)
          : DateTime(target.year, target.month, target.day);
    } else {
      switch (_freq) {
        case _Freq.everyDay:
          schedule = QuestSchedule.daily;
        case _Freq.weekdays:
          schedule = QuestSchedule.daily;
          // custom which-days; an empty set falls back to every day
          weekdays = _customDays.isEmpty
              ? const []
              : (_customDays.toList()..sort());
        case _Freq.onceWeek:
          schedule = QuestSchedule.weekly;
          weekdays = [_weekday];
        case _Freq.onceMonth:
          schedule = QuestSchedule.monthly;
          monthDay = _monthDay;
        case _Freq.justToday:
          schedule = QuestSchedule.once;
          dueDate = DateTime(now.year, now.month, now.day);
        case _Freq.untilDone:
          // a persistent to-do: no due date, so it lingers on the board every
          // day until completed (then rollover clears it) — never an overdue
          // scold, and covered by the one daily nudge like any open quest.
          schedule = QuestSchedule.once;
      }
    }

    final timed = _timed && !_allDay;
    // A rising quest whose title carries a number gets a real, visible
    // progression generated from it — without one, "grows with you" only
    // raised an invisible difficulty, which reads as a fake control.
    final ladder = _rising ? generatedLadder(title) : null;
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
      ladder: ladder,
      goalTitle: widget.config.goalTitle,
      priority: false,
      priorityDay: _isTomorrow
          ? Days.key(DateTime(now.year, now.month, now.day + 1))
          : null,
    );
  }

  void _submit() {
    if (_title.text.trim().isEmpty) return;
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
                  Text(
                    _isTomorrow ? 'FOR TOMORROW' : 'NEW QUEST',
                    style: Type.label.copyWith(fontSize: 11),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    behavior: HitTestBehavior.opaque,
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.close, size: 18, color: Palette.textLo),
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
                  hintStyle: Type.body.copyWith(
                    fontSize: 17,
                    color: Palette.textLo,
                  ),
                  isDense: true,
                  filled: true,
                  fillColor: Palette.glassFill,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
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
                    borderSide: BorderSide(
                      color: accent.withValues(alpha: 0.7),
                    ),
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
                  Transform.rotate(
                    angle: 0.785,
                    child: Container(
                      width: 7,
                      height: 7,
                      color: _effectiveStat.color,
                    ),
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
                        color: Palette.textLo,
                      ),
                    ),
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
                      Icon(
                        _more ? Icons.expand_less : Icons.expand_more,
                        size: 16,
                        color: Palette.textLo,
                      ),
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
    if (_freq == _Freq.weekdays) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('WHICH DAYS?', style: Type.label.copyWith(fontSize: 11)),
            const SizedBox(height: 6),
            _dayChoices(
              accent,
              selected: _customDays.contains,
              onTap: (d) => setState(() {
                // Keep at least one day selected — empty means every day.
                if (_customDays.contains(d)) {
                  if (_customDays.length > 1) _customDays.remove(d);
                } else {
                  _customDays.add(d);
                }
              }),
            ),
            const SizedBox(height: 6),
            Text(
              _customDaysLabel(_customDays),
              style: Type.body.copyWith(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: Palette.textLo,
              ),
            ),
          ],
        ),
      );
    }
    if (_freq == _Freq.onceWeek) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('WHICH DAY?', style: Type.label.copyWith(fontSize: 11)),
            const SizedBox(height: 6),
            _dayChoices(
              accent,
              selected: (d) => _weekday == d,
              onTap: (d) => setState(() => _weekday = d),
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
            Text('WHICH DAY?', style: Type.label.copyWith(fontSize: 11)),
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
              child: Text(
                '$_monthDay',
                textAlign: TextAlign.right,
                style: Type.numerals.copyWith(fontSize: 14, color: accent),
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _dayChoices(
    Color accent, {
    required bool Function(int day) selected,
    required ValueChanged<int> onTap,
  }) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var d = 1; d <= 7; d++)
          Semantics(
            button: true,
            selected: selected(d),
            label: _dayNames[d - 1],
            onTap: () {
              Sfx.instance.playMaterial(MaterialSound.glass);
              onTap(d);
            },
            child: GestureDetector(
              excludeFromSemantics: true,
              behavior: HitTestBehavior.opaque,
              onTap: () {
                Sfx.instance.playMaterial(MaterialSound.glass);
                onTap(d);
              },
              child: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: facetedDecoration(
                  cut: 8,
                  color: selected(d)
                      ? accent.withValues(alpha: 0.28)
                      : Palette.glassFill,
                  borderColor: selected(d) ? accent : Palette.glassEdge,
                ),
                child: Text(
                  _dayLetters[d - 1],
                  style: Type.label.copyWith(
                    fontSize: 12,
                    color: selected(d) ? accent : Palette.textLo,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _moreBlock(Color accent) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final textScale = MediaQuery.textScalerOf(context).scale(1);
              final stack = constraints.maxWidth < 340 || textScale > 1.15;
              final label = Text(
                'HOW BIG A LIFT?',
                style: Type.label.copyWith(fontSize: 11),
              );
              final value = Text(
                '+${_xpFor(_difficulty)} XP each',
                style: Type.numerals.copyWith(fontSize: 13, color: Palette.xp),
              );
              if (stack) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [label, const SizedBox(height: 3), value],
                );
              }
              return Row(children: [label, const Spacer(), value]);
            },
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final textScale = MediaQuery.textScalerOf(context).scale(1);
              final stack = constraints.maxWidth < 300 || textScale > 1.25;
              const steps = [
                ('Small', 2),
                ('A real effort', 4),
                ('A big push', 7),
              ];

              Widget option((String, int) step, {required EdgeInsets margin}) {
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _difficulty = step.$2),
                  child: Container(
                    width: double.infinity,
                    margin: margin,
                    constraints: const BoxConstraints(minHeight: 50),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    alignment: Alignment.center,
                    decoration: facetedDecoration(
                      cut: 8,
                      color: _difficulty == step.$2
                          ? Palette.xpLight.withValues(alpha: 0.2)
                          : Colors.transparent,
                      borderColor: Palette.xp.withValues(
                        alpha: _difficulty == step.$2 ? 0.7 : 0.25,
                      ),
                    ),
                    child: Text(
                      step.$1,
                      textAlign: TextAlign.center,
                      style: Type.label.copyWith(
                        fontSize: Type.minLabel,
                        color: _difficulty == step.$2
                            ? Palette.xpLight
                            : Palette.textLo,
                      ),
                    ),
                  ),
                );
              }

              if (stack) {
                return Column(
                  children: [
                    for (var i = 0; i < steps.length; i++)
                      option(
                        steps[i],
                        margin: EdgeInsets.only(
                          bottom: i == steps.length - 1 ? 0 : 6,
                        ),
                      ),
                  ],
                );
              }
              return Row(
                children: [
                  for (var i = 0; i < steps.length; i++)
                    Expanded(
                      child: option(
                        steps[i],
                        margin: EdgeInsets.only(
                          right: i == steps.length - 1 ? 0 : 6,
                        ),
                      ),
                    ),
                ],
              );
            },
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
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: facetedDecoration(
                        cut: 6,
                        color: _effectiveStat == s
                            ? s.color.withValues(alpha: 0.22)
                            : Colors.transparent,
                        borderColor: s.color.withValues(
                          alpha: _effectiveStat == s ? 0.8 : 0.3,
                        ),
                      ),
                      child: Text(
                        s.abbr,
                        style: Type.label.copyWith(
                          fontSize: Type.minLabel,
                          color: s.color,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            DomainHint(_effectiveStat),
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
          // The climb, spelled out. A number in the title becomes a real
          // ladder; without one only the payout grows, and the sheet says
          // which of the two the person is getting.
          if (_rising)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 2, 14, 6),
              child: ListenableBuilder(
                listenable: _title,
                builder: (context, _) {
                  final ladder = generatedLadder(_title.text.trim());
                  final numbers = ladder
                      ?.map((rung) => RegExp(r'\d+').firstMatch(rung)?.group(0))
                      .whereType<String>()
                      .join(' → ');
                  return Text(
                    ladder == null || numbers == null || numbers.isEmpty
                        ? 'no number in the title yet — the reward grows, the words stay'
                        : 'climbs $numbers as you hold it',
                    key: const ValueKey('ember-rising-preview'),
                    style: Type.body.copyWith(
                      fontSize: 11.5,
                      fontStyle: FontStyle.italic,
                      color: Palette.textLo,
                    ),
                  );
                },
              ),
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
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: facetedDecoration(
                          cut: 6,
                          color: _minutes == m
                              ? Palette.verify.withValues(alpha: 0.18)
                              : Colors.transparent,
                          borderColor: Palette.verify.withValues(
                            alpha: _minutes == m ? 0.8 : 0.3,
                          ),
                        ),
                        child: Text(
                          '${m}m',
                          style: Type.label.copyWith(
                            fontSize: 11,
                            color: Palette.verify,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          _Toggle(
            label: 'Check at day’s end',
            sub: 'for an all-day goal or boundary',
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
  const _FreqChips({
    required this.value,
    required this.accent,
    required this.onChanged,
  });
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
                Sfx.instance.playMaterial(MaterialSound.glass);
                onChanged(f);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 7,
                ),
                decoration: facetedDecoration(
                  cut: 7,
                  color: value == f
                      ? accent.withValues(alpha: 0.22)
                      : Palette.glassFill,
                  borderColor: value == f
                      ? accent.withValues(alpha: 0.8)
                      : Palette.glassEdge,
                ),
                child: Text(
                  _freqLabels[f]!,
                  style: Type.label.copyWith(
                    fontSize: 11,
                    color: value == f ? accent : Palette.textLo,
                  ),
                ),
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
                Text(
                  label,
                  style: Type.body.copyWith(
                    fontSize: 13.5,
                    color: Palette.textMid,
                  ),
                ),
                Text(
                  sub,
                  style: Type.body.copyWith(
                    fontSize: 11,
                    color: Palette.textLo,
                  ),
                ),
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
    return HoneyButton(label: label, onTap: onTap, enabled: !dim, glow: !dim);
  }
}
