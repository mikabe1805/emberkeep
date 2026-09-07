# Preview handoff correction — September 6, 2026

The owner reported that the supplied sample screens did not appear in the opened preview. The server on `127.0.0.1:8393` was serving the correct implementation, but the offline worker could keep serving an old Flutter bootstrap indefinitely. The root URL also opened Quests, while the sample sheet began on Goals. The screenshots used a separate Playwright profile with synthetic saved progress; that is not evidence of what the owner's in-app browser displayed.

## Changes

- Flutter release entry files now refresh from the network without the HTTP cache, update the offline cache, and fall back to cached files if the network fails. A cache-write failure cannot replace a successful fresh response with stale bytes. Ordinary artwork remains cache-first. This is not an atomic multi-file release guarantee.
- `/?page=goals` initializes the actual Goals tab. The ordinary root still opens Quests. Existing onboarding and saved-state handling remain active.
- A local-only helper at `/refresh-working-preview-20260906.html` unregisters only this preview's app worker and removes only `room-of-days-shell-` caches before opening Goals. It is restricted to `127.0.0.1:8393`, never writes saves, localStorage, or IndexedDB, and remains on an error page if unregistering fails. Source is in `tool/preview/`; it was copied into the local build after offline preparation and is not part of shipping `web/`.

## Evidence

- Focused deep-link tests: 4 passed. Main/shell/link-test analysis: no issues.
- Worker/helper behavioral tests: 6 passed. These dispatch the actual worker fetch handler, check online replacement, offline fallback, quota failure, cache-first artwork, helper scope, and failed cleanup.
- Existing native/release regression: 17 passed. Syntax and diff checks passed.
- Rebuilt release JS/Wasm; offline preparation completed (295 assets). HTTP-served JS, Wasm, worker, and offline manifest hashes match this build; exact hashes are in `preview-handoff-evidence.json`.
- Existing isolated browser profile refreshed from worker version `4128543540` to `2961611379` and landed directly on Goals.
- The stale test app cache was removed and an unrelated cache was preserved. The saved game was identical except its normal `state.lastModified` timestamp: 15 XP, one completion, all Goals, Quests, daily ranks, notes, and preferences retained.
- Visually inspected the settled Goals and chooser. Verified Goals → Change opens recommendations, and Goals → Open Quest → Open 10-minute session opens the new session view. Screenshots: `output/playwright/16-preview-goals-settled.png`, `17-preview-chooser-fixed.png`, `18-preview-session-fixed.png`. Screenshot 15 was taken before artwork finished loading; use 16 for the settled visual state.

## Handoff boundary

The corrected helper URL was sent to the Codex browser panel; the tool returned `queued`. That does not prove the owner's browser completed the refresh. Provide the same link directly in the user response. Browser verification above belongs to the isolated synthetic-save profile; the helper preserves the owner's existing save rather than replacing it with that sample.
