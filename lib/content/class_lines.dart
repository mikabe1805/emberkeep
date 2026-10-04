import 'package:flutter/widgets.dart' show StringCharacters;

import '../academic_calendar/services/class_day_projection.dart';

// The words every surface uses to name a class: the night ledger, the
// Journal trace and the weekly chronicle read the same way. Classes are only
// ever named when they were kept; an unmarked class is never mentioned.

const _weekdays = [
  'MONDAY',
  'TUESDAY',
  'WEDNESDAY',
  'THURSDAY',
  'FRIDAY',
  'SATURDAY',
  'SUNDAY',
];

/// `8:30 AM`, `2:00 PM`, `12:15 PM` from minutes after midnight.
String classTimeLabel(int minute) {
  final clamped = minute.clamp(0, 24 * 60 - 1);
  final hour = clamped ~/ 60;
  final minutes = (clamped % 60).toString().padLeft(2, '0');
  final suffix = hour < 12 ? 'AM' : 'PM';
  final twelve = hour % 12 == 0 ? 12 : hour % 12;
  return '$twelve:$minutes $suffix';
}

/// A course title short enough to sit beside others on one line. A long
/// title drops a leading "Introduction to" ("Discrete Structures II"), then
/// keeps its first part before ` & `, `: `, ` - ` or ` and ` ("Computer
/// Architecture & Assembly Language" reads "Computer Architecture"). Titles
/// that already fit are never touched.
String shortClassLabel(String label, {int fits = 28}) {
  var clean = label.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (clean.characters.length <= fits) return clean;
  final intro = RegExp(r'^(introduction|intro\.?) to ', caseSensitive: false);
  final rest = clean.replaceFirst(intro, '');
  if (rest.length >= 6) clean = rest;
  if (clean.characters.length <= fits) return clean;
  for (final separator in const [' & ', ': ', ' - ', ' and ']) {
    final cut = clean.indexOf(separator);
    if (cut >= 8) return clean.substring(0, cut).trim();
  }
  return clean;
}

/// `1 class`, `3 classes`.
String classCountLabel(int count) =>
    '$count ${count == 1 ? 'class' : 'classes'}';

/// The Journal trace line for the classes a day kept, one label per kept
/// class: `2 classes · Computer Architecture, Discrete Structures II`. A
/// course that met twice counts twice and is named once. Empty when none
/// were kept.
String classesKeptLine(List<String> labels) {
  if (labels.isEmpty) return '';
  final names = {for (final label in labels) shortClassLabel(label)};
  return '${classCountLabel(labels.length)} · ${names.join(', ')}';
}

/// Where a class meets, as one short tag (`EE 103`), else its course code.
String classPlaceTag(ProjectedClass entry) {
  final place = entry.place;
  final parts = [
    for (final part in [place.building, place.room])
      if (part != null && part.trim().isNotEmpty) part.trim(),
  ];
  if (parts.isNotEmpty) return parts.join(' ');
  final label = place.label.trim();
  if (label.isNotEmpty && label.characters.length <= 18) return label;
  return entry.courseCode.trim();
}

/// A fixed line for tomorrow's tray: `WEDNESDAY · 8:30 AM · EE 103`.
String tomorrowClassTag(ProjectedClass entry) =>
    '${_weekdays[entry.date.weekday - 1]} · '
    '${classTimeLabel(entry.localStartMinute)} · ${classPlaceTag(entry)}';
