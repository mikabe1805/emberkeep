import 'package:flutter/material.dart';
import '../audio.dart';
import '../clock.dart';
import '../haptics.dart';
import '../content/quest_suggestions.dart';
import '../models.dart';
import '../tokens.dart';
import 'pressable.dart';
import 'working_surface.dart';

Future<Set<String>?> showTopThreeWizard(
  BuildContext context, {
  required String title,
  required String subtitle,
  required String dayLabel,
  required Iterable<Quest> candidates,
  Iterable<String> initialTitles = const [],
  Iterable<Goal> goals = const [],
  DateTime? day,
  Color accent = Palette.xpLight,
  String confirmLabel = 'KEEP THESE THREE',
  Future<Quest?> Function()? onAdd,
}) => Navigator.of(context).push<Set<String>>(
  PageRouteBuilder<Set<String>>(
    settings: const RouteSettings(name: '/quests/choose'),
    transitionDuration:
        Haptics.reduceMotion || MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 260),
    reverseTransitionDuration:
        Haptics.reduceMotion || MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 180),
    pageBuilder: (_, animation, secondary) => _TopThreeWizard(
      title: title,
      dayLabel: dayLabel,
      candidates: candidates.toList(),
      initialTitles: initialTitles.toList(),
      goals: goals.toList(),
      day: day ?? Clock.now(),
      onAdd: onAdd,
    ),
    transitionsBuilder: (_, animation, secondary, child) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: child,
    ),
  ),
);

class _TopThreeWizard extends StatefulWidget {
  const _TopThreeWizard({
    required this.title,
    required this.dayLabel,
    required this.candidates,
    required this.initialTitles,
    required this.goals,
    required this.day,
    this.onAdd,
  });
  final String title, dayLabel;
  final List<Quest> candidates;
  final List<String> initialTitles;
  final List<Goal> goals;
  final DateTime day;
  final Future<Quest?> Function()? onAdd;
  @override
  State<_TopThreeWizard> createState() => _TopThreeWizardState();
}

class _TopThreeWizardState extends State<_TopThreeWizard> {
  late final Map<String, Quest> _candidates = () {
    final result = <String, Quest>{};
    for (final q in widget.candidates) {
      result.putIfAbsent(q.title, () => q);
    }
    return result;
  }();
  // Keep saved rank rather than reconstructing order from the source list.
  late final Set<String> _selected = widget.initialTitles
      .where(_candidates.containsKey)
      .take(3)
      .toSet();
  int? _minutes;
  bool _browseAll = false, _adding = false;
  String? _notice;

  void _toggle(Quest quest) => setState(() {
    _notice = null;
    if (_selected.remove(quest.title)) return;
    if (_selected.length == 3) {
      _notice = 'Your three are chosen. Remove one first to make room.';
    } else {
      _selected.add(quest.title);
    }
  });

  Future<void> _add() async {
    if (_adding || widget.onAdd == null) return;
    setState(() => _adding = true);
    try {
      final quest = await widget.onAdd!();
      if (!mounted || quest == null) return;
      setState(() {
        _candidates.putIfAbsent(quest.title, () => quest);
        if (_selected.length < 3) _selected.add(quest.title);
        _browseAll = true;
      });
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = suggestQuests(
      candidates: _candidates.values,
      goals: widget.goals,
      selectedTitles: _selected,
      day: widget.day,
      maxMinutes: _minutes,
    );
    final available = _candidates.values
        .where(
          (q) =>
              !_selected.contains(q.title) &&
              isAvailableSuggestionCandidate(
                q,
                goals: widget.goals,
                day: widget.day,
              ),
        )
        .toList();
    final reasons = {for (final s in suggestions) s.quest.title: s.reason};
    final shown = _browseAll
        ? available
        : suggestions.take(3).map((s) => s.quest).toList();
    final compact =
        MediaQuery.sizeOf(context).height < 720 ||
        MediaQuery.textScalerOf(context).scale(1) > 1.25;
    return Scaffold(
      backgroundColor: Palette.parchment,
      body: WorkingScene(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 20, 0),
                    child: Row(
                      children: [
                        WorkingAction(
                          label: 'Back',
                          icon: Icons.chevron_left,
                          iconLeading: true,
                          onTap: () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'ROOM of DAYS',
                            textAlign: TextAlign.right,
                            style: WorkingType.title.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              color: Palette.xpLight,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      key: const Key('choose-today-scroll'),
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(height: compact ? 14 : 52),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.title,
                                  style: WorkingType.title.copyWith(
                                    fontSize: compact ? 30 : 36,
                                    height: 1.06,
                                    fontWeight: FontWeight.w400,
                                    shadows: const [
                                      Shadow(
                                        color: Color(0xFF090504),
                                        blurRadius: 12,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 9),
                                Text(
                                  'Pick up to three. One or two is enough.',
                                  style: Type.body.copyWith(
                                    fontSize: 14,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  MaterialLocalizations.of(
                                    context,
                                  ).formatFullDate(widget.day),
                                  style: Type.body.copyWith(
                                    fontSize: 12,
                                    color: Palette.xpLight,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 22),
                          WorkingSurface(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        widget.dayLabel.toLowerCase().contains(
                                              'tomorrow',
                                            )
                                            ? 'CHOSEN FOR TOMORROW'
                                            : 'CHOSEN FOR TODAY',
                                        style: Type.label.copyWith(
                                          color: Palette.xpLight,
                                          fontSize: 10.5,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '${_selected.length} of 3',
                                      style: Type.body.copyWith(
                                        color: Palette.xpLight,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                if (_selected.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 20,
                                    ),
                                    child: Text(
                                      'What would feel good to have done?',
                                      style: WorkingType.title.copyWith(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                for (final (index, title) in _selected.indexed)
                                  _row(
                                    _candidates[title]!,
                                    selected: true,
                                    index: index + 1,
                                  ),
                                if (_notice != null)
                                  Semantics(
                                    liveRegion: true,
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 10),
                                      child: Text(
                                        _notice!,
                                        style: Type.body.copyWith(
                                          fontSize: 13,
                                          color: Palette.xpLight,
                                        ),
                                      ),
                                    ),
                                  ),
                                const WorkingRule(),
                                Text(
                                  'FIND A SESSION UP TO',
                                  style: Type.label.copyWith(
                                    fontSize: 10,
                                    color: Palette.textMid,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                _sessionFilters(),
                                const SizedBox(height: 16),
                                Text(
                                  _browseAll
                                      ? 'ALL AVAILABLE QUESTS'
                                      : 'WORTH CONSIDERING',
                                  style: Type.label.copyWith(
                                    fontSize: 10.5,
                                    color: Palette.xpLight,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                if (shown.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    child: Text(
                                      _browseAll
                                          ? 'Everything available is already chosen.'
                                          : _minutes == null
                                          ? 'Browse your available quests to choose what fits.'
                                          : 'No saved timer fits this length. All your other quests are still available below.',
                                      style: Type.body.copyWith(
                                        fontSize: 13,
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                for (final quest in shown)
                                  _row(
                                    quest,
                                    selected: false,
                                    reason: reasons[quest.title],
                                  ),
                                if (available.isNotEmpty)
                                  WorkingAction(
                                    label: _browseAll
                                        ? 'Show suggestions'
                                        : 'Browse all quests (${available.length})',
                                    icon: _browseAll
                                        ? Icons.expand_less
                                        : Icons.chevron_right,
                                    onTap: () => setState(
                                      () => _browseAll = !_browseAll,
                                    ),
                                  ),
                                if (widget.onAdd != null)
                                  WorkingAction(
                                    label: _adding ? 'Adding…' : 'Add a quest',
                                    icon: Icons.add,
                                    enabled: !_adding,
                                    onTap: _add,
                                  ),
                                const WorkingRule(),
                                WorkingAction(
                                  key: const Key('top-three-save'),
                                  label: _selected.isEmpty
                                      ? 'Choose one to begin'
                                      : _selected.length == 1
                                      ? 'Keep this 1'
                                      : 'Keep these ${_selected.length}',
                                  primary: true,
                                  enabled: _selected.isNotEmpty,
                                  sound: InteractionSound.place,
                                  icon: Icons.arrow_forward,
                                  onTap: () => Navigator.of(
                                    context,
                                  ).pop(Set<String>.of(_selected)),
                                ),
                                const SizedBox(height: 8),
                                WorkingAction(
                                  label: 'Cancel',
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

  Widget _sessionFilters() => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: const Color(0x44090504),
      borderRadius: BorderRadius.circular(27),
      border: Border.all(color: const Color(0x886F5133), width: .8),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        const values = <int?>[5, 10, 20, null];
        final fitsOneLine =
            constraints.maxWidth >= MediaQuery.textScalerOf(context).scale(260);
        return fitsOneLine
            ? Row(
                children: [
                  for (final value in values) Expanded(child: _filter(value)),
                ],
              )
            : Wrap(
                spacing: 5,
                runSpacing: 5,
                children: [for (final value in values) _filter(value)],
              );
      },
    ),
  );

  Widget _filter(int? minutes) {
    final selected = _minutes == minutes;
    final label = minutes == null ? 'Any' : '$minutes min';
    return Pressable(
      semanticLabel: 'Session length $label',
      edgeColor: Colors.transparent,
      semanticToggled: selected,
      interactionSound: InteractionSound.select,
      material: MaterialSound.glass,
      // The visible selected pill is the current filter, not a second action.
      // Keep a re-tap silent so a search refinement cannot become a metronome.
      soundEnabled: !selected,
      pressDepth: 1,
      onTapUp: (_) {
        if (selected) return;
        setState(() {
          _minutes = minutes;
          _browseAll = false;
        });
      },
      child: Container(
        constraints: const BoxConstraints(minWidth: 57, minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? const Color(0xFFEBCBA1) : Colors.transparent,
          ),
          gradient: selected
              ? const LinearGradient(
                  colors: [
                    Color(0x6659432F),
                    Color(0x66423942),
                    Color(0x33261B17),
                  ],
                )
              : null,
          boxShadow: selected
              ? const [BoxShadow(color: Color(0x30866A79), blurRadius: 9)]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: WorkingType.title.copyWith(
            fontSize: 18,
            color: selected ? Palette.textHi : Palette.textMid,
          ),
        ),
      ),
    );
  }

  Widget _row(
    Quest quest, {
    required bool selected,
    int? index,
    String? reason,
  }) {
    final done = quest.doneFor(widget.day);
    final aside = quest.snoozedDay == Days.key(widget.day);
    return Pressable(
      key: ValueKey('top-three-${quest.title}'),
      edgeColor: Colors.transparent,
      semanticLabel: '${selected ? 'Remove' : 'Choose'} ${quest.displayTitle}',
      semanticToggled: selected,
      interactionSound: InteractionSound.select,
      material: MaterialSound.glass,
      pressDepth: 1,
      onTapUp: (_) => _toggle(quest),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0x456F5133), width: .7),
          ),
        ),
        child: Row(
          children: [
            if (index != null) ...[
              SizedBox(
                width: 28,
                child: Text(
                  '$index',
                  style: WorkingType.title.copyWith(
                    fontSize: 26,
                    fontWeight: FontWeight.w400,
                    color: Palette.xpLight,
                  ),
                ),
              ),
              const SizedBox(width: 7),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    quest.displayTitle,
                    style: WorkingType.title.copyWith(
                      fontSize: 23,
                      fontWeight: FontWeight.w400,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    done
                        ? 'Done today · kept in your three'
                        : aside
                        ? 'Set aside · still chosen'
                        : reason ?? quest.goalTitle ?? 'A quest for you',
                    style: Type.body.copyWith(fontSize: 12.5, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF59402A), Color(0xFF20160F)],
                ),
                border: Border.all(
                  color: Palette.xpLight.withValues(alpha: .55),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0xBB0C0704),
                    blurRadius: 5,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                selected ? Icons.remove : Icons.add,
                color: Palette.xpLight,
                size: 23,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
