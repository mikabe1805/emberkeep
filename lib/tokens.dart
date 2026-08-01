import 'package:flutter/material.dart';

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
  // Moss and CARE are the same pigment; they were two near-identical greens.
  static const success = Color(0xFF9CBC88); // moss light — complete
  static const unlock = Color(0xFFC9A3DC); // plum light — unlocks / crit
  static const info = Color(0xFF8FBAB6); // teal light — evidence
  static const verify = Color(0xFF93A7E0); // periwinkle — proof / verified
  static const dread = Color(0xFF9AABB8); // moonlit steel — dreaded tasks

  // Destructive-action tint. Deliberately redder than Stat.str's BODY rose
  // (0xFFE89090) so an "Abandon"/"Delete" on a BODY-domain thing doesn't wear
  // the same hue as the thing's own accent — danger has to read as danger.
  static const danger = Color(0xFFE57468);

  // Dialog chrome, tokenized (was inlined ~20 places): the scrim behind a
  // modal and the warm smoked-glass surface a GlassPanel dialog sits on.
  static const dialogBarrier = Color(0xCC140C06);
  static const dialogSurface = Color(0xF22A211D);

  // The HUD/dock slab. Measured against the approved board art, the chrome
  // there sits at ~0.13 value while the room's wall sits at ~0.20 — the panel
  // is DARKER than the space behind it, so the room stays the lit thing and
  // the glass reads as a pane held up against it. The previous recipe (a light
  // wood tint over a BackdropFilter) landed at 0.35 and read as frosted
  // plastic, which flattened the whole first frame. Keep this dark.
  static const hudGlass = Color(0xD11A120E);

  // A card is a dark plane the room does NOT shine through. The old recipe
  // (glassFill lerped toward the desk wood, ~18% opacity) let the lit room
  // through at ~0.44 value — the cards came out brighter than the wall behind
  // them, and a screen where everything is mid-grey has nothing left to glow.
  static const cardGlass = Color(0xC2211812);

  // Glass recipe — dark glass holding warm light
  static const glassFill = Color(0x17FFF2DC); // rgba(255,242,220,.09)
  static const glassEdge = Color(0x2EFFEFD2); // warm edge highlight
  static const glassRim = Color(
    0x24140C06,
  ); // dark lower rim (the pane's shadow)
  static const specular = Color(0xFFFFF4D9); // cream drop-of-light
  static const warmShadow = Color(0x59140C06); // deep espresso shadow
  static const honeyGlow = Color(0x52E0A865); // warm halo for CTAs

  // A pane of glass is brighter where the candlelight catches its top lip and
  // dimmer toward the bottom — a vertical fill gradient reads as a lit surface
  // rather than a painted rectangle (round-24 depth pass).
  static const glassTop = Color(0x22FFF2DC); // top: catching the light
  static const glassBottom = Color(0x0BFFF2DC); // bottom: settling into shadow

  // The one gold CTA ramp — satin physical gold, not a mustard slab and not an
  // orange block. Measured off the approved target's MARK COMPLETE: a lit upper
  // plane around (216,168,102), a mid body around (194,142,80) and a lower
  // plane around (169,118,63), i.e. ~0.59 saturation and a value range that
  // stays *inside* metal. The previous recipe peaked at 0xFFF6D9A2 (near-white,
  // read as plastic) while the Quest control ran to 0xFF9B5A1D (0.81 sat, read
  // as an orange block). Both are the same material now.
  // [onHoney] is the engraved ink that sits on it.
  static const honeyGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFDDB474),
      Color(0xFFCE9C5B),
      Color(0xFFBE884C),
      Color(0xFFA9743D),
    ],
    stops: [0.0, 0.26, 0.62, 1.0],
  );
  static const onHoney = Color(0xFF4A2F1A);

  /// Gold hardware, in the three values it actually needs.
  /// [brass] is the resting rim (aged, quiet); [brassLit] is the catch-light
  /// along a top lip; [brassDeep] is the under-lip a raised plate sits on.
  static const brass = Color(0xFF8E6134);
  static const brassLit = Color(0xFFF3DDAE);
  static const brassDeep = Color(0xFF4C2F13);

  /// The recessed channel every progress rail is cut into. Dark, warm, and
  /// darker than the panel it sits in — a rail is a groove, not a light strip.
  static const railTrack = Color(0x5C120C08);
  static const railRim = Color(0x33FFE0AE);
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
/// Hues are warm-keyed off the approved targets, where every domain glyph is a
/// pigment lit by the same candle. Two of them had real defects:
/// PEOPLE was 0xFFF0AFAF against BODY's 0xFFE89090 — the same pink twice, so a
/// PEOPLE quest ring and a BODY quest ring were not distinguishable; and HOME
/// was 0xFFB3A897, a neutral bark that made every HOME ring, medallion and
/// progress rail read *disabled*. PEOPLE is now terracotta and HOME is aged
/// bronze — still below [Palette.xp] so honey keeps meaning "actionable".
enum Stat {
  str(
    'BODY',
    'Body',
    Color(0xFFE0908A), // ember rose
    'Moving and training your body.',
    'workouts, walks, sports, stretching',
  ),
  vit(
    'CARE',
    'Care',
    Color(0xFF9CBC88), // moss
    'Keeping yourself and what you tend alive and well.',
    'meals, sleep, water, meds, plants, pets',
  ),
  intl(
    'MIND',
    'Mind',
    Color(0xFF8AAFC6), // dusk blue
    'Feeding your head.',
    'reading, learning, reflecting',
  ),
  foc(
    'CRAFT',
    'Craft',
    Color(0xFFAE9AC4), // lilac
    'Focused work and making things.',
    'deep work, projects, practice, skills',
  ),
  soc(
    'PEOPLE',
    'People',
    Color(0xFFDD9A72), // terracotta
    'Tending the people in your life.',
    'reaching out, friends, family, plans',
  ),
  dis(
    'HOME',
    'Home',
    Color(0xFFC79355), // aged bronze
    'Keeping your space in order.',
    'chores, tidying, errands, repairs',
  );

  const Stat(this.abbr, this.label, this.color, this.blurb, this.examples);
  final String abbr;
  final String label;
  final Color color;

  /// One warm line: what this domain is for.
  final String blurb;

  /// A few concrete things that belong here — the disambiguator.
  final String examples;
}

/// The glyph that carries a domain when there is no room for its word — the
/// header row reads icon-first, the way the approved board art does. Tokenized
/// here so the six domains keep one mark each everywhere they appear.
extension StatGlyph on Stat {
  IconData get icon => switch (this) {
    Stat.str => Icons.favorite_outline, // BODY — a heart
    Stat.vit => Icons.eco_outlined, // CARE — a leaf
    Stat.intl => Icons.visibility_outlined, // MIND — an eye
    Stat.foc => Icons.handyman_rounded, // CRAFT — crossed maker tools
    Stat.soc => Icons.people_alt_rounded, // PEOPLE — two figures
    Stat.dis => Icons.home_rounded, // HOME — a house
  };
}

/// Motion vocabulary. The 100ms rule: first feedback frame lands inside
/// [ack]. Ease-out for responses to input; ease-in-out for ambient motion.
abstract final class Motion {
  static const ack = Duration(milliseconds: 90); // press acknowledgment
  static const quick = Duration(milliseconds: 220); // checkmark, squash
  static const settle = Duration(milliseconds: 420); // card sweep, chip pulse
  static const barFill = Duration(milliseconds: 650); // XP bar fill
  static const bubbleStagger = Duration(milliseconds: 85); // tighter cascade
  // Completion receipts are one protected, readable rail now—not a pile of
  // bubbles. Give the user enough time to understand what changed.
  static const bubbleLife = Duration(milliseconds: 3000);
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
  static const TextStyle numerals = TextStyle(
    fontFamily: 'Fraunces',
    fontFeatures: [FontFeature.tabularFigures()],
    fontWeight: FontWeight.w700,
    fontSize: 18,
    letterSpacing: 0.2,
    color: Palette.textHi,
  );

  static const TextStyle display = TextStyle(
    fontFamily: 'Fraunces',
    fontWeight: FontWeight.w600,
    fontSize: 22,
    color: Palette.textHi,
  );

  static const TextStyle body = TextStyle(
    fontFamily: 'Inter',
    fontWeight: FontWeight.w500,
    fontSize: 16,
    color: Palette.textMid,
  );

  static const TextStyle label = TextStyle(
    fontFamily: 'JetBrainsMono',
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
  }) => BoxDecoration(
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
