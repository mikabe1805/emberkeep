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
  static String key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static DateTime parse(String key) {
    final p = key.split('-');
    return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
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
      };

  static Goal fromJson(Map<String, dynamic> j) {
    final kind = _enumAt(GoalKind.values, j['kind'], GoalKind.become);
    final target = (j['target'] as int?) ?? 25;
    var milestones = j['milestones'] as int? ?? 0;
    // Back-fill for pre-round-20 saves (no `milestones` key): a BECOME goal
    // always starts at 25 and only doubles, so target == 25 * 2^n — recover the
    // count so the detail ring/caption/tile read truthfully. Never recompute
    // when the key is present (that's a real, possibly-mid-tier saved value).
    if (!j.containsKey('milestones') && kind == GoalKind.become && target > 25) {
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
      achievedDay: j['achievedDay'] as String?,
      startedDay: j['startedDay'] as String?,
      milestones: milestones,
      notes: [
        for (final e in (j['notes'] as List?) ?? const [])
          Note.fromJson((e as Map).cast<String, dynamic>())
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
class Note {
  Note({required this.at, required this.text, this.context});

  /// When the note was written (full timestamp — finer than a day).
  final DateTime at;
  final String text;

  /// A tiny "where I was" marker captured at write time — e.g. a domain's rank
  /// ("Frail") or a goal's standing ("milestone 2"). Lets a journal show proof
  /// of becoming ("written when CARE was Frail — now Vital"), the payoff that
  /// makes notes-with-consequence felt rather than described. Null for plain
  /// quest logs.
  final String? context;

  Map<String, dynamic> toJson() => {
        'at': at.toIso8601String(),
        'text': text,
        if (context != null) 'context': context,
      };

  static Note fromJson(Map<String, dynamic> j) => Note(
        // a drifted/missing timestamp sorts to the epoch rather than throwing
        // (round-9 restore resilience), never rejecting the whole save.
        at: DateTime.tryParse(j['at'] as String? ?? '') ?? DateTime(2000),
        text: (j['text'] as String?) ?? '',
        context: j['context'] as String?,
      );
}

/// Shared helpers for a list of [Note]s held by an owner (quest/goal/domain).
/// Lists are always replaced wholesale (never mutated in place) so a `const []`
/// default is safe to share across instances.
extension NoteList on List<Note> {
  List<Note> withNote(String text, DateTime at, {String? context}) =>
      [...this, Note(at: at, text: text, context: context)];
  List<Note> without(Note n) => where((e) => e != n).toList();
}

/// Which surface a room style repaints — walls or the floor (round-46, room
/// customization). Lives here (not content/) so the engine can take it without
/// a content→engine→content import cycle.
enum RoomStyleKind { wall, floor }

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
    this.priority = false,
    this.allDay = false,
    this.weekdays = const [],
    this.monthDay,
    this.rising = false,
    this.risingStreak = 0,
    this.ladder,
    this.rung = 0,
    this.kin,
    this.bonus = false,
    this.origin,
    this.workout = false,
    this.log = const [],
  });

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

  /// Countdown length for timer-verified quests.
  final int timerMinutes;

  /// User-forged quests pay ×0.85 — honesty keeps the magic.
  final bool custom;

  /// Calendar events / long-term goals: when this is due.
  final DateTime? dueDate;

  /// Day-key of the last completion — drives period-based resets.
  String? lastDoneDay;

  /// Day-key this quest was hidden "just for today" — a gentle skip that
  /// returns it to the board tomorrow (distinct from a permanent removal).
  /// Mutable: set from the long-press manage sheet.
  String? snoozedDay;

  /// Which user goal this quest feeds (matched by goal title). Mutable so the
  /// oath wizard can re-stamp it if the goal's name/domain changes before the
  /// oath is sworn.
  String? goalTitle;

  /// Starred as a MAIN quest (set in the night planner; the morning
  /// briefing leads with these).
  bool priority;

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

  /// Rising difficulty (round-8): training quests climb over time —
  /// start easy, grow with the user. NOT for maintenance routines.
  final bool rising;

  /// Completions since the last rise; at [risesAt] the night routine asks
  /// "ready to rise?".
  int risingStreak;

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
  bool get readyToRise => rising && risingStreak >= risesAt;

  /// Has somewhere left to climb on its ladder?
  bool get canRise => ladder != null && rung < ladder!.length - 1;

  bool get isEvent => schedule == QuestSchedule.once && dueDate != null;

  /// What the player actually reads — the current rung's prescription if this
  /// quest climbs, otherwise the plain title.
  String get displayTitle {
    final l = ladder;
    if (l != null && l.isNotEmpty) return l[rung.clamp(0, l.length - 1)];
    return title;
  }

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
        'priority': priority,
        'allDay': allDay,
        'weekdays': weekdays,
        'monthDay': monthDay,
        'rising': rising,
        'risingStreak': risingStreak,
        'ladder': ladder,
        'rung': rung,
        'kin': kin,
        'bonus': bonus,
        'origin': origin,
        'workout': workout,
        if (log.isNotEmpty) 'log': [for (final n in log) n.toJson()],
      };

  static Quest fromJson(Map<String, dynamic> j) => Quest(
        title: (j['title'] as String?) ?? 'Quest',
        stat: _enumAt(Stat.values, j['stat'], Stat.dis),
        difficulty: (j['difficulty'] as int?) ?? 3,
        dread: j['dread'] as bool? ?? false,
        ladderHint: j['ladderHint'] as String?,
        schedule:
            _enumAt(QuestSchedule.values, j['schedule'], QuestSchedule.daily),
        verification:
            _enumAt(Verification.values, j['verification'], Verification.honor),
        timerMinutes: j['timerMinutes'] as int? ?? 0,
        custom: j['custom'] as bool? ?? false,
        dueDate: j['dueDate'] == null
            ? null
            : DateTime.parse(j['dueDate'] as String),
        lastDoneDay: j['lastDoneDay'] as String?,
        snoozedDay: j['snoozedDay'] as String?,
        goalTitle: j['goalTitle'] as String?,
        priority: j['priority'] as bool? ?? false,
        allDay: j['allDay'] as bool? ?? false,
        weekdays: ((j['weekdays'] as List?) ?? const []).cast<int>(),
        monthDay: j['monthDay'] as int?,
        rising: j['rising'] as bool? ?? false,
        risingStreak: j['risingStreak'] as int? ?? 0,
        ladder: (j['ladder'] as List?)?.cast<String>(),
        rung: j['rung'] as int? ?? 0,
        kin: (j['kin'] as List?)?.cast<String>(),
        bonus: j['bonus'] as bool? ?? false,
        origin: j['origin'] as String?,
        workout: j['workout'] as bool? ?? false,
        log: [
          for (final e in (j['log'] as List?) ?? const [])
            Note.fromJson((e as Map).cast<String, dynamic>())
        ],
      );
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
    this.critMult,
    this.streakMult,
    this.verifiedMult,
    this.comebackMult,
    this.shieldHeld = false,
    this.firstOfDay = false,
    this.loot,
  });

  final int xp;
  final Stat stat;
  final int statGain;

  /// Embers earned by this completion — the shop currency (round-48: shown in
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

  /// e.g. 2.3 when a crit rolled, null otherwise.
  final double? critMult;

  /// e.g. 1.4 when a streak bonus applied, null otherwise.
  final double? streakMult;

  /// 1.2 when the completion was proof-verified (timer), null otherwise.
  final double? verifiedMult;

  /// Set when this is the first completion back after a missed day — a warm
  /// comeback bonus, never a scold (never-punish; RESEARCH-momentum.md §4).
  final double? comebackMult;

  /// True when a streak shield silently bridged a missed day to keep the
  /// streak alive — the completion celebrates "streak safe", not a reset.
  final bool shieldHeld;

  /// The day's FIRST completion — gets a notch-brighter beat ("first ember
  /// lit today"). One step above a normal completion, never a takeover.
  final bool firstOfDay;

  /// Loot drop name, null when nothing dropped.
  final String? loot;

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

  Map<String, dynamic> toJson() =>
      {'stat': stat.index, 'amount': amount, 'title': title};

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
