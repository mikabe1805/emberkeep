# Protected Places Functions owner runbook

This package contains the two authenticated callable boundaries used by Room of
Days' optional Google place search:

- `placesAutocomplete` sends a trimmed query, random search-session token, and
  app language to the fixed Places API (New) autocomplete endpoint.
- `placesDetails` sends the selected provider place ID, the same session token,
  and app language to the fixed place-details endpoint.

The server returns at most five narrow results. Provider display names and
addresses remain transient. The Flutter app persists only the provider, place
ID, exact person-typed query, and person-authored routing/building/room fields.
No test in this repository makes a live Google request.

## Hard stop

`PLACE_SEARCH_ENABLED` defaults to `false`. Checked and public builds must stay
false until all nine owner gates below are complete in order. Do not treat a
passing Functions build as deployment approval. This runbook does not authorize
Codex or CI to attach billing, create credentials, set secrets, deploy, publish
policies, or enable the client flag.

## 1. Attach billing

Confirm the owner-selected project is `emberkeep-5b33b`, then attach the intended
billing account. Places API requires billing. Record the project number and the
billing account chosen before continuing.

Primary reference: [Places API usage and billing](https://developers.google.com/maps/documentation/places/web-service/usage-and-billing).

## 2. Enable Places API (New)

Enable **Places API (New)** in the same project. Confirm the API dashboard names
the new API and that unrelated Maps services are not enabled just because they
appear nearby in the console.

## 3. Restrict and store the server secret

Create a dedicated server-only Google Maps Platform key. Restrict its API scope
to **Places API (New)**. If the deployed Functions path has verified fixed
outbound IP addresses, add those as the application restriction. Default cloud
egress may be dynamic, so do not guess an IP restriction that would break the
service; record the egress decision and stop for owner review if fixed egress is
not configured. The authenticated proxy, narrow API restriction, App Check,
rate guards, and quota caps are all still required.

Store the key only in Secret Manager through the Firebase Functions secret:

```sh
firebase functions:secrets:set GOOGLE_PLACES_API_KEY
```

Never print the value, place it in `.env`, commit it, pass it as a Dart define,
or add it to Flutter/web/native assets. Confirm both callables bind the secret.

Primary references: [Google Maps Platform security guidance](https://developers.google.com/maps/api-security-best-practices) and [Firebase secret parameters](https://firebase.google.com/docs/functions/config-env#secret_parameters).

## 4. Deploy in App Check monitor mode

Set the Functions deployment parameter `PLACES_ENFORCE_APP_CHECK=false`, then
deploy only the two callables:

```sh
firebase deploy --only functions:placesAutocomplete,functions:placesDetails
```

Confirm both deployed functions use Node 20, bind `GOOGLE_PLACES_API_KEY`, and
require Firebase Authentication. Keep every Flutter build at
`PLACE_SEARCH_ENABLED=false` during this monitor deployment.

Primary reference: [Deploy Cloud Functions](https://firebase.google.com/docs/functions/manage-functions#deploy_functions).

## 5. Configure cost limits and Firestore TTL

Create billing-budget alerts and conservative Places API quota caps lower than
the owner's maximum affordable exposure. Billing budgets alert; provider quotas
are the hard upstream ceiling. Confirm the source-level guards are also active:

- autocomplete: 30/minute and 300/day per Firebase UID and installation ID;
  global close at 5,000/day;
- details: 10/minute and 100/day per Firebase UID and installation ID; global
  close at 1,000/day.

Create a Firestore TTL policy for collection group `_placesCostGuards` using
the timestamp field `expiresAt`. The code writes expiry 35 days after each
counter update. Verify TTL is enabled and remember that deletion is not
instantaneous and incurs document-delete operations.

Primary references: [Manage Google Maps Platform costs](https://developers.google.com/maps/billing-and-pricing/manage-costs) and [Firestore TTL policies](https://firebase.google.com/docs/firestore/ttl).

## 6. Validate App Check monitor metrics

Use controlled internal builds with real production attestation providers. For
web, configure its public reCAPTCHA v3 App Check site key. Exercise both
`placesAutocomplete` and `placesDetails`, then inspect callable-request
verification metrics/logs separately for each function. Record valid, invalid,
and missing-token counts by Android, Apple, and web; investigate unexpected
traffic before enforcement.

Primary reference: [Monitor App Check request metrics for Cloud Functions](https://firebase.google.com/docs/app-check/monitor-functions-metrics).

## 7. Enforce App Check on both callables and redeploy

Set `PLACES_ENFORCE_APP_CHECK=true` and redeploy both functions together:

```sh
firebase deploy --only functions:placesAutocomplete,functions:placesDetails
```

Verify each callable rejects a missing or invalid App Check token and continues
to accept legitimate authenticated requests from every supported platform.
Checking only one callable is not sufficient.

Primary reference: [Enable App Check enforcement for Cloud Functions](https://firebase.google.com/docs/app-check/cloud-functions).

## 8. Publish and verify the public policies

Publish the repository's `web/privacy.html` and `web/terms.html`. From a fresh
browser, verify the live canonical pages at `https://roomofdays.com/privacy` and
`https://roomofdays.com/terms`, including their status, cache behavior, exact
place-search disclosure, and these current primary links:

- [Google Maps Platform Terms of Service](https://cloud.google.com/maps-platform/terms)
- [Google Privacy Policy](https://policies.google.com/privacy)

Do not proceed from checked files alone; the public pages must be live.

## 9. Build the opt-in candidate

Only after gates 1-8 are recorded complete, build a candidate with:

```sh
flutter build apk --release --dart-define=PLACE_SEARCH_ENABLED=true
flutter build web --release --wasm --dart-define=PLACE_SEARCH_ENABLED=true --dart-define=PLACE_SEARCH_APP_CHECK_WEB_SITE_KEY=<public-site-key>
```

The web App Check site key is public configuration, not the Google Places
server credential. Never use `PLACE_SEARCH_APP_CHECK_DEBUG=true` in a public
candidate. Re-run all backend, Flutter, release, and device gates, including a
physical iPhone provider handoff. Until that candidate passes and is explicitly
released, public builds remain `PLACE_SEARCH_ENABLED=false`.

## Repository-only verification

These commands are safe because tests mock the upstream boundary and ordinary
builds retain the default-disabled flag:

```sh
npm run lint
npm run build
npm test -- --runInBand
```

From the app root, also run the focused Flutter tests, analysis, default WASM
web build, and default release APK build required by the implementation plan.
