import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio.dart';
import '../content/furniture.dart';
import '../engine.dart';
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
                                child: Portrait(
                                  size: 80,
                                  aura: state.dominantStat?.color,
                                  level: state.level,
                                  trait: state.portraitTrait,
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
                        for (final f in furniture) ...[
                          _ShopCard(
                            item: f,
                            state: state,
                            onBuy: () => _buy(f),
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
