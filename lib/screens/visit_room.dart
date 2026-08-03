import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../clock.dart';
import '../content/creature_skins.dart';
import '../content/room_styles.dart';
import '../content/space_themes.dart';
import '../engine.dart';
import '../tokens.dart';
import '../widgets/detail_header.dart';
import '../widgets/facets.dart';
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
    this.parallax,
    this.localState,
    this.onPersist,
  });

  final Map<String, dynamic> room;
  final String code;

  /// The LOCAL user's canvas theme — the shared room doc carries no theme, so
  /// the visitor's own backdrop should hold instead of snapping to default.
  final String? themeId;

  /// The LOCAL user's reduce-motion setting — a friend's room should honour it
  /// just like every other surface (the room ambience and optional cat park).
  final bool lively;
  final ValueListenable<Offset>? parallax;

  /// Supplying both values lets a one-off visitor keep this room in their
  /// trusted Circle. Circle-originated visits simply show it as already saved.
  final GameState? localState;
  final VoidCallback? onPersist;

  @override
  Widget build(BuildContext context) {
    String safeString(String key, [String fallback = '', int max = 80]) {
      final value = room[key];
      if (value is! String) return fallback;
      return String.fromCharCodes(value.trim().runes.take(max));
    }

    final profileVisible = room['profileVisible'] == true;
    final legacyName = safeString('name', '', 40);
    final displayName = profileVisible ? safeString('displayName', '', 40) : '';
    final name = displayName.isNotEmpty ? displayName : legacyName;
    final title = safeString('title', '', 64);
    final about = profileVisible ? safeString('about', '', 180) : '';
    final featuredGoals = <String>[];
    if (profileVisible && room['featuredGoals'] is List) {
      for (final raw in room['featuredGoals'] as List) {
        if (raw is! String) continue;
        final goal = String.fromCharCodes(raw.trim().runes.take(80));
        if (goal.isEmpty || featuredGoals.contains(goal)) continue;
        featuredGoals.add(goal);
        if (featuredGoals.length == 3) break;
      }
    }
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
    final focusActive = focusUntil > Clock.now().millisecondsSinceEpoch;
    final focusKind = safeString('focusKind', 'none');
    final weather = safeString('weather', 'unknown');
    final savedWall = safeString('wall');
    final migratedWall = switch (savedWall) {
      'wall_sage' || 'wall_clay' || 'wall_amber' => 'wall_conservatory',
      'wall_plum' || 'wall_indigo' || 'wall_berry' => 'wall_archive',
      _ => savedWall,
    };
    final sharedTheme = spaceThemeById(migratedWall) ?? spaceThemes.first;

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
                        parallax: lively ? parallax : null,
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
              if (profileVisible) ...[
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _VisitorProfileCard(
                    displayName: displayName,
                    about: about,
                    featuredGoals: featuredGoals,
                  ),
                ),
              ],
              if (localState != null && onPersist != null) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _KeepInCircleAction(
                    code: code,
                    state: localState!,
                    onPersist: onPersist!,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Shared room · Journal entries and photos, quests, and account details stay private',
                  textAlign: TextAlign.center,
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

class _VisitorProfileCard extends StatelessWidget {
  const _VisitorProfileCard({
    required this.displayName,
    required this.about,
    required this.featuredGoals,
  });

  final String displayName;
  final String about;
  final List<String> featuredGoals;

  @override
  Widget build(BuildContext context) {
    final hasDetails = about.isNotEmpty || featuredGoals.isNotEmpty;
    return GlassPanel(
      key: const ValueKey('visitor-profile-card'),
      blur: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final heading = Row(
                children: [
                  const Icon(
                    Icons.person_outline_rounded,
                    size: 17,
                    color: Palette.xpLight,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'ABOUT THIS SPACE',
                      style: Type.label.copyWith(
                        fontSize: 10,
                        letterSpacing: 1.5,
                        color: Palette.xpLight,
                      ),
                    ),
                  ),
                ],
              );
              final badge = Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: facetedDecoration(
                  cut: 5,
                  color: Palette.glassFill,
                  borderColor: Palette.glassEdge,
                ),
                child: Text(
                  'SHARED BY CHOICE',
                  style: Type.label.copyWith(
                    fontSize: 8,
                    letterSpacing: 0.8,
                    color: Palette.textLo,
                  ),
                ),
              );
              final compact =
                  MediaQuery.textScalerOf(context).scale(1) > 1.15 ||
                  constraints.maxWidth < 300;
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [heading, const SizedBox(height: 5), badge],
                );
              }
              return Row(
                children: [
                  Expanded(child: heading),
                  const SizedBox(width: 10),
                  badge,
                ],
              );
            },
          ),
          if (displayName.isNotEmpty) ...[
            const SizedBox(height: 11),
            Text(
              displayName,
              style: Type.display.copyWith(fontSize: 20, color: Palette.textHi),
            ),
          ],
          if (about.isNotEmpty) ...[
            const SizedBox(height: 7),
            Text(
              about,
              style: Type.body.copyWith(
                fontSize: 14,
                height: 1.45,
                color: Palette.textHi,
              ),
            ),
          ],
          if (featuredGoals.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'MAKING ROOM FOR',
              style: Type.label.copyWith(fontSize: 9, color: Palette.textLo),
            ),
            const SizedBox(height: 7),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final goal in featuredGoals)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: facetedDecoration(
                      cut: 7,
                      color: Palette.xp.withValues(alpha: 0.1),
                      borderColor: Palette.xp.withValues(alpha: 0.34),
                    ),
                    child: Text(
                      goal,
                      style: Type.body.copyWith(
                        fontSize: 11.5,
                        color: Palette.xpLight,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          if (!hasDetails && displayName.isEmpty) ...[
            const SizedBox(height: 9),
            Text(
              'This keeper chose to leave their door open.',
              style: Type.body.copyWith(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: Palette.textLo,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _KeepInCircleAction extends StatelessWidget {
  const _KeepInCircleAction({
    required this.code,
    required this.state,
    required this.onPersist,
  });

  final String code;
  final GameState state;
  final VoidCallback onPersist;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final normalized = code.trim().toUpperCase();
        final own = normalized == state.roomCode;
        final saved = state.hearthCircleCodes.contains(normalized);
        final full = !saved && state.hearthCircleCodes.length >= 5;
        final enabled = !own && !saved && !full;
        final label = own
            ? 'THIS IS YOUR SPACE'
            : saved
            ? 'IN YOUR CIRCLE'
            : full
            ? 'CIRCLE IS FULL'
            : 'KEEP IN MY CIRCLE';
        final detail = own
            ? 'You are visiting the room attached to your own share code.'
            : saved
            ? 'Saved with your trusted spaces.'
            : full
            ? 'Your Circle holds five spaces. Remove one before adding another.'
            : 'Save this space so it is easy to visit again.';
        final icon = own
            ? Icons.home_outlined
            : saved
            ? Icons.bookmark_added_outlined
            : full
            ? Icons.people_outline_rounded
            : Icons.bookmark_add_outlined;
        final accent = enabled ? Palette.xpLight : Palette.textLo;

        void add() {
          if (!enabled || !state.addCircleCode(normalized)) return;
          onPersist();
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(
              SnackBar(
                content: Text(
                  'Kept in your Circle',
                  style: Type.body.copyWith(color: Palette.textHi),
                ),
                backgroundColor: Palette.card,
                behavior: SnackBarBehavior.floating,
              ),
            );
        }

        return GlassPanel(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                button: true,
                enabled: enabled,
                label: label,
                child: GestureDetector(
                  key: const ValueKey('visit-room-circle-action'),
                  behavior: HitTestBehavior.opaque,
                  onTap: enabled ? add : null,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: facetedDecoration(
                        cut: 9,
                        color: enabled
                            ? Palette.xp.withValues(alpha: 0.12)
                            : Palette.glassFill,
                        borderColor: enabled
                            ? Palette.xp.withValues(alpha: 0.44)
                            : Palette.glassEdge,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(icon, size: 18, color: accent),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              label,
                              textAlign: TextAlign.center,
                              style: Type.label.copyWith(
                                fontSize: 10.5,
                                letterSpacing: 1.1,
                                color: accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 7),
              Text(
                detail,
                style: Type.body.copyWith(
                  fontSize: 11.5,
                  height: 1.35,
                  color: Palette.textLo,
                ),
              ),
            ],
          ),
        );
      },
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
