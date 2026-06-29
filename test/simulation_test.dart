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

  test('weekly carries forward from its anchor through the week; monthly hits '
      'its day', () {
    today = DateTime(2026, 6, 17); // Wednesday the 17th
    final weekly = Quest(
        title: 'Sparring',
        stat: Stat.str,
        difficulty: 8,
        schedule: QuestSchedule.weekly,
        weekdays: const [3]); // anchored to Wednesday

    // before the anchor this week: not yet on the board (don't nag early)
    expect(weekly.scheduledOn(DateTime(2026, 6, 15)), isFalse); // Mon
    expect(weekly.scheduledOn(DateTime(2026, 6, 16)), isFalse); // Tue
    // anchor day through end of week: stays open — a missed Wednesday lingers
    // as "still this week" rather than vanishing (round-21 carry-forward)
    expect(weekly.scheduledOn(DateTime(2026, 6, 17)), isTrue); // Wed (anchor)
    expect(weekly.scheduledOn(DateTime(2026, 6, 19)), isTrue); // Fri
    expect(weekly.scheduledOn(DateTime(2026, 6, 21)), isTrue); // Sun
    // next week, before the anchor again: cleanly reset
    expect(weekly.scheduledOn(DateTime(2026, 6, 22)), isFalse); // next Mon

    // an empty-anchor weekly is "any day this week"
    final anyWeekly = Quest(
        title: 'Call home',
        stat: Stat.soc,
        difficulty: 2,
        schedule: QuestSchedule.weekly);
    expect(anyWeekly.scheduledOn(DateTime(2026, 6, 15)), isTrue);

    // done this week stays done all week, resets next week
    complete(GameState(), weekly);
    expect(weekly.doneFor(DateTime(2026, 6, 20)), isTrue); // Sat, same week
    expect(weekly.doneFor(DateTime(2026, 6, 24)), isFalse); // next Wednesday

    // monthly: only its day, clamped to the last day of a short month
    final monthly = Quest(
        title: 'Deep clean',
        stat: Stat.dis,
        difficulty: 5,
        schedule: QuestSchedule.monthly,
        monthDay: 15);
    expect(monthly.scheduledOn(DateTime(2026, 6, 15)), isTrue);
    expect(monthly.scheduledOn(DateTime(2026, 6, 16)), isFalse);
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

  test('quest log notes round-trip and append without mutating the default',
      () {
    // two quests share the const [] default — appending to one must never
    // bleed into the other (the wholesale-replace guarantee in addNote).
    final a = Quest(title: 'Water the fern', stat: Stat.vit, difficulty: 1);
    final b = Quest(title: 'Stretch', stat: Stat.str, difficulty: 1);
    expect(a.log, isEmpty);
    a.addNote('front bed', DateTime(2026, 6, 15, 9));
    a.addNote('R side', DateTime(2026, 6, 16, 9));
    expect(b.log, isEmpty); // default list untouched
    expect(a.latestNote?.text, 'R side');

    final back = Quest.fromJson(
        (jsonDecode(jsonEncode(a.toJson())) as Map).cast<String, dynamic>());
    expect(back.log.length, 2);
    expect(back.log.first.text, 'front bed');
    expect(back.log.last.at, DateTime(2026, 6, 16, 9));

    // an empty log stays absent from the blob (no dead keys on most quests)
    expect(b.toJson().containsKey('log'), isFalse);
  });

  test('a keep-until-done to-do lingers across days, then clears once done',
      () {
    today = DateTime(2026, 6, 15);
    final s = GameState();
    // no dueDate → a persistent to-do (not a dated event)
    final todo = Quest(
        title: 'Call the dentist',
        stat: Stat.dis,
        difficulty: 2,
        schedule: QuestSchedule.once);
    final quests = [todo];

    // always on the board, never an "event" (so no overdue treatment)
    expect(todo.scheduledOn(today), isTrue);
    expect(todo.isEvent, isFalse);

    // a day passes without doing it: survives rollover, still waiting
    today = today.add(const Duration(days: 1));
    s.rollover(quests);
    expect(quests, contains(todo));
    expect(todo.doneFor(today), isFalse);

    // complete it: stays today, then the next rollover clears it
    complete(s, todo);
    expect(todo.doneFor(today), isTrue);
    today = today.add(const Duration(days: 1));
    s.rollover(quests);
    expect(quests, isNot(contains(todo)));
  });

  test('domain notes and goal journals round-trip through the save', () {
    today = DateTime(2026, 6, 15);
    final s = GameState();
    s.setDomainNotes(
        Stat.dis,
        s.notesFor(Stat.dis).withNote('declutter the desk', today,
            context: 'Cluttered'));
    s.addGoal(Goal(title: 'Keep the home', stat: Stat.dis, target: 25));
    s.goals.first.notes = s.goals.first.notes
        .withNote('week one, kitchen done', today, context: 'starting out');

    final back = GameState.fromJson(
        (jsonDecode(jsonEncode(s.toJson())) as Map).cast<String, dynamic>());
    expect(back.notesFor(Stat.dis).single.text, 'declutter the desk');
    // the "where I was" marker survives — proof of becoming
    expect(back.notesFor(Stat.dis).single.context, 'Cluttered');
    // sparse — domains with no notes don't materialise on restore
    expect(back.notesFor(Stat.str), isEmpty);
    expect(back.goals.first.notes.single.text, 'week one, kitchen done');
    expect(back.goals.first.notes.single.context, 'starting out');
  });

  test('todays shape recaps which domains were tended', () {
    today = DateTime(2026, 6, 15);
    final s = GameState();
    expect(s.todaysShape(), contains('every ember')); // nothing done yet
    complete(s, Quest(title: 'Push-ups', stat: Stat.str, difficulty: 2));
    expect(s.todaysShape(), contains('Body'));
    complete(s, Quest(title: 'Tidy up', stat: Stat.dis, difficulty: 2));
    final two = s.todaysShape();
    expect(two, contains('Body'));
    expect(two, contains('Home'));
  });
}
