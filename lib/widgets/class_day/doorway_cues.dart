// What the Doorway's moves say to the hand and the ear.
//
// Haptics follow the ticket: a light tap as it lifts, a medium detent as the
// stamp lands. The sounds are the room's existing quiet material events (a
// paper lift, a brass click as it hangs, brass in the bowl, wood on the
// shelf), played softly; a new palette for them comes later, and only this
// file changes when it does.
library;

import 'package:flutter/foundation.dart';

import '../../audio.dart';
import '../../haptics.dart';

/// The cues the stage fires as its moves reach them. Subclass to listen (a
/// test does); the default plays the real haptics and sounds.
class DoorwayCues {
  const DoorwayCues();

  /// The ticket lifts from behind the brass lip.
  void lift() {
    Haptics.light();
    _play(MaterialSound.parchment, 0.5);
  }

  /// The stamp lands.
  void stamp() => Haptics.detent();

  /// The ticket reaches its hook.
  void hang() => _play(MaterialSound.brass, 0.55);

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
