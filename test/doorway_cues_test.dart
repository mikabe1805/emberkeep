// The class chime: the Doorway's hang plays a soft brass note whose pitch is
// the Nth degree of the room's D-major pentatonic for the Nth class kept today,
// so a day's classes sound as a small rising line.
//
// What is proved here, end to end: a position among the day's kept classes
// picks a step (doorway_cues.dart, the one place that chooses it), the step
// picks a master (audio.dart), and the master really sounds that note (its
// spectrum is measured, not trusted from a file name). The stage's own
// position counting (a class set aside is skipped, an undone one is not a hole)
// is in doorway_sequence_test.dart. The masters' bytes are locked in
// interaction_sound_quality_test.dart.
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:emberkeep/audio.dart';
import 'package:emberkeep/widgets/class_day/doorway_cues.dart';
import 'package:flutter_test/flutter_test.dart';

/// The pitch field's rising line, in the chime's register: D5 E5 F#5 A5 B5 and
/// the octave D6 (D-major pentatonic, SOUND-DESIGN.md section 3).
const _line = <(String, double)>[
  ('D5', 587.330),
  ('E5', 659.255),
  ('F#5', 739.989),
  ('A5', 880.0),
  ('B5', 987.767),
  ('D6', 1174.659),
];

void main() {
  final sfx = Sfx.instance;
  late List<String> assets;
  late List<String> events;

  setUp(() {
    sfx.debugResetForTesting();
    sfx.debugBypassPlayback = true;
    assets = <String>[];
    events = <String>[];
    sfx.debugOnPlayAsset = assets.add;
    sfx.debugOnPlay = events.add;
  });
  tearDown(sfx.debugResetForTesting);

  group('the step for a position', () {
    test('the 1st to the 6th class kept climb the six steps', () {
      expect(
        [for (var p = 1; p <= 6; p++) DoorwayCues.chimeStepFor(p)],
        [1, 2, 3, 4, 5, 6],
      );
      expect(Sfx.classChimeSteps, 6);
    });

    test('past the sixth the line starts over from the root', () {
      expect(
        [for (var p = 7; p <= 13; p++) DoorwayCues.chimeStepFor(p)],
        [1, 2, 3, 4, 5, 6, 1],
      );
      expect(DoorwayCues.chimeStepFor(25), 1);
    });

    test('a position that is not a place is the first', () {
      expect(DoorwayCues.chimeStepFor(0), 1);
      expect(DoorwayCues.chimeStepFor(-4), 1);
    });
  });

  group('the hang sounds the chime', () {
    test('position N plays step N of the class chime', () {
      const cues = DoorwayCues();
      for (var p = 1; p <= 8; p++) {
        cues.hang(p);
      }
      expect(assets, [
        for (var p = 1; p <= 8; p++)
          'room/class_chime/${DoorwayCues.chimeStepFor(p)}',
      ]);
      expect(events, everyElement('class_chime'));
    });

    test('it does not borrow the ordinary tap router', () {
      // Neither the take walk, the rapid ladder nor Paired Return hear it: a
      // day's line must never lose or shift a note to a tap that came before.
      const cues = DoorwayCues();
      sfx.playInteraction(InteractionSound.open, at: DateTime(2026, 10, 9, 9));
      sfx.playInteraction(
        InteractionSound.select,
        at: DateTime(2026, 10, 9, 9, 0, 0, 5),
      );
      cues.hang(1);
      cues.hang(2);
      expect(assets.where((a) => a.contains('class_chime')), [
        'room/class_chime/1',
        'room/class_chime/2',
      ]);
    });

    test('the sound switch mutes it, like every other cue', () {
      sfx.soundEnabled = false;
      const DoorwayCues().hang(3);
      expect(assets, isEmpty);
      expect(events, isEmpty);
      sfx.soundEnabled = true;
      const DoorwayCues().hang(3);
      expect(assets, ['room/class_chime/3']);
    });

    test(
      'Reduce Motion is not the sound switch: the cue knows nothing of it',
      () {
        // The stage turns a move into a fade under Reduce Motion but still calls
        // hang(position); the cue's only gate is soundEnabled.
        final cue = File(
          'lib/widgets/class_day/doorway_cues.dart',
        ).readAsStringSync();
        expect(cue, isNot(contains('reduceMotion')));
        expect(cue, isNot(contains('Reduce')));
      },
    );

    test('a step outside the six is clamped, never an unknown asset', () {
      sfx.playClassChime(0);
      sfx.playClassChime(99);
      expect(assets, ['room/class_chime/1', 'room/class_chime/6']);
    });

    test('it plays softly: under the master, never over it', () {
      expect(DoorwayCues.chimeVolume, inInclusiveRange(0.4, 1.0));
    });
  });

  group('the one place that chooses', () {
    test('only audio.dart and doorway_cues.dart name the chime', () {
      final offenders = <String>[];
      for (final file in Directory('lib').listSync(recursive: true)) {
        if (file is! File || !file.path.endsWith('.dart')) continue;
        final path = file.path.replaceAll('\\', '/');
        final source = file.readAsStringSync();
        if (!source.contains('class_chime') &&
            !source.contains('playClassChime')) {
          continue;
        }
        if (path.endsWith('lib/audio.dart') ||
            path.endsWith('lib/widgets/class_day/doorway_cues.dart')) {
          continue;
        }
        offenders.add(path);
      }
      expect(offenders, isEmpty, reason: 'the stage must not choose sounds');
    });

    test('the stage only announces the place; it plays nothing itself', () {
      for (final name in ['doorway_stage.dart', 'doorway_model.dart']) {
        final source = File('lib/widgets/class_day/$name').readAsStringSync();
        expect(source, isNot(contains('Sfx.')), reason: name);
        expect(source, isNot(contains('class_chime')), reason: name);
      }
      expect(
        File('lib/widgets/class_day/doorway_stage.dart').readAsStringSync(),
        contains('widget.cues.hang(m.position)'),
      );
    });
  });

  group('the masters really climb the pitch field', () {
    test('step N sounds the Nth degree, within ten cents', () {
      final measured = <double>[];
      for (var step = 1; step <= Sfx.classChimeSteps; step++) {
        final (name, want) = _line[step - 1];
        final wave = _readWave(File('assets/sfx/room/class_chime/$step.wav'));
        expect(wave.sampleRate, 44100);
        final hz = _bodyPitch(wave);
        measured.add(hz);
        final cents = 1200 * math.log(hz / want) / math.ln2;
        expect(
          cents.abs(),
          lessThan(10),
          reason: 'step $step should sound $name ($want Hz), got $hz Hz',
        );
      }
      for (var i = 1; i < measured.length; i++) {
        expect(measured[i], greaterThan(measured[i - 1]), reason: 'rising');
      }
      // The sixth is the octave of the first: the line starts over cleanly.
      expect(measured.last / measured.first, closeTo(2.0, 0.01));
    });

    test('every step is a note of the field: D, E, F#, A or B', () {
      const field = {'D', 'E', 'F#', 'A', 'B'};
      for (final (name, _) in _line) {
        expect(field, contains(name.replaceAll(RegExp(r'\d'), '')));
      }
    });

    test(
      'the masters are short, warm and soft, and sit well under -6 dBFS',
      () {
        for (var step = 1; step <= Sfx.classChimeSteps; step++) {
          final wave = _readWave(File('assets/sfx/room/class_chime/$step.wav'));
          expect(wave.channels, 1);
          expect(wave.bitsPerSample, 16);
          expect(wave.durationMs, inInclusiveRange(300, 520));
          expect(
            wave.peak,
            lessThanOrEqualTo(0.2512),
            reason: 'under -12 dBFS',
          );
          // A soft attack: the peak arrives after the contact, not at sample 0.
          expect(wave.peakAtMs, inInclusiveRange(4, 15), reason: 'step $step');
          // No tail left to click at the file's end.
          expect(wave.samples.last.abs(), lessThan(40));
        }
      },
    );
  });
}

/// The strongest pitch of the chime's body (after the hang's contact), in Hz:
/// a Hann-windowed DFT scanned from 500 to 1400 Hz in 0.5 Hz steps.
double _bodyPitch(_Wave wave) {
  final from = (0.030 * wave.sampleRate).round();
  final to = (0.180 * wave.sampleRate).round();
  final n = to - from;
  final x = Float64List(n);
  for (var i = 0; i < n; i++) {
    final w = 0.5 - 0.5 * math.cos(2 * math.pi * i / (n - 1));
    x[i] = wave.samples[from + i] / 32768 * w;
  }
  var best = 0.0;
  var bestHz = 0.0;
  for (var hz = 500.0; hz <= 1400.0; hz += 0.5) {
    final step = 2 * math.pi * hz / wave.sampleRate;
    var re = 0.0;
    var im = 0.0;
    for (var i = 0; i < n; i++) {
      re += x[i] * math.cos(step * i);
      im += x[i] * math.sin(step * i);
    }
    final power = re * re + im * im;
    if (power > best) {
      best = power;
      bestHz = hz;
    }
  }
  return bestHz;
}

_Wave _readWave(File file) {
  final bytes = file.readAsBytesSync();
  final data = ByteData.sublistView(bytes);
  expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
  expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE');
  int? channels;
  int? sampleRate;
  int? bits;
  Int16List? pcm;
  var offset = 12;
  while (offset + 8 <= bytes.length) {
    final id = String.fromCharCodes(bytes.sublist(offset, offset + 4));
    final size = data.getUint32(offset + 4, Endian.little);
    final body = offset + 8;
    if (id == 'fmt ') {
      expect(data.getUint16(body, Endian.little), 1, reason: 'PCM');
      channels = data.getUint16(body + 2, Endian.little);
      sampleRate = data.getUint32(body + 4, Endian.little);
      bits = data.getUint16(body + 14, Endian.little);
    } else if (id == 'data') {
      expect(bits, 16, reason: '${file.path} must be 16-bit PCM');
      final out = Int16List(size ~/ 2);
      for (var i = 0; i < out.length; i++) {
        out[i] = data.getInt16(body + i * 2, Endian.little);
      }
      pcm = out;
    }
    offset = body + size + (size.isOdd ? 1 : 0);
  }
  return _Wave(channels!, sampleRate!, bits!, pcm!);
}

class _Wave {
  const _Wave(this.channels, this.sampleRate, this.bitsPerSample, this.samples);

  final int channels;
  final int sampleRate;
  final int bitsPerSample;
  final Int16List samples;

  double get durationMs => samples.length / sampleRate * 1000;

  double get peak => samples.map((s) => s.abs()).reduce(math.max) / 32768;

  double get peakAtMs {
    var at = 0;
    var value = 0;
    for (var i = 0; i < samples.length; i++) {
      if (samples[i].abs() > value) {
        value = samples[i].abs();
        at = i;
      }
    }
    return at / sampleRate * 1000;
  }
}
