/// The small, privacy-safe handoff shared with home-screen widgets.
///
/// This deliberately contains only a bounded run of upcoming class facts and
/// three actionable quest labels. The bounded class run lets WidgetKit advance
/// across class boundaries without persisting the full schedule or waiting for
/// the host app to reopen. It is not a second persistence model.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:emberkeep/academic_calendar/domain/academic_schedule.dart';
import 'package:emberkeep/content/day_planning.dart';
import 'package:emberkeep/models.dart';

const int roomOfDaysWidgetSnapshotVersion = 2;
const int roomOfDaysWidgetClassLimit = 24;

final class WidgetSnapshot {
  const WidgetSnapshot({
    required this.generatedAt,
    required this.upcomingClasses,
    required this.incompleteQuests,
  });

  final DateTime generatedAt;
  final List<WidgetClassGlance> upcomingClasses;
  final List<WidgetQuestGlance> incompleteQuests;

  WidgetClassGlance? get nextClass =>
      upcomingClasses.isEmpty ? null : upcomingClasses.first;

  Map<String, dynamic> toJson() => {
    'version': roomOfDaysWidgetSnapshotVersion,
    'generatedAt': generatedAt.toUtc().toIso8601String(),
    'upcomingClasses': [
      for (final classGlance in upcomingClasses) classGlance.toJson(),
    ],
    'incompleteQuests': [for (final quest in incompleteQuests) quest.toJson()],
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
  });

  final String courseCode;
  final String courseTitle;
  final String startLocal;
  final String endLocal;
  final int startEpochMillis;
  final int endEpochMillis;
  final String timeZoneId;

  Map<String, dynamic> toJson() => {
    'courseCode': courseCode,
    'courseTitle': courseTitle,
    'startLocal': startLocal,
    'endLocal': endLocal,
    'startEpochMillis': startEpochMillis,
    'endEpochMillis': endEpochMillis,
    'timeZoneId': timeZoneId,
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
  static WidgetSnapshot build({
    required Iterable<Quest> quests,
    required AcademicSchedule schedule,
    required DateTime now,
  }) {
    final instant = now.toUtc();
    final upcomingClasses = _upcomingClasses(schedule, instant);
    final open = planningQuestsForDay(
      quests,
      now,
    ).where((quest) => !quest.allDay).toList(growable: false);
    final sourceOrder = <Quest, int>{
      for (var index = 0; index < open.length; index++) open[index]: index,
    };
    open.sort((a, b) {
      int tier(Quest quest) {
        if (quest.isEvent && quest.dueDate!.isBefore(instant)) return 0;
        if (quest.isEvent) return 1;
        if (quest.priorityOn(now)) return 2;
        if (quest.bonus) return 4;
        return 3;
      }

      final byTier = tier(a).compareTo(tier(b));
      if (byTier != 0) return byTier;
      final byRank = a.priorityRankOn(now).compareTo(b.priorityRankOn(now));
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
    return WidgetSnapshot(
      generatedAt: now,
      upcomingClasses: List.unmodifiable(upcomingClasses),
      incompleteQuests: List.unmodifiable(selected),
    );
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
        ),
      );
      if (selected.length == roomOfDaysWidgetClassLimit) break;
    }
    return selected;
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
