import 'dart:async';

import 'package:emberkeep/audio.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/cloud.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/screens/me.dart';
import 'package:emberkeep/screens/whats_new.dart';
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
  bool spaceDiscoveryEnabled = false,
  Future<void> Function()? onManageDiscovery,
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
    onRemovePrivateServiceIdentity: () async => null,
    visitorPhotoSharingEnabled: visitorPhotoSharingEnabled,
    visitorProfileSharingEnabled: visitorProfileSharingEnabled,
    spaceDiscoveryEnabled: spaceDiscoveryEnabled,
    onManageDiscovery: onManageDiscovery,
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
  bool spaceDiscoveryEnabled = false,
  bool systemReduceMotion = false,
  Future<void> Function()? onManageDiscovery,
}) async {
  tester.view.physicalSize = _phoneSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  final page = _mePage(
    state,
    onPersist,
    onPublishRoom: onPublishRoom,
    onReset: onReset,
    visitorPhotoSharingEnabled: visitorPhotoSharingEnabled,
    visitorProfileSharingEnabled: visitorProfileSharingEnabled,
    spaceDiscoveryEnabled: spaceDiscoveryEnabled,
    onManageDiscovery: onManageDiscovery,
  );
  await tester.pumpWidget(
    MaterialApp(
      home: systemReduceMotion
          ? MediaQuery(
              data: MediaQueryData.fromView(
                tester.view,
              ).copyWith(disableAnimations: true),
              child: page,
            )
          : page,
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
  await tester.ensureVisible(title);
  await tester.pumpAndSettle();
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

  testWidgets('fireplace photo is private and disabled before one is chosen', (
    tester,
  ) async {
    final state = GameState()..reduceMotion = true;

    await _pumpMe(tester, state, () {});
    await _openArranger(tester);

    final toggle = find.byKey(const ValueKey('room-photo-share-toggle'));
    expect(toggle, findsOneWidget);
    final tile = tester.widget<SwitchListTile>(toggle);
    expect(tile.value, isFalse);
    expect(tile.onChanged, isNull);
    expect(find.text('PRIVATE'), findsOneWidget);
    expect(
      find.text(
        'Choose a room photo first. It will start private on this device.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('an existing fireplace copy needs confirmation to share again', (
    tester,
  ) async {
    final state = GameState()
      ..reduceMotion = true
      ..spaceRoomPhotoPath =
          'shared_rooms/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/ABC234/room/ABCDEFGHIJKLMNOPQRSTUV';
    var persists = 0;

    await _pumpMe(tester, state, () => persists++);
    await _openArranger(tester);

    final toggle = find.byKey(const ValueKey('room-photo-share-toggle'));
    await tester.ensureVisible(toggle);
    expect(
      find.text('Room visitors can still see it until you save.'),
      findsOneWidget,
    );
    await tester.tap(toggle);
    await tester.pumpAndSettle();

    expect(state.shareRoomPhoto, isFalse);
    expect(find.text('Show this photo in your shared room?'), findsOneWidget);
    expect(find.textContaining('code, link, or Discover'), findsOneWidget);
    await tester.tap(find.text('KEEP PRIVATE'));
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(toggle).value, isFalse);

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-share-room-photo')));
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
    expect(find.text('Room visitors can see the shared copy.'), findsOneWidget);
    expect(state.shareRoomPhoto, isFalse);

    await tester.tap(find.byKey(const ValueKey('space-arranger-save')));
    await tester.pumpAndSettle();

    expect(state.shareRoomPhoto, isTrue);
    expect(state.spaceRoomPhotoPath, isNotEmpty);
    expect(persists, 1);
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

  testWidgets('a fresh private owner can open Discover settings from Me', (
    tester,
  ) async {
    final state = GameState()..reduceMotion = true;
    var opened = 0;

    await _pumpMe(
      tester,
      state,
      () {},
      spaceDiscoveryEnabled: true,
      onManageDiscovery: () async => opened++,
    );

    expect(state.roomCode, isNull);
    expect(state.roomDiscoverable, isFalse);
    final manage = find.byKey(const ValueKey('space-page-manage-discovery'));
    await tester.scrollUntilVisible(
      manage,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(manage);
    await tester.pump();
    expect(manage, findsOneWidget);
    expect(find.text('PRIVATE PAGE\nSHARING SETTINGS'), findsOneWidget);

    await tester.tap(manage);
    await tester.pump();
    expect(opened, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('discoverable My Space keeps its private-card status readable', (
    tester,
  ) async {
    final state = GameState()
      ..reduceMotion = true
      ..roomDiscoverable = true;

    await _pumpMe(tester, state, () {}, spaceDiscoveryEnabled: true);

    final status = find.byKey(
      const ValueKey('space-profile-visibility-status'),
    );
    expect(find.text('IN DISCOVER\nMANAGE LISTING'), findsOneWidget);
    expect(tester.getSize(status).width, lessThanOrEqualTo(200));
    expect(find.text('MY SPACE'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ambient light selection visibly updates and persists in state', (
    tester,
  ) async {
    final state = GameState()
      ..reduceMotion = true
      ..level = 5;

    await _pumpMe(tester, state, () {});
    final sea = find.text('Sea Cave');
    await tester.scrollUntilVisible(
      sea,
      420,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(sea);
    await tester.pump();

    expect(find.text('AMBIENT LIGHT'), findsOneWidget);
    expect(find.text('Walnut Night'), findsWidgets);
    await tester.tap(sea);
    await tester.pump();

    expect(state.canvasTheme, 'sea');
    expect(find.text('NOW LIT BY'), findsOneWidget);
    expect(find.text('Sea Cave'), findsWidgets);
    final preview = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('me-theme-ambient')),
    );
    final decoration = preview.decoration! as ShapeDecoration;
    final colors = (decoration.gradient! as LinearGradient).colors;
    expect(colors, const [Color(0xFF101A1C), Color(0xFF162428)]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ambient light changes the Me canvas and hero treatment', (
    tester,
  ) async {
    final state = GameState()
      ..reduceMotion = true
      ..level = 5;

    await _pumpMe(tester, state, () {});
    final canvas = find.byKey(const ValueKey('luxe-custom-ambient-canvas'));
    final walnut = tester.widget<AnimatedContainer>(canvas);
    final walnutColors =
        (walnut.decoration! as BoxDecoration).gradient! as LinearGradient;
    expect(walnutColors.colors, const [Color(0xFF191210), Color(0xFF231A20)]);

    state.setTheme('sea');
    await tester.pump();

    final sea = tester.widget<AnimatedContainer>(canvas);
    final seaColors =
        (sea.decoration! as BoxDecoration).gradient! as LinearGradient;
    expect(seaColors.colors, const [Color(0xFF101A1C), Color(0xFF162428)]);
    expect(seaColors.colors, isNot(walnutColors.colors));

    final expectedHeroFade = const Color(0xFF162428).withValues(alpha: 0.30);
    final heroFades = tester
        .widgetList<DecoratedBox>(
          find.descendant(
            of: find.byKey(const ValueKey('luxe-custom-hero-transform')),
            matching: find.byType(DecoratedBox),
          ),
        )
        .map((box) => box.decoration)
        .whereType<BoxDecoration>()
        .map((decoration) => decoration.gradient)
        .whereType<LinearGradient>();
    expect(
      heroFades.any((gradient) => gradient.colors.contains(expectedHeroFade)),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('system Reduce Motion parks the ambient-light preview', (
    tester,
  ) async {
    final state = GameState()..level = 5;
    await _pumpMe(tester, state, () {}, systemReduceMotion: true);

    final sea = find.text('Sea Cave');
    await tester.scrollUntilVisible(
      sea,
      420,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(sea);
    await tester.pump();
    await tester.tap(sea);
    await tester.pump();

    final preview = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('me-theme-ambient')),
    );
    expect(preview.duration, Duration.zero);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Me names a pending Discover cleanup instead of claiming listed',
    (tester) async {
      final state = GameState()
        ..reduceMotion = true
        ..setRoomCode('ABC234')
        ..setRoomDiscoverable(true)
        ..markRoomDiscoveryRemovalPending('ABC234');

      await _pumpMe(tester, state, () {}, spaceDiscoveryEnabled: true);

      expect(find.text('Closing Discover · ABC234'), findsOneWidget);
      expect(find.textContaining('Discoverable ·'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

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
      const ValueKey('space-card-audience-pinnedMoments-mutuals'),
    );
    await tester.scrollUntilVisible(
      sharePinned,
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(ReorderableListView), const Offset(0, -120));
    await tester.pump();
    await tester.tap(sharePinned);
    await tester.pump();
    await _moveRightNowBeforeAbout(tester);

    await tester.tap(find.byKey(const ValueKey('space-arranger-cancel')));
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
    final mutualPinned = find.byKey(
      const ValueKey('space-card-audience-pinnedMoments-mutuals'),
    );
    await tester.scrollUntilVisible(
      mutualPinned,
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(ReorderableListView), const Offset(0, -120));
    await tester.pump();
    await tester.tap(mutualPinned);
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
    expect(
      state.spaceAudienceFor(SpaceCardKind.pinnedMoments),
      SpaceAudience.mutuals,
    );
    expect(state.spaceAudienceFor(SpaceCardKind.about), SpaceAudience.onlyMe);
    expect(
      state.spaceAudienceFor(SpaceCardKind.rightNow),
      SpaceAudience.onlyMe,
    );
    expect(state.spaceIntro, 'I am building a kinder semester.');
    expect(notifications, 1);
    expect(persists, 1);
  });

  testWidgets('each card offers Only me, Mutuals, and Anyone', (tester) async {
    final state = GameState()..reduceMotion = true;
    var persists = 0;

    await _pumpMe(tester, state, () => persists++);
    await _openArranger(tester);

    for (final audience in SpaceAudience.values) {
      expect(
        find.byKey(ValueKey('space-card-audience-about-${audience.name}')),
        findsOneWidget,
      );
    }

    await tester.tap(find.byKey(const ValueKey('space-profile-share-toggle')));
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('space-card-audience-about-anyone')),
    );
    await tester.pump();
    expect(
      find.textContaining('Anyone who opens your space can see it.'),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('space-card-audience-about-mutuals')),
    );
    await tester.pump();
    expect(
      find.textContaining('Nothing is shared until you and another keeper'),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('space-card-audience-about-anyone')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('space-arranger-save')));
    await tester.pumpAndSettle();

    expect(state.shareSpaceProfile, isTrue);
    expect(state.spaceAudienceFor(SpaceCardKind.about), SpaceAudience.anyone);
    expect(find.text('ANYONE'), findsOneWidget);
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
    await tester.pumpAndSettle();
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
      state.spaceCardAudiences[SpaceCardKind.about] = SpaceAudience.anyone;
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
          attempted = spaceProfileDisplay(
            target,
            audience: SpaceAudience.anyone,
          );
          expect(code, 'ABC234');
          return const RoomPublishResult.failed(RoomPublishFailure.network);
        },
      );
      await _openArranger(tester);

      final audience = find.byKey(
        const ValueKey('space-card-audience-about-onlyMe'),
      );
      await tester.ensureVisible(audience);
      await tester.tap(audience);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('space-arranger-save')));
      await tester.pumpAndSettle();

      expect(publishes, 1);
      // An intentionally open page with no public cards still publishes a
      // bounded empty projection so visitors see the authored empty state.
      expect(attempted?['about'], '');
      expect(attempted?['cardOrder'], isNot(contains('about')));
      expect(find.byKey(const ValueKey('space-arranger')), findsOneWidget);
      expect(
        find.textContaining('previous version may still be visible'),
        findsOneWidget,
      );
      expect(state.shareSpaceProfile, isTrue);
      expect(state.spaceAudienceFor(SpaceCardKind.about), SpaceAudience.anyone);
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
      state.spaceCardAudiences[SpaceCardKind.about] = SpaceAudience.anyone;
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
          final display = spaceProfileDisplay(
            target,
            audience: SpaceAudience.anyone,
          );
          expect(display['about'], '');
          return response.future;
        },
      );
      await _openArranger(tester);

      final audience = find.byKey(
        const ValueKey('space-card-audience-about-onlyMe'),
      );
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
      expect(state.spaceAudienceFor(SpaceCardKind.about), SpaceAudience.anyone);

      await tester.tap(save);
      await tester.pump();
      expect(publishes, 1);

      response.complete(const RoomPublishResult.success('DEF234'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('space-arranger')), findsNothing);
      expect(state.spaceAudienceFor(SpaceCardKind.about), SpaceAudience.onlyMe);
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
    state.spaceCardAudiences[SpaceCardKind.about] = SpaceAudience.anyone;
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
    await tester.scrollUntilVisible(
      rightNowToggle,
      180,
      scrollable: find.byType(Scrollable).first,
    );
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
    state.spaceCardAudiences[SpaceCardKind.about] = SpaceAudience.anyone;
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
        final display = spaceProfileDisplay(
          target,
          audience: SpaceAudience.anyone,
        );
        expect(display['displayName'], 'New name');
        return response.future;
      },
    );

    await tester.scrollUntilVisible(
      find.byTooltip('Change your name'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Change your name'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('space-name-audience-note')),
      findsOneWidget,
    );
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

  testWidgets('Room Guide remains available from Me settings', (tester) async {
    final state = GameState()
      ..onboarded = true
      ..reduceMotion = true;
    await _pumpMe(tester, state, () {});

    final guide = find.text('ROOM GUIDE');
    await tester.scrollUntilVisible(
      guide,
      420,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(guide);
    await tester.pump();
    await tester.tap(guide);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Room Guide'), findsOneWidget);
    expect(find.text('Help for Today'), findsOneWidget);
    expect(find.textContaining('messy room'), findsOneWidget);
  });

  testWidgets("What's New remains available from Me settings", (tester) async {
    final state = GameState()
      ..onboarded = true
      ..reduceMotion = true;
    await _pumpMe(tester, state, () {});

    final whatsNew = find.text("WHAT'S NEW");
    await tester.scrollUntilVisible(
      whatsNew,
      420,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(whatsNew);
    await tester.pump();
    await tester.tap(whatsNew);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byType(WhatsNewScreen), findsOneWidget);
    expect(find.text('Your semester has a place in Plans.'), findsOneWidget);
    expect(find.text('VERSION 1.0.4 · BUILD 28'), findsOneWidget);
  });
}
