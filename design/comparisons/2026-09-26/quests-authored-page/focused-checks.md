# Quests first-slice checks

Implementation revision: `commit:b8950307410ff72b98bf0266ab36bd81b86974ac`.

The focused Flutter run passed 43 tests across `quests_daily_field_test.dart`,
`quest_selection_flow_test.dart`, `capacity_journeys_test.dart`,
`quests_feedback_test.dart`, `quest_card_polish_test.dart`, and
`night_routine_feedback_test.dart` with one test worker. It covers the daily
field, a featured Quest's named action and completion, undo, compact-row
completion and drag, timer and linked Goal boundaries, tomorrow planning,
Gentle Mode, and the evening ledger. A prior parallel run had one intermittent
reflection failure; that exact test passed in isolation and the serial focused
run passed. This is a host regression result, not a physical-device verdict.

`flutter analyze --no-pub` found no issues in the changed Quests source and
focused test files. The two focused golden capture tests passed for the phone
shell and crowded daily field, including the 320×568 enlarged-text fixture.
The phone-shell test checks that the first Quest action clears the fixed dock;
the enlarged-text test now checks that MARK COMPLETE is visible and tappable
before scrolling. The 320×568 first frame passes that check with its domain
readouts, optional-field toggle, and board tools still available after the
featured card.

The installed Android emulator was then used with an ordinary starter board.
The first screen shows one featured Quest and its complete action before the
board tools. After scrolling through four supporting Quests, tomorrow planning
and Close the Day are both fully visible in the list footer. Tapping Close the
Day opened the ledger. Returning to Quests and tapping MARK COMPLETE on the
featured starter Quest awarded 10 XP, raised Body to 3, and showed the completed
Quest as a banked compact row. The Android captures show these states; they do
not measure haptic, sound, or thumb feel on the owner's iPhone.

The post-completion board intentionally retains the completed selection as an
acknowledged identity until another Quest is selected, matching the existing
selection contract in `lib/screens/quests.dart`. It therefore has no automatic
new featured card during that settled state; this remains an owner judgment in
the review of the current slice.
