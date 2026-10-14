// The weekend brawl's door and what it leaves behind.
//
// The fight opens on Saturday and Sunday. A week's first win earns one chest
// and one piece of loot for the house; every fight after it that weekend is
// practice, with no chest. This file holds the dates and the saved record, as
// pure Dart (no widgets, no engine): the Doorway, the board, the fight and the
// Me trophy case all read the same answers from here.
library;

import 'package:flutter/foundation.dart' show visibleForTesting;

import '../models.dart' show Days;
import 'core/brawl_monsters.dart' show BrawlChest, BrawlMonster;
import 'weekly_training.dart' show trainingWeekStart, trainingWeekStartHour;

/// A test and render seam: opens the fight on any day. Nothing in the app
/// sets it, and no screen shows it.
abstract final class BrawlDebug {
  @visibleForTesting
  static bool openAnyDay = false;

  /// A fixed seed for every fight, so a render or a test plays the same one.
  @visibleForTesting
  static int? seed;
}

/// The day the app counts [now] in: the small hours after midnight still
/// belong to the day before, as everywhere else in the app (a night owl's
/// Saturday starts at 04:00).
DateTime brawlDay(DateTime now) => now.hour < trainingWeekStartHour
    ? DateTime(now.year, now.month, now.day - 1)
    : DateTime(now.year, now.month, now.day);

/// Whether [now] is Saturday or Sunday.
bool isBrawlWeekend(DateTime now) => brawlDay(now).weekday >= DateTime.saturday;

/// Whether the door to the fight is lit at [now].
bool brawlDoorOpen(DateTime now) =>
    isBrawlWeekend(now) || BrawlDebug.openAnyDay;

/// The week [now] belongs to, named by its Monday ("2026-10-05").
String brawlWeekKey(DateTime now) => Days.key(trainingWeekStart(now));

/// The most loot the save keeps (two years of weekends).
const int brawlLootCap = 104;

/// One chest earned and one piece of loot kept, for one weekend.
class BrawlLoot {
  const BrawlLoot({
    required this.week,
    required this.monster,
    required this.chest,
    required this.loot,
    required this.seconds,
    required this.at,
  });

  /// The week's key (its Monday), so one weekend earns one piece.
  final String week;

  /// The monster beaten ('troll' or 'fog').
  final BrawlMonster monster;
  final BrawlChest chest;

  /// The piece for the house ("Porch Lantern").
  final String loot;

  /// How long the fight took, in seconds.
  final double seconds;

  /// When it was won.
  final DateTime at;

  /// "Swift chest".
  String get chestName => switch (chest) {
    BrawlChest.swift => 'Swift chest',
    BrawlChest.steady => 'Steady chest',
    BrawlChest.patient => 'Patient chest',
  };

  Map<String, Object> toJson() => {
    'w': week,
    'm': monster.key,
    'c': chest.name,
    'l': loot,
    's': (seconds * 10).round() / 10,
    't': at.millisecondsSinceEpoch,
  };

  /// A damaged entry reads as null and is left out, so one bad record never
  /// costs the rest of the case.
  static BrawlLoot? tryFromJson(Object? raw) {
    if (raw is! Map) return null;
    final week = Days.validKey(raw['w']);
    final monster = BrawlMonster.fromKey(raw['m'] as String?);
    final loot = raw['l'];
    final at = raw['t'];
    BrawlChest? chest;
    for (final c in BrawlChest.values) {
      if (c.name == raw['c']) chest = c;
    }
    if (week == null ||
        monster == null ||
        chest == null ||
        loot is! String ||
        loot.isEmpty ||
        at is! num) {
      return null;
    }
    final s = raw['s'];
    return BrawlLoot(
      week: week,
      monster: monster,
      chest: chest,
      loot: loot,
      seconds: s is num ? s.toDouble() : 0,
      at: DateTime.fromMillisecondsSinceEpoch(at.toInt()),
    );
  }
}
