import 'package:flutter/material.dart';

import '../clock.dart';
import '../goal_planner.dart';
import '../models.dart';
import '../tokens.dart';
import '../widgets/facets.dart';
import '../widgets/goal_steward.dart';
import '../widgets/honey_button.dart';
import 'quick_goal_composer.dart';

/// What the Steward asks, in order. Each question is one screen of the same
/// intake the old two-page composer used: every answer feeds the same
/// [GoalPlanInput], so the plan that comes out is built by the same planner.
enum StewardAsk {
  name,
  outcome,
  kind,
  stat,
  starting,
  proof,
  minutes,
  snag,
  horizon,
}

/// The Steward's questions, one at a time, in plain words.
///
/// With no [existingGoal] this starts a new goal (name, what will be
/// different, the kind of goal, the part of life it belongs to, then the
/// reality questions). With an [existingGoal] the name and stat are already
/// known, so the Steward only asks for what the plan needs.
///
/// This widget owns the answers and builds the panel; the workshop owns the
/// room around it (the Steward's art, the back button and navigation).
class StewardIntake extends StatefulWidget {
  const StewardIntake({
    super.key,
    required this.existingGoalTitles,
    required this.onResult,
    required this.expression,
    this.existingGoal,
    this.nextChapter = false,
    this.busy = false,
  });

  final Iterable<String> existingGoalTitles;
  final Goal? existingGoal;

  /// The goal's plan is finished and this is the next one, so the old outcome
  /// is not offered back as an answer.
  final bool nextChapter;

  /// The finished intake, or one of the two exits to a different way of
  /// starting (ready-made plans, or setting the goal up by hand).
  final ValueChanged<QuickGoalComposerResult> onResult;

  /// The workshop reads this to pose the Steward as the questions go on.
  final ValueNotifier<GoalStewardExpression> expression;
  final bool busy;

  @override
  State<StewardIntake> createState() => StewardIntakeState();
}

class StewardIntakeState extends State<StewardIntake> {
  final _name = TextEditingController();
  final _outcome = TextEditingController();
  final _starting = TextEditingController();
  final _proof = TextEditingController();
  final _horizon = TextEditingController();
  final _snag = TextEditingController();

  var _index = 0;
  var _stat = Stat.dis;
  var _type = GoalRouteType.finish;
  var _minutes = 15;
  String? _error;

  static String _key(String value) => value.trim().toLowerCase();

  late final Set<String> _goalKeys = {
    for (final title in widget.existingGoalTitles) _key(title),
  };

  late final List<StewardAsk> _asks = [
    if (widget.existingGoal == null) StewardAsk.name,
    StewardAsk.outcome,
    StewardAsk.kind,
    if (widget.existingGoal == null) StewardAsk.stat,
    StewardAsk.starting,
    StewardAsk.proof,
    StewardAsk.minutes,
    StewardAsk.snag,
    StewardAsk.horizon,
  ];

  StewardAsk get _ask => _asks[_index];
  bool get _isLast => _index == _asks.length - 1;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingGoal;
    if (existing != null) {
      _name.text = existing.title;
      if (!widget.nextChapter) {
        _outcome.text = existing.why?.trim().isNotEmpty == true
            ? existing.why!.trim()
            : existing.title;
      }
      _stat = existing.stat;
      _type = existing.kind == GoalKind.become
          ? GoalRouteType.routine
          : GoalRouteType.finish;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _outcome.dispose();
    _starting.dispose();
    _proof.dispose();
    _horizon.dispose();
    _snag.dispose();
    super.dispose();
  }

  /// The Steward looks up for the first questions, studies his card through
  /// the middle ones and has the plan ready for the last. It only follows how
  /// far along the questions are.
  void _pose() {
    final next = _index <= 1
        ? GoalStewardExpression.welcome
        : _isLast
        ? GoalStewardExpression.ready
        : GoalStewardExpression.considering;
    if (widget.expression.value != next) widget.expression.value = next;
  }

  /// Steps back one question. Returns false when already on the first one, so
  /// the workshop can decide where back goes from there.
  bool stepBack() {
    if (_index == 0) return false;
    FocusScope.of(context).unfocus();
    setState(() {
      _index--;
      _error = null;
    });
    _pose();
    return true;
  }

  String? _validate() {
    switch (_ask) {
      case StewardAsk.name:
        final title = _name.text.trim();
        if (title.isEmpty) return 'Give this goal a short name.';
        if (widget.existingGoal == null && _goalKeys.contains(_key(title))) {
          return 'That goal is already on your list.';
        }
      case StewardAsk.outcome:
        if (_outcome.text.trim().isEmpty) return 'Say what will be different.';
      case StewardAsk.starting:
        if (_starting.text.trim().isEmpty) return 'Say where you are starting.';
      case StewardAsk.proof:
        if (_proof.text.trim().isEmpty) {
          return 'Say what would show it worked.';
        }
      case StewardAsk.snag:
        if (_snag.text.trim().isEmpty) {
          return 'Say what is most likely to get in the way.';
        }
      case StewardAsk.kind:
      case StewardAsk.stat:
      case StewardAsk.minutes:
      case StewardAsk.horizon:
        break;
    }
    return null;
  }

  void _continue() {
    if (widget.busy) return;
    FocusScope.of(context).unfocus();
    final problem = _validate();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    if (!_isLast) {
      setState(() {
        _index++;
        _error = null;
      });
      _pose();
      return;
    }
    final existing = widget.existingGoal;
    final title = existing?.title ?? _name.text;
    final stat = existing?.stat ?? _stat;
    final draft = GoalPlanner.draft(
      GoalPlanInput(
        title: title,
        stat: stat,
        type: _type,
        outcome: _outcome.text,
        startingPoint: _starting.text,
        successProof: _proof.text,
        timeBudgetMinutes: _minutes,
        obstacleCue: _snag.text,
        horizon: _horizon.text,
        now: Clock.now(),
      ),
    );
    widget.onResult(
      QuickGoalComposerResult.create(
        title: title.trim(),
        stat: stat,
        plan: draft,
      ),
    );
  }

  void _clearError() {
    if (_error != null) setState(() => _error = null);
  }

  ({String question, String help}) get _words => switch (_ask) {
    StewardAsk.name => (
      question: 'What do you want to work on?',
      help: 'A few words is plenty. You can change it later.',
    ),
    StewardAsk.outcome => (
      question: widget.nextChapter
          ? 'What do you want to be different next?'
          : 'When this is going well, what is different?',
      help: widget.nextChapter
          ? 'The last plan is finished. Picture what comes after it.'
          : 'Picture an ordinary day a few weeks from now.',
    ),
    StewardAsk.kind => (
      question: 'What kind of goal is this?',
      help: 'It changes how I shape the steps.',
    ),
    StewardAsk.stat => (
      question: 'Which part of your life does it belong to?',
      help: 'Its Quests will grow this part of you.',
    ),
    StewardAsk.starting => (
      question: 'Where are you starting from?',
      help: 'Be honest. A plan that begins where you really are holds up.',
    ),
    StewardAsk.proof => (
      question: 'What would show you it worked?',
      help: 'Something you could point to.',
    ),
    StewardAsk.minutes => (
      question: 'How much time can a normal try have?',
      help: 'Pick what a busy day could really spare.',
    ),
    StewardAsk.snag => (
      question: 'What is most likely to get in the way?',
      help: 'I will keep a smaller version ready for that day.',
    ),
    StewardAsk.horizon => (
      question: 'Is there a time you would like this done by?',
      help: 'Optional. Leave it empty if there is no deadline.',
    ),
  };

  static String _kindLabel(GoalRouteType type) => switch (type) {
    GoalRouteType.finish => 'Finish something',
    GoalRouteType.skill => 'Get better at something',
    GoalRouteType.routine => 'Build a habit',
    GoalRouteType.reset => 'Reset a space or situation',
  };

  static String _kindBlurb(GoalRouteType type) => switch (type) {
    GoalRouteType.finish => 'Make or complete one thing',
    GoalRouteType.skill => 'Become able to do something',
    GoalRouteType.routine => 'Make something repeatable',
    GoalRouteType.reset => 'Change a space or situation',
  };

  @override
  Widget build(BuildContext context) {
    final words = _words;
    final first = _index == 0;
    final newGoal = widget.existingGoal == null;
    return KeyedSubtree(
      key: const Key('steward-intake'),
      child: ClipPath(
        clipper: const FacetedClipper(cut: 13),
        child: DecoratedBox(
          decoration: facetedDecoration(
            cut: 13,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFA34261C), Color(0xFC160F0B)],
            ),
            borderColor: const Color(0xA8B47C43),
            borderWidth: 1.15,
            shadows: const [
              BoxShadow(
                color: Color(0xA1080503),
                blurRadius: 24,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(19, 15, 19, 0),
                child: Row(
                  children: [
                    const Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 15,
                      color: Palette.brassLit,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'THE STEWARD ASKS',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Type.label.copyWith(
                          fontSize: 11,
                          letterSpacing: 1.15,
                          color: Palette.brassLit,
                        ),
                      ),
                    ),
                    _AskProgress(
                      key: const Key('steward-ask-progress'),
                      count: _asks.length,
                      index: _index,
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  key: PageStorageKey<String>('steward-ask-scroll-$_index'),
                  padding: const EdgeInsets.fromLTRB(19, 12, 19, 10),
                  child: AnimatedSwitcher(
                    duration: Motion.quick,
                    switchInCurve: Motion.respond,
                    child: Column(
                      key: ValueKey(_ask),
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            words.question,
                            key: const Key('steward-ask-question'),
                            style: Type.display.copyWith(
                              fontSize: 25,
                              height: 1.06,
                              color: Palette.textHi,
                            ),
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          words.help,
                          style: Type.body.copyWith(
                            fontSize: 13.5,
                            height: 1.32,
                            color: Palette.textMid,
                          ),
                        ),
                        const SizedBox(height: 15),
                        _field(),
                        if (_error case final error?) ...[
                          const SizedBox(height: 10),
                          Text(
                            error,
                            key: const Key('steward-ask-error'),
                            style: Type.body.copyWith(
                              fontSize: 13,
                              height: 1.25,
                              color: const Color(0xFFE9A2A2),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0x3AAB7A49))),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        if (!first) ...[
                          HoneyButton(
                            key: const Key('steward-ask-back'),
                            label: 'Back',
                            quiet: true,
                            compact: true,
                            onTap: () => stepBack(),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: HoneyButton(
                            key: const Key('steward-ask-continue'),
                            label: _isLast ? 'Make my plan' : 'Continue',
                            icon: Icons.arrow_forward_rounded,
                            expand: true,
                            glow: false,
                            enabled: !widget.busy,
                            onTap: _continue,
                          ),
                        ),
                      ],
                    ),
                    if (first && newGoal) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: HoneyButton(
                              key: const Key('steward-ask-browse'),
                              label: 'Ready-made plans',
                              quiet: true,
                              compact: true,
                              onTap: () => widget.onResult(
                                const QuickGoalComposerResult.browse(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: HoneyButton(
                              key: const Key('steward-ask-manual'),
                              label: 'Set it up myself',
                              quiet: true,
                              compact: true,
                              onTap: () => widget.onResult(
                                const QuickGoalComposerResult.advanced(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field() => switch (_ask) {
    StewardAsk.name => _textField(
      key: 'steward-ask-name',
      controller: _name,
      hint: 'Make the apartment feel calm',
      lines: 1,
      display: true,
    ),
    StewardAsk.outcome => _textField(
      key: 'steward-ask-outcome',
      controller: _outcome,
      hint: 'I can come home and use the kitchen without feeling overwhelmed',
    ),
    StewardAsk.kind => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final type in GoalRouteType.values) ...[
          _KindChoice(
            type: type,
            label: _kindLabel(type),
            blurb: _kindBlurb(type),
            selected: type == _type,
            onTap: () => setState(() => _type = type),
          ),
          if (type != GoalRouteType.values.last) const SizedBox(height: 7),
        ],
      ],
    ),
    StewardAsk.stat => _statPicker(),
    StewardAsk.starting => _textField(
      key: 'steward-ask-starting-point',
      controller: _starting,
      hint: 'The counter is crowded and I avoid deciding where anything goes',
    ),
    StewardAsk.proof => _textField(
      key: 'steward-ask-proof',
      controller: _proof,
      hint: 'The counter stays usable for a normal week',
    ),
    StewardAsk.minutes => Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final minutes in const [5, 15, 30, 60])
          _MinutesChoice(
            minutes: minutes,
            selected: _minutes == minutes,
            onTap: () => setState(() => _minutes = minutes),
          ),
      ],
    ),
    StewardAsk.snag => _textField(
      key: 'steward-ask-snag',
      controller: _snag,
      hint: 'the whole thing feels too big after class',
      lines: 1,
    ),
    StewardAsk.horizon => _textField(
      key: 'steward-ask-horizon',
      controller: _horizon,
      hint: 'Before the semester begins',
      lines: 1,
    ),
  };

  Widget _textField({
    required String key,
    required TextEditingController controller,
    required String hint,
    int lines = 3,
    bool display = false,
  }) => TextField(
    key: Key(key),
    controller: controller,
    autofocus: true,
    minLines: lines == 1 ? 1 : 2,
    maxLines: lines,
    textCapitalization: TextCapitalization.sentences,
    textInputAction: TextInputAction.done,
    onSubmitted: (_) => _continue(),
    style: display
        ? Type.display.copyWith(fontSize: 18)
        : Type.body.copyWith(fontSize: 15.5, color: Palette.textHi),
    decoration: _fieldDecoration(hint),
    onChanged: (_) => _clearError(),
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
                  key: ValueKey('steward-ask-stat-${stat.name}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _stat = stat),
                  child: AnimatedContainer(
                    duration: Motion.quick,
                    constraints: const BoxConstraints(minHeight: 52),
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
                        Icon(stat.icon, size: 17, color: stat.color),
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

class _AskProgress extends StatelessWidget {
  const _AskProgress({super.key, required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Question ${index + 1} of $count',
    child: ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < count; i++) ...[
            AnimatedContainer(
              duration: Motion.quick,
              width: i == index ? 16 : 8,
              height: 3,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: i <= index
                    ? Palette.brassLit
                    : Palette.brassDeep.withValues(alpha: 0.7),
              ),
            ),
            if (i != count - 1) const SizedBox(width: 3),
          ],
        ],
      ),
    ),
  );
}

class _KindChoice extends StatelessWidget {
  const _KindChoice({
    required this.type,
    required this.label,
    required this.blurb,
    required this.selected,
    required this.onTap,
  });

  final GoalRouteType type;
  final String label;
  final String blurb;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: '$label. $blurb',
    child: InkWell(
      key: ValueKey('steward-ask-type-${type.name}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: Motion.quick,
        constraints: const BoxConstraints(minHeight: 56),
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Type.body.copyWith(
                      fontSize: 14.5,
                      height: 1.15,
                      fontWeight: FontWeight.w600,
                      color: selected ? Palette.xpLight : Palette.textHi,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    blurb,
                    style: Type.body.copyWith(
                      fontSize: 13,
                      height: 1.2,
                      color: Palette.textMid,
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

class _MinutesChoice extends StatelessWidget {
  const _MinutesChoice({
    required this.minutes,
    required this.selected,
    required this.onTap,
  });

  final int minutes;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ChoiceChip(
    key: ValueKey('steward-ask-minutes-$minutes'),
    label: Text('$minutes min'),
    selected: selected,
    onSelected: (_) => onTap(),
    selectedColor: Palette.xp.withValues(alpha: 0.2),
    backgroundColor: const Color(0xFF130E0B),
    side: BorderSide(
      color: selected ? Palette.xp : Palette.brassDeep.withValues(alpha: 0.65),
    ),
    labelStyle: Type.body.copyWith(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: selected ? Palette.xpLight : Palette.textMid,
    ),
    showCheckmark: false,
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
  );
}
