import 'dart:math' as math;

import 'package:emberkeep/main_room_music.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'normal music starts an approved take and rotates after a toggle',
    () async {
      final starts = <String>[];
      final music =
          MainRoomMusic.testing(rotation: MusicRotation(random: math.Random(4)))
            ..debugBypassPlayback = true
            ..debugOnStartTake = starts.add;

      await music.setEnabled(true);
      expect(music.isPlaying, isTrue);
      expect(starts, hasLength(1));
      expect(MainRoomMusic.takeAssets, contains(starts.single));

      await music.setEnabled(false);
      expect(music.isPlaying, isFalse);
      await music.setEnabled(true);
      expect(starts, hasLength(2));
      expect(starts[1], isNot(starts[0]));
      await music.dispose();
    },
  );

  test('background and resume bring back a fresh approved take', () async {
    final starts = <String>[];
    final music =
        MainRoomMusic.testing(rotation: MusicRotation(random: math.Random(9)))
          ..debugBypassPlayback = true
          ..debugOnStartTake = starts.add;

    await music.setEnabled(true);
    await music.setForeground(false);
    expect(music.isPlaying, isFalse);
    await music.setForeground(true);

    expect(music.isPlaying, isTrue);
    expect(starts, hasLength(2));
    expect(starts[1], isNot(starts[0]));
    await music.dispose();
  });

  test('quick off-on cannot strand enabled music in its drain', () async {
    final starts = <String>[];
    final music =
        MainRoomMusic.testing(rotation: MusicRotation(random: math.Random(12)))
          ..debugBypassPlayback = true
          ..debugOnStartTake = starts.add;

    await music.setEnabled(true);
    await music.setEnabled(false);
    await music.setEnabled(true);

    expect(music.enabled, isTrue);
    expect(music.isPlaying, isTrue);
    expect(starts, hasLength(2));
    expect(starts[1], isNot(starts[0]));
    await music.dispose();
  });

  test('quick background-resume cannot strand enabled music', () async {
    final starts = <String>[];
    final music =
        MainRoomMusic.testing(rotation: MusicRotation(random: math.Random(16)))
          ..debugBypassPlayback = true
          ..debugOnStartTake = starts.add;

    await music.setEnabled(true);
    await music.setForeground(false);
    await music.setForeground(true);

    expect(music.enabled, isTrue);
    expect(music.isPlaying, isTrue);
    expect(starts, hasLength(2));
    await music.dispose();
  });

  test('earned cues duck the main bed and recover without a jump', () {
    final ducker = MusicDucker();
    final start = DateTime.utc(2026, 9, 1, 12);
    final hold = start.add(const Duration(milliseconds: 140));
    ducker.duck(at: start, until: hold);

    expect(
      ducker.gainAt(start.add(const Duration(milliseconds: 80))),
      MusicDucker.duckFloor,
    );
    expect(ducker.gainAt(hold), MusicDucker.duckFloor);
    expect(
      ducker.gainAt(hold.add(const Duration(milliseconds: 200))),
      closeTo(0.70, 1e-9),
    );
    expect(
      ducker.gainAt(hold.add(MusicDucker.recoveryRamp)),
      MusicDucker.restGain,
    );
  });
}
