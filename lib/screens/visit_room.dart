import 'package:flutter/material.dart';

import '../content/creature_skins.dart';
import '../content/room_styles.dart';
import '../content/space_themes.dart';
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
  /// just like every other surface (the room ambience and optional cat park).
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
    final rawMemories = room['memories'];
    final memories = rawMemories is num
        ? rawMemories.toInt().clamp(0, 9999)
        : 0;
    final focusUntil = room['focusUntil'] is num
        ? (room['focusUntil'] as num).toInt()
        : 0;
    final focusActive = focusUntil > DateTime.now().millisecondsSinceEpoch;
    final focusKind = safeString('focusKind', 'none');
    final weather = safeString('weather', 'unknown');
    final sharedTheme = spaceThemeById(safeString('wall')) ?? spaceThemes.first;

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
                        aspect: 1.5,
                        lively: lively,
                        unlocked: furniture,
                        wall: wallColorsById(sharedTheme.id),
                        plateId: sharedTheme.id,
                        floor: floorColorsById(safeString('floor')),
                        window: safeString('window', 'moon'),
                        level: level,
                        // the friend's cat may be awake if they're active
                        petAwake: room['awake'] == true,
                        // their chosen hearth-flame colour
                        emberGlow: flameHueById(safeString('skin')),
                        heirloomFlame: safeString('skin') == 'gilded',
                        memoryArtifacts: memories,
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
                        sharedTheme.name,
                        style: Type.body.copyWith(
                          fontSize: 12,
                          color: Palette.textLo,
                        ),
                      ),
                      if (memories > 0)
                        Text(
                          '$memories memories held',
                          style: Type.body.copyWith(
                            fontSize: 11.5,
                            color: Palette.textLo,
                          ),
                        ),
                      if (room['todayLit'] == true ||
                          weather != 'unknown' ||
                          focusActive) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 7,
                          runSpacing: 7,
                          children: [
                            if (room['todayLit'] == true)
                              _StatusChip(
                                icon: Icons.auto_awesome,
                                label: 'LIT TODAY',
                                color: Palette.streak,
                              ),
                            if (weather != 'unknown')
                              _StatusChip(
                                icon: weather == 'low'
                                    ? Icons.nightlight_outlined
                                    : weather == 'bright'
                                    ? Icons.wb_sunny_outlined
                                    : Icons.horizontal_rule,
                                label: '${weather.toUpperCase()} WEATHER',
                                color: weather == 'low'
                                    ? Stat.vit.color
                                    : weather == 'bright'
                                    ? Palette.streak
                                    : Palette.xpLight,
                              ),
                            if (focusActive)
                              _StatusChip(
                                icon: Icons.hourglass_top,
                                label: '${focusKind.toUpperCase()} COMPANY',
                                color: Palette.unlock,
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Center(
                child: Text(
                  'someone building their life, one quest at a time',
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

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.icon,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      border: Border.all(color: color.withValues(alpha: 0.34)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 5),
        Text(label, style: Type.label.copyWith(fontSize: 8.5, color: color)),
      ],
    ),
  );
}
