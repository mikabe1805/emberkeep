import '../engine.dart';
import '../models.dart';
import '../tokens.dart';

class WeeklyChronicleData {
  const WeeklyChronicleData({
    required this.start,
    required this.end,
    required this.counts,
    required this.litDays,
    required this.total,
    required this.delta,
    required this.strongestDomain,
    this.reflection,
  });

  final DateTime start;
  final DateTime end;
  final List<int> counts;
  final int litDays;
  final int total;
  final int delta;
  final Stat? strongestDomain;
  final Note? reflection;

  int get brightestDayCount => counts.fold(0, (best, n) => n > best ? n : best);

  int? get brightestDayIndex {
    final best = brightestDayCount;
    if (best == 0) return null;
    return counts.indexOf(best);
  }

  String get rangeLabel =>
      '${_month(start.month)} ${start.day} — ${_month(end.month)} ${end.day}';

  String get deltaLine {
    if (delta > 0) return '$delta more quests than the week before';
    if (delta < 0) return 'a quieter week — still part of the story';
    return 'steady with the week before';
  }

  String get shareText =>
      'I showed up on $litDays of 7 days and completed $total '
      '${total == 1 ? 'quest' : 'quests'} this week.';
}

WeeklyChronicleData weeklyChronicleFor(
  GameState state, {
  DateTime? now,
  bool previousWeek = true,
}) {
  final anchor = now ?? DateTime.now();
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
    litDays: counts.where((n) => n > 0).length,
    total: total,
    delta: total - priorTotal,
    strongestDomain: state.dominantStat,
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
