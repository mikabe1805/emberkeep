# Store screenshots

These are direct production-UI captures from one deterministic account. They
have no device frame, overlay copy, alpha channel, or transparency.

The ten-frame iOS set was regenerated from the feature-on `1.0.4+37`
working candidate and visually inspected on August 30, 2026. It
becomes immutable release evidence only after the manifest-only binding commit
described below is complete.

## Candidate binding

This is a two-commit receipt. First, commit the completed candidate code,
listing, and inspected screenshots. Then, from that clean candidate, calculate
each lowercase SHA-256 and make one final commit that changes only
`app-store/CANDIDATE-MANIFEST.json`. The manifest's `sourceRevision` is the
candidate commit (`git rev-parse HEAD^` from the final receipt commit), and its
`version` must match `pubspec.yaml`. Verification rejects a dirty checkout, a
non-parent revision, or any receipt commit that changes another path. The
checked-in template is deliberately incomplete and must never be treated as
release evidence.

- `app-store/` contains Apple's accepted 1290×2796 iPhone 6.9-inch class.
- `google-play/` contains Google's recommended 1080×1920 portrait class. A
  separate render is necessary because Google's long edge may not exceed twice
  the short edge.

The App Store sequence is:

1. Quests — today's selected work, optional Quests, six life domains, and an achievable main quest.
2. Reward — a completed quest becoming XP, Glimmers, a stat gain, and streak
   progress.
3. Goals — today's chosen work and one clear next action inside the warm Goals room.
4. Workshop — owned routes and the optional Talk with the Steward entrance.
5. Recovery — smaller, prepare the return, or leave today alone without guilt.
6. Plans — the Daybook, next class, and calendar sharing one warm desk.
7. My Space — the authored visitor page with explicit Anyone, Mutuals, and
   Only me audiences.
8. Change Space — a full-room preview and the no-cost room-switching promise.
9. Journal — a private local entry shown in its then-and-now context.
10. Discover — a finite, opt-in directory of rooms with optional public names.

Google Play remains the earlier five-image core story without the Plans frame;
Android publication is deferred, so those files stay unchanged in this iOS pass.

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
