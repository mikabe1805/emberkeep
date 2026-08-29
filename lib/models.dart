import 'tokens.dart';

/// Safe enum-index read: clamps out-of-range / missing indices to a default
/// instead of throwing, so a single drifted value never rejects a whole
/// restore (round-9 resilience).
T _enumAt<T>(List<T> values, Object? idx, T fallback) {
  if (idx is int && idx >= 0 && idx < values.length) return values[idx];
  return fallback;
}

/// Day-key helpers — periods are computed from local wall-clock dates.
abstract final class Days {
  static final _keyPattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  static String key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Strict, non-normalizing parser for persisted day keys. `DateTime` would
  /// otherwise quietly turn 2026-02-31 into March, hiding a damaged save.
  static DateTime? tryParse(Object? value) {
    if (value is! String || !_keyPattern.hasMatch(value)) return null;
    final p = value.split('-');
    final year = int.tryParse(p[0]);
    final month = int.tryParse(p[1]);
    final day = int.tryParse(p[2]);
    if (year == null || month == null || day == null) return null;
    final parsed = DateTime(year, month, day);
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      return null;
    }
    return parsed;
  }

  static DateTime parse(String value) =>
      tryParse(value) ??
      (throw FormatException('Invalid Room of Days day', value));

  /// Keeps a valid persisted key and drops a drifted one to null.
  static String? validKey(Object? value) =>
      tryParse(value) == null ? null : value as String;

  /// Calendar-day distance, independent of 23/25-hour daylight-saving days.
  static int between(DateTime from, DateTime to) {
    final a = DateTime.utc(from.year, from.month, from.day);
    final b = DateTime.utc(to.year, to.month, to.day);
    return b.difference(a).inDays;
  }

  /// Monday of the week containing [d].
  static DateTime weekStart(DateTime d) =>
      DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1));

  static bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static bool sameWeek(DateTime a, DateTime b) =>
      sameDay(weekStart(a), weekStart(b));

  static bool sameMonth(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month;

  /// The calendar day owned by a night routine. Before 04:00, a person is
  /// still closing the day they just lived; constructing `day - 1` keeps the
  /// wall-clock date correct across daylight-saving boundaries.
  static DateTime nightDate(DateTime now) => now.hour < 4
      ? DateTime(now.year, now.month, now.day - 1)
      : DateTime(now.year, now.month, now.day);

  static String nightKey(DateTime now) => key(nightDate(now));

  /// The morning/day being prepared by this night's ledger.
  static DateTime afterNight(DateTime now) {
    final night = nightDate(now);
    return DateTime(night.year, night.month, night.day + 1);
  }
}

/// How often a quest recurs. Recurring quests reset when their period rolls
/// over; [once] quests (including calendar events) complete forever.
enum QuestSchedule {
  once('ONCE'),
  daily('DAILY'),
  weekly('WEEKLY'),
  monthly('MONTHLY');

  const QuestSchedule(this.label);
  final String label;
}

/// Proof level for a completion. Proof multiplies rewards, never gates
/// (RESEARCH.md §5): honor is always allowed, verification pays more.
enum Verification {
  honor,

  /// In-app wall-clock countdown — the first real proof system.
  timer,
}

/// A deliberately tiny capacity check-in. This is not a mood score or a
/// medical measure; it only helps Room of Days choose an honest amount of help.
enum EnergyWeather {
  low('GENTLE MODE'),
  steady('STEADY'),
  bright('BRIGHT');

  const EnergyWeather(this.label);
  final String label;
}

/// What kind of ambition a goal is (round-7):
/// [become] — an ongoing practice ("maintain healthy skin"); milestones
/// escalate forever. [achieve] — a finish line ("finish the book"); the
/// goal completes and is celebrated.
enum GoalKind {
  become('BECOME', 'an ongoing practice'),
  achieve('ACHIEVE', 'a finish line');

  const GoalKind(this.label, this.blurb);
  final String label;
  final String blurb;
}

/// The shape of work a goal needs. This is deliberately about route
/// structure, not personality: a finish line, a skill, a repeatable rhythm,
/// or a reset each need a different kind of first proof.
enum GoalRouteType {
  finish('FINISH', 'make or complete something'),
  skill('SKILL', 'become able to do something'),
  routine('RHYTHM', 'make something repeatable'),
  reset('RESET', 'change a space or situation');

  const GoalRouteType(this.label, this.blurb);
  final String label;
  final String blurb;
}

enum GoalPlanStepKind { prepare, act, practice, review, recover }

/// A person's explanation for why the current plan did not fit. These are
/// planning signals, never scores or diagnoses.
enum GoalPlanSignal { completed, tooBig, unclear, noTime, lowEnergy, changed }

class GoalPlanStep {
  const GoalPlanStep({
    required this.id,
    required this.title,
    required this.actionTitle,
    required this.proof,
    required this.whyNow,
    required this.ctaLabel,
    required this.minutes,
    required this.kind,
    this.requiredCompletions = 1,
    this.completions = 0,
    this.masteryCompletions = 0,
    this.completedDay,
    this.resumeAfterRecovery,
    this.questTemplate,
  });

  final String id;
  final String title;
  final String actionTitle;
  final String proof;
  final String whyNow;
  final String ctaLabel;
  final int minutes;
  final GoalPlanStepKind kind;
  final int requiredCompletions;
  final int completions;

  /// Permanent completion history for this owned route marker. Workshop
  /// Quests are deliberately short-lived attempt objects, so their mastery
  /// lives here and is handed forward to each newly accepted attempt.
  final int masteryCompletions;
  final String? completedDay;

  /// The owned marker this temporary rescue should return to after it earns a
  /// smaller proof. Keeping the marker snapshot prevents a hard-day action
  /// from quietly becoming the permanent plan for later attempts.
  final GoalPlanStep? resumeAfterRecovery;

  /// A configured Quest kept dormant inside the route until this marker is
  /// explicitly accepted. This preserves schedule, verification, and other
  /// authored choices without putting unfinished work on the board early.
  final Quest? questTemplate;

  bool get complete =>
      completedDay != null || completions >= requiredCompletions;

  GoalPlanStep copyWith({
    String? title,
    String? actionTitle,
    String? proof,
    String? whyNow,
    String? ctaLabel,
    int? minutes,
    GoalPlanStepKind? kind,
    int? requiredCompletions,
    int? completions,
    int? masteryCompletions,
    String? completedDay,
    bool clearCompletedDay = false,
    GoalPlanStep? resumeAfterRecovery,
    bool clearResumeAfterRecovery = false,
    Quest? questTemplate,
    bool clearQuestTemplate = false,
  }) => GoalPlanStep(
    id: id,
    title: title ?? this.title,
    actionTitle: actionTitle ?? this.actionTitle,
    proof: proof ?? this.proof,
    whyNow: whyNow ?? this.whyNow,
    ctaLabel: ctaLabel ?? this.ctaLabel,
    minutes: minutes ?? this.minutes,
    kind: kind ?? this.kind,
    requiredCompletions: requiredCompletions ?? this.requiredCompletions,
    completions: completions ?? this.completions,
    masteryCompletions: masteryCompletions ?? this.masteryCompletions,
    completedDay: clearCompletedDay ? null : completedDay ?? this.completedDay,
    resumeAfterRecovery: clearResumeAfterRecovery
        ? null
        : resumeAfterRecovery ?? this.resumeAfterRecovery,
    questTemplate: clearQuestTemplate
        ? null
        : questTemplate ?? this.questTemplate,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'actionTitle': actionTitle,
    'proof': proof,
    'whyNow': whyNow,
    'ctaLabel': ctaLabel,
    'minutes': minutes,
    'kind': kind.index,
    'requiredCompletions': requiredCompletions,
    'completions': completions,
    if (masteryCompletions > 0) 'masteryCompletions': masteryCompletions,
    if (completedDay != null) 'completedDay': completedDay,
    if (resumeAfterRecovery != null)
      'resumeAfterRecovery': resumeAfterRecovery!.toJson(),
    if (questTemplate != null) 'questTemplate': questTemplate!.toJson(),
  };

  static GoalPlanStep fromJson(Map<String, dynamic> j) => GoalPlanStep(
    id: (j['id'] as String?) ?? 'step',
    title: (j['title'] as String?) ?? 'Next marker',
    actionTitle: (j['actionTitle'] as String?) ?? 'Choose a next action',
    proof: (j['proof'] as String?) ?? 'A real attempt exists',
    whyNow: (j['whyNow'] as String?) ?? 'This is the next open marker.',
    ctaLabel: (j['ctaLabel'] as String?) ?? 'BEGIN HERE',
    minutes: ((j['minutes'] as int?) ?? 15).clamp(1, 240),
    kind: _enumAt(GoalPlanStepKind.values, j['kind'], GoalPlanStepKind.act),
    requiredCompletions: ((j['requiredCompletions'] as int?) ?? 1).clamp(
      1,
      100,
    ),
    completions: ((j['completions'] as int?) ?? 0).clamp(0, 10000),
    // Pre-mastery saves can at least recover the attempts still recorded on
    // this marker; future routine cycles retain the full permanent count.
    masteryCompletions:
        ((j['masteryCompletions'] as int?) ?? (j['completions'] as int?) ?? 0)
            .clamp(0, 1 << 30),
    completedDay: Days.validKey(j['completedDay']),
    resumeAfterRecovery: j['resumeAfterRecovery'] is Map
        ? GoalPlanStep.fromJson(
            Map<String, dynamic>.from(j['resumeAfterRecovery'] as Map),
          )
        : null,
    questTemplate: j['questTemplate'] is Map
        ? Quest.fromJson(Map<String, dynamic>.from(j['questTemplate'] as Map))
        : null,
  );
}

class GoalPlanAdjustment {
  const GoalPlanAdjustment({
    required this.day,
    required this.signal,
    required this.fromAction,
    required this.toAction,
  });

  final String day;
  final GoalPlanSignal signal;
  final String fromAction;
  final String toAction;

  Map<String, dynamic> toJson() => {
    'day': day,
    'signal': signal.index,
    'fromAction': fromAction,
    'toAction': toAction,
  };

  static GoalPlanAdjustment fromJson(Map<String, dynamic> j) =>
      GoalPlanAdjustment(
        day: Days.validKey(j['day']) ?? Days.key(DateTime(2000)),
        signal: _enumAt(
          GoalPlanSignal.values,
          j['signal'],
          GoalPlanSignal.tooBig,
        ),
        fromAction: (j['fromAction'] as String?) ?? '',
        toAction: (j['toAction'] as String?) ?? '',
      );
}

/// A small, explainable route from an owned aim to the next Quest.
///
/// This is local and deterministic. The app drafts it from the person's
/// stated outcome, present reality, proof, available time, and likely snag;
/// every part remains editable and every revision is recorded.
class GoalPlan {
  const GoalPlan({
    required this.type,
    required this.outcome,
    required this.startingPoint,
    required this.successProof,
    required this.timeBudgetMinutes,
    required this.obstacleCue,
    required this.fallbackAction,
    required this.steps,
    required this.createdDay,
    this.horizon,
    this.revision = 1,
    this.cyclesCompleted = 0,
    this.lastSignal,
    this.adjustments = const [],
  });

  final GoalRouteType type;
  final String outcome;
  final String startingPoint;
  final String successProof;
  final int timeBudgetMinutes;
  final String? horizon;
  final String obstacleCue;
  final String fallbackAction;
  final List<GoalPlanStep> steps;
  final String createdDay;
  final int revision;
  final int cyclesCompleted;
  final GoalPlanSignal? lastSignal;
  final List<GoalPlanAdjustment> adjustments;

  int get completedSteps => steps.where((step) => step.complete).length;
  int get currentStepIndex {
    final found = steps.indexWhere((step) => !step.complete);
    return found < 0 ? (steps.isEmpty ? 0 : steps.length - 1) : found;
  }

  GoalPlanStep? get currentStep =>
      steps.isEmpty ? null : steps[currentStepIndex];
  bool get complete => steps.isNotEmpty && steps.every((step) => step.complete);

  GoalPlan copyWith({
    GoalRouteType? type,
    String? outcome,
    String? startingPoint,
    String? successProof,
    int? timeBudgetMinutes,
    String? horizon,
    String? obstacleCue,
    String? fallbackAction,
    List<GoalPlanStep>? steps,
    int? revision,
    int? cyclesCompleted,
    GoalPlanSignal? lastSignal,
    List<GoalPlanAdjustment>? adjustments,
  }) => GoalPlan(
    type: type ?? this.type,
    outcome: outcome ?? this.outcome,
    startingPoint: startingPoint ?? this.startingPoint,
    successProof: successProof ?? this.successProof,
    timeBudgetMinutes: timeBudgetMinutes ?? this.timeBudgetMinutes,
    horizon: horizon ?? this.horizon,
    obstacleCue: obstacleCue ?? this.obstacleCue,
    fallbackAction: fallbackAction ?? this.fallbackAction,
    steps: steps ?? this.steps,
    createdDay: createdDay,
    revision: revision ?? this.revision,
    cyclesCompleted: cyclesCompleted ?? this.cyclesCompleted,
    lastSignal: lastSignal ?? this.lastSignal,
    adjustments: adjustments ?? this.adjustments,
  );

  Map<String, dynamic> toJson() => {
    'type': type.index,
    'outcome': outcome,
    'startingPoint': startingPoint,
    'successProof': successProof,
    'timeBudgetMinutes': timeBudgetMinutes,
    if (horizon != null) 'horizon': horizon,
    'obstacleCue': obstacleCue,
    'fallbackAction': fallbackAction,
    'steps': [for (final step in steps) step.toJson()],
    'createdDay': createdDay,
    'revision': revision,
    if (cyclesCompleted > 0) 'cyclesCompleted': cyclesCompleted,
    if (lastSignal != null) 'lastSignal': lastSignal!.index,
    if (adjustments.isNotEmpty)
      'adjustments': [
        for (final adjustment in adjustments) adjustment.toJson(),
      ],
  };

  static GoalPlan? fromJson(Object? value) {
    if (value is! Map) return null;
    final j = value.cast<String, dynamic>();
    final steps = <GoalPlanStep>[
      for (final raw in (j['steps'] as List?) ?? const [])
        if (raw is Map) GoalPlanStep.fromJson(raw.cast<String, dynamic>()),
    ];
    if (steps.isEmpty) return null;
    final lastSignal = j['lastSignal'];
    return GoalPlan(
      type: _enumAt(GoalRouteType.values, j['type'], GoalRouteType.finish),
      outcome: (j['outcome'] as String?) ?? 'Make this goal real',
      startingPoint: (j['startingPoint'] as String?) ?? 'Starting now',
      successProof: (j['successProof'] as String?) ?? 'A real result exists',
      timeBudgetMinutes: ((j['timeBudgetMinutes'] as int?) ?? 15).clamp(1, 240),
      horizon: j['horizon'] as String?,
      obstacleCue:
          (j['obstacleCue'] as String?) ?? 'the usual plan feels too large',
      fallbackAction:
          (j['fallbackAction'] as String?) ?? 'Give it five honest minutes',
      steps: steps,
      createdDay: Days.validKey(j['createdDay']) ?? Days.key(DateTime(2000)),
      revision: ((j['revision'] as int?) ?? 1).clamp(1, 1000000),
      cyclesCompleted: ((j['cyclesCompleted'] as int?) ?? 0).clamp(0, 1000000),
      lastSignal: lastSignal == null
          ? null
          : _enumAt(GoalPlanSignal.values, lastSignal, GoalPlanSignal.tooBig),
      adjustments: [
        for (final raw in (j['adjustments'] as List?) ?? const [])
          if (raw is Map)
            GoalPlanAdjustment.fromJson(raw.cast<String, dynamic>()),
      ],
    );
  }
}

/// A user goal: a named ambition that linked quests feed. Progress counts
/// linked-quest completions toward [target] — the bar the night recap fills.
class Goal {
  Goal({
    required this.title,
    required this.stat,
    required this.target,
    this.kind = GoalKind.become,
    this.progress = 0,
    this.achievedDay,
    this.startedDay,
    this.milestones = 0,
    this.notes = const [],
    this.why,
    this.fallbackCue,
    this.fallbackAction,
    this.firstProofTitle,
    this.firstProofDay,
    this.openingSeen = true,
    this.plan,
  });

  final String title;
  final Stat stat;
  final GoalKind kind;
  int target;
  int progress;

  /// The goal's journal — timestamped reflections on the journey (replaced
  /// wholesale, never mutated in place; see [NoteList]).
  List<Note> notes;

  /// Day-key when an [GoalKind.achieve] goal crossed its finish line.
  String? achievedDay;

  /// Day-key the goal was adopted/sworn — powers "days on the journey".
  /// Null on pre-existing saves (shown as an em-dash, never a wrong number).
  String? startedDay;

  /// How many times a BECOME goal's target has doubled — the milestone count
  /// (gold-banner moments). Tracked from when the field shipped; default 0.
  int milestones;

  /// The person's own reason for keeping this goal. Optional: a goal never
  /// needs to justify itself to the app before it can begin.
  String? why;

  /// A gentle if-then fallback: when [fallbackCue] happens, [fallbackAction]
  /// offers a smaller, self-chosen way back in. Both stay optional and are
  /// intentionally separate so the UI can present the plan as a real choice.
  String? fallbackCue;
  String? fallbackAction;

  /// The first real linked completion kept as the goal's durable starting
  /// proof. This is stamped by GameState.commit, never by creation or intent.
  String? firstProofTitle;
  String? firstProofDay;

  /// Whether this goal's one-time authored opening has been accepted.
  ///
  /// The default is deliberately true so legacy saves and programmatic test
  /// fixtures keep their existing fast return. Real creation paths opt new
  /// goals into the opening with `openingSeen: false`, and acceptance is
  /// persisted before the exact first Quest handoff.
  bool openingSeen;

  /// The optional structured route. Legacy goals remain valid without one and
  /// can be upgraded in place without inventing history.
  GoalPlan? plan;

  bool get complete => achievedDay != null;
  double get fraction => target == 0 ? 0 : (progress / target).clamp(0.0, 1.0);

  Map<String, dynamic> toJson() => {
    'title': title,
    'stat': stat.index,
    'kind': kind.index,
    'target': target,
    'progress': progress,
    'achievedDay': achievedDay,
    'startedDay': startedDay,
    'milestones': milestones,
    if (notes.isNotEmpty) 'notes': [for (final n in notes) n.toJson()],
    if (why != null) 'why': why,
    if (fallbackCue != null) 'fallbackCue': fallbackCue,
    if (fallbackAction != null) 'fallbackAction': fallbackAction,
    if (firstProofTitle != null) 'firstProofTitle': firstProofTitle,
    if (firstProofDay != null) 'firstProofDay': firstProofDay,
    'openingSeen': openingSeen,
    if (plan != null) 'plan': plan!.toJson(),
  };

  static Goal fromJson(Map<String, dynamic> j) {
    final kind = _enumAt(GoalKind.values, j['kind'], GoalKind.become);
    final target = (j['target'] as int?) ?? 25;
    var milestones = j['milestones'] as int? ?? 0;
    // Back-fill for pre-round-20 saves (no `milestones` key): a BECOME goal
    // always starts at 25 and only doubles, so target == 25 * 2^n — recover the
    // count so the detail ring/caption/tile read truthfully. Never recompute
    // when the key is present (that's a real, possibly-mid-tier saved value).
    if (!j.containsKey('milestones') &&
        kind == GoalKind.become &&
        target > 25) {
      var t = target ~/ 25;
      var n = 0;
      while (t > 1) {
        t ~/= 2;
        n++;
      }
      milestones = n;
    }
    return Goal(
      title: (j['title'] as String?) ?? 'Goal',
      stat: _enumAt(Stat.values, j['stat'], Stat.dis),
      kind: kind,
      target: target,
      progress: j['progress'] as int? ?? 0,
      achievedDay: Days.validKey(j['achievedDay']),
      startedDay: Days.validKey(j['startedDay']),
      milestones: milestones,
      why: j['why'] as String?,
      fallbackCue: j['fallbackCue'] as String?,
      fallbackAction: j['fallbackAction'] as String?,
      firstProofTitle: j['firstProofTitle'] as String?,
      firstProofDay: Days.validKey(j['firstProofDay']),
      openingSeen: j['openingSeen'] as bool? ?? true,
      plan: GoalPlan.fromJson(j['plan']),
      notes: [
        for (final e in (j['notes'] as List?) ?? const [])
          Note.fromJson((e as Map).cast<String, dynamic>()),
      ],
    );
  }
}

/// One timestamped note — the atom of "notes-with-consequence" (round-24). The
/// SAME note type attaches to a quest's running log ("R deltoid", "fed ½ cup"),
/// a goal's journal ("week three, finally enjoying this"), a life-domain's base,
/// or a free-form day reflection. It never floats alone: every note sits ON
/// something the game already gives meaning to — that connection is the whole
/// thesis (Notion-done-right, because the thing it's pinned to has stakes).
/// Immutable game context captured beside a free journal page.
///
/// Room of Days can remember what a generic notes app cannot know: which quests
/// had happened, what they moved, how much XP the day carried, and which goals
/// those actions served. Reopening an old page therefore returns the day as it
/// actually was instead of recomputing it from today's state.
class JournalTrace {
  const JournalTrace({
    required this.day,
    required this.level,
    required this.totalXp,
    required this.todayXp,
    required this.streakDays,
    this.questTitles = const [],
    this.goalTitles = const [],
    this.statGains = const {},
    this.energy,
  });

  final String day;
  final int level;
  final int totalXp;
  final int todayXp;
  final int streakDays;
  final List<String> questTitles;
  final List<String> goalTitles;
  final Map<Stat, int> statGains;
  final EnergyWeather? energy;

  bool get hasDayEvidence =>
      questTitles.isNotEmpty ||
      goalTitles.isNotEmpty ||
      statGains.values.any((gain) => gain > 0) ||
      todayXp > 0 ||
      energy != null;

  Map<String, dynamic> toJson() => {
    'day': day,
    'level': level,
    'totalXp': totalXp,
    'todayXp': todayXp,
    'streakDays': streakDays,
    if (questTitles.isNotEmpty) 'questTitles': questTitles,
    if (goalTitles.isNotEmpty) 'goalTitles': goalTitles,
    if (statGains.isNotEmpty)
      'statGains': [for (final stat in Stat.values) statGains[stat] ?? 0],
    if (energy != null) 'energy': energy!.name,
  };

  static JournalTrace? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final j = raw.cast<String, dynamic>();
    final day = Days.validKey(j['day']);
    if (day == null) return null;
    final gains = <Stat, int>{};
    final stored = (j['statGains'] as List?)?.cast<num>() ?? const <num>[];
    for (var i = 0; i < stored.length && i < Stat.values.length; i++) {
      final value = stored[i].toInt();
      if (value > 0) gains[Stat.values[i]] = value;
    }
    final energyName = j['energy'] as String?;
    EnergyWeather? energy;
    for (final value in EnergyWeather.values) {
      if (value.name == energyName) energy = value;
    }
    return JournalTrace(
      day: day,
      level: j['level'] as int? ?? 1,
      totalXp: j['totalXp'] as int? ?? 0,
      todayXp: j['todayXp'] as int? ?? 0,
      streakDays: j['streakDays'] as int? ?? 0,
      questTitles: [
        for (final value in (j['questTitles'] as List?) ?? const [])
          if (value is String) value,
      ],
      goalTitles: [
        for (final value in (j['goalTitles'] as List?) ?? const [])
          if (value is String) value,
      ],
      statGains: gains,
      energy: energy,
    );
  }
}

/// The optional pieces a person may keep while closing the day. Keeping the
/// structure beside the Journal note lets the morning return only the private
/// message meant for it, while Journal search and previews still use one plain
/// text entry.
class NightJournalData {
  const NightJournalData({
    this.reflection,
    this.gratitudes = const [],
    this.discovery,
    this.tomorrowMessage,
  });

  final String? reflection;
  final List<String> gratitudes;
  final String? discovery;
  final String? tomorrowMessage;

  bool get isEmpty =>
      _clean(reflection) == null &&
      _clean(discovery) == null &&
      _clean(tomorrowMessage) == null &&
      normalizedGratitudes.isEmpty;

  List<String> get normalizedGratitudes => [
    for (final value in gratitudes.take(3))
      if (_clean(value) case final String clean) clean,
  ];

  String get plainText {
    final sections = <String>[];
    if (_clean(reflection) case final String value) {
      sections.add('Reflection\n$value');
    }
    final grateful = normalizedGratitudes;
    if (grateful.isNotEmpty) {
      sections.add('Grateful for\n${grateful.map((e) => '• $e').join('\n')}');
    }
    if (_clean(discovery) case final String value) {
      sections.add('I discovered\n$value');
    }
    if (_clean(tomorrowMessage) case final String value) {
      sections.add('For tomorrow\n$value');
    }
    return sections.join('\n\n');
  }

  Map<String, dynamic> toJson() => {
    'v': 1,
    if (_clean(reflection) case final String value) 'reflection': value,
    if (normalizedGratitudes.isNotEmpty) 'gratitudes': normalizedGratitudes,
    if (_clean(discovery) case final String value) 'discovery': value,
    if (_clean(tomorrowMessage) case final String value)
      'tomorrowMessage': value,
  };

  static NightJournalData? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final j = raw.cast<Object?, Object?>();
    final data = NightJournalData(
      reflection: j['reflection'] is String
          ? _clean(j['reflection'] as String)
          : null,
      gratitudes: [
        for (final value in (j['gratitudes'] as List?) ?? const [])
          if (value is String && _clean(value) != null) _clean(value)!,
      ].take(3).toList(growable: false),
      discovery: j['discovery'] is String
          ? _clean(j['discovery'] as String)
          : null,
      tomorrowMessage: j['tomorrowMessage'] is String
          ? _clean(j['tomorrowMessage'] as String)
          : null,
    );
    return data.isEmpty ? null : data;
  }

  static String? _clean(String? value) {
    final clean = value?.trim() ?? '';
    return clean.isEmpty ? null : clean;
  }
}

class Note {
  Note({
    required this.at,
    required this.text,
    this.context,
    this.editedAt,
    this.images = const [],
    this.rich,
    this.trace,
    this.night,
    this.sourceQuestKey,
    String? id,
  }) : id = id ?? _freshId(at);

  /// Stable identity for an entry (round-53). Lets a note be EDITED in place —
  /// replaced by id — and reliably deleted, rather than the old object-identity
  /// matching that broke the instant a note's text changed. Generated once at
  /// creation and persisted; legacy saves (written before ids) get one assigned
  /// on load, which is then saved back.
  final String id;

  /// When the note was first written (full timestamp — finer than a day).
  final DateTime at;

  /// The body. Immutable here — an edit produces a NEW Note via [copyWith], so
  /// the wholesale-replace invariant (and the `const []` default) still holds.
  final String text;

  /// A tiny "where I was" marker captured at write time — e.g. a domain's rank
  /// ("Frail") or a goal's standing ("milestone 2"). Lets a journal show proof
  /// of becoming ("written when CARE was Frail — now Vital"), the payoff that
  /// makes notes-with-consequence felt rather than described. Null for plain
  /// quest logs. Preserved across edits (it stamps when you FIRST wrote it).
  final String? context;

  /// When the entry was last edited, if ever — drives a quiet "· edited" marker
  /// so a revised reflection still reads honestly. Null = never touched since
  /// it was written.
  final DateTime? editedAt;

  /// Local media attached to this entry — filenames into the app's journal
  /// images directory, in display order. Empty = a plain text note. (Stored
  /// on-device; media does not ride the cloud-synced save blob.)
  final List<String> images;

  /// A structured journal document — JSON of an interleaved list of text and
  /// image blocks (see [JournalDoc]) — so a free entry reads like a page you
  /// wrote, with photos sitting between paragraphs. Null on plain notes (quest
  /// logs, domain/goal notes) and legacy entries, which use [text] alone; when
  /// set, [text] holds the plain-text flattening (for previews/search).
  final String? rich;

  /// Automatic Quest/Goal/day context for a free journal page. Null on legacy
  /// entries and notes that already live directly on a quest, goal, or domain.
  final JournalTrace? trace;

  /// Structured optional prompts from the closing ledger. [text] remains the
  /// searchable/displayable flattening, so older Journal surfaces still work.
  final NightJournalData? night;

  /// Stable identity of the Quest that opened this dedicated Journal page.
  ///
  /// This is deliberately separate from [JournalTrace.questTitles]: a normal
  /// day page can mention several completed quests, while this field means
  /// "resume this exact draft when this exact quest is tapped again." The
  /// quest's identity title is stable even when a rising quest's visible rung
  /// changes.
  final String? sourceQuestKey;

  /// An edited copy that keeps the same identity, original timestamp and
  /// context. NOTE: null args mean "keep the current value" — [editedAt] is
  /// only changed when explicitly passed (an autosave of a brand-new entry
  /// must not stamp it), and no field can be cleared back to null through
  /// this method.
  Note copyWith({
    String? text,
    DateTime? editedAt,
    List<String>? images,
    String? rich,
  }) => Note(
    id: id,
    at: at,
    context: context,
    text: text ?? this.text,
    editedAt: editedAt ?? this.editedAt,
    images: images ?? this.images,
    rich: rich ?? this.rich,
    trace: trace,
    night: night,
    sourceQuestKey: sourceQuestKey,
  );

  Note withNight(NightJournalData data, {JournalTrace? updatedTrace}) => Note(
    id: id,
    at: at,
    context: context,
    text: data.plainText,
    editedAt: editedAt,
    images: const [],
    trace: updatedTrace ?? trace,
    night: data,
    sourceQuestKey: sourceQuestKey,
  );

  // microsecond timestamp + a monotonic per-process suffix → unique even for
  // two notes created within the same microsecond.
  static int _seq = 0;
  static String _freshId(DateTime at) =>
      '${at.microsecondsSinceEpoch.toRadixString(36)}_${(_seq++).toRadixString(36)}';

  Map<String, dynamic> toJson() => {
    'id': id,
    'at': at.toIso8601String(),
    'text': text,
    if (context != null) 'context': context,
    if (editedAt != null) 'editedAt': editedAt!.toIso8601String(),
    if (images.isNotEmpty) 'images': images,
    if (rich != null) 'rich': rich,
    if (trace != null) 'trace': trace!.toJson(),
    if (night != null) 'night': night!.toJson(),
    if (sourceQuestKey != null) 'sourceQuestKey': sourceQuestKey,
  };

  static Note fromJson(Map<String, dynamic> j) => Note(
    id: j['id'] as String?,
    // a drifted/missing timestamp sorts to the epoch rather than throwing
    // (round-9 restore resilience), never rejecting the whole save.
    at: DateTime.tryParse(j['at'] as String? ?? '') ?? DateTime(2000),
    text: (j['text'] as String?) ?? '',
    context: j['context'] as String?,
    editedAt: DateTime.tryParse(j['editedAt'] as String? ?? ''),
    images: [for (final e in (j['images'] as List?) ?? const []) e as String],
    rich: j['rich'] as String?,
    trace: JournalTrace.fromJson(j['trace']),
    night: NightJournalData.fromJson(j['night']),
    sourceQuestKey: j['sourceQuestKey'] as String?,
  );
}

/// Shared helpers for a list of [Note]s held by an owner (quest/goal/domain).
/// Lists are always replaced wholesale (never mutated in place) so a `const []`
/// default is safe to share across instances.
extension NoteList on List<Note> {
  List<Note> withNote(String text, DateTime at, {String? context}) => [
    ...this,
    Note(at: at, text: text, context: context),
  ];

  /// Replace the note sharing [updated]'s id — an identity-stable edit.
  List<Note> replacing(Note updated) => [
    for (final e in this) e.id == updated.id ? updated : e,
  ];

  List<Note> without(Note n) => where((e) => e.id != n.id).toList();
}

/// Which surface a room style repaints — walls or the floor (round-46, room
/// customization). Lives here (not content/) so the engine can take it without
/// a content→engine→content import cycle.
enum RoomStyleKind { wall, floor }

/// Authored Journal doorway for a Quest.
///
/// Runtime routing keys off this metadata rather than guessing from words such
/// as "write" or "grateful" in a user-editable title. The starter sits on the
/// page as a prompt but is not saved merely by opening the editor; the Quest
/// only resolves after the person adds meaningful writing of their own.
class JournalQuestPrompt {
  const JournalQuestPrompt({
    required this.starter,
    this.hint = 'Write underneath the prompt…',
  });

  final String starter;
  final String hint;

  Map<String, dynamic> toJson() => {'starter': starter, 'hint': hint};

  static JournalQuestPrompt? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final json = raw.cast<Object?, Object?>();
    final starter = json['starter'];
    if (starter is! String || starter.trim().isEmpty) return null;
    final hint = json['hint'];
    return JournalQuestPrompt(
      starter: starter,
      hint: hint is String && hint.trim().isNotEmpty
          ? hint
          : 'Write underneath the prompt…',
    );
  }
}

/// Permanent mastery belongs to the Quest itself, never to a particular
/// category. Five honest completions of a study, care, home, movement, or
/// creative Quest therefore earn the same mark.
enum QuestMasteryTier {
  unmarked(0, ''),
  kept(5, 'KEPT'),
  practiced(15, 'PRACTICED'),
  gilded(40, 'GILDED'),
  masterwork(100, 'MASTERWORK');

  const QuestMasteryTier(this.threshold, this.label);

  final int threshold;
  final String label;
}

QuestMasteryTier questMasteryTierFor(int completions) {
  for (final tier in QuestMasteryTier.values.reversed) {
    if (completions >= tier.threshold) return tier;
  }
  return QuestMasteryTier.unmarked;
}

/// The one progression mutation produced by an accepted completion.
///
/// Keeping this separate from XP lets every completion surface the same
/// mastery truth while an authored ladder may also change its prescription.
class QuestProgressChange {
  const QuestProgressChange({
    required this.completionsBefore,
    required this.completionsAfter,
    required this.tierBefore,
    required this.tierAfter,
    this.risenToTitle,
  });

  final int completionsBefore;
  final int completionsAfter;
  final QuestMasteryTier tierBefore;
  final QuestMasteryTier tierAfter;
  final String? risenToTitle;

  QuestMasteryTier? get tierReached =>
      tierAfter != tierBefore ? tierAfter : null;
}

/// A quest: curated (goal catalog), custom (user-forged), or a calendar
/// event / long-term goal ([schedule] == once with a [dueDate]).
class Quest {
  Quest({
    required this.title,
    required this.stat,
    required this.difficulty,
    this.dread = false,
    this.ladderHint,
    this.schedule = QuestSchedule.daily,
    this.verification = Verification.honor,
    this.timerMinutes = 0,
    this.custom = false,
    this.dueDate,
    this.lastDoneDay,
    this.snoozedDay,
    this.goalTitle,
    this.goalPlanStepId,
    this.goalPlanRevision,
    this.goalPlanAttempt,
    this.priority = false,
    this.priorityDay,
    this.priorityRank,
    this.allDay = false,
    this.weekdays = const [],
    this.monthDay,
    this.rising = false,
    this.risingStreak = 0,
    bool? autoRise,
    this.masteryCompletions = 0,
    this.ladder,
    this.rung = 0,
    this.kin,
    this.bonus = false,
    this.origin,
    this.workout = false,
    this.journalPrompt,
    this.createdDay,
    this.log = const [],
  }) : autoRise = autoRise ?? (!custom && rising && (ladder?.length ?? 0) > 1);

  /// Identity title — the rung-0 prescription, stable for dedup/restore even
  /// after the quest climbs (the visible prescription comes from [displayTitle]).
  final String title;

  /// Which attribute this trains. Mutable: the manage dialog lets you re-tune
  /// a quest you've adopted (deep personalization is the hook).
  Stat stat;

  /// 1–10 continuous difficulty. Custom quests cap at 8 (anti-abuse).
  /// Mutable: rising quests climb a rung when the user accepts a rise.
  int difficulty;

  /// Dreaded tasks pay a courage bonus.
  final bool dread;

  /// "next rung: 5" — the visible progression ladder.
  final String? ladderHint;

  final QuestSchedule schedule;
  final Verification verification;

  /// Countdown length for timer-verified quests. Mutable so Tune can resize
  /// a session without forging a new quest.
  int timerMinutes;

  /// User-forged quests pay ×0.85 — honesty keeps the magic.
  final bool custom;

  /// Calendar events / long-term goals: when this is due.
  final DateTime? dueDate;

  /// Day-key of the last completion — drives period-based resets.
  String? lastDoneDay;

  /// Day the quest was forged (anti-grind day-one damp for custom quests).
  String? createdDay;

  /// Day-key this quest was hidden "just for today" — a gentle skip that
  /// returns it to the board tomorrow (distinct from a permanent removal).
  /// Mutable: set from the long-press manage sheet.
  String? snoozedDay;

  /// Which user goal this quest feeds (matched by goal title). Mutable so the
  /// oath wizard can re-stamp it if the goal's name/domain changes before the
  /// oath is sworn.
  String? goalTitle;

  /// Optional identity inside a structured goal route. [goalTitle] still owns
  /// compatibility; these fields let one completion advance the exact plan
  /// marker it was created for and reject stale pre-replan actions.
  String? goalPlanStepId;
  int? goalPlanRevision;
  int? goalPlanAttempt;

  /// Starred as a MAIN quest (set in the night planner; the morning
  /// briefing leads with these).
  bool priority;

  /// A date-specific MAIN choice made while shaping tomorrow. Older saves
  /// only have [priority], which remains a standing favorite until the keeper
  /// next uses the top-three planner and turns it into a dated choice.
  String? priorityDay;

  /// One-based place among a dated top three. The rank belongs to
  /// [priorityDay]; older saves without a rank retain their existing list
  /// order and are normalized the next time the night planner is edited.
  int? priorityRank;

  bool priorityOn(DateTime day) =>
      priorityDay == Days.key(day) || (priorityDay == null && priority);

  int priorityRankOn(DateTime day) =>
      priorityOn(day) ? (priorityRank ?? 99) : 99;

  /// All-day abstention quest ("no caffeine after 2pm"): a reminder during
  /// the day, honestly confirmable only in the night routine's checklist.
  final bool allDay;

  /// For daily/weekly quests: restrict to these weekdays (1=Mon..7=Sun).
  /// Empty = every day (daily) / any day (weekly). Mutable: set at adopt-time
  /// by the day picker and editable later (like [difficulty]/[stat]).
  List<int> weekdays;

  /// For monthly quests: the day-of-month it appears (clamped to short
  /// months). Null = any day that month. Mutable (adopt/edit).
  int? monthDay;

  /// Rising difficulty (round-8): authored trainable quests climb over time —
  /// start easy, grow with the user. NOT for maintenance routines.
  final bool rising;

  /// Completions at the current rung. Curated ladders reset this automatically
  /// at [risesAt]; manually-authored ladders may still ask before climbing.
  int risingStreak;

  /// Curated ladders may raise their concrete prescription automatically.
  /// Custom quests default false: arbitrary care or life work must never be
  /// made harder merely because the user kept showing up.
  final bool autoRise;

  /// All-time accepted completions for this specific Quest. This never decays
  /// and drives the same mastery ornament for every goal domain.
  int masteryCompletions;

  /// The concrete progression for a trainable quest — the full prescription at
  /// each rung, e.g. ['Do 2 push-ups', 'Do 5 push-ups', …]. Both the same-day
  /// "Stoke it" encore and the night "RISE" climb this single ladder
  /// (RESEARCH-momentum.md §2). Null = a quest that doesn't climb.
  final List<String>? ladder;

  /// Current index into [ladder]. The night RISE advances this permanently;
  /// difficulty climbs +1 alongside it. Mutable.
  int rung;

  /// Sibling activities toward the same stat/goal — what "Switch it up" offers
  /// (variety dodges reward-habituation + injury; RESEARCH-momentum.md §3).
  /// Null falls back to the per-stat pool in content/ladders.dart.
  final List<String>? kin;

  /// A one-off momentum spawn (a Stoke rung or a Switch variant): banked as a
  /// bonus for today, never a new mandatory baseline. Visually marked ⚡.
  final bool bonus;

  /// Tapping this opens the guided-workout runner instead of completing
  /// directly — the session's outcome then flows through the normal reward
  /// path (RESEARCH-workouts.md). Back-compat: defaults false.
  final bool workout;

  /// A Quest that is completed by writing opens a dedicated, autosaving
  /// Journal page first. Null keeps the ordinary tap-to-complete behavior.
  /// Mutable only so the save loader can enrich already-adopted, authored
  /// Journal quests from schema 19. Product flows do not edit this metadata.
  JournalQuestPrompt? journalPrompt;

  /// For a [bonus] quest: the identity title of the base quest it sprang from
  /// — used to cap same-day encores per base (anti-overexertion, §4).
  final String? origin;

  /// Running log of little timestamped notes the user keeps on this quest
  /// (newest appended last). Mutable, but always replaced wholesale (never
  /// mutated in place) so the `const []` default is safe — see [addNote].
  List<Note> log;

  /// Append a note without mutating the (possibly const) existing list.
  void addNote(String text, DateTime at) => log = log.withNote(text, at);

  /// The most recent note, or null if the log is empty.
  Note? get latestNote => log.isEmpty ? null : log.last;

  static const risesAt = 5;

  QuestMasteryTier get masteryTier => questMasteryTierFor(masteryCompletions);

  /// Bounded current-rung progress for display. Old saves could contain 16/5;
  /// no surface should ever repeat that impossible-looking counter.
  int get riseProgress => risingStreak.clamp(0, risesAt);

  /// Only manual ladders belong in the night-time "ready to rise?" choice.
  bool get readyToRise =>
      rising && !autoRise && canRise && risingStreak >= risesAt;

  /// Has somewhere left to climb on its ladder?
  bool get canRise => ladder != null && rung < ladder!.length - 1;

  /// Record the permanent mastery earned by one real completion and, when the
  /// Quest owns a safe authored ladder, advance exactly one rung at threshold.
  /// Large legacy counters never skip several prescriptions at once.
  QuestProgressChange recordCompletionProgress() {
    final before = masteryCompletions;
    final tierBefore = questMasteryTierFor(before);
    masteryCompletions++;

    String? risenToTitle;
    if (rising && canRise) {
      risingStreak++;
      if (autoRise && risingStreak >= risesAt) {
        rung++;
        difficulty = (difficulty + 1).clamp(1, custom ? 8 : 10);
        risingStreak = 0;
        risenToTitle = displayTitle;
      }
    } else if (!canRise) {
      // A finished ladder is mastery, not an endlessly filling hidden meter.
      risingStreak = 0;
    }

    final after = masteryCompletions;
    return QuestProgressChange(
      completionsBefore: before,
      completionsAfter: after,
      tierBefore: tierBefore,
      tierAfter: questMasteryTierFor(after),
      risenToTitle: risenToTitle,
    );
  }

  bool get isEvent => schedule == QuestSchedule.once && dueDate != null;

  /// What the player actually reads — the current rung's prescription if this
  /// quest climbs, otherwise the plain title.
  String get displayTitle {
    final l = ladder;
    if (l != null && l.isNotEmpty) return l[rung.clamp(0, l.length - 1)];
    return title;
  }

  static final _rungMinutes = RegExp(
    r'(\d+)\s*(?:minutes?|min)\b',
    caseSensitive: false,
  );

  /// Minutes named by the current rung's prescription, if this quest climbs a
  /// ladder whose rungs carry their own session length ('Read 20 minutes').
  int? get _ladderMinutes {
    if (ladder == null) return null;
    final named = _rungMinutes.firstMatch(displayTitle);
    return named == null ? null : int.parse(named.group(1)!);
  }

  /// Countdown length the timer actually runs. When a laddered prescription
  /// names its minutes, the rung owns the length — the visible promise and
  /// the running timer can never disagree. Otherwise the stored
  /// [timerMinutes].
  int get effectiveTimerMinutes => _ladderMinutes ?? timerMinutes;

  /// Whether the ladder, not the stored value, decides the timer length —
  /// Tune hides its minutes control when the rung picker already owns it.
  bool get ladderOwnsTimer =>
      verification == Verification.timer && _ladderMinutes != null;

  /// Is this quest on the board on [d]? (Round-7: quests only appear on
  /// their scheduled days.)
  bool scheduledOn(DateTime d) {
    switch (schedule) {
      case QuestSchedule.once:
        return true; // events are gated by dueDate elsewhere
      case QuestSchedule.daily:
        // A daily restricted to certain weekdays (e.g. a M/W/F habit) appears
        // on exactly those days and resets every day — unchanged.
        return weekdays.isEmpty || weekdays.contains(d.weekday);
      case QuestSchedule.weekly:
        // A weekly's period is the whole WEEK, so an anchored one lingers from
        // its chosen day through the end of that week rather than vanishing the
        // moment its day passes (round-21). Missing your Tuesday slot leaves it
        // quietly open Wed–Sun — "still this week", never a red "missed" scold
        // (never-punish). It resets cleanly next week, before its anchor.
        if (weekdays.isEmpty) return true; // any day this week
        final anchor = weekdays.reduce((a, b) => a < b ? a : b);
        return d.weekday >= anchor;
      case QuestSchedule.monthly:
        if (monthDay == null) return true;
        final lastDay = DateTime(d.year, d.month + 1, 0).day;
        return d.day == (monthDay! > lastDay ? lastDay : monthDay);
    }
  }

  /// Done within the current period (today / this week / this month)?
  bool doneFor(DateTime now) {
    final last = lastDoneDay;
    if (last == null) return false;
    final d = Days.parse(last);
    return switch (schedule) {
      QuestSchedule.once => true,
      QuestSchedule.daily => Days.sameDay(d, now),
      QuestSchedule.weekly => Days.sameWeek(d, now),
      QuestSchedule.monthly => Days.sameMonth(d, now),
    };
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'stat': stat.index,
    'difficulty': difficulty,
    'dread': dread,
    'ladderHint': ladderHint,
    'schedule': schedule.index,
    'verification': verification.index,
    'timerMinutes': timerMinutes,
    'custom': custom,
    'dueDate': dueDate?.toIso8601String(),
    'lastDoneDay': lastDoneDay,
    'snoozedDay': snoozedDay,
    'goalTitle': goalTitle,
    if (goalPlanStepId != null) 'goalPlanStepId': goalPlanStepId,
    if (goalPlanRevision != null) 'goalPlanRevision': goalPlanRevision,
    if (goalPlanAttempt != null) 'goalPlanAttempt': goalPlanAttempt,
    'priority': priority,
    'priorityDay': priorityDay,
    'priorityRank': priorityRank,
    'allDay': allDay,
    'weekdays': weekdays,
    'monthDay': monthDay,
    'rising': rising,
    'risingStreak': risingStreak,
    'autoRise': autoRise,
    'masteryCompletions': masteryCompletions,
    'ladder': ladder,
    'rung': rung,
    'kin': kin,
    'bonus': bonus,
    'origin': origin,
    'workout': workout,
    if (journalPrompt != null) 'journalPrompt': journalPrompt!.toJson(),
    'createdDay': createdDay,
    if (log.isNotEmpty) 'log': [for (final n in log) n.toJson()],
  };

  static Quest fromJson(Map<String, dynamic> j) {
    final custom = j['custom'] as bool? ?? false;
    final rising = j['rising'] as bool? ?? false;
    final ladder = (j['ladder'] as List?)?.cast<String>();
    final autoRise =
        j['autoRise'] as bool? ??
        (!custom && rising && (ladder?.length ?? 0) > 1);
    final rawRung = j['rung'] as int? ?? 0;
    var rung = ladder == null || ladder.isEmpty
        ? 0
        : rawRung.clamp(0, ladder.length - 1);
    final rawRisingStreak = (j['risingStreak'] as int? ?? 0).clamp(0, 1 << 20);
    var risingStreak = rawRisingStreak;
    var difficulty = (j['difficulty'] as int?) ?? 3;
    var masteryCompletions =
        (j['masteryCompletions'] as int? ?? (rising ? rawRisingStreak : 0))
            .clamp(0, 1 << 30);

    final canRise = ladder != null && rung < ladder.length - 1;
    if (autoRise && canRise && risingStreak >= risesAt) {
      // Repair old 16/5-style saves with one safe catch-up, preserving the
      // complete history as mastery without suddenly leaping four rungs.
      rung++;
      difficulty = (difficulty + 1).clamp(1, custom ? 8 : 10);
      risingStreak = 0;
      if (rawRisingStreak > masteryCompletions) {
        masteryCompletions = rawRisingStreak;
      }
    } else if (!canRise) {
      risingStreak = 0;
    } else if (!autoRise) {
      risingStreak = risingStreak.clamp(0, risesAt);
    }

    return Quest(
      title: (j['title'] as String?) ?? 'Quest',
      stat: _enumAt(Stat.values, j['stat'], Stat.dis),
      difficulty: difficulty,
      dread: j['dread'] as bool? ?? false,
      ladderHint: j['ladderHint'] as String?,
      schedule: _enumAt(
        QuestSchedule.values,
        j['schedule'],
        QuestSchedule.daily,
      ),
      verification: _enumAt(
        Verification.values,
        j['verification'],
        Verification.honor,
      ),
      timerMinutes: j['timerMinutes'] as int? ?? 0,
      custom: custom,
      // tryParse, not parse: one drifted value must never reject a whole
      // restore into quarantine (the policy every other timestamp follows)
      dueDate: j['dueDate'] == null
          ? null
          : DateTime.tryParse(j['dueDate'] as String),
      lastDoneDay: Days.validKey(j['lastDoneDay']),
      createdDay: Days.validKey(j['createdDay']),
      snoozedDay: Days.validKey(j['snoozedDay']),
      goalTitle: j['goalTitle'] as String?,
      goalPlanStepId: j['goalPlanStepId'] as String?,
      goalPlanRevision: j['goalPlanRevision'] as int?,
      goalPlanAttempt: j['goalPlanAttempt'] as int?,
      priority: j['priority'] as bool? ?? false,
      priorityDay: Days.validKey(j['priorityDay']),
      priorityRank: switch (j['priorityRank']) {
        final int rank when rank >= 1 && rank <= 3 => rank,
        _ => null,
      },
      allDay: j['allDay'] as bool? ?? false,
      weekdays: ((j['weekdays'] as List?) ?? const []).cast<int>(),
      monthDay: j['monthDay'] as int?,
      rising: rising,
      risingStreak: risingStreak,
      autoRise: autoRise,
      masteryCompletions: masteryCompletions,
      ladder: ladder,
      rung: rung,
      kin: (j['kin'] as List?)?.cast<String>(),
      bonus: j['bonus'] as bool? ?? false,
      origin: j['origin'] as String?,
      workout: j['workout'] as bool? ?? false,
      journalPrompt: JournalQuestPrompt.fromJson(j['journalPrompt']),
      log: [
        for (final e in (j['log'] as List?) ?? const [])
          Note.fromJson((e as Map).cast<String, dynamic>()),
      ],
    );
  }
}

/// Everything one completion produced — drives the reward receipt,
/// with each reward type keeping its own color/sound/haptic.
class RewardBundle {
  RewardBundle({
    required this.xp,
    required this.stat,
    required this.statGain,
    required this.questTitle,
    required this.message,
    required this.difficulty,
    this.embers = 0,
    this.dread = false,
    this.custom = false,
    this.isEvent = false,
    this.goalTitle,
    this.goalPlanStepId,
    this.goalPlanRevision,
    this.critMult,
    this.streakMult,
    this.verifiedMult,
    this.comebackMult,
    this.freezesUsed = 0,
    this.freezeEarned = false,
    this.freezeBalanceAfter = 0,
    this.freezeProgressAfter = 0,
    this.freezeCadenceAfter = 3,
    this.firstOfDay = false,
    this.loot,
    this.hasEvidence = false,
    this.questKey,
    this.masteryCompletionsAfter = 0,
    this.masteryTierReached,
    this.risenToTitle,
  });

  final int xp;
  final Stat stat;
  final int statGain;

  /// Glimmers earned by this completion — the shop currency (round-48: shown in
  /// the receipt so the earn loop is felt, not silent).
  final int embers;

  /// Which quest earned this (for the ledger and the epic overlay).
  final String questTitle;

  /// The personal reward line ("That keeps you sharp :)").
  final String message;

  // Quest facts carried through for achievement counters + goal progress.
  final int difficulty;
  final bool dread;
  final bool custom;
  final bool isEvent;
  final String? goalTitle;
  final String? goalPlanStepId;
  final int? goalPlanRevision;

  /// e.g. 2.3 when a crit rolled, null otherwise.
  final double? critMult;

  /// e.g. 1.4 when a streak bonus applied, null otherwise.
  final double? streakMult;

  /// 1.2 when the completion was proof-verified (timer), null otherwise.
  final double? verifiedMult;

  /// Set when this is the first completion back after a gap — a warm
  /// comeback bonus, never a scold (never-punish; RESEARCH-momentum.md §4).
  final double? comebackMult;

  /// Number of quiet days automatically covered by streak freezes on this
  /// completion. A freeze is only spent when the entire gap can be held.
  final int freezesUsed;

  /// True when this active day completed the ordinary show-up cadence and
  /// banked another freeze. This is intentionally not tied to a perfect day.
  final bool freezeEarned;

  /// Freeze reserve after this completion applies both the held days and any
  /// newly earned freeze. The receipt can therefore tell the exact truth.
  final int freezeBalanceAfter;

  /// Ordinary active-day progress remaining after this completion. Carrying
  /// the value through the staged reward keeps roll and commit identical even
  /// if this quest itself crosses the CARE-40 cadence threshold.
  final int freezeProgressAfter;

  /// Cadence used to compute [freezeProgressAfter]. This closes the last seam
  /// between a staged roll and a commit that itself crosses CARE 40.
  final int freezeCadenceAfter;

  /// Compatibility name for the existing completion motion path.
  bool get shieldHeld => freezesUsed > 0;

  /// The day's FIRST completion — gets a notch-brighter beat ("first ember
  /// lit today"). One step above a normal completion, never a takeover.
  final bool firstOfDay;

  /// The fire was genuinely cold before this completion: either this is the
  /// keep's first-ever spark, or the player has returned after a real gap.
  /// A normal first completion on the next day continues an existing fire and
  /// should not replay the larger ignition beat.
  bool get revivesHearth =>
      comebackMult != null || (firstOfDay && streakMult == null);

  /// Loot drop name, null when nothing dropped.
  final String? loot;

  /// True when an unread evidence card is available for this completion's
  /// stat — the receipt's +Stat bubble shimmers and is tappable (DESIGN §5).
  final bool hasEvidence;

  /// Stable quest identity title (for same-day anti-grind counts).
  final String? questKey;

  /// Permanent, category-neutral Quest mastery after this completion.
  final int masteryCompletionsAfter;

  /// Non-null only when this completion crossed a visible mastery threshold.
  final QuestMasteryTier? masteryTierReached;

  /// The new concrete prescription when an authored ladder rose automatically.
  final String? risenToTitle;

  /// 0..1 celebration magnitude — parameterizes particle count, sound
  /// layers, vibrancy (one celebration system, scaled — DESIGN.md §2).
  double get magnitude {
    var m = 0.25 + (xp / 200).clamp(0.0, 0.35);
    if (critMult != null) m += 0.25;
    if (loot != null) m += 0.15;
    if (firstOfDay) m += 0.15; // the day's first ember burns a little brighter
    return m.clamp(0.0, 1.0);
  }
}

/// One line of the Me page's attribution ledger ("+10 STR — Workout").
class LedgerEntry {
  LedgerEntry({required this.stat, required this.amount, required this.title});
  final Stat stat;
  final int amount;
  final String title;

  Map<String, dynamic> toJson() => {
    'stat': stat.index,
    'amount': amount,
    'title': title,
  };

  static LedgerEntry fromJson(Map<String, dynamic> j) => LedgerEntry(
    stat: _enumAt(Stat.values, j['stat'], Stat.dis),
    amount: (j['amount'] as int?) ?? 0,
    title: (j['title'] as String?) ?? '',
  );
}

/// Result of applying XP to the level model.
class LevelResult {
  LevelResult({required this.leveledTo, required this.unlock});

  /// Null when no level-up happened.
  final int? leveledTo;

  /// The unlock revealed at this level, if any.
  final String? unlock;
}
