# Room of Days General Daybook and Places Design

Status: product design approved by the owner on 2026-08-17. Production Places
enablement remains gated on owner-authenticated billing, secret, quota, privacy,
and App Check setup.

## Scope

Plans will become a useful general calendar without removing the richer school
workflow already present. A person who never attends school can create timed or
all-day events and completable tasks, repeat weekly events, save a place, and
open directions. A student keeps the existing Class,
Assignment, Exam, study-planning, occurrence-adjustment, and Room Notes
handoff behavior as an optional School lane.

This pass also fixes two visible defects reported from the TestFlight build:

- long diagonal and vertical seams showing through translucent Quest, Goals,
  and Help for Today surfaces;
- the month grid's Today outline wrapping awkwardly around the date and its
  label.

The work extends the approved candlelit desk and folio direction. It does not
introduce a generic white calendar aesthetic, an embedded map, device-location
tracking, or a second calendar destination.

## Selected approach

The approved approach is a neutral Daybook model beside the preserved academic
engine, joined by one presentation projection.

Two alternatives were rejected:

- Renaming Academic Daybook and adding a generic row to its chooser would be
  quick, but ordinary events would remain second-class and the underlying
  calendar would still require terms and courses.
- Replacing the academic engine with a universal model would eventually reduce
  internal naming debt, but it would put stable occurrence IDs, tombstones,
  course work, study plans, conflict checks, and existing saves at unnecessary
  risk.

The existing academic types and serialized fields remain compatible. Neutral
events and tasks are additive.

## Delivery slices

The implementation plan is divided into three independently verifiable slices:

1. visual integrity removes the ambient seams and corrects the Today marker;
2. general Daybook adds the local neutral model, migration, projection,
   editors, weekly event recurrence, tasks, and manual locations;
3. Places and directions adds the protected Google service, attributed search,
   provider handoff, privacy copy, quotas, and owner-authenticated deployment.

Each slice must leave the app releasable with its focused tests and visual
evidence passing. Places remains disabled by a checked configuration flag until
the callable functions, billing controls, privacy pages, and App Check
enforcement are all live. Manual locations and directions do not depend on
Google search being enabled.

## Product language and hierarchy

The page remains `PLANS` with the existing subtitle `your days, held in one
place`.

The calendar instrument header changes from `ACADEMIC DAYBOOK` to `DAYBOOK`.
Its default supporting line is:

`Events, tasks, classes, and places in one view`

When the selected date belongs to an unarchived school term, that term's name
replaces the supporting line. Otherwise the default line remains visible.
The header icon changes from a graduation cap to the existing calendar/daybook
symbol so school is no longer presented as the identity of the whole surface.

The add action keeps the concise visible label `ADD`. Its semantic label becomes
`Add an event, task, class, assignment, or exam`.

The add sheet is titled `ADD TO YOUR DAYBOOK` and opens with two general items:

1. `EVENT` — `Something happening at a time or across a day`
2. `TASK` — `Something to finish by a date or time`

A quiet `SCHOOL` rule follows, then the existing specialized choices:

- `CLASS` — `A lecture, lab, meeting, or recurring class`
- `ASSIGNMENT` — `Course work with a due date and time`
- `EXAM` — `A test, midterm, or final on your calendar`

Reminder is not a third top-level item. General event/task notification
delivery is deferred because the existing bounded batch scheduler does not own
durable calendar-item IDs, reconciliation, or recurrence semantics. Existing
academic reminder data remains intact.

## General event behavior

An event contains a stable event ID, title, optional notes, civil start and end
dates, time-zone ID, all-day state or local start/end times, optional place,
and created/updated timestamps. For all-day events, start is inclusive and end
is exclusive, so one all-day event ends at the next civil date. For timed
events, end date is the date containing the end time; it may equal the start
date or be the following date. Longer timed events are rejected in this pass.

The first release supports one-off events and an optional weekly series. A
weekly series adds a stable series ID, one or more weekdays, interval in weeks,
optional end date, and materialized occurrence exceptions. Its occurrence keys
and tombstones use the existing academic recurrence principles so cancelling
or moving one date survives serialization and later series edits.

Weekly materialization preserves the original event's all-day span or timed
same-day/overnight duration relative to each generated start date. The
projection emits a spanning event on every civil date it occupies and clips
day-load minutes to that date.

Editing or deleting a weekly item offers `THIS EVENT` or `ENTIRE SERIES`.
`THIS AND FUTURE EVENTS`, daily recurrence, monthly recurrence, yearly
recurrence, and arbitrary recurrence rules are explicitly deferred. This keeps
one recurrence mechanism in the first release instead of creating a second
calendar engine before the general flow has been validated.

The month view includes general events in its existing day-weight calculation.
Week, three-day, and day views show their real time ranges alongside classes
and study blocks. All-day events occupy a quiet rail above the timed schedule.

## General task behavior

A task contains a stable task ID, title, optional notes, civil due date,
optional due time, optional place, completion timestamp, and created/updated
timestamps. Tasks are one-off in this release; recurring task series and
per-task notification delivery are deferred.

Completing a task is local calendar state. It does not silently create a Quest,
award XP, change a streak, or increase a stat. Existing Quest-backed plans keep
their current behavior and continue to appear in Plans. No automatic migration
converts them into tasks.

An incomplete task remains on its original date and also appears in a quiet
`STILL OPEN` section on the current day. It does not turn red, accrue penalties,
or use failure language. Completing it preserves its original due date;
undoing completion returns the same task. Quest linking is outside this pass so
the first general-calendar release does not create two sources of truth for
completion rewards.

## One calendar projection

The screen will not render unrelated academic and general calendars on top of
one another. `DaybookRangeProjection.build` accepts the schedule envelope,
Quest-backed plans, an inclusive civil-date range, and `now`. It returns a
`DaybookRange` containing one `DaybookDay` per date. Each day owns ordered
`DaybookEntry` records and a derived `DaybookDaySummary` for month weight,
deadline marks, conflicts, and accessibility copy.

Each `DaybookEntry` carries a stable display key, source kind and source ID,
title, all-day/timed/due placement, completion/cancellation state, optional
place reference, and a typed action target. It maps one source item:

- general event occurrence;
- general task due occurrence;
- class occurrence;
- assignment or exam;
- study block;
- existing Quest-backed plan.

The projection owns shared ordering, day-load minutes, all-day placement,
deadline marks, accessibility summaries, and conflict inputs. `CalendarPage`,
the month folio and selected-day panel, and the renamed general span panel all
consume this projection. They do not independently query separate general and
academic lists. Source-specific row widgets receive typed source IDs and
callbacks only for their own actions: Notes and occurrence adjustment stay on
classes, study planning stays on course work, completion stays on tasks and
Quest plans, and directions appear only when a usable place exists.

Timed conflicts are informational. The calendar never moves or deletes a
person's entries automatically. A conflict message names the overlapping items
and keeps both times exactly as entered.

## Persistence and migration

The legacy-named `AcademicSchedule` remains the schedule envelope for this
release and advances from schema 4 to schema 5. It imports focused neutral
types from `lib/daybook/domain/` and adds empty-by-default `events` and `tasks`
collections. `LocalAcademicScheduleRepository` remains the sole persistence
owner and keeps the existing `room_of_days_academic_schedule_v1` preference
key. Schema 1 through 4 decoders restore the same academic data and produce
empty neutral collections. Existing occurrence IDs, tombstones, view
preferences, and Room Notes handoff identifiers remain unchanged.

The top-level malformed-JSON behavior remains conservative: preserve the raw
blob under the existing recovery key and open an empty schedule. Within a
valid schema-5 map, neutral collections decode record by record. If one neutral
record is malformed, the repository preserves the raw blob as a recovery copy,
returns the remaining valid academic/general records, and exposes a diagnostic
count for tests and debug logging. It never drops a valid class because one new
event is invalid.

The local save remains authoritative. The current schedule repository is
device-local and outside the Quest save and Firestore mirror; schema 5 keeps
that boundary. General calendar content enters an export, private cloud backup,
or sync path only through a separately designed, disclosed, and tested change.

## Place entry

Every event and task form offers one neutral `LOCATION` section. The existing
class editor adopts the same component through an explicit `CampusPlace` ↔
`DaybookPlace` adapter. Adapter tests preserve every legacy label, building,
room, address, coordinate, provider, place ID, and campus-code field; editing a
legacy class cannot erase fields the new form did not change.

The location component contains:

- `SAVED NAME`, an ordinary local field owned by the person;
- `ADDRESS OR ROUTING TEXT`, an optional manual field used for directions;
- optional building and room fields for campuses, offices, hospitals, and
  other large sites;
- an explicit `SEARCH PLACES WITH GOOGLE` affordance;
- a manual-entry path that never disappears;
- visible Google Maps attribution beneath Google-provided suggestions and
  transient details.

Search begins only after three non-whitespace characters and a 300 ms quiet
period. A new UUID session token is created when the field gains an active
search session. Stale responses are ignored. The list is capped at five useful
predictions. Selecting a prediction ends the session with one Place Details
request using the narrowest field mask needed to confirm the place ID and
present the selection. A new search creates a new token.

The service returns a transient `PlaceSelection` containing provider,
provider-place-ID, the person's original query, and attributed primary and
secondary display text. After selection, `SAVED NAME` receives the exact query
the person typed, not provider text. The person can edit it before save.
`ADDRESS OR ROUTING TEXT` remains empty unless the person types or confirms
their own value; Google content is never copied into it automatically. The
transient Google name and address remain visible with attribution until the
form closes. Later calendar views use the saved name, building, room, and
manual routing text. They refresh Google details only when a transient provider
preview is explicitly opened.

The app never prefetches suggestions, records abandoned queries, or sends the
contents of unrelated form fields. It does not request device location. Search
bias is not part of this pass. The service uses the app's display locale and
does not infer or upload current coordinates.

Google Maps Platform content is not treated as ordinary app data. Predictions
remain transient and visibly attributed. The durable `DaybookPlace` stores the
Google place ID, provider, the person's own saved label, and their own
building/room or manually entered routing text. It does not indefinitely cache
Google formatted addresses, coordinates, prediction descriptions, or other
Places content. This follows Google's current rule that place IDs are exempt
from caching restrictions while other Places content is not.

Manual locations remain entirely local and may store the address or routing
text the person typed. Existing `CampusPlace` JSON continues to decode through
the adapter without rewriting old records.

## Places service and credential boundary

Places is a separate backend delivery slice, not a Flutter-only file change.
It bootstraps a `functions/` package, adds Functions deployment to
`firebase.json`, adds the official callable-functions and App Check client
dependencies, configures platform attestation providers, and adds a checked
release feature flag. The app remains complete with manual locations when that
slice is undeployed or disabled.

The Flutter client depends on a `PlaceSearchService` interface, not directly on
Google HTTP calls. Production search uses two narrowly scoped Firebase callable
functions:

- autocomplete accepts query, session token, and display locale;
- details accepts a selected place ID and the same session token.

The functions construct fixed Places API (New) requests server-side, apply
field masks, discard fields the app does not need, reject arbitrary upstream
URLs, and return only the normalized transient response. The Google credential
is stored in server-side secret configuration and is restricted to Places API.
No unrestricted key or service-account secret enters the Flutter bundle.

The first time a local-only person taps `SEARCH PLACES WITH GOOGLE`, a compact
disclosure explains that their typed query will be sent to Google through Room
of Days, that current device location is not used, and that a private anonymous
Firebase identifier is created for abuse protection. Search begins only after
they choose `USE PLACE SEARCH`. Declining or closing keeps manual entry fully
available and creates no Firebase identity. Consent is remembered locally and
can be withdrawn by clearing the feature's local consent and identity through
the existing account/privacy controls.

After consent, callable access requires Firebase authentication. An already
signed-in account is reused; otherwise the app provisions anonymous auth at
that moment rather than ordinary app startup. Internal builds first run with
App Check metrics in monitor mode. The public Places feature flag stays off
until those metrics confirm the shipping apps are accepted and enforcement is
enabled on both callable functions. The endpoint also enforces payload length,
per-user and per-install rate limits, and a conservative global budget guard.
App Check replay-token consumption is not used for ordinary autocomplete
because its extra attestation round trip would add cost and latency to a
low-risk action.

Manual entry is the production fallback when Firebase is unavailable, the
service is unconfigured, a request times out, App Check rejects the call, or a
quota guard closes search.

The implementation must use the current Google billing model rather than an
assumed promotional credit. Session tokens and field masks are mandatory cost
controls. Cloud billing alerts and Maps quota caps are configured before the
feature is enabled in a release build.

## Directions behavior

The visible action is `GET DIRECTIONS`. Its semantic label is `Get directions
to <saved label>`.

The launcher is isolated behind a testable `DirectionsLauncher` interface.

- Google Maps uses the universal
  `https://www.google.com/maps/dir/?api=1` URL. It supplies an encoded
  destination from the person's manual routing text or saved label and, for a
  Google-selected place, `destination_place_id` for precision. Google Maps URLs
  require no API key.
- Apple platforms use an Apple Maps link with `daddr` set only from non-empty
  manual routing text. A saved nickname or partial Google query is not assumed
  to be a safe Apple Maps destination, and Google-only Places content is not
  copied into Apple Maps.
- Android uses the Google universal URL, which opens the installed Google Maps
  app when available and otherwise falls back to the browser.
- Web opens Google Maps in a new external browsing context.

`DaybookPlace.hasGoogleDestination` is true when it has a Google place ID or
non-empty manual routing text. `hasAppleDestination` is true only for non-empty
manual routing text. `GET DIRECTIONS` appears only when at least one is true.
On iOS, the first directions action offers Apple Maps and Google Maps only when
both predicates are true; with one provider it opens directly. The selected
provider is remembered locally. Later taps open it directly; a quiet
`CHANGE MAP APP` action in the location details resets the preference.

If launch fails, the sheet remains open and offers `COPY LOCATION`. No event or
task is changed by a map-launch failure.

## Visual corrections

### Ambient seams

The source trace points to the hard path boundaries drawn by
`_AmbientPlanesPainter` in `lib/widgets/glass.dart`: their vertices align with
the reported diagonal and center seams visible through translucent content.
Before editing, fresh Goals and Help for Today baselines are captured. An A/B
render with only that painter disabled must remove the same lines. Once that
evidence confirms the trace, the faceted full-canvas polygons are removed from
`WarmBackground`. If the lines remain, the painter stays until the responsible
layer is isolated.

The existing soft radial pools, authored page art, and vignette remain in both
the A/B capture and final implementation so candlelit depth is not discarded
with the defective plane.

This is a shared-system correction because the same painter causes artifacts
on Goals, Help for Today, and other warm-background routes. No card-specific
mask is added to hide the symptom.

### Today marker

The Today state no longer outlines the entire fixed-height day plate. A compact
28–30 px faceted brass marker wraps the numeral itself. `TODAY` remains directly
beneath it in a reserved, bounded line. Day-weight and deadline marks retain
their own slot and never sit inside the Today border.

Selection is distinct from Today: a selected non-today date receives a quiet
book-cloth wash; Today keeps the compact brass marker. When Today is selected,
the two states combine into one marker and one wash rather than a doubled
outline.

The seven-column grid retains equal 62 px week rows. Month numerals and the
`TODAY` label remain intentionally non-scaling bounded metadata, with the full
date/Today state exposed through Semantics. The selected-day panel carries the
same information in normally scaling text. At 320 px width and 200 percent
text, the compact grid must not overflow and the selected-day detail must
remain fully readable.

## Error and offline behavior

- Empty or whitespace titles do not save.
- Timed event end must be after start. Overnight events are represented by an
  explicit next-day end, never by silently swapping times.
- An invalid weekly rule remains in the editor with a direct correction
  message.
- Offline or unavailable place search shows `Search unavailable — type the
  location instead.` Manual entry and saving remain available.
- A stale autocomplete response cannot replace newer text or a manual choice.
- A deleted or unavailable Google place ID leaves the person's saved label and
  manual routing text intact and invites a new search.
- One invalid schema-5 neutral record preserves the raw recovery copy and the
  remaining valid records. Invalid top-level JSON keeps the current documented
  behavior: preserve the raw recovery copy, open an empty schedule, and emit a
  diagnostic instead of crashing.

## Accessibility and privacy

All add choices, date cells, provider choices, completion controls, and
directions actions retain at least a 44 px target. Semantics name item type,
date, time, completion state, recurrence, and conflict without relying on
color. Keyboard focus follows visual order, dialogs trap focus, and the sheet
behind a modal is hidden from accessibility traversal.

The app privacy page changes from an unconditional statement that location is
not used to the narrower truth:

- Room of Days does not request or track current device location;
- manually entered locations stay in the device-local schedule store and do
  not enter the existing Firestore mirror;
- when the person actively searches for a place, the typed query is sent to
  Google Maps Platform through Room of Days' protected endpoint;
- accepting place search creates or reuses a Firebase identity solely for
  authenticated service access and abuse controls;
- queries are not used for advertising or analytics by Room of Days.

The public Terms and Privacy pages link to the applicable Google terms and
privacy policy before production search is enabled. Withdrawing local Places
consent disables future search and clears its preference; it does not silently
delete a linked Room of Days account. Account deletion remains the explicit
path for deleting the underlying Firebase identity.

## Architecture boundaries

- `lib/daybook/domain/` owns neutral events, one-off tasks, weekly event
  recurrence/occurrences, and the neutral place value. It does not import the
  academic domain.
- `lib/daybook/presentation/daybook_range_projection.dart` composes neutral,
  academic, and Quest sources into `DaybookRange`; this dependency direction
  prevents a cycle between the two domains.
- The existing `AcademicSchedule` is the schema-5 composition envelope and
  `LocalAcademicScheduleRepository` remains its device-local persistence owner.
- `lib/daybook/data/daybook_preferences.dart` owns local Places consent and map
  provider preference; neither setting enters `GameState` or the cloud mirror.
- `lib/daybook/services/place_search_service.dart` owns the injectable search
  contract and manual/unavailable implementations.
- `lib/daybook/services/directions_launcher.dart` owns URI construction and
  external launch behavior.
- `lib/daybook/widgets/` owns general editors, location search, and general
  event/task rows.
- `lib/academic_calendar/` retains courses, terms, class occurrence rules,
  course work, study planning, and notebook handoff.
- `lib/screens/calendar.dart` coordinates the selected span and consumes one
  daybook projection. The existing academic span widget becomes a general
  Daybook span consumer; neither layer implements provider HTTP or recurrence
  math.
- A new `functions/` package owns deployment dependencies and tests;
  `functions/src/places.ts` owns the two fixed Google Places proxy operations,
  validation, field masks, and cost guards.

Large existing files are split only where the new boundary requires it. This
pass does not refactor unrelated calendar or Quest behavior.

## Test-driven implementation contract

Every behavior change begins with a focused failing test and follows the
red-green-refactor cycle.

Domain tests cover:

- event and task JSON round trips;
- schema 1 through 4 migration to empty neutral collections;
- schema-5 coexistence with academic data;
- per-record neutral recovery without losing valid academic data;
- stable weekly event occurrence keys, moves, cancellations, and tombstones;
- one-off task completion, undo, preserved due date, and `STILL OPEN`
  projection;
- all-day/timed ordering, overnight validation, and conflict projection;
- manual and provider-backed place persistence rules;
- lossless `CampusPlace` ↔ `DaybookPlace` adaptation for legacy records.

Service tests cover:

- three-character threshold, debounce, cancellation, and stale responses;
- new session token per search and one details call per selection;
- one-time consent, declined consent, anonymous-auth provisioning, signed-in
  reuse, and disabled-feature behavior;
- timeout, quota, App Check, and unconfigured fallbacks;
- Google and Apple URI encoding;
- place-ID precision for Google directions;
- provider preference, failed launch, and copy fallback;
- function request validation, field masks, response filtering, and rate
  limits without calling live billable APIs.

Widget tests cover:

- neutral Daybook header and add-sheet hierarchy;
- creating, editing, moving/cancelling weekly occurrences, completing/undoing
  tasks, and deleting general items;
- School flows remaining present and unchanged;
- unified month, week, three-day, and day rendering;
- Google attribution while predictions are visible;
- manual location entry with search unavailable;
- `GET DIRECTIONS` visibility and semantics;
- Today/selected combinations, every weekday position, five- and six-week
  months, 320 x 568, and 200 percent text.

A visual regression must fail against the old full-height Today outline before
the new marker is implemented. Fresh Goals and Help for Today A/B captures must
demonstrate that disabling `_AmbientPlanesPainter` removes the reported seams
before its polygons are deleted.

## Visual and release verification

Final verification includes:

- focused domain, service, widget, and backend function tests;
- full `flutter analyze` and `flutter test`;
- Functions lint, type-check, unit tests, and deployment configuration
  validation;
- release web and Android builds;
- fresh normal, narrow, large-text, and Reduced Motion calendar captures;
- fresh Goals and Help for Today captures at rest and mid-scroll;
- source/build comparisons opened at full-frame and focused-detail scales;
- a physical iPhone pass for add-sheet flow, keyboard behavior, Places consent,
  Apple/Google provider choice, and external map handoff.

Google Places is not called from automated tests. Production API enablement is
a separate owner-authenticated setup step: enable Places API (New), attach
billing, configure the server-side secret, deploy the protected functions,
set budget alerts and quotas, verify App Check metrics, and only then turn on
the release feature flag.

## External constraints verified for this design

- [Google Places usage and billing](https://developers.google.com/maps/documentation/places/web-service/usage-and-billing)
  requires billing, supports session-token billing, and uses field masks to
  control returned fields and SKU cost.
- [Google Places policies](https://developers.google.com/maps/documentation/places/web-service/policies)
  require attribution and restrict caching while allowing place IDs to be
  stored indefinitely.
- [Google Maps Platform security guidance](https://developers.google.com/maps/api-security-best-practices)
  recommends an authenticated proxy when a client cannot safely protect a web
  service credential.
- [Firebase App Check for callable functions](https://firebase.google.com/docs/app-check/cloud-functions)
  supports server-side enforcement without placing provider secrets in the
  app.
- [Google Maps URLs](https://developers.google.com/maps/documentation/urls/get-started)
  provide cross-platform directions without an API key.
- [Apple Map Links](https://developer.apple.com/library/archive/featuredarticles/iPhoneURLScheme_Reference/MapLinks/MapLinks.html)
  support directions with a destination address and a current-location start.

## Explicitly outside this pass

- importing or two-way syncing Google, Apple, Outlook, or school calendars;
- exporting, cloud-mirroring, or syncing the device-local schedule envelope;
- reading the device's current location;
- per-event/task notification delivery and recurring tasks;
- daily, monthly, yearly, `THIS AND FUTURE`, or arbitrary recurrence rules;
- travel-time notifications or automatic departure calculations;
- an embedded interactive map;
- attendee invitations, shared calendars, or RSVP state;
- automatic Quest rewards for general tasks;
- replacing the academic recurrence and study-planning engine;
- changing Room Notes handoff identifiers or release-channel packaging.
