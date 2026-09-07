# Revision after owner feedback: general-purpose Goals

Owner feedback, verbatim:

> to be frank with you, none of them look good except for 2 but it doesnt make any sense user journey wise

Clarification, verbatim:

> what the hell does the entryway, kitchen, bedroom stuff mean? is that meant to be the steps to keep the apartment calm? if so, then it would be very hard to make something like that look right for every type of goal because that sort of UI is very hardcoded in. you have to consider and think about that kind of stuff

## Correction

Original concepts 1 and 3 are visually rejected. Original concept 2 is a useful visual reference only; its journey is rejected. This is not approval to build that screen. Its room-specific rail incorrectly promotes an apartment example into universal product structure. More generic room labels would not fix that error.

The environmental artwork stays stable. Goal names, user-defined outcomes, variable-length plans, repetitions, evidence and current actions are live, adaptable content. No route node or goal category owns a fixed wall position. No fixed number of phases, spatial slots, obligatory map or room-per-step metaphor. Plans can be short or long; they open in a scrolling reading/working surface. On narrow displays or with large text, content grows and scrolls over the continuous background instead of shrinking into the artwork.

## Single revised concept

The revision keeps the image-2 visual direction and changes the information structure using an active skill goal, Learn to sketch. This is one refinement, not a new three-way style exploration. The frame represents a returning user with a previously accepted, still-actionable linked Quest. It is not new-goal onboarding, an automatically created plan, or a goal picker masquerading as one selected goal.

The same main composition contains: Back to goals; goal title and chosen outcome; current focus with a factual repetition count; full-plan disclosure; the accepted next Quest and why it helps; open-Quest primary action; adjust-step secondary action; evidence/notes entry. The image uses illustrative edited plan copy supported by the generic model. It must not render an invented mastery percentage or promise that a fixed number of practices means the skill is mastered.

## Content and journey checks

| Case | Same content region, different data | Correct behavior |
| --- | --- | --- |
| Finish my portfolio | Outcome: two clear project pages; current work: draft a project story; evidence: accepted project-page work | A finite route can reach its chosen proof; no stage is named after the room's architecture. |
| Learn to sketch | Outcome: draw everyday objects from life; current practice: proportions; 1 of 3 practice attempts recorded for this step | Repetitions are local to a practice step, not a mastery percentage. The accepted Quest is opened without creating another. |
| Read regularly | Outcome: a reading practice that fits evenings; current cue/action: a page after tea; evidence: actual reading attempts | An ongoing rhythm can start another evidence cycle. No last-room ending or implied total number of sessions needed for a habit. |
| Make the apartment feel calm | Outcome: a usable counter; current action: a bounded reset; proof: surface stays usable | Home-specific nouns are editable plan content only. No kitchen/bedroom art assets are required. |
| No plan yet | Goal title and user outcome remain; current action region offers plan creation/review | Never fabricate milestones, counts, or a Quest. |
| Draft or revised action awaiting acceptance | Same layout shows a proposed action and Take this Quest | Explicit acceptance creates the exact linked Quest; Back/cancel leaves the draft intact without adding work. |
| After time away or a hard day | Preserve proof, show current accepted action or current proposal truthfully, offer adjustment | Do not reset honest progress or auto-accept a smaller action. |
| 1, 7, or 20 steps; long goal title | Full-plan surface is a variable list; title and body reflow in the main content surface | No art changes, new spatial markers, tiny type, or clipped actions. |

## Existing software checked

- lib/models.dart:143 and :316: generic per-step action/proof/why/time/completions, and per-plan outcome/reality/type/proof/capacity/obstacle/steps.
- lib/goal_planner.dart:160: exact current-step/revision/attempt matching; :448-640: distinct finish, skill, routine and reset routes. The default drafts currently each have four markers; that implementation default must not become a layout contract. fromActions also creates plans from a variable action list.
- lib/goal_planner.dart:262: another evidence cycle for ongoing routines; :299: adjustment preserves prior evidence.
- lib/screens/goals.dart:521 and :715: a plan can exist before Quest acceptance; acceptance is the actual mutation boundary.
- lib/screens/goal_detail.dart:269, :424 and :549: current action, route reasoning and proof are already supported.
- lib/screens/goal_workshop.dart:86 and :307: generic goal register and plan statuses.
- test/goal_route_engine_test.dart:56 and :78: portfolio initiation avoids a home-zone action; different route types have distinct behavior. These existing tests were read for the design review, not newly run for a static image pass.

The code trace independently confirmed the structure. Source inspection and this scenario check support the concept's logic; the generated image cannot establish interaction, responsive layout or sensory quality. The upgraded sound director remains the same, with accepted contact separated from committed completion. A goal switch or plan view never awards XP.
