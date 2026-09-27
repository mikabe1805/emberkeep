# Claude soul pass, 2026-09-27

Branch `claude/soul-ui-pass`, built on `codex/quests-authored-page` plus the
Codex work that was left uncommitted when its session was terminated at 00:15
(carried over verbatim as commit `356685c`).

## What prompted it

- Mika on the Quests first slice (Codex session `rollout-2026-09-26T21-53-49…`,
  line 1977): "good stuff, although the text above the main quest looks pretty
  like trash and not properly formatted/integrated into the app. by the way, i
  really liked it in the early builds of the app when level ups filled the
  entire screen with the "you did it!" screen. it felt very rewarding/encouraging"
- Mika on 2026-09-27: use the renewed soul guidelines to improve Room of Days,
  especially UI and UX, and find opportunities Codex missed.
- Open repeated complaints in `soul/library/PROJECTS.md`: "i don’t like how much
  the things in the middle of the screenshot blend together" (2026-09-18) and
  "i cant stand colored blocks like the peach and green stuff" (2026-09-05).

## Changes, with the reason each exists

| Change | Why |
| --- | --- |
| Today's three moves onto the Quest instrument as three small orbits plus title and count; FOCUS and ADD share the strip | The text above the Main Quest was the complaint. Codex's interrupted fix moved it below the card as a slab, which left four bands (slab, Open if it fits, a lone FOCUS/ADD pill, freeze row) between the featured Quest and the list: the "blend together" problem. The orbits reuse the Quest check control's own language and close when one of the three is kept. |
| One Side quests divider at the place those Quests appear | The old toggle sat three rows above the Quests it revealed. |
| Freeze reserve, streak and CLOSE DAY follow the work in the footer | Continuity still visible; no longer a band in the middle of the board. |
| "Today's three" everywhere (was "Today's field" on Quests and Goals) | One heart feature had three names; Mika's own words are "top 3". |
| Level-up: YOU DID IT. over a numeral that lights its backdrop, a two-line UNLOCKED reveal, no duplicate LEVEL N, and "12 quests since level 9" | Mika's ask. Codex's version rendered as one flat brown sheet. The evidence line comes from a new `completionsAtLastLevel` count; older saves stay silent rather than guess. |
| My Space cards share one faceted walnut surface | Green, peach and plum fills with a lime stripe were exactly the colored blocks he can't stand, on rounded cards beside faceted ones. |
| SHARE MY BUILD becomes a brass-edged secondary; "1 QUEST DONE" | Two luminous honey buttons on one screen (design bible allows one); plural bug. |
| Choose today lists Quests directly when it has nothing to suggest; rows say "Body · every day" | Found in the emulator walkthrough: an extra tap before any choice, and "A quest for you" on every row. |
| page/navigate sound lane for the new doors | glass/navigate is not a shipped lane (silent fallback, failing full-suite check). |

## Evidence

- `quests-before-after-390x844.png`, `levelup-before-after-390x844.png`,
  `myspace-before-after.png`: same size, same state.
- Android emulator (profile APK) walkthrough: choose three, complete one, watch
  the first orbit close, Side quests, footer, Me and My Space.
- Complete suite and analyzer locally; CI repeats both.

## Not verified here

- Physical iPhone feel: haptics, sound timing, scroll, the orbit closing under a
  real thumb.
- The level-up on a real threshold on device (widget test covers the real
  completion → receipt → takeover chain).
- Mika's verdict. Codex's open question also still stands: after the featured
  Quest is completed, no card is featured until another is tapped.
