import 'package:flutter/material.dart';

import '../audio.dart';
import '../goal_adjustment.dart';
import '../haptics.dart';
import '../models.dart';
import '../tokens.dart';
import 'working_surface.dart';

Future<GoalAdjustmentDraft?> showGoalAdjustmentReview(
  BuildContext context, {
  required GoalAdjustmentDraft draft,
}) => Navigator.of(context).push<GoalAdjustmentDraft>(
  PageRouteBuilder<GoalAdjustmentDraft>(
    settings: const RouteSettings(name: '/goals/adjustment-review'),
    transitionDuration:
        Haptics.reduceMotion ||
            (MediaQuery.maybeDisableAnimationsOf(context) ?? false)
        ? Duration.zero
        : const Duration(milliseconds: 260),
    reverseTransitionDuration:
        Haptics.reduceMotion ||
            (MediaQuery.maybeDisableAnimationsOf(context) ?? false)
        ? Duration.zero
        : const Duration(milliseconds: 180),
    pageBuilder: (_, animation, secondaryAnimation) =>
        _GoalAdjustmentReview(draft: draft),
    transitionsBuilder: (_, animation, secondaryAnimation, child) =>
        FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
  ),
);

class _GoalAdjustmentReview extends StatefulWidget {
  const _GoalAdjustmentReview({required this.draft});

  final GoalAdjustmentDraft draft;

  @override
  State<_GoalAdjustmentReview> createState() => _GoalAdjustmentReviewState();
}

class _GoalAdjustmentReviewState extends State<_GoalAdjustmentReview> {
  late GoalAdjustmentDraft _draft = widget.draft;
  late final TextEditingController _actionController = TextEditingController(
    text: widget.draft.currentAction,
  );
  final FocusNode _actionFocus = FocusNode();
  bool _editing = false;
  String? _editError;

  @override
  void dispose() {
    _actionController.dispose();
    _actionFocus.dispose();
    super.dispose();
  }

  void _showEditor() {
    setState(() => _editing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _actionFocus.requestFocus();
    });
  }

  void _editAction(String value) {
    final clean = value.trim();
    if (clean.isEmpty) {
      setState(() => _editError = 'Give this attempt a concrete action.');
      return;
    }
    setState(() {
      _draft = _draft.withActionTitle(clean);
      _editError = null;
    });
  }

  void _finishEditing() {
    _editAction(_actionController.text);
    if (_actionController.text.trim().isEmpty) return;
    _actionFocus.unfocus();
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    final copy = _ReviewCopy.forSignal(_draft.signal);
    final plan = _draft.revisedPlan;
    final proposedStep = plan.currentStep!;
    final originalQuest = _draft.originalQuest;
    final replacement = _draft.replacementQuest;
    final evidenceCount = _draft.originalRecordedCompletions;
    final compact =
        MediaQuery.sizeOf(context).height < 720 ||
        MediaQuery.textScalerOf(context).scale(1) > 1.25;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      backgroundColor: Palette.parchment,
      resizeToAvoidBottomInset: true,
      body: WorkingScene(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Column(
                children: [
                  _ReviewHeader(onBack: () => Navigator.of(context).pop()),
                  Expanded(
                    child: SingleChildScrollView(
                      key: const Key('goal-adjustment-review-scroll'),
                      padding: EdgeInsets.fromLTRB(
                        compact ? 14 : 20,
                        0,
                        compact ? 14 : 20,
                        28 + bottomInset,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(height: compact ? 12 : 38),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'WORKSHOP · ${replacement.goalTitle!.toUpperCase()}',
                                  style: Type.label.copyWith(
                                    color: Palette.xpLight,
                                    fontSize: 11,
                                    letterSpacing: 1.8,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  copy.heading,
                                  key: const Key('goal-adjustment-heading'),
                                  style: WorkingType.title.copyWith(
                                    color: const Color(0xFFFFEED8),
                                    fontSize: 32,
                                    height: 1.04,
                                    shadows: const [
                                      Shadow(
                                        color: Color(0xFF090504),
                                        blurRadius: 14,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 9),
                                Text(
                                  copy.subtitle,
                                  style: Type.body.copyWith(
                                    color: const Color(0xFFEAD8C4),
                                    fontSize: 14,
                                    height: 1.45,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: compact ? 18 : 26),
                          WorkingSurface(
                            borderRadius: BorderRadius.circular(28),
                            padding: EdgeInsets.fromLTRB(
                              compact ? 18 : 26,
                              compact ? 22 : 28,
                              compact ? 18 : 26,
                              compact ? 22 : 28,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _SectionLabel(
                                  text: originalQuest == null
                                      ? 'CURRENT PLAN'
                                      : 'CURRENT QUEST',
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _draft.originalAction,
                                  key: const Key(
                                    'goal-adjustment-original-action',
                                  ),
                                  style: WorkingType.title.copyWith(
                                    color: const Color(0xFFE8D8C7),
                                    fontSize: 22,
                                    height: 1.16,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                _TimeFact(
                                  quest: originalQuest,
                                  estimateMinutes: null,
                                  absentLabel: 'Not on your Quest board yet',
                                ),
                                const WorkingRule(),
                                _SectionLabel(text: copy.proposalLabel),
                                const SizedBox(height: 12),
                                Text(
                                  _draft.currentAction,
                                  key: const Key(
                                    'goal-adjustment-proposed-action',
                                  ),
                                  style: WorkingType.title.copyWith(
                                    color: const Color(0xFFFFEBD6),
                                    fontSize: 23,
                                    height: 1.12,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: _TimeFact(
                                    quest: replacement,
                                    estimateMinutes: proposedStep.minutes,
                                    highlighted:
                                        replacement.verification ==
                                        Verification.timer,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  proposedStep.whyNow,
                                  key: const Key(
                                    'goal-adjustment-proposed-guidance',
                                  ),
                                  style: Type.body.copyWith(
                                    color: const Color(0xFFE2D2C0),
                                    fontSize: 14,
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (!_editing)
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: WorkingAction(
                                      key: const Key(
                                        'goal-adjustment-edit-action',
                                      ),
                                      label: 'Edit this version',
                                      icon: Icons.edit_outlined,
                                      onTap: _showEditor,
                                    ),
                                  )
                                else
                                  _ActionEditor(
                                    controller: _actionController,
                                    focusNode: _actionFocus,
                                    error: _editError,
                                    onChanged: _editAction,
                                    onDone: _finishEditing,
                                  ),
                                const WorkingRule(),
                                const _SectionLabel(text: 'WHAT STAYS'),
                                const SizedBox(height: 12),
                                _Consequence(
                                  icon: Icons.adjust_rounded,
                                  text: _evidenceCopy(evidenceCount),
                                  detail: evidenceCount > 0
                                      ? _draft.originalProof
                                      : null,
                                ),
                                const SizedBox(height: 12),
                                const _Consequence(
                                  icon: Icons.view_week_outlined,
                                  text:
                                      'Your other Quests and saved field stay as they are.',
                                ),
                                if (_draft.restoresAfterRecovery
                                    case final next?) ...[
                                  const SizedBox(height: 12),
                                  _Consequence(
                                    key: const Key(
                                      'goal-adjustment-restoration',
                                    ),
                                    icon: Icons.replay_rounded,
                                    text: '“$next” returns after this attempt.',
                                  ),
                                ],
                                const SizedBox(height: 22),
                                WorkingAction(
                                  key: const Key('goal-adjustment-accept'),
                                  label: copy.acceptLabel,
                                  primary: true,
                                  enabled: _editError == null,
                                  sound: InteractionSound.place,
                                  icon: Icons.arrow_forward,
                                  onTap: () =>
                                      Navigator.of(context).pop(_draft),
                                ),
                                const SizedBox(height: 8),
                                WorkingAction(
                                  key: const Key(
                                    'goal-adjustment-keep-original',
                                  ),
                                  label: 'Keep original',
                                  onTap: () => Navigator.of(context).pop(),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReviewHeader extends StatelessWidget {
  const _ReviewHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 4, 16, 4),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 2,
      children: [
        WorkingAction(
          key: const Key('goal-adjustment-back'),
          label: 'Back',
          icon: Icons.chevron_left,
          iconLeading: true,
          onTap: onBack,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Text(
            'ROOM of DAYS',
            style: WorkingType.title.copyWith(
              fontSize: 16,
              letterSpacing: 1.1,
              color: Palette.xpLight,
            ),
          ),
        ),
      ],
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Type.label.copyWith(
      color: Palette.xpLight,
      fontSize: 11,
      letterSpacing: 1.7,
    ),
  );
}

class _TimeFact extends StatelessWidget {
  const _TimeFact({
    required this.quest,
    required this.estimateMinutes,
    this.absentLabel,
    this.highlighted = false,
  });

  final Quest? quest;
  final int? estimateMinutes;
  final String? absentLabel;
  final bool highlighted;

  String get _label {
    final value = quest;
    if (value == null) return absentLabel ?? 'No Quest configured';
    if (value.verification == Verification.timer &&
        value.effectiveTimerMinutes > 0) {
      return '${value.effectiveTimerMinutes}-minute timer';
    }
    if (estimateMinutes case final minutes?) {
      return 'No timer · about $minutes minutes';
    }
    return 'No timer';
  }

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          quest?.verification == Verification.timer
              ? Icons.schedule_rounded
              : Icons.hourglass_disabled_rounded,
          size: 18,
          color: highlighted ? Palette.xpLight : Palette.textMid,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            _label,
            style: Type.body.copyWith(
              color: highlighted ? const Color(0xFFFFD79B) : Palette.textMid,
              fontSize: 14,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
    if (!highlighted) return content;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xCCDC9C53), width: 1),
        boxShadow: const [BoxShadow(color: Color(0x30DA7C35), blurRadius: 8)],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        child: content,
      ),
    );
  }
}

class _ActionEditor extends StatelessWidget {
  const _ActionEditor({
    required this.controller,
    required this.focusNode,
    required this.error,
    required this.onChanged,
    required this.onDone,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String? error;
  final ValueChanged<String> onChanged;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextField(
        key: const Key('goal-adjustment-edit-field'),
        controller: controller,
        focusNode: focusNode,
        maxLength: 120,
        minLines: 1,
        maxLines: 3,
        textCapitalization: TextCapitalization.sentences,
        textInputAction: TextInputAction.done,
        onChanged: onChanged,
        onSubmitted: (_) => onDone(),
        style: Type.body.copyWith(color: Palette.textHi, fontSize: 15),
        decoration: InputDecoration(
          labelText: 'Edit this version',
          labelStyle: Type.body.copyWith(color: Palette.xpLight, fontSize: 14),
          errorText: error,
          filled: true,
          fillColor: const Color(0x66140E0B),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0x8874553C)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Palette.xpLight, width: 1.2),
          ),
        ),
      ),
      const SizedBox(height: 4),
      Align(
        alignment: Alignment.centerLeft,
        child: WorkingAction(
          key: const Key('goal-adjustment-finish-edit'),
          label: 'Use this wording',
          icon: Icons.check_rounded,
          enabled: error == null,
          onTap: onDone,
        ),
      ),
    ],
  );
}

class _Consequence extends StatelessWidget {
  const _Consequence({
    super.key,
    required this.icon,
    required this.text,
    this.detail,
  });

  final IconData icon;
  final String text;
  final String? detail;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 1),
        child: Icon(icon, size: 19, color: Palette.xpLight),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text,
              style: Type.body.copyWith(
                color: const Color(0xFFE1D1C0),
                fontSize: 14,
                height: 1.4,
              ),
            ),
            if (detail != null) ...[
              const SizedBox(height: 3),
              Text(
                detail!,
                style: Type.body.copyWith(
                  color: Palette.textLo,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    ],
  );
}

String _evidenceCopy(int count) => count == 0
    ? 'No earlier route proof changes.'
    : count == 1
    ? 'Your 1 recorded practice stays.'
    : 'Your $count recorded practices stay.';

class _ReviewCopy {
  const _ReviewCopy({
    required this.heading,
    required this.subtitle,
    required this.proposalLabel,
    required this.acceptLabel,
  });

  final String heading;
  final String subtitle;
  final String proposalLabel;
  final String acceptLabel;

  static _ReviewCopy forSignal(GoalPlanSignal signal) => switch (signal) {
    GoalPlanSignal.tooBig || GoalPlanSignal.noTime => const _ReviewCopy(
      heading: 'Make this one smaller.',
      subtitle: 'Keep the practice. Shorten this attempt.',
      proposalLabel: 'SMALLER ATTEMPT',
      acceptLabel: 'Use this smaller Quest',
    ),
    GoalPlanSignal.lowEnergy => const _ReviewCopy(
      heading: 'Prepare an easier return.',
      subtitle: 'Keep the route. Set up the next honest attempt.',
      proposalLabel: 'EASIER RETURN',
      acceptLabel: 'Use this easier return',
    ),
    GoalPlanSignal.unclear => const _ReviewCopy(
      heading: 'Make the next proof clearer.',
      subtitle: 'Keep the goal. Clarify what this attempt needs to leave.',
      proposalLabel: 'CLEARER ATTEMPT',
      acceptLabel: 'Use this clearer Quest',
    ),
    GoalPlanSignal.changed => const _ReviewCopy(
      heading: 'Review this change.',
      subtitle: 'The aim changed. Check the new route before replacing it.',
      proposalLabel: 'PROPOSED CHANGE',
      acceptLabel: 'Use this change',
    ),
    GoalPlanSignal.completed => throw StateError(
      'Completed work does not enter adjustment review.',
    ),
  };
}
