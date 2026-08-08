# Store screenshots

These are direct production-UI captures from one deterministic account. They
have no device frame, overlay copy, alpha channel, or transparency.

- `app-store/` contains Apple's accepted 1290×2796 iPhone 6.9-inch class.
- `google-play/` contains Google's recommended 1080×1920 portrait class. A
  separate render is necessary because Google's long edge may not exceed twice
  the short edge.

The sequence is the same in both folders:

1. Quests — the daily board, six life domains, and an achievable main quest.
2. Reward — a completed quest becoming XP, Glimmers, a stat gain, and streak
   progress.
3. My Space — the authored room, earned Glimmers, level, and milestones.
4. Change Space — a full-room preview and the no-cost room-switching promise.
5. Journal — a private local entry shown in its then-and-now context.

Suggested Google Play alt text (each under 140 characters):

1. `Daily quest board with six life domains and a main quest to read ten pages.`
2. `Quest completion receipt showing XP, Glimmers, a Mind gain, and streak progress.`
3. `Warm moonlit personal room with earned Glimmers, level, and milestones.`
4. `Living Conservatory room preview with a Move In button and no-cost switching.`
5. `Private Journal with an earlier note placed beside the progress that followed.`

Regenerate the production screenshot story, inspect every selected frame, then
run `dart run tool/export_store_screenshots.dart`. The exporter rejects
transparent pixels, converts Flutter's RGBA captures losslessly to 24-bit RGB
PNG, verifies dimensions, and removes the retired direct-folder set.
