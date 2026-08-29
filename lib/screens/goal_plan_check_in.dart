import 'package:flutter/material.dart';

import '../models.dart';
import '../tokens.dart';
import '../widgets/facets.dart';
import '../widgets/glass.dart';
import '../widgets/goal_steward.dart';
import '../widgets/honey_button.dart';

Future<GoalPlanSignal?> showGoalPlanCheckIn(
  BuildContext context, {
  required Goal goal,
}) => showModalBottomSheet<GoalPlanSignal>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: Colors.transparent,
  barrierColor: const Color(0xD9140C06),
  builder: (_) => _GoalPlanCheckIn(goal: goal),
);

enum GoalTodayRecoveryChoice { smaller, prepareReturn, leaveTodayAlone }

Future<GoalTodayRecoveryChoice?> showGoalTodayRecovery(
  BuildContext context, {
  required Goal goal,
}) => showModalBottomSheet<GoalTodayRecoveryChoice>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: Colors.transparent,
  barrierColor: const Color(0xD9140C06),
  builder: (_) => _GoalTodayRecovery(goal: goal),
);

Future<(String outcome, String proof)?> showGoalOutcomeEditor(
  BuildContext context, {
  required Goal goal,
}) => showModalBottomSheet<(String, String)>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: Colors.transparent,
  barrierColor: const Color(0xD9140C06),
  builder: (_) => _GoalOutcomeEditor(goal: goal),
);

class _SignalChoice {
  const _SignalChoice(this.signal, this.title, this.result, this.icon);
  final GoalPlanSignal signal;
  final String title;
  final String result;
  final IconData icon;
}

const _signals = <_SignalChoice>[
  _SignalChoice(
    GoalPlanSignal.tooBig,
    'it was too big',
    'Keep the same marker, cut the action to its five-minute proof.',
    Icons.compress_rounded,
  ),
  _SignalChoice(
    GoalPlanSignal.unclear,
    'i couldn’t tell what to do',
    'Pause the work and make the next proof concrete first.',
    Icons.alt_route_rounded,
  ),
  _SignalChoice(
    GoalPlanSignal.noTime,
    'there wasn’t enough time',
    'Use one honest five-minute version without changing the destination.',
    Icons.schedule_rounded,
  ),
  _SignalChoice(
    GoalPlanSignal.lowEnergy,
    'i didn’t have the energy',
    'Prepare the next return instead of demanding the whole action today.',
    Icons.battery_2_bar_rounded,
  ),
  _SignalChoice(
    GoalPlanSignal.changed,
    'the goal itself changed',
    'Rewrite the outcome and proof, then rebuild the route from there.',
    Icons.change_circle_outlined,
  ),
];

class _RecoveryChoice {
  const _RecoveryChoice(this.choice, this.title, this.result, this.icon);

  final GoalTodayRecoveryChoice choice;
  final String title;
  final String result;
  final IconData icon;
}

const _recoveryChoices = <_RecoveryChoice>[
  _RecoveryChoice(
    GoalTodayRecoveryChoice.smaller,
    'Make it smaller',
    'Keep the same marker and bring a five-minute cut to the steward.',
    Icons.compress_rounded,
  ),
  _RecoveryChoice(
    GoalTodayRecoveryChoice.prepareReturn,
    'Prepare the return',
    'Set up what you will need next time; no whole task today.',
    Icons.inventory_2_outlined,
  ),
  _RecoveryChoice(
    GoalTodayRecoveryChoice.leaveTodayAlone,
    'Leave today alone',
    'Change nothing. Your proof and current Quest stay exactly where they are.',
    Icons.nights_stay_outlined,
  ),
];

class _GoalTodayRecovery extends StatelessWidget {
  const _GoalTodayRecovery({required this.goal});

  final Goal goal;

  @override
  Widget build(BuildContext context) {
    final currentMove = goal.plan?.currentStep?.actionTitle ?? goal.title;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        10,
        0,
        10,
        MediaQuery.viewInsetsOf(context).bottom + 10,
      ),
      child: GlassPanel(
        tint: const Color(0xFC211812),
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 3,
                  decoration: BoxDecoration(
                    color: Palette.brass.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      'THE DAY CHANGED',
                      style: Type.label.copyWith(
                        fontSize: 10,
                        letterSpacing: 1.3,
                        color: goal.stat.color,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const _RecoveryStewardPortrait(),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'What would help now?',
                style: Type.display.copyWith(fontSize: 25, height: 1.05),
              ),
              const SizedBox(height: 7),
              Text(
                'The route can change without making this a verdict on you.',
                style: Type.body.copyWith(
                  fontSize: 14,
                  height: 1.36,
                  color: Palette.textMid,
                ),
              ),
              const SizedBox(height: 15),
              Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: facetedDecoration(
                  cut: 8,
                  color: const Color(0xFF150F0C),
                  borderColor: Palette.brassDeep.withValues(alpha: 0.6),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CURRENT MOVE',
                      style: Type.label.copyWith(
                        fontSize: 9.5,
                        color: Palette.textLo,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currentMove,
                      style: Type.display.copyWith(fontSize: 17),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              for (final choice in _recoveryChoices) ...[
                Semantics(
                  button: true,
                  label: '${choice.title}. ${choice.result}',
                  child: InkWell(
                    key: ValueKey('goal-recovery-${choice.choice.name}'),
                    onTap: () => Navigator.of(context).pop(choice.choice),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 66),
                      padding: const EdgeInsets.fromLTRB(12, 10, 11, 10),
                      decoration: facetedDecoration(
                        cut: 8,
                        color: Colors.transparent,
                        borderColor: Palette.brassDeep.withValues(alpha: 0.55),
                      ),
                      child: Row(
                        children: [
                          Icon(choice.icon, size: 19, color: goal.stat.color),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  choice.title,
                                  style: Type.display.copyWith(fontSize: 16.5),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  choice.result,
                                  style: Type.body.copyWith(
                                    fontSize: 12.3,
                                    height: 1.25,
                                    color: Palette.textMid,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: Palette.textLo,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 7),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RecoveryStewardPortrait extends StatelessWidget {
  const _RecoveryStewardPortrait();

  @override
  Widget build(BuildContext context) {
    const cut = 8.0;
    return Semantics(
      image: true,
      label: goalStewardSemanticLabel(GoalStewardExpression.considering),
      child: Container(
        width: 52,
        height: 52,
        decoration: facetedDecoration(
          cut: cut,
          color: const Color(0xFF160F0B),
          borderColor: Palette.brassDeep.withValues(alpha: 0.72),
        ),
        child: ClipPath(
          clipper: const FacetedClipper(cut: cut),
          child: Transform.scale(
            scale: 1.28,
            alignment: Alignment.topCenter,
            child: Image.asset(
              goalsWorkshopStewardConsideringAsset,
              fit: BoxFit.cover,
              alignment: const Alignment(-0.08, -0.82),
              filterQuality: FilterQuality.medium,
              excludeFromSemantics: true,
              errorBuilder: (_, _, _) =>
                  const ColoredBox(color: Color(0xFF160F0B)),
            ),
          ),
        ),
      ),
    );
  }
}

class _GoalPlanCheckIn extends StatelessWidget {
  const _GoalPlanCheckIn({required this.goal});
  final Goal goal;

  @override
  Widget build(BuildContext context) {
    final plan = goal.plan!;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        10,
        10,
        10,
        MediaQuery.viewInsetsOf(context).bottom + 10,
      ),
      child: GlassPanel(
        tint: const Color(0xFC211812),
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 3,
                  decoration: BoxDecoration(
                    color: Palette.brass.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'THE PLAN DIDN’T MEET THE DAY',
                style: Type.label.copyWith(
                  fontSize: 10,
                  letterSpacing: 1.3,
                  color: goal.stat.color,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'What got in the way?',
                style: Type.display.copyWith(fontSize: 25, height: 1.05),
              ),
              const SizedBox(height: 7),
              Text(
                'This is information about the route—not a verdict on you. Pick the closest answer and Room of Days will change the next move now.',
                style: Type.body.copyWith(
                  fontSize: 14,
                  height: 1.36,
                  color: Palette.textMid,
                ),
              ),
              const SizedBox(height: 15),
              Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: facetedDecoration(
                  cut: 8,
                  color: const Color(0xFF150F0C),
                  borderColor: Palette.brassDeep.withValues(alpha: 0.6),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CURRENT MOVE',
                      style: Type.label.copyWith(
                        fontSize: 9.5,
                        color: Palette.textLo,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      plan.currentStep?.actionTitle ?? goal.title,
                      style: Type.display.copyWith(fontSize: 17),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              for (final choice in _signals) ...[
                Semantics(
                  button: true,
                  label: '${choice.title}. ${choice.result}',
                  child: InkWell(
                    key: ValueKey('goal-plan-signal-${choice.signal.name}'),
                    onTap: () => Navigator.of(context).pop(choice.signal),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 62),
                      padding: const EdgeInsets.fromLTRB(12, 10, 11, 10),
                      decoration: facetedDecoration(
                        cut: 8,
                        color: Colors.transparent,
                        borderColor: Palette.brassDeep.withValues(alpha: 0.55),
                      ),
                      child: Row(
                        children: [
                          Icon(choice.icon, size: 19, color: goal.stat.color),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  choice.title,
                                  style: Type.display.copyWith(fontSize: 16.5),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  choice.result,
                                  style: Type.body.copyWith(
                                    fontSize: 12.3,
                                    height: 1.25,
                                    color: Palette.textLo,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: Palette.textLo,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 7),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _GoalOutcomeEditor extends StatefulWidget {
  const _GoalOutcomeEditor({required this.goal});
  final Goal goal;

  @override
  State<_GoalOutcomeEditor> createState() => _GoalOutcomeEditorState();
}

class _GoalOutcomeEditorState extends State<_GoalOutcomeEditor> {
  late final TextEditingController _outcome;
  late final TextEditingController _proof;
  String? _error;

  @override
  void initState() {
    super.initState();
    _outcome = TextEditingController(text: widget.goal.plan!.outcome);
    _proof = TextEditingController(text: widget.goal.plan!.successProof);
  }

  @override
  void dispose() {
    _outcome.dispose();
    _proof.dispose();
    super.dispose();
  }

  void _save() {
    final outcome = _outcome.text.trim();
    final proof = _proof.text.trim();
    if (outcome.isEmpty || proof.isEmpty) {
      setState(
        () => _error = 'The changed route still needs an outcome and proof.',
      );
      return;
    }
    Navigator.of(context).pop((outcome, proof));
  }

  InputDecoration _decoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: Type.body.copyWith(color: Palette.textLo),
    filled: true,
    fillColor: const Color(0xFF130E0B),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Palette.brassDeep),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Palette.brassDeep),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: widget.goal.stat.color),
    ),
  );

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      10,
      10,
      10,
      MediaQuery.viewInsetsOf(context).bottom + 10,
    ),
    child: GlassPanel(
      tint: const Color(0xFC211812),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'RESHAPE THE ROUTE',
              style: Type.label.copyWith(
                fontSize: 10,
                letterSpacing: 1.3,
                color: widget.goal.stat.color,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'What is true now?',
              style: Type.display.copyWith(fontSize: 25),
            ),
            const SizedBox(height: 7),
            Text(
              'The old proof stays in your history. This only changes where the route goes next.',
              style: Type.body.copyWith(color: Palette.textMid, height: 1.35),
            ),
            const SizedBox(height: 15),
            TextField(
              key: const Key('goal-plan-new-outcome'),
              controller: _outcome,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              style: Type.body.copyWith(color: Palette.textHi),
              decoration: _decoration('What should now be different?'),
            ),
            const SizedBox(height: 11),
            TextField(
              key: const Key('goal-plan-new-proof'),
              controller: _proof,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              style: Type.body.copyWith(color: Palette.textHi),
              decoration: _decoration('What will count as real proof now?'),
            ),
            if (_error case final error?) ...[
              const SizedBox(height: 9),
              Text(
                error,
                style: Type.body.copyWith(color: const Color(0xFFE9A2A2)),
              ),
            ],
            const SizedBox(height: 15),
            HoneyButton(
              key: const Key('goal-plan-rebuild'),
              label: 'REBUILD FROM HERE',
              icon: Icons.alt_route_rounded,
              expand: true,
              glow: false,
              onTap: _save,
            ),
          ],
        ),
      ),
    ),
  );
}
