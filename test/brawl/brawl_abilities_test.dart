// The six abilities: names, the tier thresholds, and the lines the Me page and
// the versus screen read. Pure functions, no clock.
import 'package:emberkeep/brawl/brawl_abilities.dart';
import 'package:emberkeep/tokens.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('every stat is an ability', () {
    test('the six names are the contract', () {
      expect(
        {for (final s in Stat.values) s: abilityOf(s).name},
        {
          Stat.str: 'Power Slam',
          Stat.intl: 'Spell Bolt',
          Stat.soc: 'Call a Friend',
          Stat.foc: 'Focus',
          Stat.vit: 'Second Wind',
          Stat.dis: 'Super',
        },
      );
    });

    test('each has a plain line and a perk for every tier', () {
      for (final stat in Stat.values) {
        final ability = abilityOf(stat);
        expect(ability.stat, stat);
        expect(ability.blurb, isNotEmpty);
        expect(ability.perks, hasLength(abilityTopTier));
        for (var tier = 1; tier <= abilityTopTier; tier++) {
          expect(ability.perk(tier), isNotEmpty, reason: '$stat tier $tier');
        }
        // A tier outside 1 to 4 reads the nearest one.
        expect(ability.perk(0), ability.perk(1));
        expect(ability.perk(9), ability.perk(abilityTopTier));
      }
    });

    test('no copy says a loss word, uses an em dash, or scolds', () {
      final words = <String>[];
      for (final stat in Stat.values) {
        final ability = abilityOf(stat);
        words
          ..add(ability.name)
          ..add(ability.blurb)
          ..addAll(ability.perks)
          ..add(lockedLine(stat))
          ..add(nextLine(stat, 0))
          ..add(nextLineWithPerk(stat, 12))
          ..add(abilitySpoken(stat, 0))
          ..add(abilitySpoken(stat, 500));
      }
      final text = words.join(' ').toLowerCase();
      for (final bad in [
        'failed',
        'missed',
        'lost',
        'broke',
        'behind',
        'overdue',
        '—',
      ]) {
        expect(text.contains(bad), isFalse, reason: bad);
      }
    });
  });

  group('tiers', () {
    test('locked below 10, then 10, 40, 80 and 150', () {
      expect(abilityTierAt, [10, 40, 80, 150]);
      expect(
        [
          for (final v in [0, 5, 9]) tierOf(v),
        ],
        [0, 0, 0],
      );
      expect(
        [
          for (final v in [10, 11, 39]) tierOf(v),
        ],
        [1, 1, 1],
      );
      expect(
        [
          for (final v in [40, 41, 79]) tierOf(v),
        ],
        [2, 2, 2],
      );
      expect(
        [
          for (final v in [80, 81, 149]) tierOf(v),
        ],
        [3, 3, 3],
      );
      expect(
        [
          for (final v in [150, 151, 9999]) tierOf(v),
        ],
        [4, 4, 4],
      );
    });

    test('a negative or empty value is simply locked', () {
      expect(tierOf(-3), 0);
      expect(isLocked(-3), isTrue);
      expect(isLocked(9), isTrue);
      expect(isLocked(10), isFalse);
    });

    test('the next tier is the next threshold, and null at the top', () {
      expect(nextTierAt(0), 10);
      expect(nextTierAt(9), 10);
      expect(nextTierAt(10), 40);
      expect(nextTierAt(39), 40);
      expect(nextTierAt(40), 80);
      expect(nextTierAt(80), 150);
      expect(nextTierAt(149), 150);
      expect(nextTierAt(150), isNull);
      expect(nextTierAt(400), isNull);
    });

    test('progress to the next tier runs from the last threshold', () {
      expect(tierProgress(0), 0);
      expect(tierProgress(5), closeTo(0.5, 1e-9));
      expect(tierProgress(10), 0);
      expect(tierProgress(25), closeTo(0.5, 1e-9));
      expect(tierProgress(40), 0);
      expect(tierProgress(115), closeTo(0.5, 1e-9));
      expect(tierProgress(150), 1);
      expect(tierProgress(900), 1);
    });
  });

  group('the lines', () {
    test('a locked ability is an aspiration, in the contract words', () {
      expect(lockedLine(Stat.soc), 'Reach Social 10 to unlock Call a Friend');
      expect(lockedLine(Stat.str), 'Reach Strength 10 to unlock Power Slam');
      expect(lockedLine(Stat.dis), 'Reach Discipline 10 to unlock Super');
      expect(nextLine(Stat.soc, 5), lockedLine(Stat.soc));
    });

    test('an unlocked ability says where it goes next', () {
      expect(nextLine(Stat.str, 54), 'Tier 3 at 80');
      expect(nextLine(Stat.str, 10), 'Tier 2 at 40');
      expect(nextLine(Stat.str, 79), 'Tier 3 at 80');
      expect(nextLine(Stat.dis, 110), 'Tier 4 at 150');
      expect(nextLine(Stat.vit, 150), 'Top tier');
      expect(nextLineWithPerk(Stat.str, 54), 'Tier 3 at 80: a bigger slam');
      expect(nextLineWithPerk(Stat.str, 150), 'Top tier');
      expect(nextLineWithPerk(Stat.soc, 2), lockedLine(Stat.soc));
    });

    test('tier names and the spoken line', () {
      expect(tierName(0), 'Locked');
      expect(tierName(3), 'Tier 3');
      expect(abilitySpoken(Stat.str, 54), 'Power Slam, tier 2. Tier 3 at 80.');
      expect(
        abilitySpoken(Stat.soc, 5),
        'Reach Social 10 to unlock Call a Friend.',
      );
    });
  });

  group('the six stats carry their new names', () {
    test('labels, abbreviations and the keys that stay', () {
      expect(
        [for (final s in Stat.values) s.label],
        ['Strength', 'Vitality', 'Intellect', 'Focus', 'Social', 'Discipline'],
      );
      expect(
        [for (final s in Stat.values) s.abbr],
        ['STR', 'VIT', 'INT', 'FOC', 'SOC', 'DIS'],
      );
      // The serialized order and names are the save format.
      expect(
        [for (final s in Stat.values) s.name],
        ['str', 'vit', 'intl', 'foc', 'soc', 'dis'],
      );
    });

    test('six different icons and six different hues', () {
      expect({for (final s in Stat.values) s.icon.codePoint}, hasLength(6));
      expect({for (final s in Stat.values) s.color}, hasLength(6));
    });

    test('each description is specific and says its own examples', () {
      expect(Stat.str.examples, contains('push-ups'));
      expect(Stat.str.examples, contains('lifting'));
      expect(Stat.vit.examples, contains('walks'));
      expect(Stat.vit.examples, contains('sleep'));
      expect(Stat.intl.examples, contains('reading'));
      expect(Stat.foc.examples, contains('deep work'));
      expect(Stat.soc.examples, contains('reaching out'));
      expect(Stat.dis.examples, contains('chores'));
      expect(Stat.dis.examples, contains('put off'));
    });
  });
}
