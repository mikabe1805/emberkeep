import 'package:shared_preferences/shared_preferences.dart';

import '../../clock.dart';
import '../../daybook/domain/civil_date.dart';

enum AcademicCalendarMode {
  month('MONTH', 1),
  week('WEEK', 7),
  threeDay('3 DAYS', 3),
  day('DAY', 1);

  const AcademicCalendarMode(this.label, this.spanDays);
  final String label;
  final int spanDays;
}

final class AcademicCalendarViewState {
  const AcademicCalendarViewState({
    required this.mode,
    this.selectedDate,
    this.threeDayStartDate,
  });

  final AcademicCalendarMode mode;
  final String? selectedDate;
  final String? threeDayStartDate;
}

abstract interface class AcademicCalendarPreferences {
  Future<AcademicCalendarViewState> load();
  Future<void> save(AcademicCalendarViewState state);
}

/// What Plans remembers between visits: its view (DAY, WEEK or MONTH) for good,
/// and the day it was on only for the day it was chosen. A new day opens on
/// today, so a Sunday left selected on Sunday never greets Monday.
final class LocalAcademicCalendarPreferences
    implements AcademicCalendarPreferences {
  static const _modeKey = 'room_of_days_academic_calendar_mode_v1';
  static const _dateKey = 'room_of_days_academic_calendar_date_v1';
  static const _threeDayStartKey =
      'room_of_days_academic_calendar_three_day_start_v1';

  /// The day the dates above were saved on.
  static const _savedOnKey = 'room_of_days_academic_calendar_saved_on_v1';

  static String _today() => CivilDate.fromDateTime(Clock.now()).toString();

  @override
  Future<AcademicCalendarViewState> load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final rawMode = preferences.getString(_modeKey);
      final mode = AcademicCalendarMode.values.firstWhere(
        (candidate) => candidate.name == rawMode,
        // Plans opens on today's page of the daybook until a view is chosen.
        orElse: () => AcademicCalendarMode.day,
      );
      // A day chosen on an earlier day is not today's page: a new day opens
      // Plans on today. A save with no stamp was made before this rule and
      // is read the same way, since there is no telling which day it was.
      final fresh = preferences.getString(_savedOnKey) == _today();
      return AcademicCalendarViewState(
        mode: mode,
        selectedDate: fresh ? preferences.getString(_dateKey) : null,
        threeDayStartDate: fresh
            ? preferences.getString(_threeDayStartKey)
            : null,
      );
    } catch (_) {
      return const AcademicCalendarViewState(mode: AcademicCalendarMode.day);
    }
  }

  @override
  Future<void> save(AcademicCalendarViewState state) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await Future.wait([
        preferences.setString(_modeKey, state.mode.name),
        if (state.selectedDate != null)
          preferences.setString(_dateKey, state.selectedDate!),
        if (state.threeDayStartDate != null)
          preferences.setString(_threeDayStartKey, state.threeDayStartDate!),
        preferences.setString(_savedOnKey, _today()),
      ]);
    } catch (_) {
      // View preferences are non-essential; schedule content is not touched.
    }
  }
}

final class InMemoryAcademicCalendarPreferences
    implements AcademicCalendarPreferences {
  InMemoryAcademicCalendarPreferences({
    this.state = const AcademicCalendarViewState(
      mode: AcademicCalendarMode.month,
    ),
  });

  AcademicCalendarViewState state;

  @override
  Future<AcademicCalendarViewState> load() async => state;

  @override
  Future<void> save(AcademicCalendarViewState state) async {
    this.state = state;
  }
}
