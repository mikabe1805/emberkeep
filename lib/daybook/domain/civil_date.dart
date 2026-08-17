/// A calendar date without an accidental device-time-zone interpretation.
final class CivilDate implements Comparable<CivilDate> {
  CivilDate(this.year, this.month, this.day) {
    final normalized = DateTime(year, month, day);
    if (normalized.year != year ||
        normalized.month != month ||
        normalized.day != day) {
      throw ArgumentError.value(toString(), 'date', 'Must be a valid date');
    }
  }

  factory CivilDate.fromDateTime(DateTime value) =>
      CivilDate(value.year, value.month, value.day);

  factory CivilDate.parse(String value) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
    if (match == null) {
      throw FormatException('Invalid civil date', value);
    }
    return CivilDate(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }

  final int year;
  final int month;
  final int day;

  /// UTC is intentional here: this value is only a Gregorian date-arithmetic
  /// carrier. A local midnight plus 24 hours can repeat or skip a civil date at
  /// a daylight-saving boundary.
  DateTime get dateArithmeticValue => DateTime.utc(year, month, day);
  int get weekday => dateArithmeticValue.weekday;

  CivilDate addDays(int days) =>
      CivilDate.fromDateTime(dateArithmeticValue.add(Duration(days: days)));

  CivilDate startOfWeek(int weekStartsOn) {
    if (weekStartsOn < DateTime.monday || weekStartsOn > DateTime.sunday) {
      throw ArgumentError.value(weekStartsOn, 'weekStartsOn');
    }
    final distance = (weekday - weekStartsOn + 7) % 7;
    return addDays(-distance);
  }

  bool isWithin(CivilDate first, CivilDate last) =>
      compareTo(first) >= 0 && compareTo(last) <= 0;

  @override
  int compareTo(CivilDate other) =>
      dateArithmeticValue.compareTo(other.dateArithmeticValue);

  @override
  bool operator ==(Object other) =>
      other is CivilDate &&
      year == other.year &&
      month == other.month &&
      day == other.day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';
}
