import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// The in-app text-size multiplier (accessibility, round-65). Kept OUTSIDE the
/// widget tree so `MaterialApp.builder` — which sits above the GameState — can
/// react to it. The settings screen mirrors [GameState.textScale] here on every
/// change, boot restores it from the save, and main.dart composes it with the
/// phone's own Text Size setting without weakening the platform preference.
final appTextScale = ValueNotifier<double>(1.0);

/// The offered in-app presets (label + multiplier). These are convenient
/// choices, not a ceiling: a larger Android/iOS accessibility setting remains
/// authoritative.
const textScalePresets = <(String, double)>[
  ('Default', 1.0),
  ('Large', 1.15),
  ('Larger', 1.3),
  ('Largest', 1.5),
];

/// Preserve the platform's scaler—including nonlinear accessibility scaling—
/// while treating the in-app setting as a minimum requested size.
TextScaler roomTextScaler(TextScaler platform, double inApp) =>
    platform.clamp(minScaleFactor: inApp);
