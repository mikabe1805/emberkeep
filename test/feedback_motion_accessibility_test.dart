import 'package:emberkeep/audio.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/screens/hearth_circle.dart';
import 'package:emberkeep/widgets/ember_sheet.dart';
import 'package:emberkeep/widgets/luxe_depth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    Sfx.instance.soundEnabled = false;
  });

  tearDown(() {
    Sfx.instance.soundEnabled = true;
    Clock.reset();
  });

  group('calmMotionTarget', () {
    test('parks radial hand jitter without favoring an axis', () {
      const jitter = <Offset>[
        Offset(0.119, 0),
        Offset(-0.119, 0),
        Offset(0, 0.119),
        Offset(0, -0.119),
        Offset(0.08, 0.08),
        Offset(-0.08, 0.08),
        Offset(0.08, -0.08),
        Offset(-0.08, -0.08),
      ];

      for (final reading in jitter) {
        expect(
          calmMotionTarget(reading),
          Offset.zero,
          reason: '$reading is ordinary hold jitter, not an intentional tilt',
        );
      }
    });

    test('eases intentional tilt monotonically and preserves direction', () {
      const direction = Offset(0.6, -0.8);
      final outputs = <Offset>[
        for (final magnitude in const [0.13, 0.25, 0.5, 0.8, 1.0])
          calmMotionTarget(direction * magnitude),
      ];

      for (var i = 1; i < outputs.length; i++) {
        expect(outputs[i].distance, greaterThan(outputs[i - 1].distance));
      }
      for (final output in outputs) {
        expect(output.dx / output.distance, closeTo(direction.dx, 0.000001));
        expect(output.dy / output.distance, closeTo(direction.dy, 0.000001));
      }

      final positive = calmMotionTarget(const Offset(0.6, -0.8));
      final negative = calmMotionTarget(const Offset(-0.6, 0.8));
      expect(negative.dx, closeTo(-positive.dx, 0.000001));
      expect(negative.dy, closeTo(-positive.dy, 0.000001));
      expect(
        calmMotionTarget(const Offset(2.4, 0)).distance,
        closeTo(1, 0.000001),
        reason: 'extreme sensor readings must remain inside authored travel',
      );
    });
  });

  testWidgets('Ember sheet keeps effort choices readable at 320x568 and 1.5x', (
    tester,
  ) async {
    await _useCompactLargeTextViewport(tester);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                key: const ValueKey('open-ember-sheet'),
                onPressed: () {
                  showEmberSheet(
                    context,
                    const EmberSheetConfig(defaultTitle: 'Call Mom'),
                  );
                },
                child: const Text('New quest'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('open-ember-sheet')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(
      tester.takeException(),
      isNull,
      reason: 'collapsed sheet overflowed',
    );
    await tester.tap(find.text('More'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(tester.takeException(), isNull, reason: 'expanded sheet overflowed');

    final effortFinder = find.text('A real effort');
    expect(effortFinder, findsOneWidget);
    await tester.ensureVisible(effortFinder);
    await tester.pump();

    final effort = tester.widget<Text>(effortFinder);
    expect(effort.maxLines, anyOf(isNull, greaterThanOrEqualTo(2)));
    expect(effort.overflow, isNot(TextOverflow.ellipsis));
    _expectInsidePhone(tester, effortFinder);
    _expectInsidePhone(tester, find.text('Small'));
    _expectInsidePhone(tester, find.text('A big push'));
    expect(find.text('Check at day’s end'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'scrolled sheet overflowed');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('Circle stacks dense cards at 320x568 and 1.5x', (tester) async {
    await _useCompactLargeTextViewport(tester);
    Clock.freeze(DateTime(2026, 8, 2, 14));
    final state = GameState()..reduceMotion = true;
    state.addCircleCode('DEF567');
    state.startQuietCompany('study', const Duration(minutes: 25));

    await tester.pumpWidget(
      MaterialApp(
        home: HearthCircleScreen(state: state, onPersist: () {}),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('The Circle Lantern'), findsOneWidget);
    _expectInsidePhone(tester, find.text('The Circle Lantern'));
    expect(tester.takeException(), isNull, reason: 'Circle header overflowed');
    await tester.scrollUntilVisible(
      find.textContaining('STUDY'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    expect(find.textContaining('STUDY'), findsOneWidget);
    expect(find.text('END'), findsOneWidget);
    _expectInsidePhone(tester, find.textContaining('STUDY'));
    _expectInsidePhone(tester, find.text('END'));
    expect(
      tester.getSize(find.text('END')).height,
      lessThanOrEqualTo(44),
      reason: 'the label should fit inside its 44px minimum action target',
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}

Future<void> _useCompactLargeTextViewport(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  await tester.binding.setSurfaceSize(const Size(320, 568));
  tester.platformDispatcher.textScaleFactorTestValue = 1.5;
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.binding.setSurfaceSize(null);
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
}

void _expectInsidePhone(WidgetTester tester, Finder finder) {
  final rect = tester.getRect(finder);
  expect(rect.left, greaterThanOrEqualTo(0));
  expect(rect.right, lessThanOrEqualTo(320));
}
