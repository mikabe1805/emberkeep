// The weekend brawl's promise, measured: a quiet week takes about a minute
// and a bit, some training about half that, a big week about a third, at any
// level, against both monsters. The average-player bot (2.5 taps a second,
// abilities when they light up) plays seeded fights at the real 1/60 s step,
// with no rendering, and the medians must land in the bands.
//
// These are medians over many seeds, so a platform's last-bit differences in
// sin and cos cannot move them out of a band; they never assert one seed's
// exact time.
import 'package:emberkeep/brawl/core/brawl_core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'brawl_test_support.dart';

const _bands = <String, (double, double)>{
  'quiet': (55, 85),
  'some': (25, 45),
  'big': (13, 27),
};

/// The three weeks from the spec for one monster. "Some" is 8 quests
/// (Strength 4, Intellect 2, Vitality 2). "Big" is 12: 8 in the monster's
/// weakness and 1 in each of four other stats.
Map<BrawlStat, double> weekFor(String week, BrawlMonster monster) {
  switch (week) {
    case 'quiet':
      return const {};
    case 'some':
      return const {BrawlStat.str: 4, BrawlStat.intl: 2, BrawlStat.vit: 2};
    default:
      final weak = monster.def.weak;
      final spread = [
        BrawlStat.str,
        BrawlStat.intl,
        BrawlStat.foc,
        BrawlStat.vit,
        BrawlStat.dis,
      ].where((s) => s != weak).take(4);
      return {weak: 8, for (final s in spread) s: 1};
  }
}

double median(List<double> xs) {
  final s = [...xs]..sort();
  return s[(s.length - 1) ~/ 2];
}

double finishSeconds(BrawlConfig config, int seed) {
  final fight = createBrawlFight(config.copyWith(seed: seed));
  playBrawlWithBot(fight, botSeed: seed);
  expect(fight.phase, isNot(BrawlPhase.fight), reason: 'the fight must end');
  return fight.finishTime;
}

class _Profile {
  const _Profile(this.name, this.level, this.stats, this.runs);
  final String name;
  final int level;
  final Map<BrawlStat, int> stats;
  final int runs;
}

void main() {
  final profiles = [
    _Profile('Mika LV6', 6, mikaStats, 61),
    _Profile('Level 1 (all 10)', 1, allStats(10), 61),
    _Profile('Level 20 (all 190)', 20, allStats(190), 61),
  ];

  final table = StringBuffer(
    '\nWeekend brawl tuning, median seconds to FINISH IT! (bot, 2.5 taps/s)\n',
  );
  final medians = <String, double>{};

  setUpAll(() {
    // Run the whole grid once; each test below reads from it.
    final clock = Stopwatch()..start();
    for (final p in profiles) {
      table.writeln(p.name);
      for (final monster in BrawlMonster.values) {
        final row = StringBuffer('  ${monster.def.name.padRight(12)}');
        for (final week in _bands.keys) {
          final config = testConfig(
            level: p.level,
            stats: p.stats,
            training: weekFor(week, monster),
            monster: monster,
          );
          final times = [
            for (var s = 1; s <= p.runs; s++) finishSeconds(config, s),
          ];
          final m = median(times);
          medians['${p.name}|${monster.key}|$week'] = m;
          row.write('$week ${m.toStringAsFixed(1).padLeft(5)}   ');
        }
        table.writeln(row);
      }
    }
    table.writeln('(grid took ${clock.elapsedMilliseconds} ms)');
    // ignore: avoid_print
    print(table);
  });

  for (final p in profiles) {
    for (final monster in BrawlMonster.values) {
      for (final week in _bands.keys) {
        final (lo, hi) = _bands[week]!;
        test(
          '${p.name}, ${monster.def.name}, $week week lands in $lo-$hi s',
          () {
            final m = medians['${p.name}|${monster.key}|$week']!;
            expect(m, inInclusiveRange(lo, hi));
          },
        );
      }
    }
  }

  test('more training is always faster, at every level', () {
    for (final p in profiles) {
      for (final monster in BrawlMonster.values) {
        final q = medians['${p.name}|${monster.key}|quiet']!;
        final s = medians['${p.name}|${monster.key}|some']!;
        final b = medians['${p.name}|${monster.key}|big']!;
        expect(s, lessThan(q - 10), reason: '${p.name} ${monster.key}');
        expect(b, lessThan(s - 5), reason: '${p.name} ${monster.key}');
      }
    }
  });

  test(
    'the monster scales with the level, so a quiet week is never a pushover',
    () {
      for (final monster in BrawlMonster.values) {
        final hp1 = brawlMonsterHp(
          testConfig(level: 1, stats: allStats(10), monster: monster),
        );
        final hp6 = brawlMonsterHp(testConfig(monster: monster));
        final hp20 = brawlMonsterHp(
          testConfig(level: 20, stats: allStats(190), monster: monster),
        );
        expect(hp6, greaterThan(hp1));
        expect(hp20, greaterThan(hp6));
        for (final p in profiles) {
          expect(
            medians['${p.name}|${monster.key}|quiet']!,
            greaterThan(55),
            reason: '${p.name} must not evaporate the ${monster.key}',
          );
        }
      }
    },
  );

  test('Easy mode keeps the same bands', () {
    for (final monster in BrawlMonster.values) {
      for (final week in _bands.keys) {
        final config = testConfig(
          training: weekFor(week, monster),
          monster: monster,
          easy: true,
        );
        final m = median([
          for (var s = 1; s <= 13; s++) finishSeconds(config, s),
        ]);
        final (lo, hi) = _bands[week]!;
        expect(
          m,
          inInclusiveRange(lo - 5, hi + 3),
          reason: '${monster.key} $week easy',
        );
      }
    }
  });
}
