import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio.dart';
import '../engine.dart';
import '../models.dart';
import '../tokens.dart';
import '../widgets/domain_hint.dart';
import '../widgets/ember_sheet.dart';
import '../widgets/glass.dart';
import '../widgets/particles.dart';

/// The Oath Wizard (round-23 rewrite): goal creation as ONE warm scroll, not a
/// 3-step form. Name your oath → keep-practicing or finish-line → its domain →
/// add the quests that get you there (via the shared Ember Sheet) → swear it.
/// The gold Seal moment is kept; everything else is one glanceable page.
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

class _GoalWizardScreenState extends State<GoalWizardScreen> {
  final _name = TextEditingController();
  GoalKind _kind = GoalKind.become;
  Stat _stat = Stat.vit;
  String? _error;
  int _target = 25;
  final List<Quest> _quests = [];
  bool _sealing = false;

  static const _dayShort = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
  ];

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {
          if (_error != null) _error = null;
        }));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _addQuest() async {
    if (_name.text.trim().isEmpty) {
      Sfx.instance.play('boing');
      setState(() => _error = 'name your oath first');
      return;
    }
    final q = await showEmberSheet(
      context,
      EmberSheetConfig(
        surface: EmberSurface.goal,
        defaultStat: _stat,
        lockStat: true,
        goalTitle: _name.text.trim(),
        accent: _stat.color,
      ),
    );
    if (q != null) setState(() => _quests.add(q));
  }

  Future<void> _swear() async {
    final name = _name.text.trim();
    if (name.isEmpty || _quests.isEmpty) {
      Sfx.instance.play('boing');
      return;
    }
    final created = widget.state.addGoal(Goal(
      title: name,
      stat: _stat,
      kind: _kind,
      target: _kind == GoalKind.achieve ? _target : 25,
    ));
    if (!created) {
      Sfx.instance.play('boing');
      setState(() => _error = 'you’re already on this path');
      return;
    }
    // re-stamp the goal's final name + domain onto each quest, then add them
    for (final q in _quests) {
      q.stat = _stat;
      q.goalTitle = name;
      widget.onAdd(q);
    }
    Sfx.instance.play('levelup');
    HapticFeedback.heavyImpact();
    setState(() => _sealing = true);
    await Future.delayed(const Duration(milliseconds: 1400));
    if (mounted) Navigator.of(context).pop(true);
  }

  double _perWeek(Quest q) => switch (q.schedule) {
        QuestSchedule.daily =>
          q.weekdays.isEmpty ? 7 : q.weekdays.length.toDouble(),
        QuestSchedule.weekly => 1,
        QuestSchedule.monthly => 0.25,
        QuestSchedule.once => 0,
      };

  int get _weeklyXp {
    var xp = 0.0;
    for (final q in _quests) {
      var earned = 10 * (0.5 + q.difficulty * 0.25) * GameState.customDamp;
      if (q.dread) earned *= 1.35;
      xp += earned * _perWeek(q);
    }
    return xp.round();
  }

  String _label(Quest q) {
    if (q.allDay) return 'all day';
    switch (q.schedule) {
      case QuestSchedule.daily:
        if (q.weekdays.isEmpty) return 'every day';
        if (q.weekdays.length == 5 &&
            !q.weekdays.contains(6) &&
            !q.weekdays.contains(7)) {
          return 'weekdays';
        }
        return q.weekdays.map((d) => _dayShort[d - 1]).join(' ');
      case QuestSchedule.weekly:
        return q.weekdays.isEmpty
            ? 'once a week'
            : 'every ${_dayShort[q.weekdays.first - 1]}';
      case QuestSchedule.monthly:
        return q.monthDay == null ? 'once a month' : 'on the ${q.monthDay}th';
      case QuestSchedule.once:
        return 'once';
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSwear = _name.text.trim().isNotEmpty && _quests.isNotEmpty;
    return WarmBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Stack(
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 128),
                children: [
                  GestureDetector(
                    onTap: () {
                      Sfx.instance.play('tick');
                      Navigator.of(context).pop(false);
                    },
                    behavior: HitTestBehavior.opaque,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Icon(Icons.arrow_back,
                          size: 20, color: Palette.textLo),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('A NEW OATH', style: Type.label.copyWith(fontSize: 11)),
                  const SizedBox(height: 8),
                  Text('What do you want\nto become?',
                      style:
                          Type.display.copyWith(fontSize: 30, height: 1.15)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _name,
                    style: Type.display
                        .copyWith(fontSize: 19, color: Palette.textHi),
                    decoration: InputDecoration(
                      hintText: 'keep my skin healthy…',
                      hintStyle: Type.display.copyWith(
                          fontSize: 19,
                          color: Palette.textLo.withValues(alpha: 0.6)),
                      errorText: _error,
                      errorStyle: Type.body.copyWith(
                          fontSize: 11, color: const Color(0xFFE89090)),
                      filled: true,
                      fillColor: Palette.glassFill,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Palette.glassEdge),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Palette.glassEdge),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _kindCard(GoalKind.become, Icons.all_inclusive,
                            'Keep practicing', 'a way of living'),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _kindCard(GoalKind.achieve, Icons.flag,
                            'Reach a finish line', 'done after a while'),
                      ),
                    ],
                  ),
                  if (_kind == GoalKind.achieve) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text('done after',
                            style: Type.body.copyWith(
                                fontSize: 13, color: Palette.textMid)),
                        const SizedBox(width: 8),
                        for (final t in const [5, 10, 25, 50]) ...[
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              Sfx.instance.play('tick');
                              setState(() => _target = t);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 11, vertical: 5),
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
                                      fontSize: 13, color: _stat.color)),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text('times',
                            style: Type.body.copyWith(
                                fontSize: 13, color: Palette.textMid)),
                      ],
                    ),
                  ],
                  const SizedBox(height: 18),
                  Text('PART OF MY…',
                      style: Type.label.copyWith(fontSize: 11)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      for (final s in Stat.values)
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
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
                                  color: s.color.withValues(
                                      alpha: _stat == s ? 0.9 : 0.3)),
                            ),
                            child: Text(s.label,
                                style: Type.label
                                    .copyWith(fontSize: 11, color: s.color)),
                          ),
                        ),
                    ],
                  ),
                  DomainHint(_stat),
                  const SizedBox(height: 20),
                  const Divider(color: Palette.glassEdge, height: 1),
                  const SizedBox(height: 16),
                  Text('THE QUESTS THAT GET YOU THERE',
                      style: Type.label.copyWith(fontSize: 11)),
                  const SizedBox(height: 10),
                  if (_quests.isNotEmpty) _trail(),
                  const SizedBox(height: 10),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _addQuest,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: Palette.glassFill,
                        border: Border.all(
                            color: _stat.color.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add, size: 17, color: _stat.color),
                          const SizedBox(width: 8),
                          Text('Add a quest',
                              style: Type.body.copyWith(
                                  fontSize: 14, color: Palette.textMid)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_quests.isEmpty)
                    Text('first time? one quest is plenty to start.',
                        style: Type.body.copyWith(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: Palette.textLo))
                  else
                    Text('this path earns ~$_weeklyXp XP a week',
                        style: Type.numerals
                            .copyWith(fontSize: 13, color: Palette.xpLight)),
                ],
              ),
              // pinned oath footer
              Positioned(
                left: 0,
                right: 0,
                bottom: 14,
                child: Column(
                  children: [
                    _CtaButton(
                      label: '⚔ SWEAR THE OATH',
                      dim: !canSwear,
                      onTap: _swear,
                    ),
                    const SizedBox(height: 8),
                    Text('your future self is watching, kindly',
                        style: Type.body.copyWith(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            color: Palette.textLo)),
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

  Widget _kindCard(GoalKind kind, IconData icon, String title, String blurb) {
    final on = _kind == kind;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Sfx.instance.play('tick');
        setState(() => _kind = kind);
      },
      child: AnimatedContainer(
        duration: Motion.quick,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: on
              ? Palette.xpLight.withValues(alpha: 0.14)
              : Palette.glassFill,
          border: Border.all(
              color:
                  on ? Palette.xpLight.withValues(alpha: 0.7) : Palette.glassEdge),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: on ? Palette.xpLight : Palette.textLo),
            const SizedBox(height: 6),
            Text(title,
                style: Type.body.copyWith(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: on ? Palette.xpLight : Palette.textMid)),
            Text(blurb,
                style: Type.body.copyWith(fontSize: 11, color: Palette.textLo)),
          ],
        ),
      ),
    );
  }

  Widget _trail() {
    return GlassPanel(
      child: Column(
        children: [
          for (var i = 0; i < _quests.length; i++)
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
                      if (i < _quests.length - 1)
                        Container(
                            width: 2,
                            height: 14,
                            color: _stat.color.withValues(alpha: 0.35)),
                    ],
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_quests[i].title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Type.body.copyWith(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Palette.textHi)),
                        Text(_label(_quests[i]),
                            style: Type.label.copyWith(fontSize: 11)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _quests.removeAt(i)),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child:
                          Icon(Icons.close, size: 15, color: Palette.textLo),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              const SizedBox(width: 1),
              Icon(Icons.flag, size: 15, color: _stat.color),
              const SizedBox(width: 9),
              Expanded(
                child: Text(_name.text.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Type.body.copyWith(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: _stat.color)),
              ),
            ],
          ),
        ],
      ),
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
              colors: [Color(0xFFF6D9A2), Color(0xFFEFC074), Color(0xFFC08B4F)],
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
