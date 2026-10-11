// "Your space": the player's own room, behind a door of the mantel.
//
// Me's hero is the painted mantel, so the room the player has made (its wall
// style, furniture, window view, flame skin, the photo over the fireplace) is
// never on the mantel itself. YOUR SPACE opens this page, where the room is
// the hero: edge to edge from the top of the screen down past its middle, live
// (the hearth burns, the walnut room's planes move with the tilt and the
// scroll). Under it, in the same walnut glass as the rest of the house, the
// controls the old sheet held, unchanged in what they do.
//
// The room is code-painted on authored plates and the house is painted art, so
// the page does not pretend they are one picture: the room runs under the
// status bar, falls softly into the ground at its foot, and the glass rises
// over that foot with its own brass edge. Nothing is tinted over the room.
library;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../../../content/creature_skins.dart';
import '../../../content/memories.dart';
import '../../../content/room_styles.dart';
import '../../../content/space_themes.dart';
import '../../../content/themes.dart';
import '../../../engine.dart';
import '../../../models.dart';
import '../../../room_photo.dart';
import '../../class_day/class_day_room.dart' show ClassGlass;
import '../../home_room.dart';
import 'mantel_glass.dart';
import 'mantel_model.dart';

/// The page. [content] is the controls (the glass body under the heading); it
/// is rebuilt whenever the save changes, so a label that follows it (a shared
/// code, a Glimmer count) answers at once.
class YourSpacePage extends StatefulWidget {
  const YourSpacePage({
    super.key,
    required this.state,
    required this.quests,
    required this.parallax,
    required this.content,
  });

  final GameState state;

  /// The live board quests: the room counts what its Cabinet holds.
  final List<Quest> quests;

  /// The shell's tilt, for the room's camera and light.
  final ValueListenable<Offset> parallax;

  final WidgetBuilder content;

  @override
  State<YourSpacePage> createState() => _YourSpacePageState();
}

class _YourSpacePageState extends State<YourSpacePage> {
  final ScrollController _scroll = ScrollController();

  /// The scroll offset the walnut room's depth planes read.
  final ValueNotifier<double> _scrollPosition = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_trackScroll);
  }

  void _trackScroll() {
    if (!_scroll.hasClients) return;
    final next = _scroll.offset;
    if ((_scrollPosition.value - next).abs() >= 0.75) {
      _scrollPosition.value = next;
    }
  }

  @override
  void dispose() {
    _scroll.removeListener(_trackScroll);
    _scroll.dispose();
    _scrollPosition.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The room (a wall style bought or tried on in the shop) and its photo
    // answer the save at once, so the hero is already the new room when the
    // shop's page is gone.
    return ListenableBuilder(
      listenable: Listenable.merge([widget.state, RoomPhotoStore.instance]),
      builder: (context, _) => _page(context),
    );
  }

  Widget _page(BuildContext context) {
    final state = widget.state;
    final media = MediaQuery.of(context);
    final still = state.reduceMotion || media.disableAnimations;
    final heroHeight = YourSpaceFrame.heroHeight(media.size);
    final ambient = canvasThemeById(state.canvasTheme);
    final theme = spaceThemeById(state.wallStyle) ?? spaceThemes.first;
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: 'Your space',
      child: Scaffold(
        backgroundColor: ambient.top,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // The ground the room falls into: the player's own ambient night.
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [ambient.top, ambient.top, ambient.bottom],
                  // Solid through the room's foot, so its fall into the
                  // ground leaves no step.
                  stops: [
                    0,
                    (heroHeight / media.size.height).clamp(0.0, 1.0),
                    1,
                  ],
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: heroHeight,
              child: YourRoomHero(
                state: state,
                quests: widget.quests,
                theme: theme,
                ground: ambient.top,
                inset: media.padding.top,
                roomPhoto: RoomPhotoStore.instance.photo,
                parallax: still ? null : widget.parallax,
                scrollPosition: still ? null : _scrollPosition,
                scroll: still ? null : _scroll,
                lively: !still,
              ),
            ),
            ListView(
              key: const Key('your-space-scroll'),
              controller: _scroll,
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              padding: EdgeInsets.zero,
              children: [
                SizedBox(height: heroHeight - YourSpaceFrame.glassLift),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: YourSpaceFrame.glassInset,
                  ),
                  child: ClassGlass(
                    key: const Key('your-space-glass'),
                    padding: const EdgeInsets.fromLTRB(10, 17, 10, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        MantelHeading(
                          eyebrow: 'YOUR OWN ROOM',
                          title: 'Your space',
                          subtitle: theme.name,
                        ),
                        const SizedBox(height: 12),
                        widget.content(context),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: media.padding.bottom + 28),
              ],
            ),
            // The status bar reads on the room, and on whatever scrolls up
            // under it.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: media.padding.top + 36,
              child: IgnorePointer(
                child: _StatusFall(color: ambient.top, scroll: _scroll),
              ),
            ),
            Positioned(
              top: media.padding.top + YourSpaceFrame.backGap,
              left: 0,
              child: MantelBackPill(
                spoken: 'Back to the mantel',
                onTap: () => Navigator.of(context).maybePop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The player's room as the hero: a tall slice of the painting, camera on the
/// hearth, falling into [ground] at its foot. Public so the room can be
/// rendered on its own.
class YourRoomHero extends StatelessWidget {
  const YourRoomHero({
    super.key,
    required this.state,
    required this.quests,
    required this.theme,
    required this.ground,
    required this.inset,
    required this.roomPhoto,
    required this.parallax,
    required this.scrollPosition,
    required this.scroll,
    required this.lively,
  });

  final GameState state;
  final List<Quest> quests;
  final SpaceTheme theme;
  final Color ground;

  /// The status bar's height: the painting starts under it, out of the
  /// ground's dark, so the whole room (not its ceiling) is what the slice is.
  final double inset;

  /// The player's private photo over the fireplace, if they hung one.
  final RoomPhotoData? roomPhoto;
  final ValueListenable<Offset>? parallax;
  final ValueListenable<double>? scrollPosition;
  final ScrollController? scroll;
  final bool lively;

  @override
  Widget build(BuildContext context) {
    final aspect = state.wallStyle == 'wall_walnut' ? 1.7 : 1.5;
    return Semantics(
      image: true,
      label: 'Your room, ${theme.name}',
      child: ClipRect(
        child: LayoutBuilder(
          builder: (context, box) {
            final roomWidth = box.maxWidth;
            final slice = Size(roomWidth, box.maxHeight - inset);
            final x = YourSpaceFrame.cameraX(
              hero: slice,
              roomAspect: aspect,
              hearthX: theme.hearthAnchor.dx,
            );
            final y = YourSpaceFrame.cameraY(
              hero: slice,
              roomAspect: aspect,
              hearthY: theme.hearthAnchor.dy,
            );
            final room = FittedBox(
              fit: BoxFit.cover,
              alignment: Alignment(x, y),
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: roomWidth,
                height: roomWidth / aspect,
                child: HomeRoom(
                  key: const Key('your-space-room'),
                  aspect: aspect,
                  lively: lively,
                  unlocked: const {},
                  wall: wallColorsFor(state),
                  plateId: state.wallStyle,
                  floor: floorColorsFor(state),
                  window: state.windowScene,
                  petAwake: state.streakDays > 0,
                  emberGlow: flameHueFor(state),
                  heirloomFlame: heirloomFlameFor(state),
                  level: state.level,
                  memoryArtifacts: memoryArtifactCount(state, quests),
                  roomPhoto: roomPhoto,
                  parallax: parallax,
                  scrollPosition: scrollPosition,
                ),
              ),
            );
            final placed = Positioned(
              top: inset,
              left: 0,
              right: 0,
              bottom: 0,
              child: room,
            );
            return Stack(
              fit: StackFit.expand,
              children: [
                if (scroll case final controller?)
                  AnimatedBuilder(
                    animation: controller,
                    child: placed,
                    builder: (context, room) {
                      final offset = controller.hasClients
                          ? controller.offset.clamp(
                              0.0,
                              YourSpaceFrame.heroTravel,
                            )
                          : 0.0;
                      return Transform.translate(
                        key: const Key('your-space-hero-shift'),
                        offset: Offset(0, -offset * 0.075),
                        child: Stack(fit: StackFit.expand, children: [room!]),
                      );
                    },
                  )
                else
                  placed,
                // The painting comes up out of the dark under the status bar.
                Positioned(
                  left: 0,
                  right: 0,
                  top: inset,
                  height: 56,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      key: const Key('your-space-rise'),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [ground, ground.withValues(alpha: 0)],
                        ),
                      ),
                    ),
                  ),
                ),
                // The fall into the ground, under the glass that rises over
                // it. Ground colour only; nothing here is light.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 96,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      key: const Key('your-space-fall'),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [ground.withValues(alpha: 0), ground],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The soft dark under the status bar: light over the room at rest, denser as
/// the glass scrolls up beneath it.
class _StatusFall extends StatelessWidget {
  const _StatusFall({required this.color, required this.scroll});

  final Color color;
  final ScrollController scroll;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: scroll,
    builder: (context, _) {
      final offset = scroll.hasClients ? scroll.offset : 0.0;
      final t = (offset / 160).clamp(0.0, 1.0);
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              color.withValues(alpha: 0.55 + 0.41 * t),
              color.withValues(alpha: 0.3 + 0.5 * t),
              color.withValues(alpha: 0),
            ],
            stops: const [0, 0.6, 1],
          ),
        ),
      );
    },
  );
}
