# Room of Days Android phone test

Thank you for testing Room of Days before release. These are signed prerelease
builds, not debug builds. Please use disposable quests, journal entries, photos,
and account details rather than anything private.

## Files in the tester kit

- `room-of-days-1.0.0+11-android.apk` is used only for the upgrade check.
  Its SHA-256 is
  `A87061799010FEEC415C2E16E8DE4A7425F4871E71A10111D413DC9FFF996F2F`.
- `room-of-days-1.0.0+12-android.apk` is the release candidate to test. Its
  SHA-256 is
  `9C8C924E4C98CEC35175C03508EF5E757940CA8FD9C18627DCE6E4634B4A1B12`.

Android may ask permission for your browser or Files app to install an unknown
app. Allow it only for the app opening the APK, then turn that permission off
after installation. A normal Play Protect scan is expected. Stop and report the
exact warning if Android calls the file harmful, says its signature is invalid,
or refuses the Build 12 upgrade.

## 1. Upgrade, then clean install

Use only disposable data for this sequence.

1. Remove any older Room of Days test install, then install Build 11.
2. Finish onboarding, complete one quest, add one short Journal line, and note
   the visible XP.
3. Install Build 12 directly over Build 11 without uninstalling first.
4. Confirm Android reports Room of Days version 1.0.0, onboarding does not
   return, and the XP and Journal line remain.
5. Uninstall Room of Days, then install Build 12 again. Confirm it opens as a
   clean install with onboarding and none of the disposable Build 11 data.

Use that fresh Build 12 install for the rest of the test.

## 2. Core experience

- Complete onboarding and one quest. Check the immediate press response,
  sound/haptic response, reward receipt, XP, Glimmers, and visible room change.
- Use Undo once and confirm the completion and rewards are reversed.
- Open Quests, Me, Plans, Goals, and Journal, then switch through all five tabs
  twice.
- From Me, open About. Confirm the redesigned page identifies Mika as the sole
  maker, `VISIT KO-FI` opens `https://ko-fi.com/mikabe`, and
  `SHARE ROOM OF DAYS` opens Android's normal share sheet. Neither action may
  change XP, Glimmers, unlocks, or any room state.
- Spend earned Glimmers on a room choice, fully close the app, and confirm the
  choice remains equipped after reopening.

## 3. Persistence and offline use

- Add a custom quest and Journal entry, fully close the app, and reopen it.
  Confirm both remain.
- Turn on airplane mode and launch from a fully stopped state. Complete a quest,
  close and reopen while still offline, then restore connectivity. Nothing
  should disappear or duplicate.
- Background the app during an edit and during a timer, then return. It should
  resume coherently and never award the same completion twice.

## 4. Photos, backup, account, and sharing

- Add one new camera photo and one existing image to disposable Journal entries.
  Cancel the picker once and background it once before returning. No path should
  crash or create a blank image.
- Export a manual backup, change something visible, restore the backup, and
  confirm the earlier state returns after a cold relaunch.
- Confirm the core app never asks for sign-in. If comfortable, use a disposable
  email account to test optional cloud backup, sign-out/sign-in, and in-app
  account deletion. Do not use a personal journal or reusable password.
- Coordinate one shared-room code with the owner. A visitor should see only the
  generated room and broad preset activity signals--never email, account data,
  quest or Journal writing, or photos. Stop Sharing must revoke the code.

Android App Links are provisional until Google Play supplies the final signing
certificate. Record what happens when opening a shared link, but an app chooser
by itself is not a failure for this sideloaded build.

## 5. Reminders, accessibility, and performance

- A fresh install must not request notification permission on launch. Turn on a
  reminder from Me; only then should Android ask. Confirm a real reminder
  arrives, survives a reboot, and stops after reminders are disabled.
- At a large system font and display size, complete onboarding, one quest, one
  Journal edit, and backup export. Controls must remain visible and reachable.
- With TalkBack, complete a quest, change tabs, toggle reminders, open a Journal
  entry, and go back. Controls should announce useful names, roles, and states.
- Scroll the quest board continuously for two minutes, use the room tilt, finish
  a quest, open its Journal line, and switch all five tabs twice. Repeat after
  ten minutes of use, with Battery Saver, and with Reduce Motion.

Stop testing if you find a reproducible crash, hang, data loss, private content
in a visitor room, an unexpected sign-in/network requirement, an unexplained
permission prompt, an inaccessible common task, or sustained poor performance.

## What to send back

- Tester name and date
- Phone model and Android version
- Whether the Build 11 to Build 12 upgrade preserved XP and the Journal line
- Pass/fail for core, offline, media/backup, account/sharing, reminders,
  accessibility, and warm-device performance
- For each problem: exact starting state, actions, expected result, actual
  result, whether it repeats, and a screenshot or screen recording when useful

Please do not include real passwords, private Journal content, or personal
photos in the report.
