import 'package:flutter_test/flutter_test.dart';

import 'package:emberkeep/content/ladders.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/tokens.dart';

void main() {
  test('a numbered prescription climbs a gentle, nicely rounded curve', () {
    expect(generatedLadder('Do 15 push-ups'), [
      'Do 15 push-ups',
      'Do 23 push-ups',
      'Do 35 push-ups',
      'Do 50 push-ups',
      'Do 75 push-ups',
    ]);
  });

  test('only the first number climbs; the words stay verbatim', () {
    final ladder = generatedLadder('Read 10 pages before 9pm')!;
    expect(ladder.first, 'Read 10 pages before 9pm');
    expect(ladder[1], 'Read 15 pages before 9pm');
    expect(ladder.every((rung) => rung.endsWith('before 9pm')), isTrue);
  });

  test('no number means no ladder — never a fake climb', () {
    expect(generatedLadder('Practice guitar'), isNull);
    expect(generatedLadder('Do 0 push-ups'), isNull);
  });

  test('a minutes-bearing generated ladder drives the timer', () {
    final quest = Quest(
      title: 'Practice 10 minutes of scales',
      stat: Stat.foc,
      difficulty: 3,
      custom: true,
      rising: true,
      verification: Verification.timer,
      timerMinutes: 10,
      ladder: generatedLadder('Practice 10 minutes of scales'),
    );
    expect(quest.effectiveTimerMinutes, 10);
    quest.rung = 1;
    expect(quest.effectiveTimerMinutes, 15);
    expect(quest.ladderOwnsTimer, isTrue);
  });
}
