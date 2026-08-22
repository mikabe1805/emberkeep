# Space Discovery rollout

Space Discovery is implemented as an opt-in preview behind
`--dart-define=SPACE_DISCOVERY=true`. Optional public names have a second,
independent gate: `--dart-define=PUBLIC_DISCOVERY_NAMES=true`. Ordinary
TestFlight, Play, web, and App Store builds keep both absent until every
applicable gate below is complete.

## Product boundary

- Discovery is a finite handful of rooms, not an infinite feed.
- There are no likes, rankings, popularity counts, global profiles, or contact
  import. The existing Circle is the follow/revisit layer and has no arbitrary
  five-space product cap.
- A directory card contains the app-generated build title, level, room style,
  floor, hearth skin, and window scene. When the separately gated name feature
  is enabled, it may also contain one optional public name of at most 32
  characters.
- Public names start blank, are separate from the private Me name, are never
  copied into exact-code invites or `/rooms`, and require a deliberate save.
- It never contains a uid, email, room code field, quests, goals, Journal text
  or photos, streak, memories, daily activity, weather, focus status, or
  user-authored profile.
- The Firestore document id is the existing bearer code. It is not rendered.
  The full shared room is fetched only after a deliberate card tap.
- Turning discovery off leaves exact-code sharing on. Stop Sharing removes both
  the directory card and the room/code. Turning discovery off also forgets the
  local public name so a later opt-in starts anonymous again.
- Installing a default-off build after an enabled preview hides the old opt-in
  immediately and keeps a durable cleanup marker until the directory deletion
  is acknowledged; an offline save cannot silently revive the listing later.
- Every directory card has a renewable 30-day lease. Active opted-in spaces
  renew on their normal room refresh; expired cards are unreadable and
  unlistable under Firestore rules even before configured TTL cleanup removes
  the stored document. A lost anonymous identity therefore cannot leave a
  discoverable orphan forever.
- A discovered room can be kept in Circle for revisits. A person can hide it
  locally or privately report its name/identity without contacting its owner.

## Enablement gates

1. Deploy and verify the matching `firestore.rules` in the release Firebase
   project. Confirm `/rooms` is still not publicly listable, direct clients can
   create only a blank public name and cannot change one, and moderation/rate
   records are Admin-only.
   Configure Firestore TTL for `discoverableSpaces.expiresAt`; rule-enforced
   expiry remains the immediate visibility boundary while TTL is asynchronous.
2. Run rule-emulator checks for owner-only create/update/delete, authenticated
   bounded list (`limit <= 12`), teardown, and identity deletion.
3. For public names, deploy `setDiscoveryPublicName` and
   `reportDiscoverableSpace`; verify ownership, Unicode handling, filters,
   cooldown/daily limits, App Check enforcement, report privacy, and the
   operator workflow in `SPACE-DISCOVERY-MODERATION.md`. Keep the independent
   server parameter `DISCOVERY_PUBLIC_NAMES_ENABLED=false` until those checks
   pass; the public-name endpoint denies writes by default even when a client
   build or direct caller requests them.
4. Review the directory/name disclosures in the privacy policy, terms, App
   Store review notes, and Play data-safety answers before exposing either
   switch.
5. Exercise anonymous opt in, named opt in, clear name, opt out, offline
   failure, block, every report category, Stop Sharing, reset, account deletion,
   large Circles, and stale-room behavior on physical iOS and Android devices.
6. Capture fresh Me, Share, Discover, visitor, report, and Circle screens from
   the exact signed release candidate on every store-required device size.
7. Keep the default `DISCOVERY_ENFORCE_APP_CHECK=true` and prove App
   Attest/DeviceCheck and Play Integrity on signed physical-device builds. A
   temporary staging override is not acceptable in the production release.
8. Only then build with `SPACE_DISCOVERY=true`; add
   `PUBLIC_DISCOVERY_NAMES=true` and set the matching server parameter
   `DISCOVERY_PUBLIC_NAMES_ENABLED=true` only after the additional
   name/moderation gates pass. Do not reuse captures from a default-off or
   generated-only candidate.

Until those gates are complete, the current store statement that rooms are
reachable only by link/code remains accurate for the default release build.

## Local visual evidence

The August 22 source-render review is preserved in
[`space-discovery-and-guided-workouts-phone.webp`](../design/comparisons/2026-08-22/space-discovery-and-guided-workouts-phone.webp).
The separate generated-only versus optional-public-name comparison is
[`evidence-discovery-name-opt-in.png`](../design/comparisons/2026-08-22/evidence-discovery-name-opt-in.png).
These renders verify authored states and copy; they are not signed-device or
store-acceptance evidence and do not satisfy the enablement gates above.
