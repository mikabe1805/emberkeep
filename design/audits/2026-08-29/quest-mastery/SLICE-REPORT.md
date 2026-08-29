# Quest mastery and automatic-rise slice

Captured: 2026-08-29T02:19:38-04:00
Implementation: `worktree:0e666f2639fc:c1ab39bd5db75ef3d9e4e570`

## Outcome

- Every committed Quest completion now earns the same permanent mastery, regardless of whether the work is study, home care, movement, creative practice, relationships, or a Workshop route.
- Curated Quests with a real authored ladder rise automatically on the fifth completion. Custom and maintenance work earn mastery without silently becoming harder.
- The legacy `Walk 10 minutes` `16/5` state migrates by one safe rung, preserves all sixteen completions as mastery, and cannot display the raw overflow again.
- Workshop routine attempts keep mastery on the stable route marker even though each accepted attempt is represented by a fresh Quest object.
- The existing Quest orbit gains static brass construction at KEPT, PRACTICED, GILDED, and MASTERWORK. It does not add another currency, full-card rank frame, or looping animation.

## Verification

- Full Flutter suite: **846 passed**.
- Full analyzer: **no issues found**.
- Focused mastery, visual, planner-neutrality, and simulation suite: **28 passed**.
- Independent read-only critique initially found that regenerated Workshop attempts reset their Quest object. The implementation moved that history to the stable goal marker, added a five-attempt persistence regression, and the reviewer rechecked both behavior and rise-progress semantics as **pass**.
- Rendered states inspected at 430 x 932 and 320 x 568 with 1.3x text. The repaired `16/5` state reads `Walk 20 minutes`, `0/5`, and `PRACTICED · 16×`; the mixed-domain sheet shows the same ornament ladder across study, home, movement, creative, and relationship Quests.
- The live web preview was hot-restarted after the final model and semantics changes.

## Remaining gate

Physical iPhone acceptance remains pending. Desktop tests and deterministic renders cannot establish the tiny brass detail on the exact display, haptic timing, thumb response, scroll feel, or owner judgment of the earned ornament.
