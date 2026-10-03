// Self-check for class_day_harness.dart (skipped unless CLASS_DAY_RENDERS):
// the copied theme still matches the live app, a concept study renders at
// phone size, and grab writes a 1179 x 2556 PNG. Writes only to the system
// temp folder.
//
//   flutter test --dart-define=CLASS_DAY_RENDERS=true \
//     test/design_renders/class_day_harness_check_test.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:emberkeep/tokens.dart';
import 'package:emberkeep/widgets/glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'class_day_harness.dart';

const _renders = bool.fromEnvironment('CLASS_DAY_RENDERS');

(int, int) _pngSize(File file) {
  final bytes = file.readAsBytesSync();
  final data = ByteData.sublistView(bytes);
  return (data.getUint32(16), data.getUint32(20));
}

void main() {
  setUpAll(setUpRoomRenders);
  tearDownAll(tearDownRoomRenders);

  roomRenderTest('harness: live theme, study, grab', skip: !_renders, (
    tester,
  ) async {
    final at = DateTime(2026, 10, 6, 15, 35);
    final account = mikaAccount(renderAt: at);
    await bootRoom(tester, account, schedule: mikaSchedule());
    expect(debugCheckRoomTheme(tester), isTrue);
    expect(liveState(tester).level, 18);
    expect(find.byKey(const ValueKey('quest-board-scroll')), findsOneWidget);

    await pumpPhoneStudy(
      tester,
      Scaffold(
        backgroundColor: Palette.parchment,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: GlassPanel(
              child: Text(
                'Study frame',
                style: Type.display.copyWith(fontSize: 28),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Study frame'), findsOneWidget);
    final file = await grab(
      tester,
      '${Directory.systemTemp.path}/class_day_harness_check.png',
    );
    expect(_pngSize(file), (1179, 2556));
    file.deleteSync();
  });
}
