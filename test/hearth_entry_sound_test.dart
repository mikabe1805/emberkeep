import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the hearth is a one-shot room-entry cue, never a looping room bed', () {
    final audio = File('lib/audio.dart').readAsStringSync();
    final shell = File('lib/screens/shell.dart').readAsStringSync();

    expect(audio, isNot(contains('ReleaseMode.loop')));
    expect(audio, isNot(contains('hearth_room.wav')));
    expect(audio, isNot(contains('setHearthRoomActive')));
    expect(shell, isNot(contains('setHearthRoomActive')));
    expect(shell, contains("Sfx.instance.play('hearth', volumeScale: 0.32)"));
    expect(
      RegExp(r"play\('hearth'").allMatches(shell),
      hasLength(1),
      reason: 'tab switching owns exactly one room-entry fire cue',
    );
  });
}
