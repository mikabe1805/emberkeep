import 'package:flutter/material.dart';

import '../audio.dart';
import '../clock.dart';
import '../tokens.dart';
import 'facets.dart';
import 'glass.dart';
import 'honey_button.dart';

const _dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
const _dayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// Human label for a weekly anchor: "Any day" or e.g. "Tuesdays".
String weekdayLabel(List<int> weekdays) {
  if (weekdays.isEmpty) return 'Any day';
  final d = weekdays.first.clamp(1, 7);
  return '${_dayNames[d - 1]}s';
}

/// Asks which weekday a weekly quest should land on. Returns 1..7 (Mon..Sun)
/// to anchor it, 0 for "any day this week" (no anchor), or null if dismissed.
/// Defaults the selection to [initial] (or today), so the common "I'm doing it
/// today, recur weekly" case is one tap.
Future<int?> pickWeekday(
  BuildContext context, {
  required Color accent,
  required String questTitle,
  int? initial,
}) {
  return showModalBottomSheet<int>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _WeekdaySheet(
      accent: accent,
      questTitle: questTitle,
      initial: (initial ?? Clock.now().weekday).clamp(1, 7),
    ),
  );
}

class _WeekdaySheet extends StatefulWidget {
  const _WeekdaySheet({
    required this.accent,
    required this.questTitle,
    required this.initial,
  });
  final Color accent;
  final String questTitle;
  final int initial;

  @override
  State<_WeekdaySheet> createState() => _WeekdaySheetState();
}

class _WeekdaySheetState extends State<_WeekdaySheet> {
  late int _sel = widget.initial;

  void _chooseDay(int day) {
    Sfx.instance.playMaterial(MaterialSound.parchment);
    setState(() => _sel = day);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: GlassPanel(
          tint: const Color(0xF22A211D),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'WHICH DAY EACH WEEK?',
                style: Type.label.copyWith(fontSize: 12, color: widget.accent),
              ),
              const SizedBox(height: 6),
              Text(
                widget.questTitle,
                style: Type.display.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 18),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var d = 1; d <= 7; d++)
                    Semantics(
                      button: true,
                      selected: _sel == d,
                      label: _dayNames[d - 1],
                      onTap: () => _chooseDay(d),
                      child: GestureDetector(
                        excludeFromSemantics: true,
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _chooseDay(d),
                        child: Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: facetedDecoration(
                            cut: 8,
                            color: _sel == d
                                ? widget.accent.withValues(alpha: 0.28)
                                : Palette.glassFill,
                            borderColor: _sel == d
                                ? widget.accent
                                : Palette.glassEdge,
                            borderWidth: _sel == d ? 1.6 : 1.0,
                          ),
                          child: Text(
                            _dayLetters[d - 1],
                            style: Type.label.copyWith(
                              fontSize: 13,
                              color: _sel == d ? widget.accent : Palette.textLo,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'lands every ${_dayNames[_sel - 1]}',
                style: Type.body.copyWith(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: Palette.textLo,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.of(context).pop(0),
                      child: Container(
                        alignment: Alignment.center,
                        constraints: const BoxConstraints(minHeight: 48),
                        decoration: facetedDecoration(
                          cut: 9,
                          color: Colors.transparent,
                          borderColor: Palette.glassEdge,
                        ),
                        child: Text(
                          'ANY DAY',
                          style: Type.label.copyWith(
                            fontSize: 12,
                            color: Palette.textLo,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: HoneyButton(
                      label: 'PIN TO ${_dayNames[_sel - 1].toUpperCase()}',
                      expand: true,
                      onTap: () {
                        Navigator.of(context).pop(_sel);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
