# Room of Days polished Build 39 contract

## Owner request

> alright awesome, i think now is the time to attempt again to get everything into a new polished build and doing passes to make sure the quality is great across the board and across all sectors. then, we'll package it into a better app store thing so people could easily understand why they should download room of days when looking it up

## Active product direction

- Room of Days makes ordinary effort feel meaningful without guilt, debt, or a generic productivity-dashboard voice.
- The same authored room identity carries through Me, Quests, room previews, and visits.
- A personal room photo is private by default and can appear in a public room only after a separate explicit opt-in.
- The mantel-keepsake experiment is superseded. The owner said, verbatim, "the keepsake stuff look pretty bad". Build 39 removes that experiment from visible controls, room rendering, public copy, and public semantics while retaining its bounded legacy data field only for save and wire compatibility.
- The first Quest for a goal still requires explicit Workshop acceptance.
- Music remains optional and off by default.

## Release and App Store boundary

This pass may create and upload a new internal TestFlight candidate and prepare an App Store draft. It does not authorize public App Store submission. Public readiness still requires current physical-device, owner-feel, two-account privacy, accessibility, sound, performance, upgrade, and Apple-account evidence.

## Decisive first slice

On the clean Build 38 successor, open Me with a legacy non-empty `roomKeepsakes` value and a chosen private room photo. The same room should appear in Me and Quests with the photo, no mantel objects, no keepsake control, and no keepsake narration. A local public preview must exclude the photo until separately opted in, and Discover/visit surfaces must never display keepsake copy. Existing save and public-room protocol tests must still accept and sanitize the inert legacy field.
