// The short dark fade above the dock, and when it is allowed to show.
//
// Content that scrolls under the dock used to be cut mid-glyph at the dock's
// hard top edge, so the shell lays a warm fade over the 34 pt above the dock.
// In the house that fade also sat over every room's *resting* glass (the
// Journal's last recent row, a card's lower edge), which read dim for no
// reason: nothing was passing under the dock.
//
// So the fade is tied to the thing it is for. A room's own vertical scroll
// that reaches the dock raises it as content is carried up under the dock
// (over its first 34 pt of travel) and lets it go again as the scroll comes
// to its end. At rest, and in any room that does not scroll under the dock,
// the fade is not there and the painted plate and the glass resting on it are
// shown as they are.
//
// Inner scrolls that end above the dock (a list inside a page of the Plans
// book, say) never count: their content is not passing under the dock.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// How far a scroll has to carry content before the fade is whole, in points
/// (the fade's own height).
const houseDockFadeHeight = 34.0;

/// Tracks, per room, how much content is being carried under the dock.
class HouseDockFadeController extends ChangeNotifier {
  /// Marks the fade's band, whose bottom edge is the dock's top edge.
  final GlobalKey bandKey = GlobalKey(debugLabel: 'house-dock-fade-band');

  final Map<int, Map<BuildContext, double>> _levels = {};
  bool _disposed = false;

  /// 0 (nothing passes under the dock) to 1 (the fade is whole) for [tab].
  double levelFor(int tab) {
    final scrolls = _levels[tab];
    if (scrolls == null || scrolls.isEmpty) return 0;
    scrolls.removeWhere((context, _) => !context.mounted);
    var level = 0.0;
    for (final value in scrolls.values) {
      level = math.max(level, value);
    }
    return level;
  }

  /// A scroll in [tab] reported its [metrics]; [context] is the scrollable's.
  void report(int tab, BuildContext? context, ScrollMetrics metrics) {
    if (_disposed ||
        context == null ||
        !context.mounted ||
        metrics.axis != Axis.vertical) {
      return;
    }
    // A scroll can report while the frame is still being laid out, when no
    // render box's size may be read; the measure waits for the frame's end.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback(
        (_) => report(tab, context, metrics),
      );
      return;
    }
    final level = _levelOf(context, metrics);
    final scrolls = _levels.putIfAbsent(tab, () => {});
    final before = scrolls[context] ?? 0;
    if (level == 0) {
      scrolls.remove(context);
    } else {
      scrolls[context] = level;
    }
    if ((before - level).abs() < 0.004) return;
    notifyListeners();
  }

  double _levelOf(BuildContext context, ScrollMetrics metrics) {
    final box = context.findRenderObject();
    final band = bandKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return 0;
    if (band is! RenderBox || !band.attached || !band.hasSize) return 0;
    final dockTop = band.localToGlobal(Offset(0, band.size.height)).dy;
    final bottom = box.localToGlobal(Offset(0, box.size.height)).dy;
    // A scroll that ends above the dock has nothing passing under it.
    if (bottom < dockTop - 1) return 0;
    final carried = (metrics.extentBefore / houseDockFadeHeight).clamp(
      0.0,
      1.0,
    );
    final ahead = (metrics.extentAfter / houseDockFadeHeight).clamp(0.0, 1.0);
    return carried * ahead;
  }

  @override
  void dispose() {
    _disposed = true;
    _levels.clear();
    super.dispose();
  }
}

/// Hears the vertical scrolls of one room and tells [controller] about them.
class HouseDockFadeListener extends StatelessWidget {
  const HouseDockFadeListener({
    super.key,
    required this.controller,
    required this.tab,
    required this.child,
  });

  final HouseDockFadeController controller;
  final int tab;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (notification) {
        controller.report(tab, notification.context, notification.metrics);
        return false;
      },
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          controller.report(tab, notification.context, notification.metrics);
          return false;
        },
        child: child,
      ),
    );
  }
}

/// The fade itself: a `Positioned` for the shell's stack, [bottom] points up
/// from the bottom of the screen (the dock's height).
class HouseDockFade extends StatelessWidget {
  const HouseDockFade({
    super.key,
    required this.controller,
    required this.tab,
    required this.bottom,
  });

  final HouseDockFadeController controller;
  final int tab;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: bottom,
      height: houseDockFadeHeight,
      child: IgnorePointer(
        key: controller.bandKey,
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) => AnimatedOpacity(
            key: const ValueKey('house-dock-fade'),
            opacity: controller.levelFor(tab),
            duration: const Duration(milliseconds: 120),
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x0017120F), Color(0xE617120F)],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
