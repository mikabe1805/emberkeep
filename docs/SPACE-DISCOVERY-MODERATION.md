# Space Discovery moderation

Public discovery names are a gated user-generated-content surface. Source
completion is not permission to enable `PUBLIC_DISCOVERY_NAMES` in a store
build.

## What the product prevents

- Names are optional, start anonymous, and never borrow the private Me name.
- Only the authenticated room owner can request a name change.
- A server callable normalizes Unicode, caps names at 32 code points, rejects
  controls, links, handles/contact cues, unsupported characters, and a coarse
  blocked-term list. Client writes cannot set or change the name.
- Name changes and reports each have a 60-second cooldown and a ten-per-day
  account limit. Owners cannot report their own listing. Reports contain a
  fixed category and the public-name snapshot, never free-form text.
- Hiding is immediate and local even when a report cannot reach the server.
  Blocking also removes the room and its cached name from Circle.
- Report and rate-limit records are private Admin-only collections. The room
  owner cannot see the reporter.

The automatic filter is only a first gate. It does not replace human review,
appeals, policy judgment, or abuse monitoring.

## Operator queue

Review pending documents under
`discoveryReports/{roomCode}/reporters/{reporterUid}` without copying reporter
IDs into tickets visible to the room owner. Check the current directory name,
category, duplicate-report pattern, and prior enforcement history.

For a clear violation, use an Admin-only operation to clear the directory name
or remove the directory entry, record the reason and review timestamp in a
private moderation record, and preserve only the minimum evidence required by
the published policy. Do not edit `/rooms` or a person's private/local data.

For an ambiguous report, leave the name unchanged and record the review. For
credible impersonation or threats, escalate under the published safety policy.
Never contact either person from a private anonymous UID.

## Release and response gates

- Assign a named operator and backup, a documented review cadence, and an
  escalation route before enabling names.
- Publish rules for allowed names, reporting, enforcement, retention, and
  appeals in the Terms/Community Guidelines and privacy disclosures.
- Test queue access with least privilege; client SDKs must receive permission
  denied for every moderation path.
- Prove clear-name, remove-listing, duplicate report, false report, offline
  report, and account-deletion behavior in staging.
- Record App Check enforcement, callable deployment revision, rules revision,
  operator ownership, and physical-device evidence in the release record.

If review coverage, App Check, reporting, or the operator queue becomes
unavailable, disable `PUBLIC_DISCOVERY_NAMES` for the next build and remove or
clear existing public names through the Admin moderation path. Generated-only
discovery may remain enabled only if its own rollout gates still pass.
