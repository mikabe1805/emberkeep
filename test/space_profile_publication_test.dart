import 'package:emberkeep/cloud.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/social.dart';
import 'package:flutter_test/flutter_test.dart';

RoomPublicationClient _client({
  required Future<RoomPublishResult> Function(
    Map<String, dynamic> display, {
    String? code,
  })
  publish,
  Future<bool> Function(String code)? unshare,
  RoomAndSpaceProfilePublisher? publishCombined,
}) => RoomPublicationClient(
  ensureAvailable: () async => true,
  ensureSocialSession: () async => true,
  ownerUid: () => 'owner-uid',
  fetchRoom: (_) async => null,
  publishRoom: publish,
  publishRoomWithSpaceProfile: publishCombined,
  unshareRoom: unshare ?? (_) async => true,
);

void main() {
  test('publishes generated room and separate public/mutual decks', () async {
    final state = GameState()
      ..shareSpaceProfile = true
      ..playerName = 'Mika'
      ..spaceIntro = 'Anyone can read this.'
      ..featuredGoalTitles.add('Only mutuals see this goal')
      ..spaceSeasonText = 'Only me';
    state.spaceCardAudiences
      ..[SpaceCardKind.about] = SpaceAudience.anyone
      ..[SpaceCardKind.rightNow] = SpaceAudience.mutuals
      ..[SpaceCardKind.thisSeason] = SpaceAudience.onlyMe;

    Map<String, dynamic>? room;
    Map<String, dynamic>? capturedPublicProfile;
    Map<String, dynamic>? capturedMutualProfile;
    final result = await publishSpaceRoomState(
      state,
      current: GameState.fromJson(state.toJson()),
      code: 'ABC234',
      publicationClient: _client(
        publish: (display, {code}) async {
          room = display;
          return RoomPublishResult.success(code!);
        },
      ),
      profilePublisher:
          (
            code, {
            required Map<String, dynamic>? publicProfile,
            required Map<String, dynamic>? mutualProfile,
          }) async {
            capturedPublicProfile = publicProfile;
            capturedMutualProfile = mutualProfile;
            return SpaceProfilePublishResult.saved;
          },
      visitorProfileSharingEnabled: true,
      visitorPhotoSharingEnabled: false,
    );

    expect(result.code, 'ABC234');
    expect(room?['profileVisible'], isFalse);
    expect(room?['about'], isEmpty);
    expect(capturedPublicProfile?['cardOrder'], ['about']);
    expect(capturedPublicProfile?['about'], 'Anyone can read this.');
    expect(capturedMutualProfile?['cardOrder'], ['about', 'rightNow']);
    expect(capturedMutualProfile?['featuredGoals'], [
      'Only mutuals see this goal',
    ]);
    expect(capturedMutualProfile.toString(), isNot(contains('Only me')));
  });

  test('a rejected fresh profile abandons the newly reserved room', () async {
    final state = GameState()
      ..shareSpaceProfile = true
      ..spaceIntro = 'https://contact.example';
    state.spaceCardAudiences[SpaceCardKind.about] = SpaceAudience.anyone;
    final removed = <String>[];

    final result = await publishSpaceRoomState(
      state,
      current: GameState.fromJson(state.toJson()),
      code: null,
      publicationClient: _client(
        publish: (_, {code}) async => const RoomPublishResult.success('ABC234'),
        unshare: (code) async {
          removed.add(code);
          return true;
        },
      ),
      profilePublisher:
          (_, {required publicProfile, required mutualProfile}) async =>
              SpaceProfilePublishResult.rejected,
      visitorProfileSharingEnabled: true,
      visitorPhotoSharingEnabled: false,
    );

    expect(result.failure, RoomPublishFailure.profileRejected);
    expect(removed, ['ABC234']);
  });

  test('a closed page publishes no authored projection', () async {
    Map<String, dynamic>? capturedPublicProfile = {'unexpected': true};
    Map<String, dynamic>? capturedMutualProfile = {'unexpected': true};

    final result = await publishSpaceRoomState(
      GameState(),
      current: GameState(),
      code: 'ABC234',
      publicationClient: _client(
        publish: (_, {code}) async => RoomPublishResult.success(code!),
      ),
      profilePublisher:
          (
            _, {
            required Map<String, dynamic>? publicProfile,
            required Map<String, dynamic>? mutualProfile,
          }) async {
            capturedPublicProfile = publicProfile;
            capturedMutualProfile = mutualProfile;
            return SpaceProfilePublishResult.saved;
          },
      visitorProfileSharingEnabled: true,
      visitorPhotoSharingEnabled: false,
    );

    expect(result.ok, isTrue);
    expect(capturedPublicProfile, isNull);
    expect(capturedMutualProfile, isNull);
  });

  test(
    'production-shaped client publishes room and profiles atomically',
    () async {
      final state = GameState()
        ..shareSpaceProfile = true
        ..spaceIntro = 'Visible to anyone';
      state.spaceCardAudiences[SpaceCardKind.about] = SpaceAudience.anyone;
      var ordinaryRoomWrites = 0;
      var combinedWrites = 0;

      final result = await publishSpaceRoomState(
        state,
        current: GameState.fromJson(state.toJson()),
        code: 'ABC234',
        publicationClient: _client(
          publish: (_, {code}) async {
            ordinaryRoomWrites++;
            return RoomPublishResult.success(code!);
          },
          publishCombined:
              (
                room, {
                code,
                required publicProfile,
                required mutualProfile,
              }) async {
                combinedWrites++;
                expect(room['profileVisible'], isFalse);
                expect(publicProfile?['about'], 'Visible to anyone');
                expect(mutualProfile?['about'], 'Visible to anyone');
                return RoomPublishResult.success(code!);
              },
        ),
        visitorProfileSharingEnabled: true,
        visitorPhotoSharingEnabled: false,
      );

      expect(result.ok, isTrue);
      expect(combinedWrites, 1);
      expect(ordinaryRoomWrites, 0);
    },
  );
}
