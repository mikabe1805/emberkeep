import 'package:emberkeep/widgets/luxe_depth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reflected light responds before the weightier room camera', () {
    final response = LuxeMotionResponse();
    const target = Offset(1, -0.5);

    final first = response.step(target);

    expect(first.light.dx, closeTo(0.26, 0.0001));
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

  test('motion filter ignores hand tremor and eases intentional tilts', () {
    expect(calmMotionTarget(const Offset(0.04, -0.06)), Offset.zero);

    final small = calmMotionTarget(const Offset(0.25, 0));
    final large = calmMotionTarget(const Offset(0.8, 0));
    expect(small.dx, greaterThan(0));
    expect(small.dx, lessThan(0.15));
    expect(large.dx, greaterThan(small.dx));
    expect(large.dx, lessThanOrEqualTo(1));
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
