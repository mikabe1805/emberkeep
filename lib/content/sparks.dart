import '../tokens.dart';

/// "Today's Spark" — one warm line that greets you on the first open each day,
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
        'Your legend starts at zero. Light the first ember and the day tilts your way.');
  }
  if (returning && streakDays == 0) {
    relevant.add(
        'Welcome back — the hearth’s still warm. One small quest and you’re moving again.');
  }
  if (streakDays >= 3) {
    relevant.add('Day $streakDays of your streak. The fire’s well and truly caught.');
  }
  if (perfectDays >= 1) {
    relevant.add(
        'You’ve cleared the whole board ${perfectDays == 1 ? "once" : "$perfectDays times"} — you know how this goes.');
  }
  if (nearGoalTitle != null && nearGoalGap > 0) {
    relevant.add(
        '“$nearGoalTitle” is $nearGoalGap quest${nearGoalGap == 1 ? "" : "s"} from a milestone. Could be today.');
  }
  if (dominant != null) {
    relevant.add(
        'Your ${dominant.label} is leading the build — feed it, or surprise yourself with something else.');
  }
  if (evidenceTitle != null) {
    relevant.add(
        'A thought for today: ${_lower(evidenceTitle)}. (The why’s waiting in Sparks.)');
  }

  const generic = [
    'One quest before you overthink it. That’s the whole trick.',
    'You don’t have to feel ready — you just need one small win before noon.',
    'New day, fresh XP on the table. Start absurdly small.',
    'Whatever today holds, the smallest ember still counts. Begin there.',
  ];

  final pool = relevant.isNotEmpty ? relevant : generic;
  return pool[dayKey.hashCode.abs() % pool.length];
}

String _lower(String s) => s.isEmpty ? s : s[0].toLowerCase() + s.substring(1);
