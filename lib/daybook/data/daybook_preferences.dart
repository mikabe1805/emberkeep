import 'package:shared_preferences/shared_preferences.dart';

import '../services/directions_launcher.dart';

/// Only an affirmative, versioned decision is durable. Declines and dismissed
/// prompts are deliberately never represented in storage.
enum PlaceSearchConsent { acceptedV1 }

abstract interface class DaybookPreferences {
  Future<MapProvider?> loadPreferredMapProvider();
  Future<void> savePreferredMapProvider(MapProvider? provider);
}

/// Kept separate from [DaybookPreferences] so existing map-only test doubles
/// and consumers do not acquire unrelated consent/storage responsibilities.
abstract interface class PlaceSearchPreferences {
  Future<PlaceSearchConsent?> loadPlaceSearchConsent();
  Future<bool> savePlaceSearchConsent(PlaceSearchConsent? consent);
  Future<String?> loadPlaceSearchInstallId();
  Future<bool> savePlaceSearchInstallId(String installId);
}

final class LocalDaybookPreferences
    implements DaybookPreferences, PlaceSearchPreferences {
  static const _preferredMapProviderKey =
      'room_of_days_daybook_map_provider_v1';
  static const _placeSearchConsentKey = 'room_of_days_place_search_consent_v1';
  static const _placeSearchInstallIdKey =
      'room_of_days_place_search_install_id_v1';

  @override
  Future<MapProvider?> loadPreferredMapProvider() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(_preferredMapProviderKey);
      if (raw == null) return null;
      return MapProvider.values.where((value) => value.name == raw).firstOrNull;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> savePreferredMapProvider(MapProvider? provider) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      if (provider == null) {
        await preferences.remove(_preferredMapProviderKey);
      } else {
        await preferences.setString(_preferredMapProviderKey, provider.name);
      }
    } catch (_) {
      // A map-app preference is optional and never touches Daybook content.
    }
  }

  @override
  Future<PlaceSearchConsent?> loadPlaceSearchConsent() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(_placeSearchConsentKey);
      return raw == PlaceSearchConsent.acceptedV1.name
          ? PlaceSearchConsent.acceptedV1
          : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> savePlaceSearchConsent(PlaceSearchConsent? consent) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      if (consent == PlaceSearchConsent.acceptedV1) {
        return await preferences.setString(
          _placeSearchConsentKey,
          PlaceSearchConsent.acceptedV1.name,
        );
      }
      return await preferences.remove(_placeSearchConsentKey);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String?> loadPlaceSearchInstallId() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      return preferences.getString(_placeSearchInstallIdKey);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> savePlaceSearchInstallId(String installId) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      return await preferences.setString(_placeSearchInstallIdKey, installId);
    } catch (_) {
      return false;
    }
  }
}

final class InMemoryDaybookPreferences
    implements DaybookPreferences, PlaceSearchPreferences {
  InMemoryDaybookPreferences({
    this.preferredMapProvider,
    this.placeSearchConsent,
    this.placeSearchInstallId,
  });

  MapProvider? preferredMapProvider;
  PlaceSearchConsent? placeSearchConsent;
  String? placeSearchInstallId;

  @override
  Future<MapProvider?> loadPreferredMapProvider() async => preferredMapProvider;

  @override
  Future<void> savePreferredMapProvider(MapProvider? provider) async {
    preferredMapProvider = provider;
  }

  @override
  Future<PlaceSearchConsent?> loadPlaceSearchConsent() async =>
      placeSearchConsent;

  @override
  Future<bool> savePlaceSearchConsent(PlaceSearchConsent? consent) async {
    placeSearchConsent = consent == PlaceSearchConsent.acceptedV1
        ? consent
        : null;
    return true;
  }

  @override
  Future<String?> loadPlaceSearchInstallId() async => placeSearchInstallId;

  @override
  Future<bool> savePlaceSearchInstallId(String installId) async {
    placeSearchInstallId = installId;
    return true;
  }
}
