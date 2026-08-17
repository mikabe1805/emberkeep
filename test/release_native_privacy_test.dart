import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

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
    expect(
      audio,
      contains('kIsWeb && !browserAudioAvailable'),
      reason: 'web taps must stay silent when a browser has no Web Audio',
    );
    expect(webAudioSupport, contains("'AudioContext'.toJS"));
    expect(hostingConfig['predeploy'], [
      'node tool/verify_public_downloads.mjs',
      'flutter build web --release --wasm',
      'dart run tool/prepare_web_offline.dart',
      'node tool/overlay_introduction.mjs',
    ]);
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

  test('public privacy copy covers v1 sharing and collection boundaries', () {
    final privacy = _source('web/privacy.html');
    final compact = privacy.replaceAll(RegExp(r'\s+'), ' ');

    expect(compact, contains('first store release does not publish'));
    expect(compact, contains('display name'));
    expect(compact, contains('profile cards'));
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
  });

  test('v1 visitor UGC capabilities are compile-time and default off', () {
    final feature = _source('lib/release_features.dart');
    final plist = _source('ios/Runner/Info.plist');

    expect(feature, contains("'VISITOR_PHOTO_SHARING'"));
    expect(feature, contains("'VISITOR_PROFILE_SHARING'"));
    expect(RegExp(r'defaultValue:\s*false').allMatches(feature), hasLength(2));
    expect(feature, contains('timely human moderation'));
    expect(feature, contains('defaultValue: false'));
    expect(plist, contains('They stay on this device.'));
    expect(plist, isNot(contains('shared space')));
  });

  test('canonical policy and support routes are clean and deployable', () {
    final hosting = _source('firebase.json');
    final links = _source('lib/content/links.dart');
    final support = _source('web/support.html');
    final deletion = _source('web/delete-account.html');
    final recovery = _source(
      'ACCOUNT-RECOVERY-RUNBOOK.md',
    ).replaceAll(RegExp(r'\s+'), ' ');

    expect(hosting, contains('"cleanUrls": true'));
    expect(links, contains("defaultValue: 'https://roomofdays.com'"));
    expect(links, contains("'\$_base/privacy'"));
    expect(links, contains("'\$_base/delete-account'"));
    expect(links, contains("'\$_base/support'"));
    expect(support, contains('support@roomofdays.com'));
    expect(support, contains('https://roomofdays.com/support'));
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
      'manual Codemagic `ios-testflight` workflow',
      'Team ID `D63Z4RBRT8`',
      'private content in a visitor room',
      'Low Power/Battery Saver',
      'VoiceOver/TalkBack',
      'Android Settings Force stop deliberately suppresses alarms',
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
    expect(manifest, isNot(contains('www.roomofdays.com')));
    expect(entitlements, isNot(contains('www.roomofdays.com')));
    expect(association, contains('{ "/": "/space",'));
    expect(association, contains('{ "/": "/space/*",'));
    expect(association, contains('{ "/": "/room",'));
    expect(association, contains('{ "/": "/room/*",'));
    expect(association, contains('D63Z4RBRT8.com.mikabe.emberkeep'));
  });

  test(
    'iOS release path provisions fallback plugins and foreground reminders',
    () {
      final workflow = _source('codemagic.yaml');
      final appDelegate = _source('ios/Runner/AppDelegate.swift');
      final privacyManifest = _source('ios/Runner/PrivacyInfo.xcprivacy');

      expect(workflow, contains('flutter: 3.44.2'));
      expect(workflow, contains('xcode: 26.4'));
      expect(workflow, contains('cocoapods: 1.16.2'));
      expect(workflow, contains('APPLE_TEAM_ID: "D63Z4RBRT8"'));
      expect(workflow, contains('TRIGGERING: intentionally manual'));
      expect(workflow, isNot(contains('PURE SPM')));
      expect(workflow, contains('Verify signed IPA contents'));
      expect(workflow, contains('PUBSPEC_BUILD'));
      expect(workflow, contains('Build 20 for 1.0.2'));
      expect(workflow, contains(r'NEXT_BUILD=$PUBSPEC_BUILD'));
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
      expect(workflow, contains('release-evidence.txt'));
      expect(workflow, contains('Runner.xcarchive/dSYMs/*.dSYM'));
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
    },
  );

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
        'Future<void> _finishResetRemoteCleanup',
        resetStart,
      );
      expect(resetStart, greaterThanOrEqualTo(0));
      expect(resetEnd, greaterThan(resetStart));
      final reset = shell.substring(resetStart, resetEnd);
      expect(reset, contains('if (!await media.clearAll())'));
      expect(reset, contains('Storage.clearUsage()'));
      expect(reset, contains('Storage.clearCorruptBackup()'));
      expect(reset, contains('_saveTail = _saveTail.then'));
      expect(reset, contains('if (!await _saveTail)'));
      expect(
        reset.indexOf('if (!await _saveTail)'),
        lessThan(reset.indexOf('_finishResetRemoteCleanup(oldRoomCode)')),
      );
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
    expect(pubspec, contains('version: 1.0.2+20'));
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
