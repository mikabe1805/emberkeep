// What the fight sounds and feels like, apart from what it shows.
//
// The scene only says what happened ([BrawlSound]); a [BrawlFeel] decides how
// that is heard and felt. The app's [AppBrawlFeel] answers with the app's own
// sounds (soft hand materials for hits, the class chime's pitches for crits
// and the finisher, nothing harsh), muted by the app's sound toggle, and
// with its haptics, which Reduce Motion softens. Tests use [SilentFeel] or
// [RecordingFeel].
library;

import 'package:flutter/foundation.dart' show visibleForTesting;

import '../../audio.dart';
import '../../haptics.dart';

/// Everything the fight can make a sound or a tap for.
enum BrawlSound {
  versus,
  ui,
  round,
  fight,
  jump,
  airJump,
  land,
  swing,
  hit,
  crit,
  doubleCrit,
  heavy,
  soft,
  spellHit,
  friendHit,
  charge,
  ready,
  slam,
  cast,
  call,
  superCharge,
  superHit,
  superBlast,
  meter,
  telegraph,
  teleFog,
  wave,
  drop,
  splash,
  dodge,
  hurt,
  getup,
  wind,
  locked,
  finishIt,
  finToss,
  tuck,
  lullaby,
  blow,
  cloudWater,
  bloom,
  ko,

  /// The K.O.'s rising line after its first note: [index] 1 to 3.
  koRise,
  perfect,
  victory,
  chest,
}

abstract class BrawlFeel {
  const BrawlFeel();

  /// [k] is the combo count for hits, [power] how hard a landing was (0 to
  /// 800 and up), [index] which hit of a flurry.
  void play(BrawlSound sound, {int k = 0, double power = 0, int index = 0});
}

/// Makes no sound and no tap.
class SilentFeel extends BrawlFeel {
  const SilentFeel();

  @override
  void play(BrawlSound sound, {int k = 0, double power = 0, int index = 0}) {}
}

/// Keeps what it was told, for tests.
class RecordingFeel extends BrawlFeel {
  final List<BrawlSound> heard = [];

  @override
  void play(BrawlSound sound, {int k = 0, double power = 0, int index = 0}) =>
      heard.add(sound);

  int count(BrawlSound sound) => heard.where((s) => s == sound).length;
}

/// The app's own sounds and haptics.
class AppBrawlFeel extends BrawlFeel {
  AppBrawlFeel({this.reduceMotion = false});

  /// Reduce Motion: only a single light tap now and then.
  final bool reduceMotion;

  DateTime _lastHaptic = DateTime.fromMillisecondsSinceEpoch(0);

  Sfx get _sfx => Sfx.instance;

  /// Haptics are never more than one every [gap] milliseconds, so a flurry is
  /// a texture and not a buzz.
  bool _tap(int gap) {
    final now = DateTime.now();
    if (now.difference(_lastHaptic).inMilliseconds < gap) return false;
    _lastHaptic = now;
    return true;
  }

  /// The class chime's rising line, D5 E5 F#5 A5 B5 D6: step 1 to 6.
  void _chime(int step, [double v = 0.8]) =>
      _sfx.playClassChime(step, volumeScale: v);

  @override
  void play(BrawlSound sound, {int k = 0, double power = 0, int index = 0}) {
    switch (sound) {
      case BrawlSound.versus:
      case BrawlSound.ui:
        _sfx.playMaterial(MaterialSound.parchment, volumeScale: 0.8);
      case BrawlSound.round:
        _sfx.playMaterial(MaterialSound.brass, volumeScale: 0.7);
      case BrawlSound.fight:
        _sfx.playMaterial(MaterialSound.brass, volumeScale: 0.9);
        if (!reduceMotion) Haptics.light();
      case BrawlSound.jump:
      case BrawlSound.airJump:
        _sfx.playMaterial(MaterialSound.parchment, volumeScale: 0.35);
      case BrawlSound.land:
        if (power > 500) {
          _sfx.playMaterial(MaterialSound.stone, volumeScale: 0.45);
        }
      case BrawlSound.swing:
        break;
      case BrawlSound.hit:
        _sfx.playMaterial(
          k.isEven ? MaterialSound.parchment : MaterialSound.glass,
          volumeScale: 0.5 + 0.04 * k.clamp(0, 8),
        );
        if (!reduceMotion && _tap(120)) Haptics.tap();
      case BrawlSound.soft:
        _sfx.playMaterial(MaterialSound.parchment, volumeScale: 0.4);
      case BrawlSound.friendHit:
        _sfx.playMaterial(MaterialSound.glass, volumeScale: 0.5);
      case BrawlSound.crit:
        _chime(3 + (k ~/ 4).clamp(0, 3), 0.75);
        if (_tap(90)) Haptics.light();
      case BrawlSound.doubleCrit:
        _chime(5, 0.85);
        if (_tap(90)) Haptics.detent();
      case BrawlSound.heavy:
        _sfx.playMaterial(MaterialSound.stone, volumeScale: 0.85);
        if (_tap(100)) Haptics.detent();
      case BrawlSound.spellHit:
        _sfx.playMaterial(MaterialSound.glass, volumeScale: 0.8);
        if (!reduceMotion && _tap(120)) Haptics.tap();
      case BrawlSound.charge:
        _sfx.playMaterial(MaterialSound.glass, volumeScale: 0.3);
      case BrawlSound.ready:
        _chime(2, 0.6);
        if (_tap(90)) Haptics.light();
      case BrawlSound.slam:
        break;
      case BrawlSound.cast:
        _sfx.playMaterial(MaterialSound.glass, volumeScale: 0.7);
      case BrawlSound.call:
        _chime(4, 0.7);
      case BrawlSound.superCharge:
        _chime(1, 0.8);
        _chime(3, 0.7);
      case BrawlSound.superHit:
        if (index.isEven) {
          _sfx.playMaterial(MaterialSound.glass, volumeScale: 0.4);
        }
      case BrawlSound.superBlast:
        _chime(6, 0.95);
        _sfx.playMaterial(MaterialSound.stone, volumeScale: 0.9);
        if (_tap(100)) Haptics.big();
      case BrawlSound.meter:
        _chime(5, 0.6);
        if (_tap(90)) Haptics.light();
      case BrawlSound.telegraph:
      case BrawlSound.teleFog:
        _sfx.playMaterial(MaterialSound.parchment, volumeScale: 0.45);
      case BrawlSound.wave:
        _sfx.playMaterial(MaterialSound.stone, volumeScale: 0.7);
        if (_tap(100)) Haptics.light();
      case BrawlSound.drop:
        _sfx.playMaterial(MaterialSound.glass, volumeScale: 0.3);
      case BrawlSound.splash:
        _sfx.playMaterial(MaterialSound.glass, volumeScale: 0.5);
      case BrawlSound.dodge:
        _chime(4, 0.55);
      case BrawlSound.hurt:
        _sfx.playMaterial(MaterialSound.parchment, volumeScale: 0.6);
        if (_tap(150)) Haptics.light();
      case BrawlSound.getup:
        _sfx.playMaterial(MaterialSound.parchment, volumeScale: 0.4);
      case BrawlSound.wind:
        _chime(2, 0.6);
      case BrawlSound.locked:
        _sfx.playMaterial(MaterialSound.parchment, volumeScale: 0.35);
      case BrawlSound.finishIt:
        _chime(5, 0.9);
        if (_tap(100)) Haptics.flourish();
      case BrawlSound.finToss:
        _sfx.playMaterial(MaterialSound.parchment, volumeScale: 0.6);
      case BrawlSound.tuck:
        _chime(2, 0.7);
      case BrawlSound.lullaby:
        _chime(1, 0.5);
      case BrawlSound.blow:
        _sfx.playMaterial(MaterialSound.parchment, volumeScale: 0.5);
      case BrawlSound.cloudWater:
        _sfx.playMaterial(MaterialSound.glass, volumeScale: 0.5);
      case BrawlSound.bloom:
        _chime(4, 0.7);
      case BrawlSound.ko:
        _chime(3, 0.8);
        if (_tap(100)) Haptics.big();
      case BrawlSound.koRise:
        // The finisher's rising line: F#5, A5, B5, D6.
        _chime(3 + index.clamp(1, 3), 0.8 + 0.05 * index);
      case BrawlSound.perfect:
        _chime(6, 0.7);
      case BrawlSound.victory:
        _sfx.playMaterial(MaterialSound.brass, volumeScale: 0.8);
      case BrawlSound.chest:
        _sfx.play('loot');
        if (_tap(100)) Haptics.flourish();
    }
  }
}

/// Lets a test fire every sound without the audio plugin.
@visibleForTesting
void brawlSilenceAudioForTests() {
  Sfx.instance.soundEnabled = false;
}
