// The faces of the house's rooms, for tests that measure them. A widget test
// paints every family it has not loaded in a square stand-in whose glyphs are
// far wider than the real ones, so a wall label's width (and what it runs
// under) or a stat's numerals would be measured wrong. These are loaded under
// the names the code uses.
import 'package:flutter/services.dart' show FontLoader, rootBundle;

/// The Goals room's two faces: JetBrains Mono (the labels) and EB Garamond
/// (the sign and the card).
Future<void> loadGoalsRoomFonts() async {
  final mono = FontLoader('JetBrainsMono')
    ..addFont(rootBundle.load('assets/google_fonts/JetBrainsMono-SemiBold.ttf'))
    ..addFont(rootBundle.load('assets/google_fonts/JetBrainsMono-Bold.ttf'));
  final garamond = FontLoader('EBGaramond')
    ..addFont(rootBundle.load('assets/google_fonts/EBGaramond-Variable.ttf'))
    ..addFont(
      rootBundle.load('assets/google_fonts/EBGaramond-Italic-Variable.ttf'),
    );
  await Future.wait([mono.load(), garamond.load()]);
}

/// The HUD's faces (the numerals' Fraunces and the labels' JetBrains Mono),
/// for tests that measure its stat row.
Future<void> loadHudFonts() async {
  final fraunces = FontLoader('Fraunces')
    ..addFont(rootBundle.load('assets/google_fonts/Fraunces-Bold.ttf'))
    ..addFont(rootBundle.load('assets/google_fonts/Fraunces-SemiBold.ttf'))
    ..addFont(
      rootBundle.load('assets/google_fonts/Fraunces-SemiBoldItalic.ttf'),
    );
  final mono = FontLoader('JetBrainsMono')
    ..addFont(rootBundle.load('assets/google_fonts/JetBrainsMono-SemiBold.ttf'))
    ..addFont(rootBundle.load('assets/google_fonts/JetBrainsMono-Bold.ttf'));
  await Future.wait([fraunces.load(), mono.load()]);
}
