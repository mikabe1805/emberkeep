import 'package:emberkeep/engine.dart';
import 'package:emberkeep/screens/hearth_circle.dart';
import 'package:emberkeep/screens/visit_room.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _room({
  required bool profileVisible,
  String displayName = '',
  String about = '',
  List<Object?> featuredGoals = const [],
}) => {
  'name': 'Fellow keeper',
  'title': 'STEADY HAND',
  'level': 8,
  'furniture': const ['rug', 'plant'],
  'wall': 'wall_walnut',
  'floor': 'floor_oak',
  'skin': 'ember_amber',
  'window': 'moon',
  'awake': true,
  'memories': 4,
  'weather': 'steady',
  'todayLit': true,
  'focusKind': 'none',
  'focusUntil': 0,
  'profileVisible': profileVisible,
  'displayName': displayName,
  'about': about,
  'featuredGoals': featuredGoals,
  'v': 3,
};

Future<void> _pumpCompact(
  WidgetTester tester,
  Widget child, {
  double textScale = 1.5,
}) async {
  tester.view.physicalSize = const Size(320, 568);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
  await tester.pumpWidget(MaterialApp(home: child));
  await tester.pump();
}

void main() {
  testWidgets(
    'opted-out visitor profile stays entirely private at large text',
    (tester) async {
      await _pumpCompact(
        tester,
        VisitRoomScreen(
          room: _room(
            profileVisible: false,
            displayName: 'Private name',
            about: 'Private introduction',
            featuredGoals: const ['Private goal'],
          ),
          code: 'ABC234',
          lively: false,
        ),
      );

      expect(find.byKey(const ValueKey('visitor-profile-card')), findsNothing);
      expect(find.textContaining('Private name'), findsNothing);
      expect(find.text('Private introduction'), findsNothing);
      expect(find.text('Private goal'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('opted-in visitor card is readable and clamps shared goals', (
    tester,
  ) async {
    await _pumpCompact(
      tester,
      VisitRoomScreen(
        room: _room(
          profileVisible: true,
          displayName: 'Maya',
          about: 'Making a quieter home and showing up for the people I love.',
          featuredGoals: const [
            'Walk after dinner',
            'Finish the essay',
            42,
            'Call family weekly',
            'A fourth goal that must not render',
          ],
        ),
        code: 'ABC234',
        lively: false,
      ),
    );

    final card = find.byKey(const ValueKey('visitor-profile-card'));
    await tester.scrollUntilVisible(
      card,
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();

    expect(card, findsOneWidget);
    expect(find.text('Maya'), findsOneWidget);
    expect(
      find.text('Making a quieter home and showing up for the people I love.'),
      findsOneWidget,
    );
    expect(find.text('Walk after dinner'), findsOneWidget);
    expect(find.text('Finish the essay'), findsOneWidget);
    expect(find.text('Call family weekly'), findsOneWidget);
    expect(find.text('A fourth goal that must not render'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Circle action saves once and explains the full state', (
    tester,
  ) async {
    var persists = 0;
    final state = GameState()..reduceMotion = true;
    await _pumpCompact(
      tester,
      VisitRoomScreen(
        room: _room(profileVisible: false),
        code: 'ABC234',
        lively: false,
        localState: state,
        onPersist: () => persists++,
      ),
    );

    final action = find.byKey(const ValueKey('visit-room-circle-action'));
    await tester.scrollUntilVisible(
      action,
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
    expect(find.text('KEEP IN MY CIRCLE'), findsOneWidget);

    await tester.tap(action);
    await tester.pump();
    expect(state.hearthCircleCodes, contains('ABC234'));
    expect(persists, 1);
    expect(find.text('IN YOUR CIRCLE'), findsOneWidget);

    final full = GameState()..reduceMotion = true;
    for (final code in const [
      'ABC234',
      'DEF567',
      'GHJ789',
      'KMN234',
      'PQR567',
    ]) {
      expect(full.addCircleCode(code), isTrue);
    }
    var fullPersists = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: VisitRoomScreen(
          room: _room(profileVisible: false),
          code: 'STU789',
          lively: false,
          localState: full,
          onPersist: () => fullPersists++,
        ),
      ),
    );
    await tester.pump();
    final fullAction = find.byKey(const ValueKey('visit-room-circle-action'));
    await tester.scrollUntilVisible(
      fullAction,
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();

    expect(find.text('CIRCLE IS FULL'), findsOneWidget);
    await tester.tap(fullAction);
    await tester.pump();
    expect(full.hearthCircleCodes, isNot(contains('STU789')));
    expect(fullPersists, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Circle add reuses validated in-dialog fetch at 2x text', (
    tester,
  ) async {
    final state = GameState()..reduceMotion = true;
    var persists = 0;
    var fetched = 0;
    await _pumpCompact(
      tester,
      HearthCircleScreen(
        state: state,
        onPersist: () => persists++,
        roomFetcher: (code) async {
          fetched++;
          expect(code, 'ABC234');
          return _room(profileVisible: false);
        },
      ),
      textScale: 2,
    );

    final add = find.text('ADD A SPACE');
    final circleScroll = find.descendant(
      of: find.byType(ListView).first,
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(add, 420, scrollable: circleScroll);
    await tester.pump();
    await tester.tap(add);
    await tester.pump();

    await tester.enterText(find.byKey(const Key('visit-space-code')), 'ABC');
    await tester.tap(find.byKey(const Key('visit-space-submit')));
    await tester.pump();
    expect(find.byKey(const Key('visit-space-error')), findsOneWidget);
    expect(fetched, 0);

    await tester.enterText(find.byKey(const Key('visit-space-code')), 'ABC234');
    await tester.tap(find.byKey(const Key('visit-space-submit')));
    await tester.pumpAndSettle();

    expect(state.hearthCircleCodes, contains('ABC234'));
    expect(persists, 1);
    expect(fetched, 1);
    expect(tester.takeException(), isNull);
  });
}
