import 'dart:io';

import 'package:emberkeep/content/release_notes.dart';
import 'package:emberkeep/release_notes_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('current release agrees with the source version', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(currentRoomReleaseNotes.id, '1.0.4+26');
    expect(currentRoomReleaseNotes.title, 'Every surface has a voice.');
    expect(
      currentRoomReleaseNotes.highlights.map((highlight) => highlight.title),
      containsAll(const ['TEXTURES UNDER YOUR FINGER', 'NO DEAD TAPS']),
    );
    expect(pubspec, contains('version: ${currentRoomReleaseNotes.id}'));
    expect(
      roomOfDaysReleaseNotes.map((release) => release.id),
      containsAllInOrder(const [
        '1.0.4+26',
        '1.0.4+25',
        '1.0.4+24',
        '1.0.3+21',
        '1.0.2+20',
      ]),
    );
    final build24 = roomOfDaysReleaseNotes.singleWhere(
      (release) => release.id == '1.0.4+24',
    );
    expect(build24.highlights, hasLength(3));
    final build24Titles = build24.highlights.map(
      (highlight) => highlight.title,
    );
    expect(build24Titles, isNot(contains('QUESTS STAY YOURS')));
    expect(build24Titles, isNot(contains('THE ROOM ANSWERS BACK')));
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
