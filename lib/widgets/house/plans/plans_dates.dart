// Names of days and months, the daybook's way.
library;

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
