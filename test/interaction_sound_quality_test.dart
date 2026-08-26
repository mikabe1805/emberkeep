import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:emberkeep/audio.dart';
import 'package:flutter_test/flutter_test.dart';

const _roles = ['open', 'select', 'navigate', 'place'];

void main() {
  test('runtime preserves every phone-approved X master byte for byte', () {
    for (final role in _roles) {
      for (var take = 1; take <= 5; take++) {
        final runtime = File('assets/sfx/room/ordinary/$role/$take.wav');
        final approved = File(
          'design/audits/2026-08-20/room-c-gesture-v3/'
          'roles/c-clasp-family/$role/$take.wav',
        );
        expect(
          runtime.readAsBytesSync(),
          orderedEquals(approved.readAsBytesSync()),
        );

        final wave = _readWave(runtime);
        expect(wave.audioFormat, 1);
        expect(wave.channels, 1);
        expect(wave.sampleRate, 48000);
        expect(wave.bitsPerSample, 24);
        expect(wave.durationMs, closeTo(60, 0.01));
        expect(wave.peak, lessThanOrEqualTo(0.56));
        expect(wave.tailRms / wave.peak, lessThan(0.001));
      }
    }
  });

  test('runtime preserves every phone-approved material lane master', () {
    // Phone-approved 2026-08-21 (room-material-shading-v1 gestures, shipped
    // as the render-polish-v2 masters after the owner's final verdict:
    // "it sounds wonderful! very well done").
    const lanes = [
      'slate/select',
      'slate/navigate',
      'slate/place',
      'page/navigate',
      'page/open',
      'glass/select',
      'glass/place',
      'brass/select',
      'brass/place',
    ];
    for (final lane in lanes) {
      for (var take = 1; take <= 3; take++) {
        final runtime = File('assets/sfx/room/materials/$lane/$take.wav');
        final approved = File(
          'design/audits/2026-08-21/room-material-shading-v2-polish/'
          'materials/$lane/$take.wav',
        );
        expect(
          runtime.readAsBytesSync(),
          orderedEquals(approved.readAsBytesSync()),
        );
        final wave = _readWave(runtime);
        expect(wave.audioFormat, 1);
        expect(wave.channels, 1);
        expect(wave.sampleRate, 48000);
        expect(wave.bitsPerSample, 24);
        expect(wave.peak, lessThanOrEqualTo(0.56));
        expect(wave.tailRms / wave.peak, lessThan(0.001));
      }
    }
  });

  test('runtime preserves every phone-approved event master byte for byte', () {
    // Phone-approved 2026-08-21 (room-event-voice-v1 gestures, shipped as the
    // render-polish-v2 masters after the owner's final verdict). The reward
    // tier is the room-derived family, calibrated in-file, played at 1.0.
    const events = [
      'streak',
      'crit',
      'loot',
      'levelup',
      'boing',
      'stat_0',
      'stat_1',
      'stat_2',
      'stat_3',
      'stat_4',
      'stat_5',
    ];
    for (final name in events) {
      final runtime = File('assets/sfx/$name.wav');
      final approved = File(
        'design/audits/2026-08-21/room-event-voice-v2-polish/events/$name.wav',
      );
      expect(
        runtime.readAsBytesSync(),
        orderedEquals(approved.readAsBytesSync()),
      );
      final wave = _readWave(runtime);
      expect(wave.audioFormat, 1);
      expect(wave.channels, 1);
      expect(wave.sampleRate, 48000);
      expect(wave.bitsPerSample, 24);
      // -6 dBFS authoring ceiling plus one 24-bit quantization step.
      expect(wave.peak, lessThanOrEqualTo(0.5012));
    }
  });

  test('runtime preserves every phone-approved Paired Return master', () {
    const tokens = ['d5', 'a5', 'e5'];
    expect(InteractionSoundRouter.pairedReturnAssets, hasLength(60));
    for (final token in tokens) {
      for (final role in _roles) {
        for (var take = 1; take <= 5; take++) {
          final runtime = File(
            'assets/sfx/room/paired_return/$token/$role/$take.wav',
          );
          final approved = File(
            'design/audits/2026-08-20/room-c-melody-v4/'
            'cues/$token/$role/$take.wav',
          );
          expect(
            runtime.readAsBytesSync(),
            orderedEquals(approved.readAsBytesSync()),
          );
          final wave = _readWave(runtime);
          expect(wave.audioFormat, 1);
          expect(wave.channels, 1);
          expect(wave.sampleRate, 48000);
          expect(wave.bitsPerSample, 24);
          expect(wave.durationMs, closeTo(60, 0.01));
          expect(wave.onsetMs, lessThan(1));
        }
      }
    }

    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (final token in tokens) {
      for (final role in _roles) {
        expect(
          pubspec,
          contains('assets/sfx/room/paired_return/$token/$role/'),
        );
      }
    }
    expect(
      File('tool/prepare_web_offline.dart').readAsStringSync(),
      contains('assets/assets/sfx/room/paired_return/'),
    );
  });

  test('runtime preserves the locked completion and its two sources', () {
    const componentNames = [
      'accepted-select-2.wav',
      'answered-detent-natural.wav',
    ];
    for (final name in componentNames) {
      final runtime = File('assets/sfx/room/completion/$name');
      final approved = File(
        'design/audits/2026-08-20/room-c-gesture-v3/locked/$name',
      );
      expect(
        runtime.readAsBytesSync(),
        orderedEquals(approved.readAsBytesSync()),
      );
    }
    final runtimeComposite = File(
      'assets/sfx/room/completion/completion-composite.wav',
    );
    final approvedComposite = File(
      'design/audits/2026-08-20/room-reward-voice-v1/'
      'composites/answered-detent/natural.wav',
    );
    expect(
      runtimeComposite.readAsBytesSync(),
      orderedEquals(approvedComposite.readAsBytesSync()),
    );
    expect(
      sha256.convert(runtimeComposite.readAsBytesSync()).toString(),
      '7caf33eb445f49d63fcaa90fa7d27a3236e67658f5fa4ba5844634a67a0ecad2',
      reason: 'this digest pins the approved Select-2 → +75 ms Detent master',
    );
    final wave = _readWave(runtimeComposite);
    expect(wave.durationMs, closeTo(430, 0.01));
    expect(
      wave.onsetMs,
      lessThan(1),
      reason: 'an audition timeline with leading silence is not an atomic cue',
    );
  });

  test('completion dedupe is scoped to one state transition', () {
    final gate = CompletionSoundGate();
    final first = Object();
    final second = Object();
    final start = DateTime.utc(2026, 8, 20);

    expect(gate.claim(first, at: start), isTrue);
    expect(
      gate.claim(first, at: start.add(const Duration(milliseconds: 80))),
      isFalse,
    );
    expect(
      gate.claim(second, at: start.add(const Duration(milliseconds: 90))),
      isTrue,
      reason: 'a different quest must keep its own completion voice',
    );
    expect(
      gate.claim(first, at: start.add(const Duration(seconds: 2))),
      isTrue,
    );
  });

  test('one global X walk varies takes and softens only rapid taps', () {
    final router = InteractionSoundRouter();
    final start = DateTime.utc(2026, 8, 20);
    final roles = InteractionSound.values;
    final ordinary = <InteractionSoundSelection>[];
    for (var index = 0; index < 6; index++) {
      ordinary.add(
        router.next(
          roles[index % roles.length],
          at: start.add(Duration(milliseconds: 240 * index)),
        )!,
      );
    }
    expect(ordinary.map((item) => item.asset.split('/').last), [
      '1',
      '3',
      '2',
      '4',
      '2',
      '5',
    ]);
    expect(ordinary.map((item) => item.gain), everyElement(1));

    router.resetBurst();
    final rapid = <InteractionSoundSelection>[];
    for (var index = 0; index < 5; index++) {
      rapid.add(
        router.next(
          InteractionSound.open,
          at: start.add(Duration(seconds: 3, milliseconds: 100 * index)),
        )!,
      );
    }
    expect(rapid.map((item) => item.gain), [1, 0.93, 0.93, 0.885, 0.885]);
    expect(
      router.next(
        InteractionSound.select,
        at: start.add(const Duration(seconds: 3, milliseconds: 405)),
      ),
      isNull,
      reason: 'same-action callback duplicates must not voice twice',
    );
  });

  test('the global take walk never repeats across its loop boundary', () {
    final router = InteractionSoundRouter();
    final start = DateTime.utc(2026, 8, 20);
    final takes = <String>[];
    for (var index = 0; index < 40; index++) {
      takes.add(
        router
            .next(
              InteractionSound.navigate,
              at: start.add(Duration(milliseconds: 240 * index)),
            )!
            .asset
            .split('/')
            .last,
      );
    }
    expect(takes.toSet(), {'1', '2', '3', '4', '5'});
    for (var index = 1; index < takes.length; index++) {
      expect(takes[index], isNot(takes[index - 1]));
    }
  });

  test('Paired Return appears only after four well-paced plain actions', () {
    final router = InteractionSoundRouter();
    final screen = Object();
    final start = DateTime.utc(2026, 8, 21);
    final selections = <InteractionSoundSelection>[];
    for (var index = 0; index < 9; index++) {
      selections.add(
        router.next(
          InteractionSound.values[index % InteractionSound.values.length],
          at: start.add(Duration(milliseconds: 350 * index)),
          screenId: screen,
        )!,
      );
    }

    expect(selections.map((selection) => selection.pairedReturnToken), [
      null,
      null,
      null,
      null,
      PairedReturnToken.d5,
      PairedReturnToken.a5,
      PairedReturnToken.e5,
      PairedReturnToken.d5,
      null,
    ]);
    expect(
      selections.take(4).map((selection) => selection.asset),
      everyElement(startsWith('room/ordinary/')),
    );
    expect(
      selections.skip(4).take(4).map((selection) => selection.asset),
      everyElement(startsWith('room/paired_return/')),
    );
  });

  test('duplicate, rapid, and long gaps cannot create melodic catch-up', () {
    final start = DateTime.utc(2026, 8, 21);
    final screen = Object();

    final duplicateRouter = InteractionSoundRouter();
    for (var index = 0; index < 4; index++) {
      duplicateRouter.next(
        InteractionSound.open,
        at: start.add(Duration(milliseconds: 350 * index)),
        screenId: screen,
      );
    }
    expect(
      duplicateRouter.next(
        InteractionSound.open,
        at: start.add(const Duration(milliseconds: 1060)),
        screenId: screen,
      ),
      isNull,
    );
    expect(
      duplicateRouter
          .next(
            InteractionSound.open,
            at: start.add(const Duration(milliseconds: 1400)),
            screenId: screen,
          )!
          .pairedReturnToken,
      PairedReturnToken.d5,
      reason: 'an 18 ms duplicate must not consume or abort phrase state',
    );

    final rapidRouter = InteractionSoundRouter();
    for (var index = 0; index < 4; index++) {
      rapidRouter.next(
        InteractionSound.select,
        at: start.add(Duration(milliseconds: 350 * index)),
        screenId: screen,
      );
    }
    final rapidAbort = rapidRouter.next(
      InteractionSound.select,
      at: start.add(const Duration(milliseconds: 1229)),
      screenId: screen,
    )!;
    expect(rapidAbort.pairedReturnToken, isNull);
    expect(rapidAbort.gain, 0.93);
    for (final atMs in [1579, 1929, 2279, 2629]) {
      expect(
        rapidRouter
            .next(
              InteractionSound.select,
              at: start.add(Duration(milliseconds: atMs)),
              screenId: screen,
            )!
            .pairedReturnToken,
        isNull,
      );
    }
    expect(
      rapidRouter
          .next(
            InteractionSound.select,
            at: start.add(const Duration(milliseconds: 2979)),
            screenId: screen,
          )!
          .pairedReturnToken,
      PairedReturnToken.d5,
      reason: 'a rapid abort requires a completely new four-action run',
    );

    final longGapRouter = InteractionSoundRouter();
    for (var index = 0; index < 4; index++) {
      longGapRouter.next(
        InteractionSound.navigate,
        at: start.add(Duration(milliseconds: 350 * index)),
        screenId: screen,
      );
    }
    expect(
      longGapRouter
          .next(
            InteractionSound.navigate,
            at: start.add(const Duration(milliseconds: 1751)),
            screenId: screen,
          )!
          .pairedReturnToken,
      isNull,
    );
    for (final atMs in [2101, 2451, 2801]) {
      longGapRouter.next(
        InteractionSound.navigate,
        at: start.add(Duration(milliseconds: atMs)),
        screenId: screen,
      );
    }
    expect(
      longGapRouter
          .next(
            InteractionSound.navigate,
            at: start.add(const Duration(milliseconds: 3151)),
            screenId: screen,
          )!
          .pairedReturnToken,
      PairedReturnToken.d5,
      reason: 'a 701 ms pause also requires a new four-action run',
    );
  });

  test('rapid input aborts D5 and preserves the approved gain ladder', () {
    final router = InteractionSoundRouter();
    final screen = Object();
    final start = DateTime.utc(2026, 8, 21);
    for (var index = 0; index < 4; index++) {
      router.next(
        InteractionSound.values[index],
        at: start.add(Duration(milliseconds: 350 * index)),
        screenId: screen,
      );
    }
    expect(
      router
          .next(
            InteractionSound.place,
            at: start.add(const Duration(milliseconds: 1400)),
            screenId: screen,
          )!
          .pairedReturnToken,
      PairedReturnToken.d5,
    );
    final rapid = <InteractionSoundSelection>[];
    for (final atMs in [1520, 1640, 1760, 1880]) {
      rapid.add(
        router.next(
          InteractionSound.select,
          at: start.add(Duration(milliseconds: atMs)),
          screenId: screen,
        )!,
      );
    }
    expect(rapid.map((selection) => selection.gain), [
      0.93,
      0.93,
      0.885,
      0.885,
    ]);
    expect(
      rapid.map((selection) => selection.pairedReturnToken),
      everyElement(isNull),
    );
    expect(
      rapid.map((selection) => selection.asset),
      everyElement(startsWith('room/ordinary/')),
    );
  });

  test('Paired Return is once per screen with a global 90 second cooldown', () {
    final router = InteractionSoundRouter();
    final firstScreen = Object();
    final secondScreen = Object();
    final start = DateTime.utc(2026, 8, 21);

    InteractionSoundSelection eventAt(int milliseconds, Object screen) =>
        router.next(
          InteractionSound.open,
          at: start.add(Duration(milliseconds: milliseconds)),
          screenId: screen,
        )!;

    for (final atMs in [0, 350, 700, 1050]) {
      expect(eventAt(atMs, firstScreen).pairedReturnToken, isNull);
    }
    expect(eventAt(1400, firstScreen).pairedReturnToken, PairedReturnToken.d5);

    for (final atMs in [92400, 92750, 93100, 93450, 93800]) {
      expect(
        eventAt(atMs, firstScreen).pairedReturnToken,
        isNull,
        reason: 'the same long-lived screen gets only one return',
      );
    }

    for (final atMs in [94150, 94500, 94850, 95200]) {
      expect(eventAt(atMs, secondScreen).pairedReturnToken, isNull);
    }
    expect(
      eventAt(95550, secondScreen).pairedReturnToken,
      PairedReturnToken.d5,
      reason: 'another screen may answer only after the global cooldown',
    );
  });

  test('Paired Return eligibility and phrases never cross stable screens', () {
    final start = DateTime.utc(2026, 8, 21);
    final firstScreen = Object();
    final secondScreen = Object();

    final eligibilityRouter = InteractionSoundRouter();
    for (final atMs in [0, 350, 700, 1050]) {
      expect(
        eligibilityRouter
            .next(
              InteractionSound.open,
              at: start.add(Duration(milliseconds: atMs)),
              screenId: firstScreen,
            )!
            .pairedReturnToken,
        isNull,
      );
    }
    expect(
      eligibilityRouter
          .next(
            InteractionSound.open,
            at: start.add(const Duration(milliseconds: 1400)),
            screenId: secondScreen,
          )!
          .pairedReturnToken,
      isNull,
      reason: 'screen B cannot spend screen A\'s four-action eligibility run',
    );
    for (final atMs in [1750, 2100, 2450]) {
      expect(
        eligibilityRouter
            .next(
              InteractionSound.open,
              at: start.add(Duration(milliseconds: atMs)),
              screenId: secondScreen,
            )!
            .pairedReturnToken,
        isNull,
      );
    }
    expect(
      eligibilityRouter
          .next(
            InteractionSound.open,
            at: start.add(const Duration(milliseconds: 2800)),
            screenId: secondScreen,
          )!
          .pairedReturnToken,
      PairedReturnToken.d5,
      reason: 'screen B earns its own return after four plain B actions',
    );

    final phraseRouter = InteractionSoundRouter();
    for (final atMs in [0, 350, 700, 1050]) {
      phraseRouter.next(
        InteractionSound.select,
        at: start.add(Duration(milliseconds: atMs)),
        screenId: firstScreen,
      );
    }
    expect(
      phraseRouter
          .next(
            InteractionSound.select,
            at: start.add(const Duration(milliseconds: 1400)),
            screenId: firstScreen,
          )!
          .pairedReturnToken,
      PairedReturnToken.d5,
    );
    expect(
      phraseRouter
          .next(
            InteractionSound.select,
            at: start.add(const Duration(milliseconds: 1750)),
            screenId: secondScreen,
          )!
          .pairedReturnToken,
      isNull,
      reason: 'A5 cannot follow D5 onto another screen',
    );
    expect(
      phraseRouter
          .next(
            InteractionSound.select,
            at: start.add(const Duration(milliseconds: 2100)),
            screenId: firstScreen,
          )!
          .pairedReturnToken,
      isNull,
      reason: 'returning to screen A cannot catch the interrupted phrase up',
    );
  });

  test('completion interruption clears an unfinished Paired Return', () {
    final router = InteractionSoundRouter();
    final screen = Object();
    final start = DateTime.utc(2026, 8, 21);
    for (var index = 0; index < 4; index++) {
      router.next(
        InteractionSound.open,
        at: start.add(Duration(milliseconds: 350 * index)),
        screenId: screen,
      );
    }
    expect(
      router
          .next(
            InteractionSound.open,
            at: start.add(const Duration(milliseconds: 1400)),
            screenId: screen,
          )!
          .pairedReturnToken,
      PairedReturnToken.d5,
    );
    router.resetBurst();
    expect(
      router
          .next(
            InteractionSound.open,
            at: start.add(const Duration(milliseconds: 1750)),
            screenId: screen,
          )!
          .pairedReturnToken,
      isNull,
    );

    final audio = File('lib/audio.dart').readAsStringSync();
    final completion = _between(
      audio,
      'void playCompletionAccepted(',
      'void playMaterial(',
    );
    expect(
      completion.indexOf('_interactions.resetBurst();'),
      lessThan(completion.indexOf('if (!soundEnabled')),
      reason: 'muted completion must still clear an armed phrase',
    );
  });

  test('legacy muted completion bridge clears an active Paired Return', () {
    final router = InteractionSoundRouter();
    final sfx = Sfx.testing(interactions: router)..soundEnabled = false;
    final screen = Object();
    final start = DateTime.utc(2026, 8, 21);
    for (final atMs in [0, 350, 700, 1050]) {
      router.next(
        InteractionSound.open,
        at: start.add(Duration(milliseconds: atMs)),
        screenId: screen,
      );
    }
    expect(
      router
          .next(
            InteractionSound.open,
            at: start.add(const Duration(milliseconds: 1400)),
            screenId: screen,
          )!
          .pairedReturnToken,
      PairedReturnToken.d5,
    );

    sfx.play('complete');

    expect(
      router
          .next(
            InteractionSound.open,
            at: start.add(const Duration(milliseconds: 1750)),
            screenId: screen,
          )!
          .pairedReturnToken,
      isNull,
      reason: 'the muted legacy bridge must clear A5 before returning',
    );
  });

  test('muted ordinary interactions do not advance Paired Return', () {
    final router = InteractionSoundRouter();
    final sfx = Sfx.testing(interactions: router)..soundEnabled = false;
    final screen = Object();
    final start = DateTime.utc(2026, 8, 21);
    for (var index = 0; index < 5; index++) {
      sfx.playInteraction(
        InteractionSound.open,
        at: start.add(Duration(milliseconds: 350 * index)),
        screenId: screen,
      );
    }

    expect(
      router
          .next(
            InteractionSound.open,
            at: start.add(const Duration(milliseconds: 1750)),
            screenId: screen,
          )!
          .pairedReturnToken,
      isNull,
    );
  });

  test('session ignition breathes in, crests warm, and leaves cleanly', () {
    final fire = _readWave(File('assets/sfx/fire_ignite.wav'));
    expect(fire.audioFormat, 1);
    expect(fire.channels, 2);
    expect(fire.sampleRate, 48000);
    expect(fire.bitsPerSample, 16);
    expect(fire.durationMs, inInclusiveRange(1695, 1705));
    expect(fire.encodedPeak, inInclusiveRange(0.55, 0.58));
    expect(fire.peak, inInclusiveRange(0.43, 0.46));
    expect(fire.onsetMs, inInclusiveRange(340, 430));
    expect(fire.peakAtMs, inInclusiveRange(820, 940));
    expect(fire.stereoSideToMidDb, inInclusiveRange(-11, -8));
    expect(
      fire.rmsBetweenMs(0, 120) / fire.peak,
      lessThan(0.002),
      reason: 'the fire should inhale quietly rather than click on',
    );
    expect(
      fire.rmsBetweenMs(650, 1200) / fire.peak,
      greaterThan(0.2),
      reason: 'the ignition lost its warm physical bloom',
    );
    expect(
      fire.rmsBetweenMs(1350, 1600) / fire.peak,
      lessThan(0.02),
      reason: 'the one-shot ignition should not masquerade as ambience',
    );
    expect(fire.roughness, lessThan(0.002));
  });

  test('runtime ignition remains the user-selected C master', () {
    final runtime = File('assets/sfx/fire_ignite.wav').readAsBytesSync();
    final selected = File(
      'design/audits/2026-08-19/fire-fwoosh-redesign/'
      'fwoosh-c-hearth-bloom.wav',
    ).readAsBytesSync();
    expect(runtime, orderedEquals(selected));

    final generalAuthoring = File(
      'tool/author_fantasy_sfx.py',
    ).readAsStringSync();
    expect(
      generalAuthoring,
      isNot(contains('fire_ignite.wav')),
      reason: 'the interaction generator must not overwrite the hearth master',
    );
  });

  test('one touch has one contact owner before an earned outcome', () {
    String source(String path) =>
        File(path).readAsStringSync().replaceAll('\r\n', '\n');

    final audio = source('lib/audio.dart');
    final mainApp = source('lib/main.dart');
    final shell = source('lib/screens/shell.dart');
    final goals = source('lib/screens/goals.dart');
    final me = source('lib/screens/me.dart');
    final pressable = source('lib/widgets/pressable.dart');
    final questCard = source('lib/widgets/quest_card.dart');
    final quests = source('lib/screens/quests.dart');
    final routines = source('lib/widgets/routine_flows.dart');
    final shop = source('lib/screens/shop.dart');
    final reflection = source('lib/widgets/quick_reflection_sheet.dart');

    expect(audio, contains('void playAfterContact('));
    expect(audio, contains('void playCompletionAccepted('));
    expect(audio, contains("'room/completion/answered-detent-natural'"));
    expect(audio, contains("'room/completion/completion-composite'"));
    expect(
      mainApp,
      contains('navigatorObservers: [roomSoundNavigatorObserver]'),
    );
    expect(shell, contains('Sfx.instance.setInteractionScreen'));
    expect(shell, contains('InteractionSoundScreenScope('));
    expect(
      pressable,
      contains('InteractionSoundScreenScope.maybeScreenIdOf(context)'),
    );
    expect(quests, contains('Sfx.instance.playCompletionAccepted('));
    expect(quests, contains('contactAlreadyPlayed: contactAlreadyPlayed'));
    expect(quests, isNot(contains("playAfterContact('complete')")));
    expect(routines, contains('playCompletionAccepted(transitionId: q)'));
    expect(routines, isNot(contains("play('complete')")));
    expect(quests, contains('alreadyAcknowledged: true'));
    expect(questCard, isNot(contains('soundEnabled:')));
    expect(goals, isNot(contains('soundEnabled:')));
    expect(shell, isNot(contains('soundEnabled:')));
    expect(quests, isNot(contains('_boardCoastingAt')));
    expect(quests, isNot(contains('_trackBoardCoasting')));

    final pointerDown = _between(pressable, 'onPointerDown:', 'onPointerMove:');
    expect(pointerDown, contains('_beginContact();'));
    final contact = _between(
      pressable,
      'void _beginContact()',
      'void _activate()',
    );
    expect(contact, contains('_setDown(true)'));
    expect(contact, contains('_playContactSound()'));
    expect(
      contact.indexOf('_setDown(true)'),
      lessThan(contact.indexOf('_playContactSound()')),
    );
    final pointerMove = _between(pressable, 'onPointerMove:', 'onPointerUp:');
    expect(pointerMove, isNot(contains('_playContactSound')));
    expect(pointerMove, isNot(contains('Sfx.instance')));
    final tapUp = _between(pressable, 'onTapUp: (d)', 'onLongPress:');
    expect(tapUp, contains('widget.onTapUp!(d.globalPosition);'));
    expect(tapUp, isNot(contains('_playContactSound')));
    expect(tapUp, isNot(contains('Sfx.instance')));

    final workoutOpen = _between(
      quests,
      'void _openWorkout',
      'void _finishWorkout',
    );
    expect(workoutOpen, contains('required bool contactAlreadyPlayed'));
    expect(workoutOpen, contains('if (!contactAlreadyPlayed)'));
    expect(workoutOpen, isNot(contains('HapticFeedback')));

    final themeOpen = _between(
      shop,
      'Future<void> _showTheme',
      '@override\n  Widget build',
    );
    expect(themeOpen, isNot(contains('playMaterial')));
    expect(themeOpen, isNot(contains('Haptics.tap')));

    final spaceRail = _between(me, 'class _SpaceRail', 'class _PlateOrnament');
    expect(spaceRail, contains('return Pressable('));
    expect(spaceRail, contains('material: MaterialSound.brass'));
    expect(spaceRail, isNot(contains('GestureDetector(')));

    expect(reflection, isNot(contains('Sfx.instance')));
    expect(reflection, isNot(contains('Haptics.')));
  });

  test('material lanes never replay the identical take back to back', () {
    // The ordinary walk guarantees distinct consecutive variants, but the
    // five-onto-three take fold used to collapse variants (2,5) and (1,4)
    // onto one file — an identical-master repeat on ~3 in 14 pairs.
    final sfx = Sfx.instance;
    sfx.debugResetForTesting();
    sfx.debugBypassPlayback = true;
    final assets = <String>[];
    sfx.debugOnPlayAsset = assets.add;
    addTearDown(sfx.debugResetForTesting);

    // Paced slower than the Paired Return window so only the plain
    // material-shaded walk is exercised.
    var now = DateTime(2026, 8, 25, 12);
    for (var i = 0; i < 42; i++) {
      sfx.playInteraction(
        InteractionSound.navigate,
        at: now,
        material: MaterialSound.stone,
      );
      now = now.add(const Duration(milliseconds: 900));
    }

    expect(assets, hasLength(42));
    expect(assets.first, startsWith('room/materials/slate/navigate/'));
    for (var i = 1; i < assets.length; i++) {
      expect(
        assets[i],
        isNot(assets[i - 1]),
        reason: 'taps ${i - 1}→$i replayed the identical material master',
      );
    }
    expect(assets.toSet(), hasLength(3));
  });

  test('every declared Pressable material/verb pair is a shipped lane', () {
    // A declared material whose lane never shipped falls back silently to
    // wood — the code reads as textured while the phone plays the plain
    // clasp. Declaring one is an authoring error, not a graceful upgrade.
    const materialFolders = {
      'stone': 'slate',
      'parchment': 'page',
      'glass': 'glass',
      'brass': 'brass',
    };
    const shippedLanes = {
      'slate/select',
      'slate/navigate',
      'slate/place',
      'page/navigate',
      'page/open',
      'glass/select',
      'glass/place',
      'brass/select',
      'brass/place',
    };
    final material = RegExp(r'material:\s*MaterialSound\.(\w+)');
    final verb = RegExp(r'interactionSound:\s*InteractionSound\.(\w+)');
    final offenders = <String>[];
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    for (final file in files) {
      final src = file.readAsStringSync().replaceAll('\r\n', '\n');
      for (var at = src.indexOf('Pressable(');
          at >= 0;
          at = src.indexOf('Pressable(', at + 1)) {
        final window = src.substring(
          at,
          math.min(src.length, at + 700),
        );
        final m = material.firstMatch(window);
        final v = verb.firstMatch(window);
        if (m == null || v == null) continue;
        final lane = '${materialFolders[m.group(1)]}/${v.group(1)}';
        if (m.group(1) == 'wood') continue;
        if (!shippedLanes.contains(lane)) {
          offenders.add('${file.path}: $lane');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'Pressables declaring unshipped material lanes (silent '
          'wood fallback): $offenders',
    );
  });

  test('social, discovery, and daybook surfaces wire their verbs', () {
    String source(String path) =>
        File(path).readAsStringSync().replaceAll('\r\n', '\n');

    final discover = source('lib/screens/discover_spaces.dart');
    final social = source('lib/social.dart');
    final me = source('lib/screens/me.dart');
    final memoryCabinet = source('lib/screens/memory_cabinet.dart');

    // Discover: code entry and hidden-space management voice glass; the
    // directory card travels as parchment.
    final enterCode = _between(
      discover,
      'Future<void> _enterCode()',
      'Future<void> _manageOwnListing()',
    );
    expect(enterCode, contains('playMaterial(MaterialSound.glass)'));
    final manageHidden = _between(
      discover,
      'Future<void> _manageHidden()',
      'Future<void> _openCommunityRules(',
    );
    expect(manageHidden, contains('playMaterial(MaterialSound.glass)'));
    final spaceCardAt = discover.indexOf('class _DiscoverableSpaceCard');
    expect(spaceCardAt, isNonNegative);
    expect(
      discover.substring(spaceCardAt),
      contains('material: MaterialSound.parchment'),
    );

    // Share sheet: preview voices glass like its copy siblings; stopping is
    // a glass place; only declines stay silent.
    final preview = _between(
      social,
      "label: 'PREVIEW PUBLIC VIEW'",
      "key: const ValueKey('share-space-discovery-setting')",
    );
    expect(preview, contains('playMaterial(MaterialSound.glass)'));
    final stopSharing = _between(
      social,
      'Future<void> _stopSharing()',
      'Future<void> _changeDiscovery(',
    );
    expect(stopSharing, contains('playMaterial(MaterialSound.glass)'));
    expect(stopSharing, contains('InteractionSound.place'));

    // My Space: the arranger opens as parchment travel; the name flow is a
    // glass dialog whose save seats as place.
    final personalize = _between(
      me,
      'Future<void> _personalizeSpace(',
      'class ',
    );
    expect(personalize, contains('playMaterial(MaterialSound.parchment)'));
    final changeName = _between(
      me,
      'Future<void> _changePlayerName(',
      'Future<void> _personalizeSpace(',
    );
    expect(changeName, contains('playMaterial(MaterialSound.glass)'));
    expect(changeName, contains('InteractionSound.place'));

    // Brass stays exclusive to gold; the keepsake cabinet has none.
    expect(memoryCabinet, isNot(contains('MaterialSound.brass')));

    // Each daybook editor's Close answers with the glass detent.
    for (final path in [
      'lib/daybook/widgets/daybook_event_actions.dart',
      'lib/daybook/widgets/daybook_add_choice_dialog.dart',
      'lib/daybook/widgets/daybook_task_editor.dart',
      'lib/daybook/widgets/daybook_event_editor.dart',
    ]) {
      final src = source(path);
      final closeAt = src.indexOf("tooltip: 'Close'");
      expect(closeAt, isNonNegative, reason: '$path lost its Close button');
      expect(
        src.substring(closeAt, math.min(src.length, closeAt + 300)),
        contains('playMaterial(MaterialSound.glass)'),
        reason: '$path Close must not dismiss silently',
      );
    }
  });
}

String _between(String source, String start, String end) {
  final startAt = source.indexOf(start);
  final endAt = source.indexOf(end, startAt + start.length);
  expect(startAt, isNonNegative, reason: 'missing start marker: $start');
  expect(endAt, greaterThan(startAt), reason: 'missing end marker: $end');
  return source.substring(startAt, endAt);
}

_Wave _readWave(File file) {
  final bytes = file.readAsBytesSync();
  final data = ByteData.sublistView(bytes);
  expect(_fourCc(bytes, 0), 'RIFF', reason: '${file.path} is not RIFF');
  expect(_fourCc(bytes, 8), 'WAVE', reason: '${file.path} is not WAVE');

  int? audioFormat;
  int? channels;
  int? sampleRate;
  int? bitsPerSample;
  Uint8List? pcm;
  var offset = 12;
  while (offset + 8 <= bytes.length) {
    final id = _fourCc(bytes, offset);
    final size = data.getUint32(offset + 4, Endian.little);
    final body = offset + 8;
    expect(body + size, lessThanOrEqualTo(bytes.length));
    if (id == 'fmt ') {
      expect(size, greaterThanOrEqualTo(16));
      audioFormat = data.getUint16(body, Endian.little);
      channels = data.getUint16(body + 2, Endian.little);
      sampleRate = data.getUint32(body + 4, Endian.little);
      bitsPerSample = data.getUint16(body + 14, Endian.little);
    } else if (id == 'data') {
      pcm = Uint8List.sublistView(bytes, body, body + size);
    }
    offset = body + size + (size.isOdd ? 1 : 0);
  }

  expect(audioFormat, isNotNull, reason: '${file.path} has no fmt chunk');
  expect(pcm, isNotNull, reason: '${file.path} has no data chunk');
  final pcmData = ByteData.sublistView(pcm!);
  expect(
    bitsPerSample,
    anyOf(16, 24),
    reason: '${file.path} must be 16-bit or 24-bit PCM',
  );
  final bytesPerSample = bitsPerSample! ~/ 8;
  final interleavedSamples = <int>[];
  for (var i = 0; i + bytesPerSample - 1 < pcm.length; i += bytesPerSample) {
    if (bitsPerSample == 16) {
      interleavedSamples.add(pcmData.getInt16(i, Endian.little));
      continue;
    }
    var value =
        pcmData.getUint8(i) |
        (pcmData.getUint8(i + 1) << 8) |
        (pcmData.getUint8(i + 2) << 16);
    if ((value & 0x800000) != 0) value -= 0x1000000;
    interleavedSamples.add((value / 256).round());
  }
  expect(channels, isNotNull, reason: '${file.path} has no channel count');
  final channelCount = channels!;
  expect(
    interleavedSamples.length % channelCount,
    0,
    reason: '${file.path} contains an incomplete PCM frame',
  );
  final frameCount = interleavedSamples.length ~/ channelCount;
  final samples = List<int>.generate(frameCount, (frame) {
    final frameOffset = frame * channelCount;
    var sum = 0;
    for (var channel = 0; channel < channelCount; channel++) {
      sum += interleavedSamples[frameOffset + channel];
    }
    return (sum / channelCount).round();
  });
  expect(samples, isNotEmpty, reason: '${file.path} contains no samples');

  return _Wave(
    audioFormat: audioFormat!,
    channels: channelCount,
    sampleRate: sampleRate!,
    bitsPerSample: bitsPerSample,
    samples: samples,
    interleavedSamples: interleavedSamples,
  );
}

String _fourCc(Uint8List bytes, int offset) =>
    String.fromCharCodes(bytes.sublist(offset, offset + 4));

class _Wave {
  const _Wave({
    required this.audioFormat,
    required this.channels,
    required this.sampleRate,
    required this.bitsPerSample,
    required this.samples,
    required this.interleavedSamples,
  });

  final int audioFormat;
  final int channels;
  final int sampleRate;
  final int bitsPerSample;
  final List<int> samples;
  final List<int> interleavedSamples;

  double get durationMs => samples.length / sampleRate * 1000;

  double get peak =>
      samples.map((sample) => sample.abs()).reduce(math.max) / 32768;

  double get encodedPeak =>
      interleavedSamples.map((sample) => sample.abs()).reduce(math.max) / 32768;

  double get stereoSideToMidDb {
    if (channels != 2) return double.negativeInfinity;
    var midEnergy = 0.0;
    var sideEnergy = 0.0;
    for (var i = 0; i < interleavedSamples.length; i += 2) {
      final mid = (interleavedSamples[i] + interleavedSamples[i + 1]) / 2;
      final side = (interleavedSamples[i] - interleavedSamples[i + 1]) / 2;
      midEnergy += mid * mid;
      sideEnergy += side * side;
    }
    return 10 * math.log(sideEnergy / math.max(midEnergy, 1e-12)) / math.ln10;
  }

  double get peakAtMs {
    var at = 0;
    var value = 0;
    for (var i = 0; i < samples.length; i++) {
      final candidate = samples[i].abs();
      if (candidate > value) {
        value = candidate;
        at = i;
      }
    }
    return at / sampleRate * 1000;
  }

  double get onsetMs {
    final threshold = peak * 32768 * 0.05;
    final at = samples.indexWhere((sample) => sample.abs() >= threshold);
    return (at < 0 ? samples.length : at) / sampleRate * 1000;
  }

  double get tailRms {
    final length = math.min(samples.length, (sampleRate * 0.002).round());
    final tail = samples.skip(samples.length - length);
    return math.sqrt(
          tail.fold<double>(0, (sum, sample) => sum + sample * sample) / length,
        ) /
        32768;
  }

  double rmsBetweenMs(double startMs, double endMs) => _rangeRms(
    (startMs * sampleRate / 1000).round().clamp(0, samples.length),
    (endMs * sampleRate / 1000).round().clamp(0, samples.length),
  );

  double _rangeRms(int start, int end) {
    final safeEnd = math.max(start + 1, end).clamp(0, samples.length);
    final length = safeEnd - start;
    if (length <= 0) return 0;
    var energy = 0.0;
    for (var i = start; i < safeEnd; i++) {
      energy += samples[i] * samples[i];
    }
    return math.sqrt(energy / length) / 32768;
  }

  double get roughness {
    var differences = 0.0;
    var energy = 0.0;
    for (var i = 0; i < samples.length; i++) {
      final value = samples[i].toDouble();
      energy += value * value;
      if (i > 0) {
        final delta = value - samples[i - 1];
        differences += delta * delta;
      }
    }
    return differences / math.max(4 * energy, 1e-12);
  }
}
