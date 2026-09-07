# Build 42 public submission preparation

The owner approved public TestFlight distribution and App Store submission of
1.0.4+42 on September 6, 2026, after testing the approved visual and sound work.
This record describes preparation and verified backend repair. Apple review
and distribution status must be recorded separately from live portal evidence.

## Binary identity

- Signed app source: `5b9f31f5fb2b75df3047cc28bf0f4a3dc741ec9b`.
- Existing TestFlight receipt: `7fe4527399ce8fdf15ce1d838a0b663e13a8c04d`.
- Codemagic build: `6a9e14403cf4759eab81ec80`; terminal check `101596347908` succeeded.
- App Store Connect: app `6781401469`, bundle `com.mikabe.emberkeep`, version
  1.0.4, Build 42 processed and ready for submission.
- This preparation changes listing assets, capture scaffolding, documentation,
  and a release verification tool only. It does not change the signed runtime.

## Discover repair

Manage Listing publishes the current room before presenting listing controls.
The installed Build 42 writes room schema v8, but production still had August
24 Firestore rules and sharing functions. The client translated the resulting
permission rejection into the misleading sharing-update message. An emulator
probe reproduced the denied v8 owner-room/registry batch under those live rules.

Deployed the existing Build 42 Firestore and Storage rules and seven sharing
functions, preserving App Check and public-name moderation. Provisioned the
configured default Firebase Storage bucket in us-central1 and granted its
service agent the scoped Firestore-rule evaluation role required for photo
ownership checks. No account-wide permissions or public access were opened.

Live verification at 2026-09-07T02:50:16Z confirmed:

- Firestore ruleset: `22f0e2cf-0032-4442-8e93-981b770ea5be`.
- Storage ruleset: `1a2bfb29-b3b9-4f57-b67a-cdd6481c81c0`.
- Bucket: `emberkeep-5b33b.firebasestorage.app`.
- All seven functions active; immutable deployed runtime sources match freshly
  compiled source; expected App Check and public-name settings preserved.
- Current Firestore rules: 16 passing tests. Storage rules: 4 passing tests.
- Functions: 134 passing tests across 7 suites; the 20 emulator tests were run
  separately. Photo schema/cleanup: 19 passing tests. Lint and build passed.

`tool/verify_live_sharing_backend.ps1` reproduces the live source/configuration
checks without cloud mutations. It writes a non-secret JSON receipt into the
ignored output directory. Downloaded deployment archives must remain local.
These checks do not stand in for an observed signed-device interaction; an
owner retry of Manage Listing has been requested and is recorded separately.

## Screenshots and listing

Ten fresh production Flutter views were rendered and exported as opaque RGB
1290 x 2796 PNGs. The sequence shows today's three, a real completion receipt,
Goals, Workshop, recovery, Plans, My Space, a room change, Journal, and Discover.
All frames were visually inspected. Synthetic demonstration content is confined
to the screenshot fixture; no live user save was seeded or changed.

The capture harness opens Workshop through its real entrance. An explicit
`CAPTURE_STORE_DAILY_ONLY` follow-up pass seeds the chosen three through the
real daily-selection operation and captures Quests/reward. The ordinary
production story remains intact and passed separately. Reproduction commands
are in `store-assets/screenshots/README.md`.

The manifest-only receipt follows this artifact-source commit in a clean
checkout, binds all ten PNG hashes to version 1.0.4+42 and its exact source,
and is checked with `dart run tool/verify_store_submission.dart --ios-only`.
The source snapshot and receipt are not a replacement native build.

The owner authorized submission; this does not imply every physical-device
edge case was personally observed. Apple review, external tester availability,
and App Store publication remain distinct states in the final delivery record.
