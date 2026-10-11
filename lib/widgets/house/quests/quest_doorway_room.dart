// The Quests tab on a day with no classes: the Doorway, with today's three on
// its rail and one pane of glass over the dock.
//
// It is the class-day room's sibling. The same scene, the same glass and the
// same quiet bar; the rail holds the three quests as tickets, the glass leads
// with the foremost one (its title, one supporting line, MARK COMPLETE), and
// FOCUS, ADD and BOARD sit under a fine rule. Completing a quest, from the
// bar or by lifting its ticket, is the same lift, flip, stamp and hang in the
// scene; the glass moves on to the next at once. When all three are kept the
// tickets go into the bowl and the glass says the day is enough. Nothing
// covers the screen: a single quest completes in the scene.
//
// Never punish: no count of what was not done, no "of three", no red. A
// quest set aside for today stays one of the three, quiet.
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../../../academic_calendar/domain/academic_schedule.dart'
    show CivilDate;
import '../../../audio.dart' show InteractionSound, MaterialSound;
import '../../../clock.dart';
import '../../../engine.dart';
import '../../../models.dart';
import '../../../tokens.dart';
import '../../class_day/class_day_room.dart'
    show ClassDayHud, ClassGlass, ClassThereButton, classStatusAbove;
import '../../class_day/class_room_stage.dart' show classStatusScrimHeight;
import '../../class_day/doorway_model.dart';
import '../../class_day/doorway_motion.dart' show DoorwayBeat;
import '../../class_day/doorway_stage.dart';
import '../../pressable.dart';
import '../../routine_ledger.dart' show LedgerType;
import '../house_room.dart' show HouseRoom;
import '../house_travel_scope.dart' show HouseRoomUi;
import 'quest_doorway_model.dart';

/// What the glass card shows, by the state of today's three.
enum QuestCardMode {
  /// Today's three are not chosen: three empty rings and a quiet invitation.
  choose,

  /// A quest leads: title, supporting line, the bar.
  lead,

  /// Every chosen quest is kept: the day is enough.
  kept,

  /// Nothing is open, but a chosen quest is set aside for today.
  resting,

  /// The night's ledger is closed; the day is kept until morning.
  closed,
}

class QuestDoorwayRoom extends StatefulWidget {
  const QuestDoorwayRoom({
    super.key,
    required this.state,
    required this.read,
    required this.date,
    required this.supportFor,
    required this.onComplete,
    required this.onSelect,
    required this.onChoose,
    required this.onFocus,
    required this.onAdd,
    required this.onBoard,
    required this.onExploreStat,
    required this.dockHeight,
    this.onCloseDay,
    this.onUndo,
    this.undoLabel,
    this.dayRested = false,
    this.sideOpen = 0,
    this.dayHeld = true,
    this.reduceMotion = false,
    this.parallax,
    this.lightDirection,
    this.quiet = false,
    this.onBeat,
    this.hudKey,
  });

  final GameState state;
  final QuestDoorwayRead read;
  final CivilDate date;

  /// The one supporting line under a quest's title (a note, its goal, a hint
  /// or the companion's line), or null for none.
  final String? Function(Quest quest) supportFor;

  /// Completes [quest]; [anchor] is where the press was, in global points.
  final void Function(Quest quest, Offset anchor) onComplete;

  /// A waiting ticket was tapped: bring that quest forward.
  final ValueChanged<Quest> onSelect;

  /// Opens the Today's three chooser.
  final VoidCallback onChoose;
  final VoidCallback onFocus;
  final VoidCallback onAdd;

  /// Opens the full board.
  final VoidCallback onBoard;
  final ValueChanged<Stat> onExploreStat;

  /// The shell's dock (88 pt plus the home indicator) sits over the page.
  final double dockHeight;

  /// "Close the day" on the cleared card, when tonight can be closed.
  final VoidCallback? onCloseDay;

  /// The last quest just kept can be taken back; [undoLabel] names it.
  final VoidCallback? onUndo;
  final String? undoLabel;

  /// Tonight's ledger is closed and the day rests.
  final bool dayRested;

  /// Quests still open beyond today's three.
  final int sideOpen;

  /// Whether the whole required day (the three and any dated commitment) is
  /// kept. False says a commitment waits on the board.
  final bool dayHeld;
  final bool reduceMotion;
  final ValueListenable<Offset>? parallax;
  final ValueListenable<Offset>? lightDirection;

  /// The real level-up is up: the room's words step back behind it.
  final bool quiet;

  /// The Doorway's moves the page waits on.
  final ValueChanged<DoorwayBeat>? onBeat;

  /// Keys the HUD, so a completion's XP can fly to it.
  final GlobalKey? hudKey;

  @override
  State<QuestDoorwayRoom> createState() => QuestDoorwayRoomState();
}

class QuestDoorwayRoomState extends State<QuestDoorwayRoom> {
  final GlobalKey _bar = GlobalKey();
  final GlobalKey _stage = GlobalKey();

  QuestCardMode get mode {
    final read = widget.read;
    if (widget.dayRested) return QuestCardMode.closed;
    if (!read.hasField || read.field.isEmpty) return QuestCardMode.choose;
    if (read.foremost != null) return QuestCardMode.lead;
    if (read.allKept) return QuestCardMode.kept;
    return QuestCardMode.resting;
  }

  Offset _barCenter() {
    final box = _bar.currentContext?.findRenderObject();
    if (box is RenderBox && box.attached && box.hasSize) {
      return box.localToGlobal(box.size.center(Offset.zero));
    }
    final size = MediaQuery.sizeOf(context);
    return Offset(size.width / 2, size.height * 0.68);
  }

  /// Where a ticket lifted from the rail was, roughly, in global points.
  Offset _railAnchor() {
    final box = _stage.currentContext?.findRenderObject();
    if (box is RenderBox && box.attached && box.hasSize) {
      return box.localToGlobal(
        Offset(box.size.width * 0.82, box.size.width * 0.74),
      );
    }
    final size = MediaQuery.sizeOf(context);
    return Offset(size.width * 0.82, size.height * 0.34);
  }

  void _markTicket(DoorwayTicket ticket) {
    final quest = widget.read.questFor(ticket.id);
    if (quest == null || quest.doneFor(Clock.now())) return;
    widget.onComplete(quest, _railAnchor());
  }

  void _selectTicket(DoorwayTicket ticket) {
    final quest = widget.read.questFor(ticket.id);
    if (quest != null) widget.onSelect(quest);
  }

  @override
  Widget build(BuildContext context) {
    final above = classStatusAbove(context);
    final topPad = MediaQuery.paddingOf(context).top;
    final scrimHeight = math.max(
      91.0,
      above + topPad + classStatusScrimHeight - 59,
    );
    final cardMode = mode;
    return ColoredBox(
      color: Palette.parchment,
      child: Padding(
        padding: EdgeInsets.only(bottom: widget.dockHeight),
        child: CustomMultiChildLayout(
          delegate: _QuestRoomDelegate(
            above: above,
            topPad: topPad,
            invitation: cardMode == QuestCardMode.choose,
          ),
          children: [
            LayoutId(
              id: _Slot.stage,
              child: DoorwayStage(
                key: _stage,
                day: widget.read.day,
                parallax: widget.parallax,
                reduceMotion: widget.reduceMotion,
                scrimHeight: scrimHeight,
                onMarkTicket: _markTicket,
                onSelectTicket: _selectTicket,
                semanticTickets: true,
                onBeat: widget.onBeat,
              ),
            ),
            LayoutId(
              id: _Slot.glass,
              child: _Quiet(
                quiet: widget.quiet,
                child: ClassGlass(
                  key: const Key('quest-day-glass'),
                  padding: cardMode == QuestCardMode.choose
                      ? const EdgeInsets.fromLTRB(22, 17, 22, 12)
                      : const EdgeInsets.fromLTRB(22, 17, 22, 6),
                  child: _card(cardMode),
                ),
              ),
            ),
            LayoutId(
              id: _Slot.hud,
              child: _Quiet(
                quiet: widget.quiet,
                child: KeyedSubtree(
                  key: widget.hudKey,
                  child: ClassDayHud(
                    state: widget.state,
                    date: widget.date,
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

  // ── The card ────────────────────────────────────────────────────────────

  Widget _card(QuestCardMode cardMode) {
    if (cardMode == QuestCardMode.choose) return _chooseCard();
    final read = widget.read;
    final quest = read.foremost;
    final String title;
    String? support;
    String? note;
    Widget? bar;
    switch (cardMode) {
      case QuestCardMode.lead:
        title = quest!.displayTitle;
        support = widget.supportFor(quest);
        bar = _leadBar(quest);
      case QuestCardMode.kept:
        title = widget.dayHeld ? 'Enough for today' : 'Today’s three are kept';
        support = widget.dayHeld
            ? 'What you chose for today is kept.'
            : 'A dated commitment is still open on the board.';
        note = !widget.dayHeld
            ? null
            : widget.sideOpen == 0
            ? 'nothing else needs carrying'
            : '${widget.sideOpen} quest${widget.sideOpen == 1 ? '' : 's'} '
                  'still open if the day has room';
        if (widget.onCloseDay != null) {
          bar = _closeBar();
        }
      case QuestCardMode.resting:
        title = 'A chosen quest is set aside';
        support =
            'It is still one of today’s three, just resting out of sight. '
            'Bring it back when you are ready.';
        bar = _plainBar('EDIT TODAY’S THREE', widget.onChoose);
      case QuestCardMode.closed:
        title = 'The day is kept';
        support = 'Rest well. Tomorrow is already taking shape.';
      case QuestCardMode.choose:
        return _chooseCard();
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(
          child: SingleChildScrollView(
            key: const Key('quest-day-scroll'),
            primary: false,
            clipBehavior: Clip.none,
            physics: const ClampingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(),
                const SizedBox(height: 6),
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    key: const Key('quest-day-title'),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: LedgerType.display.copyWith(
                      fontSize: 27,
                      height: 1.04,
                      fontWeight: FontWeight.w500,
                      color: Palette.textHi,
                    ),
                  ),
                ),
                if (support != null && support.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    support,
                    key: const Key('quest-day-support'),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: _serif(
                      16,
                      color: Palette.textMid,
                      style: FontStyle.italic,
                    ),
                  ),
                ],
                if (note != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    note,
                    style: _serif(
                      14,
                      color: Palette.textLo,
                      style: FontStyle.italic,
                    ),
                  ),
                ],
                if (bar != null) ...[const SizedBox(height: 12), bar],
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        const _Rule(),
        _tools(),
      ],
    );
  }

  Widget _header() {
    final read = widget.read;
    final undo = widget.onUndo;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          Semantics(
            label: read.semantics,
            excludeSemantics: true,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'TODAY’S THREE',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Type.label.copyWith(
                      fontSize: Type.minLabel,
                      letterSpacing: 2.2,
                      color: Palette.brassLit.withValues(alpha: 0.72),
                    ),
                  ),
                ),
                QuestRings(
                  key: const Key('quest-day-rings'),
                  pips: read.pips,
                  foremostIndex: read.foremost == null
                      ? -1
                      : read.field.indexWhere(
                          (q) => identical(q, read.foremost),
                        ),
                  reduceMotion: widget.reduceMotion,
                ),
                // The Undo pill's own place: the rings never move for it.
                const SizedBox(width: 78),
              ],
            ),
          ),
          if (undo != null)
            Positioned(
              right: 0,
              child: _UndoPill(
                label: widget.undoLabel ?? 'the last quest',
                onTap: undo,
              ),
            ),
        ],
      ),
    );
  }

  Widget _leadBar(Quest quest) => KeyedSubtree(
    key: _bar,
    child: ClassThereButton(
      label: questBarLabel(quest),
      semanticLabel: '${questBarLabel(quest)}: ${quest.displayTitle}',
      light: widget.lightDirection,
      reduceMotion: widget.reduceMotion,
      onTap: () => widget.onComplete(quest, _barCenter()),
    ),
  );

  Widget _closeBar() => KeyedSubtree(
    key: _bar,
    child: ClassThereButton(
      label: 'CLOSE THE DAY',
      semanticLabel: 'Close the day',
      light: widget.lightDirection,
      reduceMotion: widget.reduceMotion,
      onTap: widget.onCloseDay!,
    ),
  );

  Widget _plainBar(String label, VoidCallback onTap) => KeyedSubtree(
    key: _bar,
    child: ClassThereButton(
      label: label,
      semanticLabel: label,
      light: widget.lightDirection,
      reduceMotion: widget.reduceMotion,
      onTap: onTap,
    ),
  );

  Widget _chooseCard() {
    final dim = widget.dayRested;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(
          child: SingleChildScrollView(
            key: const Key('quest-day-scroll'),
            primary: false,
            physics: const ClampingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: QuestRings(
                    key: const Key('quest-day-rings'),
                    pips: widget.read.pips,
                    foremostIndex: -1,
                    reduceMotion: widget.reduceMotion,
                    big: true,
                  ),
                ),
                Pressable(
                  key: const Key('quest-day-choose'),
                  pressDepth: 1,
                  soundEnabled: false,
                  edgeColor: Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  material: MaterialSound.parchment,
                  interactionSound: InteractionSound.navigate,
                  enabled: !dim,
                  semanticLabel:
                      'Choose today’s three: up to three quests to carry',
                  onTapUp: (_) => widget.onChoose(),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 52),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: ExcludeSemantics(
                          child: Text(
                            'Choose today’s three',
                            textAlign: TextAlign.center,
                            style: LedgerType.display.copyWith(
                              fontSize: 26,
                              height: 1.05,
                              fontWeight: FontWeight.w500,
                              color: Palette.textHi,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        _Cells(
          cells: [
            _Cell('ADD', 'Add a quest', widget.onAdd, key: 'add'),
            _Cell(
              'BOARD',
              'Show the full Quest board',
              widget.onBoard,
              key: 'board',
            ),
          ],
          quiet: true,
        ),
      ],
    );
  }

  Widget _tools() {
    final resting = mode == QuestCardMode.closed;
    return _Cells(
      cells: [
        _Cell(
          'FOCUS',
          'Focus on one quest at a time',
          resting ? null : widget.onFocus,
          key: 'focus',
        ),
        _Cell('ADD', 'Add a quest', resting ? null : widget.onAdd, key: 'add'),
        _Cell(
          'BOARD',
          'Show the full Quest board',
          widget.onBoard,
          key: 'board',
        ),
      ],
    );
  }
}

// ── Pieces ────────────────────────────────────────────────────────────────

TextStyle _serif(
  double size, {
  Color? color,
  FontStyle? style,
  double height = 1.14,
}) => LedgerType.body.copyWith(
  fontSize: size,
  height: height,
  fontStyle: style,
  color: color ?? Palette.textMid,
);

class _Rule extends StatelessWidget {
  const _Rule();

  @override
  Widget build(BuildContext context) => Container(
    height: 1,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          Palette.brass.withValues(alpha: 0.32),
          Palette.brass.withValues(alpha: 0.06),
        ],
      ),
    ),
  );
}

class _Cell {
  const _Cell(this.label, this.semantic, this.onTap, {required this.key});

  final String label;
  final String semantic;
  final VoidCallback? onTap;
  final String key;
}

/// The glass's foot: equal cells with a hairline between, or (when [quiet])
/// two small words with a dot between, centered.
class _Cells extends StatelessWidget {
  const _Cells({required this.cells, this.quiet = false});

  final List<_Cell> cells;
  final bool quiet;

  @override
  Widget build(BuildContext context) {
    Widget word(_Cell cell) => Pressable(
      key: Key('quest-day-${cell.key}'),
      pressDepth: 1,
      soundEnabled: false,
      edgeColor: Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      material: MaterialSound.parchment,
      interactionSound: InteractionSound.navigate,
      enabled: cell.onTap != null,
      semanticLabel: cell.semantic,
      onTapUp: (_) => cell.onTap?.call(),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
        child: Center(
          widthFactor: quiet ? 1 : null,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: quiet ? 10 : 4),
            child: ExcludeSemantics(
              child: Text(
                cell.label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.fade,
                style: Type.label.copyWith(
                  fontSize: Type.minLabel,
                  letterSpacing: quiet ? 2.2 : 2.4,
                  color: Palette.textMid.withValues(
                    alpha: cell.onTap == null ? 0.4 : (quiet ? 0.8 : 0.95),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (quiet) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < cells.length; i++) ...[
            if (i > 0)
              Text(
                '·',
                style: Type.label.copyWith(
                  fontSize: Type.minLabel,
                  color: Palette.textLo,
                ),
              ),
            word(cells[i]),
          ],
        ],
      );
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < cells.length; i++) ...[
            if (i > 0)
              Container(
                width: 1,
                margin: const EdgeInsets.symmetric(vertical: 8),
                color: Palette.brass.withValues(alpha: 0.2),
              ),
            Expanded(child: word(cells[i])),
          ],
        ],
      ),
    );
  }
}

/// "Undo": a small outlined pill at the header's end while the last quest can
/// be taken back.
class _UndoPill extends StatelessWidget {
  const _UndoPill({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    key: const Key('quest-day-undo'),
    pressDepth: 1,
    soundEnabled: false,
    edgeColor: Colors.transparent,
    borderRadius: BorderRadius.circular(20),
    semanticLabel: 'Undo: take $label back',
    onTapUp: (_) => onTap(),
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44, minWidth: 56),
      child: Center(
        widthFactor: 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Palette.brassLit.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
            child: ExcludeSemantics(
              child: Text(
                'Undo',
                style: _serif(
                  16,
                  color: Palette.brassLit,
                  style: FontStyle.italic,
                  height: 1,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Today's three rings: kept ones are filled honey, the quest that leads has a
/// bright whole ring, the others wait as dashed ones. Never a fraction.
class QuestRings extends StatelessWidget {
  const QuestRings({
    super.key,
    required this.pips,
    required this.foremostIndex,
    this.reduceMotion = false,
    this.big = false,
  });

  final List<QuestPip> pips;
  final int foremostIndex;
  final bool reduceMotion;

  /// The invitation's larger, centered rings.
  final bool big;

  @override
  Widget build(BuildContext context) {
    final size = big ? 18.0 : 12.0;
    final gap = big ? 12.0 : 7.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < pips.length; i++) ...[
          if (i > 0) SizedBox(width: gap),
          TweenAnimationBuilder<double>(
            tween: Tween(end: pips[i] == QuestPip.kept ? 1.0 : 0.0),
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 450),
            curve: Curves.easeOut,
            builder: (context, fill, _) => SizedBox.square(
              dimension: size,
              child: CustomPaint(
                painter: _RingPainter(
                  fill: fill,
                  pip: pips[i],
                  current: i == foremostIndex && pips[i] == QuestPip.open,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.fill,
    required this.pip,
    required this.current,
  });

  final double fill;
  final QuestPip pip;
  final bool current;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 0.9;
    if (fill > 0.001) {
      canvas.drawCircle(
        c,
        r + 2.5,
        Paint()
          ..color = const Color(0xFFE8B464).withValues(alpha: 0.32 * fill)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [
              Color.lerp(
                const Color(0x00F7D68E),
                const Color(0xFFF7D68E),
                fill,
              )!,
              Color.lerp(
                const Color(0x00D9A24F),
                const Color(0xFFD9A24F),
                fill,
              )!,
            ],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width > 14 ? 1.5 : 1.4;
    if (fill > 0.5) {
      edge.color = const Color(0xFFE8C27A);
      canvas.drawCircle(c, r, edge);
    } else if (current) {
      edge
        ..color = const Color(0xFFE0B66D)
        ..strokeWidth = 1.6;
      canvas.drawCircle(c, r, edge);
    } else {
      // Dashed: a ring that waits (or rests), and an empty place.
      edge.color = pip == QuestPip.empty
          ? const Color(0xFF9C7A4C).withValues(alpha: 0.85)
          : const Color(0xFFB08A55);
      const dashes = 10;
      const sweep = math.pi * 2 / dashes;
      for (var i = 0; i < dashes; i++) {
        canvas.drawArc(
          Rect.fromCircle(center: c, radius: r),
          i * sweep,
          sweep * 0.55,
          false,
          edge,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fill != fill || old.pip != pip || old.current != current;
}

// ── Layout ────────────────────────────────────────────────────────────────

enum _Slot { stage, glass, hud }

class _Quiet extends StatelessWidget {
  const _Quiet({required this.quiet, required this.child});

  final bool quiet;
  final Widget child;

  @override
  Widget build(BuildContext context) => HouseRoomUi(
    room: HouseRoom.quests,
    child: AnimatedOpacity(
      opacity: quiet ? 0 : 1,
      duration: const Duration(milliseconds: 240),
      child: IgnorePointer(ignoring: quiet, child: child),
    ),
  );
}

/// The Doorway fills the page; the glass floats above the dock; the HUD sits
/// over the room's top edge. The invitation (nothing chosen yet) is a smaller,
/// narrower pane that sits a little higher.
class _QuestRoomDelegate extends MultiChildLayoutDelegate {
  _QuestRoomDelegate({
    required this.above,
    required this.topPad,
    required this.invitation,
  });

  final double above;
  final double topPad;
  final bool invitation;

  static const hudTop = 8.0;

  @override
  void performLayout(Size size) {
    final belowGlass = invitation ? 52.0 : 14.0;
    final inset = invitation ? 40.0 : 16.0;
    final hud = layoutChild(
      _Slot.hud,
      BoxConstraints.tightFor(width: size.width - 40),
    );
    positionChild(_Slot.hud, Offset(20, topPad + hudTop));
    final glass = layoutChild(
      _Slot.glass,
      BoxConstraints(
        minWidth: size.width - inset * 2,
        maxWidth: size.width - inset * 2,
        maxHeight: math.max(
          140,
          size.height - belowGlass - (topPad + hudTop + hud.height + 56),
        ),
      ),
    );
    positionChild(
      _Slot.glass,
      Offset(inset, size.height - belowGlass - glass.height),
    );
    layoutChild(
      _Slot.stage,
      BoxConstraints.tightFor(width: size.width, height: size.height + above),
    );
    positionChild(_Slot.stage, Offset(0, -above));
  }

  @override
  bool shouldRelayout(_QuestRoomDelegate old) =>
      old.above != above ||
      old.topPad != topPad ||
      old.invitation != invitation;
}
