import 'package:emberkeep/screens/shell.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'music foreground policy keeps a pending restore silent until resumed',
    () {
      expect(musicShouldRunForLifecycle(null), isFalse);
      expect(musicShouldRunForLifecycle(AppLifecycleState.inactive), isFalse);
      expect(musicShouldRunForLifecycle(AppLifecycleState.paused), isFalse);
      expect(musicShouldRunForLifecycle(AppLifecycleState.hidden), isFalse);
      expect(musicShouldRunForLifecycle(AppLifecycleState.resumed), isTrue);
    },
  );
}
