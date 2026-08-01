import 'dart:async';

import 'package:flutter/widgets.dart';

/// Browser-only device-orientation bridge.
///
/// Native builds use `sensors_plus`; this stub keeps the shared controller
/// platform-agnostic without pulling web APIs into iOS or Android builds.
class BrowserMotionSource {
  const BrowserMotionSource();

  Stream<Offset> get events => const Stream<Offset>.empty();

  Future<bool> requestPermission() async => false;

  void dispose() {}
}
