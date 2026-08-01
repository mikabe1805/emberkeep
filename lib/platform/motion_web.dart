import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

/// Web tilt input built on DeviceOrientation rather than the experimental
/// Generic Sensor API.
///
/// `sensors_plus` uses `Accelerometer()` on web, which is unavailable in
/// Safari. iPhone Safari instead exposes DeviceOrientation and requires its
/// permission request to happen during a user gesture. We attach the listener
/// immediately for browsers that do not gate it, then [requestPermission] is
/// called by the shell's first pointer-down for Safari.
class BrowserMotionSource {
  BrowserMotionSource() {
    _permissionRequired = _deviceOrientationNeedsPermission();
    if (!_permissionRequired) {
      _permissionGranted = true;
      _listen();
    }
  }

  final StreamController<Offset> _events = StreamController<Offset>.broadcast(
    sync: true,
  );
  StreamSubscription<web.DeviceOrientationEvent>? _subscription;

  Offset _rest = Offset.zero;
  var _samples = 0;
  var _permissionRequested = false;
  var _permissionGranted = false;
  var _disposed = false;
  late final bool _permissionRequired;

  Stream<Offset> get events => _events.stream;

  Future<bool> requestPermission() async {
    if (_disposed) return false;
    if (!_permissionRequired) return true;
    if (_permissionRequested) return _permissionGranted;
    _permissionRequested = true;

    try {
      final constructor = globalContext.getProperty<JSObject?>(
        'DeviceOrientationEvent'.toJS,
      );
      if (constructor != null &&
          constructor.hasProperty('requestPermission'.toJS).toDart) {
        final promise = constructor.callMethod<JSPromise<JSString>>(
          'requestPermission'.toJS,
        );
        _permissionGranted = (await promise.toDart).toDart == 'granted';
      } else {
        // Chrome/Android and desktop browsers do not expose the Safari-only
        // requestPermission method. Their event stream is already available.
        _permissionGranted = true;
      }
    } catch (_) {
      _permissionGranted = false;
    }

    if (_permissionGranted) _listen();
    return _permissionGranted;
  }

  bool _deviceOrientationNeedsPermission() {
    try {
      final constructor = globalContext.getProperty<JSObject?>(
        'DeviceOrientationEvent'.toJS,
      );
      return constructor != null &&
          constructor.hasProperty('requestPermission'.toJS).toDart;
    } catch (_) {
      return false;
    }
  }

  void _listen() {
    if (_disposed || _subscription != null) return;
    _subscription = web.EventStreamProviders.deviceOrientationEvent
        .forTarget(web.window)
        .listen(_onOrientation, onError: (_, _) {});
  }

  void _onOrientation(web.DeviceOrientationEvent event) {
    if (_disposed) return;
    final beta = event.beta;
    final gamma = event.gamma;
    if (beta == null || gamma == null) return;

    final reading = Offset(gamma, beta);
    if (_samples < 8) {
      _samples++;
      _rest = Offset.lerp(_rest, reading, 1 / _samples)!;
      return;
    }

    // Relative calibration feels natural whether the phone begins upright,
    // reclined, or held one-handed. Roughly 16–18 degrees reaches full travel;
    // the rendered layers remain much smaller than that normalized range.
    _events.add(
      Offset(
        ((reading.dx - _rest.dx) / 16).clamp(-1.0, 1.0),
        (-(reading.dy - _rest.dy) / 18).clamp(-1.0, 1.0),
      ),
    );
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(_subscription?.cancel());
    unawaited(_events.close());
  }
}
