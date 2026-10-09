import 'package:emberkeep/widgets/lamplight.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(
  Widget child, {
  double width = 325,
  double textScale = 1,
  bool disableAnimations = false,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(
        textScaler: TextScaler.linear(textScale),
        disableAnimations: disableAnimations,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF1B1310),
        body: Center(
          child: SizedBox(width: width, child: child),
        ),
      ),
    ),
  );
}

/// Bounds of the drawn outline (Path.getBounds includes control points).
Rect _tight(Path path) {
  Rect? out;
  for (final m in path.computeMetrics()) {
    for (var d = 0.0; d <= m.length; d += 0.5) {
      final p = m.getTangentForOffset(d)!.position;
      out = out == null
          ? Rect.fromLTWH(p.dx, p.dy, 0, 0)
          : out.expandToInclude(Rect.fromLTWH(p.dx, p.dy, 0, 0));
    }
  }
  return out!;
}

void main() {
  group('LampGeometry', () {
    const size = Size(325, 50);
    final path = LampGeometry.of(size, 10).path;

    test('stays inside its box', () {
      final b = _tight(path);
      expect(b.left, greaterThanOrEqualTo(-0.01));
      expect(b.top, greaterThanOrEqualTo(-0.01));
      expect(b.right, lessThanOrEqualTo(size.width + 0.01));
      expect(b.bottom, lessThanOrEqualTo(size.height + 0.2));
    });

    test('leans in toward the top and is not the chamfered plate', () {
      // The old plate filled its top-left corner square up to the chamfer;
      // the shade's side has already leaned in there.
      expect(path.contains(const Offset(3, 6)), isFalse);
      expect(path.contains(const Offset(3, 44)), isTrue);
      expect(path.contains(const Offset(322, 6)), isFalse);
      expect(path.contains(const Offset(322, 44)), isTrue);
    });

    test('the rims sag at their middle like the front arc of a cone', () {
      final g = LampGeometry.of(size, 10);
      expect(g.topY(size.width / 2), greaterThan(g.topY(g.taper)));
      expect(g.bottomY(size.width / 2), greaterThan(g.bottomY(0)));
      expect(path.contains(Offset(size.width / 2, 49)), isTrue);
      expect(path.contains(Offset(size.width / 2, 0.3)), isFalse);
    });

    test('is symmetric left to right', () {
      for (final y in [6.0, 25.0, 44.0]) {
        expect(
          path.contains(Offset(4, y)),
          path.contains(Offset(size.width - 4, y)),
          reason: 'y=$y',
        );
      }
    });

    test('the border and the clipper agree with the geometry', () {
      const border = LampShadeBorder(cut: 10);
      final outer = border.getOuterPath(const Rect.fromLTWH(10, 20, 325, 50));
      expect(_tight(outer).left, closeTo(10, 2));
      expect(_tight(outer).top, closeTo(20, 0.5));
      expect(
        _tight(const LampShadeClipper(cut: 10).getClip(size)).size,
        _tight(path).size,
      );
    });

    test('a tiny inset lamp (the ledger card) is nearly square', () {
      final g = LampGeometry.of(const Size(200, 40), 3);
      expect(g.taper, lessThan(3));
      expect(g.sag, lessThan(1.5));
    });
  });

  group('LampShade', () {
    for (final level in LampLevel.values) {
      testWidgets('${level.name} paints and settles with nothing on a clock', (
        tester,
      ) async {
        final light = ValueNotifier(const Offset(0.3, 0.1));
        final scroll = ValueNotifier(0.0);
        addTearDown(light.dispose);
        addTearDown(scroll.dispose);
        await tester.pumpWidget(
          _host(
            LampShade(
              level: level,
              light: light,
              scroll: scroll,
              child: Padding(
                padding: const EdgeInsets.all(13),
                child: LampLabel(text: 'I WAS THERE', level: level),
              ),
            ),
          ),
        );
        // Parked: no animation of any kind is left running.
        await tester.pumpAndSettle(const Duration(seconds: 1));
        expect(tester.hasRunningAnimations, isFalse);
        expect(tester.takeException(), isNull);
        // The light only moves when its input moves.
        light.value = const Offset(-0.7, 0.2);
        scroll.value = 140;
        await tester.pump();
        await tester.pumpAndSettle(const Duration(seconds: 1));
        expect(tester.hasRunningAnimations, isFalse);
      });
    }

    testWidgets('contact turns the light up at once, release eases back', (
      tester,
    ) async {
      Widget lamp(bool pressed) => _host(
        LampShade(
          pressed: pressed,
          child: const Padding(
            padding: EdgeInsets.all(13),
            child: LampLabel(text: 'MARK COMPLETE'),
          ),
        ),
      );
      await tester.pumpWidget(lamp(false));
      await tester.pumpAndSettle();
      await tester.pumpWidget(lamp(true));
      // No tween while a finger is down: the very first frame is lit.
      expect(tester.hasRunningAnimations, isFalse);
      await tester.pumpWidget(lamp(false));
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('Reduce Motion: the state change is instant, the core parks', (
      tester,
    ) async {
      Widget lamp(LampLevel level) => _host(
        disableAnimations: true,
        LampShade(
          level: level,
          dimFrom: LampShade.warmthFor(LampLevel.lit),
          light: ValueNotifier(const Offset(0.9, 0.2)),
          child: const Padding(
            padding: EdgeInsets.all(13),
            child: LampLabel(text: 'QUEST COMPLETE', icon: Icons.check_rounded),
          ),
        ),
      );
      await tester.pumpWidget(lamp(LampLevel.low));
      expect(tester.hasRunningAnimations, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('130% text wraps inside the lamp without overflowing', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          width: 240,
          textScale: 1.3,
          const LampShade(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: LampLabel(text: 'ADD 4 COURSES', icon: Icons.event),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(LampShade)).width, 240);
    });
  });
}
