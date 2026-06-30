import 'package:flutter/material.dart';

import '../content/creature_skins.dart';
import '../content/room_styles.dart';
import '../tokens.dart';
import '../widgets/detail_header.dart';
import '../widgets/glass.dart';
import '../widgets/home_room.dart';
import '../widgets/portrait.dart';

/// A read-only look at someone else's "Your Space" (round-52, social). Built
/// purely from the appearance fields in their shared room doc — no quests,
/// notes or account data ever travel.
class VisitRoomScreen extends StatelessWidget {
  const VisitRoomScreen({super.key, required this.room, required this.code});

  final Map<String, dynamic> room;
  final String code;

  @override
  Widget build(BuildContext context) {
    final name = (room['name'] as String?)?.trim() ?? '';
    final title = (room['title'] as String?)?.trim() ?? '';
    final level = (room['level'] as num?)?.toInt() ?? 1;
    final furniture =
        ((room['furniture'] as List?) ?? const []).cast<String>().toSet();

    return Scaffold(
      backgroundColor: Palette.parchment,
      body: WarmBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 36),
            children: [
              DetailHeader(
                title: name.isNotEmpty ? '$name’s space' : 'a space',
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
                        unlocked: furniture,
                        wall: wallColorsById(room['wall'] as String?),
                        floor: floorColorsById(room['floor'] as String?),
                        window: room['window'] as String? ?? 'moon',
                        petAwake: room['awake'] == true,
                        child: Portrait(
                          size: 110,
                          level: level,
                          mood: PortraitMood.happy,
                          skin: creatureColorsById(room['skin'] as String?),
                        ),
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
                        style: Type.body
                            .copyWith(fontSize: 12, color: Palette.textLo),
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
