import 'package:flutter/material.dart';

import '../../tokens.dart';
import '../../widgets/facets.dart';
import '../domain/daybook_event.dart';
import '../domain/daybook_place.dart';
import '../domain/daybook_task.dart';

class DaybookEventRow extends StatelessWidget {
  const DaybookEventRow({
    super.key,
    required this.event,
    this.occurrence,
    this.onTap,
  });

  final DaybookEvent event;
  final DaybookEventOccurrence? occurrence;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final activeOccurrence = occurrence;
    final allDay = activeOccurrence?.allDay ?? event.allDay;
    final startMinute = activeOccurrence?.startMinute ?? event.startMinute;
    final endMinute = activeOccurrence?.endMinute ?? event.endMinute;
    final cancelled =
        activeOccurrence?.state == DaybookEventOccurrenceState.cancelled;
    final timing = allDay
        ? 'ALL DAY'
        : '${_formatMinute(startMinute!)}–${_formatMinute(endMinute!)}';
    final detail = [
      if (event.weeklyRule != null) 'WEEKLY',
      timing,
      if (cancelled) 'CANCELLED',
    ].join(' · ');

    return _DaybookRowSurface(
      semanticLabel: '${event.title}, $detail${_placeSuffix(event.place)}',
      onTap: onTap,
      leading: const Icon(
        Icons.event_outlined,
        size: 20,
        color: Palette.xpLight,
      ),
      title: event.title,
      metadata: detail,
      place: event.place,
      cancelled: cancelled,
    );
  }
}

class DaybookTaskRow extends StatelessWidget {
  const DaybookTaskRow({
    super.key,
    required this.task,
    this.onCompletedChanged,
    this.onTap,
  });

  final DaybookTask task;
  final ValueChanged<bool>? onCompletedChanged;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final due = task.dueMinute == null
        ? 'DUE'
        : 'DUE ${_formatMinute(task.dueMinute!)}';
    return _DaybookRowSurface(
      semanticLabel: '${task.title}, $due${_placeSuffix(task.place)}',
      onTap: onTap,
      leading: SizedBox(
        key: ValueKey('daybook-task-toggle-${task.taskId}'),
        width: 44,
        height: 44,
        child: Semantics(
          button: true,
          checked: task.completed,
          label: task.completed
              ? 'Mark ${task.title} open'
              : 'Mark ${task.title} complete',
          child: InkWell(
            onTap: onCompletedChanged == null
                ? null
                : () => onCompletedChanged!(!task.completed),
            customBorder: const CircleBorder(),
            child: Center(
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: task.completed
                      ? Palette.xp.withValues(alpha: 0.13)
                      : Palette.glassFill,
                  border: Border.all(
                    color: task.completed
                        ? Palette.xpLight.withValues(alpha: 0.62)
                        : Palette.brass.withValues(alpha: 0.52),
                  ),
                ),
                child: task.completed
                    ? const Icon(
                        Icons.check_rounded,
                        size: 19,
                        color: Palette.xpLight,
                      )
                    : null,
              ),
            ),
          ),
        ),
      ),
      title: task.title,
      metadata: due,
      place: task.place,
      completed: task.completed,
    );
  }
}

class _DaybookRowSurface extends StatelessWidget {
  const _DaybookRowSurface({
    required this.semanticLabel,
    required this.leading,
    required this.title,
    required this.metadata,
    required this.place,
    this.onTap,
    this.completed = false,
    this.cancelled = false,
  });

  final String semanticLabel;
  final Widget leading;
  final String title;
  final String metadata;
  final DaybookPlace? place;
  final VoidCallback? onTap;
  final bool completed;
  final bool cancelled;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    button: onTap != null,
    label: semanticLabel,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: Opacity(
        opacity: cancelled
            ? 0.58
            : completed
            ? 0.72
            : 1,
        child: Container(
          constraints: const BoxConstraints(minHeight: 62),
          padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
          decoration: facetedDecoration(
            cut: 9,
            color: Palette.glassFill,
            borderColor: Palette.brass.withValues(alpha: 0.36),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              leading,
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Type.display.copyWith(
                        fontSize: 15,
                        color: Palette.textHi,
                        decoration: completed
                            ? TextDecoration.lineThrough
                            : null,
                        decorationColor: Palette.textLo,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      metadata,
                      style: Type.label.copyWith(
                        fontSize: Type.minLabel,
                        letterSpacing: 0.8,
                        color: Palette.xpLight,
                      ),
                    ),
                    if (place != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        place!.savedName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Type.body.copyWith(
                          fontSize: 11.5,
                          color: Palette.textLo,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 7),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: Palette.textLo,
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

String _placeSuffix(DaybookPlace? place) =>
    place == null ? '' : ', ${place.savedName}';

String _formatMinute(int minute) {
  final hour24 = minute ~/ 60;
  final hour = hour24 % 12 == 0 ? 12 : hour24 % 12;
  final minutes = (minute % 60).toString().padLeft(2, '0');
  return '$hour:$minutes ${hour24 < 12 ? 'AM' : 'PM'}';
}
