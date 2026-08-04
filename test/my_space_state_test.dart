import 'package:emberkeep/engine.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/tokens.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('My Space deck state', () {
    test('old saves keep the original three cards and an empty season', () {
      final oldSave = GameState().toJson()
        ..remove('spaceCardOrder')
        ..remove('hiddenSpaceCards')
        ..remove('visitorSpaceCards')
        ..remove('spaceSeasonText')
        ..remove('spaceSeasonPhotoNoteId')
        ..remove('spaceProfilePhotoNoteId')
        ..remove('shareSpaceProfilePhoto')
        ..remove('shareSpaceSeasonPhoto');

      final restored = GameState.fromJson(oldSave);

      expect(restored.spaceCardOrder, defaultSpaceCardOrder);
      expect(restored.hiddenSpaceCards, isEmpty);
      expect(restored.visitorSpaceCards, {
        SpaceCardKind.about,
        SpaceCardKind.rightNow,
      });
      expect(restored.spaceSeasonText, isEmpty);
      expect(restored.spaceSeasonPhotoNoteId, isNull);
      expect(restored.spaceSeasonPhotoNote, isNull);
      expect(restored.spaceProfilePhotoNoteId, isNull);
      expect(restored.spaceProfilePhotoNote, isNull);
      expect(restored.shareSpaceProfilePhoto, isFalse);
      expect(restored.shareSpaceSeasonPhoto, isFalse);
    });

    test('one setter cleans and atomically applies the whole page', () {
      final state = GameState()
        ..goals.addAll([
          Goal(title: 'Finish the essay', stat: Stat.intl, target: 5),
          Goal(title: 'Call family', stat: Stat.soc, target: 5),
        ]);
      var notifications = 0;
      state.addListener(() => notifications++);

      state.setSpacePage(
        order: const [
          SpaceCardKind.thisSeason,
          SpaceCardKind.about,
          SpaceCardKind.thisSeason,
        ],
        hidden: const [SpaceCardKind.rightNow, SpaceCardKind.rightNow],
        visitorVisible: const [
          SpaceCardKind.pinnedMoments,
          SpaceCardKind.pinnedMoments,
          SpaceCardKind.thisSeason,
        ],
        intro: '  i make things,   care for people.  ',
        featuredGoalTitles: const [
          ' Finish the essay ',
          'not a real goal',
          'Finish the essay',
          'Call family',
        ],
        seasonText: '  ${'x' * 220}  ',
        profilePhotoNoteId: ' profile-photo-note ',
        seasonPhotoNoteId: '  photo-note  ',
        shareProfilePhoto: true,
        shareSeasonPhoto: true,
        shareProfile: true,
      );

      expect(notifications, 1);
      expect(state.spaceCardOrder, const [
        SpaceCardKind.thisSeason,
        SpaceCardKind.about,
        SpaceCardKind.rightNow,
        SpaceCardKind.pinnedMoments,
      ]);
      expect(state.hiddenSpaceCards, {SpaceCardKind.rightNow});
      expect(state.visitorSpaceCards, {
        SpaceCardKind.pinnedMoments,
        SpaceCardKind.thisSeason,
      });
      expect(state.spaceIntro, 'i make things, care for people.');
      expect(state.featuredGoalTitles, const [
        'Finish the essay',
        'Call family',
      ]);
      expect(state.spaceSeasonText.runes.length, 180);
      expect(state.spaceProfilePhotoNoteId, 'profile-photo-note');
      expect(state.spaceSeasonPhotoNoteId, 'photo-note');
      expect(state.shareSpaceProfilePhoto, isTrue);
      expect(state.shareSpaceSeasonPhoto, isTrue);
      expect(state.shareSpaceProfile, isTrue);

      state.setSpaceProfile(
        intro: 'updated intro',
        goals: const ['Call family'],
      );
      expect(notifications, 2);
      expect(state.spaceCardOrder.first, SpaceCardKind.thisSeason);
      expect(state.hiddenSpaceCards, {SpaceCardKind.rightNow});
      expect(state.spaceSeasonText.runes.length, 180);
      expect(state.spaceSeasonPhotoNoteId, 'photo-note');
      expect(state.shareSpaceProfile, isTrue);
    });

    test(
      'restore ignores unknown and duplicate card names, then appends gaps',
      () {
        final encoded = GameState().toJson()
          ..['spaceCardOrder'] = <Object?>[
            'thisSeason',
            'futureCard',
            'about',
            'thisSeason',
            42,
          ]
          ..['hiddenSpaceCards'] = <Object?>[
            'rightNow',
            'futureCard',
            'rightNow',
          ]
          ..['visitorSpaceCards'] = <Object?>[
            'pinnedMoments',
            'futureCard',
            'pinnedMoments',
          ]
          ..['spaceSeasonText'] = '  a quiet\n  semester  '
          ..['spaceSeasonPhotoNoteId'] = '  deleted-note  ';

        final restored = GameState.fromJson(encoded);

        expect(restored.spaceCardOrder, const [
          SpaceCardKind.thisSeason,
          SpaceCardKind.about,
          SpaceCardKind.rightNow,
          SpaceCardKind.pinnedMoments,
        ]);
        expect(restored.hiddenSpaceCards, {SpaceCardKind.rightNow});
        expect(restored.visitorSpaceCards, {SpaceCardKind.pinnedMoments});
        expect(restored.spaceSeasonText, 'a quiet\nsemester');
        expect(restored.spaceSeasonPhotoNoteId, 'deleted-note');
        expect(restored.spaceSeasonPhotoNote, isNull);
      },
    );

    test('card names and season photo link survive a save round-trip', () {
      final photo = Note(
        id: 'season-photo',
        at: DateTime(2026, 8, 3),
        text: 'First week back.',
        images: const ['journal/first-week.webp'],
      );
      final state = GameState()..journal = [photo];
      state.setSpacePage(
        order: const [
          SpaceCardKind.pinnedMoments,
          SpaceCardKind.about,
          SpaceCardKind.thisSeason,
          SpaceCardKind.rightNow,
        ],
        hidden: const [SpaceCardKind.about],
        visitorVisible: const [
          SpaceCardKind.pinnedMoments,
          SpaceCardKind.thisSeason,
        ],
        intro: 'private page',
        featuredGoalTitles: const [],
        seasonText: 'Learning to begin again.',
        profilePhotoNoteId: photo.id,
        seasonPhotoNoteId: photo.id,
        shareProfilePhoto: true,
        shareSeasonPhoto: true,
        shareProfile: false,
      );

      final encoded = state.toJson();
      final restored = GameState.fromJson(encoded);

      expect(encoded['spaceCardOrder'], const [
        'pinnedMoments',
        'about',
        'thisSeason',
        'rightNow',
      ]);
      expect(encoded['hiddenSpaceCards'], const ['about']);
      expect(encoded['visitorSpaceCards'], const [
        'pinnedMoments',
        'thisSeason',
      ]);
      expect(restored.spaceCardOrder, state.spaceCardOrder);
      expect(restored.hiddenSpaceCards, state.hiddenSpaceCards);
      expect(restored.visitorSpaceCards, state.visitorSpaceCards);
      expect(restored.spaceSeasonText, state.spaceSeasonText);
      expect(restored.spaceSeasonPhotoNoteId, photo.id);
      expect(restored.spaceSeasonPhotoNote?.id, photo.id);
      expect(restored.spaceProfilePhotoNoteId, photo.id);
      expect(restored.spaceProfilePhotoNote?.id, photo.id);
      expect(restored.shareSpaceProfilePhoto, isTrue);
      expect(restored.shareSpaceSeasonPhoto, isTrue);

      restored.setJournal(const []);
      expect(restored.spaceSeasonPhotoNoteId, photo.id);
      expect(restored.spaceSeasonPhotoNote, isNull);
      expect(restored.spaceProfilePhotoNoteId, photo.id);
      expect(restored.spaceProfilePhotoNote, isNull);
    });
  });
}
