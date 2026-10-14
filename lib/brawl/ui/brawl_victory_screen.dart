// The victory screen: how long it took, the chest that speed earned, the loot
// for the house, and which of your stats did the work. A week's first win
// opens a chest; every fight after it that weekend is practice, with no chest
// to open.
library;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../tokens.dart';
import '../../widgets/honey_button.dart';
import '../brawl_loot.dart';
import '../core/brawl_core.dart';
import 'brawl_chest.dart';
import 'brawl_feel.dart';
import 'brawl_glass.dart';

/// What each source of damage is called and what in your week it stands for.
({String label, String source, String thing}) brawlSourceWords(
  BrawlDamageSource source,
) => switch (source) {
  BrawlDamageSource.fist => (
    label: 'Combos',
    source: 'your level',
    thing: 'steady combos',
  ),
  BrawlDamageSource.slam => (
    label: 'Power Slam',
    source: 'your workouts',
    thing: 'workouts',
  ),
  BrawlDamageSource.spell => (
    label: 'Spell Bolt',
    source: 'your reading',
    thing: 'reading',
  ),
  BrawlDamageSource.friend => (
    label: 'Call a Friend',
    source: 'your time with friends',
    thing: 'friends',
  ),
  BrawlDamageSource.focus => (
    label: 'Focus crits',
    source: 'your focus sessions',
    thing: 'focus',
  ),
  BrawlDamageSource.superMove => (
    label: 'Super',
    source: 'your streaks',
    thing: 'streaks',
  ),
  BrawlDamageSource.finisher => (
    label: 'The finisher',
    source: 'your timing',
    thing: 'timing',
  ),
};

/// One plain line naming what in your life did the most: "Your reading did
/// most of the work." Trained this week, it says so.
String brawlCreditLine(BrawlResult result) {
  if (result.rows.isEmpty) return '';
  final top = result.rows.first;
  final words = brawlSourceWords(top.source);
  return top.trainedPoints > 0
      ? 'This week’s ${words.thing} did most of the work.'
      : 'Your ${words.thing} did most of the work.';
}

class BrawlVictoryScreen extends StatefulWidget {
  const BrawlVictoryScreen({
    super.key,
    required this.result,
    required this.earned,
    required this.keptThisWeek,
    required this.onDone,
    required this.onAgain,
    this.feel = const SilentFeel(),
    this.reduceMotion = false,
  });

  final BrawlResult result;

  /// The loot this win earned, or null when this was practice.
  final BrawlLoot? earned;

  /// This weekend's loot from an earlier win (shown on a practice win).
  final BrawlLoot? keptThisWeek;
  final VoidCallback onDone;
  final VoidCallback onAgain;
  final BrawlFeel feel;
  final bool reduceMotion;

  @override
  State<BrawlVictoryScreen> createState() => _BrawlVictoryScreenState();
}

class _BrawlVictoryScreenState extends State<BrawlVictoryScreen>
    with SingleTickerProviderStateMixin {
  final ValueNotifier<double> _t = ValueNotifier(0);
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(
      (elapsed) => _t.value = elapsed.inMicroseconds / 1e6,
    );
    if (!widget.reduceMotion && widget.earned != null) _ticker.start();
    widget.feel.play(BrawlSound.victory);
    if (widget.earned != null) {
      Future<void>.delayed(const Duration(milliseconds: 650), () {
        if (mounted) widget.feel.play(BrawlSound.chest);
      });
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    final media = MediaQuery.of(context);
    final practice = widget.earned == null;
    return BrawlBackdrop(
      child: Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              key: const Key('brawl-victory-scroll'),
              padding: EdgeInsets.fromLTRB(
                16,
                media.padding.top + 28,
                16,
                media.padding.bottom + 150,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      r.perfect ? 'K.O. and PERFECT' : 'K.O.',
                      textAlign: TextAlign.center,
                      style: brawlSerif(
                        28,
                        weight: FontWeight.w700,
                        color: r.perfect
                            ? const Color(0xFFFFD25A)
                            : const Color(0xFFE5C896),
                      ).copyWith(letterSpacing: 6),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    r.finisherLine,
                    key: const Key('brawl-victory-line'),
                    textAlign: TextAlign.center,
                    style: brawlSerif(
                      32,
                      weight: FontWeight.w700,
                      color: Palette.textHi,
                      height: 1.08,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _TimeBlock(seconds: r.seconds),
                  const SizedBox(height: 16),
                  practice
                      ? _PracticeCard(kept: widget.keptThisWeek)
                      : _ChestCard(
                          loot: widget.earned!,
                          time: _t,
                          still: widget.reduceMotion,
                        ),
                  const SizedBox(height: 14),
                  if (r.rows.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
                      child: Text(
                        brawlCreditLine(r),
                        key: const Key('brawl-credit-line'),
                        textAlign: TextAlign.center,
                        style: brawlSerif(
                          19,
                          italic: true,
                          weight: FontWeight.w500,
                          color: Palette.xpLight,
                        ),
                      ),
                    ),
                  _Breakdown(result: r),
                  const SizedBox(height: 14),
                  _Facts(result: r),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x00130B07),
                    Color(0xF0130B07),
                    Color(0xFF130B07),
                  ],
                  stops: [0, 0.35, 1],
                ),
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  24,
                  28,
                  24,
                  media.padding.bottom + 12,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 300),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        HoneyButton(
                          key: const Key('brawl-done'),
                          label: 'DONE',
                          semanticLabel: 'Done. Back to the house',
                          expand: true,
                          fontSize: 14,
                          onTap: widget.onDone,
                        ),
                        const SizedBox(height: 8),
                        HoneyButton(
                          key: const Key('brawl-again'),
                          label: 'FIGHT AGAIN',
                          semanticLabel: 'Fight again, for practice',
                          expand: true,
                          quiet: true,
                          compact: true,
                          onTap: widget.onAgain,
                        ),
                      ],
                    ),
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

class _TimeBlock extends StatelessWidget {
  const _TimeBlock({required this.seconds});

  final double seconds;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: 'Fight time ${brawlFormatTime(seconds)}',
    child: ExcludeSemantics(
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.end,
        spacing: 10,
        children: [
          Text(
            brawlFormatTime(seconds),
            key: const Key('brawl-victory-time'),
            style: Type.label.copyWith(
              fontSize: 60,
              fontWeight: FontWeight.w500,
              letterSpacing: 2,
              height: 1,
              color: Palette.textHi,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'FIGHT TIME',
              style: Type.label.copyWith(
                fontSize: Type.minLabel,
                letterSpacing: 2,
                color: Palette.textLo,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ChestCard extends StatelessWidget {
  const _ChestCard({
    required this.loot,
    required this.time,
    required this.still,
  });

  final BrawlLoot loot;
  final ValueListenable<double> time;
  final bool still;

  @override
  Widget build(BuildContext context) {
    final rule =
        'Swift up to ${brawlFormatTime(kBrawlSwiftSeconds)}. Steady up to '
        '${brawlFormatTime(kBrawlSteadySeconds)}. Patient after.';
    return Semantics(
      container: true,
      label: '${loot.chestName}. ${loot.loot}, for your house. $rule',
      child: ExcludeSemantics(
        child: BrawlGlassCard(
          key: const Key('brawl-chest-card'),
          hot: true,
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 124,
                height: 112,
                child: CustomPaint(
                  painter: BrawlChestPainter(
                    time: time,
                    chest: loot.chest,
                    loot: loot.loot,
                    still: still,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loot.chestName.toUpperCase(),
                      style: Type.label.copyWith(
                        fontSize: Type.minLabel,
                        letterSpacing: 1.8,
                        color: Palette.xp,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      loot.loot,
                      key: const Key('brawl-loot-name'),
                      style: brawlSerif(
                        28,
                        weight: FontWeight.w700,
                        height: 1.02,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'for your house',
                      style: brawlSerif(
                        17,
                        italic: true,
                        weight: FontWeight.w500,
                        color: Palette.textMid,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      rule,
                      style: Type.label.copyWith(
                        fontSize: Type.minLabel,
                        letterSpacing: 0.2,
                        fontWeight: FontWeight.w500,
                        color: Palette.textLo,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PracticeCard extends StatelessWidget {
  const _PracticeCard({required this.kept});

  final BrawlLoot? kept;

  @override
  Widget build(BuildContext context) {
    final line = kept == null
        ? 'This weekend’s chest is already yours. This one was for practice.'
        : 'This weekend’s chest is already yours: ${kept!.loot} is waiting in '
              'your trophy case. This one was for practice.';
    return Semantics(
      container: true,
      label: 'Practice. $line',
      child: ExcludeSemantics(
        child: BrawlGlassCard(
          key: const Key('brawl-practice-card'),
          child: Row(
            children: [
              if (kept != null) ...[
                BrawlLootMark(loot: kept!.loot, size: 52),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PRACTICE',
                      style: Type.label.copyWith(
                        fontSize: Type.minLabel,
                        letterSpacing: 1.8,
                        color: Palette.xp,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      line,
                      style: brawlSerif(
                        18,
                        weight: FontWeight.w500,
                        color: Palette.textMid,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Breakdown extends StatelessWidget {
  const _Breakdown({required this.result});

  final BrawlResult result;

  @override
  Widget build(BuildContext context) => BrawlGlassCard(
    key: const Key('brawl-breakdown'),
    padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const BrawlCaps('WHAT DID THE WORK'),
        const SizedBox(height: 10),
        for (final row in result.rows) _Row(row: row),
        const SizedBox(height: 4),
        Text(
          result.knockdowns == 0
              ? 'Second Wind never needed to. You stayed on your feet.'
              : 'Second Wind got you back up ${result.knockdowns} '
                    '${result.knockdowns == 1 ? 'time' : 'times'}.',
          style: brawlSerif(
            15,
            italic: true,
            weight: FontWeight.w500,
            color: Palette.textLo,
          ),
        ),
      ],
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row({required this.row});

  final BrawlBreakdownRow row;

  @override
  Widget build(BuildContext context) {
    final words = brawlSourceWords(row.source);
    final hot = row.trainedPoints > 0;
    final pct = row.percent.round();
    final week = hot ? '+${_pts(row.trainedPoints)} this week' : null;
    return Semantics(
      container: true,
      label:
          '${words.label}, ${words.source}${week == null ? '' : ', $week'}, $pct percent',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: hot
                  ? Border.all(color: Palette.xp.withValues(alpha: 0.5))
                  : null,
              color: hot ? const Color(0x24E0A865) : null,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: words.label,
                                style: brawlSerif(
                                  18,
                                  weight: hot
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                  color: hot ? Palette.textHi : Palette.textMid,
                                ),
                              ),
                              TextSpan(
                                text: '  ·  ${words.source}',
                                style: brawlSerif(
                                  16,
                                  weight: FontWeight.w500,
                                  color: Palette.textLo,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$pct%',
                        style: Type.numerals.copyWith(fontSize: 18),
                      ),
                    ],
                  ),
                  if (week != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      week,
                      style: Type.label.copyWith(
                        fontSize: Type.minLabel,
                        letterSpacing: 0.4,
                        color: Palette.xpLight,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      height: 7,
                      child: Stack(
                        children: [
                          const Positioned.fill(
                            child: ColoredBox(color: Color(0x8C0C0603)),
                          ),
                          FractionallySizedBox(
                            heightFactor: 1,
                            alignment: Alignment.centerLeft,
                            widthFactor: (row.percent.clamp(2, 100)) / 100,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: hot
                                      ? const [
                                          Color(0xFFF7D68E),
                                          Color(0xFFE0A865),
                                        ]
                                      : const [
                                          Color(0xFFB08A55),
                                          Color(0xFF8A6A40),
                                        ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _pts(double p) {
    final r = (p * 2).round() / 2;
    return r == r.roundToDouble() ? '${r.round()}' : r.toStringAsFixed(1);
  }
}

class _Facts extends StatelessWidget {
  const _Facts({required this.result});

  final BrawlResult result;

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, int n) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE5C896).withValues(alpha: 0.25),
        ),
        color: const Color(0x33140C06),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '$label '),
            TextSpan(
              text: '$n',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Palette.textHi,
              ),
            ),
          ],
        ),
        style: Type.label.copyWith(
          fontSize: Type.minLabel,
          letterSpacing: 0.4,
          color: Palette.textMid,
        ),
      ),
    );
    return Semantics(
      container: true,
      label:
          'Best combo ${result.maxCombo}. Crits ${result.crits}. Supers ${result.supers}. Friends called ${result.friendsCalled}.',
      child: ExcludeSemantics(
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            chip('Best combo', result.maxCombo),
            chip('Crits', result.crits),
            chip('Supers', result.supers),
            chip('Friends called', result.friendsCalled),
          ],
        ),
      ),
    );
  }
}
