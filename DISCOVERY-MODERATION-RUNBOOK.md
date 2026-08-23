# Discover moderation runbook

Owner: Mika Be / Room of Days developer

Public contact and appeals: `support@roomofdays.com`

Production project: `emberkeep-5b33b`

This is a solo-operable safety queue for one optional 32-character public name,
not a chat or post feed. The primary operator reviews it at least once every 24
hours and targets action within 24 hours of a report. If that cadence cannot be
maintained, public names are paused; generated-only discovery can remain.

## Daily queue

1. Use Google Cloud Shell or a workstation with Application Default Credentials
   authorized for `emberkeep-5b33b`. Never export a service-account key into the
   repository.
2. From `functions/`, list the oldest 100 pending reports:

   ```sh
   node scripts/discovery-moderation.cjs --project=emberkeep-5b33b list
   ```

3. Compare the reported name, category, directory record, and any prior reports.
   Do not expose or contact the reporter. Do not inspect quests, Journal data, or
   a cloud save; none is relevant to a directory-name decision.
4. Apply one proportionate outcome:

   ```sh
   # No violation
   node scripts/discovery-moderation.cjs --project=emberkeep-5b33b dismiss CODE REPORTER_UID

   # Clear the public name but leave generated-only discovery available
   node scripts/discovery-moderation.cjs --project=emberkeep-5b33b clear-name CODE REPORTER_UID

   # Block this Firebase owner from every current/future discovery code
   node scripts/discovery-moderation.cjs --project=emberkeep-5b33b ban OWNER_KEY CODE REPORTER_UID REASON_CODE
   ```

Reason codes use lowercase words such as `harassment`, `hate`, `impersonation`,
`contact_info`, `sexual_content`, `threat`, or `spam`. A ban writes
`discoveryBans/{ownerKey}` and removes the current listing atomically. Firestore
Rules then reject a new or refreshed listing from the same owner key, and the
name callable rejects further name changes.

## Decision guide

- Dismiss when the name plainly complies, the report is mistaken, or the
  evidence is too ambiguous to justify action.
- Clear the name for a first, non-severe violation that is confined to the name.
- Ban for threats, hate, sexual exploitation, child-safety concerns, exposed
  private information, evasion, or repeated abuse.
- Preserve the report record with its resolution. Delete resolved records only
  when they are no longer needed for an appeal, abuse pattern, or service safety.
- For immediate danger, preserve the minimum relevant evidence and direct the
  person to local emergency services. Do not promise emergency response through
  Room of Days.

## Appeals

Check `support@roomofdays.com` with the same daily cadence. Verify an appeal
against the room code and owner key without asking for a password or Journal
export. Record the reason before reversing a ban:

```sh
node scripts/discovery-moderation.cjs --project=emberkeep-5b33b unban OWNER_KEY
```

Unbanning does not relist a room. The keeper must opt in again.

## Pause public names

If moderation, App Check, or the callable is unhealthy, fail closed:

1. In `functions/.env.emberkeep-5b33b`, set
   `DISCOVERY_PUBLIC_NAMES_ENABLED=false`.
2. Clear existing public names:

   ```sh
   node scripts/discovery-moderation.cjs --project=emberkeep-5b33b pause-names
   ```

3. Deploy only the name callable and verify it rejects a controlled signed
   request while generated-only directory reads still work:

   ```sh
   firebase deploy --project emberkeep-5b33b --only functions:setDiscoveryPublicName
   ```

Do not turn the gate back on until the queue is current, App Check enforcement
is healthy, and a controlled set/change/clear flow passes again.
