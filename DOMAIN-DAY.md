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

The remaining work needs identifiers that are intentionally not stored in the
repository:

1. Apple Developer portal -> Identifiers -> `com.mikabe.emberkeep`: enable
   **Associated Domains**, then provide the Apple Team ID. This renews the
   provisioning profile on the next Codemagic build.
2. Add the iOS associated-domains entitlement and serve
   `/.well-known/apple-app-site-association` using that Team ID plus the
   bundle ID.
3. Enroll in Play App Signing and provide its signing certificate SHA-256.
   Then add Android's `assetlinks.json` and an intent filter scoped to
   `/space/*`.

## What deliberately does not change

- `lib/firebase_options.dart` hosts are Firebase infrastructure, not public
  links. Leave them.
- Existing shared rooms and codes are unaffected. Codes are host-independent.
