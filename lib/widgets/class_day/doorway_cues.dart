// What the Doorway's moves say to the hand and the ear.
//
// Haptics follow the ticket: a light tap as it lifts, a medium detent as the
// stamp lands. The sounds are the room's quiet material events (a paper lift,
// brass in the bowl, wood on the shelf), played softly, and the hang is the
// class chime: a soft brass note whose pitch climbs the room's pentatonic as
// the day's classes are kept (the first class D, the second E, then F#, A, B
// and the octave D, and round again), so a day sounds as a small rising line
// and never one repeated note. This file is the one place that chooses which
// sound answers which move.
library;

import 'package:flutter/foundation.dart';

import '../../audio.dart';
import '../../haptics.dart';

/// The cues the stage fires as its moves reach them. Subclass to listen (a
/// test does); the default plays the real haptics and sounds.
class DoorwayCues {
  const DoorwayCues();

  /// How loud the chime plays against its master (the files carry the level
  /// ladder; the Doorway keeps its sounds soft).
  static const double chimeVolume = 0.8;

  /// The step of the chime's line (1 to [Sfx.classChimeSteps]) for the
  /// [position]th class kept today: D5, E5, F#5, A5, B5, the octave D6, then
  /// round again from D5. A position below one is the first.
  static int chimeStepFor(int position) {
    final n = position < 1 ? 1 : position;
    return (n - 1) % Sfx.classChimeSteps + 1;
  }

  /// The ticket lifts from behind the brass lip.
  void lift() {
    Haptics.light();
    _play(MaterialSound.parchment, 0.5);
  }

  /// The stamp lands.
  void stamp() => Haptics.detent();

  /// The ticket reaches its hook. [position] is how many classes are kept
  /// today with this one (the first is 1): the chime sounds that step of the
  /// field's rising line. A class set aside never counts, and an undone class
  /// kept again takes the next free place.
  void hang(int position) {
    try {
      Sfx.instance.playClassChime(
        chimeStepFor(position),
        volumeScale: chimeVolume,
      );
    } catch (e) {
      debugPrint('Doorway chime failed (continuing silent): $e');
    }
  }

  /// The day's tickets land in the bowl.
  void bowl() => _play(MaterialSound.brass, 0.7);

  /// The week's bundle settles on the shelf.
  void shelf() => _play(MaterialSound.wood, 0.6);

  /// A class slips out of its holder ("Couldn't make it"): a whisper.
  void slip() => _play(MaterialSound.parchment, 0.25);

  static void _play(MaterialSound material, double volume) {
    try {
      Sfx.instance.playMaterial(material, volumeScale: volume);
    } catch (e) {
      debugPrint('Doorway cue failed (continuing silent): $e');
    }
  }
}
