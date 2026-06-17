import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Ask the browser to make this origin's storage persistent — an installed
/// PWA that is granted this is exempt from iOS Safari's ~7-day eviction,
/// which is what protects the local save (and the Firebase auth identity)
/// from silent wipes. Best-effort: returns whether it was granted.
Future<bool> requestPersistentStorage() async {
  try {
    final storage = web.window.navigator.storage;
    final already = await storage.persisted().toDart;
    if (already.toDart) return true;
    final granted = await storage.persist().toDart;
    return granted.toDart;
  } catch (_) {
    return false;
  }
}
