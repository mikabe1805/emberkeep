import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../audio.dart';
import '../tokens.dart';

typedef PressableStateBuilder =
    Widget Function(
      BuildContext context,
      Widget child,
      bool pressed,
      bool focused,
      bool hovered,
    );

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
    this.stateBuilder,
    this.guardRapidReentry = false,
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

  /// Lets a material respond locally to press, focus, and hover while the
  /// shared control continues to own gesture arbitration and semantics.
  final PressableStateBuilder? stateBuilder;

  /// Holds a navigation or modal source through the next rendered frame so a
  /// second activation from the same touch/accessibility dispatch cannot fire.
  /// Frequent controls deliberately leave this false.
  final bool guardRapidReentry;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  static const _slop = 12.0;
  bool _down = false;
  bool _focused = false;
  bool _hovered = false;
  bool _pointerAcknowledged = false;
  bool _gestureCancelled = false;
  bool _activationLocked = false;
  Offset _downAt = Offset.zero;

  bool _claimActivation() {
    if (_activationLocked) return false;
    if (widget.guardRapidReentry) {
      _activationLocked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _activationLocked = false;
      });
    }
    return true;
  }

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
    required MaterialSound material,
    required Object? screenId,
  }) {
    if (!soundEnabled) return;
    Sfx.instance.playInteraction(role, screenId: screenId, material: material);
  }

  void _activate() {
    if (!widget.enabled || widget.onTapUp == null) return;
    if (!_claimActivation()) return;
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
      material: widget.material,
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
    // Keyboard focus should be as legible as touch depression, while mouse
    // hover stays a quieter material acknowledgement. Both use the existing
    // warm light tokens instead of a platform-blue halo that would sit outside
    // the keep's visual language.
    final highlightSide = BorderSide(
      color: _focused
          ? Palette.xpLight.withValues(alpha: 0.78)
          : _hovered
          ? Palette.brassLit.withValues(alpha: 0.24)
          : Colors.transparent,
      width: _focused ? 1.5 : 1,
    );
    final highlightDecoration = widget.shape is OutlinedBorder
        ? ShapeDecoration(
            shape: (widget.shape! as OutlinedBorder).copyWith(
              side: highlightSide,
            ),
          )
        : BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: highlightSide.color,
              width: highlightSide.width,
            ),
          );
    final presentedChild = widget.stateBuilder?.call(
      context,
      widget.child,
      _down,
      _focused,
      _hovered,
    );
    final manageActions = widget.onLongPress == null
        ? null
        : <CustomSemanticsAction, VoidCallback>{
            const CustomSemanticsAction(label: 'Manage'): widget.onLongPress!,
          };
    return FocusableActionDetector(
      enabled: widget.enabled,
      mouseCursor: widget.enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onShowFocusHighlight: (focused) {
        if (_focused != focused) setState(() => _focused = focused);
      },
      onShowHoverHighlight: (hovered) {
        if (_hovered != hovered) setState(() => _hovered = hovered);
      },
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
            if (_activationLocked) return;
            _downAt = e.position;
            _gestureCancelled = false;
            _setDown(true);
          },
          onPointerMove: (e) {
            // Pointer drifted into a scroll — release the visual immediately.
            if ((e.position - _downAt).distance > _slop) {
              _gestureCancelled = true;
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
            _gestureCancelled = false;
          },
          child: GestureDetector(
            excludeFromSemantics: true,
            onTapUp: (d) {
              if (!widget.enabled || widget.onTapUp == null) return;
              if (_gestureCancelled || !_claimActivation()) {
                _gestureCancelled = false;
                _pointerAcknowledged = false;
                return;
              }
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
                material: widget.material,
                screenId: screenId,
              );
              _pointerAcknowledged = false;
              _gestureCancelled = false;
            },
            onTapCancel: () {
              _gestureCancelled = false;
              _pointerAcknowledged = false;
              _setDown(false);
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
              child: Stack(
                fit: StackFit.passthrough,
                children: [
                  presentedChild ?? widget.child,
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedContainer(
                        key: const ValueKey('pressable-focus-highlight'),
                        duration: Motion.ack,
                        curve: Motion.respond,
                        decoration: highlightDecoration,
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
