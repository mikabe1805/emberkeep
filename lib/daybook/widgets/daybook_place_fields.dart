import 'package:flutter/material.dart';

import '../../audio.dart';
import '../../release_features.dart';
import '../../tokens.dart';
import '../domain/daybook_place.dart';
import '../services/firebase_place_search_service.dart';
import '../services/place_search_access.dart';
import '../services/place_search_authorization.dart';
import '../services/place_search_controller.dart';
import '../services/place_search_service.dart' hide PlaceSearchUnavailable;
import 'place_search_consent_dialog.dart';

abstract interface class DaybookPlaceSearchFactory {
  bool get enabled;

  PlaceSearchAccess createAccess({
    required PlaceSearchConsentRequest requestConsent,
  });

  PlaceSearchController createController({
    required String installId,
    required String locale,
    required PlaceSearchAuthorizationLease authorization,
  });
}

/// Keeps Firebase, App Check, auth, and callable construction behind the
/// explicit place-search affordance. A default build exposes only manual entry.
final class ProductionDaybookPlaceSearchFactory
    implements DaybookPlaceSearchFactory {
  const ProductionDaybookPlaceSearchFactory();

  @override
  bool get enabled => kPlaceSearchEnabled;

  @override
  PlaceSearchAccess createAccess({
    required PlaceSearchConsentRequest requestConsent,
  }) => PlaceSearchAccess.production(requestConsent: requestConsent);

  @override
  PlaceSearchController createController({
    required String installId,
    required String locale,
    required PlaceSearchAuthorizationLease authorization,
  }) => PlaceSearchController(
    service: kPlaceSearchEnabled
        ? AuthorizedPlaceSearchService(
            delegate: FirebasePlaceSearchService(),
            authorization: authorization,
          )
        : const DisabledPlaceSearchService(),
    installId: installId,
    locale: locale,
    authorization: authorization,
  );
}

final class DaybookPlaceFieldsController {
  DaybookPlaceFieldsController({DaybookPlace? initialPlace})
    : savedName = initialPlace?.savedName ?? '',
      routingText = initialPlace?.routingText ?? '',
      building = initialPlace?.building ?? '',
      room = initialPlace?.room ?? '',
      provider = initialPlace?.provider,
      providerPlaceId = initialPlace?.providerPlaceId,
      destinationIntent = DaybookPlaceDestinationIntent.preserve;

  String savedName;
  String routingText;
  String building;
  String room;
  DaybookPlaceProvider? provider;
  String? providerPlaceId;
  DaybookPlaceDestinationIntent destinationIntent;

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
        ? savedName
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

  void useGoogleSelection(PlaceSelection selection) {
    if (selection.provider != DaybookPlaceProvider.google.name) {
      throw ArgumentError.value(
        selection.provider,
        'selection.provider',
        'Unsupported place provider',
      );
    }
    savedName = selection.originalQuery;
    provider = DaybookPlaceProvider.google;
    providerPlaceId = selection.placeId;
    destinationIntent = DaybookPlaceDestinationIntent.googleSelection;
  }

  void useManualReplacement() {
    provider = null;
    providerPlaceId = null;
    destinationIntent = DaybookPlaceDestinationIntent.manualReplacement;
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
    this.placeSearchFactory = const ProductionDaybookPlaceSearchFactory(),
  });

  final DaybookPlaceFieldsController controller;
  final String keyPrefix;
  final Key? savedNameKey;
  final Key? routingTextKey;
  final Key? buildingKey;
  final Key? roomKey;
  final DaybookPlaceSearchFactory placeSearchFactory;

  @override
  State<DaybookPlaceFields> createState() => _DaybookPlaceFieldsState();
}

class _DaybookPlaceFieldsState extends State<DaybookPlaceFields> {
  late final TextEditingController _savedName;
  late final TextEditingController _routingText;
  late final TextEditingController _building;
  late final TextEditingController _room;
  late final TextEditingController _searchQuery;
  PlaceSearchAccess? _searchAccess;
  PlaceSearchController? _searchController;
  bool _accessInFlight = false;
  bool _searchActive = false;
  String? _accessErrorMessage;
  int _accessGeneration = 0;

  @override
  void initState() {
    super.initState();
    _savedName = TextEditingController(text: widget.controller.savedName);
    _routingText = TextEditingController(text: widget.controller.routingText);
    _building = TextEditingController(text: widget.controller.building);
    _room = TextEditingController(text: widget.controller.room);
    _searchQuery = TextEditingController();
  }

  @override
  void didUpdateWidget(DaybookPlaceFields oldWidget) {
    super.didUpdateWidget(oldWidget);
    final controllerChanged = oldWidget.controller != widget.controller;
    if (controllerChanged) {
      _savedName.text = widget.controller.savedName;
      _routingText.text = widget.controller.routingText;
      _building.text = widget.controller.building;
      _room.text = widget.controller.room;
    }
    if (controllerChanged ||
        oldWidget.placeSearchFactory != widget.placeSearchFactory) {
      _resetTransientSearch();
    }
  }

  @override
  void dispose() {
    _accessGeneration += 1;
    _savedName.dispose();
    _routingText.dispose();
    _building.dispose();
    _room.dispose();
    _searchQuery.dispose();
    _disposeSearchController();
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
            labelAbove: true,
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
          if (widget.placeSearchFactory.enabled) ...[
            const SizedBox(height: 11),
            _searchSection(),
          ],
          if (widget.controller.provider != null) ...[
            const SizedBox(height: 4),
            _manualReplacementButton(),
          ],
        ],
      );
    },
  );

  Widget _field({
    required Key key,
    required TextEditingController controller,
    required String label,
    bool labelAbove = false,
    required TextCapitalization capitalization,
    TextInputType? keyboardType,
    required ValueChanged<String> onChanged,
  }) {
    final field = TextField(
      key: key,
      controller: controller,
      textCapitalization: capitalization,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: Type.body.copyWith(fontSize: 14, color: Palette.textHi),
      decoration: _fieldDecoration(labelAbove ? null : label),
    );
    if (!labelAbove) return field;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Type.label.copyWith(
            fontSize: Type.minLabel,
            letterSpacing: 0.7,
            color: Palette.textLo,
          ),
        ),
        const SizedBox(height: 4),
        Semantics(label: label, textField: true, child: field),
      ],
    );
  }

  Widget _searchSection() {
    if (!_searchActive) {
      final affordance = Semantics(
        button: true,
        enabled: !_accessInFlight,
        label: 'Search places with Google',
        child: OutlinedButton.icon(
          key: ValueKey('${widget.keyPrefix}-search-affordance'),
          onPressed: _accessInFlight ? null : _startSearch,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(44),
            alignment: Alignment.centerLeft,
            foregroundColor: Palette.xpLight,
            side: BorderSide(color: Palette.brass.withValues(alpha: 0.5)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(9),
            ),
          ),
          icon: const Icon(Icons.place_outlined, size: 18),
          label: Text(
            _accessInFlight
                ? 'OPENING PLACE SEARCH…'
                : 'SEARCH PLACES WITH GOOGLE',
            style: Type.label.copyWith(
              fontSize: 11,
              letterSpacing: 0.75,
              color: Palette.xpLight,
            ),
          ),
        ),
      );
      final error = _accessErrorMessage;
      if (error == null) return affordance;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          affordance,
          const SizedBox(height: 7),
          Text(
            error,
            key: ValueKey('${widget.keyPrefix}-search-error'),
            style: Type.body.copyWith(fontSize: 12, color: Palette.textMid),
          ),
        ],
      );
    }

    final state = _searchController!.state;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _field(
          key: ValueKey('${widget.keyPrefix}-search-query'),
          controller: _searchQuery,
          label: 'PLACE SEARCH QUERY',
          labelAbove: true,
          capitalization: TextCapitalization.words,
          onChanged: _searchController!.updateQuery,
        ),
        if (state.isLoading) ...[
          const SizedBox(height: 7),
          const LinearProgressIndicator(
            minHeight: 2,
            color: Palette.xpLight,
            backgroundColor: Palette.glassFill,
          ),
        ],
        if (state.suggestions.isNotEmpty) ...[
          const SizedBox(height: 7),
          for (var index = 0; index < state.suggestions.length; index++)
            Padding(
              padding: EdgeInsets.only(
                bottom: index == state.suggestions.length - 1 ? 0 : 5,
              ),
              child: _suggestionTile(state.suggestions[index], index),
            ),
        ],
        if (state.selection case final selection?) ...[
          const SizedBox(height: 7),
          _selectionPreview(selection),
        ],
        if (state.suggestions.isNotEmpty || state.selection != null) ...[
          const SizedBox(height: 5),
          _googleAttribution(),
        ],
        if ((_accessErrorMessage ?? state.errorMessage) case final error?) ...[
          const SizedBox(height: 7),
          Text(
            error,
            key: ValueKey('${widget.keyPrefix}-search-error'),
            style: Type.body.copyWith(fontSize: 12, color: Palette.textMid),
          ),
        ],
      ],
    );
  }

  Widget _suggestionTile(PlaceSuggestion suggestion, int index) => Semantics(
    button: true,
    label: [suggestion.primaryText, ?suggestion.secondaryText].join(', '),
    child: InkWell(
      key: ValueKey('${widget.keyPrefix}-search-suggestion-$index'),
      onTap: () {
        _selectSuggestion(suggestion);
        Sfx.instance.playInteraction(InteractionSound.select);
      },
      borderRadius: BorderRadius.circular(9),
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: Palette.glassFill,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: Palette.glassEdge),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              suggestion.primaryText,
              style: Type.body.copyWith(fontSize: 13, color: Palette.textHi),
            ),
            if (suggestion.secondaryText case final secondary?) ...[
              const SizedBox(height: 2),
              Text(
                secondary,
                style: Type.body.copyWith(
                  fontSize: 11.5,
                  height: 1.25,
                  color: Palette.textMid,
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );

  Widget _selectionPreview(PlaceSelection selection) => Container(
    key: ValueKey('${widget.keyPrefix}-search-selection'),
    width: double.infinity,
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(
      color: Palette.glassFill,
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: Palette.brass.withValues(alpha: 0.46)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          selection.primaryText,
          style: Type.body.copyWith(fontSize: 13, color: Palette.textHi),
        ),
        if (selection.secondaryText case final secondary?) ...[
          const SizedBox(height: 3),
          Text(
            secondary,
            style: Type.body.copyWith(
              fontSize: 11.5,
              height: 1.25,
              color: Palette.textMid,
            ),
          ),
        ],
      ],
    ),
  );

  Widget _googleAttribution() => Text(
    'Google Maps',
    key: ValueKey('${widget.keyPrefix}-google-attribution'),
    style: Type.label.copyWith(
      fontSize: Type.minLabel,
      letterSpacing: 0.45,
      color: Palette.textLo,
    ),
  );

  Widget _manualReplacementButton() => SizedBox(
    width: double.infinity,
    child: TextButton(
      key: ValueKey('${widget.keyPrefix}-manual-replacement'),
      onPressed: () {
        Sfx.instance.playInteraction(InteractionSound.select);
        _useManualReplacement();
      },
      style: TextButton.styleFrom(
        minimumSize: const Size.fromHeight(44),
        alignment: Alignment.centerLeft,
        foregroundColor: Palette.textMid,
      ),
      child: Text(
        'USE MANUAL LOCATION INSTEAD',
        style: Type.label.copyWith(
          fontSize: 10.5,
          letterSpacing: 0.65,
          color: Palette.textMid,
        ),
      ),
    ),
  );

  Future<void> _startSearch() async {
    if (_accessInFlight || _searchActive) return;
    final accessGeneration = ++_accessGeneration;
    setState(() {
      _accessInFlight = true;
      _accessErrorMessage = null;
    });
    try {
      final access = _searchAccess ??= widget.placeSearchFactory.createAccess(
        requestConsent: () => showPlaceSearchConsentDialog(context),
      );
      final result = await access.ensureReady();
      if (!mounted || accessGeneration != _accessGeneration) return;
      if (result case PlaceSearchReady(
        :final installId,
        :final authorization,
      )) {
        final locale = Localizations.localeOf(context).toLanguageTag();
        final controller = widget.placeSearchFactory.createController(
          installId: installId,
          locale: locale,
          authorization: authorization,
        );
        _searchController = controller..addListener(_onSearchChanged);
        setState(() {
          _accessInFlight = false;
          _searchActive = true;
        });
      } else {
        setState(() {
          _accessInFlight = false;
          _accessErrorMessage = result is PlaceSearchUnavailable
              ? placeSearchUnavailableMessage
              : null;
        });
      }
    } catch (_) {
      if (!mounted || accessGeneration != _accessGeneration) return;
      setState(() {
        _accessInFlight = false;
        _accessErrorMessage = placeSearchUnavailableMessage;
      });
    }
  }

  Future<void> _selectSuggestion(PlaceSuggestion suggestion) async {
    final selection = await _searchController?.selectSuggestion(suggestion);
    if (!mounted || selection == null) return;
    widget.controller.useGoogleSelection(selection);
    _savedName.value = TextEditingValue(
      text: selection.originalQuery,
      selection: TextSelection.collapsed(
        offset: selection.originalQuery.length,
      ),
    );
    setState(() => _accessErrorMessage = null);
  }

  void _useManualReplacement() {
    widget.controller.useManualReplacement();
    _searchController?.invalidateForManualEdit();
    _searchQuery.clear();
    setState(() => _accessErrorMessage = null);
  }

  void _onSearchChanged() {
    if (mounted) setState(() {});
  }

  void _disposeSearchController() {
    final controller = _searchController;
    if (controller == null) return;
    controller.removeListener(_onSearchChanged);
    controller.dispose();
    _searchController = null;
  }

  void _resetTransientSearch() {
    _accessGeneration += 1;
    _disposeSearchController();
    _searchAccess = null;
    _searchQuery.clear();
    _searchActive = false;
    _accessInFlight = false;
    _accessErrorMessage = null;
  }
}

InputDecoration _fieldDecoration(String? label) => InputDecoration(
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
