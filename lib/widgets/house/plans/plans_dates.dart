// Names of days and months, the daybook's way.
library;

import '../../../daybook/domain/civil_date.dart';

const plansWeekdayShort = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
const plansWeekdayLong = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];
const plansWeekdayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
const plansMonthShort = [
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
const plansMonthLong = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// "Tuesday, October 6", for a screen reader.
String plansSpokenDate(DateTime day, {bool today = false}) =>
    '${plansWeekdayLong[day.weekday - 1]}, '
    '${plansMonthLong[day.month - 1]} ${day.day}${today ? ', today' : ''}';

/// The heading over a day's chosen Quests: "TODAY’S FOCUS" on today's page,
/// plain "FOCUS" on any other (the page already names its day).
String plansFocusHeading(CivilDate day, CivilDate today) =>
    day == today ? 'TODAY’S FOCUS' : 'FOCUS';

/// What a chosen Quest's card says about its day: "CHOSEN FOR TODAY" on
/// today's page, "CHOSEN FOR TOMORROW" on tomorrow's, and the weekday
/// ("CHOSEN FOR SUN") on any other. Never "today" for a day that is not.
String plansChosenFor(CivilDate day, CivilDate today) {
  if (day == today) return 'CHOSEN FOR TODAY';
  if (day == today.addDays(1)) return 'CHOSEN FOR TOMORROW';
  return 'CHOSEN FOR ${plansWeekdayShort[day.weekday - 1]}';
}

/// [plansChosenFor], for a screen reader: "today’s focus", "chosen for
/// tomorrow", "chosen for Sunday".
String plansChosenForSpoken(CivilDate day, CivilDate today) {
  if (day == today) return 'today’s focus';
  if (day == today.addDays(1)) return 'chosen for tomorrow';
  return 'chosen for ${plansWeekdayLong[day.weekday - 1]}';
}
