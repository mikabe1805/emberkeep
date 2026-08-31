# Room of Days Build 37 owner-feedback contract

Status: direction source for a first real slice; owner review of the rendered
solution is still required before release expansion.

## Direct owner decisions

- Faint, small, and low-contrast writing on the installed phone is hard to read.
- The current Goals page is gorgeous but does not add a new useful job.
- Steward conversation exists to get to know him and let his personality shine,
  not to explain the app.
- A real everyday pattern is many visible Quests, completing only some, and
  keeping the rest as inspiration if extra time or energy appears.
- The release may pause for product corrections.

The exact owner wording and three physical-phone photographs are preserved in
`design/audits/2026-08-30/owner-build36-feedback/AUDIT.md`.

## First slice

### Product edge

Goals becomes the calm place to choose today's field from the existing Quest
pool. A person may carry up to three. Remaining scheduled Quests are not
removed, snoozed, failed, or hidden forever; they stay in `Open if it fits` as
optional inspiration. Hard dated commitments remain distinct and visible.

Reuse `Quest.priorityDay` and `priorityRank`. Do not create a second planner,
an `optional` persistence flag, or another reward model. No selection preserves
the legacy full board and offers a clear `Choose today` doorway.

When a dated field exists, completing hard commitments and the chosen field is
enough for the day. Work completed from the optional shelf earns the same normal
Quest reward and Goal progress. An unfinished shelf item carries no negative
copy, count, reward loss, or streak consequence.

### Character edge

Rename `Talk shop` to `Talk with the Steward`. Conversation remains optional,
immediate, and inside the existing lower register. It never mutates a Goal,
GoalPlan, Quest, reward, route, or acceptance callback.

The first slice uses stable questions about visible, established objects and
behavior: old route cards, the two pencils, the file box, his distance from
visitors, stopping work, and the room's quiet. His voice is observant,
contained, dry, and quietly considerate. Do not give him a name, history,
romance, therapy language, generic praise, productivity advice, randomized
quips, an affinity score, or unlocks tied to completion.

These lines develop the existing visual register but are new character writing,
not pre-existing canon. The rendered slice is the owner checkpoint.

### Readability edge

Meaningful labels and state copy never masquerade as texture:

- caps/interaction labels: at least 11sp;
- supporting body and instructions: at least 13sp;
- normal meaningful text: at least 4.5:1 against its immediate surface;
- small or image-backed meaningful text: target at least 7:1 and use a stable
  local darkening plane rather than assuming the room remains dark;
- no opacity applied directly to text that conveys state or action;
- large text may reflow or scroll instead of being clamped to preserve the art.

`textQuiet` may remain visually recessed only for non-essential ornament that
conveys no unique content, action, or state.

## Preserve

- The selected Goals apartment plate, Workshop room, Steward poses, and warm
  material/light system.
- Workshop acceptance as the only first-Quest creation boundary.
- Exact GoalPlan step/revision/attempt identity and all recovery behavior.
- Existing tomorrow, morning, Gentle Mode, Focus Mode, and reward behavior
  except where they must read the shared dated field consistently.
- Every optional Quest remains available and fully completable.

## Reject

- Hiding most Quests by default without explaining where they went.
- Calling unchosen work `left`, `missed`, overdue, failed, debt, or backlog.
- Making the Steward a route tutor, mascot, therapist, romance route, or daily
  notification source.
- Solving readability with pure white, bright cards, universal bold type, or a
  second visual system.
- Treating golden tests or desktop contrast math as physical-phone acceptance.
