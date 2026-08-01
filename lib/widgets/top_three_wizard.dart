import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio.dart';
import '../models.dart';
import '../tokens.dart';
import 'facets.dart';
import 'glass.dart';
import 'honey_button.dart';

Future<Set<String>?> showTopThreeWizard(
  BuildContext context, {
  required String title,
  required String subtitle,
  required String dayLabel,
  required Iterable<Quest> candidates,
  Iterable<String> initialTitles = const [],
  Color accent = Palette.xpLight,
  String confirmLabel = 'KEEP THESE THREE',
  Future<Quest?> Function()? onAdd,
}) {
  return showModalBottomSheet<Set<String>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0xE0140C06),
    builder: (_) => _TopThreeWizard(
      title: title,
      subtitle: subtitle,
      dayLabel: dayLabel,
      candidates: candidates.toList(),
      initialTitles: initialTitles.toSet(),
      accent: accent,
      confirmLabel: confirmLabel,
      onAdd: onAdd,
    ),
  );
}

class _TopThreeWizard extends StatefulWidget {
  const _TopThreeWizard({
    required this.title,
    required this.subtitle,
    required this.dayLabel,
    required this.candidates,
    required this.initialTitles,
    required this.accent,
    required this.confirmLabel,
    required this.onAdd,
  });

  final String title;
  final String subtitle;
  final String dayLabel;
  final List<Quest> candidates;
  final Set<String> initialTitles;
  final Color accent;
  final String confirmLabel;
  final Future<Quest?> Function()? onAdd;

  @override
  State<_TopThreeWizard> createState() => _TopThreeWizardState();
}

class _TopThreeWizardState extends State<_TopThreeWizard> {
  late final List<Quest> _candidates = [...widget.candidates];
  late final Set<String> _selected = {
    for (final q in widget.candidates)
      if (widget.initialTitles.contains(q.title)) q.title,
  }.take(3).toSet();
  int _step = 0;
  bool _adding = false;

  void _toggle(Quest quest) {
    if (_selected.contains(quest.title)) {
      setState(() => _selected.remove(quest.title));
      Sfx.instance.play('tick');
      HapticFeedback.selectionClick();
      return;
    }
    if (_selected.length >= 3) {
      Sfx.instance.play('boing');
      HapticFeedback.lightImpact();
      return;
    }
    setState(() => _selected.add(quest.title));
    Sfx.instance.play('tick_lift');
    HapticFeedback.selectionClick();
  }

  Future<void> _add() async {
    final add = widget.onAdd;
    if (add == null || _adding) return;
    setState(() => _adding = true);
    final quest = await add();
    if (!mounted) return;
    setState(() {
      _adding = false;
      if (quest != null && !_candidates.any((q) => q.title == quest.title)) {
        _candidates.add(quest);
        if (_selected.length < 3) _selected.add(quest.title);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.92,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: GlassPanel(
          tint: const Color(0xFA281D1A),
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    widget.dayLabel.toUpperCase(),
                    style: Type.label.copyWith(
                      fontSize: 11,
                      color: widget.accent,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_step + 1} / 2',
                    style: Type.label.copyWith(fontSize: 10),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).pop(),
                    child: const Padding(
                      padding: EdgeInsets.all(7),
                      child: Icon(Icons.close, size: 18, color: Palette.textLo),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(widget.title, style: Type.display.copyWith(fontSize: 27)),
              const SizedBox(height: 4),
              Text(
                widget.subtitle,
                style: Type.body.copyWith(
                  fontSize: 13.5,
                  height: 1.35,
                  color: Palette.textLo,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: AnimatedSwitcher(
                  duration: Motion.settle,
                  child: _step == 0 ? _chooseStep() : _confirmStep(),
                ),
              ),
              const SizedBox(height: 12),
              if (_step == 0)
                HoneyButton(
                  label: _selected.isEmpty
                      ? 'CHOOSE UP TO THREE'
                      : 'REVIEW ${_selected.length} CHOICE${_selected.length == 1 ? '' : 'S'}',
                  icon: Icons.arrow_forward,
                  enabled: _selected.isNotEmpty,
                  expand: true,
                  onTap: () {
                    Sfx.instance.play('tick_lift');
                    setState(() => _step = 1);
                  },
                )
              else
                Row(
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _step = 0),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          'BACK',
                          style: Type.label.copyWith(fontSize: 11),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: HoneyButton(
                        label: widget.confirmLabel,
                        icon: Icons.auto_awesome,
                        expand: true,
                        onTap: () {
                          Sfx.instance.play('streak');
                          HapticFeedback.mediumImpact();
                          Navigator.of(context).pop(Set<String>.of(_selected));
                        },
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chooseStep() {
    return Column(
      key: const ValueKey('choose-three'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              '${_selected.length} OF 3 CHOSEN',
              style: Type.label.copyWith(fontSize: 11, color: widget.accent),
            ),
            const Spacer(),
            if (widget.onAdd != null)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _add,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 8,
                  ),
                  child: Text(
                    _adding ? 'ADDING…' : '+ ADD ONE',
                    style: Type.label.copyWith(
                      fontSize: 10.5,
                      color: Palette.xpLight,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Expanded(
          child: _candidates.isEmpty
              ? _emptyState()
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 8),
                  itemCount: _candidates.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 7),
                  itemBuilder: (_, index) {
                    final quest = _candidates[index];
                    return _ChoiceTile(
                      key: ValueKey('top-three-${quest.title}'),
                      quest: quest,
                      selected: _selected.contains(quest.title),
                      accent: widget.accent,
                      onTap: () => _toggle(quest),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bedtime_outlined, size: 34, color: widget.accent),
            const SizedBox(height: 10),
            Text(
              'Nothing is waiting',
              style: Type.display.copyWith(fontSize: 20),
            ),
            const SizedBox(height: 5),
            Text(
              'A clear day is allowed. Add one only if it would genuinely help.',
              textAlign: TextAlign.center,
              style: Type.body.copyWith(fontSize: 13.5, color: Palette.textLo),
            ),
            if (widget.onAdd != null) ...[
              const SizedBox(height: 12),
              HoneyButton(
                label: 'ADD ONE FOR TOMORROW',
                icon: Icons.add,
                onTap: _add,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _confirmStep() {
    final chosen = [
      for (final quest in _candidates)
        if (_selected.contains(quest.title)) quest,
    ];
    return ListView(
      key: const ValueKey('confirm-three'),
      padding: const EdgeInsets.fromLTRB(2, 8, 2, 8),
      children: [
        Icon(Icons.auto_awesome, size: 30, color: widget.accent),
        const SizedBox(height: 9),
        Text(
          chosen.length == 1 ? 'One clear promise' : 'Your day has a shape',
          textAlign: TextAlign.center,
          style: Type.display.copyWith(fontSize: 23),
        ),
        const SizedBox(height: 5),
        Text(
          'These lead the way. Everything else stays safely on your board.',
          textAlign: TextAlign.center,
          style: Type.body.copyWith(fontSize: 13.5, color: Palette.textLo),
        ),
        const SizedBox(height: 18),
        for (var i = 0; i < chosen.length; i++) ...[
          _ChosenTile(index: i + 1, quest: chosen[i], accent: widget.accent),
          if (i != chosen.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    super.key,
    required this.quest,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final Quest quest;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${quest.displayTitle}${selected ? ', chosen' : ''}',
      child: GestureDetector(
        excludeFromSemantics: true,
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 58),
          padding: const EdgeInsets.fromLTRB(12, 9, 11, 9),
          decoration: facetedDecoration(
            cut: 9,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: selected
                  ? [
                      accent.withValues(alpha: 0.17),
                      accent.withValues(alpha: 0.05),
                    ]
                  : const [Color(0x2EFFF2DC), Color(0x0AFFF2DC)],
            ),
            borderColor: selected
                ? accent.withValues(alpha: 0.72)
                : Palette.glassEdge,
          ),
          child: Row(
            children: [
              Transform.rotate(
                angle: 0.785,
                child: Container(width: 9, height: 9, color: quest.stat.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      quest.displayTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Type.body.copyWith(
                        fontSize: 14,
                        color: Palette.textHi,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${quest.stat.abbr} · ${quest.isEvent ? 'DATED' : quest.schedule.label.toUpperCase()} · ${quest.difficulty <= 3
                          ? 'LIGHT'
                          : quest.difficulty <= 6
                          ? 'STEADY'
                          : 'HEAVY'}',
                      style: Type.label.copyWith(fontSize: 10.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FacetCheck(selected: selected, accent: accent, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChosenTile extends StatelessWidget {
  const _ChosenTile({
    required this.index,
    required this.quest,
    required this.accent,
  });

  final int index;
  final Quest quest;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
      decoration: facetedDecoration(
        cut: 10,
        color: accent.withValues(alpha: 0.1),
        borderColor: accent.withValues(alpha: 0.5),
      ),
      child: Row(
        children: [
          Text(
            '$index',
            style: Type.numerals.copyWith(fontSize: 21, color: accent),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Text(
              quest.displayTitle,
              style: Type.body.copyWith(fontSize: 14.5, color: Palette.textHi),
            ),
          ),
          Transform.rotate(
            angle: 0.785,
            child: Container(width: 8, height: 8, color: quest.stat.color),
          ),
        ],
      ),
    );
  }
}
