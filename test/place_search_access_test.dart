import 'dart:async';

import 'package:emberkeep/daybook/data/daybook_preferences.dart';
import 'package:emberkeep/daybook/services/directions_launcher.dart';
import 'package:emberkeep/daybook/services/place_search_access.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

const _stableInstallId = 'b3a93124-f96e-44fc-a25d-23aa8f35262c';
const _replacementInstallId = '0987d452-8fd5-4de8-9401-530f73a577f8';

void main() {
  group('PlaceSearchAccess', () {
    test(
      'disabled access performs no reads, prompt, or bootstrap work',
      () async {
        final log = <String>[];
        final preferences = _RecordingPreferences(log: log);
        final identity = _RecordingIdentity(log: log);
        final appCheck = _RecordingAppCheck(log: log);
        var prompts = 0;
        var uuidCalls = 0;
        final access = PlaceSearchAccess(
          enabled: false,
          preferences: preferences,
          identity: identity,
          appCheck: appCheck,
          requestConsent: () async {
            prompts += 1;
            return PlaceSearchConsentDecision.accept;
          },
          createInstallId: () {
            uuidCalls += 1;
            return _stableInstallId;
          },
        );

        expect(await access.ensureReady(), isA<PlaceSearchDisabled>());
        expect(log, isEmpty);
        expect(prompts, 0);
        expect(uuidCalls, 0);
      },
    );

    for (final decision in <PlaceSearchConsentDecision?>[
      null,
      PlaceSearchConsentDecision.decline,
    ]) {
      test(
        '${decision == null ? 'closing' : 'declining'} consent persists nothing and does not bootstrap',
        () async {
          final log = <String>[];
          final preferences = _RecordingPreferences(log: log);
          final identity = _RecordingIdentity(log: log);
          final appCheck = _RecordingAppCheck(log: log);
          final access = PlaceSearchAccess(
            enabled: true,
            preferences: preferences,
            identity: identity,
            appCheck: appCheck,
            requestConsent: () async {
              log.add('prompt');
              return decision;
            },
            createInstallId: () => _stableInstallId,
          );

          expect(await access.ensureReady(), isA<PlaceSearchDeclined>());
          expect(log, ['consent.read', 'prompt']);
          expect(preferences.consentWrites, isEmpty);
          expect(preferences.installIdWrites, isEmpty);
        },
      );
    }

    test(
      'accepted V1 skips the prompt and reuses an existing identity',
      () async {
        final log = <String>[];
        final preferences = _RecordingPreferences(
          log: log,
          consent: PlaceSearchConsent.acceptedV1,
          installId: _stableInstallId,
        );
        final identity = _RecordingIdentity(log: log, signedIn: true);
        var prompts = 0;
        final access = PlaceSearchAccess(
          enabled: true,
          preferences: preferences,
          identity: identity,
          appCheck: _RecordingAppCheck(log: log),
          requestConsent: () async {
            prompts += 1;
            return PlaceSearchConsentDecision.decline;
          },
        );

        final result = await access.ensureReady();

        expect(result, isA<PlaceSearchReady>());
        expect((result as PlaceSearchReady).installId, _stableInstallId);
        expect(prompts, 0);
        expect(identity.signInCalls, 0);
        expect(log, ['consent.read', 'core', 'appcheck', 'install.read']);
      },
    );

    test(
      'acceptance persists before Core and provisions identity before install ID',
      () async {
        final log = <String>[];
        final preferences = _RecordingPreferences(log: log);
        final identity = _RecordingIdentity(log: log);
        final access = PlaceSearchAccess(
          enabled: true,
          preferences: preferences,
          identity: identity,
          appCheck: _RecordingAppCheck(log: log),
          requestConsent: () async {
            log.add('prompt');
            return PlaceSearchConsentDecision.accept;
          },
          createInstallId: () {
            log.add('install.create');
            return _stableInstallId;
          },
        );

        final result = await access.ensureReady();

        expect(result, isA<PlaceSearchReady>());
        expect(log, [
          'consent.read',
          'prompt',
          'consent.write:acceptedV1',
          'core',
          'appcheck',
          'auth',
          'install.read',
          'install.create',
          'install.write:$_stableInstallId',
        ]);
      },
    );

    test(
      'parallel readiness calls share one auth and install operation',
      () async {
        final log = <String>[];
        final authGate = Completer<void>();
        final preferences = _RecordingPreferences(
          log: log,
          consent: PlaceSearchConsent.acceptedV1,
        );
        final identity = _RecordingIdentity(
          log: log,
          authGate: authGate.future,
        );
        var uuidCalls = 0;
        final access = PlaceSearchAccess(
          enabled: true,
          preferences: preferences,
          identity: identity,
          appCheck: _RecordingAppCheck(log: log),
          requestConsent: () async => PlaceSearchConsentDecision.accept,
          createInstallId: () {
            uuidCalls += 1;
            return _stableInstallId;
          },
        );

        final first = access.ensureReady();
        final second = access.ensureReady();
        await Future<void>.delayed(Duration.zero);
        expect(identity.signInCalls, 1);
        authGate.complete();

        final results = await Future.wait([first, second]);
        expect(identity.signInCalls, 1);
        expect(uuidCalls, 1);
        expect(preferences.installIdWrites, [_stableInstallId]);
        expect(results[0], same(results[1]));
      },
    );

    test(
      'Core, App Check, and auth failures remain unavailable without install reads',
      () async {
        for (final failure in ['core', 'appcheck', 'auth']) {
          final log = <String>[];
          final preferences = _RecordingPreferences(
            log: log,
            consent: PlaceSearchConsent.acceptedV1,
          );
          final access = PlaceSearchAccess(
            enabled: true,
            preferences: preferences,
            identity: _RecordingIdentity(
              log: log,
              coreAvailable: failure != 'core',
              authAvailable: failure != 'auth',
            ),
            appCheck: _RecordingAppCheck(
              log: log,
              available: failure != 'appcheck',
            ),
            requestConsent: () async => PlaceSearchConsentDecision.accept,
            createInstallId: () => _stableInstallId,
          );

          expect(await access.ensureReady(), isA<PlaceSearchUnavailable>());
          expect(log, isNot(contains('install.read')));
          expect(preferences.consent, PlaceSearchConsent.acceptedV1);
        }
      },
    );

    test(
      'accepted consent can retry after an unavailable App Check attempt',
      () async {
        final log = <String>[];
        final preferences = _RecordingPreferences(
          log: log,
          consent: PlaceSearchConsent.acceptedV1,
        );
        final appCheck = _RecordingAppCheck(log: log, available: false);
        final access = PlaceSearchAccess(
          enabled: true,
          preferences: preferences,
          identity: _RecordingIdentity(log: log),
          appCheck: appCheck,
          requestConsent: () async => PlaceSearchConsentDecision.accept,
          createInstallId: () => _stableInstallId,
        );

        expect(await access.ensureReady(), isA<PlaceSearchUnavailable>());
        appCheck.available = true;
        final retried = await access.ensureReady();

        expect(retried, isA<PlaceSearchReady>());
        expect(preferences.consent, PlaceSearchConsent.acceptedV1);
        expect(log.where((event) => event == 'appcheck').length, 2);
      },
    );

    test(
      'a valid install UUID remains stable across access instances',
      () async {
        final preferences = _RecordingPreferences(
          log: <String>[],
          consent: PlaceSearchConsent.acceptedV1,
        );
        var generated = _stableInstallId;

        Future<String> readyId() async {
          final log = <String>[];
          preferences.log = log;
          final result = await PlaceSearchAccess(
            enabled: true,
            preferences: preferences,
            identity: _RecordingIdentity(log: log, signedIn: true),
            appCheck: _RecordingAppCheck(log: log),
            requestConsent: () async => PlaceSearchConsentDecision.accept,
            createInstallId: () => generated,
          ).ensureReady();
          return (result as PlaceSearchReady).installId;
        }

        expect(await readyId(), _stableInstallId);
        generated = _replacementInstallId;
        expect(await readyId(), _stableInstallId);
        expect(preferences.installIdWrites, [_stableInstallId]);
      },
    );

    test(
      'malformed or non-v4 stored install IDs are regenerated as UUIDv4',
      () async {
        for (final malformed in [
          'not-a-uuid',
          '6ba7b810-9dad-11d1-80b4-00c04fd430c8',
        ]) {
          final log = <String>[];
          final preferences = _RecordingPreferences(
            log: log,
            consent: PlaceSearchConsent.acceptedV1,
            installId: malformed,
          );
          final result = await PlaceSearchAccess(
            enabled: true,
            preferences: preferences,
            identity: _RecordingIdentity(log: log, signedIn: true),
            appCheck: _RecordingAppCheck(log: log),
            requestConsent: () async => PlaceSearchConsentDecision.accept,
            createInstallId: () => _replacementInstallId,
          ).ensureReady();

          final id = (result as PlaceSearchReady).installId;
          expect(UuidValue.withValidation(id).version, 4);
          expect(id, _replacementInstallId);
          expect(preferences.installId, _replacementInstallId);
        }
      },
    );

    test(
      'withdrawal clears consent only and retains identity, map choice, and install ID',
      () async {
        final log = <String>[];
        final preferences = InMemoryDaybookPreferences(
          preferredMapProvider: MapProvider.apple,
          placeSearchConsent: PlaceSearchConsent.acceptedV1,
          placeSearchInstallId: _stableInstallId,
        );
        final identity = _RecordingIdentity(log: log, signedIn: true);
        final access = PlaceSearchAccess(
          enabled: true,
          preferences: preferences,
          identity: identity,
          appCheck: _RecordingAppCheck(log: log),
          requestConsent: () async => PlaceSearchConsentDecision.accept,
        );

        expect(await access.ensureReady(), isA<PlaceSearchReady>());
        await access.withdrawConsent();

        expect(preferences.placeSearchConsent, isNull);
        expect(preferences.placeSearchInstallId, _stableInstallId);
        expect(preferences.preferredMapProvider, MapProvider.apple);
        expect(identity.signedIn, isTrue);

        final reenabled = await access.ensureReady();
        expect((reenabled as PlaceSearchReady).installId, _stableInstallId);
        expect(preferences.placeSearchInstallId, _stableInstallId);
      },
    );
  });
}

final class _RecordingPreferences implements PlaceSearchPreferences {
  _RecordingPreferences({required this.log, this.consent, this.installId});

  List<String> log;
  PlaceSearchConsent? consent;
  String? installId;
  final List<PlaceSearchConsent?> consentWrites = [];
  final List<String> installIdWrites = [];

  @override
  Future<PlaceSearchConsent?> loadPlaceSearchConsent() async {
    log.add('consent.read');
    return consent;
  }

  @override
  Future<void> savePlaceSearchConsent(PlaceSearchConsent? value) async {
    log.add('consent.write:${value?.name ?? 'clear'}');
    consentWrites.add(value);
    consent = value;
  }

  @override
  Future<String?> loadPlaceSearchInstallId() async {
    log.add('install.read');
    return installId;
  }

  @override
  Future<void> savePlaceSearchInstallId(String value) async {
    log.add('install.write:$value');
    installIdWrites.add(value);
    installId = value;
  }
}

final class _RecordingIdentity implements PlaceSearchIdentity {
  _RecordingIdentity({
    required this.log,
    this.signedIn = false,
    this.coreAvailable = true,
    this.authAvailable = true,
    this.authGate,
  });

  final List<String> log;
  @override
  bool signedIn;
  bool coreAvailable;
  bool authAvailable;
  final Future<void>? authGate;
  int signInCalls = 0;

  @override
  Future<bool> ensureCoreAvailable() async {
    log.add('core');
    return coreAvailable;
  }

  @override
  Future<bool> signInAnonymously() async {
    log.add('auth');
    signInCalls += 1;
    await authGate;
    if (authAvailable) signedIn = true;
    return authAvailable;
  }
}

final class _RecordingAppCheck implements PlaceSearchAppCheck {
  _RecordingAppCheck({required this.log, this.available = true});

  final List<String> log;
  bool available;

  @override
  Future<bool> activate() async {
    log.add('appcheck');
    return available;
  }
}
