// Today's three at the door: the Quests room on a day with no classes, as
// data. Pure: it reads the quests, a moment and (optionally) the timetable's
// own reading of the week, and writes nothing. The engine (GameState.roll,
// the undo slot) owns what a completion does; this only says what the door
// shows.
//
// The Doorway's own tickets carry the day. A chosen quest is a ticket on the
// rail (the same plaques a class has, with the stat's glyph, the quest's name
// and its XP); a kept one hangs on a hook; when all of today's three are kept
// the tickets drop into the bowl as a pair. A quest set aside for today
// stays one of the three, a quiet ticket. Nothing here counts what was not
// done.
library;

import '../../../academic_calendar/domain/academic_schedule.dart'
    show CivilDate;
import '../../../models.dart';
import '../../class_day/doorway_model.dart';
import '../../class_day/doorway_tickets.dart'
    show doorwayQuestLabel, doorwayStatGlyph;

/// How a quest looks on the three rings.
enum QuestPip {
  /// No quest chosen for this place.
  empty,

  /// Chosen, still to do.
  open,

  /// Chosen and set aside for today (it stays one of the three).
  resting,

  /// Kept.
  kept,
}

/// The ticket id a quest has on the rail: its identity title, stable across
/// an undo (which replaces every quest object).
String questTicketId(Quest quest) => 'quest:${quest.title}';

/// What the Quests room shows for [now].
final class QuestDoorwayRead {
  const QuestDoorwayRead({
    required this.hasField,
    required this.field,
    required this.pips,
    required this.foremost,
    required this.day,
  });

  /// Today's three have been chosen (a dated field exists).
  final bool hasField;

  /// The chosen quests, in their order (up to three; kept and resting ones
  /// stay).
  final List<Quest> field;

  /// Three rings, one per place.
  final List<QuestPip> pips;

  /// The quest that leads the glass card: the one he brought forward, else
  /// the first still to do. Null when nothing is open.
  final Quest? foremost;

  /// The Doorway's day: quest tickets, the day's pair in the bowl once all
  /// three are kept, and the shelf of the term's weeks.
  final DoorwayDay day;

  int get keptCount => pips.where((p) => p == QuestPip.kept).length;
  int get restingCount => pips.where((p) => p == QuestPip.resting).length;
  int get openCount => pips.where((p) => p == QuestPip.open).length;

  /// Every chosen quest is kept (and at least one was chosen).
  bool get allKept => hasField && field.isNotEmpty && keptCount == field.length;

  /// The quest for a ticket id, if it is one of today's.
  Quest? questFor(String ticketId) {
    for (final quest in field) {
      if (questTicketId(quest) == ticketId) return quest;
    }
    return null;
  }

  /// "Today's three, 2 kept" for a screen reader. Never "of".
  String get semantics {
    if (!hasField) return 'Today’s three, not chosen yet';
    final kept = keptCount;
    return kept == 0
        ? 'Today’s three, none kept yet'
        : allKept
        ? 'Today’s three, all kept'
        : 'Today’s three, $kept kept';
  }
}

/// Reads today's three for [date] from [quests]. [xp] is what completing a
/// quest is worth now (the engine's own preview); [preferredTitle] names the
/// open quest he brought forward; [base] is the timetable's reading of the
/// same day (its shelf and bowl) when the shell holds one, and
/// [weekFinished] says no class is left this week, so the week's pairs are
/// tied into a bundle on the shelf instead of lying in the bowl.
QuestDoorwayRead readQuestDoorway({
  required List<Quest> quests,
  required DateTime now,
  required CivilDate date,
  required List<Quest> field,
  required bool hasField,
  required int? Function(Quest) xp,
  String? preferredTitle,
  DoorwayDay? base,
  bool weekFinished = false,
}) {
  final today = Days.key(now);
  bool done(Quest q) => q.doneFor(now);
  bool resting(Quest q) => !done(q) && q.snoozedDay == today;
  bool open(Quest q) => !done(q) && !resting(q);

  Quest? foremost;
  if (preferredTitle != null) {
    for (final quest in field) {
      if (quest.title == preferredTitle && open(quest)) foremost = quest;
    }
  }
  foremost ??= field.where(open).firstOrNull;

  final pips = <QuestPip>[
    for (var slot = 0; slot < 3; slot++)
      if (!hasField || slot >= field.length)
        QuestPip.empty
      else if (done(field[slot]))
        QuestPip.kept
      else if (resting(field[slot]))
        QuestPip.resting
      else
        QuestPip.open,
  ];

  final hooks = doorwayHooksFor(field.length);
  final tickets = <DoorwayTicket>[];
  for (var i = 0; i < field.length; i++) {
    final quest = field[i];
    final state = done(quest)
        ? DoorwayTicketState.attended
        : resting(quest)
        ? DoorwayTicketState.settled
        : identical(quest, foremost)
        ? DoorwayTicketState.ready
        : DoorwayTicketState.upcoming;
    tickets.add(
      DoorwayTicket(
        quest: DoorwayQuestFace(
          id: questTicketId(quest),
          name: quest.displayTitle,
          glyph: doorwayStatGlyph(quest.stat),
          statLabel: quest.stat.label,
          xp: xp(quest),
        ),
        kind: DoorwayKind.lecture,
        label: doorwayQuestLabel(quest.displayTitle),
        state: state,
        hook: state == DoorwayTicketState.attended ? hooks[i] : null,
      ),
    );
  }

  final allKept =
      hasField && field.isNotEmpty && field.every((quest) => done(quest));
  final classPairs = base?.bowlPairs ?? const <CivilDate>[];
  var shelf = base?.shelfBundles ?? const <DoorwayShelfBundle>[];
  var pairs = <CivilDate>[...classPairs];
  if (weekFinished && classPairs.isNotEmpty) {
    // The week's class days are over: their pairs are one bundle on the
    // shelf, as they were on the week's last class day.
    final monday = date.addDays(-(date.weekday - 1));
    shelf = [
      ...shelf,
      DoorwayShelfBundle(weekStart: monday, attended: classPairs.length),
    ];
    pairs = [];
  }
  if (allKept && !pairs.contains(date)) pairs.add(date);

  return QuestDoorwayRead(
    hasField: hasField,
    field: field,
    pips: pips,
    foremost: foremost,
    day: DoorwayDay(
      date: date,
      tickets: List.unmodifiable(tickets),
      bowlPairs: List.unmodifiable(pairs),
      shelfBundles: List.unmodifiable(shelf),
      termName: base?.termName,
      emptyHolders: field.isEmpty ? 3 : 0,
    ),
  );
}

/// The glass bar's words for a quest: the same promise the featured quest
/// card makes about what the press does.
String questBarLabel(Quest quest) {
  if (quest.journalPrompt != null) return 'OPEN JOURNAL';
  if (quest.allDay) return 'CHECK TONIGHT';
  if (quest.workout) return 'BEGIN SESSION';
  if (quest.verification == Verification.timer &&
      quest.effectiveTimerMinutes > 0) {
    return 'OPEN ${quest.effectiveTimerMinutes}-MINUTE SESSION';
  }
  return 'MARK COMPLETE';
}
