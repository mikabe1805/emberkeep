// A Dart mirror of the Day Ledger widget's view logic in
// ios/RoomOfDaysWidgets/RoomOfDaysWidgets.swift (`RoomWidgetSnapshot`,
// `RoomWidgetEntry`, `RoomWidgetProvider.getTimeline`). The Swift compiles
// only on Codemagic's Mac, so its decisions are written here once more, line
// for line, where they can be tested and rendered. Change both together
// (and test/design_renders/day_ledger_widget_mock.dart for the views).
//
// Test-support library, not a test.
library;

import 'dart:convert';

const openClassDayUrl = 'roomofdays://class-day';

/// `RoomWidgetSnapshot`: decoded the way Swift's `JSONDecoder` reads it.
/// Unknown keys are ignored; version 3 keys are optional.
class LedgerSnapshot {
  LedgerSnapshot({
    required this.version,
    required this.generatedAt,
    required this.upcomingClasses,
    required this.incompleteQuests,
    this.questsDayEndsEpochMillis,
    this.nextDayQuests,
    this.nextDayEndsEpochMillis,
    this.classDays,
    this.boundaries,
  });

  static LedgerSnapshot empty() => LedgerSnapshot(
    version: 2,
    generatedAt: '',
    upcomingClasses: const [],
    incompleteQuests: const [],
  );

  /// `loadSnapshot()`: anything that does not decode, or a version outside
  /// 2...3, reads as [empty].
  static LedgerSnapshot load(String? json) {
    if (json == null) return empty();
    try {
      final map = (jsonDecode(json) as Map).cast<String, dynamic>();
      final decoded = LedgerSnapshot._fromJson(map);
      if (decoded.version < 2 || decoded.version > 3) return empty();
      return decoded;
    } catch (_) {
      return empty();
    }
  }

  factory LedgerSnapshot._fromJson(Map<String, dynamic> json) => LedgerSnapshot(
    version: json['version'] as int,
    generatedAt: json['generatedAt'] as String,
    upcomingClasses: [
      for (final item in json['upcomingClasses'] as List)
        LedgerClassGlance._fromJson((item as Map).cast()),
    ],
    incompleteQuests: [
      for (final item in json['incompleteQuests'] as List)
        LedgerQuest._fromJson((item as Map).cast()),
    ],
    questsDayEndsEpochMillis: json['questsDayEndsEpochMillis'] as int?,
    nextDayQuests: json['nextDayQuests'] == null
        ? null
        : [
            for (final item in json['nextDayQuests'] as List)
              LedgerQuest._fromJson((item as Map).cast()),
          ],
    nextDayEndsEpochMillis: json['nextDayEndsEpochMillis'] as int?,
    classDays: json['classDays'] == null
        ? null
        : [
            for (final item in json['classDays'] as List)
              LedgerClassDay._fromJson((item as Map).cast()),
          ],
    boundaries: json['boundaries'] == null
        ? null
        : [for (final item in json['boundaries'] as List) item as int],
  );

  final int version;
  final String generatedAt;
  final List<LedgerClassGlance> upcomingClasses;
  final List<LedgerQuest> incompleteQuests;
  final int? questsDayEndsEpochMillis;
  final List<LedgerQuest>? nextDayQuests;
  final int? nextDayEndsEpochMillis;
  final List<LedgerClassDay>? classDays;
  final List<int>? boundaries;
}

class LedgerClassGlance {
  LedgerClassGlance._fromJson(Map<String, dynamic> json)
    : courseCode = json['courseCode'] as String,
      courseTitle = json['courseTitle'] as String,
      startLocal = json['startLocal'] as String,
      endLocal = json['endLocal'] as String,
      startEpochMillis = json['startEpochMillis'] as int,
      endEpochMillis = json['endEpochMillis'] as int,
      timeZoneId = json['timeZoneId'] as String,
      dayKey = json['dayKey'] as String?,
      dayLabel = json['dayLabel'] as String?,
      shortTitle = json['shortTitle'] as String?;

  final String courseCode;
  final String courseTitle;
  final String startLocal;
  final String endLocal;
  final int startEpochMillis;
  final int endEpochMillis;
  final String timeZoneId;
  final String? dayKey;
  final String? dayLabel;
  final String? shortTitle;
}

class LedgerQuest {
  LedgerQuest._fromJson(Map<String, dynamic> json)
    : id = json['id'] as String,
      title = json['title'] as String;

  final String id;
  final String title;
}

class LedgerClassDay {
  LedgerClassDay._fromJson(Map<String, dynamic> json)
    : dayKey = json['dayKey'] as String,
      weekday = json['weekday'] as String,
      startsEpochMillis = json['startsEpochMillis'] as int,
      eveningStartsEpochMillis = json['eveningStartsEpochMillis'] as int,
      nightEndsEpochMillis = json['nightEndsEpochMillis'] as int,
      lastClassEndEpochMillis = json['lastClassEndEpochMillis'] as int,
      classXp = json['classXp'] as int,
      allKept = json['allKept'] as bool,
      attendedShort = json['attendedShort'] as String?,
      markAllUrl = json['markAllUrl'] as String?,
      recordLine = json['recordLine'] as String?,
      classes = [
        for (final item in json['classes'] as List)
          LedgerDayClass._fromJson((item as Map).cast()),
      ];

  final String dayKey;
  final String weekday;
  final int startsEpochMillis;
  final int eveningStartsEpochMillis;
  final int nightEndsEpochMillis;
  final int lastClassEndEpochMillis;
  final int classXp;
  final bool allKept;
  final String? attendedShort;

  /// Present only while the app's board keeps classes from links.
  final String? markAllUrl;
  final String? recordLine;
  final List<LedgerDayClass> classes;
}

class LedgerDayClass {
  LedgerDayClass._fromJson(Map<String, dynamic> json)
    : occurrenceKey = json['occurrenceKey'] as String,
      title = json['title'] as String,
      shortTitle = json['shortTitle'] as String,
      place = json['place'] as String,
      startLabel = json['startLabel'] as String,
      endLabel = json['endLabel'] as String,
      startEpochMillis = json['startEpochMillis'] as int,
      endEpochMillis = json['endEpochMillis'] as int,
      kept = json['kept'] as bool,
      keptXp = json['keptXp'] as int,
      markUrl = json['markUrl'] as String?;

  final String occurrenceKey;
  final String title;
  final String shortTitle;
  final String place;
  final String startLabel;
  final String endLabel;
  final int startEpochMillis;
  final int endEpochMillis;
  final bool kept;
  final int keptXp;

  /// Present only while the app's board keeps classes from links.
  final String? markUrl;
}

enum LedgerMode { today, classes, allKept }

/// `RoomWidgetEntry.EveningLine`: the one quiet line under the evening's
/// everyday look.
enum LedgerEveningLine { markAll, waiting, record }

/// `RoomWidgetEntry`: one timeline entry and everything the views ask it.
class DayLedgerEntry {
  DayLedgerEntry(this.date, this.snapshot);

  final DateTime date;
  final LedgerSnapshot snapshot;

  int get nowMillis => date.millisecondsSinceEpoch;

  /// The first class not yet ended (version 2 behavior, the everyday look).
  LedgerClassGlance? get nextClass {
    LedgerClassGlance? best;
    for (final glance in snapshot.upcomingClasses) {
      if (glance.endEpochMillis < nowMillis) continue;
      if (best == null || glance.startEpochMillis < best.startEpochMillis) {
        best = glance;
      }
    }
    return best;
  }

  /// The first class that has not started.
  LedgerClassGlance? get upcomingClass {
    LedgerClassGlance? best;
    for (final glance in snapshot.upcomingClasses) {
      if (glance.startEpochMillis <= nowMillis) continue;
      if (best == null || glance.startEpochMillis < best.startEpochMillis) {
        best = glance;
      }
    }
    return best;
  }

  /// The quests for the day the entry reads; null when neither published
  /// list is current (two midnights without the app).
  List<LedgerQuest>? get quests {
    final dayEnds = snapshot.questsDayEndsEpochMillis;
    if (dayEnds == null) return snapshot.incompleteQuests;
    if (nowMillis < dayEnds) return snapshot.incompleteQuests;
    final nextEnds = snapshot.nextDayEndsEpochMillis;
    if (nextEnds != null && nowMillis < nextEnds) {
      return snapshot.nextDayQuests ?? const [];
    }
    return null;
  }

  LedgerClassDay? get classDay {
    for (final day in snapshot.classDays ?? const <LedgerClassDay>[]) {
      if (day.startsEpochMillis <= nowMillis &&
          nowMillis < day.nightEndsEpochMillis) {
        return day;
      }
    }
    return null;
  }

  /// The class day while it owns the widget: from its first class's start
  /// (or once every class is kept) until the evening.
  LedgerClassDay? get activeClassDay {
    final day = classDay;
    if (day == null || nowMillis >= day.eveningStartsEpochMillis) return null;
    if (day.allKept) return day;
    if (day.classes.isEmpty || nowMillis < day.classes.first.startEpochMillis) {
      return null;
    }
    return day;
  }

  /// The newest class of any kind that has started and is not kept. A day
  /// whose counted classes are all kept still offers a started office hour.
  LedgerDayClass? get focusClass {
    final day = activeClassDay;
    if (day == null) return null;
    for (final entry in day.classes.reversed) {
      if (entry.startEpochMillis <= nowMillis && !entry.kept) return entry;
    }
    return null;
  }

  LedgerMode get mode {
    final day = activeClassDay;
    if (day == null) return LedgerMode.today;
    return day.allKept && focusClass == null
        ? LedgerMode.allKept
        : LedgerMode.classes;
  }

  bool isInSession(LedgerDayClass entry) =>
      entry.startEpochMillis <= nowMillis && nowMillis < entry.endEpochMillis;

  bool get classesDone {
    final day = activeClassDay;
    return day != null && nowMillis >= day.lastClassEndEpochMillis;
  }

  /// Classes of the active day that have ended and are not kept.
  List<LedgerDayClass> get waitingClasses {
    final day = activeClassDay;
    if (day == null) return const [];
    return [
      for (final entry in day.classes)
        if (entry.endEpochMillis <= nowMillis && !entry.kept) entry,
    ];
  }

  /// After the last class, with two or more waiting: one control for all.
  String? get markAllUrl {
    if (!classesDone || waitingClasses.length < 2) return null;
    return activeClassDay?.markAllUrl;
  }

  /// `I WENT TO BOTH`, else `I WENT TO ALL`: never a count of what waits.
  String get markAllLabel =>
      waitingClasses.length == 2 ? 'I WENT TO BOTH' : 'I WENT TO ALL';

  /// After the last class: at most three rows, in time order, the newest
  /// waiting classes first in line for a place, then the newest kept.
  List<LedgerDayClass> get doneRows {
    final day = activeClassDay;
    if (day == null) return const [];
    if (day.classes.length <= 3) return day.classes;
    final waiting = day.classes.where((entry) => !entry.kept).toList();
    final kept = day.classes.where((entry) => entry.kept).toList();
    final fromWaiting = waiting.length >= 3
        ? waiting.sublist(waiting.length - 3)
        : waiting;
    final room = 3 - fromWaiting.length;
    final fromKept = room <= 0
        ? <LedgerDayClass>[]
        : kept.sublist(kept.length - (room < kept.length ? room : kept.length));
    return [...fromWaiting, ...fromKept]
      ..sort((a, b) => a.startEpochMillis.compareTo(b.startEpochMillis));
  }

  /// The NEXT line gives way when three rows and the mark-all control fill
  /// the medium widget.
  bool get showsNextAfterRows => markAllUrl == null || doneRows.length < 3;

  LedgerDayClass? get lastKept {
    final day = activeClassDay;
    if (day == null) return null;
    for (final entry in day.classes.reversed) {
      if (entry.kept) return entry;
    }
    return null;
  }

  /// What comes next: the day's next class, else the first class after it.
  ({String title, String time})? get nextAfter {
    final day = activeClassDay;
    if (day != null) {
      for (final entry in day.classes) {
        if (entry.startEpochMillis > nowMillis) {
          return (title: entry.shortTitle, time: entry.startLabel);
        }
      }
    }
    final glance = upcomingClass;
    if (glance == null) return null;
    return (
      title: glance.shortTitle ?? glance.courseTitle,
      time: classTime(glance),
    );
  }

  /// The class day's evening, until its night ends at 04:00.
  LedgerClassDay? get eveningDay {
    final day = classDay;
    if (day == null || nowMillis < day.eveningStartsEpochMillis) return null;
    return day;
  }

  /// The evening's classes that ended and are not kept, oldest first.
  List<LedgerDayClass> get eveningWaiting {
    final day = eveningDay;
    if (day == null) return const [];
    return [
      for (final entry in day.classes)
        if (entry.endEpochMillis <= nowMillis && !entry.kept) entry,
    ];
  }

  LedgerEveningLine? get eveningLine {
    final day = eveningDay;
    if (day == null) return null;
    final waiting = eveningWaiting;
    if (waiting.length >= 2 && day.markAllUrl != null) {
      return LedgerEveningLine.markAll;
    }
    if (waiting.isNotEmpty) return LedgerEveningLine.waiting;
    if (day.recordLine != null) return LedgerEveningLine.record;
    return null;
  }

  String get eveningMarkAllLabel =>
      eveningWaiting.length == 2 ? 'I WENT TO BOTH' : 'I WENT TO ALL';

  /// `classTime(_:)`: `8:30 AM`, or `WED 8:30 AM` when the class is not on
  /// the entry's own date in the class's zone. [localDateOf] stands in for
  /// Swift's `DateFormatter` with the class's `TimeZone`.
  String classTime(LedgerClassGlance glance) {
    final clock = _clockFromLocalIso(glance.startLocal);
    final dayKey = glance.dayKey;
    final dayLabel = glance.dayLabel;
    if (dayKey == null || dayLabel == null) return clock;
    return localDateOf(date, glance) == dayKey ? clock : '$dayLabel $clock';
  }

  /// The entry date's civil date in the class's zone. The class's own local
  /// ISO start carries that zone's offset at the start, which is the offset
  /// the widget's `DateFormatter` uses on the same day (a daylight-saving
  /// change at 2:00 AM cannot move a calendar date that a 4:00 AM rollover
  /// reads).
  static String Function(DateTime date, LedgerClassGlance glance) localDateOf =
      _localDateOf;

  static String _localDateOf(DateTime date, LedgerClassGlance glance) {
    final localStart = _wallTime(glance.startLocal);
    final wallStart = DateTime.utc(
      localStart.year,
      localStart.month,
      localStart.day,
      localStart.hour,
      localStart.minute,
    );
    final offset = wallStart.difference(
      DateTime.fromMillisecondsSinceEpoch(glance.startEpochMillis, isUtc: true),
    );
    final there = date.toUtc().add(offset);
    return '${there.year.toString().padLeft(4, '0')}-'
        '${there.month.toString().padLeft(2, '0')}-'
        '${there.day.toString().padLeft(2, '0')}';
  }

  /// The small widget is one tap: the control it shows (mark all, or the
  /// class to mark), else the class day while it has something to show.
  String? get smallUrl {
    final all = markAllUrl;
    if (all != null) return all;
    final url = focusClass?.markUrl;
    if (url != null) return url;
    return _openUrl;
  }

  /// The medium widget's background tap; only its control marks.
  String? get mediumUrl => _openUrl;

  String? get _openUrl {
    if (activeClassDay != null) return openClassDayUrl;
    return eveningLine == null ? null : openClassDayUrl;
  }

  /// Every link a tap on the medium widget can open, background first: the
  /// `Link`s the views draw. Only the one control marks.
  List<String> get mediumLinks {
    final links = <String>[?mediumUrl];
    switch (mode) {
      case LedgerMode.today:
        final day = eveningDay;
        switch (eveningLine) {
          case LedgerEveningLine.markAll:
            links.add(day!.markAllUrl!);
          case LedgerEveningLine.waiting:
            final url = eveningWaiting.last.markUrl;
            if (url != null) links.add(url);
          case LedgerEveningLine.record || null:
            break;
        }
      case LedgerMode.classes:
        final all = markAllUrl;
        if (all != null) {
          links.add(all);
        } else {
          final url = focusClass?.markUrl;
          if (url != null) links.add(url);
        }
      case LedgerMode.allKept:
        break;
    }
    return links;
  }
}

/// `getTimeline`: now, then one entry a second past each future boundary.
List<DateTime> ledgerTimeline(LedgerSnapshot snapshot, DateTime now) {
  final millis =
      snapshot.boundaries ??
      [for (final glance in snapshot.upcomingClasses) glance.endEpochMillis];
  final future = <DateTime>{
    now,
    for (final value in millis)
      if (DateTime.fromMillisecondsSinceEpoch(
        value + 1000,
        isUtc: true,
      ).isAfter(now.toUtc()))
        DateTime.fromMillisecondsSinceEpoch(value + 1000, isUtc: true),
  }.toList()..sort();
  return future;
}

/// The wall-clock fields of a local ISO string, ignoring any UTC offset
/// suffix (`2026-10-07T08:30:00.000-0400` reads 8:30).
DateTime _wallTime(String iso) => DateTime.parse(iso.substring(0, 19));

String _clockFromLocalIso(String iso) {
  final local = _wallTime(iso);
  final hour = local.hour;
  final twelve = hour % 12 == 0 ? 12 : hour % 12;
  final minutes = local.minute.toString().padLeft(2, '0');
  return '$twelve:$minutes ${hour < 12 ? 'AM' : 'PM'}';
}
