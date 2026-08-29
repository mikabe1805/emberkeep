import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../clock.dart';
import '../goal_planner.dart';
import '../models.dart';
import '../tokens.dart';
import '../widgets/facets.dart';
import '../widgets/glass.dart';
import '../widgets/honey_button.dart';

enum QuickGoalComposerExit { create, browse, advanced }

class QuickGoalComposerResult {
  const QuickGoalComposerResult._({
    required this.exit,
    this.title,
    this.stat,
    this.plan,
  });

  const QuickGoalComposerResult.create({
    required String title,
    required Stat stat,
    required GoalPlan plan,
  }) : this._(
         exit: QuickGoalComposerExit.create,
         title: title,
         stat: stat,
         plan: plan,
       );

  const QuickGoalComposerResult.browse()
    : this._(exit: QuickGoalComposerExit.browse);

  const QuickGoalComposerResult.advanced()
    : this._(exit: QuickGoalComposerExit.advanced);

  final QuickGoalComposerExit exit;
  final String? title;
  final Stat? stat;
  final GoalPlan? plan;
}

Future<QuickGoalComposerResult?> showQuickGoalComposer(
  BuildContext context, {
  required Iterable<String> existingGoalTitles,
  required Iterable<String> existingQuestTitles,
}) {
  return showModalBottomSheet<QuickGoalComposerResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0xD9140C06),
    builder: (_) => _GoalRouteComposer(existingGoalTitles: existingGoalTitles),
  );
}

Future<GoalPlan?> showGoalPlanBuilder(
  BuildContext context, {
  required Goal goal,
}) async {
  final result = await showModalBottomSheet<QuickGoalComposerResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0xD9140C06),
    builder: (_) =>
        _GoalRouteComposer(existingGoalTitles: const [], existingGoal: goal),
  );
  return result?.plan;
}

class _GoalRouteComposer extends StatefulWidget {
  const _GoalRouteComposer({
    required this.existingGoalTitles,
    this.existingGoal,
  });

  final Iterable<String> existingGoalTitles;
  final Goal? existingGoal;

  @override
  State<_GoalRouteComposer> createState() => _GoalRouteComposerState();
}

class _GoalRouteComposerState extends State<_GoalRouteComposer> {
  final _goal = TextEditingController();
  final _outcome = TextEditingController();
  final _starting = TextEditingController();
  final _proof = TextEditingController();
  final _horizon = TextEditingController();
  final _obstacle = TextEditingController();

  var _page = 0;
  var _stat = Stat.dis;
  var _type = GoalRouteType.finish;
  var _minutes = 15;
  String? _error;

  static String _key(String value) => value.trim().toLowerCase();

  late final Set<String> _goalKeys = {
    for (final title in widget.existingGoalTitles) _key(title),
  };

  @override
  void initState() {
    super.initState();
    final existing = widget.existingGoal;
    if (existing == null) return;
    _goal.text = existing.title;
    _outcome.text = existing.why?.trim().isNotEmpty == true
        ? existing.why!.trim()
        : existing.title;
    _stat = existing.stat;
    _type = existing.kind == GoalKind.become
        ? GoalRouteType.routine
        : GoalRouteType.finish;
  }

  @override
  void dispose() {
    _goal.dispose();
    _outcome.dispose();
    _starting.dispose();
    _proof.dispose();
    _horizon.dispose();
    _obstacle.dispose();
    super.dispose();
  }

  void _clearError() {
    if (_error != null) setState(() => _error = null);
  }

  void _continue() {
    FocusScope.of(context).unfocus();
    if (_page == 0) {
      final title = _goal.text.trim();
      if (title.isEmpty || _outcome.text.trim().isEmpty) {
        setState(
          () => _error = title.isEmpty
              ? 'Give this goal a short name.'
              : 'Describe what will actually be different.',
        );
        return;
      }
      if (widget.existingGoal == null && _goalKeys.contains(_key(title))) {
        setState(() => _error = 'That goal is already here.');
        return;
      }
      setState(() {
        _error = null;
        _page = 1;
      });
      return;
    }
    if (_page == 1) {
      if (_starting.text.trim().isEmpty ||
          _proof.text.trim().isEmpty ||
          _obstacle.text.trim().isEmpty) {
        setState(
          () => _error = _starting.text.trim().isEmpty
              ? 'Tell the route where you are starting.'
              : _proof.text.trim().isEmpty
              ? 'Choose the proof that would make this feel real.'
              : 'Name the snag this plan should survive.',
        );
        return;
      }
      final draft = GoalPlanner.draft(
        GoalPlanInput(
          title: _goal.text,
          stat: _stat,
          type: _type,
          outcome: _outcome.text,
          startingPoint: _starting.text,
          successProof: _proof.text,
          timeBudgetMinutes: _minutes,
          obstacleCue: _obstacle.text,
          horizon: _horizon.text,
          now: Clock.now(),
        ),
      );
      Navigator.of(context).pop(
        QuickGoalComposerResult.create(
          title: _goal.text.trim(),
          stat: _stat,
          plan: draft,
        ),
      );
    }
  }

  void _back() {
    if (_page == 0) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _page--;
      _error = null;
    });
  }

  String get _stepLabel => switch (_page) {
    0 => '1 OF 2  ·  AIM',
    _ => '2 OF 2  ·  REALITY',
  };

  String get _buttonLabel => switch (_page) {
    0 => 'NEXT: START FROM TODAY',
    _ => 'DRAFT MY ROUTE',
  };

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    final maxHeight = math.min(media.size.height - 18, 850.0);
    return Padding(
      padding: EdgeInsets.fromLTRB(10, 9, 10, keyboard + 9),
      child: SizedBox(
        height: maxHeight - keyboard,
        child: GlassPanel(
          tint: const Color(0xFC211812),
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                child: Row(
                  children: [
                    IconButton(
                      key: const Key('quick-goal-back'),
                      onPressed: _back,
                      tooltip: _page == 0 ? 'Close' : 'Back',
                      icon: Icon(
                        _page == 0
                            ? Icons.close_rounded
                            : Icons.arrow_back_rounded,
                        color: Palette.textMid,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            _stepLabel,
                            style: Type.label.copyWith(
                              fontSize: 10,
                              letterSpacing: 1.35,
                              color: Palette.xpLight,
                            ),
                          ),
                          const SizedBox(height: 6),
                          _RouteProgress(page: _page),
                        ],
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: Motion.quick,
                  switchInCurve: Motion.respond,
                  child: SingleChildScrollView(
                    key: ValueKey(_page),
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
                    child: switch (_page) {
                      0 => _aimPage(),
                      _ => _realityPage(),
                    },
                  ),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFF180F0B).withValues(alpha: 0.88),
                  border: Border(
                    top: BorderSide(
                      color: Palette.brassDeep.withValues(alpha: 0.62),
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_error case final error?) ...[
                        Text(
                          error,
                          key: const Key('quick-goal-error'),
                          style: Type.body.copyWith(
                            fontSize: 12.5,
                            height: 1.25,
                            color: const Color(0xFFE9A2A2),
                          ),
                        ),
                        const SizedBox(height: 9),
                      ],
                      HoneyButton(
                        key: const Key('quick-goal-create'),
                        label: _buttonLabel,
                        icon: Icons.arrow_forward_rounded,
                        expand: true,
                        glow: false,
                        onTap: _continue,
                      ),
                      if (_page == 0 && widget.existingGoal == null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                key: const Key('quick-goal-browse'),
                                onPressed: () => Navigator.of(
                                  context,
                                ).pop(const QuickGoalComposerResult.browse()),
                                child: Text(
                                  'READY-MADE ROUTES',
                                  style: Type.label.copyWith(
                                    fontSize: 9.5,
                                    color: Palette.textLo,
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 22,
                              color: Palette.brassDeep.withValues(alpha: 0.55),
                            ),
                            Expanded(
                              child: TextButton(
                                key: const Key('quick-goal-advanced'),
                                onPressed: () => Navigator.of(
                                  context,
                                ).pop(const QuickGoalComposerResult.advanced()),
                                child: Text(
                                  'BUILD IT MANUALLY',
                                  style: Type.label.copyWith(
                                    fontSize: 9.5,
                                    color: Palette.textLo,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _aimPage() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        widget.existingGoal == null
            ? 'What are we actually trying to change?'
            : 'Give this goal a route that starts from today.',
        style: Type.display.copyWith(fontSize: 27, height: 1.05),
      ),
      const SizedBox(height: 7),
      Text(
        'A title is not a plan. Give Room of Days the result it should work backward from.',
        style: Type.body.copyWith(
          fontSize: 14,
          height: 1.36,
          color: Palette.textMid,
        ),
      ),
      const SizedBox(height: 18),
      _label('SHORT NAME'),
      const SizedBox(height: 7),
      TextField(
        key: const Key('quick-goal-name'),
        controller: _goal,
        textCapitalization: TextCapitalization.sentences,
        textInputAction: TextInputAction.next,
        readOnly: widget.existingGoal != null,
        style: Type.display.copyWith(fontSize: 18),
        decoration: _fieldDecoration('Make the apartment feel calm'),
        onChanged: (_) => _clearError(),
      ),
      const SizedBox(height: 14),
      _label('WHEN THIS IS WORKING, WHAT IS NOTICEABLY DIFFERENT?'),
      const SizedBox(height: 7),
      TextField(
        key: const Key('quick-goal-outcome'),
        controller: _outcome,
        minLines: 2,
        maxLines: 4,
        textCapitalization: TextCapitalization.sentences,
        style: Type.body.copyWith(fontSize: 15.5, color: Palette.textHi),
        decoration: _fieldDecoration(
          'I can come home and use the kitchen without feeling overwhelmed',
        ),
        onChanged: (_) => _clearError(),
      ),
      const SizedBox(height: 16),
      _label('WHAT KIND OF ROUTE IS THIS?'),
      const SizedBox(height: 8),
      for (final type in GoalRouteType.values) ...[
        _RouteTypeChoice(
          type: type,
          selected: type == _type,
          onTap: () => setState(() => _type = type),
        ),
        const SizedBox(height: 7),
      ],
      const SizedBox(height: 10),
      _label('PART OF YOUR…'),
      const SizedBox(height: 8),
      _statPicker(),
    ],
  );

  Widget _realityPage() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'What kind of day does this plan have to survive?',
        style: Type.display.copyWith(fontSize: 26, height: 1.06),
      ),
      const SizedBox(height: 7),
      Text(
        'The route starts from reality, not from the version of you with unlimited time and energy.',
        style: Type.body.copyWith(
          fontSize: 14,
          height: 1.36,
          color: Palette.textMid,
        ),
      ),
      const SizedBox(height: 18),
      _label('WHERE ARE YOU STARTING?'),
      const SizedBox(height: 7),
      TextField(
        key: const Key('quick-goal-starting-point'),
        controller: _starting,
        minLines: 2,
        maxLines: 4,
        textCapitalization: TextCapitalization.sentences,
        style: Type.body.copyWith(fontSize: 15.5, color: Palette.textHi),
        decoration: _fieldDecoration(
          'The counter is crowded and I avoid deciding where anything goes',
        ),
        onChanged: (_) => _clearError(),
      ),
      const SizedBox(height: 14),
      _label('WHAT WOULD COUNT AS REAL PROOF?'),
      const SizedBox(height: 7),
      TextField(
        key: const Key('quick-goal-proof'),
        controller: _proof,
        minLines: 2,
        maxLines: 4,
        textCapitalization: TextCapitalization.sentences,
        style: Type.body.copyWith(fontSize: 15.5, color: Palette.textHi),
        decoration: _fieldDecoration(
          'The counter stays usable for a normal week',
        ),
        onChanged: (_) => _clearError(),
      ),
      const SizedBox(height: 16),
      _label('TIME A NORMAL ATTEMPT CAN ACTUALLY HAVE'),
      const SizedBox(height: 8),
      Wrap(
        spacing: 7,
        runSpacing: 7,
        children: [
          for (final minutes in const [5, 15, 30, 60])
            _TimeChoice(
              minutes: minutes,
              selected: _minutes == minutes,
              onTap: () => setState(() => _minutes = minutes),
            ),
        ],
      ),
      const SizedBox(height: 16),
      _label('LIKELY SNAG'),
      const SizedBox(height: 7),
      TextField(
        key: const Key('quick-goal-obstacle'),
        controller: _obstacle,
        textCapitalization: TextCapitalization.sentences,
        style: Type.body.copyWith(fontSize: 15, color: Palette.textHi),
        decoration: _fieldDecoration(
          'the whole thing feels too big after class',
        ),
        onChanged: (_) => _clearError(),
      ),
      const SizedBox(height: 14),
      _label('HORIZON  ·  OPTIONAL'),
      const SizedBox(height: 7),
      TextField(
        key: const Key('quick-goal-horizon'),
        controller: _horizon,
        textCapitalization: TextCapitalization.sentences,
        style: Type.body.copyWith(fontSize: 15, color: Palette.textHi),
        decoration: _fieldDecoration('Before the semester begins'),
      ),
    ],
  );

  Widget _statPicker() => LayoutBuilder(
    builder: (context, constraints) {
      final width = (constraints.maxWidth - 14) / 3;
      return Wrap(
        spacing: 7,
        runSpacing: 7,
        children: [
          for (final stat in Stat.values)
            SizedBox(
              width: width,
              child: Semantics(
                button: true,
                selected: stat == _stat,
                label: stat.label,
                child: GestureDetector(
                  key: ValueKey('quick-goal-stat-${stat.name}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _stat = stat),
                  child: AnimatedContainer(
                    duration: Motion.quick,
                    constraints: const BoxConstraints(minHeight: 48),
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    decoration: facetedDecoration(
                      cut: 7,
                      color: stat == _stat
                          ? stat.color.withValues(alpha: 0.18)
                          : Colors.transparent,
                      borderColor: stat.color.withValues(
                        alpha: stat == _stat ? 0.8 : 0.3,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(stat.icon, size: 16, color: stat.color),
                        const SizedBox(height: 3),
                        Text(
                          stat.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Type.label.copyWith(
                            fontSize: 9.5,
                            color: stat.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );

  Widget _label(String value) => Text(
    value,
    style: Type.label.copyWith(
      fontSize: 10,
      letterSpacing: 1.05,
      color: Palette.textLo,
    ),
  );

  static InputDecoration _fieldDecoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: Type.body.copyWith(color: Palette.textLo, fontSize: 14.5),
    filled: true,
    fillColor: const Color(0xFF130E0B),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Palette.brassDeep.withValues(alpha: 0.7)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Palette.brassDeep.withValues(alpha: 0.7)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Palette.xp.withValues(alpha: 0.9)),
    ),
  );
}

class _RouteProgress extends StatelessWidget {
  const _RouteProgress({required this.page});
  final int page;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var index = 0; index < 2; index++) ...[
        Expanded(
          child: AnimatedContainer(
            duration: Motion.quick,
            height: 2,
            color: index <= page ? Palette.xp : Palette.brassDeep,
          ),
        ),
        if (index != 1) const SizedBox(width: 5),
      ],
    ],
  );
}

class _RouteTypeChoice extends StatelessWidget {
  const _RouteTypeChoice({
    required this.type,
    required this.selected,
    required this.onTap,
  });
  final GoalRouteType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: '${type.label}. ${type.blurb}',
    child: InkWell(
      key: ValueKey('quick-goal-type-${type.name}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: Motion.quick,
        constraints: const BoxConstraints(minHeight: 54),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: facetedDecoration(
          cut: 8,
          color: selected
              ? Palette.xp.withValues(alpha: 0.1)
              : Colors.transparent,
          borderColor: selected
              ? Palette.xp.withValues(alpha: 0.7)
              : Palette.brassDeep.withValues(alpha: 0.55),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              size: 18,
              color: selected ? Palette.xpLight : Palette.textLo,
            ),
            const SizedBox(width: 11),
            Text(
              type.label,
              style: Type.label.copyWith(
                fontSize: 10.5,
                color: selected ? Palette.xpLight : Palette.textMid,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                type.blurb,
                style: Type.body.copyWith(fontSize: 13, color: Palette.textMid),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _TimeChoice extends StatelessWidget {
  const _TimeChoice({
    required this.minutes,
    required this.selected,
    required this.onTap,
  });
  final int minutes;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ChoiceChip(
    key: ValueKey('quick-goal-minutes-$minutes'),
    label: Text('$minutes MIN'),
    selected: selected,
    onSelected: (_) => onTap(),
    selectedColor: Palette.xp.withValues(alpha: 0.2),
    backgroundColor: const Color(0xFF130E0B),
    side: BorderSide(
      color: selected ? Palette.xp : Palette.brassDeep.withValues(alpha: 0.65),
    ),
    labelStyle: Type.label.copyWith(
      fontSize: 10,
      color: selected ? Palette.xpLight : Palette.textMid,
    ),
    showCheckmark: false,
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
  );
}
