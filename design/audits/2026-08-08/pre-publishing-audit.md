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
- Fresh store exports from that same production story: five App Store frames
  at 1290×2796 and five independently reflowed Play frames at 1080×1920.
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
17. Replaced the stale illustrated store screenshots with the current authored
    rooms and Journal navigation. Added a separate native 9:16 Play render and
    a verified RGB exporter so neither store receives an invalid alpha channel,
    stretched UI, or the wrong aspect ratio.
18. Closed Android release-lint findings that could outlive a successful build:
    upgraded the desugaring runtime required by API 36, removed a duplicate old
    splash resource, and added a dedicated Android themed-icon mask.
19. Made account deletion actually leave Room of Days device-only instead of
    silently creating a fresh cloud identity. The durable cloud preference is
    cleared before the credential is deleted, and a failed credential deletion
    restores that preference.
20. Made Start over wait for journal-photo, usage-log, corrupt-backup, and blank
    local-save confirmation. Its dialog now stays open while erasure runs,
    reports a failure without claiming success, remains usable at large text,
    and describes the signed-in blank-cloud-save behavior accurately.
21. Added a direct off-app account-deletion request to the public deletion page
    and an owner runbook that covers identity verification, Firestore
    subcollections, dormant Storage data, Auth deletion, and final verification.
22. Narrowed Android App Links to exact `/space` and `/room` routes plus their
    slash-delimited children, so unrelated paths such as `/roommate` are no
    longer claimed.
23. Pinned the verified Android APIs/NDK and Codemagic Flutter/Xcode/CocoaPods
    toolchain. CI now inspects the signed IPA itself for the bundle ID, version,
    privacy manifest, signature, and associated-domain entitlement.
24. Made production-smoke cleanup attempt every temporary receipt, room, and
    Firebase identity even after an earlier cleanup error, with a regression
    test proving later cleanup actions still run.
25. Added a machine-readable Android candidate manifest and a single verifier
    for artifact hashes, source handoff, package/version/SDK values,
    permissions, exact app links, both signing containers, Bundletool and 16
    KiB packaging configuration, and all native ELF LOAD alignments.
26. Added a store-submission verifier for Apple/Google character limits,
    public URLs and deletion/privacy claims, candidate-version agreement,
    exact image inventory, dimensions, and 24-bit RGB encoding.
27. Added a valid empty Android `assetlinks.json` endpoint with an explicit JSON
    content type. It remains deliberately unassociated until the first Play
    upload exposes the Play App Signing certificate.
28. Found the first-time sharing failure in the installed release app: the
    client probed a fresh code with a read, while production rules correctly
    hide missing room documents. Build 10 now reserves by bounded writes,
    retries only denied collisions, and preserves real policy/network errors.
    The signed artifact then published and revoked a generated-only v5 room in
    production.

## Release gates, in order

1. **Use the clean candidate snapshot.** The release-critical native and link
   files are tracked. Keep excluding the unrelated `student_notebook/` and
   August 4 notebook probes from release commits.
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
- Full Flutter test suite: 332 tests passed.
- Release web build: passed, including the WebAssembly dry run.
- Screenshot suite: all 21 captures passed, were visually reviewed, and passed
  again without updating baselines.
- Focused room-reservation, social, and release-policy suite: 40 passed.
- Local AASA content exactly matches the live HTTPS response, including exact
  and wildcard forms for both `/space` and legacy `/room` links.
- Current Firestore rules compiled and deployed to production on August 8.
- The repeatable two-identity production smoke passed generated-only v5
  publication, exact reads, anti-enumeration, visitor-writing and photo-path
  rejection, anti-downgrade, owner-only Circle/Spark receipts, duplicate
  rejection, self-interaction rejection, and complete temporary-data cleanup.
- Signed Android AAB and APK candidates for `1.0.0+10`, built from source commit
  `68f45ac2b67bc41dc79e492cd556751577107a24`, passed clean release
  builds. Newer native audio/share plugin releases were rejected after their
  AGP 9 Built-in Kotlin paths failed real release compilation; the candidate
  pins the last proven versions instead of carrying a build-system workaround.
  The AAB SHA-256 is
  `0D46FBFC6EAAC2AFDDDD0BE1EFFAB9FF8576FBA251B2B43EC8DED46CFE19A654`;
  the APK SHA-256 is
  `8EA8CC79BF289B440A5FD1B384DD6AAD8B1F03FC2FA5FD36A2B39AF6B7960D16`.
  Both carry the expected upload certificate, and the packaged APK reports
  version code 10, version name 1.0.0, minimum API 24, and target API 36.
  The Android app module's AGP 9 release lint completes with 0 errors; its
  remaining findings are non-blocking manifest/icon guidance. The Gradle root
  aggregate additionally analyzes pinned plugin source and stops on
  dependency-internal findings in `firebase_storage` and
  `flutter_local_notifications`, not candidate source. Bundletool validates the
  AAB and reports `PAGE_ALIGNMENT_16K`; the APK passes 16 KiB zip alignment;
  and all twelve packaged native libraries meet the 16 KiB LOAD-alignment
  requirement.
- The release APK passed an installed Android 16 / API 36 emulator smoke:
  cold launch, onboarding, quest completion, all five destinations, offline
  relaunch, notification permission and alarm cancellation, exact and
  near-miss app-link resolution, largest in-app text, reset persistence, and
  repeated tab changes. A manual backup restored a changed 23-XP room to its
  stashed 10-XP state across cold relaunch; a system-picker photo and Journal
  text survived force-stop; and optional backup, account creation, sign-out,
  sign-in, and deletion completed against production. Account deletion
  invalidated the temporary credentials and left an empty Journal.
- Installing the signed Build 10 APK over signed Build 9 advanced version code
  9 to 10 and preserved 10 XP. First-time sharing from that exact Build 10 APK
  returned a public generated-only v5 room with profile/photo fields empty;
  Stop Sharing revoked the code. This does not replace the physical-device
  performance gate.
- Bundletool 1.18.3 generated a device-specific set from the exact immutable
  Build 10 AAB: `base-master`, `base-en`, `base-x86_64`, and `base-xxhdpi`.
  Every split carried the expected upload certificate. After removing the
  direct APK install, the split set installed cleanly on Android 16 / API 36;
  a fresh run completed onboarding, a quest, first-time production sharing,
  an exact generated-only v5 read, Stop Sharing, and Start Over. This closes
  the local AAB-delivery gap, but not the physical-device or Play Console gates.
- The machine-readable candidate verifier passed the exact artifact pair and
  source handoff; the store-submission verifier passed every field limit, URL,
  disclosure, icon, feature graphic, and both five-image RGB screenshot sets.
- The final submission screenshot sets contain only current production UI.
  All ten exports are 24-bit RGB PNGs without alpha, were inspected after
  export, and match the five-state Quests → reward → My Space → room preview →
  Journal story documented in `store-assets/screenshots/README.md`.
- The matching web build was deployed to Firebase Hosting. Live
  `main.dart.js`, privacy, deletion, support, AASA, and the intentionally empty
  Android association placeholder each matched their checked-in or built
  counterpart byte-for-byte by SHA-256 and returned HTTP 200. The deployed
  `main.dart.js` SHA-256 is
  `389659848DB320604A2E76D1C7481A66FAD5317EC537B427A7D30496AFB55A44`;
  privacy is
  `32905025D4C673CDCEBD37CFDAF62BE01798BC2F5A4FE1C90ED724193834372A`;
  deletion is
  `250AA4DD60F627A200408A070854B8FF6BFE224678D9CFB148A6625A2628B29D`;
  support is
  `E827432EC49E710F265CF4B30E9C84673C4A542D145120E61F7D651637076638`;
  AASA is
  `9810E971FB67DB38FCFAD46669F7652C3727BDEE86C6C1E2EBC805B2F9183142`;
  and `assetlinks.json` is
  `37517E5F3DC66819F61F5A7BB8ACE1921282415F10551D2DEFA5C3EB0985B570`.

## Evidence limits

This audit did not have a physical iPhone or Android device, App Store Connect,
Play Console, or Xcode signing. Those limits are release gates, not inferred
passes. Firebase Storage remains intentionally absent and dormant in v1.
