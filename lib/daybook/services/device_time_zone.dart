import 'device_time_zone_stub.dart'
    if (dart.library.io) 'device_time_zone_native.dart'
    if (dart.library.js_interop) 'device_time_zone_web.dart'
    as platform;

typedef TimeZoneIdProvider = Future<String> Function();

/// A neutral IANA fallback used only when the device/browser zone is
/// unavailable. It deliberately carries no regional assumption.
const neutralTimeZoneId = 'Etc/UTC';

Future<String> resolveDeviceTimeZoneId({TimeZoneIdProvider? discover}) async {
  try {
    final value = await (discover ?? platform.discoverDeviceTimeZoneId)();
    final trimmed = value.trim();
    return trimmed.isEmpty ? neutralTimeZoneId : trimmed;
  } catch (_) {
    return neutralTimeZoneId;
  }
}
