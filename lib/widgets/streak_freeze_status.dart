import 'package:flutter/material.dart';

import '../audio.dart';
import '../engine.dart';
import '../models.dart';
import '../tokens.dart';
import 'facets.dart';
import 'glass.dart';
import 'pressable.dart';

/// Compact continuity truth for the Quest board. It shares the existing TODAY
/// rail instead of introducing another dashboard card or competing action.
class StreakFreezeStatus extends StatelessWidget {
  const StreakFreezeStatus({super.key, required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    final gap = state.pendingStreakGap;
    final stale = gap.days > 0 && !gap.covered;
    final ready = state.streakFreezes;
    final best = state.bestStreak.clamp(state.streakDays, 1 << 30);
    final value = stale
        ? '$ready READY · BEST $best KEPT'
        : '$ready READY · ${state.streakDays} DAY STREAK';
    final spokenStatus = stale
        ? '$ready ${ready == 1 ? "freeze" : "freezes"} ready. Best streak $best kept.'
        : '$ready ${ready == 1 ? "freeze" : "freezes"} ready. '
              '${state.streakDays} day streak.';

    return Padding(
      padding: const EdgeInsets.only(top: 5, right: 8, bottom: 3),
      child: Pressable(
        material: MaterialSound.glass,
        pressDepth: 1,
        edgeColor: Colors.transparent,
        shape: const FacetedBorder(cut: 5),
        semanticLabel: 'Freeze reserve. $spokenStatus Open details.',
        onTapUp: (_) => showStreakFreezeDetails(context, state),
        child: DecoratedBox(
          decoration: facetedDecoration(
            cut: 5,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: stale
                  ? const [Color(0x261C1714), Color(0x14120F0D)]
                  : const [Color(0x242A5553), Color(0x12131E1E)],
            ),
            borderColor: (stale ? Palette.textLo : Palette.info).withValues(
              alpha: stale ? 0.24 : 0.34,
            ),
            borderWidth: 0.8,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(7, 4, 9, 5),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Icon(
                        stale ? Icons.history_rounded : Icons.ac_unit_rounded,
                        size: 9,
                        color: stale ? Palette.textLo : Palette.info,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'FREEZE RESERVE',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Type.label.copyWith(
                          fontSize: 7.5,
                          color: (stale ? Palette.textLo : Palette.info)
                              .withValues(alpha: 0.82),
                          letterSpacing: 1.15,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Type.label.copyWith(
                    fontSize: 9.2,
                    color: stale ? Palette.textLo : Palette.info,
                    letterSpacing: 0.7,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showStreakFreezeDetails(BuildContext context, GameState state) {
  final gap = state.pendingStreakGap;
  final recent = state.frozenStreakDays.toList()
    ..sort((a, b) => b.compareTo(a));
  final progress = state.streakFreezeProgress;
  final needed = state.activeDaysPerFreeze;
  final capacity = state.streakFreezeCapacity;

  final status = gap.days == 0
      ? 'A freeze quietly holds one day away. They deploy automatically only '
            'when the whole gap can be covered, so none are wasted.'
      : gap.covered
      ? '${gap.days} quiet ${gap.days == 1 ? "day is" : "days are"} ready to '
            'be held when you finish a quest today.'
      : 'Your best run stays kept. Today starts a fresh rhythm, and your '
            '${state.streakFreezes} ${state.streakFreezes == 1 ? "freeze is" : "freezes are"} still ready.';

  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0xA6120B09),
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.82,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: GlassPanel(
              blur: true,
              tint: const Color(0xF5241A16),
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(
                            Icons.ac_unit_rounded,
                            size: 22,
                            color: Palette.info,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'STREAK FREEZES',
                                style: Type.label.copyWith(
                                  fontSize: 12,
                                  color: Palette.info,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Room for real life',
                                style: Type.display.copyWith(fontSize: 22),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _FreezeFact(
                            value: '${state.streakFreezes}',
                            label: 'READY',
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 42,
                          color: Palette.glassEdge,
                        ),
                        Expanded(
                          child: _FreezeFact(
                            value: '$progress / $needed',
                            label: 'ACTIVE DAYS',
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 42,
                          color: Palette.glassEdge,
                        ),
                        Expanded(
                          child: _FreezeFact(
                            value: '$capacity',
                            label: 'CAPACITY',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      status,
                      style: Type.body.copyWith(
                        fontSize: 13.5,
                        height: 1.45,
                        color: Palette.textMid,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Every $needed active days banks another freeze. '
                      '${needed == 2 ? "Your CARE build has shortened the cadence." : "At CARE 40, that shortens to two."} '
                      '${state.level >= 6 ? "You can hold a full week." : "Level 6 opens room for a full week."}',
                      style: Type.body.copyWith(
                        fontSize: 12.5,
                        height: 1.4,
                        color: Palette.textLo,
                      ),
                    ),
                    if (recent.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      Text(
                        'RECENTLY HELD',
                        style: Type.label.copyWith(fontSize: 11),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final day in recent.take(4))
                            _FrozenDay(day: day),
                        ],
                      ),
                    ],
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

class _FreezeFact extends StatelessWidget {
  const _FreezeFact({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          maxLines: 1,
          style: Type.numerals.copyWith(fontSize: 22, color: Palette.textHi),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          style: Type.label.copyWith(fontSize: 10, color: Palette.textLo),
        ),
      ],
    );
  }
}

class _FrozenDay extends StatelessWidget {
  const _FrozenDay({required this.day});

  final String day;

  static const _months = <String>[
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

  @override
  Widget build(BuildContext context) {
    final parsed = Days.tryParse(day);
    final label = parsed == null
        ? day
        : '${_months[parsed.month - 1]} ${parsed.day}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Palette.info.withValues(alpha: 0.08),
        border: Border.all(color: Palette.info.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.ac_unit_rounded, size: 12, color: Palette.info),
          const SizedBox(width: 5),
          Text(
            label,
            style: Type.label.copyWith(fontSize: 10, color: Palette.info),
          ),
        ],
      ),
    );
  }
}
