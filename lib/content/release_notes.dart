/// A visual category for one factual release highlight. The presentation layer
/// maps these semantic roles to the app's existing icon family.
enum ReleaseHighlightKind {
  academicDaybook,
  courseWork,
  calendarViews,
  locationDirections,
  flexiblePlans,
  streakSafety,
  roomGuide,
  interactionSound,
  questControl,
}

class ReleaseHighlight {
  const ReleaseHighlight({
    required this.kind,
    required this.title,
    required this.body,
  });

  final ReleaseHighlightKind kind;
  final String title;
  final String body;
}

/// One immutable, user-facing release record. Entries remain checked in after
/// they stop being current so Me -> What's New becomes a quiet local archive.
class RoomReleaseNotes {
  const RoomReleaseNotes({
    required this.id,
    required this.versionLabel,
    required this.dateLabel,
    required this.title,
    required this.introduction,
    required this.highlights,
  });

  /// Stable identity for once-per-release presentation. This must match the
  /// shipped Flutter `version+build` value exactly.
  final String id;
  final String versionLabel;
  final String dateLabel;
  final String title;
  final String introduction;
  final List<ReleaseHighlight> highlights;
}

/// Newest first. A user-facing build is not ready to release until its record
/// is at the front of this list and its id matches the candidate metadata.
const roomOfDaysReleaseNotes = <RoomReleaseNotes>[
  RoomReleaseNotes(
    id: '1.0.4+25',
    versionLabel: 'VERSION 1.0.4 · BUILD 25',
    dateLabel: 'AUGUST 2026',
    title: 'Plans are for your whole life.',
    introduction:
        'Your Daybook is calmer, quests are easier to reshape, and every interaction feels more at home in the room.',
    highlights: <ReleaseHighlight>[
      ReleaseHighlight(
        kind: ReleaseHighlightKind.flexiblePlans,
        title: 'YOUR WHOLE DAYBOOK',
        body:
            'Add events and tasks without setting up a term or course. School stays there when you need it.',
      ),
      ReleaseHighlight(
        kind: ReleaseHighlightKind.calendarViews,
        title: 'ONE CALENDAR, FOUR VIEWS',
        body:
            'Month, week, three-day, and day views keep plans, classes, deadlines, and chosen quests together.',
      ),
      ReleaseHighlight(
        kind: ReleaseHighlightKind.locationDirections,
        title: 'GET THERE',
        body:
            'Save a location and open directions in Apple Maps or Google Maps when it is time to go.',
      ),
      ReleaseHighlight(
        kind: ReleaseHighlightKind.questControl,
        title: 'QUESTS STAY YOURS',
        body:
            'Take a quest back, choose it again, or move a weekly quest to another day without losing it.',
      ),
      ReleaseHighlight(
        kind: ReleaseHighlightKind.interactionSound,
        title: 'THE ROOM ANSWERS BACK',
        body:
            'Clicking around now has one crisp, varied voice, with a rare melodic reply tucked into the rhythm.',
      ),
    ],
  ),
  RoomReleaseNotes(
    id: '1.0.4+24',
    versionLabel: 'VERSION 1.0.4 · BUILD 24',
    dateLabel: 'AUGUST 2026',
    title: 'Plans are for your whole life.',
    introduction:
        'Events, tasks, classes, quests, and the places you need to be can now share one calm Daybook.',
    highlights: <ReleaseHighlight>[
      ReleaseHighlight(
        kind: ReleaseHighlightKind.flexiblePlans,
        title: 'YOUR WHOLE DAYBOOK',
        body:
            'Add events and tasks without setting up a term or course. School stays there when you need it.',
      ),
      ReleaseHighlight(
        kind: ReleaseHighlightKind.calendarViews,
        title: 'ONE CALENDAR, FOUR VIEWS',
        body:
            'Month, week, three-day, and day views keep plans, classes, deadlines, and chosen quests together.',
      ),
      ReleaseHighlight(
        kind: ReleaseHighlightKind.locationDirections,
        title: 'GET THERE',
        body:
            'Save a location and open directions in Apple Maps or Google Maps when it is time to go.',
      ),
    ],
  ),
  RoomReleaseNotes(
    id: '1.0.3+21',
    versionLabel: 'VERSION 1.0.3 · BUILD 21',
    dateLabel: 'AUGUST 2026',
    title: 'Plans are for your whole life.',
    introduction:
        'Events, tasks, classes, and the places you need to be can now share one calm Daybook.',
    highlights: <ReleaseHighlight>[
      ReleaseHighlight(
        kind: ReleaseHighlightKind.flexiblePlans,
        title: 'YOUR WHOLE DAYBOOK',
        body:
            'Add events and tasks without setting up a term or course. School stays there when you need it.',
      ),
      ReleaseHighlight(
        kind: ReleaseHighlightKind.calendarViews,
        title: 'ONE CALENDAR, FOUR VIEWS',
        body:
            'Month, week, three-day, and day views keep personal plans, classes, and quests together.',
      ),
      ReleaseHighlight(
        kind: ReleaseHighlightKind.locationDirections,
        title: 'GET THERE',
        body:
            'Save a location and open directions in Apple Maps or Google Maps when it is time to go.',
      ),
    ],
  ),
  RoomReleaseNotes(
    id: '1.0.2+20',
    versionLabel: 'VERSION 1.0.2 · BUILD 20',
    dateLabel: 'AUGUST 2026',
    title: 'More room for real life.',
    introduction:
        'Plans can bend with the week, streaks have a gentler safety net, and help is closer when the day feels heavy.',
    highlights: <ReleaseHighlight>[
      ReleaseHighlight(
        kind: ReleaseHighlightKind.flexiblePlans,
        title: 'PLANS THAT BEND',
        body:
            'Make room for study blocks, transition time, and one-off schedule changes without rewriting the whole semester.',
      ),
      ReleaseHighlight(
        kind: ReleaseHighlightKind.streakSafety,
        title: 'A SOFTER LANDING',
        body:
            'Streak freezes can hold a missed day, then refill as you keep showing up.',
      ),
      ReleaseHighlight(
        kind: ReleaseHighlightKind.roomGuide,
        title: 'HELP FOR TODAY',
        body:
            'Room Guide offers a next step for stuck tasks, low-energy days, and overwhelmed spaces.',
      ),
    ],
  ),
  RoomReleaseNotes(
    id: '1.0.1+13',
    versionLabel: 'VERSION 1.0.1 · BUILD 13',
    dateLabel: 'AUGUST 2026',
    title: 'Your semester has a place in Plans.',
    introduction:
        'Classes, assignments, and exams can now live beside the rest of your days.',
    highlights: <ReleaseHighlight>[
      ReleaseHighlight(
        kind: ReleaseHighlightKind.academicDaybook,
        title: 'ACADEMIC DAYBOOK',
        body: 'Keep classes, assignments, and exams together inside Plans.',
      ),
      ReleaseHighlight(
        kind: ReleaseHighlightKind.courseWork,
        title: 'COURSE WORK WITH CONTEXT',
        body:
            'Add a due date and details, then mark the work complete when it is done.',
      ),
      ReleaseHighlight(
        kind: ReleaseHighlightKind.calendarViews,
        title: 'THE VIEW THAT FITS TODAY',
        body:
            'Move between month, week, three-day, and day views. Room of Days remembers the one you chose.',
      ),
    ],
  ),
];

RoomReleaseNotes get currentRoomReleaseNotes => roomOfDaysReleaseNotes.first;
