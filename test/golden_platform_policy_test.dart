import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/golden_platform_policy.dart';

void main() {
  test('exact visual goldens run only on their canonical Windows renderer', () {
    expect(
      shouldCompareExactGoldens(
        operatingSystem: 'windows',
        explicitlyEnabled: false,
      ),
      isTrue,
    );
    expect(
      shouldCompareExactGoldens(
        operatingSystem: 'macos',
        explicitlyEnabled: false,
      ),
      isFalse,
    );
    expect(
      shouldCompareExactGoldens(
        operatingSystem: 'linux',
        explicitlyEnabled: false,
      ),
      isFalse,
    );
    expect(
      shouldCompareExactGoldens(
        operatingSystem: 'macos',
        explicitlyEnabled: true,
      ),
      isTrue,
    );
  });

  test('noncanonical hosts skip only the wrapped exact comparison', () async {
    var compareCalls = 0;

    await runExactGoldenCheck(
      operatingSystem: 'macos',
      explicitlyEnabled: false,
      updatingGoldens: false,
      compare: () async => compareCalls++,
    );

    expect(compareCalls, 0);
  });

  test(
    'canonical and explicitly enabled hosts run the exact comparison',
    () async {
      var compareCalls = 0;

      await runExactGoldenCheck(
        operatingSystem: 'windows',
        explicitlyEnabled: false,
        updatingGoldens: false,
        compare: () async => compareCalls++,
      );
      await runExactGoldenCheck(
        operatingSystem: 'macos',
        explicitlyEnabled: true,
        updatingGoldens: false,
        compare: () async => compareCalls++,
      );

      expect(compareCalls, 2);
    },
  );

  test('noncanonical hosts cannot rewrite canonical images', () async {
    await expectLater(
      () => runExactGoldenCheck(
        operatingSystem: 'macos',
        explicitlyEnabled: false,
        updatingGoldens: true,
        compare: () async {},
      ),
      throwsA(
        isA<UnsupportedError>().having(
          (error) => error.message,
          'message',
          contains('Windows'),
        ),
      ),
    );
  });

  test(
    'explicit comparison cannot rewrite canonical images elsewhere',
    () async {
      await expectLater(
        () => runExactGoldenCheck(
          operatingSystem: 'macos',
          explicitlyEnabled: true,
          updatingGoldens: true,
          compare: () async {},
        ),
        throwsA(
          isA<UnsupportedError>().having(
            (error) => error.message,
            'message',
            contains('Windows'),
          ),
        ),
      );
    },
  );

  test(
    'Build 35 Goals visual suites route every exact compare through policy',
    () {
      for (final path in const [
        'test/goal_journal_opening_visual_test.dart',
        'test/quest_mastery_visual_test.dart',
      ]) {
        final source = File(path).readAsStringSync();
        final exactComparisons = RegExp(
          'matchesGoldenFile',
        ).allMatches(source).length;
        final policyCalls = RegExp(
          'runExactGoldenCheck',
        ).allMatches(source).length;
        expect(policyCalls, exactComparisons, reason: path);
        expect(source, contains('Platform.operatingSystem'), reason: path);
        expect(source, contains('autoUpdateGoldenFiles'), reason: path);
      }
    },
  );
}
