import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:emberkeep/content/space_themes.dart';
import 'package:emberkeep/content/titles.dart';
import 'package:emberkeep/cloud.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/social.dart';
import 'package:emberkeep/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

String _firestoreRules() {
  final file = File('firestore.rules');
  expect(
    file.existsSync(),
    isTrue,
    reason: 'Run this test from the Flutter package root.',
  );
  return file
      .readAsStringSync()
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n');
}

Set<String> _singleQuotedValues(String source) => RegExp(
  r"'([^']+)'",
).allMatches(source).map((match) => match.group(1)!).toSet();

RegExp _publishedTitlePattern(String rules) {
  final match = RegExp(
    r"return\s+title\.matches\(\s*'([^']+)'\s*\)",
    dotAll: true,
  ).firstMatch(rules);
  expect(match, isNotNull, reason: 'validBuildTitle must remain inspectable.');
  return RegExp(match!.group(1)!);
}

Iterable<Map<Stat, int>> _currentBuildShapes() sync* {
  // Blank slate, every solo title, and every two-domain title.
  yield const {};
  for (final stat in Stat.values) {
    yield {stat: 1};
  }
  for (var first = 0; first < Stat.values.length; first++) {
    for (var second = first + 1; second < Stat.values.length; second++) {
      yield {Stat.values[first]: 1, Stat.values[second]: 1};
    }
  }

  // Every current rank-prefix family, while keeping a second domain close
  // enough that BuildTitles still emits a pair title rather than a solo one.
  for (var index = 0; index < Stat.values.length; index++) {
    yield {
      Stat.values[index]: 50,
      Stat.values[(index + 1) % Stat.values.length]: 17,
    };
  }
}

GameState _stateWithBuild(Map<Stat, int> shape) {
  final state = GameState();
  for (final stat in Stat.values) {
    state.stats[stat] = shape[stat] ?? 0;
  }
  return state;
}

void main() {
  test(
    'room publication queue serializes writes and recovers after failure',
    () async {
      final queue = RoomPublishQueue();
      final releaseFirst = Completer<void>();
      final events = <String>[];

      final first = queue.run(() async {
        events.add('first:start');
        await releaseFirst.future;
        events.add('first:end');
        return 1;
      });
      final second = queue.run<int>(() async {
        events.add('second:start');
        throw StateError('expected test failure');
      });
      final third = queue.run(() async {
        events.add('third:start');
        return 3;
      });
      final secondFailure = expectLater(second, throwsStateError);

      await Future<void>.delayed(Duration.zero);
      expect(events, ['first:start']);

      releaseFirst.complete();
      expect(await first, 1);
      await secondFailure;
      expect(await third, 3);
      expect(events, [
        'first:start',
        'first:end',
        'second:start',
        'third:start',
      ]);
    },
  );

  test(
    'newer privacy projection is final across a delayed old refresh',
    () async {
      final queue = RoomPublishQueue();
      final releaseOldRoom = Completer<void>();
      final roomStarted = Completer<void>();
      final profiles = <String>[];

      Future<void> sync({
        required String label,
        required String profile,
        Future<void>? roomGate,
      }) async {
        await queue.runWrite<void>(() async {
          if (!roomStarted.isCompleted) roomStarted.complete();
          if (roomGate != null) await roomGate;
          profiles.add('$label:$profile');
        });
      }

      final stale = sync(
        label: 'old',
        profile: 'anyone',
        roomGate: releaseOldRoom.future,
      );
      await roomStarted.future;
      final current = sync(label: 'new', profile: '<deleted>');
      releaseOldRoom.complete();
      await Future.wait([stale, current]);

      expect(profiles, ['old:anyone', 'new:<deleted>']);
      expect(profiles.last, 'new:<deleted>');
    },
  );

  test('invalidating a debounced room refresh rejects its stale epoch', () {
    final fence = RoomRefreshFence();
    final oldEpoch = fence.schedule();

    fence.invalidate();

    expect(fence.accepts(oldEpoch), isFalse);
    expect(fence.accepts(fence.schedule()), isTrue);
  });

  test('Stop Sharing cannot race a queued room refresh', () {
    final source = File('lib/cloud.dart').readAsStringSync();
    final unshare = source.substring(
      source.indexOf('Future<bool> unshareRoom'),
      source.indexOf('Future<_OwnedRoomDeleteResult> _deleteOwnedRoom'),
    );
    final cancel = unshare.indexOf('invalidatePendingRoomRefreshes()');
    final queue = unshare.indexOf('_roomPublishQueue.run');
    final remove = unshare.indexOf('_deleteOwnedRoom(code)');

    expect(cancel, greaterThanOrEqualTo(0));
    expect(queue, greaterThan(cancel));
    expect(remove, greaterThan(queue));
  });

  test('background room and profile refresh stay in one ordered operation', () {
    final source = File('lib/cloud.dart').readAsStringSync();
    final refresh = source.substring(
      source.indexOf('Future<void> _refreshRoomAndDirectory'),
      source.indexOf('/// Publish (or update) your space'),
    );

    expect(refresh, contains('_roomPublishQueue.runWrite<void>'));
    expect(refresh, contains('_publishRoomNow('));
    expect(refresh, contains('_publishSpaceProfileNow('));
    expect(refresh, isNot(contains('await publishRoom(')));
    expect(refresh, isNot(contains('await publishSpaceProfile(')));
  });

  test('code and Circle visits retain the profile report path', () {
    final social = File('lib/social.dart').readAsStringSync();
    final visit = social.substring(
      social.indexOf('Future<void> visitSpace('),
      social.indexOf('class SharedRoomVisit'),
    );
    final circle = File('lib/screens/hearth_circle.dart').readAsStringSync();

    expect(
      visit,
      contains(
        'onReportDiscoverableSpace: CloudSync.instance.reportDiscoverableSpace',
      ),
    );
    expect(circle, contains('onReportDiscoverableSpace:'));
    expect(circle, contains('.reportDiscoverableSpace'));
  });

  group('shared-space payload contract', () {
    test('every current room identity is emitted without schema drift', () {
      final rules = _firestoreRules();
      final keyBlock = RegExp(
        r'function\s+validRoom.*?d\.keys\(\)\.hasOnly\(\[(.*?)\]\)',
        dotAll: true,
      ).firstMatch(rules);
      expect(keyBlock, isNotNull);
      final ruleKeys = _singleQuotedValues(keyBlock!.group(1)!);
      // CloudSync adds the private-identity-derived ownerKey and server time at
      // the write boundary; roomDisplay itself remains pure generated content.
      final payloadKeys = ruleKeys.difference(const {'ownerKey', 'updatedAt'});

      final wallBlock = RegExp(
        r'&&\s+d\.wall\s+in\s+\[(.*?)\]',
        dotAll: true,
      ).firstMatch(rules);
      expect(wallBlock, isNotNull);
      final allowedWalls = _singleQuotedValues(wallBlock!.group(1)!);

      for (final theme in spaceThemes) {
        final state = GameState()..wallStyle = theme.id;
        final payload = roomDisplay(state);

        expect(payload['wall'], theme.id, reason: theme.name);
        expect(allowedWalls, contains(theme.id), reason: theme.name);
        expect(payload.keys.toSet(), payloadKeys, reason: theme.name);
        expect(payload['v'], 6, reason: theme.name);
      }
    });

    test('every current generated build title is accepted by source rules', () {
      final titlePattern = _publishedTitlePattern(_firestoreRules());
      final titles = <String>{};

      for (final shape in _currentBuildShapes()) {
        final state = _stateWithBuild(shape);
        final expected = BuildTitles.epithetOf(state.stats);
        final published = roomDisplay(state)['title'];
        titles.add(expected);

        expect(published, expected);
        expect(
          titlePattern.hasMatch(expected),
          isTrue,
          reason: '$expected is generated by the app but rejected by rules',
        );
      }

      expect(titles, containsAll(const ['STEADY HAND', 'OPEN HOUSE']));
      expect(titles, hasLength(28));
    });

    test(
      'profile fields are always present but stay empty without consent',
      () {
        const privateName = 'A name that stays on this device';
        const privateIntro = 'A private introduction for my own room.';
        const privateGoal = 'A goal I did not consent to share';
        final state = GameState()..playerName = privateName;
        state.goals.add(Goal(title: privateGoal, stat: Stat.vit, target: 12));
        state.setSpaceProfile(intro: privateIntro, goals: const [privateGoal]);

        final payload = roomDisplay(state);
        final encoded = jsonEncode(payload);

        expect(payload['v'], 6);
        expect(payload['name'], 'Fellow keeper');
        expect(payload['profileVisible'], isFalse);
        expect(payload['displayName'], isEmpty);
        expect(payload['about'], isEmpty);
        expect(payload['featuredGoals'], isEmpty);
        expect(payload['cardOrder'], isEmpty);
        expect(payload['pinnedMoments'], isEmpty);
        expect(payload['season'], isEmpty);
        expect(payload['profilePhotoPath'], isEmpty);
        expect(payload['seasonPhotoPath'], isEmpty);
        expect(encoded, isNot(contains(privateName)));
        expect(encoded, isNot(contains(privateIntro)));
        expect(encoded, isNot(contains(privateGoal)));
      },
    );

    test('authored profile photos never enter the bearer room document', () {
      const profileLocal = 'journal/local-profile.jpg';
      const seasonLocal = 'journal/local-season.webp';
      final profile = Note(
        id: 'profile-source',
        at: DateTime(2026, 8, 2),
        text: 'Profile source',
        images: const [profileLocal],
      );
      final season = Note(
        id: 'season-source',
        at: DateTime(2026, 8, 3),
        text: 'Season source',
        images: const [seasonLocal],
      );
      final state = GameState()
        ..journal = [profile, season]
        ..shareSpaceProfile = true
        ..spaceProfilePhotoNoteId = profile.id
        ..spaceSeasonPhotoNoteId = season.id
        ..shareSpaceProfilePhoto = true
        ..shareSpaceSeasonPhoto = true
        ..spaceProfilePhotoPath =
            'shared_rooms/owner_123/ABC234/profile/ABCDEFGHIJKLMNOPQRSTUV'
        ..spaceSeasonPhotoPath =
            'shared_rooms/owner_123/ABC234/season/ABCDEFGHIJKLMNOPQRSTUV';

      final releasePayload = roomDisplay(
        state,
        mediaOwnerUid: 'owner_123',
        mediaRoomCode: 'ABC234',
      );
      expect(releasePayload['profilePhotoPath'], isEmpty);
      expect(releasePayload['seasonPhotoPath'], isEmpty);

      var payload = roomDisplay(
        state,
        mediaOwnerUid: 'owner_123',
        mediaRoomCode: 'abc234',
        visitorPhotoSharingEnabled: true,
        visitorProfileSharingEnabled: true,
      );
      expect(payload['profilePhotoPath'], isEmpty);
      expect(payload['seasonPhotoPath'], isEmpty);

      state.visitorSpaceCards.add(SpaceCardKind.thisSeason);
      payload = roomDisplay(
        state,
        mediaOwnerUid: 'owner_123',
        mediaRoomCode: 'ABC234',
        visitorPhotoSharingEnabled: true,
        visitorProfileSharingEnabled: true,
      );
      expect(payload['seasonPhotoPath'], isEmpty);
      expect(jsonEncode(payload), isNot(contains(profileLocal)));
      expect(jsonEncode(payload), isNot(contains(seasonLocal)));

      state.shareSpaceProfile = false;
      payload = roomDisplay(
        state,
        mediaOwnerUid: 'owner_123',
        mediaRoomCode: 'ABC234',
        visitorPhotoSharingEnabled: true,
        visitorProfileSharingEnabled: true,
      );
      expect(payload['profilePhotoPath'], isEmpty);
      expect(payload['seasonPhotoPath'], isEmpty);
    });

    test('an explicitly shared profile is sanitized and tightly bounded', () {
      final state = GameState()
        ..shareSpaceProfile = true
        ..playerName = '  Mika\n${'x' * 80}  '
        ..spaceIntro = '  A room\nwith\tbreathing space. ${'y' * 220}  '
        ..featuredGoalTitles.addAll([
          '  Finish\nthis room  ',
          'z' * 140,
          '  A third goal  ',
          'A fourth goal that must not publish',
        ]);
      state.spaceCardAudiences
        ..[SpaceCardKind.about] = SpaceAudience.anyone
        ..[SpaceCardKind.rightNow] = SpaceAudience.anyone;

      final payload = spaceProfileDisplay(
        state,
        audience: SpaceAudience.anyone,
      );
      final goals = (payload['featuredGoals'] as List).cast<String>();

      expect(payload['displayName'], startsWith('Mika '));
      expect(
        (payload['displayName'] as String).runes.length,
        lessThanOrEqualTo(40),
      );
      expect(payload['displayName'], isNot(contains('\n')));
      expect((payload['about'] as String).runes.length, lessThanOrEqualTo(180));
      expect(payload['about'], isNot(anyOf(contains('\n'), contains('\t'))));
      expect(goals, hasLength(3));
      expect(goals.first, 'Finish this room');
      expect(goals[1].runes.length, 100);
      expect(goals.last, 'A third goal');
      expect(goals, isNot(contains('A fourth goal that must not publish')));
    });

    test('Anyone and Mutuals receive separate complete projections', () {
      final state = GameState()
        ..shareSpaceProfile = true
        ..playerName = 'Mika'
        ..spaceIntro = 'Public hello'
        ..featuredGoalTitles.add('Mutual goal')
        ..spaceSeasonText = 'Private season';
      state.spaceCardAudiences
        ..[SpaceCardKind.about] = SpaceAudience.anyone
        ..[SpaceCardKind.rightNow] = SpaceAudience.mutuals
        ..[SpaceCardKind.thisSeason] = SpaceAudience.onlyMe;

      final publicProfile = spaceProfileDisplay(
        state,
        audience: SpaceAudience.anyone,
      );
      final mutualProfile = spaceProfileDisplay(
        state,
        audience: SpaceAudience.mutuals,
      );

      expect(publicProfile['cardOrder'], ['about']);
      expect(publicProfile['about'], 'Public hello');
      expect(publicProfile['featuredGoals'], isEmpty);
      expect(mutualProfile['cardOrder'], ['about', 'rightNow']);
      expect(mutualProfile['about'], 'Public hello');
      expect(mutualProfile['featuredGoals'], ['Mutual goal']);
      expect(jsonEncode(mutualProfile), isNot(contains('Private season')));
      expect(jsonEncode(roomDisplay(state)), isNot(contains('Public hello')));
    });

    test('an open page can be intentionally empty for an audience', () {
      final state = GameState()
        ..shareSpaceProfile = true
        ..playerName = 'Private name';

      final publicProfile = spaceProfileDisplay(
        state,
        audience: SpaceAudience.anyone,
      );

      expect(publicProfile, isNotEmpty);
      expect(publicProfile['displayName'], isEmpty);
      expect(publicProfile['cardOrder'], isEmpty);
      expect(jsonEncode(publicProfile), isNot(contains('Private name')));
    });

    test('owner layout and visitor audience stay independent', () {
      final state = GameState()
        ..shareSpaceProfile = true
        ..playerName = 'Mika'
        ..spaceIntro = 'A room for making things.'
        ..featuredGoalTitles.add('Finish this room');
      state.spaceCardAudiences
        ..[SpaceCardKind.about] = SpaceAudience.anyone
        ..[SpaceCardKind.rightNow] = SpaceAudience.anyone;

      state.hiddenSpaceCards.add(SpaceCardKind.about);
      var payload = spaceProfileDisplay(state, audience: SpaceAudience.anyone);
      expect(payload['displayName'], 'Mika');
      expect(payload['about'], 'A room for making things.');
      expect(payload['featuredGoals'], ['Finish this room']);

      state.spaceCardAudiences[SpaceCardKind.about] = SpaceAudience.onlyMe;
      payload = spaceProfileDisplay(state, audience: SpaceAudience.anyone);
      expect(payload['displayName'], 'Mika');
      expect(payload['about'], isEmpty);
      expect(payload['featuredGoals'], ['Finish this room']);
      expect(payload['cardOrder'], ['rightNow']);

      state.hiddenSpaceCards.clear();
      state.spaceCardAudiences
        ..[SpaceCardKind.about] = SpaceAudience.anyone
        ..[SpaceCardKind.rightNow] = SpaceAudience.onlyMe;
      payload = spaceProfileDisplay(state, audience: SpaceAudience.anyone);
      expect(payload['displayName'], 'Mika');
      expect(payload['about'], 'A room for making things.');
      expect(payload['featuredGoals'], isEmpty);
      expect(payload['cardOrder'], ['about']);
    });

    test('private card content never enters the public room document', () {
      const pinnedText = 'PRIVATE-PIN-SENTINEL';
      const pinnedId = 'private-pin-note-id';
      const pinnedImage = 'journal/private-pin-image.webp';
      const seasonText = 'PRIVATE-SEASON-SENTINEL';
      const seasonId = 'private-season-note-id';
      const seasonImage = 'journal/private-season-image.webp';
      final state = GameState()
        ..shareSpaceProfile = true
        ..journal = [
          Note(
            id: pinnedId,
            at: DateTime(2026, 8, 2),
            text: pinnedText,
            images: const [pinnedImage],
          ),
          Note(
            id: seasonId,
            at: DateTime(2026, 8, 3),
            text: 'Photo source note',
            images: const [seasonImage],
          ),
        ]
        ..memoryPins.add(pinnedId);
      state.setSpacePage(
        order: const [
          SpaceCardKind.thisSeason,
          SpaceCardKind.pinnedMoments,
          SpaceCardKind.about,
          SpaceCardKind.rightNow,
        ],
        hidden: const [SpaceCardKind.pinnedMoments],
        intro: 'Visitor-safe about',
        featuredGoalTitles: const [],
        seasonText: seasonText,
        profilePhotoNoteId: null,
        seasonPhotoNoteId: seasonId,
        shareProfilePhoto: false,
        shareSeasonPhoto: false,
        shareProfile: true,
      );

      final encoded = jsonEncode(roomDisplay(state));

      for (final privateValue in const [
        pinnedText,
        pinnedId,
        pinnedImage,
        seasonText,
        seasonId,
        seasonImage,
        'spaceCardOrder',
        'hiddenSpaceCards',
        'spaceSeasonText',
        'spaceSeasonPhotoNoteId',
      ]) {
        expect(encoded, isNot(contains(privateValue)));
      }
    });

    test(
      'selected writing cards publish bounded text but never local media',
      () {
        const pinnedId = 'public-pin-note-id';
        const pinnedImage = 'journal/public-pin-image.webp';
        const seasonId = 'public-season-note-id';
        const seasonImage = 'journal/public-season-image.webp';
        final state = GameState()
          ..shareSpaceProfile = true
          ..journal = [
            Note(
              id: pinnedId,
              at: DateTime(2026, 8, 2),
              text: '  A pinned\nmoment ${'p' * 280}  ',
              images: const [pinnedImage],
            ),
            Note(
              id: seasonId,
              at: DateTime(2026, 8, 3),
              text: 'Photo source note',
              images: const [seasonImage],
            ),
          ]
          ..memoryPins.add(pinnedId);
        state.visitorSpaceCards
          ..clear()
          ..addAll(const [
            SpaceCardKind.thisSeason,
            SpaceCardKind.pinnedMoments,
          ]);
        state.setSpacePage(
          order: const [
            SpaceCardKind.thisSeason,
            SpaceCardKind.pinnedMoments,
            SpaceCardKind.about,
            SpaceCardKind.rightNow,
          ],
          hidden: const [],
          visitorVisible: state.visitorSpaceCards,
          intro: '',
          featuredGoalTitles: const [],
          seasonText: '  A slower\tseason.  ',
          profilePhotoNoteId: null,
          seasonPhotoNoteId: seasonId,
          shareProfilePhoto: false,
          shareSeasonPhoto: false,
          shareProfile: true,
        );

        final payload = spaceProfileDisplay(
          state,
          audience: SpaceAudience.anyone,
        );
        final moments = (payload['pinnedMoments'] as List).cast<Map>();
        final encoded = jsonEncode(payload);

        expect(payload['cardOrder'], ['thisSeason', 'pinnedMoments']);
        expect(payload['season'], 'A slower season.');
        expect(moments, hasLength(1));
        expect(moments.single['text'], startsWith('A pinned moment '));
        expect((moments.single['text'] as String).runes.length, 240);
        expect(
          moments.single['at'],
          DateTime(2026, 8, 2).millisecondsSinceEpoch,
        );
        for (final privateValue in const [
          pinnedId,
          pinnedImage,
          seasonId,
          seasonImage,
        ]) {
          expect(encoded, isNot(contains(privateValue)));
        }
      },
    );

    test('legacy schemas stay documented but only generated v6 is writable', () {
      final rules = _firestoreRules();

      expect(rules, contains('(d.v == 1'));
      expect(rules, contains('(d.v == 2'));
      expect(rules, contains('(d.v == 3'));
      expect(rules, contains('(d.v == 4'));
      expect(rules, contains('(d.v == 6'));
      expect(rules, contains('d.profileVisible is bool'));
      expect(rules, contains('d.displayName.size() <= 40'));
      expect(rules, contains('d.about.size() <= 180'));
      expect(rules, contains('d.featuredGoals.size() <= 3'));
      expect(rules, contains("d.displayName == ''"));
      expect(rules, contains('d.cardOrder.size() <= 4'));
      expect(rules, contains('d.pinnedMoments.size() <= 4'));
      expect(rules, contains('d.season.size() <= 180'));
      expect(rules, contains('validSharedPhotos(d, code)'));
      expect(
        rules,
        contains(
          "validSharedPhotoPath(d.profilePhotoPath, d.ownerKey, code, 'profile')",
        ),
      );
      expect(
        rules,
        contains(
          "validSharedPhotoPath(d.seasonPhotoPath, d.ownerKey, code, 'season')",
        ),
      );
      expect(rules, contains("parts[4].matches('^[A-Za-z0-9_-]{22}\$')"));
      expect(rules, contains('d.profileVisible == false'));
      expect(
        RegExp(r'request\.resource\.data\.v\s*==\s*6').allMatches(rules),
        hasLength(2),
      );
      expect(rules, contains('request.resource.data.v >= resource.data.v'));
      expect(
        rules,
        matches(
          RegExp(
            r'allow\s+get:\s*if\s*\(\s*resource\.data\.v\s*==\s*6\s*'
            r'&&\s*resource\.data\.profileVisible\s*==\s*false',
          ),
        ),
      );
      expect(
        rules,
        matches(
          RegExp(
            r'request\.auth\s*!=\s*null\s*'
            r'&&\s*resource\.data\.v\s*==\s*5\s*'
            r'&&\s*resource\.data\.uid\s*==\s*request\.auth\.uid',
          ),
        ),
      );
    });
  });

  test('invite links normalize valid codes and reject invalid ones', () {
    expect(roomInviteUrl('abc234'), contains('/space/ABC234'));
    expect(
      roomInviteText('abc234', ownerName: 'Mika'),
      allOf(contains('Mika'), contains('ABC234'), contains('https://')),
    );
    expect(
      roomCodeFromUri(Uri.parse('https://example.com/?space=abc234')),
      'ABC234',
    );
    expect(
      roomCodeFromUri(Uri.parse('https://example.com/space/ABC234')),
      'ABC234',
    );
    expect(
      roomCodeFromUri(Uri.parse('https://example.com/?space=BAD10I')),
      isNull,
    );
    expect(
      uriNamesSharedSpace(Uri.parse('https://roomofdays.com/spacesomething')),
      isFalse,
    );
    expect(
      uriNamesSharedSpace(Uri.parse('https://roomofdays.com/roommate')),
      isFalse,
    );
    expect(
      uriNamesSharedSpace(Uri.parse('https://roomofdays.com/space')),
      isTrue,
    );
    expect(
      uriNamesSharedSpace(Uri.parse('https://roomofdays.com/space/ABC234')),
      isTrue,
    );
  });

  test('room-link inbox preserves canonical and legacy links in order', () {
    final inbox = RoomLinkInbox();
    addTearDown(inbox.dispose);

    expect(
      inbox.enqueueUri(Uri.parse('https://roomofdays.com/?space=abc234')),
      isTrue,
    );
    expect(
      inbox.enqueueUri(Uri.parse('https://roomofdays.com/space/DEF567')),
      isTrue,
    );
    expect(inbox.enqueueUri(Uri.parse('/room/GHJ789')), isTrue);
    expect(
      inbox.enqueueUri(Uri.parse('https://roomofdays.com/space/BAD10I')),
      isFalse,
    );

    final first = inbox.takeNext();
    final second = inbox.takeNext();
    final third = inbox.takeNext();
    expect(
      [first?.code, second?.code, third?.code],
      ['ABC234', 'DEF567', 'GHJ789'],
    );
    expect(first!.sequence, lessThan(second!.sequence));
    expect(second.sequence, lessThan(third!.sequence));
    expect(inbox.takeNext(), isNull);
  });

  test('invite copy keeps the local name behind visitor-page consent', () {
    final state = GameState()..setPlayerName('Mika');

    expect(roomInviteOwnerName(state), isNull);
    expect(
      roomInviteText('ABC234', ownerName: roomInviteOwnerName(state)),
      isNot(contains('Mika')),
    );

    state.shareSpaceProfile = true;
    expect(
      roomInviteOwnerName(state, visitorProfileSharingEnabled: true),
      'Mika',
    );
    expect(
      roomInviteText(
        'ABC234',
        ownerName: roomInviteOwnerName(
          state,
          visitorProfileSharingEnabled: true,
        ),
      ),
      contains('Mika'),
    );
  });

  test('Circle receipt notices are human and count-aware', () {
    expect(circleAddNoticeText(1), contains('Someone'));
    expect(circleAddNoticeText(3), contains('3 people'));
  });

  test('rule source shapes a bounded immutable-owner cleanup query', () {
    final rules = _firestoreRules();
    final roomsStart = rules.indexOf(r'match /rooms/{code}');
    final sparksStart = rules.indexOf(r'match /sparks/{senderId}', roomsStart);
    expect(roomsStart, greaterThanOrEqualTo(0));
    expect(sparksStart, greaterThan(roomsStart));
    final roomRules = rules.substring(roomsStart, sparksStart);

    expect(
      roomRules,
      matches(
        RegExp(
          r'allow\s+get:\s*if\s*\(\s*resource\.data\.v\s*==\s*6\s*'
          r'&&\s*resource\.data\.profileVisible\s*==\s*false',
        ),
      ),
    );
    expect(roomRules, matches(RegExp(r'allow\s+list:\s*if\s*false;')));
    expect(roomRules, isNot(matches(RegExp(r'allow\s+list:\s*if\s+true;'))));

    final cloud = File('lib/cloud.dart').readAsStringSync();
    expect(
      cloud,
      matches(
        RegExp(
          r"\.where\(\s*'uid',\s*isEqualTo:\s*ownerUid\s*\)\s*"
          r'\.limit\(100\)\s*\.get\(\s*const\s+GetOptions\('
          r'source:\s*Source\.server\s*\)\s*\)',
        ),
      ),
    );
  });

  test('rule source requires deletion tombstones around receipts', () {
    final rules = _firestoreRules();
    expect(rules, contains(r'match /roomDeletionLocks/{code}'));
    expect(
      RegExp(
        r'match /(?:sparks|circleAdds)/\{senderId\}.*?allow create: if.*?'
        r'!exists\(/databases/\$\(database\)/documents/'
        r'roomDeletionLocks/\$\(code\)\)',
        dotAll: true,
      ).allMatches(rules),
      hasLength(2),
    );
    expect(
      rules,
      matches(
        RegExp(
          r'match /roomDeletionLocks/\{code\}.*?allow delete: if.*?'
          r'!existsAfter\(/databases/\$\(database\)/documents/'
          r'rooms/\$\(code\)\)',
          dotAll: true,
        ),
      ),
    );
  });

  test('rule source fences every UID write after identity deletion starts', () {
    final rules = _firestoreRules();
    expect(rules, contains(r'match /serviceIdentityDeletionTombstones/{uid}'));
    expect(rules, contains('function serviceIdentityDeletionStarted(uid)'));

    final savesStart = rules.indexOf(r'match /saves/{uid}');
    final roomsStart = rules.indexOf(r'match /rooms/{code}');
    final locksStart = rules.indexOf(r'match /roomDeletionLocks/{code}');
    expect(savesStart, greaterThanOrEqualTo(0));
    expect(roomsStart, greaterThan(savesStart));
    expect(locksStart, greaterThan(roomsStart));
    final saveRules = rules.substring(savesStart, roomsStart);
    final roomRules = rules.substring(roomsStart, locksStart);
    final roomWriteRules = roomRules.substring(
      0,
      roomRules.indexOf('allow delete:'),
    );

    expect(saveRules, contains('!serviceIdentityDeletionStarted(uid)'));
    expect(
      RegExp(
        r'allow (?:create|update):.*?'
        r'!serviceIdentityDeletionStarted\(request\.auth\.uid\)',
        dotAll: true,
      ).allMatches(roomWriteRules),
      hasLength(2),
    );
    for (final marker in const [
      r'match /sparks/{senderId}',
      r'match /circleAdds/{senderId}',
    ]) {
      final start = roomRules.indexOf(marker);
      expect(start, greaterThanOrEqualTo(0));
      final nextMatch = roomRules.indexOf(
        '\n      match /',
        start + marker.length,
      );
      final block = roomRules.substring(
        start,
        nextMatch < 0 ? roomRules.length : nextMatch,
      );
      expect(
        block,
        contains('!serviceIdentityDeletionStarted(request.auth.uid)'),
      );
      expect(
        RegExp(
          r'!serviceIdentityDeletionStarted\(',
          dotAll: true,
        ).allMatches(block),
        hasLength(2),
      );
      expect(block, contains('.data.uid'));
    }
  });

  test(
    'fresh room codes reserve by write because missing rooms are private',
    () {
      final cloud = File('lib/cloud.dart').readAsStringSync();
      final start = cloud.indexOf(
        'final freshCode = await reserveFreshRoomCode(',
      );
      final end = cloud.indexOf('return RoomPublishResult.success(', start);
      expect(start, greaterThanOrEqualTo(0));
      expect(end, greaterThan(start));

      final reservation = cloud.substring(start, end);
      expect(
        reservation,
        contains('writeOwnedRoom(candidateCode, newRoomData)'),
      );
      expect(reservation, isNot(contains('.get()')));
    },
  );

  test('Circle-add receipts are text-free and owner-only', () {
    final rules = _firestoreRules();
    final start = rules.indexOf(r'match /circleAdds/{senderId}');
    expect(start, greaterThanOrEqualTo(0));
    final block = rules.substring(start);

    expect(block, contains("request.resource.data.kind == 'circle_added'"));
    expect(block, contains("'sender', 'kind', 'sentAt'"));
    expect(block, contains('allow read, delete: if request.auth != null'));
    expect(block, contains('== request.auth.uid'));
    expect(block, contains('allow update: if false'));
  });

  test('room teardown clears private receipts before the public parent', () {
    final cloud = File('lib/cloud.dart').readAsStringSync();
    final helper = cloud.substring(
      cloud.indexOf('_deleteOwnedRoom(String code)'),
    );
    final privateChildrenStart = helper.indexOf(
      'Future<void> _deleteRoomPrivateChildren',
    );
    final ownerDelete = helper.substring(0, privateChildrenStart);
    final privateChildren = helper.substring(privateChildrenStart);
    final privateChildrenEnd = privateChildren.indexOf('\n  ///');
    final privateChildrenMethod = privateChildren.substring(
      0,
      privateChildrenEnd,
    );

    expect(
      helper,
      contains('if (clean == null) return _OwnedRoomDeleteResult.invalid;'),
    );
    expect(helper, contains("ownerSnapshot.data()?['uid'] != _uid"));
    expect(privateChildren, contains("const ['sparks', 'circleAdds']"));
    expect(privateChildren, contains('batch.delete(doc.reference)'));
    expect(
      ownerDelete.indexOf('room.get()'),
      lessThan(ownerDelete.indexOf('_deleteRoomPrivateChildren(room)')),
    );
    expect(
      ownerDelete.indexOf('_deleteRoomPrivateChildren(room)'),
      lessThan(ownerDelete.indexOf('..delete(_discoverableSpaces.doc(clean))')),
    );
    expect(
      ownerDelete.indexOf('..delete(_discoverableSpaces.doc(clean))'),
      lessThan(ownerDelete.indexOf('batch.commit()')),
    );
    expect(
      privateChildrenMethod,
      contains('.get(const GetOptions(source: Source.server))'),
    );
    expect(privateChildrenMethod, contains('batch.commit()'));
    expect(cloud, contains('deleteAllOwnedRoomsAndConfirmEmpty('));
    expect(cloud, contains('createServerDeletionFence()'));
    expect(cloud, contains('deleteParentAndFenceAtomically()'));
    expect(cloud, contains('..delete(room.reference)'));
    expect(
      cloud,
      contains('..delete(_cloud._discoverableSpaces.doc(room.id))'),
    );
    expect(cloud, contains('..delete(_lock)'));
    expect(cloud, contains('await _deleteOwnedRoom(cleanRoomCode);'));
    expect(cloud, contains('await _deleteOwnedRoom(code);'));
    expect(cloud, contains('removed == _OwnedRoomDeleteResult.deleted ||'));
    expect(cloud, contains(r'CloudSync room reset not confirmed: $removed'));
  });

  test('social requests validate codes and share the identity serializer', () {
    final cloud = File('lib/cloud.dart').readAsStringSync();
    final shell = File('lib/screens/shell.dart').readAsStringSync();

    expect(
      RegExp(r'_cleanRoomCode\(').allMatches(cloud).length,
      greaterThan(9),
    );
    expect(cloud, contains('Future<void>? _initFuture'));
    expect(cloud, contains('Future<bool> ensureAvailable()'));
    expect(cloud, contains('if (active != null) return active;'));
    expect(cloud, contains('FirebaseAuth.instance.currentUser'));
    expect(cloud, contains('if (!await ensureSocialSession())'));
    expect(cloud, contains('Future<T> _runAuthChange<T>'));
    expect(cloud, contains('FirebaseIdentityMutationQueue'));
    expect(cloud, contains('_identityMutationQueue.ensureServiceIdentity'));
    expect(cloud, contains('_identityMutationQueue.runAuthChange(action)'));
    expect(
      RegExp(r'_runAuthChange\(').allMatches(cloud).length,
      greaterThanOrEqualTo(5),
    );
    expect(shell, contains('Future<String?>? _enableCloudFuture'));
    expect(shell, contains('if (active != null) return active;'));
  });

  test('exact-code visits stay public until a Circle write needs identity', () {
    final social = File('lib/social.dart').readAsStringSync();
    final cloud = File('lib/cloud.dart').readAsStringSync();
    final visitor = File('lib/screens/visit_room.dart').readAsStringSync();
    final circle = File('lib/screens/hearth_circle.dart').readAsStringSync();

    final prompt = social.substring(
      social.indexOf('Future<SharedRoomVisit?> promptForSharedRoom'),
      social.indexOf('Future<void> visitSpace'),
    );
    expect(prompt, contains('if (!await cloud.ensureAvailable())'));
    expect(prompt, isNot(contains('ensureSocialSession')));

    final fetchRoom = cloud.substring(
      cloud.indexOf('Future<Map<String, dynamic>?> fetchRoom'),
      cloud.indexOf('Future<bool> unshareRoom'),
    );
    expect(fetchRoom, contains('if (!available) return null;'));
    expect(fetchRoom, isNot(anyOf(contains('socialReady'), contains('_uid'))));

    final visitorReceipt = visitor.substring(
      visitor.indexOf('Future<bool> _notifyOwner(String normalized)'),
      visitor.indexOf(
        '@override',
        visitor.indexOf('Future<bool> _notifyOwner'),
      ),
    );
    expect(
      visitorReceipt.indexOf('ensureSocialSession()'),
      lessThan(visitorReceipt.indexOf('setCircleRelationship(')),
    );
    expect(
      visitorReceipt.indexOf('setCircleRelationship('),
      lessThan(visitorReceipt.indexOf('sendCircleAdd(normalized)')),
    );

    final circleReceipt = circle.substring(
      circle.indexOf('Future<void> _notifyOwnerOfCircleAdd'),
      circle.indexOf('Future<void> _addKeep'),
    );
    expect(
      circleReceipt.indexOf('ensureSocialSession()'),
      lessThan(circleReceipt.indexOf('sendCircleAdd(code)')),
    );
    expect(circle, contains('unawaited(_notifyOwnerOfCircleAdd(clean));'));
  });

  test('cloud initialization retries are coalesced', () async {
    final first = CloudSync.instance.init();
    final second = CloudSync.instance.init();
    expect(identical(first, second), isTrue);
    await Future.wait([first, second]);

    // Flutter tests intentionally stay local-only; the retry helper must be
    // safe and honest rather than manufacturing availability.
    expect(await CloudSync.instance.ensureAvailable(), isFalse);
  });

  test('launch refresh repairs same-version shared-room content', () {
    final shell = File('lib/screens/shell.dart').readAsStringSync();
    final refresh = shell.substring(
      shell.indexOf('Future<void> _refreshPublishedRoom()'),
      shell.indexOf('Future<RoomPublishResult> _publishSpaceRoom'),
    );

    expect(refresh, contains('publishSpaceRoomState('));
    expect(refresh, contains('current: state'));
    expect(refresh, isNot(contains('skipCurrentVersion')));
  });

  test('failed reset cleanup preserves its owner identity for retry', () {
    final cloud = File('lib/cloud.dart').readAsStringSync();
    final reset = cloud.substring(cloud.indexOf('Future<bool> resetProfile'));

    expect(cloud, contains("'emberkeep_pending_room_cleanup'"));
    expect(cloud, contains('class _PendingRoomCleanup'));
    expect(cloud, contains('record.owner != owner'));
    expect(cloud, contains('Future<bool> _prepareIdentityChange()'));
    expect(
      RegExp(r'!await _prepareIdentityChange\(\)').allMatches(cloud).length,
      3,
    );
    expect(reset, contains('_rememberPendingRoomCleanup'));
    expect(reset, contains('_forgetPendingRoomCleanup'));
    expect(reset, contains('removed == _OwnedRoomDeleteResult.deleted'));
    expect(reset, contains('removed == _OwnedRoomDeleteResult.absent'));
    expect(reset, contains('user?.isAnonymous == true && fullyErased'));
    expect(
      reset.indexOf('await _deleteOwnedRoom(cleanRoomCode)'),
      lessThan(reset.indexOf('await user!.delete()')),
    );
    expect(
      cloud,
      contains(r'CloudSync dropped stale pending room cleanup: $result'),
    );
    expect(
      cloud,
      contains('account has not been deleted; stay signed in and try again.'),
    );
  });

  testWidgets('visit validates, loads, and retries without dismissing', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    await tester.binding.setSurfaceSize(const Size(320, 568));
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.binding.setSurfaceSize(null);
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    var fetches = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => visitSpace(
                context,
                fetcher: (code) async {
                  fetches++;
                  expect(code, 'ABC234');
                  await Future<void>.delayed(const Duration(milliseconds: 20));
                  if (fetches == 1) throw StateError('offline');
                  return null;
                },
              ),
              child: const Text('Open visit'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open visit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('visit-space-code')), 'bad');
    await tester.tap(find.byKey(const Key('visit-space-submit')));
    await tester.pump();
    expect(fetches, 0);
    expect(find.byKey(const Key('visit-space-error')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('visit-space-code')), 'abc234');
    await tester.tap(find.byKey(const Key('visit-space-submit')));
    await tester.pump();
    expect(find.byKey(const Key('visit-space-loading')), findsOneWidget);
    expect(find.text('Visit a space'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump();
    expect(fetches, 1);
    expect(find.byKey(const Key('visit-space-error')), findsOneWidget);
    expect(find.textContaining('Couldn’t reach'), findsOneWidget);
    expect(find.text('Visit a space'), findsOneWidget);

    await tester.tap(find.byKey(const Key('visit-space-submit')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump();
    expect(fetches, 2);
    expect(find.textContaining('No shared space found'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('share Done remains reachable at large text', (tester) async {
    tester.view.devicePixelRatio = 1;
    await tester.binding.setSurfaceSize(const Size(320, 568));
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.binding.setSurfaceSize(null);
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => showShareSpaceDialog(
                context,
                code: 'ABC234',
                onStop: () async => true,
              ),
              child: const Text('Open share'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open share'));
    await tester.pumpAndSettle();
    final done = find.byKey(const Key('share-space-done'));
    expect(done, findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(done);
    await tester.pump();
    await tester.tap(done);
    await tester.pumpAndSettle();
    expect(find.text('Your space is live'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('share dialog names an unconfirmed Discover cleanup honestly', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => showShareSpaceDialog(
                context,
                code: 'ABC234',
                discoveryCleanupPending: true,
                onDiscoverableChanged: (_) async => true,
                onStop: () async => true,
              ),
              child: const Text('Open share'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open share'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Cleanup will retry when you reconnect'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('share dialog tells the truth when a visitor page is published', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => showShareSpaceDialog(
                context,
                code: 'ABC234',
                visitorPagePublished: true,
                onStop: () async => true,
              ),
              child: const Text('Open share'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open share'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('follows the audience on each card'),
      findsOneWidget,
    );
    expect(find.textContaining('Your Me name, writing'), findsNothing);
  });

  testWidgets('share preview is explicit and stop sharing asks first', (
    tester,
  ) async {
    var previews = 0;
    var stops = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => showShareSpaceDialog(
                context,
                code: 'ABC234',
                onPreview: () => previews++,
                onStop: () async {
                  stops++;
                  return true;
                },
              ),
              child: const Text('Open share'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open share'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('a few small signs of presence'),
      findsOneWidget,
    );
    expect(find.textContaining('cards and photos'), findsNothing);
    await tester.tap(find.byKey(const Key('share-space-preview')));
    expect(previews, 1);

    final stop = find.byKey(const Key('share-space-stop'));
    await tester.ensureVisible(stop);
    await tester.tap(stop);
    await tester.pumpAndSettle();
    expect(find.text('Stop sharing this space?'), findsOneWidget);
    expect(stops, 0);

    await tester.tap(find.text('KEEP SHARING'));
    await tester.pumpAndSettle();
    expect(find.text('Your space is live'), findsOneWidget);
    expect(stops, 0);

    await tester.ensureVisible(stop);
    await tester.tap(stop);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('share-space-confirm-stop')));
    await tester.pumpAndSettle();
    expect(stops, 1);
    expect(find.text('Your space is live'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
