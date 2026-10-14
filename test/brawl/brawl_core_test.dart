import 'package:emberkeep/brawl/core/brawl_core.dart';
import 'package:emberkeep/tokens.dart' show Stat;
import 'package:flutter_test/flutter_test.dart';

import 'brawl_test_support.dart';

void main() {
  group('stats, tiers and the week', () {
    test('the stats keep the serialized keys and the app order', () {
      expect(BrawlStat.values.map((s) => s.key).toList(), [
        'str',
        'vit',
        'intl',
        'foc',
        'soc',
        'dis',
      ]);
      expect(
        BrawlStat.values.map((s) => s.name).toList(),
        Stat.values.map((s) => s.name).toList(),
        reason: 'BrawlStat must map 1:1 onto the app Stat enum',
      );
    });

    test('abilities unlock at 10, 40, 80 and 150', () {
      expect(
        [
          for (final v in [0, 9, 10, 39, 40, 79, 80, 149, 150, 400])
            brawlTierOf(v),
        ],
        [0, 0, 1, 1, 2, 2, 3, 3, 4, 4],
      );
    });

    test(
      'the boost is 1 + min(3, 0.18 x points) and a timer Quest counts 1.5',
      () {
        expect(brawlBoostOf(0), 1);
        expect(brawlBoostOf(5), closeTo(1.9, 1e-9));
        expect(brawlBoostOf(8), closeTo(2.44, 1e-9));
        expect(brawlBoostOf(1.5), closeTo(1.27, 1e-9));
        expect(brawlBoostOf(16), lessThan(4));
        expect(brawlBoostOf(17), 4);
        expect(brawlBoostOf(200), 4);
      },
    );

    test('a trained ability hits harder than its boost (boost to the 1.5)', () {
      expect(brawlAbilityBoost(1), 1);
      expect(brawlAbilityBoost(4), closeTo(8, 1e-12));
      expect(brawlAbilityBoost(2.44), closeTo(3.8116, 1e-3));
    });

    test('the loadout reads tiers, boosts and the aura from the config', () {
      final lo = BrawlLoadout.fromConfig(
        testConfig(
          training: {BrawlStat.str: 4, BrawlStat.intl: 2, BrawlStat.soc: 3},
        ),
      );
      expect(lo.tier[BrawlStat.str], 2);
      expect(lo.tier[BrawlStat.vit], 3);
      expect(lo.tier[BrawlStat.dis], 3);
      expect(lo.tier[BrawlStat.soc], 0);
      expect(lo.unlocked(BrawlStat.soc), isFalse);
      expect(lo.unlocked(BrawlStat.intl), isTrue);
      expect(lo.chain, 4, reason: 'Strength tier 2 adds the 4th combo hit');
      expect(lo.boost[BrawlStat.str], closeTo(1.72, 1e-9));
      expect(lo.boost[BrawlStat.foc], 1);
      // Social 5 cannot have more than 5 points of training.
      expect(lo.points[BrawlStat.soc], 3);
      expect(lo.aura, closeTo(1 + BrawlTune.auraPerPoint * 9, 1e-12));
      expect(lo.vit.hpMax, 181, reason: '100 + 0.9 x 90 with no training');
    });

    test('training points never exceed the stat, and the aura caps at 20', () {
      final lo = BrawlLoadout.fromConfig(
        testConfig(
          stats: allStats(100),
          training: allStats(100).map((k, v) => MapEntry(k, 100.0)),
        ),
      );
      expect(lo.aura, closeTo(1 + BrawlTune.auraPerPoint * 20, 1e-12));
      final capped = BrawlLoadout.fromConfig(
        testConfig(training: {BrawlStat.soc: 12}),
      );
      expect(capped.points[BrawlStat.soc], 5);
    });

    test('a quiet week has no boost and no aura', () {
      final lo = BrawlLoadout.fromConfig(testConfig());
      for (final s in BrawlStat.values) {
        expect(lo.boost[s], 1);
      }
      expect(lo.aura, 1);
    });

    test('the monster ladder, weaknesses and chest times', () {
      expect(BrawlMonster.troll.def.weak, BrawlStat.str);
      expect(BrawlMonster.fog.def.weak, BrawlStat.intl);
      expect(BrawlMonster.troll.def.mult.slam, greaterThan(1.4));
      expect(BrawlMonster.fog.def.mult.fist, lessThanOrEqualTo(0.8));
      expect(
        [
          for (final l in [1, 3, 4, 7, 8, 12, 13, 30]) brawlRankOf(l),
        ],
        [0, 0, 1, 1, 2, 2, 3, 3],
      );
      expect(brawlMonsterTitle(BrawlMonster.troll, 1), 'Cushion Squatter');
      expect(brawlMonsterTitle(BrawlMonster.troll, 20), 'Duke of the Recliner');
      expect(brawlChestFor(0), BrawlChest.swift);
      expect(brawlChestFor(25), BrawlChest.swift);
      expect(brawlChestFor(25.01), BrawlChest.steady);
      expect(brawlChestFor(50), BrawlChest.steady);
      expect(brawlChestFor(50.01), BrawlChest.patient);
      expect(brawlChestFor(300), BrawlChest.patient);
      expect(brawlFormatTime(65), '1:05');
      expect(brawlFormatTime(0), '0:00');
      expect(brawlFormatTime(69.6), '1:10');
    });

    test('monster copy follows the app voice', () {
      for (final m in BrawlMonster.values) {
        final d = m.def;
        final copy = [
          d.name,
          d.the,
          d.weakText,
          d.weakLine,
          d.moveName,
          d.moveLine,
          d.finisher,
          d.door,
          d.doorSub,
          ...d.titles,
          ...d.loot.values,
        ].join(' ');
        expect(copy.contains('—'), isFalse);
        for (final word in [
          'failed',
          'missed',
          'lost',
          'broke',
          'behind',
          'overdue',
        ]) {
          expect(copy.toLowerCase().contains(word), isFalse, reason: word);
        }
      }
    });
  });

  group('the random numbers', () {
    test('the same seed is the same stream, a different seed is not', () {
      final a = BrawlRng(7);
      final b = BrawlRng(7);
      final c = BrawlRng(8);
      final xs = [for (var i = 0; i < 20; i++) a.next()];
      expect([for (var i = 0; i < 20; i++) b.next()], xs);
      expect([for (var i = 0; i < 20; i++) c.next()], isNot(xs));
      expect(xs.every((x) => x >= 0 && x < 1), isTrue);
    });

    test('mulberry32 matches the prototype bit for bit', () {
      // Values from the prototype's core.js: mulberry32(1), first five.
      final r = BrawlRng(1);
      final got = [for (var i = 0; i < 5; i++) r.next()];
      expect(got[0], closeTo(0.6270739405881613, 1e-15));
      expect(got[1], closeTo(0.002735721180215478, 1e-15));
      expect(got[2], closeTo(0.5274470399599522, 1e-15));
      expect(got[3], closeTo(0.9810509674716741, 1e-15));
      expect(got[4], closeTo(0.9683778982143849, 1e-15));
    });

    test('the split multiply is a 32-bit multiply', () {
      expect(brawlImul(0xFFFFFFFF, 0xFFFFFFFF), 1);
      expect(
        brawlImul(0x12345678, 0x9ABCDEF0),
        (0x12345678 * 0x9ABCDEF0) & 0xFFFFFFFF,
      );
      expect(brawlImul(3, 5), 15);
    });

    test('negative seeds wrap instead of failing', () {
      expect(BrawlRng(-1).next(), BrawlRng(0xFFFFFFFF).next());
    });
  });

  group('the intro and the announcer', () {
    test('ROUND 1 first, then FIGHT! when the intro ends', () {
      final rig = Rig(testFight());
      rig.log.addAll(rig.fight.drainEvents());
      expect(rig.log.first.type, BrawlEventType.announce);
      expect(rig.log.first.cue, BrawlCue.round1);
      expect(BrawlCue.round1.text, 'ROUND 1');
      rig.run(1.0);
      expect(rig.fight.phase, BrawlPhase.intro);
      expect(rig.saw(BrawlEventType.fightStart), isFalse);
      rig.run(0.4);
      expect(rig.fight.phase, BrawlPhase.fight);
      expect(rig.saw(BrawlEventType.fightStart), isTrue);
      expect(rig.of(BrawlEventType.announce).map((e) => e.cue).toList(), [
        BrawlCue.round1,
        BrawlCue.fight,
      ]);
      expect(BrawlCue.fight.text, 'FIGHT!');
    });

    test('nothing can be hit or done during the intro', () {
      final rig = Rig(testFight());
      rig.input
        ..moveX = 1
        ..pAtk = true;
      rig.run(1.0);
      expect(
        rig.f.x,
        BrawlTune.startX,
        reason: 'the fighter waits in the intro',
      );
      expect(rig.hits(), isEmpty);
    });

    test('the fight clock starts at FIGHT!', () {
      final rig = startedRig();
      expect(rig.fight.t, closeTo(0, BrawlTune.step * 2));
      rig.run(2);
      expect(rig.fight.t, closeTo(2, 0.05));
    });

    test('advance slices a frame the way the prototype did', () {
      final a = testFight();
      final b = testFight();
      final ia = BrawlInput();
      final ib = BrawlInput();
      for (var i = 0; i < 90; i++) {
        a.advance(1 / 30, ia);
        b.step(1 / 60, ib);
        b.step(1 / 60, ib);
      }
      expect(a.clock, closeTo(b.clock, 1e-9));
      expect(a.phase, b.phase);
      expect(a.events, isEmpty, reason: 'advance hands the events back');
    });
  });

  group('moving and jumping', () {
    test('the pad moves the fighter and the monster blocks the way', () {
      final rig = startedRig();
      rig.input.moveX = 1;
      rig.run(0.5);
      expect(rig.f.x, greaterThan(BrawlTune.startX + 60));
      rig.run(4);
      expect(rig.f.x, closeTo(rig.fight.solidX(), 1e-6));
      rig.input.moveX = -1;
      rig.run(6);
      expect(rig.f.x, 14, reason: 'the left edge of the stage');
    });

    test('a jump rises about 98 px, comes down and lands with dust', () {
      final rig = startedRig();
      rig.input.pJump = true;
      var peak = 0.0;
      rig.step();
      expect(rig.f.grounded, isFalse);
      while (!rig.f.grounded) {
        rig.step();
        if (rig.f.h > peak) peak = rig.f.h;
      }
      expect(peak, inInclusiveRange(90, 105));
      expect(rig.of(BrawlEventType.jump).single.air, isFalse);
      expect(rig.of(BrawlEventType.land), hasLength(1));
      expect(rig.of(BrawlEventType.land).single.power, greaterThan(400));
    });

    test('one extra jump in the air, then no more', () {
      final rig = startedRig();
      rig.input.pJump = true;
      rig.run(0.2);
      rig.input.pJump = true;
      rig.run(0.1);
      rig.input.pJump = true;
      rig.run(0.05);
      final jumps = rig.of(BrawlEventType.jump).toList();
      expect(jumps.map((e) => e.air).toList(), [false, true]);
    });

    test('letting go of jump early trims the jump', () {
      double peak(bool held) {
        final rig = startedRig();
        rig.input.pJump = true;
        var best = 0.0;
        rig.step();
        rig.input.jumpHeld = held;
        while (!rig.f.grounded) {
          rig.step();
          if (rig.f.h > best) best = rig.f.h;
        }
        return best;
      }

      expect(peak(false), lessThan(peak(true) - 12));
    });

    test('a jump pressed during a swing cancels the recovery', () {
      final rig = startedRig();
      rig.input.pAtk = true;
      rig.step(8);
      expect(rig.f.state, BrawlFighterState.attack);
      rig.input.pJump = true;
      rig.run(0.3);
      expect(rig.of(BrawlEventType.jump), hasLength(1));
      expect(rig.f.state, isNot(BrawlFighterState.attack));
    });
  });

  group('the combo chain and hit-stop', () {
    test('Strength tier 2 chains jab, cross, kick, upper', () {
      final rig = startedRig();
      rig.walkToMonster();
      for (var i = 0; i < 90; i++) {
        rig.input.pAtk = true;
        rig.step(6);
      }
      final swings = rig.of(BrawlEventType.swing).map((e) => e.move).toList();
      expect(swings.take(4).toList(), [
        BrawlMove.jab,
        BrawlMove.cross,
        BrawlMove.kick,
        BrawlMove.upper,
      ]);
      expect(rig.fight.combo.best, greaterThanOrEqualTo(4));
    });

    test('below Strength tier 2 the chain is three hits', () {
      final rig = startedRig(stats: {...mikaStats, BrawlStat.str: 30});
      rig.walkToMonster();
      for (var i = 0; i < 90; i++) {
        rig.input.pAtk = true;
        rig.step(6);
      }
      final swings = rig.of(BrawlEventType.swing).map((e) => e.move).toList();
      expect(swings.take(4).toList(), [
        BrawlMove.jab,
        BrawlMove.cross,
        BrawlMove.upper,
        BrawlMove.jab,
      ]);
    });

    test('a hit freezes the world for a beat and says how long', () {
      final rig = startedRig();
      rig.walkToMonster();
      rig.input.pAtk = true;
      rig.until(() => rig.saw(BrawlEventType.hit));
      final hit = rig.hits().first;
      expect(hit.hitStop, 0.05);
      expect(rig.fight.freeze, greaterThan(0));
      final x = rig.f.x;
      final st = rig.f.st;
      final t0 = rig.fight.t;
      rig.step();
      expect(rig.f.x, x);
      expect(rig.f.st, st, reason: 'the fighter holds still in hit-stop');
      expect(
        rig.fight.t,
        greaterThan(t0),
        reason: 'the fight clock keeps running',
      );
    });

    test('a heavy hit stops longer and shakes the screen', () {
      final rig = startedRig();
      rig.walkToMonster();
      for (
        var i = 0;
        i < 80 && rig.hits().where((e) => e.move == BrawlMove.upper).isEmpty;
        i++
      ) {
        rig.input.pAtk = true;
        rig.step(6);
      }
      final upper = rig.hits().firstWhere((e) => e.move == BrawlMove.upper);
      expect(upper.heavy, isTrue);
      expect(upper.hitStop, 0.09);
      expect(upper.shake, 4);
    });

    test(
      'hits carry the number, the combo count and a position on the monster',
      () {
        final rig = startedRig();
        rig.walkToMonster();
        for (var i = 0; i < 30; i++) {
          rig.input.pAtk = true;
          rig.step(6);
        }
        final hits = rig.hits().toList();
        expect(hits, isNotEmpty);
        expect(hits.first.damage, greaterThan(0));
        expect(hits.first.combo, 1);
        expect(hits.map((e) => e.combo), contains(2));
        for (final h in hits) {
          expect(h.x, lessThan(rig.fight.m.x + 1));
          expect(h.y, greaterThan(0));
          expect(h.source, isNotNull);
        }
      },
    );

    test('the combo counter drops after the timer runs out', () {
      final rig = startedRig();
      rig.walkToMonster();
      rig.input.pAtk = true;
      rig.until(() => rig.fight.combo.n > 0);
      expect(rig.fight.combo.n, greaterThan(0));
      rig.run(2.5);
      expect(rig.fight.combo.n, 0);
      expect(rig.fight.combo.best, greaterThan(0));
    });

    test('a swing at nothing is a whiff and costs nothing', () {
      final rig = startedRig(stats: {...mikaStats, BrawlStat.str: 30});
      rig.input.pAtk = true;
      rig.run(0.4);
      expect(rig.of(BrawlEventType.whiff), isNotEmpty);
      expect(rig.hits(), isEmpty);
      expect(rig.fight.stats.whiffs, greaterThan(0));
    });

    test('Easy mode dashes in by itself, standard mode does not reach', () {
      final easy = startedRig(easy: true);
      easy.input.pAtk = true;
      easy.run(0.8);
      expect(easy.hits(), isNotEmpty, reason: 'tap anywhere');
      final std = startedRig();
      std.input.pAtk = true;
      std.run(0.4);
      expect(std.hits(), isEmpty);
    });

    test('presses are cleared as they are read', () {
      final rig = startedRig();
      rig.input
        ..pAtk = true
        ..pJump = true
        ..pSpell = true
        ..pFriend = true
        ..pSuper = true
        ..pFinish = true;
      rig.step();
      expect(rig.input.pAtk, isFalse);
      expect(rig.input.pJump, isFalse);
      expect(rig.input.pSpell, isFalse);
      expect(rig.input.pFriend, isFalse);
      expect(rig.input.pSuper, isFalse);
      expect(rig.input.pFinish, isFalse);
    });
  });

  group('Power Slam', () {
    test('hold ATTACK, let go, and the slam lands heavy', () {
      final rig = startedRig();
      rig.walkToMonster();
      rig.input
        ..pAtk = true
        ..attackHeld = true;
      rig.run(1.2);
      expect(rig.saw(BrawlEventType.slamCharge), isTrue);
      expect(rig.saw(BrawlEventType.slamReady), isTrue);
      rig.input.attackHeld = false;
      rig.run(1.0);
      expect(rig.of(BrawlEventType.slam), hasLength(1));
      final impact = rig.of(BrawlEventType.slamImpact).single;
      expect(impact.hitMonster, isTrue);
      expect(impact.shake, 9);
      final slam = rig.hits(BrawlDamageSource.slam).first;
      final jab = rig.hits(BrawlDamageSource.fist).first;
      expect(slam.heavy, isTrue);
      expect(slam.weak, isTrue, reason: 'the Troll is weak to Strength');
      expect(slam.damage, greaterThan(jab.damage * 2));
      expect(slam.hitStop, 0.09);
      expect(rig.fight.cd.slam, greaterThan(0));
      expect(rig.fight.cd.slam, lessThanOrEqualTo(rig.fight.lo.slam.cd));
    });

    test('a longer charge hits harder', () {
      int slamDamage(double holdFor) {
        final rig = startedRig(seed: 5);
        rig.walkToMonster();
        rig.input
          ..pAtk = true
          ..attackHeld = true;
        rig.run(holdFor);
        rig.input.attackHeld = false;
        rig.run(1.2);
        return rig.hits(BrawlDamageSource.slam).first.damage;
      }

      expect(slamDamage(1.4), greaterThan(slamDamage(0.55)));
    });

    test('a locked Power Slam does not charge', () {
      final rig = startedRig(stats: {...mikaStats, BrawlStat.str: 8});
      rig.walkToMonster();
      rig.input
        ..pAtk = true
        ..attackHeld = true;
      rig.run(1.2);
      expect(rig.saw(BrawlEventType.slamCharge), isFalse);
    });

    test('Strength tier 4 sends a ground wave after the slam', () {
      final rig = startedRig(stats: {...mikaStats, BrawlStat.str: 150});
      rig.walkToMonster();
      rig.input
        ..pAtk = true
        ..attackHeld = true;
      rig.run(1.0);
      rig.input.attackHeld = false;
      rig.run(1.2);
      expect(rig.saw(BrawlEventType.groundWave), isTrue);
      expect(
        rig.hits(BrawlDamageSource.slam).map((e) => e.label),
        contains('wave'),
      );
    });
  });

  group('Spell Bolt', () {
    test('a bolt flies, hits for Intellect and recharges', () {
      final rig = startedRig();
      rig.input.pSpell = true;
      rig.run(1.0);
      expect(rig.of(BrawlEventType.cast).single.count, 1);
      expect(rig.of(BrawlEventType.bolt), hasLength(1));
      final hit = rig.hits(BrawlDamageSource.spell).single;
      expect(hit.move, BrawlMove.spell);
      expect(rig.fight.cd.spell, greaterThan(0));
      // Pressed again before the recharge: nothing new.
      rig.input.pSpell = true;
      rig.run(0.3);
      expect(rig.of(BrawlEventType.cast), hasLength(1));
      rig.run(2.5);
      rig.input.pSpell = true;
      rig.run(0.3);
      expect(rig.of(BrawlEventType.cast), hasLength(2));
    });

    test('the Fog is weak to the bolt and soft against fists', () {
      final rig = startedRig(monster: BrawlMonster.fog);
      rig.input.pSpell = true;
      rig.run(1.2);
      expect(rig.hits(BrawlDamageSource.spell).first.weak, isTrue);
      final rig2 = startedRig(monster: BrawlMonster.fog);
      rig2.walkToMonster();
      rig2.input.pAtk = true;
      rig2.run(0.5);
      expect(rig2.hits(BrawlDamageSource.fist).first.resist, isTrue);
    });

    test('Intellect tier 2 fires twin bolts', () {
      final rig = startedRig(stats: {...mikaStats, BrawlStat.intl: 40});
      rig.input.pSpell = true;
      rig.run(1.2);
      expect(rig.of(BrawlEventType.cast).single.count, 2);
      expect(rig.hits(BrawlDamageSource.spell), hasLength(2));
    });

    test('Intellect tier 3 chains a second hit', () {
      final rig = startedRig(stats: {...mikaStats, BrawlStat.intl: 80});
      rig.input.pSpell = true;
      rig.run(1.5);
      expect(rig.saw(BrawlEventType.chainBolt), isTrue);
      expect(
        rig.hits(BrawlDamageSource.spell).map((e) => e.label),
        contains('chain'),
      );
    });

    test('a locked bolt says so and fires nothing', () {
      final rig = startedRig(stats: {...mikaStats, BrawlStat.intl: 4});
      rig.input.pSpell = true;
      rig.run(0.5);
      expect(rig.of(BrawlEventType.locked).single.stat, BrawlStat.intl);
      expect(rig.saw(BrawlEventType.cast), isFalse);
    });
  });

  group('Call a Friend', () {
    test('a locked friend says so (Mika has Social 5)', () {
      final rig = startedRig();
      rig.input.pFriend = true;
      rig.run(0.5);
      expect(rig.of(BrawlEventType.locked).single.stat, BrawlStat.soc);
      expect(rig.saw(BrawlEventType.call), isFalse);
    });

    test('with Social 10 a friend dashes in, hits three times and leaves', () {
      final rig = startedRig(stats: {...mikaStats, BrawlStat.soc: 10});
      rig.input.pFriend = true;
      rig.run(4.0);
      expect(rig.saw(BrawlEventType.call), isTrue);
      expect(
        rig.of(BrawlEventType.announce).map((e) => e.cue),
        contains(BrawlCue.friend),
      );
      expect(rig.of(BrawlEventType.friendEnter), hasLength(1));
      expect(rig.hits(BrawlDamageSource.friend), hasLength(3));
      expect(rig.hits(BrawlDamageSource.friend).last.heavy, isTrue);
      expect(rig.saw(BrawlEventType.friendLeave), isTrue);
      expect(rig.fight.friends, isEmpty);
      expect(rig.fight.cd.friend, greaterThan(0));
    });

    test('Social tier 3 brings two friends', () {
      final rig = startedRig(stats: {...mikaStats, BrawlStat.soc: 80});
      rig.input.pFriend = true;
      rig.run(4.0);
      expect(rig.of(BrawlEventType.friendEnter), hasLength(2));
      expect(rig.hits(BrawlDamageSource.friend), hasLength(6));
    });

    test('tier 2 calls friends more often than tier 1', () {
      final one = BrawlLoadout.fromConfig(
        testConfig(stats: {...mikaStats, BrawlStat.soc: 10}),
      );
      final two = BrawlLoadout.fromConfig(
        testConfig(stats: {...mikaStats, BrawlStat.soc: 40}),
      );
      expect(two.friend.cd, lessThan(one.friend.cd));
    });
  });

  group('Focus', () {
    test('crits start at Focus 10 and widen the combo window', () {
      final none = BrawlLoadout.fromConfig(
        testConfig(stats: {...mikaStats, BrawlStat.foc: 5}),
      );
      final some = BrawlLoadout.fromConfig(
        testConfig(stats: {...mikaStats, BrawlStat.foc: 12}),
      );
      final lots = BrawlLoadout.fromConfig(
        testConfig(stats: {...mikaStats, BrawlStat.foc: 150}),
      );
      expect(none.focus.on, isFalse);
      expect(none.focus.chance, BrawlTune.critBase);
      expect(none.focus.window, 0);
      expect(some.focus.on, isTrue);
      expect(some.focus.chance, greaterThan(none.focus.chance));
      expect(some.focus.window, greaterThan(0));
      expect(lots.focus.window, greaterThan(some.focus.window));
      expect(lots.focus.gold, isTrue);
      expect(lots.focus.dbl, greaterThan(0));
    });

    test('training Focus raises the crit chance (never above 80 percent)', () {
      final quiet = BrawlLoadout.fromConfig(testConfig());
      final trained = BrawlLoadout.fromConfig(
        testConfig(training: {BrawlStat.foc: 6}),
      );
      expect(trained.focus.chance, greaterThan(quiet.focus.chance));
      expect(trained.focus.window, greaterThan(quiet.focus.window));
      final huge = BrawlLoadout.fromConfig(
        testConfig(
          stats: {...mikaStats, BrawlStat.foc: 400},
          training: {BrawlStat.foc: 50},
        ),
      );
      expect(huge.focus.chance, 0.8);
    });

    test('crits happen, multiply the hit and add the Focus share', () {
      final rig = startedRig(
        stats: {...mikaStats, BrawlStat.foc: 400},
        training: {BrawlStat.foc: 50},
      );
      rig.walkToMonster();
      for (var i = 0; i < 90; i++) {
        rig.input.pAtk = true;
        rig.step(6);
      }
      final hits = rig.hits().toList();
      final crits = hits.where((e) => e.crit > 0).length;
      expect(crits / hits.length, greaterThan(0.5));
      expect(
        hits.any((e) => e.crit == 2),
        isTrue,
        reason: 'double crits from tier 3',
      );
      expect(rig.fight.stats.crits, crits);
      expect(rig.fight.stats.dmg.focus, greaterThan(0));
    });

    test(
      'a hit keeps the combo alive for the base time plus the Focus window',
      () {
        final rig = startedRig();
        rig.walkToMonster();
        rig.input.pAtk = true;
        rig.until(() => rig.saw(BrawlEventType.hit));
        expect(
          rig.fight.combo.t,
          closeTo(BrawlTune.comboKeep + rig.fight.lo.focus.window * 1.2, 1e-9),
        );
      },
    );
  });

  group('Second Wind', () {
    test('Vitality sets health, training raises it', () {
      final a = BrawlLoadout.fromConfig(
        testConfig(stats: {...mikaStats, BrawlStat.vit: 0}),
      );
      final b = BrawlLoadout.fromConfig(testConfig());
      final c = BrawlLoadout.fromConfig(
        testConfig(training: {BrawlStat.vit: 5}),
      );
      expect(a.vit.hpMax, 100);
      expect(b.vit.hpMax, 181);
      expect(c.vit.hpMax, greaterThan(b.vit.hpMax));
      expect(c.vit.getupMult, lessThan(b.vit.getupMult));
    });

    test('a bump knocks you back, you get up and the wind restores health', () {
      final rig = startedRig();
      rig.fight.f.hp = 100;
      rig.fight.debugHurt(BrawlHazard.wave);
      expect(rig.f.state, BrawlFighterState.down);
      final hurt = rig.of(BrawlEventType.hurt);
      expect(hurt, isEmpty, reason: 'events wait until the next drain');
      rig.run(2.5);
      expect(rig.of(BrawlEventType.hurt).single.knockedDown, isTrue);
      expect(rig.saw(BrawlEventType.getup), isTrue);
      expect(rig.saw(BrawlEventType.secondWind), isTrue);
      expect(rig.f.state, isNot(BrawlFighterState.down));
      expect(rig.fight.knockdowns, 1);
      expect(rig.fight.perfect, isFalse);
    });

    test('a locked Second Wind still gets you up, without the heal', () {
      final rig = startedRig(stats: {...mikaStats, BrawlStat.vit: 5});
      rig.fight.debugHurt(BrawlHazard.drop);
      rig.run(2.5);
      expect(rig.saw(BrawlEventType.getup), isTrue);
      expect(rig.saw(BrawlEventType.secondWind), isFalse);
    });

    test('no losing: at zero health you catch your breath and get up', () {
      final rig = startedRig();
      rig.fight.f.hp = 1;
      rig.fight.debugHurt(BrawlHazard.wave);
      rig.step();
      expect(rig.saw(BrawlEventType.catchBreath), isTrue);
      expect(rig.f.hp, closeTo(rig.f.hpMax * 0.7, 1e-6));
      rig.run(1.5);
      expect(rig.f.state, BrawlFighterState.down, reason: 'a longer rest');
      rig.run(1.5);
      expect(rig.f.state, isNot(BrawlFighterState.down));
      expect(rig.fight.phase, BrawlPhase.fight, reason: 'the fight goes on');
    });

    test('getting up gives a moment nobody can bump you', () {
      final rig = startedRig();
      rig.fight.debugHurt(BrawlHazard.wave);
      rig.until(() => rig.f.state == BrawlFighterState.getup);
      rig.fight.debugHurt(BrawlHazard.wave);
      rig.run(0.1);
      expect(rig.fight.knockdowns, 1);
    });

    test('Vitality tier 2 trickles health back', () {
      final rig = startedRig(stats: {...mikaStats, BrawlStat.vit: 40});
      rig.f.hp = 50;
      rig.run(2.0);
      expect(rig.f.hp, greaterThan(50 + 2));
      final none = startedRig(stats: {...mikaStats, BrawlStat.vit: 20});
      none.f.hp = 50;
      none.run(2.0);
      expect(none.f.hp, 50);
    });

    test('Easy mode only bumps, never knocks down', () {
      final rig = startedRig(easy: true);
      rig.fight.debugHurt(BrawlHazard.wave);
      rig.run(0.6);
      final hurt = rig.of(BrawlEventType.hurt).single;
      expect(hurt.knockedDown, isFalse);
      expect(rig.fight.knockdowns, 0);
      expect(rig.f.hp, rig.f.hpMax);
    });
  });

  group('the Super', () {
    test('hits fill the meter, and it rings when full', () {
      final rig = startedRig();
      rig.walkToMonster();
      rig.fight.sup = 99.9;
      rig.input.pAtk = true;
      rig.until(() => rig.saw(BrawlEventType.hit));
      expect(rig.saw(BrawlEventType.meterFull), isTrue);
      expect(rig.fight.sup, 100);
    });

    test('the meter fills by the loadout rate per hit', () {
      final rig = startedRig();
      rig.walkToMonster();
      rig.input.pAtk = true;
      rig.until(() => rig.saw(BrawlEventType.hit));
      expect(rig.fight.sup, closeTo(rig.fight.lo.dis.fill, 1e-9));
    });

    test('a full meter and a press play the cinematic and spend the meter', () {
      final rig = startedRig();
      rig.fight.sup = 100;
      rig.input.pSuper = true;
      rig.step();
      expect(rig.fight.cine, isTrue);
      expect(rig.f.state, BrawlFighterState.superMove);
      expect(
        rig.of(BrawlEventType.announce).map((e) => e.cue),
        contains(BrawlCue.superMove),
      );
      rig.until(() => rig.saw(BrawlEventType.superEnd));
      expect(rig.fight.cine, isFalse);
      expect(rig.fight.sup, 0);
      expect(rig.fight.stats.supers, 1);
      final flurry = rig.of(BrawlEventType.superHit).toList();
      expect(flurry, hasLength(rig.fight.lo.dis.hits));
      expect(flurry.last.total, rig.fight.lo.dis.hits);
      expect(rig.saw(BrawlEventType.superBlast), isTrue);
      expect(rig.of(BrawlEventType.superBlast).single.shake, 13);
      final dealt = rig.fight.stats.dmg.superMove;
      expect(
        dealt,
        closeTo(rig.fight.lo.dis.total, rig.fight.lo.dis.total * 0.1),
      );
    });

    test('the fighter cannot be bumped during the Super', () {
      final rig = startedRig();
      rig.fight.sup = 100;
      rig.input.pSuper = true;
      rig.run(0.2);
      rig.fight.debugHurt(BrawlHazard.wave);
      expect(rig.fight.knockdowns, 0);
    });

    test('pressing Super before the meter is full does nothing', () {
      final rig = startedRig();
      rig.fight.sup = 80;
      rig.input.pSuper = true;
      rig.run(0.5);
      expect(rig.saw(BrawlEventType.superStart), isFalse);
    });

    test('a locked Super never fills and says so', () {
      final rig = startedRig(stats: {...mikaStats, BrawlStat.dis: 5});
      rig.walkToMonster();
      for (var i = 0; i < 30; i++) {
        rig.input.pAtk = true;
        rig.step(6);
      }
      expect(rig.fight.sup, 0);
      rig.input.pSuper = true;
      rig.run(0.3);
      expect(rig.of(BrawlEventType.locked).single.stat, BrawlStat.dis);
    });

    test('Discipline tiers fill the meter faster and hit bigger', () {
      final t1 = BrawlLoadout.fromConfig(
        testConfig(stats: {...mikaStats, BrawlStat.dis: 10}),
      );
      final t2 = BrawlLoadout.fromConfig(
        testConfig(stats: {...mikaStats, BrawlStat.dis: 40}),
      );
      final t3 = BrawlLoadout.fromConfig(
        testConfig(stats: {...mikaStats, BrawlStat.dis: 80}),
      );
      final t4 = BrawlLoadout.fromConfig(
        testConfig(stats: {...mikaStats, BrawlStat.dis: 150}),
      );
      expect(t2.dis.fill, greaterThan(t1.dis.fill));
      expect(t3.dis.total, greaterThan(t2.dis.total));
      expect(t4.dis.fill, greaterThan(t3.dis.fill));
      expect([t1.dis.hits, t3.dis.hits, t4.dis.hits], [8, 10, 12]);
    });
  });

  group('the weekly training', () {
    test('training Strength makes the slam hit harder and recharge sooner', () {
      final quiet = BrawlLoadout.fromConfig(testConfig());
      final trained = BrawlLoadout.fromConfig(
        testConfig(training: {BrawlStat.str: 8}),
      );
      expect(
        trained.slam.max / quiet.slam.max,
        closeTo(brawlAbilityBoost(brawlBoostOf(8)), 1e-9),
      );
      expect(trained.slam.cd, lessThan(quiet.slam.cd));
      expect(trained.slam.cd, greaterThanOrEqualTo(BrawlTune.cdMinSlam));
    });

    test(
      'training Intellect speeds the bolt, Social the friend, Discipline the meter',
      () {
        final quiet = BrawlLoadout.fromConfig(
          testConfig(stats: {...mikaStats, BrawlStat.soc: 20}),
        );
        final trained = BrawlLoadout.fromConfig(
          testConfig(
            stats: {...mikaStats, BrawlStat.soc: 20},
            training: {BrawlStat.intl: 6, BrawlStat.soc: 6, BrawlStat.dis: 6},
          ),
        );
        expect(trained.spell.dmg, greaterThan(quiet.spell.dmg));
        expect(trained.spell.cd, lessThan(quiet.spell.cd));
        expect(trained.friend.dmg, greaterThan(quiet.friend.dmg));
        expect(trained.friend.cd, lessThan(quiet.friend.cd));
        expect(trained.dis.fill, greaterThan(quiet.dis.fill));
        expect(trained.dis.total, greaterThan(quiet.dis.total));
      },
    );

    test('the same hit is bigger in a trained week', () {
      int jab(Map<BrawlStat, double> training) {
        final rig = startedRig(training: training, seed: 3);
        rig.walkToMonster();
        rig.input.pAtk = true;
        rig.until(() => rig.saw(BrawlEventType.hit));
        return rig.hits().first.damage;
      }

      expect(
        jab({BrawlStat.str: 10, BrawlStat.intl: 10}),
        greaterThan(jab({}) * 1.3),
      );
    });

    test('cooldown floors keep a huge week from becoming a machine gun', () {
      final lo = BrawlLoadout.fromConfig(
        testConfig(
          stats: allStats(200),
          training: allStats(200).map((k, v) => MapEntry(k, 100.0)),
        ),
      );
      expect(lo.slam.cd, BrawlTune.cdMinSlam);
      expect(lo.spell.cd, BrawlTune.cdMinSpell);
      expect(lo.friend.cd, BrawlTune.cdMinFriend);
    });
  });

  group('the monster', () {
    test('the Troll telegraphs its cushion slam about every 7 seconds', () {
      final rig = startedRig();
      rig.until(() => rig.saw(BrawlEventType.telegraph), maxSeconds: 12);
      final tele = rig.of(BrawlEventType.telegraph).single;
      expect(tele.monster, BrawlMonster.troll);
      expect(tele.duration, 1.25);
      expect(rig.fight.t, inInclusiveRange(7.0, 7.6));
      rig.until(() => rig.saw(BrawlEventType.strike), maxSeconds: 3);
      expect(rig.of(BrawlEventType.strike).single.shake, 6);
      expect(rig.fight.waves, hasLength(1));
      // Then a pause of 6 to 8 seconds plus the strike and the recovery; the
      // clock waits while the fighter is down.
      final firstStrikeAt = rig.fight.t;
      rig.until(
        () => rig.of(BrawlEventType.telegraph).length == 2,
        maxSeconds: 16,
      );
      expect(rig.fight.t - firstStrikeAt, inInclusiveRange(7.0, 12.5));
    });

    test('Easy mode gives the Troll a slower, lower wave and more warning', () {
      final rig = startedRig(easy: true);
      rig.until(() => rig.saw(BrawlEventType.telegraph), maxSeconds: 12);
      expect(rig.of(BrawlEventType.telegraph).single.duration, 1.8);
      rig.until(() => rig.fight.waves.isNotEmpty, maxSeconds: 4);
      final wave = rig.fight.waves.single;
      expect(wave.v, -105);
      expect(wave.hgt, 18);
    });

    test(
      'standing still in the wave bumps you, jumping over it is a dodge',
      () {
        final stand = startedRig();
        stand.until(() => stand.saw(BrawlEventType.hurt), maxSeconds: 14);
        final hurt = stand.of(BrawlEventType.hurt).single;
        expect(hurt.hazard, BrawlHazard.wave);
        expect(hurt.shake, 6);
        expect(hurt.hitStop, 0.07);

        final jumper = startedRig();
        jumper.until(() => jumper.fight.waves.isNotEmpty, maxSeconds: 12);
        jumper.until(
          () => jumper.fight.waves.first.x - jumper.f.x < 70,
          maxSeconds: 3,
        );
        jumper.input.pJump = true;
        jumper.run(1.2);
        expect(jumper.saw(BrawlEventType.dodge), isTrue);
        expect(jumper.saw(BrawlEventType.hurt), isFalse);
        expect(jumper.fight.perfect, isTrue);
      },
    );

    test(
      'the Fog drops marked raindrops that bump only if you stand in them',
      () {
        final stand = startedRig(monster: BrawlMonster.fog);
        stand.until(() => stand.saw(BrawlEventType.telegraph), maxSeconds: 12);
        expect(
          stand.of(BrawlEventType.telegraph).single.monster,
          BrawlMonster.fog,
        );
        expect(stand.fight.drops, hasLength(3));
        stand.until(() => stand.saw(BrawlEventType.hurt), maxSeconds: 5);
        expect(stand.of(BrawlEventType.drop), isNotEmpty);
        expect(stand.of(BrawlEventType.splash), isNotEmpty);
        expect(stand.of(BrawlEventType.hurt).first.hazard, BrawlHazard.drop);

        final easy = startedRig(monster: BrawlMonster.fog, easy: true);
        easy.until(() => easy.saw(BrawlEventType.telegraph), maxSeconds: 12);
        expect(easy.fight.drops, hasLength(2));
      },
    );

    test('the Fog drifts while it floats', () {
      final rig = startedRig(monster: BrawlMonster.fog);
      final xs = <double>[];
      for (var i = 0; i < 6; i++) {
        rig.run(1);
        xs.add(rig.fight.m.x);
      }
      expect(
        xs.reduce((a, b) => a > b ? a : b) - xs.reduce((a, b) => a < b ? a : b),
        greaterThan(10),
      );
    });

    test('the monster grows with the level', () {
      final low = testFight(level: 1);
      final high = testFight(level: 20);
      expect(high.m.scale, greaterThan(low.m.scale));
      expect(high.m.rx, greaterThan(low.m.rx));
      expect(high.m.rank, 3);
    });
  });

  group('the health calibration', () {
    test('it is deterministic, remembered and does not depend on training', () {
      brawlClearMonsterHpCache();
      final cfg = testConfig();
      final a = brawlMonsterHp(cfg);
      final b = brawlMonsterHp(cfg);
      expect(a, b);
      expect(a % 50, 0);
      final trained = createBrawlFight(
        testConfig(training: {BrawlStat.str: 10}),
      );
      final quiet = createBrawlFight(testConfig());
      final easy = createBrawlFight(testConfig(easy: true));
      expect(trained.m.hpMax, quiet.m.hpMax);
      expect(easy.m.hpMax, quiet.m.hpMax);
      expect(quiet.m.hpMax, a);
    });

    test('Mika fights a monster of about 10000 and 7500 health', () {
      expect(brawlMonsterHp(testConfig()), inInclusiveRange(9000, 12500));
      expect(
        brawlMonsterHp(testConfig(monster: BrawlMonster.fog)),
        inInclusiveRange(6500, 8500),
      );
    });

    test(
      'a stronger player meets a tougher monster, never an evaporating one',
      () {
        final lv1 = brawlMonsterHp(testConfig(level: 1, stats: allStats(10)));
        final mika = brawlMonsterHp(testConfig());
        final lv20 = brawlMonsterHp(
          testConfig(level: 20, stats: allStats(190)),
        );
        expect(lv1, greaterThan(500));
        expect(mika, greaterThan(lv1));
        expect(lv20, greaterThan(mika));
      },
    );

    test('an explicit health wins over the calibration', () {
      final f = createBrawlFight(testConfig(hpMax: 1234));
      expect(f.m.hpMax, 1234);
    });
  });

  group('FINISH IT! and the finisher', () {
    Rig dazed(BrawlMonster monster, {bool easy = false}) {
      final rig = startedRig(monster: monster, easy: easy, hpMax: 5000);
      rig.walkToMonster();
      rig.fight.m.hp = rig.fight.m.hpMax * BrawlTune.dazeAt + 20;
      rig.input.pAtk = true;
      rig.until(() => rig.fight.phase == BrawlPhase.daze, maxSeconds: 6);
      return rig;
    }

    test(
      'the last slice of health is the finisher\'s: the monster is dazed',
      () {
        final rig = dazed(BrawlMonster.troll);
        expect(rig.fight.phase, BrawlPhase.daze);
        expect(rig.fight.m.state, BrawlMonsterState.daze);
        expect(rig.fight.m.hp, closeTo(5000 * BrawlTune.dazeAt, 1e-9));
        expect(rig.saw(BrawlEventType.daze), isTrue);
        expect(
          rig.of(BrawlEventType.announce).map((e) => e.cue),
          contains(BrawlCue.finishIt),
        );
        expect(BrawlCue.finishIt.text, 'FINISH IT!');
        final n = rig.hits().length;
        rig.input.attackHeld = false;
        rig.run(0.2);
        expect(
          rig.hits().length,
          n,
          reason: 'a dazed monster cannot be hit again',
        );
      },
    );

    test('the Troll\'s move stops when it is dazed', () {
      final rig = startedRig(hpMax: 5000);
      rig.until(() => rig.fight.waves.isNotEmpty, maxSeconds: 12);
      rig.walkToMonster();
      rig.fight.m.hp = rig.fight.m.hpMax * BrawlTune.dazeAt + 5;
      rig.input.pAtk = true;
      rig.until(() => rig.fight.phase == BrawlPhase.daze, maxSeconds: 6);
      expect(rig.fight.waves, isEmpty);
      expect(rig.fight.drops, isEmpty);
    });

    test('tapping FINISH IT! tucks the Troll in for a nap', () {
      final rig = dazed(BrawlMonster.troll);
      final tap = rig.fight.t;
      rig.input.pFinish = true;
      rig.until(() => rig.fight.phase == BrawlPhase.finisher, maxSeconds: 2);
      expect(rig.fight.phase, BrawlPhase.finisher);
      expect(rig.fight.finishTime, closeTo(tap, 0.5));
      rig.until(() => rig.fight.isDone, maxSeconds: 20);
      final order = rig.log
          .map((e) => e.type)
          .where(
            (t) => const {
              BrawlEventType.finishStart,
              BrawlEventType.finBlanket,
              BrawlEventType.finTuck,
              BrawlEventType.finSnore,
              BrawlEventType.ko,
              BrawlEventType.perfect,
              BrawlEventType.victory,
            }.contains(t),
          )
          .toList();
      expect(order, [
        BrawlEventType.finishStart,
        BrawlEventType.finBlanket,
        BrawlEventType.finTuck,
        BrawlEventType.finSnore,
        BrawlEventType.ko,
        BrawlEventType.perfect,
        BrawlEventType.victory,
      ]);
      expect(rig.fight.m.hp, 0);
      expect(rig.fight.timeScale, 1);
      expect(
        rig.of(BrawlEventType.announce).map((e) => e.cue).toList(),
        containsAllInOrder([
          BrawlCue.round1,
          BrawlCue.fight,
          BrawlCue.finishIt,
          BrawlCue.ko,
          BrawlCue.perfect,
        ]),
      );
    });

    test(
      'tapping FINISH IT! blows the Fog into a little cloud that waters a plant',
      () {
        final rig = dazed(BrawlMonster.fog);
        rig.input.pFinish = true;
        rig.until(() => rig.fight.phase == BrawlPhase.finisher, maxSeconds: 2);
        expect(rig.fight.phase, BrawlPhase.finisher);
        rig.until(() => rig.fight.isDone, maxSeconds: 20);
        final order = rig.log
            .map((e) => e.type)
            .where(
              (t) => const {
                BrawlEventType.finBlow,
                BrawlEventType.finCloud,
                BrawlEventType.finWater,
                BrawlEventType.ko,
                BrawlEventType.victory,
              }.contains(t),
            )
            .toList();
        expect(order, [
          BrawlEventType.finBlow,
          BrawlEventType.finCloud,
          BrawlEventType.finWater,
          BrawlEventType.ko,
          BrawlEventType.victory,
        ]);
      },
    );

    test('the finisher eases into slow motion and back out', () {
      final rig = dazed(BrawlMonster.troll);
      rig.input.pFinish = true;
      var slowest = 1.0;
      for (var i = 0; i < 2000 && !rig.fight.isDone; i++) {
        rig.step();
        if (rig.fight.timeScale < slowest) slowest = rig.fight.timeScale;
      }
      expect(slowest, closeTo(0.4, 1e-9));
      expect(rig.fight.timeScale, 1);
    });

    test('no PERFECT if you were ever bumped', () {
      final rig = dazed(BrawlMonster.troll);
      rig.fight.perfect = false;
      rig.input.pFinish = true;
      rig.until(() => rig.fight.isDone, maxSeconds: 20);
      expect(rig.saw(BrawlEventType.ko), isTrue);
      expect(rig.saw(BrawlEventType.perfect), isFalse);
    });

    test('if nobody taps, the finisher starts by itself (Easy waits less)', () {
      final std = dazed(BrawlMonster.troll);
      std.input.pAtk = false;
      std.input.attackHeld = false;
      std.run(6.0);
      expect(std.fight.phase, BrawlPhase.daze);
      std.run(2.0);
      expect(std.fight.phase, isNot(BrawlPhase.daze));
      final easy = dazed(BrawlMonster.troll, easy: true);
      easy.run(3.2);
      expect(easy.fight.phase, isNot(BrawlPhase.daze));
    });

    test('the Super during a daze does nothing to a dazed monster', () {
      final rig = dazed(BrawlMonster.troll);
      final hp = rig.fight.m.hp;
      rig.fight.sup = 100;
      rig.input.pSuper = true;
      rig.run(1.5);
      expect(rig.fight.m.hp, hp);
    });
  });

  group('the victory', () {
    BrawlFight finished({
      BrawlMonster monster = BrawlMonster.troll,
      Map<BrawlStat, double> training = const {},
      int seed = 2,
    }) {
      final g = createBrawlFight(
        testConfig(
          monster: monster,
          training: training,
          seed: seed,
          hpMax: 4000,
        ),
      );
      return playBrawlWithBot(g, botSeed: seed, untilDone: true);
    }

    test(
      'a fight ends with a time, a chest, loot and a breakdown by source',
      () {
        final g = finished(training: {BrawlStat.str: 4, BrawlStat.intl: 2});
        expect(g.phase, BrawlPhase.done);
        final r = BrawlResult.of(g);
        expect(r.seconds, g.finishTime);
        expect(r.seconds, greaterThan(3));
        expect(r.chest, brawlChestFor(r.seconds));
        expect(r.loot, BrawlMonster.troll.def.loot[r.chest]);
        expect(r.finisherLine, 'You tucked the Couch Troll in for a nap.');
        expect(r.monster, BrawlMonster.troll);
        final total = r.rows.fold<double>(0, (a, e) => a + e.percent);
        expect(total, closeTo(100, 1e-6));
        for (var i = 1; i < r.rows.length; i++) {
          expect(
            r.rows[i - 1].percent,
            greaterThanOrEqualTo(r.rows[i].percent),
          );
        }
        final finisher = r.rows.singleWhere(
          (e) => e.source == BrawlDamageSource.finisher,
        );
        expect(finisher.stat, isNull);
        expect(finisher.damage, closeTo(4000 * BrawlTune.dazeAt, 1e-9));
        final slam = r.rows.where((e) => e.source == BrawlDamageSource.slam);
        if (slam.isNotEmpty) {
          expect(slam.single.stat, BrawlStat.str);
          expect(slam.single.trainedPoints, 4);
        }
        final spell = r.rows.where((e) => e.source == BrawlDamageSource.spell);
        if (spell.isNotEmpty) expect(spell.single.trainedPoints, 2);
        final fist = r.rows.singleWhere(
          (e) => e.source == BrawlDamageSource.fist,
        );
        expect(fist.trainedPoints, 0);
        expect(r.maxCombo, g.stats.maxCombo);
        expect(r.knockdowns, g.knockdowns);
      },
    );

    test('rows that did no damage are left out', () {
      final g = finished();
      final r = BrawlResult.of(g);
      expect(
        r.rows.where((e) => e.source == BrawlDamageSource.friend),
        isEmpty,
        reason: 'Mika has Social 5, so no friend ever came',
      );
    });

    test('a Fog fight reads the Fog\'s loot and line', () {
      final g = finished(monster: BrawlMonster.fog);
      final r = BrawlResult.of(g);
      expect(BrawlMonster.fog.def.loot.values, contains(r.loot));
      expect(r.finisherLine, startsWith('You blew the Fog'));
    });
  });

  group('determinism', () {
    test('the same seed plays out the same, a different seed does not', () {
      List<Object> run(int seed) {
        final g = createBrawlFight(testConfig(seed: seed, hpMax: 6000));
        playBrawlWithBot(g, botSeed: seed);
        return [
          g.finishTime,
          g.stats.hits,
          g.stats.crits,
          g.stats.maxCombo,
          g.m.hp,
        ];
      }

      expect(run(4), run(4));
      expect(run(4), isNot(run(5)));
    });

    test('events come out the same for the same seed', () {
      List<String> events(int seed) {
        final g = createBrawlFight(testConfig(seed: seed, hpMax: 3000));
        final bot = BrawlBot(g, seed: seed);
        final out = <String>[];
        while (g.phase != BrawlPhase.done && g.clock < 200) {
          bot.drive();
          g.step(BrawlTune.step, bot.input);
          for (final e in g.drainEvents()) {
            out.add('${e.type.name}:${e.damage}:${e.crit}:${e.combo}');
          }
        }
        return out;
      }

      expect(events(9), events(9));
      expect(events(9).length, greaterThan(100));
    });

    test('a bot that never dodges still finishes: nobody loses', () {
      for (var seed = 1; seed <= 5; seed++) {
        final g = createBrawlFight(
          testConfig(
            seed: seed,
            hpMax: 5000,
            monster: seed.isEven ? BrawlMonster.fog : BrawlMonster.troll,
          ),
        );
        final bot = BrawlBot(g, seed: seed, dodgeP: 0);
        while (g.phase != BrawlPhase.done && g.clock < 200) {
          bot.drive();
          g.step(BrawlTune.step, bot.input);
          g.events.clear();
          expect(g.f.hp, greaterThan(0));
        }
        expect(g.phase, BrawlPhase.done, reason: 'seed $seed');
      }
    });
  });
}
