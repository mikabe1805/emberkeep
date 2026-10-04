// MOCK of the Day Ledger home-screen widget, drawn in Flutter from the same
// decisions the SwiftUI views make (test/home_widgets/day_ledger_mirror.dart
// mirrors ios/RoomOfDaysWidgets/RoomOfDaysWidgets.swift). The real widget is
// SwiftUI and compiles only on Codemagic's Mac, so this is the closest look
// available here.
//
// Approximations: Fraunces stands in for New York (the system serif), Inter
// for SF Pro, JetBrains Mono for SF Mono, and an SF Symbol checkmark is drawn
// with a Material icon. Sizes are real iPhone 15/16 Pro points: small
// 158 x 158, medium 338 x 158, with iOS 17's 16 pt content margins.
//
// Test-support library, not a test.
library;

import 'package:flutter/material.dart';

import '../home_widgets/day_ledger_mirror.dart';

// RoomWidgetPalette (RoomOfDaysWidgets.swift).
const _backdrop = Color.fromRGBO(19, 13, 11, 1);
const _panel = Color.fromRGBO(31, 21, 17, 1);
const _text = Color.fromRGBO(242, 219, 181, 1);
const _secondary = Color.fromRGBO(173, 148, 122, 1);
const _honey = Color.fromRGBO(232, 166, 61, 1);
const _honeyLight = Color.fromRGBO(247, 204, 117, 1);
const _brass = Color.fromRGBO(140, 99, 56, 1);
const _ink = Color.fromRGBO(41, 26, 15, 1);

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
  });

  final DayLedgerEntry entry;
  final LedgerFamily family;

  @override
  Widget build(BuildContext context) {
    final size = family == LedgerFamily.small
        ? ledgerSmallSize
        : ledgerMediumSize;
    return MediaQuery.withNoTextScaling(
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
            child: family == LedgerFamily.small ? _small() : _medium(),
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
          _eyebrow('NEXT CLASS'),
          const SizedBox(height: 7),
          _nextClassName(next),
          const SizedBox(height: 2),
          const Spacer(),
          _line(entry.classTime(next), _monoStyle(13, color: _honey)),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _eyebrow('NEXT CLASS'),
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

  Widget _smallClasses() {
    final day = entry.activeClassDay!;
    final focus = entry.focusClass;
    final eyebrow = entry.classesDone
        ? '${_noun(day)} DONE'
        : day.weekday.toUpperCase();
    if (focus != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _eyebrow(eyebrow),
          const SizedBox(height: 5),
          Text(
            focus.shortTitle,
            style: _serifStyle(16),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          _line(_focusLine(focus, withPlace: false), _sansStyle(11)),
          const SizedBox(height: 4),
          const Spacer(),
          _capsule(_markLabel(focus), fullWidth: true),
        ],
      );
    }
    final kept = entry.lastKept!;
    final next = entry.nextAfter;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _eyebrow(eyebrow),
        const SizedBox(height: 5),
        Text(
          kept.shortTitle,
          style: _serifStyle(16),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        _keptMark(kept.keptXp, size: 11),
        const SizedBox(height: 4),
        const Spacer(),
        if (next != null) _line('NEXT ${next.time}', _monoStyle(10)),
      ],
    );
  }

  Widget _smallAllKept() {
    final day = entry.activeClassDay!;
    final next = entry.nextAfter;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _eyebrow(day.weekday.toUpperCase()),
        const SizedBox(height: 5),
        Text(
          day.attendedShort ?? 'Attended',
          style: _serifStyle(18),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        _line('+${day.classXp} XP', _monoStyle(14, color: _honey)),
        const SizedBox(height: 4),
        const Spacer(),
        if (next != null) _line('NEXT ${next.time}', _monoStyle(10)),
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
    final left = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _eyebrow('NEXT CLASS'),
        const SizedBox(height: 7),
        if (next != null) ...[
          _nextClassName(next),
          const SizedBox(height: 2),
          const Spacer(),
          _line(entry.classTime(next), _monoStyle(12, color: _honey)),
        ] else ...[
          Text('Your day is open', style: _serifStyle(18)),
          const Spacer(),
        ],
      ],
    );
    if (quests == null) return left;
    return Row(
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
              _eyebrow('UP NEXT'),
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
                        child: _line(quest.title, _sansStyle(11, color: _text)),
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
  }

  /// Between classes, or in one: the class to mark, and what comes next.
  Widget _mediumBetween() {
    final day = entry.activeClassDay!;
    final focus = entry.focusClass;
    final kept = focus == null ? entry.lastKept : null;
    final title = focus?.shortTitle ?? kept!.shortTitle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _eyebrow('${day.weekday.toUpperCase()} · ${_noun(day)}'),
        const SizedBox(height: 6),
        const Spacer(),
        _line(title, _serifStyle(20), scaleDown: true),
        const SizedBox(height: 3),
        if (focus != null)
          _line(_focusLine(focus, withPlace: true), _sansStyle(11))
        else
          Row(children: [_keptMark(kept!.keptXp, size: 11, label: 'Attended')]),
        const SizedBox(height: 6),
        const Spacer(),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: _nextBlock()),
            if (focus != null) ...[
              const SizedBox(width: 10),
              _capsule(_markLabel(focus)),
            ],
          ],
        ),
      ],
    );
  }

  /// After the last class: the day's classes as ledger rows.
  Widget _mediumDone() {
    final day = entry.activeClassDay!;
    final rows = entry.doneRows;
    final focus = entry.focusClass;
    final next = entry.nextAfter;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _eyebrow('${day.weekday.toUpperCase()} · ${_noun(day)} DONE'),
        const SizedBox(height: 6),
        const Spacer(),
        for (final (index, row) in rows.indexed) ...[
          if (index > 0) SizedBox(height: rows.length > 2 ? 4 : 8),
          _row(row, primary: row.occurrenceKey == focus?.occurrenceKey),
        ],
        const SizedBox(height: 6),
        const Spacer(),
        if (next != null)
          Row(
            children: [
              Text('NEXT ${next.time}', style: _monoStyle(10)),
              const SizedBox(width: 8),
              Expanded(child: _line(next.title, _sansStyle(11, color: _text))),
            ],
          ),
      ],
    );
  }

  Widget _row(LedgerDayClass row, {required bool primary}) {
    final Widget trailing;
    if (row.kept) {
      trailing = _keptMark(row.keptXp, size: 10);
    } else if (primary) {
      trailing = _capsule('I WAS THERE', compact: true);
    } else {
      // A quiet dim dot: waiting, never a hollow socket. The row itself is
      // the mark link.
      trailing = Padding(
        padding: const EdgeInsets.only(right: 4),
        child: Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: _secondary.withValues(alpha: 0.45),
            shape: BoxShape.circle,
          ),
        ),
      );
    }
    return SizedBox(
      height: 24,
      child: Row(
        children: [
          SizedBox(
            width: 50,
            child: Text(
              row.startLabel,
              style: _monoStyle(10, weight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: _fitLine(row.shortTitle, _serifStyle(14))),
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
        _eyebrow('${day.weekday.toUpperCase()} · ${_noun(day)}'),
        const SizedBox(height: 6),
        const Spacer(),
        _line(day.attendedShort ?? 'Attended', _serifStyle(20)),
        const SizedBox(height: 3),
        _line('+${day.classXp} XP', _monoStyle(13, color: _honey)),
        const SizedBox(height: 6),
        const Spacer(),
        _nextBlock(),
      ],
    );
  }

  Widget _nextBlock() {
    final next = entry.nextAfter;
    if (next == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _line('NEXT ${next.time}', _monoStyle(10)),
        const SizedBox(height: 2),
        _line(next.title, _sansStyle(12, color: _text)),
      ],
    );
  }

  // ── pieces ─────────────────────────────────────────────────────────────

  /// The everyday look leads with the class's name, its code beneath.
  Widget _nextClassName(LedgerClassGlance next) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        next.shortTitle ?? next.courseTitle,
        style: _serifStyle(16),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
      const SizedBox(height: 4),
      _line(next.courseCode, _sansStyle(11)),
    ],
  );

  /// `CLASS` on a day with one, else `CLASSES`.
  String _noun(LedgerClassDay day) =>
      day.classes.length == 1 ? 'CLASS' : 'CLASSES';

  /// One line that may shrink to 90% before it truncates: SwiftUI's
  /// `.lineLimit(1).minimumScaleFactor(0.9)`.
  Widget _fitLine(String text, TextStyle style) => LayoutBuilder(
    builder: (context, constraints) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      final natural = painter.width;
      painter.dispose();
      final scale = natural <= constraints.maxWidth
          ? 1.0
          : (constraints.maxWidth / natural).clamp(0.9, 1.0);
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

  Widget _eyebrow(String text) => Text(
    text,
    maxLines: 1,
    style: const TextStyle(
      fontFamily: _sans,
      fontSize: 9,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.2,
      height: 1.2,
      color: _honey,
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

  Widget _keptMark(int xp, {required double size, String? label}) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.check_circle, size: size + 1, color: _honey),
      const SizedBox(width: 4),
      if (label != null) ...[
        Text(label, style: _sansStyle(size)),
        const SizedBox(width: 6),
      ],
      Text('+$xp XP', style: _monoStyle(size, color: _honey)),
    ],
  );

  Widget _capsule(
    String label, {
    bool fullWidth = false,
    bool compact = false,
  }) {
    final capsule = Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 9 : 12,
        vertical: compact ? 5 : 7,
      ),
      alignment: fullWidth ? Alignment.center : null,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: const LinearGradient(
          colors: [_honeyLight, _honey],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.25),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(color: _honey.withValues(alpha: 0.35), blurRadius: 12),
        ],
      ),
      child: Text(
        label,
        maxLines: 1,
        style: _monoStyle(
          compact ? 9.5 : 10.5,
          color: _ink,
          weight: FontWeight.w700,
          tracking: compact ? 0.6 : 1,
        ),
      ),
    );
    return fullWidth
        ? SizedBox(width: double.infinity, child: capsule)
        : capsule;
  }
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
  });

  final DayLedgerEntry entry;

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
