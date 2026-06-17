import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens — "Candlelit Glass" (Art Direction v3): the owner's cozy
/// liquid-glass language on a dark, warm canvas. Espresso/plum-dusk night,
/// honey glass that glows, soft colors as light sources. Never light
/// parchment (hurts the owner's eyes), never cold grey-black.
abstract final class Palette {
  // Canvas — warm night, never grey
  static const parchment = Color(0xFF191210); // espresso night (canvas)
  static const paper = Color(0xFF231A20); // plum dusk (canvas low)
  static const card = Color(0xFF2A211D); // elevated warm surface

  // Ink — candlelight cream, never pure white
  static const textHi = Color(0xFFF4EADB);
  static const textMid = Color(0xFFCFC2B0);
  static const textLo = Color(0xFF94887A);

  // Mechanics — brightened to glow against the night
  static const xp = Color(0xFFE0A865); // honey glow — XP / level
  static const xpLight = Color(0xFFF2CD93); // bright honey highlights
  static const streak = Color(0xFFE8915A); // ember
  static const success = Color(0xFF9BC08F); // moss light — complete
  static const unlock = Color(0xFFC9A3DC); // plum light — unlocks / crit
  static const info = Color(0xFF8FBAB6); // teal light — evidence
  static const verify = Color(0xFF93A7E0); // periwinkle — proof / verified
  static const dread = Color(0xFF9AABB8); // moonlit steel — dreaded tasks

  // Glass recipe — dark glass holding warm light
  static const glassFill = Color(0x17FFF2DC); // rgba(255,242,220,.09)
  static const glassEdge = Color(0x2EFFEFD2); // warm edge highlight
  static const specular = Color(0xFFFFF4D9); // cream drop-of-light
  static const warmShadow = Color(0x59140C06); // deep espresso shadow
  static const honeyGlow = Color(0x52E0A865); // warm halo for CTAs
}

/// The six attributes — luminous warm hues for the night canvas.
enum Stat {
  str('STR', 'Strength', Color(0xFFE89090)), // ember rose
  vit('VIT', 'Vitality', Color(0xFF9BC08F)), // moss light
  intl('INT', 'Intellect', Color(0xFF85B7CE)), // moonlit teal-blue
  foc('FOC', 'Focus', Color(0xFFB79BC8)), // dusty lilac
  soc('SOC', 'Social', Color(0xFFF0AFAF)), // bloom light
  dis('DIS', 'Discipline', Color(0xFFB3A897)); // pale bark

  const Stat(this.abbr, this.label, this.color);
  final String abbr;
  final String label;
  final Color color;
}

/// Motion vocabulary. The 100ms rule: first feedback frame lands inside
/// [ack]. Ease-out for responses to input; ease-in-out for ambient motion.
abstract final class Motion {
  static const ack = Duration(milliseconds: 90); // press acknowledgment
  static const quick = Duration(milliseconds: 220); // checkmark, squash
  static const settle = Duration(milliseconds: 420); // card sweep, chip pulse
  static const barFill = Duration(milliseconds: 650); // XP bar fill
  static const bubbleStagger = Duration(milliseconds: 120);
  static const bubbleLife = Duration(milliseconds: 1900);
  static const takeover = Duration(milliseconds: 700); // level-up slam

  static const respond = Curves.easeOutCubic;
  static const ambient = Curves.easeInOut;

  /// Progress bars accelerate INTO the end (perceived-duration studies):
  /// slow start, fast finish, no stall near full.
  static const barCurve = Curves.easeInQuad;
  static const slam = Curves.elasticOut;
}

/// Typography: Fraunces for display numerals/headers (the owner's editorial
/// serif), Inter for body, mono-style ALL-CAPS for labels.
abstract final class Type {
  /// Numbers are the heroes: big, animated count-ups, soft serif warmth.
  static TextStyle get numerals => GoogleFonts.fraunces(
        fontFeatures: const [FontFeature.tabularFigures()],
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
        color: Palette.textHi,
      );

  static TextStyle get display => GoogleFonts.fraunces(
        fontWeight: FontWeight.w600,
        color: Palette.textHi,
      );

  static TextStyle get body => GoogleFonts.inter(
        fontWeight: FontWeight.w500,
        color: Palette.textMid,
      );

  static TextStyle get label => GoogleFonts.jetBrainsMono(
        fontWeight: FontWeight.w600,
        letterSpacing: 1.1,
        color: Palette.textLo,
      );
}

/// Shared glass decoration helpers (the cheap, no-backdrop-blur variant —
/// translucent warm fill + edge highlight + warm shadow; reserve real
/// BackdropFilter blur for the header and nav dock).
abstract final class Glass {
  static BoxDecoration panel({
    double radius = 20,
    Color? tint,
    bool glow = false,
  }) =>
      BoxDecoration(
        color: tint ?? Palette.glassFill,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Palette.glassEdge, width: 1.2),
        boxShadow: [
          const BoxShadow(
            color: Palette.warmShadow,
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
          if (glow)
            const BoxShadow(
              color: Palette.honeyGlow,
              blurRadius: 22,
              offset: Offset(0, 8),
            ),
        ],
      );
}
