# Domain day - connecting `roomofdays.com`

Purchased and attached to the Firebase Hosting project on 2026-08-03.
Everything user-facing routes through `lib/content/links.dart`; the old
`emberkeep-5b33b.web.app` host remains connected for backward compatibility.

## Current connection state

- `https://roomofdays.com` is live over HTTPS and serves the production app.
- `https://www.roomofdays.com` redirects to the apex.
- Firebase Authentication authorizes both hosts.
- Cloudflare is configured DNS-only with Firebase's records:
  - `A` `@` -> `199.36.158.100`
  - `TXT` `@` -> `hosting-site=emberkeep-5b33b`
  - `CNAME` `www` -> `emberkeep-5b33b.web.app`
- The root, privacy, account deletion, and support routes return HTTP 200 on
  the public domain.
- The owner confirmed `support@roomofdays.com` is routed to a monitored inbox.

## Completed in the app and hosting project

- The single public origin in `lib/content/links.dart` is now
  `https://roomofdays.com`.
- New room invites use `https://roomofdays.com/space/CODE`; older query links
  remain accepted. This route can be safely scoped to native app links without
  making privacy, support, or the whole site open the app.
- Privacy, account-deletion, support, social-preview, and store-listing URLs
  use the new origin.
- Firebase Hosting serves clean `/privacy`, `/delete-account`, and `/support`
  routes. The old Firebase URL stays connected for backward compatibility.
- Flutter's route handler accepts cold and warm `/space/CODE` links and opens
  the existing visitor flow after app startup settles.

## Universal links (before store submission)

Status, August 8 2026:

1. **Done in repo** — `ios/Runner/Runner.entitlements` carries
   `applinks:roomofdays.com`, wired via `CODE_SIGN_ENTITLEMENTS` in all three
   Runner configurations (Team ID `D63Z4RBRT8`). The redirect-only `www` host
   is intentionally not claimed because association files must live on the
   exact host native links claim.
2. **Done and live** — `web/.well-known/apple-app-site-association` scopes
   `/space/*` and `/room/*` to `D63Z4RBRT8.com.mikabe.emberkeep`; verified to
   ride `flutter build web` into `build/web`. On August 8, 2026, the live URL
   returned HTTP 200 with the JSON content type.
3. **Done in repo** — AndroidManifest has the `autoVerify` intent filter for
   `/space` + `/room` on the apex host (inert until assetlinks verifies).
4. **Owner, once** — Apple Developer portal -> Identifiers ->
   `com.mikabe.emberkeep`: enable **Associated Domains**. The next Codemagic
   build's `fetch-signing-files --create` renews the profile with it.
5. **Owner, after first Play upload** — Play Console -> App integrity ->
   App signing key certificate: copy the SHA-256, then add
   `web/.well-known/assetlinks.json` for `com.mikabe.emberkeep` with it and
   redeploy hosting. The live endpoint intentionally returns an empty `[]`
   placeholder until that certificate is available.
6. After Android's file goes live: verify both well-known URLs return JSON
   (not the SPA index), then run the on-device link checks in
   RELEASE-CHECKLIST.

## What deliberately does not change

- `lib/firebase_options.dart` hosts are Firebase infrastructure, not public
  links. Leave them.
- Existing shared rooms and codes are unaffected. Codes are host-independent.
