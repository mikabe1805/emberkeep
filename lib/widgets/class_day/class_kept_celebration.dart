// The full-screen answer to "I was there": a sibling of LevelUpOverlay that
// speaks its grammar (ported from concept B, "In the room").
//
// The level-up's walnut dim with no blur, a Fraunces declarative headline
// slammed in on elasticOut, the numeral in its diamond. Here the room's own
// lamp is the light: on the layered room the camera eases back until the
// whole lamp and desk are in frame and the lamp's light opens on the desk.
// The XP counts up and threads into the level rail, the stat lands as a chip,
// and one closing line says what is actually next in the timetable.
//
// The confirmation itself lives in the card's ring, which closed on contact;
// nothing floats over the painting.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../audio.dart';
import '../../haptics.dart';
import '../../tokens.dart';
import '../../engine.dart';
import '../facets.dart';
import '../glass.dart' show OverlaySurface;
import '../quest_card.dart' show QuestCheckRing;
import '../routine_ledger.dart' show LedgerType;
import 'class_day_model.dart';
import 'class_day_room.dart' show ClassRoomCamera;
import 'class_room_stage.dart';

class ClassKeptCelebration extends StatefulWidget {
  const ClassKeptCelebration({
    super.key,
    required this.plan,
    required this.state,
    required this.onDismiss,
    this.fromShot,
    this.backdrop,
    this.stageTop = 0,
    this.stageHeight,
    this.fadeStart,
    this.fadeEnd,
    this.scrimHeight = classStatusScrimHeight,
    this.camera,
    this.onLeaving,
    this.holdFraming = false,
    this.reduceMotion = false,
  });

  final ClassCelebrationPlan plan;

  /// Read for the room style only.
  final GameState state;
  final VoidCallback onDismiss;

  /// The room's camera when the plate was pressed: the move starts here.
  final RoomShot? fromShot;

  /// What stands behind the moment in place of the painted room (the
  /// Doorway, held still): given where the room's stage sat on screen and its
  /// status scrim's height. Null paints the room the older way.
  final Widget Function(BuildContext context, double stageTop, double scrim)?
  backdrop;

  /// Where the room's stage sat on screen, so the first frame registers
  /// with the room behind it.
  final double stageTop;

  /// The room's stage height and where its floor settled (a painted plate
  /// is drawn in exactly that box, so it holds still under the fade).
  final double? stageHeight;
  final double? fadeStart;
  final double? fadeEnd;

  /// The room's status scrim, which the celebration keeps over the window
  /// until the camera has moved it out of frame.
  final double scrimHeight;

  /// The room's live camera. When given, the celebration starts from and
  /// goes home to wherever the room is framed now (the card under it may
  /// change while it is up), over the fixed values above.
  final ClassRoomCamera? camera;

  /// Going back on its own has begun: the room may settle its card now,
  /// under the still-opaque takeover, so the fade lands on the room as it
  /// will stay.
  final VoidCallback? onLeaving;

  /// The room is already in the evening (the window and the armchair, the
  /// lamp in frame): the camera holds that framing and the lamp answers
  /// where it stands, so a mark never swings the camera across the room.
  final bool holdFraming;
  final bool reduceMotion;

  @override
  State<ClassKeptCelebration> createState() => _ClassKeptCelebrationState();
}

class _ClassKeptCelebrationState extends State<ClassKeptCelebration>
    with TickerProviderStateMixin {
  ClassCelebrationPlan get plan => widget.plan;
  bool get _held => plan.held;
  bool get _quick => plan.tier == ClassCelebrationTier.quick;

  /// Going back on its own: the words leave, the camera eases home to the
  /// room's framing as the dim lifts, and only then does the takeover fade
  /// onto the room it now matches, so nothing doubles on the way.
  static const _exitDuration = Duration(milliseconds: 360);
  late final AnimationController _exit = AnimationController(
    vsync: this,
    duration: widget.reduceMotion
        ? const Duration(milliseconds: 200)
        : _exitDuration,
  );

  /// Timeline length in class-tier milliseconds.
  int get _length => _held ? 2400 : 1500;

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.reduceMotion
        // Reduced Motion: one short fade in; everything else is still.
        ? const Duration(milliseconds: 220)
        : Duration(milliseconds: (_length / plan.speed).round()),
  );
  Timer? _autoReturn;
  bool _fingerDown = false;
  bool _returnOnRelease = false;
  bool _dismissed = false;
  final Set<String> _fired = {};

  double get _ms => _c.value * _length;

  /// The evening's framing is held only when its lamp sits clear of the
  /// status scrim, so the lamp can answer where it stands. Otherwise the
  /// camera eases back to the whole lamp and desk, as by day.
  late final bool _hold = () {
    if (!widget.holdFraming) return false;
    final shot = widget.fromShot ?? widget.camera?.shot;
    if (shot == null) return false;
    final scrim = widget.camera?.scrimHeight ?? widget.scrimHeight;
    return shot.toStage(RoomMarks.bulb).dy >= scrim;
  }();

  @override
  void initState() {
    super.initState();
    if (widget.reduceMotion) {
      _c.forward();
    } else {
      _c.addListener(_beats);
      _c.forward();
    }
    final auto = plan.autoReturn;
    if (auto != null) {
      // The fade back ends at [auto]: the room is home at 2.4 s (1.4 s).
      _autoReturn = Timer(auto - _exit.duration!, () {
        if (!mounted) return;
        if (_fingerDown) {
          _returnOnRelease = true;
        } else {
          _goBack();
        }
      });
    }
  }

  /// Back on its own, when the finger lifts, or at the tap that a held tier
  /// waits for: a short fade, then gone.
  void _goBack() {
    if (_dismissed || _exit.isAnimating) return;
    _autoReturn?.cancel();
    widget.onLeaving?.call();
    _exit.forward().whenComplete(() {
      if (mounted) _dismiss();
    });
  }

  void _dismiss() {
    if (_dismissed) return;
    _dismissed = true;
    _autoReturn?.cancel();
    widget.onDismiss();
  }

  void _once(String id, double atMs, VoidCallback f) {
    if (_ms >= atMs && _fired.add(id)) f();
  }

  void _beats() {
    final stat = plan.gains.keys.firstOrNull;
    if (stat != null) {
      _once(
        'stat',
        _quick ? 420 : 640,
        () => Sfx.instance.play('stat_${stat.index}'),
      );
    }
    if (plan.streakLine != null) {
      _once('streak', 780, () => Sfx.instance.play('streak'));
    }
    if (_held) _once('flourish', 1180, Haptics.flourish);
  }

  @override
  void dispose() {
    _autoReturn?.cancel();
    _exit.dispose();
    _c.dispose();
    super.dispose();
  }

  double _iv(double from, double to, [Curve curve = Curves.easeOutCubic]) {
    if (widget.reduceMotion) return 1;
    final ms = _ms;
    if (ms <= from) return 0;
    if (ms >= to) return 1;
    return curve.transform((ms - from) / (to - from));
  }

  /// 0 -> 0.9 by 380 ms, settling to 0.58 by 1.1 s (by 700 ms for the quick
  /// tier, so its last moment is still).
  double get _bloom {
    if (widget.reduceMotion) return 0.58;
    final open = Curves.easeOutCubic.transform((_ms / 380).clamp(0.0, 1.0));
    final settle = Curves.easeInOut.transform(
      ((_ms - 380) / (_quick ? 320 : 720)).clamp(0.0, 1.0),
    );
    return open * (0.9 - 0.32 * settle);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final width = mq.size.width;
    final layered = widget.backdrop == null && classRoomIsLayered(widget.state);
    return OverlaySurface(
      child: Semantics(
        key: const Key('class-kept-celebration'),
        button: true,
        liveRegion: true,
        // One label, read once: the words drawn on it are in the label.
        excludeSemantics: true,
        label: plan.semanticsLabel,
        hint: 'Tap to continue',
        onTap: _dismiss,
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (_) => _fingerDown = true,
          onPointerUp: (_) {
            _fingerDown = false;
            if (_returnOnRelease) _goBack();
          },
          onPointerCancel: (_) {
            _fingerDown = false;
            if (_returnOnRelease) _goBack();
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticFeedback.selectionClick();
              // The held tiers leave the way the others do: the words go,
              // the dim lifts and the takeover fades onto the room (which
              // may already be turning to the evening under it).
              _goBack();
            },
            child: AnimatedBuilder(
              animation: Listenable.merge([_c, _exit]),
              builder: (context, _) {
                final camera = widget.camera;
                final room =
                    (layered ? camera?.shot : null) ??
                    widget.fromShot ??
                    RoomShot.kept(width: width);
                final target = _hold
                    ? (widget.fromShot ?? room)
                    : RoomShot.kept(width: width);
                // The quick tier holds the kept framing: the camera already
                // made that move a moment ago, and a second swing at 1.5x is
                // a rush.
                final from = _quick ? target : room;
                // The takeover fades in over the room on the room's own
                // framing (so nothing doubles), then the camera eases back.
                final arrive = widget.reduceMotion
                    ? Curves.easeOut.transform(_c.value)
                    : _iv(110, 300, Curves.easeOut);
                // Going back on its own: the words leave first, the camera
                // eases home as the dim lifts, then the takeover fades onto
                // the room it now matches.
                final exit = _exit.value;
                final words = arrive * (1 - (exit / 0.4).clamp(0.0, 1.0));
                final home = widget.reduceMotion
                    ? 0.0
                    : Curves.easeInOut.transform((exit / 0.65).clamp(0.0, 1.0));
                final fadeOut = widget.reduceMotion
                    ? exit
                    : Curves.easeIn.transform(
                        ((exit - 0.5) / 0.5).clamp(0.0, 1.0),
                      );
                final takeover = arrive * (1 - fadeOut);
                final travel = _iv(220, 640, Curves.easeInOutCubic);
                final shot = RoomShot.lerp(
                  RoomShot.lerp(from, target, travel),
                  room,
                  home,
                );
                // The room's soft dark stays over the window (its keyed
                // glass) until the camera has moved the window out of frame,
                // and is back when the camera is.
                final scrim = widget.reduceMotion || _quick
                    ? 0.0
                    // Held in the evening, the window never leaves the frame.
                    : _hold
                    ? 1.0
                    : 1 - travel * (1 - home);
                final dim =
                    _iv(160, 560, Curves.easeOut) *
                    (1 - (widget.reduceMotion ? exit : home));
                final stageTop = camera?.stage?.top ?? widget.stageTop;
                final scrimHeight = camera?.scrimHeight ?? widget.scrimHeight;
                final lamp = layered
                    ? shot.toStage(RoomMarks.bulb).translate(0, stageTop)
                    : Offset(width * 0.32, stageTop + 140);
                final imageBottom = (962 - shot.top) * shot.scale;
                final plateHeight =
                    camera?.stage?.height ?? widget.stageHeight ?? 420;
                final plateFadeStart = camera?.fadeStart ?? widget.fadeStart;
                final plateFadeEnd = camera?.fadeEnd ?? widget.fadeEnd;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Opacity(
                      opacity: takeover,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          const ColoredBox(color: Palette.parchment),
                          Positioned(
                            left: 0,
                            right: 0,
                            top: stageTop,
                            height: layered ? imageBottom : plateHeight,
                            child: widget.backdrop != null
                                ? widget.backdrop!(
                                    context,
                                    stageTop,
                                    scrimHeight,
                                  )
                                : layered
                                ? ClassRoomStage(
                                    shot: shot,
                                    bloom: _bloom * (1 - home),
                                    warmth: 1,
                                    scrim: scrim,
                                    scrimHeight: scrimHeight,
                                    fadeStart: imageBottom - 150,
                                    fadeEnd: imageBottom - 2,
                                  )
                                // A painted plate holds still: the same box,
                                // scale and fades as the room's.
                                : ClassRoomPlate(
                                    state: widget.state,
                                    fadeStart:
                                        plateFadeStart ?? plateHeight - 140,
                                    fadeEnd: plateFadeEnd ?? plateHeight - 2,
                                    scrimHeight: scrimHeight,
                                  ),
                          ),
                          CustomPaint(
                            painter: _WalnutDim(
                              lamp: lamp,
                              dim: dim,
                              // The class cards' words rest low; the quest
                              // day's stand over the door, so the floor
                              // below them stays in sight, dimmed.
                              reach: widget.plan.xpRail ? 1.0 : 1.3,
                              base: widget.plan.xpRail ? 0 : 0.34,
                              wordsFrom: widget.plan.xpRail
                                  ? stageTop + imageBottom * 0.52
                                  : stageTop + plateHeight * 0.9,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_held && !widget.reduceMotion && exit == 0)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: _MotePainter(
                              t: _iv(900, 1700, Curves.linear),
                              origin: lamp.translate(70, 60),
                              count: plan.tier == ClassCelebrationTier.weekDone
                                  ? 30
                                  : 22,
                            ),
                          ),
                        ),
                      ),
                    Opacity(
                      opacity: words,
                      child: Padding(
                        padding: EdgeInsets.only(
                          top: mq.padding.top,
                          bottom: mq.padding.bottom,
                        ),
                        child: LayoutBuilder(
                          builder: (context, box) => SingleChildScrollView(
                            physics: const ClampingScrollPhysics(),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: box.maxHeight,
                              ),
                              child: _body(width),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(double width) {
    final quick = _quick;
    final children = <Widget>[
      _headline(),
      const SizedBox(height: 6),
      _diamond(),
      const SizedBox(height: 4),
      _rise(
        _iv(380, 760),
        Text(
          plan.numeralLabel,
          key: const Key('class-celebration-numeral-label'),
          textAlign: TextAlign.center,
          maxLines: 2,
          style: Type.label.copyWith(
            fontSize: Type.minLabel,
            letterSpacing: 2.0,
            color: Palette.xpLight,
          ),
        ),
      ),
      if (plan.title case final title?) ...[
        const SizedBox(height: 8),
        _rise(
          _iv(300, 760),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: _held ? 2 : 3,
              overflow: TextOverflow.ellipsis,
              style: LedgerType.body.copyWith(
                fontSize: quick ? 26 : (_held ? 27 : 30),
                fontWeight: FontWeight.w600,
                height: 1.06,
                color: Palette.textHi,
              ),
            ),
          ),
          distance: 16,
        ),
      ],
      if (plan.detail case final detail? when !_held) ...[
        const SizedBox(height: 5),
        _rise(
          _iv(420, 820),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: Type.label.copyWith(
              fontSize: Type.minLabel,
              letterSpacing: 0.9,
              color: Palette.textLo,
            ),
          ),
        ),
      ],
      // The day's rows, or only the full-day line when a later mark
      // completes a day whose day tier already played.
      if (plan.rows.isNotEmpty || plan.bonusLine != null) ...[
        const SizedBox(height: 12),
        _rows(),
      ],
      SizedBox(height: plan.rows.isEmpty ? 16 : 12),
      // The quick tier lands its count by about 500 ms, so its last 0.9 s
      // is still and the new count can be read. The quest day's card has no
      // XP of its own to count (its quests paid when they were kept).
      if (!plan.xpRail)
        const SizedBox.shrink()
      else if (quick)
        _XpToRail(
          plan: plan,
          width: width,
          appear: _iv(300, 420),
          count: _iv(300, 750, Curves.easeInQuad),
          thread: _iv(300, 700),
          chip: _iv(420, 700, Curves.easeOutBack),
        )
      else
        _XpToRail(
          plan: plan,
          width: width,
          appear: _iv(520, 640),
          count: _iv(520, 1170, Curves.easeInQuad),
          thread: _iv(520, 900),
          chip: _iv(640, 860, Curves.easeOutBack),
        ),
      if (plan.streakLine case final line?) ...[
        const SizedBox(height: 10),
        _rise(_iv(760, 1000), _streak(line)),
      ],
      SizedBox(height: plan.xpRail ? 14 : 12),
      _rise(
        // The quick tier's closing line arrives with its headline. With no XP
        // row to wait for, the held card's closes on its words.
        _held
            ? (plan.xpRail ? _iv(1500, 1850) : _iv(900, 1250))
            : quick
            ? _iv(140, 500)
            : _iv(900, 1250),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Text(
            plan.closing.join('\n'),
            key: const Key('class-celebration-closing'),
            textAlign: TextAlign.center,
            style: LedgerType.body.copyWith(
              fontSize: 19,
              height: 1.25,
              fontStyle: FontStyle.italic,
              color: Palette.textMid,
            ),
          ),
        ),
      ),
      if (!plan.xpRail && plan.pillXp > 0) ...[
        const SizedBox(height: 18),
        _rise(_iv(1150, 1450), _bonusPill(plan.pillXp)),
      ],
      const SizedBox(height: 22),
      Opacity(
        opacity:
            (_held
                ? (plan.xpRail ? _iv(1800, 2200) : _iv(1500, 1900))
                : quick
                ? _iv(500, 700)
                : _iv(1300, 1500)) *
            0.6,
        child: Text('onward →', style: Type.label.copyWith(fontSize: 11)),
      ),
      const SizedBox(height: 18),
    ];
    // The class cards rest on the floor of the room (their rows and XP rail
    // fill it); the quest day's has only its words, so it stands where the
    // prototype's tier card does, over the door, not alone at the bottom.
    return Column(
      mainAxisAlignment: plan.xpRail
          ? MainAxisAlignment.end
          : MainAxisAlignment.center,
      children: children,
    );
  }

  /// The one small pill under the closing line: a real full-day bonus, shown
  /// only when the engine paid one.
  Widget _bonusPill(int xp) => DecoratedBox(
    key: const Key('class-celebration-pill'),
    decoration: BoxDecoration(
      color: const Color(0x47785C2C),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0x8CDCB36C)),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 9),
      child: Text(
        '+$xp XP',
        style: Type.label.copyWith(
          fontSize: 15,
          letterSpacing: 2.0,
          color: Palette.xpLight,
        ),
      ),
    ),
  );

  Widget _rise(double t, Widget child, {double distance = 12}) => Opacity(
    opacity: t.clamp(0.0, 1.0),
    child: Transform.translate(
      offset: Offset(0, (1 - t) * distance),
      child: child,
    ),
  );

  /// Fraunces, slammed in on elasticOut at 140 to 770 ms, the way
  /// "YOU DID IT." lands.
  Widget _headline() {
    final slam = _iv(140, 770, Motion.slam);
    final quick = plan.tier == ClassCelebrationTier.quick;
    return Transform.scale(
      scale: 0.58 + 0.42 * slam,
      child: Opacity(
        opacity: slam.clamp(0.0, 1.0),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              plan.headline,
              key: const Key('class-celebration-headline'),
              textAlign: TextAlign.center,
              maxLines: 1,
              style: Type.display.copyWith(
                fontSize: quick ? 38 : 44,
                height: 1.05,
                fontWeight: FontWeight.w700,
                color: Palette.textHi,
                shadows: [
                  Shadow(
                    color: Palette.xpLight.withValues(alpha: 0.55),
                    blurRadius: 28 * slam.clamp(0.0, 1.0),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The numeral in the level-up's diamond, lit by the lamp from the upper
  /// left (one light field: the diamond has no glow of its own).
  ///
  /// The box is the rotated square's own height, so its points never reach
  /// into the headline or the label. The numeral is a drawn mark: it keeps
  /// its size at any text size and is fitted inside the diamond, so a count
  /// of 24 (or 124) sits within its edges like a count of 1.
  Widget _diamond() {
    final slam = _iv(260, 900, Motion.slam);
    final side = switch (plan.tier) {
      ClassCelebrationTier.quick => 76.0,
      ClassCelebrationTier.classKept => 100.0,
      _ => 84.0,
    };
    final extent = side * math.sqrt2;
    final numeral = '${plan.numeral}';
    final size = classNumeralSize(numeral, side);
    return SizedBox(
      height: extent + 12,
      child: Center(
        child: Transform.scale(
          scale: 0.4 + 0.6 * slam,
          child: Opacity(
            opacity: slam.clamp(0.0, 1.0),
            child: SizedBox.square(
              dimension: extent,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Transform.rotate(
                    angle: math.pi / 4,
                    child: Container(
                      width: side,
                      height: side,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Palette.xpLight.withValues(alpha: 0.2),
                            const Color(0x142E1C0D),
                            const Color(0x40100804),
                          ],
                          stops: const [0, 0.55, 1],
                        ),
                        border: Border.all(
                          color: Palette.xpLight.withValues(alpha: 0.38),
                        ),
                      ),
                    ),
                  ),
                  Text(
                    numeral,
                    key: const Key('class-celebration-numeral'),
                    textScaler: TextScaler.noScaling,
                    maxLines: 1,
                    softWrap: false,
                    style: _numeralStyle(size).copyWith(
                      shadows: [
                        Shadow(
                          color: Palette.xpLight.withValues(alpha: 0.5),
                          blurRadius: 26 * slam.clamp(0.0, 1.0),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _rows() {
    final rows = <Widget>[];
    for (var i = 0; i < plan.rows.length; i++) {
      final row = plan.rows[i];
      rows.add(
        _rise(
          _iv(700 + i * 85.0, 1000 + i * 85.0),
          SizedBox(
            height: 27,
            child: Row(
              children: [
                QuestCheckRing(
                  stat: row.stat,
                  done: true,
                  size: 20,
                  reduceMotion: true,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    row.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: LedgerType.body.copyWith(
                      fontSize: 17,
                      color: row.marked ? Palette.textHi : Palette.textMid,
                    ),
                  ),
                ),
                Text(
                  row.time,
                  style: Type.label.copyWith(
                    fontSize: Type.minLabel,
                    color: Palette.textLo,
                  ),
                ),
                SizedBox(
                  width: 44,
                  child: Text(
                    '+${row.xp}',
                    textAlign: TextAlign.right,
                    style: Type.numerals.copyWith(
                      fontSize: 15,
                      color: Palette.xp,
                    ),
                  ),
                ),
              ],
            ),
          ),
          distance: 8,
        ),
      );
    }
    if (plan.bonusLine case final line?) {
      rows.add(
        _rise(
          _iv(1000, 1260),
          SizedBox(
            height: 25,
            child: Row(
              children: [
                const SizedBox(width: 30),
                Expanded(
                  child: Text(
                    line,
                    key: const Key('class-celebration-bonus'),
                    style: LedgerType.body.copyWith(
                      fontSize: 16,
                      fontStyle: FontStyle.italic,
                      color: Palette.textLo,
                    ),
                  ),
                ),
                SizedBox(
                  width: 44,
                  child: Text(
                    '+${plan.bonusXp}',
                    textAlign: TextAlign.right,
                    style: Type.numerals.copyWith(
                      fontSize: 15,
                      color: Palette.xp,
                    ),
                  ),
                ),
              ],
            ),
          ),
          distance: 8,
        ),
      );
    }
    final line = _iv(650, 900);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 34),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: Palette.brass.withValues(alpha: 0.3 * line)),
            bottom: BorderSide(
              color: Palette.brass.withValues(alpha: 0.3 * line),
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(children: rows),
        ),
      ),
    );
  }

  Widget _streak(String text) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Transform.rotate(
        angle: math.pi / 4,
        child: Container(width: 7, height: 7, color: Palette.streak),
      ),
      const SizedBox(width: 10),
      Flexible(
        child: Text(
          text,
          style: Type.label.copyWith(
            fontSize: Type.minLabel,
            letterSpacing: 1.4,
            color: Palette.streak,
          ),
        ),
      ),
    ],
  );
}

/// "+25 XP" counting up, a thread drawn from it into the level rail (the
/// app's XP thread: domain colour turning honey, a diamond growing at the
/// rail's head), and the stat chip.
class _XpToRail extends StatelessWidget {
  const _XpToRail({
    required this.plan,
    required this.width,
    required this.appear,
    required this.count,
    required this.thread,
    required this.chip,
  });

  final ClassCelebrationPlan plan;
  final double width;
  final double appear;
  final double count;
  final double thread;
  final double chip;

  static const _side = 40.0;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final shownXp =
        plan.xpFrom + ((plan.xpShown - plan.xpFrom) * count).round();
    final need = plan.xpForNextLevel;
    final before = plan.xpBefore;
    final after = before + plan.xpGained;
    final railValue = before + (after - before) * count;
    final ready = railValue >= need;
    double textW(String t, TextStyle style) => (TextPainter(
      text: TextSpan(text: t, style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      maxLines: 1,
    )..layout()).width;
    final w = width - _side * 2;
    final xpW = textW('+${plan.xpShown} XP', _xpStyle);
    var chipsW = 0.0;
    for (final stat in plan.gains.keys) {
      chipsW +=
          4 +
          10 +
          scaler.scale(15) +
          6 +
          7 +
          12 +
          textW('+${plan.gains[stat]} ${stat.abbr}', _chipLabel) +
          textW('${plan.totals[stat]}', _chipTotal);
    }
    final rowW = math.min(w, xpW + 14 + chipsW);
    final xpCentre = (w - rowW) / 2 + xpW / 2;
    final topRow = math.max(50.0, scaler.scale(40) + 10);
    final railY = topRow + 24;
    const railLeft = 40.0;
    final railRight = w - 112;
    final head =
        railLeft + (railRight - railLeft) * math.min(1, railValue / need);
    return Opacity(
      opacity: appear,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: _side),
        child: SizedBox(
          height: railY + 14 + (plan.caption == null ? 6 : 24),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: topRow,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '+$shownXp XP',
                        key: const Key('class-celebration-xp'),
                        style: _xpStyle,
                      ),
                      const SizedBox(width: 14),
                      for (final stat in plan.gains.keys)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Opacity(
                            opacity: chip.clamp(0.0, 1.0),
                            child: Transform.scale(
                              scale: 0.8 + 0.2 * chip,
                              child: _StatChip(
                                stat: stat,
                                gain: plan.gains[stat]!,
                                total: plan.totals[stat]!,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _ThreadPainter(
                      from: Offset(xpCentre, topRow - 4),
                      to: Offset(head, railY + 4),
                      t: thread,
                      domain: plan.gains.keys.firstOrNull?.color ?? Palette.xp,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: railY - 4,
                child: Row(
                  children: [
                    Text(
                      'LV',
                      style: Type.label.copyWith(
                        fontSize: Type.minLabel,
                        color: Palette.textLo,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${plan.level}',
                      maxLines: 1,
                      softWrap: false,
                      style: Type.numerals.copyWith(
                        fontSize: 16,
                        height: 1,
                        color: Palette.textHi,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: SizedBox(
                        height: 8,
                        child: CustomPaint(
                          painter: _RailPainter(
                            before / need,
                            math.min(1, railValue / need),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 112,
                      child: Text(
                        ready
                            ? 'LEVEL ${plan.level + 1} READY'
                            : '${railValue.round()} / $need',
                        key: const Key('class-celebration-rail'),
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.fade,
                        style: Type.label.copyWith(
                          fontSize: Type.minLabel,
                          letterSpacing: 0.2,
                          color: Palette.xpLight.withValues(alpha: 0.88),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (plan.caption case final caption?)
                Positioned(
                  left: 0,
                  right: 0,
                  top: railY + 14,
                  child: Text(
                    caption,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Type.label.copyWith(
                      fontSize: Type.minLabel,
                      letterSpacing: 1.2,
                      color: Palette.textLo,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

final _xpStyle = Type.numerals.copyWith(
  fontSize: 40,
  height: 1,
  color: Palette.xpLight,
  shadows: const [
    Shadow(color: Color(0x5AE0A865), blurRadius: 14, offset: Offset(0, 2)),
  ],
);
final _chipLabel = Type.label.copyWith(fontSize: 12, letterSpacing: 1.0);
final _chipTotal = Type.numerals.copyWith(fontSize: 14);

class _ThreadPainter extends CustomPainter {
  _ThreadPainter({
    required this.from,
    required this.to,
    required this.t,
    required this.domain,
  });

  final Offset from;
  final Offset to;
  final double t;
  final Color domain;

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0) return;
    final path = Path()
      ..moveTo(from.dx, from.dy)
      ..cubicTo(from.dx, from.dy + 16, to.dx, to.dy - 18, to.dx, to.dy);
    final metric = path.computeMetrics().first;
    final drawn = metric.extractPath(0, metric.length * t);
    final shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [domain, Palette.xpLight, Palette.xpLight],
      stops: const [0, 0.22, 1],
    ).createShader(Rect.fromPoints(from, to).inflate(6));
    canvas.drawPath(
      drawn,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4)
        ..color = Palette.xp.withValues(alpha: 0.35 * (1 - t * 0.5)),
    );
    canvas.drawPath(
      drawn,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.55
        ..strokeCap = StrokeCap.round
        ..shader = shader,
    );
    if (t > 0.7) {
      final grow = ((t - 0.7) / 0.3).clamp(0.0, 1.0);
      final side = 3 + 5 * grow;
      canvas.save();
      canvas.translate(to.dx, to.dy);
      canvas.rotate(math.pi / 4);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: side, height: side),
        Paint()..color = Palette.xpLight,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ThreadPainter old) =>
      old.t != t || old.from != from || old.to != to || old.domain != domain;
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.stat,
    required this.gain,
    required this.total,
  });

  final Stat stat;
  final int gain;
  final int total;

  @override
  Widget build(BuildContext context) => Container(
    key: Key('class-celebration-stat-${stat.name}'),
    padding: const EdgeInsets.fromLTRB(10, 7, 12, 7),
    decoration: facetedDecoration(
      cut: 8,
      color: const Color(0x661A120E),
      borderColor: stat.color.withValues(alpha: 0.55),
      borderWidth: 1,
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(stat.icon, size: 15, color: stat.color),
        const SizedBox(width: 6),
        Text(
          '+$gain ${stat.abbr}',
          style: _chipLabel.copyWith(color: stat.color),
        ),
        const SizedBox(width: 7),
        Text('$total', style: _chipTotal.copyWith(color: Palette.textMid)),
      ],
    ),
  );
}

class _RailPainter extends CustomPainter {
  _RailPainter(this.before, this.value);

  final double before;
  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(4),
    );
    canvas.drawRRect(r, Paint()..color = Palette.railTrack);
    canvas.drawRRect(
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = Palette.railRim,
    );
    final w = size.width * value.clamp(0.0, 1.0);
    if (w <= 0) return;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, w, size.height),
        const Radius.circular(4),
      ),
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFB98345), Color(0xFFE0A865), Color(0xFFF2CD93)],
        ).createShader(Rect.fromLTWH(0, 0, math.max(w, 1), size.height)),
    );
    final bx = size.width * before.clamp(0.0, 1.0);
    if (w > bx + 1) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(bx, 0, w - bx, size.height),
          const Radius.circular(4),
        ),
        Paint()
          ..color = const Color(0x66FFF4D9)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
  }

  @override
  bool shouldRepaint(_RailPainter old) =>
      old.value != value || old.before != before;
}

/// The level-up's walnut night, centred between the lamp and the desk: the
/// room stays visible where the lamp reaches and falls to near-black where
/// the words sit. No blur.
class _WalnutDim extends CustomPainter {
  _WalnutDim({
    required this.lamp,
    required this.dim,
    required this.wordsFrom,
    this.reach = 1.0,
    this.base = 0,
  });

  final Offset lamp;
  final double dim;

  /// How far the lamp's pool of light reaches (1: the class cards', whose
  /// words sit in the dark below; larger: the quest day's, whose words stand
  /// over the door and leave the floor in dim sight).
  final double reach;

  /// A still, even darkening under the pool of light (0: none), so a card
  /// whose words stand over the room can still be read there.
  final double base;

  /// Below this line the words sit in walnut night.
  final double wordsFrom;

  @override
  void paint(Canvas canvas, Size size) {
    if (dim <= 0) return;
    final rect = Offset.zero & size;
    if (base > 0) {
      canvas.drawRect(
        rect,
        Paint()..color = const Color(0xFF110905).withValues(alpha: base * dim),
      );
    }
    final centre = lamp.translate(70, 40);
    final align = Alignment(
      (centre.dx / size.width) * 2 - 1,
      (centre.dy / size.height) * 2 - 1,
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: align,
          radius: 1.32 * reach,
          colors: [
            const Color(0xFF3B2514).withValues(alpha: 0.10 * dim),
            const Color(0xFF22150B).withValues(alpha: 0.66 * dim),
            const Color(0xFF110905).withValues(alpha: 0.95 * dim),
          ],
          stops: const [0, 0.42, 0.9],
        ).createShader(rect),
    );
    final start = (wordsFrom / size.height).clamp(0.0, 0.9);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0x00140C07),
            const Color(0xFF140C07).withValues(alpha: 0.62 * dim),
            const Color(0xFF110905).withValues(alpha: 0.9 * dim),
          ],
          stops: [
            start,
            (start + 0.08).clamp(0.0, 1.0),
            (start + 0.24).clamp(0.0, 1.0),
          ],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_WalnutDim old) =>
      old.dim != dim ||
      old.lamp != lamp ||
      old.wordsFrom != wordsFrom ||
      old.reach != reach ||
      old.base != base;
}

/// Round honey motes that rise from the lamp-lit desk for the day and week
/// tiers, never confetti that falls. Gone before the moment settles. Seeded,
/// so every render is the same.
class _MotePainter extends CustomPainter {
  _MotePainter({required this.t, required this.origin, required this.count});

  final double t;
  final Offset origin;
  final int count;

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;
    final rng = math.Random(count);
    final fade = (1 - t).clamp(0.0, 1.0);
    final paint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6);
    for (var i = 0; i < count; i++) {
      final angle = -math.pi / 2 + (rng.nextDouble() - 0.5) * 1.6;
      final speed = (0.35 + rng.nextDouble()) * 90;
      final radius = 1.4 + rng.nextDouble() * 2.2;
      final spin = (rng.nextDouble() - 0.5) * 6;
      final delay = rng.nextDouble() * 0.35;
      final local = ((t - delay) / (1 - delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final travel = 1 - math.pow(1 - local, 3).toDouble();
      final lift = 90.0 * travel;
      final flick = math.sin(local * 7 + spin) * 4 * local;
      final v = Offset(math.cos(angle), math.sin(angle) * 0.5);
      final pos = origin + v * speed * travel * 0.6 + Offset(flick, -lift);
      final colour = i % 3 == 0
          ? const Color(0xFFFFF4D9)
          : i % 3 == 1
          ? Palette.xpLight
          : Palette.xp;
      paint.color = colour.withValues(alpha: fade * 0.75);
      canvas.drawCircle(pos, radius * (0.6 + 0.5 * fade), paint);
    }
  }

  @override
  bool shouldRepaint(_MotePainter old) => old.t != t || old.origin != origin;
}

TextStyle _numeralStyle(double size) =>
    Type.numerals.copyWith(fontSize: size, height: 1, color: Palette.xpLight);

/// The numeral's size inside a diamond of [side] (a square turned 45
/// degrees): as large as its digit count allows, and never so large that its
/// corners cross the diamond's edges. A text box of width w and figure height
/// about 0.72 of its size fits when w / 2 + 0.36 size stays inside the
/// half-diagonal, less a margin for the border.
@visibleForTesting
double classNumeralSize(String numeral, double side) {
  final digits = numeral.length;
  final preferred = side * (digits <= 1 ? 0.86 : (digits == 2 ? 0.74 : 0.6));
  final probe = TextPainter(
    text: TextSpan(text: numeral, style: _numeralStyle(100)),
    textDirection: TextDirection.ltr,
    textScaler: TextScaler.noScaling,
    maxLines: 1,
  )..layout();
  final ratio = probe.width / 100;
  probe.dispose();
  final reach = side * math.sqrt1_2 - side * 0.09;
  final fit = reach / (ratio / 2 + 0.36);
  return math.min(preferred, fit);
}
