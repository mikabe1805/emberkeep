// The mantel's glass: the YOUR BUILD card, the quiet tabs, the trophy tag and
// the sheets they open.
//
// One material throughout, the Doorway's walnut glass ([ClassGlass]): the room
// shows through a dark brown tint, the corners are cut, a fine brass edge runs
// round it. The tabs and the tag are the same smoke in small, flat and
// axis-aligned. Everything is live text over the painting; nothing here is
// painted into the plate.
library;

import 'package:flutter/material.dart';

import '../../../tokens.dart';
import '../../class_day/class_day_room.dart' show ClassGlass;
import '../../count_up.dart';
import '../../routine_ledger.dart' show LedgerType;
import 'mantel_model.dart';

const _ink = Color(0xFFF6EAD3);
const _inkSoft = Color(0xFFD8C9B3);
const _inkQuiet = Color(0xFFB9A98C);
const _rule = Color(0x24E8C892);

TextStyle _serif(double size, {Color? color, FontWeight? weight}) =>
    LedgerType.body.copyWith(
      fontSize: size,
      fontWeight: weight ?? FontWeight.w500,
      height: 1.05,
      color: color ?? _ink,
    );

TextStyle _mono(double size, {Color? color, double spacing = 1.6}) => Type.label
    .copyWith(fontSize: size, letterSpacing: spacing, color: color ?? _inkSoft);

/// Whether the phone's text size is [mantelLargeTextFrom] or more.
bool mantelLargeText(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(1) >= mantelLargeTextFrom;

/// A small caps eyebrow ("YOUR BUILD").
class MantelEyebrow extends StatelessWidget {
  const MantelEyebrow(this.text, {super.key, this.align = TextAlign.start});

  final String text;
  final TextAlign align;

  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: align,
    style: _mono(Type.minLabel, color: const Color(0xFFC3B292), spacing: 1.9),
  );
}

// ── The YOUR BUILD card ──────────────────────────────────────────────────

/// The build, on the glass: its name and level, the six domains, and the
/// footer with the quest count, the streak and the XP. Each domain opens its
/// own page.
class MantelBuildCard extends StatelessWidget {
  const MantelBuildCard({
    super.key,
    required this.facts,
    required this.onStat,
    this.maxHeight,
  });

  final MantelBuild facts;
  final ValueChanged<Stat> onStat;

  /// The most room the glass may take; past it the card scrolls inside.
  final double? maxHeight;

  @override
  Widget build(BuildContext context) {
    // At the phone's own size the footer stays pinned under the six stats. At
    // large text it would take half the glass, so it joins the scroll below
    // the stats and the stats get all the room.
    final large = mantelLargeText(context);
    Widget footer() => Container(
      key: const Key('mantel-footer'),
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.only(top: 5),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0x33EFD8B3))),
      ),
      child: Semantics(
        label:
            '${facts.questsDone} quest${facts.questsDone == 1 ? '' : 's'}'
            ' done, ${facts.streakDays} day streak, '
            '${facts.xp} of ${facts.xpNeeded} XP',
        excludeSemantics: true,
        child: _footer(context),
      ),
    );
    final glass = ClassGlass(
      key: const Key('mantel-build-card'),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: SingleChildScrollView(
              key: const Key('mantel-build-scroll'),
              primary: false,
              physics: const ClampingScrollPhysics(),
              child: large
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [_body(large: true), footer()],
                    )
                  : _body(large: false),
            ),
          ),
          if (!large) footer(),
        ],
      ),
    );
    final cap = maxHeight;
    return cap == null
        ? glass
        : ConstrainedBox(
            constraints: BoxConstraints(maxHeight: cap),
            child: glass,
          );
  }

  /// The count and streak at the left, the XP at the right. On one line they
  /// give way to each other by shrinking the count a hair; at large text they
  /// wrap instead of getting small.
  Widget _footer(BuildContext context) {
    final wrapAtLargeText = MediaQuery.textScalerOf(context).scale(1) > 1.05;
    final done = Text(
      facts.doneLine,
      key: const Key('mantel-done'),
      maxLines: wrapAtLargeText ? null : 1,
      style: _mono(Type.minLabel, color: _inkSoft, spacing: 0.2),
    );
    final xp = Text(
      facts.xpLine,
      key: const Key('mantel-xp'),
      maxLines: 1,
      style: _mono(Type.minLabel, color: _inkQuiet, spacing: 0.2),
    );
    if (wrapAtLargeText) {
      return Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 4,
        children: [done, xp],
      );
    }
    return Row(
      children: [
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: done,
          ),
        ),
        const SizedBox(width: 12),
        xp,
      ],
    );
  }

  Widget _body({required bool large}) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Semantics(
        label: 'Your build, ${facts.title}. Level ${facts.level}.',
        excludeSemantics: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const MantelEyebrow('YOUR BUILD'),
                  const SizedBox(height: 2),
                  Text(
                    facts.title,
                    key: const Key('mantel-title'),
                    style: _serif(22, weight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const MantelEyebrow('LEVEL', align: TextAlign.end),
                const SizedBox(height: 3),
                Text(
                  '${facts.level}',
                  key: const Key('mantel-level'),
                  style: _serif(22, weight: FontWeight.w700),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 2),
      // At the phone's size the week's preview sits under the title. At
      // large text it would take the first screen of the glass, so the six
      // stats come first and it follows them.
      if (!large) MantelWeekLine(facts: facts),
      for (final stat in facts.stats) _StatRow(stat: stat, onTap: onStat),
      if (large) MantelWeekLine(facts: facts),
    ],
  );
}

/// The week's preview, one quiet line under the title: the monster the
/// weekend brings and the stat it is weak to, with that stat's own glyph.
class MantelWeekLine extends StatelessWidget {
  const MantelWeekLine({super.key, required this.facts});

  final MantelBuild facts;

  @override
  Widget build(BuildContext context) {
    final weak = facts.monster.weakness;
    final style = _sans(12, color: _inkSoft);
    // One line at the phone's own size, shrunk a hair if a narrow phone needs
    // it; at large text it wraps instead of getting small.
    final big = MediaQuery.textScalerOf(context).scale(1) > 1.05;
    final line = big
        ? Text(facts.weekendLine, style: style)
        : FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              facts.weekendLine,
              maxLines: 1,
              softWrap: false,
              style: style,
            ),
          );
    return Semantics(
      label: facts.weekendLine,
      excludeSemantics: true,
      child: Padding(
        key: const Key('mantel-week-line'),
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(weak.icon, size: 15, color: weak.color.withValues(alpha: 0.9)),
            const SizedBox(width: 8),
            Expanded(child: line),
          ],
        ),
      ),
    );
  }
}

/// "Tier 3" and "Tier 4 at 150" never break across lines (a lone "3" on its
/// own line at large text reads as a mistake); the ability's own name still
/// may.
String _keepTogether(String s) => s
    .replaceAll('Tier ', 'Tier ')
    .replaceAll(' · ', ' · ')
    .replaceAll(' at ', ' at ');

TextStyle _sans(double size, {Color? color, FontWeight? weight}) =>
    Type.body.copyWith(
      fontSize: size,
      fontWeight: weight ?? FontWeight.w500,
      height: 1.2,
      color: color ?? _inkSoft,
    );

/// One stat, on its own line of the glass: its glyph in its own hue, its name
/// and value, what this week's training added to it (glowing, only when it
/// did), the ability it powers and its tier, and where it goes next. The whole
/// row opens the stat's page.
class _StatRow extends StatelessWidget {
  const _StatRow({required this.stat, required this.onTap});

  final MantelStat stat;
  final ValueChanged<Stat> onTap;

  @override
  Widget build(BuildContext context) {
    final hue = stat.stat.color;
    final trained = stat.trained;
    return Semantics(
      button: true,
      label: stat.spoken,
      hint: 'Opens the ${stat.stat.label} page',
      excludeSemantics: true,
      child: GestureDetector(
        key: Key('mantel-stat-${stat.stat.name}'),
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(stat.stat),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.fromLTRB(0, 4, 0, 3),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: _rule)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 28,
                child: Icon(
                  stat.stat.icon,
                  key: Key('mantel-stat-icon-${stat.stat.name}'),
                  size: 20,
                  color: hue.withValues(alpha: trained ? 1 : 0.82),
                  shadows: trained
                      ? [
                          Shadow(
                            color: hue.withValues(alpha: 0.7),
                            blurRadius: 9,
                          ),
                        ]
                      : null,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          stat.name,
                          key: Key('mantel-stat-name-${stat.stat.name}'),
                          style: _serif(17, weight: FontWeight.w600),
                        ),
                        if (trained) _TrainingChip(stat: stat),
                      ],
                    ),
                    const SizedBox(height: 1),
                    Wrap(
                      spacing: 10,
                      runSpacing: 0,
                      children: [
                        if (stat.abilityLine != null)
                          Text(
                            _keepTogether(stat.abilityLine!),
                            key: Key('mantel-ability-${stat.stat.name}'),
                            style: _sans(
                              12.5,
                              color: _ink,
                              weight: FontWeight.w600,
                            ),
                          ),
                        Text(
                          _keepTogether(stat.nextText),
                          key: Key('mantel-next-${stat.stat.name}'),
                          style: _sans(12.5, color: _inkQuiet),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: RollingNumber(
                  stat.value,
                  maxLines: 1,
                  style: _serif(24, weight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "+6 this week", glowing in the stat's own hue. It is only there when the
/// stat was trained, so a quiet week is not a row of zeros.
class _TrainingChip extends StatelessWidget {
  const _TrainingChip({required this.stat});

  final MantelStat stat;

  @override
  Widget build(BuildContext context) {
    final hue = stat.stat.color;
    return Container(
      key: Key('mantel-training-${stat.stat.name}'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: hue.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: hue.withValues(alpha: 0.62), width: 0.8),
        boxShadow: [
          BoxShadow(color: hue.withValues(alpha: 0.38), blurRadius: 11),
        ],
      ),
      child: Text(
        stat.trainingLine!,
        style: _sans(
          12,
          color: const Color(0xFFFBF2E1),
          weight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ── Quiet tabs and the tag ───────────────────────────────────────────────

/// One entry of a tab pill.
class MantelTabItem {
  const MantelTabItem({
    required this.label,
    required this.onTap,
    required this.keyName,
    this.spoken,
  });

  final String label;
  final VoidCallback onTap;

  /// The key suffix: `mantel-tab-<keyName>`.
  final String keyName;
  final String? spoken;
}

/// A small flat pill of smoke glass on the timber, flush to a screen edge,
/// holding one to three quiet entries. Its entries stay at 44 points to touch
/// whatever the text size.
class MantelTabs extends StatelessWidget {
  const MantelTabs({super.key, required this.items, required this.fromRight});

  final List<MantelTabItem> items;

  /// Flush to the right edge (SETTINGS, SAVE) or the left (YOUR SPACE, MORE).
  final bool fromRight;

  @override
  Widget build(BuildContext context) {
    final radius = fromRight
        ? const BorderRadius.horizontal(left: Radius.circular(9))
        : const BorderRadius.horizontal(right: Radius.circular(9));
    const edge = Color(0x3DF6E2BF);
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: mantelTabTextCap,
      child: IntrinsicHeight(
        child: Stack(
          children: [
            // The pill is a little under 34 points tall; each entry still
            // takes a touch over the full 44.
            Positioned(
              top: (MantelFrame.hit - MantelFrame.tabHeight) / 2,
              bottom: (MantelFrame.hit - MantelFrame.tabHeight) / 2,
              left: 0,
              right: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xBD1C1511),
                  borderRadius: radius,
                  border: Border(
                    top: const BorderSide(color: edge),
                    bottom: const BorderSide(color: edge),
                    left: fromRight
                        ? const BorderSide(color: edge)
                        : BorderSide.none,
                    right: fromRight
                        ? BorderSide.none
                        : const BorderSide(color: edge),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x4D0A0502),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0)
                    Container(
                      width: 1,
                      height: MantelFrame.tabHeight - 8,
                      color: const Color(0x38F6E2BF),
                    ),
                  _TabButton(item: items[i]),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({required this.item});

  final MantelTabItem item;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: item.spoken ?? item.label,
      excludeSemantics: true,
      child: GestureDetector(
        key: Key('mantel-tab-${item.keyName}'),
        behavior: HitTestBehavior.opaque,
        onTap: item.onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: MantelFrame.hit,
            minWidth: 44,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11),
            child: Center(
              child: Text(
                item.label,
                maxLines: 1,
                softWrap: false,
                style: _mono(Type.minLabel, color: const Color(0xFFE8DAC6)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The TROPHY CASE tag: a small flat plate of smoke glass beside the mantel,
/// its leader running to the medallion on the shelf.
class MantelTag extends StatelessWidget {
  const MantelTag({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: mantelTabTextCap,
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: GestureDetector(
          key: const Key('mantel-tag-trophy'),
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: MantelFrame.hit),
            child: Center(
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xC21E1611),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0x42F6E2BF)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x4D0A0502),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Text(
                    label,
                    maxLines: 1,
                    softWrap: false,
                    style: _mono(Type.minLabel, color: const Color(0xFFF1E4CD)),
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

/// The hairline from the tag to the medallion: along, then down, ending in a
/// small ring on the object. Drawn under the tag.
class MantelLeaderPainter extends CustomPainter {
  const MantelLeaderPainter({
    required this.start,
    required this.corner,
    required this.end,
  });

  final Offset start;
  final Offset corner;
  final Offset end;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0x73F6E2BF);
    canvas.drawPath(
      Path()
        ..moveTo(start.dx, start.dy)
        ..lineTo(corner.dx, corner.dy)
        ..lineTo(end.dx, end.dy - 3),
      line,
    );
    canvas.drawCircle(end, 2.2, Paint()..color = const Color(0xCCF6E2BF));
  }

  @override
  bool shouldRepaint(MantelLeaderPainter old) =>
      old.start != start || old.corner != corner || old.end != end;
}

/// A glass's heading: the small caps eyebrow over the serif title. The
/// sheets and the "Your space" page share it.
class MantelHeading extends StatelessWidget {
  const MantelHeading({
    super.key,
    required this.eyebrow,
    required this.title,
    this.subtitle,
  });

  final String eyebrow;
  final String title;

  /// A quiet line under the title (the room's name on its page).
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: MantelEyebrow(eyebrow),
      ),
      const SizedBox(height: 7),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Semantics(header: true, child: Text(title, style: _serif(25))),
      ),
      if (subtitle case final line?)
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
          child: Text(
            line,
            style: Type.body.copyWith(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: _inkQuiet,
            ),
          ),
        ),
    ],
  );
}

/// BACK: a small flat pill of smoke glass flush to the left edge, over a room
/// that runs up under the status bar. The same material as the quiet tabs,
/// a little denser because content passes under it when the page scrolls. It
/// keeps 44 points to touch whatever the text size.
class MantelBackPill extends StatelessWidget {
  const MantelBackPill({super.key, required this.onTap, this.spoken});

  final VoidCallback onTap;
  final String? spoken;

  @override
  Widget build(BuildContext context) {
    const edge = Color(0x3DF6E2BF);
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: mantelTabTextCap,
      child: Semantics(
        button: true,
        label: spoken ?? 'Back',
        onTap: onTap,
        excludeSemantics: true,
        child: GestureDetector(
          key: const Key('your-space-back'),
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: MantelFrame.hit,
              minWidth: MantelFrame.hit,
            ),
            child: Center(
              heightFactor: 1,
              widthFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xE61C1511),
                  borderRadius: const BorderRadius.horizontal(
                    right: Radius.circular(9),
                  ),
                  border: const Border(
                    top: BorderSide(color: edge),
                    bottom: BorderSide(color: edge),
                    right: BorderSide(color: edge),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x4D0A0502),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(9, 8, 13, 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.chevron_left_rounded,
                        size: 18,
                        color: Color(0xFFE8DAC6),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        'BACK',
                        maxLines: 1,
                        softWrap: false,
                        style: _mono(
                          Type.minLabel,
                          color: const Color(0xFFF1E4CD),
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
    );
  }
}

// ── Sheets ───────────────────────────────────────────────────────────────

/// Opens a sheet of the same glass over the dimmed room: a title, the content
/// (scrolling when it is long) and CLOSE. [content] is rebuilt whenever
/// [listenable] fires, so a switch inside the sheet answers at once.
///
/// Reduce Motion (the app's setting or the system's) shows the sheet without
/// a rise.
Future<T?> showMantelSheet<T>(
  BuildContext context, {
  required String eyebrow,
  required String title,
  required WidgetBuilder content,
  Listenable? listenable,
  bool reduceMotion = false,
}) {
  final still = reduceMotion || MediaQuery.disableAnimationsOf(context);
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close $title',
    barrierColor: const Color(0x800A0502),
    transitionDuration: still
        ? const Duration(milliseconds: 1)
        : const Duration(milliseconds: 280),
    // The sheet brings its own messenger and (transparent) scaffold, so a
    // snackbar from a control inside it (a copied save, a reminder that needs
    // permission) shows over the sheet instead of under the dimmed room.
    pageBuilder: (context, _, _) => MediaQuery(
      // The sheet keeps the room's stillness: its switches, previews and
      // numbers land at once when Reduce Motion is on.
      data: MediaQuery.of(context).copyWith(
        disableAnimations: still || MediaQuery.disableAnimationsOf(context),
      ),
      child: ScaffoldMessenger(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: MantelSheet(
            eyebrow: eyebrow,
            title: title,
            content: content,
            listenable: listenable,
          ),
        ),
      ),
    ),
    transitionBuilder: (context, animation, _, child) {
      if (still) return child;
      final curved = CurvedAnimation(
        parent: animation,
        curve: const Cubic(0.2, 0.7, 0.2, 1),
        reverseCurve: Curves.easeIn,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.03),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// The sheets are a little wider than the build card, and their glass hugs the
/// panels it holds (the page's own sections keep their full width).
const double _sheetInset = 12;
const double _sheetPad = 10;

/// The sheet itself: a title, then [content] in a scroll, then CLOSE.
class MantelSheet extends StatelessWidget {
  const MantelSheet({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.content,
    this.listenable,
  });

  final String eyebrow;
  final String title;
  final WidgetBuilder content;
  final Listenable? listenable;

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final pad = MediaQuery.paddingOf(context);
    Widget body(BuildContext context) => SingleChildScrollView(
      key: const Key('mantel-sheet-scroll'),
      primary: false,
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.only(top: 12),
      child: content(context),
    );
    final listen = listenable;
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: title,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // A tap on the dimmed room closes the sheet.
          Positioned.fill(
            child: Semantics(
              excludeSemantics: true,
              child: GestureDetector(
                key: const Key('mantel-sheet-barrier'),
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).maybePop(),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              // The sheet rises over the room, above the dock (the dock stays
              // where it is, dimmed with the room).
              padding: EdgeInsets.fromLTRB(
                _sheetInset,
                pad.top + 24,
                _sheetInset,
                pad.bottom + 88 + MantelFrame.glassGap,
              ),
              child: ConstrainedBox(
                key: const Key('mantel-sheet'),
                constraints: BoxConstraints(
                  maxHeight:
                      (screen.height - pad.top - pad.bottom - 88 - 40) * 0.82,
                  maxWidth: 520,
                ),
                child: ClassGlass(
                  padding: const EdgeInsets.fromLTRB(
                    _sheetPad,
                    17,
                    _sheetPad,
                    6,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      MantelHeading(eyebrow: eyebrow, title: title),
                      Flexible(
                        child: listen == null
                            ? Builder(builder: body)
                            : ListenableBuilder(
                                listenable: listen,
                                builder: (context, _) => body(context),
                              ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Semantics(
                          button: true,
                          label: 'Close',
                          excludeSemantics: true,
                          child: GestureDetector(
                            key: const Key('mantel-sheet-close'),
                            behavior: HitTestBehavior.opaque,
                            onTap: () => Navigator.of(context).maybePop(),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                minHeight: MantelFrame.hit,
                                minWidth: MantelFrame.hit,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.only(left: 12),
                                child: Center(
                                  child: Text(
                                    'CLOSE',
                                    style: _mono(
                                      Type.minLabel,
                                      color: const Color(0xFFD7C8B0),
                                      spacing: 1.8,
                                    ),
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
            ),
          ),
        ],
      ),
    );
  }
}
