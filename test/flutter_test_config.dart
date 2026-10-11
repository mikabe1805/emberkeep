// Every test in this folder runs with the Quests board as the whole page on a
// day with no classes, as it was before the Doorway room led (see
// QuestsPage.debugLegacyBoard). The room's own tests turn this off.
import 'dart:async';

import 'package:emberkeep/screens/quests.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  QuestsPage.debugLegacyBoard = true;
  await testMain();
}
