import '../models.dart';
import '../tokens.dart';

/// What a goal intake hands back. The Steward's questions (see
/// `steward_intake.dart`) end in [QuickGoalComposerExit.create] with the plan
/// they drafted, or step aside for ready-made plans or the manual wizard.
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
