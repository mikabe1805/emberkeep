import 'dart:ui' as ui;

import 'package:emberkeep/audio.dart';
import 'package:emberkeep/background_music.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/main_room_music.dart';
import 'package:emberkeep/tokens.dart';
import 'package:emberkeep/widgets/timer_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _capture = bool.fromEnvironment('CAPTURE_FOCUS_ROOM');

final class _MusicTransport implements BackgroundMusicTransport {
  final calls = <String>[];
  var started = false;
  var failVolumeOnce = false;

  @override
  Future<void> dispose() async => calls.add('dispose');

  @override
  Future<void> pause() async => calls.add('pause');

  @override
  Future<void> setVolume(double volume) async {
    if (failVolumeOnce) {
      failVolumeOnce = false;
      throw StateError('temporary volume failure');
    }
  }

  @override
  Future<void> startOrResumeLoop(String asset, {required double volume}) async {
    calls.add('${started ? 'resume' : 'start'}:$asset');
    started = true;
  }
}

final class _MainMusic implements MainRoomMusicPlayback {
  bool enabled = false;
  bool foreground = true;

  @override
  bool get isPlaying => enabled && foreground;

  @override
  Future<void> dispose() async => enabled = false;

  @override
  Future<void> retryAfterUserGesture() async {}

  @override
  Future<void> setEnabled(bool value) async => enabled = value;

  @override
  Future<void> setForeground(bool value) async => foreground = value;
}

BackgroundMusicController _music(_MusicTransport transport) =>
    BackgroundMusicController(transport: transport, mainMusic: _MainMusic());

void main() {
  setUpAll(() async {
    if (!_capture) return;
    TestWidgetsFlutterBinding.ensureInitialized();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    final fraunces = FontLoader('Fraunces')
      ..addFont(rootBundle.load('assets/google_fonts/Fraunces-SemiBold.ttf'))
      ..addFont(rootBundle.load('assets/google_fonts/Fraunces-Bold.ttf'));
    final inter = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/google_fonts/Inter-Regular.ttf'))
      ..addFont(rootBundle.load('assets/google_fonts/Inter-Medium.ttf'))
      ..addFont(rootBundle.load('assets/google_fonts/Inter-SemiBold.ttf'))
      ..addFont(rootBundle.load('assets/google_fonts/Inter-Bold.ttf'));
    final mono = FontLoader('JetBrainsMono')
      ..addFont(
        rootBundle.load('assets/google_fonts/JetBrainsMono-SemiBold.ttf'),
      );
    await Future.wait([
      icons.load(),
      fraunces.load(),
      inter.load(),
      mono.load(),
    ]);
  });

  setUp(() {
    Clock.freeze(DateTime.utc(2026, 9, 1, 14));
    Sfx.instance.debugResetForTesting();
    Sfx.instance.debugBypassPlayback = true;
  });
  tearDown(() {
    Clock.reset();
    Sfx.instance.debugResetForTesting();
  });

  testWidgets('a gesture inside Focus recovers its own music without a cue', (
    tester,
  ) async {
    final transport = _MusicTransport()..failVolumeOnce = true;
    final music = _music(transport);
    await tester.pumpWidget(
      MaterialApp(
        home: TimerOverlay(
          questTitle: 'Read one chapter',
          minutes: 25,
          musicController: music,
          startReady: false,
          onFinished: () {},
          onHonor: () {},
          onCancel: () {},
        ),
      ),
    );
    final cues = <String>[];
    Sfx.instance.debugOnPlay = cues.add;
    final toggle = find.byKey(const Key('focus-music-toggle'));
    await tester.ensureVisible(toggle);
    await tester.pump();
    final contact = await tester.startGesture(tester.getCenter(toggle));
    await tester.pump();
    await contact.cancel();
    await tester.pump();
    expect(cues, isEmpty);
    expect(music.shouldPlay, isFalse);

    await tester.tap(toggle);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(cues, ['select']);
    expect(
      transport.calls.where((call) => call.startsWith('start:')),
      hasLength(1),
    );

    await tester.tapAt(const Offset(780, 20));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(
      transport.calls.where((call) => call.startsWith('resume:')),
      hasLength(1),
    );
    expect(
      transport.calls.where((call) => call.startsWith('start:')),
      hasLength(1),
    );
    expect(cues, ['select'], reason: 'music unlock itself stays silent');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 300));
    await music.dispose();
  });

  testWidgets('Focus music has one toggle semantics action and one cue', (
    tester,
  ) async {
    final transport = _MusicTransport();
    final music = _music(transport);
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: TimerOverlay(
          questTitle: 'Read one chapter',
          minutes: 25,
          musicController: music,
          startReady: false,
          onFinished: () {},
          onHonor: () {},
          onCancel: () {},
        ),
      ),
    );
    final cues = <String>[];
    Sfx.instance.debugOnPlay = cues.add;
    const label = 'Turn meditation music on for this focus session';
    final nodes = tester.semantics.simulatedAccessibilityTraversal().where(
      (candidate) => candidate.getSemanticsData().label.contains(label),
    );
    expect(nodes, hasLength(1));
    final node = nodes.single;

    final data = node.getSemanticsData();
    expect(data.hasAction(ui.SemanticsAction.tap), isTrue);
    expect(data.flagsCollection.isButton, isTrue);
    expect(data.flagsCollection.isToggled, ui.Tristate.isFalse);

    node.owner!.performAction(node.id, ui.SemanticsAction.tap);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));

    expect(music.shouldPlay, isTrue);
    expect(cues, ['select']);
    final enabledNode = tester.semantics
        .simulatedAccessibilityTraversal()
        .singleWhere(
          (candidate) => candidate.getSemanticsData().label.contains(
            'Turn meditation music off for this focus session',
          ),
        );
    expect(
      enabledNode.getSemanticsData().flagsCollection.isToggled,
      ui.Tristate.isTrue,
    );
    semantics.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 300));
    await music.dispose();
  });

  testWidgets('Focus music is optional and can be quieted in one tap', (
    tester,
  ) async {
    final transport = _MusicTransport();
    final music = _music(transport);

    await tester.pumpWidget(
      MaterialApp(
        home: TimerOverlay(
          questTitle: 'Read one chapter',
          minutes: 25,
          musicController: music,
          startReady: false,
          onFinished: () {},
          onHonor: () {},
          onCancel: () {},
        ),
      ),
    );

    expect(music.enabled, isFalse);
    expect(music.shouldPlay, isFalse);
    expect(find.text('Optional - just for this session'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('focus-music-toggle')));
    await tester.tap(find.byKey(const Key('focus-music-toggle')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(music.enabled, isFalse);
    expect(music.sessionEnabled, isTrue);
    expect(music.shouldPlay, isTrue);
    expect(find.text('ON'), findsOneWidget);
    expect(transport.calls.single, 'start:music/focus-meditation.m4a');

    await tester.ensureVisible(find.byKey(const Key('focus-music-toggle')));
    await tester.tap(find.byKey(const Key('focus-music-toggle')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(music.enabled, isFalse);
    expect(music.shouldPlay, isFalse);
    expect(music.sessionMuted, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 300));
    expect(music.sessionEnabled, isFalse);
    expect(music.sessionMuted, isFalse);
    await music.dispose();
  });

  testWidgets('Focus quiet preserves and restores a saved global choice', (
    tester,
  ) async {
    final transport = _MusicTransport();
    final music = _music(transport);
    await music.setEnabled(true);
    await tester.pump(const Duration(milliseconds: 300));

    await tester.pumpWidget(
      MaterialApp(
        home: TimerOverlay(
          questTitle: 'Meditate',
          minutes: 5,
          musicController: music,
          startReady: false,
          onFinished: () {},
          onHonor: () {},
          onCancel: () {},
        ),
      ),
    );

    await tester.ensureVisible(find.byKey(const Key('focus-music-toggle')));
    await tester.tap(find.byKey(const Key('focus-music-toggle')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(music.enabled, isTrue);
    expect(music.sessionMuted, isTrue);
    expect(music.isPlaying, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 300));
    expect(music.enabled, isTrue);
    expect(music.sessionMuted, isFalse);
    expect(music.isPlaying, isTrue);
    await music.dispose();
  });

  testWidgets('opens Ready without counting down or finishing', (tester) async {
    var verified = 0;
    final openedAt = Clock.now();

    await tester.pumpWidget(
      MaterialApp(
        home: TimerOverlay(
          questTitle: 'Sketch one object',
          minutes: 10,
          onFinished: () => verified++,
          onHonor: () {},
          onCancel: () {},
        ),
      ),
    );

    expect(find.text('READY'), findsOneWidget);
    expect(find.text('10:00'), findsOneWidget);
    expect(find.text('Start 10 minutes'), findsOneWidget);

    Clock.freeze(openedAt.add(const Duration(hours: 2)));
    await tester.pump(const Duration(seconds: 2));

    expect(verified, 0);
    expect(find.text('READY'), findsOneWidget);
    expect(find.text('10:00'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('explicit Start creates the wall-clock countdown', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var verified = 0;
    final openedAt = Clock.now();

    await tester.pumpWidget(
      MaterialApp(
        home: TimerOverlay(
          questTitle: 'Sketch one object',
          minutes: 1,
          onFinished: () => verified++,
          onHonor: () {},
          onCancel: () {},
        ),
      ),
    );

    expect(
      find.text('A 1-minute session, ready when you are.'),
      findsOneWidget,
    );
    final readyClock = tester.semantics
        .simulatedAccessibilityTraversal()
        .singleWhere(
          (node) => node.getSemanticsData().label.contains('1:00, ready'),
        );
    expect(readyClock.getSemanticsData().flagsCollection.isLiveRegion, isFalse);
    await tester.ensureVisible(find.byKey(const Key('timer-start')));
    await tester.tap(find.byKey(const Key('timer-start')));
    await tester.pump();
    expect(find.text('IN SESSION'), findsOneWidget);
    expect(find.byKey(const Key('timer-start')), findsNothing);
    expect(find.text('Your 1-minute session is in progress.'), findsOneWidget);
    expect(find.text('A 1-minute session, ready when you are.'), findsNothing);
    final runningClock = tester.semantics
        .simulatedAccessibilityTraversal()
        .singleWhere(
          (node) => node.getSemanticsData().label.contains(
            '1:00 remaining, session in progress',
          ),
        );
    expect(
      runningClock.getSemanticsData().flagsCollection.isLiveRegion,
      isFalse,
    );

    Clock.freeze(openedAt.add(const Duration(seconds: 59)));
    await tester.pump(const Duration(seconds: 1));
    expect(verified, 0);
    expect(find.text('0:01'), findsOneWidget);

    Clock.freeze(openedAt.add(const Duration(minutes: 1)));
    await tester.pump(const Duration(seconds: 1));
    expect(verified, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    semantics.dispose();
  });

  testWidgets('honor completion never also reports verified completion', (
    tester,
  ) async {
    var honor = 0;
    var verified = 0;
    final openedAt = Clock.now();

    await tester.pumpWidget(
      MaterialApp(
        home: TimerOverlay(
          questTitle: 'Sketch one object',
          minutes: 1,
          onFinished: () => verified++,
          onHonor: () => honor++,
          onCancel: () {},
        ),
      ),
    );

    await tester.ensureVisible(find.byKey(const Key('timer-honor')));
    await tester.tap(find.byKey(const Key('timer-honor')));
    await tester.pump();
    Clock.freeze(openedAt.add(const Duration(minutes: 5)));
    await tester.pump(const Duration(seconds: 2));

    expect(honor, 1);
    expect(verified, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('back cancels a running session without a result', (
    tester,
  ) async {
    var cancelled = 0;
    var honor = 0;
    var verified = 0;
    final openedAt = Clock.now();

    await tester.pumpWidget(
      MaterialApp(
        home: TimerOverlay(
          questTitle: 'Sketch one object',
          minutes: 1,
          onFinished: () => verified++,
          onHonor: () => honor++,
          onCancel: () => cancelled++,
        ),
      ),
    );

    await tester.ensureVisible(find.byKey(const Key('timer-start')));
    await tester.tap(find.byKey(const Key('timer-start')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('timer-back')));
    await tester.tap(find.byKey(const Key('timer-back')));
    await tester.pump();
    Clock.freeze(openedAt.add(const Duration(minutes: 5)));
    await tester.pump(const Duration(seconds: 2));

    expect(cancelled, 1);
    expect(honor, 0);
    expect(verified, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'Ready music choice stays silent until the opted session starts',
    (tester) async {
      final transport = _MusicTransport();
      final music = _music(transport);

      await tester.pumpWidget(
        MaterialApp(
          home: TimerOverlay(
            questTitle: 'Sketch one object',
            minutes: 10,
            musicController: music,
            onFinished: () {},
            onHonor: () {},
            onCancel: () {},
          ),
        ),
      );

      expect(music.sessionActive, isFalse);
      expect(transport.calls, isEmpty);
      await tester.ensureVisible(find.byKey(const Key('focus-music-toggle')));
      await tester.tap(find.byKey(const Key('focus-music-toggle')));
      await tester.pump(const Duration(milliseconds: 60));
      expect(music.sessionActive, isFalse);
      expect(transport.calls, isEmpty);

      await tester.ensureVisible(find.byKey(const Key('timer-start')));
      await tester.tap(find.byKey(const Key('timer-start')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(music.sessionActive, isTrue);
      expect(music.sessionEnabled, isTrue);
      expect(
        transport.calls.where((call) => call.startsWith('start:')),
        hasLength(1),
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 300));
      expect(music.sessionActive, isFalse);
      expect(music.sessionEnabled, isFalse);
      await music.dispose();
    },
  );

  testWidgets('resume completes one started session exactly once', (
    tester,
  ) async {
    var verified = 0;
    final openedAt = Clock.now();

    await tester.pumpWidget(
      MaterialApp(
        home: TimerOverlay(
          questTitle: 'Sketch one object',
          minutes: 1,
          onFinished: () => verified++,
          onHonor: () {},
          onCancel: () {},
        ),
      ),
    );

    await tester.ensureVisible(find.byKey(const Key('timer-start')));
    await tester.tap(find.byKey(const Key('timer-start')));
    await tester.pump();
    Clock.freeze(openedAt.add(const Duration(minutes: 2)));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 2));

    expect(verified, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('live goal context is optional and hides when absent', (
    tester,
  ) async {
    Widget overlay({String? goal, String? guidance, String? note}) =>
        MaterialApp(
          home: TimerOverlay(
            questTitle: 'Sketch one object',
            minutes: 10,
            goalTitle: goal,
            guidance: guidance,
            note: note,
            onFinished: () {},
            onHonor: () {},
            onCancel: () {},
          ),
        );

    await tester.pumpWidget(overlay());
    expect(find.byKey(const Key('timer-goal-title')), findsNothing);
    expect(find.byKey(const Key('timer-guidance')), findsNothing);
    expect(find.byKey(const Key('timer-note')), findsNothing);

    await tester.pumpWidget(
      overlay(
        goal: 'Learn to sketch',
        guidance: 'Compare width and height before adding detail.',
        note: 'Start with the silhouette.',
      ),
    );
    await tester.pump();
    expect(find.text('LEARN TO SKETCH'), findsOneWidget);
    expect(
      find.text('Compare width and height before adding detail.'),
      findsOneWidget,
    );
    expect(find.text('Start with the silhouette.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final visual in const [
    (name: '430x932', size: Size(430, 932), textScale: 1.0),
    (name: '320x568_1_3x', size: Size(320, 568), textScale: 1.3),
  ]) {
    testWidgets('Focus room visual ${visual.name}', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = visual.size;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final music = _music(_MusicTransport());

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: Palette.parchment,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Palette.xp,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
          ),
          home: MediaQuery(
            data: MediaQueryData(
              size: visual.size,
              textScaler: TextScaler.linear(visual.textScale),
            ),
            child: TimerOverlay(
              questTitle: 'Read one chapter',
              minutes: 25,
              musicController: music,
              onFinished: () {},
              onHonor: () {},
              onCancel: () {},
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('25:00'), findsOneWidget);
      if (_capture) {
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/focus_room_music_${visual.name}.png'),
        );
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 300));
      await music.dispose();
    });
  }
}
