# Room of Days pre-publishing audit

August 8, 2026

## Decision

Room of Days is cohesive enough to stop broad redesign work and enter signed
device candidate testing. It is not ready to submit yet. The remaining release
gates are device, signing, production-policy, and store-console checks—not a
reason to add more features.

## Evidence reviewed

- Fresh 430 × 932 captures for onboarding, all five main destinations, the
  Quest board, Journal, daily bookends, Circle, workout flows, and sharing.
- Same-input target/build comparisons in `design/comparisons/2026-08-08/`.
- The current store-sized share-moment render in
  `test/goldens/store_13_share_moment_1290x2796.png`.
- The complete tracked and untracked change set after the August 4 release-prep
  commit, plus the Fable/Opus conversation that produced it.
- Current public support, privacy, deletion, AASA, and Android association URLs.

## What is working

- The rooms now read as one warm, authored material system rather than a stack
  of UI panels. Onboarding, Quests, Me, the morning ledger, and the night close
  belong to the same object-world.
- The main action stays visually obvious. Decorative motion supports the room
  instead of competing with the next thing to do.
- The product promise survives the new work: small actions become visible,
  resting is not failure, and social features remain support rather than a
  public feed.
- The share flow is preview-first and explicit about whether a room link travels
  with the image. Richer messaging should remain deferred until real-device
  feedback shows a need.
- Shared codes expose the generated room and broad presence only. My Space and
  Journal writing, display names, goals, and photos remain private in v1.

## Corrections made during this audit

1. Replaced the share card's flat procedural flame with the same authored,
   recolored parked-fire asset used in the room. The exported image now keeps
   the app's brush texture and no longer looks pasted together.
2. Corrected iOS photo and camera permission copy to match the v1 behavior:
   photos stay on the device.
3. Aligned reviewer notes, public privacy copy, and the store privacy worksheet
   with the same local-only photo boundary.
4. Routed in-app feedback to the monitored `support@roomofdays.com` address.
5. Recorded the live AASA verification and the intentionally empty Android
   `assetlinks.json` placeholder.
6. Serialized Stop Sharing behind any already-fired room refresh so a stale
   five-second write cannot recreate a room after its owner removes it.
7. Replaced overwrite-in-place visitor photos with immutable, unguessable
   revisions. A replacement is uploaded privately, the previous object is
   removed, and only an acknowledged Firestore write exposes the new path; a
   failed write deletes the uncommitted revision.
8. Bumped the save schema for the persisted day-rest marker and public photo
   handles, preventing an older cloud client from silently stripping them.
9. Made external coffee links opt-in for separately reviewed web/desktop
   builds; store candidates contain no external payment link by default.
10. Added a guarded, repeatable production smoke that uses two temporary
   identities, checks the complete social-policy boundary, and removes every
   temporary document and identity afterward.
11. Made screenshot fixtures deterministic and corrected the share fixture to
   load the selected room's real authored wall plate before capture.
12. Removed Firebase billing from the v1 release path without discarding the
   finished visitor-photo work. The default candidate has no visitor-photo
   switch and cannot upload, publish, or render those paths; a later build must
   deliberately opt in and pass its own Storage review.
13. Removed the last user-facing failure-language holdovers. Resting quests are
   now described as safely kept, quiet days stay quiet, and store copy speaks
   about days away and returning instead of invoking loss.
14. Corrected the privacy worksheet and public notice: passive exact-code room
   reads do not create a Firebase identity. Also removed the redirect-only
   `www` host from native-link claims so every claimed host serves its own
   association file.
15. Closed the v1 user-generated-content policy gap. Visitor-profile writing is
    now a dormant compile-time capability; release builds clear old consent,
    ignore stale profile payloads, publish generated-only v5 rooms, and refuse to
    serve legacy profile documents. It must stay off until filtering, reporting,
    blocking, terms, and timely moderation exist.
16. Corrected the share dialog's last visitor-profile claim and rebuilt its
    privacy explanation around generated rooms and small signs of presence.
    Visitor and capacity screenshot stories now preload their actual materials
    and run independently, so the visual gate no longer depends on test order.

## Release gates, in order

1. **Use the clean candidate snapshot.** Track the release-critical untracked
   files (`Runner.entitlements`, the AASA file, and Android ProGuard rules) and
   exclude the unrelated `student_notebook/` and August 4 notebook probes.
2. **Build and hold the real artifacts.** Upload/build iOS with Xcode 26 and the
   iOS 26 SDK, then confirm the release version/build numbers are new. The
   Android bundle is already release-signed, but Play App Signing still has to
   be enrolled.
3. **Use both phones.** Install signed builds on iPhone and Android. Exercise
   fresh install, upgrade, offline use, cloud backup, account deletion, photos,
   reminders, export/restore, sharing, large text, screen reader, Reduce Motion,
   Low Power Mode, long Quest scrolling, tilt, audio, and repeated tab changes.
4. **Close the links.** Enable Associated Domains for the Apple App ID and
   inspect the renewed profile. After the first Play upload, publish the Play
   signing SHA-256 in `assetlinks.json` and verify both link paths on-device.
5. **Complete the consoles from the real behavior.** Finish Apple privacy,
   Google's Data safety form, age rating, screenshots, reviewer access, and the
   final submission record.

## Watch on the phones; do not redesign from screenshots alone

- The night reflection sheet leaves a large quiet area below the prompt. It may
  feel calm on glass or empty; decide only after the phone pass.
- Journal prompt chips appear cropped at the edge in a nested view. Verify that
  horizontal scrolling, focus order, and large text make the continuation
  obvious before changing the composition.
- Some helper copy is deliberately soft. Check it in daylight and with larger
  text before increasing contrast globally.

## Verification completed on this candidate

- Formatting check: passed.
- Flutter analysis: passed.
- Full Flutter test suite: 323 tests passed.
- Release web build: passed, including the WebAssembly dry run.
- Screenshot suite: all 21 captures passed, were visually reviewed, and passed
  again without updating baselines.
- Focused About/privacy tests after the final copy changes: 10 passed.
- Local AASA content exactly matches the live HTTPS response, including exact
  and wildcard forms for both `/space` and legacy `/room` links.
- Current Firestore rules compiled and deployed to production on August 8.
- The repeatable two-identity production smoke passed generated-only v5
  publication, exact reads, anti-enumeration, visitor-writing and photo-path
  rejection, anti-downgrade, owner-only Circle/Spark receipts, duplicate
  rejection, self-interaction rejection, and complete temporary-data cleanup.
- Signed Android AAB and APK candidates for `1.0.0+7` passed clean release
  builds. Newer native audio/share plugin releases were rejected after their
  AGP 9 Built-in Kotlin paths failed real release compilation; the candidate
  pins the last proven versions instead of carrying a build-system workaround.
  The AAB SHA-256 is
  `7CDFBFE02DB89886AE5188FE8468C63730EC5F77E57B060F8A98A3DE68C25BE9`;
  the APK SHA-256 is
  `D078CB39C4068FB7A208B8EB7998D3DB38EB634F920FCFF60C58549A517FD94F`.
  Both carry the expected upload certificate, and the packaged APK reports
  version code 7, version name 1.0.0, minimum API 24, and target API 36.
- The matching web build was deployed to Firebase Hosting. Live
  `main.dart.js`, the local-only privacy page, and the AASA file each matched
  their verified local build artifact byte-for-byte by SHA-256; privacy,
  deletion, support, and AASA all returned HTTP 200. The deployed
  `main.dart.js` SHA-256 is
  `334DE66EE3D7D41090FE54E191C6A4BF3DC1E6166E45B29766F6708C7540078E`.

## Evidence limits

This audit did not have a physical iPhone or Android device, App Store Connect,
Play Console, or Xcode signing. Those limits are release gates, not inferred
passes. Firebase Storage remains intentionally absent and dormant in v1.
