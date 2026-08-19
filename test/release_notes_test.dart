import 'dart:io';

import 'package:emberkeep/content/release_notes.dart';
import 'package:emberkeep/release_notes_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('current release agrees with the source version', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(currentRoomReleaseNotes.id, '1.0.4+22');
    expect(currentRoomReleaseNotes.title, 'Plans are for your whole life.');
    expect(pubspec, contains('version: ${currentRoomReleaseNotes.id}'));
    expect(
      roomOfDaysReleaseNotes.map((release) => release.id),
      containsAllInOrder(const ['1.0.4+22', '1.0.3+21', '1.0.2+20']),
    );
  });

  test('existing install claims an unseen release exactly once', () async {
    final store = _MemoryReleaseSeenStore();
    final gate = ReleaseNotesGate(store);

    expect(
      await gate.claim(
        releaseId: currentRoomReleaseNotes.id,
        freshInstall: false,
      ),
      isTrue,
    );
    expect(store.seen, currentRoomReleaseNotes.id);
    expect(
      await gate.claim(
        releaseId: currentRoomReleaseNotes.id,
        freshInstall: false,
      ),
      isFalse,
    );
    expect(store.writes, 1);
  });

  test('fresh install records the release without presenting it', () async {
    final store = _MemoryReleaseSeenStore();
    final gate = ReleaseNotesGate(store);

    expect(
      await gate.claim(
        releaseId: currentRoomReleaseNotes.id,
        freshInstall: true,
      ),
      isFalse,
    );
    expect(store.seen, currentRoomReleaseNotes.id);
    expect(store.writes, 1);
  });

  test('failed seen write skips automatic presentation', () async {
    final store = _MemoryReleaseSeenStore(writeSucceeds: false);
    final gate = ReleaseNotesGate(store);

    expect(
      await gate.claim(
        releaseId: currentRoomReleaseNotes.id,
        freshInstall: false,
      ),
      isFalse,
    );
    expect(store.seen, isNull);
  });

  test('preference read failure leaves launch usable', () async {
    final gate = ReleaseNotesGate(_MemoryReleaseSeenStore(throwOnRead: true));

    expect(
      await gate.claim(
        releaseId: currentRoomReleaseNotes.id,
        freshInstall: false,
      ),
      isFalse,
    );
  });

  test('empty release id is never presented or persisted', () async {
    final store = _MemoryReleaseSeenStore();
    final gate = ReleaseNotesGate(store);

    expect(await gate.claim(releaseId: '', freshInstall: false), isFalse);
    expect(store.writes, 0);
  });
}

class _MemoryReleaseSeenStore implements ReleaseSeenStore {
  _MemoryReleaseSeenStore({
    this.writeSucceeds = true,
    this.throwOnRead = false,
  });

  final bool writeSucceeds;
  final bool throwOnRead;
  String? seen;
  int writes = 0;

  @override
  Future<String?> read() async {
    if (throwOnRead) throw StateError('read failed');
    return seen;
  }

  @override
  Future<bool> write(String releaseId) async {
    writes++;
    if (!writeSucceeds) return false;
    seen = releaseId;
    return true;
  }
}
