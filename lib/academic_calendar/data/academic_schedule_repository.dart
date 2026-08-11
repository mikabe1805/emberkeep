import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/academic_schedule.dart';

abstract interface class AcademicScheduleRepository {
  Future<AcademicSchedule> load();

  /// Returns false when the platform declines the durable write.
  Future<bool> save(AcademicSchedule schedule);
}

/// A separate, local-first store for academic truth. It deliberately does not
/// share the Quest save blob, so classes can evolve without changing Quest IDs
/// or making an older app version strip a semester from a main save.
final class LocalAcademicScheduleRepository
    implements AcademicScheduleRepository {
  static const storageKey = 'room_of_days_academic_schedule_v1';
  static const corruptBackupKey = 'room_of_days_academic_schedule_corrupt_v1';

  @override
  Future<AcademicSchedule> load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(storageKey);
      if (raw == null) return AcademicSchedule.empty();
      try {
        final decoded = (jsonDecode(raw) as Map).cast<String, dynamic>();
        return AcademicSchedule.fromJson(decoded);
      } catch (error) {
        debugPrint(
          'Academic schedule is unreadable; preserving a recovery copy: '
          '$error',
        );
        if (preferences.getString(corruptBackupKey) == null) {
          await preferences.setString(corruptBackupKey, raw);
        }
        return AcademicSchedule.empty();
      }
    } catch (error) {
      debugPrint('Academic schedule load failed: $error');
      return AcademicSchedule.empty();
    }
  }

  @override
  Future<bool> save(AcademicSchedule schedule) async {
    final raw = jsonEncode(schedule.toJson());
    try {
      final preferences = await SharedPreferences.getInstance();
      return await preferences.setString(storageKey, raw);
    } catch (error) {
      debugPrint('Academic schedule save failed: $error');
      return false;
    }
  }
}

/// Test and preview seam; it behaves like durable storage across repeated
/// loads while remaining completely offline.
final class InMemoryAcademicScheduleRepository
    implements AcademicScheduleRepository {
  InMemoryAcademicScheduleRepository([AcademicSchedule? initial])
    : schedule = initial ?? AcademicSchedule.empty();

  AcademicSchedule schedule;
  bool allowWrites = true;
  int saveCount = 0;

  @override
  Future<AcademicSchedule> load() async => schedule;

  @override
  Future<bool> save(AcademicSchedule schedule) async {
    saveCount += 1;
    if (!allowWrites) return false;
    this.schedule = schedule;
    return true;
  }
}
