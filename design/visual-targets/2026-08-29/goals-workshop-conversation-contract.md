# Goals workshop conversation contract

Owner direction, 2026-08-29:

> "things are looking pretty great right now! i would do more polish passes for the overall user journey and test cases for users using the goals flow, and maybe consider further fleshing out the workshop npc with more dialogue options because i actually like what you built quite a lot."

This expands the accepted steward workshop without changing its job. The
steward may now hold one optional, state-bound conversation inside the existing
route register. Conversation is a quiet reward for returning to a character the
owner likes; it is never a gate before creating, accepting, opening, repairing,
or completing a Quest.

## Product boundary

- `Talk shop` is a secondary register action. It swaps the slips for a small
  conversation page inside the same physical register; it does not open a
  generic modal, move the person to a new screen, or cover the steward.
- The first prompt is derived from the most immediate truthful workshop state:
  a cut waiting, a route to shape, an owned Quest, a completed route, or an
  empty bench.
- Two durable craft questions explain how the steward thinks about a useful
  cut and what happens when a day changes.
- A response appears immediately after a chosen prompt and remains until the
  person chooses another prompt or returns to the routes. There is no
  typewriter delay, forced acknowledgement, timer, or automatic cycling.
- Dialogue reads existing GoalPlan and exact Quest identity only. It never
  creates or accepts a Quest, changes a route, awards progress, stores
  relationship state, praises the person generically, or claims authority over
  their future.
- The steward sounds practical, restrained, and attentive. Each line names a
  real product truth, leaves room for the person to decide, and avoids mascot
  chatter or therapy-speak.

## First production slice

From a mixed workshop register, choose `Talk shop`, ask about the most immediate
route, read one state-specific answer, ask both craft questions, then return to
the unchanged register. The same goals, plans, Quests, row order, steward state,
and one exact acceptance boundary must remain intact.

## Required states

- Mixed register: the contextual prompt follows the same priority as the
  steward pose and names the selected route truthfully.
- Empty bench: conversation remains available without inventing work to do.
- Waiting cut: the response calls the cut an offer and preserves the person's
  right to change, shrink, or take it.
- Quest on board: the response recognizes the exact owned Quest without
  celebration or duplicate creation.
- Route complete: the response closes quietly and assigns nothing new.
- 320 x 568 at 1.5x text: all prompts, the response, `Back to routes`, and the
  persistent `New goal` action remain reachable without overflow.

## Anti-fallbacks

- No branching story tree, daily greeting loop, relationship meter, dialogue
  currency, randomized quips, or completion praise.
- No second bright action. `Talk shop` remains quieter than the route slips,
  `New goal`, and any exact Quest action.
- No line may explain feelings, romanticize productivity, or repeat facts the
  visible register already says without adding the steward's practical point
  of view.
- No dialogue sound is introduced until the shared sound branch is reconciled
  and the tap-versus-scroll contract passes again.
