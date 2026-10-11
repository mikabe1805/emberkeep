// The "..." on a class card: a small sheet with what you can do with this
// class. (An event or a task keeps its own actions: edit, cancel, delete.)
library;

import 'package:flutter/material.dart';

import '../../../tokens.dart';

enum PlansMenuKind { classCard, event, task }

enum PlansClassCommand { notes, adjust }

/// Shows the class menu. Returns what was chosen, or null when it was closed.
Future<PlansClassCommand?> showPlansClassMenu(
  BuildContext context, {
  required String title,
  required String occurrenceKey,
  required bool adjustable,
  String? subtitle,
}) {
  return showModalBottomSheet<PlansClassCommand>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Palette.dialogBarrier,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheet) => _ClassMenu(
      title: title,
      subtitle: subtitle,
      occurrenceKey: occurrenceKey,
      adjustable: adjustable,
    ),
  );
}

class _ClassMenu extends StatelessWidget {
  const _ClassMenu({
    required this.title,
    required this.subtitle,
    required this.occurrenceKey,
    required this.adjustable,
  });

  final String title;
  final String? subtitle;
  final String occurrenceKey;
  final bool adjustable;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: Palette.dialogSurface,
            border: Border.all(color: Palette.glassEdge),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (subtitle != null)
                            Text(
                              subtitle!,
                              style: Type.label.copyWith(
                                fontSize: Type.minLabel,
                                letterSpacing: 1.2,
                                color: Palette.xpLight,
                              ),
                            ),
                          const SizedBox(height: 3),
                          Text(
                            title,
                            style: Type.body.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Palette.textHi,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Palette.textLo,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _MenuRow(
                  key: ValueKey('open-notebook-$occurrenceKey'),
                  icon: Icons.edit_note_rounded,
                  label: 'NOTES',
                  hint: 'Open this class in your notebook',
                  semantic: 'Open $title notebook',
                  onTap: () =>
                      Navigator.of(context).pop(PlansClassCommand.notes),
                ),
                if (adjustable) ...[
                  const SizedBox(height: 7),
                  _MenuRow(
                    key: ValueKey('academic-adjust-occurrence-$occurrenceKey'),
                    icon: Icons.event_repeat_rounded,
                    label: 'MOVE / CANCEL THIS CLASS',
                    hint: 'Only this meeting. The rest of the term stays.',
                    semantic: 'Move or cancel this $title class only',
                    onTap: () =>
                        Navigator.of(context).pop(PlansClassCommand.adjust),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    super.key,
    required this.icon,
    required this.label,
    required this.hint,
    required this.semantic,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String hint;
  final String semantic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: semantic,
    excludeSemantics: true,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(11),
          color: Palette.xp.withValues(alpha: 0.07),
          border: Border.all(color: Palette.brass.withValues(alpha: 0.42)),
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
                    label,
                    style: Type.label.copyWith(
                      fontSize: Type.minLabel,
                      letterSpacing: 1.1,
                      color: Palette.textHi,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hint,
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
              size: 19,
              color: Palette.textLo,
            ),
          ],
        ),
      ),
    ),
  );
}
