import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio.dart';
import '../content/creature_skins.dart';
import '../content/furniture.dart';
import '../content/room_styles.dart';
import '../content/window_scenes.dart';
import '../engine.dart';
import '../haptics.dart';
import '../models.dart';
import '../tokens.dart';
import '../widgets/detail_header.dart';
import '../widgets/facets.dart';
import '../widgets/glass.dart';
import '../widgets/home_room.dart';
import '../widgets/honey_button.dart';

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
      Haptics.success(); // softens to a light tap under reduce-motion
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
    () =>
        state.buyFurniture(f.id, f.price, allowed: furnitureUnlocked(f, state)),
  );

  bool _buyStyle(BuildContext context, RoomStyle st) => _checkout(
    context,
    st.price,
    () => state.buyStyle(
      st.id,
      st.price,
      st.kind,
      allowed: styleUnlocked(st, state),
    ),
  );

  void _applyStyle(RoomStyle st) {
    state.applyStyle(st.id, st.kind);
    Sfx.instance.play('tick');
    HapticFeedback.selectionClick();
    onPersist();
  }

  bool _buySkin(BuildContext context, CreatureSkin sk) => _checkout(
    context,
    sk.price,
    () => state.buySkin(sk.id, sk.price, allowed: skinUnlocked(sk, state)),
  );

  void _applySkin(CreatureSkin sk) {
    state.applySkin(sk.id);
    Sfx.instance.play('tick');
    HapticFeedback.selectionClick();
    onPersist();
  }

  bool _buyWindow(BuildContext context, WindowView v) => _checkout(
    context,
    v.price,
    () => state.buyWindow(v.id, v.price, allowed: windowUnlocked(v, state)),
  );

  void _applyWindow(WindowView v) {
    state.applyWindow(v.id);
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

  /// The nearest currently-unlocked purchase across every shelf. Keeping one
  /// concrete reward in sight turns quest embers into a visible upgrade path
  /// instead of an abstract wallet balance.
  ({String name, int price})? _closestUpgrade() {
    final choices = <({String name, int price})>[];
    for (final item in furniture) {
      if (!state.ownedFurniture.contains(item.id) &&
          furnitureUnlocked(item, state)) {
        choices.add((name: item.name, price: item.price));
      }
    }
    for (final style in roomStyles) {
      if (style.price > 0 &&
          !isStyleOwned(state, style) &&
          styleUnlocked(style, state)) {
        choices.add((name: style.name, price: style.price));
      }
    }
    for (final skin in creatureSkins) {
      if (skin.price > 0 &&
          !isSkinOwned(state, skin) &&
          skinUnlocked(skin, state)) {
        choices.add((name: skin.name, price: skin.price));
      }
    }
    for (final view in windowViews) {
      if (view.price > 0 &&
          !isWindowOwned(state, view) &&
          windowUnlocked(view, state)) {
        choices.add((name: view.name, price: view.price));
      }
    }
    if (choices.isEmpty) return null;
    choices.sort((a, b) {
      final aGap = a.price > state.embers ? a.price - state.embers : 0;
      final bGap = b.price > state.embers ? b.price - state.embers : 0;
      final byGap = aGap.compareTo(bGap);
      return byGap == 0 ? a.price.compareTo(b.price) : byGap;
    });
    return choices.first;
  }

  Widget _upgradeTarget(({String name, int price}) reward) {
    final remaining = reward.price - state.embers;
    final ready = remaining <= 0;
    final progress = (state.embers / reward.price).clamp(0.0, 1.0);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
      decoration: facetedDecoration(
        cut: 9,
        color: Palette.xp.withValues(alpha: 0.08),
        borderColor: Palette.xp.withValues(alpha: 0.22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'CLOSEST UPGRADE · ${reward.name.toUpperCase()}',
                  overflow: TextOverflow.ellipsis,
                  style: Type.label.copyWith(
                    fontSize: 10.5,
                    color: Palette.xpLight,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                ready ? 'READY' : '✦ $remaining TO GO',
                style: Type.numerals.copyWith(
                  fontSize: 11,
                  color: ready ? Palette.success : Palette.xp,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          FacetedMeter(
            value: progress,
            height: 5,
            background: Colors.black.withValues(alpha: 0.18),
            color: ready ? Palette.success : Palette.xp,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final owned = state.ownedFurniture.length;
        final closestUpgrade = _closestUpgrade();
        return Scaffold(
          backgroundColor: Palette.parchment,
          body: WarmBackground(
            themeId: state.canvasTheme,
            reduceMotion: state.reduceMotion,
            tint: Palette.xp,
            child: SafeArea(
              child: Column(
                children: [
                  DetailHeader(
                    title: 'Your Keep',
                    accent: Palette.xp,
                    subtitle: 'cozy it up with the embers you earn',
                    pill: '✦ ${state.embers}',
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 40),
                      children: [
                        // a live look at your keep — it warms up as you buy
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
                                emberGlow: flameHueFor(state),
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
                              if (closestUpgrade != null) ...[
                                const SizedBox(height: 10),
                                _upgradeTarget(closestUpgrade),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _sectionHeader('HEARTH FLAME'),
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
                        _sectionHeader('WALLS & FLOOR'),
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
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Palette.card,
        duration: const Duration(milliseconds: 2200),
        content: Text(msg, style: Type.body.copyWith(color: Palette.textHi)),
      ),
    );
}

/// The settled state every card ends in ("in your room" / "on now" / "worn").
Widget _pill(Color c, IconData icon, String label) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
  decoration: facetedDecoration(
    cut: 8,
    color: c.withValues(alpha: 0.15),
    borderColor: c.withValues(alpha: 0.4),
  ),
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 14, color: c),
      const SizedBox(width: 5),
      Text(label, style: Type.label.copyWith(fontSize: 11, color: c)),
    ],
  ),
);

/// The trophy gate on a locked shelf — names the achievement, never just a
/// dead padlock.
Widget _lockedPill(String trophy) => Container(
  constraints: const BoxConstraints(maxWidth: 124),
  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
  decoration: facetedDecoration(
    cut: 8,
    color: Colors.black.withValues(alpha: 0.16),
    borderColor: Palette.textLo.withValues(alpha: 0.25),
  ),
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.lock_outline, size: 13, color: Palette.textLo),
      const SizedBox(width: 6),
      Flexible(
        child: Text(
          'earn “$trophy”',
          style: Type.body.copyWith(fontSize: 11, color: Palette.textLo),
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
    decoration: facetedDecoration(
      cut: 8,
      color: Palette.xp.withValues(alpha: 0.05),
      borderColor: Palette.xp.withValues(alpha: 0.6),
    ),
    child: Text(
      label,
      style: Type.label.copyWith(fontSize: 11, color: Palette.xpLight),
    ),
  ),
);

/// The price readout when the embers aren't there yet — a plain column, no
/// button pretence; the card's own tap still opens the try-on.
Widget _priceTag(int price, int embers) => Column(
  mainAxisSize: MainAxisSize.min,
  crossAxisAlignment: CrossAxisAlignment.end,
  children: [
    Text(
      '✦ $price',
      style: Type.display.copyWith(fontSize: 17, color: Palette.xp),
    ),
    const SizedBox(height: 1),
    Text(
      '${price - embers} to go',
      style: Type.body.copyWith(fontSize: 11, color: Palette.textLo),
    ),
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
  List<Color>? flame,
}) => HomeRoom(
  lively: !state.reduceMotion,
  unlocked: unlocked ?? state.ownedFurniture,
  wall: wall ?? wallColorsFor(state),
  floor: floor ?? floorColorsFor(state),
  window: window ?? state.windowScene,
  petAwake: true,
  // the hearth-flame hue (the item being tried on, or the current one)
  emberGlow: asFlameHue((flame ?? creatureColorsFor(state))[2]),
);

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
            Text(
              gate != null ? 'COMING UP' : 'TRY IT ON',
              style: Type.label.copyWith(
                fontSize: 11,
                letterSpacing: 1.5,
                color: Palette.textLo,
              ),
            ),
            const SizedBox(height: 14),
            hero,
            const SizedBox(height: 14),
            Text(
              name,
              textAlign: TextAlign.center,
              style: Type.display.copyWith(fontSize: 20),
            ),
            const SizedBox(height: 4),
            Text(
              blurb,
              textAlign: TextAlign.center,
              style: Type.body.copyWith(
                fontSize: 12,
                color: Palette.textLo,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            if (gate != null)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_outline, size: 13, color: Palette.textLo),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'earn “$gate” to unlock  ·  ✦ $price',
                      style: Type.body.copyWith(
                        fontSize: 11.5,
                        color: Palette.textLo,
                      ),
                    ),
                  ),
                ],
              )
            else
              Text(
                '✦ $price  ·  you have ✦ $embers',
                style: Type.body.copyWith(
                  fontSize: 11.5,
                  color: Palette.textLo,
                ),
              ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 8,
                  ),
                  child: Text(
                    'Not now',
                    style: Type.label.copyWith(
                      fontSize: 11,
                      color: Palette.textLo,
                    ),
                  ),
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
      return _pill(Palette.success, Icons.check_rounded, 'in your room');
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
    decoration: facetedDecoration(
      cut: 5,
      color: Palette.xp.withValues(alpha: 0.12),
    ),
    child: Text(
      zone.toUpperCase(),
      style: Type.label.copyWith(
        fontSize: 11,
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
                    _blurb,
                    style: Type.body.copyWith(
                      fontSize: 11.5,
                      color: Palette.textLo,
                    ),
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

  Widget _swatch() => DecoratedBox(
    decoration: facetedDecoration(
      cut: 8,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [style.a, style.b],
      ),
      borderColor: Palette.textHi.withValues(alpha: 0.15),
    ),
    child: const SizedBox(width: 46, height: 44),
  );

  Widget _kindChip() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: facetedDecoration(
      cut: 5,
      color: Palette.xp.withValues(alpha: 0.12),
    ),
    child: Text(
      style.kind == RoomStyleKind.wall ? 'WALL' : 'FLOOR',
      style: Type.label.copyWith(
        fontSize: 11,
        color: Palette.xp,
        letterSpacing: 1,
      ),
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
            ClipPath(
              clipper: const FacetedClipper(cut: 7),
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
                  Text(
                    view.name,
                    style: Type.label.copyWith(
                      fontSize: 13,
                      color: Palette.textHi,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    view.id == 'moon'
                        ? 'the original night sky'
                        : 'a new view outside your window',
                    style: Type.body.copyWith(
                      fontSize: 11.5,
                      color: Palette.textLo,
                    ),
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
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      bar,
    );
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      bar,
    );
  }

  @override
  bool shouldRepaint(_WindowSwatchPainter old) => old.scene != scene;
}

/// A hearth-flame colour row: a little flame swatch in that colour + buy / wear
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
            // a little flame swatch in this colour — see the fire before you buy
            SizedBox(
              width: 50,
              height: 50,
              child: CustomPaint(painter: _FlameSwatchPainter(skin.colors)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    skin.name,
                    style: Type.label.copyWith(
                      fontSize: 13,
                      color: Palette.textHi,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    skin.id == 'ember_amber'
                        ? 'the original hearth-fire'
                        : 'a flame all your own',
                    style: Type.body.copyWith(
                      fontSize: 11.5,
                      color: Palette.textLo,
                    ),
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

  // your keep's hearth burning in the new flame colour
  void _openTryOn(BuildContext context) => _showTryOn(
    context,
    hero: _roomHero(state, flame: skin.colors),
    name: skin.name,
    blurb: 'your hearth-fire, a new colour',
    price: skin.price,
    embers: state.embers,
    gate: skinUnlocked(skin, state)
        ? null
        : (skinGateLabel(skin) ?? 'a trophy'),
    onBuy: onBuy,
    receipt: 'Your hearth burns ${skin.name} now',
  );

  Widget _cta(BuildContext context, bool applied) {
    if (applied) {
      return _pill(Palette.success, Icons.check_rounded, 'lit');
    }
    if (isSkinOwned(state, skin)) {
      return _applyChip('Light', onApply);
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

/// A tiny flame in the given four-stop colour — the shop swatch for a hearth
/// flame colour, on a dark hearth ground.
class _FlameSwatchPainter extends CustomPainter {
  _FlameSwatchPainter(this.colors);
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final hue = asFlameHue(colors[2]);
    paintEmberFlameSwatch(canvas, size, hue);
  }

  @override
  bool shouldRepaint(_FlameSwatchPainter old) =>
      !listEquals(old.colors, colors);
}
