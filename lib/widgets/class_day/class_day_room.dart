// The Quests tab on a class day: the room, large, with today's classes on one
// calm pane of glass whose top edge sits on the floor line (ported from
// concept B, "In the room", with concept A's seams into the real board).
//
// One owner and one luminous control: the class that just ended (or the one
// he is sitting in) leads the glass with "I was there" (or "I'm here"). The
// HUD keeps the life RPG in two quiet lines (level, XP, the six stats), and
// Today's three is one line with a BOARD toggle that brings the full board
// back. Controls live in the glass; nothing is drawn onto the painting.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../../academic_calendar/services/class_day_projection.dart';
import '../../academic_calendar/domain/academic_schedule.dart' show CivilDate;
import '../../audio.dart' show InteractionSound, MaterialSound;
import '../../engine.dart';
import '../../main_room_music.dart' show MainRoomMusic;
import '../../tokens.dart';
import '../count_up.dart';
import '../facets.dart';
import '../gold_surface.dart';
import '../pressable.dart';
import '../quest_card.dart' show QuestCheckRing;
import '../routine_ledger.dart' show LedgerType;
import 'class_day_model.dart';
import 'class_room_stage.dart';

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
    required this.now,
    required this.bottomLine,
    required this.onMark,
    required this.onSelect,
    required this.onExploreStat,
    required this.dockHeight,
    required this.camera,
    this.onUndo,
    this.undoIdentity,
    this.reduceMotion = false,
    this.lightDirection,
    this.quiet = false,
    this.evening,
    this.walkFrom,
    this.onStepBack,
  });

  final GameState state;
  final ClassCard card;
  final DateTime now;

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
  final ClassRoomCamera camera;

  /// The latest kept class can be swiped left past 42% to undo, exactly as
  /// the Quest board's latest completion.
  final VoidCallback? onUndo;
  final String? undoIdentity;
  final bool reduceMotion;
  final ValueListenable<Offset>? lightDirection;

  /// The evening (the last class is over, and every class is kept or the
  /// wind-down has begun): the camera walks to the window and the armchair
  /// and the glass holds the day folded to one line, the music, a page in the
  /// journal and closing the day. Null during the class day.
  final ClassEvening? evening;

  /// Where the camera's walk starts when the evening arrives under the
  /// celebration (its framing). Only that walk stages the glass's arrival;
  /// any other turn (the app reopened after the class, the wind-down's own
  /// timer, an undo) crossfades with the glass on screen and pressable.
  final RoomShot? walkFrom;

  /// The folded evening with the room's music on: the glass, Today's three
  /// and the HUD step back, the camera eases a little closer, and the page
  /// is told so the shell's dock can step back too.
  final ValueChanged<bool>? onStepBack;

  /// The walk between the desk and the evening: slow and eased, the real
  /// planes moving at their own rates, never a blur.
  static const walkDuration = Duration(milliseconds: 2400);

  @override
  State<ClassDayRoom> createState() => _ClassDayRoomState();
}

enum _Move { walk, fade }

class _ClassDayRoomState extends State<ClassDayRoom>
    with TickerProviderStateMixin {
  late final AnimationController _move = AnimationController(
    vsync: this,
    duration: ClassDayRoom.walkDuration,
    value: 1,
  );

  /// 0..1: the music's step back (the glass dims, the camera eases closer).
  late final AnimationController _near = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
    value: _stepBack ? 1 : 0,
  );
  _Move _kind = _Move.walk;
  RoomShot? _from;

  /// The walk under the celebration: the glass arrives as the camera
  /// settles. Nothing is left to mark then.
  bool _staged = false;

  /// The framing on screen at the last frame.
  RoomShot? _shown;

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
    final turned = (oldWidget.evening == null) != (widget.evening == null);
    if (!turned || _shown == null) return;
    // The room turns. Under the celebration, on the depth room, the camera
    // walks from the celebration's framing and the glass arrives as it
    // settles. Any other turn (reopening the app after the class, the
    // wind-down's timer, an undo) is a short crossfade with the glass kept
    // on screen, so a class still to mark answers the first touch. Under
    // Reduce Motion, or on a painted plate, a still fades into the next.
    final walkFrom = widget.walkFrom;
    final walks =
        walkFrom != null &&
        classRoomIsLayered(widget.state) &&
        !widget.reduceMotion;
    _kind = walks ? _Move.walk : _Move.fade;
    _staged = walks;
    _from = walks ? walkFrom : _shown;
    _move.duration = walks
        ? ClassDayRoom.walkDuration
        : Duration(milliseconds: widget.reduceMotion ? 320 : 480);
    _move.forward(from: 0);
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

  @override
  void dispose() {
    _musicOn?.removeListener(_onMusic);
    final tell = widget.onStepBack;
    if (_toldStepBack == true && tell != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => tell(false));
    }
    _move.dispose();
    _near.dispose();
    super.dispose();
  }

  bool get _moving => _move.value < 1 && _from != null;

  /// The camera at this frame of the walk: eased, with the near planes
  /// swinging wider than the far ones while it pans (the armchair passes the
  /// window), settling as it arrives.
  RoomShot _shotAt(RoomShot target) {
    final from = _from;
    if (!_moving || _kind != _Move.walk || from == null) return target;
    final t = Curves.easeInOutSine.transform(_move.value);
    final base = RoomShot.lerp(from, target, t);
    final direction = (target.left - from.left).sign;
    return RoomShot(
      left: base.left,
      top: base.top,
      scale: base.scale,
      tilt: base.tilt + Offset(0.9 * direction * math.sin(math.pi * t), 0),
    );
  }

  /// The glass arrives as the camera settles (the last 45% of the walk under
  /// the celebration); every other time it is simply there.
  double get _glassArrive {
    if (!_moving || !_staged) return 1;
    return Curves.easeOut.transform(
      ((_move.value - 0.55) / 0.45).clamp(0.0, 1.0),
    );
  }

  @override
  Widget build(BuildContext context) {
    final widget = this.widget;
    final card = widget.card;
    final evening = widget.evening;
    final hour = RoomHour.atInstant(
      widget.now,
      card.day.classes.isEmpty ? null : card.day.classes.first.timeZoneId,
    );
    final layered = classRoomIsLayered(widget.state);
    // The painting runs up under the status bar (the shell's SafeArea keeps
    // the page below it), so the room is opened into, never placed under a
    // band. The HUD stays where it was, on the room's own soft dark.
    final above = classStatusAbove(context);
    final topPad = MediaQuery.paddingOf(context).top;
    final scaler = MediaQuery.textScalerOf(context);
    // The lamp's shade may tuck just under the stat row, never higher.
    final headroom =
        above + topPad + _ClassDayDelegate.hudTop + scaler.scale(20) + 34;
    // The soft dark under the status bar and the HUD: 150 pt from the top
    // of the screen on his phone, as in the concept.
    final scrimHeight = math.max(
      91.0,
      above + topPad + classStatusScrimHeight - 59,
    );
    // Once the day's classes are kept, or in the evening, the lamp keeps a
    // quieter, lasting warmth.
    final warmth = evening != null || card.allKept ? 1.0 : 0.0;
    final Widget body = evening == null
        ? ClassCardBody(
            state: widget.state,
            card: card,
            now: widget.now,
            onMark: widget.onMark,
            onSelect: widget.onSelect,
            onUndo: widget.onUndo,
            undoIdentity: widget.undoIdentity,
            reduceMotion: widget.reduceMotion,
            lightDirection: widget.lightDirection,
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
                  final floorAt =
                      box.maxHeight - _ClassDayDelegate.behindGlass - 4;
                  return AnimatedBuilder(
                    animation: Listenable.merge([_move, _near]),
                    builder: (context, _) {
                      final target = evening == null
                          ? RoomShot.desk(
                              floorAt: floorAt,
                              width: box.maxWidth,
                              headroom: headroom,
                            )
                          : RoomShot.evening(
                              floorAt: floorAt,
                              width: box.maxWidth,
                              headroom: headroom,
                              // Under Reduce Motion the camera stays put;
                              // only the glass steps back.
                              closer: widget.reduceMotion ? 0 : _near.value,
                            );
                      final shot = _shotAt(target);
                      _shown = shot;
                      double fadeEndFor(RoomShot at) =>
                          math.min(box.maxHeight, (962 - at.top) * at.scale) -
                          2;
                      double fadeStartFor(RoomShot at) =>
                          math.min(floorAt + 30, fadeEndFor(at) - 70);
                      widget.camera
                        ..shot = shot
                        ..fadeStart = fadeStartFor(shot)
                        ..fadeEnd = fadeEndFor(shot)
                        ..scrimHeight = scrimHeight;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        final ro = context.findRenderObject();
                        if (ro is RenderBox && ro.attached && ro.hasSize) {
                          widget.camera.stage =
                              ro.localToGlobal(Offset.zero) & ro.size;
                        }
                      });
                      if (!layered) {
                        return ClassRoomPlate(
                          state: widget.state,
                          fadeStart: fadeStartFor(shot),
                          fadeEnd: fadeEndFor(shot),
                          scrimHeight: scrimHeight,
                        );
                      }
                      Widget stageAt(RoomShot at, {Key? key}) => ClassRoomStage(
                        key: key,
                        hour: hour,
                        shot: at,
                        warmth: warmth,
                        fadeStart: fadeStartFor(at),
                        fadeEnd: fadeEndFor(at),
                        scrimHeight: scrimHeight,
                      );
                      final from = _from;
                      if (_moving && _kind == _Move.fade && from != null) {
                        // Reduce Motion: one still fades into the other.
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            stageAt(from),
                            Opacity(
                              opacity: Curves.easeOut.transform(_move.value),
                              child: stageAt(
                                shot,
                                key: const Key('class-day-stage'),
                              ),
                            ),
                          ],
                        );
                      }
                      return stageAt(shot, key: const Key('class-day-stage'));
                    },
                  );
                },
              ),
            ),
            LayoutId(
              id: _Slot.glass,
              child: _Quiet(
                quiet: widget.quiet,
                child: AnimatedBuilder(
                  animation: Listenable.merge([_move, _near]),
                  builder: (context, child) {
                    final arrive = _glassArrive;
                    return Opacity(
                      // With the music on the glass steps back; its doors
                      // stay where they are and still answer a touch.
                      opacity: arrive * (1 - 0.55 * _near.value),
                      // Only the staged walk holds the glass back, and
                      // nothing is left to mark then.
                      child: IgnorePointer(
                        ignoring: _staged && arrive < 0.5,
                        child: child,
                      ),
                    );
                  },
                  child: ClassGlass(
                    key: const Key('class-day-glass'),
                    child: body,
                  ),
                ),
              ),
            ),
            LayoutId(
              id: _Slot.line,
              child: _Quiet(
                quiet: widget.quiet,
                child: _StepBack(
                  near: _near,
                  depth: 0.55,
                  child: widget.bottomLine,
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

enum _Slot { stage, glass, line, hud }

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
  Widget build(BuildContext context) => AnimatedOpacity(
    opacity: quiet ? 0 : 1,
    duration: const Duration(milliseconds: 240),
    child: IgnorePointer(ignoring: quiet, child: child),
  );
}

/// Today's three sits just above the dock; the glass sits above it; the
/// room's floor line sits on the glass's top edge, so the room grows when the
/// glass is short and the camera eases in.
class _ClassDayDelegate extends MultiChildLayoutDelegate {
  _ClassDayDelegate({required this.above, required this.topPad});

  /// The status bar above the page: the stage reaches up through it.
  final double above;

  /// The page's own top padding (zero under the shell's SafeArea).
  final double topPad;

  /// How far the room continues behind the glass before it settles.
  static const behindGlass = 130.0;

  /// The HUD's top, under the page's top edge.
  static const hudTop = 8.0;

  @override
  void performLayout(Size size) {
    final line = layoutChild(
      _Slot.line,
      BoxConstraints.tightFor(width: size.width - 36),
    );
    final lineTop = size.height - line.height - 4;
    positionChild(_Slot.line, Offset(18, lineTop));
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
          lineTop - 6 - (topPad + hudTop + hud.height + 96),
        ),
      ),
    );
    final glassTop = lineTop - 6 - glass.height;
    positionChild(_Slot.glass, Offset(16, glassTop));
    final stageHeight = math.min(size.height, glassTop + behindGlass) + above;
    layoutChild(
      _Slot.stage,
      BoxConstraints.tightFor(width: size.width, height: stageHeight),
    );
    // From the top of the screen: nothing clips the page above its own top,
    // so the painting shows under the status bar.
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

/// Restrained glass: the room blurs through it under a walnut tint, the
/// lamp's light falls across it from the left, and its top lip catches that
/// light. No drop shadow and no bottom ledge: the lower edge dissolves into
/// the floor's shadow, so the furniture reads as standing behind it. Never
/// light parchment.
class ClassGlass extends StatelessWidget {
  const ClassGlass({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(18, 14, 18, 14),
  });

  final Widget child;
  final EdgeInsets padding;

  static const _lampX = -0.9;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: const _TopFacetClipper(cut: 12),
      child: Stack(
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: const SizedBox.expand(),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF241911).withValues(alpha: 0.72),
                      const Color(0xFF1C140F).withValues(alpha: 0.82),
                      const Color(0xFF191210).withValues(alpha: 0.95),
                    ],
                    stops: const [0, 0.45, 1],
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(_lampX, -1.35),
                    radius: 1.25,
                    colors: [
                      const Color(0xFFE9B672).withValues(alpha: 0.14),
                      const Color(0xFFE9B672).withValues(alpha: 0.04),
                      const Color(0x00E9B672),
                    ],
                    stops: const [0, 0.5, 1],
                  ),
                ),
              ),
            ),
          ),
          const Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _GlassEdgePainter(lampX: _lampX)),
            ),
          ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

class _TopFacetClipper extends CustomClipper<Path> {
  const _TopFacetClipper({required this.cut});

  final double cut;

  @override
  Path getClip(Size size) => Path()
    ..moveTo(cut, 0)
    ..lineTo(size.width - cut, 0)
    ..lineTo(size.width, cut)
    ..lineTo(size.width, size.height)
    ..lineTo(0, size.height)
    ..lineTo(0, cut)
    ..close();

  @override
  bool shouldReclip(_TopFacetClipper old) => old.cut != cut;
}

class _GlassEdgePainter extends CustomPainter {
  const _GlassEdgePainter({required this.lampX});

  final double lampX;

  @override
  void paint(Canvas canvas, Size size) {
    const cut = 12.0;
    final w = size.width;
    final h = size.height;
    final edge = Path()
      ..moveTo(0.5, h * 0.62)
      ..lineTo(0.5, cut)
      ..lineTo(cut, 0.5)
      ..lineTo(w - cut, 0.5)
      ..lineTo(w - 0.5, cut)
      ..lineTo(w - 0.5, h * 0.62);
    canvas.drawPath(
      edge,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Palette.brass.withValues(alpha: 0.7),
            Palette.brass.withValues(alpha: 0.32),
            Palette.brass.withValues(alpha: 0),
          ],
          stops: const [0, 0.35, 1],
        ).createShader(Offset.zero & Size(w, h * 0.62)),
    );
    final lipCentre = (lampX + 1) / 2;
    canvas.drawLine(
      const Offset(cut + 4, 1.4),
      Offset(w - cut - 4, 1.4),
      Paint()
        ..strokeWidth = 1.2
        ..shader = LinearGradient(
          colors: [
            const Color(0x00F3DDAE),
            const Color(0xFFF3DDAE).withValues(alpha: 0.55),
            const Color(0x00F3DDAE),
          ],
          stops: [0, lipCentre.clamp(0.08, 0.9), 1],
        ).createShader(Rect.fromLTWH(0, 0, w, 2)),
    );
  }

  @override
  bool shouldRepaint(_GlassEdgePainter old) => old.lampX != lampX;
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

class ClassCardBody extends StatelessWidget {
  const ClassCardBody({
    super.key,
    required this.state,
    required this.card,
    required this.now,
    required this.onMark,
    required this.onSelect,
    this.onUndo,
    this.undoIdentity,
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
  final bool reduceMotion;
  final ValueListenable<Offset>? lightDirection;

  /// The evening's card while a class can still be marked: the class that
  /// leads with its one control and the shortcut, the newest kept row while
  /// its undo is armed, and the other classes still open as one line of
  /// start times. No list of the day's other rows: the room keeps the frame.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final day = card.day;
    final dayName = weekdayOf(day.date).toUpperCase();
    final count = day.classes.length;
    final kept = card.keptCount;
    final foremost = card.foremost;
    final String left;
    final String? right;
    if (card.isRecord && card.allKept) {
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
    final others = [
      for (final row in card.rows)
        if (foremost == null || row.identity != foremost.identity) row,
    ];
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
    if (compact) return _compact(header);
    final children = <Widget>[
      header,
      SizedBox(height: foremost == null ? 8 : 12),
      if (foremost != null)
        _ForemostRow(
          key: ValueKey('class-foremost-${foremost.identity}'),
          row: foremost,
          card: card,
          now: now,
          onMark: onMark,
          reduceMotion: reduceMotion,
          lightDirection: lightDirection,
        ),
      for (var i = 0; i < others.length; i++) ...[
        if (foremost != null || i > 0) ...[
          SizedBox(height: foremost != null && i == 0 ? 10 : 2),
          const _GlassRule(),
          const SizedBox(height: 2),
        ],
        _QuietRow(
          key: ValueKey('class-row-${others[i].identity}'),
          row: others[i],
          now: now,
          onSelect: others[i].markable ? () => onSelect(others[i]) : null,
          onUndo: others[i].isKept && others[i].identity == undoIdentity
              ? onUndo
              : null,
        ),
      ],
      if (card.isRecord) ...[
        if ((state.dayRecordFor(day.dayKey)?.fullDayBonusXp ?? 0)
            case final bonus when bonus > 0)
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
        if (day.nextClassAfter case final next?) ...[
          const SizedBox(height: 8),
          Container(height: 1, color: Palette.brass.withValues(alpha: 0.22)),
          const SizedBox(height: 9),
          _NextLine(next: next),
        ],
      ],
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  Widget _compact(Widget header) {
    final foremost = card.foremost;
    final open = [
      for (final row in card.rows)
        if (row.markable && row.identity != foremost?.identity) row,
    ];
    ClassRow? undoRow;
    for (final row in card.rows) {
      if (row.isKept &&
          row.identity == undoIdentity &&
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
            now: now,
            onMark: onMark,
            reduceMotion: reduceMotion,
            lightDirection: lightDirection,
          ),
        if (undoRow != null) ...[
          const SizedBox(height: 8),
          const _GlassRule(),
          _QuietRow(
            key: ValueKey('class-row-${undoRow.identity}'),
            row: undoRow,
            now: now,
            onUndo: onUndo,
          ),
        ],
        if (open.isNotEmpty) _OpenTimesLine(rows: open, onSelect: onSelect),
      ],
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
  const _GlassRule();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 57),
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
    this.lightDirection,
  });

  final ClassRow row;
  final ClassCard card;
  final DateTime now;
  final void Function(List<ClassRow> rows) onMark;
  final bool reduceMotion;
  final ValueListenable<Offset>? lightDirection;

  @override
  Widget build(BuildContext context) {
    final entry = row.entry;
    final place = classPlace(entry);
    final markable = row.markable;
    final held = card.held && row.isKept;
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
    final ring = SizedBox.square(
      dimension: 44,
      child: Center(
        child: markable || held
            ? QuestCheckRing(
                stat: classStatFor(row.entry),
                done: held,
                showReadyCheck: !held,
                size: 42,
                reduceMotion: reduceMotion,
                lightDirection: lightDirection,
              )
            : const _FutureMark(size: 30),
      ),
    );
    return Column(
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
          const SizedBox(height: 14),
          ClassThereButton(
            label: inSession ? "I'M HERE" : 'I WAS THERE',
            enabled: markable,
            onTap: () => onMark([row]),
            semanticLabel: inSession
                ? "I'm here: ${classShortTitle(entry.title)}"
                : 'I was there: ${classShortTitle(entry.title)}',
          ),
          if (card.offersShortcut && !held)
            _ShortcutLine(card: card, onMark: onMark),
        ],
      ],
    );
  }
}

/// The one luminous control on the screen.
class ClassThereButton extends StatelessWidget {
  const ClassThereButton({
    super.key,
    required this.label,
    required this.onTap,
    required this.semanticLabel,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onTap;
  final String semanticLabel;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      key: const Key('class-there-button'),
      pressDepth: 3,
      material: MaterialSound.brass,
      // The completion composite voices the press; a second contact sound
      // would strike over it.
      soundEnabled: false,
      enabled: enabled,
      edgeColor: Colors.transparent,
      semanticLabel: semanticLabel,
      onTapUp: (_) => onTap(),
      stateBuilder: (context, child, pressed, focused, hovered) {
        if (!pressed) return child;
        // Pressed into the glass: the top lip goes into shadow.
        return Stack(
          children: [
            child,
            Positioned.fill(
              child: IgnorePointer(
                child: ClipPath(
                  clipper: const FacetedClipper(cut: 10),
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x4D2A1608),
                          Color(0x00000000),
                          Color(0x12FFF0C8),
                        ],
                        stops: [0, 0.45, 1],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: GoldSurface(
          cut: 10,
          textured: false,
          glow: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: GoldLabel(text: label),
          ),
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
  });

  final ClassRow row;
  final DateTime now;
  final VoidCallback? onSelect;
  final VoidCallback? onUndo;

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
      constraints: const BoxConstraints(minHeight: 46),
      child: Row(
        children: [
          SizedBox.square(dimension: 44, child: Center(child: mark)),
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
        onTapUp: (_) => onSelect!(),
        child: body,
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
