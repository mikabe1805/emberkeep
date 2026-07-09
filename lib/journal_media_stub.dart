import 'package:flutter/widgets.dart';

/// Web stub — photos are native-only (no dart:io / path_provider on web), so
/// picking is a no-op and a stored image renders as nothing. Text journaling
/// works everywhere; the editor hides the photo affordance on web.
bool lastPickFailed = false;

Future<String?> pick(bool fromCamera) async => null;

Future<void> delete(String name) async {}

/// No photos on web, so nothing to wipe (mirrors the native clearAll).
Future<void> clearAll() async {}

Widget image(String name, {double maxHeight = 340}) => const SizedBox.shrink();
