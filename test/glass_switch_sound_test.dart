import 'dart:async';

import 'package:emberkeep/audio.dart';
import 'package:emberkeep/widgets/glass_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    Sfx.instance.debugResetForTesting();
    Sfx.instance.debugBypassPlayback = true;
  });

  tearDown(Sfx.instance.debugResetForTesting);

  testWidgets('a rejected async toggle stays silent and locks reentry', (
    tester,
  ) async {
    final cues = <String>[];
    Sfx.instance.debugOnPlay = cues.add;
    var value = false;
    var calls = 0;
    var verdict = Completer<bool>();

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Center(
            child: GlassSwitch(
              value: value,
              semanticLabel: 'Permission-gated reminders',
              onChangeAccepted: (next) async {
                calls++;
                final accepted = await verdict.future;
                if (accepted) setState(() => value = next);
                return accepted;
              },
            ),
          ),
        ),
      ),
    );

    final toggle = find.byType(GlassSwitch);
    await tester.tap(toggle);
    await tester.pump();
    await tester.tap(toggle);
    await tester.pump();
    expect(calls, 1);
    expect(cues, isEmpty);
    expect(value, isFalse);

    verdict.complete(false);
    await tester.pump();
    await tester.pump();
    expect(cues, isEmpty);
    expect(value, isFalse);

    verdict = Completer<bool>();
    await tester.tap(toggle);
    await tester.pump();
    verdict.complete(true);
    await tester.pump();
    expect(calls, 2);
    expect(value, isTrue);
    expect(cues, ['select']);
  });
}
