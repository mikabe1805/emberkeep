import 'package:emberkeep/engine.dart';
import 'package:emberkeep/widgets/levelup_overlay.dart';
import 'package:emberkeep/widgets/share_moment_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  test('share text carries the room link only while a room is shared', () {
    final state = GameState()..totalCompletions = 42;
    expect(shareMomentText(state, 12), contains('Level 12'));
    expect(shareMomentText(state, 12), isNot(contains('https://')));

    state.roomCode = 'ABC234';
    expect(shareMomentText(state, 12), contains('/space/ABC234'));
  });

  testWidgets('moment card renders level, facts, and wordmark', (tester) async {
    final state = GameState()
      ..setPlayerName('Mika')
      ..streakDays = 9
      ..totalCompletions = 158
      ..wallStyle = 'wall_walnut';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 340,
              child: MomentCard(state: state, level: 18),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('18'), findsOneWidget);
    expect(find.text('LEVEL UP'), findsOneWidget);
    expect(find.text('Mika · day 9 · 158 quests kept'), findsOneWidget);
    expect(find.text('ROOM OF DAYS'), findsOneWidget);
  });

  testWidgets('level-up overlay exposes the share door only when wired', (
    tester,
  ) async {
    var shared = false;
    await tester.pumpWidget(
      MaterialApp(
        home: LevelUpOverlay(
          level: 18,
          reduceMotion: true,
          onDismiss: () {},
          onShare: () => shared = true,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.tap(find.text('SHARE THIS MOMENT'));
    expect(shared, isTrue);

    await tester.pumpWidget(
      MaterialApp(
        home: LevelUpOverlay(level: 18, reduceMotion: true, onDismiss: () {}),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1500));
    expect(find.text('SHARE THIS MOMENT'), findsNothing);
  });

  testWidgets('share sheet says whether a link travels with the image', (
    tester,
  ) async {
    final state = GameState()..wallStyle = 'wall_walnut';
    await tester.pumpWidget(
      MaterialApp(home: ShareMomentSheet(state: state, level: 7)),
    );
    await tester.pump();
    expect(find.text('Just the image — no link, no code.'), findsOneWidget);

    state.roomCode = 'ABC234';
    await tester.pumpWidget(
      MaterialApp(home: ShareMomentSheet(state: state, level: 7)),
    );
    await tester.pump();
    expect(find.text('The image travels with your room link.'), findsOneWidget);
  });
}
