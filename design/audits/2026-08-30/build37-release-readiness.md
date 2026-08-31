# Build 37 release readiness

Candidate: Room of Days `1.0.4+37`, prepared August 30, 2026.
The owner's explicit return-to-release request authorizes the TestFlight build
and store preparation after the corrected Steward writing. It does not stand
in for testing the signed build on an iPhone.

## Local evidence

- Flutter analysis: no issues.
- Complete Flutter suite after the version and smoke-runner updates: 985 pass.
- Feature-on release packet: 24 pass, one intentional skip.
- Feature-on release web build: successful.
- Functions lint/build: successful. Jest: 110 pass, 12 emulator-only cases
  skipped in the ordinary run.
- Firestore rules in the emulator: all 12 pass with a 60-second cold-start
  allowance. The initial five-second setup timeout was not an assertion failure.
- Authorized live smoke: two temporary anonymous identities, one generated v6
  room with its atomic owner anchor, one Circle receipt, and one fixed Spark.
  Exact-code reads, enumeration rejection, authored-content/photo rejection,
  legacy-schema rejection, receipt privacy, duplicate rejection, and self-send
  rejection all passed. Cleanup completed, including the room, anchor,
  receipts, and both temporary identities. Dormant Storage was not exercised.
- The live smoke runner was updated to the app's existing v6 format; no
  production service, deployed rules, or private user data was changed.

## Visual and listing evidence

All ten feature-on production App Store captures were refreshed, inspected,
and exported as opaque 1290x2796 RGB PNGs. The compact handoff is
`../../comparisons/2026-08-30/app-store-build-37-phone.webp`.
Normal and 2x narrow What's New renders show Build 37 and usable scrolling.
The selected Steward conversation has owner writing approval; optional exit,
resume, local memory, and no Quest/reward mutation have automated coverage.

The versioned listing describes the optional Quest board, Today's Field,
practical Goals, private journal, bounded sharing, and optional authored
Steward conversation. App Store promotional text, description, release notes,
keywords, and reviewer notes were saved. Internal account-preparation prose
is kept out of the reviewer-facing field. Screenshot upload and signed build
processing must be verified separately in App Store Connect.

## Release boundaries

The final manifest-only receipt commit binds this source candidate and the ten
exported screenshot hashes. The exact Build 37 tag triggers one signed
Codemagic iOS run. Local checks do not claim that run has completed.

Before public App Store submission, complete and record the signed iPhone
upgrade/data-preservation and separate disposable fresh-install passes, large
text/VoiceOver/common tasks, offline/account behavior, signed two-identity
sharing including Anyone/Mutuals/blocking, sound/performance, and the remaining
owner/legal console fields in `DEVICE-ACCEPTANCE-RUNBOOK.md` and
`STORE-LISTING.md`. The REST smoke cannot substitute for App Check or the
installed interaction journey. Keep manual release selected in App Store
Connect. No public submission or public-release completion is claimed here.
