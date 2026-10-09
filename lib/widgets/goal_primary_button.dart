import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../audio.dart';
import '../tokens.dart';
import 'facets.dart';
import 'lamplight.dart';
import 'pressable.dart';

const goalsThresholdPlateAsset =
    'assets/pages/goals-threshold-plate-flat-v1.png';

enum GoalPrimaryButtonTreatment {
  standard,
  openingClasp,
  returnClasp,
  questFolio,
  thresholdPlate,
}

/// The one luminous action inside the Goals world.
///
/// It is satin metal rather than a flat yellow fill or a glossy plastic slab:
/// one warm value roll, a fine lit lip, a quiet room-driven reflection, and a
/// shallow under-plane that physically collapses under the finger. Activation
/// paints a brief pending state before navigation begins and rejects a second
/// tap while the first handoff is resolving.
class GoalPrimaryButton extends StatefulWidget {
  const GoalPrimaryButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.expand = false,
    this.glow = true,
    this.enabled = true,
    this.reduceMotion = false,
    this.light,
    this.pendingLabel = 'Opening',
    this.semanticHint,
    this.treatment = GoalPrimaryButtonTreatment.standard,
    this.folioTitle,
    this.folioEyebrow,
    this.folioIcon,
    this.folioAccent,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool expand;
  final bool glow;
  final bool enabled;
  final bool reduceMotion;
  final ValueListenable<Offset>? light;
  final String pendingLabel;
  final String? semanticHint;
  final GoalPrimaryButtonTreatment treatment;
  final String? folioTitle;
  final String? folioEyebrow;
  final IconData? folioIcon;
  final Color? folioAccent;

  @override
  State<GoalPrimaryButton> createState() => _GoalPrimaryButtonState();
}

class _GoalPrimaryButtonState extends State<GoalPrimaryButton> {
  bool _pending = false;

  void _activate() {
    if (!widget.enabled || _pending) return;
    setState(() => _pending = true);

    // Paint one truthful accepted frame at the source before navigation or a
    // sheet can cover it. This is still only one frame of latency: contact
    // compression and sound already began under the finger, while the pending
    // label confirms that the release was accepted and guards rapid re-entry.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onTap();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _pending = false);
      });
    });
  }

  Widget _questFolioFace({
    required bool pressed,
    required bool focused,
    required bool hovered,
  }) {
    final still =
        widget.reduceMotion ||
        (MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    final animation =
        widget.light ?? const AlwaysStoppedAnimation<Offset>(Offset.zero);
    final accent = widget.folioAccent ?? Palette.xpLight;
    final title = widget.folioTitle ?? widget.label;
    final eyebrow = widget.folioEyebrow;

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final light = still ? Offset.zero : animation.value;
        return LayoutBuilder(
          builder: (context, constraints) {
            final textScale = MediaQuery.textScalerOf(context).scale(1);
            final stacked =
                constraints.maxWidth < 338 ||
                textScale > 1.22 ||
                title.length > 32 ||
                widget.label.length > 8;
            final edge = focused
                ? const Color(0xFFEBCB91)
                : hovered
                ? const Color(0xA8D7AD72)
                : pressed
                ? const Color(0xA8B57D3F)
                : const Color(0x6A9B7148);
            final latchInk = widget.enabled
                ? const Color(0xFFF0C982)
                : Palette.textLo;
            final actionCopy = _pending ? widget.pendingLabel : widget.label;

            Widget identity() => SizedBox(
              width: 36,
              child: Align(
                alignment: stacked ? Alignment.topLeft : Alignment.centerLeft,
                child: Icon(
                  widget.folioIcon ?? widget.icon,
                  size: 22,
                  color: accent.withValues(alpha: widget.enabled ? 0.96 : 0.55),
                ),
              ),
            );

            Widget copy() => Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (eyebrow case final copy?) ...[
                    Text(
                      copy,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'EBGaramond',
                        fontSize: 15,
                        height: 1.05,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.12,
                      ).copyWith(color: accent.withValues(alpha: 0.92)),
                    ),
                    const SizedBox(height: 5),
                  ],
                  Text(
                    title,
                    maxLines: stacked ? 3 : 2,
                    overflow: TextOverflow.ellipsis,
                    textScaler: MediaQuery.textScalerOf(
                      context,
                    ).clamp(maxScaleFactor: 1.45),
                    style: Type.display.copyWith(
                      fontSize: stacked ? 22.5 : 21.5,
                      height: 1.06,
                      fontWeight: FontWeight.w500,
                      color: Palette.textHi,
                    ),
                  ),
                ],
              ),
            );

            Widget latch({required bool fullWidth}) => AnimatedContainer(
              duration: pressed || still ? Duration.zero : Motion.ack,
              curve: Motion.respond,
              width: fullWidth ? null : 96,
              constraints: BoxConstraints(minHeight: fullWidth ? 43 : 58),
              padding: EdgeInsets.fromLTRB(
                fullWidth ? 0 : 7,
                fullWidth ? 9 : 8,
                fullWidth ? 0 : 5,
                fullWidth ? 0 : 8,
              ),
              decoration: BoxDecoration(
                border: Border(
                  left: fullWidth
                      ? BorderSide.none
                      : BorderSide(color: const Color(0x66966A3D), width: 1),
                  top: fullWidth
                      ? const BorderSide(color: Color(0x4B966A3D), width: 1)
                      : BorderSide.none,
                ),
                gradient: LinearGradient(
                  begin: Alignment(
                    (-0.75 + light.dx * 0.10).clamp(-0.9, -0.55),
                    -1,
                  ),
                  end: Alignment.bottomRight,
                  colors: pressed
                      ? const [Color(0x261B120D), Color(0x5A7A4A20)]
                      : const [Color(0x101B120D), Color(0x3E9A642C)],
                ),
              ),
              child: Row(
                mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: fullWidth
                    ? MainAxisAlignment.end
                    : MainAxisAlignment.center,
                children: [
                  Flexible(
                    fit: FlexFit.loose,
                    child: Text(
                      actionCopy,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontFamily: 'EBGaramond',
                        fontSize: fullWidth ? 17.5 : 16,
                        height: 1,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.12,
                        color: latchInk,
                      ),
                    ),
                  ),
                  SizedBox(width: fullWidth ? 8 : 6),
                  AnimatedRotation(
                    turns: _pending && !still ? 0.125 : 0,
                    duration: still ? Duration.zero : Motion.quick,
                    curve: Motion.respond,
                    child: Icon(
                      _pending ? Icons.more_horiz_rounded : widget.icon,
                      size: fullWidth ? 17 : 16,
                      color: latchInk,
                    ),
                  ),
                ],
              ),
            );

            return ClipPath(
              clipper: const FacetedClipper(cut: 12),
              child: AnimatedContainer(
                duration: pressed || still ? Duration.zero : Motion.ack,
                curve: Motion.respond,
                decoration: facetedDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: pressed
                        ? const [Color(0xF4211711), Color(0xFA120D0A)]
                        : const [Color(0xEE2B1F17), Color(0xFA140F0C)],
                  ),
                  cut: 12,
                  borderColor: edge,
                  borderWidth: focused ? 1.35 : 1,
                  shadows: pressed
                      ? const []
                      : const [
                          BoxShadow(
                            color: Color(0x66100805),
                            blurRadius: 18,
                            offset: Offset(0, 8),
                          ),
                        ],
                ),
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      top: 13,
                      bottom: 13,
                      child: Container(
                        width: 2.5,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              accent.withValues(alpha: 0.18),
                              accent.withValues(alpha: 0.88),
                              accent.withValues(alpha: 0.12),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              center: Alignment(
                                (-0.65 + light.dx * 0.18).clamp(-0.82, -0.42),
                                (-0.78 + light.dy * 0.08).clamp(-0.9, -0.58),
                              ),
                              radius: 1.1,
                              colors: [
                                accent.withValues(
                                  alpha: pressed ? 0.035 : 0.07,
                                ),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
                      child: stacked
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    identity(),
                                    Container(
                                      width: 1,
                                      height: 48,
                                      margin: const EdgeInsets.only(
                                        left: 1,
                                        right: 11,
                                      ),
                                      color: const Color(0x3FDFC493),
                                    ),
                                    copy(),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                latch(fullWidth: true),
                              ],
                            )
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                identity(),
                                Container(
                                  width: 1,
                                  height: 58,
                                  margin: const EdgeInsets.only(
                                    left: 1,
                                    right: 11,
                                  ),
                                  color: const Color(0x3FDFC493),
                                ),
                                copy(),
                                const SizedBox(width: 8),
                                latch(fullWidth: false),
                              ],
                            ),
                    ),
                    Positioned(
                      left: 18,
                      right: 18,
                      top: 0,
                      child: Container(
                        height: 1,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0x00F2D49C),
                              Color(0x66F2D49C),
                              Color(0x12F2D49C),
                              Color(0x00F2D49C),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _face({
    required bool pressed,
    required bool focused,
    required bool hovered,
  }) {
    if (widget.treatment == GoalPrimaryButtonTreatment.questFolio) {
      return _questFolioFace(
        pressed: pressed,
        focused: focused,
        hovered: hovered,
      );
    }
    if (widget.treatment == GoalPrimaryButtonTreatment.thresholdPlate) {
      return _thresholdPlateFace(
        pressed: pressed,
        focused: focused,
        hovered: hovered,
      );
    }
    return _lampFace(pressed: pressed);
  }

  /// Standard, opening and return actions are the app's lamp ([LampShade]):
  /// one primary-control language across Quests, Goals and sheets. Contact
  /// and the accepted (pending) frame both turn the light up; a disabled
  /// action is an unlit shade.
  Widget _lampFace({required bool pressed}) {
    final openingClasp =
        widget.treatment == GoalPrimaryButtonTreatment.openingClasp ||
        widget.treatment == GoalPrimaryButtonTreatment.returnClasp;
    final compactLabel = _pending || widget.label.length > 18;
    final level = widget.enabled ? LampLevel.lit : LampLevel.off;
    final label = _pending ? widget.pendingLabel : widget.label;
    final style = LampLabel.styleFor(
      label,
      level: level,
      fontSize: label == label.toUpperCase()
          ? 15.5
          : compactLabel
          ? 16.5
          : openingClasp
          ? 18
          : 19,
    );
    final still =
        widget.reduceMotion ||
        (MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    return LampShade(
      cut: 10,
      level: level,
      pressed: pressed || _pending,
      light: widget.light,
      reduceMotion: widget.reduceMotion,
      spill: widget.glow,
      child: Container(
        constraints: BoxConstraints(minHeight: openingClasp ? 48 : 52),
        padding: EdgeInsets.symmetric(
          horizontal: compactLabel ? 14 : 18,
          vertical: 10,
        ),
        alignment: Alignment.center,
        child: LampWords(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  textScaler: MediaQuery.textScalerOf(
                    context,
                  ).clamp(maxScaleFactor: 1.45),
                  style: style,
                ),
              ),
              SizedBox(width: _pending ? 7 : 9),
              AnimatedRotation(
                turns: _pending && !still ? 0.125 : 0,
                duration: still ? Duration.zero : Motion.quick,
                curve: Motion.respond,
                child: Icon(
                  _pending ? Icons.more_horiz_rounded : widget.icon,
                  size: compactLabel ? 17 : 19,
                  color: style.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _thresholdPlateFace({
    required bool pressed,
    required bool focused,
    required bool hovered,
  }) {
    final still =
        widget.reduceMotion ||
        (MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    final label = _pending ? widget.pendingLabel : widget.label;
    return AnimatedScale(
      scale: pressed && !still ? 0.975 : 1,
      duration: pressed || still ? Duration.zero : Motion.ack,
      curve: Motion.respond,
      child: AnimatedSlide(
        offset: pressed && !still ? const Offset(0, 0.035) : Offset.zero,
        duration: pressed || still ? Duration.zero : Motion.ack,
        curve: Motion.respond,
        child: AnimatedContainer(
          duration: pressed || still ? Duration.zero : Motion.ack,
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: focused
                ? Border.all(color: const Color(0xD8FFE4A9), width: 1.25)
                : hovered
                ? Border.all(color: const Color(0x55FFE4A9), width: 0.8)
                : null,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              AnimatedOpacity(
                opacity: pressed ? 0.76 : 0.9,
                duration: pressed || still ? Duration.zero : Motion.ack,
                curve: Motion.respond,
                child: ClipRect(
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.diagonal3Values(1, 1.56, 1),
                    child: Image.asset(
                      goalsThresholdPlateAsset,
                      fit: BoxFit.fill,
                      filterQuality: FilterQuality.high,
                      excludeFromSemantics: true,
                    ),
                  ),
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 3, 10, 7),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'EBGaramond',
                        fontSize: _pending ? 18 : 23,
                        height: 1,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.04,
                        color: pressed
                            ? const Color(0xFF402817)
                            : const Color(0xFF1D1009),
                        shadows: const [
                          Shadow(
                            color: Color(0x65FFE4A0),
                            offset: Offset(0, 1),
                          ),
                        ],
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final questFolio =
        widget.treatment == GoalPrimaryButtonTreatment.questFolio;
    final thresholdPlate =
        widget.treatment == GoalPrimaryButtonTreatment.thresholdPlate;
    final still =
        widget.reduceMotion ||
        (MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    final ShapeBorder shape = questFolio
        ? const FacetedBorder(cut: 12)
        : thresholdPlate
        ? const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(6)),
          )
        : const LampShadeBorder(cut: 10);
    final button = Pressable(
      material: MaterialSound.brass,
      shape: shape,
      enabled: widget.enabled && !_pending,
      pressDepth: still
          ? 0
          : thresholdPlate
          ? 1.25
          : 2,
      edgeColor: thresholdPlate
          ? Colors.transparent
          : questFolio
          ? const Color(0xFF3D2717)
          : const Color(0xFF1E1109),
      semanticLabel: _pending
          ? '${widget.label}. ${widget.pendingLabel}.'
          : thresholdPlate
          ? widget.label
          : questFolio
          ? '${widget.folioEyebrow ?? ''}. ${widget.folioTitle ?? ''}. ${widget.label}.'
          : widget.label,
      semanticHint: widget.semanticHint,
      onTapUp: (_) => _activate(),
      guardRapidReentry: true,
      stateBuilder: (context, child, pressed, focused, hovered) =>
          _face(pressed: pressed, focused: focused, hovered: hovered),
      child: const SizedBox.shrink(),
    );
    return button;
  }
}
