import 'package:flutter/material.dart';

/// Web stub — photos are native-only (no dart:io / path_provider on web), so
/// picking is a no-op. A restored image reference gets a quiet placeholder
/// instead of a blank card. Text journaling still works everywhere.
bool lastPickFailed = false;

Future<String?> pick(bool fromCamera) async => null;
Future<List<String>> pickMany() async => const [];

Future<void> delete(String name) async {}

/// No photos on web, so nothing to wipe (mirrors the native clearAll).
Future<void> clearAll() async {}

Widget image(String name, {double maxHeight = 340}) {
  final compact = maxHeight < 104;
  return Container(
    height: compact ? maxHeight : 128,
    alignment: Alignment.center,
    padding: compact
        ? EdgeInsets.zero
        : const EdgeInsets.symmetric(horizontal: 20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF34281F), Color(0xFF281E17)],
      ),
      borderRadius: BorderRadius.circular(compact ? 8 : 14),
      border: Border.all(color: const Color(0x22FFFFFF)),
    ),
    child: compact
        ? Semantics(
            label: 'This photo lives on your other device',
            child: Icon(
              Icons.photo_outlined,
              size: maxHeight < 60 ? 18 : 22,
              color: const Color(0xFFB9A488),
            ),
          )
        : const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.photo_outlined, size: 22, color: Color(0xFFB9A488)),
              SizedBox(height: 8),
              Text(
                'This photo lives on your other device',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.3,
                  color: Color(0xFFB9A488),
                ),
              ),
            ],
          ),
  );
}
