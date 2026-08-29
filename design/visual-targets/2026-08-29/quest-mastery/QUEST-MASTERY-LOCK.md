# Quest mastery and automatic rise lock

Status: selected first-slice direction, pending fresh owner checkpoint.

## Owner corrections

> "great stuff! i would just make sure that the system currently offers support of equal value regardless of what the goal is-- so could be someone doing better in school, cleaning up the apartment, working out, etc-- and nothing feels like it's hardcoded to only be supportive of one type of goal and quest."

> "speaking of, im paying close attention to the user case of my mom, and i saw that on her \"walk 10 minutes\" quest she had 16/5 done and it didnt actually \"rise as she went\". at the very least the default quests should be able to upgrade themselves automatically/have a new guild or something to celebrate consistency and quest completion. honestly a special guild for quests outline that gets fancier the more a quest is completed kind of like in overwatch could be sick"

## Product lock

- Mastery belongs to every recurring Quest, independent of domain, title, goal type, verification method, or whether the Quest has a difficulty ladder.
- A completed school, apartment, fitness, creative, care, social, or generic Quest advances the same permanent mastery count by one.
- Missing, snoozing, rescheduling, or lowering a prescription never removes mastery.
- Mastery records accumulated practice; it does not increase XP, gate access, create pressure, or imply that one domain is more valuable than another.
- Curated non-custom Quests with an authored concrete ladder rise automatically at each five-completion boundary while a rung remains.
- Custom Quests and maintenance work do not silently become harder. They gain mastery without automatic prescription changes unless a future explicit setting opts them into a real ladder.
- A capped ladder stops asking to rise. Permanent mastery continues.
- A legacy overflow such as `16/5` receives one safe catch-up rise on restore, keeps the real completion history as mastery, and resets the current-rung counter instead of jumping several prescriptions at once.

## Visual lock

- Extend the existing jeweler's completion orbit; do not add a second card, currency, floating badge, or unrelated fantasy frame.
- The resting card remains one authored dark book-cloth object. Mastery adds small static brass construction to the orbit only because it records real completion history.
- Thresholds are cumulative: `5 · KEPT`, `15 · PRACTICED`, `40 · GILDED`, `100 · MASTERWORK`.
- The compact row communicates tiers through geometry, not another text chip: additional hairlines, cardinal stitch marks, and a final lower notch become progressively richer without changing row height.
- The featured card may name the accumulated count in one quiet line after five completions. The reward receipt names a tier only when it is newly crossed.
- Tier geometry remains readable without color, keeps the existing stat/domain color secondary, and exposes the mastery count and tier through one semantic description.
- No autonomous sparkle or looping animation. A newly crossed tier may settle once with the existing completion event; Reduced Motion jumps to the finished geometry.

## First-slice states

1. `Walk 10 minutes`, fourth completion: current prescription, `4/5`, no mastery tier.
2. Fifth completion: prescription becomes `Walk 20 minutes`, rung counter resets, mastery becomes `KEPT`, and the completion receipt names both earned changes once.
3. Legacy `16/5`: restore becomes one safe catch-up rise, `PRACTICED · 16 TIMES`, and no raw overflow remains.
4. Study, apartment, and creative maintenance Quests at the same completion count: identical mastery tier geometry and semantics, with no forced difficulty increase.
5. Final authored ladder rung: no rise prompt or impossible progress chip; mastery remains cumulative.

## Rejected substitutions

- A universal streak or consecutive-day requirement: it would punish pauses and confuse consistency with perfection.
- Fitness-only authored ladders presented as the main progression system: it would leave study, home, care, and creative work structurally second-class.
- Automatically generating harder prescriptions from arbitrary custom text: it can make maintenance, medication, care, or already-difficult work unsafe or dishonest.
- A full-card neon rank border, repeated tier chip, or constant Overwatch-like spectacle: the reference is accumulation and recognizability, not copied competitive-game chrome.
