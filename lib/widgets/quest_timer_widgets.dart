// The quest timer's faces across the house.
//
//   * [QuestTimerAction]: the one-tap offer on a Quest ("Start a 20-minute
//     timer"), or, once that Quest's timer is running, the way back to it.
//     The Quests board, the Doorway's Today's three and Plans all use it.
//   * [showQuestTimerOffer]: the same offer, asked once when the Quest is
//     marked. Never a gate: "Just mark it done" is always there.
//   * [QuestTimerPill]: the small running indicator that stays over every
//     room and opens the timer.
//   * [showQuestTimerFinish]: the finish moment for a timer that ended while
//     the person was elsewhere.
//
// Copy is plain and warm: a timer is something offered, never owed.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../audio.dart';
import '../haptics.dart';
import '../models.dart';
import '../quest_timer.dart';
import '../tokens.dart';
import 'glass.dart';
import 'pressable.dart';
import 'working_surface.dart';

const Color _pillFill = Color(0xF0191210);

/// The offer on [quest], or the way back to its running timer, or nothing.
///
/// Nothing when a timer would not fit the Quest, and nothing while another
/// Quest's timer holds the place (one timer at a time).
class QuestTimerAction extends StatelessWidget {
  const QuestTimerAction({
    super.key,
    required this.quest,
    required this.onStart,
    required this.onOpen,
    this.caption = false,
    this.quiet = false,
    this.compact = false,
  });

  final Quest quest;

  /// A small round button (and, while it runs, a small clock) for a row with
  /// no room for the whole offer. The words stay in its spoken name.
  final bool compact;

  /// Begin a new timer for [quest].
  final VoidCallback onStart;

  /// Open [quest]'s timer, running or finished.
  final VoidCallback onOpen;

  /// Say what the timer is for, under the button.
  final bool caption;

  /// The button sits inside a pressable row that already speaks and clicks, so
  /// it adds no sound of its own.
  final bool quiet;

  @override
  Widget build(BuildContext context) {
    final timer = QuestTimerScope.maybeOf(context);
    final mine = timer?.sessionFor(quest);
    if (timer != null && mine != null) {
      return _RunningFace(
        compact: compact,
        key: ValueKey('quest-timer-running-${quest.title}'),
        timer: timer,
        session: mine,
        onTap: onOpen,
        quiet: quiet,
      );
    }
    final offer = timerOfferFor(quest);
    // A timer Quest already opens its session as its own action.
    if (offer == null || offer.inherent) return const SizedBox.shrink();
    if (timer != null && timer.hasSession) return const SizedBox.shrink();
    if (compact) {
      return _RoundButton(
        key: ValueKey('quest-timer-offer-${quest.title}'),
        semanticLabel: '${offer.label} for ${quest.displayTitle}',
        semanticHint: questTimerTrainingLine,
        quiet: quiet,
        onTap: onStart,
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PillButton(
          key: ValueKey('quest-timer-offer-${quest.title}'),
          label: offer.label,
          semanticLabel: '${offer.label} for ${quest.displayTitle}',
          semanticHint: questTimerTrainingLine,
          sound: InteractionSound.select,
          quiet: quiet,
          onTap: onStart,
        ),
        // At very large text the words are the button's own spoken hint, so
        // the page is not asked to carry a second line.
        if (caption && MediaQuery.textScalerOf(context).scale(1) <= 1.3) ...[
          const SizedBox(height: 5),
          Text(
            questTimerTrainingLine,
            textAlign: TextAlign.center,
            style: Type.body.copyWith(
              fontSize: 12.5,
              height: 1.2,
              color: Palette.textLo,
            ),
          ),
        ],
      ],
    );
  }
}

/// A 44 pt outlined pill with a timer in it, in the Doorway's glass language.
class _PillButton extends StatelessWidget {
  const _PillButton({
    super.key,
    required this.label,
    required this.semanticLabel,
    required this.onTap,
    required this.sound,
    this.semanticHint,
    this.highlight = false,
    this.quiet = false,
  });

  final String label;
  final String semanticLabel;
  final String? semanticHint;
  final VoidCallback onTap;
  final InteractionSound sound;

  /// Lit: the timer is waiting to be finished.
  final bool highlight;

  /// No sound of its own (the row around it already has one).
  final bool quiet;

  Widget _face(bool pressed, bool focused) {
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.6,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: highlight
                ? Color.fromRGBO(255, 214, 140, pressed ? 0.26 : 0.16)
                : Color.fromRGBO(255, 226, 170, pressed ? 0.16 : 0.05),
            border: Border.all(
              color: focused
                  ? Palette.textHi
                  : Palette.brassLit.withValues(
                      alpha: pressed ? 0.9 : (highlight ? 0.85 : 0.55),
                    ),
            ),
          ),
          child: ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 20,
                    color: highlight ? Palette.xpLight : Palette.brassLit,
                  ),
                  const SizedBox(width: 8),
                  Flexible(child: _PillText(label)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Pressable(
      pressDepth: 1,
      edgeColor: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      material: MaterialSound.glass,
      interactionSound: sound,
      soundEnabled: !quiet,
      guardRapidReentry: true,
      semanticLabel: semanticLabel,
      semanticHint: semanticHint,
      onTapUp: (_) => onTap(),
      stateBuilder: (context, child, pressed, focused, hovered) =>
          _face(pressed, focused),
      child: _face(false, false),
    );
  }
}

/// The pill's words. At the system's usual text size they stay on one line,
/// stepping down a little if the room is narrow; at larger sizes they wrap
/// rather than shrink, so they are never read small.
class _PillText extends StatelessWidget {
  const _PillText(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final style = Type.body.copyWith(
      fontSize: 15.5,
      height: 1.15,
      fontWeight: FontWeight.w500,
      color: Palette.textHi,
    );
    if (MediaQuery.textScalerOf(context).scale(1) > 1.15) {
      return Text(label, textAlign: TextAlign.center, style: style);
    }
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(label, maxLines: 1, softWrap: false, style: style),
    );
  }
}

/// A round timer button for a compact row: 44 pt to touch, a little ring to
/// look at, and, while a timer runs, its clock beside it.
class _RoundButton extends StatelessWidget {
  const _RoundButton({
    super.key,
    required this.semanticLabel,
    required this.onTap,
    this.semanticHint,
    this.label,
    this.highlight = false,
    this.quiet = false,
  });

  final String semanticLabel;
  final String? semanticHint;
  final VoidCallback onTap;
  final String? label;
  final bool highlight;
  final bool quiet;

  Widget _face(bool pressed, bool focused) {
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
        child: Center(
          child: ExcludeSemantics(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: highlight
                    ? Color.fromRGBO(255, 214, 140, pressed ? 0.28 : 0.18)
                    : Color.fromRGBO(255, 226, 170, pressed ? 0.16 : 0.05),
                border: Border.all(
                  color: focused
                      ? Palette.textHi
                      : Palette.brassLit.withValues(
                          alpha: pressed ? 0.9 : (highlight ? 0.85 : 0.55),
                        ),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: label == null ? 7 : 9,
                  vertical: 7,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      highlight ? Icons.alarm_on_rounded : Icons.timer_outlined,
                      size: 20,
                      color: highlight ? Palette.xpLight : Palette.brassLit,
                    ),
                    if (label != null) ...[
                      const SizedBox(width: 5),
                      Text(
                        label!,
                        style: Type.numerals.copyWith(
                          fontSize: 14,
                          height: 1,
                          color: Palette.textHi,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Pressable(
      pressDepth: 1,
      edgeColor: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      material: MaterialSound.glass,
      interactionSound: InteractionSound.select,
      soundEnabled: !quiet,
      guardRapidReentry: true,
      semanticLabel: semanticLabel,
      semanticHint: semanticHint,
      onTapUp: (_) => onTap(),
      stateBuilder: (context, child, pressed, focused, hovered) =>
          _face(pressed, focused),
      child: _face(false, false),
    );
  }
}

/// "Timer running · 19:42", ticking for itself; "Time’s up · finish it" when
/// the end has passed.
class _RunningFace extends StatefulWidget {
  const _RunningFace({
    super.key,
    required this.timer,
    required this.session,
    required this.onTap,
    this.quiet = false,
    this.compact = false,
  });

  final QuestTimer timer;
  final QuestTimerSession session;
  final VoidCallback onTap;
  final bool quiet;
  final bool compact;

  @override
  State<_RunningFace> createState() => _RunningFaceState();
}

class _RunningFaceState extends State<_RunningFace> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final finished = widget.timer.isFinished();
    final left = widget.timer.remaining();
    if (widget.compact) {
      return _RoundButton(
        semanticLabel: finished
            ? 'Timer done for ${widget.session.questTitle}. Finish it.'
            : 'Timer running for ${widget.session.questTitle}, '
                  '${_spokenLeft(left)}. Open it.',
        quiet: widget.quiet,
        onTap: widget.onTap,
        label: finished ? 'Done' : questTimerClock(left),
        highlight: finished,
      );
    }
    return _PillButton(
      label: finished
          ? 'Time’s up · finish it'
          : 'Timer running · ${questTimerClock(left)}',
      semanticLabel: finished
          ? 'Timer done for ${widget.session.questTitle}. Finish it.'
          : 'Timer running for ${widget.session.questTitle}, '
                '${_spokenLeft(left)}. Open it.',
      sound: InteractionSound.select,
      quiet: widget.quiet,
      onTap: widget.onTap,
      highlight: finished,
    );
  }
}

String _spokenLeft(Duration left) {
  final minutes = (left.inSeconds / 60).ceil();
  if (minutes <= 1) return 'about a minute left';
  return 'about $minutes minutes left';
}

// ── The running indicator ────────────────────────────────────────────────

/// The small pill over every room while a timer runs (or waits to be
/// finished). It ticks for itself, notices the end, and opens the timer.
class QuestTimerPill extends StatefulWidget {
  const QuestTimerPill({super.key, required this.timer, required this.onOpen});

  final QuestTimer timer;
  final VoidCallback onOpen;

  @override
  State<QuestTimerPill> createState() => _QuestTimerPillState();
}

class _QuestTimerPillState extends State<QuestTimerPill> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    widget.timer.addListener(_sync);
    _sync();
  }

  @override
  void didUpdateWidget(QuestTimerPill old) {
    super.didUpdateWidget(old);
    if (!identical(old.timer, widget.timer)) {
      old.timer.removeListener(_sync);
      widget.timer.addListener(_sync);
      _sync();
    }
  }

  @override
  void dispose() {
    widget.timer.removeListener(_sync);
    _tick?.cancel();
    super.dispose();
  }

  void _sync() {
    final wanted = widget.timer.hasSession && widget.timer.isRunning();
    if (wanted && _tick == null) {
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        widget.timer.checkFinished();
        if (!mounted) return;
        if (!widget.timer.isRunning()) {
          _tick?.cancel();
          _tick = null;
        }
        setState(() {});
      });
    } else if (!wanted) {
      _tick?.cancel();
      _tick = null;
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final timer = widget.timer;
    final session = timer.session;
    if (session == null || timer.overlayOpen) return const SizedBox.shrink();
    final finished = timer.isFinished();
    final left = timer.remaining();
    return KeyedSubtree(
      key: const Key('quest-timer-pill'),
      child: Pressable(
        pressDepth: 1,
        edgeColor: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        material: MaterialSound.glass,
        interactionSound: InteractionSound.select,
        guardRapidReentry: true,
        semanticLabel: finished
            ? 'Timer done for ${session.questTitle}. Tap to finish it.'
            : 'Timer running for ${session.questTitle}, '
                  '${_spokenLeft(left)}. Opens the timer.',
        onTapUp: (_) => widget.onOpen(),
        stateBuilder: (context, child, pressed, focused, hovered) =>
            _face(session, finished, left, pressed, focused),
        child: _face(session, finished, left, false, false),
      ),
    );
  }

  Widget _face(
    QuestTimerSession session,
    bool finished,
    Duration left,
    bool pressed,
    bool focused,
  ) {
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      // 44 pt to touch. The capsule you see is 34 pt, so it rests on the
      // dock's edge and covers only a sliver of the room above it.
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44, maxWidth: 232),
        child: Center(
          widthFactor: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              boxShadow: const [
                BoxShadow(
                  color: Color(0xB3090504),
                  blurRadius: 14,
                  offset: Offset(0, 4),
                ),
              ],
              color: Color.alphaBlend(
                finished
                    ? Color.fromRGBO(255, 214, 140, pressed ? 0.3 : 0.2)
                    : Color.fromRGBO(255, 226, 170, pressed ? 0.14 : 0.04),
                _pillFill,
              ),
              border: Border.all(
                color: focused
                    ? Palette.textHi
                    : Palette.brassLit.withValues(alpha: finished ? 0.95 : 0.6),
              ),
            ),
            child: ExcludeSemantics(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 5, 14, 5),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      finished ? Icons.alarm_on_rounded : Icons.timer_outlined,
                      size: 18,
                      color: finished ? Palette.xpLight : Palette.brassLit,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      finished ? 'Done' : questTimerClock(left),
                      key: const Key('quest-timer-pill-clock'),
                      style: Type.numerals.copyWith(
                        fontSize: 17,
                        height: 1,
                        color: Palette.textHi,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        finished ? 'Tap to finish' : session.questTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Type.body.copyWith(
                          fontSize: 13.5,
                          height: 1.1,
                          color: Palette.textMid,
                        ),
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

// ── Asked when a Quest is marked ─────────────────────────────────────────

enum QuestTimerChoice { start, markDone }

/// "Time it?" Asked when a Quest that fits a timer is marked. Returns null if
/// the person closed it without choosing: nothing happens then.
Future<QuestTimerChoice?> showQuestTimerOffer(
  BuildContext context, {
  required Quest quest,
  required QuestTimerOffer offer,
}) {
  return showModalBottomSheet<QuestTimerChoice>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => _TimerSheet(
      key: const Key('quest-timer-offer-sheet'),
      eyebrow: 'TIME IT?',
      title: quest.displayTitle,
      body:
          'A finished ${offer.minutes}-minute timer counts extra toward this '
          'week’s training. It keeps running if you leave, and you can '
          'still just mark it done.',
      primaryKey: const Key('quest-timer-sheet-start'),
      primaryLabel: offer.label,
      primaryIcon: Icons.timer_outlined,
      onPrimary: () => Navigator.of(sheetContext).pop(QuestTimerChoice.start),
      secondaryKey: const Key('quest-timer-sheet-skip'),
      secondaryLabel: 'Just mark it done',
      onSecondary: () =>
          Navigator.of(sheetContext).pop(QuestTimerChoice.markDone),
    ),
  );
}

/// The finish moment for a timer that ended while the person was elsewhere.
/// True: finish the Quest now. False or null: not yet (the timer waits).
Future<bool?> showQuestTimerFinish(
  BuildContext context, {
  required QuestTimerSession session,
}) {
  Sfx.instance.play('streak');
  Haptics.success();
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => _TimerSheet(
      key: const Key('quest-timer-finish-sheet'),
      eyebrow: 'TIME’S UP',
      title: session.questTitle,
      body:
          '${session.minutes} ${session.minutes == 1 ? 'minute' : 'minutes'}, '
          'done. Finish it now for extra XP. It counts extra toward this '
          'week’s training.',
      primaryKey: const Key('quest-timer-finish'),
      primaryLabel: 'Finish it',
      primaryIcon: Icons.check_rounded,
      onPrimary: () => Navigator.of(sheetContext).pop(true),
      secondaryKey: const Key('quest-timer-later'),
      secondaryLabel: 'Not yet',
      onSecondary: () => Navigator.of(sheetContext).pop(false),
    ),
  );
}

class _TimerSheet extends StatelessWidget {
  const _TimerSheet({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.primaryKey,
    required this.primaryLabel,
    required this.primaryIcon,
    required this.onPrimary,
    required this.secondaryKey,
    required this.secondaryLabel,
    required this.onSecondary,
  });

  final String eyebrow;
  final String title;
  final String body;
  final Key primaryKey;
  final String primaryLabel;
  final IconData primaryIcon;
  final VoidCallback onPrimary;
  final Key secondaryKey;
  final String secondaryLabel;
  final VoidCallback onSecondary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: GlassPanel(
        tint: const Color(0xF22A211D),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The words scroll if the text is very large; the two ways on
            // never do, so they are always in reach.
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      eyebrow,
                      style: Type.label.copyWith(
                        color: Palette.xpLight,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Semantics(
                      header: true,
                      child: Text(
                        title,
                        style: WorkingType.title.copyWith(
                          fontSize: 27,
                          height: 1.08,
                          color: Palette.textHi,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      body,
                      style: Type.body.copyWith(
                        fontSize: 15,
                        height: 1.4,
                        color: Palette.textMid,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            WorkingAction(
              key: primaryKey,
              label: primaryLabel,
              onTap: onPrimary,
              icon: primaryIcon,
              iconLeading: true,
              primary: true,
              sound: InteractionSound.place,
            ),
            const SizedBox(height: 4),
            Pressable(
              key: secondaryKey,
              semanticLabel: secondaryLabel,
              material: MaterialSound.glass,
              interactionSound: InteractionSound.select,
              pressDepth: 1,
              edgeColor: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              guardRapidReentry: true,
              onTapUp: (_) => onSecondary(),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Center(
                  child: Text(
                    secondaryLabel,
                    style: Type.display.copyWith(
                      color: Palette.xpLight,
                      fontSize: 18,
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
