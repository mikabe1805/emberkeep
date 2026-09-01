import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:emberkeep/audio.dart';
import 'package:emberkeep/cloud.dart';
import 'package:emberkeep/content/creature_skins.dart';
import 'package:emberkeep/discovery.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/screens/discover_spaces.dart';
import 'package:emberkeep/screens/visit_room.dart';
import 'package:emberkeep/social.dart';
import 'package:emberkeep/widgets/glass_switch.dart';
import 'package:emberkeep/widgets/home_room.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

DiscoverableSpaceSummary _space(
  String code, {
  String title = 'STEADY HAND',
  int level = 12,
  String wall = 'wall_walnut',
  String skin = 'ember_amber',
  String publicName = '',
  String? ownerKey,
}) => DiscoverableSpaceSummary(
  code: code,
  buildTitle: title,
  level: level,
  wall: wall,
  floor: 'floor_oak',
  skin: skin,
  window: 'moon',
  bucket: 1,
  ownerKey: ownerKey ?? discoveryOwnerKey('owner-$code'),
  publicName: publicName,
);

Map<String, dynamic> _room(DiscoverableSpaceSummary summary) => {
  'v': 6,
  'title': summary.buildTitle,
  'level': summary.level,
  'wall': summary.wall,
  'floor': summary.floor,
  'skin': summary.skin,
  'window': summary.window,
  'furniture': <String>[],
  'ownerKey': summary.ownerKey,
  'profileVisible': false,
};

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => Sfx.instance.soundEnabled = false);
  tearDown(() => Sfx.instance.soundEnabled = true);

  testWidgets('directory shows a finite private projection and filters self', (
    tester,
  ) async {
    final state = GameState()
      ..reduceMotion = true
      ..roomCode = 'ABC234';
    final visible = _space(
      'DEF234',
      title: 'DEEP CURRENT',
      level: 21,
      wall: 'wall_archive',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: DiscoverSpacesScreen(
          state: state,
          onPersist: () {},
          fetchSpaces: () async => [_space('ABC234'), visible],
          fetchRoom: (code) async => _room(visible),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Discover spaces'), findsOneWidget);
    expect(find.text('DEEP CURRENT'), findsOneWidget);
    expect(find.text('LV 21'), findsOneWidget);
    expect(find.text('STEADY HAND'), findsNothing);
    expect(find.text('ABC234'), findsNothing);
    expect(find.text('DEF234'), findsNothing);
    expect(find.textContaining('Quests, Journal pages'), findsOneWidget);
    expect(
      find.textContaining('A block still works if a keeper changes room codes'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('discover-refresh')), findsOneWidget);
    expect(find.byKey(const ValueKey('discover-enter-code')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('discover-community-rules')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a parsed found flame reaches the Discover room preview', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 8, 31);
    final summary = DiscoverableSpaceSummary.fromDocument('DEF234', {
      'v': 3,
      'title': 'MOSS HEARTH',
      'level': 12,
      'wall': 'wall_listening',
      'floor': 'floor_oak',
      'skin': 'found_moss',
      'window': 'moon',
      'bucket': 1,
      'ownerKey': discoveryOwnerKey('owner-DEF234'),
      'publicName': '',
      'expiresAt': Timestamp.fromDate(now.add(const Duration(days: 30))),
    }, now: now)!;

    await tester.pumpWidget(
      MaterialApp(
        home: DiscoverSpacesScreen(
          state: GameState()..reduceMotion = true,
          onPersist: () {},
          fetchSpaces: () async => [summary],
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final room = tester.widget<HomeRoom>(find.byType(HomeRoom));
    expect(room.emberGlow, flameHueById('found_moss'));
    expect(room.emberGlow, isNot(flameHueById('ember_amber')));
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a directory card fetches only that room then visits', (
    tester,
  ) async {
    final summary = _space('DEF234', title: 'OPEN HEARTH', publicName: 'Rowan');
    var fetches = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: DiscoverSpacesScreen(
          state: GameState()..reduceMotion = true,
          onPersist: () {},
          fetchSpaces: () async => [summary],
          publicDiscoveryNamesEnabled: true,
          fetchRoom: (code) async {
            fetches++;
            expect(code, summary.code);
            return _room(summary);
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(fetches, 0);

    await tester.tap(find.byKey(ValueKey('discover-space-${summary.code}')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));

    expect(fetches, 1);
    expect(find.text('Rowan’s space'), findsOneWidget);
    expect(find.text('visiting · ${summary.code}'), findsOneWidget);
    expect(find.text('OPEN HEARTH'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('blocked rooms stay out and a report hides the current room', (
    tester,
  ) async {
    final blocked = _space('BKM234', title: 'EVERGREEN');
    final visible = _space('DEF234', title: 'OPEN HEARTH', publicName: 'Rowan');
    final state = GameState()..reduceMotion = true;
    state.blockRoomCode(blocked.code);
    final reports = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: DiscoverSpacesScreen(
          state: state,
          onPersist: () {},
          fetchSpaces: () async => [blocked, visible],
          fetchRoom: (_) async => _room(visible),
          reportSpace: (code, category) async {
            reports.add('$code:$category');
            return true;
          },
          publicDiscoveryNamesEnabled: true,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('EVERGREEN'), findsNothing);
    expect(find.text('Rowan'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('discover-space-DEF234')));
    await tester.pumpAndSettle();
    final action = find.byKey(const ValueKey('discover-report-or-hide'));
    expect(find.text('Rowan’s space'), findsOneWidget);
    await tester.scrollUntilVisible(
      action,
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(action);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('discover-report-name')));
    await tester.pumpAndSettle();

    expect(reports, ['DEF234:inappropriate_name']);
    expect(state.blockedRoomCodes, contains('DEF234'));
    expect(state.blockedDiscoveryOwners, {visible.ownerKey: 'DEF234'});
    expect(find.text('No open doors yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('directory failure stays retryable at large text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var attempts = 0;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.6)),
          child: child!,
        ),
        home: DiscoverSpacesScreen(
          state: GameState()..reduceMotion = true,
          onPersist: () {},
          fetchSpaces: () async {
            attempts++;
            return attempts == 1 ? null : <DiscoverableSpaceSummary>[];
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('The doors went quiet'), findsOneWidget);
    final retry = find.text('TRY AGAIN');
    await tester.ensureVisible(retry);
    await tester.pump();
    await tester.tap(retry);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('No open doors yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty directory leads its owner to listing controls', (
    tester,
  ) async {
    final state = GameState()..reduceMotion = true;
    var opened = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: DiscoverSpacesScreen(
          state: state,
          onPersist: () {},
          fetchSpaces: () async => const <DiscoverableSpaceSummary>[],
          onManageOwnListing: () async => opened++,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(state.roomCode, isNull);
    expect(state.roomDiscoverable, isFalse);
    expect(find.text('No open doors yet'), findsOneWidget);
    expect(find.text('YOUR SPACE IS PRIVATE'), findsOneWidget);
    final manage = find.byKey(const ValueKey('discover-manage-own-listing'));
    expect(manage, findsOneWidget);

    await tester.tap(manage);
    await tester.pump();
    expect(opened, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'hide and report choices remain readable on a small large-text phone',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final summary = _space('DEF234', publicName: 'Rowan');
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!,
          ),
          home: VisitRoomScreen(
            room: _room(summary),
            code: summary.code,
            lively: false,
            localState: GameState()..reduceMotion = true,
            onPersist: () {},
            discoveryPublicName: summary.publicName,
            onReportDiscoverableSpace: (_, _) async => true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final action = find.byKey(const ValueKey('discover-report-or-hide'));
      await tester.scrollUntilVisible(
        action,
        220,
        scrollable: find.byType(Scrollable).first,
      );
      // Keep the control clear of the bottom safe-area on short phones. The
      // page is intentionally scrollable, so this mirrors the small follow-up
      // swipe a large-text user makes before tapping the final action.
      await tester.drag(find.byType(ListView).first, const Offset(0, -64));
      await tester.pumpAndSettle();
      await tester.tap(action);
      await tester.pumpAndSettle();

      expect(find.text('Block or report this keeper?'), findsOneWidget);
      expect(find.text('BLOCK THIS KEEPER'), findsOneWidget);
      expect(find.text('REPORT THIS NAME'), findsOneWidget);
      expect(find.text('REPORT IMPERSONATION'), findsOneWidget);
      expect(find.text('REPORT THIS PAGE'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('rejects a directory room whose fetched owner does not match', (
    tester,
  ) async {
    final summary = _space('DEF234');
    await tester.pumpWidget(
      MaterialApp(
        home: DiscoverSpacesScreen(
          state: GameState()..reduceMotion = true,
          onPersist: () {},
          fetchSpaces: () async => [summary],
          fetchRoom: (_) async => {
            ..._room(summary),
            'ownerKey': discoveryOwnerKey('another-owner'),
          },
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('discover-space-DEF234')));
    await tester.pumpAndSettle();

    expect(find.textContaining('changed before it could open'), findsOneWidget);
    expect(find.text('No open doors yet'), findsOneWidget);
    expect(find.byType(VisitRoomScreen), findsNothing);
  });

  testWidgets(
    'blocking one keeper removes every one of their directory cards',
    (tester) async {
      final first = _space('DEF234');
      final second = _space('GHJ234', ownerKey: first.ownerKey);
      final state = GameState()..reduceMotion = true;
      await tester.pumpWidget(
        MaterialApp(
          home: DiscoverSpacesScreen(
            state: state,
            onPersist: () {},
            fetchSpaces: () async => [first, second],
            fetchRoom: (_) async => _room(first),
            reportSpace: (_, _) async => true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('discover-space-DEF234')));
      await tester.pumpAndSettle();
      final action = find.byKey(const ValueKey('discover-report-or-hide'));
      await tester.scrollUntilVisible(
        action,
        220,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(action);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('discover-hide-space')));
      await tester.pumpAndSettle();

      expect(state.blockedDiscoveryOwners, {first.ownerKey: first.code});
      expect(find.byKey(const ValueKey('discover-space-GHJ234')), findsNothing);
    },
  );

  testWidgets('an exact code cannot open a blocked keeper', (tester) async {
    final state = GameState()..reduceMotion = true;
    final ownerKey = discoveryOwnerKey('blocked-owner');
    state.blockDiscoveryOwner(ownerKey, 'DEF234');
    final room = {..._room(_space('DEF234')), 'ownerKey': ownerKey};
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => visitSpace(
                context,
                state: state,
                fetcher: (_) async => room,
                initialCode: 'DEF234',
                autoSubmit: true,
              ),
              child: const Text('Visit blocked keeper'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Visit blocked keeper'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('That keeper is hidden on this device.'), findsOneWidget);
    expect(find.byType(VisitRoomScreen), findsNothing);
  });

  testWidgets(
    'discoverability toggle confirms success and rolls back failure',
    (tester) async {
      var allow = false;
      final changes = <bool>[];
      final names = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => FilledButton(
                onPressed: () => showShareSpaceDialog(
                  context,
                  code: 'ABC234',
                  discoverable: false,
                  onDiscoverableChanged: (next) async {
                    changes.add(next);
                    return allow;
                  },
                  onPublicDiscoveryNameChanged: (name) async {
                    names.add(name);
                    return DiscoveryPublicNameUpdate.saved;
                  },
                  onStop: () async => true,
                ),
                child: const Text('Open share'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open share'));
      await tester.pumpAndSettle();

      final toggle = find.byKey(const ValueKey('share-space-discovery-switch'));
      expect(tester.widget<GlassSwitch>(toggle).value, isFalse);
      await tester.tap(toggle);
      await tester.pump();
      await tester.pump();
      expect(changes, [true]);
      expect(tester.widget<GlassSwitch>(toggle).value, isFalse);
      expect(find.textContaining('still private'), findsOneWidget);

      allow = true;
      await tester.tap(toggle);
      await tester.pump();
      await tester.pump();
      expect(changes, [true, true]);
      expect(tester.widget<GlassSwitch>(toggle).value, isTrue);
      expect(find.textContaining('People can find this room'), findsOneWidget);
      final nameField = find.byKey(
        const ValueKey('share-space-public-discovery-name'),
      );
      expect(nameField, findsOneWidget);
      await tester.enterText(nameField, '  Rowan  ');
      await tester.pump();
      final saveName = find.byKey(
        const ValueKey('share-space-save-public-name'),
      );
      await tester.ensureVisible(saveName);
      await tester.pump();
      await tester.tap(saveName);
      await tester.pump();
      await tester.pump();
      expect(names, ['Rowan']);
      expect(find.textContaining('public name is saved'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'discoverability write stays acknowledged and pending until it resolves',
    (tester) async {
      final write = Completer<bool>();
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => FilledButton(
                onPressed: () => showShareSpaceDialog(
                  context,
                  code: 'ABC234',
                  discoverable: false,
                  onDiscoverableChanged: (_) {
                    calls += 1;
                    return write.future;
                  },
                  onStop: () async => true,
                ),
                child: const Text('Open share'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open share'));
      await tester.pumpAndSettle();

      final toggle = find.byKey(const ValueKey('share-space-discovery-switch'));
      await tester.tap(toggle);
      await tester.pump();
      await tester.pump(const Duration(seconds: 9));

      expect(calls, 1);
      expect(tester.widget<GlassSwitch>(toggle).value, isTrue);
      final guard = find.ancestor(
        of: toggle,
        matching: find.byType(IgnorePointer),
      );
      expect(tester.widget<IgnorePointer>(guard.first).ignoring, isTrue);
      expect(find.text('Opening your door…'), findsOneWidget);
      expect(find.textContaining('Couldn’t open your door yet'), findsNothing);

      write.complete(true);
      await tester.pump();
      await tester.pump();

      expect(tester.widget<GlassSwitch>(toggle).value, isTrue);
      expect(find.text('Opening your door…'), findsNothing);
      expect(find.textContaining('People can find this room'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('discovery-first share opens with its switch on screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => showShareSpaceDialog(
                context,
                code: 'ABC234',
                discoveryFirst: true,
                onDiscoverableChanged: (_) async => true,
                onStop: () async => true,
              ),
              child: const Text('Open discovery'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open discovery'));
    await tester.pumpAndSettle();

    final switchFinder = find.byKey(
      const ValueKey('share-space-discovery-switch'),
    );
    expect(switchFinder, findsOneWidget);
    final rect = tester.getRect(switchFinder);
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(rect.bottom, lessThanOrEqualTo(568));
    expect(tester.takeException(), isNull);
  });
}
