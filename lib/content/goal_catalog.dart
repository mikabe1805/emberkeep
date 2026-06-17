import '../models.dart';
import '../tokens.dart';

/// The goal catalog — "Take on quests!" (DESIGN.md round-3). Curated goal
/// ideas by life area, each with concrete adoptable quest templates. The
/// app does the heavy lifting so users don't have to invent their journey
/// from scratch — but everything here is just a starting point to edit.
class GoalIdea {
  const GoalIdea({
    required this.title,
    required this.blurb,
    required this.stat,
    required this.quests,
  });

  final String title;
  final String blurb;
  final Stat stat;
  final List<QuestTemplate> quests;
}

class QuestTemplate {
  const QuestTemplate({
    required this.title,
    required this.stat,
    required this.difficulty,
    this.schedule = QuestSchedule.daily,
    this.dread = false,
    this.ladderHint,
    this.timerMinutes = 0,
    this.allDay = false,
    this.rising = false,
  });

  final String title;
  final Stat stat;
  final int difficulty;
  final QuestSchedule schedule;
  final bool dread;
  final String? ladderHint;
  final int timerMinutes;
  final bool allDay;
  final bool rising;

  Quest build({String? goalTitle}) => Quest(
        title: title,
        stat: stat,
        difficulty: difficulty,
        schedule: schedule,
        dread: dread,
        ladderHint: ladderHint,
        verification:
            timerMinutes > 0 ? Verification.timer : Verification.honor,
        timerMinutes: timerMinutes,
        goalTitle: goalTitle,
        allDay: allDay,
        rising: rising,
      );
}

const goalCatalog = <GoalIdea>[
  GoalIdea(
    title: 'Become a reader',
    blurb:
        'Don’t know what to read? That’s the first quest. Fiction counts. '
        'Comics count. Anything that makes you want to turn the page counts.',
    stat: Stat.intl,
    quests: [
      QuestTemplate(
          title: 'Pick a book that excites you',
          stat: Stat.intl,
          difficulty: 2,
          schedule: QuestSchedule.once,
          ladderHint: 'ANY TOPIC · FICTION COUNTS'),
      QuestTemplate(
          title: 'Read for 10 minutes',
          stat: Stat.intl,
          difficulty: 3,
          timerMinutes: 10,
          rising: true,
          ladderHint: 'RISES AS YOU GROW 📈'),
      QuestTemplate(
          title: 'Finish a chapter',
          stat: Stat.intl,
          difficulty: 5,
          schedule: QuestSchedule.weekly),
    ],
  ),
  GoalIdea(
    title: 'Routine keeper',
    blurb:
        'The unglamorous quests are the realest ones. Skincare, meds, the '
        'weekly shot — showing up for yourself counts double here.',
    stat: Stat.dis,
    quests: [
      QuestTemplate(
          title: 'Morning skincare', stat: Stat.dis, difficulty: 2),
      QuestTemplate(
          title: 'Evening skincare', stat: Stat.dis, difficulty: 2),
      QuestTemplate(
          title: 'Take your pills',
          stat: Stat.vit,
          difficulty: 4,
          dread: true,
          ladderHint: 'HARD SOME DAYS · COUNTS EXTRA'),
      QuestTemplate(
          title: 'Weekly shot',
          stat: Stat.vit,
          difficulty: 8,
          dread: true,
          schedule: QuestSchedule.weekly,
          ladderHint: 'BRAVE · ONCE A WEEK'),
      QuestTemplate(
          title: 'Screens off by 11pm',
          stat: Stat.dis,
          difficulty: 5,
          allDay: true,
          ladderHint: 'ALL-DAY LINE · CHECKS AT NIGHT'),
    ],
  ),
  GoalIdea(
    title: 'Move through the world',
    blurb:
        'Steps count more when they take you somewhere. A new street, a '
        'park, the good coffee place that’s slightly too far.',
    stat: Stat.vit,
    quests: [
      QuestTemplate(
          title: 'Walk somewhere new',
          stat: Stat.vit,
          difficulty: 4,
          ladderHint: 'A STREET · A PARK · ANYWHERE'),
      QuestTemplate(
          title: '10 minutes outside',
          stat: Stat.vit,
          difficulty: 2,
          timerMinutes: 10),
      QuestTemplate(
          title: '7,000 steps',
          stat: Stat.vit,
          difficulty: 5,
          ladderHint: 'STEP PROOF · WITH THE PHONE APP'),
    ],
  ),
  GoalIdea(
    title: 'The strength path',
    blurb:
        'Two push-ups today beats a hundred never. The ladder is the '
        'whole secret — every rung was someone’s impossible once.',
    stat: Stat.str,
    quests: [
      QuestTemplate(
          title: 'Do 5 push-ups',
          stat: Stat.str,
          difficulty: 2,
          rising: true,
          ladderHint: 'RISES AS YOU GROW 📈'),
      QuestTemplate(
          title: 'Full workout session',
          stat: Stat.str,
          difficulty: 6,
          rising: true,
          ladderHint: 'STARTS HONEST · RISES 📈'),
      QuestTemplate(
          title: 'Class or sparring session',
          stat: Stat.str,
          difficulty: 8,
          schedule: QuestSchedule.weekly,
          ladderHint: 'BOXING · CLIMBING · ANYTHING'),
    ],
  ),
  GoalIdea(
    title: 'Deep focus',
    blurb:
        'Attention is a stat the modern world actively drains. Train it '
        'in small, timed, provable doses.',
    stat: Stat.foc,
    quests: [
      QuestTemplate(
          title: '1-minute breathing reset',
          stat: Stat.foc,
          difficulty: 1,
          timerMinutes: 1),
      QuestTemplate(
          title: '25-minute focus session',
          stat: Stat.foc,
          difficulty: 5,
          timerMinutes: 25),
      QuestTemplate(
          title: 'Phone-free meal', stat: Stat.foc, difficulty: 3),
    ],
  ),
  GoalIdea(
    title: 'Reach out',
    blurb:
        'Connection is a health behavior — it ranks with exercise in the '
        'longevity studies. One message counts.',
    stat: Stat.soc,
    quests: [
      QuestTemplate(
          title: 'Message someone you miss', stat: Stat.soc, difficulty: 3),
      QuestTemplate(
          title: 'Plan a hangout',
          stat: Stat.soc,
          difficulty: 5,
          schedule: QuestSchedule.weekly),
    ],
  ),
  GoalIdea(
    title: 'Keep your space',
    blurb:
        'A tidy room is a kinder room to wake up in. None of this has to be '
        'perfect — a made bed and one clear surface already change how the '
        'whole day feels.',
    stat: Stat.dis,
    quests: [
      QuestTemplate(
          title: 'Make your bed',
          stat: Stat.dis,
          difficulty: 1,
          ladderHint: 'TWO MINUTES · SETS THE TONE'),
      QuestTemplate(
          title: 'Ten-minute tidy',
          stat: Stat.dis,
          difficulty: 2,
          timerMinutes: 10,
          ladderHint: 'SET THE TIMER · RACE THE CLOCK'),
      QuestTemplate(
          title: 'Wash the dishes',
          stat: Stat.dis,
          difficulty: 3,
          dread: true,
          ladderHint: 'THE PILE NEVER WINS'),
      QuestTemplate(
          title: 'One load of laundry',
          stat: Stat.dis,
          difficulty: 3,
          schedule: QuestSchedule.weekly),
      QuestTemplate(
          title: 'Deep-clean one room',
          stat: Stat.dis,
          difficulty: 6,
          schedule: QuestSchedule.weekly,
          ladderHint: 'PICK ONE ROOM · JUST ONE'),
    ],
  ),
  GoalIdea(
    title: 'Tend your plants',
    blurb:
        'Looking after something green is a quiet practice — it asks for a '
        'little, often, and gives back more than it takes. Even one windowsill '
        'pot counts.',
    stat: Stat.vit,
    quests: [
      QuestTemplate(
          title: 'Bring home a plant',
          stat: Stat.vit,
          difficulty: 3,
          schedule: QuestSchedule.once,
          ladderHint: 'THE FIRST ONE IS THE HARDEST'),
      QuestTemplate(
          title: 'Check on your plants',
          stat: Stat.vit,
          difficulty: 1,
          ladderHint: 'WHO’S THIRSTY? WHO’S REACHING FOR LIGHT?'),
      QuestTemplate(
          title: 'Water what needs it', stat: Stat.vit, difficulty: 2),
      QuestTemplate(
          title: 'Give them a real tending',
          stat: Stat.vit,
          difficulty: 4,
          schedule: QuestSchedule.weekly,
          ladderHint: 'PRUNE · ROTATE · DUST A LEAF'),
    ],
  ),
  GoalIdea(
    title: 'Tend your creatures',
    blurb:
        'A creature that depends on you asks for a steadier love than a plant '
        'does — fed on time, walked in the rain, carried to the vet when it’s '
        'scary. None of it is optional to them, and that’s exactly what makes '
        'it count. One full bowl is a whole small act of devotion — whiskers, '
        'scales, or feathers all welcome.',
    stat: Stat.vit,
    quests: [
      QuestTemplate(
          title: 'Bring home a companion',
          stat: Stat.soc,
          difficulty: 4,
          schedule: QuestSchedule.once,
          ladderHint: 'NO RUSH · THE RIGHT ONE FINDS YOU'),
      QuestTemplate(
          title: 'Fill the bowls',
          stat: Stat.vit,
          difficulty: 1,
          ladderHint: 'FRESH WATER · A FULL DISH'),
      QuestTemplate(
          title: 'A proper walk together',
          stat: Stat.vit,
          difficulty: 3,
          timerMinutes: 15,
          ladderHint: 'THEIR FAVORITE LOOP · RAIN OR SHINE'),
      QuestTemplate(
          title: 'Everyone’s fed before you sleep',
          stat: Stat.vit,
          difficulty: 3,
          allDay: true,
          ladderHint: 'AN ALL-DAY LINE · CHECKS AT NIGHT'),
      QuestTemplate(
          title: 'The dreaded vet run',
          stat: Stat.vit,
          difficulty: 7,
          dread: true,
          schedule: QuestSchedule.monthly,
          ladderHint: 'BRAVE FOR BOTH OF YOU · COUNTS EXTRA'),
    ],
  ),
  GoalIdea(
    title: 'Feed yourself well',
    blurb:
        'Cooking for yourself is a love letter you write in real time. It '
        'counts even when it’s simple — toast made with care beats takeout on '
        'autopilot.',
    stat: Stat.vit,
    quests: [
      QuestTemplate(
          title: 'Start with a glass of water',
          stat: Stat.vit,
          difficulty: 1,
          ladderHint: 'BEFORE THE COFFEE · ONE GLASS'),
      QuestTemplate(
          title: 'Cook a real meal',
          stat: Stat.vit,
          difficulty: 4,
          ladderHint: 'ACTUAL INGREDIENTS · SIMPLE IS FINE'),
      QuestTemplate(
          title: 'Eat something green', stat: Stat.vit, difficulty: 2),
      QuestTemplate(
          title: 'Plan the week’s meals',
          stat: Stat.vit,
          difficulty: 5,
          schedule: QuestSchedule.weekly,
          ladderHint: 'FUTURE YOU SAYS THANK YOU'),
    ],
  ),
  GoalIdea(
    title: 'Tend your money',
    blurb:
        'Money gets calmer the moment you look at it. This isn’t about '
        'spending less for its own sake — it’s about knowing where you stand, '
        'so the numbers stop being scary.',
    stat: Stat.dis,
    quests: [
      QuestTemplate(
          title: 'Check your balance',
          stat: Stat.dis,
          difficulty: 2,
          ladderHint: 'NO JUDGMENT · JUST LOOK'),
      QuestTemplate(
          title: 'A no-spend day',
          stat: Stat.dis,
          difficulty: 4,
          dread: true,
          ladderHint: 'BUY ONLY WHAT YOU NEED TODAY'),
      QuestTemplate(
          title: 'Note what you spent', stat: Stat.dis, difficulty: 2),
      QuestTemplate(
          title: 'Sit with the numbers',
          stat: Stat.dis,
          difficulty: 5,
          schedule: QuestSchedule.weekly,
          ladderHint: 'FIFTEEN HONEST MINUTES'),
    ],
  ),
  GoalIdea(
    title: 'Wind down well',
    blurb:
        'Sleep is the quiet engine under every other stat. Protect the hour '
        'before bed and the rest tends to follow — start small, the body '
        'remembers the rhythm.',
    stat: Stat.vit,
    quests: [
      QuestTemplate(
          title: 'In bed by your hour',
          stat: Stat.vit,
          difficulty: 4,
          allDay: true,
          ladderHint: 'AN ALL-DAY LINE · CHECKS AT NIGHT'),
      QuestTemplate(
          title: 'Screens down before sleep',
          stat: Stat.dis,
          difficulty: 4,
          allDay: true,
          ladderHint: 'THE LAST 30 MINUTES ARE YOURS'),
      QuestTemplate(
          title: 'No caffeine after 2pm',
          stat: Stat.vit,
          difficulty: 3,
          allDay: true),
    ],
  ),
];
