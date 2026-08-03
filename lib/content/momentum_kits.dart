import '../clock.dart';
import '../models.dart';
import '../tokens.dart';

/// Optional, situation-shaped doorways into Room of Days' existing quest loop.
///
/// A kit never creates a second economy or a parallel checklist. It simply
/// forges a few compassionate, today-only quests which earn the same XP,
/// Glimmers, domain growth, and tapestry progress as anything else on the board.
enum MomentumKitKind {
  unstick,
  lowFlame,
  homeReset,
  focusExpedition,
  creativePractice,
  steadyDay,
  examSeason,
  movingHome,
  jobSearch,
  startingAgain,
}

class MomentumKitSpec {
  const MomentumKitSpec({
    required this.kind,
    required this.eyebrow,
    required this.title,
    required this.promise,
    required this.detail,
    required this.stat,
  });

  final MomentumKitKind kind;
  final String eyebrow;
  final String title;
  final String promise;
  final String detail;
  final Stat stat;
}

const momentumKits = <MomentumKitSpec>[
  MomentumKitSpec(
    kind: MomentumKitKind.unstick,
    eyebrow: 'EXECUTIVE FUNCTION',
    title: 'Unstick Me',
    promise: 'Turn the thing you are avoiding into one tiny first move.',
    detail: 'Name the snag, choose a short timer, and touch it once.',
    stat: Stat.foc,
  ),
  MomentumKitSpec(
    kind: MomentumKitKind.lowFlame,
    eyebrow: 'LOW-ENERGY DAYS',
    title: 'Gentle Mode Day',
    promise: 'Choose how much capacity you truly have. One step still counts.',
    detail: 'A gentle board for burnout, illness, grief, or caregiving days.',
    stat: Stat.vit,
  ),
  MomentumKitSpec(
    kind: MomentumKitKind.homeReset,
    eyebrow: 'OVERWHELMED SPACES',
    title: 'Guided Home Reset',
    promise: 'Give one room a visible win without trying to fix everything.',
    detail: 'Pick the room and the time; the guide supplies the order.',
    stat: Stat.dis,
  ),
  MomentumKitSpec(
    kind: MomentumKitKind.focusExpedition,
    eyebrow: 'STUDY & DEEP WORK',
    title: 'Focus Expedition',
    promise: 'Set one destination and protect a small stretch of attention.',
    detail: 'For studying, paperwork, applications, and difficult projects.',
    stat: Stat.intl,
  ),
  MomentumKitSpec(
    kind: MomentumKitKind.creativePractice,
    eyebrow: 'MAKERS & ARTISTS',
    title: 'Creative Practice',
    promise:
        'Keep a relationship with the work, even when inspiration is quiet.',
    detail: 'A repeatable session for writing, music, art, craft, or code.',
    stat: Stat.foc,
  ),
  MomentumKitSpec(
    kind: MomentumKitKind.steadyDay,
    eyebrow: 'BEGINNERS & OLDER ADULTS',
    title: 'Steady Day',
    promise: 'A plain, balanced day: move gently, tend a need, reach outward.',
    detail: 'No optimization language, no intensity contest, no failure state.',
    stat: Stat.soc,
  ),
  MomentumKitSpec(
    kind: MomentumKitKind.examSeason,
    eyebrow: 'LIFE CHAPTER · STUDENTS',
    title: 'Exam Season',
    promise: 'Shrink a high-pressure season into the next useful study move.',
    detail: 'A repeatable chapter for revision, assignments, and test weeks.',
    stat: Stat.intl,
  ),
  MomentumKitSpec(
    kind: MomentumKitKind.movingHome,
    eyebrow: 'LIFE CHAPTER · MOVING',
    title: 'Moving Home',
    promise: 'Build order one box, surface, and essential at a time.',
    detail: 'For packing, unpacking, downsizing, or making a new place yours.',
    stat: Stat.dis,
  ),
  MomentumKitSpec(
    kind: MomentumKitKind.jobSearch,
    eyebrow: 'LIFE CHAPTER · WORK',
    title: 'The Next Door',
    promise: 'Keep a job search moving without making every day an audition.',
    detail: 'Small sessions for applications, portfolios, and reaching out.',
    stat: Stat.foc,
  ),
  MomentumKitSpec(
    kind: MomentumKitKind.startingAgain,
    eyebrow: 'LIFE CHAPTER · RETURNING',
    title: 'Starting Again',
    promise: 'Rebuild rhythm after illness, grief, burnout, or a hard season.',
    detail: 'A deliberately gentle chapter with no catching-up debt.',
    stat: Stat.vit,
  ),
];

MomentumKitSpec momentumKit(MomentumKitKind kind) =>
    momentumKits.firstWhere((kit) => kit.kind == kind);

DateTime _today([DateTime? now]) {
  final d = now ?? Clock.now();
  return DateTime(d.year, d.month, d.day);
}

String _clean(String value, String fallback) {
  final trimmed = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  return trimmed.isEmpty ? fallback : trimmed;
}

Quest _spark({
  required String title,
  required Stat stat,
  required int difficulty,
  DateTime? now,
  int timerMinutes = 0,
  String? goalTitle,
  bool priority = false,
}) => Quest(
  title: title,
  stat: stat,
  difficulty: difficulty,
  schedule: QuestSchedule.once,
  verification: timerMinutes > 0 ? Verification.timer : Verification.honor,
  timerMinutes: timerMinutes,
  custom: true,
  dueDate: _today(now),
  goalTitle: goalTitle,
  priority: priority,
  bonus: true,
);

Quest buildUnstickQuest({
  required String task,
  required int minutes,
  Stat stat = Stat.foc,
  DateTime? now,
}) {
  final target = _clean(task, 'the stuck thing');
  return _spark(
    title: 'Touch $target for $minutes minutes',
    stat: stat,
    difficulty: minutes <= 2 ? 1 : (minutes <= 5 ? 2 : 3),
    timerMinutes: minutes,
    now: now,
  );
}

List<Quest> buildLowFlameQuests({required int capacity, DateTime? now}) {
  final count = capacity.clamp(1, 3);
  final all = <Quest>[
    _spark(
      title: 'Tend one basic need',
      stat: Stat.vit,
      difficulty: 1,
      now: now,
    ),
    _spark(
      title: 'Make one surface easier to live with',
      stat: Stat.dis,
      difficulty: 1,
      now: now,
    ),
    _spark(
      title: 'Send one low-pressure signal',
      stat: Stat.soc,
      difficulty: 1,
      now: now,
    ),
  ];
  return all.take(count).toList(growable: false);
}

List<Quest> buildHomeResetQuests({
  required String room,
  required int minutes,
  DateTime? now,
}) {
  final place = _clean(room, 'room');
  final steps = <Quest>[
    _spark(
      title: '$place reset · clear what does not belong',
      stat: Stat.dis,
      difficulty: 1,
      now: now,
    ),
    _spark(
      title: '$place reset · gather dishes and rubbish',
      stat: Stat.dis,
      difficulty: 2,
      now: now,
    ),
    _spark(
      title: '$place reset · restore one visible surface',
      stat: Stat.dis,
      difficulty: 2,
      timerMinutes: minutes,
      now: now,
    ),
  ];
  if (minutes <= 5) return [steps.last];
  if (minutes <= 15) return steps.skip(1).toList(growable: false);
  return steps;
}

Quest buildFocusQuest({
  required String target,
  required int minutes,
  DateTime? now,
}) => _spark(
  title: 'Focus expedition · ${_clean(target, 'one clear destination')}',
  stat: Stat.intl,
  difficulty: minutes <= 15 ? 3 : (minutes <= 25 ? 5 : 7),
  timerMinutes: minutes,
  goalTitle: 'Protect my attention',
  now: now,
);

Quest buildCreativeQuest({
  required String project,
  required int minutes,
  DateTime? now,
}) => _spark(
  title: 'Make contact with ${_clean(project, 'the work')}',
  stat: Stat.foc,
  difficulty: minutes <= 10 ? 2 : (minutes <= 25 ? 4 : 6),
  timerMinutes: minutes,
  goalTitle: 'Keep a creative practice',
  now: now,
);

List<Quest> buildSteadyDayQuests({required int capacity, DateTime? now}) {
  final count = capacity.clamp(1, 3);
  final all = <Quest>[
    _spark(
      title: 'Move gently for five minutes',
      stat: Stat.str,
      difficulty: 1,
      goalTitle: 'Build a steady day',
      now: now,
    ),
    _spark(
      title: 'Tend one everyday need',
      stat: Stat.vit,
      difficulty: 1,
      goalTitle: 'Build a steady day',
      now: now,
    ),
    _spark(
      title: 'Reach out to one person',
      stat: Stat.soc,
      difficulty: 1,
      goalTitle: 'Build a steady day',
      now: now,
    ),
  ];
  return all.take(count).toList(growable: false);
}

List<Quest> buildExamSeasonQuests({required int capacity, DateTime? now}) {
  final all = <Quest>[
    _spark(
      title: 'Choose the one topic that matters next',
      stat: Stat.intl,
      difficulty: 1,
      goalTitle: 'Cross exam season',
      now: now,
    ),
    _spark(
      title: 'Study one protected twenty-five minute block',
      stat: Stat.intl,
      difficulty: 4,
      timerMinutes: 25,
      goalTitle: 'Cross exam season',
      now: now,
    ),
    _spark(
      title: 'Recall five things without looking',
      stat: Stat.foc,
      difficulty: 3,
      goalTitle: 'Cross exam season',
      now: now,
    ),
  ];
  return all.take(capacity.clamp(1, 3)).toList(growable: false);
}

List<Quest> buildMovingHomeQuests({required int capacity, DateTime? now}) {
  final all = <Quest>[
    _spark(
      title: 'Pack or unpack one clear category',
      stat: Stat.dis,
      difficulty: 2,
      goalTitle: 'Make the move feel like home',
      now: now,
    ),
    _spark(
      title: 'Clear one safe walking path',
      stat: Stat.dis,
      difficulty: 2,
      goalTitle: 'Make the move feel like home',
      now: now,
    ),
    _spark(
      title: 'Set aside tomorrow’s essentials',
      stat: Stat.vit,
      difficulty: 2,
      goalTitle: 'Make the move feel like home',
      now: now,
    ),
  ];
  return all.take(capacity.clamp(1, 3)).toList(growable: false);
}

List<Quest> buildJobSearchQuests({required int capacity, DateTime? now}) {
  final all = <Quest>[
    _spark(
      title: 'Improve one line of the application',
      stat: Stat.foc,
      difficulty: 2,
      goalTitle: 'Open the next door',
      now: now,
    ),
    _spark(
      title: 'Send one considered application',
      stat: Stat.foc,
      difficulty: 4,
      goalTitle: 'Open the next door',
      now: now,
    ),
    _spark(
      title: 'Make one human career connection',
      stat: Stat.soc,
      difficulty: 3,
      goalTitle: 'Open the next door',
      now: now,
    ),
  ];
  return all.take(capacity.clamp(1, 3)).toList(growable: false);
}

List<Quest> buildStartingAgainQuests({required int capacity, DateTime? now}) {
  final all = <Quest>[
    _spark(
      title: 'Restore one basic need without earning it',
      stat: Stat.vit,
      difficulty: 1,
      goalTitle: 'Start again gently',
      now: now,
    ),
    _spark(
      title: 'Remove one small piece of friction',
      stat: Stat.dis,
      difficulty: 1,
      goalTitle: 'Start again gently',
      now: now,
    ),
    _spark(
      title: 'Choose tomorrow’s first kind move',
      stat: Stat.intl,
      difficulty: 1,
      goalTitle: 'Start again gently',
      now: now,
    ),
  ];
  return all.take(capacity.clamp(1, 3)).toList(growable: false);
}
