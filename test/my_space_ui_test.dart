import 'dart:async';

import 'package:emberkeep/audio.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/cloud.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/screens/me.dart';
import 'package:emberkeep/social.dart';
import 'package:emberkeep/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _phoneSize = Size(430, 932);

Future<RoomPublishResult> _publishRoomSuccessfully(
  GameState _, {
  required String code,
}) async => RoomPublishResult.success(code);

Future<String?> _resetSuccessfully() async => null;

Widget _mePage(
  GameState state,
  VoidCallback onPersist, {
  SpaceRoomPublisher onPublishRoom = _publishRoomSuccessfully,
  Future<String?> Function() onReset = _resetSuccessfully,
  bool visitorPhotoSharingEnabled = false,
  bool visitorProfileSharingEnabled = true,
}) => Scaffold(
  body: MePage(
    state: state,
    quests: const [],
    onPersist: onPersist,
    onPublishRoom: onPublishRoom,
    onAddQuest: (_) => true,
    onExport: () async => true,
    onImport: (_) async => true,
    onReset: onReset,
    onNotifyChanged: () async {},
    onEnableCloud: () async => null,
    onLinkAccount: (_, _) async => null,
    onSignIn: (_, _) async => null,
    onSignOut: () async {},
    onDeleteAccount: (_) async => null,
    visitorPhotoSharingEnabled: visitorPhotoSharingEnabled,
    visitorProfileSharingEnabled: visitorProfileSharingEnabled,
  ),
);

Future<void> _pumpMe(
  WidgetTester tester,
  GameState state,
  VoidCallback onPersist, {
  SpaceRoomPublisher onPublishRoom = _publishRoomSuccessfully,
  Future<String?> Function() onReset = _resetSuccessfully,
  bool visitorPhotoSharingEnabled = false,
  bool visitorProfileSharingEnabled = true,
}) async {
  tester.view.physicalSize = _phoneSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    MaterialApp(
      home: _mePage(
        state,
        onPersist,
        onPublishRoom: onPublishRoom,
        onReset: onReset,
        visitorPhotoSharingEnabled: visitorPhotoSharingEnabled,
        visitorProfileSharingEnabled: visitorProfileSharingEnabled,
      ),
    ),
  );
  await tester.pump();
}

Future<void> _openArranger(WidgetTester tester) async {
  final open = find.byKey(const ValueKey('space-page-open-arranger'));
  await tester.scrollUntilVisible(
    open,
    320,
    scrollable: find.byType(Scrollable).first,
  );
  // scrollUntilVisible stops at partial visibility; the button's centre can
  // still sit below the fold, so bring it fully on-screen before tapping.
  await tester.ensureVisible(open);
  await tester.pump();
  await tester.tap(open);
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('space-arranger')), findsOneWidget);
}

Finder _arrangerCard(SpaceCardKind kind) =>
    find.byKey(ValueKey('space-card-${kind.name}'));

Future<void> _collapseAbout(WidgetTester tester) async {
  final title = find.descendant(
    of: _arrangerCard(SpaceCardKind.about),
    matching: find.text('About'),
  );
  await tester.tap(title);
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('space-card-editor-about')), findsNothing);
}

Future<void> _moveRightNowBeforeAbout(WidgetTester tester) async {
  final handle = find.descendant(
    of: _arrangerCard(SpaceCardKind.rightNow),
    matching: find.byIcon(Icons.drag_indicator_rounded),
  );
  await tester.ensureVisible(handle);
  await tester.pump();
  final start = tester.getCenter(handle);
  final targetY = tester.getRect(_arrangerCard(SpaceCardKind.about)).top + 10;
  await tester.timedDrag(
    handle,
    Offset(0, targetY - start.dy),
    const Duration(milliseconds: 650),
  );
  await tester.pumpAndSettle();

  final rightNowY = tester.getTopLeft(_arrangerCard(SpaceCardKind.rightNow)).dy;
  final aboutY = tester.getTopLeft(_arrangerCard(SpaceCardKind.about)).dy;
  final pinnedY = tester
      .getTopLeft(_arrangerCard(SpaceCardKind.pinnedMoments))
      .dy;
  expect(rightNowY, lessThan(aboutY));
  expect(aboutY, lessThan(pinnedY));
}

void main() {
  testWidgets('v1 keeps My Space writing local and clears stale sharing', (
    tester,
  ) async {
    final state = GameState()
      ..reduceMotion = true
      ..shareSpaceProfile = true
      ..spaceIntro = 'My private introduction.'
      ..spaceSeasonText = 'My private season.'
      ..shareSpaceProfilePhoto = true
      ..shareSpaceSeasonPhoto = true
      ..spaceProfilePhotoPath = 'stale-profile-path'
      ..spaceSeasonPhotoPath = 'stale-season-path';
    state.visitorSpaceCards.addAll(SpaceCardKind.values);
    var persists = 0;

    await _pumpMe(
      tester,
      state,
      () => persists++,
      visitorProfileSharingEnabled: false,
      visitorPhotoSharingEnabled: true,
    );
    await _openArranger(tester);

    expect(
      find.byKey(const ValueKey('space-profile-local-only')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('space-profile-share-toggle')),
      findsNothing,
    );
    for (final kind in SpaceCardKind.values) {
      expect(
        find.byKey(ValueKey('space-card-share-${kind.name}')),
        findsNothing,
      );
    }
    expect(find.text('My private introduction.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('space-arranger-save')));
    await tester.pumpAndSettle();

    expect(state.spaceIntro, 'My private introduction.');
    expect(state.spaceSeasonText, 'My private season.');
    expect(state.shareSpaceProfile, isFalse);
    expect(state.visitorSpaceCards, isEmpty);
    expect(state.shareSpaceProfilePhoto, isFalse);
    expect(state.shareSpaceSeasonPhoto, isFalse);
    expect(state.spaceProfilePhotoPath, isEmpty);
    expect(state.spaceSeasonPhotoPath, isEmpty);
    expect(persists, 1);
  });

  setUp(() {
    Sfx.instance.soundEnabled = false;
    Clock.freeze(DateTime(2026, 8, 3, 10));
  });

  tearDown(() {
    Sfx.instance.soundEnabled = true;
    Clock.reset();
  });

  testWidgets('legacy My Space omits an empty This season card', (
    tester,
  ) async {
    final state = GameState()..reduceMotion = true;

    await _pumpMe(tester, state, () {});

    expect(find.text('ABOUT'), findsOneWidget);
    expect(find.text('RIGHT NOW'), findsOneWidget);
    expect(find.text('PINNED MOMENTS'), findsOneWidget);
    expect(find.text('THIS SEASON'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('My Space renders saved order and leaves hidden cards out', (
    tester,
  ) async {
    final state = GameState()
      ..reduceMotion = true
      ..goals.add(Goal(title: 'Finish the essay', stat: Stat.intl, target: 4));
    state.setSpacePage(
      order: const [
        SpaceCardKind.thisSeason,
        SpaceCardKind.rightNow,
        SpaceCardKind.pinnedMoments,
        SpaceCardKind.about,
      ],
      hidden: const [SpaceCardKind.pinnedMoments],
      intro: 'I am making room for slower mornings.',
      featuredGoalTitles: const ['Finish the essay'],
      seasonText: 'Learning how I want this semester to feel.',
      profilePhotoNoteId: null,
      seasonPhotoNoteId: null,
      shareProfilePhoto: false,
      shareSeasonPhoto: false,
      shareProfile: false,
    );

    await _pumpMe(tester, state, () {});

    final season = find.text('THIS SEASON');
    final rightNow = find.text('RIGHT NOW');
    final about = find.text('ABOUT');
    expect(season, findsOneWidget);
    expect(rightNow, findsOneWidget);
    expect(about, findsOneWidget);
    expect(find.text('PINNED MOMENTS'), findsNothing);
    expect(
      tester.getTopLeft(season).dy,
      lessThan(tester.getTopLeft(rightNow).dy),
    );
    expect(
      tester.getTopLeft(rightNow).dy,
      lessThan(tester.getTopLeft(about).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Cancel discards arranger visibility and order changes', (
    tester,
  ) async {
    final state = GameState()..reduceMotion = true;
    final originalOrder = state.spaceCardOrder.toList();
    final originalHidden = state.hiddenSpaceCards.toSet();
    final originalVisitorCards = state.visitorSpaceCards.toSet();
    var persists = 0;
    var notifications = 0;
    state.addListener(() => notifications++);

    await _pumpMe(tester, state, () => persists++);
    await _openArranger(tester);
    await _collapseAbout(tester);

    await tester.tap(find.byKey(const ValueKey('space-card-toggle-rightNow')));
    await tester.pump();
    final sharePinned = find.byKey(
      const ValueKey('space-card-share-pinnedMoments'),
    );
    await tester.ensureVisible(sharePinned);
    await tester.tap(sharePinned);
    await tester.pump();
    await _moveRightNowBeforeAbout(tester);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('space-arranger')), findsNothing);
    expect(state.spaceCardOrder, originalOrder);
    expect(state.hiddenSpaceCards, originalHidden);
    expect(state.visitorSpaceCards, originalVisitorCards);
    expect(state.spaceIntro, isEmpty);
    expect(notifications, 0);
    expect(persists, 0);
  });

  testWidgets('Save applies one arranged page change and persists once', (
    tester,
  ) async {
    final state = GameState()..reduceMotion = true;
    var persists = 0;
    var notifications = 0;
    state.addListener(() => notifications++);

    await _pumpMe(tester, state, () => persists++);
    await _openArranger(tester);

    final intro = find.descendant(
      of: find.byKey(const ValueKey('space-card-editor-about')),
      matching: find.byType(TextField),
    );
    await tester.enterText(intro, 'I am building a kinder semester.');
    tester.testTextInput.hide();
    await tester.pump();
    await _collapseAbout(tester);

    await tester.tap(find.byKey(const ValueKey('space-card-toggle-rightNow')));
    await tester.pump();
    final sharePinned = find.byKey(
      const ValueKey('space-card-share-pinnedMoments'),
    );
    await tester.ensureVisible(sharePinned);
    await tester.tap(sharePinned);
    await tester.pump();
    await _moveRightNowBeforeAbout(tester);

    await tester.tap(find.byKey(const ValueKey('space-arranger-save')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('space-arranger')), findsNothing);
    expect(state.spaceCardOrder, const [
      SpaceCardKind.rightNow,
      SpaceCardKind.about,
      SpaceCardKind.pinnedMoments,
      SpaceCardKind.thisSeason,
    ]);
    expect(state.hiddenSpaceCards, {SpaceCardKind.rightNow});
    expect(state.visitorSpaceCards, {
      SpaceCardKind.about,
      SpaceCardKind.rightNow,
      SpaceCardKind.pinnedMoments,
    });
    expect(state.spaceIntro, 'I am building a kinder semester.');
    expect(notifications, 1);
    expect(persists, 1);
  });

  testWidgets('v1 profile photo stays local and offers no visitor switch', (
    tester,
  ) async {
    final photo = Note(
      id: 'local-profile-photo',
      at: DateTime(2026, 8, 3),
      text: 'A local photo.',
      images: const ['journal/local-profile.jpg'],
    );
    final state = GameState()
      ..reduceMotion = true
      ..journal = [photo];
    var persists = 0;

    await _pumpMe(tester, state, () => persists++);
    await _openArranger(tester);

    expect(
      find.byKey(const ValueKey('space-profile-photo-share-toggle')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('space-photo-local-only')),
      findsOneWidget,
    );
    final choice = find.byKey(
      const ValueKey('space-profile-photo-local-profile-photo'),
    );
    await tester.ensureVisible(choice);
    await tester.tap(choice);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('space-arranger-save')));
    await tester.pumpAndSettle();

    expect(state.spaceProfilePhotoNoteId, photo.id);
    expect(state.shareSpaceProfilePhoto, isFalse);
    expect(persists, 1);
  });

  testWidgets('enabled profile photo needs an explicit visitor-photo switch', (
    tester,
  ) async {
    final photo = Note(
      id: 'profile-photo-source',
      at: DateTime(2026, 8, 3),
      text: 'A photo I chose.',
      images: const ['journal/profile.jpg'],
    );
    final state = GameState()
      ..reduceMotion = true
      ..journal = [photo];
    var persists = 0;

    await _pumpMe(
      tester,
      state,
      () => persists++,
      visitorPhotoSharingEnabled: true,
    );
    await _openArranger(tester);

    final choice = find.byKey(
      const ValueKey('space-profile-photo-profile-photo-source'),
    );
    await tester.ensureVisible(choice);
    await tester.pumpAndSettle();
    await tester.tap(choice);
    await tester.pump();

    expect(state.spaceProfilePhotoNoteId, isNull);
    expect(state.shareSpaceProfilePhoto, isFalse);
    final consent = find.byKey(
      const ValueKey('space-profile-photo-share-toggle'),
    );
    await tester.ensureVisible(consent);
    await tester.tap(consent);
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('space-arranger-save')));
    await tester.pumpAndSettle();

    expect(state.spaceProfilePhotoNoteId, photo.id);
    expect(state.shareSpaceProfilePhoto, isTrue);
    expect(persists, 1);
  });

  testWidgets(
    'failed live privacy save keeps editor open and live state untouched',
    (tester) async {
      final state = GameState()
        ..reduceMotion = true
        ..roomCode = 'ABC234'
        ..shareSpaceProfile = true
        ..spaceIntro = 'This is currently public.';
      var persists = 0;
      var notifications = 0;
      var publishes = 0;
      Map<String, dynamic>? attempted;
      state.addListener(() => notifications++);

      await _pumpMe(
        tester,
        state,
        () => persists++,
        onPublishRoom: (target, {required code}) async {
          publishes++;
          attempted = roomDisplay(target);
          expect(code, 'ABC234');
          return const RoomPublishResult.failed(RoomPublishFailure.network);
        },
      );
      await _openArranger(tester);

      final audience = find.byKey(const ValueKey('space-card-share-about'));
      await tester.ensureVisible(audience);
      await tester.tap(audience);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('space-arranger-save')));
      await tester.pumpAndSettle();

      expect(publishes, 1);
      expect(attempted?['about'], isEmpty);
      expect(attempted?['cardOrder'], isNot(contains('about')));
      expect(find.byKey(const ValueKey('space-arranger')), findsOneWidget);
      expect(
        find.textContaining('previous version may still be visible'),
        findsOneWidget,
      );
      expect(state.shareSpaceProfile, isTrue);
      expect(state.visitorSpaceCards, contains(SpaceCardKind.about));
      expect(state.spaceIntro, 'This is currently public.');
      expect(notifications, 0);
      expect(persists, 0);
    },
  );

  testWidgets(
    'live privacy save blocks duplicates and commits only after server ack',
    (tester) async {
      final state = GameState()
        ..reduceMotion = true
        ..roomCode = 'ABC234'
        ..shareSpaceProfile = true
        ..spaceIntro = 'This is currently public.';
      final response = Completer<RoomPublishResult>();
      var publishes = 0;
      var persists = 0;
      var notifications = 0;
      state.addListener(() => notifications++);

      await _pumpMe(
        tester,
        state,
        () => persists++,
        onPublishRoom: (target, {required code}) {
          publishes++;
          expect(code, 'ABC234');
          final display = roomDisplay(
            target,
            visitorProfileSharingEnabled: true,
          );
          expect(display['about'], isEmpty);
          return response.future;
        },
      );
      await _openArranger(tester);

      final audience = find.byKey(const ValueKey('space-card-share-about'));
      await tester.ensureVisible(audience);
      await tester.tap(audience);
      await tester.pump();
      final save = find.byKey(const ValueKey('space-arranger-save'));
      await tester.tap(save);
      await tester.pump();

      expect(find.text('Updating visitor page\u2026'), findsOneWidget);
      expect(publishes, 1);
      expect(notifications, 0);
      expect(persists, 0);
      expect(state.visitorSpaceCards, contains(SpaceCardKind.about));

      await tester.tap(save);
      await tester.pump();
      expect(publishes, 1);

      response.complete(const RoomPublishResult.success('DEF234'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('space-arranger')), findsNothing);
      expect(state.visitorSpaceCards, isNot(contains(SpaceCardKind.about)));
      expect(state.roomCode, 'DEF234');
      expect(persists, 1);
    },
  );

  testWidgets('owner-only layout changes do not wait for room publication', (
    tester,
  ) async {
    final state = GameState()
      ..reduceMotion = true
      ..roomCode = 'ABC234'
      ..shareSpaceProfile = true;
    var publishes = 0;
    var persists = 0;

    await _pumpMe(
      tester,
      state,
      () => persists++,
      onPublishRoom: (_, {required code}) async {
        publishes++;
        return RoomPublishResult.success(code);
      },
    );
    await _openArranger(tester);

    final rightNowToggle = find.byKey(
      const ValueKey('space-card-toggle-rightNow'),
    );
    await tester.ensureVisible(rightNowToggle);
    await tester.pump();
    await tester.tap(rightNowToggle);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('space-arranger-save')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('space-arranger')), findsNothing);
    expect(state.hiddenSpaceCards, contains(SpaceCardKind.rightNow));
    expect(publishes, 0);
    expect(persists, 1);
  });

  testWidgets('failed shared-name publish leaves the old public name intact', (
    tester,
  ) async {
    final state = GameState()
      ..reduceMotion = true
      ..playerName = 'Old name'
      ..roomCode = 'ABC234'
      ..shareSpaceProfile = true;
    final response = Completer<RoomPublishResult>();
    var publishes = 0;
    var persists = 0;

    await _pumpMe(
      tester,
      state,
      () => persists++,
      onPublishRoom: (target, {required code}) {
        publishes++;
        expect(code, 'ABC234');
        final display = roomDisplay(target, visitorProfileSharingEnabled: true);
        expect(display['displayName'], 'New name');
        return response.future;
      },
    );

    await tester.tap(find.byTooltip('Change your name'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('space-name-field')),
      'New name',
    );
    await tester.tap(find.text('Save name'));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('space-name-publish-busy')),
      findsOneWidget,
    );
    expect(state.playerName, 'Old name');
    expect(publishes, 1);

    response.complete(
      const RoomPublishResult.failed(RoomPublishFailure.timedOut),
    );
    await tester.pumpAndSettle();

    expect(state.playerName, 'Old name');
    expect(persists, 0);
    expect(
      find.byKey(const ValueKey('space-name-publish-error')),
      findsOneWidget,
    );
    expect(find.textContaining('previous version'), findsOneWidget);
  });

  testWidgets(
    'start over waits for confirmed erasure and keeps failures open',
    (tester) async {
      final state = GameState()..reduceMotion = true;
      final firstAttempt = Completer<String?>();
      var attempts = 0;

      await _pumpMe(
        tester,
        state,
        () {},
        onReset: () {
          attempts++;
          return attempts == 1 ? firstAttempt.future : Future.value(null);
        },
      );

      final startOver = find.text('start over');
      await tester.scrollUntilVisible(
        startOver,
        420,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(startOver);
      await tester.pumpAndSettle();
      await tester.tap(startOver);
      await tester.pumpAndSettle();

      await tester.tap(find.text('ERASE EVERYTHING'));
      await tester.pump();

      expect(find.text('Start completely over?'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(attempts, 1);

      firstAttempt.complete('Local photo erasure could not be confirmed.');
      await tester.pumpAndSettle();

      expect(find.text('Start completely over?'), findsOneWidget);
      expect(
        find.text('Local photo erasure could not be confirmed.'),
        findsOneWidget,
      );

      await tester.tap(find.text('ERASE EVERYTHING'));
      await tester.pumpAndSettle();

      expect(find.text('Start completely over?'), findsNothing);
      expect(
        find.text(
          'Everything on this device was erased. Your blank room is ready.',
        ),
        findsOneWidget,
      );
      expect(attempts, 2);
    },
  );
}
