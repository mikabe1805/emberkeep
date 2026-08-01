import 'package:flutter/material.dart';

import '../engine.dart';

/// A quiet cosmetic bridge between Your Space and the main quest board.
///
/// Quest Desk looks reuse wall styles the player already owns. They only tint
/// the HUD frame, XP rail, card finish, and selected navigation trim;
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
];

QuestDeskLook questDeskLookById(String? id) {
  for (final look in questDeskLooks) {
    if (look.roomStyleId == id) return look;
  }
  return questDeskLooks.first;
}

bool isQuestDeskLookOwned(GameState state, QuestDeskLook look) {
  return look.roomStyleId == 'wall_walnut' ||
      state.ownedStyles.contains(look.roomStyleId);
}

QuestDeskLook activeQuestDeskLook(GameState state) {
  final requested = questDeskLookById(state.questDeskStyle);
  return isQuestDeskLookOwned(state, requested)
      ? requested
      : questDeskLooks.first;
}
