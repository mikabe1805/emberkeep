import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberkeep/academic_calendar/domain/academic_schedule.dart';
import 'package:emberkeep/academic_calendar/widgets/academic_calendar_sections.dart';
import 'package:emberkeep/daybook/widgets/daybook_event_editor.dart';
import 'package:emberkeep/daybook/services/place_search_authorization.dart';
import 'package:emberkeep/daybook/widgets/daybook_place_fields.dart';
import 'package:emberkeep/daybook/widgets/daybook_task_editor.dart';
import 'package:emberkeep/release_features.dart';

String _source(String path) {
  final file = File(path);
  expect(file.existsSync(), isTrue, reason: 'Missing release source: $path');
  return file
      .readAsStringSync()
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n');
}

void main() {
  test('web invite entry has a static branded social preview', () {
    const canonical = 'https://roomofdays.com/';
    const image = '${canonical}icons/Icon-512.png';
    final index = _source('web/index.html');
    final compact = index.replaceAll(RegExp(r'\s+'), ' ');

    expect(compact, contains('<link rel="canonical" href="$canonical">'));
    expect(compact, contains('<meta property="og:type" content="website">'));
    expect(
      compact,
      contains('<meta property="og:site_name" content="Room of Days">'),
    );
    expect(
      compact,
      contains('<meta property="og:title" content="Room of Days">'),
    );
    expect(compact, contains('<meta property="og:url" content="$canonical">'));
    expect(compact, contains('<meta property="og:image" content="$image">'));
    expect(compact, contains('<meta name="twitter:card" content="summary">'));
    expect(
      compact,
      contains('<meta name="twitter:title" content="Room of Days">'),
    );
    expect(compact, contains('<meta name="twitter:image" content="$image">'));
    expect(
      RegExp(
        r'<meta property="og:description" content="[^"]+">',
      ).hasMatch(compact),
      isTrue,
    );
    expect(
      RegExp(
        r'<meta name="twitter:description" content="[^"]+">',
      ).hasMatch(compact),
      isTrue,
    );
    expect(File('web/icons/Icon-512.png').existsSync(), isTrue);

    // The preview layer must not replace the installable-app metadata.
    expect(compact, contains('<link rel="manifest" href="manifest.json">'));
    expect(compact, contains('name="apple-mobile-web-app-capable"'));
    expect(compact, contains('name="theme-color" content="#191210"'));
  });

  test('web release has a first-party, freshness-checked offline shell', () {
    final index = _source('web/index.html');
    final bootstrap = _source('web/flutter_bootstrap.js');
    final worker = _source('web/room_of_days_service_worker.js');
    final preparer = _source('tool/prepare_web_offline.dart');
    final downloadVerifier = _source('tool/verify_public_downloads.mjs');
    final marketingRoot = _source('tool/marketing_root.mjs');
    final introductionOverlay = _source('tool/overlay_introduction.mjs');
    final audio = _source('lib/audio.dart');
    final webAudioSupport = _source('lib/platform/audio_support_web.dart');
    final hosting =
        jsonDecode(_source('firebase.json')) as Map<String, dynamic>;
    final hostingConfig = hosting['hosting'] as Map<String, dynamic>;
    final headers = (hostingConfig['headers'] as List).cast<Map>();

    expect(index, isNot(contains('rel="preload" href="assets/assets/rooms/')));
    expect(bootstrap, contains('{{flutter_service_worker_version}}'));
    expect(bootstrap, contains('registerRoomOfDaysServiceWorker'));
    expect(bootstrap, contains('room_of_days_service_worker.js'));
    expect(bootstrap, contains("canvasKitBaseUrl: 'canvaskit/'"));
    expect(worker, contains("const cachePrefix = 'room-of-days-shell-'"));
    expect(worker, contains("new URL('offline-assets.json', scopeUrl)"));
    expect(worker, contains('manifest.schema !== 2'));
    expect(worker, contains("supportsSkwasm() ? 'skwasm' : 'canvaskit'"));
    expect(worker, contains("event.data === 'PAUSE_OFFLINE_CACHE'"));
    expect(worker, contains("event.data === 'WARM_OFFLINE_CACHE'"));
    expect(worker, contains('const offlineDocumentUrl = scopeUrl;'));
    expect(worker, contains("request.mode === 'navigate'"));
    expect(worker, contains('if (!self.navigator.onLine)'));
    expect(worker, contains('if (response.ok) return response;'));
    expect(worker, contains('if (bypassAppShell(url)) return;'));
    expect(worker, contains("relativePath === 'android'"));
    expect(worker, contains("relativePath === 'introduction'"));
    expect(worker, contains("relativePath.startsWith('introduction/')"));
    expect(worker, contains("request.headers.get('range')"));
    expect(worker, contains('await self.clients.claim()'));
    expect(preparer, contains("args.single != '--check'"));
    expect(preparer, contains('const _maximumCacheBytes = 96 * 1024 * 1024'));
    expect(preparer, contains("'main.dart.wasm'"));
    expect(preparer, contains("'schema': 2"));
    expect(preparer, contains("relative == 'flutter_service_worker.js'"));
    expect(
      preparer,
      contains("relative == 'assets/assets/sfx/hearth_room.wav'"),
    );
    expect(preparer, contains("relative == 'android.html'"));
    expect(preparer, contains("builtVersion['build_number']"));
    expect(downloadVerifier, contains('api.github.com/repos/'));
    expect(downloadVerifier, contains('asset.digest'));
    expect(downloadVerifier, contains('VITE_APP_STORE_URL'));
    expect(downloadVerifier, contains('resolveMarketingRoot(appRoot)'));
    expect(introductionOverlay, contains('resolveMarketingRoot(appRoot)'));
    expect(marketingRoot, contains('ROOM_OF_DAYS_MARKETING_ROOT'));
    expect(marketingRoot, contains('depth < 6'));
    expect(
      audio,
      contains('kIsWeb && !browserAudioAvailable'),
      reason: 'web taps must stay silent when a browser has no Web Audio',
    );
    expect(webAudioSupport, contains("'AudioContext'.toJS"));
    expect(hostingConfig['predeploy'], [
      'node tool/verify_public_downloads.mjs',
      'node tool/build_release_web.mjs',
      'dart run tool/prepare_web_offline.dart',
      'node tool/overlay_introduction.mjs',
    ]);
    final hostedWebBuilder = _source('tool/build_release_web.mjs');
    expect(hostedWebBuilder, contains('SPACE_DISCOVERY=true'));
    expect(hostedWebBuilder, contains('PUBLIC_DISCOVERY_NAMES=true'));
    expect(hostedWebBuilder, contains('VISITOR_PROFILE_SHARING=true'));
    expect(
      hostedWebBuilder,
      contains(
        'PLACE_SEARCH_APP_CHECK_WEB_SITE_KEY=6L1SoM-jCpoiyD9A99Y41P6zHtY',
      ),
    );
    expect(
      headers.any(
        (header) =>
            header['regex'] == r'^/(introduction|android)(/|\.html)?$' &&
            (header['headers'] as List).any(
              (value) =>
                  (value as Map)['key'] == 'Cache-Control' &&
                  value['value'] == 'no-cache, no-store, must-revalidate',
            ),
      ),
      isTrue,
    );
    final genericRouteHeader = headers.indexWhere(
      (header) => header['regex'] == r'^/[^.]*$',
    );
    final alwaysFreshRouteHeader = headers.indexWhere(
      (header) => header['regex'] == r'^/(introduction|android)(/|\.html)?$',
    );
    expect(
      alwaysFreshRouteHeader,
      greaterThan(genericRouteHeader),
      reason:
          'Firebase applies matching header rules in order, so the exact download and introduction routes must override the generic HTML cache',
    );
    expect(
      headers.any(
        (header) =>
            header['source'] == '**' &&
            (header['headers'] as List).any(
              (value) =>
                  (value as Map)['key'] == 'Cross-Origin-Opener-Policy' &&
                  value['value'] == 'same-origin',
            ) &&
            (header['headers'] as List).any(
              (value) =>
                  (value as Map)['key'] == 'Cross-Origin-Embedder-Policy' &&
                  value['value'] == 'credentialless',
            ),
      ),
      isTrue,
    );
    expect(
      headers.any(
        (header) =>
            header['regex'] == r'^/[^.]*$' &&
            (header['headers'] as List).any(
              (value) =>
                  (value as Map)['key'] == 'Cache-Control' &&
                  value['value'].toString().contains('max-age=0'),
            ),
      ),
      isTrue,
    );
    expect(
      headers.any(
        (header) =>
            header['source'] == '**/*.@(mjs|js|wasm|json)' &&
            (header['headers'] as List).any(
              (value) =>
                  (value as Map)['key'] == 'Cache-Control' &&
                  value['value'].toString().contains('max-age=0'),
            ),
      ),
      isTrue,
    );
    expect(_source('firebase.json'), isNot(contains('immutable')));
    for (final source in const [
      '/flutter_bootstrap.js',
      '/room_of_days_service_worker.js',
      '/offline-assets.json',
      '/version.json',
    ]) {
      expect(
        headers.any(
          (header) =>
              header['source'] == source &&
              (header['headers'] as List).any(
                (value) =>
                    (value as Map)['key'] == 'Cache-Control' &&
                    value['value'] == 'no-cache, no-store, must-revalidate',
              ),
        ),
        isTrue,
        reason: '$source must always revalidate so installed PWAs update',
      );
    }
  });

  test('temporary Android download is branded and verifiable', () {
    final page = _source('web/android.html').replaceAll(RegExp(r'\s+'), ' ');

    expect(page, contains('Room of Days for Android'));
    expect(
      page,
      contains(
        'https://github.com/mikabe1805/emberkeep/releases/download/'
        'v1.0.2-android-preview.20/room-of-days-1.0.2-build-20.apk',
      ),
    );
    expect(page, isNot(contains('href="/downloads/')));
    expect(page, contains('Android 7 or newer'));
    expect(page, contains('install unknown apps'));
    expect(page, contains('install Build 20 over it without uninstalling'));
    expect(page, contains('export a backup'));
    expect(
      page,
      contains(
        '07DFA5EB180C1AF3C53773B7AC24AC4176503F67F5807DD9DDCBECA9DCBFF61F',
      ),
    );
  });

  test('public privacy copy covers sharing and discovery boundaries', () {
    final privacy = _source('web/privacy.html');
    final compact = privacy.replaceAll(RegExp(r'\s+'), ' ');

    expect(compact, contains('does not publish your private Me display name'));
    expect(compact, contains('profile-card text'));
    expect(compact, contains('journal writing'));
    expect(compact, contains('season writing'));
    expect(compact, contains('generated room'));
    expect(compact, isNot(contains('Open my visitor page')));
    expect(compact, contains('does not upload journal photos'));
    expect(compact, contains('operating system may include local app data'));
    expect(compact, contains('device backups you choose to enable'));
    expect(compact, contains('workout or other activity progress'));
    expect(compact, contains('exercise, sleep, meals, medication'));
    expect(compact, contains('does not read HealthKit'));
    expect(compact, contains('Device tilt'));
    expect(compact, contains('is not a medical device'));
    expect(compact, contains('does not diagnose, treat, cure, or prevent'));
    expect(compact, contains('qualified healthcare professional'));
    expect(compact, contains('basic app/device metadata'));
    expect(compact, contains('derive location'));
    expect(compact, isNot(contains('Firebase Cloud Storage')));
    expect(compact, contains('Anyone with the room link'));
    expect(compact, contains('merely opening a room code does not'));
    expect(compact, contains('turns on full-save backup'));
    expect(compact, contains('Discover is a separate opt-in'));
    expect(compact, contains('opaque stable keeper key'));
    expect(compact, contains('expire 30 days'));
    expect(compact, contains('optional public name'));
    expect(compact, contains('privately report'));
    expect(compact, contains('community rules and safety guide'));
  });

  test('production discovery deployment stays fail-closed', () {
    final environment = _source('functions/.env.emberkeep-5b33b');
    final firebase = _source('firebase.json');

    expect(environment, contains('DISCOVERY_ENFORCE_APP_CHECK=true'));
    expect(environment, contains('DISCOVERY_PUBLIC_NAMES_ENABLED=true'));
    expect(environment, contains('PLACES_ENFORCE_APP_CHECK=false'));
    expect(firebase, contains('"runtime": "nodejs22"'));
  });

  test('place search review policies cover end-user terms and retention', () {
    final privacy = _source('web/privacy.html').replaceAll(RegExp(r'\s+'), ' ');
    final terms = _source('web/terms.html').replaceAll(RegExp(r'\s+'), ' ');
    final deletion = _source(
      'web/delete-account.html',
    ).replaceAll(RegExp(r'\s+'), ' ');

    for (final disclosure in const [
      'does not request or access your current location',
      'Manual schedule and location details stay on your device',
      'outside Cloud Firestore',
      'typed search query, a random search-session token, the app language',
      'selected Google provider place ID',
      'through a protected Room of Days service',
      'Firebase identity',
      'retained random installation ID',
      'not a hardware or device ID',
      'display name and address are transient',
      'not persisted',
      'does not use place-search queries for advertising or analytics',
      'does not delete your Firebase account or retained installation ID',
      'future requests from another open browser tab',
      'Firebase App Check',
      'attestation token',
      'Play Integrity',
      'App Attest',
      'DeviceCheck',
      'reCAPTCHA v3',
      'security and abuse prevention',
      'per-identity and per-installation abuse counters',
      'marked to expire 35 days after the last update',
      'Firestore deletes expired documents asynchronously afterward',
      'remove private service identity',
      'place-search-enabled installed build',
      'not shown in the web app',
      'service identity deletion tombstone',
      'late Firebase tokens',
      'marked to expire 35 days after it is created or refreshed',
      'owner-only server lookup',
      'server deletion lock',
      'private Spark and Circle receipts',
      'identity is kept so you can retry',
      'retained installation ID stays on your device',
      'Abuse counters associated with that ID remain marked for expiration',
    ]) {
      expect(privacy, contains(disclosure));
    }
    expect(terms, contains('https://maps.google.com/help/terms_maps/'));
    expect(terms, contains('https://policies.google.com/privacy'));
    expect(
      terms,
      isNot(contains('https://cloud.google.com/maps-platform/terms')),
    );
    expect(deletion, contains('remove private service identity'));
    expect(deletion, contains('installed app'));
    expect(deletion, contains('not shown in the web app'));
    expect(deletion, contains('service identity deletion tombstone'));
    expect(deletion, contains('late Firebase tokens'));
    expect(deletion, contains('owner-only server lookup'));
    expect(deletion, contains('server deletion lock'));
    expect(deletion, contains('identity is kept so you can retry'));
    expect(deletion, contains('currently known published shared space'));
    expect(deletion, isNot(contains('any shared room it owns')));
    expect(deletion, contains('retained random installation ID'));
    expect(
      deletion,
      contains('marked to expire 35 days after the last update'),
    );
    expect(
      deletion,
      contains('Firestore deletes expired documents asynchronously afterward'),
    );
    expect(privacy, isNot(contains('up to 35 days')));
    expect(deletion, isNot(contains('up to 35 days')));
  });

  test('place search review hard cost stops precede monitor deployment', () {
    final functions = _source(
      'functions/README.md',
    ).replaceAll(RegExp(r'\s+'), ' ');
    final checklist = _source(
      'RELEASE-CHECKLIST.md',
    ).replaceAll(RegExp(r'\s+'), ' ');

    for (final document in [functions, checklist]) {
      final quota = document.indexOf('provider quota caps');
      final budget = document.indexOf('budget alerts');
      final ttl = document.indexOf('Firestore TTL');
      final roomRules = document.indexOf('owner-only room cleanup rules');
      final deploy = document.indexOf('monitor-mode deploy');
      expect(quota, greaterThanOrEqualTo(0));
      expect(budget, greaterThan(quota));
      expect(ttl, greaterThan(budget));
      expect(roomRules, greaterThan(ttl));
      expect(deploy, greaterThan(roomRules));
    }
    expect(functions, contains('hard upstream stop'));
    expect(functions, contains('budget alerts warn but do not cap spending'));
    expect(functions, contains('roomDeletionLocks'));
    expect(functions, contains('serviceIdentityDeletionTombstones'));
    expect(functions, contains('beginServiceIdentityDeletion'));
    expect(functions, contains('all three callables'));
    expect(functions, contains('storage.rules'));
    expect(checklist, contains('owner UID with a limit of 100'));
    expect(checklist, contains('serviceIdentityDeletionTombstones'));
    expect(checklist, contains('beginServiceIdentityDeletion'));
    expect(checklist, contains('all three callables'));
    expect(checklist, contains('storage.rules'));
  });

  test('visitor publication capabilities are compile-time and default closed', () {
    final feature = _source('lib/release_features.dart');
    final cloud = _source('lib/cloud.dart');
    final plist = _source('ios/Runner/Info.plist');

    expect(feature, contains("'VISITOR_PHOTO_SHARING'"));
    expect(feature, contains("'VISITOR_PROFILE_SHARING'"));
    expect(kVisitorPhotoSharingEnabled, isFalse);
    expect(
      kVisitorProfileSharingEnabled,
      const bool.fromEnvironment(
        'VISITOR_PROFILE_SHARING',
        defaultValue: false,
      ),
    );
    expect(
      feature,
      contains(
        "'VISITOR_PROFILE_SHARING',\n"
        '  defaultValue: false,',
      ),
    );
    expect(kAnonymousServiceIdentityRemovalEnabled, isFalse);
    expect(
      RegExp(
        r'kAnonymousServiceIdentityRemovalEnabled\s*=\s*'
        r'kPlaceSearchEnabled\s*&&\s*!kIsWeb',
      ).hasMatch(feature),
      isTrue,
      reason:
          'web must not expose the destructive CloudSync capability even in an opt-in place-search build',
    );
    expect(
      RegExp(
        r'Future<String\?> deleteAnonymousServiceIdentity\('
        r'[\s\S]*?if \(!kAnonymousServiceIdentityRemovalEnabled\)',
      ).hasMatch(cloud),
      isTrue,
      reason:
          'CloudSync must reject the destructive call at its own public boundary',
    );
    expect(feature, contains('timely human moderation'));
    expect(
      plist,
      contains(
        'Room photos stay on this device unless you explicitly choose to upload one to your shared room;',
      ),
    );
    expect(
      plist,
      contains('removing it from sharing keeps your private device copy.'),
    );
    expect(plist, isNot(contains('They stay on this device.')));
    expect(plist, isNot(contains('shared space')));
  });

  testWidgets(
    'default release uses the disabled service without constructing Firebase callables',
    (tester) async {
      const factory = ProductionDaybookPlaceSearchFactory();
      expect(kPlaceSearchEnabled, isFalse);
      expect(factory.enabled, isFalse);

      final authorization = PlaceSearchAuthorization();
      final lease = await authorization.authorize(
        attempt: authorization.beginConsentAttempt(),
        persistConsent: () async => true,
      );
      expect(lease, isNotNull);

      final controller = factory.createController(
        installId: '5e7628f4-d16e-4f8d-a419-9da78655e54a',
        locale: 'en-US',
        authorization: lease!,
      );
      addTearDown(controller.dispose);
      controller.updateQuery('Alexander Library');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(controller.state.suggestions, isEmpty);
      expect(controller.state.isLoading, isFalse);
      expect(controller.state.errorMessage, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'default-disabled event task and class editors keep manual location entry available',
    (tester) async {
      final flows = <({Widget editor, Key locationKey, String value})>[
        (
          editor: DaybookEventEditor(
            selectedDay: CivilDate(2026, 8, 18),
            onSave: (_) async => true,
          ),
          locationKey: const ValueKey('daybook-event-place-saved-name'),
          value: 'Event room',
        ),
        (
          editor: DaybookTaskEditor(
            selectedDay: CivilDate(2026, 8, 18),
            onSave: (_) async => true,
          ),
          locationKey: const ValueKey('daybook-task-place-saved-name'),
          value: 'Task room',
        ),
        (
          editor: AddAcademicMeetingDialog(
            schedule: AcademicSchedule.empty(),
            selectedDay: DateTime(2026, 8, 18),
            onSave: (_, _, _) async => true,
          ),
          locationKey: const ValueKey('academic-saved-name'),
          value: 'Class room',
        ),
      ];

      for (final flow in flows) {
        await _pumpReleaseLocationFlow(tester, flow.editor);
        final location = find.byKey(flow.locationKey);
        expect(location, findsOneWidget);
        expect(tester.widget<TextField>(location).enabled, isNot(false));
        expect(find.text('SEARCH PLACES WITH GOOGLE'), findsNothing);

        await tester.enterText(location, flow.value);
        expect(tester.widget<TextField>(location).controller!.text, flow.value);
        expect(tester.takeException(), isNull);
      }
    },
  );

  test('canonical policy and support routes are clean and deployable', () {
    final hosting = _source('firebase.json');
    final links = _source('lib/content/links.dart');
    final support = _source('web/support.html');
    final community = _source(
      'web/community.html',
    ).replaceAll(RegExp(r'\s+'), ' ');
    final deletion = _source('web/delete-account.html');
    final recovery = _source(
      'ACCOUNT-RECOVERY-RUNBOOK.md',
    ).replaceAll(RegExp(r'\s+'), ' ');

    expect(hosting, contains('"cleanUrls": true'));
    expect(links, contains("defaultValue: 'https://roomofdays.com'"));
    expect(links, contains("'\$_base/privacy'"));
    expect(links, contains("'\$_base/community'"));
    expect(links, contains("'\$_base/terms'"));
    expect(links, contains("'\$_base/delete-account'"));
    expect(links, contains("'\$_base/support'"));
    expect(support, contains('support@roomofdays.com'));
    expect(support, contains('https://roomofdays.com/support'));
    expect(community, contains('https://roomofdays.com/community'));
    expect(community, contains('reviews the report queue every day'));
    expect(community, contains('within 24 hours'));
    expect(community, contains('current and future public rooms'));
    expect(community, contains('support@roomofdays.com'));
    expect(
      deletion,
      contains(
        'mailto:support@roomofdays.com?subject=Room%20of%20Days%20account%20deletion%20request',
      ),
    );
    expect(deletion, contains('Request deletion without the app'));
    expect(deletion, contains('within seven days of verification'));
    expect(recovery, contains('Never ask for or accept a'));
    expect(recovery, contains('verified custom Auth email domain'));
    expect(recovery, contains('None may expose Emberkeep'));
    expect(recovery, contains('the old password fails'));
    expect(recovery, contains("account's cloud save is preserved"));
  });

  test('physical acceptance runbook is bound to the release candidates', () {
    final runbook = _source(
      'DEVICE-ACCEPTANCE-RUNBOOK.md',
    ).replaceAll(RegExp(r'\s+'), ' ');

    for (final expected in const [
      'room-of-days-1.0.0+12-android.apk',
      '9C8C924E4C98CEC35175C03508EF5E757940CA8FD9C18627DCE6E4634B4A1B12',
      'ee091db079a54c982946aa6ab7e7b61546b3354f',
      'room-of-days-1.0.4-build-40-internal-candidate',
      'Codemagic `ios-testflight` workflow',
      'Team ID `D63Z4RBRT8`',
      'private content in a visitor room',
      'Low Power/Battery Saver',
      'VoiceOver/TalkBack',
      'Android Settings Force stop deliberately suppresses alarms',
      'BYDAY=MO,WE,FR',
      'small Day Ledger widget',
      'Focus track on the phone speaker and headphones',
      '| Final decision | **PASS / FAIL** |',
    ]) {
      expect(runbook, contains(expected));
    }
  });

  test('native app-link runtime keeps room URLs scoped and queue-backed', () {
    final app = _source('lib/main.dart');
    final social = _source('lib/social.dart');
    final shell = _source('lib/screens/shell.dart');
    final manifest = _source('android/app/src/main/AndroidManifest.xml');
    final entitlements = _source('ios/Runner/Runner.entitlements');
    final association = _source(
      'web/.well-known/apple-app-site-association',
    ).replaceAll(RegExp(r'\s+'), ' ');

    expect(social, contains("'space',\n          clean"));
    expect(social, contains('class RoomLinkInbox extends ChangeNotifier'));
    expect(app, contains('didPushRouteInformation'));
    expect(app, contains('initialRoute: Navigator.defaultRouteName'));
    expect(shell, contains('_drainPendingRoomLinks'));
    expect(manifest, contains('android:host="roomofdays.com"'));
    expect(manifest, contains('android:path="/space"'));
    expect(manifest, contains('android:pathPrefix="/space/"'));
    expect(manifest, contains('android:path="/room"'));
    expect(manifest, contains('android:pathPrefix="/room/"'));
    expect(manifest, isNot(contains('android:pathPrefix="/space"')));
    expect(manifest, isNot(contains('android:pathPrefix="/room"')));
    expect(entitlements, contains('applinks:roomofdays.com'));
    expect(
      entitlements,
      contains('com.apple.developer.devicecheck.appattest-environment'),
    );
    expect(entitlements, contains('<string>production</string>'));
    expect(manifest, isNot(contains('www.roomofdays.com')));
    expect(entitlements, isNot(contains('www.roomofdays.com')));
    expect(association, contains('{ "/": "/space",'));
    expect(association, contains('{ "/": "/space/*",'));
    expect(association, contains('{ "/": "/room",'));
    expect(association, contains('{ "/": "/room/*",'));
    expect(association, contains('D63Z4RBRT8.com.mikabe.emberkeep'));
  });

  test('iOS release path provisions fallback plugins and foreground reminders', () {
    final workflow = _source('codemagic.yaml');
    final appDelegate = _source('ios/Runner/AppDelegate.swift');
    final privacyManifest = _source('ios/Runner/PrivacyInfo.xcprivacy');
    final podfile = _source('ios/Podfile');
    final debugConfig = _source('ios/Flutter/Debug.xcconfig');
    final releaseConfig = _source('ios/Flutter/Release.xcconfig');

    expect(workflow, contains('flutter: 3.44.2'));
    expect(workflow, contains('xcode: 26.4'));
    expect(workflow, contains('cocoapods: 1.16.2'));
    expect(workflow, contains('APPLE_TEAM_ID: "D63Z4RBRT8"'));
    expect(workflow, contains('routine source/docs pushes remain inert'));
    expect(
      workflow,
      contains('room-of-days-1.0.4-build-40-internal-candidate'),
    );
    expect(workflow, contains('CM_CLONE_DEPTH: "2"'));
    expect(workflow, contains('Hydrate and verify immutable receipt identity'));
    expect(
      workflow,
      contains(r'git fetch --no-tags --depth=2 origin "$CM_COMMIT"'),
    );
    expect(
      workflow,
      contains('Confirm Flutter packages left the receipt checkout clean'),
    );
    expect(workflow, contains('Run the complete app regression suite'));
    expect(workflow, contains('beta_groups:\n          - Me'));
    expect(
      workflow,
      contains('Run the feature-on friends and discovery packet'),
    );
    expect(workflow, contains('Verify the internal TestFlight candidate'));
    expect(workflow, contains('verify_internal_testflight_candidate.dart'));
    expect(
      workflow,
      contains(
        'release-evidence/internal-testflight/1.0.4+40/CANDIDATE-MANIFEST.json',
      ),
    );
    expect(
      workflow,
      contains('Confirm validation left tracked sources unchanged'),
    );
    expect(
      workflow.indexOf('Verify the internal TestFlight candidate'),
      lessThan(workflow.indexOf('Analyze Dart')),
    );
    expect(
      workflow.indexOf('Run the feature-on friends and discovery packet'),
      lessThan(
        workflow.indexOf('Confirm validation left tracked sources unchanged'),
      ),
    );
    expect(
      RegExp(
        r'dart run tool/verify_internal_testflight_candidate\.dart',
      ).allMatches(workflow),
      hasLength(2),
    );
    expect(
      workflow,
      isNot(contains('dart run tool/verify_store_submission.dart --ios-only')),
    );
    expect(podfile, contains("platform :ios, '15.0'"));
    expect(podfile, contains('flutter_ios_podfile_setup'));
    expect(podfile, contains('flutter_install_all_ios_pods'));
    expect(podfile, contains('use_frameworks!'));
    expect(
      debugConfig,
      startsWith(
        '#include? "Pods/Target Support Files/Pods-Runner/Pods-Runner.debug.xcconfig"',
      ),
    );
    expect(
      releaseConfig,
      startsWith(
        '#include? "Pods/Target Support Files/Pods-Runner/Pods-Runner.release.xcconfig"',
      ),
    );
    expect(workflow, isNot(contains('room-of-days-1.0.4-build-35-candidate')));
    expect(workflow, isNot(contains('PURE SPM')));
    expect(workflow, contains('Verify signed IPA contents'));
    expect(workflow, contains('WIDGET_BUNDLE_ID'));
    expect(workflow, contains('com.mikabe.emberkeep.DayLedgerWidget'));
    expect(workflow, contains('APP_GROUP_ID'));
    expect(workflow, contains('group.com.mikabe.emberkeep'));
    expect(workflow, contains('--strict-match-identifier'));
    expect(
      RegExp(
        r'app-store-connect fetch-signing-files "\$IDENTIFIER"',
      ).allMatches(workflow),
      hasLength(1),
    );
    expect(workflow, contains(r'"$BUNDLE_ID" "$WIDGET_BUNDLE_ID"'));
    expect(workflow, contains('APP_GROUPS'));
    expect(workflow, contains('RoomOfDaysWidgets.appex'));
    expect(workflow, contains('widget-entitlements.plist'));
    expect(workflow, contains('widget-profile.plist'));
    expect(workflow, contains(r'widget_bundle_id=$WIDGET_BUNDLE_ID'));
    expect(workflow, contains(r'app_group_id=$APP_GROUP_ID'));
    expect(workflow, contains('PUBSPEC_BUILD'));
    expect(workflow, contains('PUBSPEC_VERSION'));
    expect(workflow, contains('Keep the checked-in version+build exact.'));
    expect(workflow, isNot(matches(RegExp(r'Build \d+ for \d+\.\d+\.\d+'))));
    expect(workflow, contains(r'NEXT_BUILD=$PUBSPEC_BUILD'));
    expect(workflow, contains(r'if [ "$LATEST" -ge "$PUBSPEC_BUILD" ]; then'));
    expect(workflow, contains('bump pubspec before starting another run'));
    expect(workflow, isNot(contains(r'NEXT_BUILD=$((LATEST + 1))')));
    expect(workflow, contains(r'--build-name="$PUBSPEC_VERSION"'));
    expect(workflow, contains(r'marketing_version=$MARKETING_VERSION'));
    expect(workflow, isNot(contains('marketing_version=1.0.2')));
    expect(workflow, contains(r'test "$BUILD_NUMBER" = "$PUBSPEC_BUILD"'));
    expect(workflow, isNot(contains('2>/dev/null || echo 0')));
    expect(workflow, contains('codesign --verify --deep --strict'));
    expect(workflow, contains('PrivacyInfo.xcprivacy'));
    for (final dataType in const [
      'NSPrivacyCollectedDataTypeName',
      'NSPrivacyCollectedDataTypeEmailAddress',
      'NSPrivacyCollectedDataTypeUserID',
      'NSPrivacyCollectedDataTypeGameplayContent',
      'NSPrivacyCollectedDataTypeHealth',
      'NSPrivacyCollectedDataTypeFitness',
      'NSPrivacyCollectedDataTypeOtherUserContent',
    ]) {
      expect(workflow, contains(dataType));
    }
    expect(workflow, contains("Print :ITSAppUsesNonExemptEncryption"));
    expect(workflow, contains("Print :DTSDKName"));
    expect(workflow, contains('iphoneos26'));
    expect(workflow, contains('embedded.mobileprovision'));
    expect(workflow, contains(r'$APPLE_TEAM_ID.$BUNDLE_ID'));
    expect(
      workflow,
      contains('com.apple.developer.devicecheck.appattest-environment'),
    );
    expect(
      RegExp(
        r"grep -Eq '\(\^\|\[\[:space:\]\]\)production",
      ).allMatches(workflow).length,
      greaterThanOrEqualTo(2),
    );
    expect(workflow, contains('app_attest_environment=production'));
    expect(workflow, contains('release-evidence.txt'));
    expect(workflow, contains('Runner.xcarchive/dSYMs/*.dSYM'));
    final runnerEntitlements = _source('ios/Runner/Runner.entitlements');
    final widgetEntitlements = _source(
      'ios/RoomOfDaysWidgets/RoomOfDaysWidgets.entitlements',
    );
    final widgetInfo = _source('ios/RoomOfDaysWidgets/Info.plist');
    final project = _source('ios/Runner.xcodeproj/project.pbxproj');
    expect(runnerEntitlements, contains('group.com.mikabe.emberkeep'));
    expect(widgetEntitlements, contains('group.com.mikabe.emberkeep'));
    expect(widgetInfo, contains(r'$(PRODUCT_BUNDLE_IDENTIFIER)'));
    expect(widgetInfo, contains(r'$(MARKETING_VERSION)'));
    expect(widgetInfo, contains(r'$(CURRENT_PROJECT_VERSION)'));
    expect(widgetInfo, contains('com.apple.widgetkit-extension'));
    expect(
      RegExp(
        r'PRODUCT_BUNDLE_IDENTIFIER = com\.mikabe\.emberkeep\.DayLedgerWidget;',
      ).allMatches(project),
      hasLength(3),
    );
    expect(project, isNot(contains('TARGETED_DEVICE_FAMILY = "1,2";')));
    expect(appDelegate, contains('import UserNotifications'));
    expect(
      appDelegate,
      contains('UNUserNotificationCenter.current().delegate'),
    );
    expect(
      privacyManifest,
      contains('NSPrivacyCollectedDataTypeOtherUserContent'),
    );
    expect(privacyManifest, contains('NSPrivacyCollectedDataTypeHealth'));
    expect(privacyManifest, contains('NSPrivacyCollectedDataTypeFitness'));
  });

  test(
    'account deletion exits cloud and reset durably orders local erasure',
    () {
      final cloud = _source('lib/cloud.dart');
      final shell = _source('lib/screens/shell.dart');

      final deleteStart = cloud.indexOf(
        'Future<String?> _deleteAccount(String password',
      );
      final deleteEnd = cloud.indexOf(
        'static String _friendlyAuth',
        deleteStart,
      );
      expect(deleteStart, greaterThanOrEqualTo(0));
      expect(deleteEnd, greaterThan(deleteStart));
      final deletion = cloud.substring(deleteStart, deleteEnd);
      expect(deletion, contains('setBool(_cloudEnabledKey, false)'));
      expect(deletion, contains('_uid = null'));
      expect(deletion, contains('optedIn = false'));
      expect(deletion, contains('ready = false'));
      expect(deletion, isNot(contains('signInAnonymously')));

      final resetStart = shell.indexOf('Future<String?> _reset() async');
      final resetEnd = shell.indexOf(
        'Future<bool> _finishResetRemoteCleanup',
        resetStart,
      );
      expect(resetStart, greaterThanOrEqualTo(0));
      expect(resetEnd, greaterThan(resetStart));
      final reset = shell.substring(resetStart, resetEnd);
      expect(reset, contains('RoomPhotoStore.instance.clearAll()'));
      expect(reset, contains('Storage.clearUsage()'));
      expect(reset, contains('Storage.clearCorruptBackup()'));
      expect(reset, contains('_saveTail = _saveTail.then'));
      expect(reset, contains('if (!await _saveTail)'));
      expect(
        reset.indexOf('if (!await _finishResetRemoteCleanup(oldRoomCode))'),
        lessThan(reset.indexOf('RoomPhotoStore.instance.clearAll()')),
      );
      expect(reset, isNot(contains('unawaited(_finishResetRemoteCleanup')));
    },
  );

  test('Android release manifest permits the shipped cloud experience', () {
    final manifest = _source('android/app/src/main/AndroidManifest.xml');
    final gradle = _source('android/app/build.gradle.kts');
    final pubspec = _source('pubspec.yaml');

    expect(manifest, contains('android.permission.INTERNET'));
    expect(manifest, contains('android.permission.POST_NOTIFICATIONS'));
    expect(gradle, contains('compileSdk = 36'));
    expect(gradle, contains('minSdk = 24'));
    expect(gradle, contains('targetSdk = 36'));
    expect(gradle, contains('ndkVersion = "28.2.13676358"'));
    expect(pubspec, contains('version: 1.0.4+40'));
    expect(pubspec, contains('enable-swift-package-manager: true'));
  });

  test(
    'release candidate and Android association inputs are machine-readable',
    () {
      final candidate = jsonDecode(_source('release-candidate.json')) as Map;
      final aab = candidate['aab'] as Map;
      final apk = candidate['apk'] as Map;

      expect(candidate['schema'], 1);
      expect(candidate['packageId'], 'com.mikabe.emberkeep');
      expect(candidate['versionName'], '1.0.2');
      expect(candidate['versionCode'], 20);
      expect(candidate['minSdk'], 24);
      expect(candidate['targetSdk'], 36);
      expect(candidate['ndkVersion'], '28.2.13676358');
      expect(candidate['nativeLoadAlignment'], 16384);
      expect(candidate['nativeLibraryCount'], 12);
      expect(aab['size'], 77026849);
      expect(apk['size'], 79306323);
      expect((aab['sha256'] as String), hasLength(64));
      expect((apk['sha256'] as String), hasLength(64));
      final sourceCommit = candidate['sourceCommit'] as String;
      expect(sourceCommit, matches(RegExp(r'^[0-9a-f]{40}$')));
      expect(sourceCommit, isNot('0000000000000000000000000000000000000000'));

      final assetLinks =
          jsonDecode(_source('web/.well-known/assetlinks.json')) as List;
      for (final entry in assetLinks.cast<Map>()) {
        expect(
          entry['relation'],
          contains('delegate_permission/common.handle_all_urls'),
        );
        final target = entry['target'] as Map;
        expect(target['namespace'], 'android_app');
        expect(target['package_name'], 'com.mikabe.emberkeep');
        expect(target['sha256_cert_fingerprints'], isNotEmpty);
      }

      final hosting = _source('firebase.json');
      expect(hosting, contains('/.well-known/assetlinks.json'));
      expect(hosting, contains('application/json'));
      expect(
        _source('tool/verify_android_candidate.dart'),
        contains('PAGE_ALIGNMENT_16K'),
      );
      expect(
        _source('tool/verify_store_submission.dart'),
        contains('store submission packet is internally consistent'),
      );
    },
  );
}

Future<void> _pumpReleaseLocationFlow(
  WidgetTester tester,
  Widget editor,
) async {
  await tester.binding.setSurfaceSize(const Size(430, 932));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(body: editor),
    ),
  );
  await tester.pump();
}
