// The Doorway's tickets, as data: today's classes by the front door, which
// hook each attended one hangs on, the pairs in the bowl, the bundles on the
// shelf and how the rail lays out. Pure: it reads the timetable, the save's
// records and a moment, and writes nothing. The engine (GameState.keepClass,
// dismissClass) owns what a mark does.
//
// Never punish. A class he said he could not make is a ticket in the
// `dismissed` state that folds away; nothing here counts it, and no list,
// pair, bundle or tier is ever built from "of". A class that ended unmarked
// is `settled`, a quiet ticket with no state of shame; a week or a day is
// counted by what he attended, never by what he did not.
library;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/widgets.dart' show StringCharacters;

import '../../academic_calendar/domain/academic_schedule.dart';
import '../../academic_calendar/services/class_day_projection.dart';
import '../../engine.dart';
import 'class_day_model.dart';

/// The hooks by the door. Five; a day with more tickets shares them.
const int doorwayHookCount = 5;

/// What a ticket is, for its mark and its color.
enum DoorwayKind {
  lecture,
  lab,
  recitation,

  /// An optional meeting (office hours): it hangs and pays like a class, but
  /// the day is complete without it.
  optional,
}

/// Where a ticket is. The five states a ticket shows, plus [settled], an
/// over, unmarked class whose night has ended: it stays on the rail as a quiet
/// ticket and nothing counts it.
enum DoorwayTicketState {
  /// Later today (including the countdown before it starts).
  upcoming,

  /// Happening now and markable.
  inSession,

  /// Over, unmarked, and still markable until its night ends.
  ready,

  /// Kept: hangs on a hook.
  attended,

  /// Set aside with "Couldn't make it": folds away. Not part of the day.
  dismissed,

  /// Over and no longer markable. Quiet.
  settled,
}

/// How the rail lays its tickets out.
enum DoorwayRailTier {
  /// One to three counting tickets: roomy, the label and the room both show.
  full,

  /// Four or five: narrower tickets, one line of label.
  compact,

  /// Six or more: a stacked list, never a squeeze.
  stack,
}

/// The tier for [counting] tickets that count toward the day (zero reads as
/// [DoorwayRailTier.full]: an empty or optional-only day has room to spare).
DoorwayRailTier doorwayTierFor(int counting) => counting <= 3
    ? DoorwayRailTier.full
    : counting <= 5
    ? DoorwayRailTier.compact
    : DoorwayRailTier.stack;

/// The hook for each of [total] tickets, in ticket order. Up to five tickets
/// each take their own, spread across the five so a short day hangs in the
/// middle of the rail (1: the middle; 2: the second and fourth; 3: the first,
/// middle and last; 4: all but the middle); from six up the tickets share
/// hooks by position (`index % 5`). It depends only on the day's ticket
/// count and a ticket's place in it, so a hook never moves when a class is
/// kept, set aside or brought back.
List<int> doorwayHooksFor(int total) {
  if (total <= 0) return const [];
  return switch (total) {
    1 => const [2],
    2 => const [1, 3],
    3 => const [0, 2, 4],
    4 => const [0, 1, 3, 4],
    5 => const [0, 1, 2, 3, 4],
    _ => [for (var i = 0; i < total; i++) i % doorwayHookCount],
  };
}

// ── The label on a small ticket ───────────────────────────────────────────

/// The longest a ticket's label runs.
const int doorwayLabelMax = 12;

const _fillerWords = {
  'introduction',
  'intro',
  'to',
  'of',
  'the',
  'a',
  'an',
  'in',
  'for',
  'advanced',
  'intermediate',
  'fundamentals',
  'principles',
  'topics',
  'foundations',
  'survey',
  'applied',
  'general',
  'computer',
};

const _kindWords = {
  'lab',
  'laboratory',
  'recitation',
  'studio',
  'seminar',
  'lecture',
  'section',
};

final _numberWord = RegExp(r'^(?:[ivx]+|\d+[a-z]?)$', caseSensitive: false);

/// A course name as one short word (or two) in capitals, for a ticket that is
/// only a few dozen points wide: "ARCHITECTURE", "DISCRETE", "ELECTRONICS".
///
/// The rule, in order: cut at the first " & ", ": ", " - " or " and "; drop
/// leading filler ("Introduction to", "Computer", "Advanced"...) and trailing
/// kind words and numerals ("Lab", "II"), which the ticket's kind and the
/// course's own count already say; keep what is left when it fits [maxChars];
/// else keep its first word when that is long enough to read alone (five or
/// more letters), else its longest word; and never run past [maxChars]: a
/// word that is still too long is cut with an ellipsis. A title with nothing
/// left falls back to [courseCode], then to "CLASS".
String doorwayTicketLabel(
  String title, {
  String courseCode = '',
  int maxChars = doorwayLabelMax,
}) {
  var text = title.trim().replaceAll(RegExp(r'\s+'), ' ');
  for (final separator in const [' & ', ': ', ' - ', ' and ']) {
    final cut = text.indexOf(separator);
    if (cut >= 4) {
      text = text.substring(0, cut).trim();
      break;
    }
  }
  final words = [
    for (final word in text.split(' '))
      if (word.isNotEmpty) word,
  ];
  var first = 0;
  while (first < words.length - 1 &&
      _fillerWords.contains(words[first].toLowerCase())) {
    first++;
  }
  var last = words.length;
  while (last - 1 > first &&
      (_kindWords.contains(words[last - 1].toLowerCase()) ||
          _numberWord.hasMatch(words[last - 1]))) {
    last--;
  }
  final kept = words.sublist(first, last);
  String result;
  if (kept.isEmpty) {
    result = courseCode.trim();
  } else {
    final joined = kept.join(' ');
    if (joined.characters.length <= maxChars) {
      result = joined;
    } else {
      final lead = kept.first;
      if (lead.characters.length >= 5 || kept.length == 1) {
        result = lead;
      } else {
        // A short lead ("Data") says little alone: the longest word does.
        result = kept.reduce(
          (best, word) =>
              word.characters.length > best.characters.length ? word : best,
        );
      }
    }
  }
  if (result.isEmpty) result = 'class';
  if (result.characters.length > maxChars) {
    result = '${result.characters.take(maxChars - 1)}…';
  }
  return result.toUpperCase();
}

// ── Tickets ───────────────────────────────────────────────────────────────

/// One class by the door.
final class DoorwayTicket {
  const DoorwayTicket({
    required this.entry,
    required this.kind,
    required this.label,
    required this.state,
    this.hook,
    this.room,
  });

  /// The class this ticket is for (its facts are what the engine keeps).
  final ProjectedClass entry;
  final DoorwayKind kind;

  /// Short capitals for the ticket ([doorwayTicketLabel]).
  final String label;
  final DoorwayTicketState state;

  /// The hook an attended ticket hangs on (0 to 4); null for every other
  /// state. Stable for the day ([doorwayHooksFor]).
  final int? hook;

  /// "HLL 114": the building and room, else the campus place's label; null
  /// when the timetable names none.
  final String? room;

  /// The timetable occurrence's key: what a mark or a dismissal names.
  String get id => entry.occurrenceKey;

  ClassFacts get facts => entry.facts;

  /// Local start and end, minutes after midnight in the schedule's zone.
  int get startMinute => entry.localStartMinute;
  int get endMinute => entry.localEndMinute;

  /// A full day waits on it (office hours do not).
  bool get counts => kind != DoorwayKind.optional;

  /// "I was there" can be pressed for it now.
  bool get markable =>
      state == DoorwayTicketState.ready ||
      state == DoorwayTicketState.inSession;

  /// "Couldn't make it" is offered on it: a class that has not started, or is
  /// over and still open, never one he is sitting in or already kept.
  bool get canSetAside =>
      state == DoorwayTicketState.upcoming || state == DoorwayTicketState.ready;

  bool get folded => state == DoorwayTicketState.dismissed;
}

/// A past week's bundle on the shelf: a week of this term in which he went to
/// at least one class.
final class DoorwayShelfBundle {
  const DoorwayShelfBundle({required this.weekStart, required this.attended});

  /// The Monday of that week.
  final CivilDate weekStart;

  /// Classes attended that week (at least one). Counts up only.
  final int attended;
}

/// Today at the door.
final class DoorwayDay {
  const DoorwayDay({
    required this.date,
    required this.tickets,
    required this.bowlPairs,
    required this.shelfBundles,
  });

  /// Reads [date]'s day (the night-owned day of [now] when null) from the
  /// timetable and the save's records. [state] says which classes were kept
  /// and which were set aside. The week and the term come from the schedule.
  factory DoorwayDay.read(
    AcademicSchedule schedule,
    GameState state,
    DateTime now, {
    CivilDate? day,
  }) {
    ClassDay project(CivilDate date) => projectClassDay(
      schedule,
      now,
      day: date,
      isDismissed: state.isClassDismissed,
    );
    final date = day ?? classDayDateFor(schedule, now);
    return DoorwayDay.build(
      day: project(date),
      state: state,
      now: now,
      dayOf: project,
      term: schedule.termFor(date),
    );
  }

  /// Builds from an already projected [day] (with its set-aside classes in
  /// [ClassDay.dismissed]). [dayOf] projects any other day of the same
  /// timetable the same way, for the week's bowl; [term] bounds the shelf.
  factory DoorwayDay.build({
    required ClassDay day,
    required GameState state,
    required DateTime now,
    required ClassDay Function(CivilDate) dayOf,
    AcademicTerm? term,
  }) {
    // Whoever projected the days, a class he set aside is out of the set.
    final aside = state.isClassDismissed;
    day = day.withoutDismissed(aside);
    final project = dayOf;
    dayOf = (date) => project(date).withoutDismissed(aside);
    final card = ClassCard.read(day, state, now);
    final byIdentity = {for (final row in card.rows) row.entry: row};
    final every = day.everyClass;
    final hooks = doorwayHooksFor(every.length);
    final tickets = <DoorwayTicket>[];
    for (var i = 0; i < every.length; i++) {
      final entry = every[i];
      final row = byIdentity[entry];
      final ticketState = row == null
          ? DoorwayTicketState.dismissed
          : switch (row.state) {
              ClassRowState.kept => DoorwayTicketState.attended,
              ClassRowState.ready => DoorwayTicketState.ready,
              ClassRowState.inSession => DoorwayTicketState.inSession,
              ClassRowState.startsSoon ||
              ClassRowState.upcoming => DoorwayTicketState.upcoming,
              ClassRowState.settled => DoorwayTicketState.settled,
            };
      final place = classPlace(entry).trim();
      tickets.add(
        DoorwayTicket(
          entry: entry,
          kind: _kindOf(entry.kind),
          label: doorwayTicketLabel(entry.title, courseCode: entry.courseCode),
          state: ticketState,
          hook: ticketState == DoorwayTicketState.attended ? hooks[i] : null,
          room: place.isEmpty ? null : place,
        ),
      );
    }
    return DoorwayDay(
      date: day.date,
      tickets: List.unmodifiable(tickets),
      bowlPairs: List.unmodifiable(_bowlPairs(day, state, now, dayOf)),
      shelfBundles: List.unmodifiable(_shelfBundles(day.date, state, term)),
    );
  }

  final CivilDate date;

  /// Every ticket the timetable holds for the day, by start, including the
  /// folded-away ones (state [DoorwayTicketState.dismissed]). A day with no
  /// classes has none.
  final List<DoorwayTicket> tickets;

  /// The days of this week (Monday to Sunday) whose counting classes are all
  /// resolved, with at least one attended: a pair in the bowl. Counts up; a
  /// day that is not here says nothing.
  final List<CivilDate> bowlPairs;

  /// The past weeks of this term in which he attended at least one class,
  /// oldest first.
  final List<DoorwayShelfBundle> shelfBundles;

  /// The tickets still on the rail: everything but the folded-away.
  List<DoorwayTicket> get visibleTickets => [
    for (final ticket in tickets)
      if (!ticket.folded) ticket,
  ];

  /// Tickets that count toward the day and are still on it.
  int get countingTickets =>
      tickets.where((ticket) => ticket.counts && !ticket.folded).length;

  /// The rail's layout, by [countingTickets].
  DoorwayRailTier get tier => doorwayTierFor(countingTickets);

  /// The attended tickets and the hooks they hang on.
  Map<int, List<DoorwayTicket>> get hung {
    final out = <int, List<DoorwayTicket>>{};
    for (final ticket in tickets) {
      final hook = ticket.hook;
      if (hook != null) (out[hook] ??= []).add(ticket);
    }
    return out;
  }

  static DoorwayKind _kindOf(MeetingKind kind) => switch (kind) {
    MeetingKind.lecture => DoorwayKind.lecture,
    MeetingKind.lab || MeetingKind.studio => DoorwayKind.lab,
    MeetingKind.recitation => DoorwayKind.recitation,
    MeetingKind.officeHours => DoorwayKind.optional,
  };

  static List<CivilDate> _bowlPairs(
    ClassDay today,
    GameState state,
    DateTime now,
    ClassDay Function(CivilDate) dayOf,
  ) {
    final monday = today.date.addDays(-(today.date.weekday - 1));
    final pairs = <CivilDate>[];
    for (var i = 0; i < 7; i++) {
      final date = monday.addDays(i);
      final day = date == today.date ? today : dayOf(date);
      if (_pairDay(day, state)) pairs.add(date);
    }
    return pairs;
  }

  /// All of the day's counting classes (a set-aside one is not among them) are
  /// kept, and something was kept.
  static bool _pairDay(ClassDay day, GameState state) {
    var attended = 0;
    var resolved = true;
    for (final entry in day.classes) {
      if (state.keptClassFor(entry.facts) != null) {
        attended++;
      } else if (entry.countsTowardDay) {
        resolved = false;
      }
    }
    return resolved && attended > 0;
  }

  static List<DoorwayShelfBundle> _shelfBundles(
    CivilDate date,
    GameState state,
    AcademicTerm? term,
  ) {
    if (term == null) return const [];
    final thisMonday = date.addDays(-(date.weekday - 1));
    var monday = term.startDate.addDays(-(term.startDate.weekday - 1));
    final bundles = <DoorwayShelfBundle>[];
    while (monday.compareTo(thisMonday) < 0) {
      var attended = 0;
      for (var i = 0; i < 7; i++) {
        final day = monday.addDays(i);
        if (!day.isWithin(term.startDate, term.endDate)) continue;
        attended += state.classesKeptOn(day.toString()).length;
      }
      if (attended > 0) {
        bundles.add(DoorwayShelfBundle(weekStart: monday, attended: attended));
      }
      monday = monday.addDays(7);
    }
    return bundles;
  }

  /// For tests: the ticket for [id], if the day holds it.
  @visibleForTesting
  DoorwayTicket? ticketFor(String id) {
    for (final ticket in tickets) {
      if (ticket.id == id) return ticket;
    }
    return null;
  }
}
