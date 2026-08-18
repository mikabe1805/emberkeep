import 'dart:js_interop';

@JS('Intl.DateTimeFormat')
extension type _IntlDateTimeFormat._(JSObject _) implements JSObject {
  external factory _IntlDateTimeFormat();

  external _IntlResolvedOptions resolvedOptions();
}

extension type _IntlResolvedOptions._(JSObject _) implements JSObject {
  external String get timeZone;
}

Future<String> discoverDeviceTimeZoneId() async =>
    _IntlDateTimeFormat().resolvedOptions().timeZone;
