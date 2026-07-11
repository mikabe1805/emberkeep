import 'package:flutter/services.dart';

/// Centralized haptics — semantic taps mapped to the iOS Taptic Engine. These
/// are REAL on a native build and silent no-ops on iOS Safari web (which
/// blocks the Vibration API) — a core reason Emberkeep wants to go native.
/// Big moments layer the built-in impacts into a richer, sequenced pattern.
///
/// When [reduceMotion] is true (DESIGN.md: honor reduce-motion), composed
/// patterns collapse to a single light tick so celebrations stay gentle.
abstract final class Haptics {
  /// Wired from GameState.reduceMotion — softens intensity, never silences
  /// entirely (a muted phone still gets a soft ack).
  static bool reduceMotion = false;

  /// A light UI tick — taps, toggles, selections.
  static void tap() => HapticFeedback.selectionClick();

  /// A single soft bump — a routine quest completion.
  static void light() => HapticFeedback.lightImpact();

  /// A confirming bump — adding, saving, equipping.
  static void success() => reduceMotion
      ? HapticFeedback.lightImpact()
      : HapticFeedback.mediumImpact();

  /// An ascending double-bump — a rung rise / rank-up climb.
  static void rise() {
    if (reduceMotion) {
      HapticFeedback.lightImpact();
      return;
    }
    HapticFeedback.lightImpact();
    Future.delayed(
      const Duration(milliseconds: 80),
      HapticFeedback.mediumImpact,
    );
  }

  /// The level-up slam — heavy, then a settling medium.
  static void big() {
    if (reduceMotion) {
      HapticFeedback.mediumImpact();
      return;
    }
    HapticFeedback.heavyImpact();
    Future.delayed(
      const Duration(milliseconds: 90),
      HapticFeedback.mediumImpact,
    );
  }

  /// A crit / loot pop — a quick triple flourish.
  static void flourish() {
    if (reduceMotion) {
      HapticFeedback.mediumImpact();
      return;
    }
    HapticFeedback.heavyImpact();
    Future.delayed(
      const Duration(milliseconds: 80),
      HapticFeedback.mediumImpact,
    );
    Future.delayed(
      const Duration(milliseconds: 170),
      HapticFeedback.lightImpact,
    );
  }

  /// Streak shield held the line — a steady, protective double-tap.
  static void shield() {
    if (reduceMotion) {
      HapticFeedback.lightImpact();
      return;
    }
    HapticFeedback.mediumImpact();
    Future.delayed(
      const Duration(milliseconds: 110),
      HapticFeedback.mediumImpact,
    );
  }
}
