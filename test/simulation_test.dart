// Multi-day case-study simulations driven by a frozen Clock. These verify
// the reliability-critical time logic — streaks, daily/weekly/monthly
// resets, rising difficulty, goal progress, persistence round-trips —
// across real day boundaries, deterministically.
import 'dart:convert';

import 'package:emberkeep/clock.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/tokens.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DateTime today; // mutable "now", advanced day by day
  setUp(() => Clock.use(() => today));
  tearDown(Clock.reset);

  // helper: complete a quest end to end (roll marks done + commits rewards)
  void complete(GameState s, Quest q) => s.commit(s.roll(q));

  test('a week of Aria — streak builds, dailies reset, a gap resets it', () {
    today = DateTime(2026, 6, 15, 9, 0); // Monday
    final s = GameState();
    final pushups = Quest(title: 'Push-ups', stat: Stat.str, difficulty: 2);
    final read = Quest(title: 'Read', stat: Stat.intl, difficulty: 3);
    final quests = [pushups, read];

    // Mon
    s.rollover(quests);
    complete(s, pushups);
    complete(s, read);
    expect(s.streakDays, 1);
    expect(pushups.doneFor(today), isTrue);
    expect(s.history[Days.key(today)], 2);

    // Tue–Thu: dailies reset each morning, streak climbs
    for (var d = 2; d <= 4; d++) {
      today = today.add(const Duration(days: 1));
      s.rollover(quests);
      expect(pushups.doneFor(today), isFalse, reason: 'daily resets day $d');
      complete(s, pushups);
      complete(s, read);
      expect(s.streakDays, d);
    }

    // Fri: SKIPPED (no completions)
    today = today.add(const Duration(days: 1));
    s.rollover(quests);

    // Sat: completing after a missed day resets the streak to 1
    today = today.add(const Duration(days: 1));
    s.rollover(quests);
    complete(s, pushups);
    expect(s.streakDays, 1, reason: 'a gap breaks the streak');
    expect(s.comebacks, 1, reason: 'returning after a gap is a comeback');
    expect(s.bestStreak, 4, reason: 'best streak remembers the peak (Mon–Thu)');
  });

  test('weekly and monthly quests only come due on their days', () {
    today = DateTime(2026, 6, 15); // Monday the 15th
    final weekly = Quest(
        title: 'Sparring',
        stat: Stat.str,
        difficulty: 8,
        schedule: QuestSchedule.weekly,
        weekdays: const [1]); // anchored to Monday
    final monthly = Quest(
        title: 'Deep clean',
        stat: Stat.dis,
        difficulty: 5,
        schedule: QuestSchedule.monthly,
        monthDay: 15);

    // both due on Mon the 15th
    expect(weekly.scheduledOn(today), isTrue);
    expect(monthly.scheduledOn(today), isTrue);
    complete(GameState(), weekly); // marks done this week

    // Tue the 16th: weekly not anchored here, monthly not its day
    final tue = today.add(const Duration(days: 1));
    expect(weekly.scheduledOn(tue), isFalse);
    expect(monthly.scheduledOn(tue), isFalse);

    // weekly stays "done" all week, resets next Monday
    expect(weekly.doneFor(today.add(const Duration(days: 3))), isTrue);
    expect(weekly.doneFor(today.add(const Duration(days: 7))), isFalse);

    // monthly clamps to the last day in a short month
    final feb = Quest(
        title: 'Rent',
        stat: Stat.dis,
        difficulty: 4,
        schedule: QuestSchedule.monthly,
        monthDay: 31);
    expect(feb.scheduledOn(DateTime(2026, 2, 28)), isTrue); // 28th = clamp
    expect(feb.scheduledOn(DateTime(2026, 2, 27)), isFalse);
  });

  test('rising difficulty offers a rung after 5 holds, never before', () {
    today = DateTime(2026, 6, 15);
    final s = GameState();
    final q = Quest(title: 'Push-ups', stat: Stat.str, difficulty: 2,
        rising: true);

    for (var d = 0; d < 4; d++) {
      complete(s, q);
      expect(q.readyToRise, isFalse, reason: 'not yet after ${d + 1}');
      today = today.add(const Duration(days: 1));
    }
    complete(s, q); // 5th
    expect(q.readyToRise, isTrue);

    // accept the rise (mirrors the night-routine action)
    q.difficulty += 1;
    q.risingStreak = 0;
    expect(q.difficulty, 3);
    expect(q.readyToRise, isFalse);
  });

  test('goal progress accumulates and a BECOME milestone escalates', () {
    today = DateTime(2026, 6, 15);
    final s = GameState();
    s.addGoal(Goal(title: 'Get stronger', stat: Stat.str, target: 5));
    final q = Quest(
        title: 'Push-ups',
        stat: Stat.str,
        difficulty: 2,
        goalTitle: 'Get stronger');

    for (var i = 0; i < 5; i++) {
      complete(s, q);
      today = today.add(const Duration(days: 1));
    }
    final goal = s.goals.first;
    // BECOME goal: milestone reached, target doubled, still going
    expect(goal.kind, GoalKind.become);
    expect(goal.target, 10, reason: 'target doubles at milestone');
    expect(s.takeJustMilestoned(), isNotNull);
    expect(goal.complete, isFalse);
  });

  test('ACHIEVE goal crosses a finish line and completes', () {
    today = DateTime(2026, 6, 15);
    final s = GameState();
    s.addGoal(Goal(
        title: 'Finish the book',
        stat: Stat.intl,
        kind: GoalKind.achieve,
        target: 3));
    final q = Quest(
        title: 'Read a chapter',
        stat: Stat.intl,
        difficulty: 3,
        goalTitle: 'Finish the book');

    for (var i = 0; i < 3; i++) {
      complete(s, q);
      today = today.add(const Duration(days: 1));
    }
    final goal = s.goals.first;
    expect(goal.complete, isTrue);
    expect(s.takeJustAchieved(), isNotNull);
  });

  test('persistence round-trips mid-week state faithfully', () {
    today = DateTime(2026, 6, 15);
    final s = GameState()
      ..playerName = 'Aria'
      ..onboarded = true;
    s.addGoal(Goal(title: 'Get stronger', stat: Stat.str, target: 5));
    final q = Quest(
        title: 'Push-ups',
        stat: Stat.str,
        difficulty: 2,
        rising: true,
        goalTitle: 'Get stronger');
    complete(s, q);
    today = today.add(const Duration(days: 1));
    complete(s, q);

    // serialize the whole save blob and read it back
    final blob = jsonEncode({
      'state': s.toJson(),
      'quests': [q.toJson()],
    });
    final j = (jsonDecode(blob) as Map).cast<String, dynamic>();
    final s2 = GameState.fromJson((j['state'] as Map).cast<String, dynamic>());
    final q2 = Quest.fromJson(
        (j['quests'] as List).first as Map<String, dynamic>);

    expect(s2.playerName, 'Aria');
    expect(s2.streakDays, 2);
    expect(s2.goals.first.progress, 2);
    expect(s2.totalXp, s.totalXp);
    expect(q2.rising, isTrue);
    expect(q2.risingStreak, 2);
    expect(q2.goalTitle, 'Get stronger');
    expect(q2.lastDoneDay, q.lastDoneDay);
  });
}
