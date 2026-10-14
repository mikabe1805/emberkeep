// The pieces of the weekend brawl were built apart: the abilities and the
// week's training from the save, the fight from a pure simulation. These tests
// hold the seams between them, so one cannot drift from the other: the same
// tiers, the same boost, the same stat order, and a week read from the engine
// reaching the fight as the points the Me page shows.
import 'dart:math';

import 'package:emberkeep/brawl/brawl_abilities.dart';
import 'package:emberkeep/brawl/core/brawl_core.dart';
import 'package:emberkeep/brawl/weekly_training.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/tokens.dart';
import 'package:flutter_test/flutter_test.dart';

/// Never crits, never drops loot: for assertions about exact numbers.
class _NoLuck implements Random {
  @override
  bool nextBool() => false;
  @override
  double nextDouble() => 0.999999;
  @override
  int nextInt(int max) => 0;
}

void main() {
  tearDown(Clock.reset);

  test('the core and the app name the six stats the same way, in order', () {
    expect(BrawlStat.values.length, Stat.values.length);
    for (var i = 0; i < Stat.values.length; i++) {
      expect(BrawlStat.values[i].name, Stat.values[i].name);
      expect(BrawlStat.values.byName(Stat.values[i].name).index, i);
    }
  });

  test('the core and the abilities agree where a tier begins', () {
    expect(kBrawlTierAt, abilityTierAt);
    for (var value = 0; value <= 200; value++) {
      expect(brawlTierOf(value), tierOf(value), reason: 'at $value');
    }
  });

  test('the core and the week agree on the boost', () {
    for (var halves = 0; halves <= 60; halves++) {
      final points = halves / 2;
      expect(brawlBoostOf(points), closeTo(boostOf(points), 1e-12));
    }
  });

  test('a week read from the engine is the training the fight gets', () {
    Clock.freeze(DateTime(2026, 10, 14, 12)); // Wed
    final state = GameState(rng: _NoLuck());
    void finish(String title, Stat stat, {bool timer = false}) => state.commit(
      state.roll(
        Quest(title: title, stat: stat, difficulty: 2),
        verified: timer,
      ),
    );
    finish('Do 5 push-ups', Stat.str);
    finish('Do 8 push-ups', Stat.str);
    finish('Read one page', Stat.intl, timer: true);
    finish('Read two pages', Stat.intl, timer: true);
    finish('Call a friend', Stat.soc);

    final week = state.weeklyTraining();
    expect(week.pointsOf(Stat.str), 2);
    expect(week.pointsOf(Stat.intl), 3, reason: 'two timed ones, 1.5 each');
    expect(week.pointsOf(Stat.soc), 1);

    // Give the fight the stat values after those quests and the week's points.
    final config = BrawlConfig(
      level: state.level,
      stats: {
        for (final stat in Stat.values)
          BrawlStat.values.byName(stat.name): state.stats[stat]!,
      },
      training: {
        for (final stat in Stat.values)
          BrawlStat.values.byName(stat.name): week.pointsOf(stat),
      },
      monster: BrawlMonster.troll,
    );
    for (final stat in Stat.values) {
      final key = BrawlStat.values.byName(stat.name);
      expect(config.pointsOf(key), week.pointsOf(stat), reason: stat.name);
    }
    // And the loadout it builds boosts the stats the week trained.
    final lo = BrawlLoadout.fromConfig(config);
    for (final stat in Stat.values) {
      final key = BrawlStat.values.byName(stat.name);
      final points = min(week.pointsOf(stat), state.stats[stat]!.toDouble());
      expect(lo.boost[key], closeTo(boostOf(points), 1e-12), reason: stat.name);
    }
    expect(lo.boost[BrawlStat.vit], 1, reason: 'nothing trained for Vitality');
  });

  test('the monster of the week is one the core can fight, weak the same', () {
    // Even ISO weeks the Couch Troll, odd weeks the Fog. The week keeps the
    // core's names for them: couch_troll is troll, fog is fog.
    final troll = monsterOfTheWeek(DateTime(2026, 10, 14)); // ISO week 42
    final fog = monsterOfTheWeek(DateTime(2026, 10, 21)); // ISO week 43
    expect(troll.id, 'couch_troll');
    expect(fog.id, 'fog');
    expect(troll.name, BrawlMonster.troll.def.name);
    expect(
      troll.theName.toLowerCase(),
      BrawlMonster.troll.def.the.toLowerCase(),
    );
    expect(fog.theName.toLowerCase(), BrawlMonster.fog.def.the.toLowerCase());
    expect(troll.weakness.name, BrawlMonster.troll.def.weak.name);
    expect(fog.weakness.name, BrawlMonster.fog.def.weak.name);
    expect(troll.weakness, Stat.str);
    expect(fog.weakness, Stat.intl);
  });
}
