/// Links into the class day from outside the app.
///
/// The Day Ledger home-screen widget opens the app with one of two URLs on
/// the app's own `roomofdays` scheme:
///
/// * `roomofdays://class-day` opens the Quests tab on the class day.
/// * `roomofdays://class-day/mark?occurrence=<key>&day=<dayKey>` does the
///   same and, when that class can be kept right now, keeps it with the same
///   keep and celebration a tap on the board's I WAS THERE plays.
///
/// Two small queues carry a link from the platform to the board:
///
/// 1. [ClassDayLinkInbox]: the app boundary (main.dart) accepts the raw link
///    as soon as the platform delivers it, cold or warm. The shell drains it
///    once the save and the timetable are loaded, routes to the Quests tab
///    and runs `GameState.checkClassKeep` at that moment.
/// 2. [ClassDayBoardSeam]: the shell hands the board a [ClassDayBoardRequest].
///    The board ([ClassDayLinkTarget], implemented by the Quests page) attaches
///    when it mounts and receives each request exactly once, in order.
///
/// Nothing here keeps a class or touches the save. The board owns the keep,
/// the undo slot and the celebration, so a widget mark can never differ from
/// a mark made on the board.
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

  /// Open it and keep one class, when that class can be kept now.
  mark,
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

  final ClassDayLinkKind kind;

  /// The timetable occurrence to keep (mark links only).
  final String? occurrenceKey;

  /// The class's own civil day in `Days.key` form (mark links only).
  final String? dayKey;

  bool get isMark => kind == ClassDayLinkKind.mark;

  /// `roomofdays://class-day` or
  /// `roomofdays://class-day/mark?occurrence=<key>&day=<dayKey>`.
  Uri toUri() => isMark
      ? Uri(
          scheme: classDayLinkScheme,
          host: classDayLinkHost,
          path: '/mark',
          queryParameters: {'occurrence': occurrenceKey!, 'day': dayKey!},
        )
      : Uri(scheme: classDayLinkScheme, host: classDayLinkHost);

  /// Parses a class-day link, or returns null for anything else.
  ///
  /// Accepts the custom scheme (`roomofdays://class-day/...`) and, so a
  /// future universal link needs no second parser, a path form whose first
  /// segment is `class-day` (`/class-day/mark?...`, bare or on
  /// roomofdays.com). A mark link with a
  /// missing or malformed key or day is still a class-day link: it opens the
  /// class day without keeping anything, so a tap is never ignored.
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
    if (action.isEmpty) return const ClassDayLink.open();
    if (action.length != 1 || action.single.toLowerCase() != 'mark') {
      return const ClassDayLink.open();
    }
    final key = uri.queryParameters['occurrence']?.trim() ?? '';
    final day = Days.validKey(uri.queryParameters['day']?.trim());
    if (key.isEmpty || key.length > classDayLinkMaxKeyLength || day == null) {
      return const ClassDayLink.open();
    }
    return ClassDayLink.mark(occurrenceKey: key, dayKey: day);
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

  /// [Clock.now] when the platform delivered the link.
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
  }) : occurrenceKey = null,
       dayKey = null;

  const ClassDayBoardRequest.mark({
    required String this.occurrenceKey,
    required String this.dayKey,
    required this.requestedAt,
    this.sequence = 0,
  });

  /// Set for a mark the shell checked as open (`ClassKeepCheck.open`) when
  /// the link arrived.
  final String? occurrenceKey;
  final String? dayKey;

  /// When the link was opened.
  final DateTime requestedAt;
  final int sequence;

  bool get isMark => occurrenceKey != null && dayKey != null;
}

/// The board's side of the seam. The Quests page state mixes this in (or
/// implements it), attaches itself to [ClassDayBoardSeam.instance] when it
/// mounts and detaches in dispose.
///
/// The defaults do nothing, so a board that has not wired the class day yet
/// still compiles and simply leaves the Quests tab as it is.
abstract mixin class ClassDayLinkTarget {
  /// Show the class-day frame (the room with today's classes) rather than
  /// the full board. Called for every request, before a mark.
  void showClassDay() {}

  /// Keep this class exactly as the board's I WAS THERE does: the same
  /// commit flush, `RewardUndoSlot`, `GameState.keepClass`, sound, haptic and
  /// celebration tier. Returns whether a class was kept. The shell already
  /// ran `checkClassKeep` when the link arrived; check again here, since the
  /// state may have moved on.
  Future<bool> markClassFromLink(String occurrenceKey, String dayKey) async =>
      false;
}

/// The pending-request queue between the shell and the board.
///
/// Requests wait until a target is attached, then each is delivered exactly
/// once, in order, one at a time (a mark's future completes before the next
/// request is handed over, so two quick marks play as two celebrations).
class ClassDayBoardSeam {
  ClassDayBoardSeam();

  /// The app's one seam. The shell requests on it; the Quests page attaches.
  static final ClassDayBoardSeam instance = ClassDayBoardSeam();

  /// At most this many requests wait for a board; older ones give way.
  static const maxPending = 8;

  final Queue<ClassDayBoardRequest> _pending = Queue<ClassDayBoardRequest>();
  ClassDayLinkTarget? _target;
  bool _draining = false;
  var _sequence = 0;

  /// Requests not yet delivered, oldest first.
  List<ClassDayBoardRequest> get pending => List.unmodifiable(_pending);

  bool get hasTarget => _target != null;

  /// Queues [request] and delivers it at once when a board is attached.
  void request(ClassDayBoardRequest request) {
    while (_pending.length >= maxPending) {
      _pending.removeFirst();
    }
    final numbered = request.isMark
        ? ClassDayBoardRequest.mark(
            occurrenceKey: request.occurrenceKey!,
            dayKey: request.dayKey!,
            requestedAt: request.requestedAt,
            sequence: ++_sequence,
          )
        : ClassDayBoardRequest.open(
            requestedAt: request.requestedAt,
            sequence: ++_sequence,
          );
    _pending.add(numbered);
    unawaited(_drain());
  }

  /// The board calls this when it mounts. Anything waiting is delivered now.
  void attach(ClassDayLinkTarget target) {
    _target = target;
    unawaited(_drain());
  }

  /// The board calls this in dispose. Undelivered requests keep waiting for
  /// the next board.
  void detach(ClassDayLinkTarget target) {
    if (identical(_target, target)) _target = null;
  }

  Future<void> _drain() async {
    if (_draining) return;
    _draining = true;
    try {
      while (_pending.isNotEmpty) {
        final target = _target;
        if (target == null) return;
        final next = _pending.removeFirst();
        target.showClassDay();
        if (next.isMark) {
          try {
            await target.markClassFromLink(next.occurrenceKey!, next.dayKey!);
          } catch (error, stack) {
            FlutterError.reportError(
              FlutterErrorDetails(
                exception: error,
                stack: stack,
                library: 'class day links',
                context: ErrorDescription('while marking a class from a link'),
              ),
            );
          }
        }
      }
    } finally {
      _draining = false;
    }
  }

  /// Tests start from an empty seam with no board attached.
  @visibleForTesting
  void debugReset() {
    _pending.clear();
    _target = null;
    _draining = false;
    _sequence = 0;
  }
}
