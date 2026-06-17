import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio.dart';
import '../tokens.dart';

/// Faux-3D press: thick bottom edge that collapses as the child drops 4px,
/// paired with a haptic tick — every tap feels physical before any reward
/// logic runs (Duolingo's cheapest juice, DESIGN.md §2).
///
/// The down-state is driven by a raw [Listener], not GestureDetector: inside
/// a scrollable, tap recognizers wait out the gesture arena (~100ms) before
/// firing, which would blow the 100ms first-feedback budget. Pointer-down is
/// instant and unarbitrated; we cancel the visual ourselves if the pointer
/// drifts into a scroll. The drop itself is a paint-only transform so the
/// surrounding list never reflows.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTapUp,
    this.onLongPress,
    this.edgeColor,
    this.borderRadius,
    this.enabled = true,
  });

  final Widget child;

  /// Reports the tap's global position (for anchoring reward overlays).
  /// Still arena-arbitrated via GestureDetector, so scrolls never complete.
  final void Function(Offset globalPosition)? onTapUp;

  /// Long-press (management affordance) — works even when [enabled] is
  /// false, so done quests can still be managed.
  final VoidCallback? onLongPress;
  final Color? edgeColor;
  final BorderRadius? borderRadius;
  final bool enabled;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  static const _drop = 4.0;
  static const _slop = 12.0;
  bool _down = false;
  Offset _downAt = Offset.zero;

  void _setDown(bool down) {
    if (!widget.enabled || _down == down) return;
    setState(() => _down = down);
    if (down) {
      HapticFeedback.selectionClick();
      Sfx.instance.play('tick');
    }
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? BorderRadius.circular(14);
    // deep espresso under-edge — warm, never grey
    final edge = widget.edgeColor ?? const Color(0xFF0F0905);
    return Listener(
      onPointerDown: (e) {
        _downAt = e.position;
        _setDown(true);
      },
      onPointerMove: (e) {
        // pointer drifted into a scroll — release the visual
        if ((e.position - _downAt).distance > _slop) _setDown(false);
      },
      onPointerUp: (_) => _setDown(false),
      onPointerCancel: (_) => _setDown(false),
      child: GestureDetector(
        onTapUp: (d) {
          if (widget.enabled) widget.onTapUp?.call(d.globalPosition);
        },
        onLongPress: widget.onLongPress,
        child: AnimatedContainer(
          // physical buttons depress instantly; only the release eases
          duration: _down ? Duration.zero : Motion.ack,
          curve: Motion.respond,
          transform: Matrix4.translationValues(0, _down ? _drop : 0, 0),
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: _down
                ? const []
                : [BoxShadow(color: edge, offset: const Offset(0, _drop))],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
