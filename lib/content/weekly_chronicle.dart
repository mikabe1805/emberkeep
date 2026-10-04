import '../clock.dart';
import '../engine.dart';
import '../models.dart';
import '../tokens.dart';
import 'class_lines.dart';

class WeeklyChronicleData {
  const WeeklyChronicleData({
    required this.start,
    required this.end,
    required this.counts,
    required this.litDays,
    required this.total,
    required this.delta,
    required this.strongestDomain,
    this.classCounts = const [0, 0, 0, 0, 0, 0, 0],
    this.reflection,
  });

  final DateTime start;
  final DateTime end;

  /// Quests completed on each day, Monday first.
  final List<int> counts;

  /// Days that held a Quest or a kept class.
  final int litDays;

  /// Quests completed this week.
  final int total;

  /// Quests against the week before.
  final int delta;
  final Stat? strongestDomain;

  /// Classes kept on each day, Monday first. A class day lights the week the
  /// same way a Quest day does.
  final List<int> classCounts;
  final Note? reflection;

  int get classesKept => classCounts.fold(0, (sum, n) => sum + n);

  int get classDays => classCounts.where((n) => n > 0).length;

  /// Whether a day held anything: a Quest or a kept class.
  bool litOn(int index) => counts[index] > 0 || classCounts[index] > 0;

  int get brightestDayCount => counts.fold(0, (best, n) => n > best ? n : best);

  int? get brightestDayIndex {
    final best = brightestDayCount;
    if (best == 0) return null;
    return counts.indexOf(best);
  }

  String get rangeLabel =>
      '${_month(start.month)} ${start.day} – ${_month(end.month)} ${end.day}';

  /// The week's one-line title.
  String get headline {
    if (total > 0) {
      return '$total ${total == 1 ? 'quest' : 'quests'} became progress';
    }
    if (classesKept > 0) return '${classCountLabel(classesKept)} kept';
    return 'A quiet chapter';
  }

  /// What sits beside "N OF 7 DAYS ACTIVE". A week of classes never reads
  /// as quiet; the Quest comparison only speaks when it has news.
  String get deltaLine {
    final parts = <String>[
      if (total > 0 && classesKept > 0) '${classCountLabel(classesKept)} kept',
      if (delta > 0)
        '$delta more ${delta == 1 ? 'quest' : 'quests'} than the week before',
    ];
    if (parts.isNotEmpty || classesKept > 0) return parts.join(' · ');
    if (delta < 0) return 'a quieter week, and still part of the story';
    return 'steady with the week before';
  }

  String get shareText {
    final quests = '$total ${total == 1 ? 'quest' : 'quests'}';
    if (classesKept == 0) {
      return 'I showed up on $litDays of 7 days and completed $quests this week.';
    }
    final classes = classCountLabel(classesKept);
    if (total == 0) {
      return 'I showed up on $litDays of 7 days and kept $classes this week.';
    }
    return 'I showed up on $litDays of 7 days, kept $classes and completed '
        '$quests this week.';
  }
}

WeeklyChronicleData weeklyChronicleFor(
  GameState state, {
  DateTime? now,
  bool previousWeek = true,
}) {
  final anchor = now ?? Clock.now();
  final thisMonday = Days.weekStart(anchor);
  final start = previousWeek
      ? thisMonday.subtract(const Duration(days: 7))
      : thisMonday;
  final end = start.add(const Duration(days: 6));
  final counts = <int>[
    for (var i = 0; i < 7; i++)
      state.history[Days.key(start.add(Duration(days: i)))] ?? 0,
  ];
  final priorStart = start.subtract(const Duration(days: 7));
  var priorTotal = 0;
  for (var i = 0; i < 7; i++) {
    priorTotal +=
        state.history[Days.key(priorStart.add(Duration(days: i)))] ?? 0;
  }
  final classCounts = <int>[
    for (var i = 0; i < 7; i++)
      state.classesKeptOn(Days.key(start.add(Duration(days: i)))).length,
  ];
  final total = counts.fold(0, (sum, n) => sum + n);
  final notes =
      state.journal
          .where(
            (n) =>
                !n.at.isBefore(start) &&
                n.at.isBefore(end.add(const Duration(days: 1))),
          )
          .toList()
        ..sort((a, b) => b.at.compareTo(a.at));
  return WeeklyChronicleData(
    start: start,
    end: end,
    counts: counts,
    litDays: [
      for (var i = 0; i < 7; i++)
        if (counts[i] > 0 || classCounts[i] > 0) i,
    ].length,
    total: total,
    delta: total - priorTotal,
    strongestDomain: state.dominantStat,
    classCounts: classCounts,
    reflection: notes.firstOrNull,
  );
}

String chronicleExcerpt(String text, {int max = 105}) {
  final clean = text.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (clean.length <= max) return clean;
  final clipped = clean.substring(0, max);
  final space = clipped.lastIndexOf(' ');
  return '${clipped.substring(0, space > max * 0.65 ? space : max).trim()}…';
}

String _month(int month) => const [
  'JAN',
  'FEB',
  'MAR',
  'APR',
  'MAY',
  'JUN',
  'JUL',
  'AUG',
  'SEP',
  'OCT',
  'NOV',
  'DEC',
][month - 1];
