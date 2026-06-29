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
  static const glassRim = Color(0x24140C06); // dark lower rim (the pane's shadow)
  static const specular = Color(0xFFFFF4D9); // cream drop-of-light
  static const warmShadow = Color(0x59140C06); // deep espresso shadow
  static const honeyGlow = Color(0x52E0A865); // warm halo for CTAs

  // A pane of glass is brighter where the candlelight catches its top lip and
  // dimmer toward the bottom — a vertical fill gradient reads as a lit surface
  // rather than a painted rectangle (round-24 depth pass).
  static const glassTop = Color(0x22FFF2DC); // top: catching the light
  static const glassBottom = Color(0x0BFFF2DC); // bottom: settling into shadow

  // The one honey CTA gradient — a lozenge of warm glass with a top sheen, dim
  // amber base. Tokenized so every gold button reads identically (was inlined
  // ~8 places). [onHoney] is the ink that sits on it.
  static const honeyGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFF6D9A2), Color(0xFFEFC074), Color(0xFFC08B4F)],
    stops: [0.0, 0.5, 1.0],
  );
  static const onHoney = Color(0xFF4A2F1A);
}

/// The six LIFE DOMAINS you level up — tangible parts of a life, not abstract
/// RPG attributes (the owner wanted to "level up my home, my caretaking").
/// The enum identifiers stay (str/vit/… ) so saves — which store the index —
/// and every switch/title key keep working; only the names/abbrs are domains.
///
/// [blurb] (one warm line of meaning) and [examples] (a few concrete things,
/// chosen to draw clean lines between the easily-confused domains — BODY is
/// exertion, CARE is keeping living things well, HOME is the physical space)
/// are surfaced wherever you pick a domain, so "which one is this?" answers
/// itself at categorization time.
enum Stat {
  str('BODY', 'Body', Color(0xFFE89090), // ember rose
      'Moving and training your body.', 'workouts, walks, sports, stretching'),
  vit('CARE', 'Care', Color(0xFF9BC08F), // moss
      'Keeping yourself and what you tend alive and well.',
      'meals, sleep, water, meds, plants, pets'),
  intl('MIND', 'Mind', Color(0xFF85B7CE), // teal-blue
      'Feeding your head.', 'reading, learning, reflecting'),
  foc('CRAFT', 'Craft', Color(0xFFB79BC8), // lilac
      'Focused work and making things.',
      'deep work, projects, practice, skills'),
  soc('PEOPLE', 'People', Color(0xFFF0AFAF), // bloom
      'Tending the people in your life.',
      'reaching out, friends, family, plans'),
  dis('HOME', 'Home', Color(0xFFB3A897), // warm bark
      'Keeping your space in order.', 'chores, tidying, errands, repairs');

  const Stat(this.abbr, this.label, this.color, this.blurb, this.examples);
  final String abbr;
  final String label;
  final Color color;

  /// One warm line: what this domain is for.
  final String blurb;

  /// A few concrete things that belong here — the disambiguator.
  final String examples;
}

/// Motion vocabulary. The 100ms rule: first feedback frame lands inside
/// [ack]. Ease-out for responses to input; ease-in-out for ambient motion.
abstract final class Motion {
  static const ack = Duration(milliseconds: 90); // press acknowledgment
  static const quick = Duration(milliseconds: 220); // checkmark, squash
  static const settle = Duration(milliseconds: 420); // card sweep, chip pulse
  static const barFill = Duration(milliseconds: 650); // XP bar fill
  static const bubbleStagger = Duration(milliseconds: 85); // tighter cascade
  static const bubbleLife = Duration(milliseconds: 1500);
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
///
/// Each base style now carries a DEFAULT fontSize sized for a phone held at
/// arm's length — the floor of a readable scale (mobile accessibility pass).
/// Call sites may still .copyWith(fontSize:) for hero numerals etc., but the
/// floor below keeps anything unspecified from rendering hairline-thin, and
/// [Type.minLabel] is the smallest size any caps-label should ever use.
abstract final class Type {
  /// Smallest readable caps-label on the dark canvas. Nothing below this.
  static const double minLabel = 11;

  /// Numbers are the heroes: big, animated count-ups, soft serif warmth.
  static TextStyle get numerals => GoogleFonts.fraunces(
        fontFeatures: const [FontFeature.tabularFigures()],
        fontWeight: FontWeight.w700,
        fontSize: 18,
        letterSpacing: 0.2,
        color: Palette.textHi,
      );

  static TextStyle get display => GoogleFonts.fraunces(
        fontWeight: FontWeight.w600,
        fontSize: 22,
        color: Palette.textHi,
      );

  static TextStyle get body => GoogleFonts.inter(
        fontWeight: FontWeight.w500,
        fontSize: 16,
        color: Palette.textMid,
      );

  static TextStyle get label => GoogleFonts.jetBrainsMono(
        fontWeight: FontWeight.w600,
        fontSize: minLabel,
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
        // a vertical fill — lit at the top lip, settling into shadow below —
        // unless an opaque [tint] is requested (dialogs want a solid surface).
        color: tint,
        gradient: tint == null
            ? const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Palette.glassTop, Palette.glassBottom],
              )
            : null,
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
