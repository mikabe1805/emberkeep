import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio.dart';
import '../engine.dart';
import '../tokens.dart';
import 'glass.dart';
import 'portrait.dart';

/// First-run welcome (round-9): three warm beats — the hearth, your name,
/// your first fire. Short on purpose; the Oath Wizard is the real ceremony.
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({
    super.key,
    required this.state,
    required this.onFinish,
  });

  final GameState state;

  /// [forgeFirstGoal] true → caller opens the Oath Wizard right after.
  final void Function({required bool forgeFirstGoal}) onFinish;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  int _step = 0;
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _next() {
    Sfx.instance.play('tick');
    HapticFeedback.selectionClick();
    setState(() => _step++);
  }

  void _finish({required bool forge}) {
    final name = _name.text.trim();
    widget.state.playerName = name.isEmpty ? null : name;
    widget.state.onboarded = true;
    Sfx.instance.play('streak');
    HapticFeedback.mediumImpact();
    widget.onFinish(forgeFirstGoal: forge);
  }

  @override
  Widget build(BuildContext context) {
    return OverlaySurface(
      child: Container(
        color: const Color(0xFA191210),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: AnimatedSwitcher(
              duration: Motion.settle,
              child: switch (_step) {
                0 => _welcome(),
                1 => _naming(),
                _ => _firstFire(),
              },
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
        const Portrait(size: 110),
        const SizedBox(height: 24),
        Text('Emberkeep', style: Type.display.copyWith(fontSize: 34)),
        const SizedBox(height: 8),
        Text('your life is the game worth playing',
            textAlign: TextAlign.center,
            style: Type.body.copyWith(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: Palette.textLo)),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
              'Real quests. Real XP. A fire banked each night,\nrekindled each morning.',
              textAlign: TextAlign.center,
              style: Type.body.copyWith(
                  fontSize: 13, height: 1.6, color: Palette.textMid)),
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
        Text('What should the fire\ncall you?',
            textAlign: TextAlign.center,
            style: Type.display.copyWith(fontSize: 28, height: 1.2)),
        const SizedBox(height: 20),
        TextField(
          controller: _name,
          autofocus: true,
          textAlign: TextAlign.center,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _next(),
          style: Type.display.copyWith(fontSize: 22, color: Palette.xpLight),
          decoration: InputDecoration(
            hintText: 'your name',
            hintStyle: Type.display.copyWith(
                fontSize: 22, color: Palette.textLo.withValues(alpha: 0.5)),
            filled: true,
            fillColor: Palette.glassFill,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Palette.glassEdge),
            ),
          ),
        ),
        const SizedBox(height: 28),
        Center(child: _Cta(label: 'CONTINUE', onTap: _next)),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: _next,
            child: Text('rather not say',
                style: Type.label.copyWith(fontSize: 11)),
          ),
        ),
      ],
    );
  }

  Widget _firstFire() {
    return Column(
      key: const ValueKey(2),
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Light your first fire',
            textAlign: TextAlign.center,
            style: Type.display.copyWith(fontSize: 28)),
        const SizedBox(height: 8),
        Text('a few starter quests are already on your board',
            textAlign: TextAlign.center,
            style: Type.body.copyWith(
                fontSize: 13.5,
                fontStyle: FontStyle.italic,
                color: Palette.textLo)),
        const SizedBox(height: 24),
        _Cta(
          label: '⚔ FORGE MY FIRST GOAL',
          onTap: () => _finish(forge: true),
        ),
        const SizedBox(height: 10),
        Center(
          child: TextButton(
            onPressed: () => _finish(forge: false),
            child: Text('I’ll explore first',
                style: Type.label.copyWith(fontSize: 11)),
          ),
        ),
      ],
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
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF2CD93), Color(0xFFC08B4F)],
            ),
            boxShadow: const [
              BoxShadow(
                  color: Palette.honeyGlow,
                  blurRadius: 20,
                  offset: Offset(0, 6)),
            ],
          ),
          child: Text(label,
              style: Type.label
                  .copyWith(fontSize: 12, color: const Color(0xFF3A2510))),
        ),
      ),
    );
  }
}
