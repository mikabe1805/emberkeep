// A room's painted backdrop: the plate stack under the room's live content.
//
// HouseRoomBackdrop(room: ..., child: ...) is how a tab becomes a room of the
// house. It paints the room's plate for the real light of the day (cross-fading
// by the same clock as the Doorway, never tinting a daylight plate to fake an
// evening), lets the plate move a hair with the phone's tilt, and puts the
// room's live content over it. The plate runs up under the status bar like the
// Doorway's does, so the painting is whole.
//
// Quests is the Doorway: its backdrop is DoorwayStage with an empty rail (a
// later pass puts Today's three on it). On a class day the Quests room draws
// its own Doorway with the day's tickets, and does not use this.
//
// At rest nothing here animates except the Doorway's ambient light; the plate
// stack repaints only when the hour moves a blend or the phone tilts. A room
// has no plate for a light it does not have (see house_room.dart), so it keeps
// its painted light.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../academic_calendar/domain/academic_schedule.dart' show CivilDate;
import '../../clock.dart';
import '../class_day/class_day_room.dart' show classStatusAbove;
import '../class_day/doorway_model.dart';
import '../class_day/doorway_stage.dart';
import '../room_travel.dart' show RoomTravel;
import 'house_light.dart';
import 'house_room.dart';
import 'house_travel_scope.dart';

/// How far the plate moves at full tilt (points), and how much larger it is
/// drawn so that movement never shows an edge. The Doorway's own numbers.
const double housePlateParallax = 1.7;
const double housePlateOverscan = 1.015;

/// How long a change of plate set (Plans, day to month) takes to cross-fade.
const housePlateSwap = Duration(milliseconds: 360);

/// How often the light of the day is read again, while the room is mounted.
const houseLightRefresh = Duration(seconds: 30);

class HouseRoomBackdrop extends StatefulWidget {
  const HouseRoomBackdrop({
    super.key,
    required this.room,
    required this.child,
    this.plates,
    this.parallax,
    this.reduceMotion,
    this.plateHeight,
    this.day,
    this.veilFrom,
  });

  /// The room this is the backdrop of.
  final HouseRoom room;

  /// The room's live content, over the plate. It fades with the dock's travel
  /// (see [HouseRoomUi]).
  final Widget child;

  /// The plates to show instead of the room's own ([HouseRoom.plates]), e.g.
  /// Plans' month spread. A change cross-fades.
  final HousePlates? plates;

  /// The shell's tilt (accelerometer) source, each axis -1 to 1; none: the
  /// plate holds still.
  final ValueListenable<Offset>? parallax;

  /// Stills the tilt and the swap. Null reads the app's and the system's
  /// Reduce Motion.
  final bool? reduceMotion;

  /// How far down the plate reaches from the top of the screen, in points
  /// (status bar included); null for the whole screen. The rest of the page is
  /// the page's own ground.
  final double? plateHeight;

  /// The Doorway's day when the room is Quests; a day with nothing on the rail
  /// when null.
  final DoorwayDay? day;

  /// Where a soft dark begins under the room's live content, in canvas points
  /// from the top of the screen (it deepens over the next 170 points), so a
  /// page that has not been rebuilt for its room yet stays readable over the
  /// painting. It rides with the room's UI: the arrival shows the bare room.
  /// Null: none.
  final double? veilFrom;

  /// Starts decoding [room]'s plates for the light of the day, so a first
  /// visit finds them ready. The dock calls it at pointer-down.
  static void warm(BuildContext context, HouseRoom room, {DateTime? now}) {
    final plates = room.plates;
    if (plates == null) return;
    for (final layer in housePlateLayersAt(plates, now ?? Clock.now())) {
      unawaited(precacheImage(AssetImage(layer.asset), context));
    }
  }

  @override
  State<HouseRoomBackdrop> createState() => _HouseRoomBackdropState();
}

class _HouseRoomBackdropState extends State<HouseRoomBackdrop>
    with SingleTickerProviderStateMixin {
  Timer? _refresh;
  late List<HousePlateLayer> _layers;

  /// The previous plate set, while a change cross-fades.
  List<HousePlateLayer>? _from;
  late final AnimationController _swap = AnimationController(
    vsync: this,
    duration: housePlateSwap,
  );

  HousePlates? get _plates => widget.plates ?? widget.room.plates;

  bool get _still =>
      widget.reduceMotion ??
      (RoomTravel.reduceMotion ||
          (MediaQuery.maybeDisableAnimationsOf(context) ?? false));

  List<HousePlateLayer> _read() {
    final plates = _plates;
    return plates == null ? const [] : housePlateLayersAt(plates, Clock.now());
  }

  @override
  void initState() {
    super.initState();
    _layers = _read();
    _swap.addStatusListener((status) {
      if (status == AnimationStatus.completed && _from != null) {
        setState(() => _from = null);
      }
    });
    _refresh = Timer.periodic(houseLightRefresh, (_) => _tick());
  }

  void _tick() {
    if (!mounted) return;
    final next = _read();
    if (!_sameLayers(next, _layers)) setState(() => _layers = next);
  }

  @override
  void didUpdateWidget(covariant HouseRoomBackdrop old) {
    super.didUpdateWidget(old);
    final was = old.plates ?? old.room.plates;
    final now = _plates;
    if (was == now && old.room == widget.room) return;
    final next = _read();
    final previous = _layers;
    _layers = next;
    if (_sameLayers(next, previous)) return;
    if (_still) {
      _from = null;
      return;
    }
    _from = previous;
    _swap.forward(from: 0);
  }

  @override
  void dispose() {
    _refresh?.cancel();
    _swap.dispose();
    super.dispose();
  }

  static bool _sameLayers(List<HousePlateLayer> a, List<HousePlateLayer> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].asset != b[i].asset ||
          (a[i].opacity - b[i].opacity).abs() > 0.004) {
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final above = classStatusAbove(context);
    final still = _still;
    final plateHeight = widget.plateHeight;
    final Widget plate = widget.room == HouseRoom.quests
        ? _doorway(still)
        : _plate(still);
    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.expand,
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: -above,
          bottom: plateHeight == null ? 0 : null,
          height: plateHeight == null ? null : plateHeight + above,
          child: IgnorePointer(
            child: ClipRect(child: RepaintBoundary(child: plate)),
          ),
        ),
        Positioned.fill(
          child: HouseRoomUi(
            room: widget.room,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (widget.veilFrom case final from?)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: LayoutBuilder(
                        builder: (context, box) => Align(
                          alignment: Alignment.bottomCenter,
                          child: SizedBox(
                            height:
                                (box.maxHeight -
                                        (from *
                                                houseContentScale(
                                                  Size(
                                                    box.maxWidth,
                                                    box.maxHeight + above,
                                                  ),
                                                ) -
                                            above))
                                    .clamp(0.0, box.maxHeight),
                            child: const _HouseVeil(),
                          ),
                        ),
                      ),
                    ),
                  ),
                widget.child,
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _doorway(bool still) => DoorwayStage(
    day: widget.day ?? DoorwayDay.quiet(CivilDate.fromDateTime(Clock.now())),
    parallax: widget.parallax,
    reduceMotion: still,
  );

  Widget _plate(bool still) {
    final from = _from;
    final stack = from == null
        ? _PlateLayers(layers: _layers)
        : AnimatedBuilder(
            animation: _swap,
            builder: (context, _) => Stack(
              fit: StackFit.expand,
              children: [
                _PlateLayers(layers: from),
                Opacity(
                  opacity: Curves.easeInOut.transform(_swap.value),
                  child: _PlateLayers(layers: _layers),
                ),
              ],
            ),
          );
    final listenable = widget.parallax;
    if (still || listenable == null) {
      return Transform.scale(scale: housePlateOverscan, child: stack);
    }
    return AnimatedBuilder(
      animation: listenable,
      child: stack,
      builder: (context, child) {
        final tilt = listenable.value;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.translationValues(
            tilt.dx.clamp(-1.0, 1.0) * housePlateParallax,
            tilt.dy.clamp(-1.0, 1.0) * housePlateParallax,
            0,
          )..scaleByDouble(housePlateOverscan, housePlateOverscan, 1, 1),
          child: child,
        );
      },
    );
  }
}

/// The plates of one light state, painted back to front with the painter's
/// cross-fade. The width fits the screen and the top is the room's top.
class _PlateLayers extends StatelessWidget {
  const _PlateLayers({required this.layers});

  final List<HousePlateLayer> layers;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        for (final layer in layers)
          // One chain whatever the opacity, so a blend never remounts a plate.
          Opacity(
            key: ValueKey(layer.asset),
            opacity: layer.opacity,
            child: Image.asset(
              layer.asset,
              fit: BoxFit.fitWidth,
              alignment: Alignment.topCenter,
              filterQuality: FilterQuality.medium,
              gaplessPlayback: true,
              excludeFromSemantics: true,
            ),
          ),
      ],
    );
  }
}

/// The soft dark under a room's live content: clear at the top, deepening to
/// the house's own ink over 170 points and staying there.
class _HouseVeil extends StatelessWidget {
  const _HouseVeil();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final ramp = box.maxHeight <= 0
          ? 1.0
          : (170 / box.maxHeight).clamp(0.0, 1.0);
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: const [
              Color(0x0017100D),
              Color(0xCC17100D),
              Color(0xE617100D),
            ],
            stops: [0, ramp, 1],
          ),
        ),
      );
    },
  );
}
