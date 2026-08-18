import 'package:emberkeep/daybook/data/daybook_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

final class _ConsentStore implements PlaceSearchConsentStore {
  String? asyncValue;
  String? legacyValue;
  String? forcedReadback;
  bool forceReadback = false;
  bool throwOnRead = false;
  bool throwOnWrite = false;
  bool throwOnRemove = false;
  bool throwOnLegacyRemove = false;
  int legacyRemoveAttempts = 0;

  @override
  Future<String?> readAsyncConsent() async {
    if (throwOnRead) throw StateError('read unavailable');
    return forceReadback ? forcedReadback : asyncValue;
  }

  @override
  Future<void> writeAsyncConsent(String value) async {
    if (throwOnWrite) throw StateError('write unavailable');
    asyncValue = value;
  }

  @override
  Future<void> removeAsyncConsent() async {
    if (throwOnRemove) throw StateError('remove unavailable');
    asyncValue = null;
  }

  @override
  Future<void> removeLegacyConsent() async {
    legacyRemoveAttempts++;
    if (throwOnLegacyRemove) throw StateError('legacy unavailable');
    legacyValue = null;
  }
}

void main() {
  group('cacheless place-search consent', () {
    test('legacy affirmative consent is not migrated or authorized', () async {
      final store = _ConsentStore()..legacyValue = 'acceptedV1';
      final preferences = LocalDaybookPreferences(
        consentStore: store,
        createConsentGrantId: () => '11111111-1111-4111-8111-111111111111',
      );

      expect(await preferences.loadPlaceSearchConsentGrant(), isNull);
      expect(await preferences.loadPlaceSearchConsent(), isNull);
      expect(store.asyncValue, isNull);
      expect(store.legacyValue, 'acceptedV1');
    });

    test('acceptance requires exact async write readback', () async {
      final store = _ConsentStore();
      final preferences = LocalDaybookPreferences(
        consentStore: store,
        createConsentGrantId: () => '11111111-1111-4111-8111-111111111111',
      );

      final grant = await preferences.acceptPlaceSearchConsent();
      expect(grant?.raw, 'acceptedV1:11111111-1111-4111-8111-111111111111');

      store
        ..forceReadback = true
        ..forcedReadback = 'acceptedV1:another-tab';
      expect(await preferences.acceptPlaceSearchConsent(), isNull);
    });

    test('read and write ambiguity fail closed', () async {
      final unreadable = _ConsentStore()..throwOnRead = true;
      final readPreferences = LocalDaybookPreferences(
        consentStore: unreadable,
        createConsentGrantId: () => '11111111-1111-4111-8111-111111111111',
      );
      expect(await readPreferences.loadPlaceSearchConsentGrant(), isNull);
      expect(await readPreferences.acceptPlaceSearchConsent(), isNull);

      final unwritable = _ConsentStore()..throwOnWrite = true;
      final writePreferences = LocalDaybookPreferences(
        consentStore: unwritable,
        createConsentGrantId: () => '11111111-1111-4111-8111-111111111111',
      );
      expect(await writePreferences.acceptPlaceSearchConsent(), isNull);
    });

    test(
      'withdrawal requires absent async readback and only best-effort clears v1',
      () async {
        final store = _ConsentStore()
          ..asyncValue = 'acceptedV1:active'
          ..legacyValue = 'acceptedV1'
          ..throwOnLegacyRemove = true;
        final preferences = LocalDaybookPreferences(consentStore: store);

        expect(await preferences.withdrawPlaceSearchConsent(), isTrue);
        expect(store.asyncValue, isNull);
        expect(store.legacyRemoveAttempts, 1);

        store
          ..asyncValue = 'acceptedV1:restored'
          ..forceReadback = true
          ..forcedReadback = 'acceptedV1:restored';
        expect(await preferences.withdrawPlaceSearchConsent(), isFalse);
      },
    );
  });
}
