import 'package:emberkeep/audio.dart';
import 'package:emberkeep/cloud.dart';
import 'package:emberkeep/content/routines.dart';
import 'package:emberkeep/discovery.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/screens/discover_spaces.dart';
import 'package:emberkeep/screens/hearth_circle.dart';
import 'package:emberkeep/screens/me.dart';
import 'package:emberkeep/screens/visit_room.dart';
import 'package:emberkeep/social.dart';
import 'package:emberkeep/tokens.dart';
import 'package:emberkeep/widgets/workout_flow.dart';
import 'package:emberkeep/widgets/home_room.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

const _capture = bool.fromEnvironment('CAPTURE_SPACE_DISCOVERY');

DiscoverableSpaceSummary _space({
  required String code,
  required String title,
  required int level,
  required String wall,
  required String floor,
  required String skin,
  required String window,
  required int bucket,
  String publicName = '',
}) => DiscoverableSpaceSummary(
  code: code,
  buildTitle: title,
  level: level,
  wall: wall,
  floor: floor,
  skin: skin,
  window: window,
  bucket: bucket,
  ownerKey: discoveryOwnerKey('owner-$code'),
  publicName: publicName,
);

Future<void> _captureScreen(
  WidgetTester tester,
  Widget screen,
  String name,
) async {
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(backgroundColor: const Color(0xFF1B1411), body: screen),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await expectLater(
    find.byType(Scaffold).first,
    matchesGoldenFile('goldens/$name.png'),
  );
}

Map<String, dynamic> _sharedRoom(DiscoverableSpaceSummary space) => {
  'v': 5,
  'name': 'Fellow keeper',
  'title': space.buildTitle,
  'level': space.level,
  'wall': space.wall,
  'floor': space.floor,
  'skin': space.skin,
  'window': space.window,
  'furniture': <String>['hearth', 'lamp', 'shelf'],
  'memories': 18,
  'awake': true,
  'todayLit': true,
  'weather': 'steady',
  'focusKind': 'none',
  'focusUntil': 0,
  'profileVisible': false,
  'uid': 'owner-${space.code}',
};

Widget _meScreen(GameState state) => MePage(
  state: state,
  quests: [workoutLauncherQuest()],
  onPersist: () {},
  onPublishRoom: (target, {required code}) async =>
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
  spaceDiscoveryEnabled: true,
);

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
    await preloadHomeRoomAssets();
    GoogleFonts.config.allowRuntimeFetching = false;
  });
  setUp(() => Sfx.instance.soundEnabled = false);
  tearDown(() => Sfx.instance.soundEnabled = true);

  testWidgets('space discovery visual evidence', (tester) async {
    if (!_capture) return;
    tester.view.devicePixelRatio = 3;
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.binding.setSurfaceSize(null);
    });

    final state = GameState()
      ..onboarded = true
      ..playerName = 'Alex'
      ..level = 18
      ..totalXp = 4280
      ..embers = 340
      ..reduceMotion = true
      ..soundEnabled = false
      ..wallStyle = 'wall_walnut'
      ..floorStyle = 'floor_oak'
      ..windowScene = 'moon'
      ..creatureSkin = 'sunstone'
      ..roomCode = 'DAY234'
      ..roomDiscoverable = true
      ..roomDiscoveryName = 'Alex';
    state.stats[Stat.str] = 88;
    state.stats[Stat.vit] = 72;
    state.stats[Stat.intl] = 116;
    state.stats[Stat.foc] = 94;
    state.stats[Stat.soc] = 61;
    state.stats[Stat.dis] = 103;

    await _captureScreen(
      tester,
      _meScreen(state),
      'space_discovery_me_1290x2796',
    );

    final privateState = GameState.fromJson(state.toJson())
      ..roomCode = null
      ..roomDiscoverable = false
      ..roomDiscoveryName = '';
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFF1B1411),
          body: _meScreen(privateState),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    final privateManage = find.byKey(
      const ValueKey('space-page-manage-discovery'),
    );
    await tester.scrollUntilVisible(
      privateManage,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(privateManage);
    await tester.pump();
    await expectLater(
      find.byType(Scaffold).first,
      matchesGoldenFile(
        'goldens/space_discovery_private_me_controls_1290x2796.png',
      ),
    );

    await _captureScreen(
      tester,
      DiscoverSpacesScreen(
        state: privateState,
        onPersist: () {},
        onManageOwnListing: () async {},
        fetchSpaces: () async => const <DiscoverableSpaceSummary>[],
        publicDiscoveryNamesEnabled: true,
      ),
      'space_discovery_empty_private_1290x2796',
    );

    privateState.level = 18;
    privateState.canvasTheme = 'walnut';
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFF1B1411),
          body: _meScreen(privateState),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    final ambientPreview = find.byKey(
      const ValueKey('me-theme-ambient-preview'),
    );
    await tester.scrollUntilVisible(
      ambientPreview,
      430,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(ambientPreview);
    await tester.drag(find.byType(ListView).first, const Offset(0, 110));
    await tester.pump();
    await expectLater(
      find.byType(Scaffold).first,
      matchesGoldenFile('goldens/ambient_light_walnut_1290x2796.png'),
    );
    privateState.setTheme('sea');
    await tester.pump();
    await expectLater(
      find.byType(Scaffold).first,
      matchesGoldenFile('goldens/ambient_light_sea_1290x2796.png'),
    );

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () => showShareSpaceDialog(
                  context,
                  code: 'DAY234',
                  ownerName: 'Alex',
                  discoverable: true,
                  publicDiscoveryName: 'Alex',
                  onDiscoverableChanged: (_) async => true,
                  onPublicDiscoveryNameChanged: (_) async =>
                      DiscoveryPublicNameUpdate.saved,
                  onPreview: () {},
                  onStop: () async => true,
                ),
                child: const Text('Open share'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open share'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(Dialog),
      matchesGoldenFile('goldens/space_discovery_share_1290x2796.png'),
    );
    Navigator.of(tester.element(find.text('DONE'))).pop();
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () => showShareSpaceDialog(
                  context,
                  code: 'DAY234',
                  discoveryFirst: true,
                  discoverable: false,
                  onDiscoverableChanged: (_) async => true,
                  onPublicDiscoveryNameChanged: (_) async =>
                      DiscoveryPublicNameUpdate.saved,
                  onPreview: () {},
                  onStop: () async => true,
                ),
                child: const Text('Manage discovery'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Manage discovery'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(Dialog),
      matchesGoldenFile('goldens/space_discovery_manage_1290x2796.png'),
    );
    Navigator.of(tester.element(find.byType(Dialog))).pop();
    await tester.pumpAndSettle();

    final spaces = [
      _space(
        code: 'ARC234',
        title: 'DEEP CURRENT',
        level: 21,
        wall: 'wall_archive',
        floor: 'floor_cherry',
        skin: 'moon_pearl',
        window: 'aurora',
        bucket: 1,
        publicName: 'Rowan',
      ),
      _space(
        code: 'GRN234',
        title: 'EVERGREEN',
        level: 14,
        wall: 'wall_conservatory',
        floor: 'floor_maple',
        skin: 'sea_glass',
        window: 'rain',
        bucket: 2,
        publicName: 'Juniper',
      ),
      _space(
        code: 'WRM234',
        title: 'STEADY HAND',
        level: 9,
        wall: 'wall_walnut',
        floor: 'floor_oak',
        skin: 'sunstone',
        window: 'moon',
        bucket: 3,
      ),
    ];
    await _captureScreen(
      tester,
      DiscoverSpacesScreen(
        state: state,
        onPersist: () {},
        fetchSpaces: () async => spaces,
        fetchRoom: (_) async => null,
        publicDiscoveryNamesEnabled: false,
      ),
      'space_discovery_directory_generated_only_1290x2796',
    );

    await _captureScreen(
      tester,
      DiscoverSpacesScreen(
        state: state,
        onPersist: () {},
        fetchSpaces: () async => spaces,
        fetchRoom: (_) async => null,
        publicDiscoveryNamesEnabled: true,
      ),
      'space_discovery_directory_1290x2796',
    );

    await _captureScreen(
      tester,
      VisitRoomScreen(
        room: _sharedRoom(spaces.first),
        code: spaces.first.code,
        themeId: state.canvasTheme,
        lively: false,
        localState: state,
        onPersist: () {},
        discoveryPublicName: spaces.first.publicName,
        onReportDiscoverableSpace: (_, _) async => true,
      ),
      'space_discovery_visitor_1290x2796',
    );

    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('space-discovery-report-capture'),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: VisitRoomScreen(
            room: _sharedRoom(spaces.first),
            code: spaces.first.code,
            themeId: state.canvasTheme,
            lively: false,
            localState: state,
            onPersist: () {},
            discoveryPublicName: spaces.first.publicName,
            onReportDiscoverableSpace: (_, _) async => true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('discover-report-or-hide')));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const ValueKey('space-discovery-report-capture')),
      matchesGoldenFile('goldens/space_discovery_report_1290x2796.png'),
    );
    Navigator.of(tester.element(find.text('CANCEL'))).pop();
    await tester.pumpAndSettle();

    final circleState = GameState()
      ..onboarded = true
      ..reduceMotion = true
      ..soundEnabled = false;
    final circleSpaces = <String, DiscoverableSpaceSummary>{};
    for (var i = 0; i < 7; i++) {
      final digit = i + 2;
      final code = 'AB${digit}23$digit';
      final space = _space(
        code: code,
        title: i.isEven ? 'STEADY HAND' : 'OPEN HEARTH',
        level: 8 + i,
        wall: i.isEven ? 'wall_walnut' : 'wall_archive',
        floor: 'floor_oak',
        skin: 'ember_amber',
        window: 'moon',
        bucket: 20 + i,
        publicName: 'Keeper ${i + 1}',
      );
      if (circleState.addCircleCode(code, publicName: space.publicName)) {
        circleSpaces[code] = space;
      }
    }
    await _captureScreen(
      tester,
      HearthCircleScreen(
        state: circleState,
        onPersist: () {},
        roomFetcher: (code) async => _sharedRoom(circleSpaces[code]!),
      ),
      'space_discovery_unlimited_circle_1290x2796',
    );

    await _captureScreen(
      tester,
      WorkoutFlow(
        state: state,
        recommended: routines.first,
        onClose: () {},
        onFinish:
            ({
              required routine,
              required verified,
              required endedEarly,
              required workMovesDone,
            }) {},
      ),
      'guided_workout_picker_1290x2796',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
