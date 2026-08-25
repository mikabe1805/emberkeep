import 'dart:async';

import 'package:emberkeep/audio.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/cloud.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/screens/calendar.dart';
import 'package:emberkeep/screens/hearth_circle.dart';
import 'package:emberkeep/screens/me.dart';
import 'package:emberkeep/social.dart';
import 'package:emberkeep/tokens.dart' show Stat;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

const _phoneSize = Size(320, 568);
const _captureLargeText = bool.fromEnvironment('CAPTURE_LARGE_TEXT');
const _captureKey = ValueKey('large-text-capture');

Future<void> _pumpAtLargestText(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = _phoneSize;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = 2;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => RepaintBoundary(
        key: _captureKey,
        child: child ?? const SizedBox.shrink(),
      ),
      home: home,
    ),
  );
  await tester.pump();
}

Future<void> _capture(WidgetTester tester, String name) async {
  if (!_captureLargeText) return;
  await expectLater(
    find.byKey(_captureKey),
    matchesGoldenFile('goldens/large_text_$name.png'),
  );
}

Finder _ancestorOfType(Finder child, Type type) => find
    .ancestor(
      of: child,
      matching: find.byWidgetPredicate((widget) => widget.runtimeType == type),
    )
    .first;

void _expectComfortableTarget(WidgetTester tester, Finder finder) {
  final size = tester.getSize(finder);
  expect(size.width, greaterThanOrEqualTo(44));
  expect(size.height, greaterThanOrEqualTo(44));
}

Map<String, dynamic> _sharedRoom() => {
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
  'profileVisible': false,
  'displayName': '',
  'about': '',
  'featuredGoals': const <String>[],
  'v': 3,
};

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    final fraunces = FontLoader('Fraunces')
      ..addFont(rootBundle.load('assets/google_fonts/Fraunces-Bold.ttf'))
      ..addFont(rootBundle.load('assets/google_fonts/Fraunces-SemiBold.ttf'))
      ..addFont(
        rootBundle.load('assets/google_fonts/Fraunces-SemiBoldItalic.ttf'),
      );
    final inter = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/google_fonts/Inter-Regular.ttf'))
      ..addFont(rootBundle.load('assets/google_fonts/Inter-Medium.ttf'))
      ..addFont(rootBundle.load('assets/google_fonts/Inter-SemiBold.ttf'))
      ..addFont(rootBundle.load('assets/google_fonts/Inter-Bold.ttf'))
      ..addFont(rootBundle.load('assets/google_fonts/Inter-Italic.ttf'));
    final mono = FontLoader('JetBrainsMono')
      ..addFont(
        rootBundle.load('assets/google_fonts/JetBrainsMono-SemiBold.ttf'),
      )
      ..addFont(rootBundle.load('assets/google_fonts/JetBrainsMono-Bold.ttf'));
    await Future.wait([
      icons.load(),
      fraunces.load(),
      inter.load(),
      mono.load(),
    ]);
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    Sfx.instance.soundEnabled = false;
    Clock.freeze(DateTime(2026, 8, 3, 10));
  });

  tearDown(() {
    Sfx.instance.soundEnabled = true;
    Clock.reset();
  });

  testWidgets('My Space and Personalize reflow at 320x568 with 2x text', (
    tester,
  ) async {
    final state = GameState()
      ..reduceMotion = true
      ..playerName = 'A deliberately long chosen name';
    state.goals.addAll([
      Goal(
        title: 'Make the room feel welcoming for everyone',
        stat: Stat.dis,
        target: 10,
      ),
      Goal(
        title: 'Call family and listen without rushing',
        stat: Stat.soc,
        target: 10,
      ),
      Goal(
        title: 'Finish a careful draft of the essay',
        stat: Stat.intl,
        target: 10,
      ),
    ]);
    state.setSpaceProfile(
      intro:
          'This is a longer introduction that should remain readable without colliding with the controls around it.',
      goals: state.goals.map((goal) => goal.title),
    );

    await _pumpAtLargestText(
      tester,
      Scaffold(
        body: MePage(
          state: state,
          quests: const [],
          onPersist: () {},
          onPublishRoom: (_, {required code}) async =>
              RoomPublishResult.success(code),
          onAddQuest: (_) => true,
          onExport: () async => true,
          onImport: (_) async => true,
          onReset: () async => null,
          onNotifyChanged: () async {},
          onEnableCloud: () async => null,
          onLinkAccount: (_, _) async => null,
          onSignIn: (_, _) async => null,
          onSignOut: () async {},
          onDeleteAccount: (_) async => null,
          onRemovePrivateServiceIdentity: () async => null,
          visitorProfileSharingEnabled: false,
        ),
      ),
    );
    expect(tester.takeException(), isNull);

    final pageScroll = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('EDIT SPACE'),
      260,
      scrollable: pageScroll,
    );
    await tester.pump();
    expect(tester.takeException(), isNull);

    final editButton = _ancestorOfType(find.text('EDIT SPACE'), TextButton);
    _expectComfortableTarget(tester, editButton);
    final status = find.byKey(
      const ValueKey('space-profile-visibility-status'),
    );
    expect(tester.getRect(status).overlaps(tester.getRect(editButton)), false);
    await _capture(tester, 'my_space_320x568_2x');

    await tester.tap(editButton);
    await tester.pumpAndSettle();
    expect(find.text('Personalize your space'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final localOnly = find.byKey(const ValueKey('space-profile-local-only'));
    await tester.ensureVisible(localOnly);
    await tester.pump();
    expect(localOnly, findsOneWidget);
    expect(
      find.byKey(const ValueKey('space-profile-share-toggle')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
    await _capture(tester, 'personalize_dialog_320x568_2x');

    final save = find.byKey(const ValueKey('space-arranger-save'));
    await tester.ensureVisible(save);
    await tester.pump();
    _expectComfortableTarget(tester, save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text('Personalize your space'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('My Space audience controls reflow at 320x568 with 2x text', (
    tester,
  ) async {
    final state = GameState()
      ..reduceMotion = true
      ..roomCode = 'ABC234'
      ..playerName = 'A deliberately long chosen name';
    state.goals.add(
      Goal(
        title: 'Make the room welcoming without rushing the work',
        stat: Stat.soc,
        target: 8,
      ),
    );
    state.setSpacePage(
      order: defaultSpaceCardOrder,
      hidden: const <SpaceCardKind>{},
      audiences: const {
        SpaceCardKind.about: SpaceAudience.anyone,
        SpaceCardKind.rightNow: SpaceAudience.mutuals,
        SpaceCardKind.pinnedMoments: SpaceAudience.onlyMe,
        SpaceCardKind.thisSeason: SpaceAudience.anyone,
      },
      intro:
          'A long introduction that should remain readable while its audience choices stack vertically.',
      featuredGoalTitles: const [
        'Make the room welcoming without rushing the work',
      ],
      seasonText:
          'Trying to make the quiet parts of the week feel intentional.',
      profilePhotoNoteId: null,
      seasonPhotoNoteId: null,
      shareProfilePhoto: false,
      shareSeasonPhoto: false,
      shareProfile: true,
    );

    await _pumpAtLargestText(
      tester,
      Scaffold(
        body: MePage(
          state: state,
          quests: const [],
          onPersist: () {},
          onPublishRoom: (_, {required code}) async =>
              RoomPublishResult.success(code),
          onAddQuest: (_) => true,
          onExport: () async => true,
          onImport: (_) async => true,
          onReset: () async => null,
          onNotifyChanged: () async {},
          onEnableCloud: () async => null,
          onLinkAccount: (_, _) async => null,
          onSignIn: (_, _) async => null,
          onSignOut: () async {},
          onDeleteAccount: (_) async => null,
          onRemovePrivateServiceIdentity: () async => null,
          onManageDiscovery: () async {},
          visitorProfileSharingEnabled: true,
          spaceDiscoveryEnabled: true,
        ),
      ),
    );

    final open = find.byKey(const ValueKey('space-page-open-arranger'));
    await tester.scrollUntilVisible(
      open,
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(open);
    await tester.pump();
    await tester.tap(open);
    await tester.pumpAndSettle();

    final anyone = find.byKey(
      const ValueKey('space-card-audience-about-anyone'),
    );
    await tester.scrollUntilVisible(
      anyone,
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(anyone);
    await tester.pump();

    expect(
      find.byKey(const ValueKey('space-card-audience-about-onlyMe')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('space-card-audience-about-mutuals')),
      findsOneWidget,
    );
    expect(anyone, findsOneWidget);
    expect(tester.takeException(), isNull);
    await _capture(tester, 'profile_audiences_320x568_2x');
  });

  testWidgets(
    'Circle empty and populated states keep actions reachable at 2x',
    (tester) async {
      final semanticsHandle = tester.ensureSemantics();
      final state = GameState()..reduceMotion = true;
      await _pumpAtLargestText(
        tester,
        HearthCircleScreen(
          state: state,
          onPersist: () {},
          roomFetcher: (_) async => _sharedRoom(),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);

      final list = find.descendant(
        of: find.byType(CustomScrollView).first,
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        find.text('ADD A SPACE'),
        260,
        scrollable: list,
      );
      await tester.pump();
      final emptyAdd = _ancestorOfType(
        find.text('ADD A SPACE'),
        GestureDetector,
      );
      _expectComfortableTarget(tester, emptyAdd);
      expect(tester.takeException(), isNull);
      await _capture(tester, 'circle_empty_320x568_2x');

      await tester.tap(emptyAdd);
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('visit-space-code')),
        'ABC234',
      );
      await tester.tap(find.byKey(const Key('visit-space-submit')));
      await tester.pumpAndSettle();
      expect(state.hearthCircleCodes, contains('ABC234'));
      expect(tester.takeException(), isNull);

      // Let the send-your-code-back snackbar retire before dragging — its
      // tap target sits over the list's centre while visible.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, 900));
      await tester.pump();
      await tester.scrollUntilVisible(
        find.text('VISIT'),
        220,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      final visit = _ancestorOfType(find.text('VISIT'), GestureDetector);
      final note = _ancestorOfType(find.text('SEND A NOTE'), GestureDetector);
      _expectComfortableTarget(tester, visit);
      _expectComfortableTarget(tester, note);
      expect(
        tester
            .getSemantics(find.bySemanticsLabel(RegExp('VISIT')))
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await _capture(tester, 'circle_populated_320x568_2x');
      semanticsHandle.dispose();
    },
  );

  testWidgets('Visit loading and error states remain in reach at 2x', (
    tester,
  ) async {
    final fetch = Completer<Map<String, dynamic>?>();
    await _pumpAtLargestText(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => FilledButton(
            onPressed: () =>
                promptForSharedRoom(context, fetcher: (_) => fetch.future),
            child: const Text('Open visit'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open visit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('visit-space-code')), 'ABC');
    final submit = find.byKey(const Key('visit-space-submit'));
    _expectComfortableTarget(tester, submit);
    await tester.tap(submit);
    await tester.pump();
    final error = find.byKey(const Key('visit-space-error'));
    expect(error, findsOneWidget);
    expect(
      tester.getRect(error).overlaps(tester.getRect(submit)),
      false,
      reason: 'validation copy must not paint underneath the dialog actions',
    );
    expect(tester.takeException(), isNull);
    await _capture(tester, 'visit_error_320x568_2x');

    await tester.enterText(find.byKey(const Key('visit-space-code')), 'ABC234');
    await tester.tap(submit);
    await tester.pump();
    expect(find.byKey(const Key('visit-space-loading')), findsOneWidget);
    expect(find.text('Visit a space'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _capture(tester, 'visit_loading_320x568_2x');

    fetch.completeError(StateError('offline'));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('reach that space'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Share dialog keeps explicit Done and share actions reachable', (
    tester,
  ) async {
    await _pumpAtLargestText(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => FilledButton(
            onPressed: () => showShareSpaceDialog(
              context,
              code: 'ABC234',
              onStop: () async => true,
            ),
            child: const Text('Open share'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open share'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final invite = find.byKey(const Key('share-space-invite'));
    final copy = find.byKey(const Key('share-space-copy-code'));
    final done = find.byKey(const Key('share-space-done'));
    _expectComfortableTarget(tester, invite);
    _expectComfortableTarget(tester, copy);
    _expectComfortableTarget(tester, done);
    await _capture(tester, 'share_dialog_320x568_2x');

    await tester.ensureVisible(done);
    await tester.pump();
    await tester.tap(done);
    await tester.pumpAndSettle();
    expect(find.text('Your space is live'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Calendar selected-day Journal remains readable and openable', (
    tester,
  ) async {
    const entryText =
        'Mom and I walked by the river after dinner and talked about the week.';
    final entry = Note(at: DateTime(2026, 8, 3, 8, 30), text: entryText);
    final state = GameState()
      ..reduceMotion = true
      ..journal = [entry];
    await _pumpAtLargestText(
      tester,
      Scaffold(
        body: CalendarPage(state: state, quests: const [], onAdd: (_) => true),
      ),
    );
    expect(tester.takeException(), isNull);

    final pageScroll = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text(entryText),
      260,
      scrollable: pageScroll,
    );
    await tester.pump();
    expect(find.text('JOURNAL'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final entryTarget = find.byKey(
      ValueKey('calendar-journal-entry-${entry.id}'),
    );
    _expectComfortableTarget(tester, entryTarget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.button == true &&
            widget.properties.label == 'Read journal entry. $entryText',
      ),
      findsOneWidget,
    );
    await _capture(tester, 'calendar_journal_320x568_2x');
    expect(tester.takeException(), isNull);
  });
}
