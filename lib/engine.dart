import 'dart:math';

import 'package:flutter/foundation.dart';

import 'clock.dart';
import 'content/achievements.dart';
import 'content/cosmetics.dart';
import 'content/messages.dart';
import 'content/stat_ranks.dart';
import 'content/titles.dart';
import 'models.dart';
import 'tokens.dart';

/// The game engine. XP = base × difficulty × dread × streak × proof × crit
/// (RESEARCH.md §5). Persisted via toJson/fromJson; period resets happen in
/// [rollover].
class GameState extends ChangeNotifier {
  GameState({Random? rng}) : _rng = rng ?? Random();

  final Random _rng;

  /// What the keeper of this fire is called (set in onboarding; greetings
  /// use it). Null = not given.
  String? playerName;

  /// First-run welcome completed?
  bool onboarded = false;

  /// Opt-in "one quest at a time" Focus mode (round-21): collapses the board
  /// to a single suggested quest to fight overwhelm. Default off (full board).
  bool focusMode = false;

  void setFocusMode(bool v) {
    if (focusMode == v) return;
    focusMode = v;
    notifyListeners();
  }

  /// Local-reminder prefs (round-22). Native-only — the scheduling no-ops on
  /// web (see notifications.dart). Default off; default nudge at 9:00am.
  bool notifyEnabled = false;
  int notifyHour = 9;
  int notifyMinute = 0;

  void setNotify({bool? enabled, int? hour, int? minute}) {
    if (enabled != null) notifyEnabled = enabled;
    if (hour != null) notifyHour = hour;
    if (minute != null) notifyMinute = minute;
    notifyListeners();
  }

  /// Wall-clock ms of the last save — the "newness" signal cloud sync uses
  /// to decide which copy wins (a stale device must never clobber a newer
  /// cloud save). Stamped by the shell on every persist.
  int lastModified = 0;

  int level = 1;
  int xp = 0;
  int totalXp = 0;
  final Map<Stat, int> stats = {for (final s in Stat.values) s: 0};

  /// Per-domain journal — notes the user keeps on a whole life domain (their
  /// "base" for Home, Care, Craft…). Sparse: only domains with entries appear.
  /// Lists are replaced wholesale (see [NoteList]) so callers never mutate in
  /// place. The keystone of notes-with-consequence (round-24): a domain page
  /// gathers its notes + the quests serving it + its growth in one place.
  final Map<Stat, List<Note>> domainNotes = {};

  List<Note> notesFor(Stat s) => domainNotes[s] ?? const [];
  void setDomainNotes(Stat s, List<Note> notes) {
    if (notes.isEmpty) {
      domainNotes.remove(s);
    } else {
      domainNotes[s] = notes;
    }
    notifyListeners();
  }

  /// Recent gains, newest first — the Me page's attribution ledger.
  final List<LedgerEntry> ledger = [];

  // ── streak (real now: consecutive days with ≥1 completion) ──────
  int streakDays = 0;
  int bestStreak = 0;
  String? lastCompletionDay;

  /// Streak shields — the Lv-6 unlock, finally real. Each one quietly bridges
  /// a single missed day so a long streak survives one bad day (never-punish;
  /// RESEARCH-momentum.md §7). Granted at the unlock and earned on perfect days.
  int streakShields = 0;
  bool shieldUnlockGranted = false;
  static const maxShields = 5;

  // ── achievement counters ─────────────────────────────────────────
  int totalCompletions = 0;
  int verifiedCompletions = 0;
  int dreadCompletions = 0;
  int epicCompletions = 0;
  int eventCompletions = 0;
  int customCompletions = 0;
  int comebacks = 0; // returns after a missed day
  int dawnCompletions = 0; // before 8am
  int duskCompletions = 0; // 9pm or later
  int perfectDays = 0; // days every due quest was cleared
  String? lastPerfectDay;
  final Set<String> unlockedAchievements = {};

  /// Default starter quests the user deliberately removed — refresh must not
  /// resurrect these (lowercased titles).
  final Set<String> removedDefaults = {};

  /// Cosmetic fragments found in the embers (loot drops). Honest now: a drop
  /// is actually kept and shown on the Me page, not announced-then-vanished.
  final Set<String> collectedLoot = {};

  /// The currently-worn cosmetic (a name from [collectedLoot]); null = the
  /// default dominant-stat look. Recolors the portrait aura + completion
  /// sparks (see content/cosmetics.dart). Toggle with [equipSkin].
  String? equippedSkin;

  /// Equip a found cosmetic, or unequip it if it's already worn. notify
  /// triggers the shell's persist listener.
  void equipSkin(String name) {
    if (!collectedLoot.contains(name)) return;
    equippedSkin = equippedSkin == name ? null : name;
    notifyListeners();
  }

  /// Evidence cards the reader has already seen surfaced as relevant — so the
  /// Sparks feed can flag a genuinely NEW card the first time it matters
  /// (after a relevant rank-up). Persisted.
  final Set<String> seenEvidence = {};

  void markEvidenceSeen(Iterable<String> titles) {
    final before = seenEvidence.length;
    seenEvidence.addAll(titles);
    if (seenEvidence.length != before) notifyListeners();
  }

  /// The chosen candlelit canvas theme (id from content/themes.dart); the
  /// non-default ones open at the Lv-5 THEMES unlock. Persisted.
  String canvasTheme = 'walnut';

  void setTheme(String id) {
    if (canvasTheme == id) return;
    canvasTheme = id;
    notifyListeners();
  }

  /// dateKey → completions that day (calendar history dots).
  final Map<String, int> history = {};

  String? lastActiveDay;

  // ── user goals (quests feed them via goalTitle) ─────────────────
  final List<Goal> goals = [];

  // Celebration queues (FIFO). Each commit may produce a goal-achieved, a
  // milestone, and/or a rank-up; the UI consumes them later, asynchronously,
  // once per completion's overlay chain. These are QUEUES (not single slots)
  // so a rapid second completion can't overwrite or drop the first's pending
  // celebration — each chain pops the oldest in arrival order (bug-hunt §12/§15).

  /// ACHIEVE goals that just crossed the finish line, awaiting their takeover.
  final List<Goal> _achievedQ = [];
  Goal? takeJustAchieved() => _achievedQ.isEmpty ? null : _achievedQ.removeAt(0);

  /// BECOME-goal milestones reached (carries the milestone value).
  final List<(Goal, int)> _milestonedQ = [];
  (Goal, int)? takeJustMilestoned() =>
      _milestonedQ.isEmpty ? null : _milestonedQ.removeAt(0);

  /// Stat rank-tier crossings, awaiting the "WHY THIS WORKS" evidence beat.
  final List<(Stat, StatRank)> _rankedUpQ = [];
  (Stat, StatRank)? takeJustRankedUp() =>
      _rankedUpQ.isEmpty ? null : _rankedUpQ.removeAt(0);

  // ── today's haul (the night recap's raw material; reset on rollover) ──
  int todayXp = 0;
  final Map<Stat, int> todayStats = {};
  final List<String> todayQuestTitles = [];

  // ── routine day-stamps ──────────────────────────────────────────
  String? nightDoneDay;
  String? morningDoneDay;

  /// A morning briefing is "armed" the moment you close out a night, and
  /// disarmed once you've seen it — sleep-cycle based, not calendar based, so
  /// a 3am wind-down still earns a morning a few hours later (user report).
  bool morningArmed = false;

  /// Wall-clock ms the night routine was closed (drives the wake-up gap).
  int nightDoneAt = 0;

  /// Minimum gap before the morning AUTO-shows — long enough that closing the
  /// night at 3am doesn't instantly re-pop, but short enough to greet you when
  /// you wake a few hours later the same calendar day.
  static const _morningGapMs = 4 * 60 * 60 * 1000;

  /// Closing the night arms tomorrow morning's briefing.
  void closeNight() {
    final now = Clock.now();
    nightDoneDay = Days.key(now);
    nightDoneAt = now.millisecondsSinceEpoch;
    morningArmed = true;
    notifyListeners();
  }

  /// Seeing the morning briefing disarms it.
  void closeMorning() {
    morningDoneDay = Days.key(Clock.now());
    morningArmed = false;
    notifyListeners();
  }

  /// Day-key the "Today's Spark" greeting was dismissed — so the cold-open
  /// delight shows once per day, never nags (RESEARCH §3 / scout pick #1).
  String? sparkSeenDay;

  /// Morning briefing AUTO-shows once a night is armed AND enough time has
  /// passed since you wound down that you've plausibly slept — so a 3am night
  /// still earns a morning when you wake, and closing the night at 3am doesn't
  /// instantly re-pop it. (nightDoneAt == 0 → an older save, gap assumed met.)
  bool get morningPending =>
      morningArmed &&
      (nightDoneAt == 0 ||
          Clock.now().millisecondsSinceEpoch - nightDoneAt >= _morningGapMs);

  /// The briefing is REACHABLE (a visible button/prompt) the whole time it's
  /// armed — so even before the gap, or after a missed auto-show, there's a
  /// way in.
  bool get morningAvailable => morningArmed;

  /// Your strongest trained stat — colors the portrait's aura. Null until
  /// something is trained.
  Stat? get dominantStat {
    Stat? best;
    var bestV = 0;
    for (final e in stats.entries) {
      if (e.value > bestV) {
        bestV = e.value;
        best = e.key;
      }
    }
    return best;
  }

  /// Your build's name — top two stats, silly but earnest; gains a rank
  /// epithet as your top stat climbs (scout pick #5).
  String get buildTitle => BuildTitles.epithetOf(stats);

  /// The dominant stat IF it's reached a real rank (tier ≥ 3) — drives the
  /// portrait's build-trait flourish. Null otherwise (room to grow, no flair).
  Stat? get portraitTrait {
    final s = dominantStat;
    if (s == null) return null;
    return rankFor(s, stats[s] ?? 0).tier >= 3 ? s : null;
  }

  /// Unlock ladder: level → unlock name. Every level-up reveals the next
  /// one by name (anticipation is free retention).
  static const unlocks = <int, String>{
    2: 'STAT DETAILS',
    3: 'CHARACTER SHEET',
    4: 'EVIDENCE ARCHIVE',
    5: 'THEMES',
    6: 'STREAK SHIELDS',
  };

  /// Rising XP-per-level curve; level 2 lands in the first session.
  int xpNeeded(int forLevel) => 60 + (forLevel - 1) * 45;

  String? nextUnlockLabel() {
    final next = unlocks.keys
        .where((l) => l > level)
        .fold<int?>(null, (a, b) => a == null || b < a ? b : a);
    return next == null ? null : 'Lv $next · ${unlocks[next]}';
  }

  /// Always-present forward carrot for the HUD: the next feature unlock while
  /// any remain, otherwise the nearest stat rank-up — so there's never a
  /// "nothing left to chase" gap past level 6 (RESEARCH-momentum.md §7).
  String? nextChaseLabel() {
    final unlock = nextUnlockLabel();
    if (unlock != null) return unlock;
    // nearest stat rank-up across all six stats
    String? best;
    var bestGap = 1 << 30;
    for (final s in Stat.values) {
      final v = stats[s] ?? 0;
      final gap = toNextTier(v);
      if (gap != null && gap < bestGap) {
        bestGap = gap;
        best = '+$gap ${s.abbr} → ${rankFor(s, v + gap).label}';
      }
    }
    return best;
  }

  /// Streak multiplier for an arbitrary day count — ramps 1.0 → 1.5 over 7
  /// days, caps at 2.0 (day 30).
  double streakMultFor(int days) {
    if (days <= 0) return 1.0;
    if (days <= 7) return 1.0 + 0.5 * days / 7;
    return min(2.0, 1.5 + 0.5 * (days - 7) / 23);
  }

  double get streakMult => streakMultFor(streakDays);

  /// How this completion sits against the streak: is there a gap since the
  /// last active day, how many days were missed, and can shields bridge it?
  /// Read identically by [roll] (for messaging) and [commit] (to apply) —
  /// both run before lastCompletionDay is bumped, so they agree.
  ({bool gap, int missed, bool covered}) _streakSituation() {
    final last = lastCompletionDay;
    final now = Clock.now();
    if (last == null || last == Days.key(now)) {
      return (gap: false, missed: 0, covered: false);
    }
    final d = Days.parse(last);
    final missed = DateTime(now.year, now.month, now.day)
            .difference(DateTime(d.year, d.month, d.day))
            .inDays -
        1;
    if (missed <= 0) return (gap: false, missed: 0, covered: false);
    return (gap: true, missed: missed, covered: streakShields >= missed);
  }

  /// Verified completions (timer proof) pay ×1.2 — proof multiplies,
  /// never gates (RESEARCH.md §5).
  static const verifiedBonus = 1.2;

  /// Custom (user-forged) quests pay ×0.85 — anti-abuse damping; honesty
  /// keeps the magic (DESIGN.md round-3).
  static const customDamp = 0.85;

  /// First completion back after a missed day pays ×1.5 — the fragile
  /// re-engagement moment is rewarded, never scolded (RESEARCH-momentum.md §4).
  static const comebackBonus = 1.5;

  /// Pure roll: computes the reward and marks the quest done for its
  /// period, but does NOT mutate xp/stats — [commit] does that later so the
  /// bar fill and chip pulses can be staged after the reward receipt.
  RewardBundle roll(Quest q, {bool verified = false}) {
    final now = Clock.now();
    final nowKey = Days.key(now);
    // How a gap (if any) resolves: a shield bridges it silently, otherwise
    // it's a true lapse and the return earns a warm comeback bonus. Read
    // before we stamp anything (mirrors [commit]'s decision).
    final sit = _streakSituation();
    final shieldHeld = sit.gap && sit.covered;
    final isComeback = sit.gap && !sit.covered;
    // the FIRST completion of the day (no completion committed yet today)
    final firstOfDay = lastCompletionDay != nowKey;

    q.lastDoneDay = nowKey;
    if (q.rising) q.risingStreak++;

    // A comeback resets the streak to 1 in commit — pay this completion at the
    // POST-reset multiplier, not the stale lapsed streak (else a broken 30-day
    // streak pays ×2.0 stacked with the comeback bonus; bug-hunt §10).
    final effStreakMult = isComeback ? streakMultFor(1) : streakMult;
    // Base scales with continuous difficulty: d1 ≈ 0.6×, d10 ≈ 3×.
    final base = 10 * (0.5 + q.difficulty * 0.25);
    var earned = base * effStreakMult;
    if (q.dread) earned *= 1.35;
    if (q.custom) earned *= customDamp;
    if (verified) earned *= verifiedBonus;
    if (isComeback) earned *= comebackBonus;

    // Critical hit: ~3% chance, ×1.5–×3, always announced with the roll.
    double? crit;
    if (_rng.nextDouble() < 0.03) {
      crit = 1.5 + _rng.nextDouble() * 1.5;
      earned *= crit;
    }

    // Loot: a common/rare skin drop (~18%); legendaries are earned, not dropped.
    String? loot;
    if (_rng.nextDouble() < 0.18) {
      loot = droppableLoot[_rng.nextInt(droppableLoot.length)];
    }

    // anti-abuse damp covers stats too — they drive the aura/title/radar
    var gain = q.difficulty * 1.5;
    if (q.custom) gain *= customDamp;

    return RewardBundle(
      xp: earned.round(),
      stat: q.stat,
      statGain: gain.round() + (q.dread ? 3 : 0),
      questTitle: q.displayTitle,
      message: RewardMessages.pick(q.stat, _rng,
          hour: now.hour,
          dread: q.dread,
          countToday: (history[nowKey] ?? 0) + 1,
          comeback: isComeback),
      difficulty: q.difficulty,
      dread: q.dread,
      custom: q.custom,
      isEvent: q.isEvent,
      goalTitle: q.goalTitle,
      critMult: crit,
      // report the multiplier actually applied (post-reset on a comeback)
      streakMult: isComeback
          ? effStreakMult
          : (streakDays > 0 ? streakMult : null),
      verifiedMult: verified ? verifiedBonus : null,
      comebackMult: isComeback ? comebackBonus : null,
      shieldHeld: shieldHeld,
      firstOfDay: firstOfDay,
      loot: loot,
    );
  }

  /// XP a quest will pay (sans crit luck) — shown on the card so the reward
  /// IS the difficulty signal (DESIGN.md §11.4). Advertises the BASE
  /// (honor) payout — the ×1.2 is the timer's upside, not a promise.
  int xpPreview(Quest q) {
    var earned = 10 * (0.5 + q.difficulty * 0.25) * streakMult;
    if (q.dread) earned *= 1.35;
    if (q.custom) earned *= customDamp;
    return earned.round();
  }

  /// Applies a rolled bundle to xp/stats/streak/counters — the moment the
  /// bar fills and the stat chip pulses.
  void commit(RewardBundle b) {
    xp += b.xp;
    totalXp += b.xp;
    // stat gain, watching for a rank-tier crossing (fires the evidence beat)
    final beforeRank = rankFor(b.stat, stats[b.stat]!);
    stats[b.stat] = stats[b.stat]! + b.statGain;
    final afterRank = rankFor(b.stat, stats[b.stat]!);
    if (afterRank.tier > beforeRank.tier) {
      _rankedUpQ.add((b.stat, afterRank));
    }
    ledger.insert(
        0, LedgerEntry(stat: b.stat, amount: b.statGain, title: b.questTitle));
    if (ledger.length > 8) ledger.removeLast();

    // streak: consecutive days with at least one completion — a shield
    // bridges a missed day so a long run survives one bad day (never-punish)
    final now = Clock.now();
    final today = Days.key(now);
    if (lastCompletionDay != today) {
      final sit = _streakSituation();
      if (!sit.gap) {
        streakDays += 1; // first ever, or yesterday → continues
      } else if (sit.covered) {
        streakShields -= sit.missed; // shield(s) hold the line
        streakDays += 1;
      } else {
        comebacks++; // a real lapse — reset, but the return is celebrated
        streakDays = 1;
      }
      lastCompletionDay = today;
    }
    if (streakDays > bestStreak) bestStreak = streakDays;

    // time-of-day flair
    if (now.hour < 8) dawnCompletions++;
    if (now.hour >= 21) duskCompletions++;

    // a found cosmetic fragment is actually kept now (honest loot)
    if (b.loot != null) collectedLoot.add(b.loot!);

    // counters + calendar history
    totalCompletions++;
    if (b.verifiedMult != null) verifiedCompletions++;
    if (b.dread) dreadCompletions++;
    if (b.difficulty >= 7) epicCompletions++;
    if (b.isEvent) eventCompletions++;
    if (b.custom) customCompletions++;
    history[today] = (history[today] ?? 0) + 1;

    // today's haul (night recap)
    todayXp += b.xp;
    todayStats[b.stat] = (todayStats[b.stat] ?? 0) + b.statGain;
    todayQuestTitles.add(b.questTitle);

    // goal progress: linked completions inch the bar toward full
    if (b.goalTitle != null) {
      for (final g in goals) {
        if (g.title == b.goalTitle && !g.complete) {
          g.progress++;
          if (g.progress >= g.target) {
            if (g.kind == GoalKind.achieve) {
              // finish line crossed — celebrate, then it rests in honor
              g.achievedDay = today;
              _achievedQ.add(g);
            } else {
              // ongoing practice: milestone reached, the path continues
              _milestonedQ.add((g, g.target));
              g.target *= 2;
              g.milestones++;
            }
          }
          break;
        }
      }
    }
    // trim history to 180 days — never evict TODAY's just-written entry (guards
    // a backward clock / future-dated restore from deleting it; bug-hunt §14)
    if (history.length > 180) {
      final keys = (history.keys.toList()..sort())
          .where((k) => k != today)
          .toList();
      if (keys.isNotEmpty) history.remove(keys.first);
    }

    notifyListeners();
  }

  /// Evaluates achievement conditions; returns the newly unlocked ones.
  /// Idempotent — call after commits and after level-ups.
  List<Achievement> checkAchievements() {
    final newly = <Achievement>[];
    for (final a in achievements) {
      if (!unlockedAchievements.contains(a.id) && a.test(this)) {
        unlockedAchievements.add(a.id);
        // a signature achievement hands you its exclusive legendary skin
        if (a.cosmetic != null) collectedLoot.add(a.cosmetic!);
        newly.add(a);
      }
    }
    if (newly.isNotEmpty) notifyListeners();
    return newly;
  }

  /// Consume XP into level-ups. Overflow always carries (no wasted
  /// progress). Returns the highest level reached this application, if any.
  /// Deliberately does NOT notify — the UI reveals the pour on its own
  /// schedule (DESIGN.md §6).
  LevelResult applyLevelUps() {
    int? reached;
    while (xp >= xpNeeded(level + 1)) {
      xp -= xpNeeded(level + 1);
      level++;
      reached = level;
    }
    // the STREAK SHIELDS unlock (Lv 6) actually hands you shields now
    if (level >= 6 && !shieldUnlockGranted) {
      shieldUnlockGranted = true;
      streakShields = (streakShields + 2).clamp(0, maxShields);
    }
    return LevelResult(leveledTo: reached, unlock: unlocks[reached]);
  }

  /// Day rollover: drops completed one-time quests from past days and
  /// stamps the active day. Recurring quests reset implicitly — their
  /// doneFor() recomputes against the new period. Returns true if the
  /// active day changed.
  bool rollover(List<Quest> quests) {
    final now = Clock.now();
    final today = Days.key(now);
    final changed = lastActiveDay != today;
    final startOfToday = DateTime(now.year, now.month, now.day);
    quests.removeWhere((q) =>
        q.schedule == QuestSchedule.once &&
        q.lastDoneDay != null &&
        q.lastDoneDay != today);
    // momentum bonuses are a today-only gift — an unfinished one quietly
    // expires at dawn rather than lingering as an "overdue" obligation.
    quests.removeWhere((q) =>
        q.bonus &&
        q.dueDate != null &&
        q.dueDate!.isBefore(startOfToday));
    if (changed) {
      todayXp = 0;
      todayStats.clear();
      todayQuestTitles.clear();
    }
    lastActiveDay = today;
    return changed;
  }

  /// A warm one-line recap of the day just cleared — which life domains you
  /// tended, reflected back so the peak-end is personal (round-32). Ranked by
  /// how much each domain got today.
  String todaysShape() {
    final worked = Stat.values.where((s) => (todayStats[s] ?? 0) > 0).toList()
      ..sort((a, b) => (todayStats[b] ?? 0).compareTo(todayStats[a] ?? 0));
    final n = todayQuestTitles.length;
    final plural = n == 1 ? 'quest' : 'quests';
    if (worked.isEmpty) return 'A day cleared — every ember you light counts.';
    if (worked.length == 1) {
      return 'You poured today into ${worked.first.label} — '
          '$n $plural, all in one direction.';
    }
    if (worked.length == 2) {
      return 'You tended ${worked[0].label} and ${worked[1].label} today — '
          '$n $plural, a balanced day.';
    }
    return 'You moved across ${worked.length} parts of your life today — '
        '$n $plural, a full and varied day.';
  }

  /// Adds a goal; refuses duplicate titles.
  bool addGoal(Goal g) {
    final key = g.title.trim().toLowerCase();
    if (goals.any((e) => e.title.trim().toLowerCase() == key)) return false;
    g.startedDay ??= Days.key(Clock.now()); // for "days on the journey"
    goals.add(g);
    notifyListeners();
    return true;
  }

  /// Abandons a goal. Caller also removes its linked quests.
  void removeGoal(Goal g) {
    goals.remove(g);
    notifyListeners();
  }

  /// Records a perfect day — every due quest cleared — at most once per day,
  /// and only if at least one quest was actually completed today.
  void recordPerfectDay() {
    final today = Days.key(Clock.now());
    if (lastPerfectDay == today || (history[today] ?? 0) < 1) return;
    lastPerfectDay = today;
    perfectDays++;
    // once shields are unlocked, a perfect day forges one (capped) — a
    // reason to clear the whole board, and a buffer for the day you can't
    if (shieldUnlockGranted && streakShields < maxShields) streakShields++;
    notifyListeners();
  }

  // ── persistence ──────────────────────────────────────────────────
  Map<String, dynamic> toJson() => {
        'playerName': playerName,
        'onboarded': onboarded,
        'focusMode': focusMode,
        'notifyEnabled': notifyEnabled,
        'notifyHour': notifyHour,
        'notifyMinute': notifyMinute,
        'lastModified': lastModified,
        'level': level,
        'xp': xp,
        'totalXp': totalXp,
        'stats': [for (final s in Stat.values) stats[s] ?? 0],
        // per-domain notes, by Stat order (parallel to 'stats'); empty lists
        // for domains with nothing kept, so a restore maps cleanly by index.
        'domainNotes': [
          for (final s in Stat.values)
            [for (final n in domainNotes[s] ?? const []) n.toJson()]
        ],
        'ledger': [for (final e in ledger) e.toJson()],
        'streakDays': streakDays,
        'bestStreak': bestStreak,
        'streakShields': streakShields,
        'shieldUnlockGranted': shieldUnlockGranted,
        'lastCompletionDay': lastCompletionDay,
        'lastActiveDay': lastActiveDay,
        'totalCompletions': totalCompletions,
        'verifiedCompletions': verifiedCompletions,
        'dreadCompletions': dreadCompletions,
        'epicCompletions': epicCompletions,
        'eventCompletions': eventCompletions,
        'customCompletions': customCompletions,
        'comebacks': comebacks,
        'dawnCompletions': dawnCompletions,
        'duskCompletions': duskCompletions,
        'perfectDays': perfectDays,
        'lastPerfectDay': lastPerfectDay,
        'removedDefaults': removedDefaults.toList(),
        'collectedLoot': collectedLoot.toList(),
        'equippedSkin': equippedSkin,
        'seenEvidence': seenEvidence.toList(),
        'canvasTheme': canvasTheme,
        'unlockedAchievements': unlockedAchievements.toList(),
        'history': history,
        'goals': [for (final g in goals) g.toJson()],
        'todayXp': todayXp,
        'todayStats': [for (final s in Stat.values) todayStats[s] ?? 0],
        'todayQuestTitles': todayQuestTitles,
        'nightDoneDay': nightDoneDay,
        'morningDoneDay': morningDoneDay,
        'morningArmed': morningArmed,
        'nightDoneAt': nightDoneAt,
        'sparkSeenDay': sparkSeenDay,
      };

  static GameState fromJson(Map<String, dynamic> j) {
    final s = GameState();
    s.playerName = j['playerName'] as String?;
    s.onboarded = j['onboarded'] as bool? ?? true; // pre-existing saves skip
    s.focusMode = j['focusMode'] as bool? ?? false;
    s.notifyEnabled = j['notifyEnabled'] as bool? ?? false;
    s.notifyHour = j['notifyHour'] as int? ?? 9;
    s.notifyMinute = j['notifyMinute'] as int? ?? 0;
    s.lastModified = j['lastModified'] as int? ?? 0;
    s.level = j['level'] as int? ?? 1;
    s.xp = j['xp'] as int? ?? 0;
    s.totalXp = j['totalXp'] as int? ?? 0;
    final st = (j['stats'] as List?)?.cast<int>() ?? const [];
    for (var i = 0; i < Stat.values.length && i < st.length; i++) {
      s.stats[Stat.values[i]] = st[i];
    }
    final dn = (j['domainNotes'] as List?) ?? const [];
    for (var i = 0; i < Stat.values.length && i < dn.length; i++) {
      final list = [
        for (final e in (dn[i] as List?) ?? const [])
          Note.fromJson((e as Map).cast<String, dynamic>())
      ];
      if (list.isNotEmpty) s.domainNotes[Stat.values[i]] = list;
    }
    for (final e in (j['ledger'] as List?) ?? const []) {
      s.ledger.add(LedgerEntry.fromJson((e as Map).cast<String, dynamic>()));
    }
    s.streakDays = j['streakDays'] as int? ?? 0;
    s.bestStreak = j['bestStreak'] as int? ?? s.streakDays;
    s.streakShields = j['streakShields'] as int? ?? 0;
    s.shieldUnlockGranted = j['shieldUnlockGranted'] as bool? ?? false;
    s.lastCompletionDay = j['lastCompletionDay'] as String?;
    s.lastActiveDay = j['lastActiveDay'] as String?;
    s.totalCompletions = j['totalCompletions'] as int? ?? 0;
    s.verifiedCompletions = j['verifiedCompletions'] as int? ?? 0;
    s.dreadCompletions = j['dreadCompletions'] as int? ?? 0;
    s.epicCompletions = j['epicCompletions'] as int? ?? 0;
    s.eventCompletions = j['eventCompletions'] as int? ?? 0;
    s.customCompletions = j['customCompletions'] as int? ?? 0;
    s.comebacks = j['comebacks'] as int? ?? 0;
    s.dawnCompletions = j['dawnCompletions'] as int? ?? 0;
    s.duskCompletions = j['duskCompletions'] as int? ?? 0;
    s.perfectDays = j['perfectDays'] as int? ?? 0;
    s.lastPerfectDay = j['lastPerfectDay'] as String?;
    s.removedDefaults
        .addAll(((j['removedDefaults'] as List?) ?? const []).cast());
    s.collectedLoot
        .addAll(((j['collectedLoot'] as List?) ?? const []).cast());
    s.equippedSkin = j['equippedSkin'] as String?;
    s.seenEvidence.addAll(((j['seenEvidence'] as List?) ?? const []).cast());
    s.canvasTheme = j['canvasTheme'] as String? ?? 'walnut';
    s.unlockedAchievements
        .addAll(((j['unlockedAchievements'] as List?) ?? const []).cast());
    for (final e
        in (((j['history'] as Map?) ?? const {}).cast<String, dynamic>())
            .entries) {
      s.history[e.key] = (e.value as num).toInt();
    }
    for (final g in (j['goals'] as List?) ?? const []) {
      s.goals.add(Goal.fromJson((g as Map).cast<String, dynamic>()));
    }
    s.todayXp = j['todayXp'] as int? ?? 0;
    final ts = (j['todayStats'] as List?)?.cast<int>() ?? const [];
    for (var i = 0; i < Stat.values.length && i < ts.length; i++) {
      if (ts[i] > 0) s.todayStats[Stat.values[i]] = ts[i];
    }
    s.todayQuestTitles
        .addAll(((j['todayQuestTitles'] as List?) ?? const []).cast());
    s.nightDoneDay = j['nightDoneDay'] as String?;
    s.morningDoneDay = j['morningDoneDay'] as String?;
    s.nightDoneAt = j['nightDoneAt'] as int? ?? 0;
    // Bridge older saves (no morningArmed key): if a night was closed and you
    // haven't been greeted today, arm the morning so it surfaces after this
    // update (e.g. a 3am wind-down before the field existed) — user report.
    s.morningArmed = j['morningArmed'] as bool? ??
        (j['nightDoneDay'] != null &&
            j['morningDoneDay'] != Days.key(Clock.now()));
    s.sparkSeenDay = j['sparkSeenDay'] as String?;
    return s;
  }
}
