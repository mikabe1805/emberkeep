import '../domain/daybook_place.dart';

/// A provider result that is deliberately kept out of durable Daybook data.
final class PlaceSuggestion {
  const PlaceSuggestion({
    required this.provider,
    required this.placeId,
    required this.primaryText,
    this.secondaryText,
  });

  final String provider;
  final String placeId;
  final String primaryText;
  final String? secondaryText;
}

/// A transient, attributed result confirmed by the provider.
final class PlaceSelection {
  const PlaceSelection({
    required this.provider,
    required this.placeId,
    required this.originalQuery,
    required this.primaryText,
    this.secondaryText,
  });

  final String provider;
  final String placeId;
  final String originalQuery;
  final String primaryText;
  final String? secondaryText;

  /// Converts only person-authored fields into the local Daybook record.
  ///
  /// Provider display text and addresses must remain transient rather than
  /// becoming cached Google Places content.
  DaybookPlace toPersistedPlace({
    String? routingText,
    String? building,
    String? room,
  }) {
    if (provider != 'google') {
      throw ArgumentError.value(provider, 'provider', 'Unsupported provider');
    }
    return DaybookPlace(
      savedName: originalQuery,
      routingText: routingText,
      building: building,
      room: room,
      provider: DaybookPlaceProvider.google,
      providerPlaceId: placeId,
    );
  }
}

/// A typed failure that intentionally exposes no provider or callable detail.
final class PlaceSearchUnavailable implements Exception {
  const PlaceSearchUnavailable();
}

abstract interface class PlaceSearchService {
  Future<List<PlaceSuggestion>> autocomplete({
    required String query,
    required String sessionToken,
    required String installId,
    required String locale,
  });

  Future<PlaceSelection> details({
    required PlaceSuggestion suggestion,
    required String originalQuery,
    required String sessionToken,
    required String installId,
    required String locale,
  });
}

/// The disabled release path deliberately performs no callable work.
final class DisabledPlaceSearchService implements PlaceSearchService {
  const DisabledPlaceSearchService();

  @override
  Future<List<PlaceSuggestion>> autocomplete({
    required String query,
    required String sessionToken,
    required String installId,
    required String locale,
  }) async => const [];

  @override
  Future<PlaceSelection> details({
    required PlaceSuggestion suggestion,
    required String originalQuery,
    required String sessionToken,
    required String installId,
    required String locale,
  }) => Future<PlaceSelection>.error(const PlaceSearchUnavailable());
}
