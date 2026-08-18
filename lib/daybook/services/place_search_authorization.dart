import 'dart:async';

import 'place_search_service.dart';

typedef PlaceSearchRevocationListener = void Function();

/// Process-wide consent authorization for every live place-search object.
///
/// A lease is valid only for the generation in which consent was durably
/// accepted. Durable withdrawal advances the generation, immediately making
/// cached access objects, controllers, and callable wrappers fail closed.
final class PlaceSearchAuthorization {
  PlaceSearchAuthorization();

  static final PlaceSearchAuthorization shared = PlaceSearchAuthorization();

  int _generation = 0;
  bool _authorized = false;
  Future<void> _mutationTail = Future<void>.value();
  final Set<PlaceSearchRevocationListener> _revocationListeners = {};

  PlaceSearchConsentAttempt beginConsentAttempt() =>
      PlaceSearchConsentAttempt._(this, _generation);

  Future<PlaceSearchAuthorizationLease?> authorize({
    required PlaceSearchConsentAttempt attempt,
    Future<bool> Function()? persistConsent,
  }) => _serialize(() async {
    if (!_acceptsAttempt(attempt)) return null;
    if (persistConsent != null && !await persistConsent()) return null;
    if (!_acceptsAttempt(attempt)) return null;
    _authorized = true;
    return PlaceSearchAuthorizationLease._(this, _generation);
  });

  /// Revokes only after the caller confirms the local consent write.
  Future<bool> revoke(Future<bool> Function() persistWithdrawal) =>
      _serialize(() async {
        if (!await persistWithdrawal()) return false;
        _authorized = false;
        _generation += 1;
        final listeners = List<PlaceSearchRevocationListener>.of(
          _revocationListeners,
        );
        _revocationListeners.clear();
        for (final listener in listeners) {
          try {
            listener();
          } catch (_) {
            // One disposed/broken observer must not make durable withdrawal
            // appear to fail after the consent write already succeeded.
          }
        }
        return true;
      });

  bool _acceptsAttempt(PlaceSearchConsentAttempt attempt) =>
      identical(attempt._authorization, this) &&
      attempt._generation == _generation;

  bool _acceptsLease(PlaceSearchAuthorizationLease lease) =>
      _authorized &&
      identical(lease._authorization, this) &&
      lease._generation == _generation;

  void _addRevocationListener(
    PlaceSearchAuthorizationLease lease,
    PlaceSearchRevocationListener listener,
  ) {
    if (_acceptsLease(lease)) _revocationListeners.add(listener);
  }

  void _removeRevocationListener(PlaceSearchRevocationListener listener) =>
      _revocationListeners.remove(listener);

  Future<T> _serialize<T>(Future<T> Function() action) {
    final previous = _mutationTail;
    final operation = previous.then((_) => action());
    _mutationTail = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }
}

final class PlaceSearchConsentAttempt {
  const PlaceSearchConsentAttempt._(this._authorization, this._generation);

  final PlaceSearchAuthorization _authorization;
  final int _generation;
}

final class PlaceSearchAuthorizationLease {
  const PlaceSearchAuthorizationLease._(this._authorization, this._generation);

  final PlaceSearchAuthorization _authorization;
  final int _generation;

  bool get isValid => _authorization._acceptsLease(this);

  void addRevocationListener(PlaceSearchRevocationListener listener) =>
      _authorization._addRevocationListener(this, listener);

  void removeRevocationListener(PlaceSearchRevocationListener listener) =>
      _authorization._removeRevocationListener(listener);
}

/// Enforces the same consent lease before and after each protected request.
/// The post-check discards results from an uncancellable request that completed
/// after consent was withdrawn.
final class AuthorizedPlaceSearchService implements PlaceSearchService {
  const AuthorizedPlaceSearchService({
    required this.delegate,
    required this.authorization,
  });

  final PlaceSearchService delegate;
  final PlaceSearchAuthorizationLease authorization;

  @override
  Future<List<PlaceSuggestion>> autocomplete({
    required String query,
    required String sessionToken,
    required String installId,
    required String locale,
  }) async {
    _requireAuthorization();
    final result = await delegate.autocomplete(
      query: query,
      sessionToken: sessionToken,
      installId: installId,
      locale: locale,
    );
    _requireAuthorization();
    return result;
  }

  @override
  Future<PlaceSelection> details({
    required PlaceSuggestion suggestion,
    required String originalQuery,
    required String sessionToken,
    required String installId,
    required String locale,
  }) async {
    _requireAuthorization();
    final result = await delegate.details(
      suggestion: suggestion,
      originalQuery: originalQuery,
      sessionToken: sessionToken,
      installId: installId,
      locale: locale,
    );
    _requireAuthorization();
    return result;
  }

  void _requireAuthorization() {
    if (!authorization.isValid) throw const PlaceSearchUnavailable();
  }
}
