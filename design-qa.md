# Flame design QA

## Source truth

- Reference: `web/icons/Icon-1024-v3.png` (1024 x 1024), especially its angular clustered silhouette, large planar facets, saturated orange/red body, and near-white heat at the fuel-contact base.
- User direction: approach the icon's quality without raster-copying it; preserve animation, purchased flame hues, and the warm room reward.

## Implementation evidence

- Full shop palette: `test/goldens/hearth_flame_palette.png` (1680 x 1552), rendered by the production shared flame painter.
- Full starter room: `test/goldens/keep_starter_level3.png` (1620 x 1260), live-hearth state at level 3.
- Full phone HUD: `test/goldens/quest_board.png` (1170 x 2532), live-hearth state at level 7.
- Full shop and equipped-room flow: `output/flame-consistency-audit/08-after-shop.png` and `output/flame-consistency-audit/07-after-keep.png` (1290 x 2796).
- Full Insights flame mark: `output/flame-consistency-audit/09-after-insights.png` (1290 x 2796).
- Cosmetic candle comparison: `output/flame-consistency-audit/10-after-cosmetic-candles.png` (1560 x 2100), showing Sunstone and Sea Glass hearth/candle pairs.
- Focused room crop: `output/flame-design-qa/03-implementation-room-flame.png` (720 x 520).
- Combined source/implementation comparison: `output/flame-design-qa/04-source-vs-implementation.png` (1024 x 512).

## Required fidelity surfaces

- Room hearth: passed — one asymmetric three-tongue cluster, crisp spear tips, distinct warm/deep planes, saturated body, and hottest facet touching the logs.
- Header hearth glyph: passed — the shared geometry remains legible at phone size and preserves level-based growth.
- Shop swatches: passed — all ten hues retain their cosmetic identity while using the same production flame construction.
- Candles and other miniature flames: passed — they call the same shared painter, inherit the corrected heat order and facets, and now inherit the equipped hue and matching halo instead of using a fixed peach fallback.
- Semantic flame marks: passed — streak chips, onboarding/error guidance, insights, goals, achievements, routines, reward receipts, and share cards route through the shared faceted flame mark; stock rounded fire glyphs and platform flame emoji no longer reach those surfaces.
- Equipped-colour continuity: passed — the selected hearth hue follows the player into the HUD, streak, insight, goal, trophy, routine, reward, candle, room, and shop contexts wherever save state is available.
- Animation: passed — existing lean/flicker inputs remain active, with movement settling to zero at the fuel line so the flame does not slide off its logs.
- Room lighting: passed — the warm additive bloom remains on the room and furniture, while the firebox is excluded so the flame itself is not bleached.

## Findings and disposition

- P0: none.
- P1: none.
- P2: none.
- Earlier mismatch: rounded teardrop tongues and a pale overall fill. Resolved with polygonal silhouettes, overlapping scale hierarchy, richer hue normalization, clipped facets, a narrower hot core, and bloom exclusion over the opening.
- Consistency mismatch: several compact surfaces still used Material fire icons, platform emoji, or fixed-colour candles. Resolved with one reusable semantic flame mark, legacy-icon routing, emoji removal, and equipped-hue propagation.
- Intentional variance: the animated vector flame uses fewer micro-facets than the 1024 px raster icon so it stays clean at 42 px and supports every purchased hue.

final result: passed
