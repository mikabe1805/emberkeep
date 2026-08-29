# Goals opening initiation slice verification

Recorded and re-verified 2026-08-27 after the owner-requested typography and
control rebuild, Fable threshold review, intermediate-scale correction, and
final motion recapture. Current scoped implementation revision:
`worktree:0e666f2639fc:f0d06378ff0e9801cb25d0d1`.

## Automated checks

- `flutter analyze`: passed with no issues.
- Focused Goals creation, opening, exact-Quest handoff, stage back, in-flight
  back, rapid repeat, and persistence checks: passed.
- Targeted opening and room-travel screenshot checks: passed, including the
  refreshed doorway midpoint.
- Full Flutter suite: 795/795 passed.
- One-time opening capture harness: passed at deterministic 30 fps with 139
  frames / 4.633 seconds, including authored holds and pressed frames.
- Compact opening capture harness: passed at 320 x 568, 1.5x text, 30 fps,
  with a visible room-only breath before the threshold folio resolves.
- Returning-room capture harness: passed at deterministic 60 fps with 110
  frames / 1.833 seconds, including pressed and settled frames.
- `flutter build web --release --wasm`: passed and
  produced the currently served phone preview.
- The direction gate passes. The slice progression gate remains intentionally
  blocked at `slice_ready_for_owner` until Mika accepts the current physical
  phone experience; code and visual-evidence verdicts are independently pass.

## Journey coverage

- Quick creation with an exact user-authored first Quest.
- Actionless quick creation with a conservative app-prepared Quest.
- Advanced wizard creation and starting-point adoption into the same one-time
  initiation; completed and legacy goals keep the direct return.
- User-controlled desk and threshold holds with 1480 ms and 1280 ms travel,
  doorway-motivated exposure, and a 1640 ms ordinary return route.
- Back from arrival to threshold to desk, exit without acceptance, and resume.
- System back during an in-flight camera move cannot discard the opening.
- Exact Quest object handoff, persisted completion, and no replay on return.
- OS and product Reduced Motion behavior using composed still crossfades.
- 320 x 568 at 1.5x text and 200% long copy remain reachable and overflow-free.
- Live threshold-plan geometry remains registered to the painted arch.
- The journey uses stable causal verbs: `See the plan`, `Step inside`, and
  `Begin`; the exact first move retains one authored serif role through every
  beat.
- The moving back control is visibly disabled and excluded until the room
  settles; one accepted press owns one haptic/sound cue.

## Visual and independent review

- Fresh normal, 1.15x, compact, 200% long-copy, and returning states were
  inspected at original resolution after the final responsive clasp and
  measured doorway-folio fit.
- Claude Fable 5 passed the rebuilt desk and arrival, then identified the dim,
  over-occluded threshold, missing serif payoff, abrupt 200% clip edge, and
  untested 1.15x clasp as concrete failures. Each was corrected and recaptured;
  the 1.15x capture reproduced and then verified the clasp-wrap fix.
- The Gemini route probe passed, but its read-only review produced no usable
  report after project-directory reads were auto-rejected. It is not counted
  as agreement.

## Preview check

- `http://127.0.0.1:4174/`: HTTP 200 on the current release build.
- `http://192.168.0.85:4174/`: HTTP 200 on the Wi-Fi address.
- The server listens on `0.0.0.0:4174` for same-network phone access.

## Remaining gate

No deterministic test proves physical iPhone haptics, phone-speaker timing,
OLED value separation, 2.22x crossing sharpness, real frame pacing, edge-swipe
feel, or whether the slower held beats feel anticipatory rather than ponderous
in the owner's hand.
