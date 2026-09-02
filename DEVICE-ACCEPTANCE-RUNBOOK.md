# Room of Days physical-device acceptance

Complete the iPhone columns before submitting the 1.0.4 App Store update.
Android publication is deferred and its historical instructions remain below
for a later release. Simulator and widget evidence are useful but do not close
the iPhone gate. Use disposable test data and accounts; never risk a personal
journal.

## Candidate identity

### Android

- Install only `../release-artifacts/room-of-days-1.0.0+12-android.apk` for the
  direct phone smoke.
- Before installing, run `dart run tool/verify_android_candidate.dart` from
  `app/`. The expected APK SHA-256 is
  `9C8C924E4C98CEC35175C03508EF5E757940CA8FD9C18627DCE6E4634B4A1B12`.
- Upload only the matching Build 12 AAB after the phone pass. Builds 2-11 are
  superseded snapshots, not fallback candidates.

### iPhone

- Install only the processed Room of Days `1.0.4` (Build 41) from TestFlight.
  It must come from the exact
  `room-of-days-1.0.4-build-41-internal-candidate-retry-1` receipt through the
  Codemagic `ios-testflight` workflow; do not substitute a local debug/profile
  build. Both Build 40 tags remain immutable history; Build 40 is superseded
  because it assigned the peaceful Focus track to the normal room too.
- Keep the emitted IPA, matching Runner dSYM, Codemagic log, and
  `release-evidence.txt` together. Record the IPA SHA-256 after the signed build
  exists; do not copy Build 19's hash into the new receipt.
- Confirm the installed version/build match that evidence, which must name the
  final release commit and Team ID `D63Z4RBRT8`.
- Keep the newest processed Room of Days TestFlight build already installed
  long enough to perform the upgrade-preservation pass before the separate
  fresh-install pass. Record that prior build number; do not delete owner data
  merely to force a particular baseline.

Record before testing:

| Field | Android | iPhone |
| --- | --- | --- |
| Tester and date |  |  |
| Phone model |  |  |
| OS version |  |  |
| Installed app version/build |  |  |
| Artifact SHA-256 / evidence file |  |  |
| Source commit | `ee091db079a54c982946aa6ab7e7b61546b3354f` |  |

## Stop conditions

Do not submit if any step reveals a reproducible crash, hang, data loss, private
content in a visitor room, unexpected account/network requirement, stale public
brand, permission request without a user action, inaccessible common task, or
sustained poor frame pacing. Record the exact device, state, action, expected
result, actual result, and a screen recording when useful. Do not mark a step as
passed because reopening the app happened to hide the failure.

## 1. Android upgrade, then clean install

Run the upgrade check before uninstalling anything:

- [ ] Install the signed Build 11 APK, finish onboarding, complete a quest, add a
  Journal line, and note the visible XP.
- [ ] Install the signed Build 12 APK over Build 11 without uninstalling. Confirm
  Android reports version `1.0.0` / build `12`, onboarding does not return, and
  the XP and Journal line remain.
- [ ] Uninstall Room of Days, then install the verified Build 12 APK fresh.
  Confirm the old test data is gone and onboarding begins normally.

For iPhone, first install Build 41 over the newest processed TestFlight build
already on the phone without deleting Room of Days. Confirm the save, journal,
room, Daybook, settings, and account state remain and What's New appears once.
Separately, use a disposable test device or installation for the
uninstall/reinstall check: install Build 41 fresh and confirm onboarding starts
with no prior test data. Never delete the owner's personal app data for this
check.

## 2. First launch and core story

Repeat on both phones:

- [ ] Launch from a fully stopped state. The Home Screen shows Open Door of Light,
  the app-switcher label says Room of Days, and the launch canvas stays dark and
  visually continuous with the first screen.
- [ ] At App Library size, the angular threshold remains recognizable, the door
  stays visibly ajar, and the honey path reads as one contained invitation rather
  than a blurry halo or a generic house glyph.
- [ ] On the first unobscured Quests view of the process, the hearth begins
  dark, one magic ignition sound lands with one visible bloom, and the flame
  stays lit. Switching tabs or resuming does not replay it; a fully new process
  does. With Reduce Motion, it settles lit without the bloom.
- [ ] With the Ring/Silent switch on, the room stays visually understandable
  without sound. With Apple Music or Spotify already playing, Room of Days does
  not stop or take over the person's audio.
- [ ] Complete onboarding at a normal text size. Buttons remain reachable with
  gesture navigation/home indicators and notches in the way.
- [ ] Complete a Quest. Confirm immediate press feedback, sound/haptic feedback,
  the reward receipt, XP/Glimmers, and the visible room/progress change.
- [ ] Tap 20–30 controls across the room, dock, calendar, journal, overlays, and
  rewards. Ordinary contacts share one crisp, weighty voice with subtle
  five-take variation, never double-fire, and do not become tiring. During a
  calm 180–700 ms rhythm, listen for the rare D5 → A5 → E5 → D5 return. Confirm
  rapid tapping stays plain with no later catch-up, changing pages clears an
  unfinished return, and Quest completion interrupts it cleanly. Repeat one
  activation with VoiceOver or a hardware keyboard.
- [ ] Use Undo once and confirm the accidental completion and its rewards are
  actually reversed.
- [ ] Open Quests, Me, Plans, Goals, and Journal. Switch through all five tabs
  twice; no stale screen, lost scroll state, or accidental activation appears.
- [ ] In Goals, take back an adopted quest and select it again. Change the day
  of a weekly quest, force-quit, and reopen. Its progress, history, selected
  state, and new weekday remain intact.
- [ ] Spend earned Glimmers on an available room choice and confirm it remains
  equipped after force-quitting and reopening.
- [ ] In Me settings, switch Ambient Light from Walnut Night to Sea Cave. The
  live preview and surrounding canvas must visibly change while the authored
  room stays the same. Force-quit and confirm Sea Cave returns. Use Change
  Space and confirm that control still replaces the whole room instead.

## 3. Persistence and offline behavior

- [ ] Add a custom Quest and a Journal entry, force-stop/force-quit, and reopen.
  Both survive.
- [ ] Turn on airplane mode and relaunch from a stopped state. Core Quests,
  Goals, Plans, Journal, Me, rewards, and room changes remain usable.
- [ ] Complete a Quest offline, close the app, reopen offline, and confirm the
  completion persists. Restore connectivity without losing or duplicating it.
- [ ] Background the app during an edit and during a timer, then return. The app
  resumes coherently and never awards the same completion twice.

## 4. Journal media, export, and restore

- [ ] From a Journal entry, take one new photo with the camera and choose one
  existing image through the system picker. The permission explanations say
  Room of Days and match local-only storage.
- [ ] Background the camera/picker before finishing, return, and complete the
  selection. Cancel once as well. Neither path crashes or creates a blank image.
- [ ] Force-quit and confirm the Journal text and both images still render.
- [ ] Export a manual backup and place the resulting file somewhere outside the
  app. Change the room by completing another Quest, then restore the backup.
  Confirm the visible state returns to the exported point and survives a cold
  relaunch.
- [ ] Run Start over only after the backup check. Read both confirmations, let
  erasure finish, and confirm an empty local room remains after relaunch.

## 5. Optional cloud account lifecycle

Use a disposable phone-smoke account, not the reusable store-review account:

- [ ] Start device-only. Confirm core use never asks for sign-in.
- [ ] Turn on optional backup, create the disposable email/password account,
  complete a Quest, and allow the save to finish.
- [ ] Sign out. Sign back in and confirm the account's cloud room and progress
  replace the temporary local state without duplication or loss.
- [ ] Repeat one sign-in attempt offline. It fails clearly and does not overwrite
  either the cloud save or current local save.
- [ ] Delete the account in-app with its password. Confirm the sign-in is gone,
  the Journal is empty, shared space is removed, and Room of Days returns to
  device-only after a cold relaunch.

Complete the separate `ACCOUNT-RECOVERY-RUNBOOK.md` with the reusable review
account before entering its credentials in either store console.

## 6. Shared room and native links

Use the other phone or a private browser window as the visitor:

- [ ] Begin with no room code and a private listing. On Me, scroll to My Space
  and confirm **PRIVATE PAGE · OPEN TO DISCOVER** is visible without first
  opening Share my space. Tap it and confirm the Discover switch is on-screen
  and still off; the app must not publish the listing without that second,
  explicit choice.
- [ ] Turn the switch on and save or clear the optional public name. Keep the
  sheet open while the protected write is pending. Confirm the switch never
  snaps back to off before a terminal result; after success, Me changes to
  **IN DISCOVER · MANAGE LISTING** and Discover changes from `PRIVATE` to
  `LISTED`, with the same management action at the top of the page.
- [ ] In **Edit space**, turn on **Publish my visitor page**. Set **About** to
  **Anyone**, **Right now** to **Mutuals**, **Pinned moments** to **Only me**,
  and **This season** to **Anyone**. Save, close, reopen, and confirm every
  audience persists independently while all four owner cards remain visible.
- [ ] From a second signed identity, refresh Discover and open the listed room.
  Confirm the optional public name and generated room projection are visible,
  then turn the owner listing off and confirm it disappears.
- [ ] Share the room for the first time and open its exact
  `https://roomofdays.com/space/<CODE>` link. A visitor who is not in Circle
  sees the generated room plus the **Anyone** About and This season cards, but
  not the Mutuals Right now card or the Only me Pinned moments card.
- [ ] Add the visitor to the owner's Circle only. Confirm the one-way keep does
  not reveal Mutuals. Then keep the owner from the visitor's Circle too and
  confirm Right now appears without refreshing private owner content into the
  public view.
- [ ] Remove either side of the reciprocal Circle relationship and confirm the
  Mutuals card disappears after the acknowledged removal. Block the owner from
  the visitor and confirm the room/profile can no longer be opened; unblock and
  verify only the currently authorized projection returns.
- [ ] Confirm no audience can see an email, unselected goal/Quest text,
  unselected Journal or My Space writing, Journal photos, daily energy,
  account details, Firebase identity, or sender list.
- [ ] Send one fixed Spark/Circle sign from the visitor. The owner receives only
  the preset, text-free support signal.
- [ ] Open the exact link from Notes, Messages, or Mail on each installed phone.
  It routes into the intended Room of Days visit flow.
- [ ] Check the legacy `/room/<CODE>` form as well. A near miss such as
  `/roommate/<CODE>` must remain a normal web URL and must not claim the app.
- [ ] Stop Sharing, then retry the old code and both links. The visitor can no
  longer load the room; the app does not silently republish it.

Android App Links cannot receive their final pass until Play App Signing's
certificate is published in `web/.well-known/assetlinks.json`. Treat a direct
APK chooser during the earlier smoke as provisional and repeat after that step.

## 7. Reminders and OS permission surfaces

- [ ] A fresh install does not request notification permission on launch.
- [ ] Turn reminders on from Me. Only then should the OS notification prompt
  appear; its app name is Room of Days.
- [ ] Schedule the nearest practical daily or plan reminder, background the app,
  and wait for real delivery. Open the notification and confirm the app resumes
  safely.
- [ ] Dismiss the app from recents, without using Android Settings' explicit
  Force stop, then wait for a second scheduled reminder. It should still arrive
  because the OS owns the schedule. An Android Settings Force stop deliberately
  suppresses alarms until the app is opened again and is not a delivery failure.
- [ ] On Android, reboot after scheduling a later reminder and confirm the
  schedule survives once the phone finishes starting.
- [ ] Turn reminders off. Pending Room of Days notifications are removed and do
  not return after a reboot/relaunch.
- [ ] On Android, system notification settings show the user-facing channel as
  `Reminders`, with no Emberkeep or Life RPG label.

## 8. Build 41 classes, widgets, and music roles

- [ ] Download the checked-in class-schedule starter, edit its documented
  fields and a comma-separated recurrence such as `BYDAY=MO,WE,FR`, then share
  the resulting `.ics` from Files into Room of Days. The app appears in the
  share/Open In sheet and always shows review before saving.
- [ ] Repeat `.ics` handoff from Mail or another provider both while Room of
  Days is closed and while it is already open. Import two valid files in quick
  succession, reject one from review, and confirm neither is silently saved or
  lost. Invalid, non-UTF-8, and oversized files fail safely.
- [ ] Import a representative class schedule with reminders untouched. Confirm
  reminders stay off and no notification permission appears. Re-import it and
  confirm that decision remains off.
- [ ] Deliberately enable one class reminder, choose each supported lead time,
  and grant permission only after that action. Re-import without changing the
  reminder choice and confirm it remains enabled. Repeat permission denial and
  later Settings recovery without losing the class schedule.
- [ ] Add the small Day Ledger widget. With classes present it shows the next
  class without its room, notes, account, or Journal content; with no upcoming
  class it shows the authored open-day state.
- [ ] Add the medium Day Ledger widget. Confirm it shows the same next class
  plus no more than three unfinished Quest titles. Complete one of those
  Quests, return to the Home Screen, and confirm the projection updates without
  revealing completed or private content.
- [ ] Leave both widgets on the Home Screen across a class end boundary,
  background/resume, force-quit/relaunch, locale change, and device restart.
  Confirm the next class advances, the extension never displays malformed or
  stale private text, and lock-screen/app-switcher privacy treatment is
  acceptable.
- [ ] Leave global Background music off, then turn it on in Me. The normal room
  must play the lively jazzy umbrella-brush rotation, never the peaceful
  meditation theme. Toggle it quickly and background/resume; it must not get
  stuck silent or overlap another long-form track.
- [ ] Start Focus with global music off, turn Focus Music on, and confirm the
  peaceful meditation theme. Make it quiet in one tap and close the timer; the
  normal room must remain silent. Repeat with global music on and verify the
  complete handoff: normal Room jazz → Focus meditation → normal Room jazz.
- [ ] Listen to both roles and their transitions on the phone speaker and
  headphones at low and ordinary volume. Exercise pause/resume,
  background/foreground, an incoming audio interruption, Ring/Silent, and
  another audio app already playing. There must be no overlap, crackle, stuck
  silence, coercive level, or tiring mix.

## 9. Accessibility and readable layout

Use the platform's screen reader and system display settings, not screenshots
alone:

- [ ] At the largest in-app text size plus a large system text setting, complete
  onboarding, one Quest, one Plan, one Journal edit, backup export, and the first
  account-deletion confirmation. Controls remain visible, scrollable, and
  ordered.
- [ ] With VoiceOver/TalkBack, complete a Quest, change tabs, toggle reminders,
  open a Journal entry, and back out. Every actionable custom control announces
  a useful name, role, state, and action.
- [ ] Turn on OS Reduce Motion and Room of Days Reduce Motion. Room/tilt and
  celebration motion quiet down without hiding progress or controls.
- [ ] Check the app in daylight and dark surroundings. Text and focus/selection
  states remain understandable without color alone.
- [ ] On iPhone, repeat the common path with Display Zoom. On Android, repeat it
  with enlarged display size as well as font size.

Only after these checks may matching App Store Accessibility Nutrition Labels
be claimed. An automated semantics test is supporting evidence, not this pass.

## 10. Performance, power, and audio

On the physical iPhone, then on the lower-memory Android test phone:

- [ ] Continuously scroll the Quest board for two minutes while tilting the
  phone. Complete a Quest, open and close its Journal line, and switch all five
  tabs twice.
- [ ] Keep using the app for at least ten minutes so the phone is warm. Repeat
  the scroll/tab sequence. Watch for sustained jank, delayed press feedback,
  accidental taps, audio crackle, or a room that flashes/rebuilds incorrectly.
- [ ] Repeat with Low Power/Battery Saver enabled.
- [ ] Repeat with Reduce Motion enabled. Reduced motion must also reduce work;
  it must not merely make an equally expensive animation invisible.
- [ ] If visible frame misses persist, profile the iPhone build in
  Xcode/Instruments before accepting it. Do not infer a pass from desktop or
  screenshot performance.

## 11. Final record

| Gate | Android result | iPhone result | Evidence / issue link |
| --- | --- | --- | --- |
| Identity and fresh launch |  |  |  |
| Upgrade/persistence/offline |  |  |  |
| Media/export/reset |  |  |  |
| Cloud/account deletion |  |  |  |
| Sharing/privacy/native links |  |  |  |
| Reminders |  |  |  |
| Class file handoff and per-class reminders |  |  |  |
| Small and medium Day Ledger widgets |  |  |  |
| Focus and Fable listening |  |  |  |
| Large text/screen reader/motion |  |  |  |
| Warm-device performance/audio |  |  |  |

| Sign-off | Record |
| --- | --- |
| Final decision | **PASS / FAIL** |
| Tester |  |
| Date |  |
| Unresolved issues |  |

A pass means every applicable checkbox above passed on the exact recorded
artifacts and no stop condition remains. It does not replace Play/App Store
processing, privacy forms, signing setup, or review.
