import 'dart:async';

import 'package:emberkeep/cloud.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DiscoveryWritePreparation', () {
    test('activates App Check before the protected write is allowed', () async {
      final calls = <String>[];
      final preparation = DiscoveryWritePreparation(
        ensureCore: () async {
          calls.add('core');
          return true;
        },
        activateAppCheck: () async {
          calls.add('app-check');
          return true;
        },
        ensureAvailable: () async {
          calls.add('available');
          return true;
        },
        ensureSocialSession: () async {
          calls.add('auth');
          return true;
        },
      );

      await preparation.run(() async {
        calls.add('write');
        return true;
      });

      expect(calls, ['core', 'app-check', 'available', 'auth', 'write']);
    });

    test('App Check failure blocks the write before auth', () async {
      final calls = <String>[];
      final preparation = DiscoveryWritePreparation(
        ensureCore: () async {
          calls.add('core');
          return true;
        },
        activateAppCheck: () async {
          calls.add('app-check');
          return false;
        },
        ensureAvailable: () async {
          calls.add('available');
          return true;
        },
        ensureSocialSession: () async {
          calls.add('auth');
          return true;
        },
      );

      final allowed = await preparation.run(() async {
        calls.add('write');
        return true;
      });

      expect(allowed, isFalse);
      expect(calls, ['core', 'app-check']);
    });

    test('coalesces simultaneous preparation but checks again later', () async {
      final calls = <String>[];
      final appCheckGate = Completer<void>();
      final preparation = DiscoveryWritePreparation(
        ensureCore: () async {
          calls.add('core');
          return true;
        },
        activateAppCheck: () async {
          calls.add('app-check');
          await appCheckGate.future;
          return true;
        },
        ensureAvailable: () async {
          calls.add('available');
          return true;
        },
        ensureSocialSession: () async {
          calls.add('auth');
          return true;
        },
      );

      final first = preparation.prepare();
      final second = preparation.prepare();
      expect(identical(first, second), isTrue);
      appCheckGate.complete();
      expect(await Future.wait([first, second]), [true, true]);
      expect(calls, ['core', 'app-check', 'available', 'auth']);

      expect(await preparation.prepare(), isTrue);
      expect(calls, [
        'core',
        'app-check',
        'available',
        'auth',
        'core',
        'app-check',
        'available',
        'auth',
      ]);
    });
  });
}
