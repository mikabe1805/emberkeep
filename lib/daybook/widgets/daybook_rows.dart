import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../tokens.dart';
import '../../widgets/facets.dart';
import '../data/daybook_preferences.dart';
import '../domain/daybook_event.dart';
import '../domain/daybook_place.dart';
import '../domain/daybook_task.dart';
import '../services/directions_launcher.dart';

class DaybookRowActionsButton extends StatelessWidget {
  const DaybookRowActionsButton({
    super.key,
    required this.title,
    required this.onTap,
  });

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Actions for $title',
    child: InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: const SizedBox.square(
        dimension: 44,
        child: Icon(Icons.more_horiz_rounded, size: 22, color: Palette.xpLight),
      ),
    ),
  );
}

class DaybookDirectionsAction extends StatefulWidget {
  const DaybookDirectionsAction({
    super.key,
    required this.place,
    required this.launcher,
    required this.preferences,
  });

  final DaybookPlace place;
  final DirectionsLauncher launcher;
  final DaybookPreferences preferences;

  @override
  State<DaybookDirectionsAction> createState() =>
      _DaybookDirectionsActionState();
}

class _DaybookDirectionsActionState extends State<DaybookDirectionsAction> {
  MapProvider? _preferredProvider;

  bool get _hasDestination =>
      widget.place.hasGoogleDestination || widget.place.hasAppleDestination;

  bool get _hasBothDestinations =>
      widget.place.hasGoogleDestination && widget.place.hasAppleDestination;

  @override
  void initState() {
    super.initState();
    unawaited(_loadPreference());
  }

  Future<void> _loadPreference() async {
    final provider = await widget.preferences.loadPreferredMapProvider();
    if (!mounted) return;
    setState(() => _preferredProvider = provider);
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasDestination) return const SizedBox.shrink();
    final isIos = Theme.of(context).platform == TargetPlatform.iOS;
    final canChangeProvider =
        isIos && _hasBothDestinations && _preferredProvider != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _DirectionsInlineAction(
          key: ValueKey('daybook-directions-${widget.place.savedName}'),
          semanticLabel: 'Get directions to ${widget.place.savedName}',
          label: 'GET DIRECTIONS',
          icon: Icons.directions_outlined,
          onTap: () => _openDirections(isIos: isIos),
        ),
        if (canChangeProvider) ...[
          const SizedBox(height: 1),
          _DirectionsInlineAction(
            key: ValueKey('daybook-change-map-app-${widget.place.savedName}'),
            semanticLabel: 'Change map app for ${widget.place.savedName}',
            label: 'CHANGE MAP APP',
            icon: Icons.swap_horiz_rounded,
            quiet: true,
            onTap: _clearPreference,
          ),
        ],
      ],
    );
  }

  Future<void> _openDirections({required bool isIos}) async {
    final latestPreference = await widget.preferences
        .loadPreferredMapProvider();
    if (!mounted) return;
    if (_preferredProvider != latestPreference) {
      setState(() => _preferredProvider = latestPreference);
    }
    if (isIos && _hasBothDestinations && latestPreference == null) {
      await _showProviderChooser();
      return;
    }
    final usablePreference =
        latestPreference != null && _providerAvailable(latestPreference)
        ? latestPreference
        : null;
    final provider = isIos && usablePreference != null
        ? usablePreference
        : widget.place.hasGoogleDestination
        ? MapProvider.google
        : MapProvider.apple;
    final opened = await widget.launcher.open(widget.place, provider);
    if (!mounted || opened) return;
    await _showCopyFallback();
  }

  bool _providerAvailable(MapProvider provider) => switch (provider) {
    MapProvider.apple => widget.place.hasAppleDestination,
    MapProvider.google => widget.place.hasGoogleDestination,
  };

  Future<void> _clearPreference() async {
    await widget.preferences.savePreferredMapProvider(null);
    if (!mounted) return;
    setState(() => _preferredProvider = null);
  }

  Future<void> _showProviderChooser() => showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Palette.dialogBarrier,
    isScrollControlled: true,
    builder: (sheetContext) {
      var launchFailed = false;
      return StatefulBuilder(
        builder: (context, setSheetState) => _DirectionsSheet(
          title: widget.place.savedName,
          message: launchFailed
              ? 'Maps couldn’t open this location. Choose another app or copy it.'
              : 'Choose the map app for this location.',
          actions: [
            _DirectionsSheetAction(
              label: 'APPLE MAPS',
              icon: Icons.map_outlined,
              onTap: () => _chooseProvider(
                sheetContext: sheetContext,
                contentContext: context,
                setSheetState: setSheetState,
                provider: MapProvider.apple,
                markFailed: () => launchFailed = true,
              ),
            ),
            _DirectionsSheetAction(
              label: 'GOOGLE MAPS',
              icon: Icons.directions_outlined,
              onTap: () => _chooseProvider(
                sheetContext: sheetContext,
                contentContext: context,
                setSheetState: setSheetState,
                provider: MapProvider.google,
                markFailed: () => launchFailed = true,
              ),
            ),
            if (launchFailed)
              _DirectionsSheetAction(
                label: 'COPY LOCATION',
                icon: Icons.copy_rounded,
                onTap: _copyLocation,
              ),
          ],
        ),
      );
    },
  );

  Future<void> _chooseProvider({
    required BuildContext sheetContext,
    required BuildContext contentContext,
    required StateSetter setSheetState,
    required MapProvider provider,
    required VoidCallback markFailed,
  }) async {
    final opened = await widget.launcher.open(widget.place, provider);
    if (!contentContext.mounted || !mounted) return;
    if (!opened) {
      setSheetState(markFailed);
      return;
    }
    await widget.preferences.savePreferredMapProvider(provider);
    if (!contentContext.mounted || !mounted) return;
    setState(() => _preferredProvider = provider);
    Navigator.of(sheetContext).pop();
  }

  Future<void> _showCopyFallback() => showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Palette.dialogBarrier,
    isScrollControlled: true,
    builder: (_) => _DirectionsSheet(
      title: widget.place.savedName,
      message: 'Maps couldn’t open this location. Copy it instead.',
      actions: [
        _DirectionsSheetAction(
          label: 'COPY LOCATION',
          icon: Icons.copy_rounded,
          onTap: _copyLocation,
        ),
      ],
    ),
  );

  Future<void> _copyLocation() => Clipboard.setData(
    ClipboardData(text: widget.place.routingText ?? widget.place.savedName),
  );
}

class _DirectionsInlineAction extends StatelessWidget {
  const _DirectionsInlineAction({
    super.key,
    required this.semanticLabel,
    required this.label,
    required this.icon,
    required this.onTap,
    this.quiet = false,
  });

  final String semanticLabel;
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool quiet;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: semanticLabel,
    excludeSemantics: true,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 76, minHeight: 44),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 17,
                color: quiet ? Palette.textMid : Palette.xpLight,
              ),
              Text(
                label,
                textAlign: TextAlign.center,
                style: Type.label.copyWith(
                  fontSize: Type.minLabel,
                  height: 1.05,
                  color: quiet ? Palette.textLo : Palette.xpLight,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _DirectionsSheet extends StatelessWidget {
  const _DirectionsSheet({
    required this.title,
    required this.message,
    required this.actions,
  });

  final String title;
  final String message;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
        decoration: facetedDecoration(
          cut: 13,
          color: Palette.card,
          borderColor: Palette.brass.withValues(alpha: 0.64),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Type.display.copyWith(fontSize: 18, color: Palette.textHi),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              style: Type.body.copyWith(fontSize: 13, color: Palette.textMid),
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: actions),
          ],
        ),
      ),
    ),
  );
}

class _DirectionsSheetAction extends StatelessWidget {
  const _DirectionsSheetAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: facetedDecoration(
          cut: 7,
          color: Palette.glassFill,
          borderColor: Palette.brass.withValues(alpha: 0.48),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: Palette.xpLight),
            const SizedBox(width: 7),
            Text(
              label,
              style: Type.label.copyWith(
                fontSize: Type.minLabel,
                color: Palette.xpLight,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

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
    final completionMark = Center(
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
            ? const Icon(Icons.check_rounded, size: 19, color: Palette.xpLight)
            : null,
      ),
    );
    return _DaybookRowSurface(
      semanticLabel: '${task.title}, $due${_placeSuffix(task.place)}',
      onTap: onTap,
      leading: SizedBox(
        key: ValueKey('daybook-task-toggle-${task.taskId}'),
        width: 44,
        height: 44,
        child: onCompletedChanged == null
            ? ExcludeSemantics(child: completionMark)
            : Semantics(
                button: true,
                checked: task.completed,
                label: task.completed
                    ? 'Mark ${task.title} open'
                    : 'Mark ${task.title} complete',
                child: InkWell(
                  onTap: () => onCompletedChanged!(!task.completed),
                  customBorder: const CircleBorder(),
                  child: completionMark,
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
