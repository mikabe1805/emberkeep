import 'package:cloud_functions/cloud_functions.dart';

import 'place_search_service.dart';

const _callableTimeout = Duration(seconds: 8);

/// A thin injectable boundary around FlutterFire so service tests never need
/// Firebase initialization or an external callable.
abstract interface class PlaceCallableClient {
  Future<Object?> call(
    String name,
    Map<String, Object?> data, {
    required Duration timeout,
  });
}

final class FirebasePlaceCallableClient implements PlaceCallableClient {
  FirebasePlaceCallableClient({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  @override
  Future<Object?> call(
    String name,
    Map<String, Object?> data, {
    required Duration timeout,
  }) async {
    final callable = _functions.httpsCallable(
      name,
      options: HttpsCallableOptions(timeout: timeout),
    );
    return (await callable.call<Object?>(data)).data;
  }
}

/// Client-side contract for the two fixed, protected Firebase callables.
final class FirebasePlaceSearchService implements PlaceSearchService {
  FirebasePlaceSearchService({PlaceCallableClient? client, Duration? timeout})
    : _client = client ?? FirebasePlaceCallableClient(),
      _timeout = timeout ?? _callableTimeout;

  final PlaceCallableClient _client;
  final Duration _timeout;

  @override
  Future<List<PlaceSuggestion>> autocomplete({
    required String query,
    required String sessionToken,
    required String installId,
    required String locale,
  }) async {
    try {
      final payload = await _client.call('placesAutocomplete', {
        'query': query,
        'sessionToken': sessionToken,
        'installId': installId,
        'locale': locale,
      }, timeout: _timeout);
      if (payload is! List) throw const PlaceSearchUnavailable();
      return List<PlaceSuggestion>.unmodifiable(
        payload.take(5).map(_suggestionFromPayload),
      );
    } catch (_) {
      throw const PlaceSearchUnavailable();
    }
  }

  @override
  Future<PlaceSelection> details({
    required PlaceSuggestion suggestion,
    required String originalQuery,
    required String sessionToken,
    required String installId,
    required String locale,
  }) async {
    try {
      final payload = await _client.call('placesDetails', {
        'placeId': suggestion.placeId,
        'sessionToken': sessionToken,
        'installId': installId,
        'locale': locale,
      }, timeout: _timeout);
      final confirmed = _suggestionFromPayload(payload);
      if (confirmed.placeId != suggestion.placeId) {
        throw const PlaceSearchUnavailable();
      }
      return PlaceSelection(
        provider: confirmed.provider,
        placeId: confirmed.placeId,
        originalQuery: originalQuery,
        primaryText: confirmed.primaryText,
        secondaryText: confirmed.secondaryText,
      );
    } catch (_) {
      throw const PlaceSearchUnavailable();
    }
  }

  PlaceSuggestion _suggestionFromPayload(Object? payload) {
    if (payload is! Map) throw const PlaceSearchUnavailable();
    final provider = payload['provider'];
    final placeId = payload['placeId'];
    final primaryText = payload['primaryText'];
    final secondaryText = payload['secondaryText'];
    if (provider != null && provider != 'google' ||
        placeId is! String ||
        placeId.trim().isEmpty ||
        primaryText is! String ||
        primaryText.trim().isEmpty ||
        secondaryText != null && secondaryText is! String) {
      throw const PlaceSearchUnavailable();
    }
    return PlaceSuggestion(
      provider: 'google',
      placeId: placeId,
      primaryText: primaryText,
      secondaryText: secondaryText as String?,
    );
  }
}
