import 'dart:async';

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
  List<Object?>? cardOrder,
  List<Object?> pinnedMoments = const [],
  String season = '',
  String profilePhotoPath = '',
  String seasonPhotoPath = '',
}) {
  final room = <String, dynamic>{
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
    'v': profilePhotoPath.isNotEmpty || seasonPhotoPath.isNotEmpty
        ? 5
        : cardOrder == null
        ? 3
        : 4,
  };
  if (cardOrder != null) {
    room
      ..['cardOrder'] = cardOrder
      ..['pinnedMoments'] = pinnedMoments
      ..['season'] = season;
  }
  if (room['v'] == 5) {
    room
      ..['uid'] = 'owner_123'
      ..['profilePhotoPath'] = profilePhotoPath
      ..['seasonPhotoPath'] = seasonPhotoPath;
  }
  return room;
}

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
  testWidgets('v1 ignores a stale opted-in visitor profile payload', (
    tester,
  ) async {
    await _pumpCompact(
      tester,
      VisitRoomScreen(
        room: _room(
          profileVisible: true,
          displayName: 'STALE-NAME-SENTINEL',
          about: 'STALE-INTRO-SENTINEL',
          featuredGoals: const ['STALE-GOAL-SENTINEL'],
          cardOrder: const ['about', 'rightNow', 'thisSeason'],
          season: 'STALE-SEASON-SENTINEL',
        ),
        code: 'ABC234',
        lively: false,
      ),
    );

    expect(find.byKey(const ValueKey('visitor-profile-card')), findsNothing);
    for (final sentinel in const [
      'STALE-NAME-SENTINEL',
      'STALE-INTRO-SENTINEL',
      'STALE-GOAL-SENTINEL',
      'STALE-SEASON-SENTINEL',
    ]) {
      expect(find.text(sentinel), findsNothing);
    }
    expect(tester.takeException(), isNull);
  });

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

  testWidgets('audience profile loads outside the bearer room document', (
    tester,
  ) async {
    var requestedMutual = true;
    await _pumpCompact(
      tester,
      VisitRoomScreen(
        room: _room(profileVisible: false),
        code: 'ABC234',
        lively: false,
        visitorProfileSharingEnabled: true,
        spaceProfileFetcher: (code, {includeMutual = false}) async {
          expect(code, 'ABC234');
          requestedMutual = includeMutual;
          return {
            'displayName': 'Mika',
            'cardOrder': const ['about'],
            'about': 'A public page, separate from the room key.',
            'featuredGoals': const <String>[],
            'pinnedMoments': const <Map<String, dynamic>>[],
            'season': '',
          };
        },
      ),
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -520));
    await tester.pumpAndSettle();

    expect(requestedMutual, isFalse);
    expect(
      find.byKey(const ValueKey('visitor-external-profile')),
      findsOneWidget,
    );
    expect(
      find.text('A public page, separate from the room key.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Circle visits request the mutual projection', (tester) async {
    final local = GameState()..addCircleCode('ABC234');
    bool? requestedMutual;
    final events = <String>[];
    await _pumpCompact(
      tester,
      VisitRoomScreen(
        room: _room(profileVisible: false),
        code: 'ABC234',
        lively: false,
        localState: local,
        onPersist: () {},
        discoveryOwnerKey: List.filled(64, 'b').join(),
        visitorProfileSharingEnabled: true,
        relationshipSetter: (code, {ownerKey = '', required active}) async {
          expect(code, 'ABC234');
          expect(ownerKey, hasLength(64));
          expect(active, isTrue);
          events.add('relationship');
          return true;
        },
        spaceProfileFetcher: (code, {includeMutual = false}) async {
          events.add('profile');
          requestedMutual = includeMutual;
          return {
            'displayName': 'A mutual',
            'cardOrder': const ['rightNow'],
            'about': '',
            'featuredGoals': const ['Mutual-only goal'],
            'pinnedMoments': const <Map<String, dynamic>>[],
            'season': '',
          };
        },
      ),
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -520));
    await tester.pumpAndSettle();

    expect(requestedMutual, isTrue);
    expect(events, ['relationship', 'profile']);
    expect(find.text('Mutual-only goal'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'visitor page explains loading, absence, and an empty deck quietly',
    (tester) async {
      final pending = Completer<Map<String, dynamic>?>();
      await _pumpCompact(
        tester,
        VisitRoomScreen(
          room: _room(profileVisible: false),
          code: 'ABC234',
          lively: false,
          visitorProfileSharingEnabled: true,
          spaceProfileFetcher: (_, {includeMutual = false}) => pending.future,
        ),
      );
      final loading = find.byKey(const ValueKey('visitor-profile-loading'));
      await tester.scrollUntilVisible(
        loading,
        220,
        scrollable: find.byType(Scrollable).first,
      );
      expect(loading, findsOneWidget);
      expect(find.text('Opening their page…'), findsOneWidget);

      pending.complete(null);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('visitor-profile-absent')),
        findsOneWidget,
      );
      expect(
        find.text('This keeper has not opened a visitor page.'),
        findsOneWidget,
      );

      await _pumpCompact(
        tester,
        VisitRoomScreen(
          room: _room(profileVisible: false),
          code: 'ABC234',
          lively: false,
          visitorProfileSharingEnabled: true,
          visitorProfile: {
            'displayName': 'Mika',
            'cardOrder': const ['about', 'rightNow'],
            'about': '',
            'featuredGoals': const <String>[],
            'pinnedMoments': const <Map<String, dynamic>>[],
            'season': '',
          },
        ),
      );
      final empty = find.byKey(const ValueKey('visitor-profile-empty'));
      await tester.scrollUntilVisible(
        empty,
        220,
        scrollable: find.byType(Scrollable).first,
      );
      expect(empty, findsOneWidget);
      expect(find.text('ABOUT'), findsNothing);
      expect(
        find.textContaining('Only the cards they chose for your audience'),
        findsNothing,
      );
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
        visitorProfileSharingEnabled: true,
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

  testWidgets(
    'v4 visitor cards follow the owner order and show bounded writing',
    (tester) async {
      await _pumpCompact(
        tester,
        VisitRoomScreen(
          room: _room(
            profileVisible: true,
            displayName: 'Maya',
            about: 'About text that is not selected.',
            featuredGoals: const ['A goal that is not selected'],
            cardOrder: const ['thisSeason', 'pinnedMoments'],
            pinnedMoments: [
              {
                'text': 'The first brave week.',
                'at': DateTime(2026, 8, 2).millisecondsSinceEpoch,
              },
            ],
            season: 'Learning to begin without rushing.',
          ),
          code: 'ABC234',
          lively: false,
          visitorProfileSharingEnabled: true,
        ),
      );

      final season = find.text('THIS SEASON');
      final moments = find.text('PINNED MOMENTS');
      await tester.scrollUntilVisible(
        moments,
        220,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();

      expect(find.text('Maya'), findsOneWidget);
      expect(find.text('Learning to begin without rushing.'), findsOneWidget);
      expect(find.text('The first brave week.'), findsOneWidget);
      expect(find.text('ABOUT'), findsNothing);
      expect(find.text('RIGHT NOW'), findsNothing);
      expect(
        tester.getTopLeft(season).dy,
        lessThan(tester.getTopLeft(moments).dy),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('v1 ignores otherwise valid visitor-photo paths', (tester) async {
    var loaderCalls = 0;
    await _pumpCompact(
      tester,
      VisitRoomScreen(
        room: _room(
          profileVisible: true,
          displayName: 'Maya',
          cardOrder: const ['thisSeason'],
          profilePhotoPath:
              'shared_rooms/owner_123/ABC234/profile/ABCDEFGHIJKLMNOPQRSTUV',
          seasonPhotoPath:
              'shared_rooms/owner_123/ABC234/season/ABCDEFGHIJKLMNOPQRSTUV',
        ),
        code: 'ABC234',
        lively: false,
        visitorProfileSharingEnabled: true,
        photoUrlLoader: (_) async {
          loaderCalls++;
          return 'https://example.test/photo';
        },
      ),
    );

    expect(find.byKey(const ValueKey('visitor-profile-photo')), findsNothing);
    expect(find.byKey(const ValueKey('visitor-season-photo')), findsNothing);
    expect(loaderCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('enabled v5 renders validated, separately shared photo slots', (
    tester,
  ) async {
    await _pumpCompact(
      tester,
      VisitRoomScreen(
        room: _room(
          profileVisible: true,
          displayName: 'Maya',
          cardOrder: const ['thisSeason'],
          season: 'A chapter worth remembering.',
          profilePhotoPath:
              'shared_rooms/owner_123/ABC234/profile/ABCDEFGHIJKLMNOPQRSTUV',
          seasonPhotoPath:
              'shared_rooms/owner_123/ABC234/season/ABCDEFGHIJKLMNOPQRSTUV',
        ),
        code: 'ABC234',
        lively: false,
        visitorPhotoSharingEnabled: true,
        visitorProfileSharingEnabled: true,
        photoUrlLoader: (_) async => throw StateError('offline test'),
      ),
    );

    expect(tester.takeException(), isNull);
    final profile = find.byKey(const ValueKey('visitor-profile-photo'));
    await tester.scrollUntilVisible(
      profile,
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    expect(profile, findsOneWidget);
    expect(tester.takeException(), isNull);

    final season = find.byKey(const ValueKey('visitor-season-photo'));
    await tester.scrollUntilVisible(
      season,
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    expect(season, findsOneWidget);
    expect(find.text('Photo unavailable'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('visitor rejects a photo path for another room or owner', (
    tester,
  ) async {
    final room = _room(
      profileVisible: true,
      displayName: 'Maya',
      cardOrder: const ['thisSeason'],
      profilePhotoPath: 'shared_rooms/another_owner/ABC234/profile',
      seasonPhotoPath: 'shared_rooms/owner_123/DEF234/season',
    );
    await _pumpCompact(
      tester,
      VisitRoomScreen(
        room: room,
        code: 'ABC234',
        lively: false,
        visitorPhotoSharingEnabled: true,
        visitorProfileSharingEnabled: true,
      ),
    );

    expect(find.byKey(const ValueKey('visitor-profile-photo')), findsNothing);
    expect(find.byKey(const ValueKey('visitor-season-photo')), findsNothing);
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

    final largerCircle = GameState()..reduceMotion = true;
    for (final code in const [
      'ABC234',
      'DEF567',
      'GHJ789',
      'KMN234',
      'PQR567',
    ]) {
      expect(largerCircle.addCircleCode(code), isTrue);
    }
    var largerCirclePersists = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: VisitRoomScreen(
          room: _room(profileVisible: false),
          code: 'STU789',
          lively: false,
          localState: largerCircle,
          onPersist: () => largerCirclePersists++,
        ),
      ),
    );
    await tester.pump();
    final largerCircleAction = find.byKey(
      const ValueKey('visit-room-circle-action'),
    );
    await tester.scrollUntilVisible(
      largerCircleAction,
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();

    expect(find.text('KEEP IN MY CIRCLE'), findsOneWidget);
    await tester.tap(largerCircleAction);
    await tester.pump();
    expect(largerCircle.hearthCircleCodes, contains('STU789'));
    expect(largerCircle.hearthCircleCodes, hasLength(6));
    expect(largerCirclePersists, 1);
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
      of: find.byType(CustomScrollView).first,
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

  testWidgets('Circle cards lead with the shared person name', (tester) async {
    final state = GameState()..reduceMotion = true;
    expect(state.addCircleCode('ABC234'), isTrue);

    await _pumpCompact(
      tester,
      HearthCircleScreen(
        state: state,
        onPersist: () {},
        roomFetcher: (_) async => _room(
          profileVisible: true,
          displayName: 'Maya',
          cardOrder: const ['about'],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(
      find.byType(CustomScrollView).first,
      const Offset(0, -520),
    );
    await tester.pump();

    expect(find.text('Maya'), findsOneWidget);
    expect(find.textContaining('STEADY HAND'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Circle keeps a discovered public name without changing room data',
    (tester) async {
      final state = GameState()..reduceMotion = true;
      expect(state.addCircleCode('ABC234', publicName: 'Rowan'), isTrue);

      await _pumpCompact(
        tester,
        HearthCircleScreen(
          state: state,
          onPersist: () {},
          roomFetcher: (_) async => _room(profileVisible: false),
        ),
      );
      await tester.pumpAndSettle();
      await tester.drag(
        find.byType(CustomScrollView).first,
        const Offset(0, -520),
      );
      await tester.pump();

      expect(find.text('Rowan'), findsOneWidget);
      expect(find.text('Fellow keeper'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Circle removal waits for server revocation before forgetting', (
    tester,
  ) async {
    final state = GameState()..reduceMotion = true;
    final ownerKey = List.filled(64, 'a').join();
    expect(state.addCircleCode('ABC234', ownerKey: ownerKey), isTrue);
    var persists = 0;
    var attempts = 0;

    await _pumpCompact(
      tester,
      HearthCircleScreen(
        state: state,
        onPersist: () => persists++,
        roomFetcher: (_) async => _room(profileVisible: false),
        relationshipSetter: (code, {ownerKey = '', required active}) async {
          attempts++;
          expect(code, 'ABC234');
          expect(ownerKey, hasLength(64));
          expect(active, isFalse);
          return false;
        },
      ),
    );
    await tester.pumpAndSettle();
    final remove = find.byKey(const ValueKey('circle-remove-ABC234'));
    await tester.scrollUntilVisible(
      remove,
      420,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(remove);
    await tester.pumpAndSettle();
    await tester.tap(remove);
    await tester.pumpAndSettle();
    expect(find.text('Remove this space?'), findsOneWidget);
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    expect(attempts, 1);
    expect(state.hearthCircleCodes, contains('ABC234'));
    expect(persists, 0);
    expect(find.textContaining('Nothing changed'), findsOneWidget);
  });

  testWidgets('public preview is local-only and excludes mutual cards', (
    tester,
  ) async {
    var fetches = 0;
    var sparks = 0;
    final local = GameState()..roomCode = 'ZZZ999';
    await _pumpCompact(
      tester,
      VisitRoomScreen(
        room: _room(
          profileVisible: true,
          about: 'A legacy private card.',
          featuredGoals: const ['A Mutual-only card.'],
        ),
        code: 'ABC234',
        lively: false,
        previewOnly: true,
        localState: local,
        onPersist: () => fail('preview must not persist visitor actions'),
        visitorProfileSharingEnabled: true,
        visitorProfile: const {
          'displayName': 'Mika',
          'cardOrder': ['about'],
          'about': 'The Anyone card.',
          'featuredGoals': <String>[],
          'pinnedMoments': <Map<String, dynamic>>[],
          'season': '',
        },
        spaceProfileFetcher: (_, {includeMutual = false}) async {
          fetches++;
          return null;
        },
        sparkSender: (_, _) async {
          sparks++;
          return true;
        },
      ),
    );

    expect(find.text('Public preview'), findsOneWidget);
    expect(
      find.text('Only Anyone cards appear here. Nothing is published.'),
      findsOneWidget,
    );
    final profile = find.byKey(const ValueKey('visitor-external-profile'));
    await tester.scrollUntilVisible(
      profile,
      220,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('The Anyone card.'), findsOneWidget);
    expect(find.text('A Mutual-only card.'), findsNothing);
    expect(find.text('A legacy private card.'), findsNothing);
    expect(
      find.byKey(const ValueKey('visit-room-circle-action')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('discover-report-or-hide')), findsNothing);
    expect(find.text('LEAVE A SPARK'), findsNothing);
    expect(fetches, 0);
    expect(sparks, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('public preview without a projection never fetches', (
    tester,
  ) async {
    var fetches = 0;
    await _pumpCompact(
      tester,
      VisitRoomScreen(
        room: _room(profileVisible: false),
        code: 'ABC234',
        lively: false,
        previewOnly: true,
        visitorProfileSharingEnabled: true,
        spaceProfileFetcher: (_, {includeMutual = false}) async {
          fetches++;
          return null;
        },
      ),
    );

    expect(find.text('Public preview'), findsOneWidget);
    expect(fetches, 0);
    expect(find.byKey(const ValueKey('visitor-profile-loading')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('confirmed Circle removal ends the local keep', (tester) async {
    final state = GameState()..reduceMotion = true;
    expect(state.addCircleCode('ABC234'), isTrue);
    var persists = 0;

    await _pumpCompact(
      tester,
      HearthCircleScreen(
        state: state,
        onPersist: () => persists++,
        roomFetcher: (_) async => _room(profileVisible: false),
        relationshipSetter: (_, {ownerKey = '', required active}) async => true,
      ),
    );
    await tester.pumpAndSettle();
    final remove = find.byKey(const ValueKey('circle-remove-ABC234'));
    await tester.scrollUntilVisible(
      remove,
      420,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(remove);
    await tester.pumpAndSettle();
    await tester.tap(remove);
    await tester.pumpAndSettle();
    expect(find.text('Remove this space?'), findsOneWidget);
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    expect(state.hearthCircleCodes, isNot(contains('ABC234')));
    expect(persists, 1);
    expect(find.textContaining('Mutual page access ended'), findsOneWidget);
  });
}
