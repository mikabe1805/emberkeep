import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'academic_schedule_file_picker.dart';

/// FIFO bridge for calendar files opened from Files, Mail, a browser, or an
/// Android share sheet. Native code retains cold-start payloads until Flutter
/// explicitly takes them, so opening a file can never race app startup.
final class AcademicScheduleFileInbox extends ChangeNotifier {
  AcademicScheduleFileInbox({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const String _channelName = 'room_of_days/academic_schedule_files';
  static const int _maxBytes = 2 * 1024 * 1024;
  static const int _maxPendingCount = 4;

  final MethodChannel _channel;
  final Queue<AcademicScheduleImportSource> _pending =
      Queue<AcademicScheduleImportSource>();
  bool _initialized = false;
  bool _draining = false;
  bool _disposed = false;

  bool get isNotEmpty => _pending.isNotEmpty;

  Future<void> initialize() async {
    if (_initialized || _disposed) return;
    _initialized = true;
    _channel.setMethodCallHandler(_handleNativeCall);
    await _drainNativeQueue();
  }

  Future<Object?> _handleNativeCall(MethodCall call) async {
    if (call.method == 'academicScheduleAvailable') {
      unawaited(_drainNativeQueue());
    }
    return null;
  }

  Future<void> _drainNativeQueue() async {
    if (_draining || _disposed) return;
    _draining = true;
    try {
      while (!_disposed) {
        final Object? raw;
        try {
          raw = await _channel.invokeMethod<Object?>(
            'takeInitialAcademicSchedule',
          );
        } on MissingPluginException {
          return;
        } on PlatformException {
          return;
        }
        if (raw is! Map) return;
        final name = raw['name']?.toString().trim() ?? '';
        var contents = raw['contents']?.toString() ?? '';
        if (contents.startsWith('\uFEFF')) contents = contents.substring(1);
        if (!name.toLowerCase().endsWith('.ics') ||
            contents.isEmpty ||
            utf8.encode(contents).length > _maxBytes) {
          continue;
        }
        _addPending(
          AcademicScheduleImportSource(
            name: name.isEmpty ? 'class-schedule.ics' : name,
            contents: contents,
          ),
        );
        notifyListeners();
      }
    } finally {
      _draining = false;
    }
  }

  @visibleForTesting
  void enqueue(AcademicScheduleImportSource source) {
    if (_disposed) return;
    _addPending(source);
  }

  void _addPending(AcademicScheduleImportSource source) {
    while (_pending.length >= _maxPendingCount) {
      _pending.removeFirst();
    }
    _pending.addLast(source);
    notifyListeners();
  }

  AcademicScheduleImportSource? takeNext() =>
      _pending.isEmpty ? null : _pending.removeFirst();

  @override
  void dispose() {
    _disposed = true;
    _pending.clear();
    _channel.setMethodCallHandler(null);
    super.dispose();
  }
}
