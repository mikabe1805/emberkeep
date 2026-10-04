// Render study for the Journal hub's prompt chips ("A WAY IN, IF YOU WANT
// ONE"), skipped unless CLASS_DAY_RENDERS. Frames land in
// design/comparisons/2026-10-03/class-day/fixes/journal-chips/ (untracked).
//
//   flutter test --dart-define=CLASS_DAY_RENDERS=true \
//     test/design_renders/journal_prompt_chips_render_test.dart
//
// Pass --dart-define=CHIPS_TAG=before (or after) to label the frames.
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/screens/journal_hub.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'class_day_harness.dart';

const _renders = bool.fromEnvironment('CLASS_DAY_RENDERS');
const _tag = String.fromEnvironment('CHIPS_TAG', defaultValue: 'after');

GameState _state({required bool questToday}) {
  final s = GameState()..level = 18;
  s.lastActiveDay = Days.key(Clock.now());
  if (questToday) s.todayQuestTitles.add('Read ten pages of the lab manual');
  s.setJournal([
    Note(
      at: DateTime(2026, 10, 5, 21, 30),
      text: 'Long day of classes. Kept the reading going anyway.',
    ),
  ]);
  return s;
}

void main() {
  setUpAll(setUpRoomRenders);
  tearDownAll(tearDownRoomRenders);

  final dir = classDayDir('fixes/journal-chips');

  for (final (width, height) in const [(393.0, 852.0), (320.0, 568.0)]) {
    for (final scale in const [1.0, 1.3]) {
      for (final questToday in const [true, false]) {
        final name =
            '${_tag}_${width.toInt()}_text${(scale * 100).round()}'
            '_${questToday ? 'quest' : 'smallwin'}';
        roomRenderTest('journal chips $name', skip: !_renders, (tester) async {
          freezeAt(DateTime(2026, 10, 6, 15, 35));
          tester.view.physicalSize = Size(width * 3, height * 3);
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await pumpPhoneStudy(
            tester,
            JournalHubScreen(
              state: _state(questToday: questToday),
              quests: const [],
              onPersist: () {},
            ),
          );
          await grab(tester, '$dir/$name.png');
          if (width < 393) {
            // The chips sit below the fold on a small phone at large text.
            await tester.drag(
              find.byType(ListView).first,
              const Offset(0, -320),
            );
            await settle(tester);
            await grab(tester, '$dir/${name}_scrolled.png');
          }
        });
      }
    }
  }
}
