import 'package:emberkeep/academic_calendar/domain/academic_schedule.dart'
    hide CivilDate;
import 'package:emberkeep/daybook/adapters/campus_place_adapter.dart';
import 'package:emberkeep/daybook/domain/civil_date.dart';
import 'package:emberkeep/daybook/domain/daybook_event.dart';
import 'package:emberkeep/daybook/domain/daybook_place.dart';
import 'package:emberkeep/daybook/domain/daybook_task.dart';
import 'package:emberkeep/models.dart';

enum DaybookSourceKind {
  event,
  task,
  classOccurrence,
  academicWork,
  studyBlock,
  questPlan,
}

enum DaybookSection { allDay, timed, due, stillOpen }

enum DaybookDayWeight { none, light, moderate, full }

final class DaybookConflict {
  const DaybookConflict(
    this.leftDisplayKey,
    this.rightDisplayKey,
    this.message,
  );

  final String leftDisplayKey;
  final String rightDisplayKey;
  final String message;
}

final class DaybookEntry {
  const DaybookEntry({
    required this.displayKey,
    required this.sourceKind,
    required this.sourceId,
    required this.title,
    required this.section,
    this.startMinute,
    this.endMinute,
    this.completed = false,
    this.cancelled = false,
    this.moved = false,
    this.place,
    this.sourceLabel,
    this.supportingText,
    this.accentColorValue,
    this.adjustable = false,
    this.transitionPressure = false,
    this.transitionBufferMinutes,
    this.plannedStudyMinutes,
    this.targetStudyMinutes,
    required this.action,
  });

  final String displayKey;
  final DaybookSourceKind sourceKind;
  final String sourceId;
  final String title;
  final DaybookSection section;
  final int? startMinute;
  final int? endMinute;
  final bool completed;
  final bool cancelled;
  final bool moved;
  final DaybookPlace? place;
  final String? sourceLabel;
  final String? supportingText;
  final int? accentColorValue;
  final bool adjustable;
  final bool transitionPressure;
  final int? transitionBufferMinutes;
  final int? plannedStudyMinutes;
  final int? targetStudyMinutes;
  final DaybookActionTarget action;
}

final class DaybookDaySummary {
  const DaybookDaySummary({
    required this.scheduledMinutes,
    required this.weight,
    required this.hasDeadline,
    required this.conflicts,
    required this.semanticLabel,
  });

  final int scheduledMinutes;
  final DaybookDayWeight weight;
  final bool hasDeadline;
  final List<DaybookConflict> conflicts;
  final String semanticLabel;
}

final class DaybookDay {
  const DaybookDay({
    required this.date,
    required this.entries,
    required this.summary,
  });

  final CivilDate date;
  final List<DaybookEntry> entries;
  final DaybookDaySummary summary;
}

final class DaybookRange {
  const DaybookRange({
    required this.first,
    required this.last,
    required this.days,
  });

  final CivilDate first;
  final CivilDate last;
  final Map<CivilDate, DaybookDay> days;

  DaybookDay dayOn(CivilDate date) {
    final day = days[date];
    if (day == null) throw ArgumentError.value(date, 'date');
    return day;
  }
}

sealed class DaybookActionTarget {
  const DaybookActionTarget();
}

final class DaybookEventAction extends DaybookActionTarget {
  const DaybookEventAction(this.eventId, this.occurrenceKey);

  final String eventId;
  final String occurrenceKey;
}

final class DaybookTaskAction extends DaybookActionTarget {
  const DaybookTaskAction(this.taskId);

  final String taskId;
}

final class AcademicOccurrenceAction extends DaybookActionTarget {
  const AcademicOccurrenceAction(this.occurrenceKey);

  final String occurrenceKey;
}

final class AcademicWorkAction extends DaybookActionTarget {
  const AcademicWorkAction(this.workId);

  final String workId;
}

final class AcademicStudyAction extends DaybookActionTarget {
  const AcademicStudyAction(this.studyBlockId);

  final String studyBlockId;
}

final class QuestPlanAction extends DaybookActionTarget {
  const QuestPlanAction(this.questTitle);

  final String questTitle;
}

/// Builds a read-only, range-bounded view of every calendar source.
abstract final class DaybookRangeProjection {
  static DaybookRange build({
    required AcademicSchedule schedule,
    required List<Quest> quests,
    required CivilDate first,
    required CivilDate last,
    required DateTime now,
  }) {
    if (first.compareTo(last) > 0) {
      throw ArgumentError('The daybook range must start before it ends');
    }

    final byDate = <CivilDate, List<DaybookEntry>>{
      for (var date = first; date.compareTo(last) <= 0; date = date.addDays(1))
        date: <DaybookEntry>[],
    };
    final currentDate = CivilDate.fromDateTime(now);

    _addEvents(schedule, first, last, byDate);
    _addClasses(schedule, first, last, byDate);
    _addStudyBlocks(schedule, first, last, byDate);
    _addDueItems(schedule, first, last, currentDate, byDate);
    _addQuestPlans(quests, first, last, currentDate, byDate);
    final questMinutesByTitle = {
      for (final quest in quests)
        quest.title: quest.effectiveTimerMinutes > 0
            ? quest.effectiveTimerMinutes
            : 60,
    };

    final days = <CivilDate, DaybookDay>{
      for (final entry in byDate.entries)
        entry.key: _buildDay(
          entry.key,
          entry.value,
          schedule,
          questMinutesByTitle,
        ),
    };
    return DaybookRange(first: first, last: last, days: Map.unmodifiable(days));
  }

  static void _addEvents(
    AcademicSchedule schedule,
    CivilDate first,
    CivilDate last,
    Map<CivilDate, List<DaybookEntry>> byDate,
  ) {
    final eventsById = {
      for (final event in schedule.events) event.eventId: event,
    };
    // Timed events can cross one midnight and all-day events may span several
    // days. Widening the materialization query by the source's longest
    // duration keeps a range view complete without storing occurrences.
    final occurrences = schedule
        .eventOccurrencesBetween(
          first.addDays(-_eventLookbackDays(schedule.events)),
          last,
        )
        .toList();
    final occurrenceKeys = {
      for (final occurrence in occurrences) occurrence.occurrenceKey,
    };
    for (final event in schedule.events) {
      for (final exception in event.exceptions) {
        if (exception.state != DaybookEventOccurrenceState.moved) continue;
        final occurrence = event
            .occurrenceFor(exception.originalDate)
            .copyWith(
              occurrenceKey: '${event.eventId}@${exception.originalDate}',
            );
        if (_overlapsRange(occurrence, first, last) &&
            occurrenceKeys.add(occurrence.occurrenceKey)) {
          occurrences.add(occurrence);
        }
      }
    }
    for (final occurrence in occurrences) {
      final event = eventsById[occurrence.eventId];
      final eventTitle = event?.title ?? 'Event';
      final sourceLabel = event?.weeklyRule == null ? 'EVENT' : 'WEEKLY EVENT';
      final moved = occurrence.state == DaybookEventOccurrenceState.moved;
      final cancelled =
          occurrence.state == DaybookEventOccurrenceState.cancelled;
      if (occurrence.allDay) {
        for (
          var date = occurrence.startDate;
          date.compareTo(occurrence.endDate) < 0;
          date = date.addDays(1)
        ) {
          final items = byDate[date];
          if (items == null) continue;
          items.add(
            DaybookEntry(
              displayKey: 'event:${occurrence.occurrenceKey}',
              sourceKind: DaybookSourceKind.event,
              sourceId: occurrence.eventId,
              title: eventTitle,
              section: DaybookSection.allDay,
              cancelled: cancelled,
              moved: moved,
              place: event?.place,
              sourceLabel: sourceLabel,
              action: DaybookEventAction(
                occurrence.eventId,
                occurrence.occurrenceKey,
              ),
            ),
          );
        }
        continue;
      }

      for (
        var date = occurrence.startDate;
        date.compareTo(occurrence.endDate) <= 0;
        date = date.addDays(1)
      ) {
        final isStart = date == occurrence.startDate;
        final isEnd = date == occurrence.endDate;
        if (isEnd && !isStart && occurrence.endMinute == 0) continue;
        final items = byDate[date];
        if (items == null) continue;
        items.add(
          DaybookEntry(
            displayKey: 'event:${occurrence.occurrenceKey}',
            sourceKind: DaybookSourceKind.event,
            sourceId: occurrence.eventId,
            title: eventTitle,
            section: DaybookSection.timed,
            startMinute: isStart ? occurrence.startMinute : 0,
            endMinute: isEnd ? occurrence.endMinute : 24 * 60,
            cancelled: cancelled,
            moved: moved,
            place: event?.place,
            sourceLabel: sourceLabel,
            action: DaybookEventAction(
              occurrence.eventId,
              occurrence.occurrenceKey,
            ),
          ),
        );
      }
    }
  }

  static int _eventLookbackDays(Iterable<DaybookEvent> events) {
    var longest = 1;
    for (final event in events) {
      if (!event.allDay) continue;
      final spans = <(CivilDate, CivilDate)>[
        (event.startDate, event.endDate),
        for (final exception in event.exceptions)
          if (exception.state == DaybookEventOccurrenceState.moved)
            (exception.movedStartDate!, exception.movedEndDate!),
      ];
      for (final span in spans) {
        final duration = span.$2.dateArithmeticValue
            .difference(span.$1.dateArithmeticValue)
            .inDays;
        if (duration > longest) longest = duration;
      }
    }
    return longest;
  }

  static bool _overlapsRange(
    DaybookEventOccurrence occurrence,
    CivilDate first,
    CivilDate last,
  ) => occurrence.allDay
      ? occurrence.startDate.compareTo(last) <= 0 &&
            occurrence.endDate.compareTo(first) > 0
      : occurrence.startDate.compareTo(last) <= 0 &&
            occurrence.endDate.compareTo(first) >= 0;

  static void _addClasses(
    AcademicSchedule schedule,
    CivilDate first,
    CivilDate last,
    Map<CivilDate, List<DaybookEntry>> byDate,
  ) {
    for (final occurrence in schedule.occurrencesBetween(first, last)) {
      final course = schedule.courseById(occurrence.courseId);
      final series = schedule.meetingSeriesById(occurrence.meetingSeriesId);
      final enabledReminders = occurrence.reminders
          .where((reminder) => reminder.enabled)
          .toList();
      final transitionPressure = schedule
          .transitionPressuresOn(occurrence.date)
          .any((pressure) => pressure.includes(occurrence.occurrenceKey));
      byDate[occurrence.date]!.add(
        DaybookEntry(
          displayKey: 'class:${occurrence.occurrenceKey}',
          sourceKind: DaybookSourceKind.classOccurrence,
          sourceId: occurrence.occurrenceKey,
          title: course?.code ?? 'Class',
          section: DaybookSection.timed,
          startMinute: occurrence.localStartMinute,
          endMinute: occurrence.localEndMinute,
          cancelled: occurrence.state == OccurrenceState.cancelled,
          moved: occurrence.state == OccurrenceState.moved,
          place: CampusPlaceDaybookAdapter.fromCampusPlace(occurrence.place),
          sourceLabel:
              '${course?.code ?? 'CLASS'} · ${occurrence.kind.shortLabel}',
          supportingText: enabledReminders.isEmpty
              ? 'reminders off'
              : '${enabledReminders.first.offsetMinutes} min reminder',
          accentColorValue: course?.colorValue,
          adjustable: occurrence.canAdjust,
          transitionPressure: transitionPressure,
          transitionBufferMinutes: series?.transitionBufferMinutes ?? 10,
          action: AcademicOccurrenceAction(occurrence.occurrenceKey),
        ),
      );
    }
  }

  static void _addStudyBlocks(
    AcademicSchedule schedule,
    CivilDate first,
    CivilDate last,
    Map<CivilDate, List<DaybookEntry>> byDate,
  ) {
    final workById = {for (final item in schedule.workItems) item.workId: item};
    for (final block in schedule.studyBlocksBetween(first, last)) {
      final work = workById[block.workId];
      final course = schedule.courseById(work?.courseId ?? '');
      byDate[block.date]!.add(
        DaybookEntry(
          displayKey: 'study:${block.studyBlockId}',
          sourceKind: DaybookSourceKind.studyBlock,
          sourceId: block.studyBlockId,
          title: work?.title ?? 'Study block',
          section: DaybookSection.timed,
          startMinute: block.startMinute,
          endMinute: block.endMinute,
          completed: block.completed,
          sourceLabel: '${course?.code ?? 'COURSE'} · STUDY',
          supportingText: '${block.durationMinutes} min',
          accentColorValue: course?.colorValue,
          action: AcademicStudyAction(block.studyBlockId),
        ),
      );
    }
  }

  static void _addDueItems(
    AcademicSchedule schedule,
    CivilDate first,
    CivilDate last,
    CivilDate currentDate,
    Map<CivilDate, List<DaybookEntry>> byDate,
  ) {
    for (final task in schedule.tasks) {
      final entry = _taskEntry(task, DaybookSection.due);
      if (task.dueDate.isWithin(first, last)) byDate[task.dueDate]!.add(entry);
      if (!task.completed && task.dueDate.compareTo(currentDate) < 0) {
        byDate[currentDate]?.add(_taskEntry(task, DaybookSection.stillOpen));
      }
    }
    for (final item in schedule.workItemsBetween(first, last)) {
      final course = schedule.courseById(item.courseId);
      final studyPlan = schedule.studyPlanFor(item.workId);
      byDate[item.dueDate]!.add(
        DaybookEntry(
          displayKey: 'work:${item.workId}',
          sourceKind: DaybookSourceKind.academicWork,
          sourceId: item.workId,
          title: item.title,
          section: DaybookSection.due,
          startMinute: item.dueMinute,
          completed: item.completed,
          sourceLabel: '${course?.code ?? 'COURSE'} · ${item.kind.shortLabel}',
          supportingText: item.details,
          accentColorValue: course?.colorValue,
          plannedStudyMinutes: schedule.plannedStudyMinutesFor(item.workId),
          targetStudyMinutes: studyPlan?.totalMinutes,
          action: AcademicWorkAction(item.workId),
        ),
      );
    }
  }

  static DaybookEntry _taskEntry(DaybookTask task, DaybookSection section) =>
      DaybookEntry(
        displayKey: 'task:${task.taskId}',
        sourceKind: DaybookSourceKind.task,
        sourceId: task.taskId,
        title: task.title,
        section: section,
        startMinute: task.dueMinute,
        completed: task.completed,
        place: task.place,
        sourceLabel: 'TASK',
        action: DaybookTaskAction(task.taskId),
      );

  static void _addQuestPlans(
    List<Quest> quests,
    CivilDate first,
    CivilDate last,
    CivilDate currentDate,
    Map<CivilDate, List<DaybookEntry>> byDate,
  ) {
    for (var date = first; date.compareTo(last) <= 0; date = date.addDays(1)) {
      final dateTime = DateTime(date.year, date.month, date.day);
      final dateKey = Days.key(dateTime);
      for (final quest in quests) {
        if (quest.snoozedDay == dateKey ||
            !_questAppearsOn(quest, dateTime, currentDate)) {
          continue;
        }
        final dueMinute =
            quest.dueDate == null ||
                quest.allDay ||
                (quest.dueDate!.hour == 0 && quest.dueDate!.minute == 0)
            ? null
            : quest.dueDate!.hour * 60 + quest.dueDate!.minute;
        byDate[date]!.add(
          DaybookEntry(
            displayKey: 'quest:${quest.title}',
            sourceKind: DaybookSourceKind.questPlan,
            sourceId: quest.title,
            title: quest.displayTitle,
            section: quest.allDay ? DaybookSection.allDay : DaybookSection.due,
            startMinute: dueMinute,
            completed: quest.doneFor(dateTime),
            sourceLabel: 'QUEST PLAN',
            action: QuestPlanAction(quest.title),
          ),
        );
      }
    }
  }

  static bool _questAppearsOn(
    Quest quest,
    DateTime date,
    CivilDate currentDate,
  ) {
    if (quest.dueDate != null) {
      return CivilDate.fromDateTime(quest.dueDate!) ==
          CivilDate.fromDateTime(date);
    }
    if (quest.schedule != QuestSchedule.once) return quest.scheduledOn(date);
    return CivilDate.fromDateTime(date) == currentDate;
  }

  static DaybookDay _buildDay(
    CivilDate date,
    List<DaybookEntry> sourceEntries,
    AcademicSchedule schedule,
    Map<String, int> questMinutesByTitle,
  ) {
    final entries = List<DaybookEntry>.of(sourceEntries)..sort(_compareEntries);
    final timed = entries
        .where(
          (entry) => entry.section == DaybookSection.timed && !entry.cancelled,
        )
        .toList();
    var scheduledMinutes = timed.fold<int>(
      0,
      (total, entry) => total + entry.endMinute! - entry.startMinute!,
    );
    for (final entry in timed.where(
      (item) => item.sourceKind == DaybookSourceKind.classOccurrence,
    )) {
      final action = entry.action as AcademicOccurrenceAction;
      final occurrence = schedule.occurrenceByKey(action.occurrenceKey);
      if (occurrence != null) {
        scheduledMinutes +=
            schedule
                .meetingSeriesById(occurrence.meetingSeriesId)
                ?.transitionBufferMinutes ??
            0;
      }
    }
    for (final entry in entries.where(
      (item) =>
          item.sourceKind == DaybookSourceKind.questPlan && !item.completed,
    )) {
      final action = entry.action as QuestPlanAction;
      scheduledMinutes += questMinutesByTitle[action.questTitle] ?? 60;
    }

    final conflicts = _conflicts(timed);
    final hasDeadline = entries.any(
      (entry) =>
          (entry.section == DaybookSection.due ||
              entry.section == DaybookSection.stillOpen) &&
          !entry.completed,
    );
    final summary = DaybookDaySummary(
      scheduledMinutes: scheduledMinutes,
      weight: _weightFor(scheduledMinutes),
      hasDeadline: hasDeadline,
      conflicts: List.unmodifiable(conflicts),
      semanticLabel: _semanticLabel(
        date,
        entries,
        scheduledMinutes,
        hasDeadline,
        conflicts,
      ),
    );
    return DaybookDay(
      date: date,
      entries: List.unmodifiable(entries),
      summary: summary,
    );
  }

  static List<DaybookConflict> _conflicts(List<DaybookEntry> timed) {
    final conflicts = <DaybookConflict>[];
    for (var leftIndex = 0; leftIndex < timed.length; leftIndex++) {
      for (
        var rightIndex = leftIndex + 1;
        rightIndex < timed.length;
        rightIndex++
      ) {
        final left = timed[leftIndex];
        final right = timed[rightIndex];
        if (left.startMinute! < right.endMinute! &&
            right.startMinute! < left.endMinute!) {
          conflicts.add(
            DaybookConflict(
              left.displayKey,
              right.displayKey,
              '${left.title} overlaps ${right.title}',
            ),
          );
        }
      }
    }
    return conflicts;
  }

  static int _compareEntries(DaybookEntry left, DaybookEntry right) {
    final section = left.section.index.compareTo(right.section.index);
    if (section != 0) return section;
    if (left.section == DaybookSection.timed) {
      final minute = left.startMinute!.compareTo(right.startMinute!);
      if (minute != 0) return minute;
    } else if (left.section == DaybookSection.due) {
      final leftTimed = left.startMinute != null;
      final rightTimed = right.startMinute != null;
      if (leftTimed != rightTimed) return leftTimed ? -1 : 1;
      if (leftTimed) {
        final minute = left.startMinute!.compareTo(right.startMinute!);
        if (minute != 0) return minute;
      }
      final title = left.title.compareTo(right.title);
      if (title != 0) return title;
    } else {
      final title = left.title.compareTo(right.title);
      if (title != 0) return title;
    }
    return left.displayKey.compareTo(right.displayKey);
  }

  static DaybookDayWeight _weightFor(int scheduledMinutes) =>
      switch (scheduledMinutes) {
        0 => DaybookDayWeight.none,
        < 120 => DaybookDayWeight.light,
        < 240 => DaybookDayWeight.moderate,
        _ => DaybookDayWeight.full,
      };

  static String _semanticLabel(
    CivilDate date,
    List<DaybookEntry> entries,
    int scheduledMinutes,
    bool hasDeadline,
    List<DaybookConflict> conflicts,
  ) {
    final labels = <String>[];
    for (final kind in DaybookSourceKind.values) {
      final count = entries.where((entry) => entry.sourceKind == kind).length;
      if (count == 0) continue;
      labels.add(_sourceCountLabel(kind, count));
    }
    if (hasDeadline) labels.add('deadline');
    if (scheduledMinutes > 0) labels.add('$scheduledMinutes scheduled minutes');
    if (conflicts.isNotEmpty) {
      labels.add(
        '${conflicts.length} ${conflicts.length == 1 ? 'conflict' : 'conflicts'}',
      );
    }
    return labels.isEmpty
        ? '$date: no daybook items'
        : '$date: ${labels.join(', ')}';
  }

  static String _sourceCountLabel(DaybookSourceKind kind, int count) {
    final noun = switch (kind) {
      DaybookSourceKind.event => 'event',
      DaybookSourceKind.task => 'task',
      DaybookSourceKind.classOccurrence => 'class',
      DaybookSourceKind.academicWork => 'academic work item',
      DaybookSourceKind.studyBlock => 'study block',
      DaybookSourceKind.questPlan => 'quest plan',
    };
    return '$count $noun${count == 1 ? '' : 's'}';
  }
}
