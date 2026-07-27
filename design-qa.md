# Flame design QA

## Source truth

- Reference: `web/icons/Icon-1024-v3.png` (1024 x 1024), especially its angular clustered silhouette, large planar facets, saturated orange/red body, and near-white heat at the fuel-contact base.
- User direction: approach the icon's quality without raster-copying it; preserve animation, purchased flame hues, and the warm room reward.

## Implementation evidence

- Full shop palette: `test/goldens/hearth_flame_palette.png` (1680 x 1552), rendered by the production shared flame painter.
- Full starter room: `test/goldens/keep_starter_level3.png` (1620 x 1260), live-hearth state at level 3.
- Full phone HUD: `test/goldens/quest_board.png` (1170 x 2532), live-hearth state at level 7.
- Focused room crop: `output/flame-design-qa/03-implementation-room-flame.png` (720 x 520).
- Combined source/implementation comparison: `output/flame-design-qa/04-source-vs-implementation.png` (1024 x 512).

## Required fidelity surfaces

- Room hearth: passed — one asymmetric three-tongue cluster, crisp spear tips, distinct warm/deep planes, saturated body, and hottest facet touching the logs.
- Header hearth glyph: passed — the shared geometry remains legible at phone size and preserves level-based growth.
- Shop swatches: passed — all ten hues retain their cosmetic identity while using the same production flame construction.
- Candles and other miniature flames: passed — they call the same shared painter and inherit the corrected heat order and facets.
- Animation: passed — existing lean/flicker inputs remain active, with movement settling to zero at the fuel line so the flame does not slide off its logs.
- Room lighting: passed — the warm additive bloom remains on the room and furniture, while the firebox is excluded so the flame itself is not bleached.

## Findings and disposition

- P0: none.
- P1: none.
- P2: none.
- Earlier mismatch: rounded teardrop tongues and a pale overall fill. Resolved with polygonal silhouettes, overlapping scale hierarchy, richer hue normalization, clipped facets, a narrower hot core, and bloom exclusion over the opening.
- Intentional variance: the animated vector flame uses fewer micro-facets than the 1024 px raster icon so it stays clean at 42 px and supports every purchased hue.

final result: passed
