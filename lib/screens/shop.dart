import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio.dart';
import '../content/creature_skins.dart';
import '../content/space_themes.dart';
import '../engine.dart';
import '../haptics.dart';
import '../models.dart' show RoomStyleKind;
import '../tokens.dart';
import '../widgets/detail_header.dart';
import '../widgets/facets.dart';
import '../widgets/glass.dart';
import '../widgets/home_room.dart';
import '../widgets/honey_button.dart';

/// Three complete places, not a catalogue of chores. Every player begins in a
/// finished room; Glimmers unlock large authored transformations that can be
/// previewed before anything is spent.
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key, required this.state, required this.onPersist});

  final GameState state;
  final VoidCallback onPersist;

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  String? _busyTheme;

  GameState get state => widget.state;

  bool _owned(SpaceTheme theme) =>
      theme.price == 0 || state.ownedStyles.contains(theme.id);

  bool _applied(SpaceTheme theme) => state.wallStyle == theme.id;

  Future<bool> _commitTheme(SpaceTheme theme) async {
    if (_busyTheme != null) return false;
    setState(() => _busyTheme = theme.id);
    await preloadSpaceTheme(theme.id);
    if (!mounted) return false;

    final alreadyOwned = _owned(theme);
    final ok = alreadyOwned
        ? () {
            state.applyStyle(theme.id, RoomStyleKind.wall);
            return state.wallStyle == theme.id;
          }()
        : state.buyStyle(theme.id, theme.price, RoomStyleKind.wall);

    if (ok) {
      state.setQuestDeskStyle(theme.id);
      Sfx.instance.play(alreadyOwned ? 'tick' : 'loot');
      if (alreadyOwned) {
        Haptics.tap();
      } else {
        Haptics.success();
      }
      widget.onPersist();
    } else {
      Sfx.instance.play('boing');
      HapticFeedback.selectionClick();
    }

    if (mounted) setState(() => _busyTheme = null);
    return ok;
  }

  void _receipt(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Palette.card,
          duration: const Duration(milliseconds: 2600),
          content: Text(
            message,
            style: Type.body.copyWith(color: Palette.textHi),
          ),
        ),
      );
  }

  Future<void> _moveIn(SpaceTheme theme) async {
    final purchased = !_owned(theme);
    final ok = await _commitTheme(theme);
    if (!mounted || !ok) return;
    _receipt(
      purchased
          ? '${theme.name} is yours. You can return whenever you like.'
          : 'You moved into ${theme.name}.',
    );
  }

  Future<void> _showTheme(SpaceTheme theme) async {
    if (_busyTheme != null) return;
    Sfx.instance.play('tick');
    Haptics.tap();
    setState(() => _busyTheme = theme.id);
    await preloadSpaceTheme(theme.id);
    if (!mounted) return;
    setState(() => _busyTheme = null);
    await showDialog<void>(
      context: context,
      barrierColor: const Color(0xD9120C09),
      builder: (dialogContext) {
        final owned = _owned(theme);
        final applied = _applied(theme);
        final affordable = state.embers >= theme.price;
        final remaining = (theme.price - state.embers).clamp(0, theme.price);
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 24,
          ),
          backgroundColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: GlassPanel(
              blur: true,
              radius: 24,
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'STEP INSIDE',
                          textAlign: TextAlign.center,
                          style: Type.label.copyWith(
                            fontSize: 11,
                            letterSpacing: 2.4,
                            color: Palette.textMid,
                          ),
                        ),
                      ),
                      Semantics(
                        button: true,
                        label: 'Close room preview',
                        child: IconButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          icon: const Icon(Icons.close_rounded),
                          color: Palette.textMid,
                          iconSize: 20,
                          tooltip: 'Close',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  RepaintBoundary(
                    child: HomeRoom(
                      key: ValueKey('theme-preview-${theme.id}'),
                      aspect: 1.5,
                      lively: !state.reduceMotion,
                      unlocked: const {},
                      plateId: theme.id,
                      petAwake: state.streakDays > 0,
                      emberGlow: flameHueFor(state),
                      heirloomFlame: state.creatureSkin == 'gilded',
                      level: state.level,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    theme.name,
                    textAlign: TextAlign.center,
                    style: Type.display.copyWith(fontSize: 25),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    theme.subtitle,
                    textAlign: TextAlign.center,
                    style: Type.body.copyWith(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: Palette.textMid,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    theme.description,
                    textAlign: TextAlign.center,
                    style: Type.body.copyWith(
                      fontSize: 12.5,
                      color: Palette.textLo,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (applied)
                    HoneyButton(
                      label: 'THIS IS YOUR ROOM',
                      icon: Icons.check_rounded,
                      glow: false,
                      onTap: () => Navigator.of(dialogContext).pop(),
                    )
                  else if (owned)
                    HoneyButton(
                      label: 'MOVE IN',
                      icon: Icons.meeting_room_outlined,
                      onTap: () async {
                        final ok = await _commitTheme(theme);
                        if (!dialogContext.mounted || !ok) return;
                        Navigator.of(dialogContext).pop();
                        if (mounted) _receipt('You moved into ${theme.name}.');
                      },
                    )
                  else
                    HoneyButton(
                      enabled: affordable,
                      label: affordable
                          ? 'MAKE IT MINE · ${theme.price} GLIMMERS'
                          : '$remaining MORE GLIMMERS',
                      icon: Icons.key_outlined,
                      onTap: () async {
                        final ok = await _commitTheme(theme);
                        if (!dialogContext.mounted || !ok) return;
                        Navigator.of(dialogContext).pop();
                        if (mounted) {
                          _receipt(
                            '${theme.name} is yours. You can return whenever you like.',
                          );
                        }
                      },
                    ),
                  const SizedBox(height: 8),
                  Text(
                    owned
                        ? 'Switching rooms never costs anything again.'
                        : '${theme.price} Glimmers · you have ${state.embers}',
                    textAlign: TextAlign.center,
                    style: Type.label.copyWith(
                      fontSize: 10.5,
                      color: Palette.textLo,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final current = spaceThemeById(state.wallStyle) ?? spaceThemes.first;
        return Scaffold(
          backgroundColor: Palette.parchment,
          body: WarmBackground(
            themeId: state.canvasTheme,
            reduceMotion: state.reduceMotion,
            tint: current.accent,
            child: SafeArea(
              child: Column(
                children: [
                  DetailHeader(
                    title: 'Change your space',
                    accent: current.accent,
                    subtitle: 'three finished rooms, each ready to live in',
                    pill: '${state.embers} GLIMMERS',
                  ),
                  Expanded(
                    child: ListView(
                      key: const ValueKey('space-theme-list'),
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 46),
                      children: [
                        _CurrentRoom(
                          state: state,
                          theme: current,
                          busy: _busyTheme == current.id,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'CHOOSE A COMPLETE ROOM',
                          style: Type.label.copyWith(
                            fontSize: 11,
                            letterSpacing: 2.1,
                            color: Palette.xpLight,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Your first room is already lived in. Each key changes the whole atmosphere—furniture, materials, and light.',
                          style: Type.body.copyWith(
                            fontSize: 12.5,
                            color: Palette.textLo,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 14),
                        for (final theme in spaceThemes) ...[
                          _ThemeCard(
                            theme: theme,
                            owned: _owned(theme),
                            applied: _applied(theme),
                            busy: _busyTheme == theme.id,
                            onOpen: () => _showTheme(theme),
                            onMoveIn: () => _moveIn(theme),
                          ),
                          const SizedBox(height: 14),
                        ],
                        const SizedBox(height: 4),
                        const _KeepsakeNote(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CurrentRoom extends StatelessWidget {
  const _CurrentRoom({
    required this.state,
    required this.theme,
    required this.busy,
  });

  final GameState state;
  final SpaceTheme theme;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final duration = state.reduceMotion ? Duration.zero : Motion.settle;
    return GlassPanel(
      blur: true,
      radius: 22,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedSwitcher(
            duration: duration,
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: HomeRoom(
              key: ValueKey('current-space-${theme.id}'),
              aspect: 1.5,
              lively: !state.reduceMotion,
              unlocked: const {},
              plateId: theme.id,
              petAwake: state.streakDays > 0,
              emberGlow: flameHueFor(state),
              heirloomFlame: state.creatureSkin == 'gilded',
              level: state.level,
            ),
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'YOUR ROOM NOW',
                      style: Type.label.copyWith(
                        fontSize: 10,
                        color: theme.accent,
                        letterSpacing: 1.7,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      theme.name,
                      style: Type.display.copyWith(fontSize: 20),
                    ),
                  ],
                ),
              ),
              if (busy)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: Palette.xp,
                  ),
                )
              else
                Icon(Icons.check_rounded, size: 20, color: theme.accent),
            ],
          ),
        ],
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.theme,
    required this.owned,
    required this.applied,
    required this.busy,
    required this.onOpen,
    required this.onMoveIn,
  });

  final SpaceTheme theme;
  final bool owned;
  final bool applied;
  final bool busy;
  final VoidCallback onOpen;
  final VoidCallback onMoveIn;

  @override
  Widget build(BuildContext context) {
    final stateLabel = applied
        ? 'currently selected'
        : owned
        ? 'owned'
        : '${theme.price} Glimmers';
    return Semantics(
      button: true,
      label: '${theme.name}, ${theme.subtitle}, $stateLabel. Open preview.',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onOpen,
        child: GlassPanel(
          radius: 20,
          glow: applied,
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 1.5,
                    child: Image.asset(
                      theme.previewAsset,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.medium,
                      semanticLabel: '${theme.name} room preview',
                    ),
                  ),
                  Positioned(
                    left: 10,
                    top: 10,
                    child: _ImagePlate(
                      label: 'COMPLETE ROOM',
                      color: theme.accent,
                    ),
                  ),
                  if (applied)
                    Positioned(
                      right: 10,
                      top: 10,
                      child: _ImagePlate(
                        label: 'ON NOW',
                        color: Palette.success,
                        icon: Icons.check_rounded,
                      ),
                    ),
                ],
              ),
              Container(height: 1, color: theme.accent.withValues(alpha: 0.55)),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      theme.name,
                      style: Type.display.copyWith(fontSize: 21),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      theme.subtitle,
                      style: Type.body.copyWith(
                        fontSize: 12.5,
                        fontStyle: FontStyle.italic,
                        color: Palette.textMid,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      theme.description,
                      style: Type.body.copyWith(
                        fontSize: 12,
                        color: Palette.textLo,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 13),
                    Row(
                      children: [
                        Expanded(child: _price()),
                        const SizedBox(width: 12),
                        if (busy)
                          const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.7,
                              color: Palette.xp,
                            ),
                          )
                        else if (applied)
                          _StatusPill(label: 'YOUR ROOM', color: theme.accent)
                        else if (owned)
                          HoneyButton(
                            label: 'MOVE IN',
                            icon: Icons.meeting_room_outlined,
                            fontSize: 10.5,
                            glow: false,
                            onTap: onMoveIn,
                          )
                        else
                          HoneyButton(
                            label: 'TRY THE ROOM',
                            icon: Icons.visibility_outlined,
                            fontSize: 10.5,
                            glow: false,
                            onTap: onOpen,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _price() {
    if (applied) {
      return Text(
        'finished from the start',
        style: Type.label.copyWith(fontSize: 10.5, color: Palette.textLo),
      );
    }
    if (owned) {
      return Text(
        'YOURS · SWITCH ANY TIME',
        style: Type.label.copyWith(fontSize: 10.5, color: Palette.success),
      );
    }
    return Text(
      '${theme.price} GLIMMERS',
      style: Type.numerals.copyWith(fontSize: 12, color: Palette.xpLight),
    );
  }
}

class _ImagePlate extends StatelessWidget {
  const _ImagePlate({required this.label, required this.color, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: facetedDecoration(
      cut: 6,
      color: const Color(0xE81A1410),
      borderColor: color.withValues(alpha: 0.72),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
        ],
        Text(
          label,
          style: Type.label.copyWith(
            fontSize: 9,
            letterSpacing: 1.2,
            color: color,
          ),
        ),
      ],
    ),
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: facetedDecoration(
      cut: 7,
      color: color.withValues(alpha: 0.12),
      borderColor: color.withValues(alpha: 0.5),
    ),
    child: Text(label, style: Type.label.copyWith(fontSize: 10, color: color)),
  );
}

class _KeepsakeNote extends StatelessWidget {
  const _KeepsakeNote();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(13, 11, 13, 12),
    decoration: facetedDecoration(
      cut: 9,
      color: Palette.xp.withValues(alpha: 0.06),
      borderColor: Palette.brass.withValues(alpha: 0.26),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.bookmark_outline, size: 17, color: Palette.brass),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            'Your room is whole from the beginning. Milestones may leave a quiet keepsake behind.',
            style: Type.body.copyWith(
              fontSize: 11.5,
              color: Palette.textLo,
              height: 1.35,
            ),
          ),
        ),
      ],
    ),
  );
}
