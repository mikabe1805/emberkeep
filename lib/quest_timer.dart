// The quest timer that keeps running when you leave.
//
// A timer is a start and an end on the wall clock (Clock.now()), saved the
// moment it begins. Nothing counts seconds, so switching rooms, leaving the
// page, backgrounding the app or closing it never stops it: whoever looks
// next just reads how far the clock has gone. Returning shows the true time
// left; if the end has passed, the timer is finished and waiting to be
// claimed.
//
// Proof multiplies, never gates: a finished timer is the only thing that makes
// a completion "timed". Finishing a Quest without one is always possible.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'clock.dart';
import 'models.dart';
import 'notifications.dart';

/// What the timer does for training, in the words the receipt and the offers
/// share.
const String questTimerTrainingLine =
    'Counts extra toward this week’s training';

/// The receipt's plain line for a completion the timer proved.
const String questTimerReceiptLine =
    'Timed · counts extra toward this week’s training';

// ── Which Quests are offered a timer ─────────────────────────────────────

/// The longest timer one tap will start.
const int questTimerMaxMinutes = 180;

/// A timer offered on a Quest's card: how long, and whether the Quest is a
/// timer Quest already (its own session length) or just a good fit for one.
@immutable
class QuestTimerOffer {
  const QuestTimerOffer({required this.minutes, this.inherent = false});

  final int minutes;

  /// The Quest was made as a timer Quest; [minutes] is its saved session.
  final bool inherent;

  String get label => 'Start a $minutes-minute timer';
}

final RegExp _minutesNamed = RegExp(
  r'(\d{1,3})\s*[- ]?\s*(?:minutes?|mins?)\b',
  caseSensitive: false,
);
final RegExp _hoursNamed = RegExp(
  r'(\d{1,2}(?:\.\d)?)\s*[- ]?\s*(?:hours?|hrs?)\b',
  caseSensitive: false,
);
final RegExp _anHour = RegExp(
  r'\b(half an|an|one) hour\b',
  caseSensitive: false,
);

/// A length in front of a moment, not a session: "30 minutes before bed".
final RegExp _notASession = RegExp(
  r'\b(before|after|until|till|early|late|later|ago|from now|by)\b',
  caseSensitive: false,
);

final List<(RegExp, int)> _timedKinds = [
  // reading
  (RegExp(r'\b(read|reading|chapter)\b', caseSensitive: false), 20),
  // studying
  (
    RegExp(
      r'\b(study|studying|homework|revise|revision|flashcards?|lesson|coursework)\b',
      caseSensitive: false,
    ),
    20,
  ),
  // practice
  (
    RegExp(
      r'\b(practi[cs]e|practi[cs]ing|rehears\w+|drills?|scales|guitar|piano|violin|ukulele|drums)\b',
      caseSensitive: false,
    ),
    20,
  ),
  // meditation
  (
    RegExp(
      r'\b(meditat\w*|mindful\w*|breathwork|stillness)\b',
      caseSensitive: false,
    ),
    10,
  ),
  // workout
  (
    RegExp(
      r'\b(work ?out|exercise|jog|jogging|yoga|stretch|stretching|gym|swim|swimming|cycling|cardio|sparring)\b|\brun(?:ning)?\b(?! errands?)',
      caseSensitive: false,
    ),
    20,
  ),
];

int? _namedMinutes(String text) {
  if (_notASession.hasMatch(text)) return null;
  final minutes = _minutesNamed.firstMatch(text);
  if (minutes != null) return int.parse(minutes.group(1)!);
  final hours = _hoursNamed.firstMatch(text);
  if (hours != null) return (double.parse(hours.group(1)!) * 60).round();
  final an = _anHour.firstMatch(text);
  if (an != null) {
    return an.group(1)!.toLowerCase().startsWith('half') ? 30 : 60;
  }
  return null;
}

/// The timer [quest] is offered, or null when a timer would not fit it: a
/// Quest already done, a journal, a guided workout (it has its own runner), an
/// all-day line or a dated plan. A timer Quest offers its own session length;
/// any other Quest is offered one when it names minutes ("Stretch 10 minutes")
/// or is reading, studying, practice, meditation or a workout.
QuestTimerOffer? timerOfferFor(Quest quest, {DateTime? now}) {
  final at = now ?? Clock.now();
  if (quest.doneFor(at)) return null;
  if (quest.allDay ||
      quest.journalPrompt != null ||
      quest.workout ||
      quest.isEvent) {
    return null;
  }
  if (quest.verification == Verification.timer &&
      quest.effectiveTimerMinutes > 0) {
    return QuestTimerOffer(
      minutes: quest.effectiveTimerMinutes.clamp(1, questTimerMaxMinutes),
      inherent: true,
    );
  }
  final text = quest.displayTitle;
  final named = _namedMinutes(text);
  if (named != null && named >= 1 && named <= questTimerMaxMinutes) {
    return QuestTimerOffer(minutes: named);
  }
  for (final (pattern, minutes) in _timedKinds) {
    if (pattern.hasMatch(text)) return QuestTimerOffer(minutes: minutes);
  }
  return null;
}

// ── One running timer ────────────────────────────────────────────────────

/// A timer that has begun: the Quest it is for, how long, and the two
/// instants that define it.
@immutable
class QuestTimerSession {
  const QuestTimerSession({
    required this.questKey,
    required this.questTitle,
    required this.minutes,
    required this.startedAt,
    required this.endsAt,
  });

  /// The Quest's identity title ([Quest.title]), which survives a climb.
  final String questKey;

  /// What the Quest was called when the timer began (its prescription).
  final String questTitle;
  final int minutes;
  final DateTime startedAt;
  final DateTime endsAt;

  bool finishedAt(DateTime now) => !now.isBefore(endsAt);

  /// Time left at [now], never negative and never more than the whole
  /// session (a clock set back cannot stretch it).
  Duration remainingAt(DateTime now) {
    final left = endsAt.difference(now);
    if (left.isNegative) return Duration.zero;
    final whole = Duration(minutes: minutes);
    return left > whole ? whole : left;
  }

  Map<String, dynamic> toJson() => {
    'questKey': questKey,
    'questTitle': questTitle,
    'minutes': minutes,
    'startedAt': startedAt.millisecondsSinceEpoch,
    'endsAt': endsAt.millisecondsSinceEpoch,
  };

  /// Total: anything damaged reads as no timer.
  static QuestTimerSession? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final key = raw['questKey'];
    final title = raw['questTitle'];
    final minutes = raw['minutes'];
    final started = raw['startedAt'];
    final ends = raw['endsAt'];
    if (key is! String || key.isEmpty) return null;
    if (title is! String) return null;
    if (minutes is! int || minutes < 1 || minutes > questTimerMaxMinutes) {
      return null;
    }
    if (started is! int || ends is! int || ends <= started) return null;
    return QuestTimerSession(
      questKey: key,
      questTitle: title,
      minutes: minutes,
      startedAt: DateTime.fromMillisecondsSinceEpoch(started),
      endsAt: DateTime.fromMillisecondsSinceEpoch(ends),
    );
  }
}

/// What tells the person a timer ended while the app was out of sight. A seam,
/// so a test can see the call without a phone.
abstract class QuestTimerAlerts {
  Future<void> schedule({
    required DateTime at,
    required String title,
    required String body,
  });
  Future<void> cancel();
}

/// The app's own local notifications (the Reminders setup). Nothing is
/// scheduled where notifications are unsupported or not allowed, and this
/// never asks for permission: only the Reminders switch in Me does that.
class NotificationsQuestTimerAlerts implements QuestTimerAlerts {
  const NotificationsQuestTimerAlerts();

  @override
  Future<void> schedule({
    required DateTime at,
    required String title,
    required String body,
  }) async {
    if (!Notifications.isSupported) return;
    final permission = await Notifications.permissionStatus();
    if (permission != ReminderPermissionStatus.granted) return;
    await Notifications.scheduleQuestTimer(at: at, title: title, body: body);
  }

  @override
  Future<void> cancel() async {
    if (!Notifications.isSupported) return;
    await Notifications.cancelQuestTimer();
  }
}

/// The one quest timer: at most one runs at a time. It saves itself on every
/// change, so a restart picks it up where the clock has got to.
///
/// It holds no ticker. A widget that wants to show the seconds ticks for
/// itself and calls [checkFinished]; nothing here can be left running.
class QuestTimer extends ChangeNotifier {
  QuestTimer({
    this.alerts = const NotificationsQuestTimerAlerts(),
    Future<SharedPreferences> Function()? preferences,
  }) : _preferences = preferences ?? SharedPreferences.getInstance;

  static const storageKey = 'room_of_days_quest_timer_v1';

  /// How many times a Quest's mark-time "Time it?" has been answered with "Just
  /// mark it done". After [askLimit] the question stops: the person knows the
  /// timer is there (it stays on the card), and is not asked every day.
  static const declinesKey = 'room_of_days_quest_timer_declines_v1';
  static const askLimit = 3;
  static const _declinesCap = 200;
  final Map<String, int> _declines = {};

  /// What sets (and cancels) the reminder for the end.
  final QuestTimerAlerts alerts;
  final Future<SharedPreferences> Function() _preferences;

  QuestTimerSession? _session;
  bool _finishAnnounced = false;
  bool _overlayOpen = false;

  QuestTimerSession? get session => _session;
  bool get hasSession => _session != null;

  /// The full-screen timer is open, so the rest of the house does not draw
  /// its own indicator or finish moment on top of it.
  bool get overlayOpen => _overlayOpen;
  set overlayOpen(bool open) {
    if (_overlayOpen == open) return;
    _overlayOpen = open;
    notifyListeners();
  }

  bool isRunning([DateTime? now]) {
    final s = _session;
    return s != null && !s.finishedAt(now ?? Clock.now());
  }

  bool isFinished([DateTime? now]) {
    final s = _session;
    return s != null && s.finishedAt(now ?? Clock.now());
  }

  Duration remaining([DateTime? now]) =>
      _session?.remainingAt(now ?? Clock.now()) ?? Duration.zero;

  /// The timer for [quest], if it is the one running (or waiting).
  QuestTimerSession? sessionFor(Quest quest) {
    final s = _session;
    return s != null && s.questKey == quest.title ? s : null;
  }

  /// Reads the saved timer, replacing whatever is in memory. A finished timer
  /// is kept: it is waiting for the person to claim it.
  Future<void> load() async {
    QuestTimerSession? loaded;
    final declines = <String, int>{};
    try {
      final prefs = await _preferences();
      final raw = prefs.getString(storageKey);
      if (raw != null) loaded = QuestTimerSession.fromJson(jsonDecode(raw));
      final asked = prefs.getString(declinesKey);
      if (asked != null) {
        final decoded = jsonDecode(asked);
        if (decoded is Map) {
          for (final entry in decoded.entries) {
            final count = entry.value;
            if (entry.key is String && count is int && count > 0) {
              declines[entry.key as String] = count;
            }
          }
        }
      }
    } catch (_) {
      loaded = null;
    }
    _session = loaded;
    _declines
      ..clear()
      ..addAll(declines);
    _finishAnnounced = false;
    notifyListeners();
  }

  /// Whether marking [quest] should still offer a timer first.
  bool shouldAsk(Quest quest) => (_declines[quest.title] ?? 0) < askLimit;

  /// The person answered "Just mark it done" for [quest].
  Future<void> recordDecline(Quest quest) async {
    _declines[quest.title] = (_declines[quest.title] ?? 0) + 1;
    while (_declines.length > _declinesCap) {
      _declines.remove(_declines.keys.first);
    }
    try {
      final prefs = await _preferences();
      await prefs.setString(declinesKey, jsonEncode(_declines));
    } catch (_) {
      /* best effort */
    }
  }

  /// Begins a timer for [quest] ending [minutes] from [startedAt] (now by
  /// default), replacing any other. When [remindersOn] (the person has
  /// Reminders on) a local notification is set for the end.
  Future<QuestTimerSession> start({
    required Quest quest,
    required int minutes,
    DateTime? startedAt,
    bool remindersOn = false,
  }) async {
    final begun = startedAt ?? Clock.now();
    final clamped = minutes.clamp(1, questTimerMaxMinutes);
    final session = QuestTimerSession(
      questKey: quest.title,
      questTitle: quest.displayTitle,
      minutes: clamped,
      startedAt: begun,
      endsAt: begun.add(Duration(minutes: clamped)),
    );
    _session = session;
    _finishAnnounced = false;
    notifyListeners();
    await _save();
    if (remindersOn) {
      try {
        await alerts.schedule(
          at: session.endsAt,
          title: 'Time’s up',
          body:
              '${session.questTitle}. Your ${session.minutes} minutes are '
              'done. Open the app to finish it.',
        );
      } catch (_) {
        // A reminder that cannot be set never stops the timer.
      }
    } else {
      await _cancelAlert();
    }
    return session;
  }

  /// Ends the timer for any reason (stopped, or claimed). No completion is
  /// made here.
  Future<void> clear() async {
    if (_session == null) return;
    _session = null;
    _finishAnnounced = false;
    notifyListeners();
    await _save();
    await _cancelAlert();
  }

  /// True exactly once per finish: the first time the clock is seen past the
  /// end. The caller shows the finish moment then. Never while the full
  /// screen timer is open (it has its own finish).
  bool checkFinished([DateTime? now]) {
    if (_finishAnnounced || _overlayOpen) return false;
    if (!isFinished(now)) return false;
    _finishAnnounced = true;
    notifyListeners();
    return true;
  }

  /// The finish moment was shown (or waved off) for this timer.
  bool get finishAnnounced => _finishAnnounced;

  Future<void> _cancelAlert() async {
    try {
      await alerts.cancel();
    } catch (_) {
      /* best effort */
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await _preferences();
      final s = _session;
      if (s == null) {
        await prefs.remove(storageKey);
      } else {
        await prefs.setString(storageKey, jsonEncode(s.toJson()));
      }
    } catch (_) {
      // Saving the timer is best effort: it still runs this session.
    }
  }
}

/// Hands the shell's timer to everything inside it, and rebuilds them as it
/// changes.
class QuestTimerScope extends InheritedNotifier<QuestTimer> {
  const QuestTimerScope({
    super.key,
    required QuestTimer timer,
    required super.child,
  }) : super(notifier: timer);

  /// The shell's timer, or null outside it (a room on its own). Rebuilds the
  /// asker as the timer changes.
  static QuestTimer? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<QuestTimerScope>()?.notifier;

  /// The same timer, read once from a callback, without listening.
  static QuestTimer? maybeRead(BuildContext context) =>
      context.getInheritedWidgetOfExactType<QuestTimerScope>()?.notifier;
}

/// "19:42", or "1:05:00" past an hour.
String questTimerClock(Duration left) {
  final total = left.inSeconds < 0 ? 0 : left.inSeconds;
  final hours = total ~/ 3600;
  final minutes = (total % 3600) ~/ 60;
  final seconds = total % 60;
  final ss = seconds.toString().padLeft(2, '0');
  if (hours > 0) return '$hours:${minutes.toString().padLeft(2, '0')}:$ss';
  return '$minutes:$ss';
}
