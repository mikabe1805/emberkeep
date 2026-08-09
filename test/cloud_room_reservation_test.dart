import 'package:emberkeep/cloud.dart';
import 'package:flutter_test/flutter_test.dart';

final class _Denied implements Exception {
  const _Denied(this.attempt);

  final int attempt;
}

final class _Offline implements Exception {
  const _Offline();
}

void main() {
  test(
    'fresh room reservation writes first and retries denied collisions',
    () async {
      final generated = <String>['ABC234', 'DEF567'];
      final writes = <String>[];

      final code = await reserveFreshRoomCode(
        generateCode: () => generated.removeAt(0),
        writeCode: (candidate) async {
          writes.add(candidate);
          if (candidate == 'ABC234') throw const _Denied(1);
        },
        shouldRetry: (error) => error is _Denied,
      );

      expect(code, 'DEF567');
      expect(writes, ['ABC234', 'DEF567']);
    },
  );

  test('fresh room reservation does not disguise a network failure', () async {
    var writes = 0;

    await expectLater(
      reserveFreshRoomCode(
        generateCode: () => 'ABC234',
        writeCode: (_) async {
          writes++;
          throw const _Offline();
        },
        shouldRetry: (error) => error is _Denied,
      ),
      throwsA(isA<_Offline>()),
    );
    expect(writes, 1);
  });

  test('fresh room reservation preserves the final denied failure', () async {
    var writes = 0;

    await expectLater(
      reserveFreshRoomCode(
        attempts: 3,
        generateCode: () => 'CODE${++writes}',
        writeCode: (_) async => throw _Denied(writes),
        shouldRetry: (error) => error is _Denied,
      ),
      throwsA(isA<_Denied>().having((error) => error.attempt, 'attempt', 3)),
    );
    expect(writes, 3);
  });

  test('fresh room reservation rejects an empty attempt budget', () async {
    await expectLater(
      reserveFreshRoomCode(
        attempts: 0,
        generateCode: () => 'ABC234',
        writeCode: (_) async {},
        shouldRetry: (_) => true,
      ),
      throwsArgumentError,
    );
  });
}
