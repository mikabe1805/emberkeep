import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../services/directions_launcher.dart';

/// Only an affirmative, versioned decision is durable. Declines and dismissed
/// prompts are deliberately never represented in storage.
enum PlaceSearchConsent { acceptedV1 }

final class PlaceSearchConsentGrant {
  const PlaceSearchConsentGrant._(this.raw);

  static final _pattern = RegExp(
    r'^acceptedV1:[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-'
    r'[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  final String raw;

  static PlaceSearchConsentGrant? parse(String? raw) =>
      raw != null && _pattern.hasMatch(raw)
      ? PlaceSearchConsentGrant._(raw)
      : null;
}

abstract interface class PlaceSearchConsentStore {
  Future<String?> readAsyncConsent();
  Future<void> writeAsyncConsent(String value);
  Future<void> removeAsyncConsent();
  Future<void> removeLegacyConsent();
}

abstract interface class DurablePlaceSearchConsentPreferences {
  Future<PlaceSearchConsentGrant?> loadPlaceSearchConsentGrant();
  Future<PlaceSearchConsentGrant?> acceptPlaceSearchConsent();
  Future<bool> withdrawPlaceSearchConsent();
}

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
    implements
        DaybookPreferences,
        PlaceSearchPreferences,
        DurablePlaceSearchConsentPreferences {
  LocalDaybookPreferences({
    PlaceSearchConsentStore? consentStore,
    String Function()? createConsentGrantId,
  }) : _providedConsentStore = consentStore,
       _createConsentGrantId = createConsentGrantId ?? const Uuid().v4;

  static const _preferredMapProviderKey =
      'room_of_days_daybook_map_provider_v1';
  static const _placeSearchInstallIdKey =
      'room_of_days_place_search_install_id_v1';

  final PlaceSearchConsentStore? _providedConsentStore;
  late final PlaceSearchConsentStore _consentStore =
      _providedConsentStore ?? _SharedPreferencesConsentStore();
  final String Function() _createConsentGrantId;

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
    return await loadPlaceSearchConsentGrant() == null
        ? null
        : PlaceSearchConsent.acceptedV1;
  }

  @override
  Future<bool> savePlaceSearchConsent(PlaceSearchConsent? consent) async {
    if (consent == PlaceSearchConsent.acceptedV1) {
      return await acceptPlaceSearchConsent() != null;
    }
    return withdrawPlaceSearchConsent();
  }

  @override
  Future<PlaceSearchConsentGrant?> loadPlaceSearchConsentGrant() async {
    try {
      return PlaceSearchConsentGrant.parse(
        await _consentStore.readAsyncConsent(),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<PlaceSearchConsentGrant?> acceptPlaceSearchConsent() async {
    final raw =
        '${PlaceSearchConsent.acceptedV1.name}:'
        '${_createConsentGrantId()}';
    final grant = PlaceSearchConsentGrant.parse(raw);
    if (grant == null) return null;
    try {
      await _consentStore.writeAsyncConsent(raw);
      return await _consentStore.readAsyncConsent() == raw ? grant : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> withdrawPlaceSearchConsent() async {
    try {
      await _consentStore.removeAsyncConsent();
      if (await _consentStore.readAsyncConsent() != null) return false;
    } catch (_) {
      return false;
    }
    try {
      await _consentStore.removeLegacyConsent();
    } catch (_) {
      // The uncached v2 key is authoritative. Legacy v1 cleanup is best effort.
    }
    return true;
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

final class _SharedPreferencesConsentStore implements PlaceSearchConsentStore {
  static const _asyncKey = 'room_of_days_place_search_consent_v2';
  static const _legacyKey = 'room_of_days_place_search_consent_v1';

  final SharedPreferencesAsync _async = SharedPreferencesAsync();

  @override
  Future<String?> readAsyncConsent() => _async.getString(_asyncKey);

  @override
  Future<void> writeAsyncConsent(String value) =>
      _async.setString(_asyncKey, value);

  @override
  Future<void> removeAsyncConsent() => _async.remove(_asyncKey);

  @override
  Future<void> removeLegacyConsent() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_legacyKey);
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
