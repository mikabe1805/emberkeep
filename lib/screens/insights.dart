import 'dart:math';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../audio.dart';
import '../clock.dart';
import '../content/creature_skins.dart';
import '../content/weekly_chronicle.dart';
import '../engine.dart';
import '../models.dart';
import '../tokens.dart';
import '../widgets/constellation.dart';
import '../widgets/detail_header.dart';
import '../widgets/facets.dart';
import '../widgets/glass.dart';
import '../widgets/luxe_depth.dart';
import 'journal_hub.dart';
import 'weekly_chronicle.dart';

/// The Insights tab: what your patterns are telling you — trends drawn
/// from your OWN data (history, stat totals, rhythm, streaks). Replaces the
/// old passive Sparks feed; evidence now lives where it matters (stat popups,
/// the per-quest "why this helps"). Everything here is computed locally.
class InsightsPage extends StatelessWidget {
  const InsightsPage({
    super.key,
    required this.state,
    required this.quests,
    required this.onPersist,
    this.parallax = const AlwaysStoppedAnimation(Offset.zero),
    this.lightDirection,
  });

  final GameState state;

  /// Live board quests — threaded so the Journal hub can gather quest logs.
  final List<Quest> quests;

  /// Persists the save after a journal edit in the hub.
  final VoidCallback onPersist;
  final ValueListenable<Offset> parallax;
  final ValueListenable<Offset>? lightDirection;

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
      builder: (context, _) => LuxePageList(
        assetPath: 'assets/pages/journal-desk-v2.webp',
        title: 'Journal',
        subtitle: 'what you noticed, and what changed',
        icon: Icons.menu_book_outlined,
        parallax: parallax,
        reduceMotion: state.reduceMotion,
        trailing: Text(
          '${_noteCount()} ENTRIES',
          style: Type.label.copyWith(fontSize: 10, color: Palette.textLo),
        ),
        children: [
          LuxeGoldButton(
            label: 'Write for today',
            icon: Icons.edit_note_rounded,
            onTap: () => _openJournal(context, compose: true),
            parallax: lightDirection ?? parallax,
          ),
          const SizedBox(height: 14),
          _JournalLensBar(
            onEntries: () => _openJournal(context),
            onPatterns: () => _openPatterns(context),
            onChronicle: () => _openChronicle(context),
          ),
          const SizedBox(height: 14),
          if (state.journal.isNotEmpty) ...[
            _thenAndNow(),
            const SizedBox(height: 14),
          ],
          _journalCard(context),
          const SizedBox(height: 14),
          _chronicleCard(context),
          const SizedBox(height: 14),
          if (state.totalCompletions == 0)
            _empty()
          else ...[
            // lead with the feeling — the one true encouraging line + this
            // week's shape — then the supporting charts below it
            _heroTakeaway(),
            const SizedBox(height: 14),
            _snapshot(),
            const SizedBox(height: 14),
            _energyWeather(),
            const SizedBox(height: 14),
            _domains(),
            const SizedBox(height: 14),
            _rhythm(),
            const SizedBox(height: 14),
            _activity(),
            const SizedBox(height: 14),
            _sky(context),
          ],
        ],
      ),
    );
  }

  void _openJournal(BuildContext context, {bool compose = false}) {
    Sfx.instance.play('tick');
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => JournalHubScreen(
          state: state,
          quests: quests,
          onPersist: onPersist,
          compose: compose,
        ),
      ),
    );
  }

  void _openChronicle(BuildContext context) {
    Sfx.instance.play('tick');
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => WeeklyChronicleScreen(state: state)),
    );
  }

  void _openPatterns(BuildContext context) {
    Sfx.instance.play('tick');
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Palette.parchment,
          body: WarmBackground(
            themeId: state.canvasTheme,
            reduceMotion: state.reduceMotion,
            tint: Palette.xp,
            child: SafeArea(
              child: Column(
                children: [
                  const DetailHeader(
                    title: 'Patterns',
                    accent: Palette.xp,
                    subtitle: 'what your own days are actually showing',
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                      children: [
                        if (state.totalCompletions == 0)
                          _empty()
                        else ...[
                          _heroTakeaway(),
                          const SizedBox(height: 14),
                          _snapshot(),
                          const SizedBox(height: 14),
                          _energyWeather(),
                          const SizedBox(height: 14),
                          _domains(),
                          const SizedBox(height: 14),
                          _rhythm(),
                          const SizedBox(height: 14),
                          _activity(),
                          const SizedBox(height: 14),
                          _sky(context),
                        ],
                      ],
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

  Widget _thenAndNow() {
    final entries = [...state.journal]..sort((a, b) => b.at.compareTo(a.at));
    final note = entries.last;
    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    // The whole point of this card is being shown your own change, so it has
    // to carry BOTH ends. It used to print only where you were when you wrote
    // it, which is half a sentence — setup with the payoff withheld.
    final then = note.context?.toUpperCase();
    final nowStanding = state.buildTitle.toUpperCase();
    final moved =
        (then != null && then != nowStanding) ||
        (note.trace != null && note.trace!.level != state.level);

    return GlassPanel(
      glow: true,
      tint: const Color(0xF0332518),
      child: Stack(
        children: [
          // A soft page of the authored MIND still life instead of the outsized
          // Material flower glyph that used to sit here — at 118 px and 5%
          // alpha that read as a smudge, not a botanical.
          Positioned(
            right: -14,
            bottom: -18,
            width: 168,
            height: 112,
            child: IgnorePointer(
              child: ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (bounds) => const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Colors.transparent, Color(0xB3000000)],
                ).createShader(bounds),
                child: Opacity(
                  opacity: 0.20,
                  child: Image.asset(
                    'assets/quest/category-mind-v2.webp',
                    fit: BoxFit.cover,
                    alignment: Alignment.centerRight,
                    filterQuality: FilterQuality.medium,
                    excludeFromSemantics: true,
                  ),
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'THEN & NOW',
                style: Type.label.copyWith(
                  fontSize: 11,
                  color: Palette.xp,
                  letterSpacing: 1.7,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '“${note.text.isEmpty ? "A moment worth keeping." : note.text}”',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Type.display.copyWith(
                  fontSize: 18,
                  height: 1.25,
                  color: Palette.textHi,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                'WRITTEN ${months[note.at.month - 1]} ${note.at.day}'
                '${note.trace == null ? '' : '  ·  LV ${note.trace!.level}'}'
                '${note.trace?.questTitles.isNotEmpty == true ? '  ·  ${note.trace!.questTitles.length} QUESTS' : ''}'
                '${then == null ? '' : '  ·  $then'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Type.label.copyWith(
                  fontSize: 10.5,
                  color: Palette.textLo,
                ),
              ),
              if (moved) ...[
                const SizedBox(height: 4),
                Text(
                  'NOW  ·  LV ${state.level}  ·  $nowStanding',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Type.label.copyWith(fontSize: 10.5, color: Palette.xp),
                ),
              ],
              if (note.context != null) ...[
                const SizedBox(height: 8),
                Text(
                  moved
                      ? 'the same thought, read by someone else'
                      : 'the same thought, seen from here',
                  style: Type.body.copyWith(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Palette.textLo,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _chronicleCard(BuildContext context) {
    final chronicle = weeklyChronicleFor(state);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Sfx.instance.play('tick');
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => WeeklyChronicleScreen(state: state),
          ),
        );
      },
      child: GlassPanel(
        glow: chronicle.total > 0,
        child: Row(
          children: [
            // Your Week and Your Journal shared one open-book glyph in two
            // tints, so the two rows read as the same destination twice.
            FacetMedallion(
              size: 40,
              accent: Palette.streak,
              child: const Icon(
                Icons.history_rounded,
                size: 20,
                color: Palette.xpLight,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your Week', style: Type.display.copyWith(fontSize: 18)),
                  const SizedBox(height: 2),
                  Text(
                    chronicle.total == 0
                        ? 'a beautiful, private-first page is waiting for your story'
                        : '${chronicle.litDays} days active · ${chronicle.total} quests · ready to share',
                    style: Type.body.copyWith(
                      fontSize: 12,
                      color: Palette.textLo,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: Palette.textLo),
          ],
        ),
      ),
    );
  }

  int _noteCount() {
    var n = state.journal.length;
    for (final s in Stat.values) {
      n += state.notesFor(s).length;
    }
    for (final g in state.goals) {
      n += g.notes.length;
    }
    for (final q in quests) {
      n += q.log.length;
    }
    return n;
  }

  /// The discoverable home for notes (round-45): a prominent, always-visible
  /// card into the Journal hub — the fix for "I don't see the notes feature
  /// anywhere." Lives at the top of Insights, where the owner looked for it.
  Widget _journalCard(BuildContext context) {
    final n = _noteCount();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Sfx.instance.play('tick');
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => JournalHubScreen(
              state: state,
              quests: quests,
              onPersist: onPersist,
            ),
          ),
        );
      },
      child: GlassPanel(
        glow: true,
        child: Row(
          children: [
            const FacetMedallion(
              size: 40,
              accent: Palette.xp,
              child: Icon(
                Icons.menu_book_outlined,
                size: 20,
                color: Palette.xpLight,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Journal',
                    style: Type.display.copyWith(fontSize: 18),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    n == 0
                        ? 'write a thought · read everything you’ve kept'
                        : '$n ${n == 1 ? "note" : "notes"} kept · tap to read & write',
                    style: Type.body.copyWith(
                      fontSize: 12,
                      color: Palette.textLo,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: Palette.textLo),
          ],
        ),
      ),
    );
  }

  Widget _empty() => GlassPanel(
    child: Column(
      children: [
        const Icon(Icons.edit_note_rounded, size: 28, color: Palette.xpLight),
        const SizedBox(height: 10),
        Text(
          'Your first page is waiting',
          style: Type.display.copyWith(fontSize: 20),
        ),
        const SizedBox(height: 6),
        Text(
          'Write one line now. Morrowloom attaches today’s quests, goal '
          'threads, and your current build automatically; patterns can grow '
          'from something you actually meant.',
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
                    style: Type.label.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _energyWeather() {
    final now = Clock.now();
    final days = [for (var i = 6; i >= 0; i--) now.subtract(Duration(days: i))];
    final values = [for (final day in days) state.energyHistory[Days.key(day)]];
    final low = values.where((v) => v == EnergyWeather.low).length;
    final bright = values.where((v) => v == EnergyWeather.bright).length;
    final recorded = values.whereType<EnergyWeather>().length;
    Color color(EnergyWeather? weather) => switch (weather) {
      EnergyWeather.low => Stat.vit.color,
      EnergyWeather.steady => Palette.xpLight,
      EnergyWeather.bright => Palette.streak,
      null => Palette.textLo,
    };
    IconData icon(EnergyWeather? weather) => switch (weather) {
      EnergyWeather.low => Icons.nightlight_outlined,
      EnergyWeather.steady => Icons.horizontal_rule,
      EnergyWeather.bright => Icons.wb_sunny_outlined,
      null => Icons.circle_outlined,
    };
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const FacetMedallion(
                size: 34,
                accent: Palette.info,
                child: Icon(
                  Icons.cloud_outlined,
                  size: 17,
                  color: Palette.info,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Energy Weather',
                      style: Type.display.copyWith(fontSize: 17),
                    ),
                    Text(
                      recorded == 0
                          ? 'check in on Quests to begin seeing your pattern'
                          : low > bright
                          ? 'a gentler week · Gentle Mode days still count'
                          : bright > low
                          ? 'more bright weather than low this week'
                          : 'a mixed week · capacity can change without failing',
                      style: Type.body.copyWith(
                        fontSize: 11.5,
                        color: Palette.textLo,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < days.length; i++)
                Column(
                  children: [
                    Text(
                      _weekdayShort[days[i].weekday - 1],
                      style: Type.label.copyWith(
                        fontSize: 9,
                        color: Palette.textLo,
                      ),
                    ),
                    const SizedBox(height: 5),
                    FacetMedallion(
                      size: 29,
                      accent: color(values[i]),
                      glow: values[i] != null,
                      child: Icon(
                        icon(values[i]),
                        size: 14,
                        color: color(values[i]),
                      ),
                    ),
                  ],
                ),
            ],
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
              fontSize: 11,
              color: lead ? color : Palette.textLo,
            ),
          ),
        ),
        Expanded(
          child: FacetedMeter(
            value: value / maxV,
            color: color.withValues(alpha: lead ? 0.9 : 0.55),
            height: 10,
            glow: lead,
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
                : 'you complete most quests in the ${top.$1.toLowerCase()}',
            style: Type.body.copyWith(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: Palette.textLo,
            ),
          ),
          const SizedBox(height: 14),
          // a single split bar
          ClipPath(
            clipper: const FacetedClipper(cut: 6),
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
                    Transform.rotate(
                      angle: 0.785,
                      child: Container(width: 7, height: 7, color: p.$3),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${p.$1}  ${(100 * p.$2 / total).round()}%',
                      style: Type.label.copyWith(fontSize: 11),
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
    final now = Clock.now();
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
            '$activeIn14 of 14 days active'
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
                              Padding(
                                padding: const EdgeInsets.only(bottom: 3),
                                child: Transform.rotate(
                                  angle: 0.785,
                                  child: Container(
                                    width: 4,
                                    height: 4,
                                    color: Palette.xpLight,
                                  ),
                                ),
                              ),
                            Container(
                              height: 6 + 44 * frac,
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              decoration: facetedDecoration(
                                color: d.$2 == 0
                                    ? Palette.glassFill
                                    : isBest
                                    ? Palette.xpLight
                                    : Palette.streak.withValues(
                                        alpha: 0.45 + 0.45 * frac,
                                      ),
                                cut: 3,
                                borderColor: Colors.transparent,
                                shadows: isBest
                                    ? [
                                        BoxShadow(
                                          color: Palette.xpLight.withValues(
                                            alpha: 0.5,
                                          ),
                                          blurRadius: 6,
                                        ),
                                      ]
                                    : const [],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _weekdayShort[d.$1.weekday - 1],
                              style: Type.label.copyWith(
                                fontSize: 11,
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
    final now = Clock.now();
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
              // The room's tapestry raster used to sit here as a 24 px chip —
              // the only photoreal object on the page, in the only rounded
              // square, wearing the only cold violet.
              const Padding(
                padding: EdgeInsets.only(top: 3),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: Palette.xp,
                  size: 18,
                ),
              ),
              const SizedBox(width: 11),
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

  /// YOUR SKY — the history constellation (ROADMAP Phase 2). Every active day
  /// becomes a star on an outward spiral; consecutive runs join into lines.
  /// It's the one surface in the app that shows the WHOLE of the
  /// effort at once, and it only ever grows: no mark for a night you missed,
  /// so a quiet week reads as the thread pausing, never as damage.
  Widget _sky(BuildContext context) {
    final lit = state.history.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    // the longest unbroken run still inside the kept window — the sky's own
    // number, which can differ from bestStreak once old days age out
    var longest = 0, run = 0;
    DateTime? prev;
    for (final e in lit) {
      final d = Days.tryParse(e.key);
      if (d == null) continue;
      run = (prev != null && Days.between(prev, d) == 1) ? run + 1 : 1;
      if (run > longest) longest = run;
      prev = d;
    }

    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('YOUR SKY', style: Type.label.copyWith(fontSize: 11)),
          const SizedBox(height: 4),
          Text(
            '${lit.length} active day${lit.length == 1 ? '' : 's'}'
            '${longest > 1 ? ' · longest run $longest days' : ''}',
            style: Type.body.copyWith(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: Palette.textLo,
            ),
          ),
          const SizedBox(height: 12),
          HistorySky(
            history: state.history,
            ember: flameHueFor(state),
            reduceMotion:
                state.reduceMotion ||
                (MediaQuery.maybeDisableAnimationsOf(context) ?? false),
          ),
          const SizedBox(height: 10),
          Text(
            lit.length < 3
                ? 'One star for every night you showed up. It only ever grows.'
                : 'Oldest day at the centre, today at the rim. Consecutive '
                      'days are joined — your streak, drawn.',
            style: Type.body.copyWith(fontSize: 12, color: Palette.textLo),
          ),
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
      // Was "a vote for the person you're becoming" — the exact register the
      // product's own direction rules out. State the fact; let it land.
      lines.add(
        state.totalCompletions == 0
            ? 'Nothing recorded yet. The first entry is the hard one.'
            : '${state.totalCompletions} quests logged. The room keeps the '
                  'count so you don’t have to.',
      );
    }
    return lines.first;
  }
}

class _JournalLensBar extends StatelessWidget {
  const _JournalLensBar({
    required this.onEntries,
    required this.onPatterns,
    required this.onChronicle,
  });

  final VoidCallback onEntries;
  final VoidCallback onPatterns;
  final VoidCallback onChronicle;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: EdgeInsets.zero,
      child: Row(
        children: [
          _item(0, Icons.menu_book_outlined, 'ENTRIES', onEntries),
          _divider(),
          _item(1, Icons.show_chart_rounded, 'PATTERNS', onPatterns),
          _divider(),
          _item(2, Icons.history_rounded, 'CHRONICLE', onChronicle),
        ],
      ),
    );
  }

  Widget _divider() => Container(
    width: 1,
    height: 34,
    color: Palette.glassEdge.withValues(alpha: 0.55),
  );

  Widget _item(int index, IconData icon, String label, VoidCallback action) {
    final selected = index == 0;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: '$label journal section',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: action,
          child: AnimatedContainer(
            duration: Motion.quick,
            curve: Motion.respond,
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 13),
            decoration: BoxDecoration(
              gradient: selected
                  ? LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Palette.xp.withValues(alpha: 0.18),
                        Palette.xp.withValues(alpha: 0.04),
                      ],
                    )
                  : null,
              border: Border(
                bottom: BorderSide(
                  color: selected ? Palette.xp : Colors.transparent,
                  width: 1.4,
                ),
              ),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 17,
                    color: selected ? Palette.xpLight : Palette.textLo,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: Type.label.copyWith(
                      fontSize: 10,
                      color: selected ? Palette.xpLight : Palette.textLo,
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
}
