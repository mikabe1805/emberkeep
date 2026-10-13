// The class-day score's files, byte-locked like the other sound masters, and
// the architectural invariants of the code that plays them.
//
// The files are made by tool/author_class_day_score.py (AAC-LC 96 kbps 48 kHz
// mono) from the music sketch the owner heard: two beds in six performances
// each, and thirty-two swells. The six performances play the same song (the
// same chords in the same bars over the same bass line, so every swell fits
// every one of them) and differ in what sits on top. The manifest beside the
// audit records every file's sha256, size, duration and measured level; a
// digest literal below pins the manifest's own contents, so changing a file and
// its record together still fails here and someone has to listen again.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:emberkeep/class_day_score_clock.dart';
import 'package:flutter_test/flutter_test.dart';

const _manifestPath = 'design/audits/2026-10-11/class-day-score/manifest.json';
const _folder = 'assets/music/class_day';

/// SHA-256 of the sorted `runtime-path file-sha256` lines of the 44 files,
/// then the sorted `stem:<name> <int16 sha256>` lines of the five sketch stems
/// they were cut from, then the `perf:<index>:<stem> <int16 sha256>` lines of
/// every performance's keys, brushes, slow bells and the shared bass.
const _scoreDigest =
    '4e4cabbc8a7952ba1374f34a68954d42b68cfed16be5edc89fbf01d490cccc3c';

const _states = ['between', 'evening'];

List<String> _bedNames() => [
  for (final state in _states)
    for (var p = 0; p < ScoreForm.performanceCount; p++) 'bed_${state}_$p',
];

Map<String, dynamic> _manifest() =>
    jsonDecode(File(_manifestPath).readAsStringSync()) as Map<String, dynamic>;

String _code(String path) => File(path)
    .readAsLinesSync()
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  group('the files', () {
    test(
      'are exactly the twelve beds and thirty-two swells the score names',
      () {
        final onDisk = [
          for (final f in Directory(_folder).listSync())
            if (f is File) f.uri.pathSegments.last,
        ]..sort();
        final named = [
          for (final asset in ScoreForm.allAssets) asset.split('/').last,
        ]..sort();
        expect(onDisk, named, reason: 'no stray file, none missing');
        expect(onDisk, hasLength(44));
        final records = (_manifest()['records'] as Map).keys.cast<String>();
        expect(records.toSet(), {
          for (final asset in ScoreForm.allAssets) 'assets/$asset',
        });
      },
    );

    test('are byte-identical to what the manifest records', () {
      final records = (_manifest()['records'] as Map<String, dynamic>)
          .cast<String, Map<String, dynamic>>();
      for (final entry in records.entries) {
        final file = File(entry.key);
        expect(file.existsSync(), isTrue, reason: 'missing ${entry.key}');
        final bytes = file.readAsBytesSync();
        expect(
          sha256.convert(bytes).toString(),
          entry.value['sha256'],
          reason: '${entry.key} must stay what the score was built from',
        );
        expect(bytes.length, entry.value['bytes']);
        // An MPEG-4 file: 'ftyp' in the first box.
        expect(utf8.decode(bytes.sublist(4, 8)), 'ftyp');
      }
    });

    test('are pinned as a set, with the stems they were cut from', () {
      final manifest = _manifest();
      final records = (manifest['records'] as Map<String, dynamic>)
          .cast<String, Map<String, dynamic>>();
      final stems = (manifest['stems'] as Map<String, dynamic>)
          .cast<String, Map<String, dynamic>>();
      final lines = StringBuffer();
      for (final path in records.keys.toList()..sort()) {
        lines.write('$path ${records[path]!['sha256']}\n');
      }
      expect(stems.keys.toSet(), {
        'keys',
        'bass',
        'brushes',
        'bells',
        'bells_slow',
      });
      for (final name in stems.keys.toList()..sort()) {
        lines.write('stem:$name ${stems[name]!['int16_sha256']}\n');
      }
      final performances = (manifest['performances'] as List)
          .cast<Map<String, dynamic>>();
      for (final performance in performances) {
        final own = (performance['stems'] as Map<String, dynamic>)
            .cast<String, String>();
        for (final name in own.keys.toList()..sort()) {
          lines.write('perf:${performance['index']}:$name ${own[name]}\n');
        }
      }
      expect(
        sha256.convert(utf8.encode(lines.toString())).toString(),
        _scoreDigest,
        reason: 'the score changed: listen again, then re-pin',
      );
    });

    test('are the sizes budgeted: the extra performances add under 8 MB', () {
      final manifest = _manifest();
      final records = (manifest['records'] as Map<String, dynamic>)
          .cast<String, Map<String, dynamic>>();
      var total = 0;
      var extra = 0;
      for (final entry in records.entries) {
        final bytes = entry.value['bytes'] as int;
        total += bytes;
        // Performance 0 is the pair of beds that shipped first (5,142,699
        // bytes with the swells); every other bed is what variety costs.
        final bed = RegExp(r'bed_\w+_(\d)\.m4a$').firstMatch(entry.key);
        if (bed != null && bed.group(1) != '0') extra += bytes;
      }
      expect(manifest['total_bytes'], total);
      expect(extra, lessThan(8000000), reason: 'the added size');
      expect(extra, greaterThan(6000000), reason: 'five more of each bed');
      expect(total, inInclusiveRange(12000000, 12600000));
      for (final name in _bedNames()) {
        final bytes =
            records['assets/music/class_day/$name.m4a']!['bytes'] as int;
        expect(bytes, inInclusiveRange(650000, 780000), reason: name);
      }
    });

    test('are one pass and its tail, and two bars and a release', () {
      final records = (_manifest()['records'] as Map<String, dynamic>)
          .cast<String, Map<String, dynamic>>();
      for (final name in _bedNames()) {
        final duration =
            records['assets/music/class_day/$name.m4a']!['duration_s'] as num;
        final expected =
            (ScoreForm.pass + ScoreForm.bedTail).inMicroseconds / 1e6;
        expect(duration, closeTo(expected, 0.002), reason: name);
      }
      for (var i = 0; i < ScoreForm.swellCount; i++) {
        final duration =
            records['assets/${ScoreForm.swellAsset(i)}']!['duration_s'] as num;
        expect(
          duration,
          closeTo(ScoreForm.swellLength.inMicroseconds / 1e6, 0.002),
        );
      }
    });

    test('swell k is cut at strong beat 2k of the form', () {
      final manifest = _manifest();
      final form = manifest['form'] as Map<String, dynamic>;
      expect(form['swell_beats'], [
        for (var k = 0; k < ScoreForm.swellCount; k++) 2 * k,
      ]);
      expect(form['bpm'], ScoreForm.bpm);
      expect(form['performance_count'], ScoreForm.performanceCount);
      expect(
        form['pass_s'] as num,
        closeTo(ScoreForm.pass.inMicroseconds / 1e6, 1e-6),
      );
      expect(
        form['bed_tail_s'] as num,
        closeTo(ScoreForm.bedTail.inMilliseconds / 1e3, 1e-9),
      );
      expect(
        form['swell_preroll_s'] as num,
        closeTo(ScoreForm.swellPreRoll.inMilliseconds / 1e3, 1e-9),
      );
      final records = (manifest['records'] as Map<String, dynamic>)
          .cast<String, Map<String, dynamic>>();
      for (var k = 0; k < ScoreForm.swellCount; k++) {
        expect(records['assets/${ScoreForm.swellAsset(k)}']!['beat'], 2 * k);
      }
    });
  });

  group('the performances', () {
    List<Map<String, dynamic>> performances() =>
        (_manifest()['performances'] as List).cast<Map<String, dynamic>>();

    test('are six, in order, each with both its beds on disk', () {
      final list = performances();
      expect(list, hasLength(ScoreForm.performanceCount));
      for (var p = 0; p < list.length; p++) {
        expect(list[p]['index'], p);
        expect(list[p]['name'], isA<String>());
        expect(list[p]['feel'], isA<String>());
        final files = (list[p]['files'] as Map<String, dynamic>)
            .cast<String, String>();
        expect(
          'assets/${ScoreForm.bedAsset(evening: false, performance: p)}',
          files['between'],
        );
        expect(
          'assets/${ScoreForm.bedAsset(evening: true, performance: p)}',
          files['evening'],
        );
        for (final path in files.values) {
          expect(File(path).existsSync(), isTrue, reason: path);
        }
      }
      expect(
        {for (final p in list) p['name']},
        hasLength(6),
        reason: 'six different names',
      );
    });

    test('play the same song: the very same bass, byte for byte', () {
      final manifest = _manifest();
      final bass =
          (manifest['stems'] as Map<String, dynamic>)['bass']['int16_sha256'];
      for (final performance in performances()) {
        final stems = (performance['stems'] as Map<String, dynamic>)
            .cast<String, String>();
        expect(
          stems['bass'],
          bass,
          reason:
              'performance ${performance['index']}: the swells are cut '
              'from this bass, so every performance must carry it',
        );
      }
      // Same chords in the same bars: the form, once, for all of them.
      final form = manifest['form'] as Map<String, dynamic>;
      expect(form['chord_bars'], hasLength(16));
      expect(form['bars'], 16);
    });

    test('are the sketch for the first and different from it after', () {
      final manifest = _manifest();
      final sketch = (manifest['stems'] as Map<String, dynamic>)
          .cast<String, Map<String, dynamic>>();
      final list = performances();
      final zero = (list[0]['stems'] as Map<String, dynamic>)
          .cast<String, String>();
      for (final name in ['keys', 'brushes', 'bells_slow']) {
        expect(zero[name], sketch[name]!['int16_sha256'], reason: name);
      }
      for (final name in ['keys', 'brushes', 'bells_slow']) {
        final all = {
          for (final p in list) (p['stems'] as Map<String, dynamic>)[name],
        };
        expect(
          all,
          hasLength(6),
          reason: 'every performance has its own $name',
        );
      }
    });

    test(
      'vary the keys, the brushes and the bells, and nothing under them',
      () {
        final list = performances();
        final keysSeeds = <Object?>{};
        for (final performance in list) {
          final controls = performance['controls'] as Map<String, dynamic>;
          expect(controls.keys.toSet(), {'keys', 'brushes', 'slow_bells'});
          keysSeeds.add((controls['keys'] as Map<String, dynamic>)['seed']);
        }
        expect(keysSeeds, hasLength(6));
        // Performance 0 plays the sketch's own controls.
        final zero = list[0]['controls'] as Map<String, dynamic>;
        expect((zero['keys'] as Map<String, dynamic>)['seed'], 14100);
        expect((zero['brushes'] as Map<String, dynamic>)['seed'], 14400);
        expect((zero['slow_bells'] as Map<String, dynamic>)['seed'], 14600);
        // Some answer with figures, some not.
        final withFigures = [
          for (final p in list)
            if ((p['figures'] as Map).isNotEmpty) p['index'],
        ];
        expect(withFigures.length, inInclusiveRange(3, 5));
        expect(withFigures, isNot(contains(0)), reason: 'the sketch has none');
      },
    );
  });

  group('the levels', () {
    test('a bed sits at the rotation\'s level, so a hand-off has no step', () {
      // Every take in the rotation measures -36.02 dBFS phone-band RMS.
      final records = (_manifest()['records'] as Map<String, dynamic>)
          .cast<String, Map<String, dynamic>>();
      for (final name in _bedNames()) {
        final level =
            records['assets/music/class_day/$name.m4a']!['loop_phone_rms_db']
                as num;
        expect(level, closeTo(-36.02, 0.1), reason: name);
      }
    });

    test('a bed\'s peak is where the sketch\'s was, not 2 dB above it', () {
      final records = (_manifest()['records'] as Map<String, dynamic>)
          .cast<String, Map<String, dynamic>>();
      for (final state in _states) {
        final sketch =
            records['assets/music/class_day/bed_${state}_0.m4a']!['peak_dbfs']
                as num;
        for (var p = 0; p < ScoreForm.performanceCount; p++) {
          final peak =
              records['assets/music/class_day/bed_${state}_$p.m4a']!['peak_dbfs']
                  as num;
          expect(peak, lessThan(sketch + 2.0), reason: '$state $p');
          expect(peak, lessThan(-14), reason: '$state $p');
        }
      }
    });

    test(
      'a swell holds -38.2 dBFS over its two bars: a lift of about 2 dB',
      () {
        final records = (_manifest()['records'] as Map<String, dynamic>)
            .cast<String, Map<String, dynamic>>();
        var lifts = 0.0;
        for (var k = 0; k < ScoreForm.swellCount; k++) {
          final r = records['assets/${ScoreForm.swellAsset(k)}']!;
          expect(
            r['held_phone_rms_db'] as num,
            closeTo(-38.2, 0.05),
            reason: 'swell $k',
          );
          final lift = r['lift_over_between_db'] as num;
          expect(lift, inInclusiveRange(1.2, 3.2), reason: 'swell $k');
          lifts += lift;
        }
        expect(lifts / ScoreForm.swellCount, closeTo(2.1, 0.3));
      },
    );

    test(
      'a swell lifts every performance about 2 dB, none lost or crowded',
      () {
        final manifest = _manifest();
        final records = (manifest['records'] as Map<String, dynamic>)
            .cast<String, Map<String, dynamic>>();
        for (var p = 0; p < ScoreForm.performanceCount; p++) {
          var sum = 0.0;
          for (var k = 0; k < ScoreForm.swellCount; k++) {
            final r = records['assets/${ScoreForm.swellAsset(k)}']!;
            final lifts = (r['lift_by_performance_db'] as List).cast<num>();
            expect(lifts, hasLength(ScoreForm.performanceCount));
            expect(
              lifts[p],
              inInclusiveRange(1.0, 3.3),
              reason: 'swell $k over $p',
            );
            final peaks = (r['with_between_peak_by_performance_db'] as List)
                .cast<num>();
            expect(peaks[p], lessThan(-12), reason: 'swell $k over $p');
            sum += lifts[p];
          }
          expect(sum / ScoreForm.swellCount, closeTo(2.1, 0.3), reason: '$p');
        }
        // Performance 0's numbers are the ones first shipped.
        for (var k = 0; k < ScoreForm.swellCount; k++) {
          final r = records['assets/${ScoreForm.swellAsset(k)}']!;
          expect(
            (r['lift_by_performance_db'] as List).first,
            r['lift_over_between_db'],
          );
        }
      },
    );

    test('nothing nears the -6 dBFS ceiling, with or without the bed', () {
      final records = (_manifest()['records'] as Map<String, dynamic>)
          .cast<String, Map<String, dynamic>>();
      for (final entry in records.entries) {
        expect(
          entry.value['peak_dbfs'] as num,
          lessThan(-12),
          reason: entry.key,
        );
        final together = entry.value['with_between_peak_db'];
        if (together != null) {
          expect(
            together as num,
            lessThan(-12),
            reason: '${entry.key} over the bed',
          );
        }
      }
    });

    test('every file begins and ends at silence: no click on any seam', () {
      final records = (_manifest()['records'] as Map<String, dynamic>)
          .cast<String, Map<String, dynamic>>();
      for (final entry in records.entries) {
        expect(
          (entry.value['first_sample'] as num).abs(),
          lessThan(1e-6),
          reason: '${entry.key} first sample',
        );
        expect(
          (entry.value['last_sample'] as num).abs(),
          lessThan(1e-6),
          reason: '${entry.key} last sample',
        );
      }
    });

    test('the tail cut from a bed was already silent', () {
      final records = (_manifest()['records'] as Map<String, dynamic>)
          .cast<String, Map<String, dynamic>>();
      for (final name in _bedNames()) {
        final cut =
            records['assets/music/class_day/$name.m4a']!['cut_tail_peak_db']
                as num;
        expect(cut, lessThan(-80), reason: 'the 6.5 s tail loses nothing');
      }
    });
  });

  group('the code that plays them', () {
    test('keeps the ambient session and takes no audio focus', () {
      final code = _code('lib/class_day_score.dart');
      expect(code, contains('AVAudioSessionCategory.ambient'));
      expect(code, contains('AndroidAudioFocus.none'));
      expect(code, isNot(contains('AVAudioSessionCategory.playback')));
      expect(code, isNot(contains('AndroidAudioFocus.gain')));
    });

    test('never loops a source, and never shares a clock it does not have', () {
      final code = _code('lib/class_day_score.dart');
      expect(code, isNot(contains('ReleaseMode.loop')));
      expect(code, contains('ReleaseMode.stop'));
      expect(code, isNot(contains('setPlaybackRate')));
    });

    test('is not a sound effect: no Sfx, no raw wall clock', () {
      for (final path in [
        'lib/class_day_score.dart',
        'lib/class_day_score_clock.dart',
      ]) {
        final code = _code(path);
        expect(code, isNot(contains("import 'audio.dart'")), reason: path);
        expect(code, isNot(contains('Sfx')), reason: path);
        expect(code, isNot(contains('DateTime.now')), reason: path);
        expect(
          code,
          isNot(contains('Clock.now')),
          reason: '$path has no day logic',
        );
      }
      // The beat clock is a stopwatch: a set clock cannot move a beat.
      expect(_code('lib/class_day_score.dart'), contains('Stopwatch()'));
    });

    test('is native only: the web build keeps the rotation', () {
      final code = _code('lib/background_music.dart');
      expect(code, contains('static bool get _scoreAvailable => !kIsWeb;'));
      final offline = File('tool/prepare_web_offline.dart').readAsStringSync();
      expect(offline, contains("'assets/assets/music/class_day/'"));
    });

    test('is declared in the bundle, one directory entry (not recursive)', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('- assets/music/class_day/'));
    });

    test('walks the performances: a seeded shuffle, one step a pass', () {
      final code = _code('lib/class_day_score.dart');
      expect(code, contains('PerformanceWalk'));
      expect(code, contains('_walk.peek'));
      expect(code, contains('_walk.take()'));
      // No wall clock behind the shuffle; a test passes a seed.
      expect(code, isNot(contains('DateTime')));
      final clock = _code('lib/class_day_score_clock.dart');
      expect(clock, contains('math.Random(seed)'));
    });

    test('plays every file at unity: the level is in the file', () {
      final code = _code('lib/class_day_score.dart');
      // Only fades and the shared duck scale a voice; no other gain.
      expect(code, contains('voice.envelopeAt(now) * duck'));
      expect(code, isNot(contains('volumeScale')));
    });
  });
}
