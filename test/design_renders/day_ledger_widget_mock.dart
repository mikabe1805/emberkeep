// MOCK of the Day Ledger home-screen widget, drawn in Flutter from the same
// decisions the SwiftUI views make (test/home_widgets/day_ledger_mirror.dart
// mirrors ios/RoomOfDaysWidgets/RoomOfDaysWidgets.swift). The real widget is
// SwiftUI and compiles only on Codemagic's Mac, so this is the closest look
// available here.
//
// Approximations: Fraunces stands in for New York (the system serif), Inter
// for SF Pro, JetBrains Mono for SF Mono. The check ring is drawn the way the
// Swift `ClassRing` draws it. Sizes are real iPhone 15/16 Pro points: small
// 158 x 158, medium 338 x 158, with iOS 17's 16 pt content margins.
// [DayLedgerWidgetMock.typeScale] stands in for the Swift `typeScale` at the
// reader's text size (1.24 at accessibility sizes).
//
// Test-support library, not a test.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../home_widgets/day_ledger_mirror.dart';

// RoomWidgetPalette (RoomOfDaysWidgets.swift).
const _backdrop = Color.fromRGBO(19, 13, 11, 1);
const _panel = Color.fromRGBO(31, 21, 17, 1);
const _text = Color.fromRGBO(242, 219, 181, 1);
const _secondary = Color.fromRGBO(173, 148, 122, 1);
const _honey = Color.fromRGBO(232, 166, 61, 1);
const _brass = Color.fromRGBO(140, 99, 56, 1);
const _ink = Color.fromRGBO(41, 26, 15, 1);
const _brassLight = Color.fromRGBO(219, 189, 136, 1);
const _brassFace = Color.fromRGBO(197, 162, 114, 1);
const _brassEdge = Color.fromRGBO(121, 80, 43, 1);
const _brassDeep = Color.fromRGBO(76, 47, 19, 1);
const _brassTick = Color.fromRGBO(220, 180, 119, 1);
const _brassWireDark = Color.fromRGBO(122, 76, 36, 1);
const _brassWireMid = Color.fromRGBO(149, 96, 46, 1);
const _brassWireLight = Color.fromRGBO(227, 190, 124, 1);
const _brassWireHot = Color.fromRGBO(240, 214, 156, 1);

const _serif = 'Fraunces';
const _sans = 'Inter';
const _mono = 'JetBrainsMono';

enum LedgerFamily { small, medium }

const ledgerSmallSize = Size(158, 158);
const ledgerMediumSize = Size(338, 158);

TextStyle _serifStyle(double size, {Color color = _text}) => TextStyle(
  fontFamily: _serif,
  fontSize: size,
  fontWeight: FontWeight.w600,
  height: 1.18,
  color: color,
);

TextStyle _sansStyle(
  double size, {
  Color color = _secondary,
  FontWeight weight = FontWeight.w500,
}) => TextStyle(
  fontFamily: _sans,
  fontSize: size,
  fontWeight: weight,
  height: 1.2,
  color: color,
);

TextStyle _monoStyle(
  double size, {
  Color color = _secondary,
  FontWeight weight = FontWeight.w600,
  double tracking = 0,
}) => TextStyle(
  fontFamily: _mono,
  fontSize: size,
  fontWeight: weight,
  height: 1.2,
  letterSpacing: tracking,
  color: color,
);

/// The widget itself at its real size.
class DayLedgerWidgetMock extends StatelessWidget {
  const DayLedgerWidgetMock({
    super.key,
    required this.entry,
    required this.family,
    this.typeScale = 1,
  });

  final DayLedgerEntry entry;
  final LedgerFamily family;

  /// The Swift `typeScale`: 1 at the default text size, up to 1.24.
  final double typeScale;

  double _s(double size) => size * typeScale;

  @override
  Widget build(BuildContext context) {
    final size = family == LedgerFamily.small
        ? ledgerSmallSize
        : ledgerMediumSize;
    // SwiftUI text has no inherited letter spacing; Material 3's body style
    // (0.25) would widen every line the mock draws.
    return MediaQuery.withNoTextScaling(
      child: DefaultTextStyle(
        style: const TextStyle(fontFamily: _sans, color: _text),
        child: SizedBox.fromSize(
          size: size,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const LinearGradient(
                colors: [_panel, _backdrop],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ClipRect(
                child: family == LedgerFamily.small ? _small() : _medium(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── small ──────────────────────────────────────────────────────────────

  Widget _small() => switch (entry.mode) {
    LedgerMode.today => _smallToday(),
    LedgerMode.classes => _smallClasses(),
    LedgerMode.allKept => _smallAllKept(),
  };

  Widget _smallToday() {
    final next = entry.nextClass;
    if (next != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _eyebrow('NEXT CLASS', _honey),
          const SizedBox(height: 7),
          _nextClassName(next, compact: false),
          const SizedBox(height: 2),
          const Spacer(),
          _line(entry.classTime(next), _monoStyle(13, color: _honey)),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _eyebrow('NEXT CLASS', _honey),
        const SizedBox(height: 7),
        Text(
          'Your day is open',
          style: _serifStyle(19),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const Spacer(),
        Text(_questCountLine, style: _sansStyle(12)),
      ],
    );
  }

  String get _questCountLine {
    final quests = entry.quests;
    if (quests == null) return '';
    final count = quests.length;
    return count == 0
        ? 'Nothing waiting'
        : '$count quest${count == 1 ? '' : 's'} waiting';
  }

  /// A closed ring and the XP it paid: `HStack(spacing: 5)`.
  Widget _keptXp(int xp, double size, double ring) => Row(
    children: [
      ClassRingMock(kept: true, size: ring),
      const SizedBox(width: 5),
      _line('+$xp XP', _monoStyle(size, color: _honey)),
    ],
  );

  /// Up to two lines that may shrink to 80% before they truncate: SwiftUI's
  /// `.lineLimit(2).minimumScaleFactor(0.8)`.
  Widget _fitLines(String text, TextStyle style) => LayoutBuilder(
    builder: (context, constraints) {
      final resolved = DefaultTextStyle.of(context).style.merge(style);
      var fontSize = style.fontSize!;
      final floor = fontSize * 0.8;
      while (fontSize > floor) {
        final painter = TextPainter(
          text: TextSpan(
            text: text,
            style: resolved.copyWith(fontSize: fontSize),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 2,
        )..layout(maxWidth: constraints.maxWidth);
        final fits = !painter.didExceedMaxLines;
        painter.dispose();
        if (fits) break;
        fontSize -= 0.25;
      }
      return Text(
        text,
        style: style.copyWith(fontSize: fontSize),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    },
  );

  Widget _smallClasses() {
    final day = entry.activeClassDay!;
    final focus = entry.focusClass;
    final eyebrow = entry.classesDone
        ? '${_noun(day)} DONE'
        : day.weekday.toUpperCase();
    if (entry.markAllUrl != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _eyebrow(eyebrow, _secondary),
          const SizedBox(height: 5),
          Text(
            '${day.weekday}’s classes',
            style: _serifStyle(16),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          _line('Ended ${day.classes.last.endLabel}', _sansStyle(_s(11))),
          const SizedBox(height: 4),
          const Spacer(),
          _capsule(entry.markAllLabel, fullWidth: true),
        ],
      );
    }
    if (focus != null) {
      final next = entry.nextAfter;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _eyebrow(eyebrow, _secondary),
          const SizedBox(height: 5),
          _fitLines(focus.shortTitle, _serifStyle(16)),
          const SizedBox(height: 3),
          _line(_focusLine(focus, withPlace: false), _sansStyle(_s(11))),
          const SizedBox(height: 4),
          const Spacer(),
          if (focus.markUrl != null)
            _capsule(_markLabel(focus), fullWidth: true)
          else if (next != null)
            _nextTime(next.time),
        ],
      );
    }
    final kept = entry.lastKept!;
    final next = entry.nextAfter;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _eyebrow(eyebrow, _secondary),
        const SizedBox(height: 5),
        _fitLines(kept.shortTitle, _serifStyle(16)),
        const SizedBox(height: 4),
        _keptXp(kept.keptXp, _s(11), 14),
        const SizedBox(height: 4),
        const Spacer(),
        if (next != null) _nextTime(next.time),
      ],
    );
  }

  Widget _smallAllKept() {
    final day = entry.activeClassDay!;
    final next = entry.nextAfter;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _eyebrow(day.weekday.toUpperCase(), _secondary),
        const SizedBox(height: 5),
        Text(
          day.attendedShort ?? 'Attended',
          style: _serifStyle(18),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        _keptXp(day.classXp, _s(14), 15),
        const SizedBox(height: 4),
        const Spacer(),
        if (next != null) _nextTime(next.time),
      ],
    );
  }

  // ── medium ─────────────────────────────────────────────────────────────

  Widget _medium() => switch (entry.mode) {
    LedgerMode.today => _mediumToday(),
    LedgerMode.classes => entry.classesDone ? _mediumDone() : _mediumBetween(),
    LedgerMode.allKept => _mediumAllKept(),
  };

  Widget _mediumToday() {
    final next = entry.nextClass;
    final quests = entry.quests;
    final evening = entry.eveningLine;
    final left = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _eyebrow('NEXT CLASS', _honey),
        const SizedBox(height: 7),
        if (next != null) ...[
          _nextClassName(next, compact: evening != null),
          const SizedBox(height: 2),
          const Spacer(),
          _line(entry.classTime(next), _monoStyle(12, color: _honey)),
        ] else ...[
          Text('Your day is open', style: _serifStyle(18)),
          const Spacer(),
        ],
      ],
    );
    final Widget columns = quests == null
        ? left
        : Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: left),
              const SizedBox(width: 14),
              Container(width: 1, color: _brass.withValues(alpha: 0.5)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _eyebrow('UP NEXT', _honey),
                    const SizedBox(height: 7),
                    if (quests.isEmpty) ...[
                      Text(
                        'Nothing waiting',
                        style: _serifStyle(14).copyWith(height: 1.2),
                      ),
                      const SizedBox(height: 7),
                      Text('The room is yours.', style: _sansStyle(11)),
                    ] else
                      for (final (index, quest) in quests.take(3).indexed) ...[
                        if (index > 0) const SizedBox(height: 7),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '${index + 1}',
                              style: _monoStyle(
                                10,
                                color: _honey,
                                weight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: _line(
                                quest.title,
                                _sansStyle(11, color: _text),
                              ),
                            ),
                          ],
                        ),
                      ],
                    const Spacer(),
                  ],
                ),
              ),
            ],
          );
    if (evening == null) return columns;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: columns),
        _eveningFooter(evening, entry.eveningDay!),
      ],
    );
  }

  /// Between classes, or in one: the class to mark with its ring and its
  /// control directly under it, then what comes next as one quiet line.
  Widget _mediumBetween() {
    final day = entry.activeClassDay!;
    final focus = entry.focusClass;
    final kept = focus == null ? entry.lastKept : null;
    final title = focus?.shortTitle ?? kept!.shortTitle;
    final url = focus?.markUrl;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _eyebrow('${day.weekday.toUpperCase()} · ${_noun(day)}', _secondary),
        const SizedBox(height: 6),
        const Spacer(),
        Row(
          children: [
            ClassRingMock(kept: focus == null, size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _line(title, _serifStyle(20), scaleDown: true),
                  const SizedBox(height: 3),
                  if (focus != null)
                    _line(
                      _focusLine(focus, withPlace: true),
                      _sansStyle(_s(11)),
                    )
                  else
                    Row(
                      children: [
                        Text('Attended', style: _sansStyle(_s(11))),
                        const SizedBox(width: 6),
                        Text(
                          '+${kept!.keptXp} XP',
                          style: _monoStyle(_s(11), color: _honey),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
        if (focus != null && url != null)
          Padding(
            padding: const EdgeInsets.only(left: 36, top: 8),
            child: _capsule(_markLabel(focus)),
          ),
        const SizedBox(height: 6),
        const Spacer(),
        _nextLine(),
      ],
    );
  }

  /// After the last class: the day's classes as ledger rows. Only the one
  /// brass control marks.
  Widget _mediumDone() {
    final day = entry.activeClassDay!;
    final rows = entry.doneRows;
    final focus = entry.focusClass;
    final markAll = entry.markAllUrl != null;
    final tight = markAll && rows.length > 2;
    final spacing = tight ? 2.0 : (rows.length > 2 ? 4.0 : 8.0);
    final gap = tight ? 3.0 : 6.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _eyebrow(
          '${day.weekday.toUpperCase()} · ${_noun(day)} DONE',
          _secondary,
        ),
        SizedBox(height: gap),
        const Spacer(),
        for (final (index, row) in rows.indexed) ...[
          if (index > 0) SizedBox(height: spacing),
          _row(
            row,
            height: tight ? 21 : 24,
            primary:
                !markAll &&
                row.occurrenceKey == focus?.occurrenceKey &&
                row.markUrl != null,
          ),
        ],
        if (markAll)
          Padding(
            padding: EdgeInsets.only(top: tight ? 4 : 6),
            child: Align(
              alignment: Alignment.centerRight,
              child: _capsule(entry.markAllLabel, compact: true),
            ),
          ),
        SizedBox(height: gap),
        const Spacer(),
        if (entry.showsNextAfterRows) _nextLine(),
      ],
    );
  }

  Widget _row(
    LedgerDayClass row, {
    required double height,
    required bool primary,
  }) {
    // The board's quiet rows: the mark leads (closed ring when kept, the
    // open ring on the one row the control marks, a dim dot otherwise).
    final Widget mark;
    final Widget trailing;
    if (row.kept) {
      mark = const ClassRingMock(kept: true, size: 15);
      trailing = Text('+${row.keptXp} XP', style: _monoStyle(_s(10.5)));
    } else if (primary) {
      mark = const ClassRingMock(kept: false, size: 15);
      trailing = _capsule('I WAS THERE', compact: true);
    } else {
      // A quiet dim dot: waiting, never a hollow socket.
      mark = Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: _secondary.withValues(alpha: 0.45),
          shape: BoxShape.circle,
        ),
      );
      trailing = Text(
        row.startLabel,
        style: _monoStyle(_s(10.5), weight: FontWeight.w500),
      );
    }
    return SizedBox(
      height: height,
      child: Row(
        children: [
          SizedBox.square(dimension: 16, child: Center(child: mark)),
          const SizedBox(width: 8),
          Expanded(
            child: _fitLine(
              row.shortTitle,
              _serifStyle(
                14,
                color: row.kept || primary
                    ? _text
                    : _text.withValues(alpha: 0.82),
              ),
            ),
          ),
          const SizedBox(width: 6),
          trailing,
        ],
      ),
    );
  }

  Widget _mediumAllKept() {
    final day = entry.activeClassDay!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _eyebrow('${day.weekday.toUpperCase()} · ${_noun(day)}', _secondary),
        const SizedBox(height: 6),
        const Spacer(),
        Row(
          children: [
            const ClassRingMock(kept: true, size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _line(day.attendedShort ?? 'Attended', _serifStyle(20)),
                  const SizedBox(height: 3),
                  _line(
                    '+${day.classXp} XP',
                    _monoStyle(_s(13), color: _honey),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Spacer(),
        _nextLine(),
      ],
    );
  }

  /// The evening's one quiet line under the everyday look.
  Widget _eveningFooter(LedgerEveningLine line, LedgerClassDay day) {
    final List<Widget> children;
    switch (line) {
      case LedgerEveningLine.record:
        children = [
          const ClassRingMock(kept: true, size: 13),
          const SizedBox(width: 7),
          Expanded(child: _line(day.recordLine ?? '', _sansStyle(_s(11)))),
          const SizedBox(width: 7),
          Text('+${day.classXp} XP', style: _monoStyle(_s(10.5))),
        ];
      case LedgerEveningLine.markAll:
        children = [
          const ClassRingMock(kept: false, size: 13),
          const SizedBox(width: 7),
          Expanded(
            child: _line(
              '${day.weekday}’s classes',
              _sansStyle(_s(11), color: _text),
            ),
          ),
          const SizedBox(width: 7),
          _quietControl(entry.eveningMarkAllLabel),
        ];
      case LedgerEveningLine.waiting:
        final waiting = entry.eveningWaiting.last;
        children = [
          const ClassRingMock(kept: false, size: 13),
          const SizedBox(width: 7),
          Expanded(
            child: _line(waiting.shortTitle, _sansStyle(_s(11), color: _text)),
          ),
          const SizedBox(width: 4),
          if (waiting.markUrl != null) _quietControl('I WAS THERE'),
        ];
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(height: 0.5, color: _brass.withValues(alpha: 0.35)),
          const SizedBox(height: 6),
          Row(children: children),
        ],
      ),
    );
  }

  // ── pieces ─────────────────────────────────────────────────────────────

  /// The everyday look leads with the class's name, its code beneath (the
  /// code gives way when the evening line needs the room).
  Widget _nextClassName(LedgerClassGlance next, {required bool compact}) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            next.shortTitle ?? next.courseTitle,
            style: _serifStyle(16),
            maxLines: compact ? 2 : 3,
            overflow: TextOverflow.ellipsis,
          ),
          if (!compact) ...[
            const SizedBox(height: 4),
            _line(next.courseCode, _sansStyle(11)),
          ],
        ],
      );

  /// One quiet line: `NEXT 2:00 PM  Discrete Structures II`.
  Widget _nextLine() {
    final next = entry.nextAfter;
    if (next == null) return const SizedBox.shrink();
    return Row(
      children: [
        Text('NEXT ${next.time}', style: _monoStyle(_s(10.5))),
        const SizedBox(width: 8),
        Expanded(child: _line(next.title, _sansStyle(_s(11.5)))),
      ],
    );
  }

  Widget _nextTime(String time) => _line('NEXT $time', _monoStyle(_s(10.5)));

  /// `CLASS` on a day with one, else `CLASSES`.
  String _noun(LedgerClassDay day) =>
      day.classes.length == 1 ? 'CLASS' : 'CLASSES';

  /// One line that may shrink to [minScale] before it truncates: SwiftUI's
  /// `.lineLimit(1).minimumScaleFactor(...)`.
  Widget _fitLine(String text, TextStyle style, {double minScale = 0.9}) =>
      LayoutBuilder(
        builder: (context, constraints) {
          final painter = TextPainter(
            text: TextSpan(
              text: text,
              style: DefaultTextStyle.of(context).style.merge(style),
            ),
            textDirection: TextDirection.ltr,
            maxLines: 1,
          )..layout();
          final natural = painter.width;
          painter.dispose();
          final scale = natural <= constraints.maxWidth
              ? 1.0
              : (constraints.maxWidth / natural).clamp(minScale, 1.0);
          return _line(text, style.copyWith(fontSize: style.fontSize! * scale));
        },
      );

  String _markLabel(LedgerDayClass focus) =>
      entry.isInSession(focus) ? "I'M HERE" : 'I WAS THERE';

  String _focusLine(LedgerDayClass focus, {required bool withPlace}) {
    final when = entry.isInSession(focus)
        ? 'Until ${focus.endLabel}'
        : 'Ended ${focus.endLabel}';
    return withPlace && focus.place.isNotEmpty
        ? '$when · ${focus.place}'
        : when;
  }

  Widget _eyebrow(String text, Color color) => Text(
    text,
    maxLines: 1,
    style: TextStyle(
      fontFamily: _sans,
      fontSize: _s(10),
      fontWeight: FontWeight.w700,
      letterSpacing: 1.2,
      height: 1.2,
      color: color,
    ),
  );

  Widget _line(String text, TextStyle style, {bool scaleDown = false}) {
    final label = Text(
      text,
      style: style,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
    );
    if (!scaleDown) return label;
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(text, style: style, maxLines: 1),
    );
  }

  /// A control that marks without owning the evening: outlined, not lit.
  Widget _quietControl(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: _brass, width: 1),
    ),
    child: Text(
      label,
      maxLines: 1,
      style: _monoStyle(
        _s(10),
        color: _brassLight,
        weight: FontWeight.w700,
        tracking: 0.6,
      ),
    ),
  );

  /// The one luminous control: the board's brushed brass, muted, with a
  /// darker rim and an under-lip. No glow.
  Widget _capsule(
    String label, {
    bool fullWidth = false,
    bool compact = false,
  }) {
    final capsule = Container(
      // The under-lip: one point of deep brass below the plate.
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(color: _brassDeep, offset: Offset(0, 1), blurRadius: 0),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_brassLight, _brassFace],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0),
                  Colors.white.withValues(alpha: 0.14),
                  Colors.white.withValues(alpha: 0),
                ],
                stops: const [0.1, 0.3, 0.52],
              ),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: _brassEdge, width: 0.75),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                // A full-width plate centres its label.
                horizontal: compact ? 9 : (fullWidth ? 8 : 13),
                vertical: compact ? 5 : 7,
              ),
              // SwiftUI's `.lineLimit(1).minimumScaleFactor(0.85)`.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: _monoStyle(
                    _s(compact ? 11 : 11.5),
                    color: _ink,
                    weight: FontWeight.w700,
                    tracking: compact ? 0.4 : 0.9,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return fullWidth
        ? SizedBox(width: double.infinity, child: capsule)
        : capsule;
  }
}

/// The Swift `ClassRing`: the board's check ring at widget size, open with
/// its clasp for a class to mark, closed with a tick once kept.
class ClassRingMock extends StatelessWidget {
  const ClassRingMock({super.key, required this.kept, required this.size});

  final bool kept;
  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _ClassRingPainter(kept: kept),
  );
}

class _ClassRingPainter extends CustomPainter {
  const _ClassRingPainter({required this.kept});

  final bool kept;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final line = math.max(1.2, s * 0.075);
    final center = size.center(Offset.zero);
    // SwiftUI's AngularGradient starts at three o'clock, like SweepGradient.
    Paint wire(Rect rect, {double rotation = 0}) => Paint()
      ..shader = SweepGradient(
        transform: GradientRotation(rotation),
        colors: const [
          _brassWireDark,
          _brassWireLight,
          _brassWireMid,
          _brassWireHot,
          _brassWireDark,
        ],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = line
      ..strokeCap = StrokeCap.round;
    final full = Offset.zero & size;
    if (kept) {
      // `.stroke` on a circle padded by 11%: the line is centred on it.
      final radius = s / 2 - s * 0.11;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = _brassEdge
          ..style = PaintingStyle.stroke
          ..strokeWidth = line * 1.6,
      );
      canvas.drawCircle(center, radius, wire(full));
      _tick(
        canvas,
        size,
        const [Offset(0.29, 0.51), Offset(0.44, 0.65), Offset(0.72, 0.35)],
        _brassLight,
        line,
      );
    } else {
      // The trimmed circle is rotated as a whole, its gradient with it.
      const turn = 82.8 * math.pi / 180;
      final radius = s / 2 - s * 0.08;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        turn,
        0.82 * 2 * math.pi,
        false,
        wire(full, rotation: turn),
      );
      _tick(
        canvas,
        size,
        const [Offset(0.672, 0.706), Offset(0.752, 0.856), Offset(0.942, 0.59)],
        _brassTick,
        line * 0.85,
      );
    }
  }

  void _tick(
    Canvas canvas,
    Size size,
    List<Offset> points,
    Color color,
    double width,
  ) {
    final path = Path()
      ..moveTo(points[0].dx * size.width, points[0].dy * size.height);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx * size.width, point.dy * size.height);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_ClassRingPainter old) => old.kept != kept;
}

/// A home screen with the medium widget above a small one, both reading the
/// same timeline entry, plus the mock tag and a caption.
class DayLedgerHomeScreenMock extends StatelessWidget {
  const DayLedgerHomeScreenMock({
    super.key,
    required this.entry,
    required this.clock,
    required this.tag,
    required this.caption,
    this.typeScale = 1,
  });

  final DayLedgerEntry entry;

  /// The Swift `typeScale` both widgets read (1.24 at accessibility sizes).
  final double typeScale;

  /// The status bar time, `11:52`.
  final String clock;
  final String tag;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF15121A),
      body: MediaQuery.withNoTextScaling(
        child: Stack(
          children: [
            const Positioned.fill(child: _Wallpaper()),
            Positioned(
              top: 11,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 126,
                  height: 37,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(19),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 19,
              left: 52,
              child: Text(
                clock,
                style: const TextStyle(
                  fontFamily: _sans,
                  fontWeight: FontWeight.w600,
                  fontSize: 17,
                  color: Colors.white,
                ),
              ),
            ),
            Positioned(
              top: 64,
              left: 27.5,
              right: 27.5,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xCC000000),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: const Color(0x55FFFFFF),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  tag,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: _mono,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 104,
              left: 27.5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DayLedgerWidgetMock(
                    entry: entry,
                    family: LedgerFamily.medium,
                    typeScale: typeScale,
                  ),
                  const SizedBox(height: 6),
                  const SizedBox(width: 338, child: _AppLabel()),
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        children: [
                          DayLedgerWidgetMock(
                            entry: entry,
                            family: LedgerFamily.small,
                            typeScale: typeScale,
                          ),
                          const SizedBox(height: 6),
                          const SizedBox(width: 158, child: _AppLabel()),
                        ],
                      ),
                      const SizedBox(width: 22),
                      const _IconGrid(),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              top: 520,
              left: 28,
              right: 28,
              child: Text(
                caption,
                style: TextStyle(
                  fontFamily: _sans,
                  fontSize: 13.5,
                  height: 1.4,
                  color: Colors.white.withValues(alpha: 0.82),
                ),
              ),
            ),
            const Positioned(bottom: 22, left: 14, right: 14, child: _Dock()),
          ],
        ),
      ),
    );
  }
}

class _AppLabel extends StatelessWidget {
  const _AppLabel();

  @override
  Widget build(BuildContext context) => Text(
    'Room of Days',
    textAlign: TextAlign.center,
    style: TextStyle(
      fontFamily: _sans,
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: Colors.white.withValues(alpha: 0.88),
    ),
  );
}

class _Wallpaper extends StatelessWidget {
  const _Wallpaper();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF2E2A38), Color(0xFF1C1822), Color(0xFF120F15)],
      ),
    ),
  );
}

class _IconGrid extends StatelessWidget {
  const _IconGrid();

  static const _tints = [
    Color(0xFF4A4E62),
    Color(0xFF4F4456),
    Color(0xFF3F4C55),
    Color(0xFF524A48),
  ];

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 158,
    child: Wrap(
      spacing: 22,
      runSpacing: 26,
      children: [
        for (var i = 0; i < 4; i++)
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _tints[i],
              borderRadius: BorderRadius.circular(15),
            ),
          ),
      ],
    ),
  );
}

class _Dock extends StatelessWidget {
  const _Dock();

  @override
  Widget build(BuildContext context) => Container(
    height: 92,
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(34),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final tint in _IconGrid._tints)
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(15),
            ),
          ),
      ],
    ),
  );
}
