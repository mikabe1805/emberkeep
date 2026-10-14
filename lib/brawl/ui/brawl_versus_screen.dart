// The versus screen: a nod to the fighting games it comes from. Your fighter
// card faces the monster's. Under them, your six stats (the ones you trained
// this week glowing as "+N this week"), the monster and what it is weak to,
// your six abilities with their tiers, and FIGHT!
//
// Everything on it is read from the save: the numbers are the real stats and
// this week's real training. Words stay plain, and nothing here can be lost.
library;

import 'package:flutter/material.dart';

import '../../tokens.dart';
import '../../widgets/glass_switch.dart';
import '../../widgets/honey_button.dart';
import '../../widgets/pressable.dart';
import '../../audio.dart' show InteractionSound, MaterialSound;
import '../brawl_abilities.dart';
import '../core/brawl_core.dart';
import '../weekly_training.dart' show boostOf, pointsLabel;
import 'brawl_glass.dart';
import 'brawl_setup.dart';

class BrawlVersusScreen extends StatelessWidget {
  const BrawlVersusScreen({
    super.key,
    required this.setup,
    required this.easy,
    required this.onEasyChanged,
    required this.onFight,
    required this.onBack,
    this.reduceMotion = false,
  });

  final BrawlSetup setup;
  final bool easy;
  final ValueChanged<bool> onEasyChanged;
  final VoidCallback onFight;
  final VoidCallback onBack;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return BrawlBackdrop(
      child: Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              key: const Key('brawl-versus-scroll'),
              padding: EdgeInsets.fromLTRB(
                16,
                media.padding.top + 8,
                16,
                media.padding.bottom + 132,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TopLine(setup: setup, onBack: onBack),
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      'Your week comes with you.',
                      textAlign: TextAlign.center,
                      style: brawlSerif(
                        18,
                        italic: true,
                        weight: FontWeight.w500,
                        color: Palette.textMid,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _Faceoff(setup: setup, reduceMotion: reduceMotion),
                  const SizedBox(height: 14),
                  _StatsCard(setup: setup),
                  const SizedBox(height: 14),
                  _MonsterCard(setup: setup),
                  const SizedBox(height: 14),
                  _AbilitiesCard(setup: setup),
                  const SizedBox(height: 14),
                  _EasyRow(easy: easy, onChanged: onEasyChanged),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _FightBar(
              practice: setup.practice,
              bottomInset: media.padding.bottom,
              onFight: onFight,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopLine extends StatelessWidget {
  const _TopLine({required this.setup, required this.onBack});

  final BrawlSetup setup;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final title = setup.practice
        ? '${setup.dayName.toUpperCase()} PRACTICE'
        : '${setup.dayName.toUpperCase()} BRAWL';
    return Row(
      children: [
        Pressable(
          key: const Key('brawl-versus-back'),
          pressDepth: 1,
          edgeColor: Colors.transparent,
          borderRadius: BorderRadius.circular(22),
          material: MaterialSound.parchment,
          interactionSound: InteractionSound.navigate,
          semanticLabel: 'Back to the house',
          onTapUp: (_) => onBack(),
          child: const SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: ExcludeSemantics(
                child: Icon(
                  Icons.arrow_back_rounded,
                  size: 24,
                  color: Palette.textMid,
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFE5C896).withValues(alpha: 0.35),
                ),
                color: const Color(0x33140C06),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Palette.xp,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      title,
                      style: Type.label.copyWith(
                        letterSpacing: 2.4,
                        color: const Color(0xFFE5C896),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 44),
      ],
    );
  }
}

// ------------------------------------------------------------------ the faceoff

class _Faceoff extends StatelessWidget {
  const _Faceoff({required this.setup, required this.reduceMotion});

  final BrawlSetup setup;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final monster = setup.monster;
    final rank = brawlRankOf(setup.level);
    final def = monster.def;
    return Semantics(
      container: true,
      label:
          'You, level ${setup.level}, face ${def.name}${brawlMonsterTitle(monster, setup.level) == def.name ? '' : ', ${brawlMonsterTitle(monster, setup.level)}'}.',
      child: ExcludeSemantics(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Row(
              children: [
                Expanded(
                  child: _Card(
                    key: const Key('brawl-card-you'),
                    portrait: BrawlPortrait(
                      kind: BrawlPortraitKind.fighter,
                      rank: 0,
                      reduceMotion: reduceMotion,
                    ),
                    name: 'You',
                    sub: 'LV ${setup.level}',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Card(
                    key: const Key('brawl-card-monster'),
                    portrait: BrawlPortrait(
                      kind: monster == BrawlMonster.troll
                          ? BrawlPortraitKind.troll
                          : BrawlPortraitKind.fog,
                      rank: rank,
                      reduceMotion: reduceMotion,
                    ),
                    name: def.name,
                    sub: brawlRankLine(monster, setup.level),
                  ),
                ),
              ],
            ),
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  center: Alignment(-0.3, -0.4),
                  colors: [
                    Color(0xFFFFE9B8),
                    Color(0xFFE0A865),
                    Color(0xFFB87A32),
                  ],
                  stops: [0, 0.6, 1],
                ),
                border: Border.all(color: const Color(0xFF2A1608), width: 2),
                boxShadow: const [
                  BoxShadow(color: Color(0x66000000), blurRadius: 8),
                ],
              ),
              child: Text(
                'VS',
                textScaler: TextScaler.noScaling,
                style: brawlSerif(
                  20,
                  weight: FontWeight.w800,
                  italic: true,
                  color: const Color(0xFF2A1608),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    super.key,
    required this.portrait,
    required this.name,
    required this.sub,
  });

  final Widget portrait;
  final String name;
  final String sub;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(18),
    child: DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE5C896).withValues(alpha: 0.22),
        ),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xDD3A281C), Color(0xF01A100B)],
        ),
      ),
      child: Stack(
        children: [
          portrait,
          Positioned(
            left: 12,
            right: 12,
            bottom: 10,
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: MediaQuery.textScalerOf(
                  context,
                ).clamp(maxScaleFactor: 1.25),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: brawlSerif(
                      24,
                      weight: FontWeight.w700,
                      color: Palette.textHi,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    sub,
                    maxLines: 2,
                    style: Type.label.copyWith(
                      fontSize: Type.minLabel,
                      letterSpacing: 1.6,
                      color: const Color(0xFFE5C896),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// ------------------------------------------------------------------ stats

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.setup});

  final BrawlSetup setup;

  @override
  Widget build(BuildContext context) {
    return BrawlGlassCard(
      key: const Key('brawl-stats'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const BrawlCaps('YOUR STATS'),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'gold = trained this week',
                  textAlign: TextAlign.end,
                  style: Type.label.copyWith(
                    fontSize: Type.minLabel,
                    letterSpacing: 0.6,
                    color: Palette.textLo,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final stat in Stat.values)
            _StatRow(
              key: ValueKey('brawl-stat-${stat.name}'),
              stat: stat,
              value: setup.stats[stat] ?? 0,
              points: setup.pointsOf(stat),
            ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    super.key,
    required this.stat,
    required this.value,
    required this.points,
  });

  final Stat stat;
  final int value;
  final double points;

  @override
  Widget build(BuildContext context) {
    final trained = points > 0;
    final week = trained ? '+${pointsLabel(points)} this week' : null;
    // At large text the week's words take a line of their own.
    final stacked = MediaQuery.textScalerOf(context).scale(1) > 1.2;
    return Semantics(
      container: true,
      label:
          '${stat.label} $value${week == null ? '' : ', plus ${pointsLabel(points)} this week'}. ${abilitySpoken(stat, value)}',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    stat.icon,
                    size: 18,
                    color: trained ? Palette.xpLight : Palette.textMid,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      stat.label,
                      style: brawlSerif(
                        19,
                        weight: trained ? FontWeight.w700 : FontWeight.w500,
                        color: trained ? Palette.textHi : Palette.textMid,
                      ),
                    ),
                  ),
                  if (week != null && !stacked) ...[
                    Flexible(
                      child: Text(
                        week,
                        textAlign: TextAlign.end,
                        style: Type.label.copyWith(
                          fontSize: Type.minLabel,
                          letterSpacing: 0.4,
                          color: Palette.xpLight,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Text(
                    '$value',
                    style: Type.numerals.copyWith(
                      fontSize: 18,
                      color: Palette.textHi,
                    ),
                  ),
                ],
              ),
              if (week != null && stacked)
                Padding(
                  padding: const EdgeInsets.only(left: 28, top: 2),
                  child: Text(
                    week,
                    style: Type.label.copyWith(
                      fontSize: Type.minLabel,
                      letterSpacing: 0.4,
                      color: Palette.xpLight,
                    ),
                  ),
                ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 28),
                child: _StatBar(value: value, points: points),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatBar extends StatelessWidget {
  const _StatBar({required this.value, required this.points});

  final int value;
  final double points;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 9,
    child: CustomPaint(painter: _BarPainter(value, points)),
  );
}

class _BarPainter extends CustomPainter {
  _BarPainter(this.value, this.points);

  final int value;
  final double points;

  static const double _cap = 150;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final track = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 1, w, h - 2),
      Radius.circular(h / 2),
    );
    canvas.drawRRect(track, Paint()..color = const Color(0x8C0C0603));
    final total = (value / _cap).clamp(0.0, 1.0) * w;
    final week = (points / _cap).clamp(0.0, 1.0) * w;
    final base = (total - week).clamp(0.0, w);
    canvas.save();
    canvas.clipRRect(track);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, base, h),
      Paint()..color = const Color(0xFFB08A55),
    );
    if (week > 0) {
      final rect = Rect.fromLTWH(base, 0, week, h);
      canvas.drawRect(
        rect,
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFFF7D68E), Color(0xFFE0A865)],
          ).createShader(rect),
      );
    }
    canvas.restore();
    // Tier ticks at 10, 40 and 80.
    final tick = Paint()
      ..color = const Color(0x66FFE2AA)
      ..strokeWidth = 1;
    for (final t in const [10, 40, 80]) {
      final x = t / _cap * w;
      canvas.drawLine(Offset(x, 2), Offset(x, h - 2), tick);
    }
    if (week > 0) {
      canvas.drawCircle(
        Offset(total.clamp(3, w - 3), h / 2),
        4.5,
        Paint()
          ..color = const Color(0x66FFD25A)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      canvas.drawCircle(
        Offset(total.clamp(3, w - 3), h / 2),
        2.4,
        Paint()..color = const Color(0xFFFFE3A0),
      );
    }
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.value != value || old.points != points;
}

// ------------------------------------------------------------------ the monster

class _MonsterCard extends StatelessWidget {
  const _MonsterCard({required this.setup});

  final BrawlSetup setup;

  @override
  Widget build(BuildContext context) {
    final def = setup.monster.def;
    final weakStat = appStatOf(def.weak);
    final ability = abilityOf(weakStat).name;
    return BrawlGlassCard(
      key: const Key('brawl-monster'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BrawlCaps('THIS WEEK’S MONSTER'),
          const SizedBox(height: 10),
          Semantics(
            container: true,
            label: '${def.weakText}.',
            child: ExcludeSemantics(
              child: Container(
                key: const Key('brawl-weak-chip'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFF7D68E), Color(0xFFD9A24F)],
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.gps_fixed_rounded,
                      size: 16,
                      color: Color(0xFF3A1D08),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        def.weakText,
                        style: brawlSerif(
                          17,
                          weight: FontWeight.w700,
                          color: const Color(0xFF3A1D08),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '${def.weakLine} '),
                TextSpan(
                  text: ability,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Palette.textHi,
                  ),
                ),
                const TextSpan(text: ' hits it where it is soft.'),
              ],
            ),
            style: brawlSerif(
              17,
              weight: FontWeight.w500,
              color: Palette.textMid,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(
                  text: 'Its one move: ',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Palette.textHi,
                  ),
                ),
                TextSpan(
                  text:
                      '${def.moveName}. ${def.moveLine} If it bumps you, you '
                      'catch your breath and get right back up.',
                ),
              ],
            ),
            style: brawlSerif(
              17,
              weight: FontWeight.w500,
              color: Palette.textMid,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'It grows as you do. A quiet week takes about a minute; the stats '
            'you trained this week make it much quicker.',
            style: brawlSerif(
              15,
              weight: FontWeight.w500,
              color: Palette.textLo,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ abilities

String _cap(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

class _AbilitiesCard extends StatelessWidget {
  const _AbilitiesCard({required this.setup});

  final BrawlSetup setup;

  @override
  Widget build(BuildContext context) {
    return BrawlGlassCard(
      key: const Key('brawl-abilities'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(child: BrawlCaps('ABILITIES')),
              Text(
                'one per stat',
                style: Type.label.copyWith(
                  fontSize: Type.minLabel,
                  letterSpacing: 0.6,
                  color: Palette.textLo,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final stat in Stat.values) ...[
            _AbilityRow(
              key: ValueKey('brawl-ability-${stat.name}'),
              stat: stat,
              value: setup.stats[stat] ?? 0,
              points: setup.pointsOf(stat),
              weakSpot: appStatOf(setup.monster.def.weak) == stat,
            ),
            if (stat != Stat.values.last) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _AbilityRow extends StatelessWidget {
  const _AbilityRow({
    super.key,
    required this.stat,
    required this.value,
    required this.points,
    required this.weakSpot,
  });

  final Stat stat;
  final int value;
  final double points;
  final bool weakSpot;

  @override
  Widget build(BuildContext context) {
    final ability = abilityOf(stat);
    final tier = tierOf(value);
    final locked = tier == 0;
    final trained = points > 0 && !locked;
    final desc = locked
        ? lockedLine(stat)
        : tier > 1
        ? 'Tier $tier: ${_cap(ability.perk(tier))}'
        : ability.blurb;
    final tag = locked
        ? '${stat.abbr} $value of ${abilityTierAt.first}'
        : trained
        ? '+${pointsLabel(points)} THIS WEEK'
        : nextLine(stat, value).toUpperCase();
    final boost = boostOf(points);
    return Semantics(
      container: true,
      label:
          '${ability.name}. ${locked ? lockedLine(stat) : 'Tier $tier. ${ability.perk(tier)}'}.'
          '${weakSpot ? ' The monster is weak to it.' : ''}'
          '${trained ? ' Trained this week, plus ${pointsLabel(points)}.' : ''}',
      child: ExcludeSemantics(
        child: BrawlGlassCard(
          hot: trained,
          radius: 14,
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: locked
                      ? null
                      : const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFFF7D68E), Color(0xFFD9A24F)],
                        ),
                  color: locked ? const Color(0x33FFE2AA) : null,
                ),
                child: Icon(
                  locked ? Icons.lock_outline_rounded : stat.icon,
                  size: 22,
                  color: locked ? Palette.textLo : const Color(0xFF3A1D08),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 2,
                      children: [
                        Text(
                          ability.name,
                          style: brawlSerif(
                            19,
                            weight: FontWeight.w700,
                            color: locked ? Palette.textMid : Palette.textHi,
                          ),
                        ),
                        if (weakSpot)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(
                                  0xFFE59B8E,
                                ).withValues(alpha: 0.7),
                              ),
                            ),
                            child: Text(
                              'WEAK SPOT',
                              style: Type.label.copyWith(
                                fontSize: Type.minLabel,
                                letterSpacing: 1.2,
                                color: const Color(0xFFE59B8E),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      desc,
                      style: brawlSerif(
                        16,
                        weight: FontWeight.w500,
                        color: Palette.textMid,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 10,
                      runSpacing: 4,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (var n = 1; n <= abilityTopTier; n++)
                              Container(
                                width: 9,
                                height: 9,
                                margin: const EdgeInsets.only(right: 4),
                                decoration: BoxDecoration(
                                  shape: BoxShape.rectangle,
                                  borderRadius: BorderRadius.circular(2),
                                  color: tier >= n
                                      ? Palette.xpLight
                                      : const Color(0x33FFE2AA),
                                ),
                              ),
                          ],
                        ),
                        Text(
                          tag,
                          style: Type.label.copyWith(
                            fontSize: Type.minLabel,
                            letterSpacing: 0.8,
                            color: trained ? Palette.xpLight : Palette.textLo,
                          ),
                        ),
                        if (trained)
                          Text(
                            'boost x${boost.toStringAsFixed(2)}',
                            style: Type.label.copyWith(
                              fontSize: Type.minLabel,
                              letterSpacing: 0.4,
                              fontWeight: FontWeight.w500,
                              color: Palette.textLo,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ easy mode and FIGHT!

class _EasyRow extends StatelessWidget {
  const _EasyRow({required this.easy, required this.onChanged});

  final bool easy;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => BrawlGlassCard(
    key: const Key('brawl-easy'),
    padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
    child: Row(
      children: [
        Expanded(
          child: ExcludeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Easy mode',
                  style: brawlSerif(19, weight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  'Tap anywhere to attack. A gentler monster.',
                  style: brawlSerif(
                    15,
                    weight: FontWeight.w500,
                    color: Palette.textLo,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 52, minHeight: 44),
          child: Center(
            child: GlassSwitch(
              key: const Key('brawl-easy-switch'),
              value: easy,
              onChanged: onChanged,
              semanticLabel:
                  'Easy mode. Tap anywhere to attack. A gentler monster',
            ),
          ),
        ),
      ],
    ),
  );
}

class _FightBar extends StatelessWidget {
  const _FightBar({
    required this.practice,
    required this.bottomInset,
    required this.onFight,
  });

  final bool practice;
  final double bottomInset;
  final VoidCallback onFight;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x00130B07), Color(0xF0130B07), Color(0xFF130B07)],
        stops: [0, 0.35, 1],
      ),
    ),
    child: Padding(
      padding: EdgeInsets.fromLTRB(24, 28, 24, bottomInset + 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (practice)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'This weekend’s chest is already yours. This one is for practice.',
                textAlign: TextAlign.center,
                style: brawlSerif(
                  15,
                  italic: true,
                  weight: FontWeight.w500,
                  color: Palette.textMid,
                  height: 1.2,
                ),
              ),
            ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: HoneyButton(
              key: const Key('brawl-fight'),
              label: 'FIGHT!',
              semanticLabel: practice ? 'Fight, for practice' : 'Fight',
              expand: true,
              fontSize: 14,
              onTap: onFight,
            ),
          ),
        ],
      ),
    ),
  );
}
