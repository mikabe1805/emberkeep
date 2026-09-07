import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../audio.dart';
import '../background_music.dart';
import '../clock.dart';
import '../haptics.dart';
import '../tokens.dart';
import 'glass.dart';
import 'pressable.dart';
import 'working_surface.dart';

/// A focused working surface for timer-verified Quests.
///
/// With [startReady] enabled, opening the overlay is deliberately inert: the
/// wall-clock deadline, periodic ticker, Focus music role, and verified result
/// all begin only after the person accepts Start. Once running, the countdown
/// remains anchored to [Clock.now] so backgrounding the app cannot pause or
/// extend the proof window.
///
/// Proof multiplies, never gates: [onHonor] remains a base-reward completion
/// path and never invokes [onFinished].
class TimerOverlay extends StatefulWidget {
  const TimerOverlay({
    super.key,
    required this.questTitle,
    required this.minutes,
    required this.onFinished,
    required this.onHonor,
    required this.onCancel,
    this.musicController,
    this.goalTitle,
    this.guidance,
    this.note,
    this.startReady = true,
  });

  final String questTitle;
  final int minutes;
  final String? goalTitle;
  final String? guidance;
  final String? note;
  final bool startReady;

  /// Countdown completed -> verified completion (x1.2).
  final VoidCallback onFinished;

  /// "I already did it" -> honor completion (base reward, no judgment).
  final VoidCallback onHonor;
  final VoidCallback onCancel;

  /// The shell-owned optional music voice. Session choices are ephemeral and
  /// never rewrite the saved global Room-music preference.
  final BackgroundMusicController? musicController;

  @override
  State<TimerOverlay> createState() => _TimerOverlayState();
}

class _TimerOverlayState extends State<TimerOverlay>
    with WidgetsBindingObserver {
  DateTime? _end;
  Timer? _tick;
  bool _started = false;
  bool _terminal = false;
  bool _musicSelected = false;
  bool _musicBusy = false;
  bool _musicSessionEntered = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!widget.startReady) {
      _musicSelected = widget.musicController?.enabled ?? false;
      _beginSession(announce: false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  void _beginSession({bool announce = true}) {
    if (_started || _terminal) return;
    _started = true;
    _end = Clock.now().add(Duration(minutes: widget.minutes));
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _check());

    final music = widget.musicController;
    if (music != null) {
      _musicSessionEntered = true;
      // Each method mutates intent synchronously before queuing transport work.
      // Applying mute immediately prevents a saved global preference from
      // briefly autoplaying Focus before an unselected session starts.
      unawaited(music.enterFocusSession());
      if (_musicSelected) {
        unawaited(music.setSessionMuted(false));
        unawaited(music.setSessionEnabled(true));
      } else {
        unawaited(music.setSessionEnabled(false));
        unawaited(music.setSessionMuted(true));
      }
    }

    if (announce) {
      setState(() {});
    }
  }

  void _check() {
    final end = _end;
    if (!mounted || !_started || _terminal || end == null) return;
    if (Clock.now().isBefore(end)) {
      setState(() {});
      return;
    }
    _terminal = true;
    _tick?.cancel();
    Sfx.instance.play('streak');
    Haptics.success();
    widget.onFinished();
  }

  void _honor() {
    if (_terminal) return;
    _terminal = true;
    _tick?.cancel();
    widget.onHonor();
  }

  void _cancel() {
    if (_terminal) return;
    _terminal = true;
    _tick?.cancel();
    widget.onCancel();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tick?.cancel();
    final music = widget.musicController;
    if (music != null && _musicSessionEntered) {
      unawaited(music.leaveFocusSession());
    }
    super.dispose();
  }

  Future<void> _toggleMusic() async {
    if (_musicBusy) return;
    final selected = !_musicSelected;
    if (!_started) {
      setState(() => _musicSelected = selected);
      return;
    }

    final music = widget.musicController;
    if (music == null) return;
    setState(() {
      _musicSelected = selected;
      _musicBusy = true;
    });
    if (selected) {
      await music.setSessionMuted(false);
      if (!music.sessionEnabled) await music.setSessionEnabled(true);
    } else {
      await music.setSessionEnabled(false);
      await music.setSessionMuted(true);
    }
    if (mounted) setState(() => _musicBusy = false);
  }

  Duration get _left {
    final end = _end;
    if (!_started || end == null) return Duration(minutes: widget.minutes);
    final left = end.difference(Clock.now());
    return left.isNegative ? Duration.zero : left;
  }

  String get _clock {
    final left = _left.inSeconds;
    return '${left ~/ 60}:${(left % 60).toString().padLeft(2, '0')}';
  }

  String get _startLabel {
    final unit = widget.minutes == 1 ? 'minute' : 'minutes';
    return 'Start ${widget.minutes} $unit';
  }

  String? _present(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  Duration _motionDuration(BuildContext context) =>
      Haptics.reduceMotion ||
          (MediaQuery.maybeDisableAnimationsOf(context) ?? false)
      ? Duration.zero
      : const Duration(milliseconds: 240);

  @override
  Widget build(BuildContext context) {
    final total = widget.minutes * 60;
    final progress = !_started
        ? 0.0
        : total <= 0
        ? 1.0
        : (1 - _left.inSeconds / total).clamp(0.0, 1.0);
    final goalTitle = _present(widget.goalTitle);
    final guidance = _present(widget.guidance);
    final note = _present(widget.note);
    final motion = _motionDuration(context);

    return BlockSemantics(
      child: Listener(
        // The overlay sits above the shell's gesture listener. Retry a blocked
        // Focus transport only after the session actually exists.
        onPointerDown: (_) {
          final music = widget.musicController;
          if (_started && music != null) {
            unawaited(music.retryAfterUserGesture());
          }
        },
        child: OverlaySurface(
          child: WorkingScene(
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 360;
                  final horizontal = compact ? 12.0 : 18.0;
                  final centeredHeight = (constraints.maxHeight - 24).clamp(
                    0.0,
                    double.infinity,
                  );
                  return SingleChildScrollView(
                    key: const Key('timer-workspace-scroll'),
                    padding: EdgeInsets.fromLTRB(
                      horizontal,
                      compact ? 10 : 14,
                      horizontal,
                      24,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: centeredHeight),
                      child: Column(
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Pressable(
                              key: const Key('timer-back'),
                              semanticLabel: _started
                                  ? 'Leave focus session'
                                  : 'Back to Quests',
                              interactionSound: InteractionSound.navigate,
                              pressDepth: 1,
                              edgeColor: Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              onTapUp: (_) => _cancel(),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minHeight: 44,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 8,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.arrow_back_ios_new_rounded,
                                        color: Palette.xpLight,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _started ? 'Leave session' : 'Quests',
                                        style: WorkingType.title.copyWith(
                                          color: Palette.xpLight,
                                          fontSize: compact ? 18 : 20,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: compact ? 18 : 38),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 480),
                            child: WorkingSurface(
                              borderRadius: BorderRadius.circular(28),
                              padding: EdgeInsets.fromLTRB(
                                compact ? 18 : 28,
                                compact ? 22 : 30,
                                compact ? 18 : 28,
                                compact ? 22 : 30,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (goalTitle != null) ...[
                                    Text(
                                      goalTitle.toUpperCase(),
                                      key: const Key('timer-goal-title'),
                                      textAlign: TextAlign.center,
                                      style: Type.label.copyWith(
                                        color: Palette.xpLight,
                                        letterSpacing: 2.1,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                  ],
                                  Text(
                                    widget.questTitle,
                                    key: const Key('timer-quest-title'),
                                    textAlign: TextAlign.center,
                                    style: WorkingType.title.copyWith(
                                      fontSize: compact ? 29 : 35,
                                      height: 1.08,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    _started
                                        ? 'Your ${widget.minutes}-minute session is in progress.'
                                        : 'A ${widget.minutes}-minute session, ready when you are.',
                                    key: const Key('timer-session-copy'),
                                    textAlign: TextAlign.center,
                                    style: Type.body.copyWith(
                                      color: Palette.textMid,
                                      height: 1.35,
                                    ),
                                  ),
                                  SizedBox(height: compact ? 20 : 28),
                                  Center(
                                    child: _TimerLens(
                                      clock: _clock,
                                      progress: progress,
                                      ready: !_started,
                                      compact: compact,
                                      motionDuration: motion,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    'Saved ${widget.minutes}-minute timer',
                                    style: Type.body.copyWith(
                                      color: Palette.xp,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  AnimatedSwitcher(
                                    duration: motion,
                                    child: _started
                                        ? Column(
                                            key: const ValueKey('running-copy'),
                                            children: [
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(
                                                    Icons.verified_rounded,
                                                    size: 15,
                                                    color: Palette.verify,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Flexible(
                                                    child: Text(
                                                      'FINISH FOR x1.2 VERIFIED XP',
                                                      textAlign:
                                                          TextAlign.center,
                                                      style: Type.label
                                                          .copyWith(
                                                            color:
                                                                Palette.verify,
                                                          ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 5),
                                              Text(
                                                'You can leave the app open or come back when the time is up.',
                                                textAlign: TextAlign.center,
                                                style: Type.body.copyWith(
                                                  fontSize: 13,
                                                  color: Palette.textLo,
                                                  height: 1.3,
                                                ),
                                              ),
                                            ],
                                          )
                                        : Text(
                                            'Timer proof begins when you press Start.',
                                            key: const ValueKey('ready-copy'),
                                            textAlign: TextAlign.center,
                                            style: Type.body.copyWith(
                                              fontSize: 14,
                                              color: Palette.textLo,
                                            ),
                                          ),
                                  ),
                                  if (guidance != null) ...[
                                    const SizedBox(height: 20),
                                    _ContextCard(
                                      key: const Key('timer-guidance'),
                                      label: 'ONE THING TO TRY',
                                      text: guidance,
                                      icon: null,
                                    ),
                                  ],
                                  if (widget.musicController != null) ...[
                                    const SizedBox(height: 14),
                                    _MusicControl(
                                      selected: _musicSelected,
                                      busy: _musicBusy,
                                      onTap: _toggleMusic,
                                    ),
                                  ],
                                  if (!_started) ...[
                                    const SizedBox(height: 18),
                                    SizedBox(
                                      width: double.infinity,
                                      child: _PrimaryStartButton(
                                        label: _startLabel,
                                        onTap: () => _beginSession(),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  Pressable(
                                    key: const Key('timer-honor'),
                                    semanticLabel:
                                        'I already did it without timer verification',
                                    semanticHint:
                                        'Completes for the base reward without verified bonus',
                                    material: MaterialSound.glass,
                                    interactionSound: InteractionSound.place,
                                    pressDepth: 1,
                                    edgeColor: Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                    guardRapidReentry: true,
                                    onTapUp: (_) => _honor(),
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        minHeight: 48,
                                      ),
                                      child: Center(
                                        child: Text(
                                          'I already did it',
                                          style: Type.display.copyWith(
                                            color: Palette.xpLight,
                                            fontSize: 18,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (note != null) ...[
                                    const SizedBox(height: 16),
                                    const WorkingRule(),
                                    _ContextCard(
                                      key: const Key('timer-note'),
                                      label: 'YOUR NOTE',
                                      text: note,
                                      icon: Icons.edit_note_rounded,
                                      framed: false,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TimerLens extends StatelessWidget {
  const _TimerLens({
    required this.clock,
    required this.progress,
    required this.ready,
    required this.compact,
    required this.motionDuration,
  });

  final String clock;
  final double progress;
  final bool ready;
  final bool compact;
  final Duration motionDuration;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 220.0 : 280.0;
    return Semantics(
      container: true,
      label: ready ? '$clock, ready' : '$clock remaining, session in progress',
      child: ExcludeSemantics(
        child: SizedBox(
          width: size,
          height: size,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const SweepGradient(
                transform: GradientRotation(-0.72),
                colors: [
                  Color(0xFF4A2B12),
                  Color(0xFFD49A55),
                  Color(0xFFFFD99B),
                  Color(0xFF6E421F),
                  Color(0xFF2B180D),
                  Color(0xFFB47835),
                  Color(0xFF4A2B12),
                ],
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0xCC080403),
                  blurRadius: 28,
                  spreadRadius: 1,
                  offset: Offset(0, 16),
                ),
                BoxShadow(color: Color(0x447B4A20), blurRadius: 18),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(4.5),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    center: Alignment(-0.34, -0.46),
                    radius: 1.14,
                    colors: [
                      Color(0xFFB37A3B),
                      Color(0xFF4B2A15),
                      Color(0xFF160C08),
                    ],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(5.5),
                  child: ClipOval(
                    child: TweenAnimationBuilder<double>(
                      duration: motionDuration,
                      curve: Curves.easeOutCubic,
                      tween: Tween<double>(end: progress),
                      builder: (context, value, _) => CustomPaint(
                        painter: _InstrumentFace(progress: value),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  clock,
                                  key: const Key('timer-clock'),
                                  maxLines: 1,
                                  softWrap: false,
                                  style: WorkingType.title.copyWith(
                                    fontSize: compact ? 70 : 84,
                                    fontWeight: FontWeight.w400,
                                    color: const Color(0xFFF2DFC6),
                                    height: .92,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                    shadows: const [
                                      Shadow(
                                        color: Color(0x99000000),
                                        blurRadius: 12,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                ready ? 'READY' : 'IN SESSION',
                                key: const Key('timer-status'),
                                style: Type.label.copyWith(
                                  color: const Color(0xFFE0A45B),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 3.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InstrumentFace extends CustomPainter {
  const _InstrumentFace({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = size.shortestSide / 2;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.28, -0.35),
          radius: 1.08,
          colors: [Color(0xFF181315), Color(0xFF0B090A), Color(0xFF030303)],
          stops: [0, .64, 1],
        ).createShader(rect),
    );

    final tickPaint = Paint()
      ..strokeCap = StrokeCap.square
      ..color = const Color(0xFFB77B3D);
    for (var index = 0; index < 60; index++) {
      final major = index % 15 == 0;
      final medium = index % 5 == 0;
      final angle = (index / 60) * math.pi * 2 - math.pi / 2;
      final outer = radius - 13;
      final length = major ? 13.0 : (medium ? 7.0 : 3.5);
      tickPaint
        ..strokeWidth = major ? 2.0 : (medium ? 1.15 : .65)
        ..color = Color.fromRGBO(205, 139, 69, major ? .92 : .54);
      canvas.drawLine(
        center + Offset(math.cos(angle), math.sin(angle)) * (outer - length),
        center + Offset(math.cos(angle), math.sin(angle)) * outer,
        tickPaint,
      );
    }

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 6),
      math.pi * 1.08,
      math.pi * .54,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round
        ..color = const Color(0x55FFE0B2),
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 4),
      .12,
      math.pi * .84,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..color = const Color(0x99000000),
    );
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - 9),
        -math.pi / 2,
        math.pi * 2 * progress.clamp(0, 1),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFFE4A75C),
      );
    }
  }

  @override
  bool shouldRepaint(_InstrumentFace oldDelegate) =>
      oldDelegate.progress != progress;
}

class _MusicControl extends StatelessWidget {
  const _MusicControl({
    required this.selected,
    required this.busy,
    required this.onTap,
  });

  final bool selected;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      key: const Key('focus-music-toggle'),
      material: MaterialSound.glass,
      interactionSound: InteractionSound.select,
      semanticLabel: selected
          ? 'Turn meditation music off for this focus session'
          : 'Turn meditation music on for this focus session',
      semanticToggled: selected,
      enabled: !busy,
      edgeColor: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      pressDepth: 1,
      guardRapidReentry: true,
      onTapUp: (_) => onTap(),
      child: AnimatedContainer(
        duration: Haptics.reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 180),
        constraints: const BoxConstraints(minHeight: 66),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0x66372029) : const Color(0x52130D0B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? Palette.xp.withValues(alpha: 0.62)
                : Palette.brass.withValues(alpha: 0.46),
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.music_note_rounded : Icons.music_off_rounded,
              color: selected ? Palette.xpLight : Palette.textLo,
              size: 23,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Focus music',
                          style: Type.display.copyWith(fontSize: 18),
                        ),
                      ),
                      Text(
                        selected ? 'ON' : 'OFF',
                        style: Type.label.copyWith(
                          color: selected ? Palette.xpLight : Palette.textLo,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Optional - just for this session',
                    style: Type.body.copyWith(
                      color: Palette.textLo,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            if (busy) ...[
              const SizedBox(width: 10),
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: Palette.xpLight,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PrimaryStartButton extends StatelessWidget {
  const _PrimaryStartButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return WorkingAction(
      key: const Key('timer-start'),
      label: label,
      onTap: onTap,
      icon: Icons.play_arrow_rounded,
      primary: true,
      sound: InteractionSound.place,
    );
  }
}

class _ContextCard extends StatelessWidget {
  const _ContextCard({
    super.key,
    required this.label,
    required this.text,
    this.icon = Icons.auto_awesome_rounded,
    this.framed = true,
  });

  final String label;
  final String text;
  final IconData? icon;
  final bool framed;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: Palette.xp),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Type.label.copyWith(
                  color: Palette.xpLight,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                text,
                style: Type.body.copyWith(color: Palette.textMid, height: 1.42),
              ),
            ],
          ),
        ),
      ],
    );
    if (!framed) return content;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(15, 5, 0, 5),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: Palette.brassLit.withValues(alpha: .72),
            width: 1.2,
          ),
        ),
      ),
      child: content,
    );
  }
}
