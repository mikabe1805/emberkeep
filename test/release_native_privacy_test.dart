import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _source(String path) {
  final file = File(path);
  expect(file.existsSync(), isTrue, reason: 'Missing release source: $path');
  return file.readAsStringSync();
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

  test('public privacy copy promises generated-room sharing only', () {
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
      expect(workflow, isNot(contains('PURE SPM')));
      expect(workflow, contains('Verify signed IPA contents'));
      expect(workflow, contains('codesign --verify --deep --strict'));
      expect(workflow, contains('PrivacyInfo.xcprivacy'));
      expect(appDelegate, contains('import UserNotifications'));
      expect(
        appDelegate,
        contains('UNUserNotificationCenter.current().delegate'),
      );
      expect(
        privacyManifest,
        contains('NSPrivacyCollectedDataTypeOtherUserContent'),
      );
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
    expect(pubspec, contains('version: 1.0.0+10'));
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
      expect(candidate['versionName'], '1.0.0');
      expect(candidate['versionCode'], 10);
      expect(candidate['minSdk'], 24);
      expect(candidate['targetSdk'], 36);
      expect(candidate['ndkVersion'], '28.2.13676358');
      expect(candidate['nativeLoadAlignment'], 16384);
      expect(candidate['nativeLibraryCount'], 12);
      expect((aab['sha256'] as String), hasLength(64));
      expect((apk['sha256'] as String), hasLength(64));
      expect((candidate['sourceCommit'] as String), hasLength(40));

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
