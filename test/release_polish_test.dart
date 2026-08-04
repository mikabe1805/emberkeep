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
          // This test owns phase replacement, not ambient motion. Park the
          // candlelit background so pumpAndSettle has a finite contract.
          state: GameState()..reduceMotion = true,
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

  testWidgets('active workout reflows on a narrow large-text phone', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.6)),
          child: child!,
        ),
        home: WorkoutFlow(
          state: GameState()..reduceMotion = true,
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
    await tester.tap(find.text('Wake-Up Snack'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.scrollUntilVisible(
      find.text('LET’S BEGIN'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('LET’S BEGIN'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byKey(const ValueKey('workout-pause'))).height,
      greaterThanOrEqualTo(44),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('workout-finish-early'))).height,
      greaterThanOrEqualTo(44),
    );
    expect(
      MediaQuery.disableAnimationsOf(
        tester.element(find.byType(WorkoutFigure).first),
      ),
      isTrue,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('guided journal starter is styled without changing saved text', (
    tester,
  ) async {
    JournalPayload? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: JournalEntryScreen(
          accent: Colors.amber,
          starter: 'One small win today:\n',
          commit: (payload, existing, markEdited) {
            saved = payload;
            return Note(
              at: DateTime(2026, 7, 28),
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

    final editor = tester.widget<EditableText>(find.byType(EditableText).first);
    expect(editor.controller.text, 'One small win today:\n');

    editor.controller.text = 'One small win today:\nI called my sister.';
    await tester.pump(const Duration(milliseconds: 700));

    final span = editor.controller.buildTextSpan(
      context: tester.element(find.byType(EditableText).first),
      style: editor.style,
      withComposing: false,
    );
    final pieces = span.children!.cast<TextSpan>();
    expect(pieces.first.text, 'One small win today:\n');
    expect(pieces.first.style?.fontStyle, FontStyle.italic);
    expect(pieces.first.style?.color, isNot(editor.style.color));
    expect(pieces.last.text, 'I called my sister.');
    expect(saved?.text, 'One small win today:\nI called my sister.');
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
