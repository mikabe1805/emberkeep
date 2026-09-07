# Useful depth around the liked chooser

2026-09-06. This is a further image exploration, not a production implementation.

## Owner direction and source identity

> i think it's a pretty good direction! i think out of the 3 screens the second you generated is by far the best, as not only does the UI look beautiful but it also adds extra functionality that wouldnt be there otherwise, that being the extra recommended quests you can choose whether or not to bring into focus today. i would honestly try imagining more potential redesigns around bringing out that kind of functionality and features while still looking beautiful and feeling high tech, but if you cant think of anything better/anything else to flesh out better then you can go into the direction you proposed

The referred-to second screen is ../2026-09-06-top-three-room/02-choose-today.png, the 2-of-3 chooser, NOT the earlier apartment route or the newer focus timer in this set. It was opened and used as an actual attachment in all three new image calls. Earlier approval of the general-purpose goal workbench remains context. Rejected palettes, flat colored panels and architecture-bound goal stages remain rejected.

The owner offers implementation of the established direction if no better exploration emerges. Three concrete useful extensions were found, so this pass explores those before changing the app. Preserve the already approved chooser as the foundation. Do not infer selection of a new feature from the order generated.

## Current capability versus proposal

| Job | Already available | New work represented by the concepts |
| --- | --- | --- |
| Choose one to three ordinary Quests | Goals and Quests share top_three_wizard; date and order persist; cancel is non-mutating | A useful, directly visible candidate region and single clear save composition |
| Get suggestions with reasons | Gentle Mode has a deterministic urgency/priority/dread/difficulty ordering; goal route data supplies the exact next action | A distinct recommendation policy, reasons and a known-session-length filter in the ordinary chooser |
| Start a timer-configured Quest | TimerOverlay counts down effectiveTimerMinutes; music is session-scoped; honor completion is available | A Ready stage that assembles goal guidance, the person's real goal note, music choice and explicit Start in one workspace |
| Adapt an action | Goal check-in/recalibration, current-step proof, fallback action and resumeAfterRecovery exist | A before/after draft with true non-mutating cancellation, explicit replacement and preservation of the current daily-field slot |

The previous image's More quests were available candidates, not a learned or contextual recommendation engine. This distinction was explained to the owner at the start of the pass. No nonexistent ranking or personal learning is claimed as shipped.

## Three independent outputs, in actual display order

1. Choices with a reason: one chosen reading Quest, a 10-minute session filter, and two suggestions with truthful reasons: a next accepted sketching practice with a configured 10-minute timer, and a saved five-minute desk-clearing session. The existing chosen task is unaffected by filtering. Browse all preserves untimed and other eligible choices. Keep this 1 is valid.
2. A session ready to begin: an already accepted, timer-configured Sketch one object Quest. Ten minutes is its saved timer, not an inferred estimate. The clock reads READY; Start begins it. Goal guidance and a real linked goal note are brought into the workspace. Music is explicitly Off and optional. I already did it is the existing base-reward path. Opening the screen earns nothing.
3. A smaller attempt, clearly chosen: a draft replacing that sketch Quest with a five-minute outline attempt. The person can inspect original/proposed work, preserved proof, and restoration of the regular practice after the recovery attempt, then accept or keep the original. This is not a midnight reset, automatic absence intervention, completion or goal achievement.

These are complementary potential improvements around the same design language. Recommend implementing the reasoned chooser and the focused workspace first; the smaller-attempt preview is valuable but has a more demanding atomic state boundary.

## Behavior design requirements

### Recommendations

Start with transparent, deterministic rules over actual local data. A learned model is unnecessary for this first version. Candidate eligibility remains existing ordinary open schedulable Quests; dated events and all-day commitments are not optional suggestions. Completed/snoozed tasks, stale goal revisions, already selected tasks and unaccepted plan proposals cannot appear as addable new recommendations.

A reason such as Next practice in Learn to sketch is permitted only if the candidate matches the currently accepted plan action, step, revision and attempt. A short-session reason requires a real configured timer. Do not equate plan.minutes, a title mentioning minutes, or difficulty with a measured duration. The time filter applies to suggestions for one session; it is not an assertion that the entire chosen day fits that duration. Untimed work remains discoverable under Browse all and Any. With no valid evidence, show available choices without inflated personalization.

One, two or three choices are valid. Selecting or ranking grants no XP, never accepts a goal plan and never replaces an existing chosen task automatically. At capacity, an addition must offer explicit replacement or explain the limit rather than evict something. Current daily-field identity is title-keyed; duplicates require a proper identity decision before implementing recommendation/replace behavior. Dismiss/rejection learning is not currently stored and is not promised.

### Ready workspace and timer

Only construct this timer workspace for a Quest whose verification and effectiveTimerMinutes support it. A goal action's capacity estimate does not enable a countdown by itself. Non-timer Quests need their correct ordinary, journal or workout action. Existing TimerOverlay starts its deadline in initState; the proposed Ready stage must defer mounting/starting the real countdown until Start is accepted. No autoplay timer or lost pre-start minutes.

Use the currently relevant GoalPlanStep's live guidance and goal.notes when available. Do not invent a persisted mini-step checklist, a prior note, an outcome, or personal coaching. The example note is illustrative mock data. Hide absent context cleanly.

Music choices stay local to the session and restore the normal room role on exit. Existing honor completion grants the base result; timer proof uses the existing verified outcome path. Preserve cancellation, mute, lifecycle resynchronization and one completion. The current timer already completes through onFinished; a new Ready stage must not create a second reward path.

### Smaller-attempt review

The image's Keep original is a NEW behavior contract for this review. Current goals.dart:958 revises the plan, removes unfinished old-revision Quests and persists before opening Workshop. A faithful implementation must hold the proposed revision separately until acceptance, rather than merely adding a Keep original label over that existing flow.

Acceptance must reconcile the live goal revision, replace only its exact unfinished Quest, preserve unrelated completed work and later notes, and carry the intended daily-field date/rank to the accepted replacement. Cancelling must leave the original plan, Quest and chosen field unchanged. No rollback of an entire old GameState snapshot.

Timer semantics need explicit handling: GoalPlanner.questFor currently clones a configured template's timer fields, while its non-template branch does not automatically create a timer from step.minutes. Thus the image's five-minute timer cannot be achieved by only setting step.minutes=5. Construct and validate the replacement Quest's actual timer configuration intentionally. Restore the normal practice through existing resumeAfterRecovery behavior after the attempt, not through a guessed date rule.

## Source checks

Read-only source checks and the supporting agent's inventory used:

- lib/widgets/top_three_wizard.dart:11, :66, :163 — Set<String> title selection, cap, two-stage picker and cancel.
- lib/content/day_planning.dart:20, :54, :99, :152 — commitments, retained selected work, ordered date-scoped field and Gentle Mode suggestion rule.
- lib/screens/quests.dart:425, :895 — daily selection and correct typed completion routing.
- lib/widgets/timer_overlay.dart:20, :57, :73 — configured timer/honor/cancel, immediate timer initialization, one deadline result and focus-music role.
- lib/goal_planner.dart:160, :202, :299 — exact action matching, template/no-template Quest construction and recovery snapshots.
- lib/screens/goals.dart:958 — current adjustment mutates before Workshop.
- lib/models.dart:449 — actual goal notes, why, fallback fields and retained proof.

Existing tests were consulted in earlier passes; no app tests were run for these static mockups. Existing dirty production code was not modified.

## Material, motion and sound

High-tech is treated as precision and useful causality within the existing warm identity. A tiny prismatic catch belongs only to the currently active time filter or the exact changed duration, not a full-screen AI glow. Glass edges and shadows describe depth; text and hit targets remain stable and legible. Avoid stacks of independently blurred panels and busy embossed button textures.

Accepted taps acknowledge once through the existing sound director. Opening reveals a contained working layer locally. Filtering changes the candidate region without clearing chosen work. Starting a timer gives one local state transition and optional focus music, with no fake celebration. Accepting a revised action settles the changed object once; a real completion owns the later reward voice. No rhythmic countdown ticks, repeated startup chimes, auto-started next Quests or forced camera travel. Reduced Motion and stronger contrast must keep the same information and clear controls.

## Primary design research checked in this turn

Apple's material discussion supports matching refraction/shadows to a functional layer, local interaction feedback, content clarity and explicit accessibility adaptation. Applying those mechanisms to Room of Days is our design inference; this Flutter app does not automatically receive native Liquid Glass behavior. [Apple: Meet Liquid Glass](https://developer.apple.com/videos/play/wwdc2025/219/)

Google PAIR's explanation guidance supports giving a short, relevant rationale tied to the person's action and the actual data involved. We apply that principle to a deterministic recommendation design, not as evidence that this app has an AI model or that a suggested Quest will improve adherence. [PAIR: Explainability + Trust](https://pair.withgoogle.com/chapter/explainability-trust/)

The earlier research-and-return.md retains primary behavioral references and their limitations. The owner's direct report that the top-three choice helps them is a product requirement, not proof that three is universally optimal. No new efficacy claim is made here.

## Visual review and limits

All three exact generated outputs were inspected. They retain the liked warm dimensional chooser surface, expose a clear new job, and keep each primary action distinct from completion or implied reward. The first shows reason text and a local active-filter highlight. The second shows a readable Ready timer and Off music state. The third distinguishes original/proposed work and preserves a visible choice to cancel.

Generated details to refine before implementation: the first two still contain repetitive texture and extra nested outlines despite the quieter prompt; tune those as physical materials, not ornamental patterns. The third added an unrequested walk/date footer copied from the reference context; remove that stray footer instead of treating it as model-backed copy. The five-minute rim should read as a value highlight unless it actually opens timer editing. No arbitrary invented glyph or drawing scene requires bespoke artwork per Quest; use the existing semantic icon system.

Static images do not verify long text, large text, hit targets, device timing, sound quality, filtering, cancellation, timer lifecycle or atomic replacement. These concepts and exact prompts are preserved for review. No production build, deployment or full-redesign completion is claimed.
