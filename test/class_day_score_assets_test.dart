// The class-day score's files, byte-locked like the other sound masters, and
// the architectural invariants of the code that plays them.
//
// The files are made by tool/author_class_day_score.py (AAC-LC 96 kbps 48 kHz
// mono) from the music sketch the owner heard: two beds and thirty-two
// swells. The manifest beside the audit records every file's sha256, size,
// duration and measured level; a digest literal below pins the manifest's own
// contents, so changing a file and its record together still fails here and
// someone has to listen again.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:emberkeep/class_day_score_clock.dart';
import 'package:flutter_test/flutter_test.dart';

const _manifestPath = 'design/audits/2026-10-11/class-day-score/manifest.json';
const _folder = 'assets/music/class_day';

/// SHA-256 of the sorted `runtime-path file-sha256` lines of the 34 files,
/// then the sorted `stem:<name> <int16 sha256>` lines of the five sketch stems
/// they were cut from.
const _scoreDigest =
    '5700737ccdabf7eab20e2f9b0676e3e5c4dfe171fc08b0c003b1e26d907222ed';

Map<String, dynamic> _manifest() =>
    jsonDecode(File(_manifestPath).readAsStringSync()) as Map<String, dynamic>;

String _code(String path) => File(path)
    .readAsLinesSync()
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  group('the files', () {
    test('are exactly the two beds and thirty-two swells the score names', () {
      final onDisk = [
        for (final f in Directory(_folder).listSync())
          if (f is File) f.uri.pathSegments.last,
      ]..sort();
      final named = [
        for (final asset in ScoreForm.allAssets) asset.split('/').last,
      ]..sort();
      expect(onDisk, named, reason: 'no stray file, none missing');
      expect(onDisk, hasLength(34));
      final records = (_manifest()['records'] as Map).keys.cast<String>();
      expect(records.toSet(), {
        for (final asset in ScoreForm.allAssets) 'assets/$asset',
      });
    });

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
      expect(
        sha256.convert(utf8.encode(lines.toString())).toString(),
        _scoreDigest,
        reason: 'the score changed: listen again, then re-pin',
      );
    });

    test(
      'are the sizes the design budgeted: about 5.1 MB, 18% on the music',
      () {
        final manifest = _manifest();
        final records = (manifest['records'] as Map<String, dynamic>)
            .cast<String, Map<String, dynamic>>();
        var total = 0;
        for (final record in records.values) {
          total += record['bytes'] as int;
        }
        expect(manifest['total_bytes'], total);
        expect(total, inInclusiveRange(5000000, 5300000));
        for (final name in ['bed_between', 'bed_evening']) {
          final bytes =
              records['assets/music/class_day/$name.m4a']!['bytes'] as int;
          expect(bytes, inInclusiveRange(650000, 780000));
        }
      },
    );

    test('are one pass and its tail, and two bars and a release', () {
      final records = (_manifest()['records'] as Map<String, dynamic>)
          .cast<String, Map<String, dynamic>>();
      for (final name in ['bed_between', 'bed_evening']) {
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

  group('the levels', () {
    test('a bed sits at the rotation\'s level, so a hand-off has no step', () {
      // Every take in the rotation measures -36.02 dBFS phone-band RMS.
      final records = (_manifest()['records'] as Map<String, dynamic>)
          .cast<String, Map<String, dynamic>>();
      for (final name in ['bed_between', 'bed_evening']) {
        final level =
            records['assets/music/class_day/$name.m4a']!['loop_phone_rms_db']
                as num;
        expect(level, closeTo(-36.02, 0.1), reason: name);
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
      for (final name in ['bed_between', 'bed_evening']) {
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

    test('plays every file at unity: the level is in the file', () {
      final code = _code('lib/class_day_score.dart');
      // Only fades and the shared duck scale a voice; no other gain.
      expect(code, contains('voice.envelopeAt(now) * duck'));
      expect(code, isNot(contains('volumeScale')));
    });
  });
}
