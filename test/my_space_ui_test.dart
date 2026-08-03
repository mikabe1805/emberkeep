import 'package:emberkeep/audio.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/screens/me.dart';
import 'package:emberkeep/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _phoneSize = Size(430, 932);

Widget _mePage(GameState state, VoidCallback onPersist) => Scaffold(
  body: MePage(
    state: state,
    quests: const [],
    onPersist: onPersist,
    onAddQuest: (_) => true,
    onExport: () async => true,
    onImport: (_) async => true,
    onReset: () {},
    onNotifyChanged: () async {},
    onEnableCloud: () async => null,
    onLinkAccount: (_, _) async => null,
    onSignIn: (_, _) async => null,
    onSignOut: () async {},
    onDeleteAccount: (_) async => null,
  ),
);

Future<void> _pumpMe(
  WidgetTester tester,
  GameState state,
  VoidCallback onPersist,
) async {
  tester.view.physicalSize = _phoneSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(MaterialApp(home: _mePage(state, onPersist)));
  await tester.pump();
}

Future<void> _openArranger(WidgetTester tester) async {
  final open = find.byKey(const ValueKey('space-page-open-arranger'));
  await tester.scrollUntilVisible(
    open,
    320,
    scrollable: find.byType(Scrollable).first,
  );
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
      seasonPhotoNoteId: null,
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
    var persists = 0;
    var notifications = 0;
    state.addListener(() => notifications++);

    await _pumpMe(tester, state, () => persists++);
    await _openArranger(tester);
    await _collapseAbout(tester);

    await tester.tap(find.byKey(const ValueKey('space-card-toggle-rightNow')));
    await tester.pump();
    await _moveRightNowBeforeAbout(tester);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('space-arranger')), findsNothing);
    expect(state.spaceCardOrder, originalOrder);
    expect(state.hiddenSpaceCards, originalHidden);
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
    expect(state.spaceIntro, 'I am building a kinder semester.');
    expect(notifications, 1);
    expect(persists, 1);
  });
}
