import 'dart:async' show FutureOr;

import 'package:flutter/material.dart';

import '../audio.dart';
import '../haptics.dart';
import '../tokens.dart';

/// A warm glass toggle — a honey-glowing thumb sliding in a glass track — so the
/// one switch in the app (Reminders) matches the candlelit language instead of
/// reading as a cold stock-Material note in a warm room (round-34).
/// A callback for changes that need a permission or remote write before the
/// switch may truthfully acknowledge its new state. Return `true` only after
/// the displayed state has changed; `false` leaves the gesture silent.
typedef GlassSwitchAcceptedChange = FutureOr<bool> Function(bool value);

class GlassSwitch extends StatefulWidget {
  const GlassSwitch({
    super.key,
    required this.value,
    this.onChanged,
    this.onChangeAccepted,
    this.semanticLabel,
  }) : assert(onChanged != null || onChangeAccepted != null);

  final bool value;

  /// Use for local, unconditional state changes.
  final ValueChanged<bool>? onChanged;

  /// Use when a change can be declined after the gesture, for example by a
  /// system permission prompt. The glass detent plays only after it accepts.
  final GlassSwitchAcceptedChange? onChangeAccepted;
  final String? semanticLabel;

  @override
  State<GlassSwitch> createState() => _GlassSwitchState();
}

class _GlassSwitchState extends State<GlassSwitch> {
  bool _changing = false;

  Future<void> _toggle() async {
    if (_changing) return;
    final next = !widget.value;
    final acceptedChange = widget.onChangeAccepted;
    if (acceptedChange == null) {
      widget.onChanged!(next);
      Sfx.instance.playMaterial(MaterialSound.glass);
      Haptics.tap();
      return;
    }

    setState(() => _changing = true);
    var accepted = false;
    try {
      accepted = await acceptedChange(next);
    } catch (_) {
      // A rejected asynchronous change leaves both the displayed value and
      // the acoustic state untouched. Its owner can present any useful error.
      accepted = false;
    }
    if (!mounted) return;
    setState(() => _changing = false);
    if (!accepted) return;
    Sfx.instance.playMaterial(MaterialSound.glass);
    Haptics.tap();
  }

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      enabled: !_changing,
      mouseCursor: _changing
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            _toggle();
            return null;
          },
        ),
      },
      child: Semantics(
        container: true,
        button: true,
        enabled: !_changing,
        label: widget.semanticLabel,
        toggled: widget.value,
        onTap: _changing ? null : _toggle,
        child: SizedBox(
          width: 48,
          height: 48,
          child: GestureDetector(
            excludeFromSemantics: true,
            behavior: HitTestBehavior.opaque,
            onTap: _changing ? null : _toggle,
            child: Center(
              child: AnimatedContainer(
                duration: Motion.quick,
                curve: Motion.respond,
                width: 48,
                height: 28,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: widget.value
                      ? Palette.xp.withValues(alpha: 0.26)
                      : Palette.glassFill,
                  border: Border.all(
                    color: widget.value
                        ? Palette.xp.withValues(alpha: 0.7)
                        : Palette.glassEdge,
                  ),
                ),
                child: AnimatedAlign(
                  duration: Motion.quick,
                  curve: Motion.respond,
                  alignment: widget.value
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: widget.value ? Palette.honeyGradient : null,
                      color: widget.value
                          ? null
                          : Palette.textLo.withValues(alpha: 0.55),
                      boxShadow: widget.value
                          ? const [
                              BoxShadow(
                                color: Palette.honeyGlow,
                                blurRadius: 10,
                              ),
                            ]
                          : null,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
