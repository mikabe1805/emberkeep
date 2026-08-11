import 'package:shared_preferences/shared_preferences.dart';

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
  const AcademicCalendarViewState({required this.mode, this.selectedDate});

  final AcademicCalendarMode mode;
  final String? selectedDate;
}

abstract interface class AcademicCalendarPreferences {
  Future<AcademicCalendarViewState> load();
  Future<void> save(AcademicCalendarViewState state);
}

final class LocalAcademicCalendarPreferences
    implements AcademicCalendarPreferences {
  static const _modeKey = 'room_of_days_academic_calendar_mode_v1';
  static const _dateKey = 'room_of_days_academic_calendar_date_v1';

  @override
  Future<AcademicCalendarViewState> load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final rawMode = preferences.getString(_modeKey);
      final mode = AcademicCalendarMode.values.firstWhere(
        (candidate) => candidate.name == rawMode,
        orElse: () => AcademicCalendarMode.month,
      );
      return AcademicCalendarViewState(
        mode: mode,
        selectedDate: preferences.getString(_dateKey),
      );
    } catch (_) {
      return const AcademicCalendarViewState(mode: AcademicCalendarMode.month);
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
