import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio.dart';
import '../engine.dart';
import '../models.dart';
import '../tokens.dart';
import '../widgets/glass.dart';
import '../widgets/particles.dart';

/// The Oath Wizard (round-7): goal creation as ceremony, not a form.
/// Step 1 THE AMBITION — name what you want to be able to do; choose
/// BECOME (ongoing practice) or ACHIEVE (a finish line). Step 2 THE PATH —
/// forge the quests that get you there, each scheduled to its days.
/// Step 3 THE OATH — see the whole journey, then swear to it.
class GoalWizardScreen extends StatefulWidget {
  const GoalWizardScreen({
    super.key,
    required this.state,
    required this.onAdd,
  });

  final GameState state;
  final bool Function(Quest) onAdd;

  @override
  State<GoalWizardScreen> createState() => _GoalWizardScreenState();
}

class _DraftQuest {
  _DraftQuest({
    required this.title,
    required this.difficulty,
    required this.schedule,
    required this.weekdays,
    this.monthDay,
    this.allDay = false,
    this.timerMinutes = 0,
    this.dread = false,
    this.rising = false,
  });

  final String title;
  final int difficulty;
  final QuestSchedule schedule;
  final List<int> weekdays;
  final int? monthDay;
  final bool allDay;
  final int timerMinutes;
  final bool dread;
  final bool rising;

  String get scheduleLabel {
    const dayNames = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    return switch (schedule) {
      QuestSchedule.daily => weekdays.isEmpty
          ? 'EVERY DAY'
          : weekdays.map((d) => dayNames[d - 1]).join(' · '),
      QuestSchedule.weekly => weekdays.isEmpty
          ? 'ONCE A WEEK'
          : 'WEEKLY · ${dayNames[weekdays.first - 1]}',
      QuestSchedule.monthly =>
        monthDay == null ? 'ONCE A MONTH' : 'MONTHLY · DAY $monthDay',
      QuestSchedule.once => 'ONE TIME',
    };
  }

  /// Rough completions per week, for the oath's weekly XP estimate.
  double get perWeek => switch (schedule) {
        QuestSchedule.daily => weekdays.isEmpty ? 7 : weekdays.length.toDouble(),
        QuestSchedule.weekly => 1,
        QuestSchedule.monthly => 0.25,
        QuestSchedule.once => 0,
      };
}

class _GoalWizardScreenState extends State<GoalWizardScreen> {
  int _step = 0;
  bool _sealing = false;

  // step 1 — the ambition
  final _name = TextEditingController();
  GoalKind _kind = GoalKind.become;
  Stat _stat = Stat.vit;
  String? _error;

  // step 2 — the path
  final List<_DraftQuest> _drafts = [];

  // step 3 — the oath
  int _target = 25; // achieve goals pick a finish line; become starts at 25

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _next() {
    if (_step == 0 && _name.text.trim().isEmpty) {
      Sfx.instance.play('boing');
      setState(() => _error = 'name it — even roughly');
      return;
    }
    if (_step == 1 && _drafts.isEmpty) {
      Sfx.instance.play('boing');
      return;
    }
    Sfx.instance.play('tick');
    HapticFeedback.selectionClick();
    setState(() => _step++);
  }

  Future<void> _swear() async {
    final name = _name.text.trim();
    final created = widget.state.addGoal(Goal(
      title: name,
      stat: _stat,
      kind: _kind,
      target: _kind == GoalKind.achieve ? _target : 25,
    ));
    if (!created) {
      Sfx.instance.play('boing');
      setState(() {
        _step = 0;
        _error = 'you’re already on this path';
      });
      return;
    }
    for (final d in _drafts) {
      widget.onAdd(Quest(
        title: d.title,
        stat: _stat,
        difficulty: d.difficulty.clamp(1, 8),
        schedule: d.schedule,
        weekdays: d.weekdays,
        monthDay: d.monthDay,
        allDay: d.allDay,
        verification:
            d.timerMinutes > 0 ? Verification.timer : Verification.honor,
        timerMinutes: d.timerMinutes,
        dread: d.dread,
        rising: d.rising,
        custom: true,
        goalTitle: name,
      ));
    }
    // the seal: a held beat of gold before returning to the world
    Sfx.instance.play('levelup');
    HapticFeedback.heavyImpact();
    setState(() => _sealing = true);
    await Future.delayed(const Duration(milliseconds: 1400));
    if (mounted) Navigator.of(context).pop(true);
  }

  int get _weeklyXp {
    var xp = 0.0;
    for (final d in _drafts) {
      var earned = 10 * (0.5 + d.difficulty * 0.25) * GameState.customDamp;
      if (d.dread) earned *= 1.35;
      xp += earned * d.perWeek;
    }
    return xp.round();
  }

  @override
  Widget build(BuildContext context) {
    return WarmBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            Sfx.instance.play('tick');
                            if (_step == 0) {
                              Navigator.of(context).pop(false);
                            } else {
                              setState(() => _step--);
                            }
                          },
                          child: const Icon(Icons.arrow_back,
                              size: 20, color: Palette.textLo),
                        ),
                        const Spacer(),
                        for (var i = 0; i < 3; i++)
                          AnimatedContainer(
                            duration: Motion.settle,
                            width: i == _step ? 22 : 8,
                            height: 8,
                            margin: const EdgeInsets.only(left: 5),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              color: i <= _step
                                  ? Palette.xpLight
                                  : Palette.glassEdge,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: Motion.settle,
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: SlideTransition(
                            position: Tween(
                                    begin: const Offset(0.06, 0),
                                    end: Offset.zero)
                                .animate(anim),
                            child: child,
                          ),
                        ),
                        child: switch (_step) {
                          0 => _ambition(),
                          1 => _path(),
                          _ => _oath(),
                        },
                      ),
                    ),
                  ],
                ),
              ),
              if (_sealing) _Seal(stat: _stat, name: _name.text.trim()),
            ],
          ),
        ),
      ),
    );
  }

  // ── STEP 1 · THE AMBITION ─────────────────────────────────────────
  Widget _ambition() {
    return ListView(
      key: const ValueKey(0),
      children: [
        const SizedBox(height: 18),
        Text('THE AMBITION', style: Type.label.copyWith(fontSize: 11)),
        const SizedBox(height: 8),
        Text('What do you want\nto be able to do?',
            style: Type.display.copyWith(fontSize: 30, height: 1.15)),
        const SizedBox(height: 16),
        TextField(
          controller: _name,
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          style: Type.display.copyWith(fontSize: 19, color: Palette.textHi),
          decoration: InputDecoration(
            hintText: 'maintain healthy skin…',
            hintStyle: Type.display.copyWith(
                fontSize: 19, color: Palette.textLo.withValues(alpha: 0.6)),
            errorText: _error,
            errorStyle: Type.body
                .copyWith(fontSize: 11, color: const Color(0xFFE89090)),
            filled: true,
            fillColor: Palette.glassFill,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Palette.glassEdge),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            for (final k in GoalKind.values) ...[
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Sfx.instance.play('tick');
                    setState(() => _kind = k);
                  },
                  child: AnimatedContainer(
                    duration: Motion.quick,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: _kind == k
                          ? Palette.xpLight.withValues(alpha: 0.14)
                          : Palette.glassFill,
                      border: Border.all(
                        color: _kind == k
                            ? Palette.xpLight.withValues(alpha: 0.7)
                            : Palette.glassEdge,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          k == GoalKind.become
                              ? Icons.all_inclusive
                              : Icons.flag,
                          size: 18,
                          color: _kind == k
                              ? Palette.xpLight
                              : Palette.textLo,
                        ),
                        const SizedBox(height: 6),
                        Text(k.label,
                            style: Type.label.copyWith(
                                fontSize: 11,
                                color: _kind == k
                                    ? Palette.xpLight
                                    : Palette.textMid)),
                        Text(k.blurb,
                            style: Type.body.copyWith(
                                fontSize: 11, color: Palette.textLo)),
                      ],
                    ),
                  ),
                ),
              ),
              if (k != GoalKind.values.last) const SizedBox(width: 10),
            ],
          ],
        ),
        const SizedBox(height: 20),
        Text('THIS SHAPES…', style: Type.label.copyWith(fontSize: 11)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            for (final s in Stat.values)
              GestureDetector(
                onTap: () {
                  Sfx.instance.play('stat_${s.index}');
                  setState(() => _stat = s);
                },
                child: AnimatedContainer(
                  duration: Motion.quick,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: _stat == s
                        ? s.color.withValues(alpha: 0.22)
                        : Colors.transparent,
                    border: Border.all(
                        color:
                            s.color.withValues(alpha: _stat == s ? 0.9 : 0.3)),
                    boxShadow: _stat == s
                        ? [
                            BoxShadow(
                                color: s.color.withValues(alpha: 0.3),
                                blurRadius: 10)
                          ]
                        : const [],
                  ),
                  child: Text('${s.abbr} · ${s.label}',
                      style:
                          Type.label.copyWith(fontSize: 11, color: s.color)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 28),
        Center(child: _CtaButton(label: 'FORGE THE PATH →', onTap: _next)),
      ],
    );
  }

  // ── STEP 2 · THE PATH ─────────────────────────────────────────────
  Widget _path() {
    return ListView(
      key: const ValueKey(1),
      children: [
        const SizedBox(height: 18),
        Text('THE PATH', style: Type.label.copyWith(fontSize: 11)),
        const SizedBox(height: 8),
        Text('What gets you there?',
            style: Type.display.copyWith(fontSize: 28)),
        const SizedBox(height: 4),
        Text('small repeatable quests — scheduled to their days',
            style: Type.body.copyWith(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: Palette.textLo)),
        const SizedBox(height: 14),
        // the path so far — each quest a node walking toward the flag
        if (_drafts.isNotEmpty)
          GlassPanel(
            child: Column(
              children: [
                for (var i = 0; i < _drafts.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Column(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle, color: _stat.color),
                            ),
                            if (i < _drafts.length - 1)
                              Container(
                                  width: 2,
                                  height: 14,
                                  color:
                                      _stat.color.withValues(alpha: 0.35)),
                          ],
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_drafts[i].title,
                                  style: Type.body.copyWith(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Palette.textHi)),
                              Text(
                                  '${_drafts[i].scheduleLabel} · d${_drafts[i].difficulty}'
                                  '${_drafts[i].allDay ? " · ALL-DAY LINE" : ""}'
                                  '${_drafts[i].timerMinutes > 0 ? " · ${_drafts[i].timerMinutes}M PROOF" : ""}',
                                  style: Type.label.copyWith(fontSize: 11)),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setState(() => _drafts.removeAt(i)),
                          child: const Icon(Icons.close,
                              size: 15, color: Palette.textLo),
                        ),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    const SizedBox(width: 1),
                    Icon(Icons.flag, size: 15, color: _stat.color),
                    const SizedBox(width: 9),
                    Text(_name.text.trim(),
                        style: Type.body.copyWith(
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            color: _stat.color)),
                  ],
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        _QuestForge(stat: _stat, onAdd: (d) => setState(() => _drafts.add(d))),
        const SizedBox(height: 22),
        Center(
          child: _CtaButton(
            label: _drafts.isEmpty
                ? 'ADD A QUEST FIRST'
                : 'READY THE OATH →',
            dim: _drafts.isEmpty,
            onTap: _next,
          ),
        ),
      ],
    );
  }

  // ── STEP 3 · THE OATH ─────────────────────────────────────────────
  Widget _oath() {
    return ListView(
      key: const ValueKey(2),
      children: [
        const SizedBox(height: 18),
        Text('THE OATH', style: Type.label.copyWith(fontSize: 11)),
        const SizedBox(height: 14),
        GlassPanel(
          blur: true,
          glow: true,
          padding: const EdgeInsets.all(22),
          child: Column(
            children: [
              Icon(
                  _kind == GoalKind.become
                      ? Icons.all_inclusive
                      : Icons.flag,
                  size: 26,
                  color: _stat.color),
              const SizedBox(height: 8),
              Text('I will',
                  style: Type.body.copyWith(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: Palette.textLo)),
              Text(_name.text.trim(),
                  textAlign: TextAlign.center,
                  style: Type.display
                      .copyWith(fontSize: 26, color: _stat.color)),
              const SizedBox(height: 12),
              Text(
                  _kind == GoalKind.become
                      ? 'an ongoing practice — first milestone at 25, and the path keeps going'
                      : 'a finish line — done after $_target quest completions',
                  textAlign: TextAlign.center,
                  style: Type.body.copyWith(
                      fontSize: 13, color: Palette.textMid)),
              if (_kind == GoalKind.achieve) ...[
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final t in const [5, 10, 25, 50]) ...[
                      GestureDetector(
                        onTap: () => setState(() => _target = t),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: _target == t
                                ? _stat.color.withValues(alpha: 0.2)
                                : Colors.transparent,
                            border: Border.all(
                                color: _stat.color.withValues(
                                    alpha: _target == t ? 0.8 : 0.3)),
                          ),
                          child: Text('$t',
                              style: Type.numerals.copyWith(
                                  fontSize: 12, color: _stat.color)),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                  ],
                ),
              ],
              const SizedBox(height: 14),
              const Divider(color: Palette.glassEdge, height: 1),
              const SizedBox(height: 12),
              for (final d in _drafts)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Icon(Icons.circle, size: 6, color: _stat.color),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(d.title,
                            style: Type.body.copyWith(
                                fontSize: 13, color: Palette.textHi)),
                      ),
                      Text(d.scheduleLabel,
                          style: Type.label.copyWith(fontSize: 11)),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              Text('this path earns ~$_weeklyXp XP a week',
                  style: Type.numerals
                      .copyWith(fontSize: 13, color: Palette.xpLight)),
            ],
          ),
        ),
        const SizedBox(height: 26),
        Center(child: _CtaButton(label: '⚔ SWEAR THE OATH', onTap: _swear)),
        const SizedBox(height: 10),
        Center(
          child: Text('your future self is watching, kindly',
              style: Type.body.copyWith(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: Palette.textLo)),
        ),
      ],
    );
  }
}

/// Inline quest forge for the path step: title, difficulty, schedule with
/// day-of-week / day-of-month pickers, all-day & timer-proof options.
class _QuestForge extends StatefulWidget {
  const _QuestForge({required this.stat, required this.onAdd});
  final Stat stat;
  final void Function(_DraftQuest) onAdd;

  @override
  State<_QuestForge> createState() => _QuestForgeState();
}

class _QuestForgeState extends State<_QuestForge> {
  final _title = TextEditingController();
  double _difficulty = 3;
  QuestSchedule _schedule = QuestSchedule.daily;
  final Set<int> _weekdays = {};
  int _monthDay = 1;
  bool _allDay = false;
  bool _timed = false;
  bool _dread = false;
  bool _rising = false;
  int _minutes = 10;

  static const _dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _add() {
    final t = _title.text.trim();
    if (t.isEmpty) {
      Sfx.instance.play('boing');
      return;
    }
    Sfx.instance.play('streak');
    HapticFeedback.selectionClick();
    widget.onAdd(_DraftQuest(
      title: t,
      difficulty: _difficulty.round(),
      schedule: _allDay ? QuestSchedule.daily : _schedule,
      weekdays:
          _schedule == QuestSchedule.monthly ? const [] : _weekdays.toList(),
      monthDay: _schedule == QuestSchedule.monthly ? _monthDay : null,
      allDay: _allDay,
      timerMinutes: _timed && !_allDay ? _minutes : 0,
      dread: _dread,
      rising: _rising,
    ));
    setState(() {
      _title.clear();
      _weekdays.clear();
      _allDay = false;
      _timed = false;
      _dread = false;
      _rising = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final schedulable = !_allDay;
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('FORGE A QUEST FOR THIS PATH',
              style: Type.label.copyWith(fontSize: 11)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('forge-title'),
                  controller: _title,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _add(),
                  style: Type.body
                      .copyWith(fontSize: 14, color: Palette.textHi),
                  decoration: InputDecoration(
                    hintText: 'e.g. Morning skincare',
                    hintStyle: Type.body
                        .copyWith(fontSize: 14, color: Palette.textLo),
                    isDense: true,
                    filled: true,
                    fillColor: Palette.glassFill,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Palette.glassEdge),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                key: const Key('forge-add'),
                onTap: _add,
                child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFF2CD93), Color(0xFFC08B4F)],
                    ),
                  ),
                  child: const Icon(Icons.add,
                      size: 18, color: Color(0xFF3A2510)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text('d${_difficulty.round()}',
                  style: Type.label.copyWith(fontSize: 11, color: Palette.xp)),
              Expanded(
                child: Slider(
                  value: _difficulty,
                  min: 1,
                  max: 8,
                  divisions: 7,
                  activeColor: Palette.xp,
                  inactiveColor: const Color(0x1FF2CD93),
                  onChanged: (v) => setState(() => _difficulty = v),
                ),
              ),
            ],
          ),
          if (schedulable) ...[
            Row(
              children: [
                for (final s in const [
                  QuestSchedule.daily,
                  QuestSchedule.weekly,
                  QuestSchedule.monthly
                ]) ...[
                  GestureDetector(
                    onTap: () => setState(() => _schedule = s),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: _schedule == s
                            ? Palette.xpLight.withValues(alpha: 0.2)
                            : Colors.transparent,
                        border: Border.all(
                            color: Palette.xp.withValues(
                                alpha: _schedule == s ? 0.7 : 0.25)),
                      ),
                      child: Text(s.label,
                          style: Type.label.copyWith(
                              fontSize: 11,
                              color: _schedule == s
                                  ? Palette.xpLight
                                  : Palette.textLo)),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
            const SizedBox(height: 8),
            if (_schedule != QuestSchedule.monthly) ...[
              Text(
                  _schedule == QuestSchedule.daily
                      ? 'ON THESE DAYS (empty = every day)'
                      : 'ANCHOR DAY (empty = any day that week)',
                  style: Type.label.copyWith(fontSize: 11)),
              const SizedBox(height: 6),
              Row(
                children: [
                  for (var d = 1; d <= 7; d++)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: GestureDetector(
                        onTap: () {
                          Sfx.instance.play('tick');
                          setState(() {
                            if (_schedule == QuestSchedule.weekly) {
                              // weekly anchors to a single day
                              _weekdays
                                ..clear()
                                ..add(d);
                            } else if (!_weekdays.remove(d)) {
                              _weekdays.add(d);
                            }
                          });
                        },
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _weekdays.contains(d)
                                ? widget.stat.color.withValues(alpha: 0.28)
                                : Palette.glassFill,
                            border: Border.all(
                              color: _weekdays.contains(d)
                                  ? widget.stat.color
                                  : Palette.glassEdge,
                            ),
                          ),
                          child: Center(
                            child: Text(_dayLetters[d - 1],
                                style: Type.label.copyWith(
                                    fontSize: 11,
                                    color: _weekdays.contains(d)
                                        ? widget.stat.color
                                        : Palette.textLo)),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  Text('ON DAY', style: Type.label.copyWith(fontSize: 11)),
                  Expanded(
                    child: Slider(
                      value: _monthDay.toDouble(),
                      min: 1,
                      max: 28,
                      divisions: 27,
                      activeColor: widget.stat.color,
                      inactiveColor: const Color(0x1FF2CD93),
                      onChanged: (v) =>
                          setState(() => _monthDay = v.round()),
                    ),
                  ),
                  Text('$_monthDay',
                      style: Type.numerals.copyWith(
                          fontSize: 12, color: widget.stat.color)),
                ],
              ),
            ],
            const SizedBox(height: 4),
          ],
          Row(
            children: [
              Expanded(
                child: _MiniToggle(
                  label: 'all-day line 🌙',
                  value: _allDay,
                  color: Palette.unlock,
                  onChanged: (v) => setState(() => _allDay = v),
                ),
              ),
              if (!_allDay)
                Expanded(
                  child: _MiniToggle(
                    label: 'timer proof',
                    value: _timed,
                    color: Palette.verify,
                    onChanged: (v) => setState(() => _timed = v),
                  ),
                ),
            ],
          ),
          _MiniToggle(
            label: 'I dread this (counts extra)',
            value: _dread,
            color: Palette.dread,
            onChanged: (v) => setState(() => _dread = v),
          ),
          _MiniToggle(
            label: 'rising difficulty 📈 (training, not maintenance)',
            value: _rising,
            color: Palette.streak,
            onChanged: (v) => setState(() => _rising = v),
          ),
          if (_timed && !_allDay)
            Wrap(
              spacing: 6,
              children: [
                for (final m in const [1, 5, 10, 25, 45])
                  GestureDetector(
                    onTap: () => setState(() => _minutes = m),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                            color: Palette.verify.withValues(
                                alpha: _minutes == m ? 0.8 : 0.3)),
                        color: _minutes == m
                            ? Palette.verify.withValues(alpha: 0.18)
                            : Colors.transparent,
                      ),
                      child: Text('${m}M',
                          style: Type.label
                              .copyWith(fontSize: 11, color: Palette.verify)),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _MiniToggle extends StatelessWidget {
  const _MiniToggle({
    required this.label,
    required this.value,
    required this.color,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final Color color;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: Type.body.copyWith(fontSize: 13, color: Palette.textMid)),
        ),
        Switch(
          value: value,
          activeThumbColor: color,
          activeTrackColor: color.withValues(alpha: 0.35),
          inactiveTrackColor: Palette.glassFill,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _CtaButton extends StatelessWidget {
  const _CtaButton({required this.label, required this.onTap, this.dim = false});
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
                  .copyWith(fontSize: 11, color: const Color(0xFF3A2510))),
        ),
      ),
    );
  }
}

/// The seal: a held golden beat as the oath takes effect.
class _Seal extends StatelessWidget {
  const _Seal({required this.stat, required this.name});
  final Stat stat;
  final String name;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Container(
      color: const Color(0xF2191210),
      child: Stack(
        children: [
          ParticleBurst(
            origin: Offset(size.width / 2, size.height * 0.4),
            colors: [stat.color, Palette.xpLight, const Color(0xFFFFF4D9)],
            count: 90,
            vibrancy: 1.0,
            spread: 170,
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_user, size: 36, color: stat.color),
                const SizedBox(height: 12),
                Text('OATH SWORN',
                    style: Type.label
                        .copyWith(fontSize: 13, color: Palette.xpLight)),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Text(name,
                      textAlign: TextAlign.center,
                      style: Type.display
                          .copyWith(fontSize: 24, color: stat.color)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
