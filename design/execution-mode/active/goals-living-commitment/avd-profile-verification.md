# Goals room travel — Android profile smoke check

Captured: 2026-08-27T02:37:06.851Z

Implementation revision:
`worktree:0e666f2639fc:474563f26f6d2549f7e22031`

## Runtime

- Existing `roomofdays` AVD: Pixel 7, Android API 36, x86_64.
- Display: 1080 x 2400, density 420 (approximately 411 x 914 logical),
  60 Hz.
- Flutter profile build using the production Goals widgets and route through
  `tool/goals_room_device_preview.dart`.
- Impeller OpenGLES renderer with the emulator's `-gpu host` override.
- The deterministic target freezes only input data and time. It does not
  duplicate or replace `GoalsPage`, `GoalDetailScreen`, or `goalRoomRoute`.

## Frame-presentation smoke check

Three warmed Begin journeys were measured from the app SurfaceView's
SurfaceFlinger presentation timestamps. The latency buffer was cleared before
each press, and screen recording was disabled during measurement.

| run | presented frames | span | p50 interval | p90 interval | p95 interval | longest | estimated missed refreshes |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 54 | 916.849 ms | 16.685 ms | 18.192 ms | 18.928 ms | 47.716 ms | 2 |
| 2 | 54 | 915.185 ms | 16.586 ms | 18.620 ms | 24.745 ms | 32.815 ms | 2 |
| 3 | 55 | 914.307 ms | 16.547 ms | 18.431 ms | 19.256 ms | 33.561 ms | 1 |

The route therefore sustains near-refresh median presentation on this real
Flutter engine and does not show a persistent compositing stall. One or two
refreshes were missed in each emulator run. The app's initial profile warm-up
reported skipped frames before measurement; those frames were deliberately
excluded by clearing the presentation buffer after the app had settled.

## Render inspection

The paired endpoint artifact is:

`design/comparisons/2026-08-26/goals-room-avd-host-profile-rest-arrival.png`

It shows the same current-Quest card at rest and after the room journey. At the
approximately 411 x 914 logical AVD viewport, the title, reason, current action,
lighter route, support disclosure, detail heading, evidence, and return-plan
content remain legible and unclipped. No Flutter exception, fatal Android
exception, RenderFlex overflow, or lost-engine connection appeared in the
post-run log check.

## Boundary

This is a real-engine integration and gross frame-pacing smoke check, not a
physical-device acceptance. Emulator presentation, host GPU behavior, and
software haptics cannot establish iPhone frame pacing, OLED values, haptic
weight, Low Power Mode behavior, or whether the final beat feels like settling
into the kitchen under the owner's thumb.
