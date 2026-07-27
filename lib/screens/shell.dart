import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio.dart';
import '../clock.dart';
import '../cloud.dart';
import '../content/ladders.dart';
import '../content/routines.dart';
import '../engine.dart';
import '../haptics.dart';
import '../journal_media.dart' as media;
import '../models.dart';
import '../notifications.dart';
import '../storage.dart';
import '../tokens.dart';
import '../widgets/facets.dart';
import '../widgets/glass.dart';
import '../widgets/onboarding_flow.dart';
import '../widgets/routine_flows.dart';
import 'calendar.dart';
import 'goal_wizard.dart';
import 'goals.dart';
import 'insights.dart';
import 'me.dart';
import 'quests.dart';

/// App shell: warm candlelit desk, five pages (Me · Quests · Goals · Plans ·
/// Insights), floating glass nav dock. Owns the GameState + quest list,
/// persists them locally, and runs day-rollover on launch/resume + at an
/// in-app midnight tick (so a foregrounded PWA rolls over on time).
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  GameState? _state;
  List<Quest>? _quests;
  int _tab = 1; // Quests is home
  OverlayEntry? _morningOverlay;
  Timer? _midnight; // fires at the next local midnight to roll the day over

  /// Bound by QuestsPage so pause-path saves always flush a pending
  /// deferred commit before writing (bug-hunt §1 — observer order alone
  /// is fragile across IndexedStack rebuilds).
  VoidCallback? _flushQuestsCommit;

  /// Serializes preference writes so a slower old write cannot land after a
  /// newer one. Export and lifecycle flushes await this same tail.
  Future<void> _saveTail = Future.value();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _midnight?.cancel();
    super.dispose();
  }

  /// Arm a one-shot timer for the next local midnight so a device left
  /// foregrounded past 00:00 (a desktop PWA especially) rolls the day over on
  /// time — instead of appending after-midnight completions to yesterday's
  /// haul until the next resume. Re-armed after it fires and on resume.
  void _armMidnight() {
    _midnight?.cancel();
    final now = Clock.now();
    final next = DateTime(now.year, now.month, now.day).add(
      const Duration(days: 1, minutes: 1), // a minute past, to be safely over
    );
    _midnight = Timer(next.difference(now), () {
      final s = _state, q = _quests;
      if (mounted && s != null && q != null && s.rollover(q)) {
        setState(() {});
        _persist();
        _maybeMorning();
      }
      _armMidnight();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    final s = _state;
    final q = _quests;
    if (s == null || q == null) return;
    if (lifecycle == AppLifecycleState.resumed) {
      Storage.logEvent('open');
      // a new day may have started while we were away
      if (s.rollover(q)) setState(() {});
      _armMidnight(); // re-aim at the (possibly new) next midnight
      _maybeMorning();
    } else if (lifecycle == AppLifecycleState.paused ||
        lifecycle == AppLifecycleState.inactive) {
      // flush any in-flight quest completion BEFORE saving — otherwise a
      // done-marked quest can persist without its XP (deferred-commit window)
      _flushQuestsCommit?.call();
      // stamp newness on the pause-path save too (only _persist did before),
      // so a mutation that never notified — e.g. an applyLevelUps shield grant
      // — can't be written with a stale timestamp and lose the cloud LWW race
      s.lastModified = Clock.now().millisecondsSinceEpoch;
      unawaited(
        _persistNow(push: false).then((_) {
          // flush the pending cloud push NOW — a scheduled debounce timer is
          // killed when the OS suspends the PWA, silently dropping the last
          // completions from the cloud mirror.
          CloudSync.instance.flush();
        }),
      );
    }
  }

  Future<void> _load() async {
    await _loadFromStorage();
    _armMidnight(); // begin the in-app day-rollover clock
    Storage.logEvent('open');
    // Defer the welcome/morning overlays until the cloud has settled, so a
    // recovered cloud save can suppress a spurious first-run welcome on a
    // reinstalled device. (Cloud-disabled path settles near-instantly.)
    await _connectCloud();
    if (!mounted) return;
    _maybeOnboard();
    _maybeMorning();
    _rescheduleNotifications(); // refresh reminders for today (native-only)
  }

  /// (Re)build state + quests from the local save. Swaps the persist
  /// listener cleanly; never touches the cloud or the welcome overlays.
  Future<void> _loadFromStorage() async {
    final saved = await Storage.load();
    final state = saved?.$1 ?? GameState();
    final quests = saved?.$2 ?? _buildQuests();
    state.rollover(quests);
    _state?.removeListener(_persist);
    state.addListener(_persist);
    // No clean save in _key (first run, or a corrupt blob was quarantined):
    // write the fresh state now so the local store holds valid bytes — never
    // leave a corrupt blob sitting in _key to be read by a later push.
    if (saved == null) await Storage.save(state, quests);
    if (!mounted) return;
    Haptics.reduceMotion = state.reduceMotion;
    setState(() {
      _state = state;
      _quests = quests;
    });
  }

  /// Connect the cloud mirror. ALWAYS compares the cloud copy's newness
  /// against the local one (by lastModified) so a stale device can never
  /// overwrite a newer cloud save — the local-only LWW trap. Cloud newer →
  /// adopt it; otherwise push local up. No recursion: a single re-load.
  Future<void> _connectCloud() async {
    await CloudSync.instance.init();
    if (!mounted || !CloudSync.instance.ready) return;
    // the UI is interactive during the pull (up to 8s) — remember how new the
    // local save was WHEN WE STARTED, so a completion made in those seconds
    // isn't silently overwritten by the adopted cloud blob
    final localBefore = _state?.lastModified ?? 0;
    final res = await CloudSync.instance.pull();
    // pull FAILED → we don't know the cloud's state; pushing local could
    // clobber a newer unread save. Skip entirely; retry next launch.
    if (!res.ok) return;
    // local changed while we were pulling → don't adopt; our newer local wins,
    // and the push below mirrors it up (recheck next launch handles the rest)
    if ((_state?.lastModified ?? 0) != localBefore) {
      CloudSync.instance.push();
      return;
    }
    final cloudRaw = res.data;
    if (cloudRaw == null) {
      CloudSync.instance.push();
      return;
    }
    // A non-null unreadable/newer-format remote is not an empty document.
    // Preserve the only possible recovery copy instead of replacing it.
    if (!Storage.isValidSave(cloudRaw) ||
        Storage.schemaOf(cloudRaw) > Storage.schema) {
      return;
    }
    if (Storage.lastModifiedOf(cloudRaw) > localBefore &&
        Storage.schemaOf(cloudRaw) >= Storage.schema) {
      if (!await Storage.importRaw(cloudRaw)) return;
      await _loadFromStorage();
    }
    CloudSync.instance.push(); // safe: we successfully read the cloud state
  }

  /// First run: the welcome flow before anything else.
  void _maybeOnboard() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = _state;
      if (!mounted || s == null || s.onboarded) return;
      late final OverlayEntry e;
      e = OverlayEntry(
        builder: (_) => OnboardingFlow(
          state: s,
          onFinish:
              ({required bool forgeFirstGoal, required TimeShape timeShape}) {
                _applyTimeShape(timeShape);
                _persist();
                e.remove();
                if (!mounted) return;
                setState(() {});
                if (forgeFirstGoal) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          GoalWizardScreen(state: s, onAdd: _addQuest),
                    ),
                  );
                }
              },
        ),
      );
      Overlay.of(context).insert(e);
    });
  }

  /// Trim or keep the starter board to match how much room days have.
  void _applyTimeShape(TimeShape shape) {
    final q = _quests;
    if (q == null) return;
    final keepCount = switch (shape) {
      TimeShape.light => 3,
      TimeShape.full => 5,
      TimeShape.packed => 7,
    };
    final defaults = _buildQuests();
    final keep = defaults.take(keepCount).map((e) => e.title).toSet();
    final drop = defaults
        .where((e) => !keep.contains(e.title))
        .map((e) => e.title)
        .toSet();
    q.removeWhere((e) => drop.contains(e.title));
    _state?.removedDefaults.addAll(drop.map((e) => e.toLowerCase()));
  }

  /// Auto-greet: last night was closed out, today hasn't been briefed.
  void _maybeMorning() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = _state;
      final q = _quests;
      if (!mounted || s == null || q == null) return;
      if (!s.onboarded) return; // welcome first; morning can wait
      if (!s.morningPending || _morningOverlay != null) return;
      late final OverlayEntry e;
      e = OverlayEntry(
        builder: (_) => MorningFlow(
          state: s,
          quests: q,
          onClose: () {
            s.closeMorning(); // disarms the briefing
            _persist();
            e.remove();
            _morningOverlay = null;
            if (mounted) setState(() {});
          },
        ),
      );
      _morningOverlay = e;
      Overlay.of(context).insert(e);
    });
  }

  void _persist() => unawaited(_persistNow());

  Future<void> _persistNow({bool push = true}) {
    final s = _state;
    final q = _quests;
    if (s != null && q != null) {
      s.lastModified = Clock.now().millisecondsSinceEpoch;
      Haptics.reduceMotion = s.reduceMotion;
      _saveTail = _saveTail.then((_) => Storage.save(s, q));
      if (push) {
        _saveTail = _saveTail.then((_) => CloudSync.instance.push());
      }
    }
    return _saveTail;
  }

  /// Copies the raw save to the clipboard for a user-held backup.
  Future<bool> _export() async {
    await _persistNow(); // make sure the blob is current
    final raw = await Storage.exportRaw();
    if (raw == null) return false;
    await Clipboard.setData(ClipboardData(text: raw));
    return true;
  }

  /// Restores a pasted backup, then reloads the world from it.
  Future<bool> _import(String raw) async {
    final ok = await Storage.importRaw(raw);
    if (!ok) return false;
    _state?.removeListener(_persist);
    await _load();
    return true;
  }

  static List<Quest> _buildQuests() => [
    Quest(
      title: 'Do 2 push-ups',
      stat: Stat.str,
      difficulty: 2,
      rising: true,
      ladder: Ladders.byBaseTitle['Do 2 push-ups'],
      ladderHint: 'CLIMBS AS YOU GROW 📈',
    ),
    Quest(
      title: 'Walk 10 minutes',
      stat: Stat.vit,
      difficulty: 3,
      rising: true,
      ladder: Ladders.byBaseTitle['Walk 10 minutes'],
      ladderHint: 'CLIMBS AS YOU GROW 📈',
    ),
    Quest(
      title: 'Read one page',
      stat: Stat.intl,
      difficulty: 2,
      rising: true,
      ladder: Ladders.byBaseTitle['Read one page'],
      ladderHint: 'CLIMBS AS YOU GROW 📈',
    ),
    Quest(title: 'Message a friend', stat: Stat.soc, difficulty: 3),
    Quest(title: 'Clear the sink', stat: Stat.dis, difficulty: 4, dread: true),
    Quest(
      title: '25-minute focus session',
      stat: Stat.foc,
      difficulty: 5,
      verification: Verification.timer,
      timerMinutes: 25,
    ),
    // a hand-held option for the user who wants to move but isn't a gym rat
    workoutLauncherQuest(),
    Quest(
      title: 'Workout — full session',
      stat: Stat.str,
      difficulty: 8,
      ladderHint: 'LADDER · 20 MIN → 40 MIN',
    ),
    Quest(
      title: 'No caffeine after 2pm',
      stat: Stat.vit,
      difficulty: 7,
      dread: true,
      allDay: true,
    ),
  ];

  void _reset() {
    final old = _state;
    final oldRoomCode = old?.roomCode;
    old?.removeListener(_persist);
    CloudSync.instance.cancelPending(); // drop any stale pre-reset push
    unawaited(Notifications.cancelAll());
    Storage.clearUsage(); // reset means erase me — wipe the usage log too
    media
        .clearAll(); // …and every journal photo on disk (else orphaned forever)
    final fresh = GameState()..rollover([]);
    fresh.addListener(_persist);
    setState(() {
      _state = fresh;
      _quests = _buildQuests();
    });
    _maybeOnboard();
    // Erase the cloud copy and published room too. Guest profiles also delete
    // their anonymous Firebase identity before a fresh one is created, so a
    // reset cannot leave an unreachable backend account behind.
    CloudSync.instance
        .resetProfile(roomCode: oldRoomCode)
        .whenComplete(_persist);
  }

  /// Non-destructive refresh of the quest board: re-run the day's rollover
  /// and re-add any default starter quests that have gone missing. Never
  /// touches the character or progress. Returns how many were re-added.
  int _refreshQuests() {
    final q = _quests;
    final s = _state;
    if (q == null || s == null) return 0;
    final have = q.map((e) => e.title.trim().toLowerCase()).toSet();
    var added = 0;
    for (final d in _buildQuests()) {
      final key = d.title.trim().toLowerCase();
      // skip defaults the user deliberately removed — refresh restores only
      // quests lost to a glitch, never ones they pruned on purpose
      if (!have.contains(key) && !s.removedDefaults.contains(key)) {
        q.add(d);
        added++;
      }
    }
    s.rollover(q);
    setState(() {});
    _persist();
    return added;
  }

  /// A JSON snapshot of the whole save right now — captured before a quest
  /// completes so an accidental tap can be fully undone.
  String _captureSnapshot() => jsonEncode({
    'state': _state?.toJson(),
    'quests': [for (final q in _quests ?? const <Quest>[]) q.toJson()],
  });

  /// Restore a snapshot (the undo action): rebuild state + quests exactly as
  /// they were, reverting every reward the completion granted.
  void _restoreSnapshot(String snap) {
    try {
      final j = (jsonDecode(snap) as Map).cast<String, dynamic>();
      final state = GameState.fromJson(
        (j['state'] as Map).cast<String, dynamic>(),
      );
      final quests = [
        for (final q in (j['quests'] as List? ?? const []))
          Quest.fromJson((q as Map).cast<String, dynamic>()),
      ];
      // Preserve anything ADDED to the board after the snapshot was taken — a
      // quick-add or a momentum bonus during the 5s undo window must not vanish
      // when the user reverts the unrelated completion (bug-hunt §2).
      final snapTitles = {for (final q in quests) q.title.trim().toLowerCase()};
      for (final live in _quests ?? const <Quest>[]) {
        if (!snapTitles.contains(live.title.trim().toLowerCase())) {
          quests.add(live);
        }
      }
      // Same for JOURNAL entries: a line jotted during the undo window is real
      // writing that the completion-revert has no business erasing. Merge any
      // live entry whose id isn't in the snapshot back into the restored state.
      // (Purchases intentionally revert with their embers — consistent — but
      // words are pure loss, so they're kept.)
      final live = _state;
      if (live != null) {
        final snapIds = {for (final n in state.journal) n.id};
        final extra = [
          for (final n in live.journal)
            if (!snapIds.contains(n.id)) n,
        ];
        if (extra.isNotEmpty) {
          state.setJournal([...state.journal, ...extra]);
        }
      }
      _state?.removeListener(_persist);
      state.addListener(_persist);
      setState(() {
        _state = state;
        _quests = quests;
      });
      _persist();
    } catch (e) {
      debugPrint('undo restore failed: $e');
    }
  }

  /// Link an email/password account to the current data (keeps everything).
  Future<String?> _linkAccount(String email, String pw) =>
      CloudSync.instance.linkAccount(email, pw);

  Future<String?> _enableCloud() async {
    final error = await CloudSync.instance.enable();
    if (error != null) return error;
    await _persistNow(push: false);
    CloudSync.instance.flush();
    if (mounted) setState(() {});
    return null;
  }

  /// Sign in to an existing account on this device, then ADOPT that
  /// account's cloud save (explicit login means "give me my keep",
  /// even if this device's local save looks newer). If the account has no
  /// cloud save yet, push the local one up as its first.
  Future<String?> _signIn(String email, String pw) async {
    final err = await CloudSync.instance.signIn(email, pw);
    if (err != null) return err;
    final res = await CloudSync.instance.pull();
    if (!res.ok) {
      // couldn't READ the account's save — never push this device's data
      // over it. Back out to anonymous so the account stays safe, retry later.
      await CloudSync.instance.signOut(saveAccount: false);
      if (mounted) setState(() {});
      return 'Couldn’t reach your account — check your connection and try again.';
    }
    final cloudRaw = res.data;
    if (cloudRaw == null) {
      CloudSync.instance.push(); // doc confirmed absent → push first save
    } else if (!Storage.isValidSave(cloudRaw) ||
        Storage.schemaOf(cloudRaw) > Storage.schema ||
        !await Storage.importRaw(cloudRaw)) {
      await CloudSync.instance.signOut(saveAccount: false);
      if (mounted) setState(() {});
      return 'That account save needs a newer Emberkeep build or is damaged. '
          'Nothing was overwritten.';
    } else {
      await _loadFromStorage(); // adopt the account's keep and progress
      await _rescheduleNotifications();
    }
    if (mounted) setState(() {});
    return null;
  }

  Future<void> _signOut() async {
    // signOut() flushes the account's save (room code and all) to the account
    // doc first; only then do we forget the code locally — the fresh anonymous
    // session doesn't own that room and can't update or take it down. Signing
    // back in re-adopts the account's save (and its code).
    await CloudSync.instance.signOut();
    _state?.setRoomCode(null);
    _persist();
    if (mounted) setState(() {});
  }

  Future<String?> _deleteAccount(String password) async {
    final s = _state;
    if (s == null) return 'Your keep is still loading — try again.';
    final error = await CloudSync.instance.deleteAccount(
      password,
      roomCode: s.roomCode,
    );
    if (error != null) return error;
    s.removeListener(_persist);
    CloudSync.instance.cancelPending();
    await Notifications.cancelAll();
    await Storage.clear();
    await Storage.clearCorruptBackup();
    await Storage.clearUsage();
    await media.clearAll();
    final fresh = GameState()..rollover([]);
    fresh.addListener(_persist);
    if (!mounted) return null;
    setState(() {
      _state = fresh;
      _quests = _buildQuests();
    });
    await _persistNow(push: false);
    _maybeOnboard();
    return null;
  }

  void _removeQuest(Quest q) {
    final s = _state;
    // remember if this was a default, so refresh won't bring it back
    final key = q.title.trim().toLowerCase();
    if (s != null &&
        _buildQuests().any((d) => d.title.trim().toLowerCase() == key)) {
      s.removedDefaults.add(key);
    }
    setState(() => _quests?.remove(q));
    _persist();
    unawaited(_rescheduleNotifications());
  }

  void _removeGoal(Goal g) {
    final s = _state;
    if (s == null) return;
    setState(() {
      s.removeGoal(g);
      _quests?.removeWhere((q) => q.goalTitle == g.title);
    });
    _persist();
    unawaited(_rescheduleNotifications());
  }

  /// Adds a quest; refuses duplicates by title (case-insensitive).
  bool _addQuest(Quest q) {
    final quests = _quests;
    if (quests == null) return false;
    final key = q.title.trim().toLowerCase();
    if (quests.any((e) => e.title.trim().toLowerCase() == key)) return false;
    q.createdDay ??= Days.key(Clock.now());
    setState(() => quests.add(q));
    _persist();
    // a new dated plan should get its reminder right away (native-only)
    if (q.isEvent && (_state?.notifyEnabled ?? false)) {
      _rescheduleNotifications();
    }
    return true;
  }

  /// (Re)schedule local reminders from the current prefs + dated plans.
  /// No-ops on web (the native plugin isn't compiled there).
  Future<void> _rescheduleNotifications() async {
    final s = _state;
    final q = _quests;
    if (s == null || q == null) return;
    if (!s.notifyEnabled) {
      await Notifications.cancelAll();
      return;
    }
    await Notifications.scheduleDailyNudge(s.notifyHour, s.notifyMinute);
    final now = Clock.now();
    final events = <EventReminder>[
      for (final quest in q)
        if (quest.isEvent && quest.dueDate != null && !quest.doneFor(now))
          EventReminder(
            when: DateTime(
              quest.dueDate!.year,
              quest.dueDate!.month,
              quest.dueDate!.day,
              s.notifyHour,
              s.notifyMinute,
            ),
            title: 'Today: ${quest.displayTitle}',
            body: 'A plan you set is due.',
          ),
    ];
    await Notifications.scheduleEvents(events);
  }

  void _selectTab(int i) {
    if (i == _tab) return;
    // The keep is visited often; auto-playing fire on every return became
    // tiring on a real phone. Keep Me quiet and reserve the full ignition for
    // a genuine hearth revival. Other tab changes retain the soft nav cue.
    if (i != 0) Sfx.instance.play('tick');
    Haptics.tap();
    setState(() => _tab = i);
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    final quests = _quests;
    if (state == null || quests == null) {
      // first frame while the save loads — keep it warm and quiet
      return const WarmBackground(
        child: Center(
          child: CircularProgressIndicator(color: Palette.xp, strokeWidth: 3),
        ),
      );
    }

    // Only the canvas listens to the notifier (theme swaps recolor it live);
    // the Scaffold subtree is passed as `child` and not rebuilt on every notify.
    return ListenableBuilder(
      listenable: state,
      builder: (context, child) => WarmBackground(
        themeId: state.canvasTheme,
        reduceMotion: state.reduceMotion,
        child: child!,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              Positioned.fill(
                child: IndexedStack(
                  index: _tab,
                  // IndexedStack keeps all five tabs alive, and nothing about
                  // being un-indexed stops a ticker — so before this the
                  // keep's hearth, the fireflies, the sky and every other
                  // ambient loop ran on ALL FIVE tabs at once, forever, four
                  // of them invisible. TickerMode mutes the vsync for the
                  // subtrees you can't see; each controller resumes exactly
                  // where it was when its tab comes forward. Free battery.
                  children: [
                    for (final (i, page) in <Widget>[
                      MePage(
                        state: state,
                        quests: quests,
                        onPersist: _persist,
                        onAddQuest: _addQuest,
                        onExport: _export,
                        onImport: _import,
                        onReset: _reset,
                        onNotifyChanged: _rescheduleNotifications,
                        onEnableCloud: _enableCloud,
                        onLinkAccount: _linkAccount,
                        onSignIn: _signIn,
                        onSignOut: _signOut,
                        onDeleteAccount: _deleteAccount,
                      ),
                      QuestsPage(
                        state: state,
                        quests: quests,
                        onRefresh: _refreshQuests,
                        onPersist: _persist,
                        onAdd: _addQuest,
                        onRemove: _removeQuest,
                        onSnapshot: _captureSnapshot,
                        onRestore: _restoreSnapshot,
                        onBindFlush: (flush) => _flushQuestsCommit = flush,
                      ),
                      GoalsPage(
                        state: state,
                        onAdd: _addQuest,
                        activeTitles: {for (final q in quests) q.title},
                        onRemoveGoal: _removeGoal,
                        onPersist: _persist,
                        quests: quests,
                      ),
                      CalendarPage(
                        state: state,
                        quests: quests,
                        onAdd: _addQuest,
                      ),
                      InsightsPage(
                        state: state,
                        quests: quests,
                        onPersist: _persist,
                      ),
                    ].indexed)
                      TickerMode(enabled: _tab == i, child: page),
                  ],
                ),
              ),
              // ── floating glass dock ─────────────────────────────
              Positioned(
                left: 0,
                right: 0,
                bottom: 18 + MediaQuery.paddingOf(context).bottom,
                child: Center(
                  child: GlassPanel(
                    blur: true,
                    radius: 999,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _DockItem(
                          icon: Icons.emoji_emotions_outlined,
                          label: 'ME',
                          selected: _tab == 0,
                          onTap: () => _selectTab(0),
                        ),
                        _DockItem(
                          icon: Icons.task_alt,
                          label: 'QUESTS',
                          selected: _tab == 1,
                          onTap: () => _selectTab(1),
                        ),
                        _DockItem(
                          icon: Icons.explore_outlined,
                          label: 'GOALS',
                          selected: _tab == 2,
                          onTap: () => _selectTab(2),
                        ),
                        _DockItem(
                          icon: Icons.calendar_month_outlined,
                          label: 'PLANS',
                          selected: _tab == 3,
                          onTap: () => _selectTab(3),
                        ),
                        _DockItem(
                          icon: Icons.insights_outlined,
                          label: 'INSIGHTS',
                          selected: _tab == 4,
                          onTap: () => _selectTab(4),
                        ),
                      ],
                    ),
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

class _DockItem extends StatelessWidget {
  const _DockItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$label tab',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.settle,
          curve: Motion.respond,
          constraints: const BoxConstraints(minHeight: 48),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
          decoration: facetedDecoration(
            cut: 9,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: selected
                  ? const [Color(0xFFF2CD93), Color(0xFFC49C6C)]
                  : const [Colors.transparent, Colors.transparent],
            ),
            borderColor: selected
                ? const Color(0x66FFF0C7)
                : Colors.transparent,
            shadows: selected
                ? const [
                    BoxShadow(
                      color: Palette.honeyGlow,
                      blurRadius: 14,
                      offset: Offset(0, 4),
                    ),
                  ]
                : const [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 23,
                color: selected ? const Color(0xFF4A2F1A) : Palette.textLo,
              ),
              if (selected) ...[
                const SizedBox(width: 7),
                Text(
                  label,
                  style: Type.label.copyWith(
                    fontSize: 12,
                    color: const Color(0xFF4A2F1A),
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
