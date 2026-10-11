// MONTH / WEEK / DAY: the switch that hangs over the top of the book.
//
// Three days stays reachable from the switch's overflow (a quiet menu at its
// end); when it is the view in use, the overflow lights like the others.
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../academic_calendar/data/academic_calendar_preferences.dart'
    show AcademicCalendarMode;
import '../../../tokens.dart';
import 'plans_glass.dart';

class PlansModeSwitch extends StatelessWidget {
  const PlansModeSwitch({
    super.key,
    required this.mode,
    required this.onChanged,
  });

  final AcademicCalendarMode mode;
  final ValueChanged<AcademicCalendarMode> onChanged;

  static const _shown = [
    AcademicCalendarMode.month,
    AcademicCalendarMode.week,
    AcademicCalendarMode.day,
  ];

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(11) / 11;
    // The switch is bounded chrome: its words stop growing at 130% and give
    // way to short ones beyond that (the full words stay in Semantics).
    final compact = scale > 1.35;
    final textScaler = TextScaler.linear(scale.clamp(1.0, 1.3));
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: textScaler),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: const Color(0xC71A130F),
              border: Border.all(color: const Color(0x40F4E0C0), width: 0.75),
            ),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final candidate in _shown)
                    _Segment(
                      key: ValueKey('academic-mode-${candidate.name}'),
                      label: compact ? _short(candidate) : candidate.label,
                      spoken: '${candidate.label} calendar view',
                      selected: candidate == mode,
                      onTap: () => onChanged(candidate),
                    ),
                  _Overflow(
                    selected: mode == AcademicCalendarMode.threeDay,
                    onSelected: onChanged,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _short(AcademicCalendarMode mode) => switch (mode) {
    AcademicCalendarMode.month => 'MON',
    AcademicCalendarMode.week => 'WK',
    AcademicCalendarMode.threeDay => '3D',
    AcademicCalendarMode.day => 'DAY',
  };
}

class _Segment extends StatelessWidget {
  const _Segment({
    super.key,
    required this.label,
    required this.spoken,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String spoken;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: spoken,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (!selected) HapticFeedback.selectionClick();
          onTap();
        },
        child: _Pill(
          selected: selected,
          child: Text(
            label,
            maxLines: 1,
            style: TextStyle(
              fontFamily: PlansInk.mono,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              fontSize: Type.minLabel,
              letterSpacing: 1.2,
              height: 1,
              color: selected
                  ? const Color(0xFFFFF0DA)
                  : const Color(0xFFC4B3A0),
            ),
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.selected, required this.child, this.minWidth});

  final bool selected;
  final Widget child;
  final double? minWidth;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      constraints: BoxConstraints(minWidth: minWidth ?? 44, minHeight: 36),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: selected ? const Color(0x8C805B33) : const Color(0x00805B33),
        border: Border(
          bottom: BorderSide(
            color: selected ? const Color(0xBFFFD397) : const Color(0x00FFD397),
            width: 0.75,
          ),
        ),
      ),
      child: child,
    );
  }
}

class _Overflow extends StatelessWidget {
  const _Overflow({required this.selected, required this.onSelected});

  final bool selected;
  final ValueChanged<AcademicCalendarMode> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<AcademicCalendarMode>(
      key: const ValueKey('academic-mode-overflow'),
      tooltip: 'More views',
      color: Palette.card,
      padding: EdgeInsets.zero,
      position: PopupMenuPosition.under,
      onSelected: onSelected,
      itemBuilder: (context) => [
        PopupMenuItem<AcademicCalendarMode>(
          key: const ValueKey('academic-mode-threeDay'),
          value: AcademicCalendarMode.threeDay,
          child: Semantics(
            label: '3 DAYS calendar view',
            child: ExcludeSemantics(
              child: Text(
                AcademicCalendarMode.threeDay.label,
                style: Type.label.copyWith(
                  fontSize: Type.minLabel,
                  letterSpacing: 1.2,
                  color: selected ? Palette.xpLight : Palette.textHi,
                ),
              ),
            ),
          ),
        ),
      ],
      child: Semantics(
        button: true,
        selected: selected,
        label: 'More calendar views',
        excludeSemantics: true,
        child: _Pill(
          selected: selected,
          minWidth: 32,
          child: Icon(
            Icons.more_horiz_rounded,
            size: 18,
            color: selected ? const Color(0xFFFFF0DA) : const Color(0xFFC4B3A0),
          ),
        ),
      ),
    );
  }
}
