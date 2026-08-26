import 'package:flutter/material.dart';

import '../../audio.dart';
import '../../tokens.dart';
import '../../widgets/facets.dart';
import '../../widgets/glass.dart';

enum DaybookAddTarget { event, task, classMeeting, assignment, exam }

class DaybookAddChoiceDialog extends StatelessWidget {
  const DaybookAddChoiceDialog({super.key});

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    insetPadding: const EdgeInsets.all(16),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: GlassPanel(
        tint: Palette.dialogSurface,
        padding: const EdgeInsets.fromLTRB(18, 15, 18, 18),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'ADD TO YOUR DAYBOOK',
                      style: Type.label.copyWith(
                        fontSize: 12,
                        color: Palette.xpLight,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () {
                      Sfx.instance.playMaterial(MaterialSound.glass);
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Palette.textLo,
                    ),
                  ),
                ],
              ),
              Text(
                'Keep events, tasks, and school together.',
                style: Type.body.copyWith(fontSize: 13, color: Palette.textMid),
              ),
              const SizedBox(height: 12),
              _DaybookAddChoice(
                key: const ValueKey('daybook-add-choice-event'),
                icon: Icons.event_outlined,
                title: 'EVENT',
                subtitle: 'Something happening at a time or across a day',
                onTap: () => Navigator.of(context).pop(DaybookAddTarget.event),
              ),
              const SizedBox(height: 7),
              _DaybookAddChoice(
                key: const ValueKey('daybook-add-choice-task'),
                icon: Icons.check_circle_outline_rounded,
                title: 'TASK',
                subtitle: 'Something to finish by a date or time',
                onTap: () => Navigator.of(context).pop(DaybookAddTarget.task),
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: Divider(
                      height: 1,
                      color: Palette.brass.withValues(alpha: 0.3),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 9),
                    child: Text(
                      'SCHOOL',
                      style: Type.label.copyWith(
                        fontSize: Type.minLabel,
                        letterSpacing: 1.5,
                        color: Palette.textLo,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Divider(
                      height: 1,
                      color: Palette.brass.withValues(alpha: 0.3),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              _DaybookAddChoice(
                key: const ValueKey('academic-add-choice-class'),
                icon: Icons.calendar_view_week_outlined,
                title: 'CLASS',
                subtitle: 'A lecture, lab, meeting, or recurring class',
                onTap: () =>
                    Navigator.of(context).pop(DaybookAddTarget.classMeeting),
              ),
              const SizedBox(height: 7),
              _DaybookAddChoice(
                key: const ValueKey('academic-add-choice-assignment'),
                icon: Icons.assignment_outlined,
                title: 'ASSIGNMENT',
                subtitle: 'Course work with a due date and time',
                onTap: () =>
                    Navigator.of(context).pop(DaybookAddTarget.assignment),
              ),
              const SizedBox(height: 7),
              _DaybookAddChoice(
                key: const ValueKey('academic-add-choice-exam'),
                icon: Icons.quiz_outlined,
                title: 'EXAM',
                subtitle: 'A test, midterm, or final on your calendar',
                onTap: () => Navigator.of(context).pop(DaybookAddTarget.exam),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _DaybookAddChoice extends StatelessWidget {
  const _DaybookAddChoice({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '$title, $subtitle',
    child: InkWell(
      onTap: () {
        onTap();
        Sfx.instance.playInteraction(InteractionSound.select);
      },
      borderRadius: BorderRadius.circular(11),
      child: Container(
        constraints: const BoxConstraints(minHeight: 58),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: facetedDecoration(
          cut: 9,
          color: Palette.xp.withValues(alpha: 0.07),
          borderColor: Palette.brass.withValues(alpha: 0.42),
        ),
        child: Row(
          children: [
            Icon(icon, size: 21, color: Palette.xpLight),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Type.label.copyWith(
                      fontSize: Type.minLabel,
                      letterSpacing: 1.1,
                      color: Palette.textHi,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Type.body.copyWith(
                      fontSize: 12.5,
                      color: Palette.textMid,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: Palette.textLo,
            ),
          ],
        ),
      ),
    ),
  );
}
