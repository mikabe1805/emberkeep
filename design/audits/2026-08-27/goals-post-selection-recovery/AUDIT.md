# Goals post-selection recovery audit — 2026-08-27

## Audit scope

Current production journey after a person has chosen a goal and linked Quest:
returning Goals page, room transition into Goal Detail, exact-Quest handoff,
goal-specific return plan, and hard-day recovery.

The current rendered states were re-verified against the Flutter build at
430 × 932 during this audit. Focused interaction tests also re-verified the
two-stage Goal Detail handoff, support disclosure, hard-day action, and exact
Quest promotion.

## Overall verdict

The ordinary return loop is strong, specific, and unusually kind. A person sees
one selected goal, why it matters, one exact action for today, a visible lighter
version, and evidence of prior returns. The handoff preserves the exact Quest
instead of dropping them onto a generic board.

Recovery is not yet effortless when motivation is already low. `Begin` first
opens Goal Detail and requires a second `Begin`; the lighter action opens Quest
creation instead of immediately starting; and `Unstick Me` is a global rescue
that does not reconnect its generated Quest to the selected goal. The page
helps a person who chooses to re-enter, but it does not yet notice a goal that
has gone quiet and do the last bit of planning for them.

## Flow steps

1. **Returning goal — healthy.** The first viewport keeps one focus, the saved
   reason, today's exact Quest, a goal-specific lighter version, accumulated
   evidence, and the support disclosure together. Evidence:
   `01-returning-goal.png`.
2. **Room crossing into Goal Detail — mostly healthy.** The same action survives
   the transition and the destination adds context without losing identity.
   `Begin` is misleadingly final, though: it lands on another screen with a
   second `Begin`. Evidence: `02-goal-detail-entry.png`.
3. **Evidence and return plan — healthy but passive.** Progress is framed as
   “You returned…” rather than debt, and the saved hard-day plan is visible.
   The return-plan panel edits the plan; it does not start the smaller action
   while an ordinary Quest is due. Evidence: `03-return-plan-and-proof.png`.
4. **Hard-day recovery — promising but still one planning step too many.** When
   no ordinary Quest is actionable, the smaller version becomes primary and
   the page remains calm and non-punitive. Activating it opens the Quest
   composer instead of creating and focusing a goal-linked two-minute action.
   Evidence: `04-hard-day-recovery.png`.
5. **Exact Quest board handoff — behavior healthy, visual arrival not captured
   in this screenshot set.** Current tests confirm that the requested Quest is
   promoted to the top and receives the arrival treatment. A real iPhone is
   still needed to judge whether the two-stage transition feels grounding or
   like an extra hurdle.

## Highest-impact opportunity

Turn the existing recovery pieces into one goal-aware return state:

- Preserve the room transition, but let one `Begin` terminate on the exact
  Quest rather than asking for a second acceptance.
- When the selected goal has gone quiet, replace generic support with an
  authored reassurance using real evidence: the goal is still here, and the
  person has already returned to it before.
- Offer one tap to create and focus the saved two-minute fallback, automatically
  linked to the selected goal. Keep `Resume the full plan` secondary.
- Make `Unstick Me` accept the selected goal and its saved reason/fallback so a
  rescue Quest advances the commitment the person came to recover.
- After that smaller Quest completes, return to the Goals page with explicit
  evidence that it counted toward this goal.

## Accessibility and evidence limits

- Current controls have semantics, keyboard/focus support, Reduced Motion, and
  responsive text behavior; focused tests cover the important routes.
- Screenshots cannot prove VoiceOver order, physical target comfort, haptics,
  OLED separation, or whether the transition duration feels supportive.
- A focused 1.5–2× Dynamic Type recovery journey from fallback through Quest
  completion is not yet represented in this audit set.

## Verification

- Three current screenshot scenarios passed: active return, hard-day return,
  and Goal Detail support/proof.
- Four focused interaction scenarios passed: two-stage exact action, support
  disclosure, hard-day action, and requested-Quest promotion.
