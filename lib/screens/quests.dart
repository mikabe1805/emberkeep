import 'dart:async';
import 'dart:math' show min;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio.dart';
import '../content/achievements.dart';
import '../content/cosmetics.dart';
import '../content/embers.dart';
import '../content/evidence.dart';
import '../content/ladders.dart';
import '../content/routines.dart';
import '../content/sparks.dart';
import '../content/stat_ranks.dart';
import '../engine.dart';
import '../haptics.dart';
import '../models.dart';
import '../storage.dart';
import '../tokens.dart';
import '../widgets/workout_flow.dart';
import '../widgets/achievement_toast.dart';
import '../widgets/day_picker.dart';
import '../widgets/domain_hint.dart';
import '../widgets/ember_sheet.dart';
import '../widgets/epic_overlay.dart';
import '../widgets/glass.dart';
import '../widgets/honey_button.dart';
import '../widgets/install_hint.dart';
import '../widgets/levelup_overlay.dart';
import '../widgets/particles.dart';
import '../widgets/portrait.dart';
import '../widgets/notes_sheet.dart';
import '../widgets/quest_card.dart';
import '../widgets/reward_receipt.dart';
import '../widgets/routine_flows.dart';
import '../widgets/stat_chips.dart';
import '../widgets/timer_overlay.dart';
import '../widgets/xp_bar.dart';

/// Focus-mode ordering lens: ease in with quick wins, or take the hardest
/// (most-dreaded / heaviest) first. Ephemeral — resets to easeIn each session.
enum _FocusLens { quickWin, hardest }

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

  /// When a weekly quest is cleared on a day other than its anchor, we offer
  /// (gently, inline) to make THIS the day going forward. The candidate quest
  /// and the day it was done on; null when there's no pending offer.
  Quest? _reAnchorQuest;
  int? _reAnchorDay;

  /// Day-key whose "board cleared" flourish has already played, so the gentle
  /// whole-board ember wash fires once per day, not on every idle rebuild.
  String? _clearedDay;

  /// The most-recently-completed quest stays put (where swipe-to-undo lives and
  /// the win is still fresh); only OLDER finished quests bank to the bottom.
  /// Set the instant a completion starts, so the card never visibly jumps.
  String? _pinnedDoneTitle;

  /// Back-to-back clears build warmth (never-punish: pure bonus, no timer
  /// pressure). [_combo] is consecutive completions inside [_comboWindow];
  /// it brightens the burst and fires an "ON A ROLL" flourish at ×2+.
  int _combo = 0;
  DateTime? _lastCompleteAt;
  static const _comboWindow = Duration(seconds: 15);

  /// Focus mode's ordering lens (ephemeral; the on/off itself lives on state).
  _FocusLens _focusLens = _FocusLens.quickWin;

  void _toggleFocus() {
    _state.setFocusMode(!_state.focusMode);
    widget.onPersist();
    Haptics.tap();
    setState(() {});
  }

  void _undoLast() {
    final snap = _undoSnapshot;
    if (snap == null) return;
    Sfx.instance.play('boing');
    HapticFeedback.selectionClick();
    if (_undoTitle != null) Storage.logEvent('undo', [_undoTitle]);
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
    if (_remainingToday() == 0 && !_anySnoozedToday()) ps.recordPerfectDay();
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
      if (_remainingToday() == 0 && !_anySnoozedToday()) ps.recordPerfectDay();
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
          content: Text(
            'Noted — you’re holding the line. Tonight it counts 🌙',
            style: Type.body.copyWith(color: Palette.textHi),
          ),
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
    _pinnedDoneTitle =
        q.title; // keep this fresh win in place (undo lives here)
    Storage.logEvent('done', [
      q.custom ? Storage.hashTitle(q.title) : q.title,
      q.stat.index,
      q.difficulty,
      verified ? 1 : 0,
    ]);
    setState(() {}); // card done-state + quests-left counter
    // back-to-back clears build a combo (pure warmth, no penalty for pausing)
    final nowT = DateTime.now();
    _combo =
        (_lastCompleteAt != null &&
            nowT.difference(_lastCompleteAt!) < _comboWindow)
        ? _combo + 1
        : 1;
    _lastCompleteAt = nowT;
    _maybeOfferReAnchor(q); // "did your Tuesday quest on Thursday? move it?"
    _celebrateDayClearedIfDone(q); // a warm wash when the last ember is lit
    _beam(); // the portrait shares the moment with you

    Sfx.instance.play('complete');
    HapticFeedback.lightImpact();
    // a shield that held the line gets its own steady double-tap
    if (bundle.shieldHeld) {
      Future.delayed(const Duration(milliseconds: 260), Haptics.shield);
    }

    final overlay = Overlay.of(context);

    // Particle burst — fires NOW, coincident with the squash + sound + haptic,
    // so the embers ARE the tap's exhaust rather than a beat behind it. [tapPos]
    // resolves to the check-ring centre (quest_card), so the spray ignites from
    // the ring that just filled, not a random thumb spot.
    final comboBoost = min(_combo - 1, 5); // a roll brightens the burst
    late final OverlayEntry burst;
    burst = OverlayEntry(
      builder: (_) => ParticleBurst(
        origin: tapPos,
        colors:
            cosmeticFor(s.equippedSkin)?.particles ??
            [q.stat.color, Palette.xp, Palette.xpLight],
        count: (14 + 40 * bundle.magnitude).round() + comboBoost * 8,
        vibrancy: 0.5 + bundle.magnitude + comboBoost * 0.12,
        onDone: () => burst.remove(),
      ),
    );
    // a flourish for a roll of clears — escalating warmth, never a takeover
    if (_combo >= 2) {
      Haptics.rise();
      late final OverlayEntry flourish;
      flourish = OverlayEntry(
        builder: (_) =>
            _ComboFlourish(combo: _combo, onDone: () => flourish.remove()),
      );
      overlay.insert(flourish);
    }
    overlay.insert(burst);

    // The reward receipt starts quickly so there's no dead gap after the tap;
    // epic + level-ups still resolve once it finishes so big moments never
    // land on top of mid-flight bubbles.
    Future.delayed(const Duration(milliseconds: 240), () {
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

    // Commit early — right as the XP bubble lands — so the RISING XP BAR is the
    // first payoff and the multiplier bubbles cascade on top of an already-
    // moving bar (decoupled from bubble count; the bar was the slowest, most
    // satisfying element and used to fire last). Flushable/atomic as before.
    _pendingState = s;
    _pendingBundle = bundle;
    _pendingSnapshot = snapshot;
    _pendingTitle = q.title;
    _commitTimer = Timer(const Duration(milliseconds: 520), _flushCommit);
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
    final today = Days.key(now);
    final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);
    return widget.quests
        .where(
          (q) =>
              q.snoozedDay != today &&
              (q.isEvent
                  ? (!q.dueDate!.isAfter(endOfToday) && !q.doneFor(now))
                  : (q.scheduledOn(now) && !q.doneFor(now))),
        )
        .length;
  }

  /// A perfect day must be EARNED, not snoozed: a quest hidden "just for today"
  /// was due and not cleared, so a day cleared only by hiding quests can't mint
  /// a perfect-day reward / streak shield.
  bool _anySnoozedToday() {
    final today = Days.key(DateTime.now());
    return widget.quests.any((q) => q.snoozedDay == today);
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
                Text(
                  q.displayTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Type.display.copyWith(fontSize: 17),
                ),
                if (q.goalTitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'part of “${q.goalTitle}”',
                    style: Type.body.copyWith(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: Palette.textLo,
                    ),
                  ),
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
                      Icon(
                        q.priority ? Icons.star : Icons.star_border,
                        size: 18,
                        color: Palette.xpLight,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        q.priority
                            ? 'Unstar — back to side quest'
                            : 'Star as a MAIN quest',
                        style: Type.body.copyWith(
                          fontSize: 14,
                          color: Palette.textHi,
                        ),
                      ),
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
                      Text(
                        'Tune difficulty & stat',
                        style: Type.body.copyWith(
                          fontSize: 14,
                          color: Palette.textHi,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                // The running log: little timestamped notes kept on this quest
                // (which side, how much, where) — context that travels with it.
                GestureDetector(
                  onTap: () {
                    Sfx.instance.play('tick');
                    Navigator.of(ctx).pop();
                    final last = q.lastDoneDay;
                    showNotesSheet(
                      context,
                      kicker: 'LOG',
                      title: q.displayTitle,
                      icon: Icons.sticky_note_2_outlined,
                      accent: q.stat.color,
                      subtitle: last != null
                          ? 'last done ${relativeWhen(Days.parse(last))}'
                          : null,
                      emptyHint:
                          'Nothing logged yet. Jot whatever you’ll want to '
                          'remember next time — which side, how much, where.',
                      read: () => q.log,
                      onAdd: (text) {
                        q.addNote(text, DateTime.now());
                        setState(() {});
                        widget.onPersist();
                      },
                      onDelete: (n) {
                        q.log = q.log.without(n);
                        setState(() {});
                        widget.onPersist();
                      },
                    );
                  },
                  child: Row(
                    children: [
                      Icon(
                        Icons.sticky_note_2_outlined,
                        size: 18,
                        color: q.stat.color,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        q.log.isEmpty
                            ? 'Keep a note / log'
                            : 'Notes & log (${q.log.length})',
                        style: Type.body.copyWith(
                          fontSize: 14,
                          color: Palette.textHi,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                // A gentle skip: hide it from today's board, back tomorrow —
                // never a penalty, just "not today."
                GestureDetector(
                  onTap: () {
                    Sfx.instance.play('tick');
                    HapticFeedback.selectionClick();
                    setState(() => q.snoozedDay = Days.key(DateTime.now()));
                    Storage.logEvent('snooze', [
                      q.custom ? Storage.hashTitle(q.title) : q.title,
                    ]);
                    widget.onPersist();
                    Navigator.of(ctx).pop();
                  },
                  child: Row(
                    children: [
                      const Icon(
                        Icons.bedtime_outlined,
                        size: 18,
                        color: Palette.textMid,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Hide it just for today',
                        style: Type.body.copyWith(
                          fontSize: 14,
                          color: Palette.textHi,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                // The permanent remove keeps its two-tap arm.
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
                      Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: const Color(
                          0xFFE89090,
                        ).withValues(alpha: armed ? 1 : 0.7),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        armed
                            ? 'Tap again — gone for good'
                            : 'Remove it for good',
                        style: Type.body.copyWith(
                          fontSize: 14,
                          color: armed
                              ? const Color(0xFFE89090)
                              : Palette.textHi,
                        ),
                      ),
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
  void _quickAdd() async {
    Sfx.instance.play('tick');
    HapticFeedback.selectionClick();
    final q = await showEmberSheet(
      context,
      const EmberSheetConfig(surface: EmberSurface.board),
    );
    if (q != null) widget.onAdd(q);
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
            if (_remainingToday() == 0 && !_anySnoozedToday()) {
              s.recordPerfectDay();
            }
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
        onFinish:
            ({
              required Routine routine,
              required bool verified,
              required bool endedEarly,
              required int workMovesDone,
            }) {
              e.remove();
              _workoutRunnerOpen = false;
              _finishWorkout(
                launcher,
                routine,
                tapPos,
                verified: verified,
                endedEarly: endedEarly,
                workMovesDone: workMovesDone,
              );
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
  void _finishWorkout(
    Quest launcher,
    Routine routine,
    Offset tapPos, {
    required bool verified,
    required bool endedEarly,
    required int workMovesDone,
  }) {
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

  /// Clearing the whole board is the peak of the daily loop — it deserves more
  /// than a quiet card. When the last actionable quest is done, a gentle warm
  /// ember wash sweeps the board + a flourish haptic (once per day). It lands
  /// after the per-quest celebration so the two don't collide.
  void _celebrateDayClearedIfDone(Quest justDone) {
    // all-day lines confirm at night, so clearing the tappable board still
    // counts even if an all-day reminder remains; but don't fire ON an all-day
    // "completion" (it isn't really one until the night check).
    if (justDone.allDay) return;
    final today = Days.key(DateTime.now());
    if (_clearedDay == today || _remainingToday() != 0) return;
    _clearedDay = today;
    Future.delayed(const Duration(milliseconds: 720), () {
      if (!mounted || _remainingToday() != 0) return;
      Haptics.flourish();
      Sfx.instance.play('streak');
      final size = MediaQuery.sizeOf(context);
      late final OverlayEntry wash;
      wash = OverlayEntry(
        builder: (_) => ParticleBurst(
          origin: Offset(size.width / 2, size.height * 0.3),
          colors: const [Palette.xpLight, Palette.xp, Palette.streak],
          count: 34,
          vibrancy: 0.6,
          spread: size.width * 0.85,
          onDone: () => wash.remove(),
        ),
      );
      Overlay.of(context).insert(wash);
    });
  }

  /// A weekly quest cleared on a day other than its anchor: stash a gentle,
  /// dismissible offer to make THIS the day going forward — the board learning
  /// your real rhythm (round-21). Only single-anchor weeklies; a deliberate
  /// multi-day pattern is left alone.
  void _maybeOfferReAnchor(Quest q) {
    if (q.schedule != QuestSchedule.weekly || q.weekdays.length != 1) return;
    final today = DateTime.now().weekday;
    if (q.weekdays.first == today) return; // done on its day — nothing to offer
    setState(() {
      _reAnchorQuest = q;
      _reAnchorDay = today;
    });
  }

  /// The inline re-anchor offer — calm, optional, never a modal. Lives in the
  /// page body so it waits politely behind the completion celebration and is
  /// trivially ignorable (never-punish: a suggestion, not a correction).
  Widget _reAnchorPanel() {
    final q = _reAnchorQuest;
    final day = _reAnchorDay;
    if (q == null || day == null) return const SizedBox.shrink();
    void dismiss() {
      setState(() {
        _reAnchorQuest = null;
        _reAnchorDay = null;
      });
    }

    final plural = weekdayLabel([day]); // "Thursdays"
    final singular = plural.substring(0, plural.length - 1); // "Thursday"
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: GlassPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.event_repeat, size: 18, color: q.stat.color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'You finished this on a $singular — want it to land on '
                    '$plural from now on?',
                    style: Type.body.copyWith(
                      fontSize: 13.5,
                      color: Palette.textHi,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'now lands on ${weekdayLabel(q.weekdays)}',
              style: Type.body.copyWith(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: Palette.textLo,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: dismiss,
                    child: Container(
                      alignment: Alignment.center,
                      constraints: const BoxConstraints(minHeight: 44),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Palette.glassEdge),
                      ),
                      child: Text(
                        'KEEP IT',
                        style: Type.label.copyWith(
                          fontSize: 12,
                          color: Palette.textLo,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: HoneyButton(
                    label: 'MOVE TO ${plural.toUpperCase()}',
                    expand: true,
                    onTap: () {
                      Sfx.instance.play('streak');
                      HapticFeedback.selectionClick();
                      setState(() {
                        q.weekdays = [day];
                        _reAnchorQuest = null;
                        _reAnchorDay = null;
                      });
                      widget.onPersist();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// A clear, tappable "good morning" prompt whenever the briefing is owed —
  /// so a missed auto-show never leaves the morning unreachable (user report).
  /// Wraps a dismissible board card so it can be SWIPED away (satisfying and
  /// freeing — clears the deck so the quests come forward), not just poked at a
  /// tiny ×. [onGone] stamps it seen; the swipe slides it off then rebuilds.
  Widget _swipeAway({
    required String dismissKey,
    required VoidCallback onGone,
    required Widget child,
  }) {
    return Dismissible(
      key: ValueKey('board-$dismissKey'),
      direction: DismissDirection.horizontal,
      onDismissed: (_) {
        Sfx.instance.play('tick');
        HapticFeedback.selectionClick();
        setState(onGone);
        widget.onPersist();
      },
      child: child,
    );
  }

  /// The "Ember of the Day" — a small, fun, today-only bonus quest offered once
  /// a day (domain rotates). Tap ADD to drop it on the board as a ⚡ bonus
  /// (expires at dawn); or dismiss. Pure novelty, never an obligation.
  Widget _emberPanel() {
    if (!_state.emberDue) return const SizedBox.shrink();
    final now = DateTime.now();
    final e = emberOfDay(now);
    void dismiss() {
      _state.dismissEmber();
      widget.onPersist();
    }

    return _swipeAway(
      dismissKey: 'ember',
      onGone: () => _state.emberSeenDay = Days.key(now),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: GlassPanel(
          child: Row(
            children: [
              Icon(Icons.local_fire_department, size: 18, color: e.stat.color),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'EMBER OF THE DAY',
                          style: Type.label.copyWith(
                            fontSize: 11,
                            color: e.stat.color,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          e.stat.abbr,
                          style: Type.label.copyWith(
                            fontSize: 10,
                            color: Palette.textLo,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      e.title,
                      style: Type.body.copyWith(
                        fontSize: 13.5,
                        color: Palette.textHi,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  final ok = widget.onAdd(
                    Quest(
                      title: e.title,
                      stat: e.stat,
                      difficulty: 2,
                      schedule: QuestSchedule.once,
                      dueDate: DateTime(now.year, now.month, now.day),
                      bonus: true,
                      custom: true,
                    ),
                  );
                  if (ok) {
                    Sfx.instance.play('streak');
                    HapticFeedback.selectionClick();
                  }
                  dismiss();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: e.stat.color.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Text(
                    'ADD',
                    style: Type.label.copyWith(
                      fontSize: 11,
                      color: e.stat.color,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  Sfx.instance.play('tick');
                  dismiss();
                },
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Icon(Icons.close, size: 16, color: Palette.textLo),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// A once-a-week look-back the first time you open the board in a new week —
  /// last week's days-lit + total, vs the week before. Dismissible, never nags.
  Widget _weekRecapPanel() {
    if (!_state.weekRecapDue) return const SizedBox.shrink();
    final r = _state.weeklyRecap();
    final deltaLine = r.delta > 0
        ? '▲ ${r.delta} more than the week before — your strongest stretch yet.'
        : r.delta < 0
        ? 'a quieter week than the one before — this new one is yours to claim.'
        : 'steady with the week before — consistency is its own win.';
    return _swipeAway(
      dismissKey: 'weekrecap',
      onGone: () =>
          _state.weekRecapSeenWeek = Days.key(Days.weekStart(DateTime.now())),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: GlassPanel(
          glow: true,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.calendar_today,
                size: 17,
                color: Palette.xpLight,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LAST WEEK',
                      style: Type.label.copyWith(
                        fontSize: 11,
                        color: Palette.xpLight,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'You lit ${r.litDays} of 7 days — ${r.total} '
                      'quest${r.total == 1 ? '' : 's'}.',
                      style: Type.body.copyWith(
                        fontSize: 13.5,
                        color: Palette.textHi,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      deltaLine,
                      style: Type.body.copyWith(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: Palette.textLo,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  Sfx.instance.play('tick');
                  _state.dismissWeekRecap();
                  widget.onPersist();
                },
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Icon(Icons.close, size: 16, color: Palette.textLo),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
                    Text(
                      'GOOD MORNING',
                      style: Type.label.copyWith(
                        fontSize: 11,
                        color: Palette.streak,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'tap to see what’s ahead today ☀️',
                      style: Type.body.copyWith(
                        fontSize: 13.5,
                        color: Palette.textHi,
                      ),
                    ),
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
    return _swipeAway(
      dismissKey: 'spark',
      onGone: () => _state.sparkSeenDay = today,
      child: Padding(
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
                    Text(
                      'TODAY’S SPARK',
                      style: Type.label.copyWith(
                        fontSize: 11,
                        color: Palette.xpLight,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      line,
                      style: Type.body.copyWith(
                        fontSize: 13.5,
                        color: Palette.textHi,
                      ),
                    ),
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
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Icon(Icons.close, size: 16, color: Palette.textLo),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Focus mode's body: one suggested quest, a calm queued-count, the all-day
  /// footer, and a way back to the full board. Completing runs the normal
  /// reward path; the next quest surfaces on the rebuild.
  Widget _focusBody(List<Quest> pool, int allDayLeft, DateTime now) {
    final q = pool.first;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 130),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 2, 6, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'NEXT UP · 1 OF ${pool.length}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Type.label.copyWith(
                    fontSize: 12,
                    color: Palette.streak,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _FocusLensToggle(
                lens: _focusLens,
                onChanged: (l) => setState(() => _focusLens = l),
              ),
            ],
          ),
        ),
        // swap with a soft cross-fade so toggling the lens is visibly felt
        AnimatedSwitcher(
          duration: Motion.settle,
          switchInCurve: Motion.respond,
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SizeTransition(sizeFactor: anim, child: child),
          ),
          child: QuestCard(
            key: ValueKey('focus-${q.title}'),
            quest: q,
            done: false,
            xpPreview: _state.xpPreview(q),
            onComplete: (pos) => _completeQuest(q, pos),
            onManage: () => _manageQuest(q),
          ),
        ),
        const SizedBox(height: 16),
        if (pool.length > 1)
          Center(
            child: Text(
              '${pool.length - 1} more waiting — one at a time',
              textAlign: TextAlign.center,
              style: Type.body.copyWith(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: Palette.textLo,
              ),
            ),
          ),
        if (allDayLeft > 0) ...[
          const SizedBox(height: 10),
          Center(
            child: Text(
              '$allDayLeft all-day · checked tonight',
              style: Type.label.copyWith(fontSize: 11, color: Palette.unlock),
            ),
          ),
        ],
        const SizedBox(height: 22),
        Center(
          child: GestureDetector(
            onTap: _toggleFocus,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Text(
                'SEE THE FULL BOARD',
                style: Type.label.copyWith(fontSize: 11, color: Palette.textLo),
              ),
            ),
          ),
        ),
      ],
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
    final visible =
        [
          for (final q in widget.quests)
            // "hide just for today" skips it from the board until tomorrow
            if (q.snoozedDay != today &&
                (q.isEvent
                    ? (!q.dueDate!.isAfter(endOfToday) || q.doneFor(now))
                    : (q.scheduledOn(now) || q.lastDoneDay == today)))
              q,
        ]..sort((a, b) {
          // finished quests sink to the bottom so the board visibly shrinks
          // toward the top as you clear it — banked wins, not interleaved
          // clutter. The most-recent win stays put (undo lives on it).
          bool banked(Quest q) => q.doneFor(now) && q.title != _pinnedDoneTitle;
          final ad = banked(a), bd = banked(b);
          if (ad != bd) return ad ? 1 : -1;
          // then: due events first, starred MAIN next, the rest, all-day last
          // (nothing to tap on an all-day line until tonight)
          int rank(Quest q) =>
              q.allDay ? 3 : (q.isEvent ? 0 : (q.priority ? 1 : 2));
          return rank(a).compareTo(rank(b));
        });
    final remaining = visible.where((q) => !q.doneFor(now)).length;

    // Focus mode: the actionable pool (all-day lines have nothing to tap until
    // night, so they're never the "next" focus — shown as a footer count).
    // Tiered order: overdue events → due-today events → starred MAIN → the
    // rest (by the energy lens) → bonus last.
    final actionable =
        [
          for (final q in visible)
            if (!q.doneFor(now) && !q.allDay) q,
        ]..sort((a, b) {
          // Time-sensitive events float to the top; everything else (incl.
          // starred MAIN quests) is ordered by the chosen lens, so toggling
          // EASE IN / HARDEST visibly changes the focused quest (the lens IS
          // your stated preference in focus mode). Bonus spawns sink last.
          int tier(Quest q) {
            if (q.isEvent) {
              return q.dueDate!.isBefore(DateTime(now.year, now.month, now.day))
                  ? 0
                  : 1;
            }
            if (q.bonus) return 3;
            return 2;
          }

          final ta = tier(a), tb = tier(b);
          if (ta != tb) return ta.compareTo(tb);
          // within a tier, the energy lens decides
          if (a.dread != b.dread) {
            if (_focusLens == _FocusLens.hardest) return a.dread ? -1 : 1;
            return a.dread ? 1 : -1;
          }
          final xa = _state.xpPreview(a), xb = _state.xpPreview(b);
          return _focusLens == _FocusLens.hardest
              ? xb.compareTo(xa)
              : xa.compareTo(xb);
        });
    final allDayLeft = visible.where((q) => q.allDay && !q.doneFor(now)).length;
    final showFocus = _state.focusMode && actionable.isNotEmpty;

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
                      // today's clear-progress — the ring fills as you go
                      progress: visible.isEmpty
                          ? 0.0
                          : (visible.length - remaining) / visible.length,
                      child: Portrait(
                        size: 44,
                        mood: _beaming ? PortraitMood.happy : PortraitMood.idle,
                        aura:
                            cosmeticFor(_state.equippedSkin)?.aura ??
                            _state.dominantStat?.color,
                        level: _state.level,
                        badge: cosmeticFor(_state.equippedSkin)?.badge ?? false,
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
                              Text(
                                'LEVEL ${_state.level}',
                                style: Type.label.copyWith(fontSize: 13),
                              ),
                              // clamp: pre-level-up overflow reads as a
                              // full bar, never "130 / 105"
                              Flexible(
                                child: Text(
                                  '${min(_state.xp, next)} / $next XP',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Type.numerals.copyWith(
                                    fontSize: 16,
                                    color: Palette.xp,
                                  ),
                                ),
                              ),
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
                                  size: 13,
                                  color: Palette.textLo,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'NEXT · ${_state.nextChaseLabel()}',
                                  style: Type.label.copyWith(fontSize: 12),
                                ),
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
        _weekRecapPanel(),
        _emberPanel(),
        _reAnchorPanel(),
        _sparkPanel(),

        // ── Quest list ──────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 8, 14, 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  showFocus ? 'FOCUS MODE' : 'TODAY · $remaining LEFT',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Type.label.copyWith(
                    fontSize: 12,
                    color: showFocus ? Palette.streak : null,
                  ),
                ),
              ),
              Row(
                children: [
                  // one-quest-at-a-time toggle (round-21): tames the overwhelm
                  _HeaderAction(
                    icon: _state.focusMode
                        ? Icons.center_focus_strong
                        : Icons.center_focus_weak,
                    color: _state.focusMode ? Palette.streak : Palette.xpLight,
                    onTap: _toggleFocus,
                  ),
                  _HeaderAction(
                    icon: Icons.add_circle_outline,
                    color: Palette.xpLight,
                    onTap: _quickAdd,
                  ),
                  // the day's bookends: sun while a morning briefing is
                  // reachable (always tappable, not just on auto-show),
                  // moon until tonight's close-out is done
                  if (_state.morningAvailable)
                    _HeaderAction(
                      icon: Icons.wb_twilight,
                      color: Palette.streak,
                      onTap: _openMorning,
                    )
                  else if (_state.nightDoneDay != today)
                    _HeaderAction(
                      icon: Icons.nightlight_round,
                      color: Palette.xpLight,
                      onTap: _openNight,
                    )
                  else
                    const _HeaderAction(
                      icon: Icons.nightlight_round,
                      color: Palette.textLo,
                    ),
                  // the momentum spark: cleared something? push further.
                  _HeaderAction(
                    icon: Icons.bolt,
                    color: Palette.xpLight,
                    onTap: _openMomentum,
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: showFocus
              ? _focusBody(actionable, allDayLeft, now)
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 130),
                  itemCount: visible.isEmpty
                      ? 1
                      : visible.length + (remaining == 0 ? 1 : 0),
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    // a board with nothing on it — invite the first ember, don't
                    // pretend a day was "cleared" when none was
                    if (visible.isEmpty) {
                      return GlassPanel(
                        child: Column(
                          children: [
                            const Icon(
                              Icons.local_fire_department_outlined,
                              size: 26,
                              color: Palette.xpLight,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'A clear board',
                              style: Type.display.copyWith(fontSize: 20),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'add a quest with + above, or take on a goal — '
                              'light the first ember and the day tilts your way',
                              textAlign: TextAlign.center,
                              style: Type.body.copyWith(
                                fontSize: 13.5,
                                fontStyle: FontStyle.italic,
                                color: Palette.textLo,
                              ),
                            ),
                            const SizedBox(height: 12),
                            GestureDetector(
                              onTap: _quickAdd,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 9,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: Palette.xpLight.withValues(
                                      alpha: 0.6,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  'ADD A QUEST',
                                  style: Type.label.copyWith(
                                    fontSize: 11,
                                    color: Palette.xpLight,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    // the day, cleared — celebrate and hand off to the night
                    if (remaining == 0 && i == 0) {
                      return TweenAnimationBuilder<double>(
                        // a gentle pop-in: the candles flaring up as the day closes
                        tween: Tween(begin: 0, end: 1),
                        duration: Motion.takeover,
                        curve: Curves.easeOutBack,
                        builder: (_, t, child) => Opacity(
                          opacity: t.clamp(0.0, 1.0),
                          child: Transform.scale(
                            scale: 0.9 + 0.1 * t,
                            child: child,
                          ),
                        ),
                        child: GlassPanel(
                          glow: true,
                          child: Column(
                            children: [
                              const Icon(
                                Icons.auto_awesome,
                                size: 26,
                                color: Palette.xpLight,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Day cleared ✨',
                                style: Type.display.copyWith(fontSize: 20),
                              ),
                              const SizedBox(height: 8),
                              // the day reflected back — which domains you
                              // tended, in the app's warm voice (round-32)
                              Text(
                                _state.todaysShape(),
                                textAlign: TextAlign.center,
                                style: Type.body.copyWith(
                                  fontSize: 14,
                                  height: 1.4,
                                  color: Palette.textMid,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _state.nightDoneDay == today
                                    ? 'rest well — tomorrow is already taking shape'
                                    : 'nothing left but the goodnight',
                                style: Type.body.copyWith(
                                  fontSize: 13.5,
                                  fontStyle: FontStyle.italic,
                                  color: Palette.textLo,
                                ),
                              ),
                              // peak-end: you cleared it — still hot? push further
                              const SizedBox(height: 10),
                              GestureDetector(
                                onTap: _openMomentum,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.bolt,
                                      size: 13,
                                      color: Palette.streak,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'keep the fire going',
                                      style: Type.label.copyWith(
                                        fontSize: 11,
                                        color: Palette.streak,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_state.nightDoneDay != today) ...[
                                const SizedBox(height: 12),
                                GestureDetector(
                                  onTap: _openNight,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 9,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: Palette.xpLight.withValues(
                                          alpha: 0.6,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      'CLOSE OUT THE DAY 🌙',
                                      style: Type.label.copyWith(
                                        fontSize: 11,
                                        color: Palette.xpLight,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }
                    final q = visible[remaining == 0 ? i - 1 : i];
                    final isDone = q.doneFor(now);
                    final card = QuestCard(
                      // stable key so a card's squash/state follows it as the list
                      // re-sorts a finished quest down to the bottom
                      key: ValueKey('card-${q.title}'),
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
                          DismissDirection.endToStart: 0.42,
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
                              const Icon(
                                Icons.undo,
                                size: 16,
                                color: Palette.xpLight,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'UNDO',
                                style: Type.label.copyWith(
                                  fontSize: 11,
                                  color: Palette.xpLight,
                                ),
                              ),
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

/// A board-header action: an icon inside a 44pt tap target (iOS HIG minimum).
/// Omit [onTap] for a disabled/indicator state (e.g. the spent moon).
class _HeaderAction extends StatelessWidget {
  const _HeaderAction({required this.icon, required this.color, this.onTap});
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Icon(icon, size: 23, color: color),
      ),
    );
  }
}

/// Focus mode's energy-lens segmented pill: EASE IN (quick wins first) vs
/// HARDEST (most-dreaded / heaviest first). A gentle either/or, not raw sorts.
class _FocusLensToggle extends StatelessWidget {
  const _FocusLensToggle({required this.lens, required this.onChanged});
  final _FocusLens lens;
  final ValueChanged<_FocusLens> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget seg(_FocusLens l, String label) {
      final on = lens == l;
      return GestureDetector(
        onTap: () => onChanged(l),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: Motion.quick,
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: on ? Palette.xpLight.withValues(alpha: 0.22) : null,
          ),
          child: Text(
            label,
            style: Type.label.copyWith(
              fontSize: 10,
              color: on ? Palette.xpLight : Palette.textLo,
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Palette.glassEdge),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          seg(_FocusLens.quickWin, 'EASE IN'),
          seg(_FocusLens.hardest, 'HARDEST'),
        ],
      ),
    );
  }
}

/// The portrait inside a slowly breathing ring that mirrors XP progress.
/// Keyed by level (like XpBar's generation) so a level-up refills from 0
/// instead of draining backwards; the breathe is the §2 ambient idle motion.
/// The "ON A ROLL ×N" flourish for back-to-back clears — a warm pill that pops
/// near the top, the word escalating with the combo, then fades. Never a
/// takeover; pure momentum warmth (round-33).
class _ComboFlourish extends StatefulWidget {
  const _ComboFlourish({required this.combo, required this.onDone});
  final int combo;
  final VoidCallback onDone;

  @override
  State<_ComboFlourish> createState() => _ComboFlourishState();
}

class _ComboFlourishState extends State<_ComboFlourish>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1300),
      )..addStatusListener((s) {
        if (s == AnimationStatus.completed) widget.onDone();
      });

  @override
  void initState() {
    super.initState();
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  static String _word(int n) {
    if (n >= 5) return 'UNSTOPPABLE';
    if (n == 4) return 'BLAZING';
    if (n == 3) return 'ON FIRE';
    return 'ON A ROLL';
  }

  @override
  Widget build(BuildContext context) {
    // Positioned.fill is the overlay entry's top-level (the Overlay theatre is
    // a Stack); position the pill within it via Align, not a bare Positioned.
    return Positioned.fill(
      child: OverlaySurface(
        child: IgnorePointer(
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, _) {
              final t = _c.value;
              final inP = Curves.easeOutBack.transform(
                (t / 0.22).clamp(0.0, 1.0),
              );
              final out = ((t - 0.72) / 0.28).clamp(0.0, 1.0);
              return Align(
                alignment: Alignment(0, -0.62 - 0.06 * out),
                child: Opacity(
                  opacity: (1 - out).clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: 0.7 + 0.3 * inP,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: Palette.card.withValues(alpha: 0.92),
                        border: Border.all(
                          color: Palette.streak.withValues(alpha: 0.7),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Palette.streak.withValues(alpha: 0.4),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.local_fire_department,
                            size: 16,
                            color: Palette.streak,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${_word(widget.combo)} · ×${widget.combo}',
                            style: Type.label.copyWith(
                              fontSize: 13,
                              color: Palette.streak,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The portrait's ring now tracks TODAY'S clear-progress (it fills as you clear
/// the board), not XP — XP already lives in the bar + numeral right beside it,
/// so the ring earns its own job (round-31: no triple-encoding one value).
class _LevelRing extends StatefulWidget {
  const _LevelRing({required this.progress, required this.child});
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
          final wave = Motion.ambient.transform(
            (_breathe.value * 56).round() / 56,
          );
          return Transform.scale(
            scale: 1 + 0.02 * wave,
            child: TweenAnimationBuilder<double>(
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
                    Text(
                      '${stat.abbr} RANKED UP',
                      style: Type.label.copyWith(
                        fontSize: 11,
                        color: stat.color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'You’re ${rank.label} now',
                  style: Type.display.copyWith(fontSize: 24),
                ),
                const SizedBox(height: 16),
                Text(
                  'WHY THIS WORKS',
                  style: Type.label.copyWith(fontSize: 11, color: Palette.info),
                ),
                const SizedBox(height: 6),
                Text(card.title, style: Type.display.copyWith(fontSize: 16)),
                const SizedBox(height: 6),
                Text(
                  card.text,
                  style: Type.body.copyWith(
                    fontSize: 13,
                    height: 1.5,
                    color: Palette.textMid,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.menu_book_outlined,
                      size: 11,
                      color: Palette.info,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        card.source,
                        style: Type.label.copyWith(
                          fontSize: 11,
                          color: Palette.info,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    'tap to keep going →',
                    style: Type.label.copyWith(fontSize: 11),
                  ),
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

  Iterable<String> _boardTitles() => widget.quests.map((q) => q.displayTitle);

  void _stoke(Quest q) {
    final l = q.ladder;
    if (l == null) return;
    final next = (q.rung + 1).clamp(0, l.length - 1);
    final root = q.origin ?? q.title;
    final ok = widget.onAdd(
      Quest(
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
      ),
    );
    _afterSpawn(ok, l[next]);
  }

  void _switch(Quest q) {
    final variants = Ladders.variantsFor(q, _boardTitles());
    if (variants.isEmpty) return;
    final pick = variants.first;
    final ok = widget.onAdd(
      Quest(
        title: pick,
        stat: q.stat,
        difficulty: q.difficulty,
        schedule: QuestSchedule.once,
        dueDate: DateTime(_now.year, _now.month, _now.day),
        bonus: true,
        origin: q.origin ?? q.title,
      ),
    );
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
            maxHeight: MediaQuery.sizeOf(context).height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.bolt, size: 16, color: Palette.xpLight),
                  const SizedBox(width: 6),
                  Text(
                    'KEEP THE FIRE GOING',
                    style: Type.label.copyWith(
                      fontSize: 11,
                      color: Palette.xpLight,
                    ),
                  ),
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
                  color: Palette.textLo,
                ),
              ),
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
                                const Icon(
                                  Icons.bolt,
                                  size: 13,
                                  color: Palette.streak,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '$t — on the board',
                                    style: Type.body.copyWith(
                                      fontSize: 13,
                                      color: Palette.textMid,
                                    ),
                                  ),
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
                Text(
                  _note!,
                  style: Type.body.copyWith(
                    fontSize: 11,
                    color: const Color(0xFFE89090),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: GestureDetector(
                      onTap: _shuffle,
                      child: Text(
                        _shuffled == null
                            ? 'shuffle the board'
                            : _shuffled == 0
                            ? 'board’s all here'
                            : 'pulled $_shuffled back',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Type.label.copyWith(
                          fontSize: 11,
                          color: Palette.textLo.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xFFF6D9A2),
                            Color(0xFFEFC074),
                            Color(0xFFC08B4F),
                          ],
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Palette.honeyGlow,
                            blurRadius: 14,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Text(
                        _spawned.isEmpty ? 'NOT NOW' : 'LET’S GO',
                        style: Type.label.copyWith(
                          fontSize: 11,
                          color: const Color(0xFF3A2510),
                        ),
                      ),
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
                child: Text(
                  q.displayTitle,
                  style: Type.body.copyWith(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: Palette.textHi,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (capped)
            Text(
              'you’ve stoked this plenty today — rest is part of the build',
              style: Type.body.copyWith(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: Palette.textLo,
              ),
            )
          else if (!canStoke && !canSwitch)
            Text(
              'already covered — every variant’s on the board',
              style: Type.body.copyWith(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: Palette.textLo,
              ),
            )
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
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 160),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: highlight
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFFF6D9A2),
                      Color(0xFFEFC074),
                      Color(0xFFC08B4F),
                    ],
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
              Text(label, style: Type.label.copyWith(fontSize: 11, color: fg)),
              if (sub != null)
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text(
                    sub!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Type.body.copyWith(
                      fontSize: 11,
                      color: highlight
                          ? const Color(0xFF3A2510)
                          : Palette.textMid,
                    ),
                  ),
                ),
            ],
          ),
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
  late List<int> _weekdays = List.of(widget.quest.weekdays);

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
            Text('TUNE THIS QUEST', style: Type.label.copyWith(fontSize: 11)),
            const SizedBox(height: 4),
            Text(
              widget.quest.displayTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Type.display.copyWith(fontSize: 16),
            ),
            const SizedBox(height: 12),
            Text('TRAINS', style: Type.label.copyWith(fontSize: 11)),
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
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: _stat == s
                            ? s.color.withValues(alpha: 0.22)
                            : Colors.transparent,
                        border: Border.all(
                          color: s.color.withValues(
                            alpha: _stat == s ? 0.8 : 0.3,
                          ),
                        ),
                      ),
                      child: Text(
                        s.abbr,
                        style: Type.label.copyWith(
                          fontSize: 11,
                          color: s.color,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            DomainHint(_stat),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  'd${_difficulty.round()}',
                  style: Type.label.copyWith(fontSize: 11, color: Palette.xp),
                ),
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
            if (widget.quest.schedule == QuestSchedule.weekly) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Text('LANDS ON', style: Type.label.copyWith(fontSize: 11)),
                  const SizedBox(width: 12),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () async {
                      final day = await pickWeekday(
                        context,
                        accent: _stat.color,
                        questTitle: widget.quest.title,
                        initial: _weekdays.isNotEmpty ? _weekdays.first : null,
                      );
                      if (day == null) return;
                      setState(() => _weekdays = day == 0 ? [] : [day]);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: _stat.color.withValues(alpha: 0.6),
                        ),
                      ),
                      child: Text(
                        weekdayLabel(_weekdays),
                        style: Type.label.copyWith(
                          fontSize: 11,
                          color: _stat.color,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            Center(
              child: GestureDetector(
                onTap: () {
                  Sfx.instance.play('streak');
                  HapticFeedback.selectionClick();
                  widget.quest.difficulty = _difficulty.round();
                  widget.quest.stat = _stat;
                  widget.quest.weekdays = _weekdays;
                  widget.onSaved();
                  Navigator.of(context).pop();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFFF6D9A2),
                        Color(0xFFEFC074),
                        Color(0xFFC08B4F),
                      ],
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Palette.honeyGlow,
                        blurRadius: 14,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    'SAVE',
                    style: Type.label.copyWith(
                      fontSize: 11,
                      color: const Color(0xFF3A2510),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
