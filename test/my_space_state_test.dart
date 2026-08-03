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
        ..remove('spaceSeasonText')
        ..remove('spaceSeasonPhotoNoteId');

      final restored = GameState.fromJson(oldSave);

      expect(restored.spaceCardOrder, defaultSpaceCardOrder);
      expect(restored.hiddenSpaceCards, isEmpty);
      expect(restored.spaceSeasonText, isEmpty);
      expect(restored.spaceSeasonPhotoNoteId, isNull);
      expect(restored.spaceSeasonPhotoNote, isNull);
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
        intro: '  i make things,   care for people.  ',
        featuredGoalTitles: const [
          ' Finish the essay ',
          'not a real goal',
          'Finish the essay',
          'Call family',
        ],
        seasonText: '  ${'x' * 220}  ',
        seasonPhotoNoteId: '  photo-note  ',
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
      expect(state.spaceIntro, 'i make things, care for people.');
      expect(state.featuredGoalTitles, const [
        'Finish the essay',
        'Call family',
      ]);
      expect(state.spaceSeasonText.runes.length, 180);
      expect(state.spaceSeasonPhotoNoteId, 'photo-note');
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
        intro: 'private page',
        featuredGoalTitles: const [],
        seasonText: 'Learning to begin again.',
        seasonPhotoNoteId: photo.id,
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
      expect(restored.spaceCardOrder, state.spaceCardOrder);
      expect(restored.hiddenSpaceCards, state.hiddenSpaceCards);
      expect(restored.spaceSeasonText, state.spaceSeasonText);
      expect(restored.spaceSeasonPhotoNoteId, photo.id);
      expect(restored.spaceSeasonPhotoNote?.id, photo.id);

      restored.setJournal(const []);
      expect(restored.spaceSeasonPhotoNoteId, photo.id);
      expect(restored.spaceSeasonPhotoNote, isNull);
    });
  });
}
