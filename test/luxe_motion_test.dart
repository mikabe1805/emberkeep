import 'package:emberkeep/widgets/luxe_depth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reflected light responds before the weightier room camera', () {
    final response = LuxeMotionResponse();
    const target = Offset(1, -0.5);

    final first = response.step(target);

    expect(first.light.dx, closeTo(0.46, 0.0001));
    expect(first.camera.dx, closeTo(0.18, 0.0001));
    expect(
      (target - first.light).distance,
      lessThan((target - first.camera).distance),
    );

    var settled = first;
    for (var frame = 0; frame < 12; frame++) {
      settled = response.step(target);
    }

    expect(
      (target - settled.light).distance,
      lessThan((target - settled.camera).distance),
    );
  });

  test('reduce motion immediately parks both motion planes', () {
    final controller = LuxeMotionController();
    addTearDown(controller.dispose);
    controller.parallax.value = const Offset(0.5, -0.25);
    controller.light.value = const Offset(-0.4, 0.7);

    controller.setReduceMotion(true);

    expect(controller.parallax.value, Offset.zero);
    expect(controller.light.value, Offset.zero);
  });
}
