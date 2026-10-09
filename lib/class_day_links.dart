/// Links into the class day from outside the app.
///
/// The Day Ledger home-screen widget opens the app with one of three URLs on
/// the app's own `roomofdays` scheme:
///
/// * `roomofdays://class-day` opens the Quests tab on the class day.
/// * `roomofdays://class-day/mark?occurrence=<key>&day=<dayKey>` does the
///   same and, when that class could be kept at the moment of the tap, keeps
///   it with the same keep and celebration a tap on the board's I WAS THERE
///   plays.
/// * `roomofdays://class-day/mark-all?day=<dayKey>` does the same for every
///   class of that day that had ended, unmarked, by the tap: the board's
///   "I went to all of today's classes", one keep and one celebration.
///
/// Two small queues carry a link from the platform to the board:
///
/// 1. [ClassDayLinkInbox]: the app boundary (main.dart) accepts the raw link
///    as soon as the platform delivers it, cold or warm, and stamps the
///    moment. The shell drains it once the save and the timetable are
///    loaded, routes to the Quests tab and runs `GameState.checkClassKeep`
///    for the moment of the tap.
/// 2. [ClassDayBoardSeam]: once the Quest room is on screen, the shell hands
///    the board a [ClassDayBoardRequest]. The board ([ClassDayLinkTarget],
///    implemented by the Quests page) attaches when it mounts and receives
///    each request exactly once, in order, after the frame it attached in.
///
/// Nothing here keeps a class or touches the save. The board owns the keep,
/// the undo slot and the celebration, so a widget mark can never differ from
/// a mark made on the board.
///
/// The widget only offers a mark control while a board that keeps from links
/// is attached ([ClassDayLinkTarget.marksClassesFromLinks]). Until then the
/// snapshot carries no mark links and every tap only opens the class day, so
/// the home screen never shows a control that does nothing.
library;

import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import 'clock.dart';
import 'models.dart' show Days;

/// The app's own URL scheme (ios/Runner/Info.plist, CFBundleURLSchemes).
const String classDayLinkScheme = 'roomofdays';

/// The host (or first path segment) every class-day link names.
const String classDayLinkHost = 'class-day';

/// The longest occurrence key a link may carry (the engine's own limit in
/// `GameState.checkClassKeep`).
const int classDayLinkMaxKeyLength = 200;

enum ClassDayLinkKind {
  /// Open the Quests tab on the class day.
  open,

  /// Open it and keep one class, when that class can be kept.
  mark,

  /// Open it and keep every class of one day that had ended, unmarked.
  markAll,
}

/// One parsed class-day link.
@immutable
final class ClassDayLink {
  const ClassDayLink.open()
    : kind = ClassDayLinkKind.open,
      occurrenceKey = null,
      dayKey = null;

  const ClassDayLink.mark({
    required String this.occurrenceKey,
    required String this.dayKey,
  }) : kind = ClassDayLinkKind.mark;

  const ClassDayLink.markAll({required String this.dayKey})
    : kind = ClassDayLinkKind.markAll,
      occurrenceKey = null;

  final ClassDayLinkKind kind;

  /// The timetable occurrence to keep (mark links only).
  final String? occurrenceKey;

  /// The class's own civil day in `Days.key` form (mark and mark-all links).
  final String? dayKey;

  bool get isMark => kind == ClassDayLinkKind.mark;

  bool get isMarkAll => kind == ClassDayLinkKind.markAll;

  /// `roomofdays://class-day`,
  /// `roomofdays://class-day/mark?occurrence=<key>&day=<dayKey>` or
  /// `roomofdays://class-day/mark-all?day=<dayKey>`.
  Uri toUri() => switch (kind) {
    ClassDayLinkKind.open => Uri(
      scheme: classDayLinkScheme,
      host: classDayLinkHost,
    ),
    ClassDayLinkKind.mark => Uri(
      scheme: classDayLinkScheme,
      host: classDayLinkHost,
      path: '/mark',
      queryParameters: {'occurrence': occurrenceKey!, 'day': dayKey!},
    ),
    ClassDayLinkKind.markAll => Uri(
      scheme: classDayLinkScheme,
      host: classDayLinkHost,
      path: '/mark-all',
      queryParameters: {'day': dayKey!},
    ),
  };

  /// Parses a class-day link, or returns null for anything else.
  ///
  /// Accepts the custom scheme (`roomofdays://class-day/...`) and, so a
  /// future universal link needs no second parser, a path form whose first
  /// segment is `class-day` (`/class-day/mark?...`, bare or on
  /// roomofdays.com). A mark link with a missing or malformed key or day is
  /// still a class-day link: it opens the class day without keeping
  /// anything, so a tap is never ignored.
  static ClassDayLink? fromUri(Uri uri) {
    final List<String> rest;
    final scheme = uri.scheme.toLowerCase();
    if (scheme == classDayLinkScheme) {
      if (uri.host.toLowerCase() == classDayLinkHost) {
        rest = uri.pathSegments;
      } else if (uri.host.isEmpty &&
          uri.pathSegments.isNotEmpty &&
          uri.pathSegments.first.toLowerCase() == classDayLinkHost) {
        rest = uri.pathSegments.sublist(1);
      } else {
        return null;
      }
    } else if (scheme.isEmpty ||
        ((scheme == 'https' || scheme == 'http') &&
            const {
              'roomofdays.com',
              'www.roomofdays.com',
            }.contains(uri.host.toLowerCase()))) {
      if (uri.pathSegments.isEmpty ||
          uri.pathSegments.first.toLowerCase() != classDayLinkHost) {
        return null;
      }
      rest = uri.pathSegments.sublist(1);
    } else {
      return null;
    }
    final action = rest.where((segment) => segment.isNotEmpty).toList();
    if (action.length != 1) return const ClassDayLink.open();
    final day = Days.validKey(uri.queryParameters['day']?.trim());
    switch (action.single.toLowerCase()) {
      case 'mark':
        final key = uri.queryParameters['occurrence']?.trim() ?? '';
        if (key.isEmpty ||
            key.length > classDayLinkMaxKeyLength ||
            day == null) {
          return const ClassDayLink.open();
        }
        return ClassDayLink.mark(occurrenceKey: key, dayKey: day);
      case 'mark-all':
        if (day == null) return const ClassDayLink.open();
        return ClassDayLink.markAll(dayKey: day);
      default:
        return const ClassDayLink.open();
    }
  }

  @override
  bool operator ==(Object other) =>
      other is ClassDayLink &&
      other.kind == kind &&
      other.occurrenceKey == occurrenceKey &&
      other.dayKey == dayKey;

  @override
  int get hashCode => Object.hash(kind, occurrenceKey, dayKey);

  @override
  String toString() => toUri().toString();
}

/// The mark link for one class, as the widget snapshot publishes it.
String classDayMarkUrl(String occurrenceKey, String dayKey) =>
    ClassDayLink.mark(
      occurrenceKey: occurrenceKey,
      dayKey: dayKey,
    ).toUri().toString();

/// The mark-all link for one class day, as the widget snapshot publishes it.
String classDayMarkAllUrl(String dayKey) =>
    ClassDayLink.markAll(dayKey: dayKey).toUri().toString();

/// The plain open link.
final String classDayOpenUrl = const ClassDayLink.open().toUri().toString();

/// One accepted delivery, stamped when it arrived.
@immutable
final class ClassDayLinkEvent {
  const ClassDayLinkEvent({
    required this.link,
    required this.receivedAt,
    required this.sequence,
  });

  final ClassDayLink link;

  /// [Clock.now] when the platform delivered the link: the moment of the
  /// tap, give or take an app launch. A mark is judged by it, never by when
  /// the shell got round to it, so a tap just before 04:00 still counts.
  final DateTime receivedAt;

  /// Makes two taps on the same link two events.
  final int sequence;
}

/// A small FIFO between the platform route channel and the loaded shell, the
/// class-day sibling of `RoomLinkInbox` (social.dart).
///
/// iOS delivers a widget link as a route event just after a cold start, or at
/// any moment while the app runs. Holding it here means neither case races
/// the save load, the timetable load or the cloud handshake.
class ClassDayLinkInbox extends ChangeNotifier {
  /// At most this many links wait; older ones give way. A burst of taps is
  /// one intent, and every mark is checked again when it is taken.
  static const maxPending = 8;

  final Queue<ClassDayLinkEvent> _pending = Queue<ClassDayLinkEvent>();
  var _sequence = 0;

  bool get isNotEmpty => _pending.isNotEmpty;

  /// Accepts [uri] when it is a class-day link.
  bool enqueueUri(Uri uri) {
    final link = ClassDayLink.fromUri(uri);
    return link != null && enqueue(link);
  }

  bool enqueue(ClassDayLink link) {
    while (_pending.length >= maxPending) {
      _pending.removeFirst();
    }
    _pending.add(
      ClassDayLinkEvent(
        link: link,
        receivedAt: Clock.now(),
        sequence: ++_sequence,
      ),
    );
    notifyListeners();
    return true;
  }

  ClassDayLinkEvent? takeNext() =>
      _pending.isEmpty ? null : _pending.removeFirst();

  @override
  void dispose() {
    _pending.clear();
    super.dispose();
  }
}

/// What the shell asks of the board.
@immutable
final class ClassDayBoardRequest {
  const ClassDayBoardRequest.open({
    required this.requestedAt,
    this.sequence = 0,
  }) : occurrenceKeys = const [],
       dayKey = null;

  /// One class the shell checked as open (`ClassKeepCheck.open`) for the
  /// moment of the tap.
  ClassDayBoardRequest.mark({
    required String occurrenceKey,
    required String this.dayKey,
    required this.requestedAt,
    this.sequence = 0,
  }) : occurrenceKeys = List.unmodifiable([occurrenceKey]);

  /// Two or more classes of one day, each checked as open for the moment of
  /// the tap: one keep, one celebration.
  ClassDayBoardRequest.markAll({
    required List<String> occurrenceKeys,
    required String this.dayKey,
    required this.requestedAt,
    this.sequence = 0,
  }) : occurrenceKeys = List.unmodifiable(occurrenceKeys);

  /// The classes to keep, in time order. Empty for an open request.
  final List<String> occurrenceKeys;
  final String? dayKey;

  /// When the link was tapped. The board passes it on as the keep's `at`.
  final DateTime requestedAt;
  final int sequence;

  /// The one class of a single mark.
  String? get occurrenceKey =>
      occurrenceKeys.length == 1 ? occurrenceKeys.single : null;

  bool get isMark => dayKey != null && occurrenceKeys.length == 1;

  bool get isMarkAll => dayKey != null && occurrenceKeys.length > 1;

  ClassDayBoardRequest _numbered(int number) {
    final day = dayKey;
    if (day == null || occurrenceKeys.isEmpty) {
      return ClassDayBoardRequest.open(
        requestedAt: requestedAt,
        sequence: number,
      );
    }
    return ClassDayBoardRequest.markAll(
      occurrenceKeys: occurrenceKeys,
      dayKey: day,
      requestedAt: requestedAt,
      sequence: number,
    );
  }
}

/// The board's side of the seam. The Quests page state mixes this in (or
/// implements it), attaches itself to [ClassDayBoardSeam.instance] when it
/// mounts (initState is fine: delivery waits for the end of that frame) and
/// detaches in dispose.
///
/// The defaults do nothing, so a board that has not wired the class day yet
/// still compiles and simply leaves the Quests tab as it is.
///
/// The shell hands a request over only while the Quest room is on screen (no
/// route pushed over it, no morning briefing or What's New), so the keep and
/// its celebration are always seen.
abstract mixin class ClassDayLinkTarget {
  /// True once [markClassFromLink] and [markClassesFromLink] really keep and
  /// celebrate. The widget publishes its I WAS THERE controls only while an
  /// attached board says so; before that every widget tap only opens the
  /// class day.
  bool get marksClassesFromLinks => false;

  /// Show the class-day frame (the room with today's classes) rather than
  /// the full board. Called for every request, before a mark.
  void showClassDay() {}

  /// Keep this class exactly as the board's I WAS THERE does: the same
  /// commit flush, `RewardUndoSlot`, `GameState.keepClass` (pass [at] on as
  /// its `at`: the moment of the tap), sound, haptic and celebration tier.
  /// Returns whether a class was kept. The shell already ran
  /// `checkClassKeep` for [at]; check again here, since the state may have
  /// moved on.
  ///
  /// Complete the future when the celebration has closed and so has any
  /// level-up moment it chains into. The next request waits for it, so two
  /// widget marks play as two celebrations and a level-up is never cut short
  /// or stacked under the next mark's; if the board is disposed first,
  /// [ClassDayBoardSeam.detach] releases the seam.
  Future<bool> markClassFromLink(
    String occurrenceKey,
    String dayKey, {
    DateTime? at,
  }) async => false;

  /// Keep every one of these classes together, exactly as the board's "I
  /// went to all of today's classes" does: one keep pass, one celebration.
  /// Same [at] and completion rules as [markClassFromLink].
  Future<bool> markClassesFromLink(
    List<String> occurrenceKeys,
    String dayKey, {
    DateTime? at,
  }) async => false;
}

/// One request in the queue, stamped when it was queued.
final class _Queued {
  const _Queued(this.request, this.queuedAt);

  final ClassDayBoardRequest request;
  final DateTime queuedAt;
}

/// The pending-request queue between the shell and the board.
///
/// Requests wait until a target is attached, then each is delivered exactly
/// once, in order, one at a time (a mark's future completes before the next
/// request is handed over, so two quick marks play as two celebrations).
/// Delivery always waits for the current frame to finish, so a board that
/// attaches in initState never keeps a class in the middle of a build. A
/// request that waited longer than [maxWait] with no board free to take it
/// is dropped: a celebration hours after the tap would be out of place.
class ClassDayBoardSeam {
  ClassDayBoardSeam();

  /// The app's one seam. The shell requests on it; the Quests page attaches.
  static final ClassDayBoardSeam instance = ClassDayBoardSeam();

  /// At most this many requests wait for a board; older ones give way.
  static const maxPending = 8;

  /// The longest a request waits for a board that can take it.
  static const maxWait = Duration(minutes: 1);

  final Queue<_Queued> _pending = Queue<_Queued>();
  final List<ClassDayBoardRequest> _received = [];
  final ValueNotifier<bool> _boardMarks = ValueNotifier<bool>(false);
  ClassDayLinkTarget? _target;

  /// Changes whenever the attached board changes. A delivery loop belongs to
  /// one generation and stops once it is stale, so a board disposed in the
  /// middle of a celebration can never hold the seam.
  var _generation = 0;
  bool _draining = false;
  bool _drainScheduled = false;
  var _sequence = 0;

  /// When the last delivery finished: a request queued behind a long
  /// celebration only starts waiting from then.
  DateTime? _lastDeliveryEnded;

  /// Requests not yet delivered, oldest first.
  List<ClassDayBoardRequest> get pending => [
    for (final queued in _pending) queued.request,
  ];

  /// Every request the shell handed over since the last [debugReset],
  /// delivered or not, oldest first (at most 32).
  @visibleForTesting
  List<ClassDayBoardRequest> get debugReceived => List.unmodifiable(_received);

  bool get hasTarget => _target != null;

  /// Whether the board that last attached keeps classes from links
  /// ([ClassDayLinkTarget.marksClassesFromLinks]). The widget snapshot
  /// publishes mark links only while this is true.
  ValueListenable<bool> get boardMarksClasses => _boardMarks;

  /// Queues [request]; an attached board gets it after the current frame.
  void request(ClassDayBoardRequest request) {
    while (_pending.length >= maxPending) {
      _pending.removeFirst();
    }
    final numbered = request._numbered(++_sequence);
    _received.add(numbered);
    if (_received.length > 32) _received.removeAt(0);
    _pending.add(_Queued(numbered, Clock.now()));
    _scheduleDrain();
  }

  /// The board calls this when it mounts. Anything waiting is delivered once
  /// the current frame is done.
  void attach(ClassDayLinkTarget target) {
    if (!identical(_target, target)) {
      _target = target;
      _generation++;
      _draining = false;
    }
    _boardMarks.value = target.marksClassesFromLinks;
    _scheduleDrain();
  }

  /// The board calls this in dispose. Undelivered requests keep waiting for
  /// the next board, and a mark still in flight no longer holds the queue.
  void detach(ClassDayLinkTarget target) {
    if (!identical(_target, target)) return;
    _target = null;
    _generation++;
    _draining = false;
  }

  /// Delivery runs in a microtask: after the build, layout and paint of the
  /// frame that queued or attached, never inside it.
  void _scheduleDrain() {
    if (_drainScheduled) return;
    _drainScheduled = true;
    scheduleMicrotask(() {
      _drainScheduled = false;
      unawaited(_drain());
    });
  }

  /// Whether [queued] waited too long for a board that could take it.
  bool _stale(_Queued queued) {
    final ended = _lastDeliveryEnded;
    final since = ended != null && ended.isAfter(queued.queuedAt)
        ? ended
        : queued.queuedAt;
    return Clock.now().toUtc().difference(since.toUtc()) > maxWait;
  }

  Future<void> _drain() async {
    if (_draining) return;
    final generation = _generation;
    _draining = true;
    try {
      while (_pending.isNotEmpty && generation == _generation) {
        final target = _target;
        if (target == null) return;
        final queued = _pending.removeFirst();
        if (_stale(queued)) continue;
        final next = queued.request;
        try {
          target.showClassDay();
          if (next.isMark) {
            await target.markClassFromLink(
              next.occurrenceKey!,
              next.dayKey!,
              at: next.requestedAt,
            );
          } else if (next.isMarkAll) {
            await target.markClassesFromLink(
              next.occurrenceKeys,
              next.dayKey!,
              at: next.requestedAt,
            );
          }
        } catch (error, stack) {
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: error,
              stack: stack,
              library: 'class day links',
              context: ErrorDescription(
                'while opening the class day from a link',
              ),
            ),
          );
        }
        if (generation == _generation) _lastDeliveryEnded = Clock.now();
      }
    } finally {
      if (generation == _generation) _draining = false;
    }
  }

  /// Tests start from an empty seam with no board attached.
  @visibleForTesting
  void debugReset() {
    _pending.clear();
    _received.clear();
    _target = null;
    _generation++;
    _draining = false;
    _drainScheduled = false;
    _sequence = 0;
    _lastDeliveryEnded = null;
    _boardMarks.value = false;
  }
}
