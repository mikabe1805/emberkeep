import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:emberkeep/daybook/services/firebase_place_search_service.dart';
import 'package:emberkeep/daybook/services/place_search_controller.dart';
import 'package:emberkeep/daybook/services/place_search_service.dart';

void main() {
  const installId = '3fa85f64-5717-4562-b3fc-2c963f66afa6';

  test('place selections persist only user-authored place fields', () {
    const selection = PlaceSelection(
      provider: 'google',
      placeId: 'place-id',
      originalQuery: '  The exact thing I typed  ',
      primaryText: 'Google supplied name',
      secondaryText: 'Google supplied address',
    );

    final place = selection.toPersistedPlace(
      routingText: 'My routing note',
      building: 'My building',
      room: 'My room',
    );

    expect(place.savedName, '  The exact thing I typed  ');
    expect(place.providerPlaceId, 'place-id');
    expect(place.routingText, 'My routing note');
    expect(place.building, 'My building');
    expect(place.room, 'My room');
    expect(place.toJson().values, isNot(contains('Google supplied name')));
    expect(place.toJson().values, isNot(contains('Google supplied address')));
  });

  test(
    'controller waits for the debounce and shares one session token',
    () async {
      final service = _RecordingService();
      final controller = PlaceSearchController(
        service: service,
        installId: installId,
        locale: 'en-US',
        debounce: const Duration(milliseconds: 5),
        createSessionToken: () => '11111111-1111-4111-8111-111111111111',
      );
      addTearDown(controller.dispose);

      controller.updateQuery('  ab ');
      await Future<void>.delayed(const Duration(milliseconds: 8));
      expect(service.autocompleteCalls, isEmpty);

      controller.updateQuery('  abc ');
      await Future<void>.delayed(const Duration(milliseconds: 1));
      expect(service.autocompleteCalls, isEmpty);
      await Future<void>.delayed(const Duration(milliseconds: 8));

      expect(service.autocompleteCalls, hasLength(1));
      expect(service.autocompleteCalls.single.query, 'abc');
      expect(
        service.autocompleteCalls.single.sessionToken,
        '11111111-1111-4111-8111-111111111111',
      );
      controller.updateQuery('  abcd ');
      await Future<void>.delayed(const Duration(milliseconds: 8));
      expect(service.autocompleteCalls, hasLength(2));
      expect(
        service.autocompleteCalls.last.sessionToken,
        service.autocompleteCalls.first.sessionToken,
      );
    },
  );

  test(
    'selection calls details once with the current raw query and ends session',
    () async {
      final service = _RecordingService();
      final tokens = [
        '11111111-1111-4111-8111-111111111111',
        '22222222-2222-4222-8222-222222222222',
      ].iterator;
      final controller = PlaceSearchController(
        service: service,
        installId: installId,
        locale: 'en-US',
        debounce: Duration.zero,
        createSessionToken: () {
          tokens.moveNext();
          return tokens.current;
        },
      );
      addTearDown(controller.dispose);

      controller.updateQuery('  cafe  ');
      await _flush();
      final suggestion = controller.state.suggestions.single;
      await Future.wait([
        controller.selectSuggestion(suggestion),
        controller.selectSuggestion(suggestion),
      ]);

      expect(service.detailsCalls, hasLength(1));
      expect(service.detailsCalls.single.originalQuery, '  cafe  ');
      expect(
        service.detailsCalls.single.sessionToken,
        '11111111-1111-4111-8111-111111111111',
      );
      expect(controller.state.selection!.originalQuery, '  cafe  ');

      controller.updateQuery('library');
      await _flush();
      expect(
        service.autocompleteCalls.last.sessionToken,
        '22222222-2222-4222-8222-222222222222',
      );
    },
  );

  test(
    'stale autocomplete and unavailable detail never overwrite current state',
    () async {
      final service = _RecordingService(deferAutocomplete: true);
      final controller = PlaceSearchController(
        service: service,
        installId: installId,
        locale: 'en-US',
        debounce: Duration.zero,
        createSessionToken: () => '11111111-1111-4111-8111-111111111111',
      );
      addTearDown(controller.dispose);

      controller.updateQuery('first');
      await _flush();
      controller.updateQuery('second');
      await _flush();
      service.completeAutocomplete(0);
      await _flush();
      expect(controller.state.suggestions, isEmpty);
      service.completeAutocomplete(1);
      await _flush();
      expect(controller.state.suggestions.single.primaryText, 'second');

      service.failDetails = true;
      await controller.selectSuggestion(controller.state.suggestions.single);
      expect(
        controller.state.errorMessage,
        'Search unavailable — type the location instead.',
      );
    },
  );

  test(
    'callable service uses fixed names, payloads, timeout, and result cap',
    () async {
      final client = _RecordingCallableClient(
        results: [
          List<Object?>.generate(6, (index) => _payload('place-$index')),
          _payload('place-0'),
        ],
      );
      final service = FirebasePlaceSearchService(client: client);
      const token = '11111111-1111-4111-8111-111111111111';

      final suggestions = await service.autocomplete(
        query: ' Rutgers ',
        sessionToken: token,
        installId: installId,
        locale: 'en-US',
      );
      final selection = await service.details(
        suggestion: suggestions.first,
        originalQuery: ' Rutgers ',
        sessionToken: token,
        installId: installId,
        locale: 'en-US',
      );

      expect(suggestions, hasLength(5));
      expect(selection.originalQuery, ' Rutgers ');
      expect(client.calls.map((call) => call.name), [
        'placesAutocomplete',
        'placesDetails',
      ]);
      expect(client.calls.first.data, {
        'query': ' Rutgers ',
        'sessionToken': token,
        'installId': installId,
        'locale': 'en-US',
      });
      expect(client.calls.last.data, {
        'placeId': 'place-0',
        'sessionToken': token,
        'installId': installId,
        'locale': 'en-US',
      });
      expect(
        client.calls.every(
          (call) => call.timeout == const Duration(seconds: 8),
        ),
        isTrue,
      );
    },
  );

  test(
    'callable failures and malformed payloads become typed unavailable',
    () async {
      const token = '11111111-1111-4111-8111-111111111111';
      for (final result in <Object?>[
        TimeoutException('timeout'),
        StateError('quota'),
        StateError('app check'),
        StateError('unconfigured'),
        {'placeId': 'missing-primary'},
      ]) {
        final service = FirebasePlaceSearchService(
          client: _RecordingCallableClient(results: [result]),
        );
        expect(
          () => service.autocomplete(
            query: 'Rutgers',
            sessionToken: token,
            installId: installId,
            locale: 'en-US',
          ),
          throwsA(isA<PlaceSearchUnavailable>()),
        );
      }
    },
  );

  test(
    'manual clear and disposal invalidate pending autocomplete work',
    () async {
      final service = _RecordingService(deferAutocomplete: true);
      final controller = PlaceSearchController(
        service: service,
        installId: installId,
        locale: 'en-US',
        debounce: Duration.zero,
        createSessionToken: () => '11111111-1111-4111-8111-111111111111',
      );
      controller.updateQuery('library');
      await _flush();
      controller.clear();
      service.completeAutocomplete(0);
      await _flush();
      expect(controller.state.suggestions, isEmpty);

      controller.updateQuery('library');
      await _flush();
      controller.dispose();
      service.completeAutocomplete(1);
      await _flush();
      expect(controller.state.query, 'library');
    },
  );

  test('an old suggestion cannot call Details after a new query', () async {
    final service = _RecordingService();
    final controller = PlaceSearchController(
      service: service,
      installId: installId,
      locale: 'en-US',
      debounce: Duration.zero,
      createSessionToken: () => '11111111-1111-4111-8111-111111111111',
    );
    addTearDown(controller.dispose);

    controller.updateQuery('first');
    await _flush();
    final oldSuggestion = controller.state.suggestions.single;
    controller.updateQuery('second');
    await _flush();

    expect(await controller.selectSuggestion(oldSuggestion), isNull);
    expect(service.detailsCalls, isEmpty);
  });

  test(
    'controller caps a valid service response at five suggestions',
    () async {
      final service = _RecordingService(resultCount: 6);
      final controller = PlaceSearchController(
        service: service,
        installId: installId,
        locale: 'en-US',
        debounce: Duration.zero,
        createSessionToken: () => '11111111-1111-4111-8111-111111111111',
      );
      addTearDown(controller.dispose);

      controller.updateQuery('library');
      await _flush();

      expect(controller.state.suggestions, hasLength(5));
    },
  );

  test('stale Details completion and disposal cannot update state', () async {
    final service = _RecordingService(deferDetails: true);
    final controller = PlaceSearchController(
      service: service,
      installId: installId,
      locale: 'en-US',
      debounce: Duration.zero,
      createSessionToken: () => '11111111-1111-4111-8111-111111111111',
    );

    controller.updateQuery('first');
    await _flush();
    final firstSelection = controller.selectSuggestion(
      controller.state.suggestions.single,
    );
    controller.updateQuery('second');
    await _flush();
    service.completeDetails(0);
    expect(await firstSelection, isNull);
    expect(controller.state.selection, isNull);

    final secondSelection = controller.selectSuggestion(
      controller.state.suggestions.single,
    );
    controller.dispose();
    service.completeDetails(1);
    expect(await secondSelection, isNull);
  });

  test(
    'callable response maps reject unknown keys and invalid values',
    () async {
      const token = '11111111-1111-4111-8111-111111111111';
      final invalidAutocompleteItems = <Object?>[
        {'placeId': 'place-id', 'primaryText': 'Name', 'provider': 'google'},
        {'placeId': 'place-id', 'primaryText': 'Name', 'extra': 'nope'},
        {'placeId': 'invalid place id', 'primaryText': 'Name'},
        {'placeId': 'x' * 256, 'primaryText': 'Name'},
        {'placeId': 'place-id', 'primaryText': '   '},
        {'placeId': 'place-id', 'primaryText': 'Name', 'secondaryText': '  '},
      ];
      for (final item in invalidAutocompleteItems) {
        final service = FirebasePlaceSearchService(
          client: _RecordingCallableClient(
            results: [
              <Object?>[item],
            ],
          ),
        );
        await expectLater(
          service.autocomplete(
            query: 'Rutgers',
            sessionToken: token,
            installId: installId,
            locale: 'en-US',
          ),
          throwsA(isA<PlaceSearchUnavailable>()),
        );
      }

      final details = FirebasePlaceSearchService(
        client: _RecordingCallableClient(
          results: [
            {'placeId': 'place-id', 'primaryText': 'Name', 'unexpected': true},
          ],
        ),
      );
      await expectLater(
        details.details(
          suggestion: const PlaceSuggestion(
            provider: 'google',
            placeId: 'place-id',
            primaryText: 'Suggestion',
          ),
          originalQuery: 'Rutgers',
          sessionToken: token,
          installId: installId,
          locale: 'en-US',
        ),
        throwsA(isA<PlaceSearchUnavailable>()),
      );

      final mismatchedDetails = FirebasePlaceSearchService(
        client: _RecordingCallableClient(
          results: [_payload('different-place')],
        ),
      );
      await expectLater(
        mismatchedDetails.details(
          suggestion: const PlaceSuggestion(
            provider: 'google',
            placeId: 'place-id',
            primaryText: 'Suggestion',
          ),
          originalQuery: 'Rutgers',
          sessionToken: token,
          installId: installId,
          locale: 'en-US',
        ),
        throwsA(isA<PlaceSearchUnavailable>()),
      );
    },
  );

  test('a hanging callable is bounded by the injected timeout', () async {
    final service = FirebasePlaceSearchService(
      client: _HangingCallableClient(),
      timeout: const Duration(milliseconds: 5),
    );
    await expectLater(
      service.autocomplete(
        query: 'Rutgers',
        sessionToken: '11111111-1111-4111-8111-111111111111',
        installId: installId,
        locale: 'en-US',
      ),
      throwsA(isA<PlaceSearchUnavailable>()),
    );
  });

  test(
    'disabled service returns no suggestions without callable work',
    () async {
      const service = DisabledPlaceSearchService();
      expect(
        await service.autocomplete(
          query: 'Rutgers',
          sessionToken: '11111111-1111-4111-8111-111111111111',
          installId: installId,
          locale: 'en-US',
        ),
        isEmpty,
      );
    },
  );
}

Future<void> _flush() => Future<void>.delayed(const Duration(milliseconds: 1));

final class _Call {
  const _Call(this.query, this.sessionToken);
  final String query;
  final String sessionToken;
}

final class _DetailsCall {
  const _DetailsCall(this.originalQuery, this.sessionToken);
  final String originalQuery;
  final String sessionToken;
}

Map<String, Object?> _payload(String placeId) => {
  'placeId': placeId,
  'primaryText': 'Provider $placeId',
  'secondaryText': 'Provider address',
};

final class _CallableCall {
  const _CallableCall(this.name, this.data, this.timeout);
  final String name;
  final Map<String, Object?> data;
  final Duration timeout;
}

final class _RecordingCallableClient implements PlaceCallableClient {
  _RecordingCallableClient({required List<Object?> results})
    : _results = List<Object?>.of(results);

  final List<Object?> _results;
  final List<_CallableCall> calls = [];

  @override
  Future<Object?> call(
    String name,
    Map<String, Object?> data, {
    required Duration timeout,
  }) async {
    calls.add(_CallableCall(name, Map<String, Object?>.of(data), timeout));
    final result = _results.removeAt(0);
    if (result case Exception value) throw value;
    if (result case Error value) throw value;
    return result;
  }
}

final class _HangingCallableClient implements PlaceCallableClient {
  @override
  Future<Object?> call(
    String name,
    Map<String, Object?> data, {
    required Duration timeout,
  }) => Completer<Object?>().future;
}

final class _RecordingService implements PlaceSearchService {
  _RecordingService({
    this.deferAutocomplete = false,
    this.deferDetails = false,
    this.resultCount = 1,
  });

  final bool deferAutocomplete;
  final bool deferDetails;
  final int resultCount;
  final List<_Call> autocompleteCalls = [];
  final List<_DetailsCall> detailsCalls = [];
  final List<Completer<List<PlaceSuggestion>>> _autocompleteCompleters = [];
  final List<Completer<PlaceSelection>> _detailsCompleters = [];
  bool failDetails = false;

  @override
  Future<List<PlaceSuggestion>> autocomplete({
    required String query,
    required String sessionToken,
    required String installId,
    required String locale,
  }) {
    autocompleteCalls.add(_Call(query, sessionToken));
    if (!deferAutocomplete) {
      return Future.value(
        List.generate(resultCount, (index) => _suggestion('$query-$index')),
      );
    }
    final completer = Completer<List<PlaceSuggestion>>();
    _autocompleteCompleters.add(completer);
    return completer.future;
  }

  void completeAutocomplete(int index) {
    _autocompleteCompleters[index].complete([
      _suggestion(index == 0 ? 'first' : 'second'),
    ]);
  }

  @override
  Future<PlaceSelection> details({
    required PlaceSuggestion suggestion,
    required String originalQuery,
    required String sessionToken,
    required String installId,
    required String locale,
  }) async {
    detailsCalls.add(_DetailsCall(originalQuery, sessionToken));
    if (failDetails) throw const PlaceSearchUnavailable();
    final selection = PlaceSelection(
      provider: suggestion.provider,
      placeId: suggestion.placeId,
      originalQuery: originalQuery,
      primaryText: suggestion.primaryText,
      secondaryText: suggestion.secondaryText,
    );
    if (!deferDetails) return selection;
    final completer = Completer<PlaceSelection>();
    _detailsCompleters.add(completer);
    return completer.future;
  }

  void completeDetails(int index) => _detailsCompleters[index].complete(
    PlaceSelection(
      provider: 'google',
      placeId: 'place-details-$index',
      originalQuery: 'details $index',
      primaryText: 'details $index',
    ),
  );

  PlaceSuggestion _suggestion(String query) => PlaceSuggestion(
    provider: 'google',
    placeId: 'place-$query',
    primaryText: query,
  );
}
