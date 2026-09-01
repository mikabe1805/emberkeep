import 'package:flutter/material.dart';

import '../engine.dart';
import 'space_themes.dart';

/// Board materials belonging to the selected complete room. The background,
/// HUD frame, XP rail and navigation trim follow that one room choice;
/// mechanic colours stay stable and readable.
class QuestDeskLook {
  const QuestDeskLook({
    required this.roomStyleId,
    required this.name,
    required this.textile,
    required this.future,
    required this.wood,
    required this.brass,
  });

  final String roomStyleId;
  final String name;
  final Color textile;
  final Color future;
  final Color wood;
  final Color brass;
}

const questDeskLooks = <QuestDeskLook>[
  QuestDeskLook(
    roomStyleId: 'wall_walnut',
    name: 'Writer’s Desk',
    textile: Color(0xFF6B463D),
    future: Color(0xFF3A2A2A),
    wood: Color(0xFF4A3024),
    brass: Color(0xFFD6A45C),
  ),
  QuestDeskLook(
    roomStyleId: 'wall_conservatory',
    name: 'Conservatory Ledger',
    textile: Color(0xFF687457),
    future: Color(0xFF28332B),
    wood: Color(0xFF51412B),
    brass: Color(0xFFD1AE70),
  ),
  QuestDeskLook(
    roomStyleId: 'wall_archive',
    name: 'Archive Ledger',
    textile: Color(0xFF56657B),
    future: Color(0xFF222A39),
    wood: Color(0xFF302C31),
    brass: Color(0xFFD4A35F),
  ),
  QuestDeskLook(
    roomStyleId: 'wall_listening',
    name: 'Listening Room',
    textile: Color(0xFF8A684B),
    future: Color(0xFF29252A),
    wood: Color(0xFF4B382B),
    brass: Color(0xFFD2A15B),
  ),
  QuestDeskLook(
    roomStyleId: 'wall_rain',
    name: 'Rain Room',
    textile: Color(0xFF617B80),
    future: Color(0xFF293739),
    wood: Color(0xFF4D342B),
    brass: Color(0xFFD2AF75),
  ),
  QuestDeskLook(
    roomStyleId: 'wall_atelier',
    name: 'Painter’s Loft',
    textile: Color(0xFF906B54),
    future: Color(0xFF382A2E),
    wood: Color(0xFF644432),
    brass: Color(0xFFDBAC68),
  ),
];

QuestDeskLook questDeskLookById(String? id) {
  for (final look in questDeskLooks) {
    if (look.roomStyleId == id) return look;
  }
  return questDeskLooks.first;
}

bool isQuestDeskLookOwned(GameState state, QuestDeskLook look) {
  return spaceThemeById(look.roomStyleId)?.price == 0 ||
      state.ownedStyles.contains(look.roomStyleId);
}

QuestDeskLook activeQuestDeskLook(GameState state) {
  // The Quest Desk is part of the room now. Keep reading the old persisted
  // field for migration/round-trip compatibility, but never let it split the
  // room identity from the wall the player selected in Your Space.
  final requested = questDeskLookById(state.wallStyle);
  return isQuestDeskLookOwned(state, requested)
      ? requested
      : questDeskLooks.first;
}
