import 'package:emberkeep/audio.dart';
import 'package:emberkeep/widgets/rung_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    Sfx.instance.debugResetForTesting();
    Sfx.instance.debugBypassPlayback = true;
  });

  tearDown(Sfx.instance.debugResetForTesting);

  testWidgets('the selected starting rung stays silent when retapped', (
    tester,
  ) async {
    final cues = <String>[];
    Sfx.instance.debugOnPlay = cues.add;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => pickRung(
                context,
                accent: Colors.amber,
                questTitle: 'Read a chapter',
                ladder: const ['One page', 'One chapter'],
              ),
              child: const Text('Open rungs'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open rungs'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pick-rung-0')));
    await tester.pump();
    expect(cues, isEmpty);

    await tester.tap(find.byKey(const ValueKey('pick-rung-1')));
    await tester.pump();
    expect(cues, ['select']);

    await tester.tap(find.byKey(const ValueKey('pick-rung-1')));
    await tester.pump();
    expect(cues, ['select']);
  });
}
