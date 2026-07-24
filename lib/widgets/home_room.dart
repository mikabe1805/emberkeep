import 'dart:math' show pi, sin;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show listEquals, setEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../tokens.dart';

/// "Your Space" — a cozy, code-painted room the avatar lives in, that fills
/// with earned furniture as you grow (round-40, the home/world scaffold). The
/// painter switches on the unlocked piece-ids from content/furniture.dart.
/// Phase 1: a warm room + window + the pieces; later phases add placement,
/// nicer art, and visiting others' rooms.
const _defaultWall = [Color(0xFF2E2229), Color(0xFF3A2C2A)];
const _defaultFloor = [Color(0xFF3C2C20), Color(0xFF2A1D14)];

/// Painterly grain for the wall/floor — a whisper of brush-stroke texture
/// (assets/room/, extracted from the room concept paintings by
/// tools/gen_room_textures.py) softLight-blended over the flat style
/// gradients, so every purchased style keeps its exact colours but stops
/// reading as a vector-flat fill. Loads once, lazily; until the images land
/// (or if they're ever missing) the room paints exactly as before.
class _RoomGrain {
  static ui.Image? wall;
  static ui.Image? floor;
  static bool _requested = false;

  /// Bumped when a texture finishes decoding, so live rooms repaint.
  static final ValueNotifier<int> version = ValueNotifier(0);

  static void ensure() {
    if (_requested) return;
    _requested = true;
    _load('assets/room/wall_grain.png', (i) => wall = i);
    _load('assets/room/floor_grain.png', (i) => floor = i);
  }

  static Future<void> _load(String asset, void Function(ui.Image) set) async {
    try {
      final bytes = await rootBundle.load(asset);
      final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
      set((await codec.getNextFrame()).image);
      version.value++;
    } catch (_) {
      // a missing grain texture is fine — the room just paints flat
    }
  }
}

/// Maps a player [level] to the hearth's visual stage 0..5, matching the
/// "YOUR HEARTH GROWS" milestones on the Me page (First Spark L5 → Steady Flame
/// L10 → Bright Crest L16 → Twin Fire L24 → Everflame L34). Kept here so the
/// keep's own hearth and the daily-HUD [HearthGlyph] read the same tiers from
/// one source of truth.
int hearthStageForLevel(int level) {
  if (level >= 34) return 5;
  if (level >= 24) return 4;
  if (level >= 16) return 3;
  if (level >= 10) return 2;
  if (level >= 5) return 1;
  return 0;
}

class HomeRoom extends StatefulWidget {
  const HomeRoom({
    super.key,
    required this.unlocked,
    this.child,
    this.aspect = 1.7,
    this.wall = _defaultWall,
    this.floor = _defaultFloor,
    this.window = 'moon',
    this.petAwake = false,
    this.emberGlow,
    this.level = 1,
    this.lively = true,
  });

  /// Furniture piece-ids the player owns (GameState.ownedFurniture) — what
  /// the room draws. Bought in the shop with embers (content/furniture.dart).
  final Set<String> unlocked;

  /// Optional overlay in the middle of the room. Round-62 pivot: the keep has
  /// no creature, so this is normally null — the hearth is the heart now.
  final Widget? child;
  final double aspect;

  /// The chosen wall / floor gradient colours (content/room_styles.dart) — two
  /// stops each. Default = the original Walnut/Oak look.
  final List<Color> wall;
  final List<Color> floor;

  /// The scene painted outside the window (content/window_scenes.dart).
  final String window;

  /// Whether the keep's hearth-fire is LIT (you're keeping your streak) vs
  /// banked to glowing embers (you've been away). The heart of "Emberkeep":
  /// show up and the fire burns; the little pet by the fire wakes too.
  final bool petAwake;

  /// The hearth-flame's mid-tone colour — its firelight pools on the floor and
  /// the flames take this hue (amber by default; a chosen flame colour tints
  /// the whole keep warm). Null = default honey/amber fire.
  final Color? emberGlow;

  /// The player's level — the hearth burns taller/brighter as it climbs the
  /// tiers (see [hearthStageForLevel]), making the "YOUR HEARTH GROWS"
  /// milestones real instead of text. Defaults to 1 for preview/visit callers.
  final int level;

  /// The ambient-life switch (round-61): fire flickers, candles sway, rain
  /// falls, dust drifts. Pass `!state.reduceMotion` once the app wires it up;
  /// the OS-level disable-animations switch is honoured regardless. Off, the
  /// room paints one calm still frame — same beauty, parked.
  final bool lively;

  @override
  State<HomeRoom> createState() => _HomeRoomState();
}

class _HomeRoomState extends State<HomeRoom>
    with SingleTickerProviderStateMixin {
  /// ONE slow loop drives every ambient motion in the room — hearth, candles,
  /// garland, weather, dust. Quantized to ~11fps (MascotSprite's trick) inside
  /// its own RepaintBoundary, so a living room costs a handful of small
  /// repaints a second, not a 60fps rebuild of the screen. Created lazily and
  /// only while [HomeRoom.lively] + the OS animation setting allow it.
  AnimationController? _life;

  @override
  void dispose() {
    _life?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _RoomGrain.ensure();
    final lively =
        widget.lively &&
        !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    if (lively && _life == null) {
      _life = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 10),
      )..repeat();
    } else if (!lively && _life != null) {
      _life!.dispose();
      _life = null;
    }
    final life = _life;
    return AspectRatio(
      aspectRatio: widget.aspect,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Positioned.fill(
              // repaint-bounded so the ambient tick repaints the room alone,
              // never the avatar (who has his own boundary) or the screen
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: life == null
                      ? _RoomGrain.version
                      : Listenable.merge([_RoomGrain.version, life]),
                  builder: (_, _) {
                    // quantize the loop to 110 steps (~11fps) — alive to the
                    // eye, near-free to paint; t=0 is the calm reduced-motion
                    // frame and every t must look finished on its own
                    final t = life == null
                        ? 0.0
                        : (life.value * 110).round() / 110;
                    return CustomPaint(
                      painter: _RoomPainter(
                        widget.unlocked,
                        widget.wall,
                        widget.floor,
                        widget.window,
                        widget.petAwake,
                        widget.emberGlow,
                        widget.level,
                        _RoomGrain.wall,
                        _RoomGrain.floor,
                        t,
                      ),
                    );
                  },
                ),
              ),
            ),
            // optional overlay (none in the keep — kept for a caller that
            // wants to place something in the room)
            if (widget.child != null)
              Align(
                alignment: const Alignment(0, 0.7),
                child: FractionallySizedBox(
                  heightFactor: 0.52,
                  child: FittedBox(child: widget.child!),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RoomPainter extends CustomPainter {
  _RoomPainter(
    Set<String> unlocked,
    this.wall,
    this.floor,
    this.window,
    this.petAwake,
    this.emberGlow,
    this.level,
    this.wallGrain,
    this.floorGrain,
    this.t,
  )
    // snapshot the furniture set: some callers hand us the live
    // GameState.ownedFurniture, which the engine mutates IN PLACE — the old
    // painter and the new one would hold the SAME instance, so an identity
    // compare in shouldRepaint went blind to purchases. A copy here plus
    // setEquals below compares what actually matters: the contents.
    : unlocked = Set.of(unlocked);
  final Set<String> unlocked;
  final List<Color> wall;
  final List<Color> floor;
  final String window;
  final bool petAwake;
  final Color? emberGlow;
  final int level;

  /// 0..1 through the slow ambient loop (quantized upstream). Every motion in
  /// here is a pure function of [t] — deterministic, seamless at the wrap, and
  /// t=0 must always be a finished, pretty still frame (reduced motion parks
  /// there, and the goldens capture wherever the pump lands).
  final double t;

  /// Brush-stroke grain (see [_RoomGrain]); null paints flat, like always.
  final ui.Image? wallGrain;
  final ui.Image? floorGrain;
  bool has(String id) => unlocked.contains(id);

  /// softLight-tile [img] over [rect] — the grain pass. The texture is
  /// normalized around mid-gray so this only *modulates* the style colour
  /// underneath, never replaces it; [opacity] is the strength knob.
  void _grain(
    Canvas canvas,
    ui.Image img,
    Rect rect,
    double featureScale,
    double opacity,
  ) {
    final s = featureScale / img.width;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ImageShader(
          img,
          TileMode.mirror,
          TileMode.mirror,
          (Matrix4.identity()..scaleByDouble(s, s, 1, 1)).storage,
        )
        ..blendMode = BlendMode.softLight
        // with a shader set, the color only contributes alpha (strength)
        ..color = Color.fromRGBO(0, 0, 0, opacity),
    );
  }

  // furniture wood tone (independent of the chosen wall/floor)
  static const _wood = Color(0xFF4A3A2C);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final floorY = h * 0.66;

    // ── back wall (recoloured by the chosen room style) ─────────────
    final wallRect = Rect.fromLTRB(0, 0, w, floorY);
    canvas.drawRect(
      wallRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: wall,
        ).createShader(wallRect),
    );
    // painterly wall grain — soft plaster mottling in the style's own colour
    if (wallGrain != null) _grain(canvas, wallGrain!, wallRect, w * 0.62, 0.8);
    // a warm light pool washing the upper wall (window moonlight + candle glow)
    // so the wall reads as a LIT surface, not a flat panel
    canvas.drawCircle(
      Offset(w * 0.32, h * 0.18),
      w * 0.4,
      Paint()
        ..color = Palette.honeyGlow.withValues(alpha: 0.18)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.17),
    );

    // ── floor (recoloured) + a warm sheen pooling where the avatar stands ──
    final floorRect = Rect.fromLTRB(0, floorY, w, h);
    canvas.drawRect(
      floorRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: floor,
        ).createShader(floorRect),
    );
    // brushed wood grain over the floor fill, same deal as the wall
    if (floorGrain != null) {
      _grain(canvas, floorGrain!, floorRect, w * 0.85, 0.8);
    }
    // a few faint plank seams fanning toward the viewer so the floor reads as
    // laid boards, not a flat sheet — darker line + a hair of highlight below
    final plankDark = Paint()
      ..color = Colors.black.withValues(alpha: 0.12)
      ..strokeWidth = 1;
    final plankLit = Paint()
      ..color = Palette.xpLight.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    for (final spec in const [-0.62, -0.24, 0.12, 0.5, 0.86]) {
      // seams splay out from a vanishing point high on the wall
      final topX = w * (0.5 + spec * 0.28);
      final botX = w * (0.5 + spec * 0.85);
      canvas.drawLine(Offset(topX, floorY), Offset(botX, h), plankDark);
      canvas.drawLine(Offset(topX + 1, floorY), Offset(botX + 1, h), plankLit);
    }
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, floorY + (h - floorY) * 0.55),
        width: w * 0.72,
        height: (h - floorY) * 0.95,
      ),
      Paint()
        ..color = Palette.honeyGlow.withValues(alpha: 0.10)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.08),
    );

    // ── the hearth's firelight pooling on the floor in front of it — the warm
    // heart of the keep. Brighter + breathing when the fire is LIT (a kept
    // streak), dimmer when banked to embers. Tinted by the chosen flame hue. ──
    final glow = emberGlow ?? Palette.honeyGlow;
    final glowBreath = 0.5 + 0.5 * sin(t * 2 * pi * 2 + 0.4);
    final lit = petAwake ? 1.0 : 0.45;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, floorY + (h - floorY) * 0.42),
        width: w * (0.5 + 0.03 * glowBreath) * (0.85 + 0.15 * lit),
        height: (h - floorY) * (0.8 + 0.05 * glowBreath),
      ),
      Paint()
        ..color = glow.withValues(alpha: (0.14 + 0.08 * glowBreath) * lit)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.07),
    );

    // ── window light shaft: a soft wedge of the outside light spilling
    // diagonally across the floor, tinted by the scene (cool silver moon,
    // warm gold dawn, teal aurora, blue-grey rain), with a few dust motes
    // adrift inside it. The room's biggest "this space is lit" tell. ──
    _lightShaft(canvas, w, h, floorY);

    // baseboard — a thin warm highlight over a soft shadow, grounding the wall
    canvas.drawRect(
      Rect.fromLTWH(0, floorY - 2, w, 3),
      Paint()..color = const Color(0x55000000),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, floorY - 2.5, w, 1),
      Paint()..color = Palette.xpLight.withValues(alpha: 0.10),
    );

    _window(canvas, w, h);
    // the keep's HEARTH — always here, the heart of the room (round-62 pivot)
    _hearth(canvas, w, h, floorY);
    // back-to-front so nearer pieces overlap farther ones
    if (has('garland')) _garland(canvas, w, h);
    if (has('shelf')) _shelf(canvas, w, h);
    if (has('picture')) _picture(canvas, w, h);
    if (has('rug')) _rug(canvas, w, h, floorY);
    if (has('cushion')) _cushion(canvas, w, h, floorY);
    if (has('lamp')) _lamp(canvas, w, h, floorY);
    if (has('chair')) _chair(canvas, w, h, floorY);
    if (has('candles')) _candles(canvas, w, h, floorY);
    if (has('plant')) _plant(canvas, w, h, floorY);
    if (has('pet')) _pet(canvas, w, h, floorY, petAwake);

    // ── FIRELIGHT PASS: the hearth is the room's light source, so its light
    // has to land ON the furniture, not only pool underneath it. One additive
    // bloom centred on the firebox, composited over everything already
    // painted, so the rug, the chair, the plant and the cat all catch the
    // fire's warmth with honest distance falloff. This is the difference
    // between a lit room and a flat illustration. ──
    _firelight(canvas, w, h, floorY);

    // ── a soft vignette: the corners settle into shadow so the lit centre
    // (where the avatar lives) reads as the warm heart of the room ──
    final all = Rect.fromLTWH(0, 0, w, h);
    canvas.drawRect(
      all,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.05),
          radius: 0.98,
          // deepened to hold contrast against the additive firelight pass —
          // the bloom lifts the whole room, so the corners have to fall
          // further for the hearth to still read as the brightest thing here
          colors: const [
            Color(0x00140C06),
            Color(0x33140C06),
            Color(0x7A140C06),
          ],
          stops: const [0.45, 0.72, 1.0],
        ).createShader(all),
    );
  }

  /// The hearth's light, composited over the finished room: an additive warm
  /// bloom centred on the firebox, a reflection smear on the floorboards, and
  /// (when the fire is kept) sparks lifting off the coals. Everything here is
  /// deterministic in [t] and scales with [level]'s hearth tier, so a bigger
  /// fire genuinely lights more of the keep.
  void _firelight(Canvas canvas, double w, double h, double floorY) {
    final u = h - floorY;
    final glow = emberGlow ?? const Color(0xFFE8915A);
    final lit = petAwake ? 1.0 : 0.42; // banked, never cold
    final breath = 0.5 + 0.5 * sin(t * 2 * pi * 2 + 0.4);
    final stage = hearthStageForLevel(level);
    final centre = Offset(w * 0.5, floorY - u * 0.16);

    // the bloom — hot cream at the core, the flame's own hue further out,
    // gone by the corners
    final bloom = Rect.fromCircle(
      center: centre,
      radius: w * (0.50 + 0.026 * stage) * (0.97 + 0.06 * breath),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(
          colors: [
            Color.lerp(
              glow,
              const Color(0xFFFFF4D9),
              0.4,
            )!.withValues(alpha: (0.125 + 0.03 * breath) * lit),
            glow.withValues(alpha: (0.042 + 0.014 * breath) * lit),
            const Color(0x00000000),
          ],
          stops: const [0.0, 0.40, 1.0],
        ).createShader(bloom),
    );

    // firelight glinting off the waxed floorboards — a soft vertical smear
    // running straight down from the hearth toward the viewer
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, floorY + u * 0.52),
        width: w * 0.24 * (0.94 + 0.1 * breath),
        height: u * 1.02,
      ),
      Paint()
        ..blendMode = BlendMode.plus
        ..color = glow.withValues(alpha: 0.075 * lit)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.05),
    );

    // sparks lifting off the coals and winking out inside the arch — the one
    // thing in the room that travels upward, so the eye keeps returning to
    // the fire. Count climbs with the hearth's tier.
    if (petAwake) {
      final count = 2 + stage ~/ 2; // 2 sparks at First Spark … 4 at Everflame
      for (var i = 0; i < count; i++) {
        final phase = (t * (1.3 + i * 0.21) + i * 0.29) % 1.0;
        final sx =
            w * 0.5 +
            w *
                (0.008 + 0.035 * phase) *
                sin(phase * pi * (1.7 + i * 0.5)) *
                (i.isEven ? 1 : -1);
        final sy = floorY - u * (0.07 + 0.34 * phase);
        // snap alight, fade slowly, shrinking as it cools
        final a = phase < 0.15 ? phase / 0.15 : 1 - (phase - 0.15) / 0.85;
        canvas.drawCircle(
          Offset(sx, sy),
          w * 0.0048 * (1 - phase * 0.5),
          Paint()
            ..blendMode = BlendMode.plus
            ..color = Color.lerp(
              const Color(0xFFFFF4D9),
              glow,
              phase,
            )!.withValues(alpha: 0.7 * a),
        );
      }
    }
  }

  /// The scene's characteristic light colour — what spills through the pane
  /// onto the floor. Derived from each window scene's own palette so the shaft
  /// always agrees with the view above it.
  Color get _shaftColor => switch (window) {
    'dawn' => const Color(0xFFF6D79A), // warm sunrise gold
    'aurora' => const Color(0xFF8FD0E0), // cold teal shimmer
    'rain' => const Color(0xFFAEB8D0), // flat blue-grey
    'forest' => const Color(0xFFBFE0C0), // green-washed moon
    'city' => const Color(0xFFE8C77A), // sodium-lamp amber
    _ => Palette.xpLight, // silver moonlight
  };

  /// A soft wedge of window light thrown diagonally across the floor, with a
  /// few dust motes turning slowly inside it. Drawn low (on the floor, behind
  /// the furniture) so pieces cast into it. Deterministic in [t].
  void _lightShaft(Canvas canvas, double w, double h, double floorY) {
    // the pane sits upper-left (see _window); the beam falls down-right
    final srcL = Offset(w * 0.10, h * 0.16);
    final srcR = Offset(w * 0.30, h * 0.16);
    final footL = Offset(w * 0.30, h);
    final footR = Offset(w * 0.66, h);
    final beam = Path()
      ..moveTo(srcL.dx, srcL.dy)
      ..lineTo(srcR.dx, srcR.dy)
      ..lineTo(footR.dx, footR.dy)
      ..lineTo(footL.dx, footL.dy)
      ..close();
    final tint = _shaftColor;
    canvas.save();
    canvas.clipPath(beam);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [tint.withValues(alpha: 0.16), tint.withValues(alpha: 0)],
        ).createShader(Rect.fromLTWH(w * 0.1, h * 0.16, w * 0.56, h * 0.84)),
    );
    // dust motes drifting in the beam — three, slow, deterministic in t
    for (var i = 0; i < 3; i++) {
      // ph rides t directly (integer coefficient) so it wraps seamlessly; the
      // alpha (sin(ph*pi)) fades the mote out at the top and in at the bottom,
      // hiding the vertical reset. x sways on an integer-frequency sine so it
      // too is continuous across the loop.
      final ph = (t + i / 3) % 1.0;
      final mx = w * (0.30 + 0.13 * sin((t + i * 0.37) * 2 * pi));
      final my = h * (0.24 + 0.66 * ph);
      canvas.drawCircle(
        Offset(mx, my),
        w * 0.004,
        Paint()
          ..color = tint.withValues(alpha: 0.35 * sin(ph * pi))
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.004),
      );
    }
    canvas.restore();
  }

  void _window(Canvas canvas, double w, double h) {
    final fx = w * 0.07, fy = h * 0.13, fw = w * 0.26, fh = h * 0.3;
    final rect = Rect.fromLTWH(fx, fy, fw, fh);
    final r = RRect.fromRectAndRadius(rect, const Radius.circular(6));
    // the view outside (clipped to the pane) — t makes the weather live
    paintWindowScene(canvas, window, rect, t: t);
    // frame + mullions on top
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = const Color(0xFF5A4536);
    canvas.drawRRect(r, edge);
    final bar = Paint()
      ..color = const Color(0xFF5A4536)
      ..strokeWidth = 2;
    canvas.drawLine(Offset(fx, fy + fh / 2), Offset(fx + fw, fy + fh / 2), bar);
    canvas.drawLine(Offset(fx + fw / 2, fy), Offset(fx + fw / 2, fy + fh), bar);
  }

  void _rug(Canvas canvas, double w, double h, double floorY) {
    final c = Offset(w * 0.5, floorY + (h - floorY) * 0.62);
    final rx = w * 0.35, ry = (h - floorY) * 0.42;
    final rect = Rect.fromCenter(center: c, width: rx * 2, height: ry * 2);
    canvas.drawOval(
      rect,
      Paint()..color = const Color(0xFF6E4A55).withValues(alpha: 0.9),
    );
    canvas.drawOval(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Palette.xpLight.withValues(alpha: 0.25),
    );
    canvas.drawOval(
      Rect.fromCenter(center: c, width: rx * 1.4, height: ry * 1.4),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFF8A6070).withValues(alpha: 0.55),
    );
  }

  void _lamp(Canvas canvas, double w, double h, double floorY) {
    final x = w * 0.115;
    final baseY = floorY + (h - floorY) * 0.46;
    final topY = h * 0.22;
    // warm glow
    canvas.drawCircle(
      Offset(x, topY + 4),
      w * 0.1,
      Paint()
        ..color = Palette.honeyGlow
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );
    // pole + base
    canvas.drawLine(
      Offset(x, topY + 8),
      Offset(x, baseY),
      Paint()
        ..color = _wood
        ..strokeWidth = 3,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(x, baseY),
        width: w * 0.08,
        height: (h - floorY) * 0.12,
      ),
      Paint()..color = _wood,
    );
    // shade
    final shade = Path()
      ..moveTo(x - w * 0.05, topY + 10)
      ..lineTo(x + w * 0.05, topY + 10)
      ..lineTo(x + w * 0.034, topY - 8)
      ..lineTo(x - w * 0.034, topY - 8)
      ..close();
    canvas.drawPath(shade, Paint()..color = Palette.xpLight);
  }

  void _shelf(Canvas canvas, double w, double h) {
    final x = w * 0.6, y = h * 0.26, sw = w * 0.3;
    // a soft shadow the shelf casts on the wall below it — grounds it to the
    // surface instead of floating (ambient-occlusion feel)
    canvas.drawRect(
      Rect.fromLTWH(x - 2, y + 3, sw + 4, 7),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawRect(Rect.fromLTWH(x, y, sw, 4), Paint()..color = _wood);
    // book spines
    const cols = [
      Palette.success,
      Palette.verify,
      Palette.unlock,
      Palette.dread,
    ];
    for (var i = 0; i < 4; i++) {
      final bw = sw * 0.12;
      final bx = x + sw * 0.08 + i * (bw + sw * 0.06);
      final bh = h * (0.05 + (i.isEven ? 0.02 : 0.0));
      canvas.drawRect(
        Rect.fromLTWH(bx, y - bh, bw, bh),
        Paint()..color = cols[i].withValues(alpha: 0.85),
      );
    }
  }

  void _picture(Canvas canvas, double w, double h) {
    final x = w * 0.46, y = h * 0.14, pw = w * 0.16, ph = h * 0.16;
    final outer = Rect.fromLTWH(x, y, pw, ph);
    // soft drop shadow on the wall behind the frame
    canvas.drawRRect(
      RRect.fromRectAndRadius(outer.translate(2, 4), const Radius.circular(3)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.20)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    // carved wood frame + inner mat
    canvas.drawRRect(
      RRect.fromRectAndRadius(outer, const Radius.circular(3)),
      Paint()..color = const Color(0xFF5A4536),
    );
    final inner = outer.deflate(pw * 0.07);
    // a cozy framed dusk: warm gradient sky, a soft moon, a gentle hill
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(inner, const Radius.circular(2)));
    canvas.drawRect(
      inner,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF45324F), Color(0xFFB5683E), Color(0xFFE8B570)],
        ).createShader(inner),
    );
    canvas.drawCircle(
      Offset(inner.left + inner.width * 0.68, inner.top + inner.height * 0.34),
      inner.width * 0.1,
      Paint()..color = const Color(0xFFFFE9B8),
    );
    final hill = Path()
      ..moveTo(inner.left, inner.bottom)
      ..lineTo(inner.left, inner.bottom - inner.height * 0.28)
      ..quadraticBezierTo(
        inner.left + inner.width * 0.5,
        inner.bottom - inner.height * 0.55,
        inner.right,
        inner.bottom - inner.height * 0.22,
      )
      ..lineTo(inner.right, inner.bottom)
      ..close();
    canvas.drawPath(hill, Paint()..color = const Color(0xFF6E4A38));
    canvas.restore();
  }

  void _chair(Canvas canvas, double w, double h, double floorY) {
    final x = w * 0.76, seatY = floorY + (h - floorY) * 0.2;
    final cw = w * 0.16, seatH = (h - floorY) * 0.3;
    final col = Paint()..color = const Color(0xFF7A4F44);
    // contact shadow on the floor — grounds the chair
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(x + cw * 0.5, seatY + seatH * 0.62),
        width: cw * 1.5,
        height: (h - floorY) * 0.12,
      ),
      Paint()
        ..color = const Color(0x40000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    // back
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, seatY - seatH * 0.9, cw, seatH * 1.1),
        const Radius.circular(8),
      ),
      col,
    );
    // seat
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x - cw * 0.1, seatY, cw * 1.2, seatH * 0.6),
        const Radius.circular(6),
      ),
      Paint()..color = const Color(0xFF8A5C50),
    );
  }

  void _plant(Canvas canvas, double w, double h, double floorY) {
    final x = w * 0.88, baseY = floorY + (h - floorY) * 0.55;
    // contact shadow — grounds the pot on the floor
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(x, baseY + (h - floorY) * 0.3),
        width: w * 0.11,
        height: (h - floorY) * 0.1,
      ),
      Paint()
        ..color = const Color(0x40000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    // pot
    final pot = Path()
      ..moveTo(x - w * 0.04, baseY)
      ..lineTo(x + w * 0.04, baseY)
      ..lineTo(x + w * 0.03, baseY + (h - floorY) * 0.3)
      ..lineTo(x - w * 0.03, baseY + (h - floorY) * 0.3)
      ..close();
    canvas.drawPath(pot, Paint()..color = const Color(0xFF8A5A3C));
    // leaves
    final leaf = Paint()..color = Palette.success.withValues(alpha: 0.9);
    for (final a in [-0.5, 0.0, 0.5]) {
      final tip = Offset(
        x + a * w * 0.05,
        baseY - (h * 0.13) * (1 - a.abs() * 0.4),
      );
      final path = Path()
        ..moveTo(x, baseY)
        ..quadraticBezierTo(
          x + a * w * 0.06 - 6,
          baseY - h * 0.06,
          tip.dx,
          tip.dy,
        )
        ..quadraticBezierTo(x + a * w * 0.06 + 6, baseY - h * 0.06, x, baseY);
      canvas.drawPath(path, leaf);
    }
  }

  /// The keep's HEARTH — the central heart of the room (round-62 pivot). Always
  /// present. When the fire is kept LIT (a live streak, [petAwake]) it burns
  /// with full flames; when you've been away it banks down to glowing embers,
  /// never cold — never-punish, the warmth is the reward for showing up. The
  /// flame takes [emberGlow]'s hue so a chosen flame colour warms the whole keep.
  void _hearth(Canvas canvas, double w, double h, double floorY) {
    final x = w * 0.5;
    final u = h - floorY;
    final hw = w * 0.30; // surround width
    final topY = h * 0.14; // the chimney breast rises high on the wall
    final flameHue = emberGlow ?? const Color(0xFFE8915A);
    final lit = petAwake ? 1.0 : 0.45;
    final flick = 1 + 0.09 * sin(t * 2 * pi * 2) + 0.05 * sin(t * 2 * pi * 3);
    // the fire climbs its tiers with your level — taller flames, a hotter
    // heart, and at Everflame a drifting spark. Never shrinks; only grows.
    final stage = hearthStageForLevel(level);
    final grow = 0.82 + 0.045 * stage; // 0.82 (baseline) .. ~1.05 (Everflame)

    // a soft wall shadow either side, grounding the breast against the wall
    canvas.drawRect(
      Rect.fromLTWH(x - hw / 2 - w * 0.02, topY, hw + w * 0.04, floorY - topY),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.20)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );
    // chimney breast / stone surround — sooted and cool up near the ceiling,
    // warming toward the floor where the fire actually reaches it. One flat
    // slab was the largest and deadest shape in the room.
    final breast = Rect.fromLTWH(x - hw / 2, topY, hw, floorY - topY + 2);
    canvas.drawRect(
      breast,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2B2320), Color(0xFF382E2A), Color(0xFF443832)],
          stops: [0.0, 0.55, 1.0],
        ).createShader(breast),
    );
    // brick courses hint
    final brick = Paint()
      ..color = const Color(0x22000000)
      ..strokeWidth = 1;
    for (var i = 1; i < 6; i++) {
      final by = topY + (floorY - topY) * i / 6;
      canvas.drawLine(Offset(x - hw / 2, by), Offset(x + hw / 2, by), brick);
    }
    // mantel shelf
    final mantelY = floorY - u * 0.62;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x - hw / 2 - w * 0.025, mantelY, hw + w * 0.05, u * 0.07),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFF5C4B40),
    );
    canvas.drawRect(
      Rect.fromLTWH(x - hw / 2 - w * 0.025, mantelY, hw + w * 0.05, 2),
      Paint()..color = Palette.xpLight.withValues(alpha: 0.12),
    );

    // firebox opening (dark, arched)
    final fbW = hw * 0.58, fbH = u * 0.5;
    final fb = floorY - u * 0.04; // the log bed
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(x - fbW / 2, floorY - fbH, fbW, fbH),
        topLeft: Radius.circular(fbW * 0.32),
        topRight: Radius.circular(fbW * 0.32),
      ),
      Paint()..color = const Color(0xFF140C08),
    );
    // the firebox's back wall, warmed from within — a gradient rising off the
    // coal bed, so the opening reads as a hot cavity instead of a black hole
    // (this is what keeps the BANKED hearth from looking dead: never-punish
    // has to be true of the picture, not just the copy)
    final fbRect = Rect.fromLTWH(x - fbW / 2, floorY - fbH, fbW, fbH);
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        fbRect,
        topLeft: Radius.circular(fbW * 0.32),
        topRight: Radius.circular(fbW * 0.32),
      ),
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, 0.88),
          radius: 0.95,
          colors: [
            flameHue.withValues(alpha: 0.40 * (0.45 + 0.55 * lit)),
            flameHue.withValues(alpha: 0.12 * (0.45 + 0.55 * lit)),
            const Color(0x00000000),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(fbRect),
    );
    // soot licking up the breast above the opening — a century of fires
    final sootRect = Rect.fromLTWH(
      x - fbW * 0.60,
      floorY - fbH - u * 0.16,
      fbW * 1.20,
      u * 0.19,
    );
    canvas.drawRect(
      sootRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0x5C120A06), Color(0x00120A06)],
        ).createShader(sootRect)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    // the stone lip around the mouth catches the firelight
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        fbRect.inflate(2),
        topLeft: Radius.circular(fbW * 0.34),
        topRight: Radius.circular(fbW * 0.34),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..color = flameHue.withValues(alpha: 0.10 + 0.22 * lit)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    // firelight glowing out of the opening (reactive)
    canvas.drawCircle(
      Offset(x, floorY - fbH * 0.34),
      fbW * 0.72 * (0.9 + 0.12 * flick),
      Paint()
        ..color = flameHue.withValues(
          alpha: (0.42 + 0.14 * (flick - 1) * 5) * lit,
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
    );
    // ── the log bed: two split logs crossed over live coals. Both stay when
    // the fire banks — a keep's hearth banks down, it never goes out. ──
    void log(double x0, double y0, double x1, double y1, double thick) {
      canvas.drawLine(
        Offset(x0, y0),
        Offset(x1, y1),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = thick
          ..color = const Color(0xFF4A2C18),
      );
      // the underside catches the coals' light
      canvas.drawLine(
        Offset(x0, y0 + thick * 0.26),
        Offset(x1, y1 + thick * 0.26),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = thick * 0.38
          ..color = Color.lerp(
            flameHue,
            const Color(0xFF4A2C18),
            0.45,
          )!.withValues(alpha: 0.2 + 0.5 * lit),
      );
    }

    log(
      x - fbW * 0.40,
      fb - u * 0.028,
      x + fbW * 0.34,
      fb - u * 0.004,
      u * 0.044,
    );
    log(
      x - fbW * 0.32,
      fb - u * 0.003,
      x + fbW * 0.40,
      fb - u * 0.032,
      u * 0.038,
    );

    // live coals, each breathing on its own beat so the bed never looks like
    // four painted dots
    const coalXs = [-0.30, -0.11, 0.09, 0.28];
    for (var i = 0; i < coalXs.length; i++) {
      final heat = 0.5 + 0.5 * sin(t * 2 * pi * 1.5 + i * 1.9);
      canvas.drawCircle(
        Offset(x + coalXs[i] * fbW, fb - u * 0.004),
        fbW * 0.055 * (0.88 + 0.18 * heat),
        Paint()
          ..color = Color.lerp(
            flameHue,
            const Color(0xFFFFDE9A),
            0.35 * heat,
          )!.withValues(alpha: (0.45 + 0.4 * heat) * (0.5 + 0.5 * lit))
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, fbW * 0.025),
      );
    }

    if (petAwake) {
      // Full flames when the fire is kept. White-hot at the base, cooling to
      // the flame's own hue at the licking tip — real fire is hottest low
      // down, and the old gradient ran the other way, which is why it read as
      // three white teeth instead of fire.
      for (final spec in const [
        (-0.20, 0.66, 0.0),
        (0.0, 1.0, 1.3),
        (0.20, 0.70, 2.4),
      ]) {
        final fx = x + spec.$1 * fbW;
        final f = 1 + 0.16 * sin(t * 2 * pi * 2 + spec.$3);
        final lean = fbW * 0.07 * sin(t * 2 * pi + spec.$3);
        final fhh = fbH * 0.80 * spec.$2 * f * grow;
        final bw = fbW * 0.082 * spec.$2;
        // a licking tongue: bellied low, drawn out to a leaning point
        final flame = Path()
          ..moveTo(fx - bw, fb)
          ..cubicTo(
            fx - bw * 1.15,
            fb - fhh * 0.34,
            fx - bw * 0.62 + lean,
            fb - fhh * 0.72,
            fx + lean,
            fb - fhh,
          )
          ..cubicTo(
            fx + bw * 0.62 + lean,
            fb - fhh * 0.72,
            fx + bw * 1.15,
            fb - fhh * 0.34,
            fx + bw,
            fb,
          )
          ..close();
        final fr = Rect.fromLTWH(fx - bw * 1.2, fb - fhh, bw * 2.4, fhh);
        canvas.drawPath(
          flame,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                const Color(0xFFFFF6E4),
                Color.lerp(flameHue, const Color(0xFFFFDE9A), 0.55)!,
                flameHue,
                flameHue.withValues(alpha: 0.66),
              ],
              stops: const [0.0, 0.26, 0.74, 1.0],
            ).createShader(fr),
        );
      }
      // a hot bright heart low in the fire — hotter as the hearth climbs
      canvas.drawCircle(
        Offset(x, fb - u * 0.035),
        fbW * 0.115 * flick * (0.92 + 0.05 * stage),
        Paint()
          ..color = const Color(0xFFFFF4D9).withValues(alpha: 0.6)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      // Everflame (top tier): a single spark drifts up from the crown
      if (stage >= 5) {
        final sy = (fb - fbH * grow) - u * 0.06 * (0.5 + 0.5 * sin(t * 2 * pi));
        canvas.drawCircle(
          Offset(x + fbW * 0.10 * sin(t * 2 * pi * 1.5), sy),
          fbW * 0.035,
          Paint()
            ..color = const Color(
              0xFFFFF4D9,
            ).withValues(alpha: 0.35 + 0.45 * (0.5 + 0.5 * sin(t * 2 * pi * 3)))
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
        );
      }
    }
  }

  // A little companion (round-50): curled cozily asleep, or — when you're on a
  // streak — awake and beaming up at you. Never-punish: sleeping is rest, not
  // a scold; the warmth is the reward for showing up.
  void _pet(Canvas canvas, double w, double h, double floorY, bool awake) {
    final u = h - floorY;
    final cx = w * 0.66;
    final baseY = floorY + u * 0.92;
    final tan = Paint()..color = const Color(0xFFCBA471);
    final tanLight = const Color(0xFFE0C091);
    const ink = Color(0xFF5A4030);

    // contact shadow
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, baseY),
        width: w * 0.17,
        height: u * 0.06,
      ),
      Paint()..color = const Color(0x33000000),
    );

    // An ear ANCHORED ON THE SKULL: both base points sit inside the head
    // circle (radius [r]) and the tip pushes out past the rim, so it reads as
    // part of the animal. The old version placed a free triangle by offset and
    // drifted off the head on the left / vanished into it on the right.
    void ear(Offset hc, double r, double s) {
      final baseA = Offset(hc.dx + s * r * 0.16, hc.dy - r * 0.92);
      final baseB = Offset(hc.dx + s * r * 0.90, hc.dy - r * 0.30);
      final tip = Offset(hc.dx + s * r * 0.84, hc.dy - r * 1.46);
      canvas.drawPath(
        Path()
          ..moveTo(baseA.dx, baseA.dy)
          ..lineTo(tip.dx, tip.dy)
          ..lineTo(baseB.dx, baseB.dy)
          ..close(),
        tan,
      );
      // the inner cup — a smaller rose triangle inset toward the centroid
      final c = Offset(
        (baseA.dx + baseB.dx + tip.dx) / 3,
        (baseA.dy + baseB.dy + tip.dy) / 3,
      );
      Offset inset(Offset p) => Offset.lerp(p, c, 0.36)!;
      final ia = inset(baseA), ib = inset(baseB), it = inset(tip);
      canvas.drawPath(
        Path()
          ..moveTo(ia.dx, ia.dy)
          ..lineTo(it.dx, it.dy)
          ..lineTo(ib.dx, ib.dy)
          ..close(),
        Paint()..color = const Color(0xFFD79A93).withValues(alpha: 0.6),
      );
    }

    if (!awake) {
      // ── asleep: a curled, rounded loaf with a tail wrapped to the front ──
      final bodyC = Offset(cx, baseY - u * 0.1);
      canvas.drawOval(
        Rect.fromCenter(center: bodyC, width: w * 0.17, height: u * 0.24),
        tan,
      );
      // tail curling around the front
      final tail = Path()
        ..moveTo(cx + w * 0.08, baseY - u * 0.06)
        ..quadraticBezierTo(
          cx + w * 0.12,
          baseY - u * 0.2,
          cx + w * 0.02,
          baseY - u * 0.16,
        );
      canvas.drawPath(
        tail,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = u * 0.08
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFFE0C091),
      );
      // head resting on the left
      final hc = Offset(cx - w * 0.06, baseY - u * 0.13);
      canvas.drawCircle(hc, w * 0.042, tan);
      ear(hc, w * 0.042, -1);
      ear(hc, w * 0.042, 1);
      // a sleepy closed eye
      canvas.drawArc(
        Rect.fromCircle(center: hc.translate(w * 0.005, 0), radius: w * 0.014),
        0,
        pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round
          ..color = ink,
      );
      // Zzz drifting up
      final z = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round
        ..color = Palette.xpLight.withValues(alpha: 0.6);
      for (var i = 0; i < 3; i++) {
        final s = w * (0.018 - i * 0.004);
        final zx = hc.dx + w * 0.04 + i * w * 0.025;
        final zy = hc.dy - u * 0.12 - i * u * 0.07;
        canvas.drawLine(Offset(zx, zy), Offset(zx + s, zy), z);
        canvas.drawLine(Offset(zx + s, zy), Offset(zx, zy + s), z);
        canvas.drawLine(Offset(zx, zy + s), Offset(zx + s, zy + s), z);
      }
    } else {
      // ── awake: sitting up, beaming up at you ──
      // tail to the side
      final tail = Path()
        ..moveTo(cx + w * 0.05, baseY - u * 0.06)
        ..quadraticBezierTo(
          cx + w * 0.13,
          baseY - u * 0.04,
          cx + w * 0.11,
          baseY - u * 0.2,
        );
      canvas.drawPath(
        tail,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = u * 0.06
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFFE0C091),
      );
      // body sitting
      final bodyC = Offset(cx, baseY - u * 0.16);
      canvas.drawOval(
        Rect.fromCenter(center: bodyC, width: w * 0.12, height: u * 0.3),
        tan,
      );
      // belly highlight
      canvas.drawOval(
        Rect.fromCenter(
          center: bodyC.translate(0, u * 0.04),
          width: w * 0.07,
          height: u * 0.16,
        ),
        Paint()..color = tanLight.withValues(alpha: 0.6),
      );
      // head up
      final hc = Offset(cx, baseY - u * 0.34);
      canvas.drawCircle(hc, w * 0.058, tan);
      ear(hc, w * 0.058, -1);
      ear(hc, w * 0.058, 1);
      // big eyes with catchlights, looking up toward the ember
      for (final s in [-1.0, 1.0]) {
        final ec = hc.translate(s * w * 0.025, -w * 0.004);
        canvas.drawOval(
          Rect.fromCenter(center: ec, width: w * 0.018, height: w * 0.024),
          Paint()..color = ink,
        );
        canvas.drawCircle(
          ec.translate(-w * 0.004, -w * 0.006),
          w * 0.006,
          Paint()..color = Colors.white.withValues(alpha: 0.9),
        );
      }
      // a happy little smile
      canvas.drawArc(
        Rect.fromCenter(
          center: hc.translate(0, w * 0.02),
          width: w * 0.03,
          height: w * 0.022,
        ),
        pi * 0.1,
        pi * 0.8,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3
          ..strokeCap = StrokeCap.round
          ..color = ink,
      );
      // rosy cheeks
      final blush = Paint()
        ..color = const Color(0x44D88A8A)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      canvas.drawCircle(hc.translate(-w * 0.045, w * 0.012), w * 0.014, blush);
      canvas.drawCircle(hc.translate(w * 0.045, w * 0.012), w * 0.014, blush);
    }
  }

  // a string of warm bulbs draped across the upper wall (sags in the middle)
  void _garland(Canvas canvas, double w, double h) {
    final left = Offset(w * 0.36, h * 0.07);
    final right = Offset(w * 0.97, h * 0.09);
    final mid = Offset((left.dx + right.dx) / 2, h * 0.07 + h * 0.07); // sag
    final wire = Path()
      ..moveTo(left.dx, left.dy)
      ..quadraticBezierTo(mid.dx, mid.dy, right.dx, right.dy);
    canvas.drawPath(
      wire,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color(0xFF5A4536),
    );
    const bulbs = 7;
    for (var i = 1; i < bulbs; i++) {
      final u = i / bulbs, mt = 1 - (i / bulbs);
      final bx = mt * mt * left.dx + 2 * mt * u * mid.dx + u * u * right.dx;
      final by = mt * mt * left.dy + 2 * mt * u * mid.dy + u * u * right.dy;
      // a warm twinkle travelling along the string — each bulb brightens on a
      // phase set by its position, so light seems to run down the garland
      final tw = 0.6 + 0.4 * sin(t * 2 * pi * 2 - i * 0.9);
      canvas.drawCircle(
        Offset(bx, by + 3),
        4.5 * (0.85 + 0.25 * tw),
        Paint()
          ..color = Palette.honeyGlow.withValues(alpha: 0.5 + 0.4 * tw)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawCircle(
        Offset(bx, by + 3),
        2.2,
        Paint()..color = Palette.xpLight.withValues(alpha: 0.7 + 0.3 * tw),
      );
    }
  }

  // a soft floor cushion to the left of the avatar
  void _cushion(Canvas canvas, double w, double h, double floorY) {
    final c = Offset(w * 0.3, floorY + (h - floorY) * 0.52);
    final cw = w * 0.1, ch = (h - floorY) * 0.26;
    canvas.drawOval(
      Rect.fromCenter(
        center: c.translate(0, ch * 0.5),
        width: cw * 1.2,
        height: ch * 0.3,
      ),
      Paint()..color = const Color(0x55000000), // contact shadow
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: c, width: cw, height: ch),
        Radius.circular(ch * 0.5),
      ),
      Paint()..color = const Color(0xFF8A6070),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: c.translate(-cw * 0.12, -ch * 0.18),
        width: cw * 0.5,
        height: ch * 0.3,
      ),
      Paint()..color = Palette.specular.withValues(alpha: 0.12),
    );
  }

  // a little cluster of three candles glowing on the floor — each flame sways
  // and its halo pulses on its own phase (t), so the cluster wavers like real
  // candlelight instead of three frozen teardrops
  void _candles(Canvas canvas, double w, double h, double floorY) {
    final baseY = floorY + (h - floorY) * 0.42;
    var i = 0;
    for (final spec in [(-0.04, 0.9), (0.0, 1.15), (0.04, 0.8)]) {
      final cx = w * 0.4 + spec.$1 * w;
      final ch = (h - floorY) * 0.22 * spec.$2;
      final phase = i * 2.1;
      final sway = 2.0 * sin(t * 2 * pi * 2 + phase);
      final pulse = 0.85 + 0.15 * sin(t * 2 * pi * 2 + phase);
      final tipY = baseY - ch - 9 - 1.5 * sin(t * 2 * pi * 2 + phase);
      canvas.drawCircle(
        Offset(cx, baseY - ch - 4),
        8 * pulse,
        Paint()
          ..color = Palette.honeyGlow.withValues(alpha: 0.7 * pulse)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - 3, baseY - ch, 6, ch),
          const Radius.circular(2),
        ),
        Paint()..color = const Color(0xFFF0E2C8),
      );
      final flame = Path()
        ..moveTo(cx - 2, baseY - ch)
        ..quadraticBezierTo(cx - 3 + sway, baseY - ch - 6, cx + sway, tipY)
        ..quadraticBezierTo(cx + 3 + sway, baseY - ch - 6, cx + 2, baseY - ch)
        ..close();
      canvas.drawPath(flame, Paint()..color = Palette.xpLight);
      i++;
    }
  }

  @override
  bool shouldRepaint(_RoomPainter old) =>
      old.t != t ||
      old.window != window ||
      old.petAwake != petAwake ||
      old.emberGlow != emberGlow ||
      old.level != level ||
      old.wallGrain != wallGrain ||
      old.floorGrain != floorGrain ||
      // content compares, not identity: the live owned-set mutates in place
      // (same instance ≠ same furniture) and visit_room builds a fresh set
      // every build (different instance ≠ different furniture)
      !setEquals(old.unlocked, unlocked) ||
      !listEquals(old.wall, wall) ||
      !listEquals(old.floor, floor);
}

/// Paints the landscape inside a window pane [rect] for the chosen [scene]
/// (content/window_scenes.dart). Public so the shop's preview swatch can reuse
/// it. Clips to the pane; the caller draws the frame on top. [t] (0..1, the
/// room's slow ambient loop) makes the weather live — rain falls, aurora
/// drifts, stars breathe; passing the default 0 paints a calm still frame
/// (the shop swatch + goldens rely on that).
void paintWindowScene(Canvas canvas, String scene, Rect rect, {double t = 0}) {
  final fx = rect.left, fy = rect.top, fw = rect.width, fh = rect.height;
  final rr = RRect.fromRectAndRadius(rect, const Radius.circular(6));
  canvas.save();
  canvas.clipRRect(rr);

  Offset at(double x, double y) => Offset(fx + fw * x, fy + fh * y);
  // a gentle twinkle: each star swells + fades on its own phase, so a night
  // sky shimmers instead of sitting frozen
  void stars(List<Offset> pts) {
    for (var i = 0; i < pts.length; i++) {
      final tw = 0.7 + 0.3 * sin(t * 2 * pi + i * 1.7);
      canvas.drawCircle(
        at(pts[i].dx, pts[i].dy),
        (1.3 - (i.isOdd ? 0.4 : 0)) * (0.85 + 0.25 * tw),
        Paint()..color = Palette.xpLight.withValues(alpha: 0.55 + 0.35 * tw),
      );
    }
  }

  void sky(List<Color> colors) => canvas.drawRect(
    rect,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: colors,
      ).createShader(rect),
  );

  /// A moon's halo — the bloom real moonlight has in humid night air. Without
  /// it a moon is a flat sticker pasted on a flat sky; with it the sky reads
  /// as atmosphere. Two stacked falloffs (tight + wide) beat one big blur.
  void moonGlow(double x, double y, double rFrac, [double strength = 1]) {
    final c = at(x, y);
    canvas.drawCircle(
      c,
      fw * rFrac * 3.0,
      Paint()
        ..color = Palette.xpLight.withValues(alpha: 0.09 * strength)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, fw * rFrac * 1.4),
    );
    canvas.drawCircle(
      c,
      fw * rFrac * 1.6,
      Paint()
        ..color = Palette.xpLight.withValues(alpha: 0.16 * strength)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, fw * rFrac * 0.75),
    );
  }

  void fullMoon(double x, double y, double rFrac) {
    moonGlow(x, y, rFrac);
    canvas.drawCircle(at(x, y), fw * rFrac, Paint()..color = Palette.xpLight);
    // two faint maria so the disc has a surface instead of reading as a hole
    canvas.drawCircle(
      at(x, y).translate(-fw * rFrac * 0.3, -fw * rFrac * 0.22),
      fw * rFrac * 0.30,
      Paint()..color = const Color(0x18140C06),
    );
    canvas.drawCircle(
      at(x, y).translate(fw * rFrac * 0.26, fw * rFrac * 0.3),
      fw * rFrac * 0.20,
      Paint()..color = const Color(0x14140C06),
    );
  }

  /// A crescent carved by subtracting a shifted disc. Never overdraw the dark
  /// side with a flat colour — on a gradient sky that leaves a visible
  /// wrong-tone ghost circle beside the moon.
  void crescent(double x, double y, double rFrac, double alpha) {
    final r = fw * rFrac;
    moonGlow(x, y, rFrac, alpha * 0.9);
    canvas.save();
    canvas.clipPath(
      Path.combine(
        PathOperation.difference,
        Path()..addOval(Rect.fromCircle(center: at(x, y), radius: r)),
        Path()..addOval(
          Rect.fromCircle(
            center: at(x, y).translate(r * 0.52, -r * 0.3),
            radius: r,
          ),
        ),
      ),
    );
    canvas.drawCircle(
      at(x, y),
      r,
      Paint()..color = Palette.xpLight.withValues(alpha: alpha),
    );
    canvas.restore();
  }

  switch (scene) {
    case 'city':
      sky(const [Color(0xFF161A2E), Color(0xFF241A2A)]);
      stars(const [Offset(0.18, 0.18), Offset(0.42, 0.12), Offset(0.8, 0.2)]);
      fullMoon(0.2, 0.24, 0.08);
      // light pollution — the sodium haze a city throws up against its own
      // sky. The one detail that separates "a city at night" from "black
      // rectangles with yellow dots".
      canvas.drawRect(
        Rect.fromLTWH(fx, fy + fh * 0.42, fw, fh * 0.58),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              const Color(0xFFE8C77A).withValues(alpha: 0.24),
              const Color(0xFFE8C77A).withValues(alpha: 0.0),
            ],
          ).createShader(Rect.fromLTWH(fx, fy + fh * 0.42, fw, fh * 0.58)),
      );
      // skyline silhouette with lit windows
      final sil = Paint()..color = const Color(0xFF0A0C16);
      final lit = Paint()..color = const Color(0xFFE8C77A);
      const bx = [0.08, 0.26, 0.42, 0.58, 0.74, 0.88];
      const bh = [0.34, 0.5, 0.28, 0.46, 0.36, 0.24];
      for (var i = 0; i < bx.length; i++) {
        final bw = fw * 0.13;
        final top = fy + fh * (1 - bh[i]);
        canvas.drawRect(
          Rect.fromLTWH(fx + fw * bx[i] - bw / 2, top, bw, fh),
          sil,
        );
        for (var r = 0; r < 3; r++) {
          for (var c = 0; c < 2; c++) {
            if ((i + r + c).isEven) continue;
            final cell = Rect.fromLTWH(
              fx + fw * bx[i] - bw * 0.28 + c * bw * 0.34,
              top + fh * 0.06 + r * fh * 0.1,
              fw * 0.022,
              fh * 0.04,
            );
            // each window blooms a little into the dark — lit glass at night
            // is never a crisp rectangle
            canvas.drawRect(
              cell.inflate(fw * 0.012),
              Paint()
                ..color = const Color(0xFFE8C77A).withValues(alpha: 0.30)
                ..maskFilter = MaskFilter.blur(BlurStyle.normal, fw * 0.014),
            );
            canvas.drawRect(cell, lit);
          }
        }
        // a red aircraft-warning light winking on the two tallest towers
        if (bh[i] > 0.44) {
          final blink = 0.35 + 0.65 * (sin(t * 2 * pi * 2 + i) > 0.4 ? 1 : 0);
          canvas.drawCircle(
            Offset(fx + fw * bx[i], top - fh * 0.012),
            fw * 0.011,
            Paint()
              ..color = const Color(0xFFE57468).withValues(alpha: blink)
              ..maskFilter = MaskFilter.blur(BlurStyle.normal, fw * 0.01),
          );
        }
      }
    case 'forest':
      sky(const [Color(0xFF101A14), Color(0xFF16140E)]);
      stars(const [Offset(0.2, 0.18), Offset(0.5, 0.14), Offset(0.34, 0.3)]);
      fullMoon(0.72, 0.26, 0.11);
      // two ranks of pines — a hazed far rank, then the near black silhouette,
      // with ground mist between them. Depth from tone, same as the mountains.
      void pines(List<double> tx, List<double> th, Color col, double halfFrac) {
        final paint = Paint()..color = col;
        for (var i = 0; i < tx.length; i++) {
          final baseY = fy + fh;
          final topY = fy + fh * (1 - th[i]);
          final cxp = fx + fw * tx[i], halfW = fw * halfFrac;
          // a stepped conifer rather than one flat triangle
          final p = Path()
            ..moveTo(cxp, topY)
            ..lineTo(cxp - halfW * 0.62, topY + (baseY - topY) * 0.45)
            ..lineTo(cxp - halfW * 0.34, topY + (baseY - topY) * 0.45)
            ..lineTo(cxp - halfW, baseY)
            ..lineTo(cxp + halfW, baseY)
            ..lineTo(cxp + halfW * 0.34, topY + (baseY - topY) * 0.45)
            ..lineTo(cxp + halfW * 0.62, topY + (baseY - topY) * 0.45)
            ..close();
          canvas.drawPath(p, paint);
        }
      }

      pines(
        const [0.04, 0.2, 0.36, 0.54, 0.7, 0.88],
        const [0.3, 0.38, 0.32, 0.4, 0.34, 0.3],
        const Color(0xFF1C2A20),
        0.055,
      );
      canvas.drawRect(
        Rect.fromLTWH(fx, fy + fh * 0.62, fw, fh * 0.24),
        Paint()
          ..color = const Color(0xFFBFE0C0).withValues(alpha: 0.13)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, fh * 0.06),
      );
      pines(
        const [0.1, 0.26, 0.44, 0.62, 0.8, 0.94],
        const [0.42, 0.56, 0.46, 0.6, 0.5, 0.4],
        const Color(0xFF0A140E),
        0.07,
      );
    case 'mountains':
      sky(const [Color(0xFF1A2236), Color(0xFF2A2438)]);
      stars(const [Offset(0.16, 0.16), Offset(0.6, 0.12), Offset(0.84, 0.22)]);
      fullMoon(0.78, 0.22, 0.09);
      Path ridgeAt(List<double> peaks) {
        final p = Path()..moveTo(fx, fy + fh);
        final n = peaks.length;
        for (var i = 0; i < n; i++) {
          p.lineTo(fx + fw * (i / (n - 1)), fy + fh * (1 - peaks[i]));
        }
        p
          ..lineTo(fx + fw, fy + fh)
          ..close();
        return p;
      }
      // Atmospheric perspective: three ranges, each nearer one darker and
      // more saturated than the last. Distance in a landscape is carried by
      // haze, not by scale — flat-toned ridges read as cut paper.
      canvas.drawPath(
        ridgeAt(const [0.34, 0.54, 0.4, 0.6, 0.38]),
        Paint()..color = const Color(0xFF3A4360),
      );
      // a band of haze pooling in the valley behind the middle range
      canvas.drawRect(
        Rect.fromLTWH(fx, fy + fh * 0.52, fw, fh * 0.26),
        Paint()
          ..color = const Color(0xFF6E7AA0).withValues(alpha: 0.22)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, fh * 0.06),
      );
      canvas.drawPath(
        ridgeAt(const [0.26, 0.44, 0.3, 0.5, 0.28, 0.44]),
        Paint()..color = const Color(0xFF262E48),
      );
      canvas.drawPath(
        ridgeAt(const [0.14, 0.3, 0.18, 0.34, 0.16, 0.3]),
        Paint()..color = const Color(0xFF121728),
      );
      // moonlight catching the near range's lit flanks
      canvas.save();
      canvas.clipPath(ridgeAt(const [0.14, 0.3, 0.18, 0.34, 0.16, 0.3]));
      canvas.drawCircle(
        at(0.78, 0.22),
        fw * 0.55,
        Paint()
          ..color = Palette.xpLight.withValues(alpha: 0.07)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, fw * 0.2),
      );
      canvas.restore();
    case 'rain':
      sky(const [Color(0xFF14100C), Color(0xFF181820)]);
      // dim crescent behind the rain, hazed by the weather
      crescent(0.66, 0.3, 0.12, 0.62);
      // Rain that isn't a hatch pattern: each drop gets its own length, weight
      // and fall speed, so near drops streak fast and far ones drift. Uniform
      // diagonals of identical length read as ruled lines, not weather.
      for (var i = 0; i < 26; i++) {
        final near = (i * 0.37) % 1.0; // 0 far … 1 near
        final len = fh * (0.06 + 0.09 * near);
        final x = fx + fw * ((i * 0.137) % 1.0);
        final y = fy + fh * ((i * 0.231 + t * (1.4 + 1.4 * near)) % 1.0);
        canvas.drawLine(
          Offset(x, y),
          Offset(x - fw * 0.03 * (0.6 + near), y + len),
          Paint()
            ..color = const Color(
              0xFFAEB8D0,
            ).withValues(alpha: 0.22 + 0.34 * near)
            ..strokeWidth = 0.7 + 0.9 * near
            ..strokeCap = StrokeCap.round,
        );
      }
      // beads clinging to the inside of the pane, catching the moon
      for (var i = 0; i < 5; i++) {
        final bx = fx + fw * (0.12 + i * 0.19);
        final by = fy + fh * (0.22 + ((i * 0.31 + t * 0.35) % 0.7));
        canvas.drawCircle(
          Offset(bx, by),
          fw * (0.008 + 0.004 * (i % 3)),
          Paint()..color = Palette.xpLight.withValues(alpha: 0.28),
        );
      }
    case 'dawn':
      sky(const [Color(0xFF3A2A4A), Color(0xFFB5683E), Color(0xFFE8B570)]);
      // a low sun with a soft glow
      canvas.drawCircle(
        at(0.3, 0.62),
        fw * 0.3,
        Paint()
          ..color = const Color(0xFFF6D79A).withValues(alpha: 0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      canvas.drawCircle(
        at(0.3, 0.62),
        fw * 0.13,
        Paint()..color = const Color(0xFFFFE9B8),
      );
      // hill silhouette
      final hill = Path()
        ..moveTo(fx, fy + fh)
        ..lineTo(fx, fy + fh * 0.78)
        ..quadraticBezierTo(
          fx + fw * 0.5,
          fy + fh * 0.66,
          fx + fw,
          fy + fh * 0.8,
        )
        ..lineTo(fx + fw, fy + fh)
        ..close();
      canvas.drawPath(hill, Paint()..color = const Color(0xFF6E4A38));
    case 'aurora':
      sky(const [Color(0xFF0A1220), Color(0xFF101A26)]);
      stars(const [
        Offset(0.2, 0.2),
        Offset(0.5, 0.14),
        Offset(0.8, 0.24),
        Offset(0.66, 0.4),
      ]);
      // wavy aurora bands, blurred
      for (final band in [
        (0.28, const Color(0xFF6FE0A0)),
        (0.5, const Color(0xFF8FD0E0)),
        (0.72, const Color(0xFFB58AE0)),
      ]) {
        final p = Path()..moveTo(fx, fy + fh * 0.5);
        for (var i = 0; i <= 6; i++) {
          final x = fx + fw * (i / 6);
          // the curtain undulates: the phase drifts with the loop so the bands
          // slowly ripple sideways instead of hanging frozen
          final y =
              fy +
              fh *
                  (0.34 +
                      0.12 * sin(i * 1.3 + band.$1 * 6 + t * 2 * pi) +
                      band.$1 * 0.18);
          p.lineTo(x, y);
        }
        canvas.drawPath(
          p,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = fh * 0.08
            ..color = band.$2.withValues(alpha: 0.45)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, fh * 0.04),
        );
      }
    default: // 'moon' — the classic moonlit night
      // a real sky rather than a flat black rectangle: cold high air settling
      // into the warm haze the keep's own valley throws up at the horizon
      sky(const [Color(0xFF141A2A), Color(0xFF1B1622), Color(0xFF241A14)]);
      stars(const [
        Offset(0.14, 0.16),
        Offset(0.30, 0.30),
        Offset(0.46, 0.13),
        Offset(0.24, 0.52),
        Offset(0.86, 0.36),
        Offset(0.72, 0.14),
      ]);
      crescent(0.64, 0.34, 0.14, 1.0);
      // a far treeline along the sill — depth for free, and it grounds the
      // moon as sky instead of wallpaper
      final ridge = Path()..moveTo(fx, fy + fh);
      for (var i = 0; i <= 7; i++) {
        final rx = fx + fw * (i / 7);
        ridge
          ..lineTo(rx, fy + fh * (0.88 - (i.isEven ? 0.07 : 0.03)))
          ..lineTo(rx + fw / 14, fy + fh * 0.92);
      }
      ridge
        ..lineTo(fx + fw, fy + fh)
        ..close();
      canvas.drawPath(ridge, Paint()..color = const Color(0xFF120E12));
  }
  canvas.restore();
}
