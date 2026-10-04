// The evening on a class day: once the last class is over and every class is
// kept (or the wind-down has begun), the room turns to the window and the
// armchair and the glass holds the rest of the day. The day's record folds to
// one line; the music, a page in the journal and closing the day sit under
// it, all in the glass and none on the painting. A class still unmarked is
// neutral: while one can be marked, the card leads with it exactly as during
// the day, and nothing ever counts the rest.
part of 'class_day_room.dart';

/// What the evening glass offers under the day's record.
class ClassEvening {
  const ClassEvening({required this.onWrite, this.onCloseDay, this.music});

  /// A page in the journal ("Write a line").
  final VoidCallback onWrite;

  /// Closes the day (the night ledger). Null before the wind-down, and once
  /// tonight is closed.
  final VoidCallback? onCloseDay;

  /// The room's music, through the shell's controller. Null when the page
  /// has no controller.
  final ClassEveningMusic? music;
}

/// The music control's live state and its one action.
class ClassEveningMusic {
  const ClassEveningMusic({
    required this.on,
    required this.nowPlaying,
    required this.onToggle,
  });

  /// Whether music is wanted now: his saved setting, or tonight's choice.
  final ValueListenable<bool> on;

  /// The take sounding now (an asset path), or null.
  final ValueListenable<String?> nowPlaying;
  final VoidCallback onToggle;
}

class ClassEveningBody extends StatelessWidget {
  const ClassEveningBody({
    super.key,
    required this.state,
    required this.card,
    required this.now,
    required this.evening,
    required this.onMark,
    required this.onSelect,
    this.onUndo,
    this.undoIdentity,
    this.reduceMotion = false,
    this.lightDirection,
  });

  final GameState state;
  final ClassCard card;
  final DateTime now;
  final ClassEvening evening;
  final void Function(List<ClassRow> rows) onMark;
  final ValueChanged<ClassRow> onSelect;
  final VoidCallback? onUndo;
  final String? undoIdentity;
  final bool reduceMotion;
  final ValueListenable<Offset>? lightDirection;

  @override
  Widget build(BuildContext context) {
    final music = evening.music;
    return Column(
      key: const Key('class-evening'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Something can still be marked: the card leads with it, one press
        // as during the day. Otherwise the day is one line.
        if (card.foremost != null)
          ClassCardBody(
            state: state,
            card: card,
            now: now,
            onMark: onMark,
            onSelect: onSelect,
            onUndo: onUndo,
            undoIdentity: undoIdentity,
            reduceMotion: reduceMotion,
            lightDirection: lightDirection,
          )
        else
          _EveningRecord(
            state: state,
            card: card,
            onUndo: onUndo,
            undoIdentity: undoIdentity,
          ),
        const SizedBox(height: 8),
        const _EveningRule(),
        // While a class can still be marked the glass stays about that: the
        // music joins once the day is on one line.
        if (music != null && card.foremost == null) ...[
          _EveningMusicRow(music: music),
          const _EveningRule(),
        ],
        _EveningDoors(onWrite: evening.onWrite, onCloseDay: evening.onCloseDay),
      ],
    );
  }
}

class _EveningRule extends StatelessWidget {
  const _EveningRule();

  @override
  Widget build(BuildContext context) => Container(
    height: 1,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          Palette.brass.withValues(alpha: 0.26),
          Palette.brass.withValues(alpha: 0.08),
        ],
      ),
    ),
  );
}

/// "Tuesday’s classes, both attended   +60 XP", on one line. The newest
/// gesture can be swiped left past 42% to undo, as on the card.
class _EveningRecord extends StatelessWidget {
  const _EveningRecord({
    required this.state,
    required this.card,
    this.onUndo,
    this.undoIdentity,
  });

  final GameState state;
  final ClassCard card;
  final VoidCallback? onUndo;
  final String? undoIdentity;

  @override
  Widget build(BuildContext context) {
    final words = classRecordLine(card);
    final xp = state.classXpForDay(card.day.dayKey);
    // One line. At large text the words may wrap rather than shrink.
    final large = MediaQuery.textScalerOf(context).scale(10) > 11.5;
    final text = Text(
      words,
      key: const Key('class-evening-record-words'),
      maxLines: large ? 2 : 1,
      softWrap: large,
      overflow: large ? TextOverflow.ellipsis : TextOverflow.visible,
      style: _serif(18, color: Palette.textMid, height: 1.15),
    );
    final Widget line = Semantics(
      label: xp > 0 ? '$words, $xp XP' : words,
      excludeSemantics: true,
      child: ConstrainedBox(
        key: const Key('class-evening-record'),
        constraints: const BoxConstraints(minHeight: 44),
        child: Row(
          children: [
            Expanded(
              child: large
                  ? text
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: text,
                    ),
            ),
            if (xp > 0)
              Padding(
                padding: const EdgeInsets.only(left: 10),
                child: Text(
                  '+$xp XP',
                  style: Type.numerals.copyWith(
                    fontSize: 16,
                    color: Palette.xpLight,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    final undo = onUndo;
    if (undo == null || undoIdentity == null) return line;
    return Dismissible(
      key: ValueKey('class-undo-$undoIdentity'),
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
      child: line,
    );
  }
}

/// The room's music, in the glass: Lamp left on, then the room's rotation,
/// through the shell's own controller. It plays only when he presses it (or
/// when his saved setting already has music on), and pausing it here is for
/// tonight: his setting in Me is never rewritten.
class _EveningMusicRow extends StatelessWidget {
  const _EveningMusicRow({required this.music});

  final ClassEveningMusic music;

  static final _lampAsset = MainRoomMusic.assetForTake(
    MainRoomMusic.lampLeftOnTake,
  );

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: music.on,
      builder: (context, on, _) => ValueListenableBuilder<String?>(
        valueListenable: music.nowPlaying,
        builder: (context, playing, _) {
          // The rotation's other takes are the room's music; until a take
          // has started, the control names what its press begins.
          final title = on && playing != null && playing != _lampAsset
              ? 'Room music'
              : 'Lamp left on';
          return Pressable(
            key: const Key('class-evening-music'),
            material: MaterialSound.glass,
            interactionSound: InteractionSound.select,
            pressDepth: 1,
            edgeColor: Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            semanticLabel: on ? 'Music: $title. Pause' : 'Play $title',
            semanticToggled: on,
            onTapUp: (_) => music.onToggle(),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Row(
                children: [
                  SizedBox.square(
                    dimension: 44,
                    child: Center(child: _PlayDisc(on: on)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _glassLabel('MUSIC'),
                        const SizedBox(height: 3),
                        Text(
                          title,
                          key: const Key('class-evening-music-title'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _serif(19, color: Palette.textHi),
                        ),
                      ],
                    ),
                  ),
                  if (on)
                    const Padding(
                      padding: EdgeInsets.only(left: 8, right: 2),
                      child: _Levels(),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A fine brass ring with play or pause in it: lit by the glass, never a
/// second gold control.
class _PlayDisc extends StatelessWidget {
  const _PlayDisc({required this.on});

  final bool on;

  @override
  Widget build(BuildContext context) => Container(
    width: 32,
    height: 32,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(
        color: Palette.brassLit.withValues(alpha: on ? 0.7 : 0.5),
        width: 1.1,
      ),
    ),
    child: Icon(
      on ? Icons.pause_rounded : Icons.play_arrow_rounded,
      size: 18,
      color: Palette.brassLit.withValues(alpha: 0.9),
    ),
  );
}

/// Four still bars: the music is on.
class _Levels extends StatelessWidget {
  const _Levels();

  @override
  Widget build(BuildContext context) => Row(
    key: const Key('class-evening-music-levels'),
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      for (final h in const [6.0, 11.0, 5.0, 8.0])
        Container(
          width: 2,
          height: h,
          margin: const EdgeInsets.only(left: 2.5),
          color: Palette.brassLit.withValues(alpha: 0.6),
        ),
    ],
  );
}

/// A page in the journal, and closing the day once the wind-down has begun.
class _EveningDoors extends StatelessWidget {
  const _EveningDoors({required this.onWrite, this.onCloseDay});

  final VoidCallback onWrite;
  final VoidCallback? onCloseDay;

  @override
  Widget build(BuildContext context) {
    final close = onCloseDay;
    return Row(
      children: [
        Expanded(
          child: Pressable(
            key: const Key('class-evening-write'),
            material: MaterialSound.parchment,
            interactionSound: InteractionSound.open,
            pressDepth: 1,
            edgeColor: Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            semanticLabel: 'Write a line in the journal',
            onTapUp: (_) => onWrite(),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Write a line',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _serif(19, color: Palette.textHi),
                ),
              ),
            ),
          ),
        ),
        if (close != null)
          Flexible(
            child: Pressable(
              key: const Key('class-evening-close-day'),
              // The board's own rail voices the ledger with the glass.
              material: MaterialSound.glass,
              interactionSound: InteractionSound.select,
              pressDepth: 1,
              edgeColor: Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              semanticLabel: 'Close the day',
              onTapUp: (_) => close(),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 52),
                child: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Icon(
                        Icons.nightlight_outlined,
                        size: 18,
                        color: Palette.xpLight,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'CLOSE THE DAY',
                            maxLines: 1,
                            style: Type.label.copyWith(
                              fontSize: Type.minLabel,
                              letterSpacing: 1.15,
                              color: Palette.xpLight,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: Palette.textLo,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
