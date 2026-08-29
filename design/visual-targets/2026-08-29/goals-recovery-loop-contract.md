# Goals recovery loop contract

Status: owner-approved direction on 2026-08-29.

Owner response after the conceptual Goals stress check:

> "sounds good, you can get working on that"

The approved work preserves the current Goals apartment, steward workshop,
single luminous action, explicit workshop acceptance, and exact Quest identity.
It extends that system where people are most likely to need help: beginning with
low executive capacity, returning after a difficult day, pausing without losing
proof, and deciding what happens after completion.

## Product decisions

1. The focused goal gets one quiet, directly discoverable recovery entry beside
   the current action: `This doesn't fit today`.
2. Recovery is non-punitive and non-committing. It must offer three materially
   different outcomes:
   - make the current move smaller;
   - prepare the next return;
   - leave today alone without creating, unsnoozing, or rescheduling a Quest.
3. The steward is the recovery interface. His involvement must be useful and
   state-aware, not an added greeting, praise loop, or dialogue tree.
4. A new custom goal may begin from one short name or sentence. The app may
   draft a bounded provisional route from that input, while deeper outcome,
   proof, starting-point, snag, and timing questions remain available for a
   stronger cut rather than blocking entry.
5. The first Quest remains off the board until explicit workshop acceptance.
   Provisional drafting must not weaken cancellation, exact identity, or rapid
   repeat protection.
6. Leaving a goal should preserve its accumulated proof and linked Quest
   history. The ordinary action is `Shelve this goal`; permanent erasure is a
   separate, explicitly destructive choice.
7. Completed goals should preserve their evidence and offer a useful next
   posture: keep as proof, repeat, deepen, or let the goal rest.
8. Domain support must not pretend to know more than the person supplied.
   School, relationships, money, health, and ambiguous custom goals should get
   context-appropriate clarification. Money and health support may operationalize
   a user-owned plan but must not invent financial or medical decisions.

## Visual and interaction decisions

- Do not create a new dashboard, tab, floating help bubble, or second luminous
  button.
- Use the current physical/material vocabulary: quiet walnut glass or parchment
  for recovery choices, honey gold only for the one committed action, live
  Flutter text and semantics over the authored room.
- Recovery choices must remain legible at 320 x 568 and large text, park on a
  complete Reduced Motion still, and expose real semantic actions.
- The no-op choice must visibly acknowledge that today was left alone while
  preserving all Goal and Quest state.

## Representative slice

A person opens an active goal, chooses `This doesn't fit today`, selects
`Leave today alone`, returns to the same Goals room, and sees their prior proof
intact with no new or changed Quest. They may reopen recovery and instead choose
a smaller cut, inspect it with the steward, and explicitly accept exactly one
revised Quest.

## Source evidence

The accepted conceptual audit and fresh current-state captures live under:

`design/audits/2026-08-29/goals-conceptual-stress-check/`

The current recovery-state comparison is:

`design/audits/2026-08-29/goals-conceptual-stress-check/goals-stress-recovery.webp`
