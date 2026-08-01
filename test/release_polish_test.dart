import 'package:emberkeep/audio.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/content/routines.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/screens/calendar.dart';
import 'package:emberkeep/screens/journal_entry.dart';
import 'package:emberkeep/widgets/workout_flow.dart';
import 'package:emberkeep/widgets/workout_pose.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    Sfx.instance.soundEnabled = false;
  });

  tearDown(() {
    Sfx.instance.soundEnabled = true;
    Clock.reset();
  });

  test('workout move names resolve to honest support poses', () {
    expect(poseForMove('Wall press-up'), WorkoutPose.wallPress);
    expect(poseForMove('Wall push-ups'), WorkoutPose.wallPress);
    expect(poseForMove('Sideways leg lift'), WorkoutPose.sideLift);
    expect(poseForMove('Box breathing'), WorkoutPose.breathe);
    expect(poseForMove('Plank'), WorkoutPose.plank);
  });

  testWidgets('workout phase changes never keep the outgoing scene visible', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: WorkoutFlow(
          state: GameState(),
          recommended: routines.first,
          onFinish:
              ({
                required routine,
                required verified,
                required endedEarly,
                required workMovesDone,
              }) {},
          onClose: () {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Pick a session'), findsOneWidget);
    await tester.tap(find.text('Wake-Up Snack'));
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.text('Pick a session'), findsNothing);
    expect(find.text('Wake-Up Snack'), findsOneWidget);

    await tester.pumpAndSettle();
    await tester.tap(find.text('LET’S BEGIN'));
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.text('LET’S BEGIN'), findsNothing);
    expect(find.text('March on the spot'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('guided journal starter opens as editable ordinary text', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: JournalEntryScreen(
          accent: Colors.amber,
          starter: 'One small win today:\n',
          commit: (payload, existing, markEdited) => Note(
            at: DateTime(2026, 7, 28),
            text: payload.text,
            rich: payload.rich,
            images: payload.images,
          ),
          onDelete: (_) {},
        ),
      ),
    );
    await tester.pump();

    final editor = tester.widget<EditableText>(find.byType(EditableText).first);
    expect(editor.controller.text, 'One small win today:\n');
  });

  testWidgets('planner day-shape preset fills a useful editable plan', (
    tester,
  ) async {
    Clock.freeze(DateTime(2026, 7, 28, 10));
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CalendarPage(
            state: GameState(),
            quests: const [],
            onAdd: (_) => true,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('+ PLAN'));
    // Advance the finite dialog transition explicitly. The authored planner
    // plate keeps its candle attached to the desk; no independent screen-space
    // flame ticker should remain on this page.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text('FOCUS BLOCK'));
    await tester.pump();

    final field = tester.widget<TextField>(find.byType(TextField).first);
    expect(field.controller!.text, 'One focused block');
    expect(find.text('d4'), findsOneWidget);
  });
}
