// The form of the class-day score, and the clock that puts a swell on a beat.
//
// This file is pure: no audio, no timers, no platform. The score
// (class_day_score.dart) plays two pre-mixed beds and thirty-two two-bar
// swells (assets/music/class_day, made by tool/author_class_day_score.py).
// The audio plugin in use has no shared clock, so the score measures one: it
// anchors each bed pass to a monotonic stopwatch and plans every swell on that
// grid. Everything that decides WHEN and WHICH lives here, where a test can
// reach it without a phone.
library;

/// The 16-bar form the files were cut from: one 72 BPM pass of 64 beats.
abstract final class ScoreForm {
  static const int bpm = 72;
  static const int beatsPerPass = 64;

  /// One beat, 60 / 72 s.
  static const Duration beat = Duration(microseconds: 833333);

  /// One 16-bar pass of the form, 2,560,000 frames at 48 kHz.
  static const Duration pass = Duration(microseconds: 53333333);

  /// What a bed file keeps past the pass: the notes ringing out. The next
  /// pass starts under it, so two passes add up to the circular loop.
  static const Duration bedTail = Duration(milliseconds: 6500);

  /// A swell file begins this long before its beat, so the first bass note
  /// lands ON the beat after the 120 ms rise.
  static const Duration swellPreRoll = Duration(milliseconds: 150);

  /// A swell file is 0.15 s, two bars (6.667 s) and a 2.5 s release.
  static const Duration swellLength = Duration(microseconds: 9316667);

  /// A swell is cut at every strong beat (1 and 3 of each bar): 32 of 64.
  static const int swellCount = 32;

  static const String bedBetween = 'music/class_day/bed_between.m4a';
  static const String bedEvening = 'music/class_day/bed_evening.m4a';

  /// The swell cut at strong beat [index] of the form (0 to 31).
  static String swellAsset(int index) {
    RangeError.checkValueInInterval(index, 0, swellCount - 1, 'index');
    return 'music/class_day/swell_${index.toString().padLeft(2, '0')}.m4a';
  }

  static final List<String> allAssets = List<String>.unmodifiable([
    bedBetween,
    bedEvening,
    for (var i = 0; i < swellCount; i++) swellAsset(i),
  ]);

  /// Beat k sounds k * 2,500,000 / 3 microseconds into a pass (72 BPM is
  /// 833,333.33 microseconds a beat), so beats are placed on that exact
  /// fraction and not on the rounded [beat].
  static const int _beatThirdsOfMicros = 2500000;

  /// The time of beat [n] after [anchor] (the moment of a pass's first
  /// sample). Beats past 63 are the next pass's.
  static Duration beatAt(Duration anchor, int n) =>
      anchor + Duration(microseconds: (n * _beatThirdsOfMicros / 3).round());

  /// The index of the first beat at or after [sincePassStart], to the
  /// microsecond: integer arithmetic, so a beat exactly there (or a rounded
  /// microsecond past it) is that beat and not the next.
  static int beatAtOrAfter(Duration sincePassStart) {
    if (sincePassStart.inMicroseconds <= 1) return 0;
    return ((sincePassStart.inMicroseconds - 1) * 3 +
            _beatThirdsOfMicros -
            1) ~/
        _beatThirdsOfMicros;
  }
}

/// Where and when a swell goes.
class SwellPlan {
  const SwellPlan({
    required this.beat,
    required this.file,
    required this.beatAt,
    required this.startAt,
  });

  /// Beats after the anchor. 64 or more is the next pass of the form.
  final int beat;

  /// Which of the 32 swell files (strong beat [beat] of the form).
  final int file;

  /// When the beat sounds, on the stopwatch.
  final Duration beatAt;

  /// When the file's play call goes out: the beat, less the pre-roll, less
  /// how late the platform starts a source.
  final Duration startAt;

  bool get inNextPass => beat >= ScoreForm.beatsPerPass;

  @override
  String toString() =>
      'SwellPlan(beat $beat, file $file, beat at $beatAt, start at $startAt)';
}

/// The score's beat clock: one anchor (when the current pass's first sample
/// sounded), whether it can be believed, and how late the platform starts a
/// source. All on a monotonic stopwatch, never the wall clock, so setting the
/// phone's clock cannot move a beat.
class ScoreClock {
  ScoreClock({
    this.tolerance = const Duration(milliseconds: 40),
    this.lagWindow = 5,
    this.defaultLag = const Duration(milliseconds: 30),
  });

  /// How far a re-measured zero may sit from the anchor before the clock is
  /// no longer believed (an interruption, a route change, a stall).
  final Duration tolerance;

  /// How many start lags the median is taken over.
  final int lagWindow;

  /// The lag assumed before any is measured.
  final Duration defaultLag;

  Duration? _anchor;
  bool _trusted = false;
  final List<Duration> _lags = <Duration>[];

  /// The stopwatch time of the current pass's first sample, or null.
  Duration? get anchor => _anchor;

  /// Whether swells may be placed on this clock.
  bool get trusted => _trusted && _anchor != null;

  /// The median of the last [lagWindow] measured start lags (the delay from
  /// the play call to the first sample), or [defaultLag] before any.
  Duration get lag {
    if (_lags.isEmpty) return defaultLag;
    final sorted = [..._lags]..sort();
    return sorted[sorted.length ~/ 2];
  }

  /// Records one measured start lag. Negative or absurd values are not lags.
  void noteLag(Duration lag) {
    if (lag.isNegative || lag > const Duration(milliseconds: 400)) return;
    _lags.add(lag);
    if (_lags.length > lagWindow) _lags.removeAt(0);
  }

  /// A pass began at [zero]: believe it.
  void anchorAt(Duration zero) {
    _anchor = zero;
    _trusted = true;
  }

  /// A pass began but its start could not be measured: keep a nominal anchor
  /// to chain the next pass from, but place no swell on it.
  void anchorUnmeasured(Duration nominal) {
    _anchor = nominal;
    _trusted = false;
  }

  /// No swell until the next pass is anchored.
  void distrust() => _trusted = false;

  void reset() {
    _anchor = null;
    _trusted = false;
  }

  /// Whether a re-measured zero agrees with the anchor.
  bool agrees(Duration measuredZero) {
    final anchor = _anchor;
    if (anchor == null) return false;
    return (measuredZero - anchor).abs() <= tolerance;
  }

  /// The swell for the first strong beat at or after [earliest]: the file cut
  /// at that beat of the form, and the stopwatch time to start it. Null while
  /// the clock is not believed.
  SwellPlan? planSwell({required Duration earliest}) {
    final anchor = _anchor;
    if (anchor == null || !trusted) return null;
    var n = ScoreForm.beatAtOrAfter(earliest - anchor);
    if (n.isOdd) n++;
    final beatAt = ScoreForm.beatAt(anchor, n);
    return SwellPlan(
      beat: n,
      file: (n ~/ 2) % ScoreForm.swellCount,
      beatAt: beatAt,
      startAt: beatAt - ScoreForm.swellPreRoll - lag,
    );
  }
}
