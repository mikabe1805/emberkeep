import '../tokens.dart';
import 'stat_ranks.dart';

/// Build titles — your top two stats name you. Silly but earnest: the
/// identity layer that makes a build personal and shareable.
abstract final class BuildTitles {
  static const _pairs = <String, String>{
    'str+vit': 'IRONBLOOD',
    'str+intl': 'WARRIOR SCHOLAR',
    'str+foc': 'SILENT HAMMER',
    'str+soc': 'GENTLE GIANT',
    'str+dis': 'FORGED WILL',
    'vit+intl': 'CLEAR SPRING',
    'vit+foc': 'STEADY FLAME',
    'vit+soc': 'SUNSHINE SOUL',
    'vit+dis': 'EVERGREEN',
    'intl+foc': 'DEEP CURRENT',
    'intl+soc': 'STORYTELLER',
    'intl+dis': 'QUIET MASTER',
    'foc+soc': 'PRESENT HEART',
    'foc+dis': 'UNSHAKEABLE',
    'soc+dis': 'KEPT PROMISE',
  };

  static const _solo = <Stat, String>{
    Stat.str: 'BRAWLER',
    Stat.vit: 'WELLSPRING',
    Stat.intl: 'SCHOLAR',
    Stat.foc: 'MONK',
    Stat.soc: 'FRIEND',
    Stat.dis: 'KEEPER',
  };

  /// Title for a stat spread. Needs two stats trained to earn a pair title;
  /// one trained stat earns its solo title; zero = a hopeful blank slate.
  static String of(Map<Stat, int> stats) {
    final trained = stats.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (trained.isEmpty) return 'BLANK SLATE';
    if (trained.length == 1 ||
        (trained.length > 1 && trained[1].value * 3 < trained[0].value)) {
      // one stat towers over the rest → solo identity
      return _solo[trained[0].key]!;
    }
    final a = trained[0].key;
    final b = trained[1].key;
    return _pairs['${a.name}+${b.name}'] ?? _pairs['${b.name}+${a.name}']!;
  }

  /// The title, grown into an EPITHET: once your top stat reaches a real rank
  /// (tier ≥ 3 — Strong / Astute / Beloved / …), it prefixes the name, so your
  /// title visibly records how far you've come (scout pick #5: MIGHTY
  /// IRONBLOOD). Below that, just the base name — never a "weak"-sounding word.
  static String epithetOf(Map<Stat, int> stats) {
    final base = of(stats);
    Stat? top;
    var topV = 0;
    for (final e in stats.entries) {
      if (e.value > topV) {
        topV = e.value;
        top = e.key;
      }
    }
    if (top == null) return base;
    final rank = rankFor(top, topV);
    if (rank.tier < 3) return base;
    return '${rank.label.toUpperCase()} $base';
  }
}
