import 'package:emberkeep/widgets/goal_world.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('room travel replaces missing source art without an X', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox.expand(
          child: GoalRoomTravelBackdrop(
            progress: 0.35,
            reduceMotion: true,
            sourceAsset: 'assets/pages/does-not-exist.webp',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('goal-room-source-fallback')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
