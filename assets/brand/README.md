# Room of Days brand assets

## Public app mark

The approved public launcher mark is **The Day Ledger**: a shallow open quest
ledger with three broad quest rows, one completed honey-gold medallion, and two
unfinished Room of Days completion rings. It was selected on 2026-08-19 after
the owner identified it as the only direction they would automatically
recognize as Room of Days, then confirmed that it felt like an app they would
click out of curiosity.

The immutable selected artwork and the production cutout source are:

- `design/source-assets/runtime-originals/assets/brand/room-of-days-day-ledger-source-v1.png`
- `design/source-assets/runtime-originals/assets/brand/room-of-days-day-ledger-chroma-v1.png`

The selected source is a 1254 x 1254 opaque RGB PNG with SHA-256
`32BD78056539A66E409AC7468FC3BA6CF91F44969FFCD46234CF5ED7B094B31A`.
The built-in image-generation workflow refined an earlier Day Ledger render
without changing its book silhouette or three-row structure. The exact
preserved revised prompt and full generation lineage live in
`design/icon-exploration/2026-08-19/README.md`.

The chroma source is a 1254 x 1254 opaque RGB production derivative with
SHA-256
`99143E48B5551A28D6DC270080162046B034A1E0D64D6DCDC86D7A9DB26BBD79`.
It exists only so the deterministic exporter can produce a true transparent
Android foreground. It is not a public icon master.

`tool/export_app_icons.dart` performs the bounded deterministic work: cubic RGB
resizes, green-dominance alpha extraction and despill, a 92 percent maskable-web
composition, luminance-weighted monochrome alpha, and a multi-frame Windows
ICO. `flutter_launcher_icons` then regenerates the Android and iOS matrices with
an 8 percent adaptive inset. Every source and derivative hash is recorded in
`room-of-days-icon-manifest-v1.json`.

From the app root, regenerate and verify with:

```powershell
dart run tool/export_app_icons.dart --app-root . --master design/source-assets/runtime-originals/assets/brand/room-of-days-day-ledger-source-v1.png --adaptive-chroma design/source-assets/runtime-originals/assets/brand/room-of-days-day-ledger-chroma-v1.png
dart run flutter_launcher_icons
dart run tool/export_app_icons.dart --app-root . --master design/source-assets/runtime-originals/assets/brand/room-of-days-day-ledger-source-v1.png --adaptive-chroma design/source-assets/runtime-originals/assets/brand/room-of-days-day-ledger-chroma-v1.png
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
