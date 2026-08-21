import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../audio.dart';
import '../content/evidence.dart';
import '../content/routines.dart';
import '../engine.dart';
import '../haptics.dart';
import '../tokens.dart';
import 'facets.dart';
import 'glass.dart';
import 'honey_button.dart';
import 'workout_pose.dart';

/// The guided-workout runner (RESEARCH-workouts.md). A full-screen overlay
/// (mirrors NightFlow) that walks a beginner through a curated [Routine] one
/// move at a time — reps via a slow-tap honor counter, holds/cardio via a
/// pausable countdown ring — with EASIER / SKIP / PAUSE / End-early on every
/// move. It NEVER rewards itself: it only reports the outcome via [onFinish],
/// and the Quests page runs the real reward through the existing engine.
class WorkoutFlow extends StatefulWidget {
  const WorkoutFlow({
    super.key,
    required this.state,
    required this.recommended,
    required this.onFinish,
    required this.onClose,
  });

  final GameState state;

  /// The routine recommended by the launcher quest's current rung (shown
  /// first / highlighted); the picker offers all of them.
  final Routine recommended;

  /// Reports a completed (or early-ended) session.
  final void Function({
    required Routine routine,
    required bool verified,
    required bool endedEarly,
    required int workMovesDone,
  })
  onFinish;

  /// Closed without finishing (no reward).
  final VoidCallback onClose;

  @override
  State<WorkoutFlow> createState() => _WorkoutFlowState();
}

class _WorkoutFlowState extends State<WorkoutFlow> {
  Routine? _routine; // null → picker
  int _i = -1; // -1 → preview; 0..n-1 → moves
  bool _resting = false;
  bool _paused = false;
  bool _relaxed = false; // pace toggle (longer rests)
  bool _ended = false;

  int _remaining = 0; // countdown seconds (timed move / rest)
  int _total = 0;
  Timer? _ticker;

  int _repCount = 0;
  final Set<int> _easiered = {};

  bool _anyVerified = false; // a timed WORK move finished on its countdown
  int _workDone = 0;

  List<WorkoutMove> get _moves => _routine!.moves;
  WorkoutMove get _move => _moves[_i];

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  // ── countdown engine (pausable) ──────────────────────────────────
  void _startCountdown(int seconds, VoidCallback onZero) {
    _ticker?.cancel();
    _total = seconds;
    _remaining = seconds;
    _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_paused) return;
      setState(() => _remaining--);
      if (_remaining <= 0) {
        t.cancel();
        Haptics.success();
        Sfx.instance.play('tick');
        onZero();
      }
    });
  }

  // ── flow control ─────────────────────────────────────────────────
  void _pick(Routine r) {
    Sfx.instance.playMaterial(MaterialSound.parchment);
    Haptics.tap();
    setState(() {
      _routine = r;
      _i = -1;
    });
  }

  void _begin() {
    _startMove(0);
  }

  void _startMove(int i) {
    setState(() {
      _i = i;
      _resting = false;
      _repCount = 0;
    });
    if (_move.kind == MoveKind.timed) {
      _startCountdown(_move.seconds, _onTimedZero);
    } else {
      _ticker?.cancel();
    }
  }

  void _onTimedZero() {
    if (_move.isWork) _anyVerified = true;
    _onMoveDone();
  }

  /// Called when the current move is finished (reps DONE, timed countdown, or
  /// the "I already did it" honor path).
  void _onMoveDone() {
    if (_move.isWork) _workDone++;
    Haptics.light();
    final rest = _resting ? 0 : _move.restSeconds;
    final hasNext = _i + 1 < _moves.length;
    if (rest > 0 && hasNext) {
      setState(() => _resting = true);
      _startCountdown((rest * (_relaxed ? 1.4 : 1.0)).round(), _next);
    } else {
      _next();
    }
  }

  /// Skip the current move (and its rest) — no penalty, no credit.
  void _skip() {
    Sfx.instance.playMaterial(MaterialSound.parchment);
    _next();
  }

  void _next() {
    _ticker?.cancel();
    final to = _i + 1;
    if (to >= _moves.length) {
      _finish(endedEarly: false);
    } else {
      _startMove(to);
    }
  }

  void _finish({required bool endedEarly}) {
    if (_ended) return;
    _ended = true;
    _ticker?.cancel();
    widget.onFinish(
      routine: _routine!,
      verified: _anyVerified,
      endedEarly: endedEarly,
      workMovesDone: _workDone,
    );
  }

  void _togglePause({bool alreadyAcknowledged = false}) {
    setState(() => _paused = !_paused);
    if (!alreadyAcknowledged) {
      Sfx.instance.playMaterial(MaterialSound.wood);
    }
  }

  // ── build ────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final Widget body;
    if (_routine == null) {
      body = _picker();
    } else if (_paused) {
      body = _pausedScreen();
    } else if (_i == -1) {
      body = _preview();
    } else if (_resting) {
      body = _restScreen();
    } else {
      body = _moveScreen();
    }
    final still =
        widget.state.reduceMotion ||
        (MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    final media = MediaQuery.of(context);
    return OverlaySurface(
      child: WarmBackground(
        themeId: widget.state.canvasTheme,
        tint: (_routine ?? widget.recommended).stat.color,
        reduceMotion: still,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            // WorkoutFigure also reads the platform preference. Mirroring the
            // in-app switch into MediaQuery parks its breath on the authored
            // still, while the countdown itself continues to function.
            child: MediaQuery(
              data: media.copyWith(disableAnimations: still),
              child: TickerMode(
                enabled: !still,
                child: AnimatedSwitcher(
                  duration: still
                      ? Duration.zero
                      : const Duration(milliseconds: 240),
                  // Never lay out the outgoing full-screen scene. The old
                  // default cross-fade stacked two transparent pages for
                  // 420ms, producing unreadable title/card collisions and
                  // stale hit targets.
                  layoutBuilder: (currentChild, previousChildren) =>
                      currentChild ?? const SizedBox.shrink(),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: CurvedAnimation(
                      parent: animation,
                      curve: const Interval(
                        0.18,
                        1,
                        curve: Curves.easeOutCubic,
                      ),
                    ),
                    child: SlideTransition(
                      position:
                          Tween<Offset>(
                            begin: const Offset(0.035, 0),
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutCubic,
                            ),
                          ),
                      child: child,
                    ),
                  ),
                  child: body,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── picker ───────────────────────────────────────────────────────
  Widget _picker() {
    return ListView(
      key: const ValueKey('picker'),
      children: [
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('MOVE', style: Type.label.copyWith(fontSize: 11)),
            IconButton(
              tooltip: 'Close workouts',
              onPressed: widget.onClose,
              constraints: const BoxConstraints.tightFor(width: 48, height: 48),
              icon: const Icon(Icons.close, size: 22, color: Palette.textLo),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text('Pick a session', style: Type.display.copyWith(fontSize: 28)),
        const SizedBox(height: 4),
        Text(
          'gentle, guided, and yours to leave anytime — no gym required',
          style: Type.body.copyWith(
            fontSize: 13.5,
            fontStyle: FontStyle.italic,
            color: Palette.textLo,
          ),
        ),
        const SizedBox(height: 16),
        for (final r in routines)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _routineTile(r, r.id == widget.recommended.id),
          ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            'general fitness guidance — not medical advice',
            style: Type.label.copyWith(fontSize: 11),
          ),
        ),
      ],
    );
  }

  Widget _routineTile(Routine r, bool recommended) {
    return GestureDetector(
      onTap: () => _pick(r),
      child: GlassPanel(
        glow: recommended,
        child: Row(
          children: [
            FacetMedallion(
              size: 40,
              accent: r.stat.color,
              child: Icon(
                r.restDay ? Icons.self_improvement : Icons.fitness_center,
                size: 19,
                color: r.stat.color,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          r.title,
                          overflow: TextOverflow.ellipsis,
                          style: Type.display.copyWith(fontSize: 16),
                        ),
                      ),
                      if (recommended) ...[
                        const SizedBox(width: 6),
                        Text(
                          'FOR YOU',
                          style: Type.label.copyWith(
                            fontSize: 11,
                            color: Palette.xpLight,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '~${r.minutes} min · ${r.workMoves} moves · ${r.stat.abbr}'
                    '${r.restDay ? " · rest day" : ""}',
                    style: Type.label.copyWith(fontSize: 11),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    r.restDay
                        ? 'MOBILITY · GENTLE PACE'
                        : r.minutes <= 4
                        ? 'QUICK START · NO EQUIPMENT'
                        : 'GUIDED · NO EQUIPMENT',
                    style: Type.label.copyWith(
                      fontSize: Type.minLabel,
                      color: recommended ? Palette.xpLight : Palette.textLo,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: Palette.textLo),
          ],
        ),
      ),
    );
  }

  // ── preview ──────────────────────────────────────────────────────
  Widget _preview() {
    final r = _routine!;
    final card = evidenceByTitle(r.evidenceTitle);
    final safetyLine = r.restDay
        ? 'Move slowly, breathe normally, and stay in a comfortable range — no bouncing, no pushing through pain. Sharp or sudden pain, chest pain, dizziness, or feeling unwell? Stop now.'
        : 'Muscle burn and next-day soreness are normal — that’s your body adapting. Sharp or sudden pain, chest pain, or dizziness? Stop now.';
    return ListView(
      key: const ValueKey('preview'),
      children: [
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => setState(() => _routine = null),
          child: Row(
            children: [
              const Icon(Icons.chevron_left, size: 18, color: Palette.textLo),
              Text('choose another', style: Type.label.copyWith(fontSize: 11)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(r.title, style: Type.display.copyWith(fontSize: 28)),
        const SizedBox(height: 4),
        Text(
          '~${r.minutes} min · start smaller than you think',
          style: Type.label.copyWith(fontSize: 11),
        ),
        const SizedBox(height: 10),
        Text(
          r.blurb,
          style: Type.body.copyWith(
            fontSize: 13.5,
            fontStyle: FontStyle.italic,
            color: Palette.textMid,
          ),
        ),
        const SizedBox(height: 14),
        GlassPanel(
          child: SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'YOUR ROUTE',
                  style: Type.label.copyWith(fontSize: 11, color: r.stat.color),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final move in r.moves.where((m) => m.isWork))
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: facetedDecoration(
                          cut: 6,
                          color: r.stat.color.withValues(alpha: 0.10),
                          borderColor: r.stat.color.withValues(alpha: 0.28),
                        ),
                        child: Text(
                          move.name,
                          style: Type.body.copyWith(
                            fontSize: 11.5,
                            color: Palette.textMid,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (card != null)
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_stories, size: 13, color: r.stat.color),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'WHY THIS WORKS',
                        maxLines: 2,
                        style: Type.label.copyWith(
                          fontSize: 11,
                          color: Palette.info,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(card.title, style: Type.display.copyWith(fontSize: 15)),
                const SizedBox(height: 4),
                Text(
                  card.text,
                  style: Type.body.copyWith(
                    fontSize: 13.5,
                    height: 1.45,
                    color: Palette.textMid,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        GlassPanel(
          child: LayoutBuilder(
            builder: (context, bounds) {
              final compact =
                  bounds.maxWidth < 340 ||
                  MediaQuery.textScalerOf(context).scale(1) > 1.3;
              final relaxed = _paceChip(
                'Relaxed',
                _relaxed,
                () => setState(() => _relaxed = true),
              );
              final steady = _paceChip(
                'Steady',
                !_relaxed,
                () => setState(() => _relaxed = false),
              );
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.speed,
                          size: 15,
                          color: Palette.xpLight,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'PACE',
                            style: Type.label.copyWith(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [relaxed, steady],
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  const Icon(Icons.speed, size: 15, color: Palette.xpLight),
                  const SizedBox(width: 8),
                  Text('PACE', style: Type.label.copyWith(fontSize: 11)),
                  const Spacer(),
                  relaxed,
                  const SizedBox(width: 6),
                  steady,
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        GlassPanel(
          child: Text(
            safetyLine,
            style: Type.body.copyWith(
              fontSize: 11.5,
              fontStyle: FontStyle.italic,
              color: Palette.textLo,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Center(child: _bigButton("LET’S BEGIN", _begin)),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: widget.onClose,
            child: Text('not now', style: Type.label.copyWith(fontSize: 11)),
          ),
        ),
      ],
    );
  }

  Widget _paceChip(String label, bool on, VoidCallback onTap) {
    return Semantics(
      button: true,
      selected: on,
      label: '$label pace',
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          alignment: Alignment.center,
          decoration: facetedDecoration(
            cut: 6,
            color: on ? Palette.xpLight.withValues(alpha: 0.2) : null,
            borderColor: on
                ? Palette.xpLight.withValues(alpha: 0.7)
                : Palette.glassEdge,
          ),
          child: Text(
            label,
            style: Type.label.copyWith(
              fontSize: 11,
              color: on ? Palette.xpLight : Palette.textLo,
            ),
          ),
        ),
      ),
    );
  }

  // ── move screen ──────────────────────────────────────────────────
  Widget _moveScreen() {
    final m = _move;
    // Captured so a stale/rapid tap can never advance a second time. The scene
    // switch no longer keeps outgoing pages in layout, but this guard remains
    // cheap insurance for repeated taps on the live control.
    final idx = _i;
    final easier = _easiered.contains(_i);
    final kicker = m.isWarmup
        ? 'WARM-UP'
        : m.isCooldown
        ? 'COOL-DOWN'
        : 'MOVE ${_i + 1} OF ${_moves.length}';
    return LayoutBuilder(
      key: ValueKey('move-$_i'),
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final baseStageHeight = constraints.maxHeight < 700
            ? 252.0
            : (constraints.maxHeight * 0.37).clamp(286.0, 324.0);
        // Large text is allowed to make the whole page scroll. The movement
        // plate grows with it instead of shrinking the timer or count label.
        final stageHeight =
            baseStageHeight + ((textScale - 1).clamp(0.0, 2.0) * 160);
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              children: [
                const SizedBox(height: 2),
                _sessionProgressHeader(),
                const SizedBox(height: 10),
                Text(
                  kicker,
                  style: Type.label.copyWith(
                    fontSize: 11,
                    color: m.isWork ? _routine!.stat.color : Palette.textLo,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  easier ? '${m.name} · easier' : m.name,
                  textAlign: TextAlign.center,
                  style: Type.display.copyWith(fontSize: 26),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: stageHeight,
                  child: _movementPlate(m),
                ),
                const SizedBox(height: 12),
                GlassPanel(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 13),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        easier ? 'EASIER VERSION' : 'FORM',
                        style: Type.label.copyWith(
                          fontSize: 11,
                          color: easier ? Palette.xpLight : Palette.textLo,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        easier ? m.easier : m.cue,
                        style: Type.body.copyWith(
                          fontSize: 15,
                          height: 1.35,
                          color: Palette.textHi,
                        ),
                      ),
                      if (m.caution != null) ...[
                        const SizedBox(height: 7),
                        Text(
                          m.caution!,
                          style: Type.body.copyWith(
                            fontSize: 13,
                            height: 1.35,
                            fontStyle: FontStyle.italic,
                            color: Palette.textLo,
                          ),
                        ),
                      ],
                      if (_i + 1 < _moves.length) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.only(top: 9),
                          decoration: const BoxDecoration(
                            border: Border(
                              top: BorderSide(color: Color(0x24F2CD93)),
                            ),
                          ),
                          child: Text(
                            'NEXT · ${_moves[_i + 1].name}',
                            style: Type.label.copyWith(
                              fontSize: 11,
                              color: Palette.xpLight,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (!easier)
                      _smallButton('EASIER', Palette.xpLight, () {
                        if (idx != _i) return;
                        Sfx.instance.playMaterial(MaterialSound.wood);
                        Haptics.tap();
                        setState(() => _easiered.add(idx));
                      }),
                    _smallButton('SKIP', Palette.textLo, () {
                      if (idx != _i) return;
                      _skip();
                    }),
                  ],
                ),
                const SizedBox(height: 8),
                if (m.kind == MoveKind.reps)
                  _bigButton('DONE →', () {
                    if (idx != _i) return;
                    _onMoveDone();
                  })
                else
                  _smallButton(
                    'FINISHED THIS MOVE',
                    Palette.xpLight,
                    () {
                      if (idx != _i) return;
                      _onMoveDone();
                    },
                    key: const ValueKey('workout-finish-early'),
                  ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sessionProgressHeader() {
    final accent = _routine!.stat.color;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'SESSION PROGRESS',
                      maxLines: 2,
                      style: Type.label.copyWith(fontSize: 11),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_i + 1} / ${_moves.length}',
                    style: Type.label.copyWith(fontSize: 11, color: accent),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              FacetedMeter(
                value: (_i + 1) / _moves.length,
                height: 6,
                color: accent,
                background: Palette.railTrack,
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Tooltip(
          message: 'Pause session',
          child: Semantics(
            button: true,
            label: 'Pause session',
            onTap: _togglePause,
            excludeSemantics: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _togglePause,
              child: Container(
                key: const ValueKey('workout-pause'),
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: facetedDecoration(
                  cut: 9,
                  color: Palette.cardGlass,
                  borderColor: Palette.brass.withValues(alpha: 0.7),
                ),
                child: const Icon(
                  Icons.pause_rounded,
                  size: 23,
                  color: Palette.textMid,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _movementPlate(WorkoutMove m) {
    final accent = _routine!.stat.color;
    final counterLabel = m.kind == MoveKind.timed
        ? 'GUIDED TIMER'
        : 'TAP COUNTER';
    final totalLabel = m.kind == MoveKind.timed
        ? '${m.seconds} SEC'
        : '${m.reps} REPS';
    return GlassPanel(
      radius: 22,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 13),
      tint: Color.alphaBlend(
        accent.withValues(alpha: 0.055),
        const Color(0xF21A120E),
      ),
      child: Column(
        children: [
          Row(
            children: [
              FacetMedallion(
                size: 32,
                accent: accent,
                child: Icon(_routine!.stat.icon, size: 16, color: accent),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  '${_routine!.stat.abbr} · $counterLabel',
                  style: Type.label.copyWith(fontSize: 11, color: accent),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                totalLabel,
                style: Type.label.copyWith(
                  fontSize: 11,
                  color: Palette.textMid,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Palette.brass.withValues(alpha: 0.6),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: m.kind == MoveKind.timed ? _timedBody(m) : _repsBody(m),
          ),
        ],
      ),
    );
  }

  /// The figure is carved out of the room's own light, not painted in the raw
  /// domain hue — at 148 px on a near-black screen, BODY rose read as a pink
  /// plastic mannequin. Pulling it toward honey keeps the domain legible and
  /// puts the one large illustrated object back inside the candlelit palette.
  static Color _figureTone(Color statColor) =>
      Color.lerp(statColor, Palette.xp, 0.42)!;

  Widget _timedBody(WorkoutMove m) {
    final progress = _total == 0
        ? 1.0
        : (1 - _remaining / _total).clamp(0.0, 1.0);
    final accent = _routine!.stat.color;
    return Semantics(
      container: true,
      label: '$_remaining seconds remaining',
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final ringSize = math
                    .min(constraints.maxWidth, constraints.maxHeight)
                    .clamp(112.0, 204.0);
                return Center(
                  child: SizedBox.square(
                    dimension: ringSize,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox.expand(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  Color.lerp(
                                    accent,
                                    Palette.xp,
                                    0.42,
                                  )!.withValues(alpha: 0.16),
                                  Palette.warmShadow.withValues(alpha: 0.03),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SizedBox.expand(
                          child: CircularProgressIndicator(
                            value: progress,
                            strokeWidth: 7,
                            strokeCap: StrokeCap.round,
                            backgroundColor: const Color(0x33F2CD93),
                            color: Color.lerp(accent, Palette.xpLight, 0.30),
                          ),
                        ),
                        WorkoutFigure(
                          pose: poseForMove(m.name),
                          color: _figureTone(accent),
                          size: ringSize * 0.64,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 5),
          _counterPlate(
            value: '$_remaining',
            label: 'SECONDS LEFT',
            color: Color.lerp(accent, Palette.xpLight, 0.32)!,
          ),
        ],
      ),
    );
  }

  Widget _repsBody(WorkoutMove m) {
    final target = m.reps;
    final reached = _repCount >= target;
    final VoidCallback? countRep = reached
        ? null
        : () {
            Haptics.tap();
            Sfx.instance.playMaterial(MaterialSound.wood);
            setState(() => _repCount++);
          };
    return Semantics(
      container: true,
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final figureSize = math
                    .min(constraints.maxWidth, constraints.maxHeight)
                    .clamp(112.0, 180.0);
                return Center(
                  child: Semantics(
                    button: true,
                    enabled: !reached,
                    label: reached
                        ? '$target repetitions counted'
                        : 'Count one repetition. $_repCount of $target counted',
                    onTap: countRep,
                    excludeSemantics: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: countRep,
                      child: SizedBox.square(
                        dimension: figureSize,
                        child: WorkoutFigure(
                          pose: poseForMove(m.name),
                          color: reached
                              ? Palette.success
                              : _figureTone(_routine!.stat.color),
                          size: figureSize,
                          bump: _repCount,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 5),
          _counterPlate(
            value: '$_repCount / $target',
            label: reached
                ? 'READY FOR DONE'
                : m.perSide
                ? 'EACH SIDE · TAP FIGURE'
                : 'TAP FIGURE TO COUNT',
            color: reached ? Palette.success : _routine!.stat.color,
          ),
        ],
      ),
    );
  }

  Widget _counterPlate({
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 46, minWidth: 132),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: facetedDecoration(
        cut: 8,
        color: const Color(0xE629201A),
        borderColor: color.withValues(alpha: 0.62),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 10,
        runSpacing: 2,
        children: [
          Text(
            value,
            style: Type.numerals.copyWith(fontSize: 25, color: Palette.textHi),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Type.label.copyWith(fontSize: 11, color: color),
          ),
        ],
      ),
    );
  }

  // ── rest screen ──────────────────────────────────────────────────
  Widget _restScreen() {
    final progress = _total == 0
        ? 1.0
        : (1 - _remaining / _total).clamp(0.0, 1.0);
    return LayoutBuilder(
      key: const ValueKey('rest'),
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'REST',
                  style: Type.label.copyWith(fontSize: 11, color: Palette.info),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: 150,
                  height: 150,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.expand(
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 6,
                          strokeCap: StrokeCap.round,
                          backgroundColor: const Color(0x1FF2CD93),
                          color: Palette.info,
                        ),
                      ),
                      Text(
                        '$_remaining',
                        style: Type.numerals.copyWith(
                          fontSize: 44,
                          color: Palette.textHi,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Text(
                    'Breathe. This little pause is part of the work — it’s where the '
                    'build happens.',
                    textAlign: TextAlign.center,
                    style: Type.body.copyWith(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: Palette.textLo,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _smallButton('SKIP REST →', Palette.textLo, () {
                  _ticker?.cancel();
                  _next();
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── paused screen ────────────────────────────────────────────────
  Widget _pausedScreen() {
    return LayoutBuilder(
      key: const ValueKey('paused'),
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.pause_circle_outline,
                  size: 40,
                  color: Palette.xpLight,
                ),
                const SizedBox(height: 12),
                Text('Paused', style: Type.display.copyWith(fontSize: 26)),
                const SizedBox(height: 6),
                Text(
                  'take all the time you need',
                  style: Type.body.copyWith(
                    fontSize: 13.5,
                    fontStyle: FontStyle.italic,
                    color: Palette.textLo,
                  ),
                ),
                const SizedBox(height: 24),
                _bigButton(
                  'RESUME',
                  () => _togglePause(alreadyAcknowledged: true),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => _finish(endedEarly: true),
                  child: Text(
                    'end early — bank what you did',
                    style: Type.label.copyWith(
                      fontSize: 11,
                      color: Palette.streak,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── shared button styles ─────────────────────────────────────────
  Widget _bigButton(String label, VoidCallback onTap) {
    return HoneyButton(label: label, onTap: onTap, glow: true);
  }

  Widget _smallButton(
    String label,
    Color color,
    VoidCallback onTap, {
    Key? key,
  }) {
    return Semantics(
      button: true,
      label: label.replaceAll('→', '').trim(),
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          key: key,
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: facetedDecoration(
            cut: 8,
            color: const Color(0x4D1A120E),
            borderColor: color.withValues(alpha: 0.55),
          ),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: Type.label.copyWith(fontSize: 11, color: color),
            ),
          ),
        ),
      ),
    );
  }
}
