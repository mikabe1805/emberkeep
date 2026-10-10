// The Quests tab on a class day: the Doorway, large, with today's classes on
// one calm pane of glass floating above the dock.
//
// The Doorway is the room on every class day and for every room style (the
// tickets by the door are the day's state). One owner and one luminous
// control: the class that just ended (or the one he is sitting in) leads the
// glass with "I was there" (or "I'm here"). The HUD keeps the life RPG in two
// quiet lines (level, XP, the six stats), and Today's three is one line with
// a BOARD toggle at the glass's foot that brings the full board back.
// Controls live in the glass; nothing is drawn onto the painting.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;

import '../../academic_calendar/services/class_day_projection.dart';
import '../../academic_calendar/domain/academic_schedule.dart' show CivilDate;
import '../../audio.dart' show InteractionSound, MaterialSound;
import '../../engine.dart';
import '../../main_room_music.dart' show MainRoomMusic;
import '../../tokens.dart';
import '../count_up.dart';
import '../pressable.dart';
import '../quest_card.dart' show QuestCheckRing;
import '../house/house_room.dart' show HouseRoom;
import '../house/house_travel_scope.dart' show HouseRoomUi;
import '../routine_ledger.dart' show LedgerType;
import 'class_day_model.dart';
import 'class_room_stage.dart';
import 'doorway_model.dart';
import 'doorway_motion.dart' show DoorwayBeat;
import 'doorway_stage.dart';

part 'class_evening.dart';

/// Where the room's camera was last laid out, so the celebration can start
/// its move from exactly that framing.
class ClassRoomCamera {
  RoomShot? shot;

  /// The stage's rect in global coordinates. It starts at the top of the
  /// screen: the painting runs up under the status bar.
  Rect? stage;

  /// Where the floor settles into the canvas, in stage coordinates (a
  /// painted plate's celebration fades at the same lines).
  double? fadeStart;
  double? fadeEnd;

  /// How far the status scrim reaches from the stage's top.
  double? scrimHeight;
}

/// How far the screen reaches above [context]'s top that belongs to the
/// status bar: an ancestor SafeArea (the shell's) took it out of the
/// MediaQuery padding. Zero when nothing above was taken out.
double classStatusAbove(BuildContext context) {
  final view = View.maybeOf(context);
  if (view == null) return 0;
  final viewTop = view.padding.top / view.devicePixelRatio;
  return math.max(0.0, viewTop - MediaQuery.paddingOf(context).top);
}

class ClassDayRoom extends StatefulWidget {
  const ClassDayRoom({
    super.key,
    required this.state,
    required this.card,
    required this.doorway,
    required this.now,
    required this.bottomLine,
    required this.onMark,
    required this.onSelect,
    required this.onExploreStat,
    required this.dockHeight,
    required this.camera,
    this.onUndo,
    this.undoIdentity,
    this.onDismiss,
    this.dismissedLabel,
    this.onUndoDismiss,
    this.reduceMotion = false,
    this.lightDirection,
    this.parallax,
    this.quiet = false,
    this.evening,
    this.onStepBack,
    this.onBeat,
  });

  final GameState state;
  final ClassCard card;

  /// The Doorway's reading of the day: its tickets, hooks, bowl and shelf.
  final DoorwayDay doorway;
  final DateTime now;

  /// "Couldn't make it" on a row that can be set aside. Null: not offered.
  final ValueChanged<ClassRow>? onDismiss;

  /// The class just folded away (its short name) while its "Undo" waits;
  /// null once the few seconds are up. [onUndoDismiss] brings it back.
  final String? dismissedLabel;
  final VoidCallback? onUndoDismiss;

  /// While the real level-up is up, the room's words step back so nothing
  /// reads through behind "YOU DID IT.".
  final bool quiet;

  /// Today's three, one line, with the BOARD toggle.
  final Widget bottomLine;

  /// Marks these rows (one, or every waiting class for the shortcut).
  final void Function(List<ClassRow> rows) onMark;

  /// Brings a quiet row forward so its own "I was there" leads.
  final ValueChanged<ClassRow> onSelect;
  final ValueChanged<Stat> onExploreStat;

  /// The shell's dock (88 pt plus the home indicator) sits over the page.
  final double dockHeight;

  /// Where the room's stage sits on screen, for the celebration's backdrop.
  final ClassRoomCamera camera;

  /// The latest kept class can be swiped left past 42% to undo, exactly as
  /// the Quest board's latest completion.
  final VoidCallback? onUndo;
  final String? undoIdentity;
  final bool reduceMotion;
  final ValueListenable<Offset>? lightDirection;

  /// The shell's tilt (the accelerometer), which moves the Doorway's depth.
  final ValueListenable<Offset>? parallax;

  /// The evening (the last class is over, and every class is kept or the
  /// wind-down has begun): the glass holds the day folded to one line, the
  /// music, a page in the journal and closing the day, over the Doorway's
  /// light at that hour. Null during the class day.
  final ClassEvening? evening;

  /// The folded evening with the room's music on: the glass and the HUD step
  /// back, and the page is told so the shell's dock can step back too.
  final ValueChanged<bool>? onStepBack;

  /// The Doorway's moves the page waits on: a ticket hung, the day's tickets
  /// landed in the bowl, the week's bundle on the shelf.
  final ValueChanged<DoorwayBeat>? onBeat;

  @override
  State<ClassDayRoom> createState() => _ClassDayRoomState();
}

class _ClassDayRoomState extends State<ClassDayRoom>
    with SingleTickerProviderStateMixin {
  /// 0..1: the music's step back (the glass dims).
  late final AnimationController _near = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
    value: _stepBack ? 1 : 0,
  );

  ValueListenable<bool>? _musicOn;
  bool? _toldStepBack;

  /// The day folded to one line with the room's music on.
  bool get _stepBack =>
      widget.evening != null &&
      widget.card.foremost == null &&
      (widget.evening?.music?.on.value ?? false);

  @override
  void initState() {
    super.initState();
    _bindMusic();
    _tellStepBack();
  }

  @override
  void didUpdateWidget(ClassDayRoom oldWidget) {
    super.didUpdateWidget(oldWidget);
    _bindMusic();
    _syncNear();
  }

  void _bindMusic() {
    final on = widget.evening?.music?.on;
    if (identical(on, _musicOn)) return;
    _musicOn?.removeListener(_onMusic);
    _musicOn = on;
    on?.addListener(_onMusic);
  }

  void _onMusic() {
    if (!mounted) return;
    setState(_syncNear);
  }

  void _syncNear() {
    final want = _stepBack ? 1.0 : 0.0;
    _tellStepBack();
    if (_near.value == want && !_near.isAnimating) return;
    if (_near.isAnimating && _nearTarget == want) return;
    _nearTarget = want;
    _near.animateTo(
      want,
      duration: Duration(milliseconds: widget.reduceMotion ? 360 : 1800),
      curve: Curves.easeInOutSine,
    );
  }

  double? _nearTarget;

  void _tellStepBack() {
    final step = _stepBack;
    if (_toldStepBack == step) return;
    _toldStepBack = step;
    final tell = widget.onStepBack;
    if (tell == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) tell(step);
    });
  }

  /// A ticket was dragged up past the mark line in the Doorway: the same
  /// mark as pressing "I was there" on its card.
  void _markTicket(DoorwayTicket ticket) {
    for (final row in widget.card.rows) {
      if (row.entry.facts.identity == ticket.facts.identity) {
        if (row.markable) widget.onMark([row]);
        return;
      }
    }
  }

  @override
  void dispose() {
    _musicOn?.removeListener(_onMusic);
    final tell = widget.onStepBack;
    if (_toldStepBack == true && tell != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => tell(false));
    }
    _near.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final widget = this.widget;
    final card = widget.card;
    final evening = widget.evening;
    // The painting runs up under the status bar (the shell's SafeArea keeps
    // the page below it), so the room is opened into, never placed under a
    // band. The HUD stays where it was, on the room's own soft dark.
    final above = classStatusAbove(context);
    final topPad = MediaQuery.paddingOf(context).top;
    // The soft dark under the status bar and the HUD: 150 pt from the top
    // of the screen on his phone, as in the concept.
    final scrimHeight = math.max(
      91.0,
      above + topPad + classStatusScrimHeight - 59,
    );
    final Widget body = evening == null
        ? SingleChildScrollView(
            // A day with many classes, or large text, scrolls inside the glass
            // rather than running past it. Short days are exactly as tall as
            // their rows (the viewport hugs them) and nothing is clipped.
            key: const Key('class-day-scroll'),
            primary: false,
            clipBehavior: Clip.none,
            physics: const ClampingScrollPhysics(),
            child: ClassCardBody(
              state: widget.state,
              card: card,
              now: widget.now,
              onMark: widget.onMark,
              onSelect: widget.onSelect,
              onUndo: widget.onUndo,
              undoIdentity: widget.undoIdentity,
              onDismiss: widget.onDismiss,
              dismissedLabel: widget.dismissedLabel,
              onUndoDismiss: widget.onUndoDismiss,
              reduceMotion: widget.reduceMotion,
              lightDirection: widget.lightDirection,
            ),
          )
        : SingleChildScrollView(
            key: const Key('class-evening-scroll'),
            physics: const ClampingScrollPhysics(),
            child: ClassEveningBody(
              state: widget.state,
              card: card,
              now: widget.now,
              evening: evening,
              onMark: widget.onMark,
              onSelect: widget.onSelect,
              onUndo: widget.onUndo,
              undoIdentity: widget.undoIdentity,
              onDismiss: widget.onDismiss,
              dismissedLabel: widget.dismissedLabel,
              onUndoDismiss: widget.onUndoDismiss,
              reduceMotion: widget.reduceMotion,
              lightDirection: widget.lightDirection,
            ),
          );
    return ColoredBox(
      color: Palette.parchment,
      child: Padding(
        padding: EdgeInsets.only(bottom: widget.dockHeight),
        child: CustomMultiChildLayout(
          delegate: _ClassDayDelegate(above: above, topPad: topPad),
          children: [
            LayoutId(
              id: _Slot.stage,
              child: LayoutBuilder(
                builder: (context, box) {
                  widget.camera.scrimHeight = scrimHeight;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    final ro = context.findRenderObject();
                    if (ro is RenderBox && ro.attached && ro.hasSize) {
                      widget.camera.stage =
                          ro.localToGlobal(Offset.zero) & ro.size;
                    }
                  });
                  return DoorwayStage(
                    key: const Key('class-day-stage'),
                    day: widget.doorway,
                    parallax: widget.parallax,
                    reduceMotion: widget.reduceMotion,
                    scrimHeight: scrimHeight,
                    onBeat: widget.onBeat,
                    onMarkTicket: _markTicket,
                  );
                },
              ),
            ),
            LayoutId(
              id: _Slot.glass,
              child: _Quiet(
                quiet: widget.quiet,
                child: AnimatedBuilder(
                  animation: _near,
                  builder: (context, child) => Opacity(
                    // With the music on the glass steps back; its doors
                    // stay where they are and still answer a touch.
                    opacity: 1 - 0.55 * _near.value,
                    child: child,
                  ),
                  child: ClassGlass(
                    key: const Key('class-day-glass'),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Flexible(child: body),
                        // Today's three and BOARD sit at the foot of the
                        // glass, under a fine rule, as in the concept.
                        const _GlassRule(inset: 0),
                        _StepBack(
                          near: _near,
                          depth: 0.55,
                          child: widget.bottomLine,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            LayoutId(
              id: _Slot.hud,
              child: _Quiet(
                quiet: widget.quiet,
                child: _StepBack(
                  near: _near,
                  depth: 0.4,
                  child: ClassDayHud(
                    state: widget.state,
                    date: card.day.date,
                    onExploreStat: widget.onExploreStat,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _Slot { stage, glass, hud }

/// Steps [child] back by [depth] as the music's [near] rises.
class _StepBack extends StatelessWidget {
  const _StepBack({
    required this.near,
    required this.depth,
    required this.child,
  });

  final Animation<double> near;
  final double depth;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: near,
    builder: (context, child) =>
        Opacity(opacity: 1 - depth * near.value, child: child),
    child: child,
  );
}

class _Quiet extends StatelessWidget {
  const _Quiet({required this.quiet, required this.child});

  final bool quiet;
  final Widget child;

  @override
  // The room's live glass and HUD wait for the dock's light on arrival and
  // let go first on departure (the painted Doorway behind stays).
  Widget build(BuildContext context) => HouseRoomUi(
    room: HouseRoom.quests,
    child: AnimatedOpacity(
      opacity: quiet ? 0 : 1,
      duration: const Duration(milliseconds: 240),
      child: IgnorePointer(ignoring: quiet, child: child),
    ),
  );
}

/// The Doorway fills the page behind everything; the glass floats above the
/// dock with a small gap, and the HUD sits over the room's top edge.
class _ClassDayDelegate extends MultiChildLayoutDelegate {
  _ClassDayDelegate({required this.above, required this.topPad});

  /// The status bar above the page: the stage reaches up through it.
  final double above;

  /// The page's own top padding (zero under the shell's SafeArea).
  final double topPad;

  /// The gap between the glass and the dock.
  static const belowGlass = 14.0;

  /// The HUD's top, under the page's top edge.
  static const hudTop = 8.0;

  @override
  void performLayout(Size size) {
    final hud = layoutChild(
      _Slot.hud,
      BoxConstraints.tightFor(width: size.width - 40),
    );
    positionChild(_Slot.hud, Offset(20, topPad + hudTop));
    final glass = layoutChild(
      _Slot.glass,
      BoxConstraints(
        minWidth: size.width - 32,
        maxWidth: size.width - 32,
        // The room keeps at least a band above the glass, even at large text.
        maxHeight: math.max(
          140,
          size.height - belowGlass - (topPad + hudTop + hud.height + 56),
        ),
      ),
    );
    positionChild(
      _Slot.glass,
      Offset(16, size.height - belowGlass - glass.height),
    );
    // From the top of the screen: nothing clips the page above its own top,
    // so the painting shows under the status bar.
    layoutChild(
      _Slot.stage,
      BoxConstraints.tightFor(width: size.width, height: size.height + above),
    );
    positionChild(_Slot.stage, Offset(0, -above));
  }

  @override
  bool shouldRelayout(_ClassDayDelegate oldDelegate) =>
      oldDelegate.above != above || oldDelegate.topPad != topPad;
}

// ── HUD ──────────────────────────────────────────────────────────────────

const _hudShadow = [Shadow(color: Color(0xCC0A0604), blurRadius: 8)];

/// The level line and the six stats, over the room's top edge: the life RPG
/// stays in the first frame, quietly.
class ClassDayHud extends StatelessWidget {
  const ClassDayHud({
    super.key,
    required this.state,
    required this.date,
    required this.onExploreStat,
  });

  final GameState state;
  final CivilDate date;
  final ValueChanged<Stat> onExploreStat;

  @override
  Widget build(BuildContext context) {
    final need = state.xpNeeded(state.level + 1);
    return Column(
      key: const Key('class-day-hud'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          label: 'Level ${state.level}, ${state.xp} of $need XP',
          excludeSemantics: true,
          child: Row(
            children: [
              Text(
                'LV',
                style: Type.label.copyWith(
                  fontSize: Type.minLabel,
                  letterSpacing: 1.2,
                  color: Palette.textMid,
                  shadows: _hudShadow,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${state.level}',
                style: Type.numerals.copyWith(
                  fontSize: 20,
                  height: 1,
                  color: Palette.textHi,
                  shadows: _hudShadow,
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 58,
                height: 6,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: (state.xp / need).clamp(0.0, 1.0)),
                  // Out of view (or Reduce Motion) the rail lands at once,
                  // so it never refills from an old value when it shows.
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : Motion.barFill,
                  curve: Motion.barCurve,
                  builder: (context, value, _) =>
                      CustomPaint(painter: _MiniRail(value)),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: RollingNumber(
                    math.min(state.xp, need),
                    suffix: ' / $need XP',
                    maxLines: 1,
                    style: Type.label.copyWith(
                      fontSize: Type.minLabel,
                      letterSpacing: 0.3,
                      color: Palette.xpLight.withValues(alpha: 0.9),
                      shadows: _hudShadow,
                    ),
                  ),
                ),
              ),
              // Room enough that the XP and the date never read as one run,
              // even at large text (the XP shrinks to fit first).
              const SizedBox(width: 16),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    classDayStamp(date),
                    maxLines: 1,
                    style: Type.label.copyWith(
                      fontSize: Type.minLabel,
                      letterSpacing: 1.4,
                      color: Palette.textMid,
                      shadows: _hudShadow,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            for (final stat in Stat.values)
              Expanded(
                child: Semantics(
                  button: true,
                  label: '${stat.label} ${state.stats[stat] ?? 0}',
                  excludeSemantics: true,
                  child: GestureDetector(
                    key: Key('class-day-stat-${stat.name}'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onExploreStat(stat),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 36),
                      child: Row(
                        mainAxisAlignment: stat == Stat.values.first
                            ? MainAxisAlignment.start
                            : stat == Stat.values.last
                            ? MainAxisAlignment.end
                            : MainAxisAlignment.center,
                        children: [
                          Icon(
                            stat.icon,
                            size: 13,
                            color: stat.color.withValues(alpha: 0.85),
                            shadows: _hudShadow,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              '${state.stats[stat] ?? 0}',
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.fade,
                              style: Type.numerals.copyWith(
                                fontSize: 14,
                                height: 1,
                                color: Palette.textMid,
                                shadows: _hudShadow,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _MiniRail extends CustomPainter {
  _MiniRail(this.value);

  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(3),
    );
    canvas.drawRRect(r, Paint()..color = const Color(0xA0120C08));
    canvas.drawRRect(
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7
        ..color = Palette.railRim,
    );
    final w = size.width * value.clamp(0.0, 1.0);
    if (w <= 0) return;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, w, size.height),
        const Radius.circular(3),
      ),
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFB98345), Color(0xFFE0A865)],
        ).createShader(Rect.fromLTWH(0, 0, w + 1, size.height)),
    );
  }

  @override
  bool shouldRepaint(_MiniRail old) => old.value != value;
}

// ── The glass ────────────────────────────────────────────────────────────

/// Warm walnut glass floating over the Doorway: the room blurs through it
/// under a dark brown tint, its corners are cut like the dock's, a fine brass
/// edge runs round it and its top catches a little light. Never light
/// parchment, never a flat card.
class ClassGlass extends StatelessWidget {
  const ClassGlass({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(22, 17, 22, 6),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: const _FacetClipper(top: 8, bottom: 12),
      child: Stack(
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: const SizedBox.expand(),
            ),
          ),
          const Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment(-0.25, -1),
                    end: Alignment(0.15, 1),
                    colors: [Color(0xE0402C1E), Color(0xEE1E150F)],
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: FractionallySizedBox(
                alignment: Alignment.topCenter,
                heightFactor: 0.46,
                widthFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xFFFFE2AA).withValues(alpha: 0.075),
                        const Color(0x00FFE2AA),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const Positioned.fill(
            child: IgnorePointer(child: CustomPaint(painter: _GlassEdge())),
          ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

class _FacetClipper extends CustomClipper<Path> {
  const _FacetClipper({required this.top, required this.bottom});

  final double top;
  final double bottom;

  @override
  Path getClip(Size size) => _facet(size, top, bottom);

  @override
  bool shouldReclip(_FacetClipper old) =>
      old.top != top || old.bottom != bottom;
}

Path _facet(Size size, double top, double bottom) => Path()
  ..moveTo(top, 0)
  ..lineTo(size.width - top, 0)
  ..lineTo(size.width, top)
  ..lineTo(size.width, size.height - bottom)
  ..lineTo(size.width - bottom, size.height)
  ..lineTo(bottom, size.height)
  ..lineTo(0, size.height - bottom)
  ..lineTo(0, top)
  ..close();

/// The glass's fine brass edge: warm at the top left, settling to amber.
class _GlassEdge extends CustomPainter {
  const _GlassEdge();

  @override
  void paint(Canvas canvas, Size size) {
    final box = Offset.zero & size;
    canvas.drawPath(
      _facet(size, 7.5, 11.5).shift(const Offset(0.5, 0.5)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFECC480).withValues(alpha: 0.5),
            const Color(0xFFAA7A40).withValues(alpha: 0.22),
            const Color(0xFFECC480).withValues(alpha: 0.28),
          ],
          stops: const [0, 0.4, 1],
        ).createShader(box),
    );
  }

  @override
  bool shouldRepaint(_GlassEdge old) => false;
}

Text _glassLabel(String text, {Color? color, TextAlign? align}) => Text(
  text,
  textAlign: align,
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
  style: Type.label.copyWith(
    fontSize: Type.minLabel,
    letterSpacing: 1.5,
    color: color ?? Palette.brassLit.withValues(alpha: 0.72),
  ),
);

TextStyle _serif(
  double size, {
  Color? color,
  FontWeight? weight,
  double? height,
  FontStyle? style,
}) => LedgerType.body.copyWith(
  fontSize: size,
  fontWeight: weight ?? FontWeight.w500,
  height: height ?? 1.12,
  fontStyle: style,
  color: color ?? Palette.textMid,
);

// ── The card's body ──────────────────────────────────────────────────────

/// The day on the glass: the class that is ready (or in session, or next)
/// leads with its one control and a quiet "Couldn't make it" under it; the
/// next two classes still to come follow as quiet rows; the rest wait behind
/// "N more later today", which opens the whole list. A class he went to hangs
/// on its hook in the Doorway and folds off the card; one he set aside folds
/// away. Tapping a class still to come shows its own quiet "Couldn't make it".
class ClassCardBody extends StatefulWidget {
  const ClassCardBody({
    super.key,
    required this.state,
    required this.card,
    required this.now,
    required this.onMark,
    required this.onSelect,
    this.onUndo,
    this.undoIdentity,
    this.onDismiss,
    this.dismissedLabel,
    this.onUndoDismiss,
    this.reduceMotion = false,
    this.lightDirection,
    this.compact = false,
  });

  final GameState state;
  final ClassCard card;
  final DateTime now;
  final void Function(List<ClassRow> rows) onMark;
  final ValueChanged<ClassRow> onSelect;
  final VoidCallback? onUndo;
  final String? undoIdentity;

  /// "Couldn't make it" (see [ClassDayRoom.onDismiss]).
  final ValueChanged<ClassRow>? onDismiss;
  final String? dismissedLabel;
  final VoidCallback? onUndoDismiss;
  final bool reduceMotion;
  final ValueListenable<Offset>? lightDirection;

  /// The evening's card while a class can still be marked: the class that
  /// leads with its one control and the shortcut, the newest kept row while
  /// its undo is armed, and the other classes still open as one line of
  /// start times. No list of the day's other rows: the room keeps the frame.
  final bool compact;

  /// How many classes still to come show before "N more later today".
  static const upcomingShown = 2;

  @override
  State<ClassCardBody> createState() => _ClassCardBodyState();
}

class _ClassCardBodyState extends State<ClassCardBody> {
  /// The full list of classes still to come is open.
  bool _expanded = false;

  /// The class still to come whose own "Couldn't make it" is showing.
  String? _revealed;

  @override
  void didUpdateWidget(ClassCardBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    final revealed = _revealed;
    if (revealed != null &&
        !widget.card.rows.any((row) => row.identity == revealed)) {
      _revealed = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final card = widget.card;
    final day = card.day;
    final dayName = weekdayOf(day.date).toUpperCase();
    final count = day.classes.length;
    final kept = card.keptCount;
    final foremost = card.foremost;
    final String left;
    final String? right;
    if (count == 0) {
      // Every class was set aside: the day holds nothing to count, and the
      // header says no number.
      left = dayName;
      right = null;
    } else if (card.isRecord && card.allKept) {
      left =
          '$dayName · ${switch (count) {
            1 => 'ATTENDED',
            2 => 'BOTH ATTENDED',
            _ => 'ALL ${classCountWord(count).toUpperCase()} ATTENDED',
          }}';
      right = '+${state.classXpForDay(day.dayKey)} XP';
    } else if (kept == 0) {
      left = '$dayName · $count ${count == 1 ? 'CLASS' : 'CLASSES'}';
      right = null;
    } else {
      // Once anything is kept the day's total steps out: a kept count beside
      // a total would read as N of M.
      left = dayName;
      right = '$kept ATTENDED';
    }
    final header = Row(
      children: [
        Expanded(child: _glassLabel(left)),
        if (right != null)
          Padding(
            padding: const EdgeInsets.only(left: 10),
            child: card.isRecord && card.allKept
                ? Text(
                    right,
                    style: Type.numerals.copyWith(
                      fontSize: 16,
                      color: Palette.xpLight,
                    ),
                  )
                : _glassLabel(
                    right,
                    color: Palette.xpLight.withValues(alpha: 0.8),
                  ),
          ),
      ],
    );
    if (widget.compact) return _compact(header);

    // What the glass shows, in order. A kept class has gone to its hook (it
    // shows only while its undo is armed); one set aside is not here at all.
    final others = <ClassRow>[
      for (final row in card.rows)
        if (row.identity != foremost?.identity &&
            (row.markable ||
                (row.isKept && row.identity == widget.undoIdentity)))
          row,
    ];
    final coming = <ClassRow>[
      for (final row in card.rows)
        if (row.identity != foremost?.identity &&
            (row.state == ClassRowState.upcoming ||
                row.state == ClassRowState.startsSoon))
          row,
    ];
    final shown = _expanded
        ? coming
        : coming.take(ClassCardBody.upcomingShown).toList();
    final more = coming.length - shown.length;

    final items = <_FoldItem>[];
    if (foremost != null) {
      items.add(
        _FoldItem(
          'foremost-${foremost.identity}',
          _ForemostRow(
            key: ValueKey('class-foremost-${foremost.identity}'),
            row: foremost,
            card: card,
            now: widget.now,
            onMark: widget.onMark,
            onDismiss: widget.onDismiss,
            onUndo: foremost.isKept && foremost.identity == widget.undoIdentity
                ? widget.onUndo
                : null,
            reduceMotion: widget.reduceMotion,
            lightDirection: widget.lightDirection,
          ),
        ),
      );
    }
    var first = true;
    Widget lead(Widget row) {
      final spacing = foremost != null && first ? 10.0 : 2.0;
      final showRule = foremost != null || !first;
      first = false;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: spacing),
          if (showRule) ...[const _GlassRule(), const SizedBox(height: 2)],
          row,
        ],
      );
    }

    for (final row in others) {
      items.add(
        _FoldItem(
          'row-${row.identity}',
          lead(
            _QuietRow(
              key: ValueKey('class-row-${row.identity}'),
              row: row,
              now: widget.now,
              onSelect: row.markable ? () => widget.onSelect(row) : null,
              onUndo: row.isKept && row.identity == widget.undoIdentity
                  ? widget.onUndo
                  : null,
              onDismiss: widget.onDismiss == null || !row.canSetAside
                  ? null
                  : () => widget.onDismiss!(row),
            ),
          ),
        ),
      );
    }
    for (final row in shown) {
      final revealed = _revealed == row.identity;
      items.add(
        _FoldItem(
          'row-${row.identity}',
          lead(
            _QuietRow(
              key: ValueKey('class-row-${row.identity}'),
              row: row,
              now: widget.now,
              revealed: revealed,
              onReveal: widget.onDismiss == null || !row.canSetAside
                  ? null
                  : () => setState(
                      () => _revealed = revealed ? null : row.identity,
                    ),
              onDismiss: widget.onDismiss == null || !row.canSetAside
                  ? null
                  : () => widget.onDismiss!(row),
            ),
          ),
        ),
      );
    }
    if (coming.length > ClassCardBody.upcomingShown) {
      items.add(
        _FoldItem(
          'more',
          _MoreLine(
            more: more,
            expanded: _expanded,
            onTap: () => setState(() => _expanded = !_expanded),
          ),
        ),
      );
    }
    if (widget.dismissedLabel != null) {
      items.add(
        _FoldItem(
          'dismissed',
          ClassDismissedLine(
            label: widget.dismissedLabel!,
            onUndo: widget.onUndoDismiss,
          ),
        ),
      );
    }
    if (card.isRecord) {
      final bonus = state.dayRecordFor(day.dayKey)?.fullDayBonusXp ?? 0;
      if (bonus > 0) {
        items.add(
          _FoldItem(
            'bonus',
            Padding(
              key: const Key('class-day-record-bonus'),
              padding: const EdgeInsets.fromLTRB(56, 2, 0, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'All of ${weekdayOf(day.date)}’s classes',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _serif(
                        16,
                        color: Palette.textLo,
                        style: FontStyle.italic,
                      ),
                    ),
                  ),
                  Text(
                    '+$bonus XP',
                    style: Type.numerals.copyWith(
                      fontSize: 15,
                      color: Palette.xp.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      if (day.nextClassAfter case final next?) {
        items.add(
          _FoldItem(
            'next',
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: 1,
                    color: Palette.brass.withValues(alpha: 0.22),
                  ),
                  const SizedBox(height: 9),
                  _NextLine(next: next),
                ],
              ),
            ),
          ),
        );
      }
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        SizedBox(height: foremost == null ? 8 : 12),
        _FoldColumn(items: items, reduceMotion: widget.reduceMotion),
      ],
    );
  }

  Widget _compact(Widget header) {
    final card = widget.card;
    final foremost = card.foremost;
    final open = [
      for (final row in card.rows)
        if (row.markable && row.identity != foremost?.identity) row,
    ];
    ClassRow? undoRow;
    for (final row in card.rows) {
      if (row.isKept &&
          row.identity == widget.undoIdentity &&
          row.identity != foremost?.identity) {
        undoRow = row;
      }
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        const SizedBox(height: 10),
        if (foremost != null)
          _ForemostRow(
            key: ValueKey('class-foremost-${foremost.identity}'),
            row: foremost,
            card: card,
            now: widget.now,
            onMark: widget.onMark,
            onDismiss: widget.onDismiss,
            reduceMotion: widget.reduceMotion,
            lightDirection: widget.lightDirection,
            besideLamp: true,
          ),
        if (widget.dismissedLabel != null)
          ClassDismissedLine(
            label: widget.dismissedLabel!,
            onUndo: widget.onUndoDismiss,
          ),
        if (undoRow != null) ...[
          const SizedBox(height: 8),
          const _GlassRule(),
          _QuietRow(
            key: ValueKey('class-row-${undoRow.identity}'),
            row: undoRow,
            now: widget.now,
            onUndo: widget.onUndo,
          ),
        ],
        if (open.isNotEmpty)
          _OpenTimesLine(rows: open, onSelect: widget.onSelect),
      ],
    );
  }
}

/// One thing on the card that can fold in and out.
class _FoldItem {
  const _FoldItem(this.key, this.child);

  final String key;
  final Widget child;
}

/// A column whose members fold open when they arrive and fold shut when they
/// leave (a class kept, a class set aside, a class brought back), so the card
/// closes its gaps instead of jumping. Under Reduce Motion they simply come
/// and go.
class _FoldColumn extends StatefulWidget {
  const _FoldColumn({required this.items, required this.reduceMotion});

  final List<_FoldItem> items;
  final bool reduceMotion;

  @override
  State<_FoldColumn> createState() => _FoldColumnState();
}

class _FoldEntry {
  _FoldEntry(this.key, this.child, {this.appear = false});

  final String key;
  Widget child;
  bool visible = true;

  /// Folds open from nothing (arrived after the first build).
  final bool appear;
}

class _FoldColumnState extends State<_FoldColumn> {
  late List<_FoldEntry> _entries = [
    for (final item in widget.items) _FoldEntry(item.key, item.child),
  ];

  @override
  void didUpdateWidget(_FoldColumn oldWidget) {
    super.didUpdateWidget(oldWidget);
    final byKey = {for (final entry in _entries) entry.key: entry};
    final wanted = {for (final item in widget.items) item.key};
    final next = <_FoldEntry>[];
    for (final item in widget.items) {
      final entry =
          byKey[item.key] ?? _FoldEntry(item.key, item.child, appear: true);
      entry
        ..child = item.child
        ..visible = true;
      next.add(entry);
    }
    // An entry that is leaving stays where it was, after the nearest
    // survivor that came before it, while it folds shut.
    for (var i = 0; i < _entries.length; i++) {
      final entry = _entries[i];
      if (wanted.contains(entry.key)) continue;
      entry.visible = false;
      var at = 0;
      for (var j = i - 1; j >= 0; j--) {
        final index = next.indexOf(_entries[j]);
        if (index >= 0) {
          at = index + 1;
          break;
        }
      }
      next.insert(at, entry);
    }
    _entries = next;
  }

  void _gone(_FoldEntry entry) {
    if (!mounted || entry.visible) return;
    setState(() => _entries.remove(entry));
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final entry in _entries)
        _Fold(
          key: ValueKey('fold-${entry.key}'),
          visible: entry.visible,
          appear: entry.appear,
          animate: !widget.reduceMotion,
          onGone: () => _gone(entry),
          child: entry.child,
        ),
    ],
  );
}

class _Fold extends StatefulWidget {
  const _Fold({
    super.key,
    required this.visible,
    required this.appear,
    required this.animate,
    required this.onGone,
    required this.child,
  });

  final bool visible;
  final bool appear;
  final bool animate;
  final VoidCallback onGone;
  final Widget child;

  @override
  State<_Fold> createState() => _FoldState();
}

class _FoldState extends State<_Fold> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
    value: widget.appear && widget.animate ? 0 : (widget.visible ? 1 : 0),
  )..addStatusListener(_status);

  @override
  void initState() {
    super.initState();
    if (widget.appear && widget.animate && widget.visible) _c.forward();
  }

  void _status(AnimationStatus status) {
    if (status != AnimationStatus.dismissed || widget.visible) return;
    // Never inside a build: the column drops the entry after this frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onGone();
    });
  }

  @override
  void didUpdateWidget(_Fold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible == oldWidget.visible) return;
    if (!widget.animate) {
      _c.value = widget.visible ? 1 : 0;
    } else if (widget.visible) {
      _c.forward();
    } else {
      _c.reverse();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.animate && !widget.visible) return const SizedBox.shrink();
    final curve = CurvedAnimation(parent: _c, curve: Curves.easeInOut);
    return SizeTransition(
      sizeFactor: curve,
      alignment: Alignment.topCenter,
      child: FadeTransition(opacity: curve, child: widget.child),
    );
  }
}

/// "2 more later today": a quiet line that opens the whole list (and closes
/// it again). Counts what is still to come, never what was not marked.
class _MoreLine extends StatelessWidget {
  const _MoreLine({
    required this.more,
    required this.expanded,
    required this.onTap,
  });

  final int more;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = expanded ? 'Show fewer' : '$more more later today';
    return Pressable(
      key: const Key('class-more-later'),
      pressDepth: 1,
      soundEnabled: false,
      edgeColor: Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      semanticLabel: expanded
          ? 'Show fewer of today’s classes'
          : '$more more ${more == 1 ? 'class' : 'classes'} later today',
      semanticHint: expanded ? null : 'Show them all',
      onTapUp: (_) => onTap(),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Row(
          children: [
            const SizedBox(width: 56),
            Expanded(
              child: ExcludeSemantics(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _serif(
                    16,
                    color: Palette.textMid.withValues(alpha: 0.78),
                    style: FontStyle.italic,
                  ),
                ),
              ),
            ),
            Icon(
              expanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              size: 20,
              color: Palette.brassLit.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }
}

/// The evening's other classes still open, as one quiet line of start
/// times: "Earlier today  · 8:30  · 2:00". A time brings its class forward
/// to be marked. It names classes, never how many were not marked.
class _OpenTimesLine extends StatelessWidget {
  const _OpenTimesLine({required this.rows, required this.onSelect});

  final List<ClassRow> rows;
  final ValueChanged<ClassRow> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      key: const Key('class-open-times'),
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, right: 6),
          child: Text(
            'Earlier today',
            style: _serif(16, color: Palette.textLo, style: FontStyle.italic),
          ),
        ),
        for (final row in rows)
          Pressable(
            key: ValueKey('class-open-${row.identity}'),
            pressDepth: 1,
            soundEnabled: false,
            edgeColor: Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            semanticLabel:
                '${classBriefTitle(row.entry.title)}, '
                '${classClock(row.entry.localStartMinute)}',
            semanticHint: 'Bring forward to mark it',
            onTapUp: (_) => onSelect(row),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _QuietDot(),
                    const SizedBox(width: 7),
                    Text(
                      classClockShort(row.entry.localStartMinute),
                      style: _serif(17, color: Palette.textMid),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _GlassRule extends StatelessWidget {
  const _GlassRule({this.inset = 57});

  /// How far the rule is set in from the glass's left (a row's text edge).
  final double inset;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(left: inset),
    child: Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Palette.brass.withValues(alpha: 0.32),
            Palette.brass.withValues(alpha: 0.06),
          ],
        ),
      ),
    ),
  );
}

/// The row that owns the card: ready to mark (with the one luminous
/// control), in session, or next.
class _ForemostRow extends StatelessWidget {
  const _ForemostRow({
    super.key,
    required this.row,
    required this.card,
    required this.now,
    required this.onMark,
    required this.reduceMotion,
    this.onDismiss,
    this.onUndo,
    this.lightDirection,
    this.besideLamp = false,
  });

  /// The quiet "Couldn't make it" sits beside the lamp instead of under it.
  final bool besideLamp;

  /// Swiping a class just kept (held in place while the Doorway hangs its
  /// ticket) undoes it.
  final VoidCallback? onUndo;

  final ClassRow row;
  final ClassCard card;
  final DateTime now;
  final void Function(List<ClassRow> rows) onMark;
  final ValueChanged<ClassRow>? onDismiss;
  final bool reduceMotion;
  final ValueListenable<Offset>? lightDirection;

  @override
  Widget build(BuildContext context) {
    final held = card.held && row.isKept;
    return _AttendingGate(
      held: held,
      reduceMotion: reduceMotion,
      builder: (context, closed) => _body(context, held, closed),
    );
  }

  Widget _body(BuildContext context, bool held, bool closed) {
    final entry = row.entry;
    final place = classPlace(entry);
    final markable = row.markable;
    final inSession =
        row.state == ClassRowState.inSession ||
        (held && entry.momentAt(now) == ClassMoment.inSession);
    final String meta;
    String? countdown;
    switch (row.state) {
      case ClassRowState.inSession:
        meta = '$place · until ${classClockShort(entry.localEndMinute)}';
      case ClassRowState.ready:
      case ClassRowState.settled:
        meta = '$place · ended ${classClockShort(entry.localEndMinute)}';
      case ClassRowState.startsSoon:
        final minutes = math.max(
          1,
          (entry.startsAt.difference(now.toUtc()).inSeconds / 60).ceil(),
        );
        countdown = 'STARTS IN $minutes MIN';
        meta = '${classClock(entry.localStartMinute)} · $place';
      case ClassRowState.upcoming:
        meta = '${classClock(entry.localStartMinute)} · $place';
      case ClassRowState.kept:
        meta = inSession
            ? '$place · until ${classClockShort(entry.localEndMinute)}'
            : '$place · ended ${classClockShort(entry.localEndMinute)}';
    }
    final showButton = markable || held;
    final setAside = onDismiss != null && row.canSetAside && !held
        ? () => onDismiss!(row)
        : null;
    final ring = SizedBox.square(
      dimension: 44,
      child: Center(
        child: markable || held
            ? QuestCheckRing(
                stat: classStatFor(row.entry),
                done: closed,
                showReadyCheck: !closed,
                size: 42,
                reduceMotion: reduceMotion,
                lightDirection: lightDirection,
              )
            : const _FutureMark(size: 30),
      ),
    );
    final lamp = ClassThereButton(
      label: inSession ? "I'M HERE" : 'I WAS THERE',
      attendedLabel: held ? 'ATTENDED · +${row.kept?.xp ?? 25} XP' : null,
      enabled: markable,
      kept: closed,
      acknowledged: held && !closed,
      light: lightDirection,
      reduceMotion: reduceMotion,
      onTap: () => onMark([row]),
      onSetAside: setAside,
      semanticLabel: held
          ? 'Attended: ${classShortTitle(entry.title)}'
          : inSession
          ? "I'm here: ${classShortTitle(entry.title)}"
          : 'I was there: ${classShortTitle(entry.title)}',
    );
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            KeyedSubtree(key: const Key('class-foremost-ring'), child: ring),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    classBriefTitle(entry.title),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: LedgerType.display.copyWith(
                      fontSize: 25,
                      height: 1.06,
                      fontWeight: FontWeight.w500,
                      color: Palette.textHi,
                    ),
                  ),
                  if (countdown != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      countdown,
                      key: const Key('class-countdown'),
                      style: Type.label.copyWith(
                        fontSize: Type.minLabel,
                        letterSpacing: 1.4,
                        color: Palette.xpLight,
                      ),
                    ),
                  ],
                  const SizedBox(height: 5),
                  Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Type.label.copyWith(
                      fontSize: Type.minLabel,
                      letterSpacing: 0.6,
                      color: Palette.textLo,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (showButton) ...[
          const SizedBox(height: 10),
          // The one lamp, and under it the quiet word, small and centered:
          // the lamp stays the largest thing on the card. The evening's card,
          // which is short of room, keeps the word beside the lamp.
          if (besideLamp)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: lamp),
                if (setAside != null)
                  ClassSetAsideButton(
                    key: ValueKey('class-set-aside-${row.identity}'),
                    title: classBriefTitle(entry.title),
                    onTap: setAside,
                    narrow: true,
                  ),
              ],
            )
          else ...[
            lamp,
            if (setAside != null)
              Center(
                child: ClassSetAsideButton(
                  key: ValueKey('class-set-aside-${row.identity}'),
                  title: classBriefTitle(entry.title),
                  onTap: setAside,
                ),
              ),
          ],
          if (card.offersShortcut && !held)
            _ShortcutLine(card: card, onMark: onMark),
        ] else if (setAside != null)
          Padding(
            padding: const EdgeInsets.only(left: 56),
            child: Align(
              alignment: Alignment.centerLeft,
              child: ClassSetAsideButton(
                key: ValueKey('class-set-aside-${row.identity}'),
                title: classBriefTitle(entry.title),
                onTap: setAside,
              ),
            ),
          ),
      ],
    );
    final undo = onUndo;
    if (undo == null || !held) return column;
    return Dismissible(
      key: ValueKey('class-undo-${row.identity}'),
      direction: DismissDirection.endToStart,
      dismissThresholds: const {DismissDirection.endToStart: 0.42},
      confirmDismiss: (_) async {
        undo();
        return false; // the restore handles the state change
      },
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.undo, size: 16, color: Palette.xpLight),
            const SizedBox(width: 6),
            Text(
              'UNDO',
              style: Type.label.copyWith(fontSize: 11, color: Palette.xpLight),
            ),
          ],
        ),
      ),
      background: const SizedBox.shrink(),
      child: column,
    );
  }
}

/// A class just kept is held in place while the Doorway hangs its ticket: the
/// card's ring closes and its control turns to "ATTENDED" half a second in,
/// as the stamp lands. Under Reduce Motion, at once.
class _AttendingGate extends StatefulWidget {
  const _AttendingGate({
    required this.held,
    required this.reduceMotion,
    required this.builder,
  });

  final bool held;
  final bool reduceMotion;
  final Widget Function(BuildContext context, bool closed) builder;

  @override
  State<_AttendingGate> createState() => _AttendingGateState();
}

class _AttendingGateState extends State<_AttendingGate>
    with SingleTickerProviderStateMixin {
  late final AnimationController _beat;

  bool _closed = false;

  @override
  void initState() {
    super.initState();
    _beat = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..addStatusListener(_status);
    // A card first built already held (it was marked a moment ago, or the
    // page was rebuilt around it) is closed.
    _closed = widget.held;
  }

  void _status(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted && widget.held) {
      setState(() => _closed = true);
    }
  }

  @override
  void didUpdateWidget(_AttendingGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.held && !oldWidget.held) {
      if (widget.reduceMotion) {
        _closed = true;
      } else {
        _closed = false;
        _beat.forward(from: 0);
      }
    } else if (!widget.held) {
      _beat.stop();
      _closed = false;
    }
  }

  @override
  void dispose() {
    _beat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _closed);
}

/// The one control on the card: a quiet bar of smoked glass with cream serif
/// capitals and a thin warm hairline ([ClassThereButton]).
/// Contact turns its light up under the finger at once; a kept class turns
/// the lamp low; a class that cannot be marked yet is an unlit shade.
class ClassThereButton extends StatelessWidget {
  const ClassThereButton({
    super.key,
    required this.label,
    required this.onTap,
    required this.semanticLabel,
    this.attendedLabel,
    this.onSetAside,
    this.enabled = true,
    this.kept = false,
    this.acknowledged = false,
    this.light,
    this.reduceMotion = false,
  });

  final String label;

  /// What the bar says once the class is kept ("ATTENDED · +25 XP").
  final String? attendedLabel;
  final VoidCallback onTap;
  final String semanticLabel;

  /// Offered to a screen reader as a named action on this control, beside the
  /// quiet "Couldn't make it" button under it.
  final VoidCallback? onSetAside;
  final bool enabled;

  /// The class is kept: the bar settles to its attended face.
  final bool kept;

  /// The press was taken a moment ago and the card has not closed its ring
  /// yet: the bar holds a touch brighter.
  final bool acknowledged;
  final ValueListenable<Offset>? light;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final words = kept && attendedLabel != null ? attendedLabel! : label;
    Widget word(String text, {Key? key}) => Text(
      text,
      key: key,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: LedgerType.body.copyWith(
        fontSize: 13.6,
        height: 1,
        fontWeight: FontWeight.w500,
        letterSpacing: kept ? 2.0 : 2.7,
        color: enabled || kept || acknowledged
            ? const Color(0xFFF2E3C4)
            : const Color(0xFFF2E3C4).withValues(alpha: 0.42),
      ),
    );
    Widget face(bool pressed) => ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: CustomPaint(
        painter: _GlassBar(
          kept: kept,
          enabled: enabled || kept || acknowledged,
          lit: pressed || acknowledged,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Center(
            child: attendedLabel == null
                ? word(words)
                // The bar turns to its attended words with a short cross-fade.
                : AnimatedSwitcher(
                    // The old words go, then the new ones come: never both
                    // at once.
                    duration: Duration(milliseconds: reduceMotion ? 0 : 360),
                    switchInCurve: const Interval(0.45, 1),
                    switchOutCurve: const Interval(0.45, 1),
                    child: word(words, key: ValueKey(kept)),
                  ),
          ),
        ),
      ),
    );
    return Pressable(
      key: const Key('class-there-button'),
      pressDepth: 1,
      // The completion composite voices the press; a second contact sound
      // would strike over it.
      soundEnabled: false,
      enabled: enabled,
      edgeColor: Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      semanticLabel: semanticLabel,
      semanticActions: onSetAside == null
          ? null
          : {
              const CustomSemanticsAction(label: classSetAsideLabel):
                  onSetAside!,
            },
      onTapUp: (_) => onTap(),
      stateBuilder: (context, child, pressed, focused, hovered) =>
          face(pressed),
      child: face(false),
    );
  }
}

/// The bar's glass: a smoked pane a little narrower at the top, warmed by the
/// faintest gradient, with a thin warm hairline and a bright line along its
/// top edge. No glow: the door's light is the scene's one warm accent.
class _GlassBar extends CustomPainter {
  const _GlassBar({
    required this.kept,
    required this.enabled,
    required this.lit,
  });

  final bool kept;
  final bool enabled;
  final bool lit;

  @override
  void paint(Canvas canvas, Size size) {
    final inset = size.width * 0.025;
    const r = 5.0;
    final path = Path()
      ..moveTo(inset + r, 0)
      ..lineTo(size.width - inset - r, 0)
      ..quadraticBezierTo(size.width - inset, 0, size.width - inset + 0.4, r)
      ..lineTo(size.width - 0.2, size.height - r)
      ..quadraticBezierTo(size.width, size.height, size.width - r, size.height)
      ..lineTo(r, size.height)
      ..quadraticBezierTo(0, size.height, 0.2, size.height - r)
      ..lineTo(inset - 0.4, r)
      ..quadraticBezierTo(inset, 0, inset + r, 0)
      ..close();
    // The pane's shade under it, soft.
    canvas.drawPath(
      path.shift(const Offset(0, 3)),
      Paint()
        ..color = const Color(0x59000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    // Smoked glass: a dark body with the faintest warm gradient over it.
    canvas.drawPath(path, Paint()..color = const Color(0x4A140A04));
    final bump = lit ? 0.07 : 0.0;
    final warm = kept ? 1.0 : 0.0;
    final dim = enabled ? 1.0 : 0.55;
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.fromRGBO(255, 226, 170, (0.12 + 0.10 * warm + bump) * dim),
            Color.fromRGBO(255, 210, 150, (0.03 + 0.05 * warm + bump) * dim),
            Color.fromRGBO(255, 200, 130, (0.09 + 0.08 * warm + bump) * dim),
          ],
          stops: const [0, 0.55, 1],
        ).createShader(Offset.zero & size),
    );
    // The bright line along the top, and the quiet one along the foot.
    canvas.save();
    canvas.clipPath(path);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, 1),
      Paint()..color = Color.fromRGBO(255, 226, 170, 0.5 * dim),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - 1, size.width, 1),
      Paint()..color = Color.fromRGBO(255, 200, 130, 0.22 * dim),
    );
    canvas.restore();
    // The hairline.
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = kept
            ? const Color(0xBFE8BE74)
            : Color.fromRGBO(214, 170, 100, 0.5 * dim),
    );
  }

  @override
  bool shouldRepaint(_GlassBar old) =>
      old.kept != kept || old.enabled != enabled || old.lit != lit;
}

/// "Couldn’t make it": a quiet word on a class that can be set aside. Cream
/// text on the glass, no color, no icon, nothing that reads as a warning, and
/// always smaller than the one bright control. [narrow] is the form that sits
/// at the end of a quiet row (two short lines).
class ClassSetAsideButton extends StatelessWidget {
  const ClassSetAsideButton({
    super.key,
    required this.title,
    required this.onTap,
    this.narrow = false,
  });

  /// The class's short name, for the screen reader.
  final String title;
  final VoidCallback onTap;
  final bool narrow;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      classSetAsideLabel,
      textAlign: narrow ? TextAlign.right : TextAlign.center,
      style: _serif(
        narrow ? 14 : 16,
        color: Palette.textMid.withValues(alpha: 0.72),
        height: 1.1,
        style: FontStyle.italic,
      ),
    );
    return Pressable(
      pressDepth: 1,
      soundEnabled: false,
      edgeColor: Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      semanticLabel: classSetAsideSemantics(title),
      onTapUp: (_) => onTap(),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: narrow ? 44 : 40,
          minWidth: 44,
          maxWidth: narrow ? 118 : 220,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: narrow ? 6 : 10),
          child: Center(widthFactor: 1, child: ExcludeSemantics(child: text)),
        ),
      ),
    );
  }
}

/// The few seconds after a class folds away: it is named once as off today's
/// list, with "Undo". Polite live region; says nothing else.
class ClassDismissedLine extends StatelessWidget {
  const ClassDismissedLine({super.key, required this.label, this.onUndo});

  final String label;
  final VoidCallback? onUndo;

  @override
  Widget build(BuildContext context) {
    final words = classSetAsideLine(label);
    return Semantics(
      liveRegion: true,
      container: true,
      label: words,
      child: ConstrainedBox(
        key: const Key('class-dismissed-line'),
        constraints: const BoxConstraints(minHeight: 44),
        child: Row(
          children: [
            Expanded(
              child: ExcludeSemantics(
                child: Text(
                  words,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _serif(
                    16,
                    color: Palette.textLo,
                    style: FontStyle.italic,
                  ),
                ),
              ),
            ),
            if (onUndo != null)
              Pressable(
                key: const Key('class-dismissed-undo'),
                pressDepth: 1,
                soundEnabled: false,
                edgeColor: Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                semanticLabel: 'Undo: $label back on today’s list',
                onTapUp: (_) => onUndo!(),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: 44,
                    minWidth: 56,
                  ),
                  child: Center(
                    widthFactor: 1,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: ExcludeSemantics(
                        child: Text(
                          'Undo',
                          style: Type.label.copyWith(
                            fontSize: Type.minLabel,
                            letterSpacing: 1.2,
                            color: Palette.xpLight,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// "I went to all of today’s classes": quiet, under the one bright control,
/// only while two or more ended classes wait.
class _ShortcutLine extends StatelessWidget {
  const _ShortcutLine({required this.card, required this.onMark});

  final ClassCard card;
  final void Function(List<ClassRow> rows) onMark;

  @override
  Widget build(BuildContext context) {
    final n = card.waiting.length;
    final label = card.shortcutCompletesDay
        ? 'I went to all of today’s classes'
        : n == 2
        ? 'I went to both'
        : 'I went to all ${classCountWord(n)}';
    return Pressable(
      key: const Key('class-all-of-today'),
      pressDepth: 1,
      soundEnabled: false,
      edgeColor: Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      semanticLabel: label,
      onTapUp: (_) => onMark(card.waiting),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CustomPaint(
                size: const Size(22, 12),
                painter: _TwinRings(
                  color: Palette.brassLit.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(width: 9),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: _serif(18, color: Palette.textHi),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TwinRings extends CustomPainter {
  const _TwinRings({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.height / 2 - 0.8;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = color;
    canvas.drawCircle(Offset(r + 0.8, size.height / 2), r, paint);
    canvas.drawCircle(Offset(size.width - r - 0.8, size.height / 2), r, paint);
  }

  @override
  bool shouldRepaint(_TwinRings old) => old.color != color;
}

/// A quiet row: kept (closed ring and its XP), later (its start time), or
/// over and unmarked (a dim dot, nothing more). An unmarked row can be
/// brought forward with a tap; the latest kept row can be swiped to undo.
class _QuietRow extends StatelessWidget {
  const _QuietRow({
    super.key,
    required this.row,
    required this.now,
    this.onSelect,
    this.onUndo,
    this.onDismiss,
    this.onReveal,
    this.revealed = false,
  });

  final ClassRow row;
  final DateTime now;
  final VoidCallback? onSelect;
  final VoidCallback? onUndo;

  /// "Couldn't make it" on a row that can be set aside; null otherwise.
  final VoidCallback? onDismiss;

  /// A class still to come keeps its "Couldn't make it" out of sight until
  /// the row is tapped: [onReveal] toggles it, [revealed] says it is showing.
  /// Null (and [revealed] ignored) for a row whose word is always there.
  final VoidCallback? onReveal;
  final bool revealed;

  @override
  Widget build(BuildContext context) {
    final entry = row.entry;
    final place = classPlace(entry);
    final title = classBriefTitle(entry.title);
    final String meta = switch (row.state) {
      ClassRowState.kept =>
        '${classClockShort(entry.localStartMinute)} · $place',
      ClassRowState.inSession =>
        '$place · until ${classClockShort(entry.localEndMinute)}',
      ClassRowState.startsSoon =>
        'starts in ${math.max(1, (entry.startsAt.difference(now.toUtc()).inSeconds / 60).ceil())} min · $place',
      ClassRowState.upcoming =>
        '${classClock(entry.localStartMinute)} · $place',
      ClassRowState.ready || ClassRowState.settled =>
        '${classClockShort(entry.localStartMinute)} · $place',
    };
    final Widget mark = switch (row.state) {
      ClassRowState.kept => QuestCheckRing(
        stat: row.kept!.stat,
        done: true,
        size: 28,
      ),
      ClassRowState.upcoming ||
      ClassRowState.startsSoon => const _FutureMark(size: 20),
      _ => const _QuietDot(),
    };
    final quiet =
        row.state == ClassRowState.upcoming ||
        row.state == ClassRowState.startsSoon;
    Widget body = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 42),
      child: Row(
        children: [
          SizedBox.square(dimension: 40, child: Center(child: mark)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LedgerType.body.copyWith(
                    fontSize: 19,
                    height: 1.1,
                    color: row.isKept ? Palette.textHi : Palette.textMid,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Type.label.copyWith(
                    fontSize: Type.minLabel,
                    letterSpacing: 0.5,
                    color: quiet
                        ? Palette.textLo
                        : Palette.textLo.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          if (row.kept case final kept?)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                '+${kept.xp} XP',
                style: Type.numerals.copyWith(
                  fontSize: 15,
                  color: Palette.xp.withValues(alpha: 0.9),
                ),
              ),
            ),
        ],
      ),
    );
    if (onSelect != null) {
      body = Pressable(
        pressDepth: 1,
        soundEnabled: false,
        edgeColor: Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        semanticLabel: '$title, ${classClock(entry.localStartMinute)}',
        semanticHint: 'Bring forward to mark it',
        semanticActions: onDismiss == null
            ? null
            : {
                const CustomSemanticsAction(label: classSetAsideLabel):
                    onDismiss!,
              },
        onTapUp: (_) => onSelect!(),
        child: body,
      );
    } else if (onReveal != null) {
      body = Pressable(
        key: ValueKey('class-reveal-${row.identity}'),
        pressDepth: 1,
        soundEnabled: false,
        edgeColor: Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        semanticLabel: '$title, ${classClock(entry.localStartMinute)}',
        semanticHint: revealed ? null : 'Shows $classSetAsideLabel',
        semanticActions: onDismiss == null
            ? null
            : {
                const CustomSemanticsAction(label: classSetAsideLabel):
                    onDismiss!,
              },
        onTapUp: (_) => onReveal!(),
        child: body,
      );
    }
    if (onDismiss != null && (onReveal == null || revealed)) {
      // Beside the row, not inside its press: bringing a row forward and
      // setting it aside are two separate touches.
      body = Row(
        children: [
          Expanded(child: body),
          ClassSetAsideButton(
            key: ValueKey('class-set-aside-${row.identity}'),
            title: title,
            onTap: onDismiss!,
            narrow: true,
          ),
        ],
      );
    }
    if (onUndo == null) return body;
    return Dismissible(
      key: ValueKey('class-undo-${row.identity}'),
      direction: DismissDirection.endToStart,
      dismissThresholds: const {DismissDirection.endToStart: 0.42},
      confirmDismiss: (_) async {
        onUndo!();
        return false; // the restore handles the state change
      },
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.undo, size: 16, color: Palette.xpLight),
            const SizedBox(width: 6),
            Text(
              'UNDO',
              style: Type.label.copyWith(fontSize: 11, color: Palette.xpLight),
            ),
          ],
        ),
      ),
      background: const SizedBox.shrink(),
      child: body,
    );
  }
}

/// An ended class nobody marked: a dim dot. Never a hollow socket.
class _QuietDot extends StatelessWidget {
  const _QuietDot();

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('class-quiet-dot'),
    width: 6,
    height: 6,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Palette.textLo.withValues(alpha: 0.42),
    ),
  );
}

/// A class still to come: a fine broken orbit, dim.
class _FutureMark extends StatelessWidget {
  const _FutureMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _FutureMarkPainter(color: Palette.brass.withValues(alpha: 0.55)),
  );
}

class _FutureMarkPainter extends CustomPainter {
  const _FutureMarkPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 1.5;
    const dashes = 18;
    const sweep = 2 * math.pi / dashes;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        i * sweep,
        sweep * 0.45,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_FutureMarkPainter old) => old.color != color;
}

/// "TOMORROW · 8:30 AM    Computer Architecture Lab".
class _NextLine extends StatelessWidget {
  const _NextLine({required this.next});

  final NextClass next;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('class-day-next'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${next.dayWord.toUpperCase()} · '
          '${classClock(next.entry.localStartMinute)}',
          style: Type.label.copyWith(
            fontSize: Type.minLabel,
            letterSpacing: 0.8,
            color: Palette.brassLit.withValues(alpha: 0.72),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          classBriefTitle(next.entry.title),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: _serif(18, color: Palette.textMid),
        ),
      ],
    );
  }
}

/// Today's three, one line, and BOARD: the game stays one tap away. [three]
/// is the board's own pips and words; [onBoard] brings the full board back.
class ClassDayBottomLine extends StatelessWidget {
  const ClassDayBottomLine({
    super.key,
    required this.three,
    required this.onBoard,
    this.boardLabel = 'BOARD',
    this.boardIcon = Icons.keyboard_arrow_up_rounded,
  });

  final Widget three;
  final VoidCallback onBoard;
  final String boardLabel;
  final IconData boardIcon;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Row(
        children: [
          Expanded(child: three),
          Pressable(
            key: Key('class-day-toggle-${boardLabel.toLowerCase()}'),
            pressDepth: 1,
            edgeColor: Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            material: MaterialSound.parchment,
            interactionSound: InteractionSound.navigate,
            semanticLabel: boardLabel == 'BOARD'
                ? 'Show the full Quest board'
                : 'Back to the room',
            onTapUp: (_) => onBoard(),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44, minWidth: 64),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 4, 2, 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      boardLabel,
                      style: Type.label.copyWith(
                        fontSize: Type.minLabel,
                        letterSpacing: 1.4,
                        color: Palette.textMid,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(boardIcon, size: 18, color: Palette.textMid),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A class that is not a lab feeds MIND; a lab or studio, CRAFT (the
/// engine's [ClassPay] rule, for the ring's colour before a keep exists).
Stat classStatFor(ProjectedClass entry) =>
    ClassPay.forKind(entry.kind.name).stat;
