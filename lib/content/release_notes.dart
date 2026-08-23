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
  spaceDiscovery,
  ambientLight,
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
    id: '1.0.4+31',
    versionLabel: 'VERSION 1.0.4 · BUILD 31',
    dateLabel: 'AUGUST 2026',
    title: 'The open door is finally in the open.',
    introduction:
        'Your public listing now has a clear home, and ambient-light choices '
        'visibly relight the space around you.',
    highlights: <ReleaseHighlight>[
      ReleaseHighlight(
        kind: ReleaseHighlightKind.spaceDiscovery,
        title: 'OPEN FROM MY SPACE',
        body:
            'Private and listed spaces now carry a direct Open to Discover or '
            'Manage Listing control. You never have to guess that sharing a code comes first.',
      ),
      ReleaseHighlight(
        kind: ReleaseHighlightKind.spaceDiscovery,
        title: 'YOUR LISTING LIVES IN DISCOVER',
        body:
            'Discover shows your own privacy state and listing action above '
            'its open doors, including the optional public-name control.',
      ),
      ReleaseHighlight(
        kind: ReleaseHighlightKind.ambientLight,
        title: 'LIGHT YOU CAN ACTUALLY SEE',
        body:
            'Themes are now Ambient Light, with a live preview and a visible '
            'canvas change. Change Space remains the way to replace the whole room.',
      ),
    ],
  ),
  RoomReleaseNotes(
    id: '1.0.4+30',
    versionLabel: 'VERSION 1.0.4 · BUILD 30',
    dateLabel: 'AUGUST 2026',
    title: 'Open the door, on your terms.',
    introduction:
        'You can now find other keepers through Discover — or list your own '
        'room with a separate public name, only when you choose.',
    highlights: <ReleaseHighlight>[
      ReleaseHighlight(
        kind: ReleaseHighlightKind.spaceDiscovery,
        title: 'A FEW OPEN DOORS',
        body:
            'Discover offers a small, shuffled handful of rooms whose keepers '
            'chose to be found. No code exchange is needed.',
      ),
      ReleaseHighlight(
        kind: ReleaseHighlightKind.streakSafety,
        title: 'YOUR PRIVATE LIFE STAYS PRIVATE',
        body:
            'Listing a room shows only an optional public name, its generated '
            'style, title, and level — never quests, Journal pages, or account details.',
      ),
      ReleaseHighlight(
        kind: ReleaseHighlightKind.roomGuide,
        title: 'KEEP UP WITHOUT KEEPING SCORE',
        body:
            'Keep a space in your Circle to return. Progress is never ranked, '
            'and blocking a keeper hides their future rooms too.',
      ),
    ],
  ),
  RoomReleaseNotes(
    id: '1.0.4+29',
    versionLabel: 'VERSION 1.0.4 · BUILD 29',
    dateLabel: 'AUGUST 2026',
    title: 'The room keeps pace with you.',
    introduction:
        'Quests now sound exactly when they move, guided workouts let you '
        'choose the session, and your Circle can grow without a ceiling.',
    highlights: <ReleaseHighlight>[
      ReleaseHighlight(
        kind: ReleaseHighlightKind.interactionSound,
        title: 'MOVEMENT YOU CAN HEAR',
        body:
            'Every visible quest bob answers once, even when the gesture '
            'becomes a scroll. A swipe with no pressed quest stays quiet.',
      ),
      ReleaseHighlight(
        kind: ReleaseHighlightKind.questControl,
        title: 'PICK THE SESSION',
        body:
            'Guided workouts now open into seven distinct sessions, so you '
            'can choose what belongs on today’s board.',
      ),
      ReleaseHighlight(
        kind: ReleaseHighlightKind.roomGuide,
        title: 'A CIRCLE WITHOUT A CEILING',
        body:
            'Keep as many trusted spaces as you want. Larger Circles load '
            'progressively without turning anyone’s progress into a rank.',
      ),
    ],
  ),
  RoomReleaseNotes(
    id: '1.0.4+28',
    versionLabel: 'VERSION 1.0.4 · BUILD 28',
    dateLabel: 'AUGUST 2026',
    title: 'Two pages became places.',
    introduction:
        'Plans opens onto a rainlit conservatory and Journal into a quiet '
        'archive, with controls shaped around what each page is for.',
    highlights: <ReleaseHighlight>[
      ReleaseHighlight(
        kind: ReleaseHighlightKind.flexiblePlans,
        title: 'PLANS WITH A VIEW',
        body:
            'Your Daybook now sits inside a rainlit conservatory, so planning '
            'feels like entering its own corner of the room.',
      ),
      ReleaseHighlight(
        kind: ReleaseHighlightKind.academicDaybook,
        title: 'A PLACE TO WRITE',
        body:
            'Journal opens on a warm archive desk, with entries and reflection '
            'tools gathered into one writing surface.',
      ),
      ReleaseHighlight(
        kind: ReleaseHighlightKind.questControl,
        title: 'CONTROLS THAT BELONG',
        body:
            'Tabs, filters, and actions now borrow the materials and details '
            'of the page they serve instead of feeling pasted on.',
      ),
    ],
  ),
  RoomReleaseNotes(
    id: '1.0.4+27',
    versionLabel: 'VERSION 1.0.4 · BUILD 27',
    dateLabel: 'AUGUST 2026',
    title: 'Every surface has a voice.',
    introduction:
        'Tap around and the room answers in its own materials — and the good '
        'moments finally sound as good as they feel.',
    highlights: <ReleaseHighlight>[
      ReleaseHighlight(
        kind: ReleaseHighlightKind.interactionSound,
        title: 'TEXTURES UNDER YOUR FINGER',
        body:
            'Stone buttons land with a satisfying dak, tabs turn like pages, '
            'and glass and brass keep their own small voices.',
      ),
      ReleaseHighlight(
        kind: ReleaseHighlightKind.interactionSound,
        title: 'REWARDS WORTH HEARING',
        body:
            'Streaks, finds, and level-ups now speak the same warm language '
            'as the rest of the room instead of a synth blip.',
      ),
      ReleaseHighlight(
        kind: ReleaseHighlightKind.questControl,
        title: 'NO DEAD TAPS',
        body:
            'Retap the tab you are on, catch a scrolling list, hold an '
            'all-day line — everything that does something says so.',
      ),
    ],
  ),
  RoomReleaseNotes(
    id: '1.0.4+26',
    versionLabel: 'VERSION 1.0.4 · BUILD 26',
    dateLabel: 'AUGUST 2026',
    title: 'Every surface has a voice.',
    introduction:
        'Tap around and the room answers in its own materials — and the good '
        'moments finally sound as good as they feel.',
    highlights: <ReleaseHighlight>[
      ReleaseHighlight(
        kind: ReleaseHighlightKind.interactionSound,
        title: 'TEXTURES UNDER YOUR FINGER',
        body:
            'Stone buttons land with a satisfying dak, tabs turn like pages, '
            'and glass and brass keep their own small voices.',
      ),
      ReleaseHighlight(
        kind: ReleaseHighlightKind.interactionSound,
        title: 'REWARDS WORTH HEARING',
        body:
            'Streaks, finds, and level-ups now speak the same warm language '
            'as the rest of the room instead of a synth blip.',
      ),
      ReleaseHighlight(
        kind: ReleaseHighlightKind.questControl,
        title: 'NO DEAD TAPS',
        body:
            'Retap the tab you are on, catch a scrolling list, tap around the '
            'Daybook — everything that does something says so.',
      ),
    ],
  ),
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
