import 'dart:math';

import 'package:flutter/material.dart';

import '../engine.dart';
import '../models.dart';
import '../tokens.dart';
import '../widgets/glass.dart';

/// The Insights tab (round-22): what your fire is telling you — trends drawn
/// from your OWN data (history, stat totals, rhythm, streaks). Replaces the
/// old passive Sparks feed; evidence now lives where it matters (stat popups,
/// the per-quest "why this helps"). Everything here is computed locally.
class InsightsPage extends StatelessWidget {
  const InsightsPage({super.key, required this.state});

  final GameState state;

  static const _weekdayShort = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const _weekdayFull = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 130),
        children: [
          Text('Insights', style: Type.display.copyWith(fontSize: 30)),
          const SizedBox(height: 4),
          Text(
            'what your fire is telling you',
            style: Type.body.copyWith(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: Palette.textLo,
            ),
          ),
          const SizedBox(height: 16),
          if (state.totalCompletions == 0)
            _empty()
          else ...[
            // lead with the feeling — the one true encouraging line + this
            // week's shape — then the supporting charts below it
            _heroTakeaway(),
            const SizedBox(height: 14),
            _snapshot(),
            const SizedBox(height: 14),
            _domains(),
            const SizedBox(height: 14),
            _rhythm(),
            const SizedBox(height: 14),
            _activity(),
          ],
        ],
      ),
    );
  }

  Widget _empty() => GlassPanel(
    child: Column(
      children: [
        const Icon(Icons.insights_outlined, size: 28, color: Palette.xpLight),
        const SizedBox(height: 10),
        Text('Nothing to read yet', style: Type.display.copyWith(fontSize: 20)),
        const SizedBox(height: 6),
        Text(
          'Clear a few quests over a few days and your patterns — your '
          'strongest domain, the time you show up, your streak shape — '
          'will take shape here.',
          textAlign: TextAlign.center,
          style: Type.body.copyWith(
            fontSize: 13,
            fontStyle: FontStyle.italic,
            color: Palette.textLo,
          ),
        ),
      ],
    ),
  );

  Widget _snapshot() {
    final activeDays = state.history.length;
    final tiles = <(String, String)>[
      ('${state.totalCompletions}', 'QUESTS DONE'),
      ('${state.streakDays}', 'DAY STREAK'),
      ('${state.bestStreak}', 'BEST STREAK'),
      ('$activeDays', 'DAYS SHOWN UP'),
    ];
    return GlassPanel(
      child: Row(
        children: [
          for (final t in tiles)
            Expanded(
              child: Column(
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      t.$1,
                      maxLines: 1,
                      style: Type.numerals.copyWith(
                        fontSize: 26,
                        color: Palette.xp,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    t.$2,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Type.label.copyWith(fontSize: 9),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _domains() {
    final entries = Stat.values.map((s) => (s, state.stats[s] ?? 0)).toList()
      ..sort((a, b) => b.$2.compareTo(a.$2));
    final maxV = max(1, entries.first.$2);
    final lead = entries.first;
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('YOUR DOMAINS', style: Type.label.copyWith(fontSize: 11)),
          const SizedBox(height: 4),
          Text(
            lead.$2 == 0
                ? 'every domain is wide open — pick one to lead'
                : '${lead.$1.label} is leading your build',
            style: Type.body.copyWith(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: Palette.textLo,
            ),
          ),
          const SizedBox(height: 12),
          for (final e in entries) ...[
            _bar(
              e.$1.label.toUpperCase(),
              e.$2,
              maxV,
              e.$1.color,
              lead: e.$1 == lead.$1 && lead.$2 > 0,
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _bar(
    String label,
    int value,
    int maxV,
    Color color, {
    bool lead = false,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 58,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Type.label.copyWith(
              fontSize: 10,
              color: lead ? color : Palette.textLo,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 10,
            decoration: BoxDecoration(
              color: Palette.glassFill,
              borderRadius: BorderRadius.circular(999),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: (value / maxV).clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: color.withValues(alpha: lead ? 0.9 : 0.55),
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: lead
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.4),
                            blurRadius: 8,
                          ),
                        ]
                      : const [],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 30,
          child: Text(
            '$value',
            textAlign: TextAlign.right,
            style: Type.numerals.copyWith(fontSize: 13, color: color),
          ),
        ),
      ],
    );
  }

  Widget _rhythm() {
    final dawn = state.dawnCompletions;
    final dusk = state.duskCompletions;
    final mid = (state.totalCompletions - dawn - dusk).clamp(
      0,
      state.totalCompletions,
    );
    final total = max(1, dawn + mid + dusk);
    final parts = <(String, int, Color)>[
      ('MORNING', dawn, Palette.xpLight),
      ('MIDDAY', mid, Palette.success),
      ('NIGHT', dusk, Palette.unlock),
    ];
    final top = parts.reduce((a, b) => b.$2 > a.$2 ? b : a);
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('YOUR RHYTHM', style: Type.label.copyWith(fontSize: 11)),
          const SizedBox(height: 4),
          Text(
            top.$2 == 0
                ? 'still finding your rhythm'
                : 'you light most embers in the ${top.$1.toLowerCase()}',
            style: Type.body.copyWith(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: Palette.textLo,
            ),
          ),
          const SizedBox(height: 14),
          // a single split bar
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Row(
              children: [
                for (final p in parts)
                  if (p.$2 > 0)
                    Expanded(
                      flex: p.$2,
                      child: Container(
                        height: 14,
                        color: p.$3.withValues(alpha: 0.8),
                      ),
                    ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final p in parts)
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: p.$3,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${p.$1}  ${(100 * p.$2 / total).round()}%',
                      style: Type.label.copyWith(fontSize: 10),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _activity() {
    final now = DateTime.now();
    final days = <(DateTime, int)>[];
    for (var i = 13; i >= 0; i--) {
      final d = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: i));
      days.add((d, state.history[Days.key(d)] ?? 0));
    }
    final maxC = max(1, days.map((d) => d.$2).reduce(max));
    final activeIn14 = days.where((d) => d.$2 > 0).length;
    // strongest weekday across all history
    final byWeekday = List<int>.filled(7, 0);
    for (final e in state.history.entries) {
      byWeekday[Days.parse(e.key).weekday - 1] += e.value;
    }
    final hasWeekday = byWeekday.any((v) => v > 0);
    var bestWd = 0;
    for (var i = 1; i < 7; i++) {
      if (byWeekday[i] > byWeekday[bestWd]) bestWd = i;
    }
    // the single strongest day in the 14-day window — a peak for the eye
    var bestIdx = -1;
    for (var i = 0; i < days.length; i++) {
      if (days[i].$2 > 0 && (bestIdx < 0 || days[i].$2 > days[bestIdx].$2)) {
        bestIdx = i;
      }
    }
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('LAST TWO WEEKS', style: Type.label.copyWith(fontSize: 11)),
          const SizedBox(height: 4),
          Text(
            '$activeIn14 of 14 days lit'
            '${hasWeekday ? ' · strongest on ${_weekdayFull[bestWd]}s' : ''}',
            style: Type.body.copyWith(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: Palette.textLo,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 80,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < days.length; i++)
                  Expanded(
                    child: Builder(
                      builder: (_) {
                        final d = days[i];
                        final frac = d.$2 / maxC;
                        final isBest = i == bestIdx;
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // a small dot crowns the strongest day
                            if (isBest)
                              Container(
                                width: 4,
                                height: 4,
                                margin: const EdgeInsets.only(bottom: 3),
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Palette.xpLight,
                                ),
                              ),
                            Container(
                              height: 6 + 44 * frac,
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              decoration: BoxDecoration(
                                color: d.$2 == 0
                                    ? Palette.glassFill
                                    : isBest
                                    ? Palette.xpLight
                                    : Palette.streak.withValues(
                                        alpha: 0.45 + 0.45 * frac,
                                      ),
                                borderRadius: BorderRadius.circular(4),
                                boxShadow: isBest
                                    ? [
                                        BoxShadow(
                                          color: Palette.xpLight.withValues(
                                            alpha: 0.5,
                                          ),
                                          blurRadius: 6,
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _weekdayShort[d.$1.weekday - 1],
                              style: Type.label.copyWith(
                                fontSize: 10,
                                color: isBest
                                    ? Palette.xpLight
                                    : Palette.textLo,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The hero: the most encouraging true observation, large, plus this week's
  /// shape vs last — the line a proud user screenshots.
  Widget _heroTakeaway() {
    final now = DateTime.now();
    int sumDays(int startAgo, int count) {
      var s = 0;
      for (var i = startAgo; i < startAgo + count; i++) {
        final d = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: i));
        s += state.history[Days.key(d)] ?? 0;
      }
      return s;
    }

    final thisWeek = sumDays(0, 7);
    final lastWeek = sumDays(7, 7);
    final delta = thisWeek - lastWeek;
    final showWeek = thisWeek > 0 || lastWeek > 0;

    final (String deltaText, Color deltaColor) = lastWeek == 0
        ? ('your first week — it begins', Palette.xpLight)
        : delta > 0
        ? ('▲ $delta vs last week', Palette.success)
        : delta < 0
        ? ('▼ ${-delta} vs last week', Palette.textLo)
        : ('steady with last week', Palette.textLo);

    return GlassPanel(
      glow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.local_fire_department,
                  size: 20,
                  color: Palette.streak,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _takeawayLine(),
                  style: Type.display.copyWith(fontSize: 17, height: 1.3),
                ),
              ),
            ],
          ),
          if (showWeek) ...[
            const SizedBox(height: 14),
            const Divider(color: Palette.glassEdge, height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                Text('THIS WEEK', style: Type.label.copyWith(fontSize: 11)),
                const SizedBox(width: 8),
                Text(
                  '$thisWeek',
                  style: Type.numerals.copyWith(
                    fontSize: 18,
                    color: Palette.xp,
                  ),
                ),
                const Spacer(),
                Flexible(
                  child: Text(
                    deltaText,
                    textAlign: TextAlign.right,
                    style: Type.label.copyWith(fontSize: 11, color: deltaColor),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _takeawayLine() {
    // pick the most encouraging true observation
    final lines = <String>[];
    if (state.comebacks > 0) {
      lines.add(
        'You’ve come back after a gap ${state.comebacks} time${state.comebacks == 1 ? '' : 's'} — '
        'returning is rarer and harder than never stopping.',
      );
    }
    if (state.dreadCompletions > 0) {
      lines.add(
        'You’ve done ${state.dreadCompletions} quest${state.dreadCompletions == 1 ? '' : 's'} you '
        'dreaded. That’s the muscle most people never train.',
      );
    }
    if (state.perfectDays > 0) {
      lines.add(
        '${state.perfectDays} perfect day${state.perfectDays == 1 ? '' : 's'} — '
        'whole boards cleared. Those are the ones that compound.',
      );
    }
    if (state.verifiedCompletions > 0) {
      lines.add(
        '${state.verifiedCompletions} quest${state.verifiedCompletions == 1 ? '' : 's'} '
        'proved on the timer — you showed up AND stayed.',
      );
    }
    if (lines.isEmpty) {
      lines.add(
        'Every quest you finish is a vote for the person you’re becoming. '
        'Keep stacking them.',
      );
    }
    return lines.first;
  }
}
