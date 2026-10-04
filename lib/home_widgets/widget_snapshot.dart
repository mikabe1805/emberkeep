/// The small, privacy-safe handoff shared with home-screen widgets.
///
/// This deliberately contains only a bounded run of class facts and a few
/// actionable quest labels. The bounded class run lets WidgetKit advance
/// across class boundaries without persisting the full schedule or waiting for
/// the host app to reopen. It is not a second persistence model.
///
/// Version 3 adds the class day: the night-owned day's real classes (and the
/// next few class days) with occurrence key, title, time, place and state,
/// the mark link for each, the instants the widget changes at (each class
/// start and end, the evening, the 04:00 night end, local midnight), and the
/// next day's quests for after midnight. Every version 2 field keeps its name
/// and shape; the new ones are additions a version 2 reader ignores.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:emberkeep/academic_calendar/domain/academic_schedule.dart';
import 'package:emberkeep/academic_calendar/services/class_day_projection.dart';
import 'package:emberkeep/class_day_links.dart';
import 'package:emberkeep/content/class_lines.dart';
import 'package:emberkeep/content/day_planning.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/models.dart';

const int roomOfDaysWidgetSnapshotVersion = 3;
const int roomOfDaysWidgetClassLimit = 24;

/// The night-owned class day plus following days that have classes, at most
/// this many in all.
const int roomOfDaysWidgetClassDayLimit = 7;

/// The most instants the widget timeline is handed.
const int roomOfDaysWidgetBoundaryLimit = 96;

/// The after-class list holds at least this long after the last class ends,
/// even when the evening would begin sooner (his Monday class runs to 7:00
/// PM, Thursday's lab to 6:50 PM), so the walk home still shows it.
const Duration roomOfDaysWidgetAfterClassHold = Duration(hours: 1);

/// The evening begins at this local hour at the earliest, the same hour
/// `isWindDownTime` (content/routines.dart) opens the wind-down.
const int roomOfDaysWidgetEveningHour = 17;

final class WidgetSnapshot {
  const WidgetSnapshot({
    required this.generatedAt,
    required this.upcomingClasses,
    required this.incompleteQuests,
    this.questsDayEndsAt,
    this.nextDayQuests = const [],
    this.nextDayEndsAt,
    this.classDays = const [],
    this.boundaries = const [],
  });

  final DateTime generatedAt;
  final List<WidgetClassGlance> upcomingClasses;
  final List<WidgetQuestGlance> incompleteQuests;

  /// Local midnight after [generatedAt]. From then on [incompleteQuests]
  /// belong to yesterday and the widget shows [nextDayQuests].
  final DateTime? questsDayEndsAt;

  /// The open quests the next day starts with, as the app will show them
  /// after its midnight rollover (tomorrow's three included).
  final List<WidgetQuestGlance> nextDayQuests;

  /// The midnight after that. Past it neither list is current and the widget
  /// shows no quests until the app publishes again.
  final DateTime? nextDayEndsAt;

  /// The night-owned day first (when it has classes), then later class days.
  final List<WidgetClassDay> classDays;

  /// Every future instant the widget's picture can change at, ascending.
  final List<DateTime> boundaries;

  WidgetClassGlance? get nextClass =>
      upcomingClasses.isEmpty ? null : upcomingClasses.first;

  /// The class day containing [at], if any.
  WidgetClassDay? classDayAt(DateTime at) {
    final instant = at.toUtc();
    for (final day in classDays) {
      if (!instant.isBefore(day.startsAt) &&
          instant.isBefore(day.nightEndsAt)) {
        return day;
      }
    }
    return null;
  }

  /// The first boundary strictly after [at], for the app's own refresh.
  DateTime? nextBoundaryAfter(DateTime at) {
    final instant = at.toUtc();
    for (final boundary in boundaries) {
      if (boundary.isAfter(instant)) return boundary;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    'version': roomOfDaysWidgetSnapshotVersion,
    'generatedAt': generatedAt.toUtc().toIso8601String(),
    'upcomingClasses': [
      for (final classGlance in upcomingClasses) classGlance.toJson(),
    ],
    'incompleteQuests': [for (final quest in incompleteQuests) quest.toJson()],
    if (questsDayEndsAt != null)
      'questsDayEndsEpochMillis': _millis(questsDayEndsAt!),
    'nextDayQuests': [for (final quest in nextDayQuests) quest.toJson()],
    if (nextDayEndsAt != null)
      'nextDayEndsEpochMillis': _millis(nextDayEndsAt!),
    'classDays': [for (final day in classDays) day.toJson()],
    'boundaries': [for (final boundary in boundaries) _millis(boundary)],
  };

  String encode() => jsonEncode(toJson());
}

final class WidgetClassGlance {
  const WidgetClassGlance({
    required this.courseCode,
    required this.courseTitle,
    required this.startLocal,
    required this.endLocal,
    required this.startEpochMillis,
    required this.endEpochMillis,
    required this.timeZoneId,
    this.occurrenceKey,
    this.dayKey,
    this.dayLabel,
    this.shortTitle,
  });

  final String courseCode;
  final String courseTitle;
  final String startLocal;
  final String endLocal;
  final int startEpochMillis;
  final int endEpochMillis;
  final String timeZoneId;

  /// Version 3. The occurrence and its civil day in the timetable's zone.
  final String? occurrenceKey;
  final String? dayKey;

  /// Version 3. The class day's own word, fixed to its date so it never goes
  /// stale: `WED` within six days of publishing, else `NOV 30`. The widget
  /// shows it before the time whenever the class is not on the day it reads.
  final String? dayLabel;

  /// Version 3. A title short enough for one widget row (`shortClassLabel`).
  final String? shortTitle;

  Map<String, dynamic> toJson() => {
    'courseCode': courseCode,
    'courseTitle': courseTitle,
    'startLocal': startLocal,
    'endLocal': endLocal,
    'startEpochMillis': startEpochMillis,
    'endEpochMillis': endEpochMillis,
    'timeZoneId': timeZoneId,
    if (occurrenceKey != null) 'occurrenceKey': occurrenceKey,
    if (dayKey != null) 'dayKey': dayKey,
    if (dayLabel != null) 'dayLabel': dayLabel,
    if (shortTitle != null) 'shortTitle': shortTitle,
  };
}

/// Where one class on a class day stands for the widget.
enum WidgetClassState {
  /// Has not started.
  upcoming,

  /// Between its start and its end, not kept yet.
  inSession,

  /// Over and not kept yet; it can still be marked until the night ends.
  waiting,

  /// Kept.
  kept,
}

/// One class day as the widget reads it.
final class WidgetClassDay {
  const WidgetClassDay({
    required this.dayKey,
    required this.weekday,
    required this.startsAt,
    required this.eveningStartsAt,
    required this.nightEndsAt,
    required this.lastClassEndsAt,
    required this.classXp,
    required this.allKept,
    required this.classes,
    this.attendedShort,
  });

  final String dayKey;

  /// `Tuesday`.
  final String weekday;

  /// 04:00 that morning in the timetable's zone: the day's night begins.
  final DateTime startsAt;

  /// The later of 5:00 PM and an hour after the last class: the widget turns
  /// back to its everyday look.
  final DateTime eveningStartsAt;

  /// 04:00 the next morning: marking closes and the day is over.
  final DateTime nightEndsAt;
  final DateTime lastClassEndsAt;

  /// Class XP kept that day, full-day bonus included.
  final int classXp;

  /// Every class the day is judged by is kept (and there is at least one).
  final bool allKept;

  final List<WidgetDayClass> classes;

  /// Only when [allKept]: `Both attended`.
  final String? attendedShort;

  Map<String, dynamic> toJson() => {
    'dayKey': dayKey,
    'weekday': weekday,
    'startsEpochMillis': _millis(startsAt),
    'eveningStartsEpochMillis': _millis(eveningStartsAt),
    'nightEndsEpochMillis': _millis(nightEndsAt),
    'lastClassEndEpochMillis': _millis(lastClassEndsAt),
    'classXp': classXp,
    'allKept': allKept,
    if (attendedShort != null) 'attendedShort': attendedShort,
    'classes': [for (final entry in classes) entry.toJson()],
  };
}

/// One real class on a class day.
final class WidgetDayClass {
  const WidgetDayClass({
    required this.occurrenceKey,
    required this.courseCode,
    required this.title,
    required this.shortTitle,
    required this.kind,
    required this.place,
    required this.startLabel,
    required this.endLabel,
    required this.startsAt,
    required this.endsAt,
    required this.timeZoneId,
    required this.kept,
    required this.keptXp,
    required this.state,
    required this.markUrl,
  });

  final String occurrenceKey;
  final String courseCode;
  final String title;
  final String shortTitle;

  /// The meeting kind's name (`lecture`, `lab`, ...).
  final String kind;

  /// One short tag (`HLL 114`), from `classPlaceTag`.
  final String place;

  /// `10:20 AM`, in the timetable's zone.
  final String startLabel;
  final String endLabel;
  final DateTime startsAt;
  final DateTime endsAt;
  final String timeZoneId;
  final bool kept;

  /// XP this class paid when kept (its full-day bonus is on the day).
  final int keptXp;

  /// As of the snapshot's `generatedAt`. The widget works the live state out
  /// from the instants and [kept] for each timeline entry.
  final WidgetClassState state;

  /// `roomofdays://class-day/mark?occurrence=...&day=...` (class_day_links).
  final String markUrl;

  Map<String, dynamic> toJson() => {
    'occurrenceKey': occurrenceKey,
    'courseCode': courseCode,
    'title': title,
    'shortTitle': shortTitle,
    'kind': kind,
    'place': place,
    'startLabel': startLabel,
    'endLabel': endLabel,
    'startEpochMillis': _millis(startsAt),
    'endEpochMillis': _millis(endsAt),
    'timeZoneId': timeZoneId,
    'kept': kept,
    'keptXp': keptXp,
    'state': state.name,
    'markUrl': markUrl,
  };
}

final class WidgetQuestGlance {
  const WidgetQuestGlance({required this.id, required this.title});

  /// A deterministic opaque identity. Quest has a legacy title-owned model,
  /// so this remains stable across snapshots without exposing account data.
  final String id;
  final String title;

  Map<String, dynamic> toJson() => {'id': id, 'title': title};
}

abstract final class WidgetSnapshotBuilder {
  /// [state] supplies which classes are kept and the day's class XP. Without
  /// it every class reads as not kept.
  static WidgetSnapshot build({
    required Iterable<Quest> quests,
    required AcademicSchedule schedule,
    required DateTime now,
    GameState? state,
  }) {
    final instant = now.toUtc();
    final local = now.toLocal();
    final questsDayEnds = DateTime(local.year, local.month, local.day + 1);
    final nextDayEnds = DateTime(local.year, local.month, local.day + 2);
    final classDays = _classDays(schedule, now, state);
    final upcomingClasses = _upcomingClasses(schedule, instant);
    final boundaries = <DateTime>{
      for (final day in classDays) ...[
        for (final entry in day.classes) ...[entry.startsAt, entry.endsAt],
        day.eveningStartsAt,
        day.nightEndsAt,
      ],
      for (final glance in upcomingClasses)
        DateTime.fromMillisecondsSinceEpoch(glance.endEpochMillis, isUtc: true),
      questsDayEnds.toUtc(),
      nextDayEnds.toUtc(),
    }.where((boundary) => boundary.isAfter(instant)).toList()..sort();
    return WidgetSnapshot(
      generatedAt: now,
      upcomingClasses: List.unmodifiable(upcomingClasses),
      incompleteQuests: List.unmodifiable(_openQuests(quests, now, now)),
      questsDayEndsAt: questsDayEnds.toUtc(),
      nextDayQuests: List.unmodifiable(
        _openQuests(_afterRollover(quests, questsDayEnds), questsDayEnds, now),
      ),
      nextDayEndsAt: nextDayEnds.toUtc(),
      classDays: List.unmodifiable(classDays),
      boundaries: List.unmodifiable(
        boundaries.take(roomOfDaysWidgetBoundaryLimit),
      ),
    );
  }

  /// Up to three open quests for [day] in practical order. [reference] is the
  /// instant an event is judged overdue against.
  static List<WidgetQuestGlance> _openQuests(
    Iterable<Quest> quests,
    DateTime day,
    DateTime reference,
  ) {
    final instant = (day.isAfter(reference) ? day : reference).toUtc();
    final open = planningQuestsForDay(
      quests,
      day,
    ).where((quest) => !quest.allDay).toList(growable: false);
    final sourceOrder = <Quest, int>{
      for (var index = 0; index < open.length; index++) open[index]: index,
    };
    open.sort((a, b) {
      int tier(Quest quest) {
        if (quest.isEvent && quest.dueDate!.isBefore(instant)) return 0;
        if (quest.isEvent) return 1;
        if (quest.priorityOn(day)) return 2;
        if (quest.bonus) return 4;
        return 3;
      }

      final byTier = tier(a).compareTo(tier(b));
      if (byTier != 0) return byTier;
      final byRank = a.priorityRankOn(day).compareTo(b.priorityRankOn(day));
      if (byRank != 0) return byRank;
      if (a.dread != b.dread) return a.dread ? 1 : -1;
      final byDifficulty = a.difficulty.compareTo(b.difficulty);
      if (byDifficulty != 0) return byDifficulty;
      final byTitle = a.displayTitle.toLowerCase().compareTo(
        b.displayTitle.toLowerCase(),
      );
      if (byTitle != 0) return byTitle;
      return sourceOrder[a]!.compareTo(sourceOrder[b]!);
    });

    final seen = <String>{};
    final selected = <WidgetQuestGlance>[];
    for (final quest in open) {
      final id = _questId(quest);
      if (!seen.add(id)) continue;
      selected.add(WidgetQuestGlance(id: id, title: quest.displayTitle));
      if (selected.length == 3) break;
    }
    return selected;
  }

  /// The quests the app keeps through its rollover into the day starting at
  /// [dayStart] (GameState.rollover): a finished one-off and an unfinished
  /// momentum bonus from an earlier day are gone by then.
  static Iterable<Quest> _afterRollover(
    Iterable<Quest> quests,
    DateTime dayStart,
  ) {
    final today = Days.key(dayStart);
    return quests.where(
      (quest) =>
          !(quest.schedule == QuestSchedule.once &&
              quest.lastDoneDay != null &&
              quest.lastDoneDay != today) &&
          !(quest.bonus &&
              quest.dueDate != null &&
              quest.dueDate!.isBefore(dayStart)),
    );
  }

  static List<WidgetClassDay> _classDays(
    AcademicSchedule schedule,
    DateTime now,
    GameState? state,
  ) {
    if (schedule.occurrences.isEmpty) return const [];
    final first = projectClassDay(schedule, now);
    final days = <WidgetClassDay>[];
    void add(ClassDay day) {
      final built = _classDay(day, now, state);
      if (built != null) days.add(built);
    }

    add(first);
    for (var ahead = 1; ahead < roomOfDaysWidgetClassDayLimit; ahead++) {
      add(projectClassDay(schedule, now, day: first.date.addDays(ahead)));
    }
    return days;
  }

  static WidgetClassDay? _classDay(
    ClassDay day,
    DateTime now,
    GameState? state,
  ) {
    if (!day.isClassDay) return null;
    final zone = day.classes.first.timeZoneId;
    final lastEnd = day.lastClassEnd!;
    final startsAt =
        classNightEndFor(day.date.addDays(-1), zone) ??
        DateTime(day.date.year, day.date.month, day.date.day, 4).toUtc();
    final nightEndsAt =
        classNightEndFor(day.date, zone) ??
        DateTime(day.date.year, day.date.month, day.date.day + 1, 4).toUtc();
    final eveningHour = _localInstant(
      day.date,
      roomOfDaysWidgetEveningHour * 60,
      zone,
    );
    var evening = lastEnd.add(roomOfDaysWidgetAfterClassHold);
    if (eveningHour.isAfter(evening)) evening = eveningHour;
    if (evening.isAfter(nightEndsAt)) evening = nightEndsAt;

    final classes = <WidgetDayClass>[];
    for (final entry in day.classes) {
      final kept = state?.keptClassFor(entry.facts);
      final moment = entry.momentAt(now);
      classes.add(
        WidgetDayClass(
          occurrenceKey: entry.occurrenceKey,
          courseCode: entry.courseCode,
          title: entry.title,
          shortTitle: shortClassLabel(entry.title, fits: _shortTitleFits),
          kind: entry.kind.name,
          place: classPlaceTag(entry),
          startLabel: classTimeLabel(entry.localStartMinute),
          endLabel: classTimeLabel(entry.localEndMinute),
          startsAt: entry.startsAt.toUtc(),
          endsAt: entry.endsAt.toUtc(),
          timeZoneId: entry.timeZoneId,
          kept: kept != null,
          keptXp: kept?.xp ?? 0,
          state: kept != null
              ? WidgetClassState.kept
              : switch (moment) {
                  ClassMoment.upcoming ||
                  ClassMoment.startsSoon => WidgetClassState.upcoming,
                  ClassMoment.inSession => WidgetClassState.inSession,
                  ClassMoment.ended => WidgetClassState.waiting,
                },
          markUrl: classDayMarkUrl(entry.occurrenceKey, day.dayKey),
        ),
      );
    }
    final counted = [
      for (var index = 0; index < day.classes.length; index++)
        if (day.classes[index].countsTowardDay) classes[index],
    ];
    final allKept = counted.isNotEmpty && counted.every((entry) => entry.kept);
    final keptCount = classes.where((entry) => entry.kept).length;
    final weekday = _weekdays[day.date.weekday - 1];
    return WidgetClassDay(
      dayKey: day.dayKey,
      weekday: weekday,
      startsAt: startsAt,
      eveningStartsAt: evening,
      nightEndsAt: nightEndsAt,
      lastClassEndsAt: lastEnd.toUtc(),
      classXp: state?.classXpForDay(day.dayKey) ?? 0,
      allKept: allKept,
      attendedShort: allKept ? attendedShort(keptCount) : null,
      classes: List.unmodifiable(classes),
    );
  }

  /// The quiet line for a day whose classes are all kept. Only ever true
  /// words: no count of anything left unmarked.
  static String attendedShort(int kept) => switch (kept) {
    1 => 'Attended',
    2 => 'Both attended',
    3 => 'All three attended',
    _ => 'All attended',
  };

  static DateTime _localInstant(CivilDate date, int minute, String zone) {
    try {
      final (start, _) = OccurrenceMaterializer.resolveInstants(
        date,
        minute,
        minute,
        zone,
      );
      return start.toUtc();
    } catch (_) {
      return DateTime(
        date.year,
        date.month,
        date.day,
      ).add(Duration(minutes: minute)).toUtc();
    }
  }

  static List<WidgetClassGlance> _upcomingClasses(
    AcademicSchedule schedule,
    DateTime nowUtc,
  ) {
    final occurrences =
        schedule.occurrences
            .where((item) {
              final course = schedule.courseById(item.courseId);
              return item.state != OccurrenceState.cancelled &&
                  item.tombstonedAt == null &&
                  course != null &&
                  !course.archived &&
                  !item.endInstant.toUtc().isBefore(nowUtc);
            })
            .toList(growable: false)
          ..sort(
            (a, b) => a.startInstant.toUtc().compareTo(b.startInstant.toUtc()),
          );
    final selected = <WidgetClassGlance>[];
    for (final occurrence in occurrences) {
      final course = schedule.courseById(occurrence.courseId);
      if (course == null) continue;
      final start = OccurrenceMaterializer.localTime(
        occurrence.startInstant,
        occurrence.timeZoneId,
      );
      final end = OccurrenceMaterializer.localTime(
        occurrence.endInstant,
        occurrence.timeZoneId,
      );
      selected.add(
        WidgetClassGlance(
          courseCode: course.code,
          courseTitle: course.title,
          startLocal: start.toIso8601String(),
          endLocal: end.toIso8601String(),
          startEpochMillis: occurrence.startInstant
              .toUtc()
              .millisecondsSinceEpoch,
          endEpochMillis: occurrence.endInstant.toUtc().millisecondsSinceEpoch,
          timeZoneId: occurrence.timeZoneId,
          occurrenceKey: occurrence.occurrenceKey,
          dayKey: occurrence.date.toString(),
          dayLabel: _dayLabel(occurrence, nowUtc),
          shortTitle: shortClassLabel(course.title, fits: _shortTitleFits),
        ),
      );
      if (selected.length == roomOfDaysWidgetClassLimit) break;
    }
    return selected;
  }

  /// `WED` when the class is within six days of now (so the weekday cannot
  /// be mistaken for a later one), else `NOV 30`. Fixed to the class's date.
  static String _dayLabel(ClassOccurrence occurrence, DateTime nowUtc) {
    final date = occurrence.date;
    final nowThere = OccurrenceMaterializer.localTime(
      nowUtc,
      occurrence.timeZoneId,
    );
    final today = CivilDate(nowThere.year, nowThere.month, nowThere.day);
    final away = date.dateArithmeticValue
        .difference(today.dateArithmeticValue)
        .inDays;
    if (away >= 0 && away <= 6) return _weekdayShort[date.weekday - 1];
    return '${_monthShort[date.month - 1]} ${date.day}';
  }

  static String _questId(Quest quest) {
    final identity = [
      quest.title,
      quest.origin ?? '',
      quest.goalTitle ?? '',
      quest.schedule.name,
    ].join('|');
    return sha256
        .convert(utf8.encode('room-of-days-quest|$identity'))
        .toString();
  }
}

/// Titles longer than this many characters are shortened for the widget's
/// rows (`Linear Systems & Signals` reads `Linear Systems`).
const _shortTitleFits = 20;

int _millis(DateTime instant) => instant.toUtc().millisecondsSinceEpoch;

const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

const _weekdayShort = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

const _monthShort = [
  'JAN',
  'FEB',
  'MAR',
  'APR',
  'MAY',
  'JUN',
  'JUL',
  'AUG',
  'SEP',
  'OCT',
  'NOV',
  'DEC',
];
