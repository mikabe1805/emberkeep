import 'dart:math' as math;

import 'package:emberkeep/main_room_music.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('generic rotation preserves an explicitly eight-take umbrella bag', () {
    for (var seed = 0; seed < 16; seed++) {
      final rotation = MusicRotation(random: math.Random(seed), takeCount: 8);
      final takes = [for (var index = 0; index < 24; index++) rotation.next()];

      for (var index = 1; index < takes.length; index++) {
        expect(takes[index], isNot(takes[index - 1]));
      }
      for (var bag = 0; bag < 3; bag++) {
        expect(takes.sublist(bag * 8, bag * 8 + 8).toSet(), {
          1,
          2,
          3,
          4,
          5,
          6,
          7,
          8,
        });
      }
    }
  });

  test(
    'grouped rotation gives every composition one turn before repeating',
    () {
      final rotation = MusicRotation(
        random: math.Random(7),
        takeCount: 11,
        compositionGroups: const [
          [1, 2, 3, 4, 5, 6, 7, 8],
          [9],
          [10],
          [11],
        ],
      );
      final takes = [for (var index = 0; index < 32; index++) rotation.next()];
      final families = [for (final take in takes) take <= 8 ? 0 : take - 8];

      for (var index = 1; index < families.length; index++) {
        expect(families[index], isNot(families[index - 1]));
      }
      for (var cycle = 0; cycle < 8; cycle++) {
        expect(families.sublist(cycle * 4, cycle * 4 + 4).toSet(), {
          0,
          1,
          2,
          3,
        });
      }
      expect(takes.where((take) => take <= 8).toSet(), {
        1,
        2,
        3,
        4,
        5,
        6,
        7,
        8,
      });
    },
  );

  test(
    'a single custom composition still cycles its takes without repeats',
    () {
      final rotation = MusicRotation(
        random: math.Random(4),
        takeCount: 3,
        compositionGroups: const [
          [1, 2, 3],
        ],
      );
      final takes = [for (var index = 0; index < 9; index++) rotation.next()];

      for (var index = 1; index < takes.length; index++) {
        expect(takes[index], isNot(takes[index - 1]));
      }
      for (var bag = 0; bag < 3; bag++) {
        expect(takes.sublist(bag * 3, bag * 3 + 3).toSet(), {1, 2, 3});
      }
    },
  );

  test('grouped rotation rejects invalid composition declarations', () {
    expect(
      () => MusicRotation(takeCount: 3, compositionGroups: const []),
      throwsArgumentError,
    );
    expect(
      () => MusicRotation(
        takeCount: 3,
        compositionGroups: const [
          [1, 2],
          [],
        ],
      ),
      throwsArgumentError,
    );
    expect(
      () => MusicRotation(
        takeCount: 3,
        compositionGroups: const [
          [1, 2],
          [2, 3],
        ],
      ),
      throwsArgumentError,
    );
    expect(
      () => MusicRotation(
        takeCount: 3,
        compositionGroups: const [
          [1, 2],
          [4],
        ],
      ),
      throwsArgumentError,
    );
    expect(
      () => MusicRotation(
        takeCount: 3,
        compositionGroups: const [
          [1, 2],
        ],
      ),
      throwsArgumentError,
    );
  });

  test(
    'normal music defaults to the approved alternating compositions',
    () async {
      final starts = <String>[];
      final music = MainRoomMusic.testing()
        ..debugBypassPlayback = true
        ..debugOnStartTake = starts.add;

      for (var index = 0; index < 16; index++) {
        await music.setEnabled(true);
        if (index < 15) await music.setEnabled(false);
      }

      expect(music.isPlaying, isTrue);
      expect(starts, hasLength(16));
      expect(MainRoomMusic.compositionGroups, const [
        [1, 2, 3, 4, 5, 6, 7, 8],
        [9],
      ]);
      for (var index = 1; index < starts.length; index++) {
        final previousIsNewComposition =
            starts[index - 1] == MainRoomMusic.assetForTake(9);
        final currentIsNewComposition =
            starts[index] == MainRoomMusic.assetForTake(9);
        expect(currentIsNewComposition, isNot(previousIsNewComposition));
      }
      expect(
        starts.where((asset) => asset != MainRoomMusic.assetForTake(9)).toSet(),
        {
          for (final take in MainRoomMusic.compositionGroups.first)
            MainRoomMusic.assetForTake(take),
        },
      );
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
