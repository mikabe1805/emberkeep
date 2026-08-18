import 'package:flutter/material.dart';

import '../../tokens.dart';
import '../domain/daybook_place.dart';

final class DaybookPlaceFieldsController {
  DaybookPlaceFieldsController({DaybookPlace? initialPlace})
    : savedName = initialPlace?.savedName ?? '',
      routingText = initialPlace?.routingText ?? '',
      building = initialPlace?.building ?? '',
      room = initialPlace?.room ?? '',
      provider = initialPlace?.provider,
      providerPlaceId = initialPlace?.providerPlaceId;

  String savedName;
  String routingText;
  String building;
  String room;
  DaybookPlaceProvider? provider;
  String? providerPlaceId;

  bool get isEmpty =>
      savedName.trim().isEmpty &&
      routingText.trim().isEmpty &&
      building.trim().isEmpty &&
      room.trim().isEmpty;

  bool get needsSavedName => !isEmpty && savedName.trim().isEmpty;

  DaybookPlace? toPlace({String? fallbackSavedName}) {
    if (isEmpty) return null;
    final cleanFallback = fallbackSavedName?.trim();
    final name = savedName.trim().isNotEmpty
        ? savedName.trim()
        : cleanFallback == null || cleanFallback.isEmpty
        ? null
        : cleanFallback;
    if (name == null) return null;
    return DaybookPlace(
      savedName: name,
      routingText: routingText,
      building: building,
      room: room,
      provider: provider,
      providerPlaceId: providerPlaceId,
    );
  }
}

class DaybookPlaceFields extends StatefulWidget {
  const DaybookPlaceFields({
    super.key,
    required this.controller,
    this.keyPrefix = 'daybook-place',
    this.savedNameKey,
    this.routingTextKey,
    this.buildingKey,
    this.roomKey,
  });

  final DaybookPlaceFieldsController controller;
  final String keyPrefix;
  final Key? savedNameKey;
  final Key? routingTextKey;
  final Key? buildingKey;
  final Key? roomKey;

  @override
  State<DaybookPlaceFields> createState() => _DaybookPlaceFieldsState();
}

class _DaybookPlaceFieldsState extends State<DaybookPlaceFields> {
  late final TextEditingController _savedName;
  late final TextEditingController _routingText;
  late final TextEditingController _building;
  late final TextEditingController _room;

  @override
  void initState() {
    super.initState();
    _savedName = TextEditingController(text: widget.controller.savedName);
    _routingText = TextEditingController(text: widget.controller.routingText);
    _building = TextEditingController(text: widget.controller.building);
    _room = TextEditingController(text: widget.controller.room);
  }

  @override
  void didUpdateWidget(DaybookPlaceFields oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    _savedName.text = widget.controller.savedName;
    _routingText.text = widget.controller.routingText;
    _building.text = widget.controller.building;
    _room.text = widget.controller.room;
  }

  @override
  void dispose() {
    _savedName.dispose();
    _routingText.dispose();
    _building.dispose();
    _room.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final textScale = MediaQuery.textScalerOf(context).scale(1);
      final stackLastPair = constraints.maxWidth < 340 || textScale > 1.35;
      final buildingField = _field(
        key: widget.buildingKey ?? ValueKey('${widget.keyPrefix}-building'),
        controller: _building,
        label: 'BUILDING',
        capitalization: TextCapitalization.words,
        onChanged: (value) => widget.controller.building = value,
      );
      final roomField = _field(
        key: widget.roomKey ?? ValueKey('${widget.keyPrefix}-room'),
        controller: _room,
        label: 'ROOM',
        capitalization: TextCapitalization.characters,
        onChanged: (value) => widget.controller.room = value,
      );

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _field(
            key:
                widget.savedNameKey ??
                ValueKey('${widget.keyPrefix}-saved-name'),
            controller: _savedName,
            label: 'SAVED NAME',
            capitalization: TextCapitalization.words,
            onChanged: (value) => widget.controller.savedName = value,
          ),
          const SizedBox(height: 7),
          _field(
            key:
                widget.routingTextKey ??
                ValueKey('${widget.keyPrefix}-routing-text'),
            controller: _routingText,
            label: 'ADDRESS OR ROUTING TEXT',
            capitalization: TextCapitalization.words,
            keyboardType: TextInputType.streetAddress,
            onChanged: (value) => widget.controller.routingText = value,
          ),
          const SizedBox(height: 7),
          if (stackLastPair) ...[
            buildingField,
            const SizedBox(height: 7),
            roomField,
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: buildingField),
                const SizedBox(width: 7),
                Expanded(flex: 2, child: roomField),
              ],
            ),
        ],
      );
    },
  );

  Widget _field({
    required Key key,
    required TextEditingController controller,
    required String label,
    required TextCapitalization capitalization,
    TextInputType? keyboardType,
    required ValueChanged<String> onChanged,
  }) => TextField(
    key: key,
    controller: controller,
    textCapitalization: capitalization,
    keyboardType: keyboardType,
    onChanged: onChanged,
    style: Type.body.copyWith(fontSize: 14, color: Palette.textHi),
    decoration: _fieldDecoration(label),
  );
}

InputDecoration _fieldDecoration(String label) => InputDecoration(
  labelText: label,
  labelStyle: Type.label.copyWith(
    fontSize: Type.minLabel,
    letterSpacing: 0.7,
    color: Palette.textLo,
  ),
  floatingLabelStyle: Type.label.copyWith(
    fontSize: Type.minLabel,
    letterSpacing: 0.7,
    color: Palette.xpLight,
  ),
  isDense: true,
  filled: true,
  fillColor: Palette.glassFill,
  contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 12),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: const BorderSide(color: Palette.glassEdge),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: const BorderSide(color: Palette.glassEdge),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(color: Palette.xpLight.withValues(alpha: 0.72)),
  ),
);
