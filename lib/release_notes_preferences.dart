import 'package:shared_preferences/shared_preferences.dart';

/// Device-local UI state. It deliberately does not share a key or lifecycle
/// with the game save, cloud backup, manual exports, or account deletion.
const whatsNewSeenReleasePreferenceKey =
    'room_of_days_whats_new_seen_release_v1';

abstract interface class ReleaseSeenStore {
  Future<String?> read();
  Future<bool> write(String releaseId);
}

class SharedPreferencesReleaseSeenStore implements ReleaseSeenStore {
  const SharedPreferencesReleaseSeenStore();

  @override
  Future<String?> read() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(whatsNewSeenReleasePreferenceKey);
  }

  @override
  Future<bool> write(String releaseId) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.setString(whatsNewSeenReleasePreferenceKey, releaseId);
  }
}

/// Atomically decides whether the current release may be presented. The seen
/// id is written before true is returned so a crash or force-close cannot turn
/// this informational screen into a launch trap.
class ReleaseNotesGate {
  const ReleaseNotesGate(this.store);

  final ReleaseSeenStore store;

  Future<bool> claim({
    required String releaseId,
    required bool freshInstall,
  }) async {
    if (releaseId.isEmpty) return false;
    try {
      if (await store.read() == releaseId) return false;
      if (!await store.write(releaseId)) return false;
      return !freshInstall;
    } catch (_) {
      // Release notes are helpful but never important enough to block launch.
      return false;
    }
  }
}
