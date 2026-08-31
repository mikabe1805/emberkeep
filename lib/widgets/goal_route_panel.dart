import 'package:flutter/material.dart';

import '../models.dart';
import '../tokens.dart';
import 'facets.dart';
import 'pressable.dart';

class GoalRouteBuilderPrompt extends StatelessWidget {
  const GoalRouteBuilderPrompt({
    super.key,
    required this.accent,
    required this.onBuild,
  });

  final Color accent;
  final VoidCallback onBuild;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('goal-route-builder-prompt'),
    padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
    decoration: facetedDecoration(
      cut: 11,
      color: const Color(0xE6171210),
      borderColor: accent.withValues(alpha: 0.52),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'THIS GOAL DOESN’T HAVE A ROUTE YET',
          style: Type.label.copyWith(
            fontSize: Type.minLabel,
            letterSpacing: 1.1,
            color: accent,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          'Tell Room of Days what should change, where you are now, and what proof would count. It will work backward into an editable plan.',
          style: Type.body.copyWith(
            fontSize: 13.5,
            height: 1.3,
            color: Palette.textMid,
          ),
        ),
        const SizedBox(height: 10),
        Pressable(
          key: const Key('goal-build-route'),
          pressDepth: 1,
          borderRadius: BorderRadius.circular(8),
          semanticLabel: 'Build a real route',
          onTapUp: (_) => onBuild(),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: accent.withValues(alpha: 0.62)),
              borderRadius: BorderRadius.circular(8),
              color: accent.withValues(alpha: 0.08),
            ),
            child: Text(
              'BUILD THE ROUTE',
              style: Type.label.copyWith(
                fontSize: Type.minLabel,
                color: accent,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class GoalRoutePanel extends StatelessWidget {
  const GoalRoutePanel({super.key, required this.goal, required this.onAdjust});

  final Goal goal;
  final VoidCallback onAdjust;

  @override
  Widget build(BuildContext context) {
    final plan = goal.plan!;
    final current = plan.currentStep;
    final totalProofs = plan.steps.fold(
      0,
      (total, step) => total + step.requiredCompletions,
    );
    final keptProofs = plan.steps.fold(
      0,
      (total, step) =>
          total + step.completions.clamp(0, step.requiredCompletions),
    );
    final latestAdjustment = plan.adjustments.isEmpty
        ? null
        : plan.adjustments.last;
    return Semantics(
      container: true,
      label:
          'Your route for ${plan.outcome}. ${plan.completedSteps} of ${plan.steps.length} markers complete. Success proof: ${plan.successProof}.',
      child: Container(
        key: const Key('goal-route-panel'),
        padding: const EdgeInsets.fromLTRB(18, 15, 15, 14),
        decoration: facetedDecoration(
          cut: 11,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xF02A1F17), Color(0xF018120F)],
          ),
          borderColor: Palette.brassDeep.withValues(alpha: 0.78),
          shadows: const [
            BoxShadow(
              color: Color(0x73100805),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan.cyclesCompleted == 0
                            ? 'YOUR ROUTE'
                            : 'RHYTHM CYCLE ${plan.cyclesCompleted + 1}',
                        style: Type.label.copyWith(
                          fontSize: Type.minLabel,
                          letterSpacing: 1.25,
                          color: goal.stat.color,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        plan.outcome,
                        style: Type.display.copyWith(
                          fontSize: 19,
                          height: 1.12,
                          color: Palette.textHi,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$keptProofs/$totalProofs',
                      style: Type.display.copyWith(
                        fontSize: 23,
                        color: goal.stat.color,
                      ),
                    ),
                    Text(
                      'PROOFS',
                      style: Type.label.copyWith(
                        fontSize: Type.minLabel,
                        color: Palette.textLo,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (var index = 0; index < plan.steps.length; index++) ...[
              _RouteStepRow(
                step: plan.steps[index],
                number: index + 1,
                current: identical(plan.steps[index], current),
                accent: goal.stat.color,
              ),
              if (index != plan.steps.length - 1) const SizedBox(height: 7),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              decoration: BoxDecoration(
                color: goal.stat.color.withValues(alpha: 0.07),
                border: Border(
                  left: BorderSide(
                    color: goal.stat.color.withValues(alpha: 0.72),
                    width: 2,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SUCCESS LOOKS LIKE',
                    style: Type.label.copyWith(
                      fontSize: Type.minLabel,
                      color: Palette.textLo,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    plan.successProof,
                    style: Type.body.copyWith(
                      fontSize: 13,
                      height: 1.28,
                      color: Palette.textMid,
                    ),
                  ),
                ],
              ),
            ),
            if (latestAdjustment != null) ...[
              const SizedBox(height: 9),
              Container(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                decoration: BoxDecoration(
                  color: Palette.brassDeep.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: Palette.brassDeep.withValues(alpha: 0.42),
                  ),
                ),
                child: Text(
                  'Last adjustment · ${latestAdjustment.fromAction} → ${latestAdjustment.toAction}',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Type.body.copyWith(
                    fontSize: 13,
                    height: 1.25,
                    fontStyle: FontStyle.italic,
                    color: Palette.textLo,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 7),
            Pressable(
              key: const Key('goal-route-adjust'),
              pressDepth: 1,
              borderRadius: BorderRadius.circular(8),
              semanticLabel: 'The plan needs adjusting',
              semanticHint:
                  'Tell Room of Days what got in the way and revise the next action.',
              onTapUp: (_) => onAdjust(),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.tune_rounded,
                      size: 16,
                      color: Palette.textLo,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      'THE PLAN NEEDS ADJUSTING',
                      style: Type.label.copyWith(
                        fontSize: Type.minLabel,
                        color: Palette.textLo,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteStepRow extends StatelessWidget {
  const _RouteStepRow({
    required this.step,
    required this.number,
    required this.current,
    required this.accent,
  });
  final GoalPlanStep step;
  final int number;
  final bool current;
  final Color accent;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 23,
        height: 23,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: step.complete
              ? accent.withValues(alpha: 0.2)
              : Colors.transparent,
          border: Border.all(
            color: step.complete || current
                ? accent.withValues(alpha: 0.92)
                : Palette.brassDeep,
          ),
        ),
        child: step.complete
            ? Icon(Icons.check_rounded, size: 14, color: accent)
            : Text(
                '$number',
                style: Type.label.copyWith(
                  fontSize: Type.minLabel,
                  color: current ? accent : Palette.textLo,
                ),
              ),
      ),
      const SizedBox(width: 9),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              step.title,
              style: Type.label.copyWith(
                fontSize: Type.minLabel,
                color: current ? accent : Palette.textLo,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              step.actionTitle,
              maxLines: current ? 3 : 1,
              overflow: TextOverflow.ellipsis,
              style: Type.body.copyWith(
                fontSize: current ? 13.5 : 13,
                height: 1.25,
                color: step.complete
                    ? Palette.textLo
                    : current
                    ? Palette.textHi
                    : Palette.textMid,
              ),
            ),
            if (current && step.requiredCompletions > 1) ...[
              const SizedBox(height: 3),
              Text(
                '${step.completions} of ${step.requiredCompletions} honest repeats',
                style: Type.body.copyWith(fontSize: 13, color: Palette.textLo),
              ),
            ],
            if (current) ...[
              const SizedBox(height: 5),
              Text(
                step.whyNow,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Type.body.copyWith(
                  fontSize: 13,
                  height: 1.24,
                  fontStyle: FontStyle.italic,
                  color: Palette.textLo,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Proof: ${step.proof}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Type.label.copyWith(
                  fontSize: Type.minLabel,
                  height: 1.2,
                  color: accent,
                ),
              ),
            ],
          ],
        ),
      ),
    ],
  );
}
