import 'package:flutter/material.dart';

import '../brawl/brawl_abilities.dart';
import '../brawl/weekly_training.dart';
import '../tokens.dart';
import 'facets.dart';
import 'glass.dart';

/// What a stat is for in the weekend fight, on its own page: the ability it
/// powers, what each tier adds and where the stat stands among them, and what
/// this week's training does to it. The Me page says it in a line; this is the
/// place that says it in full.
class StatAbilityPanel extends StatelessWidget {
  const StatAbilityPanel({
    super.key,
    required this.stat,
    required this.value,
    required this.training,
    required this.monster,
  });

  final Stat stat;
  final int value;

  /// This week's training for all six stats.
  final WeeklyTraining training;

  /// The week's monster, so the stat it is weak to can say so.
  final WeeklyMonster monster;

  @override
  Widget build(BuildContext context) {
    final ability = abilityOf(stat);
    final hue = stat.color;
    final tier = tierOf(value);
    final trained = training.trained(stat);
    return GlassPanel(
      key: Key('stat-ability-${stat.name}'),
      blur: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(stat.icon, size: 16, color: hue),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'IN THE WEEKEND FIGHT',
                        style: Type.label.copyWith(fontSize: 11),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 6,
                  ),
                  decoration: facetedDecoration(
                    cut: 7,
                    color: hue.withValues(alpha: tier == 0 ? 0.06 : 0.16),
                    borderColor: hue.withValues(alpha: tier == 0 ? 0.25 : 0.45),
                  ),
                  child: Text(
                    tierName(tier).toUpperCase(),
                    key: Key('stat-ability-tier-${stat.name}'),
                    style: Type.label.copyWith(
                      fontSize: 12,
                      color: tier == 0 ? Palette.textLo : hue,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(ability.name, style: Type.display.copyWith(fontSize: 24)),
          const SizedBox(height: 4),
          Text(
            ability.blurb,
            style: Type.body.copyWith(fontSize: 14, color: Palette.textMid),
          ),
          if (tier == 0) ...[
            const SizedBox(height: 8),
            Text(
              lockedLine(stat),
              key: Key('stat-ability-locked-${stat.name}'),
              style: Type.body.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: hue,
              ),
            ),
          ],
          const SizedBox(height: 12),
          for (var t = 1; t <= abilityTopTier; t++)
            _TierRow(
              stat: stat,
              tier: t,
              reached: tier >= t,
              next: tier + 1 == t,
            ),
          const SizedBox(height: 8),
          const Divider(color: Palette.glassEdge, height: 1),
          const SizedBox(height: 10),
          if (trained)
            Wrap(
              spacing: 10,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  key: Key('stat-ability-week-${stat.name}'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: hue.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: hue.withValues(alpha: 0.62),
                      width: 0.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: hue.withValues(alpha: 0.38),
                        blurRadius: 11,
                      ),
                    ],
                  ),
                  child: Text(
                    training.lineFor(stat)!,
                    style: Type.body.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Palette.textHi,
                    ),
                  ),
                ),
                Text(
                  '${ability.name} is boosted ×'
                  '${training.boost(stat).toStringAsFixed(1)} '
                  'in the fight.',
                  key: Key('stat-ability-boost-${stat.name}'),
                  style: Type.body.copyWith(
                    fontSize: 13,
                    color: Palette.textMid,
                  ),
                ),
              ],
            )
          else
            Text(
              'Finish quests for ${stat.label} this week to boost '
              '${ability.name} in the fight.',
              key: Key('stat-ability-quiet-${stat.name}'),
              style: Type.body.copyWith(fontSize: 13, color: Palette.textLo),
            ),
          if (monster.weakness == stat) ...[
            const SizedBox(height: 8),
            Text(
              '${_capitalized(monster.theName)} is ${monster.weakLine} this '
              'week, so it matters most.',
              key: Key('stat-ability-weak-${stat.name}'),
              style: Type.body.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: hue,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _capitalized(String s) =>
    s.isEmpty ? s : '${s.substring(0, 1).toUpperCase()}${s.substring(1)}';

class _TierRow extends StatelessWidget {
  const _TierRow({
    required this.stat,
    required this.tier,
    required this.reached,
    required this.next,
  });

  final Stat stat;
  final int tier;
  final bool reached;
  final bool next;

  @override
  Widget build(BuildContext context) {
    final hue = stat.color;
    final ability = abilityOf(stat);
    final color = reached
        ? Palette.textHi
        : next
        ? Palette.textMid
        : Palette.textLo;
    return Padding(
      key: Key('stat-ability-tier-${stat.name}-$tier'),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 22,
            child: Icon(
              reached ? Icons.check_circle_rounded : Icons.circle_outlined,
              size: 15,
              color: reached ? hue : hue.withValues(alpha: next ? 0.8 : 0.35),
            ),
          ),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'Tier $tier at ${abilityTierAt[tier - 1]}  ',
                    style: Type.body.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  TextSpan(
                    text: ability.perk(tier),
                    style: Type.body.copyWith(fontSize: 13, color: color),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
