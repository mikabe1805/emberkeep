import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio.dart';
import '../cloud.dart';
import '../content/ladders.dart';
import '../content/routines.dart';
import '../engine.dart';
import '../models.dart';
import '../notifications.dart';
import '../storage.dart';
import '../tokens.dart';
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
/// Sparks), floating glass nav dock. Owns the GameState + quest list,
/// persists them locally, and runs day-rollover on launch/resume.
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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
      _maybeMorning();
    } else if (lifecycle == AppLifecycleState.paused ||
        lifecycle == AppLifecycleState.inactive) {
      Storage.save(s, q);
      // flush the pending cloud push NOW — a scheduled debounce timer is
      // killed when the OS suspends the PWA, silently dropping the last
      // completions from the cloud mirror.
      CloudSync.instance.flush();
    }
  }

  Future<void> _load() async {
    await _loadFromStorage();
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
    final res = await CloudSync.instance.pull();
    // pull FAILED → we don't know the cloud's state; pushing local could
    // clobber a newer unread save. Skip entirely; retry next launch.
    if (!res.ok) return;
    final cloudRaw = res.data;
    if (cloudRaw != null &&
        Storage.lastModifiedOf(cloudRaw) > (_state?.lastModified ?? 0) &&
        // never adopt an OLDER-schema cloud save even if its timestamp is
        // newer — an old build strips fields it doesn't know (loot, shields,
        // skin, theme, ladder progress); we re-enrich it instead (bug-hunt §5)
        Storage.schemaOf(cloudRaw) >= Storage.schema &&
        await Storage.importRaw(cloudRaw)) {
      // a newer life lives in the cloud — bring it home
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
          onFinish: ({required bool forgeFirstGoal}) {
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

  void _persist() {
    final s = _state;
    final q = _quests;
    if (s != null && q != null) {
      s.lastModified = DateTime.now().millisecondsSinceEpoch;
      Storage.save(s, q).then((_) => CloudSync.instance.push());
    }
  }

  /// Copies the raw save to the clipboard for a user-held backup.
  Future<bool> _export() async {
    _persist(); // make sure the blob is current
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
            ladderHint: 'CLIMBS AS YOU GROW 📈'),
        Quest(
            title: 'Walk 10 minutes',
            stat: Stat.vit,
            difficulty: 3,
            rising: true,
            ladder: Ladders.byBaseTitle['Walk 10 minutes'],
            ladderHint: 'CLIMBS AS YOU GROW 📈'),
        Quest(
            title: 'Read one page',
            stat: Stat.intl,
            difficulty: 2,
            rising: true,
            ladder: Ladders.byBaseTitle['Read one page'],
            ladderHint: 'CLIMBS AS YOU GROW 📈'),
        Quest(
            title: '25-minute focus session',
            stat: Stat.foc,
            difficulty: 5,
            verification: Verification.timer,
            timerMinutes: 25),
        Quest(title: 'Message a friend', stat: Stat.soc, difficulty: 3),
        Quest(title: 'Clear the sink', stat: Stat.dis, difficulty: 4, dread: true),
        // a hand-held option for the user who wants to move but isn't a gym rat
        workoutLauncherQuest(),
        Quest(
            title: 'Workout — full session',
            stat: Stat.str,
            difficulty: 8,
            ladderHint: 'LADDER · 20 MIN → 40 MIN'),
        Quest(
            title: 'No caffeine after 2pm',
            stat: Stat.vit,
            difficulty: 7,
            dread: true,
            allDay: true),
      ];

  void _reset() {
    final old = _state;
    old?.removeListener(_persist);
    CloudSync.instance.cancelPending(); // drop any stale pre-reset push
    Storage.clearUsage(); // reset means erase me — wipe the usage log too
    final fresh = GameState()..rollover([]);
    fresh.addListener(_persist);
    setState(() {
      _state = fresh;
      _quests = _buildQuests();
    });
    // Erase the cloud copy too, then persist the fresh state — otherwise a
    // recovery on another device would resurrect everything just erased.
    CloudSync.instance.deleteRemote().whenComplete(_persist);
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
      final state =
          GameState.fromJson((j['state'] as Map).cast<String, dynamic>());
      final quests = [
        for (final q in (j['quests'] as List? ?? const []))
          Quest.fromJson((q as Map).cast<String, dynamic>()),
      ];
      // Preserve anything ADDED to the board after the snapshot was taken — a
      // quick-add or a momentum bonus during the 5s undo window must not vanish
      // when the user reverts the unrelated completion (bug-hunt §2).
      final snapTitles = {
        for (final q in quests) q.title.trim().toLowerCase()
      };
      for (final live in _quests ?? const <Quest>[]) {
        if (!snapTitles.contains(live.title.trim().toLowerCase())) {
          quests.add(live);
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

  /// Sign in to an existing account on this device, then ADOPT that
  /// account's cloud save (explicit login means "give me my character",
  /// even if this device's local save looks newer). If the account has no
  /// cloud save yet, push the local one up as its first.
  Future<String?> _signIn(String email, String pw) async {
    final err = await CloudSync.instance.signIn(email, pw);
    if (err != null) return err;
    final res = await CloudSync.instance.pull();
    if (!res.ok) {
      // couldn't READ the account's save — never push this device's data
      // over it. Back out to anonymous so the account stays safe, retry later.
      await CloudSync.instance.signOut();
      if (mounted) setState(() {});
      return 'Couldn’t reach your account — check your connection and try again.';
    }
    final cloudRaw = res.data;
    if (cloudRaw != null &&
        Storage.isValidSave(cloudRaw) &&
        await Storage.importRaw(cloudRaw)) {
      await _loadFromStorage(); // adopt the account's character
    } else {
      CloudSync.instance.push(); // doc confirmed absent → push first save
    }
    if (mounted) setState(() {});
    return null;
  }

  Future<void> _signOut() async {
    await CloudSync.instance.signOut();
    if (mounted) setState(() {});
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
  }

  void _removeGoal(Goal g) {
    final s = _state;
    if (s == null) return;
    setState(() {
      s.removeGoal(g);
      _quests?.removeWhere((q) => q.goalTitle == g.title);
    });
    _persist();
  }

  /// Adds a quest; refuses duplicates by title (case-insensitive).
  bool _addQuest(Quest q) {
    final quests = _quests;
    if (quests == null) return false;
    final key = q.title.trim().toLowerCase();
    if (quests.any((e) => e.title.trim().toLowerCase() == key)) return false;
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
    final now = DateTime.now();
    final events = <EventReminder>[
      for (final quest in q)
        if (quest.isEvent &&
            quest.dueDate != null &&
            !quest.doneFor(now))
          EventReminder(
            when: DateTime(quest.dueDate!.year, quest.dueDate!.month,
                quest.dueDate!.day, s.notifyHour, s.notifyMinute),
            title: 'Today: ${quest.displayTitle}',
            body: 'A plan you set is due 🔥',
          ),
    ];
    await Notifications.scheduleEvents(events);
  }

  void _selectTab(int i) {
    if (i == _tab) return;
    Sfx.instance.play('tick');
    HapticFeedback.selectionClick();
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
      builder: (context, child) =>
          WarmBackground(themeId: state.canvasTheme, child: child!),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              Positioned.fill(
                child: IndexedStack(
                  index: _tab,
                  children: [
                    MePage(
                        state: state,
                        onExport: _export,
                        onImport: _import,
                        onReset: _reset,
                        onNotifyChanged: _rescheduleNotifications,
                        onLinkAccount: _linkAccount,
                        onSignIn: _signIn,
                        onSignOut: _signOut),
                    QuestsPage(
                      state: state,
                      quests: quests,
                      onRefresh: _refreshQuests,
                      onPersist: _persist,
                      onAdd: _addQuest,
                      onRemove: _removeQuest,
                      onSnapshot: _captureSnapshot,
                      onRestore: _restoreSnapshot,
                    ),
                    GoalsPage(
                      state: state,
                      onAdd: _addQuest,
                      activeTitles: {for (final q in quests) q.title},
                      onRemoveGoal: _removeGoal,
                      quests: quests,
                    ),
                    CalendarPage(
                        state: state, quests: quests, onAdd: _addQuest),
                    InsightsPage(state: state),
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
                        horizontal: 10, vertical: 8),
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.settle,
        curve: Motion.respond,
        constraints: const BoxConstraints(minHeight: 48),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: selected
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFF2CD93), Color(0xFFC49C6C)],
                )
              : null,
          boxShadow: selected
              ? const [
                  BoxShadow(
                      color: Palette.honeyGlow,
                      blurRadius: 14,
                      offset: Offset(0, 4)),
                ]
              : const [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 23,
                color: selected ? const Color(0xFF4A2F1A) : Palette.textLo),
            if (selected) ...[
              const SizedBox(width: 7),
              Text(label,
                  style: Type.label.copyWith(
                      fontSize: 12, color: const Color(0xFF4A2F1A))),
            ],
          ],
        ),
      ),
    );
  }
}
