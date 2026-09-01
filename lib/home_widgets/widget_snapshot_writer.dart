import 'package:flutter/services.dart';

import 'widget_snapshot.dart';

abstract interface class WidgetSnapshotWriter {
  Future<bool> write(WidgetSnapshot snapshot);
}

/// Writes the small JSON handoff to the platform's shared widget container.
/// Unsupported platforms deliberately return false; app persistence never
/// depends on this optional projection.
final class PlatformWidgetSnapshotWriter implements WidgetSnapshotWriter {
  const PlatformWidgetSnapshotWriter();

  static const _channel = MethodChannel('room_of_days/home_widget');

  @override
  Future<bool> write(WidgetSnapshot snapshot) async {
    try {
      return await _channel.invokeMethod<bool>('writeSnapshot', {
            'json': snapshot.encode(),
          }) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
