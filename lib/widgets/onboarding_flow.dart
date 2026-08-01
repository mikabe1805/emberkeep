import 'package:flutter/material.dart';

import '../audio.dart';
import '../clock.dart';
import '../engine.dart';
import '../haptics.dart';
import '../tokens.dart';
import 'facets.dart';
import 'glass.dart';
import 'honey_button.dart';

/// How much room a day usually has — seeds the starter board (DESIGN Round-3).
enum TimeShape { light, full, packed }

/// First-run welcome: brand room → name → time shape → first quest.
/// Short on purpose; the starter board is the fastest path to a first win.
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

  void _back() {
    if (_step == 0) return;
    Sfx.instance.play('tick');
    Haptics.tap();
    setState(() => _step--);
  }

  String get _greeting {
    final hour = Clock.now().hour;
    if (hour < 12) return 'Good morning.';
    if (hour < 17) return 'Good afternoon.';
    return 'Good evening.';
  }

  Widget _stepHeader() => Row(
    children: [
      if (_step > 0)
        Semantics(
          button: true,
          label: 'Back',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _back,
            child: const Padding(
              padding: EdgeInsets.fromLTRB(0, 8, 12, 8),
              child: Icon(
                Icons.chevron_left_rounded,
                size: 24,
                color: Palette.textMid,
              ),
            ),
          ),
        )
      else
        const SizedBox(width: 36),
      Expanded(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < 4; i++) ...[
              AnimatedContainer(
                duration: Motion.quick,
                width: i == _step ? 28 : 12,
                height: 3,
                decoration: BoxDecoration(
                  color: i <= _step ? Palette.xp : Palette.glassEdge,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              if (i != 3) const SizedBox(width: 5),
            ],
          ],
        ),
      ),
      SizedBox(
        width: 36,
        child: Text(
          '${_step + 1}/4',
          textAlign: TextAlign.right,
          style: Type.label.copyWith(fontSize: 9.5, color: Palette.textLo),
        ),
      ),
    ],
  );

  Widget _fact(IconData icon, String title, String copy) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FacetMedallion(
          size: 34,
          accent: Palette.xp,
          child: Icon(icon, size: 17, color: Palette.xpLight),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Type.label.copyWith(fontSize: 10.5)),
              const SizedBox(height: 2),
              Text(
                copy,
                style: Type.body.copyWith(
                  fontSize: 12,
                  height: 1.3,
                  color: Palette.textLo,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return OverlaySurface(
      child: WarmBackground(
        themeId: widget.state.canvasTheme,
        reduceMotion: widget.state.reduceMotion,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final short = constraints.maxHeight < 640;
              final horizontalPad = constraints.maxWidth < 360 ? 18.0 : 24.0;
              final verticalPad = short ? 12.0 : 24.0;
              return SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  horizontalPad,
                  verticalPad,
                  horizontalPad,
                  verticalPad + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - verticalPad * 2,
                  ),
                  child: AnimatedSwitcher(
                    duration: Motion.settle,
                    child: switch (_step) {
                      0 => _welcome(),
                      1 => _naming(),
                      2 => _timeShape(),
                      _ => _firstQuest(),
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _welcome() {
    final height = MediaQuery.sizeOf(context).height;
    final compact = height < 640;
    final short = height < 590;
    return Column(
      key: const ValueKey(0),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _stepHeader(),
        SizedBox(height: short ? 5 : (compact ? 8 : 14)),
        ClipPath(
          clipper: const FacetedClipper(cut: 18),
          child: SizedBox(
            height: compact
                ? (short ? 76 : 104)
                : (MediaQuery.sizeOf(context).height * 0.26).clamp(132, 210),
            // The opening image is the finished room aspiration. Loading this
            // single authored plate directly prevents the first-run screen
            // from briefly flashing the procedural fallback while the live,
            // layered room textures decode in the background.
            child: Image.asset(
              'assets/rooms/wall_walnut-clean-v2.webp',
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
              gaplessPlayback: true,
              cacheWidth: 900,
            ),
          ),
        ),
        SizedBox(height: short ? 7 : (compact ? 12 : 22)),
        Text(
          'Morrowloom',
          style: Type.display.copyWith(
            fontSize: short ? 27 : (compact ? 31 : 36),
            letterSpacing: 0.6,
          ),
        ),
        SizedBox(height: short ? 2 : (compact ? 4 : 7)),
        Text(
          'a quest ledger for the life you’re actually living',
          textAlign: TextAlign.center,
          style: Type.body.copyWith(
            fontSize: short ? 12 : (compact ? 13.5 : 14.5),
            fontStyle: FontStyle.italic,
            color: Palette.textMid,
          ),
        ),
        SizedBox(height: short ? 5 : (compact ? 8 : 13)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'Turn the things you mean to do into quests. Finish them for XP '
            'and Glimmers; the room and journal keep the evidence.',
            textAlign: TextAlign.center,
            style: Type.body.copyWith(
              fontSize: short ? 11.2 : (compact ? 12 : 13),
              height: short ? 1.24 : (compact ? 1.32 : 1.45),
              color: Palette.textMid,
            ),
          ),
        ),
        SizedBox(height: short ? 9 : (compact ? 14 : 28)),
        _Cta(label: 'ENTER MORROWLOOM', onTap: _next),
      ],
    );
  }

  Widget _naming() {
    final height = MediaQuery.sizeOf(context).height;
    final compact = height < 640;
    final short = height < 590;
    return Column(
      key: const ValueKey(1),
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _stepHeader(),
        SizedBox(height: short ? 5 : (compact ? 18 : 44)),
        if (!short) ...[
          Center(
            child: FacetMedallion(
              size: compact ? 44 : 52,
              accent: Palette.xp,
              glow: true,
              child: const Icon(
                Icons.person_outline_rounded,
                size: 25,
                color: Palette.xpLight,
              ),
            ),
          ),
          SizedBox(height: compact ? 10 : 18),
        ],
        Text(
          '$_greeting\nWhat should this place call you?',
          textAlign: TextAlign.center,
          style: Type.display.copyWith(
            fontSize: short ? 19.5 : (compact ? 23 : 27),
            height: short ? 1.10 : 1.18,
          ),
        ),
        SizedBox(height: short ? 3 : (compact ? 7 : 11)),
        Text(
          'Only the occasional greeting uses it. You can change it later.',
          textAlign: TextAlign.center,
          style: Type.body.copyWith(
            fontSize: short ? 10.5 : (compact ? 11.5 : 12.5),
            fontStyle: FontStyle.italic,
            color: Palette.textLo,
          ),
        ),
        SizedBox(height: short ? 7 : (compact ? 12 : 22)),
        GlassPanel(
          glow: true,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          child: TextField(
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
              counterText: '',
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                vertical: short ? 6 : (compact ? 10 : 14),
              ),
            ),
          ),
        ),
        SizedBox(height: short ? 7 : (compact ? 12 : 28)),
        Center(
          child: _Cta(label: 'CONTINUE', onTap: _next),
        ),
        SizedBox(height: short ? 0 : (compact ? 2 : 8)),
        Center(
          child: TextButton(
            onPressed: _next,
            child: Text(
              'skip for now',
              style: Type.label.copyWith(fontSize: 11),
            ),
          ),
        ),
      ],
    );
  }

  Widget _timeShape() {
    final compact = MediaQuery.sizeOf(context).height < 640;
    return Column(
      key: const ValueKey(2),
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _stepHeader(),
        SizedBox(height: compact ? 14 : 34),
        Text(
          'How full are your\ndays, usually?',
          textAlign: TextAlign.center,
          style: Type.display.copyWith(
            fontSize: compact ? 23 : 26,
            height: 1.2,
          ),
        ),
        SizedBox(height: compact ? 5 : 8),
        Text(
          'This only sets the first board. Nothing is a permanent pace.',
          textAlign: TextAlign.center,
          style: Type.body.copyWith(
            fontSize: compact ? 11.5 : 13,
            fontStyle: FontStyle.italic,
            color: Palette.textLo,
          ),
        ),
        SizedBox(height: compact ? 12 : 24),
        _ShapePick(
          label: 'LIGHT DAYS',
          blurb: '3 small quests · recovery, soft weeks, room to breathe',
          selected: _shape == TimeShape.light,
          onTap: () => setState(() => _shape = TimeShape.light),
        ),
        SizedBox(height: compact ? 6 : 10),
        _ShapePick(
          label: 'FULL DAYS',
          blurb: '5 balanced quests · enough shape without a packed board',
          selected: _shape == TimeShape.full,
          onTap: () => setState(() => _shape = TimeShape.full),
        ),
        SizedBox(height: compact ? 6 : 10),
        _ShapePick(
          label: 'PACKED DAYS',
          blurb: '7 varied quests · training, focus, a genuinely full calendar',
          selected: _shape == TimeShape.packed,
          onTap: () => setState(() => _shape = TimeShape.packed),
        ),
        SizedBox(height: compact ? 12 : 28),
        Center(
          child: _Cta(label: 'CONTINUE', onTap: _next),
        ),
      ],
    );
  }

  Widget _firstQuest() {
    final compact = MediaQuery.sizeOf(context).height < 640;
    return Column(
      key: const ValueKey(3),
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _stepHeader(),
        SizedBox(height: compact ? 12 : 30),
        Text(
          '${_name.text.trim().isEmpty ? 'Your' : '${_name.text.trim()}’s'} first board is ready',
          textAlign: TextAlign.center,
          style: Type.display.copyWith(fontSize: compact ? 24 : 28),
        ),
        SizedBox(height: compact ? 5 : 8),
        Text(
          'Start small. You can replace every starter quest once you know what fits.',
          textAlign: TextAlign.center,
          style: Type.body.copyWith(
            fontSize: compact ? 12 : 13.5,
            fontStyle: FontStyle.italic,
            color: Palette.textLo,
          ),
        ),
        SizedBox(height: compact ? 10 : 20),
        GlassPanel(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Column(
            children: [
              _fact(
                Icons.task_alt_rounded,
                'FINISH A QUEST',
                'XP and Glimmers land on the thing you actually completed.',
              ),
              _fact(
                Icons.chair_outlined,
                'THE ROOM RESPONDS',
                'Your room begins complete, and the atmosphere you choose stays visible without another checklist.',
              ),
              _fact(
                Icons.edit_note_rounded,
                'THE JOURNAL KEEPS CONTEXT',
                'When you write, today’s quests and build attach themselves.',
              ),
            ],
          ),
        ),
        SizedBox(height: compact ? 10 : 22),
        _Cta(label: 'OPEN TODAY’S QUESTS', onTap: () => _finish(forge: false)),
        SizedBox(height: compact ? 3 : 10),
        Center(
          child: TextButton(
            onPressed: () => _finish(forge: true),
            child: Text(
              'set a goal first',
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
          decoration: facetedDecoration(
            cut: 10,
            color: selected
                ? Palette.xp.withValues(alpha: 0.18)
                : Palette.glassFill,
            borderColor: selected ? Palette.xp : Palette.glassEdge,
            borderWidth: selected ? 1.4 : 1,
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
