# Room of Days brand assets

## Public app mark

The approved public launcher mark is **The Day Ledger**: a shallow open quest
ledger with three broad quest rows, one completed honey-gold medallion, and two
unfinished Room of Days completion rings. It was selected on 2026-08-19 after
the owner identified it as the only direction they would automatically
recognize as Room of Days, then confirmed that it felt like an app they would
click out of curiosity.

The current immutable selected artwork and production cutout source are:

- `design/source-assets/runtime-originals/assets/brand/room-of-days-day-ledger-source-v2.png`
- `design/source-assets/runtime-originals/assets/brand/room-of-days-day-ledger-chroma-v2.png`

The selected source is a 1254 x 1254 opaque RGB PNG with SHA-256
`DBB4936D2D6E4BD430C19B51E6F2E99D42F125C05AD79A16F287E4659E2F0ABB`.
The second production pass preserves the approved book silhouette, framing,
materials, and three-row structure while making the completed medallion the
single high-luminance earned reward. The exact preserved prompts and full
generation lineage live in
`design/icon-exploration/2026-08-19/README.md`.

The chroma source is a 1254 x 1254 opaque RGB production derivative with
SHA-256
`EEB69A16749A1AA0A8FA2AD1BB0DCD6B7A4551F5C31F679D0396D827C7091700`.
It exists only so the deterministic exporter can produce a true transparent
Android foreground. It is not a public icon master.

The first approved Day Ledger sources remain archived as
`room-of-days-day-ledger-source-v1.png` and
`room-of-days-day-ledger-chroma-v1.png`; they are historical inputs, not the
shipping master.

`tool/export_app_icons.dart` performs the bounded deterministic work: cubic RGB
resizes, green-dominance alpha extraction and despill, a 92 percent maskable-web
composition, luminance-weighted monochrome alpha, and a multi-frame Windows
ICO. `flutter_launcher_icons` then regenerates the Android and iOS matrices with
an 8 percent adaptive inset. Every source and derivative hash is recorded in
`room-of-days-icon-manifest-v1.json`.

From the app root, regenerate and verify with:

```powershell
dart run tool/export_app_icons.dart --app-root . --master design/source-assets/runtime-originals/assets/brand/room-of-days-day-ledger-source-v2.png --adaptive-chroma design/source-assets/runtime-originals/assets/brand/room-of-days-day-ledger-chroma-v2.png
dart run flutter_launcher_icons
dart run tool/export_app_icons.dart --app-root . --master design/source-assets/runtime-originals/assets/brand/room-of-days-day-ledger-source-v2.png --adaptive-chroma design/source-assets/runtime-originals/assets/brand/room-of-days-day-ledger-chroma-v2.png
dart run tool/build_shipping_icon_review.dart --app-root . --output-dir design/icon-exploration/2026-08-19/selected
```

The second deterministic export refreshes the manifest after native generation.
The former isometric room-and-sun source remains archived at
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
