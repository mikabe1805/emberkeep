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

  @override
  Future<void> dispose() async => calls.add('dispose');

  @override
  Future<void> pause() async => calls.add('pause');

  @override
  Future<void> setVolume(double volume) async {}

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

  setUp(() => Clock.freeze(DateTime.utc(2026, 9, 1, 14)));
  tearDown(Clock.reset);

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
          onFinished: () {},
          onHonor: () {},
          onCancel: () {},
        ),
      ),
    );

    expect(music.enabled, isFalse);
    expect(music.shouldPlay, isFalse);
    expect(
      find.text('optional · tap for the peaceful focus theme'),
      findsOneWidget,
    );

    await tester.tap(find.text('FOCUS MUSIC'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(music.enabled, isFalse);
    expect(music.sessionEnabled, isTrue);
    expect(music.shouldPlay, isTrue);
    expect(
      find.text('meditation theme · tap anytime to quiet'),
      findsOneWidget,
    );
    expect(transport.calls.single, 'start:music/focus-meditation.m4a');

    await tester.tap(find.text('FOCUS MUSIC'));
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
          onFinished: () {},
          onHonor: () {},
          onCancel: () {},
        ),
      ),
    );

    await tester.tap(find.text('FOCUS MUSIC'));
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
