# Room of Days brand assets

## Public app mark

The approved public launcher mark is **Open Door of Light**: one angular
dark-walnut threshold, a door held ajar, and one cream-to-honey path entering
the room. It was selected on 2026-09-01 after the owner rejected the book-ledger
mark as the app's click hook and chose Direction 1 from three new world-first
directions as the best fit for Room of Days.

The current immutable selected artwork and production cutout source are:

- `design/source-assets/runtime-originals/assets/brand/room-of-days-open-door-source-v1.png`
- `design/source-assets/runtime-originals/assets/brand/room-of-days-open-door-chroma-v1.png`

The selected source is a 1254 x 1254 opaque RGB PNG with SHA-256
`2ABAC214582901D4456642D5D49CCA8E68DEA943C5B7E69C34F9AD13E1ED4524`.
It keeps one strong threshold silhouette and one motivated light field so the
mark reads as an invitation into a warm little world at 32 pixels rather than
as a miniature planner interface. The exact prompt, owner-selection lineage,
and small-size review live in
`design/icon-exploration/2026-09-01/open-door-of-light/README.md`.

The chroma source is a 1254 x 1254 opaque RGB production derivative with
SHA-256
`9CB20A12FC163EC1AEDD073C647A30CAE089CF57D0286C5EA2047310DD4A83CE`.
It exists only so the deterministic exporter can produce a true transparent
Android foreground. It is not a public icon master.

The Day Ledger sources remain archived as
`room-of-days-day-ledger-source-v1.png`,
`room-of-days-day-ledger-chroma-v1.png`,
`room-of-days-day-ledger-source-v2.png`, and
`room-of-days-day-ledger-chroma-v2.png`. The literal ledger remains part of the
product's morning, night, planning, and widget language; it is no longer the
launcher identity.

`tool/export_app_icons.dart` performs the bounded deterministic work: cubic RGB
resizes, green-dominance alpha extraction and despill, a 92 percent maskable-web
composition, luminance-weighted monochrome alpha, and a multi-frame Windows
ICO. `flutter_launcher_icons` then regenerates the Android and iOS matrices with
an 8 percent adaptive inset. Every source and derivative hash is recorded in
`room-of-days-icon-manifest-v1.json`.

From the app root, regenerate and verify with:

```powershell
dart run tool/export_app_icons.dart --app-root . --master design/source-assets/runtime-originals/assets/brand/room-of-days-open-door-source-v1.png --adaptive-chroma design/source-assets/runtime-originals/assets/brand/room-of-days-open-door-chroma-v1.png
dart run flutter_launcher_icons
dart run tool/export_app_icons.dart --app-root . --master design/source-assets/runtime-originals/assets/brand/room-of-days-open-door-source-v1.png --adaptive-chroma design/source-assets/runtime-originals/assets/brand/room-of-days-open-door-chroma-v1.png
dart run tool/build_shipping_icon_review.dart --app-root . --output-dir design/icon-exploration/2026-09-01/open-door-of-light/shipping
```

The second deterministic export refreshes the manifest after native generation.
The former Day Ledger and isometric room-and-sun sources remain archived. The
isometric source is at
`design/source-assets/runtime-originals/assets/brand/room-of-days-icon-source-v2.png`;
it is no longer the shipping launcher identity.

## The Woven Dawn

The former public tapestry mark remains in the product as **The Woven Dawn**,
the permanent room object that grows with level. Its historical internal asset
names stay unchanged for compatibility:

- `design/source-assets/runtime-originals/assets/brand/morrowloom-icon-source.png`
- `design/source-assets/runtime-originals/assets/brand/morrowloom-tapestry-room.png`
- `design/source-assets/runtime-originals/assets/brand/morrow-tapestry-wide.png`
- `morrowloom-icon-runtime-v2.webp`
- `morrowloom-tapestry-room-v2.webp`
- `morrow-tapestry-wide-v2.webp`

The wide derivative preserves the literal woven-dawn subject, rod, faceted
brass/copper construction, plum wool, gold sunrise, and mountain grammar. Quest
Desk customization may change its surrounding frame and textile rail, but must
not recolor the finished artwork itself.
