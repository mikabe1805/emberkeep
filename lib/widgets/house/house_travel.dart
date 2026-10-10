// The dock's travel: each room arrives through its own light.
//
// Replaces the single tab dissolve. Nothing slides; you turn toward a place and
// that room's own light brings it up (house_arrival.dart has the five lights,
// house_travel_model.dart the choreography). Here is the widget that plays it:
//
//   * every room stays mounted (state, scroll positions and decoded art stay
//     alive); only the room being shown, and while one is arriving the rooms
//     it arrives over, are on stage;
//   * the arriving room is under a soft-edged reveal mask (a ShaderMask) over a
//     cross-dissolve, with a faint glow along the edge in the light's own
//     colour, screened over the picture. No blur;
//   * the room it leaves dips 25% over 220 ms and lets go of its UI first; the
//     arriving room drifts in 14 pt from the tapped side and dollies 1.03 to
//     1.0, and its UI comes up once its light reaches it;
//   * a new tap re-aims from the picture on screen;
//   * Reduce Motion is a 200 ms cross-fade.
//
// Masks exist only while arriving. At rest the stage is one room painted
// directly, exactly as it was under IndexedStack. Route pushes are not touched
// here: they stay the native Cupertino transitions (room_travel.dart).
library;

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../clock.dart';
import '../class_day/class_day_room.dart' show classStatusAbove;
import '../class_day/doorway_light.dart';
import '../room_travel.dart' show RoomTravel;
import 'house_arrival.dart';
import 'house_room.dart';
import 'house_travel_model.dart';
import 'house_travel_scope.dart';

/// The five rooms, switched by the dock, each arriving through its own light.
///
/// Keeps IndexedStack's contract: every child stays mounted with its state
/// alive, and only the live one hits or speaks to assistive tech. [children]
/// are the rooms in dock order ([HouseRoom.values]).
class HouseTravelStack extends StatefulWidget {
  const HouseTravelStack({
    super.key,
    required this.index,
    required this.children,
    this.reduceMotion,
  });

  /// The dock tab being shown.
  final int index;

  /// The five rooms, in dock order.
  final List<Widget> children;

  /// Forces Reduce Motion on or off (tests); null reads the app's and the
  /// system's setting.
  final bool? reduceMotion;

  @override
  State<HouseTravelStack> createState() => _HouseTravelStackState();
}

class _HouseTravelStackState extends State<HouseTravelStack> {
  late final HouseTravelModel _model;
  final HouseTravelSignals _signals = HouseTravelSignals();
  final ValueNotifier<int> _frame = ValueNotifier(0);
  bool _scheduled = false;
  double _lastMs = 0;

  @override
  void initState() {
    super.initState();
    _model = HouseTravelModel(initial: widget.index);
  }

  bool get _still =>
      widget.reduceMotion ??
      (RoomTravel.reduceMotion ||
          (MediaQuery.maybeDisableAnimationsOf(context) ?? false));

  /// The time of the frame being built, in ms; the last known one outside a
  /// frame (a tap that rebuilds before any frame has run).
  double _nowMs() {
    final binding = SchedulerBinding.instance;
    switch (binding.schedulerPhase) {
      case SchedulerPhase.idle:
      case SchedulerPhase.postFrameCallbacks:
        return _lastMs;
      case SchedulerPhase.transientCallbacks:
      case SchedulerPhase.midFrameMicrotasks:
      case SchedulerPhase.persistentCallbacks:
        _lastMs = binding.currentFrameTimeStamp.inMicroseconds / 1000.0;
        return _lastMs;
    }
  }

  @override
  void didUpdateWidget(covariant HouseTravelStack old) {
    super.didUpdateWidget(old);
    if (widget.index == old.index) return;
    _model.reduceMotion = _still;
    _model.goTo(widget.index, _nowMs());
    _publish();
    _scheduleFrame();
  }

  void _scheduleFrame() {
    if (_scheduled || !(_model.busy || _model.glintPending)) return;
    _scheduled = true;
    SchedulerBinding.instance.scheduleFrameCallback(_onFrame);
  }

  void _onFrame(Duration timestamp) {
    _scheduled = false;
    if (!mounted) return;
    _lastMs = timestamp.inMicroseconds / 1000.0;
    _model.reduceMotion = _still;
    _model.update(_lastMs);
    _publish();
    _frame.value++;
    _scheduleFrame();
  }

  /// Hands the rooms' UI values and the glint to whoever listens.
  void _publish() {
    final staged = {for (final f in _model.frames) f.room: f};
    for (var i = 0; i < _signals.ui.length; i++) {
      _signals.ui[i].value = staged[i]?.ui ?? 1;
    }
    _signals.glint.value = _model.glintAt(_lastMs);
  }

  @override
  void dispose() {
    _signals.dispose();
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The painting runs up under the status bar (the shell's SafeArea keeps
    // the pages below it): the stage is the whole screen, and each room's page
    // sits where it always did.
    final above = classStatusAbove(context);
    return HouseTravelScope(
      signals: _signals,
      child: Stack(
        clipBehavior: Clip.none,
        fit: StackFit.expand,
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: -above,
            bottom: 0,
            child: LayoutBuilder(
              builder: (context, box) => AnimatedBuilder(
                animation: _frame,
                builder: (context, _) => _stage(box.biggest, above),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stage(Size size, double above) {
    final frames = _model.frames;
    final staged = {for (final f in frames) f.room: f};
    final live = widget.index;
    final lights = doorwayLightsAt(Clock.now());
    final k = size.width / houseCanvasWidth;
    final height = k <= 0 ? houseCanvasHeight : size.height / k;
    final now = _lastMs;
    final arrivals = <int, HouseArrivalFrame>{
      for (final f in frames)
        if (f.arriving)
          f.room: houseArrivalFrame(
            HouseRoom.values[f.room],
            f.light,
            timeMs: now,
            lights: lights,
            canvasHeight: height,
          ),
    };
    final children = <Widget>[
      // Rooms that are not on stage wait offstage, first, so a staged room
      // never moves in the tree when the others come and go (keyed siblings).
      for (var i = 0; i < widget.children.length; i++)
        if (!staged.containsKey(i)) _pane(i, null, above, false, null),
      for (final f in frames) ...[
        _pane(f.room, f, above, f.room == live, arrivals[f.room]?.mask),
        if (arrivals[f.room] case final arrival?)
          Positioned.fill(
            key: ValueKey('house-glow-${f.room}'),
            child: IgnorePointer(
              child: CustomPaint(painter: _GlowPainter(arrival.glow, k)),
            ),
          ),
      ],
    ];
    return Stack(fit: StackFit.expand, children: children);
  }

  Widget _pane(
    int room,
    HouseLayerFrame? f,
    double above,
    bool live,
    List<HouseGradient>? mask,
  ) {
    final transform = f == null || (f.dx == 0 && f.scale == 1)
        ? Matrix4.identity()
        : (Matrix4.translationValues(f.dx, 0, 0)
            ..scaleByDouble(f.scale, f.scale, 1, 1));
    final dim = f?.dim ?? 0;
    return Positioned.fill(
      key: ValueKey('house-room-$room'),
      child: Offstage(
        offstage: f == null,
        child: IgnorePointer(
          ignoring: !live,
          child: ExcludeSemantics(
            excluding: !live,
            child: Opacity(
              opacity: f?.opacity ?? 1,
              child: HouseMask(
                gradients: mask,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Transform(
                      alignment: Alignment.center,
                      transform: transform,
                      child: RepaintBoundary(
                        child: Padding(
                          padding: EdgeInsets.only(top: above),
                          child: widget.children[room],
                        ),
                      ),
                    ),
                    IgnorePointer(
                      child: ColoredBox(
                        color: dim > 0.003
                            ? const Color(0xFF0B0603).withValues(alpha: dim)
                            : const Color(0x00000000),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The light's own colour along the reveal's edge, screened over the picture.
class _GlowPainter extends CustomPainter {
  _GlowPainter(this.glow, this.scale);

  final List<HouseGradient> glow;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    // The recipes list the top layer first.
    for (final layer in glow.reversed) {
      canvas.drawRect(
        rect,
        Paint()
          ..blendMode = BlendMode.screen
          ..shader = layer.shader(scale),
      );
    }
  }

  @override
  bool shouldRepaint(_GlowPainter old) => true;
}

/// Paints [child] through a soft-edged reveal made of [gradients] (black
/// gradients, composited as a union; the child shows where they are opaque).
/// With no gradients the child paints directly, with no layer at all.
///
/// A single gradient is its own shader. A union (the hearth's embers over the
/// rising firelight, the lamp's circle under its cone) is drawn into a small
/// mask image (a quarter of the screen's resolution: the edges are soft) and
/// used as the shader.
class HouseMask extends SingleChildRenderObjectWidget {
  const HouseMask({super.key, required this.gradients, super.child});

  final List<HouseGradient>? gradients;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderHouseMask(gradients);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderHouseMask).gradients = gradients;
  }
}

class _RenderHouseMask extends RenderProxyBox {
  _RenderHouseMask(this._gradients);

  List<HouseGradient>? _gradients;
  final LayerHandle<ShaderMaskLayer> _layerHandle =
      LayerHandle<ShaderMaskLayer>();
  final List<ui.Image> _images = [];

  set gradients(List<HouseGradient>? value) {
    final was = _gradients != null;
    _gradients = value;
    if (was != (value != null)) markNeedsCompositingBitsUpdate();
    markNeedsPaint();
  }

  @override
  bool get alwaysNeedsCompositing => _gradients != null && child != null;

  /// How many logical pixels one mask-image pixel covers.
  static const double _cell = 4;

  ui.Shader _shader(Size size, List<HouseGradient> gradients) {
    final k = size.width / houseCanvasWidth;
    if (gradients.length == 1) return gradients.single.shader(k);
    final w = (size.width / _cell).ceil().clamp(1, 4096);
    final h = (size.height / _cell).ceil().clamp(1, 4096);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(w / size.width, h / size.height);
    final rect = Offset.zero & size;
    for (final layer in gradients) {
      canvas.drawRect(rect, Paint()..shader = layer.shader(k));
    }
    final picture = recorder.endRecording();
    final image = picture.toImageSync(w, h);
    picture.dispose();
    _images.add(image);
    // The shader holds the image until the frame is drawn: keep the last two.
    while (_images.length > 2) {
      _images.removeAt(0).dispose();
    }
    return ui.ImageShader(
      image,
      ui.TileMode.clamp,
      ui.TileMode.clamp,
      Float64List.fromList([
        size.width / w, 0, 0, 0, //
        0, size.height / h, 0, 0,
        0, 0, 1, 0,
        0, 0, 0, 1,
      ]),
      filterQuality: FilterQuality.low,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) {
      _layerHandle.layer = null;
      return;
    }
    final gradients = _gradients;
    if (gradients == null || gradients.isEmpty || size.isEmpty) {
      _layerHandle.layer = null;
      for (final image in _images) {
        image.dispose();
      }
      _images.clear();
      context.paintChild(child, offset);
      return;
    }
    final layer = (_layerHandle.layer ??= ShaderMaskLayer())
      ..shader = _shader(size, gradients)
      ..maskRect = offset & size
      ..blendMode = BlendMode.dstIn;
    context.pushLayer(
      layer,
      super.paint,
      offset,
      childPaintBounds: offset & size,
    );
  }

  @override
  void dispose() {
    _layerHandle.layer = null;
    for (final image in _images) {
      image.dispose();
    }
    _images.clear();
    super.dispose();
  }
}
