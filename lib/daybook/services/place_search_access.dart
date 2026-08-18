import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../cloud.dart';
import '../../release_features.dart';
import '../data/daybook_preferences.dart';
import 'place_search_authorization.dart';

export '../data/daybook_preferences.dart' show PlaceSearchConsent;

enum PlaceSearchConsentDecision { accept, decline }

typedef PlaceSearchConsentRequest =
    Future<PlaceSearchConsentDecision?> Function();
typedef PlaceSearchInstallIdFactory = String Function();

sealed class PlaceSearchAccessResult {
  const PlaceSearchAccessResult();
}

final class PlaceSearchReady extends PlaceSearchAccessResult {
  const PlaceSearchReady({
    required this.installId,
    required this.authorization,
  });

  /// Random app-install state used for server-side abuse limits. It is not a
  /// hardware identifier and is created only after accepted consent/readiness.
  final String installId;
  final PlaceSearchAuthorizationLease authorization;
}

final class PlaceSearchDisabled extends PlaceSearchAccessResult {
  const PlaceSearchDisabled();
}

final class PlaceSearchDeclined extends PlaceSearchAccessResult {
  const PlaceSearchDeclined();
}

final class PlaceSearchUnavailable extends PlaceSearchAccessResult {
  const PlaceSearchUnavailable();
}

abstract interface class PlaceSearchIdentity {
  bool get signedIn;
  Future<bool> ensureCoreAvailable();
  Future<bool> signInAnonymously();
}

abstract interface class PlaceSearchCloudCoordinator {
  bool get serviceIdentityReady;
  Future<bool> ensureCoreAvailable();
  Future<bool> ensureServiceIdentity();
}

final class CloudSyncPlaceSearchCoordinator
    implements PlaceSearchCloudCoordinator {
  CloudSyncPlaceSearchCoordinator({CloudSync? cloud})
    : _cloud = cloud ?? CloudSync.instance;

  final CloudSync _cloud;

  @override
  bool get serviceIdentityReady => _cloud.socialReady;

  @override
  Future<bool> ensureCoreAvailable() => _cloud.ensureCoreAvailable();

  @override
  Future<bool> ensureServiceIdentity() => _cloud.ensureServiceIdentity();
}

/// Uses CloudSync's single Core/bootstrap/auth actor. Place search must never
/// create a competing FirebaseAuth session or initialize Firebase in main().
final class CloudPlaceSearchIdentity implements PlaceSearchIdentity {
  CloudPlaceSearchIdentity({PlaceSearchCloudCoordinator? coordinator})
    : _coordinator = coordinator ?? CloudSyncPlaceSearchCoordinator();

  final PlaceSearchCloudCoordinator _coordinator;

  @override
  bool get signedIn => _coordinator.serviceIdentityReady;

  @override
  Future<bool> ensureCoreAvailable() => _coordinator.ensureCoreAvailable();

  @override
  Future<bool> signInAnonymously() => _coordinator.ensureServiceIdentity();
}

abstract interface class PlaceSearchAppCheck {
  Future<bool> activate();
}

enum PlaceSearchAppCheckPlatform { android, apple, web, unsupported }

enum PlaceSearchAppCheckProvider {
  playIntegrity,
  appAttestWithDeviceCheckFallback,
  recaptchaV3,
  debug,
}

final class PlaceSearchAppCheckConfiguration {
  const PlaceSearchAppCheckConfiguration({
    required this.platform,
    required this.provider,
    this.webSiteKey,
  });

  final PlaceSearchAppCheckPlatform platform;
  final PlaceSearchAppCheckProvider provider;
  final String? webSiteKey;
}

abstract interface class PlaceSearchAppCheckActivator {
  Future<void> activate(PlaceSearchAppCheckConfiguration configuration);
}

final class FlutterFirePlaceSearchAppCheckActivator
    implements PlaceSearchAppCheckActivator {
  @override
  Future<void> activate(PlaceSearchAppCheckConfiguration configuration) {
    final debug = configuration.provider == PlaceSearchAppCheckProvider.debug;
    return FirebaseAppCheck.instance.activate(
      providerWeb: configuration.platform == PlaceSearchAppCheckPlatform.web
          ? (debug
                ? WebDebugProvider()
                : ReCaptchaV3Provider(configuration.webSiteKey!))
          : null,
      providerAndroid:
          configuration.platform == PlaceSearchAppCheckPlatform.android && debug
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
      providerApple:
          configuration.platform == PlaceSearchAppCheckPlatform.apple && debug
          ? const AppleDebugProvider()
          : const AppleAppAttestWithDeviceCheckFallbackProvider(),
    );
  }
}

/// Activates attestation lazily after Firebase Core and before auth/callables.
/// Callable enforcement remains a server deployment gate; early builds use
/// monitor mode, not weakened client providers.
final class FirebasePlaceSearchAppCheck implements PlaceSearchAppCheck {
  factory FirebasePlaceSearchAppCheck({
    PlaceSearchAppCheckPlatform? platform,
    String webSiteKey = kPlaceSearchAppCheckWebSiteKey,
    bool useDebugProvider = kPlaceSearchAppCheckDebug,
    Duration timeout = const Duration(seconds: 8),
    PlaceSearchAppCheckActivator? activator,
  }) => FirebasePlaceSearchAppCheck._(
    platform ?? _currentPlatform,
    webSiteKey.trim(),
    useDebugProvider,
    timeout,
    activator ?? FlutterFirePlaceSearchAppCheckActivator(),
  );

  FirebasePlaceSearchAppCheck._(
    this._platform,
    this._webSiteKey,
    this._useDebugProvider,
    this._timeout,
    this._activator,
  );

  final PlaceSearchAppCheckPlatform _platform;
  final String _webSiteKey;
  final bool _useDebugProvider;
  final Duration _timeout;
  final PlaceSearchAppCheckActivator _activator;
  bool _activated = false;
  Future<bool>? _activationFuture;
  Future<void>? _providerActivationFuture;

  static PlaceSearchAppCheckPlatform get _currentPlatform {
    if (kIsWeb) return PlaceSearchAppCheckPlatform.web;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => PlaceSearchAppCheckPlatform.android,
      TargetPlatform.iOS => PlaceSearchAppCheckPlatform.apple,
      _ => PlaceSearchAppCheckPlatform.unsupported,
    };
  }

  @override
  Future<bool> activate() {
    if (_activated) return Future.value(true);
    final active = _activationFuture;
    if (active != null) return active;
    late final Future<bool> attempt;
    attempt = _activateOnce().whenComplete(() {
      if (identical(_activationFuture, attempt)) _activationFuture = null;
    });
    _activationFuture = attempt;
    return attempt;
  }

  Future<bool> _activateOnce() async {
    final configuration = _configuration;
    if (configuration == null) return false;
    final providerActivation = _providerActivationFuture ??=
        _startProviderActivation(configuration);
    try {
      await providerActivation.timeout(_timeout);
      return _activated;
    } on TimeoutException {
      // The provider call cannot be cancelled. Keep its underlying Future so
      // a retry waits on the same activation instead of racing a duplicate.
      return false;
    } catch (error) {
      debugPrint('Place search App Check unavailable: $error');
      return false;
    }
  }

  PlaceSearchAppCheckConfiguration? get _configuration {
    if (_platform == PlaceSearchAppCheckPlatform.unsupported) return null;
    if (_platform == PlaceSearchAppCheckPlatform.web && _webSiteKey.isEmpty) {
      return null;
    }
    final provider = _useDebugProvider
        ? PlaceSearchAppCheckProvider.debug
        : switch (_platform) {
            PlaceSearchAppCheckPlatform.android =>
              PlaceSearchAppCheckProvider.playIntegrity,
            PlaceSearchAppCheckPlatform.apple =>
              PlaceSearchAppCheckProvider.appAttestWithDeviceCheckFallback,
            PlaceSearchAppCheckPlatform.web =>
              PlaceSearchAppCheckProvider.recaptchaV3,
            PlaceSearchAppCheckPlatform.unsupported => throw StateError(
              'Unsupported App Check platform.',
            ),
          };
    return PlaceSearchAppCheckConfiguration(
      platform: _platform,
      provider: provider,
      webSiteKey: provider == PlaceSearchAppCheckProvider.recaptchaV3
          ? _webSiteKey
          : null,
    );
  }

  Future<void> _startProviderActivation(
    PlaceSearchAppCheckConfiguration configuration,
  ) {
    late final Future<void> tracked;
    tracked = Future<void>.sync(() => _activator.activate(configuration)).then(
      (_) {
        _activated = true;
        if (identical(_providerActivationFuture, tracked)) {
          _providerActivationFuture = null;
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (identical(_providerActivationFuture, tracked)) {
          _providerActivationFuture = null;
        }
        Error.throwWithStackTrace(error, stackTrace);
      },
    );
    return tracked;
  }
}

final class PlaceSearchAccess {
  factory PlaceSearchAccess({
    required bool enabled,
    required PlaceSearchPreferences preferences,
    required PlaceSearchIdentity identity,
    required PlaceSearchAppCheck appCheck,
    required PlaceSearchConsentRequest requestConsent,
    PlaceSearchInstallIdFactory? createInstallId,
    PlaceSearchAuthorization? authorization,
  }) => PlaceSearchAccess._(
    enabled,
    preferences,
    identity,
    appCheck,
    requestConsent,
    createInstallId ?? const Uuid().v4,
    authorization ?? PlaceSearchAuthorization(),
  );

  PlaceSearchAccess._(
    this._enabled,
    this._preferences,
    this._identity,
    this._appCheck,
    this._requestConsent,
    this._createInstallId,
    this._authorization,
  );

  factory PlaceSearchAccess.production({
    required PlaceSearchConsentRequest requestConsent,
    PlaceSearchPreferences? preferences,
    PlaceSearchAuthorization? authorization,
  }) {
    return PlaceSearchAccess(
      enabled: kPlaceSearchEnabled,
      preferences: preferences ?? LocalDaybookPreferences(),
      identity: CloudPlaceSearchIdentity(),
      appCheck: FirebasePlaceSearchAppCheck(),
      requestConsent: requestConsent,
      authorization: authorization ?? PlaceSearchAuthorization.shared,
    );
  }

  final bool _enabled;
  final PlaceSearchPreferences _preferences;
  final PlaceSearchIdentity _identity;
  final PlaceSearchAppCheck _appCheck;
  final PlaceSearchConsentRequest _requestConsent;
  final PlaceSearchInstallIdFactory _createInstallId;
  final PlaceSearchAuthorization _authorization;
  Future<PlaceSearchAccessResult>? _ensureFuture;
  PlaceSearchReady? _ready;

  Future<PlaceSearchAccessResult> ensureReady() {
    if (!_enabled) return Future.value(const PlaceSearchDisabled());
    final active = _ensureFuture;
    if (active != null) return active;
    late final Future<PlaceSearchAccessResult> attempt;
    attempt = _ensureReadyOnce().whenComplete(() {
      if (identical(_ensureFuture, attempt)) _ensureFuture = null;
    });
    _ensureFuture = attempt;
    return attempt;
  }

  Future<PlaceSearchAccessResult> _ensureReadyOnce() async {
    final ready = _ready;
    if (ready != null &&
        ready.authorization.isValid &&
        await ready.authorization.validateDurableConsent() &&
        ready.authorization.isValid) {
      return ready;
    }
    _ready = null;

    final attempt = _authorization.beginConsentAttempt();
    final durablePreferences =
        _preferences is DurablePlaceSearchConsentPreferences
        ? _preferences as DurablePlaceSearchConsentPreferences
        : null;
    var durableGrant = await durablePreferences?.loadPlaceSearchConsentGrant();
    final consent = durablePreferences == null
        ? await _preferences.loadPlaceSearchConsent()
        : durableGrant == null
        ? null
        : PlaceSearchConsent.acceptedV1;
    if (consent != PlaceSearchConsent.acceptedV1) {
      final decision = await _requestConsent();
      if (decision != PlaceSearchConsentDecision.accept) {
        return const PlaceSearchDeclined();
      }
    }

    late final PlaceSearchAuthorizationLease? authorization;
    try {
      authorization = await _authorization.authorize(
        attempt: attempt,
        persistConsent: consent == PlaceSearchConsent.acceptedV1
            ? null
            : durablePreferences == null
            ? () => _preferences.savePlaceSearchConsent(
                PlaceSearchConsent.acceptedV1,
              )
            : () async {
                durableGrant = await durablePreferences
                    .acceptPlaceSearchConsent();
                return durableGrant != null;
              },
        validateDurableConsent: durablePreferences == null
            ? () async =>
                  await _preferences.loadPlaceSearchConsent() ==
                  PlaceSearchConsent.acceptedV1
            : () async {
                final expected = durableGrant;
                if (expected == null) return false;
                return (await durablePreferences.loadPlaceSearchConsentGrant())
                        ?.raw ==
                    expected.raw;
              },
      );
    } catch (error) {
      debugPrint('Place search consent could not be saved: $error');
      return const PlaceSearchUnavailable();
    }
    if (authorization == null || !authorization.isValid) {
      return const PlaceSearchUnavailable();
    }

    try {
      if (!authorization.isValid ||
          !await _identity.ensureCoreAvailable() ||
          !authorization.isValid) {
        return const PlaceSearchUnavailable();
      }
      if (!await _appCheck.activate() || !authorization.isValid) {
        return const PlaceSearchUnavailable();
      }
      if (!_identity.signedIn &&
          (!authorization.isValid ||
              !await _identity.signInAnonymously() ||
              !authorization.isValid)) {
        return const PlaceSearchUnavailable();
      }

      if (!authorization.isValid ||
          !await authorization.validateDurableConsent() ||
          !authorization.isValid) {
        return const PlaceSearchUnavailable();
      }
      var installId = await _preferences.loadPlaceSearchInstallId();
      if (!authorization.isValid) return const PlaceSearchUnavailable();
      if (!_isUuidV4(installId)) {
        final generated = _createInstallId();
        if (!_isUuidV4(generated)) return const PlaceSearchUnavailable();
        if (!authorization.isValid ||
            !await _preferences.savePlaceSearchInstallId(generated) ||
            !authorization.isValid) {
          return const PlaceSearchUnavailable();
        }
        installId = generated;
      }
      if (!authorization.isValid) return const PlaceSearchUnavailable();
      final result = PlaceSearchReady(
        installId: installId!,
        authorization: authorization,
      );
      _ready = result;
      return result;
    } catch (error) {
      debugPrint('Place search access unavailable: $error');
      return const PlaceSearchUnavailable();
    }
  }

  Future<bool> withdrawConsent() async {
    try {
      if (!await _authorization.revoke(
        () => _preferences is DurablePlaceSearchConsentPreferences
            ? (_preferences as DurablePlaceSearchConsentPreferences)
                  .withdrawPlaceSearchConsent()
            : _preferences.savePlaceSearchConsent(null),
      )) {
        return false;
      }
    } catch (error) {
      debugPrint('Place search consent could not be withdrawn: $error');
      return false;
    }
    _ready = null;
    return true;
  }

  static bool _isUuidV4(String? value) {
    if (value == null) return false;
    try {
      return UuidValue.withValidation(value).version == 4;
    } on FormatException {
      return false;
    }
  }
}
