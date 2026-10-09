// The evening on a class day: once the last class is over and every class is
// kept (or the wind-down has begun), the room turns to the window and the
// armchair and the glass holds the rest of the day in two calm lines: the
// day's record, then one quiet row of doors (the music, a page in the
// journal, closing the day), all in the glass and none on the painting. A
// class still unmarked is neutral: while one can be marked, the glass leads
// with it exactly as during the day, and nothing ever counts the rest.
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
    final waiting = card.foremost != null;
    return Column(
      key: const Key('class-evening'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Something can still be marked: the glass leads with it, one press
        // as during the day, and keeps only what that needs. Otherwise the
        // day is one line.
        if (waiting)
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
            compact: true,
          )
        else
          _EveningRecord(
            state: state,
            card: card,
            onUndo: onUndo,
            undoIdentity: undoIdentity,
          ),
        SizedBox(height: waiting ? 6 : 0),
        // While a class can still be marked the glass stays about that: the
        // music joins once the day is on one line.
        _EveningDoors(
          music: waiting ? null : evening.music,
          onWrite: evening.onWrite,
          onCloseDay: evening.onCloseDay,
          reduceMotion: reduceMotion,
        ),
      ],
    );
  }
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
      style: _serif(19, color: Palette.textHi, height: 1.15),
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

/// One quiet row of doors under the record: the room's music, a page in the
/// journal, and closing the day once the wind-down has begun. Dimmer than
/// the record they serve; at large text they wrap rather than shrink.
class _EveningDoors extends StatelessWidget {
  const _EveningDoors({
    required this.onWrite,
    this.onCloseDay,
    this.music,
    this.reduceMotion = false,
  });

  final VoidCallback onWrite;
  final VoidCallback? onCloseDay;
  final ClassEveningMusic? music;
  final bool reduceMotion;

  static TextStyle get _style => _serif(17, color: Palette.textMid);

  @override
  Widget build(BuildContext context) {
    final music = this.music;
    final close = onCloseDay;
    final doors = <Widget>[
      if (music != null)
        _EveningMusicDoor(music: music, reduceMotion: reduceMotion),
      _Door(
        key: const Key('class-evening-write'),
        label: 'Write a line',
        semanticLabel: 'Write a line in the journal',
        material: MaterialSound.parchment,
        sound: InteractionSound.open,
        onTap: onWrite,
      ),
      if (close != null)
        _Door(
          key: const Key('class-evening-close-day'),
          label: 'Close the day',
          semanticLabel: 'Close the day',
          // The board's own rail voices the ledger with the glass.
          material: MaterialSound.glass,
          sound: InteractionSound.select,
          onTap: close,
        ),
    ];
    return LayoutBuilder(
      builder: (context, box) {
        // One line with a dot between doors when it fits; otherwise the
        // doors wrap, each whole, and every label keeps the text size.
        final scaler = MediaQuery.textScalerOf(context);
        final direction = Directionality.of(context);
        double widthOf(String text) {
          final painter = TextPainter(
            text: TextSpan(text: text, style: _style),
            textDirection: direction,
            textScaler: scaler,
            maxLines: 1,
          )..layout();
          final w = painter.width;
          painter.dispose();
          return w;
        }

        final labels = [
          if (music != null) 'Lamp left on',
          'Write a line',
          if (close != null) 'Close the day',
        ];
        final needed =
            labels.fold(0.0, (sum, label) => sum + widthOf(label)) +
            (music != null ? _EveningMusicDoor.glyphWidth : 0) +
            (labels.length - 1) * _Dot.width +
            labels.length * _Door.padding * 2;
        if (needed <= box.maxWidth) {
          return Row(
            key: const Key('class-evening-doors'),
            children: [
              for (var i = 0; i < doors.length; i++) ...[
                if (i > 0) const _Dot(),
                doors[i],
              ],
            ],
          );
        }
        // Too wide for one line: the music keeps a line of its own and the
        // day's two doors share the next, so no door is left on its own.
        if (music != null && doors.length > 2) {
          return Column(
            key: const Key('class-evening-doors'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              doors.first,
              Wrap(spacing: 14, children: doors.sublist(1)),
            ],
          );
        }
        return Wrap(
          key: const Key('class-evening-doors'),
          spacing: 14,
          children: doors,
        );
      },
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  static const width = 18.0;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Center(
      child: Container(
        width: 3,
        height: 3,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Palette.brass.withValues(alpha: 0.6),
        ),
      ),
    ),
  );
}

/// A door in the glass: quiet serif words, a whole-height target.
class _Door extends StatelessWidget {
  const _Door({
    super.key,
    required this.label,
    required this.semanticLabel,
    required this.material,
    required this.sound,
    required this.onTap,
    this.leading,
    this.toggled,
    this.textKey,
  });

  static const padding = 4.0;

  final String label;
  final String semanticLabel;
  final MaterialSound material;
  final InteractionSound sound;
  final VoidCallback onTap;
  final Widget? leading;
  final bool? toggled;
  final Key? textKey;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      material: material,
      interactionSound: sound,
      pressDepth: 1,
      edgeColor: Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      semanticLabel: semanticLabel,
      semanticToggled: toggled,
      onTapUp: (_) => onTap(),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: padding),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ?leading,
              Text(
                label,
                key: textKey,
                maxLines: 1,
                softWrap: false,
                style: _EveningDoors._style,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The room's music, as a door: Lamp left on, then the room's rotation,
/// through the shell's own controller. It plays only when he presses it (or
/// when his saved setting already has music on), and pausing it here is for
/// tonight: his setting in Me is never rewritten.
class _EveningMusicDoor extends StatelessWidget {
  const _EveningMusicDoor({required this.music, this.reduceMotion = false});

  final ClassEveningMusic music;
  final bool reduceMotion;

  /// The glyph before the words and its gap.
  static const glyphWidth = 22.0;

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
          return _Door(
            key: const Key('class-evening-music'),
            label: title,
            textKey: const Key('class-evening-music-title'),
            semanticLabel: on ? 'Music: $title. Pause' : 'Play $title',
            toggled: on,
            material: MaterialSound.glass,
            sound: InteractionSound.select,
            onTap: music.onToggle,
            leading: SizedBox(
              width: glyphWidth,
              child: Align(
                alignment: Alignment.centerLeft,
                child: on
                    ? _Levels(still: reduceMotion)
                    : const _PlayMark(key: Key('class-evening-music-play')),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A small brass play mark: what a press begins.
class _PlayMark extends StatelessWidget {
  const _PlayMark({super.key});

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size(9, 11),
    painter: _PlayMarkPainter(Palette.brassLit.withValues(alpha: 0.85)),
  );
}

class _PlayMarkPainter extends CustomPainter {
  const _PlayMarkPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(0.5, 0.5)
        ..lineTo(size.width - 0.5, size.height / 2)
        ..lineTo(0.5, size.height - 0.5)
        ..close(),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_PlayMarkPainter old) => old.color != color;
}

/// Three fine bars that rise and fall slowly while the music plays (held
/// still under Reduce Motion).
class _Levels extends StatefulWidget {
  const _Levels({this.still = false});

  final bool still;

  @override
  State<_Levels> createState() => _LevelsState();
}

class _LevelsState extends State<_Levels> with SingleTickerProviderStateMixin {
  late final AnimationController _t = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  );

  @override
  void initState() {
    super.initState();
    if (!widget.still) _t.repeat();
  }

  @override
  void didUpdateWidget(_Levels old) {
    super.didUpdateWidget(old);
    if (widget.still && _t.isAnimating) {
      _t.stop();
    } else if (!widget.still && !_t.isAnimating) {
      _t.repeat();
    }
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    key: const Key('class-evening-music-levels'),
    width: 14,
    height: 12,
    child: AnimatedBuilder(
      animation: _t,
      builder: (context, _) => CustomPaint(
        painter: _LevelsPainter(
          t: _t.value,
          color: Palette.brassLit.withValues(alpha: 0.8),
        ),
      ),
    ),
  );
}

class _LevelsPainter extends CustomPainter {
  const _LevelsPainter({required this.t, required this.color});

  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    // Each bar breathes on its own slow cycle (2, 3 and 4 times a loop),
    // never in step: a quiet sign of music, not a meter.
    const base = [0.55, 0.85, 0.4];
    const cycles = [2.0, 3.0, 4.0];
    const phase = [0.0, 1.7, 3.1];
    for (var i = 0; i < 3; i++) {
      final wave = math.sin(2 * math.pi * cycles[i] * t + phase[i]);
      final h = (size.height * (base[i] + 0.22 * wave)).clamp(3.0, size.height);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(i * 5.0, size.height - h, 2, h),
          const Radius.circular(1),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_LevelsPainter old) => old.t != t || old.color != color;
}
