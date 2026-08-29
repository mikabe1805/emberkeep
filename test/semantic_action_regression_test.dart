import 'package:emberkeep/audio.dart';
import 'package:emberkeep/content/routines.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/screens/calendar.dart';
import 'package:emberkeep/screens/goal_wizard.dart';
import 'package:emberkeep/screens/journal_entry.dart';
import 'package:emberkeep/widgets/day_picker.dart';
import 'package:emberkeep/widgets/glass_switch.dart';
import 'package:emberkeep/widgets/workout_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    Sfx.instance.soundEnabled = false;
  });

  tearDown(() {
    Sfx.instance.soundEnabled = true;
  });

  Finder semanticsControl(String label) => find.byWidgetPredicate(
    (widget) =>
        widget is Semantics &&
        widget.properties.button == true &&
        widget.properties.label == label,
  );

  void expectTapAction(WidgetTester tester, String label) {
    final control = semanticsControl(label);
    expect(control, findsOneWidget);
    expect(tester.widget<Semantics>(control).properties.onTap, isNotNull);
  }

  testWidgets('custom selection controls expose a screen-reader tap action', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: GoalWizardScreen(state: GameState())),
    );
    await tester.tap(find.text('Reach a finish line'));
    await tester.pump();
    expectTapAction(tester, '5 times');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => pickWeekday(
                context,
                accent: Colors.amber,
                questTitle: 'Read',
              ),
              child: const Text('Open weekday picker'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open weekday picker'));
    await tester.pump();
    expectTapAction(tester, 'Monday');
  });

  testWidgets('calendar navigation and glass toggles stay actionable', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CalendarPage(
            state: GameState()..reduceMotion = true,
            quests: const [],
            onAdd: (_) => true,
          ),
        ),
      ),
    );
    await tester.pump();
    expectTapAction(tester, 'Previous month');

    var enabled = false;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Center(
            child: GlassSwitch(
              key: const ValueKey('reminder-switch'),
              value: enabled,
              semanticLabel: 'Reminders',
              onChanged: (next) => setState(() => enabled = next),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expectTapAction(tester, 'Reminders');
    expect(
      tester.getSize(find.byKey(const ValueKey('reminder-switch'))),
      const Size(48, 48),
    );
  });

  testWidgets('workout pace and active-session controls expose tap actions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
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

    expectTapAction(tester, 'Relaxed pace');
    expectTapAction(tester, 'Steady pace');

    await tester.tap(find.text('LET’S BEGIN'));
    await tester.pump(const Duration(milliseconds: 300));
    expectTapAction(tester, 'Pause session');
    expectTapAction(tester, 'FINISHED THIS MOVE');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('journal reader and photo actions expose tap actions', (
    tester,
  ) async {
    final note = Note(at: DateTime(2026, 8, 4), text: 'A quiet page.');
    await tester.pumpWidget(
      MaterialApp(
        home: JournalEntryScreen(
          initial: note,
          initiallyEditing: false,
          accent: Colors.amber,
          commit: (payload, existing, markEdited) => note,
          onDelete: (_) {},
        ),
      ),
    );
    await tester.pump();

    expectTapAction(tester, 'Back');
    expectTapAction(tester, 'Edit journal entry');

    await tester.tap(find.byKey(const ValueKey('journal-entry-edit')));
    await tester.pump();
    expectTapAction(tester, 'Delete entry');
    final photoAction = find.byKey(const ValueKey('journal-photo-action'));
    expect(photoAction, findsOneWidget);
    expect(tester.widget<Semantics>(photoAction).properties.onTap, isNotNull);
  });
}
