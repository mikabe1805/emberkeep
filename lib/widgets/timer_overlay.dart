import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio.dart';
import '../tokens.dart';
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
  });

  final String questTitle;
  final int minutes;

  /// Countdown completed → verified completion (×1.2).
  final VoidCallback onFinished;

  /// "I already did it" → honor completion (no bonus, no judgment).
  final VoidCallback onHonor;
  final VoidCallback onCancel;

  @override
  State<TimerOverlay> createState() => _TimerOverlayState();
}

class _TimerOverlayState extends State<TimerOverlay>
    with WidgetsBindingObserver {
  late final DateTime _end;
  Timer? _tick;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _end = DateTime.now().add(Duration(minutes: widget.minutes));
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _check());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // resync immediately on resume — the wall clock kept running
    if (state == AppLifecycleState.resumed) _check();
  }

  void _check() {
    if (!mounted || _done) return;
    if (DateTime.now().isBefore(_end)) {
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
    super.dispose();
  }

  Duration get _left {
    final d = _end.difference(DateTime.now());
    return d.isNegative ? Duration.zero : d;
  }

  String _clock() {
    final left = _left.inSeconds;
    return '${left ~/ 60}:${(left % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.minutes * 60;
    final progress =
        total == 0 ? 1.0 : (1 - _left.inSeconds / total).clamp(0.0, 1.0);
    return OverlaySurface(
      child: Container(
      color: const Color(0xF2191210),
      child: Center(
        child: GlassPanel(
          blur: true,
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('PROOF IN PROGRESS',
                  style:
                      Type.label.copyWith(fontSize: 10, color: Palette.verify)),
              const SizedBox(height: 6),
              Text(widget.questTitle,
                  textAlign: TextAlign.center,
                  style: Type.display.copyWith(fontSize: 18)),
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
                    Text(_clock(),
                        style: Type.numerals
                            .copyWith(fontSize: 44, color: Palette.textHi)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.verified, size: 13, color: Palette.verify),
                  const SizedBox(width: 5),
                  Text('FINISH FOR ×1.2 VERIFIED XP',
                      style: Type.label
                          .copyWith(fontSize: 9, color: Palette.verify)),
                ],
              ),
              const SizedBox(height: 6),
              Text('real-time clock — locking your phone is fine',
                  style: Type.body.copyWith(
                      fontSize: 10.5,
                      fontStyle: FontStyle.italic,
                      color: Palette.textLo)),
              const SizedBox(height: 18),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () {
                      Sfx.instance.play('boing');
                      widget.onCancel();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 9),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                            color: Palette.textLo.withValues(alpha: 0.4)),
                      ),
                      child:
                          Text('NOT NOW', style: Type.label.copyWith(fontSize: 10)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // proof multiplies, never gates — honor path always open
                  GestureDetector(
                    onTap: () {
                      Sfx.instance.play('tick');
                      widget.onHonor();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 9),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                            color: Palette.success.withValues(alpha: 0.5)),
                      ),
                      child: Text('I ALREADY DID IT',
                          style: Type.label.copyWith(
                              fontSize: 10, color: Palette.success)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
