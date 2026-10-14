// Every test in this folder runs with the Quests board as the whole page on a
// day with no classes, as it was before the Doorway room led (see
// QuestsPage.debugLegacyBoard). The room's own tests turn this off.
// Marking a Quest that fits a timer (reading, practice, a workout) would ask
// "Time it?" first (QuestsPage.debugAskTimerOnMark); the old tests mark those
// Quests directly, so it is off here, and the timer's own tests turn it on.
import 'dart:async';

import 'package:emberkeep/screens/quests.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  QuestsPage.debugLegacyBoard = true;
  QuestsPage.debugAskTimerOnMark = false;
  await testMain();
}
