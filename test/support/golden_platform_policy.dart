/// Exact PNG baselines in this repository are authored with Flutter on Windows.
///
/// Flutter documents that custom-font goldens can render differently across
/// operating systems. Non-canonical hosts still execute every widget, layout,
/// semantics, and accessibility assertion; only their pixel-for-pixel compare
/// is bypassed.
bool shouldCompareExactGoldens({
  required String operatingSystem,
  required bool explicitlyEnabled,
}) => explicitlyEnabled || operatingSystem == 'windows';

/// Runs one explicitly selected exact-golden assertion on its canonical host.
///
/// This helper is intentionally applied only to the visual suites proven to
/// differ between the Windows-authored baselines and Codemagic's macOS
/// renderer. It does not replace Flutter's global comparator, so every other
/// golden remains exact on every host.
Future<void> runExactGoldenCheck({
  required String operatingSystem,
  required bool explicitlyEnabled,
  required bool updatingGoldens,
  required Future<void> Function() compare,
}) async {
  if (operatingSystem != 'windows' && updatingGoldens) {
    throw UnsupportedError(
      'Windows is the canonical exact-golden renderer; non-Windows hosts '
      'cannot rewrite its baselines.',
    );
  }

  if (shouldCompareExactGoldens(
    operatingSystem: operatingSystem,
    explicitlyEnabled: explicitlyEnabled,
  )) {
    await compare();
  }
}
