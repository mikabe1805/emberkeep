import 'package:emberkeep/audio.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/screens/journal_entry.dart';
import 'package:emberkeep/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    Sfx.instance.soundEnabled = false;
  });

  tearDown(() {
    Sfx.instance.soundEnabled = true;
  });

  testWidgets(
    'writing and photo tools stay together on the physical page at large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
      final semantics = tester.ensureSemantics();

      await tester.pumpWidget(
        MaterialApp(
          home: JournalEntryScreen(
            accent: Palette.xp,
            reduceMotion: true,
            trace: const JournalTrace(
              day: '2026-08-03',
              level: 4,
              totalXp: 620,
              todayXp: 41,
              streakDays: 3,
              questTitles: ['Call Mom'],
              statGains: {Stat.soc: 3},
            ),
            commit: (payload, existing, markEdited) => Note(
              at: DateTime(2026, 8, 3),
              text: payload.text,
              rich: payload.rich,
              images: payload.images,
            ),
            onDelete: (_) {},
          ),
        ),
      );
      await tester.pump();

      final page = find.byKey(const ValueKey('journal-writing-page'));
      final photoAction = find.byKey(const ValueKey('journal-photo-action'));
      expect(page, findsOneWidget);
      expect(photoAction, findsOneWidget);

      final pageRect = tester.getRect(page);
      final actionRect = tester.getRect(photoAction);
      expect(pageRect.contains(actionRect.topLeft), isTrue);
      expect(pageRect.contains(actionRect.bottomRight), isTrue);
      expect(actionRect.height, greaterThanOrEqualTo(44));
      expect(
        tester.getSemantics(photoAction).label,
        contains('Photos stay on this device'),
      );

      final field = tester.widget<TextField>(find.byType(TextField).first);
      expect(field.style?.fontFamily, 'EBGaramond');
      expect(field.style?.fontSize, 19);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      semantics.dispose();
    },
  );

  testWidgets('physical-page editor keeps debounce and lifecycle autosave', (
    tester,
  ) async {
    var commits = 0;
    JournalPayload? latest;
    await tester.pumpWidget(
      MaterialApp(
        home: JournalEntryScreen(
          accent: Palette.xp,
          reduceMotion: true,
          commit: (payload, existing, markEdited) {
            commits++;
            latest = payload;
            return Note(
              at: DateTime(2026, 8, 3),
              text: payload.text,
              rich: payload.rich,
              images: payload.images,
            );
          },
          onDelete: (_) {},
        ),
      ),
    );
    await tester.pump();

    final field = find.byType(TextField).first;
    await tester.enterText(field, 'The kitchen felt peaceful after dinner.');
    await tester.pump(const Duration(milliseconds: 649));
    expect(commits, 0);
    await tester.pump(const Duration(milliseconds: 2));
    expect(commits, 1);
    expect(latest?.text, 'The kitchen felt peaceful after dinner.');

    await tester.enterText(
      field,
      'The kitchen felt peaceful after dinner. Mom noticed too.',
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(commits, 2);
    expect(
      latest?.text,
      'The kitchen felt peaceful after dinner. Mom noticed too.',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
