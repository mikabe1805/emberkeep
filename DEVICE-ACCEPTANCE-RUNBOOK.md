# Room of Days physical-device acceptance

Complete this runbook on a physical Android phone and a physical iPhone before
submitting either store build. Emulator evidence is useful but does not close
this gate. Use disposable test data and accounts; never risk a personal journal.

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

- Install the processed TestFlight build produced by the manual Codemagic
  `ios-testflight` workflow. Do not substitute a local debug/profile build.
- Keep the matching IPA, dSYM, build log, and `release-evidence.txt` together.
- Confirm the installed version and build match `release-evidence.txt`, and that
  the evidence names the intended source commit and Team ID `D63Z4RBRT8`.

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

- [ ] Install the signed Build 10 APK, finish onboarding, complete a quest, add a
  Journal line, and note the visible XP.
- [ ] Install the signed Build 11 APK over Build 10 without uninstalling. Confirm
  Android reports version `1.0.0` / build `11`, onboarding does not return, and
  the XP and Journal line remain.
- [ ] Uninstall Room of Days, then install the verified Build 11 APK fresh.
  Confirm the old test data is gone and onboarding begins normally.

For iPhone, use the processed TestFlight build as a clean install unless a real
earlier signed/TestFlight build is available for a legitimate update test.

## 2. First launch and core story

Repeat on both phones:

- [ ] Launch from a fully stopped state. The icon, app-switcher label, splash,
  and first screen all say Room of Days and use the dark lit-window identity.
- [ ] Complete onboarding at a normal text size. Buttons remain reachable with
  gesture navigation/home indicators and notches in the way.
- [ ] Complete a Quest. Confirm immediate press feedback, sound/haptic feedback,
  the reward receipt, XP/Glimmers, and the visible room/progress change.
- [ ] Use Undo once and confirm the accidental completion and its rewards are
  actually reversed.
- [ ] Open Quests, Me, Plans, Goals, and Journal. Switch through all five tabs
  twice; no stale screen, lost scroll state, or accidental activation appears.
- [ ] Spend earned Glimmers on an available room choice and confirm it remains
  equipped after force-quitting and reopening.

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

- [ ] Share the room for the first time and open its exact
  `https://roomofdays.com/space/<CODE>` link. The browser visitor sees the
  generated room and broad presence only.
- [ ] Confirm the visitor cannot see an email, display name, goal/Quest text,
  Journal or My Space writing, Journal photos, account details, or sender list.
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

## 8. Accessibility and readable layout

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

## 9. Performance, power, and audio

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

## 10. Final record

| Gate | Android result | iPhone result | Evidence / issue link |
| --- | --- | --- | --- |
| Identity and fresh launch |  |  |  |
| Upgrade/persistence/offline |  |  |  |
| Media/export/reset |  |  |  |
| Cloud/account deletion |  |  |  |
| Sharing/privacy/native links |  |  |  |
| Reminders |  |  |  |
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
