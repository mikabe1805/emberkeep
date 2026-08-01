import 'dart:async';

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
    Sfx.instance.play('tick');
    Haptics.tap();
    setState(() {
      _routine = r;
      _i = -1;
    });
  }

  void _begin() {
    Sfx.instance.play('streak');
    Haptics.success();
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
    Sfx.instance.play('tick');
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

  void _togglePause() {
    setState(() => _paused = !_paused);
    Sfx.instance.play('tick');
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
    return OverlaySurface(
      child: Container(
        // Fully opaque: the quest board is context, not visual noise behind a
        // movement instruction. This is especially important at large text.
        color: const Color(0xFF140E08),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: AnimatedSwitcher(
              duration: still
                  ? Duration.zero
                  : const Duration(milliseconds: 240),
              // Never lay out the outgoing full-screen scene. The old default
              // cross-fade stacked two transparent pages for 420ms, producing
              // unreadable title/card collisions and stale hit targets.
              layoutBuilder: (currentChild, previousChildren) =>
                  currentChild ?? const SizedBox.shrink(),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: CurvedAnimation(
                  parent: animation,
                  curve: const Interval(0.18, 1, curve: Curves.easeOutCubic),
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
            GestureDetector(
              onTap: widget.onClose,
              child: const Icon(Icons.close, size: 20, color: Palette.textLo),
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
                      fontSize: 9.5,
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
                    Text(
                      'WHY THIS WORKS',
                      style: Type.label.copyWith(
                        fontSize: 11,
                        color: Palette.info,
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
          child: Row(
            children: [
              const Icon(Icons.speed, size: 15, color: Palette.xpLight),
              const SizedBox(width: 8),
              Text('PACE', style: Type.label.copyWith(fontSize: 11)),
              const Spacer(),
              _paceChip(
                'Relaxed',
                _relaxed,
                () => setState(() => _relaxed = true),
              ),
              const SizedBox(width: 6),
              _paceChip(
                'Steady',
                !_relaxed,
                () => setState(() => _relaxed = false),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GlassPanel(
          child: Text(
            'Muscle burn and next-day soreness are normal — that’s your body '
            'adapting. Sharp or sudden pain, chest pain, or dizziness? Stop now.',
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
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
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(
            child: Column(
              children: [
                const SizedBox(height: 4),
                // top bar: progress + pause/close
                Row(
                  children: [
                    Expanded(
                      child: FacetedMeter(
                        value: (_i + 1) / _moves.length,
                        height: 4,
                        color: _routine!.stat.color,
                        background: Palette.railTrack,
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: _togglePause,
                      child: const Icon(
                        Icons.pause_circle_outline,
                        size: 24,
                        color: Palette.textLo,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  kicker,
                  style: Type.label.copyWith(
                    fontSize: 11,
                    color: m.isWork ? _routine!.stat.color : Palette.textLo,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  easier ? '${m.name} · easier' : m.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Type.display.copyWith(fontSize: 26),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Center(
                    child: m.kind == MoveKind.timed
                        ? _timedBody(m)
                        : _repsBody(m),
                  ),
                ),
                // form cue / easier instruction
                GlassPanel(
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
                      const SizedBox(height: 4),
                      Text(
                        easier ? m.easier : m.cue,
                        style: Type.body.copyWith(
                          fontSize: 13,
                          color: Palette.textHi,
                        ),
                      ),
                      if (m.caution != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          m.caution!,
                          style: Type.body.copyWith(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            color: Palette.textLo,
                          ),
                        ),
                      ],
                      if (_i + 1 < _moves.length) ...[
                        const SizedBox(height: 9),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.only(top: 8),
                          decoration: const BoxDecoration(
                            border: Border(
                              top: BorderSide(color: Color(0x24F2CD93)),
                            ),
                          ),
                          child: Text(
                            'NEXT · ${_moves[_i + 1].name}',
                            style: Type.label.copyWith(
                              fontSize: 10.5,
                              color: Palette.xpLight,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // escape valves
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (!easier)
                      // Moss is "you finished it". Taking the gentler version
                      // is not a completion, so it wears aged brass instead.
                      _smallButton('EASIER', Palette.xpLight, () {
                        if (idx != _i) return;
                        Sfx.instance.play('tick');
                        Haptics.tap();
                        setState(() => _easiered.add(idx));
                      }),
                    if (!easier) const SizedBox(width: 8),
                    _smallButton('SKIP', Palette.textLo, () {
                      if (idx != _i) return;
                      _skip();
                    }),
                  ],
                ),
                const SizedBox(height: 10),
                // primary action
                if (m.kind == MoveKind.reps)
                  _bigButton('DONE →', () {
                    if (idx != _i) return;
                    _onMoveDone();
                  })
                else
                  GestureDetector(
                    onTap: () {
                      if (idx != _i) return; // honor path: "I already did it"
                      _onMoveDone();
                    },
                    child: Text(
                      'I already did it →',
                      style: Type.label.copyWith(
                        fontSize: 12,
                        color: Palette.xpLight,
                      ),
                    ),
                  ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        ),
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 220,
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.expand(
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 7,
                  strokeCap: StrokeCap.round,
                  backgroundColor: const Color(0x1FF2CD93),
                  color: _routine!.stat.color,
                ),
              ),
              // the move, illustrated, breathing inside the countdown ring
              WorkoutFigure(
                pose: poseForMove(m.name),
                color: _figureTone(_routine!.stat.color),
                size: 148,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$_remaining s',
          style: Type.numerals.copyWith(fontSize: 24, color: Palette.textHi),
        ),
      ],
    );
  }

  Widget _repsBody(WorkoutMove m) {
    final target = m.reps;
    final reached = _repCount >= target;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // tap the figure to count — it squashes a little on each rep
        GestureDetector(
          onTap: () {
            if (_repCount >= target) return;
            Haptics.tap();
            Sfx.instance.play('tick');
            setState(() => _repCount++);
          },
          child: WorkoutFigure(
            pose: poseForMove(m.name),
            color: reached
                ? Palette.success
                : _figureTone(_routine!.stat.color),
            size: 150,
            bump: _repCount,
          ),
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            m.perSide
                ? '$_repCount / $target each side'
                : '$_repCount / $target',
            maxLines: 1,
            style: Type.numerals.copyWith(
              fontSize: 28,
              color: reached ? Palette.success : Palette.textHi,
            ),
          ),
        ),
        Text(
          reached ? 'nice — tap DONE' : 'tap the figure to count',
          style: Type.label.copyWith(fontSize: 11),
        ),
      ],
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
                _bigButton('RESUME', _togglePause),
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

  Widget _smallButton(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: facetedDecoration(
          cut: 8,
          color: Colors.transparent,
          borderColor: color.withValues(alpha: 0.5),
        ),
        child: Text(
          label,
          style: Type.label.copyWith(fontSize: 11, color: color),
        ),
      ),
    );
  }
}
