import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _source(String path) {
  final file = File(path);
  expect(file.existsSync(), isTrue, reason: 'Missing release source: $path');
  return file.readAsStringSync();
}

void main() {
  test('public privacy copy tells the truth about opt-in visitor profiles', () {
    final privacy = _source('web/privacy.html');
    final compact = privacy.replaceAll(RegExp(r'\s+'), ' ');

    expect(compact, contains('private by default'));
    expect(compact, contains('Show this page to visitors'));
    expect(compact, contains('display name, short introduction'));
    expect(compact, contains('up to three goals'));
    expect(compact, contains('journal entries or photos'));
    expect(compact, contains('does not turn on full-save backup'));
    expect(
      privacy,
      isNot(contains('chosen name and other free-form text are not published')),
    );
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
    },
  );
}
