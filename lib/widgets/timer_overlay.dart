import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio.dart';
import '../background_music.dart';
import '../clock.dart';
import '../tokens.dart';
import 'facets.dart';
import 'glass.dart';

/// Timer proof: a real countdown anchored to WALL-CLOCK time — locking the
/// phone or switching apps is fine; the clock keeps running honestly and
/// resyncs on resume. Finishing earns the VERIFIED ×1.2 bonus.
///
/// Proof multiplies, never gates (RESEARCH.md §5): the honor path is always
/// available — "I already did it" completes without the bonus.
class TimerOverlay extends StatefulWidget {
  const TimerOverlay({
    super.key,
    required this.questTitle,
    required this.minutes,
    required this.onFinished,
    required this.onHonor,
    required this.onCancel,
    this.musicController,
  });

  final String questTitle;
  final int minutes;

  /// Countdown completed → verified completion (×1.2).
  final VoidCallback onFinished;

  /// "I already did it" → honor completion (no bonus, no judgment).
  final VoidCallback onHonor;
  final VoidCallback onCancel;

  /// The shell-owned optional music voice. Direct widget previews can omit it;
  /// the production Quest flow supplies it so Focus has one obvious, local
  /// music control without creating a second audio player.
  final BackgroundMusicController? musicController;

  @override
  State<TimerOverlay> createState() => _TimerOverlayState();
}

class _TimerOverlayState extends State<TimerOverlay>
    with WidgetsBindingObserver {
  late final DateTime _end;
  Timer? _tick;
  bool _done = false;
  bool _musicBusy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _end = Clock.now().add(Duration(minutes: widget.minutes));
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _check());
    // Focus is a real music-role boundary: a saved Room-music choice moves
    // from the jazzy umbrella-brush rotation to the peaceful meditation bed
    // for this overlay, without rewriting the saved preference.
    unawaited(widget.musicController?.enterFocusSession());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // resync immediately on resume — the wall clock kept running
    if (state == AppLifecycleState.resumed) _check();
  }

  void _check() {
    if (!mounted || _done) return;
    if (Clock.now().isBefore(_end)) {
      setState(() {}); // refresh the clock string + ring
      return;
    }
    _done = true;
    _tick?.cancel();
    Sfx.instance.play('streak');
    HapticFeedback.mediumImpact();
    widget.onFinished();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tick?.cancel();
    final music = widget.musicController;
    if (music != null) {
      // Session choices are ephemeral. This also restores the fun normal-room
      // rotation when the saved global preference is still on.
      unawaited(music.leaveFocusSession());
    }
    super.dispose();
  }

  Future<void> _toggleMusic() async {
    final music = widget.musicController;
    if (music == null || _musicBusy) return;
    final enable = !music.shouldPlay;
    setState(() => _musicBusy = true);
    if (enable) {
      await music.setSessionMuted(false);
      if (!music.enabled) await music.setSessionEnabled(true);
    } else {
      await music.setSessionEnabled(false);
      await music.setSessionMuted(true);
    }
    if (mounted) setState(() => _musicBusy = false);
  }

  Duration get _left {
    final d = _end.difference(Clock.now());
    return d.isNegative ? Duration.zero : d;
  }

  String _clock() {
    final left = _left.inSeconds;
    return '${left ~/ 60}:${(left % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.minutes * 60;
    final progress = total == 0
        ? 1.0
        : (1 - _left.inSeconds / total).clamp(0.0, 1.0);
    return OverlaySurface(
      child: Container(
        color: const Color(0xF2191210),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final centeredHeight = (constraints.maxHeight - 44).clamp(
                0.0,
                double.infinity,
              );
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: centeredHeight),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 430),
                      child: GlassPanel(
                        blur: true,
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'FOCUS ROOM · VERIFIED PROOF',
                              style: Type.label.copyWith(
                                fontSize: 11,
                                color: Palette.verify,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              widget.questTitle,
                              textAlign: TextAlign.center,
                              style: Type.display.copyWith(fontSize: 18),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: 170,
                              height: 170,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  SizedBox.expand(
                                    child: CircularProgressIndicator(
                                      value: progress,
                                      strokeWidth: 6,
                                      strokeCap: StrokeCap.round,
                                      backgroundColor: const Color(0x1FF2CD93),
                                      color: Palette.verify,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(18),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        _clock(),
                                        maxLines: 1,
                                        softWrap: false,
                                        style: Type.numerals.copyWith(
                                          fontSize: 44,
                                          color: Palette.textHi,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.verified,
                                  size: 13,
                                  color: Palette.verify,
                                ),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    'FINISH FOR ×1.2 VERIFIED XP',
                                    textAlign: TextAlign.center,
                                    style: Type.label.copyWith(
                                      fontSize: 11,
                                      color: Palette.verify,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'real-time clock — locking your phone is fine',
                              textAlign: TextAlign.center,
                              style: Type.body.copyWith(
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                                color: Palette.textLo,
                              ),
                            ),
                            if (widget.musicController case final music?) ...[
                              const SizedBox(height: 18),
                              Semantics(
                                button: true,
                                toggled: music.shouldPlay,
                                label: music.shouldPlay
                                    ? 'Turn meditation music off for this focus session'
                                    : 'Turn meditation music on for this focus session',
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: _musicBusy ? null : _toggleMusic,
                                  child: Container(
                                    constraints: const BoxConstraints(
                                      minHeight: 52,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    decoration: facetedDecoration(
                                      cut: 10,
                                      color: music.shouldPlay
                                          ? Palette.verify.withValues(
                                              alpha: 0.10,
                                            )
                                          : const Color(0x24130E0C),
                                      borderColor: music.shouldPlay
                                          ? Palette.verify.withValues(
                                              alpha: 0.55,
                                            )
                                          : Palette.textLo.withValues(
                                              alpha: 0.30,
                                            ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          music.shouldPlay
                                              ? Icons.volume_up_rounded
                                              : Icons.volume_off_rounded,
                                          size: 20,
                                          color: music.shouldPlay
                                              ? Palette.verify
                                              : Palette.textLo,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'FOCUS MUSIC',
                                                style: Type.label.copyWith(
                                                  fontSize: 11,
                                                  color: music.shouldPlay
                                                      ? Palette.verify
                                                      : Palette.textHi,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                music.shouldPlay
                                                    ? 'meditation theme · tap anytime to quiet'
                                                    : 'optional · tap for the peaceful focus theme',
                                                style: Type.body.copyWith(
                                                  fontSize: 11,
                                                  color: Palette.textLo,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (_musicBusy)
                                          const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 1.5,
                                              color: Palette.verify,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 18),
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    Sfx.instance.play('boing');
                                    widget.onCancel();
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 9,
                                    ),
                                    decoration: facetedDecoration(
                                      cut: 8,
                                      color: Colors.transparent,
                                      borderColor: Palette.textLo.withValues(
                                        alpha: 0.4,
                                      ),
                                    ),
                                    child: Text(
                                      'NOT NOW',
                                      style: Type.label.copyWith(fontSize: 11),
                                    ),
                                  ),
                                ),
                                // proof multiplies, never gates — honor path always open
                                GestureDetector(
                                  onTap: () {
                                    Sfx.instance.playInteraction(
                                      InteractionSound.place,
                                      material: MaterialSound.glass,
                                    );
                                    widget.onHonor();
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 9,
                                    ),
                                    decoration: facetedDecoration(
                                      cut: 8,
                                      color: Colors.transparent,
                                      borderColor: Palette.success.withValues(
                                        alpha: 0.5,
                                      ),
                                    ),
                                    child: Text(
                                      'I ALREADY DID IT',
                                      style: Type.label.copyWith(
                                        fontSize: 11,
                                        color: Palette.success,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
