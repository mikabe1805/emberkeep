import 'dart:async';
import 'dart:math' show min, pi, sin;

import 'package:flutter/foundation.dart' show ValueListenable, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio.dart';
import '../clock.dart';
import '../content/achievements.dart';
import '../content/cosmetics.dart';
import '../content/creature_skins.dart';
import '../content/day_planning.dart';
import '../content/embers.dart';
import '../content/evidence.dart';
import '../content/ladders.dart';
import '../content/quest_desk_styles.dart';
import '../content/routines.dart';
import '../content/space_themes.dart';
import '../content/sparks.dart';
import '../content/stat_ranks.dart';
import '../engine.dart';
import '../room_photo.dart';
import '../haptics.dart';
import '../journal_media.dart' as journal_media;
import '../models.dart';
import '../storage.dart';
import '../tokens.dart';
import '../widgets/workout_flow.dart';
import 'journal_entry.dart';
import '../widgets/achievement_toast.dart';
import '../widgets/day_picker.dart';
import '../widgets/domain_hint.dart';
import '../widgets/ember_sheet.dart';
import '../widgets/epic_overlay.dart';
import '../widgets/count_up.dart';
import '../widgets/facets.dart';
import '../widgets/glass.dart';
import '../widgets/gold_surface.dart';
import '../widgets/honey_button.dart';
import '../widgets/install_hint.dart';
import '../widgets/levelup_overlay.dart';
import '../widgets/share_moment_card.dart';
import '../widgets/luxe_depth.dart';
import '../widgets/particles.dart';
import '../widgets/home_room.dart';
import '../widgets/notes_sheet.dart';
import '../widgets/quest_card.dart';
import '../widgets/quest_desk.dart';
import '../widgets/reward_receipt.dart';
import '../widgets/routine_flows.dart';
import '../widgets/timer_overlay.dart';
import '../widgets/top_three_wizard.dart';
import '../widgets/streak_milestone_overlay.dart';
import '../widgets/stat_chips.dart';
import '../widgets/streak_freeze_status.dart';

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
    this.onBindFlush,
    this.onBindComplete,
    this.onBindOpenWorkout,
    this.onNightClosed,
    this.parallax,
    this.lightDirection,
    this.roomIgniting = false,
    this.roomHearthLit = true,
    this.focusQuestTitle,
    this.focusRequestId = 0,
    this.workoutRequestId = 0,
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

  /// Lets the shell flush a pending deferred commit before pause-path saves.
  final void Function(VoidCallback flush)? onBindFlush;

  /// Lets another kept-alive surface invoke this page's one canonical Quest
  /// completion pipeline without copying reward or persistence logic.
  final void Function(void Function(Quest quest, Offset anchor) complete)?
  onBindComplete;

  /// Lets the Goals page enter the same canonical workout picker without
  /// manufacturing another launcher or duplicating reward logic.
  final void Function(void Function(Quest launcher) open)? onBindOpenWorkout;

  /// Lets the shell push an enabled night reminder to tomorrow immediately
  /// after this evening's ledger closes.
  final VoidCallback? onNightClosed;

  /// The shell's calibrated tilt/pointer source. Directly-constructed pages
  /// retain the local fallback below.
  final ValueListenable<Offset>? parallax;

  /// The quicker reflected-light response. Keeping this separate from the
  /// weightier room camera makes gold answer the hand without making the
  /// painted environment feel floaty.
  final ValueListenable<Offset>? lightDirection;

  /// Owned by the shell's non-persisted app-session gate. This is not a tab
  /// transition effect: it is only the room's first visible wake-up.
  final bool roomIgniting;

  /// Whether this app session has completed its one visible room ignition.
  /// Direct page previews retain a lit hearth; the real shell starts dark.
  final bool roomHearthLit;

  /// A one-shot handoff from Goals. The requested Quest becomes the first
  /// actionable card and the board returns to its top so the tap has a visible
  /// destination rather than merely changing tabs.
  final String? focusQuestTitle;
  final int focusRequestId;

  /// A one-shot request from the Goals workout door. The Quests page remains
  /// the sole owner of the runner and reward path, even when another room is
  /// the entry point.
  final int workoutRequestId;

  @override
  State<QuestsPage> createState() => _QuestsPageState();
}

class _QuestsPageState extends State<QuestsPage> with WidgetsBindingObserver {
  GameState get _state => widget.state;

  /// One scroll surface carries the HUD and quests across the fixed room.
  /// Listening directly keeps the atmospheric blur paint-only: quest data does
  /// not rebuild for every pixel of a drag.
  late final ScrollController _boardScroll = ScrollController();

  /// The shell normally owns one motion source for all five pages. A local
  /// controller remains for tests and directly-constructed quest pages.
  LuxeMotionController? _localMotion;
  final ValueNotifier<double> _scrollLight = ValueNotifier(0);

  ValueListenable<Offset> get _activeLight =>
      widget.lightDirection ??
      widget.parallax ??
      _localMotion?.light ??
      const AlwaysStoppedAnimation<Offset>(Offset.zero);

  ValueListenable<Offset> get _activeParallax =>
      widget.parallax ?? _localMotion?.parallax ?? _activeLight;

  // ── deferred-commit machinery (flushable, so rapid completions and undo
  // can't corrupt each other's state) ───────────────────────────────────
  Timer? _commitTimer;
  GameState? _pendingState;
  RewardBundle? _pendingBundle;
  String? _pendingSnapshot;
  String? _pendingTitle;

  /// Achievement checks happen when rewards commit, but their banners wait
  /// until every reward receipt has cleared. This keeps the first completion
  /// from stacking "First Step" over the still-arriving XP/stat bubbles.
  final List<Achievement> _pendingAchievementToasts = [];
  final Set<Timer> _achievementToastTimers = {};
  int _activeReceipts = 0;

  /// The reward rail is a protected band above the dock. The board measures the
  /// featured card against it so a completion can never park its receipt on top
  /// of the next quest's action — the bible's one hard rule for the rail.
  static const double _rewardRailBand = 200;
  final GlobalKey _featuredAnchor = GlobalKey();

  /// Lift the featured quest clear of the reward rail, by the smallest amount
  /// that does it, and only when it is actually behind the rail. Nothing moves
  /// when the action is already in the clear.
  void _clearFeaturedOfRewardRail() {
    if (!mounted) return;
    final anchor = _featuredAnchor.currentContext;
    if (anchor == null) return;
    final box = anchor.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return;
    final viewport = MediaQuery.sizeOf(context);
    final railTop =
        viewport.height -
        MediaQuery.paddingOf(context).bottom -
        96 -
        _rewardRailBand;
    final cardBottom = box.localToGlobal(Offset.zero).dy + box.size.height;
    if (cardBottom <= railTop - 10) return;
    final still =
        _state.reduceMotion ||
        (MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    unawaited(
      Scrollable.ensureVisible(
        anchor,
        alignment: 0.30,
        alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
        duration: still ? Duration.zero : const Duration(milliseconds: 340),
        curve: Motion.respond,
      ),
    );
  }

  /// One guided-workout runner at a time (rapid double-tap can't spawn two
  /// runners → double reward; bug-hunt §8).
  bool _workoutRunnerOpen = false;

  /// A fast double-tap must not push two editors for the same Journal Quest.
  /// The durable duplicate guard is the Note's [Note.sourceQuestKey]; this
  /// small route guard closes the few-millisecond gap before Navigator paints.
  bool _journalRouteOpen = false;

  /// One closing ledger at a time. The flow's own guard prevents a double
  /// submit inside one overlay; this prevents two overlays from being opened
  /// by rapid taps on separate entry points.
  OverlayEntry? _nightOverlay;

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

  /// Gentle Mode shelters the board by default, but the keeper can briefly
  /// reveal everything without changing or losing the chosen three.
  bool _showFullLowFlame = false;

  /// A shaped day has two honest layers: the few things deliberately carried,
  /// and the rest of the board, which stays available without becoming a
  /// debt ledger. This only changes what is expanded on this visit; the dated
  /// field itself is persisted on the quests.
  bool _showOptionalField = false;

  void _toggleFocus() {
    _state.setFocusMode(!_state.focusMode);
    widget.onPersist();
    Haptics.tap();
    setState(() {});
  }

  Future<void> _openQuestDeskStyle() async {
    final current = activeQuestDeskLook(_state);
    final selected = await showModalBottomSheet<QuestDeskLook>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 22),
          child: GlassPanel(
            blur: true,
            // Smoked walnut glass, not a lit sheet. Lerping from the 9%-cream
            // glassFill over a BackdropFilter made this the largest light area
            // in the app — a pale grey-taupe plane from an older generation
            // sitting on top of a candlelit room.
            tint: Color.lerp(const Color(0xF41C1512), current.wood, 0.12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'YOUR ROOM',
                  style: Type.display.copyWith(
                    fontSize: 24,
                    color: Palette.textHi,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'The same room in Me, Quests, and your public preview. '
                  'Choose any room you already own.',
                  style: Type.body.copyWith(
                    fontSize: 12,
                    color: Palette.textLo,
                  ),
                ),
                const SizedBox(height: 14),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 430),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        for (final look in questDeskLooks)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _QuestDeskLookRow(
                              look: look,
                              selected: current.roomStyleId == look.roomStyleId,
                              owned: isQuestDeskLookOwned(_state, look),
                              price:
                                  spaceThemeById(look.roomStyleId)?.price ?? 0,
                              onTap: () {
                                if (!isQuestDeskLookOwned(_state, look)) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      behavior: SnackBarBehavior.floating,
                                      backgroundColor: Palette.card,
                                      content: Text(
                                        'Choose ${look.name} in Change your space first.',
                                        style: Type.body.copyWith(
                                          color: Palette.textHi,
                                        ),
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                Navigator.of(sheetContext).pop(look);
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (selected == null || !mounted) return;
    await preloadSpaceTheme(selected.roomStyleId);
    if (!mounted) return;
    _state.applyStyle(selected.roomStyleId, RoomStyleKind.wall);
    widget.onPersist();
    Haptics.tap();
    setState(() {});
  }

  List<Quest> _lowFlameCandidates(DateTime day) =>
      planningQuestsForDay(widget.quests, day);

  Future<void> _editLowFlameThree() async {
    final now = Clock.now();
    final candidates = _lowFlameCandidates(now);
    final initial = _state.lowFlameQuestTitles.isEmpty
        ? suggestedLowFlameQuests(candidates, now).map((q) => q.title)
        : _state.lowFlameQuestTitles;
    final chosen = await showTopThreeWizard(
      context,
      title: 'Shelter the day',
      subtitle:
          'Choose up to three things worth carrying. Everything else rests without penalty.',
      dayLabel: 'Gentle Mode · Today',
      candidates: candidates.where((q) => !q.allDay),
      initialTitles: initial,
      accent: Stat.vit.color,
      confirmLabel: 'SHELTER THE DAY',
    );
    if (chosen == null || !mounted) return;
    setState(() {
      _state.setLowFlameQuests(chosen);
      _showFullLowFlame = false;
    });
    widget.onPersist();
  }

  Future<void> _chooseToday() async {
    final now = Clock.now();
    final candidates = planningQuestsForDay(
      widget.quests,
      now,
    ).where((q) => !q.allDay && !q.isEvent);
    final chosen = await showTopThreeWizard(
      context,
      title: 'Choose today',
      subtitle:
          'Pick up to three quests to carry. Everything else stays open if the day has room.',
      dayLabel: 'Today’s field',
      candidates: candidates,
      initialTitles: selectedDailyFieldForDay(
        widget.quests,
        now,
      ).map((q) => q.title),
      accent: Palette.xpLight,
      confirmLabel: 'SET TODAY’S FIELD',
    );
    if (chosen == null || !mounted) return;
    applyDailyField(widget.quests, now, chosen);
    setState(() => _showOptionalField = false);
    widget.onPersist();
  }

  Future<void> _planTomorrow(VoidCallback dismissEmber) async {
    final now = Clock.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final candidates = planningQuestsForDay(
      widget.quests,
      tomorrow,
    ).where((q) => !q.allDay && !q.isEvent).toList(growable: false);
    final initial = candidates
        .where((q) => q.priorityOn(tomorrow))
        .map((q) => q.title);
    final chosen = await showTopThreeWizard(
      context,
      title: 'Shape tomorrow',
      subtitle:
          'Pick up to three quests to lead the morning. This is a compass, not another obligation.',
      dayLabel: 'Tomorrow’s Three',
      candidates: candidates,
      initialTitles: initial,
      accent: Palette.xpLight,
      confirmLabel: 'SET TOMORROW’S THREE',
      onAdd: () async {
        final quest = await showEmberSheet(
          context,
          const EmberSheetConfig(surface: EmberSurface.tomorrow),
        );
        if (quest == null) return null;
        if (!widget.onAdd(quest)) {
          Sfx.instance.play('boing');
          return null;
        }
        return quest;
      },
    );
    if (chosen == null || !mounted) return;

    // The shared helper writes a stable dated rank as well as retiring only
    // the relevant standing stars. A hand-written loop used to lose the order
    // a keeper chose for tomorrow.
    applyDailyField(widget.quests, tomorrow, chosen);
    widget.onPersist();
    dismissEmber();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Palette.card,
        content: Text(
          chosen.length == 1
              ? 'Tomorrow has one clear lead.'
              : 'Tomorrow’s ${chosen.length} leading quests are set.',
          style: Type.body.copyWith(color: Palette.textHi),
        ),
      ),
    );
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
      _pendingAchievementToasts.clear();
    });
    ScaffoldMessenger.of(context).clearSnackBars();
    widget.onRestore(snap);
  }

  void _syncLocalMotion() {
    final needsLocal = widget.parallax == null && widget.lightDirection == null;
    if (needsLocal && _localMotion == null) {
      _localMotion = LuxeMotionController(reduceMotion: _state.reduceMotion);
      unawaited(_localMotion!.start());
    } else if (!needsLocal && _localMotion != null) {
      _localMotion!.dispose();
      _localMotion = null;
    }
    _localMotion?.setReduceMotion(_state.reduceMotion);
  }

  void _handleScrollLight() {
    if (!_boardScroll.hasClients) return;
    final next = _boardScroll.offset;
    if ((_scrollLight.value - next).abs() >= (kIsWeb ? 2.0 : 0.25)) {
      _scrollLight.value = next;
    }
  }

  void _handleBoardPointerDown(PointerDownEvent _) {
    if (_localMotion != null) {
      unawaited(_localMotion!.requestBrowserMotionPermission());
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _boardScroll.addListener(_handleScrollLight);
    _syncLocalMotion();
    // bind flush so the shell can settle rewards before a pause-path save
    widget.onBindFlush?.call(_flushCommit);
    widget.onBindComplete?.call(_completeQuest);
    widget.onBindOpenWorkout?.call(_openWorkoutFromOutside);
    Haptics.reduceMotion = _state.reduceMotion;
    if (widget.focusRequestId > 0) _showFocusedQuest();
    if (widget.workoutRequestId > 0) _showRequestedWorkout();
  }

  void _showFocusedQuest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_boardScroll.hasClients) return;
      if (_state.reduceMotion) {
        _boardScroll.jumpTo(_boardScroll.position.minScrollExtent);
      } else {
        _boardScroll.animateTo(
          _boardScroll.position.minScrollExtent,
          duration: Motion.settle,
          curve: Motion.respond,
        );
      }
    });
  }

  void _showRequestedWorkout() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Quest? launcher;
      for (final quest in widget.quests) {
        if (quest.workout) {
          launcher = quest;
          break;
        }
      }
      if (launcher == null) return;
      final size = MediaQuery.sizeOf(context);
      _openWorkout(launcher, Offset(size.width / 2, size.height * 0.58));
    });
  }

  @override
  void didUpdateWidget(QuestsPage old) {
    super.didUpdateWidget(old);
    if (!identical(old.state, widget.state)) {
      _pendingAchievementToasts.clear();
      for (final timer in _achievementToastTimers) {
        timer.cancel();
      }
      _achievementToastTimers.clear();
    }
    if (old.onBindFlush != widget.onBindFlush) {
      widget.onBindFlush?.call(_flushCommit);
    }
    if (old.onBindComplete != widget.onBindComplete) {
      widget.onBindComplete?.call(_completeQuest);
    }
    if (old.onBindOpenWorkout != widget.onBindOpenWorkout) {
      widget.onBindOpenWorkout?.call(_openWorkoutFromOutside);
    }
    if (old.focusRequestId != widget.focusRequestId) _showFocusedQuest();
    if (old.workoutRequestId != widget.workoutRequestId) {
      _showRequestedWorkout();
    }
    _syncLocalMotion();
    Haptics.reduceMotion = _state.reduceMotion;
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
    _pendingAchievementToasts.addAll(ps.checkAchievements());
    widget.onPersist();
    if (snap != null && title != null) _offerUndo(title, snap);
    // The list has just re-sorted and promoted the next quest. Measure the new
    // featured card against the reward rail once that layout exists.
    if (_activeReceipts > 0) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _clearFeaturedOfRewardRail(),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _nightOverlay?.remove();
    _nightOverlay = null;
    _localMotion?.dispose();
    _boardScroll.removeListener(_handleScrollLight);
    _boardScroll.dispose();
    _scrollLight.dispose();
    // data-only flush (no setState during teardown) — never lose a reward
    // that was earned but whose visual commit hadn't fired yet. Mirror
    // _flushCommit's DATA effects (perfect-day shield + achievement/cosmetic
    // grants), omitting only the UI (setState/toasts/undo) — bug-hunt §11.
    _commitTimer?.cancel();
    for (final timer in _achievementToastTimers) {
      timer.cancel();
    }
    _achievementToastTimers.clear();
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

  /// The everyday reward lands on the thing that actually changed: XP.
  /// The tapestry is reserved for level-up and room progression rather than
  /// narrating every ordinary completion.
  final GlobalKey _xpNumberKey = GlobalKey();

  Offset _xpDestination() {
    final box = _xpNumberKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      return Offset(MediaQuery.sizeOf(context).width * 0.5, 96);
    }
    return box.localToGlobal(Offset(box.size.width * 0.5, box.size.height));
  }

  Note? _journalDraftFor(Quest quest, DateTime day) {
    for (final note in _state.journal.reversed) {
      if (note.sourceQuestKey == quest.title && Days.sameDay(note.at, day)) {
        return note;
      }
    }
    return null;
  }

  JournalTrace _journalTraceFor(Quest quest) {
    final base = _state.todayJournalTrace(widget.quests);
    final questTitles = [...base.questTitles];
    if (!questTitles.contains(quest.displayTitle)) {
      questTitles.add(quest.displayTitle);
    }
    final goalTitles = [...base.goalTitles];
    final goal = quest.goalTitle?.trim();
    if (goal != null && goal.isNotEmpty && !goalTitles.contains(goal)) {
      goalTitles.add(goal);
    }
    return JournalTrace(
      day: base.day,
      level: base.level,
      totalXp: base.totalXp,
      todayXp: base.todayXp,
      streakDays: base.streakDays,
      questTitles: questTitles,
      goalTitles: goalTitles,
      statGains: base.statGains,
      energy: base.energy,
    );
  }

  bool _hasMeaningfulQuestWriting(Note note, JournalQuestPrompt prompt) {
    final written = note.text.trim();
    if (written.isEmpty) return false;
    final starter = prompt.starter.trim();
    if (written == starter) return false;
    if (written.startsWith(starter)) {
      return written.substring(starter.length).trim().isNotEmpty;
    }
    // Replacing the prompt with the person's own words still counts.
    return true;
  }

  /// Opens (or resumes) the one dedicated page for this Quest today. Merely
  /// looking at the prompt earns nothing; once meaningful writing has actually
  /// autosaved, returning to the board uses the ordinary reward pipeline once.
  Future<void> _openQuestJournal(Quest quest, Offset tapPos) async {
    final prompt = quest.journalPrompt;
    if (prompt == null || _journalRouteOpen || quest.doneFor(Clock.now())) {
      return;
    }
    _flushCommit();
    final state = _state;
    final openedAt = Clock.now();
    var current = _journalDraftFor(quest, openedAt);
    final trace = current?.trace ?? _journalTraceFor(quest);
    _journalRouteOpen = true;
    // The page flip voices the page actually opening — the press already
    // voiced its own everyday contact under the finger.
    Sfx.instance.playMaterial(MaterialSound.parchment);
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => JournalEntryScreen(
            key: ValueKey('quest-journal-${quest.title}'),
            initial: current,
            accent: quest.stat.color,
            themeId: state.canvasTheme,
            reduceMotion: state.reduceMotion,
            heading: quest.displayTitle,
            hint: prompt.hint,
            // Existing drafts already contain the starter; passing it again
            // only restores the prompt treatment and never inserts a duplicate.
            starter: prompt.starter,
            trace: trace,
            commit: (payload, existing, markEdited) {
              final source = existing ?? current;
              final Note saved;
              if (source == null) {
                saved = Note(
                  at: Clock.now(),
                  text: payload.text,
                  context: state.buildTitle,
                  rich: payload.rich,
                  images: payload.images,
                  trace: trace,
                  sourceQuestKey: quest.title,
                );
                state.setJournal([...state.journal, saved]);
              } else {
                saved = source.copyWith(
                  text: payload.text,
                  rich: payload.rich,
                  images: payload.images,
                  editedAt: markEdited ? Clock.now() : null,
                );
                state.setJournal(state.journal.replacing(saved));
              }
              current = saved;
              return saved;
            },
            onDelete: (note) {
              for (final image in note.images) {
                journal_media.delete(image);
              }
              state.setJournal(state.journal.without(note));
              if (current?.id == note.id) current = null;
            },
          ),
        ),
      );
    } finally {
      _journalRouteOpen = false;
    }
    if (!mounted || !identical(state, _state)) return;
    final saved = current;
    if (saved == null ||
        !state.journal.any((note) => note.id == saved.id) ||
        !_hasMeaningfulQuestWriting(saved, prompt) ||
        !Days.sameDay(openedAt, Clock.now()) ||
        quest.doneFor(Clock.now())) {
      return;
    }
    _runCompletion(quest, tapPos);
  }

  /// Entry point from a card tap: timer-proof quests run their countdown
  /// first (proof multiplies, never gates — cancel just backs out).
  void _completeQuest(Quest q, Offset tapPos) {
    if (q.journalPrompt != null) {
      unawaited(_openQuestJournal(q, tapPos));
      return;
    }
    if (q.allDay) {
      // honesty by design: an all-day line is only confirmed at night — but
      // the moment of willpower still deserves a beat, not a cold deferral.
      Sfx.instance.playInteraction(InteractionSound.open);
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
    if (q.verification == Verification.timer && q.effectiveTimerMinutes > 0) {
      late final OverlayEntry timer;
      timer = OverlayEntry(
        builder: (_) => TimerOverlay(
          questTitle: q.title,
          minutes: q.effectiveTimerMinutes,
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
      Sfx.instance.playInteraction(InteractionSound.open);
      return;
    }
    _runCompletion(q, tapPos);
  }

  void _keepQuestReflection(GameState state, Quest quest, String text) {
    if (!identical(state, _state)) return;
    // The receipt arrives just before the staged XP commit. Settle it first so
    // the frozen Journal trace includes the quest, XP, stat movement, streak,
    // and linked goal the person is reflecting on.
    _flushCommit();
    final note = Note(
      at: Clock.now(),
      text: text,
      context: state.buildTitle,
      trace: state.todayJournalTrace(widget.quests),
    );
    state.setJournal([...state.journal, note]);
    widget.onPersist();
    Storage.logEvent('quick_reflection', [quest.stat.index]);
  }

  /// The §3 completion sequence, staged (see DESIGN.md §3).
  void _runCompletion(
    Quest q,
    Offset tapPos, {
    bool verified = false,
    Quest? progressionQuest,
  }) {
    // settle any prior in-flight completion FIRST, so this snapshot reflects
    // it fully committed (never rolled-but-not-committed — the data-loss trap)
    _flushCommit();
    final s = _state; // guard: the dev reset button can swap state mid-flight
    // capture the pre-completion state so an accidental tap can be undone
    final snapshot = widget.onSnapshot();
    final bundle = s.roll(
      q,
      verified: verified,
      progressionQuest: progressionQuest,
    );
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
    final nowT = Clock.now();
    _combo =
        (_lastCompleteAt != null &&
            nowT.difference(_lastCompleteAt!) < _comboWindow)
        ? _combo + 1
        : 1;
    _lastCompleteAt = nowT;
    _maybeOfferReAnchor(q); // "did your Tuesday quest on Thursday? move it?"
    _celebrateDayClearedIfDone(q); // a warm wash when the last ember is lit
    // Completion owns one atomic contact-to-outcome voice. QuestCard suppresses
    // its ordinary press here, and delayed paths arrive through this same gate.
    Sfx.instance.playCompletionAccepted(transitionId: q);
    if (_combo < 2 && !bundle.shieldHeld) Haptics.questComplete();
    // a freeze that held the quiet days gets its own steady double-tap
    if (bundle.shieldHeld) {
      Future.delayed(const Duration(milliseconds: 260), Haptics.streakFreeze);
    }

    final overlay = Overlay.of(context);
    final still = s.reduceMotion || MediaQuery.disableAnimationsOf(context);
    // a flourish for a roll of clears — escalating warmth, never a takeover
    if (_combo >= 2) {
      Haptics.rise();
      late final OverlayEntry flourish;
      flourish = OverlayEntry(
        builder: (_) => _ComboFlourish(
          combo: _combo,
          flameHue: flameHueFor(_state),
          onDone: () => flourish.remove(),
        ),
      );
      overlay.insert(flourish);
    }

    // Routine clears belong to the check + XP flight. Flecks are reserved for a
    // genuine exceptional beat, so the page never turns into layered confetti.
    final showBurst =
        _combo >= 2 ||
        bundle.critMult != null ||
        bundle.loot != null ||
        q.dread;
    if (showBurst) {
      final comboBoost = min(_combo - 1, 5);
      late final OverlayEntry burst;
      burst = OverlayEntry(
        builder: (_) => ParticleBurst(
          origin: tapPos,
          colors:
              cosmeticFor(s.equippedSkin)?.particles ??
              [q.stat.color, Palette.xp, Palette.xpLight],
          count: (5 + 12 * bundle.magnitude).round() + comboBoost * 3,
          vibrancy: 0.38 + bundle.magnitude + comboBoost * 0.08,
          reduce: still,
          onDone: () => burst.remove(),
        ),
      );
      overlay.insert(burst);
    }

    // A single bright trace carries the reward from the checked ring to the
    // XP rail. The stat chip then pulses when the commit lands, so the loop is
    // visibly game-first: quest -> XP -> build.
    late final OverlayEntry xpFlight;
    xpFlight = OverlayEntry(
      builder: (_) => QuestCompletionStitch(
        origin: tapPos,
        destination: _xpDestination(),
        xp: bundle.xp,
        statColor: q.stat.color,
        reduceMotion: still,
        onDone: () => xpFlight.remove(),
      ),
    );
    overlay.insert(xpFlight);

    // The reward receipt starts quickly so there's no dead gap after the tap;
    // epic + level-ups still resolve once it finishes so big moments never
    // land on top of mid-flight bubbles.
    Future.delayed(const Duration(milliseconds: 240), () {
      if (!mounted) return;
      _activeReceipts++;
      late final OverlayEntry receipt;
      receipt = OverlayEntry(
        builder: (_) => Stack(
          children: [
            RewardReceipt(
              bundle: bundle,
              anchor: tapPos,
              state: s,
              onReflect: (text) => _keepQuestReflection(s, q, text),
              onDone: () {
                receipt.remove();
                _activeReceipts--;
                _afterReceipt(s, q, bundle);
              },
            ),
          ],
        ),
      );
      overlay.insert(receipt);
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _clearFeaturedOfRewardRail(),
      );
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

  /// The honest boundary of a shaped day: dated commitments plus the field.
  /// The shared helper deliberately retains snoozed selections: setting a
  /// chosen Quest aside may be compassionate, but it cannot mint a false clear.
  List<Quest> _requiredDailyBoundary(DateTime day) =>
      requiredQuestsForDay(widget.quests, day);

  /// Count of quests still open today. Once the keeper has shaped a dated
  /// field, optional inspiration does not become an all-or-nothing test.
  int _remainingToday() {
    final now = Clock.now();
    if (hasDateScopedDailyField(widget.quests, now)) {
      return _requiredDailyBoundary(now).where((q) => !q.doneFor(now)).length;
    }
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
  /// a perfect-day reward. Freeze replenishment is intentionally based on
  /// ordinary active days, never an all-or-nothing board.
  bool _anySnoozedToday() {
    final now = Clock.now();
    final today = Days.key(now);
    if (hasDateScopedDailyField(widget.quests, now)) {
      return _requiredDailyBoundary(
        now,
      ).any((q) => q.snoozedDay == today && !q.doneFor(now));
    }
    return widget.quests.any((q) => q.snoozedDay == today);
  }

  /// Queue achievement banners, staggered so each gets its moment. Guarded
  /// by [s]: if the state was swapped (undo/reset) before a toast fires, it
  /// is suppressed — no claiming a trophy the restored state no longer holds.
  void _toastAchievements(GameState s, List<Achievement> newly) {
    for (var i = 0; i < newly.length; i++) {
      late final Timer timer;
      timer = Timer(Duration(milliseconds: 200 + i * 2800), () {
        _achievementToastTimers.remove(timer);
        if (!mounted || !identical(s, _state)) return;
        late final OverlayEntry toast;
        toast = OverlayEntry(
          builder: (_) => Stack(
            children: [
              AchievementToast(
                achievement: newly[i],
                flameHue: flameHueFor(s),
                reduceMotion: s.reduceMotion,
                onDone: () => toast.remove(),
              ),
            ],
          ),
        );
        Overlay.of(context).insert(toast);
      });
      _achievementToastTimers.add(timer);
    }
  }

  /// Drain banners only after the visual reward chain has reached a quiet
  /// moment. [checkAchievements] remains idempotent, while the explicit queue
  /// preserves trophies that were granted during the earlier commit beat.
  void _releaseAchievementToasts(GameState s) {
    _pendingAchievementToasts.addAll(s.checkAchievements());
    if (_activeReceipts != 0) return;

    final seen = <String>{};
    final newly = [
      for (final achievement in _pendingAchievementToasts)
        if (seen.add(achievement.id)) achievement,
    ];
    _pendingAchievementToasts.clear();
    _toastAchievements(s, newly);
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
          reduceMotion: s.reduceMotion,
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
          reduceMotion: s.reduceMotion,
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
    Sfx.instance.playMaterial(MaterialSound.glass);
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
                  // full-width, 44pt target (a11y pass) — was an 18px row
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    // faceted commit row: slate weight (brass stays gold-only)
                    Sfx.instance.playInteraction(
                      InteractionSound.place,
                      material: MaterialSound.stone,
                    );
                    setState(() {
                      if (q.priorityOn(Clock.now())) {
                        q.priority = false;
                        q.priorityDay = null;
                      } else {
                        q.priority = true;
                        q.priorityDay = null;
                      }
                    });
                    widget.onPersist();
                    Navigator.of(ctx).pop();
                  },
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 44),
                    alignment: Alignment.centerLeft,
                    child: Row(
                      children: [
                        Icon(
                          q.priorityOn(Clock.now())
                              ? Icons.star
                              : Icons.star_border,
                          size: 18,
                          color: Palette.xpLight,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          q.priorityOn(Clock.now())
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
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    Sfx.instance.playMaterial(MaterialSound.glass);
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
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 44),
                    alignment: Alignment.centerLeft,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.tune,
                          size: 18,
                          color: Palette.xpLight,
                        ),
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
                ),
                // The running log: little timestamped notes kept on this quest
                // (which side, how much, where) — context that travels with it.
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    Sfx.instance.playMaterial(MaterialSound.parchment);
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
                        q.addNote(text, Clock.now());
                        setState(() {});
                        widget.onPersist();
                      },
                      onDelete: (n) {
                        q.log = q.log.without(n);
                        setState(() {});
                        widget.onPersist();
                      },
                      onEdit: (orig, text) {
                        q.log = q.log.replacing(
                          orig.copyWith(text: text, editedAt: Clock.now()),
                        );
                        setState(() {});
                        widget.onPersist();
                      },
                    );
                  },
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 44),
                    alignment: Alignment.centerLeft,
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
                ),
                // A gentle skip: hide it from today's board, back tomorrow —
                // never a penalty, just "not today."
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    Sfx.instance.playInteraction(
                      InteractionSound.place,
                      material: MaterialSound.stone,
                    );
                    HapticFeedback.selectionClick();
                    setState(() => q.snoozedDay = Days.key(Clock.now()));
                    Storage.logEvent('snooze', [
                      q.custom ? Storage.hashTitle(q.title) : q.title,
                    ]);
                    widget.onPersist();
                    Navigator.of(ctx).pop();
                  },
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 44),
                    alignment: Alignment.centerLeft,
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
                ),
                // a quiet fence before the one destructive action, so a fast
                // thumb never lands on it by rhythm alone
                Divider(
                  height: 18,
                  color: Palette.textLo.withValues(alpha: 0.15),
                ),
                // The permanent remove keeps its two-tap arm.
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (!armed) {
                      Sfx.instance.playInteraction(
                        InteractionSound.select,
                        material: MaterialSound.stone,
                      );
                      setDialog(() => armed = true);
                      return;
                    }
                    Sfx.instance.play('boing');
                    widget.onRemove(q);
                    Navigator.of(ctx).pop();
                  },
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 44),
                    alignment: Alignment.centerLeft,
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
    Sfx.instance.playMaterial(MaterialSound.glass);
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
    Sfx.instance.playMaterial(MaterialSound.glass);
    HapticFeedback.selectionClick();
    final q = await showEmberSheet(
      context,
      const EmberSheetConfig(surface: EmberSurface.board),
    );
    if (q != null) widget.onAdd(q);
  }

  void _openNight({bool alreadyAcknowledged = false}) {
    if (_nightOverlay != null) return;
    if (!alreadyAcknowledged) {
      Sfx.instance.playMaterial(MaterialSound.glass);
    }
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
          if (identical(_nightOverlay, e)) _nightOverlay = null;
          if (mounted && identical(s, _state)) {
            // a night-confirmed all-day line can be the day's last clear
            if (_remainingToday() == 0 && !_anySnoozedToday()) {
              s.recordPerfectDay();
            }
            setState(() {});
            _toastAchievements(s, s.checkAchievements());
          }
          if (s.nightDoneDay == Days.nightKey(Clock.now())) {
            widget.onNightClosed?.call();
          }
        },
      ),
    );
    _nightOverlay = e;
    Overlay.of(context).insert(e);
  }

  void _openMorning() {
    Sfx.instance.playMaterial(MaterialSound.glass);
    final s = _state;
    late final OverlayEntry e;
    e = OverlayEntry(
      builder: (_) => MorningFlow(
        state: s,
        quests: widget.quests,
        onDismiss: () {
          e.remove();
          if (mounted && identical(s, _state)) setState(() {});
        },
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
  void _openWorkoutFromOutside(Quest launcher) {
    final box = context.findRenderObject() as RenderBox?;
    final anchor = box == null
        ? MediaQuery.sizeOf(context).center(Offset.zero)
        : box.localToGlobal(box.size.center(Offset.zero));
    // The only outside entry is the Pressable Guided Workouts card in Goals.
    _openWorkout(launcher, anchor);
  }

  void _openWorkout(Quest launcher, Offset tapPos) {
    if (_workoutRunnerOpen) return; // dedupe rapid double-tap (bug-hunt §8)
    _workoutRunnerOpen = true;
    // The guided runner is travel into a mode: the parchment flip voices it
    // opening, on top of whichever contact the launching press already made.
    Sfx.instance.playMaterial(MaterialSound.parchment);
    late final OverlayEntry e;
    e = OverlayEntry(
      builder: (_) => _WorkoutTakeover(
        reduceMotion: _state.reduceMotion,
        child: WorkoutFlow(
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
      ),
    );
    Overlay.of(context).insert(e);
  }

  /// Pay for a finished session through the EXISTING reward engine: synthesize
  /// one throwaway Quest (routine stat/difficulty, ×1.2 if a timed move was
  /// proved, and strength sessions alone tick the strength goal) and run the
  /// normal completion. Difficulty scales down fairly for an early exit. The
  /// launcher is marked done AFTER the snapshot is captured, so Undo reverts
  /// both the reward and the tick.
  void _finishWorkout(
    Quest launcher,
    Routine routine,
    Offset tapPos, {
    required bool verified,
    required bool endedEarly,
    required int workMovesDone,
  }) {
    if (!mounted) return;
    if (launcher.doneFor(Clock.now())) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: Palette.card,
            content: Text(
              'Session kept — today’s guided-workout reward already landed.',
              style: Type.body.copyWith(color: Palette.textHi),
            ),
          ),
        );
      return;
    }
    final frac = routine.workMoves == 0
        ? 1.0
        : (workMovesDone / routine.workMoves).clamp(0.25, 1.0);
    final diff = endedEarly
        ? (routine.difficulty * frac).round().clamp(1, 10)
        : routine.difficulty;
    final reward = workoutRewardQuest(routine, difficulty: diff);
    // _runCompletion captures the undo snapshot (launcher still un-done) and
    // ARMS the deferred reward commit. Mark the launcher done in-memory for the
    // visual, but do NOT persist here — persistence happens atomically when the
    // reward actually commits (_flushCommit/dispose call onPersist), so a save
    // can never capture a done launcher without its XP/stat (bug-hunt §3/§4/§7).
    _runCompletion(
      reward,
      tapPos,
      verified: verified,
      progressionQuest: launcher,
    );
    launcher.lastDoneDay = Days.key(Clock.now());
    setState(() {});
  }

  void _resolveLevelUps(GameState s) {
    if (!mounted || !identical(s, _state)) return;
    final result = s.applyLevelUps();
    widget.onPersist();
    if (result.leveledTo == null) {
      _resolveStreakMilestone(s);
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
        reduceMotion: s.reduceMotion,
        onDismiss: () {
          takeover.remove();
          if (mounted && identical(s, _state)) {
            setState(() {});
            // streak milestone (if any), then rank-ups, then achievements
            _resolveStreakMilestone(s);
          }
        },
        // Sharing replaces the takeover with the preview sheet, then rejoins
        // the exact same celebration chain onDismiss runs — a shared level-up
        // must not swallow the streak/rank/achievement beats behind it.
        onShare: () {
          takeover.remove();
          if (!mounted) return;
          unawaited(
            showShareMoment(context, s, level: result.leveledTo!).whenComplete(
              () {
                if (mounted && identical(s, _state)) {
                  setState(() {});
                  _resolveStreakMilestone(s);
                }
              },
            ),
          );
        },
      ),
    );
    Overlay.of(context).insert(takeover);
  }

  /// Streak milestone check — if the just-completed quest pushed the streak
  /// across 7/30/100 days, show the full-screen chest celebration before
  /// continuing to rank-ups and achievement toasts.
  void _resolveStreakMilestone(GameState s) {
    if (!mounted || !identical(s, _state)) return;
    final days = s.takeJustStreakMilestone();
    if (days == null) {
      _afterRankThenToasts(s);
      return;
    }
    final embers = GameState.streakMilestones[days] ?? 0;
    widget.onPersist();
    late final OverlayEntry milestone;
    milestone = OverlayEntry(
      builder: (_) => StreakMilestoneOverlay(
        days: days,
        embers: embers,
        reduceMotion: s.reduceMotion,
        onDismiss: () {
          milestone.remove();
          if (mounted && identical(s, _state)) {
            setState(() {});
            // continue the chain: rank-ups, then achievement toasts
            _afterRankThenToasts(s);
          }
        },
      ),
    );
    Overlay.of(context).insert(milestone);
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
      _releaseAchievementToasts(s);
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
            _releaseAchievementToasts(s);
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
    final today = Days.key(Clock.now());
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
          reduce: _state.reduceMotion,
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
    final today = Clock.now().weekday;
    if (q.weekdays.first == today) return; // done on its day — nothing to offer
    setState(() {
      _reAnchorQuest = q;
      _reAnchorDay = today;
    });
  }

  /// The inline re-anchor offer — calm, optional, never a modal. Lives in the
  /// page body so it waits politely behind the completion celebration and is
  /// trivially ignorable (never-punish: a suggestion, not a correction).
  /// The single mantel: exactly one hearth banner shows, by priority —
  /// first-ember guide > morning briefing > energy weather > re-anchor offer >
  /// week recap > daily ember > spark. Each panel keeps its own seen/dismiss stamps, so a
  /// lower-priority banner simply waits for a quieter day instead of stacking.
  Widget _hearthPanel() {
    if (_state.totalCompletions == 0 && _state.onboarded) {
      return _firstEmberPanel();
    }
    if (_state.morningAvailable) return _morningPanel();
    if (_state.energyWeatherDue) return _energyWeatherPanel();
    if (_reAnchorQuest != null && _reAnchorDay != null) return _reAnchorPanel();
    if (_state.weekRecapDue) return _weekRecapPanel();
    if (_state.emberDue) return _emberPanel();
    return _sparkPanel();
  }

  void _selectEnergyWeather(EnergyWeather weather) {
    setState(() {
      _state.setEnergyWeather(weather);
      if (weather == EnergyWeather.low) {
        _focusLens = _FocusLens.quickWin;
        _state.setFocusMode(false);
        final candidates = _lowFlameCandidates(Clock.now());
        _state.setLowFlameQuests(
          suggestedLowFlameQuests(candidates, Clock.now()).map((q) => q.title),
        );
        _showFullLowFlame = false;
      }
    });
    widget.onPersist();
    Sfx.instance.play('streak');
    HapticFeedback.selectionClick();
  }

  Widget _energyWeatherPanel() {
    final options = <(EnergyWeather, IconData, Color)>[
      (EnergyWeather.low, Icons.nightlight_outlined, Stat.vit.color),
      (EnergyWeather.steady, Icons.horizontal_rule, Palette.xpLight),
      (EnergyWeather.bright, Icons.wb_sunny_outlined, Palette.streak),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: GlassPanel(
        glow: true,
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.cloud_outlined,
                  size: 17,
                  color: Palette.xpLight,
                ),
                const SizedBox(width: 8),
                Text(
                  'ENERGY WEATHER',
                  style: Type.label.copyWith(
                    fontSize: Type.minLabel,
                    color: Palette.xpLight,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'What is the weather inside today?',
              style: Type.body.copyWith(fontSize: 13.5, color: Palette.textHi),
            ),
            const SizedBox(height: 9),
            Row(
              children: [
                for (final option in options) ...[
                  Expanded(
                    child: Semantics(
                      button: true,
                      label: option.$1.label,
                      onTap: () => _selectEnergyWeather(option.$1),
                      child: GestureDetector(
                        excludeFromSemantics: true,
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _selectEnergyWeather(option.$1),
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 44),
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          decoration: facetedDecoration(
                            cut: 8,
                            color: option.$3.withValues(alpha: 0.1),
                            borderColor: option.$3.withValues(alpha: 0.36),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(option.$2, size: 16, color: option.$3),
                              const SizedBox(height: 3),
                              Text(
                                option.$1.label,
                                maxLines: 1,
                                style: Type.label.copyWith(
                                  fontSize: Type.minLabel,
                                  letterSpacing: 0.7,
                                  color: option.$3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (option.$1 != EnergyWeather.bright)
                    const SizedBox(width: 7),
                ],
              ],
            ),
            const SizedBox(height: 7),
            Text(
              'This changes suggestions, never rewards or streaks.',
              style: Type.body.copyWith(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: Palette.textLo,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// First-session nudge: highlight that the loop starts with one tap.
  Widget _firstEmberPanel() {
    final open = widget.quests.where((q) {
      final now = Clock.now();
      return q.scheduledOn(now) && !q.doneFor(now) && !q.allDay;
    }).toList();
    final tip = open.isNotEmpty ? open.first.displayTitle : 'any quest below';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: GlassPanel(
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: facetedDecoration(
                cut: 8,
                color: Palette.xpLight.withValues(alpha: 0.08),
                borderColor: Palette.xpLight.withValues(alpha: 0.38),
              ),
              child: const Icon(
                Icons.touch_app_rounded,
                size: 19,
                color: Palette.xpLight,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TRY THIS',
                    style: Type.label.copyWith(
                      fontSize: 11,
                      color: Palette.xpLight,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap “$tip” and see what changes.',
                    style: Type.body.copyWith(
                      fontSize: 13.5,
                      color: Palette.textHi,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

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
                      decoration: facetedDecoration(
                        cut: 9,
                        color: Colors.transparent,
                        borderColor: Palette.glassEdge,
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
        Sfx.instance.playMaterial(MaterialSound.glass);
        HapticFeedback.selectionClick();
        setState(onGone);
        widget.onPersist();
      },
      child: child,
    );
  }

  /// "Today's Bonus" — a small, fun, today-only quest offered once
  /// a day (domain rotates). Tap ADD to drop it on the board as a ⚡ bonus
  /// (expires at dawn); or dismiss. Pure novelty, never an obligation.
  Widget _emberPanel() {
    if (!_state.emberDue) return const SizedBox.shrink();
    final now = Clock.now();
    final e = emberOfDay(now);
    void dismiss() {
      setState(() => _state.dismissEmber());
      widget.onPersist();
    }

    Widget buildInfo() => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.add_task_rounded, size: 20, color: e.stat.color),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'TODAY’S BONUS',
                    style: Type.label.copyWith(
                      fontSize: 11,
                      color: e.stat.color,
                    ),
                  ),
                  Text(
                    e.stat.abbr,
                    style: Type.label.copyWith(
                      fontSize: Type.minLabel,
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
      ],
    );

    final addAction = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (e.title == planTomorrowEmber) {
          unawaited(_planTomorrow(dismiss));
          return;
        }
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        // Controls are brass; the domain speaks through the row's glyph and
        // label. The action stays the same material across bonus categories.
        decoration: agedBrassPlate(cut: 7),
        child: Text(
          e.title == planTomorrowEmber ? 'PLAN' : 'ADD',
          style: Type.label.copyWith(
            fontSize: 11,
            letterSpacing: 1.1,
            color: Palette.xpLight,
          ),
        ),
      ),
    );

    final closeAction = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Sfx.instance.playMaterial(MaterialSound.glass);
        dismiss();
      },
      child: const Padding(
        padding: EdgeInsets.all(10),
        child: Icon(Icons.close, size: 16, color: Palette.textLo),
      ),
    );

    return _swipeAway(
      dismissKey: 'ember',
      onGone: () => _state.emberSeenDay = Days.key(now),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: GlassPanel(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final stackActions =
                  MediaQuery.textScalerOf(context).scale(1) > 1.5;
              if (stackActions) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    buildInfo(),
                    const SizedBox(height: 7),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        addAction,
                        const SizedBox(width: 4),
                        closeAction,
                      ],
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: buildInfo()),
                  const SizedBox(width: 8),
                  addAction,
                  const SizedBox(width: 4),
                  closeAction,
                ],
              );
            },
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
          _state.weekRecapSeenWeek = Days.key(Days.weekStart(Clock.now())),
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
                      'You showed up on ${r.litDays} of 7 days — ${r.total} '
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
                  Sfx.instance.playMaterial(MaterialSound.glass);
                  setState(() => _state.dismissWeekRecap());
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

  /// A warm, state-aware note on the first open each day
  /// (scout pick #1). Dismissed → stamped, never re-shown that day. Suppressed
  /// while the morning prompt is up (the brief is the bigger greeting).
  Widget _sparkPanel() {
    final today = Days.key(Clock.now());
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
                      'A NOTE FOR TODAY',
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
                  Sfx.instance.playMaterial(MaterialSound.glass);
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
  /// The closed board. The ledger is written, the fire is banked, and the
  /// page says so instead of offering more work — closure the person can see.
  /// One quiet way back in for the genuinely-not-done, kept deliberately
  /// smaller than the rest it interrupts.
  Widget _restingBody(DateTime now) {
    final keptDay = _state.nightDoneDay ?? Days.key(now);
    final kept = _state.history[keptDay] ?? 0;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 130),
      children: [
        GlassPanel(
          key: const ValueKey('day-resting-panel'),
          padding: const EdgeInsets.fromLTRB(20, 26, 20, 22),
          child: Column(
            children: [
              FacetMedallion(
                size: 52,
                accent: Palette.unlock,
                child: const Icon(
                  Icons.nightlight_round,
                  size: 24,
                  color: Color(0xFFD6C38C),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'The day is kept.',
                textAlign: TextAlign.center,
                style: Type.display.copyWith(fontSize: 22),
              ),
              const SizedBox(height: 8),
              Text(
                kept > 0
                    ? '$kept quest${kept == 1 ? '' : 's'} went into the ledger '
                          'tonight. The rest can wait.'
                    : 'Tonight is closed and written. The rest can wait.',
                textAlign: TextAlign.center,
                style: Type.body.copyWith(
                  fontSize: 13.5,
                  height: 1.5,
                  color: Palette.textMid,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'The board opens with the morning.',
                textAlign: TextAlign.center,
                style: Type.body.copyWith(
                  fontSize: 12.5,
                  fontStyle: FontStyle.italic,
                  color: Palette.textLo,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Center(
          child: Semantics(
            button: true,
            label: 'Reopen tonight’s board',
            onTap: _liftRest,
            excludeSemantics: true,
            child: GestureDetector(
              key: const ValueKey('day-resting-reopen'),
              behavior: HitTestBehavior.opaque,
              onTap: _liftRest,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                child: Text(
                  'I’M NOT DONE YET',
                  style: Type.label.copyWith(
                    fontSize: 11,
                    color: Palette.textLo,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _liftRest() {
    Sfx.instance.playMaterial(MaterialSound.wood);
    HapticFeedback.selectionClick();
    setState(() => _state.liftRest());
    widget.onPersist();
  }

  Widget _focusBody(List<Quest> pool, int allDayLeft, DateTime now) {
    final q = pool.first;
    return ListView(
      key: const ValueKey('focus-quest-list'),
      // Match the rest of the board's protected dock inset so the exit action
      // never disappears behind navigation on short phones.
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
            featured: true,
            xpPreview: _state.xpPreview(q),
            deskFinish: activeQuestDeskLook(_state).wood,
            reduceMotion: _state.reduceMotion,
            lightDirection: _activeLight,
            scrollPosition: _scrollLight,
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
          child: Semantics(
            button: true,
            label: 'Show the full quest board',
            onTap: _toggleFocus,
            excludeSemantics: true,
            child: GestureDetector(
              onTap: _toggleFocus,
              behavior: HitTestBehavior.opaque,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Center(
                    child: Text(
                      'SEE THE FULL BOARD',
                      style: Type.label.copyWith(
                        fontSize: 11,
                        color: Palette.textLo,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _lowFlameBar({
    required int chosen,
    required int resting,
    required bool showingAll,
  }) {
    final accent = Stat.vit.color;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(13, 11, 11, 10),
        decoration: facetedDecoration(
          cut: 10,
          color: accent.withValues(alpha: 0.1),
          borderColor: accent.withValues(alpha: 0.55),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.nightlight_outlined, size: 17, color: accent),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    showingAll
                        ? 'GENTLE MODE · FULL BOARD'
                        : 'GENTLE MODE SHELTER',
                    style: Type.label.copyWith(
                      fontSize: Type.minLabel,
                      color: accent,
                    ),
                  ),
                ),
                // Both shelter actions read as one control group in aged
                // brass. A moss EDIT next to an amber SHOW ALL, at identical
                // weight, implied a difference that does not exist.
                _ShelterAction(
                  label: 'EDIT 3',
                  color: Palette.xpLight,
                  onTap: () => unawaited(_editLowFlameThree()),
                ),
                const SizedBox(width: 5),
                _ShelterAction(
                  label: showingAll ? 'RETURN TO 3' : 'SHOW ALL',
                  color: Palette.xpLight,
                  onTap: () {
                    Sfx.instance.playMaterial(MaterialSound.glass);
                    HapticFeedback.selectionClick();
                    setState(() => _showFullLowFlame = !showingAll);
                  },
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              chosen == 0
                  ? 'Nothing needs carrying right now. A clear day is allowed.'
                  : showingAll
                  ? 'All quests are visible for a moment. Your chosen $chosen still define enough.'
                  : '$chosen chosen · $resting resting safely for later.',
              style: Type.body.copyWith(
                fontSize: 12.5,
                fontStyle: FontStyle.italic,
                color: Palette.textLo,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = Clock.now();
    final reduceMotion =
        _state.reduceMotion ||
        (MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    final next = _state.xpNeeded(_state.level + 1);
    final deskLook = activeQuestDeskLook(_state);

    // Visible today: recurring quests on their scheduled days (round-7);
    // events only once due. Due/overdue events lead the list.
    final today = Days.key(now);
    final nightDay = Days.nightKey(now);
    final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final fullVisible =
        [
          for (final q in widget.quests)
            // A set-aside ordinary quest rests until tomorrow. A dated
            // commitment remains visible; it cannot be quietly hidden.
            if (q.isEvent
                ? (!q.dueDate!.isAfter(endOfToday) || q.doneFor(now))
                : (q.snoozedDay != today &&
                      (q.scheduledOn(now) || q.lastDoneDay == today)))
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
              q.allDay ? 3 : (q.isEvent ? 0 : (q.priorityOn(now) ? 1 : 2));
          final ar = rank(a), br = rank(b);
          if (ar != br) return ar.compareTo(br);
          if (_state.energyWeatherDay == today) {
            if (_state.energyWeather == EnergyWeather.low) {
              if (a.dread != b.dread) return a.dread ? 1 : -1;
              return a.difficulty.compareTo(b.difficulty);
            }
            if (_state.energyWeather == EnergyWeather.bright) {
              return b.difficulty.compareTo(a.difficulty);
            }
          }
          return 0;
        });
    final lowFlame = _state.lowFlameActive;
    final hasDailyField = hasDateScopedDailyField(widget.quests, now);
    // Gentle Mode is an explicitly separate shelter. The ordinary field is
    // still saved and still governs the honest day boundary underneath it.
    final showingDailyField = hasDailyField && !lowFlame;
    final chosenField = selectedDailyFieldForDay(widget.quests, now);
    final commitmentTitles = hardCommitmentsForDay(
      widget.quests,
      now,
    ).map((q) => q.title).toSet();
    final fieldTitles = chosenField.map((q) => q.title).toSet();
    final commitmentsVisible = fullVisible
        .where((q) => commitmentTitles.contains(q.title))
        .toList(growable: false);
    final fieldVisible = fullVisible
        .where(
          (q) =>
              fieldTitles.contains(q.title) &&
              !commitmentTitles.contains(q.title),
        )
        .toList(growable: false);
    final optionalVisible = fullVisible
        .where(
          (q) =>
              !commitmentTitles.contains(q.title) &&
              !fieldTitles.contains(q.title),
        )
        .toList(growable: false);
    final shelterTitles = _state.lowFlameQuestTitles.isNotEmpty
        ? _state.lowFlameQuestTitles.toSet()
        : suggestedLowFlameQuests(fullVisible, now).map((q) => q.title).toSet();
    final sheltered = lowFlame && !_showFullLowFlame;
    final visible = sheltered
        ? fullVisible.where((q) => shelterTitles.contains(q.title)).toList()
        : showingDailyField
        ? [
            ...commitmentsVisible,
            ...fieldVisible,
            if (_showOptionalField) ...optionalVisible,
          ]
        : List<Quest>.of(fullVisible);
    final requestedTitle = widget.focusQuestTitle?.trim().toLowerCase();
    if (requestedTitle != null && requestedTitle.isNotEmpty) {
      Quest? requested;
      for (final quest in fullVisible) {
        if (quest.title.trim().toLowerCase() == requestedTitle) {
          requested = quest;
          break;
        }
      }
      if (requested != null && !requested.doneFor(now) && !requested.allDay) {
        visible.remove(requested);
        visible.insert(0, requested);
      }
    }
    final visibleRemaining = visible.where((q) => !q.doneFor(now)).length;
    final remaining = showingDailyField ? _remainingToday() : visibleRemaining;
    final fullRemaining = fullVisible.where((q) => !q.doneFor(now)).length;
    final shelteredQuestCount = fullVisible
        .where((q) => shelterTitles.contains(q.title))
        .length;
    final shelterRemaining = fullVisible
        .where((q) => shelterTitles.contains(q.title) && !q.doneFor(now))
        .length;
    final resting = (fullRemaining - shelterRemaining).clamp(0, fullRemaining);
    final commitmentsRemaining = commitmentsVisible
        .where((q) => !q.doneFor(now))
        .length;
    final fieldRemaining = chosenField.where((q) => !q.doneFor(now)).length;
    final setAside = chosenField
        .where((q) => q.snoozedDay == today && !q.doneFor(now))
        .length;
    final optionalOpen = optionalVisible.where((q) => !q.doneFor(now)).length;

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
    final allDayLeft = fullVisible
        .where((q) => q.allDay && !q.doneFor(now))
        .length;
    final showFocus = _state.focusMode && actionable.isNotEmpty;
    final firstVisibleActionable = visible.indexWhere(
      (q) => !q.doneFor(now) && !q.allDay,
    );
    final boardItemCount = visible.isEmpty
        ? 1
        : visible.length + (remaining == 0 ? 1 : 0);
    final nightOpen = _state.nightDoneDay != nightDay;
    final showCloseDayRail =
        nightOpen && isWindDownTime(now) && (remaining > 0 || visible.isEmpty);
    // Closing the day actually closes it: once tonight's ledger is written the
    // board rests until morning (or an explicit "I'm not done yet").
    final dayResting = _state.dayRestingNow;

    return LayoutBuilder(
      builder: (context, bounds) {
        // Use the board's actual constraint rather than a possibly one-frame
        // stale MediaQuery width while a test host or split view is resizing.
        // Text can grow on the same frame constraints become compact.
        final largePhoneType =
            MediaQuery.textScalerOf(context).scale(1) >= 1.25 &&
            bounds.maxWidth <= 360;
        // Compact-height windows sacrifice the cinematic reveal before they
        // sacrifice the board's primary task. Normal phones retain the full
        // room; short landscape/split-screen surfaces begin almost collapsed.
        final roomHeight = bounds.maxHeight < 700
            ? 48.0
            : min(
                bounds.maxWidth / 1.70,
                bounds.maxHeight * 0.28,
              ).clamp(168.0, 270.0).toDouble();
        _localMotion?.setReduceMotion(reduceMotion);
        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: _handleBoardPointerDown,
          child: MouseRegion(
            onHover: _localMotion == null
                ? null
                : (event) => _localMotion!.handlePointer(event, bounds.biggest),
            onExit: _localMotion?.clearPointer,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const Positioned.fill(
                  child: ColoredBox(color: Color(0xFF100D0B)),
                ),
                _QuestRoomBackdrop(
                  state: _state,
                  height: roomHeight,
                  parallax: _activeParallax,
                  scrollPosition: _scrollLight,
                  igniting: widget.roomIgniting,
                  hearthLit: widget.roomHearthLit,
                ),
                _QuestBackdropBlur(
                  state: _state,
                  controller: _boardScroll,
                  scrollPosition: _scrollLight,
                  height: roomHeight,
                  parallax: _activeParallax,
                ),
                NestedScrollView(
                  key: const ValueKey('quest-board-scroll'),
                  controller: _boardScroll,
                  // A reverse scroll belongs to the quest list until it has
                  // genuinely reached the top. Only then may the room return.
                  floatHeaderSlivers: false,
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  headerSliverBuilder: (context, innerBoxIsScrolled) => [
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(height: roomHeight - 8),
                          // ── Header HUD ──────────────────────────────────────────
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // ── Level + XP ──────────────────────────────────
                                // Its own slab, the way the approved board art has
                                // it: medallion, LEVEL as a small caps label, the
                                // level itself as a display numeral, honey track
                                // underneath. One string of grey mono carried all
                                // three jobs before and no hierarchy survived it.
                                _QuestHudPanel(
                                  padding: const EdgeInsets.fromLTRB(
                                    10,
                                    2,
                                    12,
                                    2,
                                  ),
                                  child: SizedBox(
                                    height: largePhoneType ? 80 : 45,
                                    child: Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        Positioned(
                                          left: 0,
                                          top: -4.5,
                                          child: QuestDeskStyleButton(
                                            look: deskLook,
                                            onTap: _openQuestDeskStyle,
                                            compact: true,
                                          ),
                                        ),
                                        Positioned(
                                          left: 64,
                                          right: 0,
                                          top: 0,
                                          bottom: 0,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(
                                                    'LEVEL',
                                                    style: Type.display
                                                        .copyWith(
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          letterSpacing: 0.8,
                                                          color:
                                                              Palette.textMid,
                                                        ),
                                                  ),
                                                  const SizedBox(width: 7),
                                                  Text(
                                                    '${_state.level}',
                                                    style: Type.numerals
                                                        .copyWith(
                                                          fontSize: 23,
                                                          color: Palette.textHi,
                                                        ),
                                                  ),
                                                  Expanded(
                                                    child: Align(
                                                      alignment:
                                                          Alignment.centerRight,
                                                      child: KeyedSubtree(
                                                        key: _xpNumberKey,
                                                        child: RollingNumber(
                                                          min(_state.xp, next),
                                                          suffix: ' / $next XP',
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style: Type.numerals
                                                              .copyWith(
                                                                fontSize: 15.5,
                                                                color:
                                                                    Palette.xp,
                                                              ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                              _QuestXpTrack(
                                                progress: _state.xp / next,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 7),
                                // ── The six domains ─────────────────────────────
                                _QuestHudPanel(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  child: SizedBox(
                                    height: largePhoneType ? 120 : 106,
                                    child: StatChips(
                                      values: _state.stats,
                                      reduceMotion: _state.reduceMotion,
                                    ),
                                  ),
                                ),
                                // ── Progression + desk finish ───────────────────
                                // Lifted out of the panels. Boxed inside them these
                                // were a frame within a frame, and the pair
                                // truncated against each other on every phone —
                                // "Expe…" sitting beside "MIDNIGHT DE…" reads as
                                // broken, not as dense.
                                const SizedBox.shrink(),
                                Offstage(
                                  offstage: true,
                                  child: Row(
                                    children: [
                                      if (_state.nextChaseLabel() != null) ...[
                                        Icon(
                                          _state.nextUnlockLabel() != null
                                              ? Icons.lock_outline
                                              : Icons.trending_up,
                                          size: 13,
                                          color: Palette.textLo,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            'NEXT · ${_state.nextChaseLabel()}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Type.label.copyWith(
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                      ] else
                                        const Spacer(),
                                      ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxWidth: 190,
                                        ),
                                        child: QuestDeskStyleButton(
                                          look: deskLook,
                                          onTap: _openQuestDeskStyle,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          Offstage(
                            offstage: true,
                            child: Column(
                              children: [
                                const InstallHint(),
                                // ONE banner at a time — the hearth has a single mantel. Whichever is
                                // due wins by priority; the others keep their own seen-stamps and get
                                // their own quiet day (audit: three stacked panels pushed the quest
                                // list below the fold on smaller phones).
                                _hearthPanel(),
                                if (lowFlame)
                                  _lowFlameBar(
                                    chosen: shelteredQuestCount,
                                    resting: resting,
                                    showingAll: _showFullLowFlame,
                                  ),
                              ],
                            ),
                          ),
                          // Planning tomorrow is a deliberate, time-bound action rather
                          // than an ordinary bonus. Keep that invitation at the room edge
                          // instead of burying it after a long board.
                          if (_state.emberDue &&
                              emberOfDay(now).title == planTomorrowEmber)
                            _emberPanel(),

                          // A shaped day earns a useful distinction that the
                          // old beautiful board did not provide: commitments,
                          // the few quests deliberately carried, and every
                          // other open possibility. Gentle Mode has its own
                          // shelter above and is intentionally not folded into
                          // this ordinary planning surface.
                          if (!lowFlame && !dayResting)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
                              child: _DailyFieldRail(
                                hasField: hasDailyField,
                                commitments: commitmentsVisible.length,
                                commitmentsRemaining: commitmentsRemaining,
                                chosen: chosenField.length,
                                chosenRemaining: fieldRemaining,
                                setAside: setAside,
                                optionalOpen: optionalOpen,
                                showingOptional: _showOptionalField,
                                onChoose: _chooseToday,
                                onToggleOptional:
                                    !showingDailyField || optionalOpen == 0
                                    ? null
                                    : () => setState(
                                        () => _showOptionalField =
                                            !_showOptionalField,
                                      ),
                              ),
                            ),

                          // ── Quest list ──────────────────────────────────────────
                          Padding(
                            padding: const EdgeInsets.fromLTRB(18, 7, 13, 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        dayResting
                                            ? 'THE DAY IS KEPT'
                                            : showFocus
                                            ? 'FOCUS MODE'
                                            : lowFlame
                                            ? (_showFullLowFlame
                                                  ? 'GENTLE MODE · $fullRemaining ON THE BOARD'
                                                  : 'GENTLE MODE · $remaining LEFT')
                                            : showingDailyField
                                            ? (largePhoneType
                                                  ? (remaining == 0
                                                        ? 'FIELD · ENOUGH'
                                                        : '$remaining TO CARRY')
                                                  : (remaining == 0
                                                        ? 'TODAY’S FIELD · ENOUGH'
                                                        : 'TODAY’S FIELD · $remaining TO CARRY'))
                                            : 'TODAY · $remaining OPEN',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Type.label.copyWith(
                                          fontSize: 12,
                                          color: showFocus
                                              ? Palette.streak
                                              : null,
                                        ),
                                      ),
                                      StreakFreezeStatus(state: _state),
                                    ],
                                  ),
                                ),
                                if (!dayResting)
                                  Row(
                                    children: [
                                      // one-quest-at-a-time toggle (round-21): tames the overwhelm
                                      _HeaderAction(
                                        icon: _state.focusMode
                                            ? Icons.center_focus_strong
                                            : Icons.center_focus_weak,
                                        color: _state.focusMode
                                            ? Palette.streak
                                            : Palette.xpLight,
                                        label: _state.focusMode
                                            ? 'Leave focus mode'
                                            : 'Focus mode — one quest at a time',
                                        onTap: _toggleFocus,
                                      ),
                                      _HeaderAction(
                                        icon: Icons.add_circle_outline,
                                        color: Palette.xpLight,
                                        label: 'Add a quest',
                                        onTap: _quickAdd,
                                      ),
                                      // Morning and night are independent doors:
                                      // an unviewed morning must not hide tonight.
                                      if (_state.morningAvailable)
                                        _HeaderAction(
                                          icon: Icons.wb_twilight,
                                          color: Palette.streak,
                                          label: 'Morning briefing',
                                          onTap: _openMorning,
                                        ),
                                      if (nightOpen && !showCloseDayRail)
                                        _HeaderAction(
                                          icon: Icons.nightlight_outlined,
                                          color: Palette.xpLight,
                                          label: 'Close the day',
                                          onTap: _openNight,
                                        ),
                                      // the momentum spark: cleared something? push further.
                                      Offstage(
                                        offstage: true,
                                        child: _HeaderAction(
                                          icon: Icons.bolt,
                                          color: Palette.xpLight,
                                          label:
                                              'Take one more step — encores & variety',
                                          onTap: _openMomentum,
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                          if (showCloseDayRail)
                            _CloseDayRail(
                              remaining: remaining,
                              onTap: _openNight,
                            ),
                        ],
                      ),
                    ),
                  ],
                  body: dayResting
                      ? _restingBody(now)
                      : showFocus
                      ? _focusBody(actionable, allDayLeft, now)
                      : ListView.separated(
                          // 130 is the shared dock inset (widgets/luxe_depth.dart);
                          // this board was the one list that used its own number,
                          // so its last quest stopped 14px shy of where every
                          // other page's does.
                          padding: const EdgeInsets.fromLTRB(12, 3, 12, 130),
                          itemCount: boardItemCount + 1,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            if (i == boardItemCount) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const InstallHint(),
                                  if (!(_state.emberDue &&
                                      emberOfDay(now).title ==
                                          planTomorrowEmber))
                                    _hearthPanel(),
                                  if (lowFlame)
                                    _lowFlameBar(
                                      chosen: shelteredQuestCount,
                                      resting: resting,
                                      showingAll: _showFullLowFlame,
                                    ),
                                ],
                              );
                            }
                            // a board with nothing on it — invite the first ember, don't
                            // pretend a day was "cleared" when none was
                            if (visible.isEmpty) {
                              return GlassPanel(
                                child: Column(
                                  children: [
                                    const Icon(
                                      Icons.add_task_rounded,
                                      size: 28,
                                      color: Palette.xpLight,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      sheltered
                                          ? 'The day is sheltered'
                                          : showingDailyField && setAside > 0
                                          ? 'A chosen quest is set aside'
                                          : showingDailyField && remaining == 0
                                          ? 'Enough for today'
                                          : 'A clear board',
                                      style: Type.display.copyWith(
                                        fontSize: 20,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      sheltered
                                          ? 'Nothing needs carrying right now. A clear day is allowed.'
                                          : showingDailyField && setAside > 0
                                          ? 'It is still part of today’s field, just resting out of sight. Bring it back when you are ready.'
                                          : showingDailyField
                                          ? 'Your field is kept. Other open quests are still here if the day has room.'
                                          : 'add a quest with + above, or take on a goal — '
                                                'choose one next step and the day tilts your way',
                                      textAlign: TextAlign.center,
                                      style: Type.body.copyWith(
                                        fontSize: 13.5,
                                        fontStyle: FontStyle.italic,
                                        color: Palette.textLo,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    GestureDetector(
                                      onTap: sheltered
                                          ? () =>
                                                unawaited(_editLowFlameThree())
                                          : showingDailyField
                                          ? () => unawaited(_chooseToday())
                                          : _quickAdd,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 18,
                                          vertical: 9,
                                        ),
                                        decoration: facetedDecoration(
                                          cut: 8,
                                          color: Colors.transparent,
                                          borderColor: Palette.xpLight
                                              .withValues(alpha: 0.6),
                                        ),
                                        child: Text(
                                          sheltered
                                              ? 'CHOOSE UP TO THREE'
                                              : showingDailyField
                                              ? 'EDIT TODAY’S FIELD'
                                              : 'ADD A QUEST',
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
                                duration: reduceMotion
                                    ? Duration.zero
                                    : Motion.takeover,
                                curve: Curves.easeOutBack,
                                builder: (_, t, child) => Opacity(
                                  opacity: t.clamp(0.0, 1.0),
                                  child: Transform.scale(
                                    scale: 0.9 + 0.1 * t,
                                    child: child,
                                  ),
                                ),
                                child: GlassPanel(
                                  glow: false,
                                  child: Column(
                                    children: [
                                      const Icon(
                                        Icons.auto_awesome,
                                        size: 26,
                                        color: Palette.xpLight,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        sheltered
                                            ? 'Enough for today'
                                            : showingDailyField
                                            ? 'Enough for today'
                                            : 'Day cleared',
                                        style: Type.display.copyWith(
                                          fontSize: 20,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      // the day reflected back — which domains you
                                      // tended, in the app's warm voice (round-32)
                                      Text(
                                        sheltered
                                            ? 'You protected your energy and still tended what mattered.'
                                            : showingDailyField
                                            ? 'The commitments and field you chose are kept. The rest remains open if it fits.'
                                            : _state.todaysShape(),
                                        textAlign: TextAlign.center,
                                        style: Type.body.copyWith(
                                          fontSize: 14,
                                          height: 1.4,
                                          color: Palette.textMid,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        sheltered
                                            ? '$resting quest${resting == 1 ? '' : 's'} resting safely · all still kept'
                                            : showingDailyField
                                            ? (optionalOpen == 0
                                                  ? 'nothing else needs carrying'
                                                  : '$optionalOpen quest${optionalOpen == 1 ? '' : 's'} still open if the day has room')
                                            : _state.nightDoneDay == nightDay
                                            ? 'rest well — tomorrow is already taking shape'
                                            : 'nothing left but the goodnight',
                                        style: Type.body.copyWith(
                                          fontSize: 13.5,
                                          fontStyle: FontStyle.italic,
                                          color: Palette.textLo,
                                        ),
                                      ),
                                      if (_state.nightDoneDay != nightDay) ...[
                                        const SizedBox(height: 14),
                                        HoneyButton(
                                          label: 'CLOSE THE DAY',
                                          icon: Icons.nightlight_outlined,
                                          onTap: () => _openNight(
                                            alreadyAcknowledged: true,
                                          ),
                                          expand: true,
                                        ),
                                      ],
                                      // Peak-end: closing the day is the handoff;
                                      // an encore stays available as a quiet extra.
                                      if (!sheltered) ...[
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
                                                'take one more step',
                                                style: Type.label.copyWith(
                                                  fontSize: 11,
                                                  color: Palette.streak,
                                                ),
                                              ),
                                            ],
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
                            final isFeatured =
                                !isDone &&
                                firstVisibleActionable >= 0 &&
                                identical(q, visible[firstVisibleActionable]);
                            final Widget card = QuestCard(
                              // stable key so a card's squash/state follows it as the list
                              // re-sorts a finished quest down to the bottom
                              key: ValueKey('card-${q.title}'),
                              featuredAnchor: isFeatured
                                  ? _featuredAnchor
                                  : null,
                              quest: q,
                              done: isDone,
                              featured: isFeatured,
                              xpPreview: _state.xpPreview(q),
                              deskFinish: deskLook.wood,
                              reduceMotion: _state.reduceMotion,
                              lightDirection: _activeLight,
                              scrollPosition: _scrollLight,
                              onComplete: (pos) => _completeQuest(q, pos),
                              onManage: () => _manageQuest(q),
                              // a finished, still-climbable quest offers the next rung
                              // right on the card
                              onEncore:
                                  (isDone &&
                                      !q.bonus &&
                                      !q.workout &&
                                      q.canRise)
                                  ? _openMomentum
                                  : null,
                            );
                            final requested =
                                widget.focusRequestId > 0 &&
                                widget.focusQuestTitle != null &&
                                q.title.trim().toLowerCase() ==
                                    widget.focusQuestTitle!
                                        .trim()
                                        .toLowerCase();
                            final deliveredCard = requested
                                ? _QuestArrival(
                                    key: ValueKey(
                                      'quest-arrival-${widget.focusRequestId}',
                                    ),
                                    accent: q.stat.color,
                                    reduceMotion: _state.reduceMotion,
                                    child: card,
                                  )
                                : card;
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
                                // The receipt teaches "swipe card to undo".
                                // Keeping a second hint on the card collided with
                                // XP on long titles and cheapened the settled win.
                                child: deliveredCard,
                              );
                            }
                            return deliveredCard;
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The guided runner enters as the destination room, while Quests stays the
/// durable owner underneath it. This same takeover is used whether the entry
/// tap began on a Quest card or the Goals workout door.
class _WorkoutTakeover extends StatelessWidget {
  const _WorkoutTakeover({required this.reduceMotion, required this.child});

  final bool reduceMotion;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final still =
        reduceMotion || (MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: still ? Motion.ack : const Duration(milliseconds: 320),
      curve: Motion.respond,
      child: child,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: still ? Offset.zero : Offset(0, 5 * (1 - t)),
          child: Transform.scale(
            scale: still ? 1 : 0.985 + (0.015 * t),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// The receiving half of the Goals → Quests handoff. The exact requested
/// Quest is already promoted by the board ordering; this brief local rim and
/// settle makes that continuity visible without sliding or blurring the page.
class _QuestArrival extends StatelessWidget {
  const _QuestArrival({
    super.key,
    required this.accent,
    required this.reduceMotion,
    required this.child,
  });

  final Color accent;
  final bool reduceMotion;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final still =
        reduceMotion || (MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: still ? Motion.ack : Motion.settle,
      curve: Motion.respond,
      child: child,
      builder: (context, t, child) {
        final glow = still ? 0.42 : (1 - t) * 0.72;
        return Transform.translate(
          offset: still ? Offset.zero : Offset(0, 5 * (1 - t)),
          child: Transform.scale(
            scale: still ? 1 : 0.992 + (0.008 * t),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: accent.withValues(alpha: glow),
                  width: glow > 0.1 ? 1.2 : 0,
                ),
                boxShadow: glow <= 0
                    ? const []
                    : [
                        BoxShadow(
                          color: accent.withValues(alpha: glow * 0.3),
                          blurRadius: 14 * glow,
                        ),
                      ],
              ),
              child: Padding(
                padding: EdgeInsets.all(glow > 0.1 ? 2 : 0),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A fixed slice of the player's selected complete room behind the quest board,
/// so the backdrop carries the same identity rather than acting as wallpaper.
class _QuestRoomBackdrop extends StatelessWidget {
  const _QuestRoomBackdrop({
    required this.state,
    required this.height,
    required this.parallax,
    required this.scrollPosition,
    required this.igniting,
    required this.hearthLit,
  });

  final GameState state;
  final double height;
  final ValueListenable<Offset> parallax;
  final ValueListenable<double> scrollPosition;
  final bool igniting;
  final bool hearthLit;

  @override
  Widget build(BuildContext context) {
    final still =
        state.reduceMotion ||
        (MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    return Positioned(
      top: 0,
      left: -17,
      right: -17,
      height: height + 18,
      child: AnimatedBuilder(
        animation: RoomPhotoStore.instance,
        builder: (context, _) => IgnorePointer(
          child: ClipRect(
            child: LayoutBuilder(
              builder: (context, bounds) {
                final roomWidth = bounds.maxWidth;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: roomWidth,
                        height: roomWidth / 1.7,
                        child: HomeRoom(
                          key: const Key('quests-room'),
                          aspect: 1.7,
                          unlocked: state.ownedFurniture,
                          plateId: activeQuestDeskLook(state).roomStyleId,
                          parallax: still ? null : parallax,
                          scrollPosition: scrollPosition,
                          igniting: igniting,
                          emberGlow: flameHueFor(state),
                          heirloomFlame: heirloomFlameFor(state),
                          lively: !still,
                          hearthLit: hearthLit,
                          level: state.level,
                          roomPhoto: RoomPhotoStore.instance.photo,
                        ),
                      ),
                    ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0x12000000),
                            Color(0x04000000),
                            Color(0x24191210),
                            Color(0xB0191210),
                          ],
                          stops: [0, 0.66, 0.92, 1],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Lives between the fixed room and scrolling content. As the board climbs,
/// the environment becomes progressively softer and warmer while every quest
/// label and action above this layer stays crisp.
class _QuestBackdropBlur extends StatelessWidget {
  const _QuestBackdropBlur({
    required this.state,
    required this.controller,
    required this.scrollPosition,
    required this.height,
    required this.parallax,
  });

  final ScrollController controller;
  final ValueListenable<double> scrollPosition;
  final GameState state;
  final double height;
  final ValueListenable<Offset> parallax;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: kIsWeb ? controller : Listenable.merge([controller, parallax]),
      builder: (context, _) {
        final offset = controller.hasClients
            ? controller.offset.clamp(0.0, 220.0)
            : 0.0;
        final strength = Curves.easeOutCubic.transform(offset / 220);
        // At rest there is no veil to composite. During scroll a registered,
        // pre-softened copy of the room replaces the former live
        // BackdropFilter, preserving the expensive-looking depth cue without
        // asking a phone GPU to reblur the full animated room every frame.
        if (strength <= 0.001) return const SizedBox.shrink();
        if (!kIsWeb) {
          return Positioned(
            top: 0,
            left: -17,
            right: -17,
            height: height + 18,
            child: AnimatedBuilder(
              animation: RoomPhotoStore.instance,
              builder: (context, _) => IgnorePointer(
                child: ClipRect(
                  child: Opacity(
                    key: const ValueKey('quest-backdrop-blur'),
                    opacity: strength,
                    child: LayoutBuilder(
                      builder: (context, bounds) => FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: bounds.maxWidth,
                          height: bounds.maxWidth / 1.7,
                          child: HomeRoom(
                            aspect: 1.7,
                            unlocked: const {},
                            plateId: activeQuestDeskLook(state).roomStyleId,
                            softened: true,
                            scrollPosition: scrollPosition,
                            hearthLit: false,
                            lively: false,
                            parallax:
                                state.reduceMotion ||
                                    (MediaQuery.maybeDisableAnimationsOf(
                                          context,
                                        ) ??
                                        false)
                                ? null
                                : parallax,
                            roomPhoto: RoomPhotoStore.instance.photo,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }
        {
          // CanvasKit's extra full-room raster cross-fade was still expensive
          // enough to interrupt iPhone scrolling. A source-colored value veil
          // keeps the foreground separation and warmth without introducing a
          // second viewport-sized image layer.
          return Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: height,
            child: IgnorePointer(
              child: DecoratedBox(
                key: const ValueKey('quest-backdrop-blur'),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(
                        0xFF1A120E,
                      ).withValues(alpha: 0.04 * strength),
                      const Color(
                        0xFF211610,
                      ).withValues(alpha: 0.18 * strength),
                      const Color(
                        0xFF140D0A,
                      ).withValues(alpha: 0.48 * strength),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
      },
    );
  }
}

/// Liquid-honey progress chrome. The tapestry remains a quiet permanent room
/// object instead of being repeated as an everyday HUD element.
/// The level mark: a cut-stone plate carrying one honey star. In the approved
/// board art this is the only piece of jewellery on the header, and it's what
/// anchors the left edge — without it LEVEL/XP is a line of text floating in a
/// slab with nothing holding it down.
class _QuestHudPanel extends StatelessWidget {
  const _QuestHudPanel({
    required this.child,
    this.padding = const EdgeInsets.all(12),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    const cut = 10.0;
    return DecoratedBox(
      decoration: facetedDecoration(
        cut: cut,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xEC27201A), Color(0xF2181411), Color(0xF5100D0B)],
          stops: [0, 0.58, 1],
        ),
        borderColor: const Color(0xFF584C40),
        borderWidth: 1,
        shadows: const [
          BoxShadow(
            color: Color(0x8F080605),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ClipPath(
        clipper: const FacetedClipper(cut: cut),
        child: Stack(
          children: [
            Padding(padding: padding, child: child),
            Positioned(
              left: 18,
              right: 18,
              top: 0,
              child: IgnorePointer(
                child: Container(
                  height: 1,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0x00FFE3AD),
                        Color(0x90FFE3AD),
                        Color(0x12FFE3AD),
                        Color(0x00FFE3AD),
                      ],
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

class _QuestXpTrack extends StatelessWidget {
  const _QuestXpTrack({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final value = progress.clamp(0.0, 1.0);
    return Container(
      height: 10,
      padding: const EdgeInsets.all(1.5),
      decoration: facetedDecoration(
        cut: 4,
        color: const Color(0xFF0E0B09),
        borderColor: const Color(0xFF4E4033),
        borderWidth: 0.8,
      ),
      child: ClipPath(
        clipper: const FacetedClipper(cut: 2.8),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: value,
            // Without heightFactor the childless DecoratedBox below lays out at
            // constraints.smallest — height 0 — and the fill vanishes entirely.
            // (FacetedMeter already carries this; this one had lost it.)
            heightFactor: 1,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFFFD98B),
                    Color(0xFFE4A347),
                    Color(0xFFB96520),
                  ],
                ),
                boxShadow: [BoxShadow(color: Palette.honeyGlow, blurRadius: 7)],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A board-header action: an icon inside a 44pt tap target (iOS HIG minimum).
/// Omit [onTap] for a disabled/indicator state (e.g. the spent moon).
class _ShelterAction extends StatelessWidget {
  const _ShelterAction({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      onTap: onTap,
      child: GestureDetector(
        excludeFromSemantics: true,
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: facetedDecoration(
            cut: 6,
            color: Colors.transparent,
            borderColor: color.withValues(alpha: 0.45),
          ),
          child: Text(
            label,
            style: Type.label.copyWith(
              fontSize: Type.minLabel,
              letterSpacing: 0.6,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

class _QuestDeskLookRow extends StatelessWidget {
  const _QuestDeskLookRow({
    required this.look,
    required this.selected,
    required this.owned,
    required this.price,
    required this.onTap,
  });

  final QuestDeskLook look;
  final bool selected;
  final bool owned;
  final int price;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    enabled: owned,
    label: '${look.name} Quest Desk style${owned ? '' : ', locked'}',
    child: InkWell(
      customBorder: const FacetedBorder(cut: 9),
      onTap: onTap,
      child: AnimatedOpacity(
        duration: Motion.quick,
        opacity: owned ? 1 : 0.52,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
          decoration: facetedDecoration(
            cut: 9,
            color: Color.lerp(const Color(0xD9241A15), look.wood, 0.22),
            borderColor: selected
                ? look.brass.withValues(alpha: 0.86)
                : look.brass.withValues(alpha: 0.30),
          ),
          child: Row(
            children: [
              // A swatch of the actual finish — wood, textile, brass — instead
              // of a 12 px slice of the tapestry raster, which showed the same
              // picture seven times and told you nothing about the desk.
              _DeskSwatch(look: look),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  look.name.toUpperCase(),
                  style: Type.label.copyWith(
                    fontSize: 11,
                    color: owned ? Palette.textHi : Palette.textLo,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (selected)
                Icon(Icons.check, size: 17, color: look.brass)
              else if (owned)
                Icon(Icons.chevron_right, size: 18, color: Palette.textLo)
              else ...[
                Icon(Icons.lock_outline, size: 14, color: Palette.textLo),
                const SizedBox(width: 4),
                if (price == 0)
                  Text(
                    'ROOM',
                    style: Type.label.copyWith(
                      fontSize: Type.minLabel,
                      color: Palette.textLo,
                    ),
                  )
                else ...[
                  Icon(Icons.auto_awesome, size: 11, color: Palette.textLo),
                  const SizedBox(width: 2),
                  Text(
                    '$price',
                    style: Type.label.copyWith(
                      fontSize: Type.minLabel,
                      color: Palette.textLo,
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

/// A material swatch for one Quest Desk finish: the wood plane it is cut from,
/// its textile band, and the brass it is trimmed in.
class _DeskSwatch extends StatelessWidget {
  const _DeskSwatch({required this.look});
  final QuestDeskLook look;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 64,
    height: 26,
    child: ClipPath(
      clipper: const FacetedClipper(cut: 6),
      child: DecoratedBox(
        decoration: facetedDecoration(
          cut: 6,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.lerp(look.wood, const Color(0xFFFFE9C4), 0.16)!,
              look.wood,
              Color.lerp(look.wood, const Color(0xFF14100C), 0.42)!,
            ],
          ),
          borderColor: look.brass.withValues(alpha: 0.62),
          borderWidth: 0.9,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(height: 7, color: look.textile),
            Container(height: 2, color: look.brass.withValues(alpha: 0.86)),
          ],
        ),
      ),
    ),
  );
}

class _DailyFieldRail extends StatelessWidget {
  const _DailyFieldRail({
    required this.hasField,
    required this.commitments,
    required this.commitmentsRemaining,
    required this.chosen,
    required this.chosenRemaining,
    required this.setAside,
    required this.optionalOpen,
    required this.showingOptional,
    required this.onChoose,
    required this.onToggleOptional,
  });

  final bool hasField;
  final int commitments;
  final int commitmentsRemaining;
  final int chosen;
  final int chosenRemaining;
  final int setAside;
  final int optionalOpen;
  final bool showingOptional;
  final VoidCallback onChoose;
  final VoidCallback? onToggleOptional;

  @override
  Widget build(BuildContext context) {
    final heading = hasField ? 'TODAY’S FIELD' : 'CHOOSE TODAY';
    final detail = !hasField
        ? 'Pick up to three quests to carry. Everything else stays open if the day has room.'
        : setAside > 0
        ? '$setAside chosen quest${setAside == 1 ? ' is' : 's are'} set aside for today. It still counts as part of the field.'
        : commitmentsRemaining + chosenRemaining == 0
        ? 'The commitments and field you chose are kept. Other quests remain open if it fits.'
        : '$commitmentsRemaining commitment${commitmentsRemaining == 1 ? '' : 's'} · $chosenRemaining chosen quest${chosenRemaining == 1 ? '' : 's'} to carry.';
    return Material(
      color: Colors.transparent,
      shape: const FacetedBorder(cut: 9),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const Key('daily-field-rail'),
        onTap: onChoose,
        child: Container(
          padding: const EdgeInsets.fromLTRB(13, 10, 12, 9),
          decoration: facetedDecoration(
            cut: 9,
            color: const Color(0xED241B17),
            borderColor: Palette.brass.withValues(alpha: 0.50),
            shadows: const [
              BoxShadow(
                color: Color(0x42000000),
                blurRadius: 11,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    hasField
                        ? Icons.bookmark_added_outlined
                        : Icons.bookmark_add_outlined,
                    size: 17,
                    color: Palette.xpLight,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      heading,
                      style: Type.label.copyWith(
                        fontSize: Type.minLabel,
                        color: Palette.xpLight,
                        letterSpacing: 1.05,
                      ),
                    ),
                  ),
                  Text(
                    hasField ? 'EDIT' : 'CHOOSE',
                    style: Type.label.copyWith(
                      fontSize: Type.minLabel,
                      color: Palette.textHi,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                detail,
                style: Type.body.copyWith(
                  fontSize: 13,
                  height: 1.28,
                  color: Palette.textMid,
                ),
              ),
              if (hasField) ...[
                const SizedBox(height: 7),
                Text(
                  'COMMITMENTS $commitments  ·  FIELD $chosen',
                  style: Type.label.copyWith(
                    fontSize: Type.minLabel,
                    color: Palette.textMid,
                    letterSpacing: 0.75,
                  ),
                ),
              ],
              if (onToggleOptional != null) ...[
                const SizedBox(height: 9),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Semantics(
                    button: true,
                    label: showingOptional
                        ? 'Hide optional quests'
                        : 'Open $optionalOpen optional quests if they fit',
                    child: InkWell(
                      onTap: onToggleOptional,
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 2,
                          vertical: 3,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              showingOptional
                                  ? Icons.keyboard_arrow_up
                                  : Icons.keyboard_arrow_down,
                              size: 18,
                              color: Palette.streak,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              showingOptional
                                  ? 'HIDE OPTIONAL QUESTS'
                                  : 'OPEN IF IT FITS · $optionalOpen',
                              style: Type.label.copyWith(
                                fontSize: Type.minLabel,
                                color: Palette.streak,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CloseDayRail extends StatelessWidget {
  const _CloseDayRail({required this.remaining, required this.onTap});

  final int remaining;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final detail = remaining == 0
        ? 'Nothing else needs doing.'
        : '$remaining quest${remaining == 1 ? '' : 's'} still open — close whenever you’re ready.';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 7),
      child: Semantics(
        button: true,
        label: 'Close the day. $detail',
        onTap: onTap,
        child: ExcludeSemantics(
          child: Material(
            key: const Key('close-day-rail'),
            color: Colors.transparent,
            shape: const FacetedBorder(cut: 9),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Container(
                constraints: const BoxConstraints(minHeight: 52),
                padding: const EdgeInsets.fromLTRB(13, 8, 11, 8),
                decoration: facetedDecoration(
                  cut: 9,
                  color: const Color(0xE6241B17),
                  borderColor: Palette.brass.withValues(alpha: 0.58),
                  shadows: const [
                    BoxShadow(
                      color: Color(0x52000000),
                      blurRadius: 12,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Palette.brass.withValues(alpha: 0.10),
                        border: Border.all(
                          color: Palette.brass.withValues(alpha: 0.42),
                        ),
                      ),
                      child: const Icon(
                        Icons.nightlight_outlined,
                        size: 18,
                        color: Palette.xpLight,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CLOSE THE DAY',
                            style: Type.label.copyWith(
                              fontSize: Type.minLabel,
                              color: Palette.xpLight,
                              letterSpacing: 1.15,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            detail,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Type.body.copyWith(
                              fontSize: 11.5,
                              height: 1.2,
                              color: Palette.textMid,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: Palette.textLo,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.icon,
    required this.color,
    required this.label,
    this.onTap,
  });
  final IconData icon;
  final Color color;

  /// What this glyph does — a long-press tooltip for everyone and the
  /// VoiceOver name (a11y pass: five mystery icons, zero labels before).
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: label,
      child: Tooltip(
        message: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            width: 44,
            height: 44,
            margin: const EdgeInsets.only(left: 5),
            alignment: Alignment.center,
            decoration: facetedDecoration(
              cut: 8,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF241D18), Color(0xFF13100E)],
              ),
              borderColor: const Color(0xFF4D4035),
              borderWidth: 0.9,
            ),
            child: Icon(icon, size: 20, color: color),
          ),
        ),
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
      final spokenLabel = l == _FocusLens.quickWin
          ? 'Order quests: Ease in'
          : 'Order quests: Hardest first';
      return Semantics(
        button: true,
        selected: on,
        label: spokenLabel,
        onTap: () => onChanged(l),
        excludeSemantics: true,
        child: GestureDetector(
          onTap: () => onChanged(l),
          behavior: HitTestBehavior.opaque,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: AnimatedContainer(
              duration: Motion.quick,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: facetedDecoration(
                cut: 7,
                color: on ? Palette.xpLight.withValues(alpha: 0.22) : null,
                borderColor: Colors.transparent,
              ),
              child: Text(
                label,
                style: Type.label.copyWith(
                  fontSize: Type.minLabel,
                  color: on ? Palette.xpLight : Palette.textLo,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: facetedDecoration(
        cut: 9,
        color: Colors.transparent,
        borderColor: Palette.glassEdge,
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
  const _ComboFlourish({
    required this.combo,
    required this.flameHue,
    required this.onDone,
  });
  final int combo;
  final Color flameHue;
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
    if (n == 4) return 'LOCKED IN';
    if (n == 3) return 'IN FLOW';
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
              // easeOutBack overshoots (a little bounce); under reduce-motion
              // swap to a plain easeOut so the pill settles without the pop.
              final inCurve = Haptics.reduceMotion
                  ? Curves.easeOut
                  : Curves.easeOutBack;
              final inP = inCurve.transform((t / 0.22).clamp(0.0, 1.0));
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
                      decoration: facetedDecoration(
                        cut: 8,
                        color: Palette.card.withValues(alpha: 0.92),
                        borderColor: Palette.streak.withValues(alpha: 0.7),
                        shadows: [
                          BoxShadow(
                            color: Palette.streak.withValues(alpha: 0.4),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.bolt_rounded,
                            size: 18,
                            color: widget.flameHue,
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
/// The streak shown as forgiving continuity — a link + day count that lifts
/// gently when it extends and NEVER turns red, urgent, or "don't lose this".
/// Shields and rest days absorb misses silently upstream (never-punish), so
/// this is only ever an anchor, never a threat.
class _StreakChip extends StatefulWidget {
  const _StreakChip({required this.days});
  final int days;

  @override
  State<_StreakChip> createState() => _StreakChipState();
}

class _StreakChipState extends State<_StreakChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flare = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 480),
  );

  @override
  void didUpdateWidget(_StreakChip old) {
    super.didUpdateWidget(old);
    if (widget.days > old.days) _flare.forward(from: 0);
  }

  @override
  void dispose() {
    _flare.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _flare,
      builder: (context, child) {
        final s = _flare.value > 0 ? sin(_flare.value * pi) : 0.0;
        return Transform.scale(scale: 1 + 0.18 * s, child: child);
      },
      // Unboxed on purpose. Inside an already-bordered panel this pill was one
      // more frame in a stack of frames, and it lit up an area of chrome that
      // should be reading as dark glass. The ember hue alone carries it.
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.link_rounded, size: 14, color: Palette.streak),
          const SizedBox(width: 3),
          Text(
            '${widget.days}',
            style: Type.label.copyWith(fontSize: 12, color: Palette.streak),
          ),
        ],
      ),
    );
  }
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

/// The "one more step" encore sheet. For each quest cleared today it
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

  DateTime get _now => Clock.now();

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
    Sfx.instance.playInteraction(InteractionSound.place);
    HapticFeedback.mediumImpact();
    setState(() {
      _spawned.add(title);
      _note = null;
    });
  }

  void _shuffle() {
    Sfx.instance.playMaterial(MaterialSound.wood);
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
                    'TAKE ONE MORE STEP',
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
                      decoration: facetedDecoration(
                        cut: 9,
                        gradient: Palette.honeyGradient,
                        shadows: const [
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
                          color: Palette.onHoney,
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
      decoration: facetedDecoration(
        cut: 10,
        color: Palette.glassFill,
        borderColor: Palette.glassEdge,
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
    final fg = highlight ? Palette.onHoney : Palette.xpLight;
    return GestureDetector(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 160),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: facetedDecoration(
            cut: 8,
            gradient: highlight ? Palette.honeyGradient : null,
            borderColor: highlight
                ? Colors.transparent
                : Palette.xpLight.withValues(alpha: 0.5),
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
                      color: highlight ? Palette.onHoney : Palette.textMid,
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
  late int _rung = widget.quest.rung;
  late int _timerMinutes = widget.quest.timerMinutes;

  @override
  Widget build(BuildContext context) {
    final maxD = widget.quest.custom ? 8 : 10;
    final ladder = widget.quest.ladder;
    // When a rung names its own minutes the rung picker owns the timer;
    // otherwise the session length is the person's to set.
    final tunableTimer =
        widget.quest.verification == Verification.timer &&
        !widget.quest.ladderOwnsTimer;
    final minuteChoices = <int>{5, 10, 15, 20, 25, 45, _timerMinutes}.toList()
      ..sort();
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
                      decoration: facetedDecoration(
                        cut: 6,
                        color: _stat == s
                            ? s.color.withValues(alpha: 0.22)
                            : Colors.transparent,
                        borderColor: s.color.withValues(
                          alpha: _stat == s ? 0.8 : 0.3,
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
            if (ladder != null && ladder.length > 1) ...[
              const SizedBox(height: 10),
              Text(
                'WHERE ARE YOU NOW?',
                style: Type.label.copyWith(fontSize: 11),
              ),
              const SizedBox(height: 6),
              // The ladder is the amount control: pick the rung that matches
              // today's honest floor and the prescription follows. Payout
              // moves with it on save, mirroring the night rise, so a higher
              // start earns like a risen quest instead of inflating XP.
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (var i = 0; i < ladder.length; i++)
                    GestureDetector(
                      key: ValueKey('tune-rung-$i'),
                      onTap: () => setState(() {
                        _difficulty = (_difficulty + (i - _rung)).clamp(
                          1,
                          maxD.toDouble(),
                        );
                        _rung = i;
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: facetedDecoration(
                          cut: 6,
                          color: _rung == i
                              ? Palette.xp.withValues(alpha: 0.20)
                              : Colors.transparent,
                          borderColor: Palette.xp.withValues(
                            alpha: _rung == i ? 0.8 : 0.3,
                          ),
                        ),
                        child: Text(
                          ladder[i],
                          style: Type.label.copyWith(
                            fontSize: 11,
                            color: _rung == i
                                ? Palette.xpLight
                                : Palette.textMid,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
            if (tunableTimer) ...[
              const SizedBox(height: 10),
              Text('SESSION LENGTH', style: Type.label.copyWith(fontSize: 11)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final minutes in minuteChoices)
                    GestureDetector(
                      key: ValueKey('tune-minutes-$minutes'),
                      onTap: () => setState(() => _timerMinutes = minutes),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: facetedDecoration(
                          cut: 6,
                          color: _timerMinutes == minutes
                              ? Palette.verify.withValues(alpha: 0.20)
                              : Colors.transparent,
                          borderColor: Palette.verify.withValues(
                            alpha: _timerMinutes == minutes ? 0.8 : 0.3,
                          ),
                        ),
                        child: Text(
                          '$minutes MIN',
                          style: Type.label.copyWith(
                            fontSize: 11,
                            color: _timerMinutes == minutes
                                ? Palette.verify
                                : Palette.textMid,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
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
                      decoration: facetedDecoration(
                        cut: 7,
                        color: Colors.transparent,
                        borderColor: _stat.color.withValues(alpha: 0.6),
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
                  if (tunableTimer) {
                    widget.quest.timerMinutes = _timerMinutes;
                  }
                  if (_rung != widget.quest.rung) {
                    // A hand-picked rung restarts the climb from here; the
                    // held-completions count belongs to the old prescription.
                    widget.quest.rung = _rung;
                    widget.quest.risingStreak = 0;
                  }
                  widget.onSaved();
                  Navigator.of(context).pop();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 10,
                  ),
                  decoration: facetedDecoration(
                    cut: 9,
                    gradient: Palette.honeyGradient,
                    shadows: const [
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
                      color: Palette.onHoney,
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
