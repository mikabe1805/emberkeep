import 'package:flutter/material.dart';

import '../content/creature_skins.dart';
import '../content/room_styles.dart';
import '../tokens.dart';
import '../widgets/detail_header.dart';
import '../widgets/glass.dart';
import '../widgets/home_room.dart';

/// A read-only look at someone else's "Your Space" (round-52, social). Built
/// purely from the appearance fields in their shared room doc — no quests,
/// notes or account data ever travel.
class VisitRoomScreen extends StatelessWidget {
  const VisitRoomScreen({
    super.key,
    required this.room,
    required this.code,
    this.themeId,
    this.lively = true,
  });

  final Map<String, dynamic> room;
  final String code;

  /// The LOCAL user's canvas theme — the shared room doc carries no theme, so
  /// the visitor's own backdrop should hold instead of snapping to default.
  final String? themeId;

  /// The LOCAL user's reduce-motion setting — a friend's room should honour it
  /// just like every other surface (the room ambient + the companion park).
  final bool lively;

  @override
  Widget build(BuildContext context) {
    String safeString(String key, [String fallback = '']) {
      final value = room[key];
      return value is String ? value.trim() : fallback;
    }

    final name = safeString('name');
    final title = safeString('title');
    final rawLevel = room['level'];
    final level = rawLevel is num ? rawLevel.toInt().clamp(1, 9999) : 1;
    final rawFurniture = room['furniture'];
    final furniture = rawFurniture is List
        ? rawFurniture.whereType<String>().take(64).toSet()
        : <String>{};

    return Scaffold(
      backgroundColor: Palette.parchment,
      body: WarmBackground(
        themeId: themeId,
        reduceMotion: !lively,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 36),
            children: [
              DetailHeader(
                title: name.isNotEmpty ? '$name’s keep' : 'a keep',
                accent: Palette.xp,
                subtitle: 'visiting · $code',
                pill: 'LV $level',
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GlassPanel(
                  blur: true,
                  child: Column(
                    children: [
                      HomeRoom(
                        lively: lively,
                        unlocked: furniture,
                        wall: wallColorsById(safeString('wall')),
                        floor: floorColorsById(safeString('floor')),
                        window: safeString('window', 'moon'),
                        // the friend's hearth is lit if they're on a streak
                        petAwake: room['awake'] == true,
                        // their chosen hearth-flame colour
                        emberGlow: flameHueById(safeString('skin')),
                        heirloomFlame: safeString('skin') == 'gilded',
                      ),
                      const SizedBox(height: 14),
                      if (title.isNotEmpty)
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: Type.display.copyWith(
                            fontSize: 20,
                            color: Palette.xpLight,
                            letterSpacing: 1.5,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        '${furniture.length} pieces furnished',
                        style: Type.body.copyWith(
                          fontSize: 12,
                          color: Palette.textLo,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Center(
                child: Text(
                  'someone building their life, one ember at a time',
                  style: Type.body.copyWith(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Palette.textLo,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
