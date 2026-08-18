import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'place_search_service.dart';

const placeSearchUnavailableMessage =
    'Search unavailable — type the location instead.';
final _nonWhitespaceCharacter = RegExp(r'\S', unicode: true);

typedef PlaceSearchUuidFactory = String Function();

@immutable
final class PlaceSearchState {
  PlaceSearchState({
    this.query = '',
    List<PlaceSuggestion> suggestions = const [],
    this.selection,
    this.errorMessage,
    this.isLoading = false,
  }) : suggestions = List<PlaceSuggestion>.unmodifiable(suggestions);

  final String query;
  final List<PlaceSuggestion> suggestions;
  final PlaceSelection? selection;
  final String? errorMessage;
  final bool isLoading;
}

/// Owns a single search session, without owning any manual form fields.
final class PlaceSearchController extends ChangeNotifier {
  factory PlaceSearchController({
    required PlaceSearchService service,
    required String installId,
    required String locale,
    Duration debounce = const Duration(milliseconds: 300),
    PlaceSearchUuidFactory? createSessionToken,
  }) => PlaceSearchController._(
    service,
    installId,
    locale,
    debounce,
    createSessionToken ?? const Uuid().v4,
  );

  PlaceSearchController._(
    this._service,
    this._installId,
    this._locale,
    this._debounce,
    this._createSessionToken,
  );

  final PlaceSearchService _service;
  final String _installId;
  final String _locale;
  final Duration _debounce;
  final PlaceSearchUuidFactory _createSessionToken;

  PlaceSearchState _state = PlaceSearchState();
  PlaceSearchState get state => _state;

  Timer? _debounceTimer;
  String? _sessionToken;
  int _generation = 0;
  final Map<PlaceSuggestion, _SuggestionContext> _suggestionContexts = {};
  bool _selectionInFlight = false;
  bool _disposed = false;

  /// Receives the raw manual field value. Only its trimmed form is transferred.
  void updateQuery(String rawQuery) {
    if (_disposed) return;
    _debounceTimer?.cancel();
    _generation += 1;
    _clearSuggestionContexts();
    _selectionInFlight = false;
    final trimmed = rawQuery.trim();
    if (_nonWhitespaceCharacter.allMatches(trimmed).length < 3) {
      _sessionToken = null;
      _setState(PlaceSearchState(query: rawQuery));
      return;
    }

    final token = _sessionToken ??= _createSessionToken();
    final requestGeneration = _generation;
    _setState(PlaceSearchState(query: rawQuery, isLoading: true));
    _debounceTimer = Timer(_debounce, () {
      _autocomplete(
        query: trimmed,
        token: token,
        requestGeneration: requestGeneration,
      );
    });
  }

  void clear() => updateQuery('');

  /// Cancels an outstanding session when a manual field edit replaces search.
  void invalidateForManualEdit() => clear();

  Future<PlaceSelection?> selectSuggestion(PlaceSuggestion suggestion) async {
    if (_disposed || _selectionInFlight) return null;
    final context = _suggestionContexts[suggestion];
    if (context == null ||
        context.generation != _generation ||
        context.sessionToken != _sessionToken) {
      return null;
    }

    _selectionInFlight = true;
    _debounceTimer?.cancel();
    final requestGeneration = ++_generation;
    final originalQuery = context.originalQuery;
    final token = context.sessionToken;
    _clearSuggestionContexts();
    _sessionToken = null;
    _setState(PlaceSearchState(query: originalQuery, isLoading: true));
    try {
      final selection = await _service.details(
        suggestion: suggestion,
        originalQuery: originalQuery,
        sessionToken: token,
        installId: _installId,
        locale: _locale,
      );
      if (!_isCurrent(requestGeneration)) return null;
      _selectionInFlight = false;
      _setState(PlaceSearchState(query: originalQuery, selection: selection));
      return selection;
    } catch (_) {
      if (!_isCurrent(requestGeneration)) return null;
      _selectionInFlight = false;
      _setState(
        PlaceSearchState(
          query: originalQuery,
          errorMessage: placeSearchUnavailableMessage,
        ),
      );
      return null;
    }
  }

  Future<void> _autocomplete({
    required String query,
    required String token,
    required int requestGeneration,
  }) async {
    try {
      final suggestions = await _service.autocomplete(
        query: query,
        sessionToken: token,
        installId: _installId,
        locale: _locale,
      );
      if (!_isCurrent(requestGeneration) || _sessionToken != token) return;
      final visibleSuggestions = List<PlaceSuggestion>.unmodifiable(
        suggestions.take(5),
      );
      _clearSuggestionContexts();
      for (final suggestion in visibleSuggestions) {
        _suggestionContexts[suggestion] = _SuggestionContext(
          generation: requestGeneration,
          sessionToken: token,
          originalQuery: _state.query,
        );
      }
      _setState(
        PlaceSearchState(query: _state.query, suggestions: visibleSuggestions),
      );
    } catch (_) {
      if (!_isCurrent(requestGeneration) || _sessionToken != token) return;
      _setState(
        PlaceSearchState(
          query: _state.query,
          errorMessage: placeSearchUnavailableMessage,
        ),
      );
    }
  }

  bool _isCurrent(int requestGeneration) =>
      !_disposed && requestGeneration == _generation;

  void _clearSuggestionContexts() => _suggestionContexts.clear();

  void _setState(PlaceSearchState next) {
    if (_disposed) return;
    _state = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation += 1;
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _sessionToken = null;
    _clearSuggestionContexts();
    super.dispose();
  }
}

final class _SuggestionContext {
  const _SuggestionContext({
    required this.generation,
    required this.sessionToken,
    required this.originalQuery,
  });

  final int generation;
  final String sessionToken;
  final String originalQuery;
}
