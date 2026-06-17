/// Non-web platforms have durable storage already — nothing to request.
Future<bool> requestPersistentStorage() async => false;
