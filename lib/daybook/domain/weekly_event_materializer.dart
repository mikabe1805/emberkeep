import 'civil_date.dart';
import 'daybook_event.dart';

/// Expands a weekly rule only inside an explicit inclusive date window.
abstract final class WeeklyEventMaterializer {
  static List<DaybookEventOccurrence> between(
    DaybookEvent event,
    CivilDate first,
    CivilDate last,
  ) {
    if (first.compareTo(last) > 0) {
      throw ArgumentError(
        'The materialization range must start before it ends',
      );
    }

    final originalDates = <CivilDate>{};
    final rule = event.weeklyRule;
    if (rule == null) {
      if (event.startDate.isWithin(first, last)) {
        originalDates.add(event.startDate);
      }
    } else {
      final anchor = event.startDate.startOfWeek(DateTime.monday);
      final rangeStart = event.startDate.compareTo(first) > 0
          ? event.startDate
          : first;
      final rangeEnd = rule.endsOn != null && rule.endsOn!.compareTo(last) < 0
          ? rule.endsOn!
          : last;
      for (
        var date = rangeStart;
        date.compareTo(rangeEnd) <= 0;
        date = date.addDays(1)
      ) {
        if (!rule.weekdays.contains(date.weekday)) continue;
        final dateWeek = date.startOfWeek(DateTime.monday);
        final weeksFromAnchor =
            dateWeek.dateArithmeticValue
                .difference(anchor.dateArithmeticValue)
                .inDays ~/
            7;
        if (weeksFromAnchor % rule.intervalWeeks == 0) {
          originalDates.add(date);
        }
      }
    }

    // A moved occurrence can enter the requested window from an original date
    // outside it. Exceptions are finite durable values, so inspecting them does
    // not turn recurrence expansion into an unbounded operation.
    for (final exception in event.exceptions) {
      if (exception.state == DaybookEventOccurrenceState.moved &&
          exception.movedStartDate!.isWithin(first, last)) {
        originalDates.add(exception.originalDate);
      }
    }

    final occurrences = <DaybookEventOccurrence>[];
    for (final originalDate in originalDates) {
      final occurrence = event
          .occurrenceFor(originalDate)
          .copyWith(
            occurrenceKey: '${event.eventId}@${originalDate.toString()}',
          );
      if (occurrence.startDate.isWithin(first, last)) {
        occurrences.add(occurrence);
      }
    }
    occurrences.sort(_compareOccurrences);
    return List.unmodifiable(occurrences);
  }
}

int _compareOccurrences(
  DaybookEventOccurrence left,
  DaybookEventOccurrence right,
) {
  final date = left.startDate.compareTo(right.startDate);
  if (date != 0) return date;
  final time = (left.startMinute ?? -1).compareTo(right.startMinute ?? -1);
  if (time != 0) return time;
  return left.occurrenceKey.compareTo(right.occurrenceKey);
}
