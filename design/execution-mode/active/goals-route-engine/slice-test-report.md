# Goals route engine slice test report

Captured for implementation revision `worktree:0e666f2639fc:5d340497f462eebdd616ac44` on 2026-08-27.

## Automated behavior

- `flutter analyze`: pass, no issues.
- Complete Flutter suite: pass, 815 tests.
- Route-engine suite: pass, 12 tests covering explicit aim/reality/proof/capacity, distinct route types, exact marker/revision/attempt selection, out-of-order and stale rejection, rescue restoration, legacy progress preservation, changed aim, routine cycles, and persistence.
- Goals interaction suite: pass, 28 tests covering creation, one-time opening, room travel, exact Quest handoff, legacy route construction, recovery, fallback reuse, Reduced Motion, and overflow stress.
- Screenshot state captures: pass for AIM, REALITY, ROUTE, active threshold, adjusted threshold, opening arrival, and goal detail.
- Deterministic motion captures: pass at 30 fps for the one-time opening and 60 fps for the planned returning-room handoff.

## Build and preview

- `flutter build web --release`: pass.
- Preview server: bound to `0.0.0.0:4174` and serving `build/web`.
- Desktop check: `http://127.0.0.1:4174` returned HTTP 200.
- LAN check: `http://192.168.0.85:4174` returned HTTP 200 from the host.

## Rendered evidence inspected

- `test/goldens/goals_quick_create_430x932.png`
- `test/goldens/goals_quick_create_reality_430x932.png`
- `test/goldens/goals_quick_create_route_430x932.png`
- `test/goldens/goals_personal_index_active_430x932.png`
- `test/goldens/goals_personal_index_adjusted_430x932.png`
- `test/goldens/goal_opening_03_arrival_430x932.png`
- `test/goldens/goal_detail_habit_support_430x932.png`
- `design/comparisons/2026-08-27/evidence-goals-route-backed-threshold.png`
- `design/comparisons/2026-08-27/goals-threshold-room-motion-contact-sheet.png`

## Remaining gate

Code and rendered evidence are ready. Owner/device acceptance is still pending: the decisive check is one real, non-demo goal created and recalibrated on the owner's phone.
