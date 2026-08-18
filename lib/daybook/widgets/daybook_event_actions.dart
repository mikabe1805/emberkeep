import 'package:flutter/material.dart';

import '../../tokens.dart';
import '../../widgets/facets.dart';
import '../../widgets/glass.dart';

enum DaybookEventScope { thisEvent, entireSeries }

enum DaybookEventCommand { edit, delete, cancel, restore }

enum DaybookTaskCommand { edit, delete }

class DaybookEventScopeDialog extends StatelessWidget {
  const DaybookEventScopeDialog({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => _ActionDialogFrame(
    heading: 'CHANGE WEEKLY EVENT',
    supporting: title,
    children: [
      _ActionTile(
        key: const ValueKey('daybook-scope-this-event'),
        label: 'THIS EVENT',
        supporting: 'Change only this occurrence.',
        icon: Icons.today_outlined,
        onTap: () => Navigator.of(context).pop(DaybookEventScope.thisEvent),
      ),
      const SizedBox(height: 7),
      _ActionTile(
        key: const ValueKey('daybook-scope-entire-series'),
        label: 'ENTIRE SERIES',
        supporting: 'Change every occurrence in this weekly event.',
        icon: Icons.event_repeat_outlined,
        onTap: () => Navigator.of(context).pop(DaybookEventScope.entireSeries),
      ),
    ],
  );
}

class DaybookEventActionsDialog extends StatelessWidget {
  const DaybookEventActionsDialog({
    super.key,
    required this.title,
    required this.scope,
    this.cancelled = false,
  });

  final String title;
  final DaybookEventScope? scope;
  final bool cancelled;

  @override
  Widget build(BuildContext context) {
    final entireSeries = scope == DaybookEventScope.entireSeries;
    final oneOff = scope == null;
    return _ActionDialogFrame(
      heading: oneOff
          ? 'EVENT ACTIONS'
          : entireSeries
          ? 'SERIES ACTIONS'
          : 'THIS EVENT',
      supporting: title,
      children: [
        _ActionTile(
          key: ValueKey(
            !oneOff && !entireSeries
                ? 'daybook-event-move'
                : 'daybook-event-edit',
          ),
          label: !oneOff && !entireSeries
              ? 'MOVE EVENT'
              : entireSeries
              ? 'EDIT SERIES'
              : 'EDIT EVENT',
          supporting: entireSeries
              ? 'Change the weekly source and every generated occurrence.'
              : !oneOff
              ? 'Change only this occurrence’s date or time.'
              : 'Change its details or timing.',
          icon: Icons.edit_outlined,
          onTap: () => Navigator.of(context).pop(DaybookEventCommand.edit),
        ),
        const SizedBox(height: 7),
        if (oneOff || entireSeries)
          _ActionTile(
            key: const ValueKey('daybook-event-delete'),
            label: entireSeries ? 'DELETE SERIES' : 'DELETE EVENT',
            supporting: entireSeries
                ? 'Remove the weekly event and its occurrences.'
                : 'Remove this event from your Daybook.',
            icon: Icons.delete_outline_rounded,
            danger: true,
            onTap: () => Navigator.of(context).pop(DaybookEventCommand.delete),
          )
        else
          _ActionTile(
            key: ValueKey(
              cancelled ? 'daybook-event-restore' : 'daybook-event-cancel',
            ),
            label: cancelled ? 'RESTORE EVENT' : 'CANCEL EVENT',
            supporting: cancelled
                ? 'Remove the override and return this occurrence.'
                : 'Keep the series and mark only this occurrence cancelled.',
            icon: cancelled ? Icons.restore_rounded : Icons.event_busy_outlined,
            danger: !cancelled,
            onTap: () => Navigator.of(context).pop(
              cancelled
                  ? DaybookEventCommand.restore
                  : DaybookEventCommand.cancel,
            ),
          ),
      ],
    );
  }
}

class DaybookTaskActionsDialog extends StatelessWidget {
  const DaybookTaskActionsDialog({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => _ActionDialogFrame(
    heading: 'TASK ACTIONS',
    supporting: title,
    children: [
      _ActionTile(
        key: const ValueKey('daybook-task-edit'),
        label: 'EDIT TASK',
        supporting: 'Change its details or due date.',
        icon: Icons.edit_outlined,
        onTap: () => Navigator.of(context).pop(DaybookTaskCommand.edit),
      ),
      const SizedBox(height: 7),
      _ActionTile(
        key: const ValueKey('daybook-task-delete'),
        label: 'DELETE TASK',
        supporting: 'Remove this task from your Daybook.',
        icon: Icons.delete_outline_rounded,
        danger: true,
        onTap: () => Navigator.of(context).pop(DaybookTaskCommand.delete),
      ),
    ],
  );
}

class DaybookMutationDialog extends StatefulWidget {
  const DaybookMutationDialog({
    super.key,
    required this.heading,
    required this.message,
    required this.confirmLabel,
    required this.confirmKey,
    required this.errorMessage,
    required this.onConfirm,
    this.danger = true,
  });

  final String heading;
  final String message;
  final String confirmLabel;
  final Key confirmKey;
  final String errorMessage;
  final Future<bool> Function() onConfirm;
  final bool danger;

  @override
  State<DaybookMutationDialog> createState() => _DaybookMutationDialogState();
}

class _DaybookMutationDialogState extends State<DaybookMutationDialog> {
  bool _saving = false;
  String? _error;

  Future<void> _confirm() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    var saved = false;
    try {
      saved = await widget.onConfirm();
    } catch (_) {
      saved = false;
    }
    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _saving = false;
      _error = widget.errorMessage;
    });
  }

  @override
  Widget build(BuildContext context) => _ActionDialogFrame(
    heading: widget.heading,
    supporting: widget.message,
    children: [
      if (_error != null) ...[
        Text(
          _error!,
          key: const ValueKey('daybook-mutation-error'),
          style: Type.body.copyWith(fontSize: 12.5, color: Palette.danger),
        ),
        const SizedBox(height: 9),
      ],
      Row(
        children: [
          Expanded(
            child: _ActionTile(
              label: 'KEEP IT',
              supporting: 'Return without changing anything.',
              icon: Icons.arrow_back_rounded,
              onTap: _saving ? null : () => Navigator.of(context).pop(false),
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: _ActionTile(
              key: widget.confirmKey,
              label: _saving ? 'SAVING…' : widget.confirmLabel,
              supporting: _saving ? 'Keeping this change locally.' : null,
              icon: widget.danger
                  ? Icons.delete_outline_rounded
                  : Icons.restore_rounded,
              danger: widget.danger,
              onTap: _saving ? null : _confirm,
            ),
          ),
        ],
      ),
    ],
  );
}

class _ActionDialogFrame extends StatelessWidget {
  const _ActionDialogFrame({
    required this.heading,
    required this.supporting,
    required this.children,
  });

  final String heading;
  final String supporting;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    insetPadding: const EdgeInsets.all(16),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
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
                      heading,
                      style: Type.label.copyWith(
                        fontSize: 12,
                        color: Palette.xpLight,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Palette.textLo,
                    ),
                  ),
                ],
              ),
              Text(
                supporting,
                style: Type.body.copyWith(fontSize: 13, color: Palette.textMid),
              ),
              const SizedBox(height: 12),
              ...children,
            ],
          ),
        ),
      ),
    ),
  );
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    super.key,
    required this.label,
    this.supporting,
    required this.icon,
    required this.onTap,
    this.danger = false,
  });

  final String label;
  final String? supporting;
  final IconData icon;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onTap != null,
    label: label.toLowerCase(),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: facetedDecoration(
          cut: 8,
          color: danger
              ? Palette.danger.withValues(alpha: 0.045)
              : Palette.glassFill,
          borderColor: danger
              ? Palette.danger.withValues(alpha: 0.42)
              : Palette.glassEdge,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 19,
              color: danger ? Palette.danger : Palette.xpLight,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    maxLines: 2,
                    style: Type.label.copyWith(
                      fontSize: Type.minLabel,
                      color: danger ? Palette.danger : Palette.textHi,
                    ),
                  ),
                  if (supporting != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      supporting!,
                      maxLines: 3,
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
          ],
        ),
      ),
    ),
  );
}
