# Protected Places Functions owner runbook

This package contains the three authenticated callable boundaries used by Room
of Days' optional Google place search and its scoped private-identity removal:

- `placesAutocomplete` sends a trimmed query, random search-session token, and
  app language to the fixed Places API (New) autocomplete endpoint.
- `placesDetails` sends the selected provider place ID, the same session token,
  and app language to the fixed place-details endpoint.
- `beginServiceIdentityDeletion` creates or refreshes a private
  `serviceIdentityDeletionTombstones/{uid}` document. It accepts only a current
  Firebase anonymous sign-in provider, requires App Check, and never calls
  Google or binds the Places server secret.

The server returns at most five narrow results. Provider display names and
addresses remain transient. The Flutter app persists only the provider, place
ID, exact person-typed query, and person-authored routing/building/room fields.
No test in this repository makes a live Google request.

## Hard stop

`PLACE_SEARCH_ENABLED` defaults to `false`. Checked and public builds must stay
false until all ten owner gates below are complete in order. Do not treat a
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
or add it to Flutter/web/native assets. Confirm only `placesAutocomplete` and
`placesDetails` bind the secret; `beginServiceIdentityDeletion` must not.

Primary references: [Google Maps Platform security guidance](https://developers.google.com/maps/api-security-best-practices) and [Firebase secret parameters](https://firebase.google.com/docs/functions/config-env#secret_parameters).

## 4. Configure provider quota caps, budget alerts, and Firestore TTL

Before the first public callable deployment, set conservative Places API
provider quota caps below the owner's maximum affordable exposure. Provider
quota caps are the hard upstream stop. Next, create billing budget alerts;
budget alerts warn but do not cap spending. Confirm both controls are active in
the owner-selected project and record their values before continuing.

Then create Firestore TTL policies using timestamp field `expiresAt` for both
collection group `_placesCostGuards` and collection
`serviceIdentityDeletionTombstones`. Each counter is marked to expire 35 days
after its last update. Each deletion tombstone is marked to expire 35 days
after it is created or refreshed. Verify both policies are active before
deployment. Firestore deletes expired documents asynchronously afterward; TTL
deletion is not an exact retention deadline and incurs document delete
operations.

Also confirm the source-level guards are active:

- autocomplete: 30/minute and 300/day per Firebase UID and installation ID;
  global close at 5,000/day;
- details: 10/minute and 100/day per Firebase UID and installation ID; global
  close at 1,000/day.

Primary references: [Manage Google Maps Platform costs](https://developers.google.com/maps/billing-and-pricing/manage-costs) and [Firestore TTL policies](https://firebase.google.com/docs/firestore/ttl).

## 5. Deploy and verify the owner-only room cleanup rules

Before any place-search-enabled client exists, deploy the checked
`firestore.rules` containing the owner-only room cleanup rules, the private
`roomDeletionLocks` collection, and the private
`serviceIdentityDeletionTombstones` collection. This gate does not change
ordinary sharing when no tombstone or room lock exists:
clients can still create, update, or stop sharing a room when no deletion lock
exists. Once a strong deletion lock exists for a room, room updates, new Spark
or Circle receipts, and old-client deletion attempts must fail until the owner
finishes the atomic cleanup or retries it.

An acknowledged UID tombstone must block save and room create/update from every
open client using that UID, including clients holding late Firebase tokens. It
must also block new Spark and Circle receipts and shared-room media create or
update. Deletes stay available for cleanup. Deploy the checked `storage.rules`
with the Firestore rules and prove this behavior before ever enabling visitor
photo sharing; `VISITOR_PHOTO_SHARING` remains false in checked/public builds.

Verify with authenticated rule tests against a disposable project or emulator:

- an authenticated owner query for its own owner UID with a limit of 100 is
  allowed and finds public, private, and legacy rooms carrying that UID;
- unauthenticated, unfiltered, other-UID, missing-limit, and over-100 queries
  are denied, while existing exact-code public and private `get` behavior is
  unchanged;
- only the room owner can create or refresh its deletion lock;
- clients cannot create, update, delete, or list deletion tombstones, and can
  read only their own tombstone;
- `beginServiceIdentityDeletion` requires an authenticated anonymous provider,
  App Check, and creates or refreshes the caller's tombstone before cleanup;
- a tombstone blocks same-UID save, room, receipt, and Storage media writes from
  a second app instance or late token, while cleanup deletes remain allowed;
- an acknowledged lock blocks room create/update and new private `sparks` and
  `circleAdds` documents;
- the owner can delete the room and `roomDeletionLocks/{code}` document only in
  the same acknowledged batch, and a crash after lock creation can retry; and
- any query, lock, child cleanup, batch, or Auth-identity ambiguity fails closed
  and retains the anonymous identity.

Record the Firestore and Storage ruleset versions and emulator/live evidence
before continuing. Repository rule-shape tests are not runtime allow/deny proof.
The anonymous private-service-identity control is coupled to
`PLACE_SEARCH_ENABLED` and excluded from web builds; default builds do not show
it. A checked source file is not proof that these rules are deployed.

Primary reference: [Securely query data](https://firebase.google.com/docs/firestore/security/rules-query) and [Atomic operations](https://firebase.google.com/docs/firestore/manage-data/transactions).

## 6. Perform the first monitor-mode deploy

Only after the provider quota caps, budget alerts, and Firestore TTL policy are
confirmed, set the Functions deployment parameter
`PLACES_ENFORCE_APP_CHECK=false`, then deploy all three callables:

```sh
firebase deploy --only functions:placesAutocomplete,functions:placesDetails,functions:beginServiceIdentityDeletion
```

Confirm all three deployed functions use Node 20 and require Firebase
Authentication. Confirm the two Places functions bind `GOOGLE_PLACES_API_KEY`
and the deletion function does not. Keep every Flutter build at
`PLACE_SEARCH_ENABLED=false` during this monitor-mode deploy.

Primary reference: [Deploy Cloud Functions](https://firebase.google.com/docs/functions/manage-functions#deploy_functions).

## 7. Validate App Check monitor metrics

Use controlled internal builds with real production attestation providers. For
web, configure its public reCAPTCHA v3 App Check site key. Exercise
`placesAutocomplete`, `placesDetails`, and a cold-session
`beginServiceIdentityDeletion` bootstrap that initializes Firebase Core and App
Check without first making a search. Inspect callable-request verification
metrics/logs separately for all three callables. Record valid, invalid, and
missing-token counts by Android, Apple, and web; investigate unexpected traffic
before enforcement. The destructive identity-removal control remains hidden on
web even though the callable itself must still reject invalid callers.

Primary reference: [Monitor App Check request metrics for Cloud Functions](https://firebase.google.com/docs/app-check/monitor-functions-metrics).

## 8. Enforce App Check on all three callables and redeploy

Set `PLACES_ENFORCE_APP_CHECK=true` and redeploy all three functions together:

```sh
firebase deploy --only functions:placesAutocomplete,functions:placesDetails,functions:beginServiceIdentityDeletion
```

Verify each callable rejects a missing or invalid App Check token. Confirm the
Places endpoints continue to accept legitimate authenticated requests from
every supported platform and the deletion endpoint accepts only an anonymous
Firebase sign-in provider. Checking only one callable is not sufficient.

Primary reference: [Enable App Check enforcement for Cloud Functions](https://firebase.google.com/docs/app-check/cloud-functions).

## 9. Publish and verify the public policies

Publish the repository's `web/privacy.html` and `web/terms.html`. From a fresh
browser, verify the live canonical pages at `https://roomofdays.com/privacy` and
`https://roomofdays.com/terms`, including their status, cache behavior, exact
place-search disclosure, and these current primary links:

- [Google Maps Additional Terms of Service](https://maps.google.com/help/terms_maps/)
- [Google Privacy Policy](https://policies.google.com/privacy)

Do not proceed from checked files alone; the public pages must be live.

## 10. Build the opt-in candidate

Only after gates 1-9 are recorded complete, build a candidate with:

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
