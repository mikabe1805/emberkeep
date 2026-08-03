import 'dart:async' show unawaited;
import 'dart:math' show cos, min, pi, sin;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart'
    show ValueListenable, listEquals, setEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../content/space_themes.dart';
import '../tokens.dart';
import 'facets.dart';

/// Room of Days' shared flame language: a graphic outer tongue in the purchased
/// hue rising from a pale, white-hot base. Room hearth, HUD, candles, and shop
/// swatches all call this painter so the heat model cannot drift again.
void paintEmberFlame(
  Canvas canvas,
  Rect rect,
  Color hue, {
  double lean = 0,
  double intensity = 1,
}) {
  if (rect.isEmpty) return;
  final w = rect.width;
  final h = rect.height;
  final cx = rect.center.dx;
  final baseY = rect.bottom;
  final hsv = HSVColor.fromColor(hue);
  final deep = hsv
      .withSaturation((hsv.saturation * 1.18).clamp(0.0, 1.0))
      .withValue((hsv.value * 0.46).clamp(0.12, 0.48))
      .toColor();
  final warm = hsv
      .withSaturation((hsv.saturation * 0.94).clamp(0.36, 1.0))
      .withValue((hsv.value * 1.08).clamp(0.58, 1.0))
      .toColor();
  final gold = hsv
      .withHue((hsv.hue - 8) % 360)
      .withSaturation((hsv.saturation * 0.78).clamp(0.30, 0.88))
      .withValue((hsv.value * 1.14).clamp(0.68, 1.0))
      .toColor();

  // Normalized angular points. Lean is strongest at the tip and settles to
  // zero at the fuel line, so the flame sways without sliding off its logs.
  Offset p(double x, double y) =>
      Offset(rect.left + w * x + lean * (1 - y), rect.top + h * y);

  // The icon's essential silhouette: a long spear tip, one cut-in shoulder,
  // and a wider ember-facing flank. Multiple overlapping calls build the
  // clustered blaze in the hearth; a single call still reads at HUD/tile size.
  final outer = Path()
    ..moveTo(p(0.08, 1).dx, p(0.08, 1).dy)
    ..lineTo(p(0.04, 0.79).dx, p(0.04, 0.79).dy)
    ..lineTo(p(0.27, 0.57).dx, p(0.27, 0.57).dy)
    ..lineTo(p(0.23, 0.37).dx, p(0.23, 0.37).dy)
    ..lineTo(p(0.58, 0).dx, p(0.58, 0).dy)
    ..lineTo(p(0.56, 0.44).dx, p(0.56, 0.44).dy)
    ..lineTo(p(0.88, 0.72).dx, p(0.88, 0.72).dy)
    ..lineTo(p(0.76, 1).dx, p(0.76, 1).dy)
    ..close();

  canvas.drawOval(
    Rect.fromCenter(
      center: Offset(cx, rect.top + h * 0.88),
      width: w * 1.9,
      height: h * 0.64,
    ),
    Paint()
      ..color = warm.withValues(alpha: 0.26 * intensity)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.24),
  );

  canvas.drawPath(
    outer,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          warm.withValues(alpha: intensity),
          hue.withValues(alpha: intensity),
          deep.withValues(alpha: 0.98 * intensity),
        ],
        stops: const [0.0, 0.58, 1.0],
      ).createShader(rect),
  );

  // Large clipped facets replace the old smooth teardrop shading. They follow
  // the same visual construction as the icon: warm left plane, ember-dark
  // right plane, and one golden diagonal rising from the fuel-contact core.
  canvas.save();
  canvas.clipPath(outer);
  canvas.drawPath(
    Path()
      ..moveTo(p(0.08, 1).dx, p(0.08, 1).dy)
      ..lineTo(p(0.04, 0.79).dx, p(0.04, 0.79).dy)
      ..lineTo(p(0.27, 0.57).dx, p(0.27, 0.57).dy)
      ..lineTo(p(0.58, 0).dx, p(0.58, 0).dy)
      ..lineTo(p(0.42, 0.66).dx, p(0.42, 0.66).dy)
      ..lineTo(p(0.34, 1).dx, p(0.34, 1).dy)
      ..close(),
    Paint()..color = warm.withValues(alpha: 0.24 * intensity),
  );
  canvas.drawPath(
    Path()
      ..moveTo(p(0.58, 0).dx, p(0.58, 0).dy)
      ..lineTo(p(0.56, 0.44).dx, p(0.56, 0.44).dy)
      ..lineTo(p(0.88, 0.72).dx, p(0.88, 0.72).dy)
      ..lineTo(p(0.76, 1).dx, p(0.76, 1).dy)
      ..lineTo(p(0.58, 0.67).dx, p(0.58, 0.67).dy)
      ..close(),
    Paint()..color = deep.withValues(alpha: 0.42 * intensity),
  );
  canvas.drawPath(
    Path()
      ..moveTo(p(0.34, 1).dx, p(0.34, 1).dy)
      ..lineTo(p(0.42, 0.66).dx, p(0.42, 0.66).dy)
      ..lineTo(p(0.58, 0).dx, p(0.58, 0).dy)
      ..lineTo(p(0.58, 0.67).dx, p(0.58, 0.67).dy)
      ..lineTo(p(0.61, 1).dx, p(0.61, 1).dy)
      ..close(),
    Paint()..color = gold.withValues(alpha: 0.30 * intensity),
  );
  canvas.restore();

  // The hot heart is itself faceted and joins the fuel line. The pale region
  // reaches upward as a narrow gold wedge, but only the bottom foot is white.
  final inner = Path()
    ..moveTo(p(0.26, 1).dx, p(0.26, 1).dy)
    ..lineTo(p(0.39, 0.84).dx, p(0.39, 0.84).dy)
    ..lineTo(p(0.50, 0.66).dx, p(0.50, 0.66).dy)
    ..lineTo(p(0.56, 0.86).dx, p(0.56, 0.86).dy)
    ..lineTo(p(0.68, 0.76).dx, p(0.68, 0.76).dy)
    ..lineTo(p(0.62, 1).dx, p(0.62, 1).dy)
    ..close();
  canvas.drawPath(
    inner,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          const Color(0xFFFFF1B0).withValues(alpha: 0.96 * intensity),
          gold.withValues(alpha: 0.95 * intensity),
          warm.withValues(alpha: 0.68 * intensity),
        ],
        stops: const [0.0, 0.36, 1.0],
      ).createShader(rect),
  );

  // The only near-white facet sits directly on the fuel line.
  final foot = Path()
    ..moveTo(cx - w * 0.12, baseY)
    ..lineTo(cx - w * 0.02, baseY - h * 0.13)
    ..lineTo(cx + w * 0.08, baseY)
    ..close();
  canvas.drawPath(
    foot,
    Paint()
      ..color = const Color(0xFFFFFEF1).withValues(alpha: 0.96 * intensity),
  );
}

/// Paints the exact flame tile used on the shop shelf. Keeping the tile here
/// beside [paintEmberFlame] lets the visual harness render the production
/// swatch for every purchasable hue, instead of testing a lookalike.
void paintEmberFlameSwatch(Canvas canvas, Size size, Color hue) {
  final w = size.width, h = size.height;
  final panel = Offset.zero & size;
  canvas.drawRRect(
    RRect.fromRectAndRadius(panel, const Radius.circular(8)),
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF2B1D18), Color(0xFF160F0D)],
      ).createShader(panel),
  );

  final cx = w * 0.5;
  canvas.drawCircle(
    Offset(cx, h * 0.61),
    w * 0.34,
    Paint()
      ..color = hue.withValues(alpha: 0.34)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.12),
  );
  canvas.drawLine(
    Offset(cx - w * 0.17, h * 0.83),
    Offset(cx + w * 0.17, h * 0.83),
    Paint()
      ..color = Color.lerp(hue, const Color(0xFF3A2016), 0.62)!
      ..strokeWidth = w * 0.045
      ..strokeCap = StrokeCap.square,
  );
  // The shelf preview uses the same overlapping three-tongue construction as
  // the room, so buying a colour previews the actual icon-like blaze rather
  // than a simplified teardrop.
  paintEmberFlame(
    canvas,
    Rect.fromLTWH(cx - w * 0.25, h * 0.41, w * 0.22, h * 0.41),
    hue,
    lean: -w * 0.015,
  );
  paintEmberFlame(
    canvas,
    Rect.fromLTWH(cx + w * 0.03, h * 0.36, w * 0.23, h * 0.46),
    hue,
    lean: w * 0.012,
  );
  paintEmberFlame(
    canvas,
    Rect.fromLTWH(cx - w * 0.18, h * 0.15, w * 0.36, h * 0.67),
    hue,
  );
}

/// Procedural fallback for legacy/missing room plates. Current Me spaces use
/// complete authored identities; this painter exists so an old shared payload
/// or damaged asset still has a warm, readable room instead of a blank panel.
const _defaultWall = [Color(0xFF34262F), Color(0xFF49332E)];
const _defaultFloor = [Color(0xFF4A3322), Color(0xFF2A190F)];

/// Painterly grain for the wall/floor — a whisper of brush-stroke texture
/// (assets/room/, extracted from the room concept paintings by
/// tools/gen_room_textures.py) softLight-blended over the flat style
/// gradients, so every purchased style keeps its exact colours but stops
/// reading as a vector-flat fill. Loads once, lazily; until the images land
/// (or if they're ever missing) the room paints exactly as before.
class _RoomGrain {
  static ui.Image? wall;
  static ui.Image? floor;
  static ui.Image? tapestry;
  static Future<void>? _loading;

  /// Bumped when a texture finishes decoding, so live rooms repaint.
  static final ValueNotifier<int> version = ValueNotifier(0);

  static void ensure() {
    _loading ??= _loadAll();
  }

  static Future<void> preload() {
    ensure();
    return _loading!;
  }

  static Future<void> _loadAll() async {
    try {
      await Future.wait([
        _load('assets/room/wall_grain.png', (i) => wall = i),
        _load('assets/room/floor_grain.png', (i) => floor = i),
        _loadTapestry(),
      ]);
    } catch (_) {
      // Permit a later room build to retry after a transient decode failure.
      _loading = null;
      rethrow;
    }
  }

  static Future<void> _loadTapestry() async {
    try {
      await _load(
        'assets/brand/morrowloom-tapestry-room-v2.webp',
        (i) => tapestry = i,
        required: true,
      );
    } catch (_) {
      // The canonical approved source is the no-blank fallback if the
      // room-specific transparent derivative is missing or damaged.
      await _load(
        'assets/brand/morrowloom-icon-runtime-v2.webp',
        (i) => tapestry = i,
        required: true,
      );
    }
  }

  static Future<void> _load(
    String asset,
    void Function(ui.Image) set, {
    bool required = false,
  }) async {
    ui.Codec? codec;
    try {
      final bytes = await rootBundle.load(asset);
      codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
      set((await codec.getNextFrame()).image);
      version.value++;
    } catch (_) {
      codec?.dispose();
      codec = null;
      if (required) rethrow;
      // a missing grain texture is fine — the room just paints flat
    }
    codec?.dispose();
  }
}

/// Painted room plates — one image per wall style in `assets/rooms/<id>.png`.
///
/// The procedural room below is a flat elevation: a wall rect and a floor rect
/// with decals on top. It has no perspective and no single light source, which
/// is why it reads as an illustration of a room rather than a lit space. A
/// plate is a painted interior with the geometry, the furniture, the fire AND
/// its light baked in — see ROOM-PLATES.md for how they're generated.
///
/// Plates are optional and per-style. A wall style with no plate falls straight
/// through to the painter, so the set can land one file at a time.
class _RoomPlate {
  static final Map<String, ui.Image> _plates = {};
  static final Map<String, ui.Image> _previews = {};
  static final Map<String, Future<void>> _loading = {};
  static final Map<String, Future<void>> _previewLoading = {};

  /// Bumped when a plate finishes decoding, so live rooms repaint.
  static final ValueNotifier<int> version = ValueNotifier(0);

  /// Returns the decoded, already-complete room texture for this identity.
  static ui.Image? displayOf(String? id, {bool preview = false}) {
    if (id == null) return null;
    return preview ? _previews[id] ?? _plates[id] : _plates[id];
  }

  static void ensure(String? id, {bool preview = false}) {
    if (id == null) return;
    unawaited(preview ? preloadPreview(id) : preload(id));
  }

  static Future<void> preload(String id) =>
      _loading.putIfAbsent(id, () => _load(id));

  static Future<void> preloadPreview(String id) =>
      _previewLoading.putIfAbsent(id, () => _loadPreview(id));

  /// Decodes every plate that exists. Screenshot surfaces await this so a
  /// capture never records the one-frame procedural fallback.
  static Future<void> preloadAll(Iterable<String> ids) async {
    await Future.wait(ids.map(preload), eagerError: false);
  }

  static Future<void> preloadAllPreviews(Iterable<String> ids) async {
    await Future.wait(ids.map(preloadPreview), eagerError: false);
  }

  static Future<void> _load(String id) async {
    try {
      final theme = spaceThemeById(id);
      if (theme != null) {
        _plates[id] = await _decode(theme.plateAsset);
      } else {
        _plates[id] = await _decode('assets/rooms/$id.png');
      }
      version.value++;
    } catch (_) {
      // No plate for this style yet — the painter handles it. Not an error.
    }
  }

  static Future<void> _loadPreview(String id) async {
    try {
      final theme = spaceThemeById(id);
      if (theme == null) return;
      _previews[id] = await _decode(theme.previewAsset);
      version.value++;
    } catch (_) {
      // Chooser previews are optional. Fall back to the complete room instead
      // of flattening the card into the old procedural placeholder.
      await preload(id);
    }
  }

  static Future<ui.Image> _decode(String asset) async {
    final bytes = await rootBundle.load(asset);
    final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
    try {
      return (await codec.getNextFrame()).image;
    } finally {
      codec.dispose();
    }
  }

  // Complete themes deliberately have no furniture-composition branch.
}

/// Where the fire sits inside a plate, as a fraction of the room. The flicker
/// overlay is the only thing in the code that assumes anything about what the
/// painting contains, and this is the single place it assumes it. Measured off
/// the approved board art; move it if a generated room puts the hearth
/// somewhere else.
const _plateHearth = Offset(0.83, 0.63);

/// Decodes the room's reusable raster textures before a deterministic capture.
/// Live rooms still load lazily through [HomeRoom]; screenshot and share-card
/// surfaces can await this to avoid recording the one-frame loading fallback.
Future<void> preloadHomeRoomAssets() async {
  await _RoomGrain.preload();
  final ids = spaceThemes.map((theme) => theme.id);
  await Future.wait([
    _RoomPlate.preloadAll(ids),
    _RoomPlate.preloadAllPreviews(ids),
  ]);
}

/// Prepares one full room before a user moves into it, preventing a procedural
/// fallback frame from flashing between two authored identities.
Future<void> preloadSpaceTheme(String id) => _RoomPlate.preload(id);

/// Legacy hearth-glyph tier mapping retained for compatibility with old visual
/// tests. The production room no longer maps level to fire size; level belongs
/// exclusively to the permanent Woven Dawn.
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
    this.heirloomFlame = false,
    this.level = 1,
    this.lively = true,
    this.memoryArtifacts = 0,
    this.plateId,
    this.lightweightPreview = false,
    this.parallax,
  });

  /// The wall-style id, used to look up a painted plate in `assets/rooms/`.
  /// When a plate exists it replaces the whole procedural room — geometry,
  /// furniture, fire and light are all baked into the painting, and only the
  /// hearth flicker stays live. Null, or a style with no plate on disk, paints
  /// procedurally exactly as before.
  ///
  /// NOTE: a plate bakes in its floor, so the floor picker has no visual effect
  /// on a plated wall style. That is the trade for painted light — plating
  /// every wall×floor pair would be 42 images instead of 7.
  final String? plateId;

  /// Uses the identity's 720 x 480 chooser derivative while retaining the
  /// exact same intact-camera, moving-light, hearth, and ember treatment as
  /// the full room. This keeps the chooser responsive without flattening its
  /// alternate rooms into static thumbnails or decoding three full masters.
  final bool lightweightPreview;

  /// Legacy furniture ids used only by the procedural fallback. Complete room
  /// identities ignore this set because all of their contents are authored.
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

  /// Whether the room's cat is awake. The ambient fireplace no longer mirrors
  /// streak or level; it stays welcoming regardless of recent activity.
  final bool petAwake;

  /// The hearth-flame's mid-tone colour — its firelight pools on the floor and
  /// the flames take this hue (amber by default; a chosen flame colour tints
  /// the whole keep warm). Null = default honey/amber fire.
  final Color? emberGlow;

  /// Achievement-gated flames earn one restrained signature: a small crown of
  /// gold sparks above the blaze. The room still reserves its brightest value
  /// for the fuel-line core, and reduced motion parks the sparks in place.
  final bool heirloomFlame;

  /// The player's level — controls the permanent woven portion of the Morrow
  /// Tapestry. Defaults to 1 for preview/visit callers.
  final int level;

  /// The ambient-life switch (round-61): fire flickers, candles sway, rain
  /// falls, dust drifts. Pass `!state.reduceMotion` once the app wires it up;
  /// the OS-level disable-animations switch is honoured regardless. Off, the
  /// room paints one calm still frame — same beauty, parked.
  final bool lively;

  /// Number of private Cabinet artifacts. Only the count reaches the painter;
  /// journal text, goal names, and note identities never become room data.
  final int memoryArtifacts;

  /// A normalized -1..1 light/view direction supplied by the quest board.
  /// Painted plates use it for a tiny overscanned camera drift and responsive
  /// reflected light. Null parks the composition at its finished still
  /// (including reduced-motion and every non-interactive room caller).
  final ValueListenable<Offset>? parallax;

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
    _RoomPlate.ensure(widget.plateId, preview: widget.lightweightPreview);
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
      child: ClipPath(
        clipper: const FacetedClipper(cut: 15),
        child: Stack(
          children: [
            Positioned.fill(
              // repaint-bounded so the ambient tick repaints the room alone,
              // never the avatar (who has his own boundary) or the screen
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: Listenable.merge([
                    _RoomGrain.version,
                    _RoomPlate.version,
                    ?life,
                    ?widget.parallax,
                  ]),
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
                        widget.heirloomFlame,
                        widget.level,
                        widget.memoryArtifacts,
                        _RoomGrain.wall,
                        _RoomGrain.floor,
                        _RoomGrain.tapestry,
                        t,
                        _RoomPlate.displayOf(
                          widget.plateId,
                          preview: widget.lightweightPreview,
                        ),
                        widget.parallax?.value ?? Offset.zero,
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
    this.heirloomFlame,
    this.level,
    this.memoryArtifacts,
    this.wallGrain,
    this.floorGrain,
    this.tapestryImage,
    this.t,
    this.plate,
    this.parallax,
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
  final bool heirloomFlame;
  final int level;
  final int memoryArtifacts;

  /// The painted room for this wall style, if one has been generated. Non-null
  /// replaces every procedural pass below.
  final ui.Image? plate;

  /// 0..1 through the slow ambient loop (quantized upstream). Every motion in
  /// here is a pure function of [t] — deterministic, seamless at the wrap, and
  /// t=0 must always be a finished, pretty still frame (reduced motion parks
  /// there, and the goldens capture wherever the pump lands).
  final double t;

  /// Normalized view/light direction. Only painted plates use the optical
  /// response today; the procedural room remains its deterministic fallback.
  final Offset parallax;

  /// Brush-stroke grain (see [_RoomGrain]); null paints flat, like always.
  final ui.Image? wallGrain;
  final ui.Image? floorGrain;
  final ui.Image? tapestryImage;
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
    if (plate != null) {
      _paintPlate(canvas, w, h, plate!);
      return;
    }
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
    if (wallGrain != null) _grain(canvas, wallGrain!, wallRect, w * 0.62, 0.30);
    // Large quiet plaster planes give the room authored geometry. Texture is
    // secondary; these diagonals are what keep the wall from becoming mud.
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(w * 0.46, 0)
        ..lineTo(w * 0.31, floorY)
        ..lineTo(0, floorY)
        ..close(),
      Paint()..color = Colors.white.withValues(alpha: 0.025),
    );
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.72, 0)
        ..lineTo(w, 0)
        ..lineTo(w, floorY)
        ..lineTo(w * 0.84, floorY)
        ..close(),
      Paint()..color = Colors.black.withValues(alpha: 0.055),
    );
    // Give a legacy/missing-asset fallback enough architecture to remain
    // intentional rather than reading as a blank error surface.
    final wainscotY = floorY * 0.69;
    canvas.drawRect(
      Rect.fromLTRB(0, wainscotY, w, floorY),
      Paint()..color = Colors.black.withValues(alpha: 0.055),
    );
    canvas.drawLine(
      Offset.zero.translate(0, wainscotY),
      Offset(w, wainscotY),
      Paint()
        ..color = Palette.xpLight.withValues(alpha: 0.075)
        ..strokeWidth = 1,
    );
    final panelLine = Paint()
      ..color = Colors.black.withValues(alpha: 0.075)
      ..strokeWidth = 1;
    for (final px in const [0.025, 0.355, 0.645, 0.975]) {
      canvas.drawLine(
        Offset(w * px, wainscotY),
        Offset(w * px, floorY),
        panelLine,
      );
    }
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
      _grain(canvas, floorGrain!, floorRect, w * 0.85, 0.36);
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
    // ── the ambient fireplace pooling warm light across the floor. Its
    // brightness never tracks streak or level; only the chosen hue changes. ──
    final glow = emberGlow ?? Palette.honeyGlow;
    final warmBounce = Color.lerp(glow, const Color(0xFFFFD49A), 0.58)!;
    final glowBreath = 0.5 + 0.5 * sin(t * 2 * pi * 2 + 0.4);
    const lit = 0.86;
    final spill = Path()
      ..moveTo(w * 0.73, floorY)
      ..lineTo(w * 0.85, floorY)
      ..lineTo(w * (0.98 + 0.006 * glowBreath), h)
      ..lineTo(w * (0.53 - 0.012 * glowBreath), h)
      ..close();
    canvas.drawPath(
      spill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            warmBounce.withValues(alpha: (0.28 + 0.07 * glowBreath) * lit),
            glow.withValues(alpha: 0.090 * lit),
            glow.withValues(alpha: 0),
          ],
          stops: const [0.0, 0.58, 1.0],
        ).createShader(Rect.fromLTRB(w * 0.51, floorY, w, h)),
    );
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.77, floorY)
        ..lineTo(w * 0.82, floorY)
        ..lineTo(w * 0.93, h)
        ..lineTo(w * 0.62, h)
        ..close(),
      Paint()..color = Palette.specular.withValues(alpha: 0.050 * lit),
    );

    // ── window light shaft: a soft wedge of the outside light spilling
    // diagonally across the floor, tinted by the scene (cool silver moon,
    // warm gold dawn, teal aurora, blue-grey rain), with a few dust motes
    // adrift inside it. The room's biggest "this space is lit" tell. ──
    _lightShaft(canvas, w, h, floorY);

    // A permanent stone apron anchors the fireplace in the floor. This is
    // architecture rather than furniture: it gives the empty keep a crafted
    // hearthside focal point, while the purchasable rug still owns the large
    // soft floor silhouette further into the room.
    final apronU = h - floorY;
    final apron = Path()
      ..moveTo(w * 0.715, floorY - 1)
      ..lineTo(w * 0.865, floorY - 1)
      ..lineTo(w * 0.905, floorY + apronU * 0.17)
      ..lineTo(w * 0.675, floorY + apronU * 0.17)
      ..close();
    final apronBounds = Rect.fromLTRB(
      w * 0.67,
      floorY,
      w * 0.91,
      floorY + apronU * 0.18,
    );
    canvas.drawPath(
      apron,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF675044), Color(0xFF3A2B25)],
        ).createShader(apronBounds),
    );
    canvas.drawPath(
      apron,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.miter
        ..strokeWidth = 1.2
        ..color = Palette.xpLight.withValues(alpha: 0.14),
    );
    canvas.drawLine(
      Offset(w * 0.79, floorY),
      Offset(w * 0.79, floorY + apronU * 0.17),
      Paint()
        ..strokeWidth = 1
        ..color = Colors.black.withValues(alpha: 0.12),
    );

    // baseboard — a thin warm highlight over a soft shadow, grounding the wall
    canvas.drawRect(
      Rect.fromLTWH(0, floorY - 2, w, 3),
      Paint()..color = const Color(0x55000000),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, floorY - 2.5, w, 1),
      Paint()..color = Palette.xpLight.withValues(alpha: 0.10),
    );

    _tapestryBay(canvas, w, h);
    _window(canvas, w, h);
    // the keep's HEARTH — always here, the heart of the room (round-62 pivot)
    _hearth(canvas, w, h, floorY);
    if (memoryArtifacts > 0) _memoryRelics(canvas, w, h, floorY);
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

    // ── KEY-LIGHT FALLOFF ────────────────────────────────────────────────
    // The hearth is the only real light in this room, so everything has to
    // fall away from IT — not from the middle of the screen. Measured against
    // the approved board art, the lit wall beside the fire sits near 0.20
    // value and the far floor near 0.04: a range of about five to one. The
    // previous pass was a symmetric vignette centred on the room that capped
    // at 0.22 in the corners, which compressed that range to nothing and left
    // the whole space reading as evenly-lit mid-grey — technically polished,
    // emotionally flat. Anchored on the firebox and taken deep, the same one
    // draw call gives the room a light source and a dark side.
    final all = Rect.fromLTWH(0, 0, w, h);
    const corner = Color(0xFF0B0705);
    canvas.drawRect(
      all,
      Paint()
        ..shader = RadialGradient(
          // the firebox itself — measured off the render at ~0.83w, ~0.63h,
          // converted to Alignment space. Guessing this put the light in the
          // middle of the room and darkened the hearth, which inverted the
          // whole thing: the far wall came out brighter than the fire.
          center: const Alignment(0.66, 0.26),
          // radius is a fraction of the SHORTEST side; the room is wide, so
          // this has to exceed 1 to carry past the far bottom-left corner
          radius: 1.32,
          colors: [
            corner.withValues(alpha: 0),
            corner.withValues(alpha: 0.26),
            corner.withValues(alpha: 0.58),
            corner.withValues(alpha: 0.82),
          ],
          stops: const [0.10, 0.42, 0.72, 1.0],
        ).createShader(all),
    );

    // The moon and the standing lamp are light SOURCES, so they have to
    // survive their own room's shadow — but only just. These pools stay tight
    // to the fixture: sized generously they lift the whole left half and
    // invert the room, putting more light on the far wall than on the hearth.
    _reliteFixture(
      canvas,
      Offset(w * 0.115, h * 0.185),
      h * 0.11,
      const Color(0x24BFD4E8),
    );
    if (has('lamp')) {
      _reliteFixture(
        canvas,
        Offset(w * 0.225, h * 0.26),
        h * 0.12,
        const Color(0x2EFFD9A0),
      );
    }
  }

  /// Gives the painted room a restrained optical response, then keeps the fire
  /// alive with additive light and drifting embers.
  ///
  /// The whole authored plate moves as one continuous painting. Earlier
  /// versions redrew broad polygon samples from the same raster; those samples
  /// dragged pieces of the window with the chair and exposed their cut edges.
  /// A tiny overscanned camera drift plus independent window/hearth light now
  /// creates depth without separating pixels that belong together.
  void _paintPlate(Canvas canvas, double w, double h, ui.Image img) {
    // cover-fit: fill the room, crop the overflowing axis, never letterbox
    final scale = (w / img.width) > (h / img.height)
        ? w / img.width
        : h / img.height;
    final sw = w / scale, sh = h / scale;
    final src = Rect.fromLTWH(
      (img.width - sw) / 2,
      (img.height - sh) / 2,
      sw,
      sh,
    );
    final px = parallax.dx.clamp(-1.0, 1.0).toDouble();
    final py = parallax.dy.clamp(-1.0, 1.0).toDouble();
    // Enough real image beyond the crop for a visible, weighty camera drift.
    // The entire plate still moves intact, so stronger motion does not
    // reintroduce the cut-window/chair seam from the old sampled approach.
    final overscan = w * 0.045;
    final plateRect = Rect.fromLTWH(
      -overscan,
      -overscan,
      w + overscan * 2,
      h + overscan * 2,
    );
    final roomShift = Offset(-px * w * 0.0145, -py * h * 0.022);
    final samplePaint = Paint()..filterQuality = FilterQuality.medium;

    canvas.drawImageRect(img, src, plateRect.shift(roomShift), samplePaint);

    // A cool window reflection and a warmer room key move at different rates
    // across the intact painting. That material response supplies the depth
    // cue without turning any object into a visible paper cut-out.
    final windowAt = Offset(w * (0.14 + px * 0.022), h * (0.23 + py * 0.014));
    canvas.drawCircle(
      windowAt,
      w * 0.34,
      Paint()
        ..blendMode = BlendMode.screen
        ..shader = const RadialGradient(
          colors: [Color(0x0A7895B8), Color(0x03627E9E), Color(0x00627E9E)],
          stops: [0, 0.48, 1],
        ).createShader(Rect.fromCircle(center: windowAt, radius: w * 0.34)),
    );

    // A moving key-light veil unifies the depth samples. It is too faint to
    // recolour the art; it only makes the authored planes catch light together.
    final lightAt = Offset(w * (0.48 + px * 0.055), h * (0.30 + py * 0.035));
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(
          colors: const [
            Color(0x10FFD9A0),
            Color(0x05FFD9A0),
            Color(0x00FFD9A0),
          ],
          stops: const [0, 0.42, 1],
        ).createShader(Rect.fromCircle(center: lightAt, radius: w * 0.62)),
    );

    // The plate owns every fixture and its cast light. Keeping those pixels
    // intact avoids guessed glows floating over differently furnished themes.
    // Every complete room includes a working hearth; it never has to be bought
    // before the room is allowed to feel warm.

    // the hearth breathing. Two offset sines so the loop never reads as a
    // metronome, and a floor of 0.55 so it glows rather than blinks.
    final breath =
        0.55 + 0.30 * sin(t * 2 * pi * 2) + 0.15 * sin(t * 2 * pi * 3 + 1.1);
    final at =
        Offset(w * _plateHearth.dx, h * _plateHearth.dy) + roomShift * 0.72;
    final glow = emberGlow ?? const Color(0xFFE8915A);
    final radius = w * 0.30;
    canvas.drawCircle(
      at,
      radius,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(
          colors: [
            glow.withValues(alpha: 0.085 * breath),
            glow.withValues(alpha: 0.030 * breath),
            glow.withValues(alpha: 0),
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(Rect.fromCircle(center: at, radius: radius)),
    );
    // a tighter, brighter core right on the firebox
    canvas.drawCircle(
      at,
      w * 0.075,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(
          colors: [
            glow.withValues(alpha: 0.16 * breath),
            glow.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: at, radius: w * 0.075)),
    );

    // The plate contains the beautifully painted fire, but a baked flame alone
    // cannot feel alive. Three very low-opacity tongues from Room of Days'
    // established flame painter move inside that existing firebox. Screen
    // compositing preserves the authored texture underneath instead of
    // replacing it with a new graphic.
    final flameSway =
        sin(t * pi * 4.0) * w * 0.004 + sin(t * pi * 6.0 + 0.8) * w * 0.002;
    final flameBounds = Rect.fromCenter(
      center: at.translate(0, h * 0.020),
      width: w * 0.105,
      height: h * (0.15 + 0.012 * breath),
    );
    canvas.saveLayer(
      flameBounds.inflate(w * 0.03),
      Paint()..blendMode = BlendMode.screen,
    );
    paintEmberFlame(
      canvas,
      Rect.fromLTWH(
        flameBounds.left,
        flameBounds.top + flameBounds.height * 0.12,
        flameBounds.width * 0.48,
        flameBounds.height * 0.88,
      ),
      glow,
      lean: flameSway,
      intensity: 0.18 * breath,
    );
    paintEmberFlame(
      canvas,
      Rect.fromLTWH(
        flameBounds.left + flameBounds.width * 0.28,
        flameBounds.top,
        flameBounds.width * 0.50,
        flameBounds.height,
      ),
      glow,
      lean: -flameSway * 0.75,
      intensity: 0.22 * breath,
    );
    paintEmberFlame(
      canvas,
      Rect.fromLTWH(
        flameBounds.left + flameBounds.width * 0.56,
        flameBounds.top + flameBounds.height * 0.18,
        flameBounds.width * 0.40,
        flameBounds.height * 0.82,
      ),
      glow,
      lean: flameSway * 0.55,
      intensity: 0.16 * breath,
    );
    canvas.restore();

    // Warm light skates over the nearest floor plane instead of ending as a
    // circular glow. The thin angular reflection is what makes the fireplace
    // feel embedded in a room with depth.
    final reflection = Path()
      ..moveTo(at.dx - w * 0.035, at.dy + h * 0.015)
      ..lineTo(at.dx + w * 0.045, at.dy + h * 0.015)
      ..lineTo(w * (0.97 + px * 0.006), h)
      ..lineTo(w * (0.52 + px * 0.012), h)
      ..close();
    canvas.drawPath(
      reflection,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            glow.withValues(alpha: 0),
            glow.withValues(alpha: 0.022 * breath),
            const Color(0x00E8915A),
          ],
          stops: const [0, 0.62, 1],
        ).createShader(Rect.fromLTWH(0, at.dy, w, h - at.dy)),
    );

    _paintPlateEmbers(canvas, w, h, at, glow);
  }

  /// Tiny deterministic embers give the baked fireplace a living edge without
  /// redrawing its flames. At t=0 they form an intentional still composition;
  /// with ambient motion enabled they rise, sway and trade brightness.
  void _paintPlateEmbers(
    Canvas canvas,
    double w,
    double h,
    Offset hearth,
    Color glow,
  ) {
    final count = heirloomFlame ? 9 : 6;
    for (var i = 0; i < count; i++) {
      final cycle = (t * (0.58 + i * 0.037) + i * 0.173) % 1.0;
      final lift = Curves.easeOutCubic.transform(cycle);
      final sway = sin(cycle * pi * 2 + i * 1.71);
      final alpha = sin(cycle * pi).abs() * (i.isEven ? 0.64 : 0.44);
      final point = Offset(
        hearth.dx + sway * w * (0.006 + (i % 3) * 0.0025),
        hearth.dy - h * (0.045 + lift * (0.13 + (i % 4) * 0.018)),
      );
      final hot = Color.lerp(glow, const Color(0xFFFFF0BC), 0.76)!;
      canvas.drawCircle(
        point,
        w * (i.isEven ? 0.0055 : 0.0042),
        Paint()
          ..blendMode = BlendMode.plus
          ..color = hot.withValues(alpha: alpha * 0.24)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawCircle(
        point,
        w * (i.isEven ? 0.0018 : 0.0013),
        Paint()
          ..blendMode = BlendMode.plus
          ..color = hot.withValues(alpha: alpha),
      );
      if (heirloomFlame && i % 3 == 0) {
        final flare = w * 0.0055 * alpha;
        final line = Paint()
          ..blendMode = BlendMode.plus
          ..color = const Color(0xFFFFF3C8).withValues(alpha: alpha * 0.62)
          ..strokeWidth = 0.75
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(
          point.translate(-flare, 0),
          point.translate(flare, 0),
          line,
        );
        canvas.drawLine(
          point.translate(0, -flare * 1.5),
          point.translate(0, flare * 1.5),
          line,
        );
      }
    }
  }

  /// One additive pool of light, drawn after the key-light falloff so a fixture
  /// on the dark side of the room still reads as lit.
  void _reliteFixture(Canvas canvas, Offset at, double radius, Color hue) {
    canvas.drawCircle(
      at,
      radius,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(
          colors: [hue, hue.withValues(alpha: 0)],
          stops: const [0.0, 1.0],
        ).createShader(Rect.fromCircle(center: at, radius: radius)),
    );
  }

  /// Small objects that accumulate on the permanent mantel as the keeper saves
  /// memories. They are symbolic only: a sealed letter, a pressed-flower frame,
  /// and an achievement prism. Their meaning lives in the private Cabinet.
  void _memoryRelics(Canvas canvas, double w, double h, double floorY) {
    final u = h - floorY;
    final y = _mantelY(h, floorY);
    final count = memoryArtifacts.clamp(1, 3);
    if (count >= 1) {
      final envelope = Path()
        ..moveTo(w * 0.735, y - u * 0.075)
        ..lineTo(w * 0.785, y - u * 0.075)
        ..lineTo(w * 0.780, y - u * 0.005)
        ..lineTo(w * 0.740, y - u * 0.005)
        ..close();
      canvas.drawPath(envelope, Paint()..color = const Color(0xFFD9C49C));
      canvas.drawPath(
        Path()
          ..moveTo(w * 0.735, y - u * 0.075)
          ..lineTo(w * 0.760, y - u * 0.038)
          ..lineTo(w * 0.785, y - u * 0.075),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = const Color(0xFF7A5A44),
      );
    }
    if (count >= 2) {
      final frame = Rect.fromLTWH(
        w * 0.695,
        y - u * 0.135,
        w * 0.034,
        u * 0.13,
      );
      canvas.drawRect(frame, Paint()..color = const Color(0xFF8A6A4F));
      canvas.drawRect(
        frame.deflate(2),
        Paint()..color = const Color(0xFF322822),
      );
      canvas.drawCircle(
        Offset(frame.center.dx, frame.center.dy + 1),
        frame.width * 0.15,
        Paint()..color = Palette.success.withValues(alpha: 0.78),
      );
      canvas.drawLine(
        Offset(frame.center.dx, frame.center.dy + 1),
        Offset(frame.center.dx - 2, frame.bottom - 3),
        Paint()
          ..strokeWidth = 1
          ..color = Palette.success,
      );
    }
    if (count >= 3) {
      final cx = w * 0.830;
      final prism = Path()
        ..moveTo(cx, y - u * 0.14)
        ..lineTo(cx + w * 0.018, y - u * 0.07)
        ..lineTo(cx + w * 0.012, y - u * 0.005)
        ..lineTo(cx - w * 0.012, y - u * 0.005)
        ..lineTo(cx - w * 0.018, y - u * 0.07)
        ..close();
      canvas.drawPath(
        prism,
        Paint()
          ..shader =
              LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Palette.specular.withValues(alpha: 0.9),
                  Palette.unlock.withValues(alpha: 0.7),
                  const Color(0xFF5B3D65),
                ],
              ).createShader(
                Rect.fromCenter(
                  center: Offset(cx, y - u * 0.07),
                  width: w * 0.05,
                  height: u * 0.15,
                ),
              ),
      );
      canvas.drawCircle(
        Offset(cx, y - u * 0.075),
        w * 0.024,
        Paint()
          ..color = Palette.unlock.withValues(alpha: 0.22)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
    }
  }

  /// The hearth's light, composited over the finished room: an additive warm
  /// bloom centred on the firebox, a reflection smear on the floorboards, and
  /// sparks lifting off the coals. Everything here is deterministic in [t].
  /// The ambient light deliberately ignores level and streak.
  void _firelight(Canvas canvas, double w, double h, double floorY) {
    final u = h - floorY;
    final glow = emberGlow ?? const Color(0xFFEC6007);
    final warm = Color.lerp(glow, const Color(0xFFFFD49A), 0.68)!;
    const lit = 0.86;
    final breath = 0.5 + 0.5 * sin(t * 2 * pi * 2 + 0.4);
    const stage = 2;
    final fireX = w * 0.79;
    final centre = Offset(fireX, floorY - u * 0.16);

    // A generous but controlled warm bloom is the emotional reward for a live
    // hearth. Crisp light planes still provide structure underneath it.
    final bloom = Rect.fromCircle(
      center: centre,
      radius: w * (0.39 + 0.020 * stage) * (0.98 + 0.04 * breath),
    );
    // The room catches the fire's light, but the fire itself must keep its
    // saturated planes. Excluding the opening prevents the additive bloom
    // from bleaching the orange/red flame back into a pale peach candle.
    final openingW = w * 0.225 * 0.58;
    final openingH = u * 0.50;
    final openingRect = Rect.fromLTWH(
      fireX - openingW / 2,
      floorY - openingH,
      openingW,
      openingH,
    );
    final shoulder = openingW * 0.18;
    final opening = Path()
      ..moveTo(openingRect.left, openingRect.bottom)
      ..lineTo(openingRect.left, openingRect.top + shoulder)
      ..lineTo(openingRect.left + shoulder, openingRect.top)
      ..lineTo(openingRect.right - shoulder, openingRect.top)
      ..lineTo(openingRect.right, openingRect.top + shoulder)
      ..lineTo(openingRect.right, openingRect.bottom)
      ..close();
    final litRoom = Path.combine(
      PathOperation.difference,
      Path()..addRect(Rect.fromLTWH(0, 0, w, h)),
      opening,
    );
    canvas.save();
    canvas.clipPath(litRoom);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(
          colors: [
            // Bright enough to warm the room, restrained enough that additive
            // light does not bleach the saturated icon-like flame underneath.
            warm.withValues(alpha: (0.145 + 0.026 * breath) * lit),
            warm.withValues(alpha: (0.064 + 0.012 * breath) * lit),
            glow.withValues(alpha: 0.016 * lit),
            const Color(0x00000000),
          ],
          stops: const [0.0, 0.30, 0.70, 1.0],
        ).createShader(bloom),
    );
    canvas.restore();

    // A narrow reflected facet on the waxed boards, aligned to the floor's
    // perspective rather than painted as a fuzzy oval.
    final reflection = Path()
      ..moveTo(w * 0.76, floorY)
      ..lineTo(w * 0.82, floorY)
      ..lineTo(w * (0.93 + 0.01 * breath), h)
      ..lineTo(w * (0.62 - 0.01 * breath), h)
      ..close();
    canvas.drawPath(
      reflection,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            warm.withValues(alpha: 0.095 * lit),
            glow.withValues(alpha: 0.030 * lit),
            glow.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromLTRB(w * 0.59, floorY, w * 0.99, h)),
    );

    // sparks lifting off the coals and winking out inside the arch — the one
    // thing in the room that travels upward, so the eye keeps returning to
    // the fire. Count climbs with the hearth's tier.
    {
      final count = 2 + stage ~/ 2; // 2 sparks at First Spark … 4 at Everflame
      for (var i = 0; i < count; i++) {
        final phase = (t * (1.3 + i * 0.21) + i * 0.29) % 1.0;
        final sx =
            fireX +
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
    final footR = Offset(w * 0.56, h);
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
          // 0.105 laid a pale wedge across a third of the floor that read as
          // haze rather than moonlight — the room's second-largest light
          // source competing with the hearth from the cold side.
          colors: [tint.withValues(alpha: 0.048), tint.withValues(alpha: 0)],
        ).createShader(Rect.fromLTWH(w * 0.1, h * 0.16, w * 0.46, h * 0.84)),
    );
    canvas.drawPath(
      Path()
        ..moveTo(srcL.dx, srcL.dy)
        ..lineTo(srcL.dx + (srcR.dx - srcL.dx) * 0.38, srcL.dy)
        ..lineTo(footL.dx + (footR.dx - footL.dx) * 0.54, footL.dy)
        ..lineTo(footL.dx, footL.dy)
        ..close(),
      Paint()..color = tint.withValues(alpha: 0.022),
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

  /// A purpose-built faceted wall bay for the Woven Dawn. The textile is
  /// a quiet permanent record rather than the room's loudest object. Its small
  /// architectural recess keeps the authored cloth grounded without turning
  /// the whole wall into interface chrome.
  void _tapestryBay(Canvas canvas, double w, double h) {
    final outerBounds = Rect.fromLTRB(
      w * 0.365,
      h * 0.075,
      w * 0.545,
      h * 0.49,
    );
    final outer = Path()
      ..moveTo(w * 0.385, h * 0.075)
      ..lineTo(w * 0.525, h * 0.075)
      ..lineTo(w * 0.545, h * 0.11)
      ..lineTo(w * 0.545, h * 0.46)
      ..lineTo(w * 0.525, h * 0.49)
      ..lineTo(w * 0.385, h * 0.49)
      ..lineTo(w * 0.365, h * 0.46)
      ..lineTo(w * 0.365, h * 0.11)
      ..close();
    canvas.drawPath(
      outer.shift(Offset(w * 0.008, h * 0.010)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawPath(
      outer,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF514441), Color(0xFF2D292D), Color(0xFF463839)],
        ).createShader(outerBounds),
    );

    final inner = Path()
      ..moveTo(w * 0.397, h * 0.105)
      ..lineTo(w * 0.513, h * 0.105)
      ..lineTo(w * 0.525, h * 0.126)
      ..lineTo(w * 0.525, h * 0.438)
      ..lineTo(w * 0.513, h * 0.458)
      ..lineTo(w * 0.397, h * 0.458)
      ..lineTo(w * 0.385, h * 0.438)
      ..lineTo(w * 0.385, h * 0.126)
      ..close();
    canvas.drawPath(inner, Paint()..color = const Color(0xFF241F27));
    canvas.drawPath(
      inner,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeJoin = StrokeJoin.miter
        ..color = Palette.specular.withValues(alpha: 0.14),
    );

    // Cool moonlight catches the left mitre while the fireplace gives the
    // right edge a restrained warm return. The textile itself never glows.
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.365, h * 0.11)
        ..lineTo(w * 0.385, h * 0.126)
        ..lineTo(w * 0.385, h * 0.438)
        ..lineTo(w * 0.365, h * 0.46)
        ..close(),
      Paint()..color = Palette.specular.withValues(alpha: 0.065),
    );
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.525, h * 0.126)
        ..lineTo(w * 0.545, h * 0.11)
        ..lineTo(w * 0.545, h * 0.46)
        ..lineTo(w * 0.525, h * 0.438)
        ..close(),
      Paint()..color = Palette.honeyGlow.withValues(alpha: 0.045),
    );

    _morrowTapestry(canvas, w * 0.455, h * 0.095, h * 0.465, w * 0.15);
  }

  void _window(Canvas canvas, double w, double h) {
    final fx = w * 0.055, fy = h * 0.17, fw = w * 0.205, fh = h * 0.39;
    final rect = Rect.fromLTWH(fx, fy, fw, fh);
    final r = RRect.fromRectAndRadius(rect, const Radius.circular(2));
    // the view outside (clipped to the pane) — t makes the weather live
    paintWindowScene(canvas, window, rect, t: t);
    // frame + mullions on top
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..color = const Color(0xFF5A4536);
    canvas.drawRRect(r, edge);
    final bar = Paint()
      ..color = const Color(0xFF5A4536)
      ..strokeWidth = 2;
    canvas.drawLine(Offset(fx, fy + fh / 2), Offset(fx + fw, fy + fh / 2), bar);
    canvas.drawLine(Offset(fx + fw / 2, fy), Offset(fx + fw / 2, fy + fh), bar);
  }

  /// The rug takes its tone FROM THE WALLS, so every purchasable style reads
  /// as a room somebody decorated rather than one template with the same pink
  /// oval dropped into it. It used to be a fixed mauve, which happened to suit
  /// Plum Dusk and fought all four of the others — and it's the largest object
  /// on the floor, so it fought them loudly.
  /// The top surface of the mantel shelf. Shared by [_hearth], which draws the
  /// shelf, and [_candles], which stand on it — one source so they can't drift
  /// apart and leave the candles hovering.
  double _mantelY(double h, double floorY) => floorY - (h - floorY) * 0.62;

  Color get _rugTone {
    final base = Color.lerp(wall[0], wall[1], 0.5)!;
    final hsl = HSLColor.fromColor(base);
    // Only just lift it off the wall, and DESATURATE while doing it. Dyed wool
    // in a candlelit room is muted; the first pass multiplied saturation up
    // instead and produced vivid purple/mint/cornflower ovals that outshone
    // the fire. Nothing in this room may be brighter than the hearth.
    final lifted = hsl
        .withSaturation((hsl.saturation * 0.7 + 0.05).clamp(0.0, 0.28))
        .withLightness((hsl.lightness * 1.22 + 0.06).clamp(0.0, 0.32))
        .toColor();
    // a common warm bias keeps five different walls from producing one cold
    // rug and one sickly one — every style still lands in the cozy family
    return Color.lerp(lifted, const Color(0xFF6B4340), 0.32)!;
  }

  void _rug(Canvas canvas, double w, double h, double floorY) {
    final u = h - floorY;
    final c = Offset(w * 0.5, floorY + u * 0.64);
    final rx = w * 0.305, ry = u * 0.34;
    final tone = _rugTone;
    Path shape(double scale, [double yShift = 0]) => Path()
      ..moveTo(c.dx - rx * 0.54 * scale, c.dy - ry * 0.72 * scale + yShift)
      ..lineTo(c.dx + rx * 0.54 * scale, c.dy - ry * 0.72 * scale + yShift)
      ..lineTo(c.dx + rx * 0.86 * scale, c.dy - ry * 0.18 * scale + yShift)
      ..lineTo(c.dx + rx * 0.90 * scale, c.dy + ry * 0.28 * scale + yShift)
      ..lineTo(c.dx + rx * 0.70 * scale, c.dy + ry * 0.70 * scale + yShift)
      ..lineTo(c.dx - rx * 0.70 * scale, c.dy + ry * 0.70 * scale + yShift)
      ..lineTo(c.dx - rx * 0.90 * scale, c.dy + ry * 0.28 * scale + yShift)
      ..lineTo(c.dx - rx * 0.86 * scale, c.dy - ry * 0.18 * scale + yShift)
      ..close();

    // A narrow side wall gives the textile weight at the near edge.
    canvas.drawPath(
      shape(1.01, ry * 0.11),
      Paint()
        ..color = Color.lerp(tone, Colors.black, 0.46)!
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.008),
    );
    final outer = shape(1);
    canvas.drawPath(
      outer,
      Paint()
        ..shader =
            LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.lerp(tone, Palette.specular, 0.14)!,
                tone,
                Color.lerp(tone, Colors.black, 0.24)!,
              ],
            ).createShader(
              Rect.fromCenter(center: c, width: rx * 2, height: ry * 1.5),
            ),
    );
    canvas.drawPath(
      outer,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.miter
        ..strokeWidth = 2.0
        ..color = Palette.xpLight.withValues(alpha: 0.24),
    );

    // A single mitred keyline follows the same floor perspective. The old
    // oversized inner diamond read as another object sitting on the rug.
    canvas.drawPath(
      shape(0.77, ry * 0.015),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.miter
        ..strokeWidth = 1.5
        ..color = Color.lerp(
          tone,
          Palette.specular,
          0.42,
        )!.withValues(alpha: 0.46),
    );

    canvas.save();
    canvas.clipPath(outer);
    // Moonlight and firelight meet as two restrained textile planes.
    canvas.drawPath(
      Path()
        ..moveTo(c.dx - rx * 0.88, c.dy - ry * 0.18)
        ..lineTo(c.dx - rx * 0.54, c.dy - ry * 0.72)
        ..lineTo(c.dx + rx * 0.02, c.dy + ry * 0.70)
        ..lineTo(c.dx - rx * 0.28, c.dy + ry * 0.70)
        ..close(),
      Paint()..color = Palette.specular.withValues(alpha: 0.055),
    );
    canvas.drawPath(
      Path()
        ..moveTo(c.dx, c.dy - ry * 0.72)
        ..lineTo(c.dx + rx * 0.30, c.dy + ry * 0.70)
        ..lineTo(c.dx - rx * 0.04, c.dy + ry * 0.70)
        ..close(),
      Paint()..color = Palette.honeyGlow.withValues(alpha: 0.035),
    );
    canvas.restore();

    // One shallow chevron points back to the hearth and reads as weave, not a
    // floating emblem. It stays quiet enough for every wall style.
    canvas.drawPath(
      Path()
        ..moveTo(c.dx - rx * 0.43, c.dy + ry * 0.22)
        ..lineTo(c.dx, c.dy - ry * 0.22)
        ..lineTo(c.dx + rx * 0.43, c.dy + ry * 0.22),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.miter
        ..strokeWidth = 1.4
        ..color = Palette.xpLight.withValues(alpha: 0.14),
    );
  }

  void _lamp(Canvas canvas, double w, double h, double floorY) {
    // Clear the moon window: the lamp now owns the narrow hearth-side wall
    // instead of sitting directly in front of the app's strongest light wedge.
    final x = w * 0.265;
    final baseY = floorY + (h - floorY) * 0.46;
    final topY = h * 0.29;
    // A quiet faceted halo: the shade remains an object rather than dissolving
    // into a round blur, and the moonlight keeps ownership of the large beam.
    canvas.drawPath(
      Path()
        ..moveTo(x, topY - h * 0.055)
        ..lineTo(x + w * 0.058, topY - h * 0.005)
        ..lineTo(x + w * 0.040, topY + h * 0.060)
        ..lineTo(x - w * 0.040, topY + h * 0.060)
        ..lineTo(x - w * 0.058, topY - h * 0.005)
        ..close(),
      Paint()..color = Palette.honeyGlow.withValues(alpha: 0.065),
    );
    // brass pole: dark body plus one controlled fire-facing edge
    canvas.drawLine(
      Offset(x, topY + 8),
      Offset(x, baseY),
      Paint()
        ..color = const Color(0xFF4A3528)
        ..strokeWidth = 3.2,
    );
    canvas.drawLine(
      Offset(x - 0.8, topY + 8),
      Offset(x - 0.8, baseY),
      Paint()
        ..color = const Color(0xFFC39A5B).withValues(alpha: 0.44)
        ..strokeWidth = 0.9,
    );
    final footW = w * 0.08, footH = (h - floorY) * 0.10;
    canvas.drawPath(
      Path()
        ..moveTo(x - footW * 0.48, baseY)
        ..lineTo(x - footW * 0.30, baseY - footH * 0.58)
        ..lineTo(x + footW * 0.30, baseY - footH * 0.58)
        ..lineTo(x + footW * 0.48, baseY)
        ..close(),
      Paint()..color = _wood,
    );
    canvas.drawLine(
      Offset(x - footW * 0.30, baseY - footH * 0.58),
      Offset(x + footW * 0.30, baseY - footH * 0.58),
      Paint()
        ..color = const Color(0xFFC39A5B).withValues(alpha: 0.28)
        ..strokeWidth = 1,
    );
    // shade
    final shade = Path()
      ..moveTo(x - w * 0.041, topY + 8)
      ..lineTo(x + w * 0.041, topY + 8)
      ..lineTo(x + w * 0.028, topY - 7)
      ..lineTo(x - w * 0.028, topY - 7)
      ..close();
    canvas.drawPath(shade, Paint()..color = const Color(0xFFD4B27A));
    canvas.save();
    canvas.clipPath(shade);
    canvas.drawPath(
      Path()
        ..moveTo(x - w * 0.028, topY - 7)
        ..lineTo(x, topY - 7)
        ..lineTo(x - w * 0.006, topY + 8)
        ..lineTo(x - w * 0.041, topY + 8)
        ..close(),
      Paint()..color = const Color(0xFFF0D49A).withValues(alpha: 0.42),
    );
    canvas.drawPath(
      Path()
        ..moveTo(x, topY - 7)
        ..lineTo(x + w * 0.028, topY - 7)
        ..lineTo(x + w * 0.041, topY + 8)
        ..lineTo(x - w * 0.006, topY + 8)
        ..close(),
      Paint()..color = const Color(0xFF9B7548).withValues(alpha: 0.36),
    );
    canvas.restore();
    canvas.drawLine(
      Offset(x - w * 0.041, topY + 8),
      Offset(x + w * 0.041, topY + 8),
      Paint()
        ..color = const Color(0xFF6B4A2E)
        ..strokeWidth = 1.5,
    );
    canvas.drawPath(
      Path()
        ..moveTo(x - w * 0.035, topY + 6.8)
        ..lineTo(x + w * 0.035, topY + 6.8)
        ..lineTo(x + w * 0.027, topY + 10)
        ..lineTo(x - w * 0.027, topY + 10)
        ..close(),
      Paint()..color = const Color(0xFFF4C96F).withValues(alpha: 0.30),
    );
  }

  void _shelf(Canvas canvas, double w, double h) {
    final x = w * 0.70, y = h * 0.30, sw = w * 0.235;
    // A narrow cast shadow, then separate top and front planes: one readable
    // piece of timber rather than a floating line.
    canvas.drawRect(
      Rect.fromLTWH(x - 1, y + 5, sw + 2, 4),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    const spines = [
      Color(0xFF7A4A46), // oxblood cloth
      Color(0xFF3F5A55), // deep teal board
      Color(0xFF6B5836), // tan calf
      Color(0xFF4A3E5C), // slate violet
      Color(0xFF7E5C3A), // russet
    ];
    const positions = [0.05, 0.20, 0.37, 0.56, 0.74];
    const widths = [0.10, 0.12, 0.09, 0.11, 0.10];
    const heights = [0.050, 0.067, 0.058, 0.064, 0.052];
    const leans = [-0.010, 0.004, -0.013, 0.008, -0.004];
    for (var i = 0; i < 5; i++) {
      final bw = sw * widths[i];
      final bx = x + sw * positions[i];
      final bh = h * heights[i];
      final lean = sw * leans[i];
      final top = y - bh;
      final book = Path()
        ..moveTo(bx, y)
        ..lineTo(bx + bw, y)
        ..lineTo(bx + bw + lean, top)
        ..lineTo(bx + lean, top)
        ..close();
      canvas.drawPath(book, Paint()..color = spines[i]);
      canvas.drawLine(
        Offset(bx + lean, top),
        Offset(bx + bw + lean, top),
        Paint()
          ..color = Palette.xpLight.withValues(alpha: 0.18)
          ..strokeWidth = 1,
      );
      canvas.drawLine(
        Offset(bx + lean + bw * 0.20, top + bh * 0.08),
        Offset(bx + bw * 0.20, y),
        Paint()
          ..color = Palette.specular.withValues(alpha: 0.10)
          ..strokeWidth = bw * 0.18,
      );
      canvas.drawLine(
        Offset(bx + lean * 0.35, top + bh * 0.68),
        Offset(bx + bw + lean * 0.35, top + bh * 0.68),
        Paint()
          ..color = const Color(0xFFC8A56B).withValues(alpha: 0.42)
          ..strokeWidth = 0.8,
      );
    }
    final topPlane = Path()
      ..moveTo(x - sw * 0.02, y)
      ..lineTo(x + sw, y)
      ..lineTo(x + sw * 0.97, y + 3)
      ..lineTo(x, y + 3)
      ..close();
    canvas.drawPath(topPlane, Paint()..color = const Color(0xFF6A5037));
    canvas.drawPath(
      Path()
        ..moveTo(x, y + 3)
        ..lineTo(x + sw * 0.97, y + 3)
        ..lineTo(x + sw * 0.96, y + 7)
        ..lineTo(x + sw * 0.01, y + 7)
        ..close(),
      Paint()..color = const Color(0xFF3D2A20),
    );
    canvas.drawLine(
      Offset(x - sw * 0.02, y),
      Offset(x + sw, y),
      Paint()
        ..color = Palette.xpLight.withValues(alpha: 0.20)
        ..strokeWidth = 1,
    );
  }

  void _picture(Canvas canvas, double w, double h) {
    // The Woven Dawn owns the chimney breast. This collected picture
    // hangs above the right-side shelf instead of obscuring permanent progress.
    final x = w * 0.815, y = h * 0.16, pw = w * 0.105, ph = h * 0.115;
    final outer = Rect.fromLTWH(x, y, pw, ph);
    // soft drop shadow on the wall behind the frame
    canvas.drawRRect(
      RRect.fromRectAndRadius(outer.translate(2, 4), const Radius.circular(3)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.20)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    // carved wood frame, bevelled — lit along the top-left moulding and
    // shadowed along the bottom-right, so it reads as a carved edge with
    // thickness instead of a flat brown border
    canvas.drawRRect(
      RRect.fromRectAndRadius(outer, const Radius.circular(3)),
      Paint()..color = const Color(0xFF5A4536),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(outer.deflate(0.8), const Radius.circular(3)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Palette.specular.withValues(alpha: 0.22),
            Colors.black.withValues(alpha: 0.28),
          ],
        ).createShader(outer),
    );
    final inner = outer.deflate(pw * 0.07);
    // the mat's inner lip casts into the picture
    canvas.drawRRect(
      RRect.fromRectAndRadius(inner.inflate(1), const Radius.circular(2)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.black.withValues(alpha: 0.30),
    );
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
      ..lineTo(inner.left, inner.bottom - inner.height * 0.25)
      ..lineTo(
        inner.left + inner.width * 0.30,
        inner.bottom - inner.height * 0.48,
      )
      ..lineTo(
        inner.left + inner.width * 0.62,
        inner.bottom - inner.height * 0.38,
      )
      ..lineTo(inner.right, inner.bottom - inner.height * 0.20)
      ..lineTo(inner.right, inner.bottom)
      ..close();
    canvas.drawPath(hill, Paint()..color = const Color(0xFF6E4A38));
    // a diagonal sheen across the glazing — the tell that says "framed and
    // behind glass" rather than "a picture printed on the wall"
    canvas.drawPath(
      Path()
        ..moveTo(inner.left, inner.bottom)
        ..lineTo(inner.left + inner.width * 0.52, inner.top)
        ..lineTo(inner.left + inner.width * 0.78, inner.top)
        ..lineTo(inner.left + inner.width * 0.26, inner.bottom)
        ..close(),
      Paint()..color = Palette.specular.withValues(alpha: 0.07),
    );
    canvas.restore();
  }

  void _chair(Canvas canvas, double w, double h, double floorY) {
    final u = h - floorY;
    final x = w * 0.19, seatY = floorY + u * 0.38;
    final cw = w * 0.18, ch = u * 0.60;
    const walnut = Color(0xFF4B3024);
    const walnutLit = Color(0xFF79503A);
    const cloth = Color(0xFF835146);
    const clothLit = Color(0xFFA87362);
    const clothShade = Color(0xFF56322F);

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(x, floorY + u * 0.70),
        width: cw * 1.34,
        height: u * 0.085,
      ),
      Paint()
        ..color = const Color(0x4A000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    // Four splayed legs establish the floor perspective; the rear pair stays
    // quiet while the near pair gets a slim lit edge.
    final rearLegs = Paint()
      ..color = const Color(0xFF332119)
      ..strokeWidth = w * 0.0055
      ..strokeCap = StrokeCap.square;
    canvas.drawLine(
      Offset(x - cw * 0.28, seatY + ch * 0.22),
      Offset(x - cw * 0.35, floorY + u * 0.63),
      rearLegs,
    );
    canvas.drawLine(
      Offset(x + cw * 0.28, seatY + ch * 0.22),
      Offset(x + cw * 0.35, floorY + u * 0.63),
      rearLegs,
    );
    final frontLegs = Paint()
      ..color = walnut
      ..strokeWidth = w * 0.0065
      ..strokeCap = StrokeCap.square;
    canvas.drawLine(
      Offset(x - cw * 0.43, seatY + ch * 0.25),
      Offset(x - cw * 0.54, floorY + u * 0.70),
      frontLegs,
    );
    canvas.drawLine(
      Offset(x + cw * 0.43, seatY + ch * 0.25),
      Offset(x + cw * 0.54, floorY + u * 0.70),
      frontLegs,
    );

    // Walnut shell first, then an inset upholstered panel. The material break
    // turns the reward into furniture instead of a large fabric polygon.
    final shell = Path()
      ..moveTo(x - cw * 0.42, seatY - ch * 0.76)
      ..lineTo(x + cw * 0.34, seatY - ch * 0.76)
      ..lineTo(x + cw * 0.50, seatY + ch * 0.04)
      ..lineTo(x - cw * 0.50, seatY + ch * 0.04)
      ..close();
    canvas.drawPath(shell, Paint()..color = walnut);
    canvas.drawPath(
      Path()
        ..moveTo(x - cw * 0.33, seatY - ch * 0.67)
        ..lineTo(x + cw * 0.27, seatY - ch * 0.67)
        ..lineTo(x + cw * 0.39, seatY - ch * 0.04)
        ..lineTo(x - cw * 0.40, seatY - ch * 0.04)
        ..close(),
      Paint()..color = cloth,
    );
    canvas.save();
    canvas.clipPath(shell);
    canvas.drawPath(
      Path()
        ..moveTo(x - cw * 0.33, seatY - ch * 0.67)
        ..lineTo(x - cw * 0.02, seatY - ch * 0.67)
        ..lineTo(x - cw * 0.14, seatY - ch * 0.04)
        ..lineTo(x - cw * 0.40, seatY - ch * 0.04)
        ..close(),
      Paint()..color = clothLit.withValues(alpha: 0.62),
    );
    canvas.drawPath(
      Path()
        ..moveTo(x - cw * 0.02, seatY - ch * 0.67)
        ..lineTo(x + cw * 0.27, seatY - ch * 0.67)
        ..lineTo(x + cw * 0.39, seatY - ch * 0.04)
        ..lineTo(x - cw * 0.14, seatY - ch * 0.04)
        ..close(),
      Paint()..color = clothShade.withValues(alpha: 0.46),
    );
    canvas.restore();
    canvas.drawPath(
      Path()
        ..moveTo(x - cw * 0.28, seatY - ch * 0.60)
        ..lineTo(x + cw * 0.22, seatY - ch * 0.60)
        ..lineTo(x + cw * 0.30, seatY - ch * 0.11)
        ..lineTo(x - cw * 0.32, seatY - ch * 0.11)
        ..close(),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..strokeJoin = StrokeJoin.miter
        ..color = const Color(0xFFE2B19A).withValues(alpha: 0.20),
    );

    final seatFrame = Path()
      ..moveTo(x - cw * 0.49, seatY)
      ..lineTo(x + cw * 0.49, seatY)
      ..lineTo(x + cw * 0.60, seatY + ch * 0.30)
      ..lineTo(x - cw * 0.60, seatY + ch * 0.30)
      ..close();
    canvas.drawPath(seatFrame, Paint()..color = walnutLit);
    final cushion = Path()
      ..moveTo(x - cw * 0.40, seatY + ch * 0.025)
      ..lineTo(x + cw * 0.40, seatY + ch * 0.025)
      ..lineTo(x + cw * 0.48, seatY + ch * 0.22)
      ..lineTo(x - cw * 0.48, seatY + ch * 0.22)
      ..close();
    canvas.drawPath(cushion, Paint()..color = clothLit);
    canvas.drawLine(
      Offset(x - cw * 0.37, seatY + ch * 0.055),
      Offset(x + cw * 0.37, seatY + ch * 0.055),
      Paint()
        ..color = const Color(0xFFE1B09A).withValues(alpha: 0.22)
        ..strokeWidth = 1,
    );
    canvas.drawPath(
      Path()
        ..moveTo(x - cw * 0.60, seatY + ch * 0.30)
        ..lineTo(x + cw * 0.60, seatY + ch * 0.30)
        ..lineTo(x + cw * 0.52, seatY + ch * 0.39)
        ..lineTo(x - cw * 0.52, seatY + ch * 0.39)
        ..close(),
      Paint()..color = walnut,
    );

    final arm = Paint()
      ..color = walnutLit
      ..strokeWidth = w * 0.0065
      ..strokeCap = StrokeCap.square;
    canvas.drawLine(
      Offset(x - cw * 0.46, seatY - ch * 0.10),
      Offset(x - cw * 0.63, seatY + ch * 0.26),
      arm,
    );
    canvas.drawLine(
      Offset(x + cw * 0.46, seatY - ch * 0.10),
      Offset(x + cw * 0.63, seatY + ch * 0.26),
      arm,
    );
  }

  void _plant(Canvas canvas, double w, double h, double floorY) {
    // A quiet far-left anchor balances the chair/cat group on the right.
    final x = w * 0.10, baseY = floorY + (h - floorY) * 0.59;
    final u = h - floorY;
    // contact shadow — grounds the pot on the floor
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(x, baseY + u * 0.25),
        width: w * 0.085,
        height: u * 0.075,
      ),
      Paint()
        ..color = const Color(0x40000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    // pot
    final pot = Path()
      ..moveTo(x - w * 0.032, baseY)
      ..lineTo(x + w * 0.032, baseY)
      ..lineTo(x + w * 0.024, baseY + u * 0.25)
      ..lineTo(x - w * 0.024, baseY + u * 0.25)
      ..close();
    canvas.drawPath(pot, Paint()..color = const Color(0xFF8A5A3C));
    canvas.save();
    canvas.clipPath(pot);
    canvas.drawPath(
      Path()
        ..moveTo(x - w * 0.032, baseY)
        ..lineTo(x, baseY)
        ..lineTo(x - w * 0.005, baseY + u * 0.25)
        ..lineTo(x - w * 0.024, baseY + u * 0.25)
        ..close(),
      Paint()..color = const Color(0xFFA86F49),
    );
    canvas.drawPath(
      Path()
        ..moveTo(x, baseY)
        ..lineTo(x + w * 0.032, baseY)
        ..lineTo(x + w * 0.024, baseY + u * 0.25)
        ..lineTo(x - w * 0.005, baseY + u * 0.25)
        ..close(),
      Paint()..color = const Color(0xFF70442F),
    );
    canvas.restore();
    canvas.drawLine(
      Offset(x - w * 0.034, baseY),
      Offset(x + w * 0.034, baseY),
      Paint()
        ..color = const Color(0xFFC08457)
        ..strokeWidth = 2,
    );

    // Five faceted lance leaves, each with a cool shadow plane. Decorative
    // greens stay independent from the app's success mechanic colour.
    const leaves = <(double, double, double)>[
      (-0.54, 0.60, 0.46),
      (-0.28, 0.88, 0.54),
      (0.0, 1.0, 0.58),
      (0.30, 0.82, 0.50),
      (0.56, 0.58, 0.42),
    ];
    for (var i = 0; i < leaves.length; i++) {
      final spec = leaves[i];
      final tip = Offset(x + spec.$1 * w * 0.046, baseY - h * 0.13 * spec.$2);
      final mid = Offset(x + spec.$1 * w * 0.030, baseY - h * 0.062 * spec.$2);
      final half = w * 0.012 * spec.$3;
      final leaf = Path()
        ..moveTo(x, baseY)
        ..lineTo(mid.dx - half, mid.dy)
        ..lineTo(tip.dx, tip.dy)
        ..lineTo(mid.dx + half, mid.dy)
        ..close();
      final base = i.isEven ? const Color(0xFF58745B) : const Color(0xFF6F8B69);
      canvas.drawPath(leaf, Paint()..color = base);
      canvas.drawPath(
        Path()
          ..moveTo(x, baseY)
          ..lineTo(tip.dx, tip.dy)
          ..lineTo(mid.dx + half, mid.dy)
          ..close(),
        Paint()..color = const Color(0xFF314B3B).withValues(alpha: 0.48),
      );
      canvas.drawLine(
        Offset(x, baseY),
        tip,
        Paint()
          ..color = const Color(0xFFC2C99B).withValues(alpha: 0.28)
          ..strokeWidth = 0.8,
      );
    }
  }

  /// The room's ambient hearth. It remains warmly lit regardless of streak or
  /// level; permanent progress belongs to the tapestry above it. The flame
  /// takes [emberGlow]'s hue so a chosen color still personalizes the room.
  void _hearth(Canvas canvas, double w, double h, double floorY) {
    final x = w * 0.79;
    final u = h - floorY;
    final carved = has('hearth');
    final hw = w * (carved ? 0.225 : 0.205); // compact ambient surround
    final topY = h * 0.36; // secondary side-wall fireplace
    final flameHue = emberGlow ?? const Color(0xFFEC6007);
    final fireWarm = Color.lerp(flameHue, const Color(0xFFFFD49A), 0.52)!;
    const lit = 0.86;
    final flick = 1 + 0.09 * sin(t * 2 * pi * 2) + 0.05 * sin(t * 2 * pi * 3);
    // Ambient fire uses one stable scale; level now changes only the tapestry.
    const stage = 2;
    final grow =
        0.82 +
        0.045 * stage +
        (carved ? 0.045 : 0); // trophy visibly burns taller

    // a soft wall shadow either side, grounding the breast against the wall
    canvas.drawRect(
      Rect.fromLTWH(x - hw / 2 - w * 0.02, topY, hw + w * 0.04, floorY - topY),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
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
          colors: [Color(0xFF393230), Color(0xFF463C37), Color(0xFF584940)],
          stops: [0.0, 0.55, 1.0],
        ).createShader(breast),
    );
    // Faceted stone planes: a cool shadow side and a narrow fire-facing bevel.
    // The breast remains quiet architecture, but no longer one dead rectangle.
    canvas.drawPath(
      Path()
        ..moveTo(breast.left, breast.top)
        ..lineTo(breast.left + breast.width * 0.18, breast.top)
        ..lineTo(breast.left + breast.width * 0.25, breast.bottom)
        ..lineTo(breast.left, breast.bottom)
        ..close(),
      Paint()..color = Colors.black.withValues(alpha: 0.17),
    );
    canvas.drawPath(
      Path()
        ..moveTo(breast.right - breast.width * 0.13, breast.top)
        ..lineTo(breast.right, breast.top)
        ..lineTo(breast.right, breast.bottom)
        ..lineTo(breast.right - breast.width * 0.22, breast.bottom)
        ..close(),
      Paint()..color = Palette.specular.withValues(alpha: 0.075),
    );
    // sparse stone courses — enough construction to read as masonry without
    // turning the largest shape into a grid
    final brick = Paint()
      ..color = const Color(0x22000000)
      ..strokeWidth = 1;
    for (var i = 1; i < 5; i++) {
      final by = topY + (floorY - topY) * i / 5;
      canvas.drawLine(Offset(x - hw / 2, by), Offset(x + hw / 2, by), brick);
    }
    if (carved) {
      // Week of Fire becomes architecture, not a no-op purchase. Slim carved
      // edge stones leave the picture and garland breathing room; the visual
      // payoff stays concentrated around the firebox below.
      final leftTrim = Path()
        ..moveTo(breast.left, breast.top)
        ..lineTo(breast.left + hw * 0.075, breast.top)
        ..lineTo(breast.left + hw * 0.11, breast.bottom)
        ..lineTo(breast.left, breast.bottom)
        ..close();
      final rightTrim = Path()
        ..moveTo(breast.right - hw * 0.075, breast.top)
        ..lineTo(breast.right, breast.top)
        ..lineTo(breast.right, breast.bottom)
        ..lineTo(breast.right - hw * 0.11, breast.bottom)
        ..close();
      final trimPaint = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF493A34), Color(0xFF665044), Color(0xFF392C27)],
        ).createShader(breast);
      canvas.drawPath(leftTrim, trimPaint);
      canvas.drawPath(rightTrim, trimPaint);
    }
    // mantel shelf
    final mantelY = _mantelY(h, floorY);
    final mantel = Path()
      ..moveTo(x - hw / 2 - w * 0.032, mantelY)
      ..lineTo(x + hw / 2 + w * 0.032, mantelY)
      ..lineTo(x + hw / 2 + w * 0.020, mantelY + u * 0.07)
      ..lineTo(x - hw / 2 - w * 0.020, mantelY + u * 0.07)
      ..close();
    canvas.drawPath(mantel, Paint()..color = const Color(0xFF5C4B40));
    canvas.drawPath(
      Path()
        ..moveTo(x - hw / 2 - w * 0.020, mantelY + u * 0.045)
        ..lineTo(x + hw / 2 + w * 0.020, mantelY + u * 0.045)
        ..lineTo(x + hw / 2 + w * 0.012, mantelY + u * 0.07)
        ..lineTo(x - hw / 2 - w * 0.012, mantelY + u * 0.07)
        ..close(),
      Paint()..color = Colors.black.withValues(alpha: 0.18),
    );
    canvas.drawRect(
      Rect.fromLTWH(x - hw / 2 - w * 0.025, mantelY, hw + w * 0.05, 2),
      Paint()..color = Palette.xpLight.withValues(alpha: 0.12),
    );
    if (carved) {
      // Keep the earned carving on the mantel's front edge so the tapestry
      // remains an uninterrupted, readable record of permanent progress.
      final runeY = mantelY + u * 0.038;
      final rune = Path()
        ..moveTo(x, runeY - u * 0.018)
        ..lineTo(x + w * 0.014, runeY)
        ..lineTo(x, runeY + u * 0.018)
        ..lineTo(x - w * 0.014, runeY)
        ..close();
      canvas.drawPath(
        rune,
        Paint()..color = fireWarm.withValues(alpha: 0.50 + 0.18 * lit),
      );
    }

    // firebox opening (dark, arched)
    final fbW = hw * 0.58, fbH = u * 0.5;
    final fb = floorY - u * 0.04; // the log bed
    final fbRect = Rect.fromLTWH(x - fbW / 2, floorY - fbH, fbW, fbH);
    final shoulder = fbW * 0.18;
    final firebox = Path()
      ..moveTo(fbRect.left, fbRect.bottom)
      ..lineTo(fbRect.left, fbRect.top + shoulder)
      ..lineTo(fbRect.left + shoulder, fbRect.top)
      ..lineTo(fbRect.right - shoulder, fbRect.top)
      ..lineTo(fbRect.right, fbRect.top + shoulder)
      ..lineTo(fbRect.right, fbRect.bottom)
      ..close();
    canvas.drawPath(firebox, Paint()..color = const Color(0xFF140C08));
    if (carved) {
      // Two cut-stone jambs and a keystone frame the existing firebox. They
      // stay outside the opening, so the pale fuel-line heart remains visible.
      final stone = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF8C7059), Color(0xFF5A4438), Color(0xFF372922)],
        ).createShader(fbRect.inflate(w * 0.05));
      Path jamb(bool left) {
        final edge = left ? fbRect.left : fbRect.right;
        final dir = left ? -1.0 : 1.0;
        return Path()
          ..moveTo(edge, fbRect.top + shoulder * 0.55)
          ..lineTo(edge + dir * w * 0.045, fbRect.top + shoulder * 0.28)
          ..lineTo(edge + dir * w * 0.052, fbRect.bottom)
          ..lineTo(edge, fbRect.bottom)
          ..close();
      }

      canvas.drawPath(jamb(true), stone);
      canvas.drawPath(jamb(false), stone);
      final key = Path()
        ..moveTo(x - fbW * 0.13, fbRect.top - u * 0.055)
        ..lineTo(x + fbW * 0.13, fbRect.top - u * 0.055)
        ..lineTo(x + fbW * 0.18, fbRect.top + u * 0.045)
        ..lineTo(x, fbRect.top + u * 0.085)
        ..lineTo(x - fbW * 0.18, fbRect.top + u * 0.045)
        ..close();
      canvas.drawPath(key, stone);
      canvas.drawPath(
        key,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = fireWarm.withValues(alpha: 0.34),
      );
    }
    // the firebox's back wall, warmed from within — a gradient rising off the
    // coal bed, so the opening reads as a hot cavity instead of a black hole
    // (this is what keeps the BANKED hearth from looking dead: never-punish
    // has to be true of the picture, not just the copy)
    canvas.drawPath(
      firebox,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, 0.88),
          radius: 0.95,
          colors: [
            fireWarm.withValues(alpha: 0.48 * (0.45 + 0.55 * lit)),
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
    // A crisp stone lip plus one restrained warm edge: material first, glow
    // second. The old blurred outline made the masonry look airbrushed.
    canvas.drawPath(
      firebox,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..strokeJoin = StrokeJoin.miter
        ..color = const Color(0xFF786258).withValues(alpha: 0.58),
    );
    canvas.drawLine(
      Offset(fbRect.left + shoulder * 0.22, fbRect.bottom - 1),
      Offset(fbRect.right - shoulder * 0.22, fbRect.bottom - 1),
      Paint()
        ..color = fireWarm.withValues(alpha: 0.20 + 0.22 * lit)
        ..strokeWidth = 1.2,
    );

    // firelight glowing out of the opening (reactive)
    canvas.drawCircle(
      Offset(x, floorY - fbH * 0.27),
      fbW * 0.56 * (0.94 + 0.08 * flick),
      Paint()
        ..color = fireWarm.withValues(
          alpha: (0.38 + 0.10 * (flick - 1) * 5) * lit,
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    // ── the log bed: two split logs crossed over live coals. Both stay when
    // the fireplace stays consistently warm; activity never banks it. ──
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

    {
      // The shared painter anchors the pale
      // heat at each tongue's fuel-contact base while the purchased hue rises,
      // keeping the shop colour visible through the upper silhouette.
      // Side tongues paint first and the broad central spear overlaps them,
      // forming the same single clustered silhouette as the app icon.
      for (final spec in const [
        (-0.18, 0.66, 0.0, 0.095),
        (0.18, 0.72, 2.4, 0.095),
        (0.0, 1.0, 1.3, 0.12),
      ]) {
        final fx = x + spec.$1 * fbW;
        final f = 1 + 0.16 * sin(t * 2 * pi * 2 + spec.$3);
        final lean = fbW * 0.07 * sin(t * 2 * pi + spec.$3);
        final fhh = fbH * 0.80 * spec.$2 * f * grow;
        final bw = fbW * spec.$4 * spec.$2;
        final fr = Rect.fromLTWH(fx - bw * 1.2, fb - fhh, bw * 2.4, fhh);
        paintEmberFlame(canvas, fr, flameHue, lean: lean, intensity: lit);
      }
      // Everflame and the achievement-gated Gilded flame earn a restrained
      // crown of sparks. The carved hearth adds one more ember: trophies feel
      // exceptional, but never outshine the fire itself.
      final sparkCount = heirloomFlame
          ? 3
          : (carved ? 2 : (stage >= 5 ? 1 : 0));
      for (var i = 0; i < sparkCount; i++) {
        final phase = i * 2.15;
        final sy =
            (fb - fbH * grow) -
            u * (0.045 + i * 0.018) * (0.5 + 0.5 * sin(t * 2 * pi + phase));
        canvas.drawCircle(
          Offset(x + fbW * 0.14 * sin(t * 2 * pi * 1.5 + phase), sy),
          fbW * (heirloomFlame ? 0.038 : 0.032),
          Paint()
            ..color =
                (heirloomFlame
                        ? const Color(0xFFFFE08A)
                        : const Color(0xFFFFF4D9))
                    .withValues(
                      alpha:
                          0.35 +
                          0.45 * (0.5 + 0.5 * sin(t * 2 * pi * 3 + phase)),
                    )
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
        );
      }
    }
  }

  /// The permanent progress object: a future landscape woven one lasting row
  /// at a time. The source stays opaque and textural; future rows are colour-
  /// muted instead of faded, and a soft transition replaces the old hard crop.
  /// Level never falls, so neither can the woven edge.
  void _morrowTapestry(
    Canvas canvas,
    double centerX,
    double topY,
    double mantelY,
    double hearthWidth,
  ) {
    final image = tapestryImage;
    if (image == null) return;

    final availableH = mantelY - topY;
    final source = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    final aspect = source.width / source.height;
    final width = min(hearthWidth * 1.08, availableH * 1.04 * aspect);
    final height = width / aspect;
    final dest = Rect.fromCenter(
      center: Offset(centerX, topY + availableH * 0.48),
      width: width,
      height: height,
    );
    final woven = ((level + 2) / 36).clamp(0.12, 1.0);
    // Progress belongs to the cloth itself, not to the already-finished rod or
    // tassels. These bounds track the woven body inside the approved source.
    final clothTop = dest.top + dest.height * 0.18;
    final clothBottom = dest.top + dest.height * 0.78;
    final edgeY = clothBottom - (clothBottom - clothTop) * woven;
    final feather = min(dest.height * 0.055, 7.0);
    final transitionTop = (edgeY - feather / 2).clamp(dest.top, dest.bottom);
    final transitionBottom = (edgeY + feather / 2).clamp(dest.top, dest.bottom);
    const futureTint = Color(0xFF766A79);

    void drawSlice(double top, double bottom, Color tint) {
      if (bottom <= top) return;
      final topT = (top - dest.top) / dest.height;
      final bottomT = (bottom - dest.top) / dest.height;
      final sourceSlice = Rect.fromLTRB(
        source.left,
        source.top + source.height * topT,
        source.right,
        source.top + source.height * bottomT,
      );
      final destinationSlice = Rect.fromLTRB(
        dest.left,
        top,
        dest.right,
        bottom,
      );
      canvas.drawImageRect(
        image,
        sourceSlice,
        destinationSlice,
        Paint()
          ..colorFilter = ColorFilter.mode(tint, BlendMode.modulate)
          ..filterQuality = FilterQuality.high,
      );
    }

    // The derived room asset removes only the edge-connected near-black
    // backdrop from the approved source. The tapestry itself remains opaque,
    // so it hangs naturally on the stone instead of reading as a pasted icon.
    drawSlice(dest.top, clothTop, Colors.white);
    drawSlice(clothTop, transitionTop, futureTint);
    const transitionSteps = 6;
    for (var i = 0; i < transitionSteps; i++) {
      final start = i / transitionSteps;
      final end = (i + 1) / transitionSteps;
      drawSlice(
        transitionTop + (transitionBottom - transitionTop) * start,
        transitionTop + (transitionBottom - transitionTop) * end,
        Color.lerp(futureTint, Colors.white, (start + end) / 2)!,
      );
    }
    drawSlice(transitionBottom, clothBottom, Colors.white);
    drawSlice(clothBottom, dest.bottom, Colors.white);

    // One intentionally stitched frontier makes the current completed row
    // legible without turning the artwork into a progress bar or restoring the
    // old hard crop. The dashes move upward only as level increases.
    final stitchLeft = dest.left + dest.width * 0.17;
    final stitchRight = dest.right - dest.width * 0.17;
    const stitchCount = 9;
    final slot = (stitchRight - stitchLeft) / stitchCount;
    final stitchPaint = Paint()
      ..color = const Color(0xFFF1AA3C).withValues(alpha: 0.72)
      ..strokeWidth = dest.width * 0.008
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < stitchCount; i++) {
      final startX = stitchLeft + slot * (i + 0.16);
      final endX = stitchLeft + slot * (i + 0.72);
      canvas.drawLine(Offset(startX, edgeY), Offset(endX, edgeY), stitchPaint);
    }
  }

  /// The room's optional cat: sitting up when the space is active, curled into
  /// a loaf when it is quiet. It is ambient furniture, never the product's
  /// companion, progress meter, or reason to return.
  ///
  /// Built from a locked set of proportions rather than free offsets, because
  /// the previous version drifted: the head had grown as wide as the entire
  /// body, there were no legs or muzzle, and the tail was a stroke floating
  /// clear of the silhouette. A cat reads as a cat from three things — a head
  /// clearly smaller than the body it sits on, a muzzle, and paws on the floor.
  void _pet(Canvas canvas, double w, double h, double floorY, bool awake) {
    final u = h - floorY;
    final cx = w * 0.63;
    final baseY = floorY + u * 0.88; // the floorboard the cat sits on

    const coat = Color(0xFF29262F);
    const coatLit = Color(0xFF62505E); // surfaces the hearth reaches
    const coatShade = Color(0xFF17151C); // undersides and the far flank
    const innerEar = Color(0xFF8C6678);
    const ink = Color(0xFF0E0C12);
    final fur = Paint()..color = coat;

    // Moonlight describes the left planes; the side-wall fireplace adds a
    // warm rim through the final additive light pass.
    final lit = Paint()..color = coatLit;

    // one soft contact shadow, pooled under whatever pose is drawn
    void ground(double width) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx, baseY + u * 0.01),
          width: width,
          height: u * 0.045,
        ),
        Paint()
          ..color = const Color(0x4D000000)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, u * 0.018),
      );
    }

    Path facetedDisc(Offset c, double r, [int sides = 9]) {
      final p = Path();
      for (var i = 0; i < sides; i++) {
        final a = -pi / 2 + 2 * pi * i / sides;
        final point = c.translate(cos(a) * r, sin(a) * r);
        if (i == 0) {
          p.moveTo(point.dx, point.dy);
        } else {
          p.lineTo(point.dx, point.dy);
        }
      }
      return p..close();
    }

    /// An ear anchored ON the skull: both base points sit inside the head
    /// circle and only the tip pushes past the rim, so it can never drift off
    /// the head or vanish inside it.
    void ear(Offset hc, double r, double s) {
      final baseA = Offset(hc.dx + s * r * 0.16, hc.dy - r * 0.92);
      final baseB = Offset(hc.dx + s * r * 0.90, hc.dy - r * 0.30);
      final tip = Offset(hc.dx + s * r * 0.84, hc.dy - r * 1.44);
      canvas.drawPath(
        Path()
          ..moveTo(baseA.dx, baseA.dy)
          ..lineTo(tip.dx, tip.dy)
          ..lineTo(baseB.dx, baseB.dy)
          ..close(),
        fur,
      );
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
        Paint()..color = innerEar.withValues(alpha: 0.62),
      );
    }

    /// Muzzle, nose and mouth. This is the single detail that turns a tan
    /// circle with ears into a cat, so it is worth the four extra draws.
    void muzzle(Offset hc, double r) {
      // two soft cheek pads
      for (final s in const [-1.0, 1.0]) {
        canvas.drawOval(
          Rect.fromCenter(
            center: hc.translate(s * r * 0.20, r * 0.46),
            width: r * 0.52,
            height: r * 0.38,
          ),
          Paint()..color = coatLit.withValues(alpha: 0.75),
        );
      }
      // nose
      final nose = hc.translate(0, r * 0.30);
      canvas.drawPath(
        Path()
          ..moveTo(nose.dx - r * 0.10, nose.dy)
          ..lineTo(nose.dx + r * 0.10, nose.dy)
          ..lineTo(nose.dx, nose.dy + r * 0.11)
          ..close(),
        Paint()..color = innerEar,
      );
      // the two strokes of a cat's w-shaped mouth
      final mouth = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.055
        ..strokeCap = StrokeCap.round
        ..color = ink.withValues(alpha: 0.8);
      for (final s in const [-1.0, 1.0]) {
        canvas.drawArc(
          Rect.fromCenter(
            center: nose.translate(s * r * 0.16, r * 0.20),
            width: r * 0.34,
            height: r * 0.28,
          ),
          s < 0 ? 0 : pi * 0.5,
          pi * 0.5,
          false,
          mouth,
        );
      }
    }

    if (awake) {
      // ── sitting up, watching you ──
      final bw = w * 0.078; // a room-scale companion, never the focal mascot
      final bh = u * 0.35; // floor to shoulder
      final headR = bw * 0.40; // decisively smaller than the body
      final headC = Offset(cx + bw * 0.02, baseY - bh - headR * 0.62);

      ground(bw * 1.35);

      // tail: leaves the body low on the right, sweeps out and curls up. Drawn
      // BEFORE the body so it reads as emerging from behind the haunch rather
      // than being pasted on the side of it.
      canvas.drawPath(
        Path()
          ..moveTo(cx + bw * 0.30, baseY - bh * 0.10)
          ..cubicTo(
            cx + bw * 0.95,
            baseY - bh * 0.02,
            cx + bw * 1.05,
            baseY - bh * 0.46,
            cx + bw * 0.72,
            baseY - bh * 0.58,
          ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = bw * 0.16
          ..strokeCap = StrokeCap.round
          ..color = coatShade,
      );

      // body: a faceted pear — wide haunch, narrow shoulder, crisp silhouette
      canvas.drawPath(
        Path()
          ..moveTo(cx - bw * 0.5, baseY)
          ..lineTo(cx - bw * 0.46, baseY - bh * 0.48)
          ..lineTo(cx - bw * 0.28, baseY - bh * 0.88)
          ..lineTo(cx, baseY - bh)
          ..lineTo(cx + bw * 0.28, baseY - bh * 0.88)
          ..lineTo(cx + bw * 0.46, baseY - bh * 0.48)
          ..lineTo(cx + bw * 0.5, baseY)
          ..close(),
        fur,
      );
      // the far flank falls into shadow; the hearth-facing side catches light
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx + bw * 0.30, baseY - bh * 0.42),
          width: bw * 0.42,
          height: bh * 0.72,
        ),
        Paint()..color = coatShade.withValues(alpha: 0.5),
      );
      // chest bib
      canvas.drawPath(
        Path()
          ..moveTo(cx - bw * 0.22, baseY - bh * 0.62)
          ..lineTo(cx + bw * 0.12, baseY - bh * 0.66)
          ..lineTo(cx + bw * 0.22, baseY - bh * 0.12)
          ..lineTo(cx - bw * 0.18, baseY - bh * 0.08)
          ..close(),
        Paint()..color = coatLit.withValues(alpha: 0.55),
      );

      // front legs + paws, planted on the floor — without these the cat floats
      for (final s in const [-1.0, 1.0]) {
        final lx = cx + s * bw * 0.20;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              lx - bw * 0.10,
              baseY - bh * 0.30,
              bw * 0.20,
              bh * 0.30,
            ),
            Radius.circular(bw * 0.09),
          ),
          // the far leg has to be a shade darker or it vanishes into the body
          s < 0 ? lit : Paint()
            ..color = coatShade,
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(lx, baseY - bh * 0.02),
            width: bw * 0.24,
            height: bh * 0.11,
          ),
          s < 0 ? lit : Paint()
            ..color = coatShade,
        );
      }

      // head
      canvas.drawPath(facetedDisc(headC, headR), fur);
      // firelit crown on the hearth side
      canvas.drawCircle(
        headC.translate(-headR * 0.26, -headR * 0.22),
        headR * 0.62,
        Paint()..color = coatLit.withValues(alpha: 0.45),
      );
      ear(headC, headR, -1);
      ear(headC, headR, 1);
      muzzle(headC, headR);

      // eyes: almonds, not black discs, with a catchlight and a lower lid
      for (final s in const [-1.0, 1.0]) {
        final ec = headC.translate(s * headR * 0.41, -headR * 0.08);
        canvas.drawOval(
          Rect.fromCenter(
            center: ec,
            width: headR * 0.24,
            height: headR * 0.28,
          ),
          Paint()..color = ink,
        );
        canvas.drawCircle(
          ec.translate(-headR * 0.07, -headR * 0.09),
          headR * 0.06,
          Paint()..color = Colors.white.withValues(alpha: 0.92),
        );
      }

      // whiskers — three light strokes a side, the last cat-tell
      final whisker = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = headR * 0.035
        ..strokeCap = StrokeCap.round
        ..color = Palette.specular.withValues(alpha: 0.32);
      for (final s in const [-1.0, 1.0]) {
        for (final dy in const [-0.06, 0.06, 0.18]) {
          canvas.drawLine(
            headC.translate(s * headR * 0.40, headR * (0.34 + dy)),
            headC.translate(s * headR * 1.12, headR * (0.26 + dy * 1.6)),
            whisker,
          );
        }
      }
    } else {
      // ── curled into a loaf, asleep ──
      final bw = w * 0.108; // a loaf is wider than it is tall
      final bh = u * 0.22;
      final headR = bw * 0.27;
      final headC = Offset(cx - bw * 0.30, baseY - headR * 0.96);

      ground(bw * 1.15);

      // the loaf: a low faceted dome with a flat floor edge
      canvas.drawPath(
        Path()
          ..moveTo(cx - bw * 0.5, baseY)
          ..lineTo(cx - bw * 0.44, baseY - bh * 0.58)
          ..lineTo(cx - bw * 0.12, baseY - bh)
          ..lineTo(cx + bw * 0.16, baseY - bh * 0.96)
          ..lineTo(cx + bw * 0.46, baseY - bh * 0.54)
          ..lineTo(cx + bw * 0.5, baseY)
          ..close(),
        fur,
      );
      // the back curve catches the hearth; the front falls away
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx - bw * 0.06, baseY - bh * 0.74),
          width: bw * 0.66,
          height: bh * 0.44,
        ),
        Paint()..color = coatLit.withValues(alpha: 0.42),
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx + bw * 0.10, baseY - bh * 0.16),
          width: bw * 0.72,
          height: bh * 0.34,
        ),
        Paint()..color = coatShade.withValues(alpha: 0.45),
      );

      // tail wrapped around the front, tip tucked in by the chin — drawn AFTER
      // the body, because a sleeping cat's tail lies over its own paws
      canvas.drawPath(
        Path()
          ..moveTo(cx + bw * 0.46, baseY - bh * 0.16)
          ..cubicTo(
            cx + bw * 0.30,
            baseY + bh * 0.06,
            cx - bw * 0.10,
            baseY + bh * 0.02,
            cx - bw * 0.26,
            baseY - bh * 0.16,
          ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = bh * 0.30
          ..strokeCap = StrokeCap.round
          ..color = coatLit,
      );

      // head resting on the paws
      canvas.drawPath(facetedDisc(headC, headR), fur);
      canvas.drawCircle(
        headC.translate(-headR * 0.24, -headR * 0.26),
        headR * 0.60,
        Paint()..color = coatLit.withValues(alpha: 0.40),
      );
      ear(headC, headR, -1);
      ear(headC, headR, 1);
      muzzle(headC, headR);

      // two contented closed eyes
      final shut = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = headR * 0.10
        ..strokeCap = StrokeCap.round
        ..color = ink;
      for (final s in const [-1.0, 1.0]) {
        canvas.drawArc(
          Rect.fromCircle(
            center: headC.translate(s * headR * 0.34, -headR * 0.06),
            radius: headR * 0.22,
          ),
          pi * 0.15,
          pi * 0.7,
          false,
          shut,
        );
      }

      // Zzz drifting up from the head
      final z = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round
        ..color = Palette.xpLight.withValues(alpha: 0.6);
      for (var i = 0; i < 3; i++) {
        final s = w * (0.018 - i * 0.004);
        // start clear of the ear tips, then drift up and away
        final zx = headC.dx + w * 0.075 + i * w * 0.026;
        final zy = headC.dy - u * 0.20 - i * u * 0.09;
        canvas.drawLine(Offset(zx, zy), Offset(zx + s, zy), z);
        canvas.drawLine(Offset(zx + s, zy), Offset(zx, zy + s), z);
        canvas.drawLine(Offset(zx, zy + s), Offset(zx + s, zy + s), z);
      }
    }
  }

  // a string of warm bulbs draped across the upper wall (sags in the middle)
  void _garland(Canvas canvas, double w, double h) {
    // Keep the strand in the high wall band so the enlarged Woven Dawn
    // retains an uninterrupted silhouette on the chimney breast.
    final left = Offset(w * 0.36, h * 0.012);
    final right = Offset(w * 0.97, h * 0.025);
    final mid = Offset((left.dx + right.dx) / 2, h * 0.045); // shallow sag
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

  /// A floor cushion — a faceted tufted pouffe seen slightly from above: an
  /// hexagonal top plane over a short side wall, a button in the middle and
  /// seams running out from it.
  ///
  /// The old version was a plain rounded rectangle in the rug's dye, and it
  /// read as an unidentifiable coloured blob rather than as the "floor
  /// cushion" the shop sells. A thing you paid embers for has to be legible
  /// as that thing.
  void _cushion(Canvas canvas, double w, double h, double floorY) {
    final u = h - floorY;
    final c = Offset(w * 0.67, floorY + u * 0.58);
    final cw = w * 0.11, ch = u * 0.19;
    // warmer and a touch deeper than the rug, not lighter: a throw cushion is
    // an accent against the floor covering, and lerping toward cream just
    // turned it grey — it read like a stone disc rather than something soft
    final tone = Color.lerp(_rugTone, const Color(0xFF9A6A5E), 0.45)!;
    final side = Color.lerp(tone, Colors.black, 0.28)!;

    canvas.drawOval(
      Rect.fromCenter(
        center: c.translate(0, ch * 0.52),
        width: cw * 1.1,
        height: ch * 0.3,
      ),
      Paint()
        ..color = const Color(0x55000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    final topC = c.translate(0, -ch * 0.14);
    Path hex(Offset p, double sx, double sy) => Path()
      ..moveTo(p.dx - sx * 0.50, p.dy)
      ..lineTo(p.dx - sx * 0.25, p.dy - sy * 0.50)
      ..lineTo(p.dx + sx * 0.25, p.dy - sy * 0.50)
      ..lineTo(p.dx + sx * 0.50, p.dy)
      ..lineTo(p.dx + sx * 0.25, p.dy + sy * 0.50)
      ..lineTo(p.dx - sx * 0.25, p.dy + sy * 0.50)
      ..close();
    final lower = hex(topC.translate(0, ch * 0.30), cw, ch * 0.62);
    canvas.drawPath(lower, Paint()..color = side);
    final top = hex(topC, cw, ch * 0.62);
    canvas.drawPath(
      top,
      Paint()
        ..shader =
            LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color.lerp(tone, Colors.white, 0.10)!, tone, side],
            ).createShader(
              Rect.fromCenter(center: topC, width: cw, height: ch * 0.62),
            ),
    );
    canvas.drawPath(
      top,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeJoin = StrokeJoin.round
        ..color = Palette.specular.withValues(alpha: 0.16),
    );
    // seams pulled in toward a button at the centre — the tuft is the detail
    // that names the object
    final seam = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = side.withValues(alpha: 0.6);
    for (var i = 0; i < 6; i++) {
      final a = 2 * pi * i / 6 - pi / 6;
      canvas.drawLine(
        topC.translate(cos(a) * cw * 0.07, sin(a) * ch * 0.045),
        topC.translate(cos(a) * cw * 0.46, sin(a) * ch * 0.28),
        seam,
      );
    }
    canvas.drawOval(
      Rect.fromCenter(center: topC, width: cw * 0.15, height: ch * 0.1),
      Paint()..color = side,
    );
  }

  // a little cluster of three candles glowing on the floor — each flame sways
  // and its halo pulses on its own phase (t), so the cluster wavers like real
  // candlelight instead of three frozen teardrops
  void _candles(Canvas canvas, double w, double h, double floorY) {
    final u = h - floorY;
    final flameHue = emberGlow ?? const Color(0xFFEC6007);
    final candleWarm = Color.lerp(flameHue, const Color(0xFFFFD49A), 0.58)!;
    // ON THE MANTEL, not on the rug. Open flames standing on a wool rug beside
    // a sleeping cat is a fire hazard anyone who has lived with an animal reads
    // instantly, and a scene whose whole job is to feel calm cannot afford to
    // make you anxious. A stone shelf above the animal is where candles
    // actually live in a room with a hearth.
    final clusterX = w * 0.855; // on the compact side-wall mantel
    final baseY = _mantelY(h, floorY);
    // the light they throw back onto the chimney breast behind them
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(clusterX, baseY - u * 0.10),
        width: w * 0.19 * (0.94 + 0.06 * sin(t * 2 * pi * 2)),
        height: u * 0.34,
      ),
      Paint()
        ..color = candleWarm.withValues(alpha: 0.16)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.035),
    );
    var i = 0;
    for (final spec in [(-0.028, 0.9), (0.0, 1.15), (0.028, 0.8)]) {
      final cx = clusterX + spec.$1 * w;
      final ch = u * 0.17 * spec.$2;
      final phase = i * 2.1;
      final sway = 2.0 * sin(t * 2 * pi * 2 + phase);
      final pulse = 0.85 + 0.15 * sin(t * 2 * pi * 2 + phase);
      final tipY = baseY - ch - 9 - 1.5 * sin(t * 2 * pi * 2 + phase);
      // a wax foot, so each candle stands ON the stone rather than in front of it
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, baseY), width: 11, height: 3.6),
        Paint()..color = const Color(0x44000000),
      );
      canvas.drawCircle(
        Offset(cx, baseY - ch - 4),
        8 * pulse,
        Paint()
          ..color = candleWarm.withValues(alpha: 0.7 * pulse)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - 3, baseY - ch, 6, ch),
          const Radius.circular(2),
        ),
        Paint()..color = const Color(0xFFF0E2C8),
      );
      // the taper's shaded right side — a lit cylinder, not a cream stripe
      canvas.drawRect(
        Rect.fromLTWH(cx + 1, baseY - ch, 2, ch),
        Paint()..color = const Color(0x22000000),
      );
      paintEmberFlame(
        canvas,
        Rect.fromLTWH(cx - 3.2, tipY, 6.4, (baseY - ch) - tipY),
        flameHue,
        lean: sway,
        intensity: pulse,
      );
      i++;
    }
  }

  @override
  bool shouldRepaint(_RoomPainter old) =>
      old.t != t ||
      old.parallax != parallax ||
      old.window != window ||
      old.petAwake != petAwake ||
      old.emberGlow != emberGlow ||
      old.heirloomFlame != heirloomFlame ||
      old.level != level ||
      old.memoryArtifacts != memoryArtifacts ||
      old.tapestryImage != tapestryImage ||
      old.wallGrain != wallGrain ||
      old.floorGrain != floorGrain ||
      old.plate != plate ||
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
      // A low sun caught between crisp, graphic ridges. The restrained halo
      // gives it atmosphere without softening the whole miniature.
      canvas.drawCircle(
        at(0.3, 0.62),
        fw * 0.23,
        Paint()
          ..color = const Color(0xFFF6D79A).withValues(alpha: 0.4)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, fw * 0.05),
      );
      canvas.drawCircle(
        at(0.3, 0.62),
        fw * 0.13,
        Paint()..color = const Color(0xFFFFE9B8),
      );
      final farRidge = Path()
        ..moveTo(fx, fy + fh)
        ..lineTo(fx, fy + fh * 0.78)
        ..lineTo(fx + fw * 0.22, fy + fh * 0.69)
        ..lineTo(fx + fw * 0.42, fy + fh * 0.74)
        ..lineTo(fx + fw * 0.67, fy + fh * 0.64)
        ..lineTo(fx + fw, fy + fh * 0.77)
        ..lineTo(fx + fw, fy + fh)
        ..close();
      canvas.drawPath(farRidge, Paint()..color = const Color(0xFF78503C));
      final nearRidge = Path()
        ..moveTo(fx, fy + fh)
        ..lineTo(fx, fy + fh * 0.88)
        ..lineTo(fx + fw * 0.28, fy + fh * 0.79)
        ..lineTo(fx + fw * 0.54, fy + fh * 0.86)
        ..lineTo(fx + fw * 0.77, fy + fh * 0.75)
        ..lineTo(fx + fw, fy + fh * 0.84)
        ..lineTo(fx + fw, fy + fh)
        ..close();
      canvas.drawPath(nearRidge, Paint()..color = const Color(0xFF4B352F));
    case 'aurora':
      sky(const [Color(0xFF0A1220), Color(0xFF101A26)]);
      stars(const [
        Offset(0.2, 0.2),
        Offset(0.5, 0.14),
        Offset(0.8, 0.24),
        Offset(0.66, 0.4),
      ]);
      // Faceted curtains: still slowly alive, but made from translucent light
      // planes rather than three blurred marker strokes.
      for (final band in [
        (0.00, 0.20, const Color(0xFF6FE0A0)),
        (0.17, 0.16, const Color(0xFF8FD0E0)),
        (0.36, 0.13, const Color(0xFFB58AE0)),
      ]) {
        final top = <Offset>[];
        final bottom = <Offset>[];
        for (var i = 0; i <= 7; i++) {
          final x = fx + fw * (i / 7);
          final wave =
              0.055 * sin(i * 1.45 + band.$1 * 8 + t * 2 * pi) +
              0.018 * sin(i * 2.7 - t * 2 * pi);
          final topY =
              fy + fh * (0.20 + band.$1 + wave + (i.isEven ? -0.025 : 0.025));
          final depth = fh * band.$2 * (i.isEven ? 1.1 : 0.72);
          top.add(Offset(x, topY));
          bottom.add(Offset(x, topY + depth));
        }
        final p = Path()..moveTo(top.first.dx, top.first.dy);
        for (final point in top.skip(1)) {
          p.lineTo(point.dx, point.dy);
        }
        for (final point in bottom.reversed) {
          p.lineTo(point.dx, point.dy);
        }
        p.close();
        canvas.drawPath(
          p,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                band.$3.withValues(alpha: 0.62),
                band.$3.withValues(alpha: 0.26),
                band.$3.withValues(alpha: 0.02),
              ],
            ).createShader(p.getBounds()),
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
