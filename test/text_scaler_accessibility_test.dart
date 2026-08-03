import 'package:emberkeep/a11y.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('platform accessibility text size is never capped by the app', () {
    const platform = TextScaler.linear(2.0);
    final combined = roomTextScaler(platform, 1.3);

    expect(combined.scale(16), 32);
  });

  test('in-app text size remains a minimum when the platform is smaller', () {
    const platform = TextScaler.linear(1.0);
    final combined = roomTextScaler(platform, 1.5);

    expect(combined.scale(16), 24);
  });
}
