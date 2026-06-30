import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio.dart';
import '../content/creature_skins.dart';
import '../content/furniture.dart';
import '../content/room_styles.dart';
import '../content/window_scenes.dart';
import '../engine.dart';
import '../models.dart';
import '../tokens.dart';
import '../widgets/detail_header.dart';
import '../widgets/glass.dart';
import '../widgets/home_room.dart';
import '../widgets/honey_button.dart';
import '../widgets/portrait.dart';

/// "Your Space" shop (round-42): spend the Embers (✦) you earn by playing on
/// furniture for your room — in whatever order you like. Customization is about
/// CHOICE, so nothing is forced on a fixed track; you save up for the pieces
/// you want. A few special pieces are gated behind a trophy first (you still
/// pay), so achievements quietly open new shelves.
class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key, required this.state, required this.onPersist});

  final GameState state;

  /// Persist the save after a purchase.
  final VoidCallback onPersist;

  void _buy(FurnitureItem f) {
    final ok = state.buyFurniture(
      f.id,
      f.price,
      allowed: furnitureUnlocked(f, state),
    );
    if (ok) {
      Sfx.instance.play('loot'); // a small treasure
      HapticFeedback.mediumImpact();
      onPersist();
    } else {
      Sfx.instance.play('tick');
      HapticFeedback.selectionClick();
    }
  }

  void _buyStyle(RoomStyle st) {
    final ok = state.buyStyle(st.id, st.price, st.kind,
        allowed: styleUnlocked(st, state));
    if (ok) {
      Sfx.instance.play('loot');
      HapticFeedback.mediumImpact();
      onPersist();
    } else {
      Sfx.instance.play('tick');
      HapticFeedback.selectionClick();
    }
  }

  void _applyStyle(RoomStyle st) {
    state.applyStyle(st.id, st.kind);
    Sfx.instance.play('tick');
    HapticFeedback.selectionClick();
    onPersist();
  }

  void _buySkin(CreatureSkin sk) {
    final ok = state.buySkin(sk.id, sk.price, allowed: skinUnlocked(sk, state));
    if (ok) {
      Sfx.instance.play('loot');
      HapticFeedback.mediumImpact();
      onPersist();
    } else {
      Sfx.instance.play('tick');
      HapticFeedback.selectionClick();
    }
  }

  void _applySkin(CreatureSkin sk) {
    state.applySkin(sk.id);
    Sfx.instance.play('tick');
    HapticFeedback.selectionClick();
    onPersist();
  }

  void _buyWindow(WindowView v) {
    final ok =
        state.buyWindow(v.id, v.price, allowed: windowUnlocked(v, state));
    if (ok) {
      Sfx.instance.play('loot');
      HapticFeedback.mediumImpact();
      onPersist();
    } else {
      Sfx.instance.play('tick');
      HapticFeedback.selectionClick();
    }
  }

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
                                unlocked: state.ownedFurniture,
                                wall: wallColorsFor(state),
                                floor: floorColorsFor(state),
                                window: state.windowScene,
                                child: Portrait(
                                  size: 80,
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
                            onBuy: () => _buySkin(sk),
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
                            onBuy: () => _buy(f),
                          ),
                          const SizedBox(height: 10),
                        ],
                        const SizedBox(height: 8),
                        _sectionHeader('ROOM STYLE'),
                        for (final st in roomStyles) ...[
                          _StyleCard(
                            style: st,
                            state: state,
                            onBuy: () => _buyStyle(st),
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
                            onBuy: () => _buyWindow(v),
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

class _ShopCard extends StatelessWidget {
  const _ShopCard({
    required this.item,
    required this.state,
    required this.onBuy,
  });

  final FurnitureItem item;
  final GameState state;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final owned = state.ownedFurniture.contains(item.id);
    return Opacity(
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
            _cta(),
          ],
        ),
      ),
    );
  }

  Widget _cta() {
    if (state.ownedFurniture.contains(item.id)) {
      return _pill(
        Palette.success,
        Icons.check_rounded,
        'in your room',
      );
    }
    if (!furnitureUnlocked(item, state)) {
      return _lockedPill(furnitureGateLabel(item) ?? 'a trophy');
    }
    if (state.embers >= item.price) {
      return HoneyButton(label: '✦ ${item.price}', onTap: onBuy);
    }
    // unlocked, but not enough embers yet
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '✦ ${item.price}',
          style: Type.display.copyWith(fontSize: 17, color: Palette.xp),
        ),
        const SizedBox(height: 1),
        Text(
          '${item.price - state.embers} to go',
          style: Type.body.copyWith(fontSize: 10, color: Palette.textLo),
        ),
      ],
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
  final VoidCallback onBuy;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final applied = isStyleApplied(state, style);
    return GlassPanel(
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
                  style.kind == RoomStyleKind.wall
                      ? 'a new colour for your walls'
                      : 'a new look underfoot',
                  style:
                      Type.body.copyWith(fontSize: 11.5, color: Palette.textLo),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _cta(applied),
        ],
      ),
    );
  }

  Widget _cta(bool applied) {
    if (applied) {
      return _pill(Palette.success, Icons.check_rounded, 'on now');
    }
    if (isStyleOwned(state, style)) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onApply,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Palette.xp.withValues(alpha: 0.6)),
          ),
          child: Text('Apply',
              style: Type.label.copyWith(fontSize: 11, color: Palette.xpLight)),
        ),
      );
    }
    if (!styleUnlocked(style, state)) {
      return _lockedPill(styleGateLabel(style) ?? 'a trophy');
    }
    if (state.embers >= style.price) {
      return HoneyButton(label: '✦ ${style.price}', onTap: onBuy);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text('✦ ${style.price}',
            style: Type.display.copyWith(fontSize: 17, color: Palette.xp)),
        const SizedBox(height: 1),
        Text('${style.price - state.embers} to go',
            style: Type.body.copyWith(fontSize: 10, color: Palette.textLo)),
      ],
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
              child: Text('earn “$trophy”',
                  style:
                      Type.body.copyWith(fontSize: 10, color: Palette.textLo)),
            ),
          ],
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
  final VoidCallback onBuy;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final applied = isWindowApplied(state, view);
    return GlassPanel(
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
                  style:
                      Type.body.copyWith(fontSize: 11.5, color: Palette.textLo),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _cta(applied),
        ],
      ),
    );
  }

  Widget _cta(bool applied) {
    if (applied) {
      return _pill(Palette.success, Icons.check_rounded, 'on now');
    }
    if (isWindowOwned(state, view)) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onApply,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Palette.xp.withValues(alpha: 0.6)),
          ),
          child: Text('Apply',
              style: Type.label.copyWith(fontSize: 11, color: Palette.xpLight)),
        ),
      );
    }
    if (!windowUnlocked(view, state)) {
      return _lockedPill(windowGateLabel(view) ?? 'a trophy');
    }
    if (state.embers >= view.price) {
      return HoneyButton(label: '✦ ${view.price}', onTap: onBuy);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text('✦ ${view.price}',
            style: Type.display.copyWith(fontSize: 17, color: Palette.xp)),
        const SizedBox(height: 1),
        Text('${view.price - state.embers} to go',
            style: Type.body.copyWith(fontSize: 10, color: Palette.textLo)),
      ],
    );
  }

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
              child: Text('earn “$trophy”',
                  style:
                      Type.body.copyWith(fontSize: 10, color: Palette.textLo)),
            ),
          ],
        ),
      );
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
  final VoidCallback onBuy;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final applied = isSkinApplied(state, skin);
    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          // a real little ember in this colour — see it before you buy
          SizedBox(
            width: 50,
            height: 50,
            child: Portrait(
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
                  style:
                      Type.body.copyWith(fontSize: 11.5, color: Palette.textLo),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _cta(applied),
        ],
      ),
    );
  }

  Widget _cta(bool applied) {
    if (applied) {
      return _pill(Palette.success, Icons.check_rounded, 'worn');
    }
    if (isSkinOwned(state, skin)) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onApply,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Palette.xp.withValues(alpha: 0.6)),
          ),
          child: Text('Wear',
              style: Type.label.copyWith(fontSize: 11, color: Palette.xpLight)),
        ),
      );
    }
    if (!skinUnlocked(skin, state)) {
      return _lockedPill(skinGateLabel(skin) ?? 'a trophy');
    }
    if (state.embers >= skin.price) {
      return HoneyButton(label: '✦ ${skin.price}', onTap: onBuy);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text('✦ ${skin.price}',
            style: Type.display.copyWith(fontSize: 17, color: Palette.xp)),
        const SizedBox(height: 1),
        Text('${skin.price - state.embers} to go',
            style: Type.body.copyWith(fontSize: 10, color: Palette.textLo)),
      ],
    );
  }

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
              child: Text('earn “$trophy”',
                  style:
                      Type.body.copyWith(fontSize: 10, color: Palette.textLo)),
            ),
          ],
        ),
      );
}
