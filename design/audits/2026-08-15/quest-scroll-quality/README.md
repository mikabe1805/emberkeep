# Quest scroll quality pass

## Scope

- Surface: Quests
- Goal: reverse through a long quest list without revealing the room until the
  list has genuinely returned to its top
- Secondary check: keep Focus mode usable on a 320 x 568 phone surface
- Evidence state: 16 quests, 430 x 932, Reduced Motion; Focus mode at 320 x 568

## Result

The inner quest list now owns reverse scrolling while it still has content
above it. The room remains parked and the overlap treatment remains present.
Once the inner list reaches offset zero, the outer room header may expand and
the overlap treatment clears.

Focus mode now reserves the shared 130 px dock inset. Its two ordering choices
and full-board exit expose button semantics, selected state where applicable,
and at least a 44 px interaction height.

## Captured steps

1. `01-room-resting.png` -- room visible at the board's true top; healthy.
2. `02-list-scrolled.png` -- long list owns the frame; healthy.
3. `03-reverse-list-first.png` -- reverse motion advances the list while the
   room stays absent; healthy.
4. `04-room-returned-at-top.png` -- room returns only after both coordinated
   positions reach the top; healthy.
5. `05-focus-short-phone.png` -- Focus ordering controls remain readable and
   comfortably touchable on a short phone, with the full-board exit reachable;
   healthy.

## Verification

- `flutter analyze lib/screens/quests.dart test/capacity_journeys_test.dart`
- `flutter test test/capacity_journeys_test.dart test/quest_card_polish_test.dart test/quest_depth_room_test.dart`
- `flutter build web --release --wasm`
- Source/current comparison:
  `../../../comparisons/2026-08-15/probe-quest-scroll-resting.png`
- Compact flow sheet:
  `../../../comparisons/2026-08-15/quest-scroll-quality-phone.webp`

## Evidence limits

The capture and interaction checks use Flutter's widget-test renderer. They
confirm coordinated offsets, layout, semantics, and rendered states, but do
not certify VoiceOver/TalkBack phrasing, physical-device haptics, or native
frame pacing. The release web build passed; the Chrome-hosted test runner did
not reach execution in this desktop session, so a real mobile-web drag remains
a device check for the next release candidate.
