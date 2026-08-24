import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio.dart';
import '../clock.dart';
import '../cloud.dart';
import '../content/ladders.dart';
import '../content/quest_desk_styles.dart';
import '../content/release_notes.dart';
import '../content/routines.dart';
import '../daybook/data/daybook_preferences.dart';
import '../daybook/services/place_search_access.dart';
import '../daybook/services/place_search_identity_removal.dart';
import '../engine.dart';
import '../haptics.dart';
import '../journal_media.dart' as media;
import '../models.dart';
import '../notifications.dart';
import '../release_features.dart';
import '../release_notes_preferences.dart';
import '../storage.dart';
import '../social.dart';
import '../tokens.dart';
import '../widgets/facets.dart';
import '../widgets/glass.dart' show OverlaySurface, WarmBackground;
import '../widgets/home_room.dart'
    show preloadHearthFireFrames, preloadSpaceTheme;
import '../widgets/luxe_depth.dart';
import '../widgets/onboarding_flow.dart';
import '../widgets/pressable.dart';
import '../widgets/routine_flows.dart';
import 'calendar.dart';
import 'goal_wizard.dart';
import 'goals.dart';
import 'hearth_circle.dart';
import 'insights.dart';
import 'me.dart';
import 'quests.dart';
import 'room_guide.dart';
import 'whats_new.dart';

/// Returns the next occurrence of a reminder's local wall-clock time.
/// Calendar construction keeps the displayed hour stable across DST changes.
DateTime nextNightReminderOccurrence(DateTime now, int hour, int minute) {
  var next = DateTime(now.year, now.month, now.day, hour, minute);
  if (!next.isAfter(now)) {
    next = DateTime(now.year, now.month, now.day + 1, hour, minute);
  }
  return next;
}

bool shouldSuppressNextNightReminder({
  required DateTime now,
  required int hour,
  required int minute,
  required String? nightDoneDay,
}) {
  if (nightDoneDay == null) return false;
  final next = nextNightReminderOccurrence(now, hour, minute);
  return Days.nightKey(next) == nightDoneDay;
}

/// The welcome ignition is a visible-room event, never a launch side effect.
/// Keeping this pure makes overlay ordering explicit and regression-testable.
bool sessionIgnitionMayBegin({
  required bool startupSettled,
  required bool onboarded,
  required bool questRoomVisible,
  required bool whatsNewPending,
  required bool whatsNewVisible,
  required bool whatsNewCheckScheduled,
  required bool morningVisible,
  required bool morningCheckScheduled,
}) =>
    startupSettled &&
    onboarded &&
    questRoomVisible &&
    !whatsNewPending &&
    !whatsNewVisible &&
    !whatsNewCheckScheduled &&
    !morningVisible &&
    !morningCheckScheduled;

class FreshSocialInbox {
  const FreshSocialInbox({required this.sparkKinds, required this.circleAdds});

  final List<String> sparkKinds;
  final int circleAdds;

  bool get isEmpty => sparkKinds.isEmpty && circleAdds == 0;
}

/// Keeps launch/resume notices calm: an uncollected receipt stays visible in
/// Circle, but it is announced only once during this app session.
class SocialInboxSessionTracker {
  final Set<String> _sparkIds = {};
  final Set<String> _circleAddIds = {};

  FreshSocialInbox takeFresh({
    required Iterable<Map<String, dynamic>> sparks,
    required Iterable<Map<String, dynamic>> circleAdds,
  }) {
    final kinds = <String>[];
    for (final spark in sparks) {
      final id = spark['id'];
      if (id is! String || id.isEmpty || !_sparkIds.add(id)) continue;
      kinds.add(normalizedSparkKind(spark['kind']));
    }
    var freshAdds = 0;
    for (final add in circleAdds) {
      final id = add['id'];
      if (id is String && id.isNotEmpty && _circleAddIds.add(id)) freshAdds++;
    }
    return FreshSocialInbox(sparkKinds: kinds, circleAdds: freshAdds);
  }
}

String socialInboxNoticeText({
  required Iterable<String> sparkKinds,
  required int circleAdds,
}) {
  final parts = <String>[
    if (circleAdds > 0) circleAddNoticeText(circleAdds),
    if (sparkKinds.isNotEmpty) sparkSupportNoticeText(sparkKinds),
  ];
  return parts.join(' ');
}

/// App shell: warm candlelit desk, five pages (Me · Quests · Goals · Plans ·
/// Insights), floating glass nav dock. Owns the GameState + quest list,
/// persists them locally, and runs day-rollover on launch/resume + at an
/// in-app midnight tick (so a foregrounded PWA rolls over on time).
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    this.initialRoomCode,
    this.roomLinks,
    this.releaseNotesGate,
  });

  final String? initialRoomCode;
  final RoomLinkInbox? roomLinks;

  /// Optional seam for preference-failure and launch-order tests. Production
  /// uses the device-local SharedPreferences implementation.
  final ReleaseNotesGate? releaseNotesGate;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  GameState? _state;
  List<Quest>? _quests;
  int _tab = 1; // Quests is home
  final Set<int> _visitedTabs = {1};
  final List<Object> _soundTabScopes = List<Object>.generate(
    5,
    (_) => Object(),
    growable: false,
  );
  late final LuxeMotionController _luxeMotion;
  late final ReleaseNotesGate _releaseNotesGate;
  OverlayEntry? _morningOverlay;
  OverlayEntry? _whatsNewOverlay;
  bool _morningCheckScheduled = false;
  bool _whatsNewCheckScheduled = false;
  bool _ignitionCheckScheduled = false;
  bool _whatsNewPending = false;
  bool _startupSettled = false;
  bool _initialRoomHandled = false;
  bool _drainingRoomLinks = false;
  bool _checkingSocialInbox = false;
  final SocialInboxSessionTracker _socialInboxSession =
      SocialInboxSessionTracker();
  Timer? _midnight; // fires at the next local midnight to roll the day over
  Timer? _ignitionClearTimer;
  Future<void> _notificationSchedule = Future<void>.value();
  Future<String?>? _enableCloudFuture;
  final AppSessionIgnitionGate _sessionIgnition = AppSessionIgnitionGate();
  bool _roomIgniting = false;
  bool _roomHearthLit = false;

  /// Bound by QuestsPage so pause-path saves always flush a pending
  /// deferred commit before writing (bug-hunt §1 — observer order alone
  /// is fragile across IndexedStack rebuilds).
  VoidCallback? _flushQuestsCommit;
  void Function(Quest quest, Offset anchor)? _completeQuest;
  void Function(Quest launcher)? _openGuidedWorkout;

  /// Serializes preference writes so a slower old write cannot land after a
  /// newer one. Export and lifecycle flushes await this same tail.
  Future<bool> _saveTail = Future.value(true);

  @override
  void initState() {
    super.initState();
    _releaseNotesGate =
        widget.releaseNotesGate ??
        const ReleaseNotesGate(SharedPreferencesReleaseSeenStore());
    _luxeMotion = LuxeMotionController();
    unawaited(_luxeMotion.start());
    Sfx.instance.setInteractionScreen(_soundTabScopes[_tab]);
    WidgetsBinding.instance.addObserver(this);
    widget.roomLinks?.addListener(_onIncomingRoomLink);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.roomLinks?.removeListener(_onIncomingRoomLink);
    _midnight?.cancel();
    _ignitionClearTimer?.cancel();
    _luxeMotion.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.roomLinks == widget.roomLinks) return;
    oldWidget.roomLinks?.removeListener(_onIncomingRoomLink);
    widget.roomLinks?.addListener(_onIncomingRoomLink);
    _onIncomingRoomLink();
  }

  void _onIncomingRoomLink() {
    if (_startupSettled) unawaited(_drainPendingRoomLinks());
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
      _maybeWhatsNew();
      _maybeMorning();
      unawaited(_rescheduleNotifications(refreshTimeZone: true));
      unawaited(_notifySocialInbox());
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
        _persistNow(push: false).then((saved) {
          if (!saved) return;
          // flush the pending cloud push NOW — a scheduled debounce timer is
          // killed when the OS suspends the PWA, silently dropping the last
          // completions from the cloud mirror.
          CloudSync.instance.flush();
          final cloud = CloudSync.instance;
          final syncProfile =
              kVisitorProfileSharingEnabled && s.shareSpaceProfile;
          final publicProfile = syncProfile
              ? spaceProfileDisplay(s, audience: SpaceAudience.anyone)
              : const <String, dynamic>{};
          final mutualProfile = syncProfile
              ? spaceProfileDisplay(s, audience: SpaceAudience.mutuals)
              : const <String, dynamic>{};
          cloud.flushRoom(
            roomDisplay(
              s,
              mediaOwnerUid: cloud.socialUid,
              mediaRoomCode: s.roomCode,
            ),
            code: s.roomCode,
            discoverable: kSpaceDiscoveryEnabled && s.roomDiscoverable,
            syncSpaceProfile: syncProfile,
            publicProfile: publicProfile.isEmpty ? null : publicProfile,
            mutualProfile: mutualProfile.isEmpty ? null : mutualProfile,
          );
        }),
      );
    }
  }

  Future<void> _load() async {
    // A restore can call _load again while the shell is already mounted. Do
    // not let a lifecycle resume surface a briefing from the transient local
    // copy before cloud/restore reconciliation has finished.
    _startupSettled = false;
    await _loadFromStorage();
    _armMidnight(); // begin the in-app day-rollover clock
    Storage.logEvent('open');
    // Defer the welcome/morning overlays until the cloud has settled, so a
    // recovered cloud save can suppress a spurious first-run welcome on a
    // reinstalled device. (Cloud-disabled path settles near-instantly.)
    await _connectCloud();
    if (!mounted) return;
    _startupSettled = true;
    final openedInitialRoom = await _openInitialRoom();
    final openedLinkedRoom = await _drainPendingRoomLinks();
    if (openedInitialRoom || openedLinkedRoom) {
      unawaited(_refreshPublishedRoom());
      unawaited(_notifySocialInbox());
      return;
    }
    unawaited(_refreshPublishedRoom());
    unawaited(_notifySocialInbox());
    _maybeOnboard();
    _maybeWhatsNew();
    _maybeMorning();
    _maybeStartSessionIgnition();
    _rescheduleNotifications(); // refresh reminders for today (native-only)
  }

  /// Repair the current public document on launch and rotate a restored code
  /// that belongs to a lost anonymous identity. Someone who already shared has
  /// explicitly opted into this room publication; this never turns sharing on.
  Future<void> _refreshPublishedRoom() async {
    final state = _state;
    final cloud = CloudSync.instance;
    if (state == null || !cloud.available) return;
    if (state.roomCode == null && !state.roomDiscoveryRemovalPending) return;
    if (!await cloud.ensureSocialSession() || !mounted) return;
    final currentCode = state.roomCode;
    final currentDisplay = currentCode == null
        ? const <String, dynamic>{}
        : roomDisplay(
            state,
            mediaOwnerUid: cloud.socialUid,
            mediaRoomCode: currentCode,
          );
    var removedPendingDiscovery = false;
    for (final pendingCode in state.roomDiscoveryRemovalCodes) {
      final removed = await cloud.setRoomDiscoverable(
        pendingCode,
        currentDisplay,
        discoverable: false,
      );
      if (!mounted) return;
      if (!removed) continue;
      state.confirmRoomDiscoveryRemoval(pendingCode);
      removedPendingDiscovery = true;
    }
    if (removedPendingDiscovery) {
      await _persistNow(push: false);
    }
    if (currentCode == null) return;
    final result = await publishSpaceRoomState(
      state,
      current: state,
      code: currentCode,
    );
    final code = result.code;
    if (code == null) return;
    if (code == state.roomCode) {
      if (kSpaceDiscoveryEnabled && state.roomDiscoverable) {
        await cloud.setRoomDiscoverable(
          code,
          currentDisplay,
          discoverable: true,
        );
      }
      return;
    }
    state.setRoomCode(code);
    // A recovered code rotation is a new public address. Never silently carry
    // an old directory opt-in onto it; the keeper can deliberately re-enable
    // discovery from Share.
    state.setRoomDiscoverable(false);
    await _persistNow();
    _showSocialNotice(
      'Your restored share code belonged to another session, so a new one was made: $code',
    );
  }

  /// The My Space editor uses this acknowledged path only when its bounded
  /// public room payload changed. Ordinary local persistence remains
  /// best-effort, while privacy reductions never claim success before the
  /// server has accepted them.
  Future<RoomPublishResult> _publishSpaceRoom(
    GameState target, {
    required String code,
  }) async {
    final current = _state;
    if (current == null) {
      return const RoomPublishResult.failed(RoomPublishFailure.unavailable);
    }
    final result = await publishSpaceRoomState(
      target,
      current: current,
      code: code,
    );
    final publishedCode = result.code;
    if (publishedCode != null &&
        kSpaceDiscoveryEnabled &&
        target.roomDiscoverable) {
      unawaited(
        CloudSync.instance.setRoomDiscoverable(
          publishedCode,
          roomDisplay(
            target,
            mediaOwnerUid: CloudSync.instance.socialUid,
            mediaRoomCode: publishedCode,
          ),
          discoverable: true,
        ),
      );
    }
    return result;
  }

  /// Surface Circle receipts without making the owner manually open Circle to
  /// discover them. Receipts remain there until collected; each one is toasted
  /// once per app session and is checked again on resume.
  Future<void> _notifySocialInbox() async {
    final state = _state;
    final cloud = CloudSync.instance;
    final code = state?.roomCode;
    if (_checkingSocialInbox || code == null || !cloud.available) return;
    _checkingSocialInbox = true;
    try {
      if (!await cloud.ensureSocialSession() || !mounted) return;
      final receipts = await Future.wait([
        cloud.fetchSparks(code),
        cloud.fetchCircleAdds(code),
      ]);
      if (!mounted) return;
      final fresh = _socialInboxSession.takeFresh(
        sparks: receipts[0],
        circleAdds: receipts[1],
      );
      if (fresh.isEmpty) return;
      _showSocialNotice(
        socialInboxNoticeText(
          sparkKinds: fresh.sparkKinds,
          circleAdds: fresh.circleAdds,
        ),
      );
    } finally {
      _checkingSocialInbox = false;
    }
  }

  void _showSocialNotice(String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger == null) return;
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(message),
            action: SnackBarAction(
              label: 'OPEN CIRCLE',
              onPressed: _openCircle,
            ),
          ),
        );
    });
  }

  void _openCircle() {
    final state = _state;
    if (state == null || !mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HearthCircleScreen(
          state: state,
          onPersist: _persist,
          parallax: _luxeMotion.parallax,
        ),
      ),
    );
  }

  /// A web invite carries the room code in its URL. Let startup and cloud auth
  /// settle first, then validate that code through the same visitor handoff as
  /// a typed one. Onboarding waits until the visitor returns home.
  Future<bool> _openInitialRoom() async {
    final code = widget.initialRoomCode;
    final state = _state;
    if (_initialRoomHandled || code == null || state == null) return false;
    _initialRoomHandled = true;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return true;
    await visitSpace(
      context,
      initialCode: code,
      autoSubmit: true,
      state: state,
      onPersist: _persist,
      themeId: state.canvasTheme,
      lively: !state.reduceMotion,
      parallax: _luxeMotion.parallax,
    );
    if (mounted) {
      _maybeOnboard();
      _maybeWhatsNew();
      _maybeMorning();
      _maybeStartSessionIgnition();
      _rescheduleNotifications();
    }
    return true;
  }

  /// Opens queued platform links one at a time through the exact visitor flow
  /// used by a typed code. The inbox can receive a warm link while startup or
  /// another visit is in flight, so never drop or overlap those sheets.
  Future<bool> _drainPendingRoomLinks() async {
    final inbox = widget.roomLinks;
    final state = _state;
    if (!_startupSettled ||
        inbox == null ||
        state == null ||
        _drainingRoomLinks) {
      return false;
    }
    _drainingRoomLinks = true;
    var opened = false;
    try {
      while (mounted) {
        final link = inbox.takeNext();
        if (link == null) break;
        opened = true;
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted) break;
        // An empty code is a claimed-but-codeless link (bare or typo'd
        // /space): open the prompt unfilled so the person can finish the
        // code themselves instead of the tap doing nothing.
        await visitSpace(
          context,
          initialCode: link.code.isEmpty ? null : link.code,
          autoSubmit: link.code.isNotEmpty,
          state: state,
          onPersist: _persist,
          themeId: state.canvasTheme,
          lively: !state.reduceMotion,
          parallax: _luxeMotion.parallax,
        );
        if (!mounted) break;
        _maybeOnboard();
        _maybeWhatsNew();
        _maybeMorning();
        _maybeStartSessionIgnition();
        _rescheduleNotifications();
      }
    } finally {
      _drainingRoomLinks = false;
    }
    // A link can land just after the final takeNext above but before the
    // listener is free to begin another drain. Pick it up without asking the
    // user to tap again.
    if (mounted && inbox.isNotEmpty) unawaited(_drainPendingRoomLinks());
    return opened;
  }

  /// (Re)build state + quests from the local save. Swaps the persist
  /// listener cleanly; never touches the cloud or the welcome overlays.
  Future<void> _loadFromStorage() async {
    final saved = await Storage.load();
    _whatsNewPending =
        _whatsNewPending ||
        await _releaseNotesGate.claim(
          releaseId: currentRoomReleaseNotes.id,
          freshInstall: saved == null,
        );
    final state = saved?.$1 ?? GameState();
    final quests = saved?.$2 ?? _buildQuests();
    final releaseCapabilitiesChanged = !kVisitorProfileSharingEnabled
        ? state.disableVisitorProfileSharing()
        : !kVisitorPhotoSharingEnabled
        ? state.disableVisitorPhotoSharing()
        : false;
    state.rollover(quests);
    _state?.removeListener(_persist);
    state.addListener(_persist);
    // No clean save in _key (first run, or a corrupt blob was quarantined):
    // write the fresh state now so the local store holds valid bytes — never
    // leave a corrupt blob sitting in _key to be read by a later push.
    if (saved == null || releaseCapabilitiesChanged) {
      await Storage.save(state, quests);
    }
    if (!mounted) return;
    Haptics.reduceMotion = state.reduceMotion;
    Sfx.instance.soundEnabled = state.soundEnabled;
    // Decode the selected complete room while the Quest home is appearing, so
    // opening Me never flashes the procedural legacy fallback.
    unawaited(preloadSpaceTheme(state.wallStyle));
    // The room plate can be large; the shared three-frame fire is small enough
    // to warm in parallel so the very first hearth is already lit when Me
    // opens, without paying to decode every cosmetic room at launch.
    unawaited(preloadHearthFireFrames());
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
    final cloud = CloudSync.instance;
    // Block save pushes for the whole read/compare window. The UI remains
    // interactive, but no mutation can race ahead and overwrite the copy we
    // have not inspected yet.
    cloud.holdSavePushes(report: false);
    await cloud.init();
    if (!mounted) return;
    if (!cloud.ready) {
      cloud.releaseSavePushes();
      return;
    }
    // The UI is interactive during the pull (up to 8s). Snapshot the actual
    // blob — including its schema — so a legacy local save can safely compare
    // with a legacy remote before this build migrates either one.
    final localRawBefore = await Storage.exportRaw();
    final localBefore = localRawBefore == null
        ? 0
        : Storage.lastModifiedOf(localRawBefore);
    final res = await cloud.pull();
    // pull FAILED → we don't know the cloud's state; pushing local could
    // clobber a newer unread save. Skip entirely; retry next launch.
    if (!res.ok) {
      cloud.holdSavePushes();
      return;
    }
    final cloudRaw = res.data;
    // Local changed while we were pulling → never adopt over that live work.
    // Flush it to the blob, then push only when the normal schema/readability
    // gate says doing so cannot destroy a cloud recovery copy.
    if ((_state?.lastModified ?? 0) != localBefore) {
      if (!await _saveTail) {
        cloud.holdSavePushes();
        return;
      }
      final liveRaw = await Storage.exportRaw();
      if (Storage.decideCloudMerge(localRaw: liveRaw, remoteRaw: cloudRaw) ==
          CloudMergeDecision.pushLocal) {
        cloud.releaseSavePushes();
        cloud.push();
      } else {
        cloud.holdSavePushes();
      }
      return;
    }

    switch (Storage.decideCloudMerge(
      localRaw: localRawBefore,
      remoteRaw: cloudRaw,
    )) {
      case CloudMergeDecision.hold:
        cloud.holdSavePushes();
        return;
      case CloudMergeDecision.pushLocal:
        cloud.releaseSavePushes();
        cloud.push();
        return;
      case CloudMergeDecision.adoptRemote:
        if (cloudRaw == null || !await Storage.importRaw(cloudRaw)) {
          cloud.holdSavePushes();
          return;
        }
        await _loadFromStorage();
        // A same-schema legacy winner (for example 17 ↔ 17) is safe to adopt,
        // but must be rewritten as this build's schema before it is mirrored.
        if (Storage.schemaOf(cloudRaw) < Storage.schema) {
          final state = _state;
          final quests = _quests;
          if (state == null || quests == null) {
            cloud.holdSavePushes();
            return;
          }
          _saveTail = _saveTail.then((_) => Storage.save(state, quests));
          if (!await _saveTail) {
            cloud.holdSavePushes();
            return;
          }
          final migratedRaw = await Storage.exportRaw();
          if (migratedRaw == null ||
              Storage.schemaOf(migratedRaw) != Storage.schema) {
            cloud.holdSavePushes();
            return;
          }
        }
        cloud.releaseSavePushes();
        cloud.push();
    }
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
              ({
                required bool forgeFirstGoal,
                required bool openGuide,
                required TimeShape timeShape,
              }) {
                _applyTimeShape(timeShape);
                _persist();
                e.remove();
                if (!mounted) return;
                setState(() {});
                unawaited(
                  _continueAfterOnboarding(
                    state: s,
                    forgeFirstGoal: forgeFirstGoal,
                    openGuide: openGuide,
                  ),
                );
              },
        ),
      );
      Overlay.of(context).insert(e);
    });
  }

  Future<void> _continueAfterOnboarding({
    required GameState state,
    required bool forgeFirstGoal,
    required bool openGuide,
  }) async {
    if (!mounted) return;
    if (forgeFirstGoal) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => GoalWizardScreen(state: state, onAdd: _addQuest),
        ),
      );
    } else if (openGuide) {
      await _openRoomGuide();
    }
    if (!mounted) return;
    _maybeWhatsNew();
    _maybeMorning();
    _maybeStartSessionIgnition();
  }

  Future<void> _openRoomGuide() async {
    final state = _state;
    if (!mounted || state == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RoomGuideScreen(
          state: state,
          onAddQuest: _addQuest,
          onPersist: _persist,
          onSelectTab: _selectTab,
        ),
      ),
    );
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

  /// A shipped build gets one calm release card. Eligibility is claimed in
  /// [_loadFromStorage] before this runs, so a crash or force-close while the
  /// card is visible cannot turn it into a repeat-launch trap.
  void _maybeWhatsNew() {
    if (!_startupSettled ||
        !_whatsNewPending ||
        _whatsNewOverlay != null ||
        _whatsNewCheckScheduled) {
      return;
    }
    _whatsNewCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _whatsNewCheckScheduled = false;
      final state = _state;
      if (!mounted ||
          !_startupSettled ||
          !_whatsNewPending ||
          state == null ||
          !state.onboarded ||
          _whatsNewOverlay != null ||
          _morningOverlay != null ||
          Navigator.of(context).canPop()) {
        return;
      }

      late final OverlayEntry entry;
      entry = OverlayEntry(
        builder: (_) => OverlaySurface(
          child: WhatsNewScreen(
            automatic: true,
            themeId: state.canvasTheme,
            reduceMotion: state.reduceMotion,
            onDismiss: _dismissWhatsNew,
          ),
        ),
      );
      _whatsNewPending = false;
      _whatsNewOverlay = entry;
      setState(() {});
      Overlay.of(context).insert(entry);
    });
  }

  void _dismissWhatsNew() {
    final entry = _whatsNewOverlay;
    if (entry == null) return;
    entry.remove();
    _whatsNewOverlay = null;
    if (mounted) setState(() {});
    _maybeMorning();
    _maybeStartSessionIgnition();
  }

  /// Auto-greet: last night was closed out, today hasn't been briefed.
  void _maybeMorning() {
    if (!_startupSettled ||
        _morningCheckScheduled ||
        _whatsNewPending ||
        _whatsNewOverlay != null ||
        _whatsNewCheckScheduled) {
      return;
    }
    _morningCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _morningCheckScheduled = false;
      final s = _state;
      final q = _quests;
      if (!mounted ||
          !_startupSettled ||
          s == null ||
          q == null ||
          _whatsNewPending ||
          _whatsNewOverlay != null ||
          _whatsNewCheckScheduled) {
        return;
      }
      if (!s.onboarded) return; // welcome first; morning can wait
      // [morningArmed] is persisted separately for old-save migration. Treat
      // today's completion stamp as authoritative if a restored/cloud copy
      // ever contains a stale armed bit.
      final alreadyCompleted = s.morningDoneDay == Days.key(Clock.now());
      if (alreadyCompleted || !s.morningPending || _morningOverlay != null) {
        return;
      }
      late final OverlayEntry e;
      e = OverlayEntry(
        builder: (_) => MorningFlow(
          state: s,
          quests: q,
          onDismiss: () {
            e.remove();
            _morningOverlay = null;
            if (mounted) setState(() {});
            _maybeStartSessionIgnition();
          },
          onClose: () {
            s.closeMorning(); // disarms the briefing
            _persist();
            e.remove();
            _morningOverlay = null;
            if (mounted) setState(() {});
            _maybeStartSessionIgnition();
          },
        ),
      );
      _morningOverlay = e;
      Overlay.of(context).insert(e);
    });
  }

  /// Starts the welcome flame only when the Quest room is genuinely on screen.
  /// Overlay flows and pushed routes defer it without consuming the session
  /// gate, so a first-run welcome or morning brief never steals the fwoosh.
  void _maybeStartSessionIgnition() {
    if (_ignitionCheckScheduled || _sessionIgnition.isClaimed) return;
    _ignitionCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ignitionCheckScheduled = false;
      if (!mounted) return;
      final state = _state;
      if (state == null) return;
      final questRoomVisible =
          _tab == 1 &&
          _visitedTabs.contains(1) &&
          Navigator.of(context).canPop() == false;
      if (!sessionIgnitionMayBegin(
            startupSettled: _startupSettled,
            onboarded: state.onboarded,
            questRoomVisible: questRoomVisible,
            whatsNewPending: _whatsNewPending,
            whatsNewVisible: _whatsNewOverlay != null,
            whatsNewCheckScheduled: _whatsNewCheckScheduled,
            morningVisible: _morningOverlay != null,
            morningCheckScheduled: _morningCheckScheduled,
          ) ||
          !_sessionIgnition.claim()) {
        return;
      }
      setState(() {
        _roomHearthLit = true;
        _roomIgniting = true;
      });
      Sfx.instance.play('fire_ignite');
      _ignitionClearTimer?.cancel();
      _ignitionClearTimer = Timer(const Duration(milliseconds: 900), () {
        _ignitionClearTimer = null;
        if (mounted) setState(() => _roomIgniting = false);
      });
    });
  }

  void _persist() => unawaited(_persistNow());

  Future<bool> _persistNow({bool push = true}) {
    final s = _state;
    final q = _quests;
    if (s != null && q != null) {
      s.lastModified = Clock.now().millisecondsSinceEpoch;
      Haptics.reduceMotion = s.reduceMotion;
      _saveTail = _saveTail.then((_) => Storage.save(s, q));
      final cloud = CloudSync.instance;
      _saveTail = _saveTail.then((saved) {
        if (!saved) {
          // A scheduled cloud push would read the previous blob and make it
          // look as though the latest local work had been mirrored.
          cloud.cancelPending();
          return false;
        }
        if (push) {
          cloud.push();
          final syncProfile =
              kVisitorProfileSharingEnabled && s.shareSpaceProfile;
          final publicProfile = syncProfile
              ? spaceProfileDisplay(s, audience: SpaceAudience.anyone)
              : const <String, dynamic>{};
          final mutualProfile = syncProfile
              ? spaceProfileDisplay(s, audience: SpaceAudience.mutuals)
              : const <String, dynamic>{};
          cloud.queueRoomUpdate(
            roomDisplay(
              s,
              mediaOwnerUid: cloud.socialUid,
              mediaRoomCode: s.roomCode,
            ),
            code: s.roomCode,
            discoverable: kSpaceDiscoveryEnabled && s.roomDiscoverable,
            syncSpaceProfile: syncProfile,
            publicProfile: publicProfile.isEmpty ? null : publicProfile,
            mutualProfile: mutualProfile.isEmpty ? null : mutualProfile,
          );
        }
        return true;
      });
    }
    return _saveTail;
  }

  /// Copies the raw save to the clipboard for a user-held backup.
  Future<bool> _export() async {
    if (!await _persistNow()) return false; // make sure the blob is current
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
    // Starts at its Fogg-floor rung (20 minutes) and climbs to the full hour
    // — the hint used to advertise a ladder that was never attached, and d8
    // for a 20-minute session paid like a full one.
    Quest(
      title: 'Workout — full session',
      stat: Stat.str,
      difficulty: 4,
      rising: true,
      ladder: Ladders.byBaseTitle['Workout — full session'],
      ladderHint: 'CLIMBS AS YOU GROW 📈',
    ),
    Quest(
      title: 'No caffeine after 2pm',
      stat: Stat.vit,
      difficulty: 7,
      dread: true,
      allDay: true,
    ),
  ];

  Future<String?> _reset() async {
    final old = _state;
    if (old == null) return 'Your room is still loading — try again.';
    final oldRoomCode = old.roomCode;
    CloudSync.instance.cancelPending(); // drop any stale pre-reset push

    // Confirm local privacy cleanup before presenting a fresh room. In
    // particular, do not fire-and-forget journal deletion: a process kill just
    // after the tap must not leave old photos behind while the UI says reset.
    if (!await media.clearAll()) {
      return 'Couldn’t confirm that journal photos were erased. Your progress '
          'was left in place; try again.';
    }
    final localMetadataCleared = await Future.wait([
      Storage.clearUsage(),
      Storage.clearCorruptBackup(),
    ]);
    if (localMetadataCleared.any((cleared) => !cleared)) {
      return 'Couldn’t finish erasing local Room of Days data. Your progress '
          'was left in place; try again.';
    }

    final fresh = GameState()..rollover([]);
    final freshQuests = _buildQuests();
    fresh.lastModified = Clock.now().millisecondsSinceEpoch;
    // Serialize behind every older write so a slow pre-reset save can never
    // land after this blank one and resurrect the erased room on relaunch.
    _saveTail = _saveTail.then((_) => Storage.save(fresh, freshQuests));
    if (!await _saveTail) {
      return 'Couldn’t save the blank room on this device. Try again before '
          'closing the app.';
    }
    // A pre-reset save tail may have scheduled a cloud write after the first
    // cancellation. Stop it again now that the blank local save is authoritative.
    CloudSync.instance.cancelPending();

    await Notifications.cancelAll();
    old.removeListener(_persist);
    fresh.addListener(_persist);
    setState(() {
      _state = fresh;
      _quests = freshQuests;
    });
    _maybeOnboard();
    // Erase the cloud copy and published room too. Guest profiles also delete
    // their anonymous Firebase identity before a fresh one is created, so a
    // reset cannot leave an unreachable backend account behind.
    unawaited(_finishResetRemoteCleanup(oldRoomCode));
    return null;
  }

  Future<void> _finishResetRemoteCleanup(String? oldRoomCode) async {
    final fullyErased = await CloudSync.instance.resetProfile(
      roomCode: oldRoomCode,
    );
    _persist();
    if (!mounted || fullyErased) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.showSnackBar(
        const SnackBar(
          content: Text(
            'Your new room is ready, but the old shared room could not be confirmed removed. Keep the app online so it can retry.',
          ),
        ),
      );
    });
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
        final mergedIds = {for (final note in state.journal) note.id};
        if (mergedIds.contains(live.nightDraftNoteId)) {
          state.nightDraftNoteId = live.nightDraftNoteId;
        }
        if (mergedIds.contains(live.pendingMorningNoteId)) {
          state.pendingMorningNoteId = live.pendingMorningNoteId;
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

  Future<String?> _enableCloud() {
    final active = _enableCloudFuture;
    if (active != null) return active;
    final attempt = _enableCloudGuarded();
    _enableCloudFuture = attempt;
    return attempt;
  }

  Future<String?> _enableCloudGuarded() async {
    try {
      return await _enableCloudOnce();
    } finally {
      _enableCloudFuture = null;
    }
  }

  Future<String?> _enableCloudOnce() async {
    final error = await CloudSync.instance.enable();
    if (error != null) return error;
    if (!await _persistNow(push: false)) {
      return 'Cloud is on, but your current changes could not be saved on this device. Free some storage, then try again.';
    }
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
      CloudSync.instance.releaseSavePushes();
      CloudSync.instance.push(); // doc confirmed absent → push first save
    } else if (!Storage.isValidSave(cloudRaw) ||
        Storage.schemaOf(cloudRaw) > Storage.schema ||
        !await Storage.importRaw(cloudRaw)) {
      await CloudSync.instance.signOut(saveAccount: false);
      if (mounted) setState(() {});
      return 'That account save needs a newer Room of Days build or is damaged. '
          'Nothing was overwritten.';
    } else {
      await _loadFromStorage(); // adopt the account's keep and progress
      CloudSync.instance.releaseSavePushes();
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
    final signedOut = await CloudSync.instance.signOut();
    if (!signedOut) {
      _showSocialNotice(
        'Your shared room is still being removed. Stay online and try '
        'signing out again.',
      );
      return;
    }
    _state?.setRoomCode(null);
    _persist();
    if (mounted) setState(() {});
  }

  Future<String?> _deleteAccount(String password) async {
    final s = _state;
    if (s == null) return 'Your space is still loading — try again.';
    final error = await CloudSync.instance.deleteAccount(
      password,
      roomCode: s.roomCode,
    );
    if (error != null) return error;
    s.removeListener(_persist);
    CloudSync.instance.cancelPending();
    await Notifications.cancelAll();
    final localCleanup = await Future.wait([
      Storage.clear(),
      Storage.clearCorruptBackup(),
      Storage.clearUsage(),
      media.clearAll(),
    ]);
    final fresh = GameState()..rollover([]);
    fresh.addListener(_persist);
    if (!mounted) return null;
    setState(() {
      _state = fresh;
      _quests = _buildQuests();
    });
    final blankSaved = await _persistNow(push: false);
    _maybeOnboard();
    if (localCleanup.any((cleared) => !cleared) || !blankSaved) {
      _showSocialNotice(
        'Your account is gone and backup is off, but this device could not '
        'confirm every local file was erased. Keep the app installed and try '
        'Start over once more.',
      );
    }
    return null;
  }

  Future<String?> _removePrivateServiceIdentity() async {
    final s = _state;
    if (s == null) return 'Your space is still loading — try again.';
    final error = await PlaceSearchIdentityRemoval(
      preferences: LocalDaybookPreferences(),
      remote: CloudSync.instance,
      prepareSecureRemoval: () async {
        if (!await CloudSync.instance.ensureCoreAvailable()) return false;
        return FirebasePlaceSearchAppCheck().activate();
      },
    ).remove(roomCode: s.roomCode);
    if (error != null) return error;

    // The remote room is gone with its anonymous owner, so forget only that
    // obsolete bearer code. Daybook, progress, preferences, and local media
    // remain untouched.
    if (s.roomCode != null) {
      s.setRoomCode(null);
      _persist();
    }
    if (mounted) setState(() {});
    return null;
  }

  Future<String?> _withdrawPlaceSearchConsent() async {
    final access = PlaceSearchAccess.production(
      requestConsent: () async => PlaceSearchConsentDecision.decline,
    );
    if (await access.withdrawConsent()) return null;
    return 'Couldn’t turn off place search on this device. Try again.';
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
    setState(() {
      quests.add(q);
      // A deliberate re-take supersedes the old "don't restore this default"
      // marker. Removing it again will add the marker back normally.
      _state?.removedDefaults.remove(key);
    });
    _persist();
    // a new dated plan should get its reminder right away (native-only)
    if (q.isEvent && (_state?.notifyEnabled ?? false)) {
      _rescheduleNotifications();
    }
    return true;
  }

  void _openGuidedWorkouts() {
    final quests = _quests;
    if (quests == null) return;
    Quest? launcher;
    for (final quest in quests) {
      if (quest.workout) {
        launcher = quest;
        break;
      }
    }
    if (launcher == null) {
      final fresh = workoutLauncherQuest();
      _addQuest(fresh);
      launcher = fresh;
    }
    _selectTab(1);
    final chosen = launcher;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _openGuidedWorkout?.call(chosen);
    });
  }

  /// (Re)schedule local reminders from the current prefs + dated plans.
  /// No-ops on web (the native plugin isn't compiled there).
  Future<void> _rescheduleNotifications({bool refreshTimeZone = false}) {
    _notificationSchedule = _notificationSchedule.then(
      (_) => _rescheduleNotificationsNow(refreshTimeZone: refreshTimeZone),
    );
    return _notificationSchedule;
  }

  Future<void> _rescheduleNotificationsNow({
    required bool refreshTimeZone,
  }) async {
    final s = _state;
    final q = _quests;
    if (s == null || q == null) return;
    if (refreshTimeZone) await Notifications.refreshTimeZone();
    // Restores and system-settings changes can leave a persisted switch on
    // after notification delivery has become impossible. Verify silently:
    // only the explicit switches in Me are allowed to request permission.
    if (Notifications.isSupported &&
        (s.notifyEnabled || s.nightReminderEnabled)) {
      final permission = await Notifications.permissionStatus();
      if (permission == ReminderPermissionStatus.denied) {
        s.disableRemindersWithoutPermission();
      }
    }
    final now = Clock.now();
    if (s.notifyEnabled) {
      await Notifications.scheduleDailyNudge(s.notifyHour, s.notifyMinute);
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
    } else {
      await Notifications.cancelDailyNudge();
      await Notifications.cancelEvents();
    }
    if (s.nightReminderEnabled) {
      await Notifications.scheduleNightRoutine(
        s.nightReminderHour,
        s.nightReminderMinute,
        skipNext: shouldSuppressNextNightReminder(
          now: now,
          hour: s.nightReminderHour,
          minute: s.nightReminderMinute,
          nightDoneDay: s.nightDoneDay,
        ),
      );
    } else {
      await Notifications.cancelNightRoutine();
    }
  }

  void _selectTab(int i) {
    if (i == _tab) return;
    // The dock owns pointer-down sound/haptic feedback so acknowledgement is
    // immediate instead of waiting for the gesture arena. Build a destination
    // only on its first visit; keeping five illustrated pages alive from frame
    // one decoded tens of megabytes the person had not asked to see yet.
    Sfx.instance.setInteractionScreen(_soundTabScopes[i]);
    setState(() {
      _visitedTabs.add(i);
      _tab = i;
    });
    if (i == 1) _maybeStartSessionIgnition();
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
    _luxeMotion.setReduceMotion(
      state.reduceMotion ||
          (MediaQuery.maybeDisableAnimationsOf(context) ?? false),
    );
    const parkedMotion = AlwaysStoppedAnimation<Offset>(Offset.zero);
    ValueListenable<Offset> cameraFor(int index) =>
        _tab == index ? _luxeMotion.parallax : parkedMotion;
    ValueListenable<Offset> lightFor(int index) =>
        _tab == index ? _luxeMotion.light : parkedMotion;
    // Hide the shell as soon as an eligible release has been claimed, not one
    // frame later when the OverlayEntry is inserted. That closes the brief
    // screen-reader/focus window between the post-frame check and the modal.
    final releaseOverlayVisible =
        _whatsNewPending || _whatsNewOverlay != null || _whatsNewCheckScheduled;
    final soundRootRoute = ModalRoute.of(context);

    // Only the canvas listens to the notifier (theme swaps recolor it live);
    // the Scaffold subtree is passed as `child` and not rebuilt on every notify.
    return ListenableBuilder(
      listenable: state,
      builder: (context, child) {
        _luxeMotion.setReduceMotion(
          state.reduceMotion ||
              (MediaQuery.maybeDisableAnimationsOf(context) ?? false),
        );
        return WarmBackground(
          themeId: state.canvasTheme,
          reduceMotion: state.reduceMotion,
          child: child!,
        );
      },
      // Onboarding is a full-screen OverlayEntry rather than a Navigator route.
      // Without an explicit boundary, screen readers and hardware-keyboard
      // focus can still reach the fully built Quest board underneath it.
      child: ExcludeSemantics(
        excluding: !state.onboarded || releaseOverlayVisible,
        child: ExcludeFocus(
          excluding: !state.onboarded || releaseOverlayVisible,
          child: AbsorbPointer(
            absorbing: !state.onboarded || releaseOverlayVisible,
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: LayoutBuilder(
                builder: (context, bounds) => MouseRegion(
                  onHover: (event) =>
                      _luxeMotion.handlePointer(event, bounds.biggest),
                  onExit: _luxeMotion.clearPointer,
                  child: Listener(
                    behavior: HitTestBehavior.translucent,
                    // iPhone browsers only unlock device orientation from a genuine
                    // touch. Calling here keeps the request in that first gesture;
                    // native builds and browsers without the gate simply no-op.
                    onPointerDown: (_) {
                      if (!state.reduceMotion) {
                        unawaited(_luxeMotion.requestBrowserMotionPermission());
                      }
                    },
                    child: SafeArea(
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
                                  _visitedTabs.contains(0)
                                      ? MePage(
                                          state: state,
                                          quests: quests,
                                          onPersist: _persist,
                                          onPublishRoom: _publishSpaceRoom,
                                          onAddQuest: _addQuest,
                                          onExport: _export,
                                          onImport: _import,
                                          onReset: _reset,
                                          onNotifyChanged:
                                              _rescheduleNotifications,
                                          onEnableCloud: _enableCloud,
                                          onLinkAccount: _linkAccount,
                                          onSignIn: _signIn,
                                          onSignOut: _signOut,
                                          onDeleteAccount: _deleteAccount,
                                          onRemovePrivateServiceIdentity:
                                              _removePrivateServiceIdentity,
                                          onWithdrawPlaceSearchConsent:
                                              _withdrawPlaceSearchConsent,
                                          cloudAccountView: CloudSync.instance,
                                          onSelectTab: _selectTab,
                                          parallax: cameraFor(0),
                                        )
                                      : const SizedBox.shrink(),
                                  _visitedTabs.contains(1)
                                      ? QuestsPage(
                                          state: state,
                                          quests: quests,
                                          onRefresh: _refreshQuests,
                                          onPersist: _persist,
                                          onAdd: _addQuest,
                                          onRemove: _removeQuest,
                                          onSnapshot: _captureSnapshot,
                                          onRestore: _restoreSnapshot,
                                          onBindFlush: (flush) =>
                                              _flushQuestsCommit = flush,
                                          onBindComplete: (complete) =>
                                              _completeQuest = complete,
                                          onBindOpenWorkout: (open) =>
                                              _openGuidedWorkout = open,
                                          onNightClosed: () => unawaited(
                                            _rescheduleNotifications(),
                                          ),
                                          parallax: cameraFor(1),
                                          lightDirection: lightFor(1),
                                          roomIgniting: _roomIgniting,
                                          roomHearthLit: _roomHearthLit,
                                        )
                                      : const SizedBox.shrink(),
                                  _visitedTabs.contains(2)
                                      ? GoalsPage(
                                          state: state,
                                          onAdd: _addQuest,
                                          onRemoveQuest: _removeQuest,
                                          onRemoveGoal: _removeGoal,
                                          onPersist: _persist,
                                          quests: quests,
                                          onOpenQuests: () => _selectTab(1),
                                          onOpenGuidedWorkouts:
                                              _openGuidedWorkouts,
                                          parallax: cameraFor(2),
                                          lightDirection: lightFor(2),
                                        )
                                      : const SizedBox.shrink(),
                                  _visitedTabs.contains(3)
                                      ? CalendarPage(
                                          state: state,
                                          quests: quests,
                                          onAdd: _addQuest,
                                          onCompleteQuest: (quest, anchor) =>
                                              _completeQuest?.call(
                                                quest,
                                                anchor,
                                              ),
                                          parallax: cameraFor(3),
                                          lightDirection: lightFor(3),
                                        )
                                      : const SizedBox.shrink(),
                                  _visitedTabs.contains(4)
                                      ? InsightsPage(
                                          state: state,
                                          quests: quests,
                                          onPersist: _persist,
                                          parallax: cameraFor(4),
                                          lightDirection: lightFor(4),
                                        )
                                      : const SizedBox.shrink(),
                                ].indexed)
                                  InteractionSoundScreenScope(
                                    id: _soundTabScopes[i],
                                    sourceRoute: soundRootRoute,
                                    child: TickerMode(
                                      enabled: _tab == i,
                                      child: page,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          // Content passes UNDER the dock, so without this it was
                          // guillotined mid-glyph on every page long enough to scroll —
                          // a section header sliced in half at the dock's hard top
                          // edge. A short warm fade turns that cut into depth.
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 88 + MediaQuery.paddingOf(context).bottom,
                            height: 34,
                            child: const IgnorePointer(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Color(0x0017120F),
                                      Color(0xE617120F),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // The board owns the scene; navigation is one anchored dark
                          // rail, not another floating glass object competing with it.
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: _BottomDock(
                              selected: _tab,
                              questAccent: activeQuestDeskLook(state).brass,
                              bottomInset: MediaQuery.paddingOf(context).bottom,
                              onSelect: _selectTab,
                            ),
                          ),
                        ],
                      ),
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
}

class _BottomDock extends StatelessWidget {
  const _BottomDock({
    required this.selected,
    required this.questAccent,
    required this.bottomInset,
    required this.onSelect,
  });

  final int selected;
  final Color questAccent;
  final double bottomInset;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 88 + bottomInset,
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Color(0xFA17120F),
        border: Border(top: BorderSide(color: Color(0xFF654526), width: 1)),
        boxShadow: [
          BoxShadow(
            color: Color(0xC0000000),
            blurRadius: 24,
            offset: Offset(0, -7),
          ),
          BoxShadow(
            color: Color(0x2AAF721E),
            blurRadius: 18,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _DockItem(
              icon: Icons.emoji_emotions_outlined,
              label: 'ME',
              selected: selected == 0,
              onTap: () => onSelect(0),
            ),
          ),
          Expanded(
            child: _DockItem(
              icon: Icons.task_alt,
              label: 'QUESTS',
              selected: selected == 1,
              accent: questAccent,
              onTap: () => onSelect(1),
            ),
          ),
          Expanded(
            child: _DockItem(
              icon: Icons.explore_outlined,
              label: 'GOALS',
              selected: selected == 2,
              onTap: () => onSelect(2),
            ),
          ),
          Expanded(
            child: _DockItem(
              icon: Icons.calendar_month_outlined,
              label: 'PLANS',
              selected: selected == 3,
              onTap: () => onSelect(3),
            ),
          ),
          Expanded(
            child: _DockItem(
              icon: Icons.menu_book_outlined,
              label: 'JOURNAL',
              selected: selected == 4,
              onTap: () => onSelect(4),
            ),
          ),
        ],
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
    this.accent,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final selectedAccent = accent ?? const Color(0xFFC49C6C);
    return Semantics(
      container: true,
      selected: selected,
      child: Pressable(
        pressDepth: 2,
        // travel between the five pages of the room: the parchment flip lane
        // (falls back to the navigate clasp until the page masters ship)
        material: MaterialSound.parchment,
        // A selected tab still bobs, so it gets the quieter contact at the
        // same instant. Actual travel keeps the fuller navigate weight.
        interactionSound: selected
            ? InteractionSound.select
            : InteractionSound.navigate,
        edgeColor: Colors.transparent,
        semanticLabel: '$label tab',
        onTapUp: (_) => onTap(),
        child: AnimatedContainer(
          duration: Motion.quick,
          curve: Motion.respond,
          constraints: const BoxConstraints(minHeight: 88),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          // The selected tab used to invert to a near-white honey slab with dark
          // ink on it, which made the navigation the single brightest object in
          // the app — brighter than the hearth. Selection now reads as a warm
          // lit tab with honey ink, so the top of the value range goes back to
          // the fire and the one primary action.
          decoration: facetedDecoration(
            cut: 11,
            gradient: selected
                ? LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      selectedAccent.withValues(alpha: 0.21),
                      const Color(0xFF221A14),
                    ],
                  )
                : null,
            borderColor: selected
                ? selectedAccent.withValues(alpha: 0.52)
                : Colors.transparent,
            shadows: selected
                ? [
                    BoxShadow(
                      color: selectedAccent.withValues(alpha: 0.14),
                      blurRadius: 12,
                      offset: const Offset(0, -2),
                    ),
                  ]
                : const [],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // The lit tab is cut stone like everything else in the keep — a
              // circular bubble here was the one rounded shape in the faceted
              // system, and its near-white ring outshone the hearth. The ring
              // now stays inside the accent's own value range.
              Container(
                width: 31,
                height: 31,
                alignment: Alignment.center,
                decoration: facetedDecoration(
                  cut: 7,
                  color: selected
                      ? selectedAccent.withValues(alpha: 0.90)
                      : Colors.transparent,
                  borderColor: selected
                      ? selectedAccent.withValues(alpha: 0.75)
                      : Colors.transparent,
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: selected ? const Color(0xFF3A210E) : Palette.textLo,
                ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  // Floor-size labels (Type.minLabel); the FittedBox above is
                  // the escape valve for 320dp-class screens, not a licence to
                  // author below the floor.
                  style: Type.label.copyWith(
                    fontSize: Type.minLabel,
                    letterSpacing: 0.8,
                    color: selected ? Palette.xpLight : Palette.textLo,
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
