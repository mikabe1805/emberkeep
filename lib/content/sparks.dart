import '../tokens.dart';

/// One warm note that greets you on the first open each day,
/// keyed to YOUR live state so it reads personal, not fortune-cookie (scout
/// pick #1). Deterministic per day (stable all day), rotating among the lines
/// that actually apply to you; a few gentle generics ensure there's always one.
String dailySpark({
  required String dayKey,
  required int streakDays,
  required int perfectDays,
  required int totalXp,
  required bool returning,
  Stat? dominant,
  String? nearGoalTitle,
  int nearGoalGap = 0,
  String? evidenceTitle,
}) {
  final relevant = <String>[];

  if (totalXp == 0) {
    relevant.add(
      'Your legend starts at zero. Choose one next step and the day tilts your way.',
    );
  }
  if (returning && streakDays == 0) {
    relevant.add(
      'Welcome back. Your progress is right where you left it, and one small quest gets you moving again.',
    );
  }
  if (streakDays >= 3) {
    relevant.add(
      'Day $streakDays of your streak. Your rhythm is finding its feet.',
    );
  }
  if (perfectDays >= 1) {
    relevant.add(
      'You’ve cleared the whole board ${perfectDays == 1 ? "once" : "$perfectDays times"}. You know how this goes.',
    );
  }
  if (nearGoalTitle != null && nearGoalGap > 0) {
    relevant.add(
      '“$nearGoalTitle” is $nearGoalGap quest${nearGoalGap == 1 ? "" : "s"} from a milestone. Could be today.',
    );
  }
  if (dominant != null) {
    relevant.add(
      'Your ${dominant.label} is leading the build. Feed it, or surprise yourself with something else.',
    );
  }
  if (evidenceTitle != null) {
    relevant.add(
      'A thought for today: ${_lower(evidenceTitle)}. (Tap a +stat bubble to read why.)',
    );
  }

  const generic = [
    'One quest before you overthink it. That’s the whole trick.',
    'Feeling ready is optional. One small win is enough to start.',
    'New day, fresh XP on the table. Start absurdly small.',
    'Whatever today holds, the smallest step still counts. Begin there.',
  ];

  final pool = relevant.isNotEmpty ? relevant : generic;
  return pool[dayKey.hashCode.abs() % pool.length];
}

String _lower(String s) => s.isEmpty ? s : s[0].toLowerCase() + s.substring(1);
