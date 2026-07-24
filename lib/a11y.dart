import 'package:flutter/foundation.dart';

/// The in-app text-size multiplier (accessibility, round-65). Kept OUTSIDE the
/// widget tree so `MaterialApp.builder` — which sits above the GameState — can
/// react to it. The settings screen mirrors [GameState.textScale] here on every
/// change, boot restores it from the save, and main.dart composes it with the
/// phone's own Text Size setting (taking the larger of the two, then clamping).
final appTextScale = ValueNotifier<double>(1.0);

/// The offered presets (label + multiplier). Capped conservatively so the dense
/// candlelit cards stay intact; anything larger needs a dedicated layout pass.
const textScalePresets = <(String, double)>[
  ('Default', 1.0),
  ('Large', 1.15),
  ('Larger', 1.3),
  ('Largest', 1.5),
];

/// The hard ceiling applied after combining the in-app and OS settings.
const maxTextScale = 1.5;
