import 'package:flutter/material.dart';

import '../audio.dart';
import '../engine.dart';
import '../haptics.dart';
import '../tokens.dart';
import 'glass.dart';
import 'home_room.dart';
import 'honey_button.dart';

/// How much room a day usually has — seeds the starter board (DESIGN Round-3).
enum TimeShape { light, full, packed }

/// First-run welcome: hearth → name → time shape → first fire.
/// Short on purpose; the Oath Wizard is the real ceremony.
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({
    super.key,
    required this.state,
    required this.onFinish,
  });

  final GameState state;

  /// [forgeFirstGoal] true → caller opens the Oath Wizard right after.
  /// [timeShape] seeds how dense the starter quest board should feel.
  final void Function({
    required bool forgeFirstGoal,
    required TimeShape timeShape,
  })
  onFinish;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  int _step = 0;
  final _name = TextEditingController();
  TimeShape _shape = TimeShape.full;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _next() {
    Sfx.instance.play('tick');
    Haptics.tap();
    setState(() => _step++);
  }

  void _finish({required bool forge}) {
    final name = _name.text.trim();
    widget.state.playerName = name.isEmpty ? null : name;
    widget.state.onboarded = true;
    widget.state.timeShape = _shape.name;
    Sfx.instance.play('streak');
    Haptics.success();
    widget.onFinish(forgeFirstGoal: forge, timeShape: _shape);
  }

  @override
  Widget build(BuildContext context) {
    return OverlaySurface(
      child: WarmBackground(
        themeId: widget.state.canvasTheme,
        reduceMotion: widget.state.reduceMotion,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                24,
                24,
                24,
                24 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 48,
                ),
                child: AnimatedSwitcher(
                  duration: Motion.settle,
                  child: switch (_step) {
                    0 => _welcome(),
                    1 => _naming(),
                    2 => _timeShape(),
                    _ => _firstFire(),
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _welcome() {
    return Column(
      key: const ValueKey(0),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            height: (MediaQuery.sizeOf(context).height * 0.23).clamp(120, 190),
            child: const HomeRoom(
              unlocked: {'rug', 'lamp', 'plant', 'pet'},
              petAwake: true,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text('Emberkeep', style: Type.display.copyWith(fontSize: 34)),
        const SizedBox(height: 8),
        Text(
          'your life is the game worth playing',
          textAlign: TextAlign.center,
          style: Type.body.copyWith(
            fontSize: 14,
            fontStyle: FontStyle.italic,
            color: Palette.textLo,
          ),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Real quests. Real XP. A fire banked each night,\nrekindled each morning.',
            textAlign: TextAlign.center,
            style: Type.body.copyWith(
              fontSize: 13,
              height: 1.6,
              color: Palette.textMid,
            ),
          ),
        ),
        const SizedBox(height: 36),
        _Cta(label: 'BEGIN', onTap: _next),
      ],
    );
  }

  Widget _naming() {
    return Column(
      key: const ValueKey(1),
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'What should the fire\ncall you?',
          textAlign: TextAlign.center,
          style: Type.display.copyWith(fontSize: 28, height: 1.2),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _name,
          maxLength: 40,
          autofocus: true,
          textAlign: TextAlign.center,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _next(),
          style: Type.display.copyWith(fontSize: 22, color: Palette.xpLight),
          decoration: InputDecoration(
            hintText: 'your name',
            hintStyle: Type.display.copyWith(
              fontSize: 22,
              color: Palette.textLo.withValues(alpha: 0.5),
            ),
            filled: true,
            counterText: '',
            fillColor: Palette.glassFill,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Palette.glassEdge),
            ),
          ),
        ),
        const SizedBox(height: 28),
        Center(
          child: _Cta(label: 'CONTINUE', onTap: _next),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: _next,
            child: Text(
              'rather not say',
              style: Type.label.copyWith(fontSize: 11),
            ),
          ),
        ),
      ],
    );
  }

  Widget _timeShape() {
    return Column(
      key: const ValueKey(2),
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'How much room\ndo your days have?',
          textAlign: TextAlign.center,
          style: Type.display.copyWith(fontSize: 26, height: 1.2),
        ),
        const SizedBox(height: 8),
        Text(
          'we’ll size your starter board to fit — you can always add more',
          textAlign: TextAlign.center,
          style: Type.body.copyWith(
            fontSize: 13,
            fontStyle: FontStyle.italic,
            color: Palette.textLo,
          ),
        ),
        const SizedBox(height: 24),
        _ShapePick(
          label: 'LIGHT DAYS',
          blurb: 'a few small quests — summer break, recovery, soft weeks',
          selected: _shape == TimeShape.light,
          onTap: () => setState(() => _shape = TimeShape.light),
        ),
        const SizedBox(height: 10),
        _ShapePick(
          label: 'FULL DAYS',
          blurb: 'a balanced board — the default pace for most lives',
          selected: _shape == TimeShape.full,
          onTap: () => setState(() => _shape = TimeShape.full),
        ),
        const SizedBox(height: 10),
        _ShapePick(
          label: 'PACKED DAYS',
          blurb: 'more on the table — two jobs, training, a full calendar',
          selected: _shape == TimeShape.packed,
          onTap: () => setState(() => _shape = TimeShape.packed),
        ),
        const SizedBox(height: 28),
        Center(
          child: _Cta(label: 'CONTINUE', onTap: _next),
        ),
      ],
    );
  }

  Widget _firstFire() {
    return Column(
      key: const ValueKey(3),
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Light your first fire',
          textAlign: TextAlign.center,
          style: Type.display.copyWith(fontSize: 28),
        ),
        const SizedBox(height: 8),
        Text(
          'a few starter quests are already on your board',
          textAlign: TextAlign.center,
          style: Type.body.copyWith(
            fontSize: 13.5,
            fontStyle: FontStyle.italic,
            color: Palette.textLo,
          ),
        ),
        const SizedBox(height: 24),
        _Cta(label: 'FORGE MY FIRST GOAL', onTap: () => _finish(forge: true)),
        const SizedBox(height: 10),
        Center(
          child: TextButton(
            onPressed: () => _finish(forge: false),
            child: Text(
              'I’ll explore first',
              style: Type.label.copyWith(fontSize: 11),
            ),
          ),
        ),
      ],
    );
  }
}

class _ShapePick extends StatelessWidget {
  const _ShapePick({
    required this.label,
    required this.blurb,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final String blurb;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$label. $blurb',
      onTap: onTap,
      child: GestureDetector(
        excludeFromSemantics: true,
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.settle,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: selected
                ? Palette.xp.withValues(alpha: 0.18)
                : Palette.glassFill,
            border: Border.all(
              color: selected ? Palette.xp : Palette.glassEdge,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Type.label.copyWith(
                  fontSize: 12,
                  color: selected ? Palette.xpLight : Palette.textMid,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                blurb,
                style: Type.body.copyWith(
                  fontSize: 12.5,
                  color: Palette.textLo,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Cta extends StatelessWidget {
  const _Cta({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: HoneyButton(label: label, onTap: onTap),
    );
  }
}
