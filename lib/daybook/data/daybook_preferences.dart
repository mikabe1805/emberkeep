import 'package:shared_preferences/shared_preferences.dart';

import '../services/directions_launcher.dart';

abstract interface class DaybookPreferences {
  Future<MapProvider?> loadPreferredMapProvider();
  Future<void> savePreferredMapProvider(MapProvider? provider);
}

final class LocalDaybookPreferences implements DaybookPreferences {
  static const _preferredMapProviderKey =
      'room_of_days_daybook_map_provider_v1';

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
}

final class InMemoryDaybookPreferences implements DaybookPreferences {
  InMemoryDaybookPreferences({this.preferredMapProvider});

  MapProvider? preferredMapProvider;

  @override
  Future<MapProvider?> loadPreferredMapProvider() async => preferredMapProvider;

  @override
  Future<void> savePreferredMapProvider(MapProvider? provider) async {
    preferredMapProvider = provider;
  }
}
