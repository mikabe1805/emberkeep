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

    expect(hosting, contains('"cleanUrls": true'));
    expect(links, contains("defaultValue: 'https://roomofdays.com'"));
    expect(links, contains("'\$_base/privacy'"));
    expect(links, contains("'\$_base/delete-account'"));
    expect(links, contains("'\$_base/support'"));
    expect(support, contains('support@roomofdays.com'));
    expect(support, contains('https://roomofdays.com/support'));
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

      expect(workflow, contains('cocoapods: default'));
      expect(workflow, isNot(contains('PURE SPM')));
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

  test('Android release manifest permits the shipped cloud experience', () {
    final manifest = _source('android/app/src/main/AndroidManifest.xml');

    expect(manifest, contains('android.permission.INTERNET'));
    expect(manifest, contains('android.permission.POST_NOTIFICATIONS'));
  });
}
