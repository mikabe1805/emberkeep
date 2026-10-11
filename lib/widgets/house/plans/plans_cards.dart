// The day's cards: one light smoky-glass card per class, event, task,
// assignment, exam, study block and planned Quest, each with its completion
// ring and its "..." menu.
//
// The ring is the card's own completion where there is one (tasks, course
// work, study blocks, a Quest planned for today) and a quiet course ring where
// there is not (a class or an event is not something you tick off here; the
// Quests room has I WAS THERE). Everything a row could do before is still on
// the card: the "..." menu holds notes and MOVE / CANCEL THIS CLASS for a
// class and the event and task actions for the rest; a tight turnaround, the
// study plan and directions sit on the card where they were.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../academic_calendar/domain/academic_schedule.dart';
import '../../../academic_calendar/widgets/academic_calendar_sections.dart';
import '../../../audio.dart';
import '../../../clock.dart';
import '../../../daybook/presentation/daybook_range_projection.dart';
import '../../../daybook/widgets/daybook_rows.dart';
import '../../../tokens.dart';
import 'plans_actions.dart';
import 'plans_card_menu.dart';
import 'plans_glass.dart';

/// A press that darkens and settles a little, for glass (an ink splash would
/// paint under the glass and never show).
class PlansPress extends StatefulWidget {
  const PlansPress({
    super.key,
    required this.child,
    required this.onTap,
    this.radius = 9,
    this.behavior = HitTestBehavior.opaque,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double radius;
  final HitTestBehavior behavior;

  @override
  State<PlansPress> createState() => _PlansPressState();
}

class _PlansPressState extends State<PlansPress> {
  bool _down = false;

  void _set(bool down) {
    if (_down != down && mounted) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      behavior: widget.behavior,
      excludeFromSemantics: true,
      onTap: widget.onTap,
      onTapDown: enabled ? (_) => _set(true) : null,
      onTapUp: enabled ? (_) => _set(false) : null,
      onTapCancel: enabled ? () => _set(false) : null,
      child: AnimatedScale(
        scale: _down ? 0.992 : 1,
        duration: const Duration(milliseconds: 90),
        child: Stack(
          children: [
            widget.child,
            if (_down)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0x4D140D08),
                      borderRadius: BorderRadius.circular(widget.radius),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The completion ring: honey outline, filled gold with a small check when
/// done.
class PlansRing extends StatelessWidget {
  const PlansRing({super.key, required this.done, this.accent, this.size = 19});

  final bool done;

  /// A course's colour, for the ring of a class (a task's ring is honey).
  final Color? accent;
  final double size;

  @override
  Widget build(BuildContext context) {
    final line = accent ?? PlansInk.ring;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: done ? PlansInk.ringDone : line, width: 1.6),
        color: done ? null : const Color(0x2610140C),
        gradient: done
            ? const RadialGradient(
                colors: [Color(0xFFF7D68E), Color(0xFFD9A24F)],
              )
            : null,
        boxShadow: done
            ? const [BoxShadow(color: Color(0x80E8B464), blurRadius: 6)]
            : null,
      ),
      child: done
          ? const Icon(Icons.check_rounded, size: 13, color: Color(0xFF2A1B0C))
          : null,
    );
  }
}

class PlansEntryCard extends StatelessWidget {
  const PlansEntryCard({
    super.key,
    required this.entry,
    required this.day,
    required this.schedule,
    required this.actions,
    this.first = false,
    this.status,
  });

  final DaybookEntry entry;
  final DaybookDay day;
  final AcademicSchedule schedule;
  final PlansActions actions;

  /// The first card of the day has the brighter edge.
  final bool first;

  /// What to say on the class that is in session or comes next ("NOW",
  /// "IN 12 MIN", "NEXT"), and whether it is the one in session.
  final ({String label, bool active})? status;

  ClassOccurrence? get _occurrence => entry.action is AcademicOccurrenceAction
      ? schedule.occurrenceByKey(
          (entry.action as AcademicOccurrenceAction).occurrenceKey,
        )
      : null;

  @override
  Widget build(BuildContext context) {
    final occurrence = _occurrence;
    final course = occurrence == null
        ? null
        : schedule.courseById(occurrence.courseId);
    final dim = entry.completed || entry.cancelled;
    final conflict = day.summary.conflicts.any(
      (item) =>
          item.leftDisplayKey == entry.displayKey ||
          item.rightDisplayKey == entry.displayKey,
    );
    final title = course?.title ?? entry.title;
    final lines = _lines(occurrence);
    final menu = _menuKind();
    final notes = status != null && occurrence != null
        ? _NotesMini(
            key: const ValueKey('academic-doorway-open-notebook'),
            title: entry.title,
            onTap: () => actions.onOpenNotebook(occurrence),
          )
        : null;
    final ring = _ring(context);
    final footer = _footer();

    final tags = <Widget>[
      if (status != null)
        _Tag(
          key: ValueKey(
            status!.active ? 'academic-now-next' : 'academic-next-class',
          ),
          label: status!.label,
          color: PlansInk.ringDone,
        ),
      if (entry.moved) const _Tag(label: 'MOVED', color: PlansInk.creamSoft),
      if (entry.cancelled)
        const _Tag(label: 'CANCELLED', color: PlansInk.creamDim),
      if (conflict)
        _Tag(
          key: ValueKey('academic-overlap-${entry.sourceId}'),
          label: 'OVERLAP',
          color: const Color(0xFFF0B0A0),
        ),
    ];

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        PlansCardTitle(title: title, dim: dim),
        const SizedBox(height: 4),
        Wrap(
          spacing: 7,
          runSpacing: 3,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              lines.primary,
              style: _mono(
                dim ? PlansInk.creamDim : PlansInk.creamSoft,
                letterSpacing: 0.6,
              ),
            ),
            ...tags,
          ],
        ),
        if (lines.secondary != null) ...[
          const SizedBox(height: 2),
          Text(
            lines.secondary!,
            style: _mono(PlansInk.creamDim, letterSpacing: 0.6),
          ),
        ],
        if (lines.detail != null) ...[
          const SizedBox(height: 3),
          Text(
            lines.detail!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12.5,
              height: 1.25,
              color: PlansInk.creamDim,
            ),
          ),
        ],
        if (footer != null) ...[const SizedBox(height: 8), footer],
      ],
    );

    // At large text the ring and the menu step up above the words, so the
    // words have the whole card and never break in the middle of a word.
    final large = plansTextScale(context) >= 1.5;
    final content = large
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  SizedBox(width: 44, child: Center(child: ring)),
                  const Spacer(),
                  ?notes,
                  if (menu != null)
                    SizedBox(width: 44, child: _more(context, menu)),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: body,
              ),
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 44,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [ring, ?notes],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: body,
                ),
              ),
              SizedBox(
                width: menu == null ? 8 : 44,
                child: menu == null ? null : _more(context, menu),
              ),
            ],
          );

    final card = PlansGlass(
      bright: first,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 62),
        child: content,
      ),
    );
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: daybookEntrySemantics(entry),
      child: menu == null
          ? card
          : PlansPress(onTap: () => _openMenu(context, menu), child: card),
    );
  }

  // ── what the card says ────────────────────────────────────────────────

  ({String primary, String? secondary, String? detail}) _lines(
    ClassOccurrence? occurrence,
  ) {
    final range = daybookEntryTiming(entry);
    switch (entry.sourceKind) {
      case DaybookSourceKind.classOccurrence:
        // "PHY · 001" reads as one room: "PHY 001". The course's code stays
        // in the "..." menu, where the class is named in full.
        final room = occurrence?.place.shortLabel.replaceAll(' · ', ' ');
        final kind = occurrence?.kind.shortLabel;
        return (
          primary: range,
          secondary: [
            if (room != null && room.isNotEmpty) room,
            ?kind,
          ].join(' · '),
          detail: null,
        );
      case DaybookSourceKind.task:
        final plain = entry.startMinute == null;
        return (
          primary: plain ? 'TASK' : range,
          secondary: plain ? null : 'TASK',
          detail: entry.place?.savedName,
        );
      case DaybookSourceKind.questPlan:
        return (primary: range, secondary: 'QUEST', detail: null);
      case DaybookSourceKind.event:
      case DaybookSourceKind.academicWork:
      case DaybookSourceKind.studyBlock:
        final extra = [
          if (entry.place != null) entry.place!.savedName,
          if (entry.supportingText != null &&
              entry.sourceKind != DaybookSourceKind.studyBlock)
            entry.supportingText!,
        ];
        return (
          primary: range,
          secondary: entry.sourceLabel,
          detail: extra.isEmpty ? null : extra.join(' · '),
        );
    }
  }

  static TextStyle _mono(Color color, {double letterSpacing = 1}) => TextStyle(
    fontFamily: PlansInk.mono,
    fontWeight: FontWeight.w500,
    fontSize: Type.minLabel,
    height: 1.15,
    letterSpacing: letterSpacing,
    color: color,
    shadows: const [
      Shadow(color: Color(0x990A0502), blurRadius: 1.5, offset: Offset(0, 0.5)),
    ],
  );

  // ── the ring ──────────────────────────────────────────────────────────

  Widget _ring(BuildContext context) {
    Widget button({
      required Key key,
      required String title,
      VoidCallback? onTap,
      ValueChanged<Offset>? onTapAt,
      bool canReopen = true,
    }) {
      final enabled = onTap != null || onTapAt != null;
      return Semantics(
        button: enabled,
        enabled: enabled,
        checked: entry.completed,
        label: entry.completed && (!enabled || !canReopen)
            ? '$title complete'
            : entry.completed
            ? 'Mark $title open'
            : 'Mark $title complete',
        excludeSemantics: true,
        onTap: enabled
            ? () => _activate(context, onTap: onTap, onTapAt: onTapAt)
            : null,
        child: GestureDetector(
          key: key,
          behavior: HitTestBehavior.opaque,
          onTap: enabled
              ? () => _activate(context, onTap: onTap, onTapAt: onTapAt)
              : null,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(child: PlansRing(done: entry.completed)),
          ),
        ),
      );
    }

    return switch (entry.action) {
      DaybookTaskAction() => button(
        key: ValueKey('daybook-task-toggle-${entry.sourceId}'),
        title: entry.title,
        onTap: _toggleTask,
      ),
      AcademicWorkAction() => button(
        key: ValueKey('academic-work-toggle-${entry.sourceId}'),
        title: entry.title,
        onTap: _toggleWork,
      ),
      AcademicStudyAction() => button(
        key: ValueKey('academic-study-toggle-${entry.sourceId}'),
        title: 'study ${entry.title}',
        onTap: _toggleStudyBlock,
      ),
      QuestPlanAction() when day.date == CivilDate.fromDateTime(Clock.now()) =>
        button(
          key: ValueKey('quest-plan-toggle-${entry.sourceId}'),
          title: entry.title,
          onTapAt: !entry.completed && actions.onCompleteQuestPlan != null
              ? (anchor) => _completeQuestPlan(anchor)
              : null,
          canReopen: false,
        ),
      _ => ExcludeSemantics(child: PlansRing(done: entry.completed)),
    };
  }

  void _activate(
    BuildContext context, {
    VoidCallback? onTap,
    ValueChanged<Offset>? onTapAt,
  }) {
    HapticFeedback.selectionClick();
    onTap?.call();
    final callback = onTapAt;
    if (callback == null) return;
    final box = context.findRenderObject() as RenderBox?;
    final anchor = box == null || !box.hasSize
        ? Offset.zero
        : box.localToGlobal(box.size.center(Offset.zero));
    callback(anchor);
  }

  Future<void> _toggleTask() async {
    final action = entry.action as DaybookTaskAction;
    final task = schedule.tasks
        .where((item) => item.taskId == action.taskId)
        .firstOrNull;
    if (task != null) await actions.onToggleTask(task, !entry.completed);
  }

  Future<void> _toggleWork() async {
    final action = entry.action as AcademicWorkAction;
    final item = schedule.workItems
        .where((candidate) => candidate.workId == action.workId)
        .firstOrNull;
    if (item != null) await actions.onToggleWork(item);
  }

  Future<void> _toggleStudyBlock() async {
    final action = entry.action as AcademicStudyAction;
    final block = schedule.studyBlocks
        .where((candidate) => candidate.studyBlockId == action.studyBlockId)
        .firstOrNull;
    if (block != null) await actions.onToggleStudyBlock(block);
  }

  void _completeQuestPlan(Offset anchor) {
    final action = entry.action as QuestPlanAction;
    actions.onCompleteQuestPlan?.call(action.questTitle, anchor);
  }

  // ── the "..." menu ────────────────────────────────────────────────────

  PlansMenuKind? _menuKind() => switch (entry.action) {
    AcademicOccurrenceAction() => PlansMenuKind.classCard,
    DaybookEventAction() => PlansMenuKind.event,
    DaybookTaskAction() => PlansMenuKind.task,
    _ => null,
  };

  Key _menuKey(PlansMenuKind kind) => switch (kind) {
    PlansMenuKind.classCard => ValueKey('academic-card-menu-${entry.sourceId}'),
    PlansMenuKind.event => ValueKey('daybook-event-actions-${entry.sourceId}'),
    PlansMenuKind.task => ValueKey('daybook-task-actions-${entry.sourceId}'),
  };

  Widget _more(BuildContext context, PlansMenuKind kind) {
    return Semantics(
      button: true,
      label: kind == PlansMenuKind.classCard
          ? 'Actions for ${entry.title} class'
          : 'Actions for ${entry.title}',
      excludeSemantics: true,
      onTap: () => _openMenu(context, kind),
      child: GestureDetector(
        key: _menuKey(kind),
        behavior: HitTestBehavior.opaque,
        onTap: () => _openMenu(context, kind),
        child: Center(
          child: Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0x57FAE8CA), width: 0.75),
            ),
            child: const Icon(
              Icons.more_horiz_rounded,
              size: 16,
              color: Color(0xFFE1D2BF),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openMenu(BuildContext context, PlansMenuKind kind) async {
    Sfx.instance.playInteraction(InteractionSound.open);
    switch (kind) {
      case PlansMenuKind.event || PlansMenuKind.task:
        await actions.onOpenDaybookActions(entry.action);
      case PlansMenuKind.classCard:
        final occurrence = _occurrence;
        if (occurrence == null) return;
        final course = schedule.courseById(occurrence.courseId);
        final command = await showPlansClassMenu(
          context,
          title: course?.title ?? entry.title,
          subtitle: entry.sourceLabel,
          occurrenceKey: entry.sourceId,
          adjustable: entry.adjustable,
        );
        switch (command) {
          case PlansClassCommand.notes:
            await actions.onOpenNotebook(occurrence);
          case PlansClassCommand.adjust:
            await actions.onOpenOccurrenceAdjuster(occurrence);
          case null:
            break;
        }
    }
  }

  // ── what sits on the card ─────────────────────────────────────────────

  Widget? _footer() {
    final occurrence = _occurrence;
    final parts = <Widget>[];
    if (entry.action is AcademicOccurrenceAction &&
        entry.transitionPressure &&
        occurrence != null) {
      parts.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TIGHT TURNAROUND',
              key: ValueKey('academic-transition-${entry.sourceId}'),
              style: _mono(PlansInk.ringDone, letterSpacing: 0.8),
            ),
            const SizedBox(height: 6),
            TransitionBufferButton(
              occurrenceKey: entry.sourceId,
              courseCode: entry.title,
              transitionBufferMinutes: entry.transitionBufferMinutes ?? 10,
              onSetTransitionBuffer: (minutes) =>
                  actions.onUpdateTransitionBuffer(occurrence, minutes),
            ),
          ],
        ),
      );
    }
    if (entry.action is AcademicWorkAction && !entry.completed) {
      parts.add(
        ProjectedStudyPlanAction(
          workId: entry.sourceId,
          title: entry.title,
          plannedMinutes: entry.plannedStudyMinutes,
          targetMinutes: entry.targetStudyMinutes,
          onTap: _openStudyPlanner,
        ),
      );
    }
    final place = entry.place;
    if (place != null &&
        (place.hasGoogleDestination || place.hasAppleDestination)) {
      parts.add(
        DaybookDirectionsAction(
          place: place,
          launcher: actions.directionsLauncher,
          preferences: actions.daybookPreferences,
        ),
      );
    }
    if (parts.isEmpty) return null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < parts.length; i++) ...[
          if (i > 0) const SizedBox(height: 6),
          parts[i],
        ],
      ],
    );
  }

  Future<void> _openStudyPlanner() async {
    final action = entry.action as AcademicWorkAction;
    final item = schedule.workItems
        .where((candidate) => candidate.workId == action.workId)
        .firstOrNull;
    if (item != null) await actions.onOpenStudyPlanner(item);
  }
}

/// A card's title, two lines at most at any text size.
///
/// A long course name is set whole when it can be: at the system's usual text
/// size it steps down a point or two (never below 14.5) to fit two lines before
/// it gives up a word, so "Computer Architecture & Assembly Language" is not
/// cut to "Computer Architecture & Ass…". When it still does not fit, and at
/// large text, it ends in an ellipsis. The full name stays in the card's spoken
/// label and in its "..." menu, which names the class in full.
class PlansCardTitle extends StatelessWidget {
  const PlansCardTitle({super.key, required this.title, required this.dim});

  final String title;
  final bool dim;

  static const _sizes = [16.5, 15.5, 14.5];

  TextStyle _style(double size) => TextStyle(
    fontFamily: PlansInk.serif,
    fontWeight: FontWeight.w500,
    fontSize: size,
    height: 1.12,
    color: dim ? PlansInk.creamDim : PlansInk.cream,
    decoration: dim ? TextDecoration.lineThrough : null,
    decorationColor: PlansInk.creamDim,
    shadows: const [
      Shadow(color: Color(0x990A0502), blurRadius: 1.5, offset: Offset(0, 0.5)),
    ],
  );

  bool _fits(
    TextStyle inherited,
    double size,
    double width,
    TextScaler scaler,
  ) {
    // Measured the way Text will set it, with what it inherits (the theme's
    // letter spacing, say), so the measure and the words agree.
    final painter = TextPainter(
      text: TextSpan(text: title, style: inherited.merge(_style(size))),
      maxLines: 2,
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout(maxWidth: width);
    final fits = !painter.didExceedMaxLines;
    painter.dispose();
    return fits;
  }

  @override
  Widget build(BuildContext context) {
    // At large text the words keep the size the person chose.
    final steps = plansTextScale(context) <= 1.15 ? _sizes : [_sizes.first];
    return LayoutBuilder(
      builder: (context, box) {
        final scaler = MediaQuery.textScalerOf(context);
        final inherited = DefaultTextStyle.of(context).style;
        var size = steps.first;
        if (box.maxWidth.isFinite) {
          for (final candidate in steps) {
            size = candidate;
            if (_fits(inherited, candidate, box.maxWidth, scaler)) break;
          }
        }
        return Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: _style(size),
        );
      },
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      Text(label, style: PlansEntryCard._mono(color, letterSpacing: 0.9));
}

/// NOTES under the ring of the class that is in session or next: one tap into
/// its notebook.
class _NotesMini extends StatelessWidget {
  const _NotesMini({super.key, required this.title, required this.onTap});

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Open $title notebook',
    excludeSemantics: true,
    onTap: onTap,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.edit_note_rounded,
              size: 20,
              color: PlansInk.ringDone,
            ),
            Text(
              'NOTES',
              maxLines: 1,
              textScaler: TextScaler.noScaling,
              style: PlansEntryCard._mono(
                PlansInk.ringDone,
                letterSpacing: 0,
              ).copyWith(fontSize: Type.minLabel, height: 1),
            ),
          ],
        ),
      ),
    ),
  );
}
