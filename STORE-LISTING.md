# Room of Days — Store Listing and Review Copy

Source of truth for App Store Connect, Google Play Console, and TestFlight.
Voice: human, specific, warm, and honest. Avoid clinical claims and generic
productivity language.

## Public positioning

- **App name:** Room of Days
- **Apple subtitle (30 characters):** Real quests. Real progress.
- **Apple promotional text (170 characters max):** Turn everyday actions into quests, earn XP and Glimmers, and watch your build change. Free, private by default, and never punishing.
- **Apple keywords (100 characters max):** habits,routines,goals,quests,life RPG,self care,productivity,focus,wellness,motivation
- **Primary category:** Productivity
- **Secondary category:** Lifestyle
- **Google Play short description (80 characters max):** Turn everyday actions into quests, XP, and a build that changes with you.
- **Privacy policy:** `https://roomofdays.com/privacy`
- **Account deletion:** `https://roomofdays.com/delete-account`
- **Support URL:** `https://roomofdays.com/support`
- **Marketing URL:** `https://roomofdays.com/`

## App Store What's New — Version 1.0.4

Open the door, on your terms.

Discover now offers a small, shuffled handful of rooms whose keepers chose to
be found. Make your own room discoverable only when you want to, choose a
separate optional public name, and keep interesting spaces in your Circle
without exchanging codes first. Quests, Journal pages, streaks, private Me
cards, and account details stay out of the directory.

You can block a keeper across future room-code changes or send a private
report. Public names are filtered and rate-limited, and community rules are
available from Discover.

This build also keeps the new seven-session guided-workout chooser and pairs
every quest sound with the visible movement that caused it.

## Full description

Room of Days turns the ordinary things you want to do into quests worth showing
up for.

Complete a short workout, clear the dishes, read a page, answer a message, or
write a quest of your own. Each win earns XP and Glimmers. Your six life
domains grow, your build takes shape, and new room pieces become possible.

As you level, the Woven Dawn in your room gains lasting rows and never
unweaves. There is no health bar to lose and no punishment for taking a break.
Days away cost nothing. Returning is something to celebrate.

With Room of Days you can:

- turn everyday tasks into satisfying quests;
- adopt ready-made goals or forge goals of your own;
- grow Body, Care, Mind, Craft, People, and Home;
- watch your six-stat build and room change as your level grows;
- unlock room styles, windows, fireplace colors, and furnishings;
- see patterns in your progress without being judged by them;
- keep a private journal with optional on-device photos;
- back up across devices with an optional account; and
- share a six-character code so a friend can visit the room you built;
- optionally list your room in Discover with a separate public name; and
- find a few open rooms and keep as many as you want in your private Circle.

Room of Days works without an account. Your device is the source of truth, cloud
backup is optional, and manual export is always available. There are no ads,
subscriptions, paywalls, or paid cosmetics. Everything is earned by living
your life.

Room of Days offers general fitness and wellness guidance. It is not a medical
device and does not diagnose, treat, cure, or prevent any medical condition.
Consult a qualified healthcare professional for medical advice, diagnosis, or
treatment.

## TestFlight description

Room of Days is a local-first life RPG. Real-life actions become quests; quests
earn XP and Glimmers; and lasting progress appears in your six-stat build and
your warm, personal room.

It is built to be kind. Nothing takes damage, days away cost nothing, and
coming back after a break is rewarded. Every cosmetic is earned. There are no
ads, subscriptions, or paywalls.

This build makes the optional public room directory available. Discover shows
a finite, shuffled handful of rooms whose keepers explicitly opted in. A keeper
may choose a separate optional public name; quests, Journal pages, streaks,
private Me cards, email, and account details stay out of the directory. Visitors
can privately report or block a keeper across future room-code changes, and can
keep as many trusted spaces as they want in their private Circle. Public names
are filtered, rate-limited, and protected by App Check. This build also includes
the seven-session guided-workout chooser and the final movement-linked quest
sound behavior. Protected Google place search remains intentionally off.

Feedback on clarity, warmth, performance, and anything that gets between you
and doing what matters is especially useful.

## What to Test

- Install over the previous TestFlight build and confirm your quests, goals,
  journal, room, and settings remain.
- In Me, open **Share my space**, switch on **Make my space discoverable**, and
  save or clear a separate public name. Confirm Me says **ROOM LISTED · CARDS
  PRIVATE**, then turn discovery off and confirm the listing state closes.
- Open **Discover spaces**. Refresh the finite set, open a room, keep it in your
  Circle, and return without entering a code. Confirm private quests, Journal
  pages, streaks, and account details never appear on a directory card.
- From a discovered room, block the keeper and confirm all of their current
  cards disappear. Unblock from **Manage hidden spaces**. Send a private test
  report and verify the success/failure message is honest.
- Open **Community rules & safety** from Discover and confirm the hosted page,
  support address, and appeal route work.
- In Plans, add an all-day event, a timed event, and a task. Edit, complete,
  undo, and delete them; then force-quit and confirm the saved entries return.
- Try Month, Week, 3 Days, and Day. Check Today's marker, longer titles, and
  larger text.
- If you use School, add a class, assignment, or exam beside personal plans. If
  you do not, confirm nothing asks you to set up a term or course.
- Add a manual location and routing address, tap **Get Directions**, and try
  Apple Maps and Google Maps. Confirm the remembered choice and change option
  behave clearly.
- In Goals, take back an adopted quest, choose it again, and change the day of
  a weekly quest. Confirm its history and progress stay intact.
- Look through Quests, Goals, Help for Today, and Plans for stray lines,
  awkward wrapping, or visible background seams.
- Start the app from a fully stopped state and confirm the hearth ignites once
  when Quests is first unobscured, stays lit, and does not replay on tab changes
  or resume. Repeat with Reduce Motion and the Ring/Silent switch.
- Tap across the dock, calendar, journal, overlays, and rewards at an ordinary
  pace and in a rapid burst. Confirm clicks stay crisp, a rare melodic answer
  never spills across pages, completion takes priority, and background music
  keeps playing.
- Check the Day Ledger in the Home Screen and App Library at its smallest size;
  the completed honey mark should catch the eye without losing the book.
- Repeat important flows offline, with Reduce Motion, Larger Text, and
  VoiceOver.

Report anything confusing, slow, visually cold, or unrewarding, plus anything
that makes returning after a break feel harder than it should.

## Reviewer notes

- **Sign-in required:** No. The complete guest experience works immediately.
- **Network required:** No for core quests, goals, journal, Daybook, tapestry
  and room progression, shop, and insights. Network is required for optional
  cloud/account and shared-space features, and normally by the chosen maps app
  when opening directions.
- **Health and wellness:** Guided workouts and wellness routines are general
  guidance. Room of Days does not use HealthKit, Health Connect, heart-rate or
  body-sensor data, or device location. A person can type a place into the
  Daybook, but the app requests no location permission. It is not a medical
  device and makes no diagnosis or treatment claim.
- **Account creation:** Me → Device-only by default → Turn on cloud backup →
  Create account.
- **Account deletion:** Me → Your account → Delete account. The user confirms
  the account password; the app removes the sign-in, cloud save, shared space,
  and local profile.
- **Privacy policy in app:** Me → Your save is yours → Privacy.
- **Project support:** The iOS candidate deliberately omits the external Ko-fi
  tip link and offers only the system share action from About. It contains no
  purchase, paid entitlement, subscription, or in-app donation flow. Android
  and web may link to the owner's voluntary tip-only Ko-fi page; tips unlock
  nothing in Room of Days.
- **Shared spaces and Discover:** Exact-code rooms remain read-only to visitors.
  Discover is a separate, explicit opt-in and returns only a finite shuffled
  handful. Directory cards contain a separate optional public name, preset room
  appearance, level, app-generated title, and an opaque stable keeper key used
  for owner-level blocking. They do not contain quests, Journal pages, streaks,
  private Me cards, email, sign-in credentials, or account-profile details.
  Opening a card fetches the same shared room by its bearer code.
- **Public-name safety:** Names are limited to 32 characters, normalized,
  filtered for abusive language, links, handles, and contact cues, rate-limited,
  and written only through an App Check-protected callable. Every discovered
  room exposes **Block or report this keeper**. Blocking persists locally across
  room-code changes; reports are private and enter a developer-reviewed queue.
  Community rules and the monitored support/appeal address are published at
  `https://roomofdays.com/community`. The developer reviews the queue daily and
  targets action within 24 hours; if that operation cannot be maintained,
  public names are disabled until review resumes.
- **Review account:** OWNER REQUIRED before Google Play review. Create one
  dedicated, reusable review-only account, store its credentials outside the
  repository, and enter them only in the store consoles. Google should receive
  it proactively because optional cloud backup is account-gated. Apple can
  still be told that sign-in is not required because the complete guest
  experience works without it; keep the same account ready if App Review asks
  to inspect the optional cross-device path.
- **Account recovery:** Before supplying that account, complete
  `ACCOUNT-RECOVERY-RUNBOOK.md`. Brand Firebase's password-reset sender,
  template, domain, and action page as Room of Days, then prove on the review
  account that the old password fails, the new password signs in, and its cloud
  save remains intact. Support never asks for or handles a user's password.

## Apple App Store Connect completion key

- **Price:** Free.
- **License Agreement:** Use Apple's standard EULA; Room of Days has no custom
  license agreement.
- **Content Rights:** **Yes.** The app bundles third-party fonts and sound
  source material under licenses that permit this use: SIL Open Font License,
  CC0 1.0, and the Pixabay Content License. Provenance is recorded in
  `ASSET-LICENSES.md`, `assets/sfx/SOURCES.md`, and the four bundled
  `assets/google_fonts/OFL-*.txt` files. Do not answer No merely because the
  material is open-licensed.
- **Copyright:** OWNER REQUIRED. Enter `2026 <legal rights holder>` using the
  person or entity that actually owns Room of Days, exactly as legally
  appropriate. Do not type the copyright symbol; Apple adds it.
- **App Review contact:** OWNER REQUIRED. Supply a monitored person's name,
  direct email address, and phone number. These fields are required and are not
  replaced by the public support URL.
- **Sign-in required:** No. The complete guest experience is available without
  credentials. Paste the `Reviewer notes` section above into App Review Notes.
- **Export compliance:** The app uses standard platform/service HTTPS and no
  proprietary or non-exempt cryptography. Source `Info.plist` sets
  `ITSAppUsesNonExemptEncryption` to `false`; confirm the uploaded build shows
  the same value. No App Store Connect encryption document is expected for
  this candidate.
- **Digital Services Act (DSA) status:** OWNER REQUIRED even if the app will not
  be distributed in the EU. The owner must make the legal trader/non-trader
  self-assessment. An individual hobbyist acting outside any trade, business,
  craft, or profession may be a non-trader; distributing in connection with a
  business or organization points toward trader status. If trader is selected,
  finish Apple's verification of the public address, phone number, and email
  before EU distribution. Do not choose based only on which contact details
  are more convenient to publish.
- **Regulated Medical Devices:** With Productivity / Lifestyle categories and
  `Medical or Treatment Information: None`, this declaration is not triggered.
  If App Store Connect nevertheless presents it, answer **No**: Room of Days is
  general wellness software and is not a regulated medical device in the
  EU/EEA, UK, or US.
- **Version release:** Manual release is recommended for 1.0 so approval can be
  followed by one final link, listing, and availability check before going
  live.

Official references: [Apple platform-version fields and App Review information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information),
[Apple app-level information](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information),
[export-compliance key](https://developer.apple.com/documentation/bundleresources/information-property-list/itsappusesnonexemptencryption),
[DSA trader requirements](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements/),
and [regulated-medical-device status](https://developer.apple.com/help/app-store-connect/manage-app-information/declare-regulated-medical-device-status).

## Google Play App content completion key

- **App or game / price / category:** App; Free; Productivity.
- **Ads:** No. The candidate contains no ads or ad SDK.
- **Sign-in details:** Select **All or some functionality is restricted** and
  provide the dedicated, reusable review-only email and password described
  above. In `Any other instructions`, enter: `The core app works without an
  account. To inspect optional cross-device cloud backup, open Me → Device-only
  by default → Turn on cloud backup → Sign in. There is no MFA, subscription,
  location restriction, or other access condition.` Keep the account valid for
  every active review; never commit its credentials to this file.
- **Privacy policy / Data safety / account deletion:** Use the URLs and exact
  answers in the two privacy sections below. Enter
  `https://roomofdays.com/delete-account` in the account-deletion field.
- **Target audience and content rating:** Use the answer key below. Do not mark
  Room of Days as designed for children or enroll it in Families.
- **Health apps:** Yes. Use all four non-medical categories in the Health apps
  section below; do not select `My app doesn't provide any health features`.
- **Financial features:** Select **My app doesn't provide any financial
  features**. XP and Glimmers are non-purchasable, non-transferable progression
  counters with no cash, credit, loyalty, exchange, or real-world redemption
  value. They are not financial rewards or points.
- **Government apps:** No. Room of Days is not developed by or on behalf of a
  government and does not communicate or facilitate government information or
  services.
- **News and Magazine apps:** No.
- **COVID-19 contact tracing or status app:** No.
- **Advertising ID:** No. The exact Build 11 permission inventory contains no
  `com.google.android.gms.permission.AD_ID`, and the app performs no advertising
  or analytics.
- **Photo and video permissions:** No broad-media declaration is expected. The
  candidate requests neither `READ_MEDIA_IMAGES` nor `READ_MEDIA_VIDEO`; it
  uses the system picker for user-selected Journal media.
- **Permissions Declaration Form:** No high-risk or sensitive permission form
  is expected for the exact candidate. Its only user-facing runtime permission
  is contextual notification access; it requests no SMS, call-log, contacts,
  location, broad media, exact-alarm, install-package, VPN, or accessibility
  service permission.
- **Child Safety Standards / age-restricted chat:** Not in scope. Room of Days
  is not a Social or Dating app and has no anonymous chat, random chat,
  free-form messaging, public profiles, or visitor-visible user-generated
  content. Fixed Circle/Spark receipts and generated-only code-gated rooms do
  not change that answer.

After completing the forms, open both `Needs attention` and `Actioned` on the
App content page. Resolve every card Play Console actually shows for Build 11;
policy cards can change and the console is authoritative about which forms are
pending.

Official references: [Play App content overview](https://support.google.com/googleplay/android-developer/answer/9859455),
[review sign-in requirements](https://support.google.com/googleplay/android-developer/answer/15748846),
[Financial features declaration](https://support.google.com/googleplay/android-developer/answer/13849271),
[government-app requirements](https://support.google.com/googleplay/android-developer/answer/9514050),
[photo and video permission requirements](https://support.google.com/googleplay/android-developer/answer/15800983),
and [Advertising ID](https://support.google.com/googleplay/android-developer/answer/6048248).

## App privacy and Play Data safety worksheet

Answer the console questionnaires from actual behavior, not from whether a
feature is optional.

- **Tracking:** No.
- **Advertising / analytics:** None.
- **Account data:** Email address is collected only when an account is created.
  A Firebase user ID is also created for optional cloud backup, shared-space
  publishing, Circle receipts, and preset support signals. Merely opening a
  room code does not create an identity. These are linked to that Firebase
  identity and used only for app functionality.
- **Gameplay/app activity:** The cloud save contains progress, quests, goals,
  journal text, settings, and room state when backup is enabled; linked to the
  user; used for app functionality.
- **Health:** Preset or custom quests, goals, and journal writing can describe
  sleep, meals, medication, stress, or other health and wellness routines. If
  cloud backup is enabled, those titles, notes, and completion records can be
  linked to the Firebase identity and are used only for app functionality.
- **Fitness:** Guided-workout and other exercise/activity progress can be part
  of the optional cloud save; linked to the Firebase identity; used for app
  functionality. Room of Days does not read HealthKit, Health Connect,
  heart-rate or body-sensor data, or location. Device tilt only controls visual
  depth and is not stored or uploaded.
- **User name:** A locally chosen name is included only in the optional full
  cloud save; linked to the Firebase identity; used for app functionality; not
  published to shared-room visitors.
- **Other user content:** Custom quests and goals, journal text, My Space
  writing, and related save content are included in the optional full cloud
  backup; linked to the Firebase identity; used only for app functionality;
  never published to shared-room visitors in the v1 candidate.
- **Social interactions:** Keeping a room in Circle or sending preset support
  can store a fixed signal kind, timestamp, and anonymous sender ID for that
  room’s owner. There is no custom message body or public sender list.
- **Photos:** Not collected in the v1 store candidate. Room of Days keeps
  journal photos local and does not upload them to its cloud backup or shared
  spaces. The operating system may include local app data in device backups the
  person controls.
- **Diagnostics:** No developer analytics or crash-reporting SDK is currently
  included. Platform providers may supply their own aggregate console data.
- **Deletion:** Available immediately inside the app. The public deletion URL
  also provides a direct email request path for someone who uninstalled the app
  or cannot sign in; verified requests are normally completed within seven
  days.
- **Data encrypted in transit:** Yes, for Firebase traffic.
- **Data sale:** No.

Keep these answers aligned with `web/privacy.html` and
`ios/Runner/PrivacyInfo.xcprivacy`.

## Apple App Privacy answer key

Use these answers for the submitted v1 binary. Apple requires the label to
cover optional collection too, so the correct opening answer is **Yes, we
collect data from this app**.

- **Privacy Policy URL:** `https://roomofdays.com/privacy`
- **User Privacy Choices URL:** `https://roomofdays.com/delete-account`
- Select these data types: **Name**, **Email Address**, **User ID**, **Health**,
  **Fitness**, **Gameplay Content**, and **Other User Content**.
- For every selected type: **App Functionality = Yes**, **Linked to the User =
  Yes**, **Used for Tracking = No**.
- Do not select Photos or Videos, Product Interaction, Diagnostics, Location,
  Contacts, Purchases, or Advertising Data for this candidate.

Why: Name, email, and the Firebase ID can enter the optional account/cloud
path. Health covers backed-up quest, goal, or journal content about sleep,
meals, medication, stress, and similar routines; Fitness covers guided-workout
and exercise progress. Gameplay Content covers the backed-up save and generated
shared-room state. Other User Content covers custom quests, goals, journal text,
and My Space writing in the optional cloud save. The local usage log and all
photos stay on-device.

Official references: [Apple App Privacy workflow](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/),
[Apple data-type definitions](https://developer.apple.com/app-store/app-privacy-details/),
and [Firebase Apple disclosure guidance](https://firebase.google.com/docs/ios/app-store-data-collection).

## Google Play Data safety answer key

- **Does the app collect or share required user data types?** Yes.
- **Is all collected data encrypted in transit?** Yes.
- **Can users request deletion?** Yes. Deletion is available in-app and at
  `https://roomofdays.com/delete-account`. The page prominently opens a
  pre-addressed deletion request to the monitored support inbox, does not send
  the person back to the app, and explains verification and the seven-day
  completion window.
- **Data shared with third parties:** No. Firebase is the service provider;
  generated room sharing and fixed support signals are deliberate user actions,
  not advertising, data-broker, or analytics sharing.
- **Independent security review:** No.

Create these collected-data rows:

| Data type | Collected | Shared | Ephemeral | Required | Purposes |
| --- | --- | --- | --- | --- | --- |
| Name | Yes | No | No | Optional | App functionality |
| Email address | Yes | No | No | Optional | App functionality; Account management |
| User IDs | Yes | No | No | Optional | App functionality; Account management; Fraud prevention, security, and compliance |
| Health info | Yes | No | No | Optional | App functionality |
| Fitness info | Yes | No | No | Optional | App functionality |
| Other user-generated content | Yes | No | No | Optional | App functionality |
| Other actions | Yes | No | No | Optional | App functionality |
| Device or other IDs | Yes | No | No | Optional | App functionality; Fraud prevention, security, and compliance |

`Other actions` covers game progress and the fixed Circle/Spark actions, not tap
analytics. `Device or other IDs` is the conservative disclosure for Firebase
Authentication security metadata such as the IP address processed during an
optional sign-up or authentication action. Do not select approximate location:
Room of Days does not derive or use location from that address.

`Health info` covers health-related quest, goal, and journal content such as
sleep, medication, meals, or stress routines when optional cloud backup is on.
`Fitness info` covers guided-workout and exercise progress. These disclosures
do not mean Room of Days reads Health Connect, HealthKit, heart-rate sensors, or
location; it does not.

Do not select Photos, Messages, App interactions, Crash logs, Diagnostics,
Location, Contacts, Files and docs, Calendar, Purchase history, or Advertising
data. The app requests photo access for local Journal media, but Google defines
collection as transmission off-device; v1 performs no such transmission.

Official references: [Play Data safety instructions and definitions](https://support.google.com/googleplay/android-developer/answer/10787469),
[Google Play account-deletion requirements](https://support.google.com/googleplay/android-developer/answer/13327111),
[Android data-use guidance](https://developer.android.com/privacy-and-security/declare-data-use),
and [Firebase Android disclosure guidance](https://firebase.google.com/docs/android/play-data-disclosure).

## Google Play Health apps declaration

Do not select **My app doesn't provide any health features**. The submitted
candidate contains guided workouts plus preset goals and evidence for movement,
meals, sleep, breathing, and other wellness routines.

Select these non-medical Health and fitness features:

- **Activity and Fitness** — guided routines, workouts, walks, steps, and their
  completion records.
- **Nutrition and Weight Management** — meal, hydration, and meal-planning
  goals. Room of Days does not estimate weight or prescribe a diet.
- **Sleep Management** — wind-down, sleep-schedule, and sleep-hygiene goals.
- **Stress Management, Relaxation, Mental Acuity** — breathing resets,
  reflection, journaling, focus, and mindfulness-oriented routines.

Do not select a Medical, Medical Device, Health Research, Period Tracking, or
Health Connect category. Room of Days is general wellness software, uses no
health-platform permission, makes no diagnosis or treatment claim, and includes
this required store-description language:

> Room of Days offers general fitness and wellness guidance. It is not a
> medical device and does not diagnose, treat, cure, or prevent any medical
> condition. Consult a qualified healthcare professional for medical advice,
> diagnosis, or treatment.

Google requires developers providing health apps to use an **Organization**
Play developer account, with verifiable organization information and a D-U-N-S
number. Confirm the current account type before submission; if it is Personal,
resolve the Organization requirement in Play Console rather than declaring that
Room of Days has no health features.

Official references: [Health apps declaration](https://support.google.com/googleplay/android-developer/answer/14738291),
[Health Content and Services policy](https://support.google.com/googleplay/android-developer/answer/16679511),
and [Play developer account types](https://support.google.com/googleplay/android-developer/answer/13634885).

## Age rating and content declarations

- No violence, gambling, sexual content, controlled substances, or mature
  themes.
- No free-form chat or post feed. Discover displays one optional, filtered
  public name plus app-generated room fields. Circle and Sparks remain private,
  fixed-purpose interactions rather than a follower count or public ranking.
- Wellness/productivity framing only. Do not claim to diagnose, treat, cure, or
  prevent ADHD or any medical condition.
- Complete Apple’s updated age-rating questionnaire in App Store Connect before
  submission.

### Apple age-rating answers

- **Parental Controls / Age Assurance:** No / No.
- **Unrestricted Web Access / User-Generated Content / Social Media /
  Advertising:** No / Yes / No / No. User-generated content is limited to the
  optional public name in Discover and has filtering, reporting, blocking, and
  human moderation.
- **Messaging and Chat:** Yes, conservatively, because one person can send a
  fixed preset Spark or Circle receipt to a room owner. There is no free-form
  message, reply thread, public post, or sender profile.
- **Health or Wellness Topics:** Frequent. The app includes guided workouts,
  movement, sleep, food, and self-care recommendations.
- **Medical or Treatment Information:** None. The workout surface identifies
  itself as general fitness guidance, not medical advice.
- **Profanity, horror, alcohol/tobacco/drugs, mature themes, sexuality/nudity,
  cartoon/fantasy violence, realistic violence, and guns/weapons:** None.
- **Contests and simulated gambling:** None. **Gambling:** No. **Loot Boxes:**
  No; Room of Days sells nothing, and Apple defines loot boxes as randomized
  virtual items for purchase.
- **Made for Kids / Override:** Not Applicable. Accept Apple’s recalculated
  regional results after answering User-Generated Content truthfully; do not
  preserve the prior 9+ result by withholding the new public-name surface.

Apple’s current definitions are in the
[age-rating reference](https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions).

### Apple Accessibility Nutrition Labels

Prepare iPhone answers, but do not publish an accessibility claim until the
physical-iPhone pass proves that every common task meets Apple's criteria.
Room of Days has implementation and automated evidence for Larger Text,
Reduced Motion, and VoiceOver semantics, but screenshots and widget tests do
not prove the whole installed experience. Voice Control, Sufficient Contrast,
Dark Interface, and Differentiate Without Color Alone also require a real-device
audit before claiming support. Captions and Audio Descriptions are not
applicable because the candidate contains no spoken or video content.

Apple allows the Accessibility URL to remain blank. Add one only after a public
Room of Days accessibility page accurately documents the verified support and
any limitations.

Official references: [Accessibility Nutrition Labels overview](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/overview-of-accessibility-nutrition-labels/)
and [label management](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/manage-accessibility-nutrition-labels/).

### Google target audience and content rating

- Recommended target audience: **13–15, 16–17, and 18+**; do not mark the app as
  designed for children or enroll it in Families.
- Ads, purchases, gambling, simulated gambling, paid randomized items,
  violence, sexual content, profanity, drugs, and unrestricted web browsing:
  **No**.
- User-shared text: **Yes**, limited to an optional filtered public name.
  User-shared photos/audio: **No**. Public UGC discovery: **Yes**.
- User interaction: **Yes**. Explain that Discover has no chat, comments,
  public follower graph, or ranking; Circle/Spark receipts remain preset and
  text-free, while public names have report, block, and moderation controls.
- Account required: **No**. Optional account creation and deletion are both
  available.

## Screenshot story

Use real production UI with no device frame required. Capture at least these
five moments in one consistent account:

1. **Your day, as quests** — a welcoming board with achievable actions.
2. **A real win becomes progress** — the reward receipt with XP and Glimmers.
3. **Your space reflects the work** — a furnished room, level, and milestones.
4. **Make the space your own** — a complete-room preview with no-cost switching.
5. **Kind progress over time** — a private Journal note in its then-and-now
   context.

## Store asset checklist

- App Store icon: `web/icons/Icon-1024.png`.
- Google Play icon: `web/icons/Icon-512.png` (512×512 PNG).
- Google Play feature graphic: `store-assets/google-play-feature-graphic-1024x500.png`.
- App Store phone screenshots: six opaque 24-bit RGB PNGs at Apple's accepted
  1290×2796 iPhone 6.9-inch class are in
  `store-assets/screenshots/app-store/`.
- The App Store sequence adds a real Plans/Daybook frame between Reward and My
  Space so the 1.0.4 calendar work is represented without overlay copy.
- Google Play phone screenshots: the earlier five-state core story is independently
  rendered at Google's recommended 1080×1920 portrait class in
  `store-assets/screenshots/google-play/`. Do not upload the taller Apple
  files to Play; their long edge exceeds Google's mandatory 2:1 limit.
- Exact filenames and ready-to-paste Google Play alt text are in
  `store-assets/screenshots/README.md`.
- iPad screenshots are not required while the target device family remains
  iPhone-only.

## Final truthfulness rule

Do not mention a character, creature, avatar, paid upgrade, medical outcome, or
feature that is not in the submitted binary. Keep the free, no-ads, no-paywall,
local-first, permanent-progress, and non-punitive promises prominent.
