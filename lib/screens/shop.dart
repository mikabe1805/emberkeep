import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio.dart';
import '../content/creature_skins.dart';
import '../content/furniture.dart';
import '../content/room_styles.dart';
import '../content/scenes.dart';
import '../content/window_scenes.dart';
import '../engine.dart';
import '../models.dart';
import '../tokens.dart';
import '../widgets/detail_header.dart';
import '../widgets/glass.dart';
import '../widgets/home_room.dart';
import '../widgets/honey_button.dart';
import '../widgets/mascot_sprite.dart';
import '../widgets/painted_backdrop.dart';
import '../widgets/portrait.dart';

/// "Your Space" shop (round-42): spend the Embers (✦) you earn by playing on
/// furniture for your room — in whatever order you like. Customization is about
/// CHOICE, so nothing is forced on a fixed track; you save up for the pieces
/// you want. A few special pieces are gated behind a trophy first (you still
/// pay), so achievements quietly open new shelves. Every not-owned item now
/// opens a try-on first (see [_showTryOn]) — nothing in the shop buys blind.
class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key, required this.state, required this.onPersist});

  final GameState state;

  /// Persist the save after a purchase.
  final VoidCallback onPersist;

  /// One checkout for every shelf: run the engine buy, then play the right
  /// beat. Success is a small treasure; a refusal must SOUND like a refusal —
  /// 'boing', never the 'tick' that also means success-on-apply — and when
  /// it's the wallet (not a trophy gate) it says so in words. Rare in
  /// practice: the try-on dialog keeps Buy dark until you can pay.
  bool _checkout(BuildContext context, int price, bool Function() attempt) {
    final ok = attempt();
    if (ok) {
      Sfx.instance.play('loot'); // a small treasure
      HapticFeedback.mediumImpact();
      onPersist();
    } else {
      Sfx.instance.play('boing');
      HapticFeedback.selectionClick();
      if (state.embers < price) _toast(context, 'not enough embers yet');
    }
    return ok;
  }

  bool _buy(BuildContext context, FurnitureItem f) => _checkout(
      context,
      f.price,
      () => state.buyFurniture(f.id, f.price,
          allowed: furnitureUnlocked(f, state)));

  bool _buyStyle(BuildContext context, RoomStyle st) => _checkout(
      context,
      st.price,
      () => state.buyStyle(st.id, st.price, st.kind,
          allowed: styleUnlocked(st, state)));

  void _applyStyle(RoomStyle st) {
    state.applyStyle(st.id, st.kind);
    Sfx.instance.play('tick');
    HapticFeedback.selectionClick();
    onPersist();
  }

  bool _buySkin(BuildContext context, CreatureSkin sk) => _checkout(
      context,
      sk.price,
      () => state.buySkin(sk.id, sk.price, allowed: skinUnlocked(sk, state)));

  void _applySkin(CreatureSkin sk) {
    state.applySkin(sk.id);
    Sfx.instance.play('tick');
    HapticFeedback.selectionClick();
    onPersist();
  }

  bool _buyWindow(BuildContext context, WindowView v) => _checkout(
      context,
      v.price,
      () => state.buyWindow(v.id, v.price, allowed: windowUnlocked(v, state)));

  void _applyWindow(WindowView v) {
    state.applyWindow(v.id);
    Sfx.instance.play('tick');
    HapticFeedback.selectionClick();
    onPersist();
  }

  bool _buyScene(BuildContext context, StageScene v) => _checkout(
      context,
      v.price,
      () => state.buyScene(v.id, v.price, allowed: sceneUnlocked(v, state)));

  void _applyScene(StageScene v) {
    state.applyScene(v.id);
    Sfx.instance.play('tick');
    HapticFeedback.selectionClick();
    onPersist();
  }

  Widget _sectionHeader(String label) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8, top: 2),
        child: Text(
          label,
          style: Type.label.copyWith(
            fontSize: 11,
            color: Palette.textLo,
            letterSpacing: 1.5,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final owned = state.ownedFurniture.length;
        return Scaffold(
          backgroundColor: Palette.parchment,
          body: WarmBackground(
            themeId: state.canvasTheme,
            tint: Palette.xp,
            child: SafeArea(
              child: Column(
                children: [
                  DetailHeader(
                    title: 'Your Space',
                    accent: Palette.xp,
                    subtitle: 'furnish it with the embers you earn',
                    pill: '✦ ${state.embers}',
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 40),
                      children: [
                        // a live look at the room — it fills as you buy
                        GlassPanel(
                          blur: true,
                          child: Column(
                            children: [
                              HomeRoom(
                                lively: !state.reduceMotion,
                                unlocked: state.ownedFurniture,
                                wall: wallColorsFor(state),
                                floor: floorColorsFor(state),
                                window: state.windowScene,
                                petAwake: state.streakDays > 0,
                                emberGlow: creatureColorsFor(state)[1],
                                child: MascotSprite(
                                  size: 80,
                                  skinId: state.creatureSkin,
                                  aura: state.dominantStat?.color,
                                  level: state.level,
                                  trait: state.portraitTrait,
                                  skin: creatureColorsFor(state),
                                  mood: PortraitMood.happy,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '$owned of ${furniture.length} pieces · '
                                'you earn ✦ for every quest you finish',
                                textAlign: TextAlign.center,
                                style: Type.body.copyWith(
                                  fontSize: 11,
                                  color: Palette.textLo,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _sectionHeader('YOUR EMBER'),
                        for (final sk in creatureSkins) ...[
                          _SkinCard(
                            skin: sk,
                            state: state,
                            onBuy: () => _buySkin(context, sk),
                            onApply: () => _applySkin(sk),
                          ),
                          const SizedBox(height: 10),
                        ],
                        const SizedBox(height: 8),
                        _sectionHeader('FURNITURE'),
                        for (final f in furniture) ...[
                          _ShopCard(
                            item: f,
                            state: state,
                            onBuy: () => _buy(context, f),
                          ),
                          const SizedBox(height: 10),
                        ],
                        const SizedBox(height: 8),
                        _sectionHeader('ROOM STYLE'),
                        for (final st in roomStyles) ...[
                          _StyleCard(
                            style: st,
                            state: state,
                            onBuy: () => _buyStyle(context, st),
                            onApply: () => _applyStyle(st),
                          ),
                          const SizedBox(height: 10),
                        ],
                        const SizedBox(height: 8),
                        _sectionHeader('THE VIEW'),
                        for (final v in windowViews) ...[
                          _WindowCard(
                            view: v,
                            state: state,
                            onBuy: () => _buyWindow(context, v),
                            onApply: () => _applyWindow(v),
                          ),
                          const SizedBox(height: 10),
                        ],
                        const SizedBox(height: 8),
                        _sectionHeader('THE STAGE'),
                        for (final v in stageScenes) ...[
                          _SceneCard(
                            scene: v,
                            state: state,
                            onBuy: () => _buyScene(context, v),
                            onApply: () => _applyScene(v),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── shared shop chrome ─────────────────────────────────────────────────
// One copy of the pills, price column and CTA ladder that used to be pasted
// verbatim into all five card classes — same glass everywhere, one source
// of truth when the shape changes.

/// A small warm receipt — floating glass over the shop, gone in a breath.
/// No overlay theatre for a purchase; the room itself already changed.
void _toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Palette.card,
      duration: const Duration(milliseconds: 2200),
      content: Text(msg, style: Type.body.copyWith(color: Palette.textHi)),
    ));
}

/// The settled state every card ends in ("in your room" / "on now" / "worn").
Widget _pill(Color c, IconData icon, String label) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: c.withValues(alpha: 0.15),
        border: Border.all(color: c.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: c),
          const SizedBox(width: 5),
          Text(label, style: Type.label.copyWith(fontSize: 10, color: c)),
        ],
      ),
    );

/// The trophy gate on a locked shelf — names the achievement, never just a
/// dead padlock.
Widget _lockedPill(String trophy) => Container(
      constraints: const BoxConstraints(maxWidth: 124),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.black.withValues(alpha: 0.16),
        border: Border.all(color: Palette.textLo.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline, size: 13, color: Palette.textLo),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'earn “$trophy”',
              style: Type.body.copyWith(fontSize: 10, color: Palette.textLo),
            ),
          ),
        ],
      ),
    );

/// The quiet outlined action on an owned exclusive ("Apply" / "Wear") — you
/// already paid; switching should feel free, not like another sale.
Widget _applyChip(String label, VoidCallback onTap) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Palette.xp.withValues(alpha: 0.6)),
        ),
        child: Text(label,
            style: Type.label.copyWith(fontSize: 11, color: Palette.xpLight)),
      ),
    );

/// The price readout when the embers aren't there yet — a plain column, no
/// button pretence; the card's own tap still opens the try-on.
Widget _priceTag(int price, int embers) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text('✦ $price',
            style: Type.display.copyWith(fontSize: 17, color: Palette.xp)),
        const SizedBox(height: 1),
        Text('${price - embers} to go',
            style: Type.body.copyWith(fontSize: 10, color: Palette.textLo)),
      ],
    );

/// The tail of every not-owned row: the trophy gate when locked, a honey
/// price button when affordable, the "N to go" column when not. All three
/// roads lead to the same try-on dialog now — a tap on a price PREVIEWS
/// instead of charging, so the first tap is never a surprise sale.
Widget _shelfCta({
  required GameState state,
  required int price,
  required String? gate,
  required VoidCallback onPeek,
}) {
  if (gate != null) return _lockedPill(gate);
  if (state.embers >= price) {
    return HoneyButton(label: '✦ $price', onTap: onPeek);
  }
  return _priceTag(price, state.embers);
}

// ── try-on heroes ──────────────────────────────────────────────────────
// The dialog's hero is always YOUR space with one thing changed, never a
// stock render — furniture, styles and window views swap into your own
// room (ember included)…

Widget _roomHero(
  GameState state, {
  Set<String>? unlocked,
  List<Color>? wall,
  List<Color>? floor,
  String? window,
}) =>
    HomeRoom(
      lively: !state.reduceMotion,
      unlocked: unlocked ?? state.ownedFurniture,
      wall: wall ?? wallColorsFor(state),
      floor: floor ?? floorColorsFor(state),
      window: window ?? state.windowScene,
      petAwake: true,
      emberGlow: creatureColorsFor(state)[1],
      child: MascotSprite(
        size: 96,
        skinId: state.creatureSkin,
        level: state.level,
        skin: creatureColorsFor(state),
        lively: !state.reduceMotion,
      ),
    );

/// …while skins and stage scenes pose the ember on the painted stage: a
/// scene try-on keeps your current skin on the NEW stage, a skin try-on
/// wears the NEW skin on your current stage.
Widget _stageHero(GameState state, {StageScene? scene, CreatureSkin? skin}) {
  final st = scene ?? stageSceneFor(state);
  return PaintedBackdrop(
    scene: st.id,
    height: 160,
    alignment: st.stand,
    child: MascotSprite(
      // a skin fitting zooms in a touch — the skin IS the subject
      size: skin != null ? 110 : 100,
      skinId: skin?.id ?? state.creatureSkin,
      level: state.level,
      mood: PortraitMood.happy,
      skin: skin?.colors ?? creatureColorsFor(state),
      lively: !state.reduceMotion,
    ),
  );
}

/// Every not-owned item opens this fitting room — a live look at the actual
/// thing already in YOUR space (the preview IS the motivation: you see
/// yourself already having it — visible-next, RESEARCH-momentum.md), with
/// the price sitting right beside your balance so the decision is made with
/// open eyes. Locked items keep the original "COMING UP" framing: the gate
/// line and a single "Keep at it" — the trophy, not the wallet, is the door.
/// Unlocked ones get a Buy that only lights up when you can afford it, and
/// a quiet way back out either way.
void _showTryOn(
  BuildContext context, {
  required Widget hero,
  required String name,
  required String blurb,
  required int price,
  required int embers,
  String? gate,
  bool Function()? onBuy,
  String? receipt,
}) {
  Sfx.instance.play('tick');
  HapticFeedback.selectionClick();
  final affordable = embers >= price;
  showDialog(
    context: context,
    barrierColor: const Color(0xCC140C06),
    builder: (dialogCtx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(28),
      child: GlassPanel(
        tint: const Color(0xF22A211D),
        glow: true,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(gate != null ? 'COMING UP' : 'TRY IT ON',
                style: Type.label.copyWith(
                    fontSize: 10,
                    letterSpacing: 1.5,
                    color: Palette.textLo)),
            const SizedBox(height: 14),
            hero,
            const SizedBox(height: 14),
            Text(name,
                textAlign: TextAlign.center,
                style: Type.display.copyWith(fontSize: 20)),
            const SizedBox(height: 4),
            Text(blurb,
                textAlign: TextAlign.center,
                style: Type.body.copyWith(
                    fontSize: 12, color: Palette.textLo, height: 1.35)),
            const SizedBox(height: 12),
            if (gate != null)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_outline, size: 13, color: Palette.textLo),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text('earn “$gate” to unlock  ·  ✦ $price',
                        style: Type.body
                            .copyWith(fontSize: 11.5, color: Palette.textLo)),
                  ),
                ],
              )
            else
              Text('✦ $price  ·  you have ✦ $embers',
                  style: Type.body
                      .copyWith(fontSize: 11.5, color: Palette.textLo)),
            const SizedBox(height: 16),
            if (gate != null)
              HoneyButton(
                label: 'Keep at it',
                onTap: () => Navigator.of(dialogCtx).pop(),
              )
            else ...[
              // Buy only lights up when the embers are there; short shows a
              // visible "M more to go", never a silently dead button.
              HoneyButton(
                enabled: affordable,
                label: affordable
                    ? 'Buy · ✦ $price'
                    : '✦ $price — ${price - embers} more to go',
                onTap: () {
                  final ok = onBuy?.call() ?? false;
                  Navigator.of(dialogCtx).pop();
                  if (ok && receipt != null) _toast(context, receipt);
                },
              ),
              const SizedBox(height: 6),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(dialogCtx).pop(),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  child: Text('Not now',
                      style: Type.label
                          .copyWith(fontSize: 11, color: Palette.textLo)),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _ShopCard extends StatelessWidget {
  const _ShopCard({
    required this.item,
    required this.state,
    required this.onBuy,
  });

  final FurnitureItem item;
  final GameState state;

  /// Attempts the purchase; true on success (drives the receipt toast).
  final bool Function() onBuy;

  @override
  Widget build(BuildContext context) {
    final owned = state.ownedFurniture.contains(item.id);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // the whole card is the fitting-room door — tap anywhere on a piece
      // you don't own yet to see it in YOUR room before an ember moves
      onTap: owned ? null : () => _openTryOn(context),
      child: Opacity(
        opacity: owned ? 0.78 : 1.0,
        child: GlassPanel(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _zoneChip(item.zone),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            item.name,
                            style: Type.label.copyWith(
                              fontSize: 13,
                              color: Palette.textHi,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      item.blurb,
                      style: Type.body.copyWith(
                        fontSize: 11.5,
                        color: Palette.textLo,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _cta(context),
            ],
          ),
        ),
      ),
    );
  }

  // a peek at your room WITH the piece already in it
  void _openTryOn(BuildContext context) => _showTryOn(
        context,
        hero: _roomHero(state, unlocked: {...state.ownedFurniture, item.id}),
        name: item.name,
        blurb: item.blurb,
        price: item.price,
        embers: state.embers,
        gate: furnitureUnlocked(item, state)
            ? null
            : (furnitureGateLabel(item) ?? 'a trophy'),
        onBuy: onBuy,
        receipt: '${item.name} is yours — already in your room',
      );

  Widget _cta(BuildContext context) {
    if (state.ownedFurniture.contains(item.id)) {
      return _pill(
        Palette.success,
        Icons.check_rounded,
        'in your room',
      );
    }
    return _shelfCta(
      state: state,
      price: item.price,
      gate: furnitureUnlocked(item, state)
          ? null
          : (furnitureGateLabel(item) ?? 'a trophy'),
      onPeek: () => _openTryOn(context),
    );
  }

  Widget _zoneChip(String zone) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(6),
      color: Palette.xp.withValues(alpha: 0.12),
    ),
    child: Text(
      zone.toUpperCase(),
      style: Type.label.copyWith(
        fontSize: 8,
        color: Palette.xp,
        letterSpacing: 1,
      ),
    ),
  );
}

/// A room-style row: a gradient swatch + name, with buy / apply / on-now /
/// locked states. Styles are exclusive per surface, so buying applies it and
/// owned ones offer "Apply" to switch.
class _StyleCard extends StatelessWidget {
  const _StyleCard({
    required this.style,
    required this.state,
    required this.onBuy,
    required this.onApply,
  });

  final RoomStyle style;
  final GameState state;

  /// Attempts the purchase; true on success (drives the receipt toast).
  final bool Function() onBuy;
  final VoidCallback onApply;

  String get _blurb => style.kind == RoomStyleKind.wall
      ? 'a new colour for your walls'
      : 'a new look underfoot';

  @override
  Widget build(BuildContext context) {
    final applied = isStyleApplied(state, style);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: isStyleOwned(state, style) ? null : () => _openTryOn(context),
      child: GlassPanel(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Row(
          children: [
            _swatch(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _kindChip(),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          style.name,
                          style: Type.label.copyWith(
                              fontSize: 13, color: Palette.textHi),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _blurb,
                    style: Type.body
                        .copyWith(fontSize: 11.5, color: Palette.textLo),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _cta(context, applied),
          ],
        ),
      ),
    );
  }

  // your own room wearing the style
  void _openTryOn(BuildContext context) => _showTryOn(
        context,
        hero: _roomHero(
          state,
          wall: style.kind == RoomStyleKind.wall ? [style.a, style.b] : null,
          floor: style.kind == RoomStyleKind.floor ? [style.a, style.b] : null,
        ),
        name: style.name,
        blurb: _blurb,
        price: style.price,
        embers: state.embers,
        gate: styleUnlocked(style, state)
            ? null
            : (styleGateLabel(style) ?? 'a trophy'),
        onBuy: onBuy,
        receipt: style.kind == RoomStyleKind.wall
            ? '${style.name} is on your walls now'
            : '${style.name} is underfoot now',
      );

  Widget _cta(BuildContext context, bool applied) {
    if (applied) {
      return _pill(Palette.success, Icons.check_rounded, 'on now');
    }
    if (isStyleOwned(state, style)) {
      return _applyChip('Apply', onApply);
    }
    return _shelfCta(
      state: state,
      price: style.price,
      gate: styleUnlocked(style, state)
          ? null
          : (styleGateLabel(style) ?? 'a trophy'),
      onPeek: () => _openTryOn(context),
    );
  }

  Widget _swatch() => Container(
        width: 46,
        height: 44,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [style.a, style.b],
          ),
          border: Border.all(color: Palette.textHi.withValues(alpha: 0.15)),
        ),
      );

  Widget _kindChip() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: Palette.xp.withValues(alpha: 0.12),
        ),
        child: Text(
          style.kind == RoomStyleKind.wall ? 'WALL' : 'FLOOR',
          style: Type.label.copyWith(
              fontSize: 8, color: Palette.xp, letterSpacing: 1),
        ),
      );
}

/// A window-view row: a live painted swatch of the scene + buy / apply states.
class _WindowCard extends StatelessWidget {
  const _WindowCard({
    required this.view,
    required this.state,
    required this.onBuy,
    required this.onApply,
  });

  final WindowView view;
  final GameState state;

  /// Attempts the purchase; true on success (drives the receipt toast).
  final bool Function() onBuy;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final applied = isWindowApplied(state, view);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: isWindowOwned(state, view) ? null : () => _openTryOn(context),
      child: GlassPanel(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: SizedBox(
                width: 64,
                height: 46,
                child: CustomPaint(painter: _WindowSwatchPainter(view.id)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(view.name,
                      style: Type.label
                          .copyWith(fontSize: 13, color: Palette.textHi)),
                  const SizedBox(height: 4),
                  Text(
                    view.id == 'moon'
                        ? 'the original night sky'
                        : 'a new view outside your window',
                    style: Type.body
                        .copyWith(fontSize: 11.5, color: Palette.textLo),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _cta(context, applied),
          ],
        ),
      ),
    );
  }

  // your own room with the new view already through the glass — the room,
  // not a bare pane, because the view only means something from inside
  void _openTryOn(BuildContext context) => _showTryOn(
        context,
        hero: _roomHero(state, window: view.id),
        name: view.name,
        blurb: 'a new view outside your window',
        price: view.price,
        embers: state.embers,
        gate: windowUnlocked(view, state)
            ? null
            : (windowGateLabel(view) ?? 'a trophy'),
        onBuy: onBuy,
        receipt: '${view.name} is outside your window now',
      );

  Widget _cta(BuildContext context, bool applied) {
    if (applied) {
      return _pill(Palette.success, Icons.check_rounded, 'on now');
    }
    if (isWindowOwned(state, view)) {
      return _applyChip('Apply', onApply);
    }
    return _shelfCta(
      state: state,
      price: view.price,
      gate: windowUnlocked(view, state)
          ? null
          : (windowGateLabel(view) ?? 'a trophy'),
      onPeek: () => _openTryOn(context),
    );
  }
}

/// A painted-stage row: a little slice of the painting + name, with the same
/// buy / apply / on-now / locked ladder as every other exclusive cosmetic.
class _SceneCard extends StatelessWidget {
  const _SceneCard({
    required this.scene,
    required this.state,
    required this.onBuy,
    required this.onApply,
  });

  final StageScene scene;
  final GameState state;

  /// Attempts the purchase; true on success (drives the receipt toast).
  final bool Function() onBuy;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final applied = isSceneApplied(state, scene);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: isSceneOwned(state, scene) ? null : () => _openTryOn(context),
      child: GlassPanel(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: SizedBox(
                width: 64,
                height: 46,
                child: Image.asset(
                  'assets/backdrops/${scene.id}.webp',
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (_, _, _) =>
                      const ColoredBox(color: Color(0xFF3A2C2A)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(scene.name,
                      style: Type.label
                          .copyWith(fontSize: 13, color: Palette.textHi)),
                  const SizedBox(height: 4),
                  Text(
                    scene.blurb,
                    style: Type.body
                        .copyWith(fontSize: 11.5, color: Palette.textLo),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _cta(context, applied),
          ],
        ),
      ),
    );
  }

  // your ember standing in the new scene
  void _openTryOn(BuildContext context) => _showTryOn(
        context,
        hero: _stageHero(state, scene: scene),
        name: scene.name,
        blurb: scene.blurb,
        price: scene.price,
        embers: state.embers,
        gate: sceneUnlocked(scene, state)
            ? null
            : (sceneGateLabel(scene) ?? 'a trophy'),
        onBuy: onBuy,
        receipt: '${scene.name} is on stage now',
      );

  Widget _cta(BuildContext context, bool applied) {
    if (applied) {
      return _pill(Palette.success, Icons.check_rounded, 'on stage');
    }
    if (isSceneOwned(state, scene)) {
      return _applyChip('Apply', onApply);
    }
    return _shelfCta(
      state: state,
      price: scene.price,
      gate: sceneUnlocked(scene, state)
          ? null
          : (sceneGateLabel(scene) ?? 'a trophy'),
      onPeek: () => _openTryOn(context),
    );
  }
}

class _WindowSwatchPainter extends CustomPainter {
  _WindowSwatchPainter(this.scene);
  final String scene;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    paintWindowScene(canvas, scene, rect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(0.5), const Radius.circular(6)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFF5A4536),
    );
    final bar = Paint()
      ..color = const Color(0xFF5A4536)
      ..strokeWidth = 1.2;
    canvas.drawLine(
        Offset(0, size.height / 2), Offset(size.width, size.height / 2), bar);
    canvas.drawLine(
        Offset(size.width / 2, 0), Offset(size.width / 2, size.height), bar);
  }

  @override
  bool shouldRepaint(_WindowSwatchPainter old) => old.scene != scene;
}

/// A creature-skin row: a live mini-ember in that colour + buy / wear / locked
/// states. Skins are exclusive (wear one), so buying wears it and owned ones
/// offer "Wear" to switch.
class _SkinCard extends StatelessWidget {
  const _SkinCard({
    required this.skin,
    required this.state,
    required this.onBuy,
    required this.onApply,
  });

  final CreatureSkin skin;
  final GameState state;

  /// Attempts the purchase; true on success (drives the receipt toast).
  final bool Function() onBuy;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final applied = isSkinApplied(state, skin);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: isSkinOwned(state, skin) ? null : () => _openTryOn(context),
      child: GlassPanel(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          children: [
            // a real little ember in this colour — see it before you buy.
            // Colour skins preview with the crisp painter; outfits must show
            // their actual costumed frames (the painter has no costume).
            SizedBox(
              width: 50,
              height: 50,
              child: skin.outfit
                  ? MascotSprite(
                      size: 50,
                      minSpriteSize: 0,
                      skinId: skin.id,
                      level: 8,
                      mood: PortraitMood.happy,
                      skin: skin.colors,
                      lively: false,
                    )
                  : Portrait(
                      size: 50,
                      level: 8,
                      mood: PortraitMood.happy,
                      skin: skin.colors),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(skin.name,
                      style: Type.label
                          .copyWith(fontSize: 13, color: Palette.textHi)),
                  const SizedBox(height: 4),
                  Text(
                    skin.id == 'ember_amber'
                        ? 'the original ember'
                        : 'a colour all your own',
                    style: Type.body
                        .copyWith(fontSize: 11.5, color: Palette.textLo),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _cta(context, applied),
          ],
        ),
      ),
    );
  }

  // your ember already wearing the skin, on your own stage
  void _openTryOn(BuildContext context) => _showTryOn(
        context,
        hero: _stageHero(state, skin: skin),
        name: skin.name,
        blurb: skin.outfit
            ? 'your ember takes up a calling'
            : 'the same little flame, a new glass',
        price: skin.price,
        embers: state.embers,
        gate: skinUnlocked(skin, state)
            ? null
            : (skinGateLabel(skin) ?? 'a trophy'),
        onBuy: onBuy,
        receipt: 'You’re wearing ${skin.name} now',
      );

  Widget _cta(BuildContext context, bool applied) {
    if (applied) {
      return _pill(Palette.success, Icons.check_rounded, 'worn');
    }
    if (isSkinOwned(state, skin)) {
      return _applyChip('Wear', onApply);
    }
    return _shelfCta(
      state: state,
      price: skin.price,
      gate: skinUnlocked(skin, state)
          ? null
          : (skinGateLabel(skin) ?? 'a trophy'),
      onPeek: () => _openTryOn(context),
    );
  }
}
