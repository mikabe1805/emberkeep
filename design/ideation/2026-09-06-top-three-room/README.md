# Goals and Quests: today's three in a layered room

Date: Sunday, September 6, 2026.

## Owner direction

> i like this, but also the other most important role of the goals page is setting up your top 3 of the day which has been helping me nicely. so maybe think of new designs too and make them even more beautiful/spacial/3d feeling and layered and for the quests page too

The liked reference is ../2026-09-05-room-evolution/04-goal-at-the-workbench.png. This is positive direction on its general-purpose composition, with a request for further exploration and the missing daily top-three role. Earlier original concepts 1 and 3 remain rejected. The apartment-room route rail remains rejected. No production implementation selection is inferred from this new image set.

## Scope and display mapping

Exactly three independent generated images were shown in actual display order. They are connected views of the same proposed experience, not mutually exclusive replacements for each other:

1. Goals landing: the chosen three are the dominant working surface; new goals and the goal collection remain discoverable.
2. Choose today: a nearer working layer shows two draft choices and available ordinary Quests, with explicit Keep these 2 and Cancel.
3. Quests: the first selected task is brought forward with an explicit completion control; the other two remain visible and optional work stays behind a disclosure.

The selected unique titles in saved-state views are Read ten pages, Take a ten-minute walk, and Sketch one object, in that order. The chooser shows the first two while the third is still available; it can save two, or add the third and save three. Goal associations are illustrative: Read regularly and Learn to sketch. The walk demonstrates an ordinary Quest that need not belong to a Goal. All names, dates and numbers are mock data, not a report of the user's activity.

The first and third images use the production navigation Me / Quests / Goals / Plans / Journal; the earlier liked mock's More tab was an inaccurate reference detail. The chooser is a contained working layer with explicit back/cancel, so its tabs may be hidden.

## Composition and interaction

The room, desk, glass working plane and active control have distinct depths. Warm lamplight explains rim highlights and shadows. Near-edge occlusion and a thin glass sidewall provide depth without requiring new scenery for each goal or task. Goal plans remain variable content; the up-to-three day capacity is the established product rule, not a universal number of goal steps.

Goals has two useful jobs: shaping today and shaping/reviewing longer goals. In the saved state, the three titles and Change control are directly visible; Open today's quests hands off to the existing board. Before a field exists, this same main area should offer Choose today's three rather than manufacture three sample slots or imply work was selected. Long-term goal rows lead to the previously explored adaptable detail/workshop flow.

## Current behavior verified by source trace

- Goals and Quests share the picker and date-scoped field: lib/screens/goals.dart:392, lib/screens/quests.dart:425 and lib/content/day_planning.dart:6.
- Review is allowed for one, two or three; a fourth is rejected and zero cannot be confirmed. Cancel returns without mutation: lib/widgets/top_three_wizard.dart:75, :163; goals.dart:414; quests.dart:445.
- Saving preserves order as priorityDay and priorityRank 1-3; another date is not cleared: day_planning.dart:99 and test/day_planning_test.dart:34.
- Dated events and all-day commitments are separate. They remain ahead of ordinary chosen work on the board and do not consume the three slots: day_planning.dart:20; quests.dart:2911 and :2938. These concept frames have no scheduled commitment; an actual day with one must still show it.
- Completed and snoozed selections remain part of the day's chosen field. No automatic replacement or extra completion pressure: day_planning.dart:54; quests.dart:2882 and :3567.
- Important current limitation: the picker and applyDailyField are title-keyed, not stable-Quest-ID keyed. The images use distinct titles. Do not claim duplicate-name identity has been solved. New drag/reorder interaction is not currently shipped; these images use selection order and do not depict a drag handle.
- Goal planning and Quest selection remain separate: choosing an existing Quest for today cannot create, accept, finish or advance a goal plan.

A bounded read-only source review by the supporting agent confirmed these invariants. Existing tests were read, not newly run for a static design pass.

## Proposed motion and sound behavior

Use the existing central audio director and room SFX; the prior sound-and-behavior.md establishes that Build41 already holds the newer tap pack.

- Open the chooser with a short move toward the working plane; the room falls slightly out of focus while live text remains crisp. Back reverses that relationship without a timed stop or extra required tap. Reduced Motion uses a brief fade and unchanged layout.
- Accepted choice produces one material contact and a short local settling motion into the chosen group. Plus and minus remain direct tap targets; no drag skill or sound is needed to understand selection. Scrolling and cancelled input must not play success.
- Keep saves the exact ordered field, then settles that group onto the Goals desk with one place cue. Cancel does not play a saved-outcome cue. Field selection grants no XP or stats.
- Open today's quests preserves the visible selected identities and order into the board. Bringing a task forward only selects it; the explicit completion control owns the completion mutation.
- On successful completion, respond on the exact task first, then show real XP/domain/currency consequences and one completion voice. Preserve undo and the remaining chosen tasks. Do not automatically fill the cleared space with new work or start another Quest.
- In a live implementation, background and physical material planes can move slightly relative to each other; text and touch-target locations must stay stable. Avoid repeated camera journeys during everyday use, uncontrolled scroll-linked movement, and motion that delays a useful action.

These timings and relationships are proposed, not device-tested claims. Central duplicate, priority, mute and overlap gates remain authoritative.

## Research continuity

The user now supplies direct evidence that this top-three choice has been helping them; preserve that successful behavior as an owner requirement. It is not a population-level claim that exactly three is optimal. The existing research-and-return.md and prior sound-and-behavior.md retain primary references on consistent cues, autonomy, feedback and neutral return. No new habit-efficacy claims are made for these images.

## Visual inspection and remaining corrections

All three native image results were inspected. The same warm materials, room depth and selected content are carried across the set. The chooser correctly shows two draft selections and a Keep these 2 action. The Quests image keeps all three selected titles visible, the RPG build visible, one completion action, and optional work secondary.

Generated-image details are not immutable implementation requirements:

- Goals has some perspective tilt in the text and too much ornamental texture on its button. A live build must retain material depth with unwarped typography, stable hit targets and quieter button texture.
- The chooser's nested outlines and repeating texture can be softened; the selected and available groups need spacing and subtle rules, not more frames.
- Quests omitted the requested Today’s three / Change / 0 of 3 completed heading. The live composition must restore a compact selected-field heading and direct change affordance, using less hero/rail height if needed. The ordinals and Chosen for today text alone are not the full management contract.
- Typography remains more serif-heavy than requested. Resolve the live body face and contrast deliberately rather than copying generated type artifacts.
- Large text, long names, one/two choices, dense goal lists, explicit commitments, completed/snoozed work, empty/no-plan state and returning after absence still need live layouts and interaction checks. A static image cannot establish those properties.

No production code changed, no new app build was claimed, and the existing dirty Quests code was preserved. The images and exact prompts are review artifacts. Overall product implementation and sensory acceptance remain separate future evidence.
