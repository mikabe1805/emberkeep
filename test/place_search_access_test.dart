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

    for (final throws in [false, true]) {
      test(
        'accepted consent ${throws ? 'exception' : 'false return'} fails closed before Core',
        () async {
          final log = <String>[];
          final preferences = _RecordingPreferences(
            log: log,
            consentWriteSucceeds: false,
            throwOnConsentWrite: throws,
          );
          final identity = _RecordingIdentity(log: log);
          final access = PlaceSearchAccess(
            enabled: true,
            preferences: preferences,
            identity: identity,
            appCheck: _RecordingAppCheck(log: log),
            requestConsent: () async => PlaceSearchConsentDecision.accept,
            createInstallId: () => _stableInstallId,
          );

          expect(await access.ensureReady(), isA<PlaceSearchUnavailable>());
          expect(log, ['consent.read', 'consent.write:acceptedV1']);
          expect(identity.coreCalls, 0);
        },
      );
    }

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

    for (final throws in [false, true]) {
      test(
        'install ID ${throws ? 'exception' : 'false return'} does not return or cache ready',
        () async {
          final log = <String>[];
          final preferences = _RecordingPreferences(
            log: log,
            consent: PlaceSearchConsent.acceptedV1,
            installIdWriteSucceeds: false,
            throwOnInstallIdWrite: throws,
          );
          final access = PlaceSearchAccess(
            enabled: true,
            preferences: preferences,
            identity: _RecordingIdentity(log: log, signedIn: true),
            appCheck: _RecordingAppCheck(log: log),
            requestConsent: () async => PlaceSearchConsentDecision.accept,
            createInstallId: () => _stableInstallId,
          );

          expect(await access.ensureReady(), isA<PlaceSearchUnavailable>());
          preferences
            ..installIdWriteSucceeds = true
            ..throwOnInstallIdWrite = false;
          expect(await access.ensureReady(), isA<PlaceSearchReady>());
          expect(preferences.installIdWrites, [
            _stableInstallId,
            _stableInstallId,
          ]);
        },
      );
    }

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

    for (final throws in [false, true]) {
      test(
        'withdrawal ${throws ? 'exception' : 'false return'} preserves ready and reports failure',
        () async {
          final log = <String>[];
          final preferences = _RecordingPreferences(
            log: log,
            consent: PlaceSearchConsent.acceptedV1,
            installId: _stableInstallId,
          );
          final identity = _RecordingIdentity(log: log, signedIn: true);
          final access = PlaceSearchAccess(
            enabled: true,
            preferences: preferences,
            identity: identity,
            appCheck: _RecordingAppCheck(log: log),
            requestConsent: () async => PlaceSearchConsentDecision.decline,
          );

          final ready = await access.ensureReady();
          preferences
            ..consentWriteSucceeds = false
            ..throwOnConsentWrite = throws;

          expect(await access.withdrawConsent(), isFalse);
          expect(await access.ensureReady(), same(ready));
          expect(preferences.consent, PlaceSearchConsent.acceptedV1);
          expect(identity.coreCalls, 1);
        },
      );
    }
  });

  group('FirebasePlaceSearchAppCheck', () {
    test(
      'unsupported and missing web configuration fail without activation',
      () async {
        final activator = _RecordingAppCheckActivator();

        expect(
          await FirebasePlaceSearchAppCheck(
            platform: PlaceSearchAppCheckPlatform.unsupported,
            activator: activator,
          ).activate(),
          isFalse,
        );
        expect(
          await FirebasePlaceSearchAppCheck(
            platform: PlaceSearchAppCheckPlatform.web,
            webSiteKey: '   ',
            activator: activator,
          ).activate(),
          isFalse,
        );
        expect(activator.configurations, isEmpty);
      },
    );

    test(
      'selects production and explicitly opted-in debug providers',
      () async {
        final activator = _RecordingAppCheckActivator();
        final cases = [
          (
            PlaceSearchAppCheckPlatform.android,
            false,
            PlaceSearchAppCheckProvider.playIntegrity,
            '',
          ),
          (
            PlaceSearchAppCheckPlatform.apple,
            false,
            PlaceSearchAppCheckProvider.appAttestWithDeviceCheckFallback,
            '',
          ),
          (
            PlaceSearchAppCheckPlatform.web,
            false,
            PlaceSearchAppCheckProvider.recaptchaV3,
            'public-site-key',
          ),
          (
            PlaceSearchAppCheckPlatform.android,
            true,
            PlaceSearchAppCheckProvider.debug,
            '',
          ),
          (
            PlaceSearchAppCheckPlatform.apple,
            true,
            PlaceSearchAppCheckProvider.debug,
            '',
          ),
          (
            PlaceSearchAppCheckPlatform.web,
            true,
            PlaceSearchAppCheckProvider.debug,
            'public-site-key',
          ),
        ];

        for (final entry in cases) {
          final appCheck = FirebasePlaceSearchAppCheck(
            platform: entry.$1,
            useDebugProvider: entry.$2,
            webSiteKey: entry.$4,
            activator: activator,
          );
          expect(await appCheck.activate(), isTrue);
        }

        expect(
          activator.configurations
              .map((configuration) => configuration.provider)
              .toList(),
          cases.map((entry) => entry.$3).toList(),
        );
        expect(activator.configurations[2].webSiteKey, 'public-site-key');
        expect(activator.configurations[5].webSiteKey, isNull);
      },
    );

    test('coalesces parallel activation calls', () async {
      final gate = Completer<void>();
      final activator = _RecordingAppCheckActivator(gates: [gate.future]);
      final appCheck = FirebasePlaceSearchAppCheck(
        platform: PlaceSearchAppCheckPlatform.android,
        activator: activator,
      );

      final first = appCheck.activate();
      final second = appCheck.activate();
      await Future<void>.delayed(Duration.zero);
      expect(activator.configurations, hasLength(1));
      gate.complete();

      expect(await Future.wait([first, second]), [isTrue, isTrue]);
      expect(activator.configurations, hasLength(1));
    });

    test(
      'timeout retains the pending activation and retries without duplication',
      () async {
        final gate = Completer<void>();
        final activator = _RecordingAppCheckActivator(gates: [gate.future]);
        final appCheck = FirebasePlaceSearchAppCheck(
          platform: PlaceSearchAppCheckPlatform.android,
          timeout: const Duration(milliseconds: 5),
          activator: activator,
        );

        expect(await appCheck.activate(), isFalse);
        final retry = appCheck.activate();
        await Future<void>.delayed(Duration.zero);
        expect(activator.configurations, hasLength(1));
        gate.complete();

        expect(await retry, isTrue);
        expect(activator.configurations, hasLength(1));
      },
    );

    test('a failed provider activation is retryable', () async {
      final activator = _RecordingAppCheckActivator(
        gates: [Future<void>.error(StateError('attestation failed'))],
      );
      final appCheck = FirebasePlaceSearchAppCheck(
        platform: PlaceSearchAppCheckPlatform.android,
        activator: activator,
      );

      expect(await appCheck.activate(), isFalse);
      expect(await appCheck.activate(), isTrue);
      expect(activator.configurations, hasLength(2));
    });
  });

  test(
    'CloudPlaceSearchIdentity delegates Core-only then serialized service auth',
    () async {
      final coordinator = _RecordingCloudCoordinator();
      final identity = CloudPlaceSearchIdentity(coordinator: coordinator);

      expect(await identity.ensureCoreAvailable(), isTrue);
      expect(coordinator.log, ['core']);
      expect(identity.signedIn, isFalse);
      expect(await identity.signInAnonymously(), isTrue);
      expect(coordinator.log, ['core', 'service-auth']);
      expect(identity.signedIn, isTrue);
    },
  );
}

final class _RecordingPreferences implements PlaceSearchPreferences {
  _RecordingPreferences({
    required this.log,
    this.consent,
    this.installId,
    this.consentWriteSucceeds = true,
    this.installIdWriteSucceeds = true,
    this.throwOnConsentWrite = false,
    this.throwOnInstallIdWrite = false,
  });

  List<String> log;
  PlaceSearchConsent? consent;
  String? installId;
  bool consentWriteSucceeds;
  bool installIdWriteSucceeds;
  bool throwOnConsentWrite;
  bool throwOnInstallIdWrite;
  final List<PlaceSearchConsent?> consentWrites = [];
  final List<String> installIdWrites = [];

  @override
  Future<PlaceSearchConsent?> loadPlaceSearchConsent() async {
    log.add('consent.read');
    return consent;
  }

  @override
  Future<bool> savePlaceSearchConsent(PlaceSearchConsent? value) async {
    log.add('consent.write:${value?.name ?? 'clear'}');
    consentWrites.add(value);
    if (throwOnConsentWrite) throw StateError('consent write failed');
    if (!consentWriteSucceeds) return false;
    consent = value;
    return true;
  }

  @override
  Future<String?> loadPlaceSearchInstallId() async {
    log.add('install.read');
    return installId;
  }

  @override
  Future<bool> savePlaceSearchInstallId(String value) async {
    log.add('install.write:$value');
    installIdWrites.add(value);
    if (throwOnInstallIdWrite) throw StateError('install write failed');
    if (!installIdWriteSucceeds) return false;
    installId = value;
    return true;
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
  int coreCalls = 0;

  @override
  Future<bool> ensureCoreAvailable() async {
    log.add('core');
    coreCalls += 1;
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

final class _RecordingAppCheckActivator
    implements PlaceSearchAppCheckActivator {
  _RecordingAppCheckActivator({List<Future<void>> gates = const []})
    : _gates = List<Future<void>>.of(gates);

  final List<Future<void>> _gates;
  final List<PlaceSearchAppCheckConfiguration> configurations = [];

  @override
  Future<void> activate(PlaceSearchAppCheckConfiguration configuration) async {
    configurations.add(configuration);
    if (_gates.isNotEmpty) await _gates.removeAt(0);
  }
}

final class _RecordingCloudCoordinator implements PlaceSearchCloudCoordinator {
  final List<String> log = [];
  bool _signedIn = false;

  @override
  bool get serviceIdentityReady => _signedIn;

  @override
  Future<bool> ensureCoreAvailable() async {
    log.add('core');
    return true;
  }

  @override
  Future<bool> ensureServiceIdentity() async {
    log.add('service-auth');
    _signedIn = true;
    return true;
  }
}
