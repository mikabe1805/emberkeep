import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../cloud.dart';
import '../../release_features.dart';
import '../data/daybook_preferences.dart';

export '../data/daybook_preferences.dart' show PlaceSearchConsent;

enum PlaceSearchConsentDecision { accept, decline }

typedef PlaceSearchConsentRequest =
    Future<PlaceSearchConsentDecision?> Function();
typedef PlaceSearchInstallIdFactory = String Function();

sealed class PlaceSearchAccessResult {
  const PlaceSearchAccessResult();
}

final class PlaceSearchReady extends PlaceSearchAccessResult {
  const PlaceSearchReady({required this.installId});

  /// Random app-install state used for server-side abuse limits. It is not a
  /// hardware identifier and is created only after accepted consent/readiness.
  final String installId;
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

/// Uses CloudSync's single Core/bootstrap/auth actor. Place search must never
/// create a competing FirebaseAuth session or initialize Firebase in main().
final class CloudPlaceSearchIdentity implements PlaceSearchIdentity {
  CloudPlaceSearchIdentity({CloudSync? cloud})
    : _cloud = cloud ?? CloudSync.instance;

  final CloudSync _cloud;

  @override
  bool get signedIn => _cloud.socialReady;

  @override
  Future<bool> ensureCoreAvailable() => _cloud.ensureAvailable();

  @override
  Future<bool> signInAnonymously() => _cloud.ensureSocialSession();
}

abstract interface class PlaceSearchAppCheck {
  Future<bool> activate();
}

enum PlaceSearchAppCheckPlatform { android, apple, web, unsupported }

/// Activates attestation lazily after Firebase Core and before auth/callables.
/// Callable enforcement remains a server deployment gate; early builds use
/// monitor mode, not weakened client providers.
final class FirebasePlaceSearchAppCheck implements PlaceSearchAppCheck {
  factory FirebasePlaceSearchAppCheck({
    PlaceSearchAppCheckPlatform? platform,
    String webSiteKey = kPlaceSearchAppCheckWebSiteKey,
    bool useDebugProvider = kPlaceSearchAppCheckDebug,
  }) => FirebasePlaceSearchAppCheck._(
    platform ?? _currentPlatform,
    webSiteKey.trim(),
    useDebugProvider,
  );

  FirebasePlaceSearchAppCheck._(
    this._platform,
    this._webSiteKey,
    this._useDebugProvider,
  );

  final PlaceSearchAppCheckPlatform _platform;
  final String _webSiteKey;
  final bool _useDebugProvider;
  bool _activated = false;
  Future<bool>? _activationFuture;

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
    if (_platform == PlaceSearchAppCheckPlatform.unsupported) return false;
    if (_platform == PlaceSearchAppCheckPlatform.web && _webSiteKey.isEmpty) {
      return false;
    }
    try {
      await FirebaseAppCheck.instance.activate(
        providerWeb: _platform == PlaceSearchAppCheckPlatform.web
            ? (_useDebugProvider
                  ? WebDebugProvider()
                  : ReCaptchaV3Provider(_webSiteKey))
            : null,
        providerAndroid: _useDebugProvider
            ? const AndroidDebugProvider()
            : const AndroidPlayIntegrityProvider(),
        providerApple: _useDebugProvider
            ? const AppleDebugProvider()
            : const AppleAppAttestWithDeviceCheckFallbackProvider(),
      );
      _activated = true;
      return true;
    } catch (error) {
      debugPrint('Place search App Check unavailable: $error');
      return false;
    }
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
  }) => PlaceSearchAccess._(
    enabled,
    preferences,
    identity,
    appCheck,
    requestConsent,
    createInstallId ?? const Uuid().v4,
  );

  PlaceSearchAccess._(
    this._enabled,
    this._preferences,
    this._identity,
    this._appCheck,
    this._requestConsent,
    this._createInstallId,
  );

  factory PlaceSearchAccess.production({
    required PlaceSearchConsentRequest requestConsent,
    PlaceSearchPreferences? preferences,
  }) {
    return PlaceSearchAccess(
      enabled: kPlaceSearchEnabled,
      preferences: preferences ?? LocalDaybookPreferences(),
      identity: CloudPlaceSearchIdentity(),
      appCheck: FirebasePlaceSearchAppCheck(),
      requestConsent: requestConsent,
    );
  }

  final bool _enabled;
  final PlaceSearchPreferences _preferences;
  final PlaceSearchIdentity _identity;
  final PlaceSearchAppCheck _appCheck;
  final PlaceSearchConsentRequest _requestConsent;
  final PlaceSearchInstallIdFactory _createInstallId;
  Future<PlaceSearchAccessResult>? _ensureFuture;
  PlaceSearchReady? _ready;

  Future<PlaceSearchAccessResult> ensureReady() {
    if (!_enabled) return Future.value(const PlaceSearchDisabled());
    final ready = _ready;
    if (ready != null) return Future.value(ready);
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
    final consent = await _preferences.loadPlaceSearchConsent();
    if (consent != PlaceSearchConsent.acceptedV1) {
      final decision = await _requestConsent();
      if (decision != PlaceSearchConsentDecision.accept) {
        return const PlaceSearchDeclined();
      }
      await _preferences.savePlaceSearchConsent(PlaceSearchConsent.acceptedV1);
    }

    try {
      if (!await _identity.ensureCoreAvailable()) {
        return const PlaceSearchUnavailable();
      }
      if (!await _appCheck.activate()) {
        return const PlaceSearchUnavailable();
      }
      if (!_identity.signedIn && !await _identity.signInAnonymously()) {
        return const PlaceSearchUnavailable();
      }

      var installId = await _preferences.loadPlaceSearchInstallId();
      if (!_isUuidV4(installId)) {
        final generated = _createInstallId();
        if (!_isUuidV4(generated)) return const PlaceSearchUnavailable();
        await _preferences.savePlaceSearchInstallId(generated);
        installId = generated;
      }
      final result = PlaceSearchReady(installId: installId!);
      _ready = result;
      return result;
    } catch (error) {
      debugPrint('Place search access unavailable: $error');
      return const PlaceSearchUnavailable();
    }
  }

  Future<void> withdrawConsent() async {
    final active = _ensureFuture;
    if (active != null) await active;
    await _preferences.savePlaceSearchConsent(null);
    _ready = null;
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
