import 'package:flutter/material.dart';

const stewardSupperRoomAsset = 'assets/pages/steward-supper-room-v2.webp';
const stewardSupperOfferingAsset =
    'assets/pages/steward-supper-offering-v2.webp';

Future<void> precacheStewardRoom(BuildContext context) async {
  await Future.wait([
    precacheImage(
      const AssetImage(stewardSupperRoomAsset),
      context,
      onError: (_, _) {}, // The visible image owns the graceful fallback.
    ),
    precacheImage(
      const AssetImage(stewardSupperOfferingAsset),
      context,
      onError: (_, _) {},
    ),
  ]);
}

/// The optional conversation has its own destination. Crossing one doorway
/// reveals that destination directly; it never tours the goal's apartment.
PageRoute<T> stewardRoomRoute<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool reduceMotion = false,
}) {
  final still =
      reduceMotion || (MediaQuery.maybeDisableAnimationsOf(context) ?? false);
  return PageRouteBuilder<T>(
    settings: const RouteSettings(name: '/goals/workshop/supper'),
    transitionDuration: Duration(milliseconds: still ? 180 : 720),
    reverseTransitionDuration: Duration(milliseconds: still ? 160 : 440),
    pageBuilder: (context, animation, _) => _StewardArrival(
      animation: animation,
      reduceMotion: still,
      child: builder(context),
    ),
    transitionsBuilder: (context, animation, _, child) {
      if (still) {
        return FadeTransition(
          key: const Key('steward-arrival-still'),
          opacity: animation.drive(CurveTween(curve: Curves.easeOutCubic)),
          child: child,
        );
      }
      return AnimatedBuilder(
        animation: animation,
        child: child,
        builder: (context, child) {
          // Pass through the dark jamb before revealing the seated figure.
          // This occludes the standing Steward first, so the two complete
          // paintings never splice their faces together during a crossing.
          final shade = Curves.easeInOut.transform(
            (animation.value / .35).clamp(0.0, 1.0),
          );
          final progress = Curves.easeInOutCubic.transform(
            ((animation.value - .2) / .8).clamp(0.0, 1.0),
          );
          return Stack(
            fit: StackFit.expand,
            children: [
              IgnorePointer(
                child: ColoredBox(
                  color: const Color(0xFF100D0B).withValues(alpha: shade),
                ),
              ),
              ClipRect(
                key: const Key('steward-doorway-reveal'),
                clipper: _DoorwayClipper(progress),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    child!,
                    if (progress > 0 && progress < 1)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(painter: _DoorwayEdge(progress)),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

class _StewardArrival extends InheritedWidget {
  const _StewardArrival({
    required this.animation,
    required this.reduceMotion,
    required super.child,
  });

  final Animation<double> animation;
  final bool reduceMotion;

  @override
  bool updateShouldNotify(_StewardArrival oldWidget) =>
      animation != oldWidget.animation ||
      reduceMotion != oldWidget.reduceMotion;
}

class _DoorwayClipper extends CustomClipper<Rect> {
  const _DoorwayClipper(this.progress);
  final double progress;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(size.width * (1 - progress), 0, size.width, size.height);

  @override
  bool shouldReclip(_DoorwayClipper oldClipper) =>
      progress != oldClipper.progress;
}

class _DoorwayEdge extends CustomPainter {
  const _DoorwayEdge(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final left = size.width * (1 - progress);
    final rect = Rect.fromLTWH(left, 0, 32, size.height);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xB8100906), Color(0x00100906)],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_DoorwayEdge oldDelegate) =>
      progress != oldDelegate.progress;
}

/// An intact, registered plate: no independently sliding furniture or cutouts.
/// The small approach ends at a composed still and stops rendering underneath
/// hidden routes. Pose changes are authored actions, never an idle mood loop.
class StewardRoomArtwork extends StatelessWidget {
  const StewardRoomArtwork({
    super.key,
    required this.offeringBread,
    required this.reduceMotion,
  });

  final bool offeringBread;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final arrival = context
        .dependOnInheritedWidgetOfExactType<_StewardArrival>();
    final animation = arrival?.animation ?? const AlwaysStoppedAnimation(1.0);
    final still = reduceMotion || (arrival?.reduceMotion ?? false);
    final asset = offeringBread
        ? stewardSupperOfferingAsset
        : stewardSupperRoomAsset;
    final art = Semantics(
      image: true,
      label: offeringBread
          ? 'The Steward slides a plate of bread toward your chair.'
          : 'The Steward sits by a rainy window, holding the cook’s note beside his supper.',
      child: AnimatedSwitcher(
        duration: Duration(milliseconds: still ? 0 : 180),
        child: Image.asset(
          asset,
          key: ValueKey(asset),
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          width: double.infinity,
          height: double.infinity,
          excludeFromSemantics: true,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFF1B130F)),
        ),
      ),
    );
    if (still) return art;
    return AnimatedBuilder(
      animation: animation,
      child: art,
      builder: (context, child) {
        final remaining = 1 - Curves.easeOutCubic.transform(animation.value);
        return ClipRect(
          child: Transform.scale(
            scale: 1 + .035 * remaining,
            alignment: const Alignment(.15, -.35),
            child: Transform.translate(
              offset: Offset(14 * remaining, 0),
              child: child,
            ),
          ),
        );
      },
    );
  }
}
