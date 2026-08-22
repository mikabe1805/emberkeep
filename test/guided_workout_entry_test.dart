import 'package:emberkeep/audio.dart';
import 'package:emberkeep/content/routines.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/screens/goals.dart';
import 'package:emberkeep/widgets/workout_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => Sfx.instance.soundEnabled = false);
  tearDown(() => Sfx.instance.soundEnabled = true);

  testWidgets(
    'Goals card opens all guided sessions without adding a duplicate',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final state = GameState()..reduceMotion = true;
      final quests = <Quest>[workoutLauncherQuest()];
      var addCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (routeContext) => GoalsPage(
              state: state,
              quests: quests,
              onAdd: (_) {
                addCalls++;
                return false;
              },
              onRemoveQuest: (_) {},
              onRemoveGoal: (_) {},
              onPersist: () {},
              onOpenQuests: () {},
              onOpenGuidedWorkouts: () => Navigator.of(routeContext).push<void>(
                MaterialPageRoute(
                  builder: (_) => WorkoutFlow(
                    state: state,
                    recommended: routines.first,
                    onClose: () => Navigator.of(routeContext).pop(),
                    onFinish:
                        ({
                          required routine,
                          required verified,
                          required endedEarly,
                          required workMovesDone,
                        }) {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      final card = find.byKey(const ValueKey('guided-workouts-card'));
      await tester.scrollUntilVisible(
        card,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(card);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));

      expect(find.text('Pick a session'), findsOneWidget);
      for (final routine in routines) {
        expect(find.text(routine.title, skipOffstage: false), findsOneWidget);
      }
      expect(addCalls, 0);
      expect(quests.where((quest) => quest.workout), hasLength(1));
      expect(find.textContaining('already on your Quests board'), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
