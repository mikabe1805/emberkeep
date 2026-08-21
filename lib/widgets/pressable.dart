import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../audio.dart';
import '../tokens.dart';

/// Stable sound identity for one visible app screen. A nested Navigator route
/// overrides the inherited tab identity, while the five IndexedStack pages
/// retain their own identity across rebuilds and scrolls.
class InteractionSoundScreenScope extends InheritedWidget {
  const InteractionSoundScreenScope({
    super.key,
    required this.id,
    required this.sourceRoute,
    required super.child,
  });

  final Object id;
  final Route<dynamic>? sourceRoute;

  static Object? maybeScreenIdOf(BuildContext context) {
    final scope = context
        .getInheritedWidgetOfExactType<InteractionSoundScreenScope>();
    final route = ModalRoute.of(context);
    if (route != null &&
        (scope == null || !identical(route, scope.sourceRoute))) {
      return route;
    }
    return scope?.id ?? route;
  }

  @override
  bool updateShouldNotify(InteractionSoundScreenScope oldWidget) =>
      !identical(id, oldWidget.id) ||
      !identical(sourceRoute, oldWidget.sourceRoute);
}

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
    this.shape,
    this.enabled = true,
    this.pressDepth = 4,
    this.material = MaterialSound.wood,
    this.interactionSound,
    this.soundEnabled = true,
    this.semanticLabel,
    this.semanticHint,
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
  final ShapeBorder? shape;
  final bool enabled;
  final double pressDepth;
  final MaterialSound material;
  final InteractionSound? interactionSound;
  final bool soundEnabled;
  final String? semanticLabel;
  final String? semanticHint;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  static const _slop = 12.0;
  bool _down = false;
  bool _pointerAcknowledged = false;
  Offset _downAt = Offset.zero;

  void _setDown(bool down) {
    if (!widget.enabled || _down == down) return;
    setState(() => _down = down);
    if (down) {
      _pointerAcknowledged = true;
      HapticFeedback.selectionClick();
    }
  }

  void _playAcceptedSound({
    required bool soundEnabled,
    required InteractionSound role,
    required Object? screenId,
  }) {
    if (!soundEnabled) return;
    Sfx.instance.playInteraction(
      role,
      screenId: screenId,
      material: widget.material,
    );
  }

  void _activate() {
    if (!widget.enabled || widget.onTapUp == null) return;
    // Keyboard and accessibility activation have no pointer-down phase. Give
    // them the same single physical acknowledgement without duplicating touch.
    if (!_pointerAcknowledged) {
      HapticFeedback.selectionClick();
    }
    _pointerAcknowledged = false;
    final box = context.findRenderObject() as RenderBox?;
    final center = box == null
        ? Offset.zero
        : box.localToGlobal(box.size.center(Offset.zero));
    final callback = widget.onTapUp!;
    final soundEnabled = widget.soundEnabled;
    final role =
        widget.interactionSound ?? interactionForMaterial(widget.material);
    final screenId = InteractionSoundScreenScope.maybeScreenIdOf(context);
    callback(center);
    _playAcceptedSound(
      soundEnabled: soundEnabled,
      role: role,
      screenId: screenId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? BorderRadius.circular(14);
    final drop = widget.pressDepth.clamp(0.0, 6.0).toDouble();
    // deep espresso under-edge — warm, never grey
    final edge = widget.edgeColor ?? const Color(0xFF0F0905);
    final shadows = _down
        ? const <BoxShadow>[]
        : [BoxShadow(color: edge, offset: Offset(0, drop))];
    final edgeDecoration = widget.shape == null
        ? BoxDecoration(borderRadius: radius, boxShadow: shadows)
        : ShapeDecoration(shape: widget.shape!, shadows: shadows);
    final manageActions = widget.onLongPress == null
        ? null
        : <CustomSemanticsAction, VoidCallback>{
            const CustomSemanticsAction(label: 'Manage'): widget.onLongPress!,
          };
    return FocusableActionDetector(
      mouseCursor: widget.enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            _activate();
            return null;
          },
        ),
      },
      child: Semantics(
        container: true,
        button: widget.onTapUp != null,
        enabled: widget.enabled,
        label: widget.semanticLabel,
        hint: widget.semanticHint,
        onTap: widget.enabled ? _activate : null,
        customSemanticsActions: manageActions,
        child: Listener(
          onPointerDown: (e) {
            _downAt = e.position;
            _setDown(true);
          },
          onPointerMove: (e) {
            // Pointer drifted into a scroll — release the visual immediately.
            if ((e.position - _downAt).distance > _slop) {
              _setDown(false);
              _pointerAcknowledged = false;
            }
          },
          onPointerUp: (_) {
            _setDown(false);
            // GestureDetector's pointer path invokes the callback directly,
            // so this may clear now even if the arena ultimately declines the
            // tap. Never carry a stale touch ack into later keyboard/VO use.
            _pointerAcknowledged = false;
          },
          onPointerCancel: (_) {
            _setDown(false);
            _pointerAcknowledged = false;
          },
          child: GestureDetector(
            excludeFromSemantics: true,
            onTapUp: (d) {
              if (!widget.enabled || widget.onTapUp == null) return;
              final callback = widget.onTapUp!;
              final soundEnabled = widget.soundEnabled;
              final role =
                  widget.interactionSound ??
                  interactionForMaterial(widget.material);
              final screenId = InteractionSoundScreenScope.maybeScreenIdOf(
                context,
              );
              callback(d.globalPosition);
              _playAcceptedSound(
                soundEnabled: soundEnabled,
                role: role,
                screenId: screenId,
              );
              _pointerAcknowledged = false;
            },
            onLongPress: widget.onLongPress == null
                ? null
                : () {
                    _pointerAcknowledged = false;
                    widget.onLongPress!.call();
                  },
            child: AnimatedContainer(
              // physical buttons depress instantly; only the release eases
              duration: _down ? Duration.zero : Motion.ack,
              curve: Motion.respond,
              transform: Matrix4.translationValues(0, _down ? drop : 0, 0),
              decoration: edgeDecoration,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
