// Local notifications facade. Native (iOS/Android) gets the real
// flutter_local_notifications-backed impl; web (and anything without dart:io)
// gets a no-op stub, so the web build never compiles the native plugin.
// Mirrors the haptics.dart / share conditional-import pattern.
export 'platform/notifications_stub.dart'
    if (dart.library.io) 'platform/notifications_native.dart';
