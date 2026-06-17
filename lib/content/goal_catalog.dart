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
  // The home/life-admin & wellbeing goals (rounds 15-16) were re-audited in
  // round-18 against habit research: every quest below is an evidence-supported
  // good habit (citation noted inline), deduped against the default board, with
  // no acquire-a-pet / one-time-life-decision quests. Citations are honest —
  // correlational/survey sources are flagged.
  GoalIdea(
    title: 'Keep your space',
    blurb:
        'A tidy room is a kinder room to wake up in. None of this has to be '
        'perfect — a made bed and one clear surface already change how the '
        'whole day feels. Homes people call cluttered rather than restful track '
        'with a flatter daily stress-hormone rhythm; you’re not chasing '
        'spotless, you’re lowering the noise.',
    stat: Stat.dis,
    quests: [
      // bed-makers report steadier sleep + a daily sense of order — NSF Bedroom Poll (survey)
      QuestTemplate(
          title: 'Make your bed',
          stat: Stat.dis,
          difficulty: 1,
          ladderHint: 'TWO MINUTES · SETS THE TONE'),
      // cluttered vs restful homes ↔ flatter daily cortisol — Saxbe & Repetti 2010, PubMed 19934011 (correlational)
      QuestTemplate(
          title: 'Ten-minute tidy',
          stat: Stat.dis,
          difficulty: 2,
          timerMinutes: 10,
          ladderHint: 'SET THE TIMER · RACE THE CLOCK'),
      // weekly washing clears dust mites/allergens that disrupt sleep — Cleveland Clinic
      QuestTemplate(
          title: 'Fresh sheets',
          stat: Stat.dis,
          difficulty: 2,
          schedule: QuestSchedule.weekly,
          ladderHint: 'ONCE A WEEK · CLIMB INTO CLEAN'),
      // completing a finishable chore lifts mood (behavioral activation) — Cuijpers 2007, PMC4061095
      QuestTemplate(
          title: 'One load of laundry',
          stat: Stat.dis,
          difficulty: 3,
          schedule: QuestSchedule.weekly,
          ladderHint: 'WASH · DRY · ACTUALLY PUT AWAY'),
      // restorative homes show healthier cortisol slopes — Saxbe & Repetti 2010, PubMed 19934011 (correlational)
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
        'little, often, and gives back more than it takes. The research is '
        'unusually kind here: tending houseplants can lower blood pressure, and '
        'people who keep them report steadier moods and more everyday '
        'mindfulness. Even one windowsill pot counts.',
    stat: Stat.vit,
    quests: [
      // indoor plants ↔ more positive emotion + lower systolic BP — Han 2022, PMC9224521
      QuestTemplate(
          title: 'Bring home a plant',
          stat: Stat.vit,
          difficulty: 3,
          schedule: QuestSchedule.once,
          ladderHint: 'THE FIRST IS THE HARDEST · A FEW DOLLARS IS PLENTY'),
      // time on houseplant care ↔ higher wellbeing + mindfulness — Ma 2022, PMC9739745
      QuestTemplate(
          title: 'Check on your plants',
          stat: Stat.vit,
          difficulty: 1,
          ladderHint: 'WHO’S THIRSTY · WHO’S REACHING FOR LIGHT'),
      // caring for indoor plants lowered BP + raised calming alpha waves vs a screen task — Park 2023, PMC10557185
      QuestTemplate(
          title: 'Water what needs it', stat: Stat.vit, difficulty: 2),
      // hands-in-soil transplanting cut sympathetic activity + diastolic BP vs computer work — Lee 2015, PMC4419447
      QuestTemplate(
          title: 'Give them a real tending',
          stat: Stat.vit,
          difficulty: 4,
          schedule: QuestSchedule.weekly,
          ladderHint: 'PRUNE · ROTATE · REPOT · DUST A LEAF'),
    ],
  ),
  GoalIdea(
    title: 'Tend your creatures',
    blurb:
        'A creature that depends on you asks for a steadier love than a plant '
        'does — fed on time, walked in the rain, their teeth and their checkups '
        'remembered even when it’s a hassle. None of it is optional to them, '
        'and that’s exactly what makes it count. The kindest secret: a walked '
        'dog walks you too — whiskers, scales, or feathers all welcome.',
    stat: Stat.vit,
    quests: [
      // consistent meal times regulate a pet’s digestion/weight + reduce food anxiety — AVMA feeding guidance
      QuestTemplate(
          title: 'Feed on the same schedule',
          stat: Stat.vit,
          difficulty: 1,
          ladderHint: 'SAME HOURS · FRESH WATER · A FULL DISH'),
      // daily walks/play meet exercise + enrichment needs — and dog-walking ↔ ~24% lower owner mortality — Mubanga 2019; AHA 2013
      QuestTemplate(
          title: 'A proper walk or play session',
          stat: Stat.vit,
          difficulty: 3,
          timerMinutes: 15,
          ladderHint: 'THEIR FAVORITE LOOP · OR 15 MIN OF REAL PLAY'),
      // most pets show dental disease by age 3; brushing is the best home defense — AVMA Pet Dental Care
      QuestTemplate(
          title: 'Brush their teeth or scrub a bowl',
          stat: Stat.dis,
          difficulty: 2,
          ladderHint: 'PET TOOTHPASTE · OR WASH THE FOOD DISH'),
      // reliable daily feeding is the backbone of pet welfare — AAHA enrichment guidance
      QuestTemplate(
          title: 'Everyone’s fed before you sleep',
          stat: Stat.vit,
          difficulty: 3,
          allDay: true,
          ladderHint: 'AN ALL-DAY LINE · CHECKS AT NIGHT'),
      // annual wellness exams catch disease early, when it’s cheapest + most treatable — AAHA/AVMA
      QuestTemplate(
          title: 'Book the vet checkup',
          stat: Stat.vit,
          difficulty: 7,
          dread: true,
          schedule: QuestSchedule.once,
          ladderHint: 'BRAVE FOR BOTH · COUNTS EXTRA'),
    ],
  ),
  GoalIdea(
    title: 'Feed yourself well',
    blurb:
        'Cooking for yourself is a love letter you write in real time. It '
        'counts even when it’s simple — a plate with something green on it '
        'beats takeout on autopilot, and future you is the one who gets fed.',
    stat: Stat.vit,
    quests: [
      // water displacing sugary drinks ↔ lower T2D/CVD risk; hydration steadies mood/focus — PMC10050372; PMC6068860
      QuestTemplate(
          title: 'Start with a glass of water',
          stat: Stat.vit,
          difficulty: 1,
          ladderHint: 'BEFORE THE COFFEE · ONE GLASS'),
      // cooking at home ↔ higher diet quality (more fruit/veg) — Fenland cohort, PMC5561571
      QuestTemplate(
          title: 'Cook a real meal',
          stat: Stat.vit,
          difficulty: 4,
          ladderHint: 'ACTUAL INGREDIENTS · SIMPLE IS FINE'),
      // ~5 servings of fruit/veg a day ↔ ~13% lower early-death risk — Circulation 2021, PMID 33641343
      QuestTemplate(
          title: 'Eat something green',
          stat: Stat.vit,
          difficulty: 2,
          ladderHint: 'ONE HANDFUL · LEAVES OR STALKS'),
      // slower eating lets fullness land; fast eaters ~2× overweight odds — PMC7230501
      QuestTemplate(
          title: 'Eat one meal slowly, no screen',
          stat: Stat.vit,
          difficulty: 2,
          ladderHint: 'PUT THE FORK DOWN · LET FULLNESS CATCH UP'),
      // meal planning ↔ higher diet quality + lower obesity odds — NutriNet-Santé, PMC5288891
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
        'Money gets calmer the moment you look at it. This isn’t about spending '
        'less for its own sake — it’s about knowing where you stand and quietly '
        'building a little cushion, so the numbers stop being scary.',
    stat: Stat.dis,
    quests: [
      // financial self-monitoring ↔ lower discretionary spend + better saving — CFPB; financial-tracking research
      QuestTemplate(
          title: 'Check your balance',
          stat: Stat.dis,
          difficulty: 2,
          ladderHint: 'NO JUDGMENT · JUST LOOK'),
      // a 24-hour pause on non-essentials lets the impulse settle, cutting overspending — delay/cooling-off research
      QuestTemplate(
          title: 'Sleep on it before you buy',
          stat: Stat.dis,
          difficulty: 3,
          allDay: true,
          ladderHint: 'WANT IT? WAIT A DAY'),
      // small regular (ideally automatic) saving builds the emergency cushion that most predicts financial wellbeing — Hershfield 2020; CFPB 2022
      QuestTemplate(
          title: 'Move a little to savings',
          stat: Stat.dis,
          difficulty: 3,
          schedule: QuestSchedule.weekly,
          rising: true,
          ladderHint: 'TINY IS FINE · RISES AS YOU GROW 📈'),
      // a regular review builds financial self-awareness + catches forgotten subscriptions (~$200+/yr) — CFPB Well-Being Scale
      QuestTemplate(
          title: 'Sit with the numbers',
          stat: Stat.dis,
          difficulty: 5,
          schedule: QuestSchedule.weekly,
          timerMinutes: 15,
          ladderHint: 'FIFTEEN HONEST MINUTES · SCAN FOR STRAYS'),
    ],
  ),
  GoalIdea(
    title: 'Wind down well',
    blurb:
        'Sleep is the quiet engine under every other stat. Your body keeps '
        'better time than any alarm — it just needs you to be regular with it. '
        'Protect the hour before bed, rise at a steady time, and the rest tends '
        'to follow.',
    stat: Stat.vit,
    quests: [
      // sleep regularity beats duration — most-regular sleepers had 20-48% lower mortality — Windred 2024, SLEEP (UK Biobank)
      QuestTemplate(
          title: 'In bed by your hour',
          stat: Stat.vit,
          difficulty: 4,
          allDay: true,
          ladderHint: 'AN ALL-DAY LINE · CHECKS AT NIGHT'),
      // a fixed wake time is the strongest circadian anchor — National Sleep Foundation consensus
      QuestTemplate(
          title: 'Wake at the same time',
          stat: Stat.vit,
          difficulty: 3,
          allDay: true,
          ladderHint: 'EVEN ON WEEKENDS · THE REAL ANCHOR'),
      // evening screen light delays melatonin + lengthens time to fall asleep — Höhn 2023, PMC9974389
      QuestTemplate(
          title: 'Screens down before sleep',
          stat: Stat.dis,
          difficulty: 4,
          allDay: true,
          ladderHint: 'THE LAST 30 MINUTES ARE YOURS'),
      // bright room light before bed suppresses melatonin ~71% — Gooley 2011, PMC3047226
      QuestTemplate(
          title: 'Dim the lights an hour before bed',
          stat: Stat.dis,
          difficulty: 3,
          allDay: true,
          ladderHint: 'ONE LAMP · NOT THE BIG LIGHT'),
    ],
  ),
];

/// Per-quest research backing (round-19) — keyed by quest title, this powers the
/// tappable "why this helps" info-dot on catalog quest rows. Claims are warm and
/// user-facing; sources are real (PMC/DOI/named authority), honestly hedged where
/// the evidence is correlational or survey-grade. The inline `// why:` comments
/// above each quest are the terse dev note; this map is the surfaced copy.
const questWhy = <String, ({String claim, String source})>{
  // Keep your space
  'Make your bed': (
    claim:
        'Daily bed-makers report steadier sleep and a small end-of-day sense of '
        'accomplishment — a tiny keystone habit that anchors the day’s order.',
    source: 'National Sleep Foundation, Bedroom Poll (survey-grade)',
  ),
  'Ten-minute tidy': (
    claim:
        'Homes people describe as cluttered rather than restful track with a '
        'flatter daily stress-hormone rhythm — ten minutes of clearing chips '
        'away at that load.',
    source: 'Saxbe & Repetti 2010, PubMed 19934011 (correlational)',
  ),
  'Fresh sheets': (
    claim:
        'Weekly-washed sheets clear out the dust mites, sweat and dead skin that '
        'trigger allergies, congestion and broken sleep.',
    source: 'Cleveland Clinic, sleep-hygiene guidance',
  ),
  'One load of laundry': (
    claim:
        'Completing a concrete, finishable chore is exactly the kind of '
        'scheduled activity that behavioral-activation trials show reliably '
        'lifts mood.',
    source: 'Cuijpers et al. 2007, behavioral-activation meta-analysis, PMC4061095',
  ),
  'Deep-clean one room': (
    claim:
        'Homes people find restorative rather than cluttered show healthier '
        'daily cortisol slopes — one reset room turns a stressor into a refuge.',
    source: 'Saxbe & Repetti 2010, PubMed 19934011 (correlational)',
  ),
  // Tend your plants
  'Bring home a plant': (
    claim:
        'Indoor plants are linked to more positive emotion, less negative '
        'feeling, and lower blood pressure — one green thing on the sill is a '
        'real start.',
    source: 'Han et al. 2022, systematic review & meta-analysis, PMC9224521',
  ),
  'Check on your plants': (
    claim:
        'More time spent caring for houseplants tracks with higher well-being '
        'and more everyday mindfulness — the daily noticing is the mechanism, '
        'not just the watering.',
    source: 'Ma 2022, houseplant care & mindfulness, PMC9739745',
  ),
  'Water what needs it': (
    claim:
        'Caring for indoor plants lowered blood pressure and raised calming '
        'alpha-wave activity compared with a screen-based task.',
    source: 'Park et al. 2023, plant care & neurophysiology, PMC10557185',
  ),
  'Give them a real tending': (
    claim:
        'Hands-in-soil transplanting suppressed “fight-or-flight” activity and '
        'lowered blood pressure versus computer work — a weekly session is where '
        'the calm really lands.',
    source: 'Lee et al. 2015, randomized crossover study, PMC4419447',
  ),
  // Tend your creatures
  'Feed on the same schedule': (
    claim:
        'Consistent meal times help regulate a pet’s digestion and weight and '
        'ease food-related anxiety — vets recommend scheduled meals over '
        'free-feeding.',
    source: 'American Veterinary Medical Association, feeding guidance',
  ),
  'A proper walk or play session': (
    claim:
        'Daily walks and play meet a pet’s exercise and enrichment needs — and '
        'the walk doubles as yours: dog ownership is tied to about 24% lower '
        'all-cause mortality.',
    source: 'Mubanga et al. 2019 (DOI 10.1161/CIRCOUTCOMES.119.005554); AHA 2013',
  ),
  'Brush their teeth or scrub a bowl': (
    claim:
        'Most dogs and cats show dental disease by age three; brushing is the '
        'single most effective home defense against painful, organ-straining '
        'decay.',
    source: 'American Veterinary Medical Association, Pet Dental Care',
  ),
  'Everyone’s fed before you sleep': (
    claim:
        'Reliable daily care — every creature fed and watered before lights-out '
        '— is the backbone of pet welfare, and keeps a missed meal from slipping '
        'by in a busy home.',
    source: 'American Animal Hospital Association, enrichment guidance',
  ),
  'Book the vet checkup': (
    claim:
        'An annual wellness exam catches kidney, heart and dental disease early '
        '— when it’s cheapest and most treatable, before your pet shows '
        'symptoms.',
    source: 'AAHA / AVMA preventive-care guidance',
  ),
  // Feed yourself well
  'Start with a glass of water': (
    claim:
        'Water in place of sugary drinks is tied to lower diabetes and heart '
        'risk — and being well-hydrated steadies mood and focus.',
    source: 'Sugary-drink meta-analysis PMC10050372; hydration RCT PMC6068860',
  ),
  'Cook a real meal': (
    claim:
        'People who cook at home more often eat measurably better — more fruit '
        'and veg, higher-quality diets. Simple counts.',
    source: 'Fenland cohort, n=11,396, PMC5561571',
  ),
  'Eat something green': (
    claim:
        'Vegetables are how you quietly hit your fiber — around five servings of '
        'fruit and veg a day tracks with about 13% lower risk of early death.',
    source: 'Pooled cohorts, Circulation 2021, PMID 33641343',
  ),
  'Eat one meal slowly, no screen': (
    claim:
        'Slowing down lets your fullness signal land before you overshoot — '
        'faster eaters are roughly twice as likely to carry excess weight.',
    source: 'Multi-ethnic cohort PMC7230501; chewing & satiety PMC8323852',
  ),
  'Plan the week’s meals': (
    claim:
        'A little planning means more variety and a better diet — people who '
        'plan their meals eat more healthfully and are less likely to be obese.',
    source: 'NutriNet-Santé, n=40,554, PMC5288891',
  ),
  // Tend your money
  'Check your balance': (
    claim:
        'Briefly checking your accounts is financial self-monitoring — the '
        'awareness it builds links to lower spending, fewer overdrafts, and more '
        'saving.',
    source: 'CFPB Making Ends Meet survey; financial-tracking research',
  ),
  'Sleep on it before you buy': (
    claim:
        'Putting a 24-hour pause between wanting a non-essential and buying it '
        'lets the impulse settle and your rational brain re-engage — measurably '
        'cutting overspending.',
    source: 'Delay / “cooling-off” spending research',
  ),
  'Move a little to savings': (
    claim:
        'Saving a small amount on a regular rhythm — ideally an automatic '
        'transfer — is the strongest lever for the emergency cushion that most '
        'predicts financial well-being.',
    source: 'Hershfield, Shu & Benartzi 2020; CFPB Emergency Savings 2022',
  ),
  'Sit with the numbers': (
    claim:
        'A regular money review builds the self-awareness behind better choices '
        '— and a quick subscription scan catches the forgotten charges people '
        'bleed \$200+/yr on.',
    source: 'CFPB Financial Well-Being Scale; subscription-waste surveys',
  ),
  // Wind down well
  'In bed by your hour': (
    claim:
        'Sleep regularity matters even more than how long you sleep — the most '
        'regular sleepers had 20–48% lower mortality than the most irregular, '
        'independent of duration.',
    source: 'Windred et al. 2024, SLEEP, UK Biobank (DOI 10.1093/sleep/zsad253)',
  ),
  'Wake at the same time': (
    claim:
        'A steady wake-up time is the strongest signal your body clock has — '
        'consistent rise times track with better mood, metabolism, and heart '
        'health.',
    source: 'National Sleep Foundation, consensus on sleep regularity',
  ),
  'Screens down before sleep': (
    claim:
        'Evening screen light delays your melatonin and pushes sleep later — '
        'even moderate display light before bed lengthens how long it takes to '
        'fall asleep.',
    source: 'Höhn et al. 2023, Communications Biology, PMC9974389',
  ),
  'Dim the lights an hour before bed': (
    claim:
        'Bright room light before bed suppresses melatonin by about 71% — '
        'dimming the room lets the sleep signal arrive on time.',
    source: 'Gooley et al. 2011, J Clin Endocrinol Metab, PMC3047226',
  ),
};
