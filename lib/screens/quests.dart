import 'dart:async';
import 'dart:math' show min;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio.dart';
import '../content/achievements.dart';
import '../content/cosmetics.dart';
import '../content/evidence.dart';
import '../content/ladders.dart';
import '../content/routines.dart';
import '../content/sparks.dart';
import '../content/stat_ranks.dart';
import '../engine.dart';
import '../haptics.dart';
import '../models.dart';
import '../tokens.dart';
import '../widgets/workout_flow.dart';
import '../widgets/achievement_toast.dart';
import '../widgets/epic_overlay.dart';
import '../widgets/glass.dart';
import '../widgets/install_hint.dart';
import '../widgets/levelup_overlay.dart';
import '../widgets/particles.dart';
import '../widgets/portrait.dart';
import '../widgets/quest_card.dart';
import '../widgets/reward_receipt.dart';
import '../widgets/routine_flows.dart';
import '../widgets/stat_chips.dart';
import '../widgets/timer_overlay.dart';
import '../widgets/xp_bar.dart';

/// The Quests page: glass header HUD over today's quest list. Orchestrates
/// the completion sequence end to end (DESIGN.md §3 + §11):
/// ack → squash/check → particles → receipt → bar fill → epic → level-up.
class QuestsPage extends StatefulWidget {
  const QuestsPage({
    super.key,
    required this.state,
    required this.quests,
    required this.onRefresh,
    required this.onPersist,
    required this.onAdd,
    required this.onRemove,
    required this.onSnapshot,
    required this.onRestore,
  });

  final GameState state;
  final List<Quest> quests;

  /// Non-destructive board refresh; returns how many quests were re-added.
  final int Function() onRefresh;

  /// Asks the shell to save (called after mutations the notifier misses).
  final VoidCallback onPersist;

  /// Adds a quest (night planner's tomorrow-adder uses this).
  final bool Function(Quest) onAdd;

  /// Removes a quest from the board (long-press management).
  final void Function(Quest) onRemove;

  /// Captures a full-save snapshot for undo (called before a completion).
  final String Function() onSnapshot;

  /// Restores a snapshot — the undo action.
  final void Function(String) onRestore;

  @override
  State<QuestsPage> createState() => _QuestsPageState();
}

class _QuestsPageState extends State<QuestsPage> with WidgetsBindingObserver {
  GameState get _state => widget.state;

  // ── deferred-commit machinery (flushable, so rapid completions and undo
  // can't corrupt each other's state) ───────────────────────────────────
  Timer? _commitTimer;
  GameState? _pendingState;
  RewardBundle? _pendingBundle;
  String? _pendingSnapshot;
  String? _pendingTitle;

  /// One guided-workout runner at a time (rapid double-tap can't spawn two
  /// runners → double reward; bug-hunt §8).
  bool _workoutRunnerOpen = false;

  /// The most recent completion's undo target. Drives the swipe-left-to-undo on
  /// the just-completed card — a calm, in-place undo (the transient snackbar
  /// was removed).
  String? _undoTitle;
  String? _undoSnapshot;

  void _undoLast() {
    final snap = _undoSnapshot;
    if (snap == null) return;
    Sfx.instance.play('boing');
    HapticFeedback.selectionClick();
    setState(() {
      _undoTitle = null;
      _undoSnapshot = null;
    });
    ScaffoldMessenger.of(context).clearSnackBars();
    widget.onRestore(snap);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  /// Backgrounding within the ~1.5s deferred-commit window must never persist
  /// a done-marked quest without its reward — flush the pending commit so the
  /// shell's save captures the committed state, not a half-applied one
  /// (bug-hunt §1/§3). Cheap no-op when nothing is pending.
  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle == AppLifecycleState.paused ||
        lifecycle == AppLifecycleState.inactive) {
      _flushCommit();
    }
  }

  /// Apply any in-flight completion's rewards NOW (mounted path). Called
  /// before each new completion so a fresh snapshot reflects prior
  /// completions fully committed, never half-applied — the rapid-double-tap
  /// data-loss trap.
  void _flushCommit() {
    _commitTimer?.cancel();
    _commitTimer = null;
    final ps = _pendingState;
    final pb = _pendingBundle;
    final snap = _pendingSnapshot;
    final title = _pendingTitle;
    _pendingState = null;
    _pendingBundle = null;
    _pendingSnapshot = null;
    _pendingTitle = null;
    if (ps == null || pb == null) return;
    if (!identical(ps, _state)) return; // state swapped (undo/reset) → drop
    setState(() => ps.commit(pb));
    if (_remainingToday() == 0) ps.recordPerfectDay();
    _toastAchievements(ps, ps.checkAchievements());
    widget.onPersist();
    if (snap != null && title != null) _offerUndo(title, snap);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // data-only flush (no setState during teardown) — never lose a reward
    // that was earned but whose visual commit hadn't fired yet. Mirror
    // _flushCommit's DATA effects (perfect-day shield + achievement/cosmetic
    // grants), omitting only the UI (setState/toasts/undo) — bug-hunt §11.
    _commitTimer?.cancel();
    final ps = _pendingState;
    final pb = _pendingBundle;
    if (ps != null && pb != null && identical(ps, widget.state)) {
      ps.commit(pb);
      if (_remainingToday() == 0) ps.recordPerfectDay();
      ps.checkAchievements();
      widget.onPersist();
    }
    super.dispose();
  }

  /// While true the header portrait beams (set on every completion).
  bool _beaming = false;
  int _beamGen = 0;

  void _beam() {
    final gen = ++_beamGen;
    setState(() => _beaming = true);
    Future.delayed(const Duration(milliseconds: 1600), () {
      // only the latest beam may end the glow — rapid completions extend it
      if (mounted && gen == _beamGen) setState(() => _beaming = false);
    });
  }

  /// Entry point from a card tap: timer-proof quests run their countdown
  /// first (proof multiplies, never gates — cancel just backs out).
  void _completeQuest(Quest q, Offset tapPos) {
    if (q.allDay) {
      // honesty by design: an all-day line is only confirmed at night — but
      // the moment of willpower still deserves a beat, not a cold deferral.
      Sfx.instance.play('tick');
      HapticFeedback.lightImpact();
      _beam();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Palette.card,
          duration: const Duration(milliseconds: 2000),
          content: Text('Noted — you’re holding the line. Tonight it counts 🌙',
              style: Type.body.copyWith(color: Palette.textHi)),
        ),
      );
      return;
    }
    if (q.workout) {
      // a guided session: walk the user through the runner; its outcome
      // flows back through the normal reward path (RESEARCH-workouts.md)
      _openWorkout(q, tapPos);
      return;
    }
    if (q.verification == Verification.timer && q.timerMinutes > 0) {
      late final OverlayEntry timer;
      timer = OverlayEntry(
        builder: (_) => TimerOverlay(
          questTitle: q.title,
          minutes: q.timerMinutes,
          onFinished: () {
            timer.remove();
            if (mounted) _runCompletion(q, tapPos, verified: true);
          },
          // honor path: did it without the timer → full base, no ×1.2
          onHonor: () {
            timer.remove();
            if (mounted) _runCompletion(q, tapPos);
          },
          onCancel: () => timer.remove(),
        ),
      );
      Overlay.of(context).insert(timer);
      return;
    }
    _runCompletion(q, tapPos);
  }

  /// The §3 completion sequence, staged (see DESIGN.md §3).
  void _runCompletion(Quest q, Offset tapPos, {bool verified = false}) {
    // settle any prior in-flight completion FIRST, so this snapshot reflects
    // it fully committed (never rolled-but-not-committed — the data-loss trap)
    _flushCommit();
    final s = _state; // guard: the dev reset button can swap state mid-flight
    // capture the pre-completion state so an accidental tap can be undone
    final snapshot = widget.onSnapshot();
    final bundle = s.roll(q, verified: verified);
    setState(() {}); // card done-state + quests-left counter
    _beam(); // the portrait shares the moment with you

    Sfx.instance.play('complete');
    HapticFeedback.lightImpact();
    // a shield that held the line gets its own steady double-tap
    if (bundle.shieldHeld) {
      Future.delayed(const Duration(milliseconds: 260), Haptics.shield);
    }

    final overlay = Overlay.of(context);

    // Particle burst — count/vibrancy scale with magnitude.
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;
      late final OverlayEntry burst;
      burst = OverlayEntry(
        builder: (_) => ParticleBurst(
          origin: tapPos,
          colors: cosmeticFor(s.equippedSkin)?.particles ??
              [q.stat.color, Palette.xp, Palette.xpLight],
          count: (14 + 40 * bundle.magnitude).round(),
          vibrancy: 0.5 + bundle.magnitude,
          onDone: () => burst.remove(),
        ),
      );
      overlay.insert(burst);
    });

    // The reward receipt; epic + level-ups resolve once it finishes so big
    // moments never land on top of mid-flight bubbles.
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      late final OverlayEntry receipt;
      receipt = OverlayEntry(
        builder: (_) => Stack(
          children: [
            RewardReceipt(
              bundle: bundle,
              anchor: tapPos,
              onDone: () {
                receipt.remove();
                _afterReceipt(s, q, bundle);
              },
            ),
          ],
        ),
      );
      overlay.insert(receipt);
    });

    // Commit once the last bubble has entered: NOW the bar fills and the
    // stat chip pulses, as their bubbles point at them. Held as a flushable
    // pending commit (see _flushCommit) so it can never be half-applied.
    final bubbles = 3 + // xp + stat + message
        (bundle.firstOfDay ? 1 : 0) +
        (bundle.streakMult != null ? 1 : 0) +
        (bundle.verifiedMult != null ? 1 : 0) +
        (bundle.comebackMult != null ? 1 : 0) +
        (bundle.shieldHeld ? 1 : 0) +
        (bundle.critMult != null ? 1 : 0) +
        (bundle.loot != null ? 1 : 0);
    _pendingState = s;
    _pendingBundle = bundle;
    _pendingSnapshot = snapshot;
    _pendingTitle = q.title;
    _commitTimer = Timer(
        Duration(milliseconds: 400 + 120 * bubbles + 250), _flushCommit);
  }

  /// Arms the just-completed card so it can be swiped left to undo a misfire;
  /// restoring reverts every reward the completion granted. The old transient
  /// undo snackbar was removed — the card swipe is now the single undo
  /// affordance (no redundant popup).
  void _offerUndo(String title, String snapshot) {
    if (!mounted) return;
    setState(() {
      _undoTitle = title;
      _undoSnapshot = snapshot;
    });
  }

  /// Count of quests still open today (mirrors the build() filter).
  int _remainingToday() {
    final now = DateTime.now();
    final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);
    return widget.quests
        .where((q) => q.isEvent
            ? (!q.dueDate!.isAfter(endOfToday) && !q.doneFor(now))
            : (q.scheduledOn(now) && !q.doneFor(now)))
        .length;
  }

  /// Queue achievement banners, staggered so each gets its moment. Guarded
  /// by [s]: if the state was swapped (undo/reset) before a toast fires, it
  /// is suppressed — no claiming a trophy the restored state no longer holds.
  void _toastAchievements(GameState s, List<Achievement> newly) {
    for (var i = 0; i < newly.length; i++) {
      Future.delayed(Duration(milliseconds: 200 + i * 2800), () {
        if (!mounted || !identical(s, _state)) return;
        late final OverlayEntry toast;
        toast = OverlayEntry(
          builder: (_) => Stack(
            children: [
              AchievementToast(
                achievement: newly[i],
                onDone: () => toast.remove(),
              ),
            ],
          ),
        );
        Overlay.of(context).insert(toast);
      });
    }
  }

  /// EPIC (d≥7) quests get their full-screen moment before any level-up.
  void _afterReceipt(GameState s, Quest q, RewardBundle bundle) {
    if (!mounted || !identical(s, _state)) return;
    if (q.difficulty >= 7) {
      late final OverlayEntry epic;
      epic = OverlayEntry(
        builder: (_) => EpicOverlay(
          questTitle: q.title,
          message: bundle.message,
          onDismiss: () {
            epic.remove();
            _afterEpic(s);
          },
        ),
      );
      Overlay.of(context).insert(epic);
    } else {
      _afterEpic(s);
    }
  }

  /// Goal celebrations: a crossed finish line gets the full sunlit moment;
  /// a milestone on an ongoing practice gets a gold banner.
  void _afterEpic(GameState s) {
    if (!mounted || !identical(s, _state)) return;

    final milestone = s.takeJustMilestoned();
    if (milestone != null) {
      final (g, reached) = milestone;
      _toastAchievements(s, [
        Achievement(
          id: '_milestone',
          title: '${g.title} · $reached',
          desc: 'milestone reached — the path continues',
          icon: Icons.all_inclusive,
          test: (_) => true,
        ),
      ]);
    }

    final achieved = s.takeJustAchieved();
    if (achieved != null) {
      late final OverlayEntry done;
      done = OverlayEntry(
        builder: (_) => EpicOverlay(
          kicker: 'GOAL ACHIEVED',
          headline: 'YOU MADE IT.',
          questTitle: achieved.title,
          message:
              'an oath, kept — ${achieved.target} quests walked to the end.',
          onDismiss: () {
            done.remove();
            _resolveLevelUps(s);
          },
        ),
      );
      Overlay.of(context).insert(done);
    } else {
      _resolveLevelUps(s);
    }
  }

  /// Long-press management: star as MAIN, or remove (two-tap confirm).
  void _manageQuest(Quest q) {
    Sfx.instance.play('tick');
    HapticFeedback.selectionClick();
    var armed = false;
    showDialog(
      context: context,
      barrierColor: const Color(0xCC140C06),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => Dialog(
          backgroundColor: Colors.transparent,
          child: GlassPanel(
            tint: const Color(0xF22A211D),
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(q.displayTitle, style: Type.display.copyWith(fontSize: 17)),
                if (q.goalTitle != null) ...[
                  const SizedBox(height: 2),
                  Text('part of “${q.goalTitle}”',
                      style: Type.body.copyWith(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: Palette.textLo)),
                ],
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: () {
                    Sfx.instance.play('tick');
                    setState(() => q.priority = !q.priority);
                    widget.onPersist();
                    Navigator.of(ctx).pop();
                  },
                  child: Row(
                    children: [
                      Icon(q.priority ? Icons.star : Icons.star_border,
                          size: 18, color: Palette.xpLight),
                      const SizedBox(width: 10),
                      Text(
                          q.priority
                              ? 'Unstar — back to side quest'
                              : 'Star as a MAIN quest',
                          style: Type.body.copyWith(
                              fontSize: 14, color: Palette.textHi)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: () {
                    Sfx.instance.play('tick');
                    Navigator.of(ctx).pop();
                    showDialog(
                      context: context,
                      barrierColor: const Color(0xCC140C06),
                      builder: (_) => _EditQuestDialog(
                        quest: q,
                        onSaved: () {
                          setState(() {});
                          widget.onPersist();
                        },
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      const Icon(Icons.tune, size: 18, color: Palette.xpLight),
                      const SizedBox(width: 10),
                      Text('Tune difficulty & stat',
                          style: Type.body.copyWith(
                              fontSize: 14, color: Palette.textHi)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: () {
                    if (!armed) {
                      Sfx.instance.play('tick');
                      setDialog(() => armed = true);
                      return;
                    }
                    Sfx.instance.play('boing');
                    widget.onRemove(q);
                    Navigator.of(ctx).pop();
                  },
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline,
                          size: 18,
                          color: const Color(0xFFE89090)
                              .withValues(alpha: armed ? 1 : 0.7)),
                      const SizedBox(width: 10),
                      Text(
                          armed
                              ? 'Tap again — gone for good'
                              : 'Remove from the board',
                          style: Type.body.copyWith(
                              fontSize: 14,
                              color: armed
                                  ? const Color(0xFFE89090)
                                  : Palette.textHi)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The "keep the fire going" encore (RESEARCH-momentum.md §1): for quests
  /// already cleared today, offer the next rung (STOKE) or a fresh variant
  /// (SWITCH) as a one-off bonus — momentum on a high, without touching the
  /// banked win, the streak, or the daily baseline. The old board-shuffle
  /// lives on as a quiet footer link for the rare genuine reload.
  void _openMomentum() {
    Sfx.instance.play('tick');
    HapticFeedback.selectionClick();
    showDialog(
      context: context,
      barrierColor: const Color(0xCC140C06),
      builder: (_) => _MomentumSheet(
        quests: widget.quests,
        onAdd: widget.onAdd,
        onShuffle: widget.onRefresh,
      ),
    );
  }

  /// Quick capture for real life ("laundry, today, no schedule"): one
  /// field, smart defaults, lands at the top of today as a due event.
  void _quickAdd() {
    Sfx.instance.play('tick');
    HapticFeedback.selectionClick();
    showDialog(
      context: context,
      barrierColor: const Color(0xCC140C06),
      builder: (_) => _QuickAddDialog(onAdd: widget.onAdd),
    );
  }

  void _openNight() {
    Sfx.instance.play('tick');
    final s = _state;
    late final OverlayEntry e;
    e = OverlayEntry(
      builder: (_) => NightFlow(
        state: s,
        quests: widget.quests,
        onAdd: widget.onAdd,
        onPersist: widget.onPersist,
        onClose: () {
          e.remove();
          if (mounted && identical(s, _state)) {
            // a night-confirmed all-day line can be the day's last clear
            if (_remainingToday() == 0) s.recordPerfectDay();
            setState(() {});
            _toastAchievements(s, s.checkAchievements());
          }
        },
      ),
    );
    Overlay.of(context).insert(e);
  }

  void _openMorning() {
    Sfx.instance.play('tick');
    final s = _state;
    late final OverlayEntry e;
    e = OverlayEntry(
      builder: (_) => MorningFlow(
        state: s,
        quests: widget.quests,
        onClose: () {
          s.closeMorning(); // disarms the briefing
          widget.onPersist();
          e.remove();
          if (mounted && identical(s, _state)) setState(() {});
        },
      ),
    );
    Overlay.of(context).insert(e);
  }

  /// Open the guided-workout runner for a workout launcher quest. The runner
  /// never rewards itself — its outcome routes back to [_finishWorkout].
  void _openWorkout(Quest launcher, Offset tapPos) {
    if (_workoutRunnerOpen) return; // dedupe rapid double-tap (bug-hunt §8)
    _workoutRunnerOpen = true;
    Sfx.instance.play('tick');
    HapticFeedback.selectionClick();
    late final OverlayEntry e;
    e = OverlayEntry(
      builder: (_) => WorkoutFlow(
        state: _state,
        recommended: recommendedForRung(launcher.rung),
        onClose: () {
          e.remove();
          _workoutRunnerOpen = false;
        },
        onFinish: ({
          required Routine routine,
          required bool verified,
          required bool endedEarly,
          required int workMovesDone,
        }) {
          e.remove();
          _workoutRunnerOpen = false;
          _finishWorkout(launcher, routine, tapPos,
              verified: verified,
              endedEarly: endedEarly,
              workMovesDone: workMovesDone);
        },
      ),
    );
    Overlay.of(context).insert(e);
  }

  /// Pay for a finished session through the EXISTING reward engine: synthesize
  /// one throwaway Quest (routine stat/difficulty, ×1.2 if a timed move was
  /// proved, ticks the strength goal) and run the normal completion. Difficulty
  /// scales down fairly for an early exit. The launcher is marked done AFTER
  /// the snapshot is captured, so Undo reverts both the reward and the tick.
  void _finishWorkout(Quest launcher, Routine routine, Offset tapPos,
      {required bool verified,
      required bool endedEarly,
      required int workMovesDone}) {
    if (!mounted) return;
    final frac = routine.workMoves == 0
        ? 1.0
        : (workMovesDone / routine.workMoves).clamp(0.25, 1.0);
    final diff = endedEarly
        ? (routine.difficulty * frac).round().clamp(1, 10)
        : routine.difficulty;
    final reward = Quest(
      title: routine.title,
      stat: routine.stat,
      difficulty: diff,
      schedule: QuestSchedule.once,
      goalTitle: 'The strength path',
    );
    // _runCompletion captures the undo snapshot (launcher still un-done) and
    // ARMS the deferred reward commit. Mark the launcher done in-memory for the
    // visual, but do NOT persist here — persistence happens atomically when the
    // reward actually commits (_flushCommit/dispose call onPersist), so a save
    // can never capture a done launcher without its XP/stat (bug-hunt §3/§4/§7).
    _runCompletion(reward, tapPos, verified: verified);
    launcher.lastDoneDay = Days.key(DateTime.now());
    if (launcher.rising) launcher.risingStreak++;
    setState(() {});
  }

  void _resolveLevelUps(GameState s) {
    if (!mounted || !identical(s, _state)) return;
    final result = s.applyLevelUps();
    widget.onPersist();
    if (result.leveledTo == null) {
      _afterRankThenToasts(s);
      return;
    }

    // A level-up is a big moment; drop the undo snackbar so it doesn't sit
    // under the takeover offering to revert the celebration mid-show.
    ScaffoldMessenger.of(context).clearSnackBars();
    // Deliberately NO setState here: the header keeps the full bar behind
    // the takeover's dim, and the overflow pour plays on dismissal where it
    // can actually be seen (DESIGN.md §6).
    late final OverlayEntry takeover;
    takeover = OverlayEntry(
      builder: (_) => LevelUpOverlay(
        level: result.leveledTo!,
        unlock: result.unlock,
        nextUnlock: s.nextUnlockLabel(),
        onDismiss: () {
          takeover.remove();
          if (mounted && identical(s, _state)) {
            setState(() {});
            // the rank-up evidence beat, then achievements, after the takeover
            _afterRankThenToasts(s);
          }
        },
      ),
    );
    Overlay.of(context).insert(takeover);
  }

  /// The signature beat: if a stat just crossed a rank tier, surface a
  /// "WHY THIS WORKS" evidence moment before the achievement toasts — stats
  /// growing with real-world meaning, at the moment they grow.
  void _afterRankThenToasts(GameState s) {
    if (!mounted || !identical(s, _state)) {
      return;
    }
    final ranked = s.takeJustRankedUp();
    final card = ranked == null ? null : evidenceForStat(ranked.$1);
    if (ranked == null || card == null) {
      _toastAchievements(s, s.checkAchievements());
      return;
    }
    final (stat, rank) = ranked;
    Sfx.instance.play('levelup');
    Haptics.rise(); // an ascending climb for crossing a rank tier
    late final OverlayEntry beat;
    beat = OverlayEntry(
      builder: (_) => _RankUpBeat(
        stat: stat,
        rank: rank,
        card: card,
        onDismiss: () {
          beat.remove();
          if (mounted && identical(s, _state)) {
            _toastAchievements(s, s.checkAchievements());
          }
        },
      ),
    );
    Overlay.of(context).insert(beat);
  }

  /// A clear, tappable "good morning" prompt whenever the briefing is owed —
  /// so a missed auto-show never leaves the morning unreachable (user report).
  Widget _morningPanel() {
    if (!_state.morningAvailable) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: GestureDetector(
        onTap: _openMorning,
        child: GlassPanel(
          glow: true,
          child: Row(
            children: [
              const Icon(Icons.wb_twilight, size: 20, color: Palette.streak),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('GOOD MORNING',
                        style: Type.label
                            .copyWith(fontSize: 8, color: Palette.streak)),
                    const SizedBox(height: 2),
                    Text('tap to see what’s ahead today ☀️',
                        style: Type.body
                            .copyWith(fontSize: 12.5, color: Palette.textHi)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 18, color: Palette.textLo),
            ],
          ),
        ),
      ),
    );
  }

  /// "Today's Spark" — a warm, state-aware greeting on the first open each day
  /// (scout pick #1). Dismissed → stamped, never re-shown that day. Suppressed
  /// while the morning prompt is up (the brief is the bigger greeting).
  Widget _sparkPanel() {
    final today = Days.key(DateTime.now());
    if (_state.morningAvailable) return const SizedBox.shrink();
    if (_state.sparkSeenDay == today) return const SizedBox.shrink();
    // nearest goal within reach (for a "could be today" nudge)
    String? nearTitle;
    var nearGap = 0;
    var best = 1 << 30;
    for (final g in _state.goals) {
      if (g.complete) continue;
      final gap = g.target - g.progress;
      if (gap > 0 && gap <= 4 && gap < best) {
        best = gap;
        nearTitle = g.title;
        nearGap = gap;
      }
    }
    final dom = _state.dominantStat;
    final line = dailySpark(
      dayKey: today,
      streakDays: _state.streakDays,
      perfectDays: _state.perfectDays,
      totalXp: _state.totalXp,
      returning: _state.lastCompletionDay != null && _state.streakDays == 0,
      dominant: dom,
      nearGoalTitle: nearTitle,
      nearGoalGap: nearGap,
      evidenceTitle: dom == null ? null : evidenceForStat(dom)?.title,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: GlassPanel(
        glow: true,
        child: Row(
          children: [
            const Icon(Icons.auto_awesome, size: 16, color: Palette.xpLight),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TODAY’S SPARK',
                      style: Type.label
                          .copyWith(fontSize: 8, color: Palette.xpLight)),
                  const SizedBox(height: 2),
                  Text(line,
                      style: Type.body
                          .copyWith(fontSize: 12.5, color: Palette.textHi)),
                ],
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () {
                Sfx.instance.play('tick');
                HapticFeedback.selectionClick();
                setState(() => _state.sparkSeenDay = today);
                widget.onPersist();
              },
              child: const Icon(Icons.close, size: 15, color: Palette.textLo),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final next = _state.xpNeeded(_state.level + 1);

    // Visible today: recurring quests on their scheduled days (round-7);
    // events only once due. Due/overdue events lead the list.
    final today = Days.key(now);
    final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final visible = [
      for (final q in widget.quests)
        if (q.isEvent
            ? (!q.dueDate!.isAfter(endOfToday) || q.doneFor(now))
            : (q.scheduledOn(now) || q.lastDoneDay == today))
          q,
    ]..sort((a, b) {
        // due events first, then starred MAIN quests, then the rest;
        // all-day reminders last (nothing to tap until tonight)
        int rank(Quest q) =>
            q.allDay ? 3 : (q.isEvent ? 0 : (q.priority ? 1 : 2));
        return rank(a).compareTo(rank(b));
      });
    final remaining = visible.where((q) => !q.doneFor(now)).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Header HUD ──────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: GlassPanel(
            blur: true,
            child: Column(
              children: [
                Row(
                  children: [
                    _LevelRing(
                      level: _state.level,
                      progress: (_state.xp / next).clamp(0.0, 1.0),
                      child: Portrait(
                        size: 44,
                        mood: _beaming
                            ? PortraitMood.happy
                            : PortraitMood.idle,
                        aura: cosmeticFor(_state.equippedSkin)?.aura ??
                            _state.dominantStat?.color,
                        level: _state.level,
                        badge:
                            cosmeticFor(_state.equippedSkin)?.badge ?? false,
                      ),

                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('LEVEL ${_state.level}',
                                  style: Type.label.copyWith(fontSize: 11)),
                              // clamp: pre-level-up overflow reads as a
                              // full bar, never "130 / 105"
                              Text('${min(_state.xp, next)} / $next XP',
                                  style: Type.numerals.copyWith(
                                      fontSize: 13, color: Palette.xp)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          XpBar(
                            progress: _state.xp / next,
                            generation: _state.level,
                          ),
                          if (_state.nextChaseLabel() != null) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                    _state.nextUnlockLabel() != null
                                        ? Icons.lock_outline
                                        : Icons.trending_up,
                                    size: 11,
                                    color: Palette.textLo),
                                const SizedBox(width: 4),
                                Text('NEXT · ${_state.nextChaseLabel()}',
                                    style: Type.label.copyWith(fontSize: 9)),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                StatChips(values: _state.stats),
              ],
            ),
          ),
        ),

        const SizedBox(height: 8),
        const InstallHint(),
        _morningPanel(),
        _sparkPanel(),

        // ── Quest list ──────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('TODAY · $remaining QUESTS LEFT',
                  style: Type.label.copyWith(fontSize: 10)),
              Row(
                children: [
                  GestureDetector(
                    onTap: _quickAdd,
                    child: const Icon(Icons.add_circle_outline,
                        size: 18, color: Palette.xpLight),
                  ),
                  const SizedBox(width: 14),
                  // the day's bookends: sun while a morning briefing is
                  // reachable (always tappable, not just on auto-show),
                  // moon until tonight's close-out is done
                  if (_state.morningAvailable)
                    GestureDetector(
                      onTap: _openMorning,
                      child: const Icon(Icons.wb_twilight,
                          size: 18, color: Palette.streak),
                    )
                  else if (_state.nightDoneDay != today)
                    GestureDetector(
                      onTap: _openNight,
                      child: const Icon(Icons.nightlight_round,
                          size: 17, color: Palette.xpLight),
                    )
                  else
                    const Icon(Icons.nightlight_round,
                        size: 17, color: Palette.textLo),
                  const SizedBox(width: 14),
                  // the momentum spark: cleared something? push further.
                  GestureDetector(
                    onTap: _openMomentum,
                    child: const Icon(Icons.bolt,
                        size: 18, color: Palette.xpLight),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 130),
            itemCount:
                visible.isEmpty ? 1 : visible.length + (remaining == 0 ? 1 : 0),
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              // a board with nothing on it — invite the first ember, don't
              // pretend a day was "cleared" when none was
              if (visible.isEmpty) {
                return GlassPanel(
                  child: Column(
                    children: [
                      const Icon(Icons.local_fire_department_outlined,
                          size: 26, color: Palette.xpLight),
                      const SizedBox(height: 8),
                      Text('A clear board',
                          style: Type.display.copyWith(fontSize: 20)),
                      const SizedBox(height: 4),
                      Text('add a quest with + above, or take on a goal — '
                          'light the first ember and the day tilts your way',
                          textAlign: TextAlign.center,
                          style: Type.body.copyWith(
                              fontSize: 12.5,
                              fontStyle: FontStyle.italic,
                              color: Palette.textLo)),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: _quickAdd,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 9),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                                color:
                                    Palette.xpLight.withValues(alpha: 0.6)),
                          ),
                          child: Text('ADD A QUEST',
                              style: Type.label.copyWith(
                                  fontSize: 9, color: Palette.xpLight)),
                        ),
                      ),
                    ],
                  ),
                );
              }
              // the day, cleared — celebrate and hand off to the night
              if (remaining == 0 && i == 0) {
                return GlassPanel(
                  glow: true,
                  child: Column(
                    children: [
                      const Icon(Icons.auto_awesome,
                          size: 26, color: Palette.xpLight),
                      const SizedBox(height: 8),
                      Text('Day cleared ✨',
                          style: Type.display.copyWith(fontSize: 20)),
                      const SizedBox(height: 4),
                      Text(
                          _state.nightDoneDay == today
                              ? 'rest well — tomorrow is already taking shape'
                              : 'nothing left but the goodnight',
                          style: Type.body.copyWith(
                              fontSize: 12.5,
                              fontStyle: FontStyle.italic,
                              color: Palette.textLo)),
                      // peak-end: you cleared it — still hot? push further
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: _openMomentum,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.bolt,
                                size: 13, color: Palette.streak),
                            const SizedBox(width: 4),
                            Text('keep the fire going',
                                style: Type.label.copyWith(
                                    fontSize: 9, color: Palette.streak)),
                          ],
                        ),
                      ),
                      if (_state.nightDoneDay != today) ...[
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: _openNight,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 9),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                  color: Palette.xpLight
                                      .withValues(alpha: 0.6)),
                            ),
                            child: Text('CLOSE OUT THE DAY 🌙',
                                style: Type.label.copyWith(
                                    fontSize: 9,
                                    color: Palette.xpLight)),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }
              final q = visible[remaining == 0 ? i - 1 : i];
              final isDone = q.doneFor(now);
              final card = QuestCard(
                quest: q,
                done: isDone,
                xpPreview: _state.xpPreview(q),
                onComplete: (pos) => _completeQuest(q, pos),
                onManage: () => _manageQuest(q),
                // a finished, still-climbable quest offers the next rung
                // right on the card
                onEncore: (isDone && !q.bonus && !q.workout && q.canRise)
                    ? _openMomentum
                    : null,
              );
              // the latest finished quest can be swiped left to undo (a calmer
              // affordance than chasing the snackbar)
              if (isDone &&
                  _undoSnapshot != null &&
                  q.title == _undoTitle) {
                return Dismissible(
                  key: ValueKey('undo-${q.title}'),
                  direction: DismissDirection.endToStart,
                  dismissThresholds: const {
                    DismissDirection.endToStart: 0.42
                  },
                  confirmDismiss: (_) async {
                    _undoLast();
                    return false; // restore handles the state change
                  },
                  secondaryBackground: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 26),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.undo,
                            size: 16, color: Palette.xpLight),
                        const SizedBox(width: 6),
                        Text('UNDO',
                            style: Type.label.copyWith(
                                fontSize: 10, color: Palette.xpLight)),
                      ],
                    ),
                  ),
                  background: const SizedBox.shrink(),
                  child: card,
                );
              }
              return card;
            },
          ),
        ),
      ],
    );
  }
}

/// The portrait inside a slowly breathing ring that mirrors XP progress.
/// Keyed by level (like XpBar's generation) so a level-up refills from 0
/// instead of draining backwards; the breathe is the §2 ambient idle motion.
class _LevelRing extends StatefulWidget {
  const _LevelRing({
    required this.level,
    required this.progress,
    required this.child,
  });
  final int level;
  final double progress;
  final Widget child;

  @override
  State<_LevelRing> createState() => _LevelRingState();
}

class _LevelRingState extends State<_LevelRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breathe = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _breathe.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _breathe,
        builder: (context, child) {
          // quantized so shouldRepaint dedupes to ~20 repaints/s
          final wave =
              Motion.ambient.transform((_breathe.value * 56).round() / 56);
          return Transform.scale(
            scale: 1 + 0.02 * wave,
            child: TweenAnimationBuilder<double>(
              key: ValueKey(widget.level),
              tween: Tween(begin: 0, end: widget.progress),
              duration: Motion.barFill,
              curve: Motion.barCurve,
              builder: (_, value, _) => CustomPaint(
                painter: _RingPainter(progress: value, glow: 0.15 + 0.2 * wave),
                child: child,
              ),
            ),
          );
        },
        child: SizedBox(
          width: 58,
          height: 58,
          child: Center(child: widget.child),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.glow});
  final double progress;
  final double glow;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 3;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = const Color(0x1FF2CD93),
    );
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -1.5708, // start at 12 o'clock
        6.2832 * progress,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..color = Palette.xpLight.withValues(alpha: 0.7)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -1.5708,
        6.2832 * progress,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..color = Palette.xp,
      );
    }
    // ambient breathe: a faint halo that swells and settles
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Palette.xp.withValues(alpha: glow * 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.glow != glow;
}

/// The "WHY THIS WORKS" celebration beat shown when a stat crosses a rank
/// tier on completion — the signature stats-grow-with-evidence principle, at
/// the moment of meaning (RESEARCH-momentum.md §7).
class _RankUpBeat extends StatelessWidget {
  const _RankUpBeat({
    required this.stat,
    required this.rank,
    required this.card,
    required this.onDismiss,
  });

  final Stat stat;
  final StatRank rank;
  final EvidenceCard card;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    // OverlaySurface gives this overlay a Material ancestor — without it every
    // Text renders with the debug yellow-underline fallback (the "underline bug").
    return OverlaySurface(
      child: GestureDetector(
        onTap: onDismiss,
        behavior: HitTestBehavior.opaque,
        child: Container(
          color: const Color(0xE6140C06),
          alignment: Alignment.center,
          padding: const EdgeInsets.all(28),
          child: GlassPanel(
            tint: const Color(0xF22A211D),
            glow: true,
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.trending_up, size: 16, color: stat.color),
                    const SizedBox(width: 6),
                    Text('${stat.abbr} RANKED UP',
                        style:
                            Type.label.copyWith(fontSize: 10, color: stat.color)),
                  ],
                ),
                const SizedBox(height: 4),
                Text('You’re ${rank.label} now',
                    style: Type.display.copyWith(fontSize: 24)),
                const SizedBox(height: 16),
                Text('WHY THIS WORKS',
                    style: Type.label.copyWith(fontSize: 9, color: Palette.info)),
                const SizedBox(height: 6),
                Text(card.title, style: Type.display.copyWith(fontSize: 16)),
                const SizedBox(height: 6),
                Text(card.text,
                    style: Type.body.copyWith(
                        fontSize: 13, height: 1.5, color: Palette.textMid)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.menu_book_outlined,
                        size: 11, color: Palette.info),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(card.source,
                          style: Type.label
                              .copyWith(fontSize: 8, color: Palette.info)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text('tap to keep going →',
                      style: Type.label.copyWith(fontSize: 10)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// At most this many momentum bonuses per base quest per day — the
/// anti-overexertion rail (RESEARCH-momentum.md §4). Two encores, then rest.
const int _bonusCapPerBase = 2;

/// The "keep the fire going" encore sheet. For each quest cleared today it
/// offers STOKE (the next rung of its ladder) or SWITCH (a fresh sibling
/// toward the same stat) — spawned as a one-off bonus for today only. The
/// banked win is never touched; the daily baseline and streak are never
/// touched (RESEARCH-momentum.md §1–4). The old board-shuffle is a quiet
/// footer link.
class _MomentumSheet extends StatefulWidget {
  const _MomentumSheet({
    required this.quests,
    required this.onAdd,
    required this.onShuffle,
  });

  final List<Quest> quests;
  final bool Function(Quest) onAdd;
  final int Function() onShuffle;

  @override
  State<_MomentumSheet> createState() => _MomentumSheetState();
}

class _MomentumSheetState extends State<_MomentumSheet> {
  final List<String> _spawned = [];
  String? _note; // inline feedback (e.g. duplicate)
  int? _shuffled;

  DateTime get _now => DateTime.now();

  /// Non-bonus quests cleared today — the sources an encore can spring from.
  /// Workout launchers are excluded: stoking them would spawn a non-guided
  /// bonus that pays the session reward on a bare tap (bug-hunt §6). They
  /// progress via the night RISE and the runner's own picker instead.
  List<Quest> _sources() => [
        for (final q in widget.quests)
          if (!q.allDay && !q.bonus && !q.workout && q.doneFor(_now)) q,
      ];

  int _bonusCount(String root) =>
      widget.quests.where((q) => q.bonus && q.origin == root).length;

  Iterable<String> _boardTitles() =>
      widget.quests.map((q) => q.displayTitle);

  void _stoke(Quest q) {
    final l = q.ladder;
    if (l == null) return;
    final next = (q.rung + 1).clamp(0, l.length - 1);
    final root = q.origin ?? q.title;
    final ok = widget.onAdd(Quest(
      title: l[next],
      stat: q.stat,
      difficulty: (q.difficulty + 1).clamp(1, 10),
      schedule: QuestSchedule.once,
      dueDate: DateTime(_now.year, _now.month, _now.day),
      bonus: true,
      origin: root,
      ladder: q.ladder,
      rung: next,
      kin: q.kin,
    ));
    _afterSpawn(ok, l[next]);
  }

  void _switch(Quest q) {
    final variants = Ladders.variantsFor(q, _boardTitles());
    if (variants.isEmpty) return;
    final pick = variants.first;
    final ok = widget.onAdd(Quest(
      title: pick,
      stat: q.stat,
      difficulty: q.difficulty,
      schedule: QuestSchedule.once,
      dueDate: DateTime(_now.year, _now.month, _now.day),
      bonus: true,
      origin: q.origin ?? q.title,
    ));
    _afterSpawn(ok, pick);
  }

  void _afterSpawn(bool ok, String title) {
    if (!ok) {
      Sfx.instance.play('boing');
      setState(() => _note = '“$title” is already on the board');
      return;
    }
    Sfx.instance.play('streak');
    HapticFeedback.mediumImpact();
    setState(() {
      _spawned.add(title);
      _note = null;
    });
  }

  void _shuffle() {
    Sfx.instance.play('tick');
    HapticFeedback.selectionClick();
    setState(() => _shuffled = widget.onShuffle());
  }

  @override
  Widget build(BuildContext context) {
    final sources = _sources();
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: GlassPanel(
        tint: const Color(0xF22A211D),
        glow: true,
        padding: const EdgeInsets.all(18),
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.bolt, size: 16, color: Palette.xpLight),
                  const SizedBox(width: 6),
                  Text('KEEP THE FIRE GOING',
                      style: Type.label
                          .copyWith(fontSize: 10, color: Palette.xpLight)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                  sources.isEmpty
                      ? 'clear a quest first — then come back to push further'
                      : 'your wins are already banked · this is just for momentum, today only',
                  style: Type.body.copyWith(
                      fontSize: 11.5,
                      fontStyle: FontStyle.italic,
                      color: Palette.textLo)),
              const SizedBox(height: 14),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final q in sources) _sourceTile(q),
                      if (_spawned.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        for (final t in _spawned)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 5),
                            child: Row(
                              children: [
                                const Icon(Icons.bolt,
                                    size: 13, color: Palette.streak),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text('$t — on the board',
                                      style: Type.body.copyWith(
                                          fontSize: 12,
                                          color: Palette.textMid)),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
              if (_note != null) ...[
                const SizedBox(height: 6),
                Text(_note!,
                    style: Type.body.copyWith(
                        fontSize: 11, color: const Color(0xFFE89090))),
              ],
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: _shuffle,
                    child: Text(
                        _shuffled == null
                            ? 'shuffle the board'
                            : _shuffled == 0
                                ? 'board’s all here'
                                : 'pulled $_shuffled back',
                        style: Type.label.copyWith(
                            fontSize: 9,
                            color: Palette.textLo.withValues(alpha: 0.8))),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 22, vertical: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFFF2CD93), Color(0xFFC08B4F)],
                        ),
                        boxShadow: const [
                          BoxShadow(
                              color: Palette.honeyGlow,
                              blurRadius: 14,
                              offset: Offset(0, 4)),
                        ],
                      ),
                      child: Text(_spawned.isEmpty ? 'NOT NOW' : 'LET’S GO',
                          style: Type.label.copyWith(
                              fontSize: 10, color: const Color(0xFF3A2510))),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sourceTile(Quest q) {
    final root = q.origin ?? q.title;
    final capped = _bonusCount(root) >= _bonusCapPerBase;
    final variants = Ladders.variantsFor(q, _boardTitles());
    final canStoke = q.canRise && !capped;
    final canSwitch = variants.isNotEmpty && !capped;
    // physical work, or a second same-day bout → favor variety over reload
    final favorSwitch = q.stat == Stat.str || _bonusCount(root) >= 1;
    final nextRung = q.canRise ? q.ladder![(q.rung + 1)] : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Palette.glassFill,
        border: Border.all(color: Palette.glassEdge),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, size: 14, color: q.stat.color),
              const SizedBox(width: 7),
              Expanded(
                child: Text(q.displayTitle,
                    style: Type.body.copyWith(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: Palette.textHi)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (capped)
            Text('you’ve stoked this plenty today — rest is part of the build',
                style: Type.body.copyWith(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: Palette.textLo))
          else if (!canStoke && !canSwitch)
            Text('already covered — every variant’s on the board',
                style: Type.body.copyWith(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: Palette.textLo))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (canStoke)
                  _MomentumChip(
                    label: 'STOKE',
                    sub: nextRung,
                    highlight: !favorSwitch,
                    onTap: () => _stoke(q),
                  ),
                if (canSwitch)
                  _MomentumChip(
                    label: 'SWITCH IT UP',
                    sub: variants.first,
                    highlight: favorSwitch || !canStoke,
                    onTap: () => _switch(q),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// One encore action — a honey pill when recommended, an outline otherwise.
class _MomentumChip extends StatelessWidget {
  const _MomentumChip({
    required this.label,
    required this.sub,
    required this.highlight,
    required this.onTap,
  });

  final String label;
  final String? sub;
  final bool highlight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = highlight ? const Color(0xFF3A2510) : Palette.xpLight;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: highlight
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFF2CD93), Color(0xFFC08B4F)],
                )
              : null,
          border: highlight
              ? null
              : Border.all(color: Palette.xpLight.withValues(alpha: 0.5)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Type.label.copyWith(fontSize: 9, color: fg)),
            if (sub != null)
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Text(sub!,
                    style: Type.body.copyWith(
                        fontSize: 10.5,
                        color: highlight
                            ? const Color(0xFF3A2510)
                            : Palette.textMid)),
              ),
          ],
        ),
      ),
    );
  }
}

/// Re-tune an adopted quest — difficulty and which stat it trains. The board
/// is yours to shape (deep personalization is the hook).
class _EditQuestDialog extends StatefulWidget {
  const _EditQuestDialog({required this.quest, required this.onSaved});
  final Quest quest;
  final VoidCallback onSaved;

  @override
  State<_EditQuestDialog> createState() => _EditQuestDialogState();
}

class _EditQuestDialogState extends State<_EditQuestDialog> {
  late double _difficulty = widget.quest.difficulty.toDouble();
  late Stat _stat = widget.quest.stat;

  @override
  Widget build(BuildContext context) {
    final maxD = widget.quest.custom ? 8 : 10;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: GlassPanel(
        tint: const Color(0xF22A211D),
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('TUNE THIS QUEST', style: Type.label.copyWith(fontSize: 10)),
            const SizedBox(height: 4),
            Text(widget.quest.displayTitle,
                style: Type.display.copyWith(fontSize: 16)),
            const SizedBox(height: 12),
            Text('TRAINS', style: Type.label.copyWith(fontSize: 8)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final s in Stat.values)
                  GestureDetector(
                    onTap: () => setState(() => _stat = s),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: _stat == s
                            ? s.color.withValues(alpha: 0.22)
                            : Colors.transparent,
                        border: Border.all(
                            color: s.color
                                .withValues(alpha: _stat == s ? 0.8 : 0.3)),
                      ),
                      child: Text(s.abbr,
                          style: Type.label
                              .copyWith(fontSize: 8.5, color: s.color)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text('d${_difficulty.round()}',
                    style: Type.label.copyWith(fontSize: 9, color: Palette.xp)),
                Expanded(
                  child: Slider(
                    value: _difficulty.clamp(1, maxD.toDouble()),
                    min: 1,
                    max: maxD.toDouble(),
                    divisions: maxD - 1,
                    activeColor: Palette.xp,
                    inactiveColor: const Color(0x1FF2CD93),
                    onChanged: (v) => setState(() => _difficulty = v),
                  ),
                ),
              ],
            ),
            Center(
              child: GestureDetector(
                onTap: () {
                  Sfx.instance.play('streak');
                  HapticFeedback.selectionClick();
                  widget.quest.difficulty = _difficulty.round();
                  widget.quest.stat = _stat;
                  widget.onSaved();
                  Navigator.of(context).pop();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFF2CD93), Color(0xFFC08B4F)],
                    ),
                    boxShadow: const [
                      BoxShadow(
                          color: Palette.honeyGlow,
                          blurRadius: 14,
                          offset: Offset(0, 4)),
                    ],
                  ),
                  child: Text('SAVE',
                      style: Type.label.copyWith(
                          fontSize: 10, color: const Color(0xFF3A2510))),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One field, smart defaults: a one-time quest due today. For the laundry
/// moments — capture in five seconds, get back to your life.
class _QuickAddDialog extends StatefulWidget {
  const _QuickAddDialog({required this.onAdd});
  final bool Function(Quest) onAdd;

  @override
  State<_QuickAddDialog> createState() => _QuickAddDialogState();
}

class _QuickAddDialogState extends State<_QuickAddDialog> {
  final _title = TextEditingController();
  Stat _stat = Stat.dis;
  double _difficulty = 3;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _add() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      Sfx.instance.play('boing');
      setState(() => _error = 'what needs doing?');
      return;
    }
    final now = DateTime.now();
    final ok = widget.onAdd(Quest(
      title: title,
      stat: _stat,
      difficulty: _difficulty.round(),
      schedule: QuestSchedule.once,
      dueDate: DateTime(now.year, now.month, now.day),
    ));
    if (!ok) {
      Sfx.instance.play('boing');
      setState(() => _error = 'already on your list');
      return;
    }
    Sfx.instance.play('streak');
    HapticFeedback.selectionClick();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: GlassPanel(
        tint: const Color(0xF22A211D),
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('JUST FOR TODAY', style: Type.label.copyWith(fontSize: 10)),
            const SizedBox(height: 10),
            TextField(
              controller: _title,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _add(),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              style: Type.body.copyWith(fontSize: 15, color: Palette.textHi),
              decoration: InputDecoration(
                hintText: 'e.g. Do the laundry',
                hintStyle:
                    Type.body.copyWith(fontSize: 15, color: Palette.textLo),
                errorText: _error,
                errorStyle: Type.body
                    .copyWith(fontSize: 11, color: const Color(0xFFE89090)),
                filled: true,
                fillColor: Palette.glassFill,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Palette.glassEdge),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final s in Stat.values)
                  GestureDetector(
                    onTap: () => setState(() => _stat = s),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: _stat == s
                            ? s.color.withValues(alpha: 0.22)
                            : Colors.transparent,
                        border: Border.all(
                            color: s.color
                                .withValues(alpha: _stat == s ? 0.8 : 0.3)),
                      ),
                      child: Text(s.abbr,
                          style: Type.label
                              .copyWith(fontSize: 8.5, color: s.color)),
                    ),
                  ),
              ],
            ),
            Row(
              children: [
                Text('d${_difficulty.round()}',
                    style:
                        Type.label.copyWith(fontSize: 9, color: Palette.xp)),
                Expanded(
                  child: Slider(
                    value: _difficulty,
                    min: 1,
                    max: 8,
                    divisions: 7,
                    activeColor: Palette.xp,
                    inactiveColor: const Color(0x1FF2CD93),
                    onChanged: (v) => setState(() => _difficulty = v),
                  ),
                ),
              ],
            ),
            Center(
              child: GestureDetector(
                onTap: _add,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFF2CD93), Color(0xFFC08B4F)],
                    ),
                    boxShadow: const [
                      BoxShadow(
                          color: Palette.honeyGlow,
                          blurRadius: 14,
                          offset: Offset(0, 4)),
                    ],
                  ),
                  child: Text('ON THE BOARD',
                      style: Type.label.copyWith(
                          fontSize: 10, color: const Color(0xFF3A2510))),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
