import '../tokens.dart';
import 'stat_ranks.dart';

/// Build titles — your top two stats name you. Silly but earnest: the
/// identity layer that makes a build personal and shareable.
abstract final class BuildTitles {
  // Keys are <stat.name>+<stat.name> in enum order (str<vit<intl<foc<soc<dis).
  // str=Strength vit=Vitality intl=Intellect foc=Focus soc=Social
  // dis=Discipline.
  static const _pairs = <String, String>{
    'str+vit': 'LIONHEART', // Strength + Vitality
    'str+intl': 'WARRIOR SCHOLAR', // Strength + Intellect
    'str+foc': 'SILENT HAMMER', // Strength + Focus
    'str+soc': 'GENTLE GIANT', // Strength + Social
    'str+dis': 'HOMESTEADER', // Strength + Discipline
    'vit+intl': 'CLEAR SPRING', // Vitality + Intellect
    'vit+foc': 'STEADY HAND', // Vitality + Focus
    'vit+soc': 'SUNSHINE SOUL', // Vitality + Social
    'vit+dis': 'EVERGREEN', // Vitality + Discipline
    'intl+foc': 'DEEP CURRENT', // Intellect + Focus
    'intl+soc': 'STORYTELLER', // Intellect + Social
    'intl+dis': 'QUIET MASTER', // Intellect + Discipline
    'foc+soc': 'PRESENT HEART', // Focus + Social
    'foc+dis': 'UNSHAKEABLE', // Focus + Discipline
    'soc+dis': 'OPEN HOUSE', // Social + Discipline
  };

  static const _solo = <Stat, String>{
    Stat.str: 'BRAWLER', // Strength
    Stat.vit: 'WELLSPRING', // Vitality
    Stat.intl: 'SCHOLAR', // Intellect
    Stat.foc: 'MAKER', // Focus
    Stat.soc: 'FRIEND', // Social
    Stat.dis: 'KEEPER', // Discipline
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
