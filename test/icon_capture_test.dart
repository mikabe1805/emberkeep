// One-off: render the code-painted ember to a transparent 1024px PNG so the
// app-icon pipeline (tools/gen_icon_mascot.py) can composite it onto the warm
// candlelit background. Run:
//   flutter test test/icon_capture_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:emberkeep/widgets/portrait.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('capture the code ember for the app icon', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 1024));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final key = GlobalKey();
    await tester.pumpWidget(
      MediaQuery(
        // disable animations → the painter parks at its calm resting pose
        // (eyes open, flame at rest), so the capture is deterministic
        data: const MediaQueryData(disableAnimations: true),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: RepaintBoundary(
            key: key,
            child: const SizedBox(
              width: 1024,
              height: 1024,
              child: Portrait(size: 1024, level: 34, mood: PortraitMood.happy),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1.0);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final out = Directory('build').path;
      Directory(out).createSync(recursive: true);
      File('$out/code_ember.png')
          .writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  });
}
