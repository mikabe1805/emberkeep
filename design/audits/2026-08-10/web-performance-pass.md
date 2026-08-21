# Web responsiveness and silence pass — 2026-08-10

## Outcome

The release candidate keeps the authored Room of Days atmosphere while
removing the browser's permanent work. The web room-fire ambience is disabled
and excluded from the offline cache; short event sounds remain lazy and
user-triggered. The native Apple app keeps its existing behavior.

## Measured change

Measurements used Chromium at 929 × 917 with 4× CPU throttling and sampled
`requestAnimationFrame` during a three-second rest and an actively wheeled
scroll. They are comparative diagnostics, not promises for every device.

| Build and path | Idle | Active scroll |
| --- | ---: | ---: |
| Live site before this pass, JS CanvasKit | 38.6 fps | 35.9 fps |
| Release candidate, SkWasm | 59.2 fps | 51.7 fps |
| Release candidate, JS CanvasKit fallback | 55.1 fps | 44.4 fps |
| Release candidate, 390 × 844 JS fallback | 55.4 fps | 43.9 fps |

The final SkWasm sample had no frame over 50 ms. The phone-sized fallback had
four frames over 50 ms during its 2.2-second forced scroll and none while idle.
Desktop and phone visual checks produced no browser warnings or errors.

## What changed

- Web no longer preloads all sixteen sound pools or starts the looping
  `hearth_room.wav`; event sounds warm only when used and no-op cleanly when a
  browser or embedded web view has no Web Audio implementation.
- The web offline manifest explicitly excludes `hearth_room.wav`.
- Decorative systems use actual low-frequency web timers rather than 60 Hz
  animation controllers with quantized output. Hidden systems stop with
  `TickerMode`; Quest fire also parks while the board is moving.
- Global web motes and the XP stripe rest on intentional still compositions.
- The Quest room does not move every authored raster on scroll. Its scrolled
  atmosphere uses a lightweight warm value veil rather than another animated
  full-screen raster and blur.
- The release emits Wasm plus the JS CanvasKit fallback. Hosting headers opt
  eligible browsers into multithreaded SkWasm; Safari/iPhone can keep using the
  tested fallback.
- Offline install caches only the shared first room and the renderer the
  browser can execute. Deferred assets wait for idle time and pause around
  pointer, touch, wheel, or keyboard input.

The generated offline manifest contains 130 files: 24.6 MiB for the selected
renderer and first interactive room, plus 8.2 MiB warmed later.

## Verification

- `flutter analyze --no-pub`
- 79 focused behavior, accessibility, room-depth, visual, and release tests
- release-policy test rerun after excluding the ambience asset
- `flutter build web --release --wasm`
- offline manifest generation plus freshness check
- production bootstrap and service-worker syntax checks
- direct desktop and 390 × 844 browser inspection on both renderer paths
- request audit confirming no app playback/request for room ambience, followed
  by a manifest audit confirming the worker cannot fetch it in the background

## Production release

Deployed to Firebase Hosting and the custom domain on 2026-08-10. Production
served the expected COOP/COEP headers and selected multithread-capable SkWasm
in Chromium. At 4× CPU throttling the live Quest board measured 60.4 fps idle
and 59.1 fps during active wheel scrolling, with no frame above 50 ms.

The live 393 × 659 iPhone 15/WebKit emulation selected the JS CanvasKit
fallback, completed onboarding, opened and rendered the Quest board, made no
room-ambience request, and produced zero app errors. Its three console warnings
were WebKit notices for CanvasKit's `WEBGL_polygon_mode` extension. Playwright
WebKit does not support mouse-wheel input while emulating a touchscreen, so a
physical iPhone Safari smoke test remains useful for human touch-scroll feel
and offline reopen.
