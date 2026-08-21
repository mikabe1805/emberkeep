import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../audio.dart';
import '../content/creature_skins.dart' show flameHueFor;
import '../content/space_themes.dart';
import '../engine.dart';
import '../platform/share_stub.dart'
    if (dart.library.js_interop) '../platform/share_web.dart';
import '../social.dart' show roomInviteUrl;
import '../tokens.dart';
import 'facets.dart';
import 'living_hearth_fire.dart';
import 'pressable.dart';

/// The words that travel with the card. The room link rides along only while a
/// shared room actually exists — a code that was never shared, or was
/// unshared, must not leak into a brag image.
String shareMomentText(GameState state, int level) {
  final base =
      'Level $level in Room of Days — built out of days I actually '
      'kept.';
  final code = state.roomCode;
  if (code == null || code.isEmpty) return base;
  return '$base\nCome see the room: ${roomInviteUrl(code)}';
}

/// Opens the share-a-moment preview over whatever is on screen. Returns after
/// the sheet closes, whether or not anything was shared.
Future<void> showShareMoment(
  BuildContext context,
  GameState state, {
  required int level,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Palette.dialogBarrier,
    builder: (_) => ShareMomentSheet(state: state, level: level),
  );
}

/// A preview-first share: the keeper sees the exact image before anything
/// leaves the device. The card is the app's best beat — the room they built
/// and the level it carried them to — sized 4:5 so it lands well in Messages,
/// WhatsApp, and feeds.
class ShareMomentSheet extends StatefulWidget {
  const ShareMomentSheet({super.key, required this.state, required this.level});

  final GameState state;
  final int level;

  @override
  State<ShareMomentSheet> createState() => _ShareMomentSheetState();
}

class _ShareMomentSheetState extends State<ShareMomentSheet> {
  final _cardKey = GlobalKey();
  bool _busy = false;

  Future<void> _share() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final boundary =
          _cardKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      final ok =
          bytes != null &&
          await sharePng(
            bytes.buffer.asUint8List(),
            'room-of-days-level-${widget.level}.png',
            shareMomentText(widget.state, widget.level),
          );
      if (!mounted) return;
      Sfx.instance.play(ok ? 'streak' : 'tick');
      if (ok) Navigator.of(context).maybePop();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RepaintBoundary(
                key: _cardKey,
                child: MomentCard(state: widget.state, level: widget.level),
              ),
              const SizedBox(height: 14),
              // Wrap, not Row: at large accessibility text the two actions
              // exceed a narrow dialog's width, and a Row clips the primary
              // button — the one control this sheet exists for.
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 10,
                runSpacing: 6,
                children: [
                  Semantics(
                    button: true,
                    label: 'Not now',
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.of(context).maybePop(),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 44),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                        child: Text(
                          'NOT NOW',
                          style: Type.label.copyWith(fontSize: 11),
                        ),
                      ),
                    ),
                  ),
                  Pressable(
                    semanticLabel: 'Share this moment',
                    material: MaterialSound.brass,
                    shape: const FacetedBorder(cut: 9),
                    onTapUp: (_) => _share(),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 26,
                        vertical: 13,
                      ),
                      decoration: facetedDecoration(
                        cut: 9,
                        gradient: Palette.honeyGradient,
                        borderColor: Palette.brassLit.withValues(alpha: 0.6),
                      ),
                      child: Text(
                        _busy ? 'SHARING…' : 'SHARE THIS MOMENT',
                        style: Type.label.copyWith(
                          fontSize: 12,
                          color: Palette.onHoney,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                widget.state.roomCode == null
                    ? 'Just the image — no link, no code.'
                    : 'The image travels with your room link.',
                style: Type.label.copyWith(
                  fontSize: Type.minLabel,
                  color: Palette.textLo,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lights the plate's firebox with the same authored parked fire used by Me
/// and Quests. Every room plate is 1536x1024 with the hearth at the same
/// registered spot, so the position under this card's cover-crop is pure
/// arithmetic: cover-fit the 1.5 plate into the 0.8 card at the card's own
/// alignment, then map the hearth fraction through it.
class _CardHearth extends StatelessWidget {
  const _CardHearth({required this.hue});

  final Color hue;

  // Mirrors MomentCard's Image.asset alignment and home_room's
  // _plateHearthImage — the fire bed as a fraction of the plate art.
  static const _alignX = 0.72;
  static const _plateAspect = 1536 / 1024;
  static const _hearth = Offset(0.866, 0.662);

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          final scaledW = size.height * _plateAspect;
          final leftCrop = (scaledW - size.width) * (1 + _alignX) / 2;
          final cx = _hearth.dx * scaledW - leftCrop;
          final baseY = _hearth.dy * size.height;
          if (cx < -size.width * 0.1 || cx > size.width * 1.1) {
            return const SizedBox.shrink();
          }
          final flameW = size.width * 0.15;
          final flameH = size.height * 0.115;
          return Stack(
            fit: StackFit.expand,
            children: [
              Positioned(
                left: cx - flameW * 1.3,
                top: baseY - flameH * 0.45,
                width: flameW * 2.6,
                height: flameH * 0.9,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        hue.withValues(alpha: 0.34),
                        hue.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: cx - flameW / 2,
                top: baseY - flameH,
                width: flameW,
                height: flameH,
                child: RecoloredHearthFireFrame(
                  asset: hearthFireAssets.first,
                  hue: hue,
                  opacity: 1,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The image itself: the keeper's real room as the hero, the level carried on
/// it like a plate. 4:5, self-contained, no live widgets — everything here
/// must rasterize deterministically.
class MomentCard extends StatelessWidget {
  const MomentCard({super.key, required this.state, required this.level});

  final GameState state;
  final int level;

  @override
  Widget build(BuildContext context) {
    final theme = spaceThemeById(state.wallStyle);
    final name = state.playerName?.trim() ?? '';
    final facts = <String>[
      if (name.isNotEmpty) name,
      if (state.streakDays > 0) 'day ${state.streakDays}',
      if (state.totalCompletions > 0) '${state.totalCompletions} quests kept',
    ];
    return AspectRatio(
      aspectRatio: 4 / 5,
      child: ClipPath(
        clipper: const FacetedClipper(cut: 14),
        child: DecoratedBox(
          decoration: const BoxDecoration(color: Palette.parchment),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (theme != null)
                Image.asset(
                  theme.plateAsset,
                  fit: BoxFit.cover,
                  // The plates are landscape; a 4:5 cover-crop keeps barely
                  // half their width. Centered, that half is the desk — and
                  // the hearth, the one object that says which app this is,
                  // falls off the right edge. Bias toward it.
                  alignment: const Alignment(0.72, 0),
                  filterQuality: FilterQuality.high,
                  excludeFromSemantics: true,
                )
              else
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Palette.card, Palette.parchment],
                    ),
                  ),
                ),
              // The plates ship with an unlit firebox — the app draws the
              // living fire itself. The card uses the authored parked frame,
              // not the old procedural flame, so the exported still keeps the
              // same brush texture as Me and Quests.
              if (theme != null) _CardHearth(hue: flameHueFor(state)),
              // the room stays the hero; the words sit in its shadow
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.42, 0.78, 1.0],
                    colors: [
                      Color(0x00140C06),
                      Color(0xCC140C06),
                      Color(0xF2140C06),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Spacer(),
                    Text(
                      'LEVEL UP',
                      style: Type.label.copyWith(
                        fontSize: 11,
                        letterSpacing: 2.4,
                        color: Palette.xpLight,
                      ),
                    ),
                    Text(
                      '$level',
                      style: Type.numerals.copyWith(
                        fontSize: 92,
                        height: 1.02,
                        color: Palette.xpLight,
                        shadows: const [
                          Shadow(color: Palette.honeyGlow, blurRadius: 26),
                        ],
                      ),
                    ),
                    if (facts.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        facts.join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Type.label.copyWith(
                          fontSize: Type.minLabel,
                          color: Palette.textMid,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Container(
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Palette.brass.withValues(alpha: 0.8),
                            Palette.brass.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      'ROOM OF DAYS',
                      style: Type.label.copyWith(
                        fontSize: Type.minLabel,
                        letterSpacing: 2.6,
                        color: Palette.textLo,
                      ),
                    ),
                  ],
                ),
              ),
              // the same edge light every pane in the app wears
              IgnorePointer(
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    shape: FacetedBorder(
                      cut: 14,
                      side: BorderSide(
                        color: Palette.glassEdge.withValues(alpha: 0.9),
                        width: 1.4,
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
}
