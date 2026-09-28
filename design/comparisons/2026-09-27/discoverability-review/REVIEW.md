# Discoverability pass — September 27–28, 2026

## Correction and source

The owner called out the two Goals controls in the upper right: their outcomes
were unclear and they did not feel like two separate opportunities. He also
pointed to useful Room of Days features hidden by unclear presentation. The
source for this pass is the current room and desk design system, the previous
installed Android build, and those two jobs. No generated page is treated as
proof of implementation.

The retained hierarchy is one bright current-Quest action. The new destinations
use separate quiet surfaces and literal names so they can be found without
competing with it.

## What the installed build shows

| Moment | Visible promise | Checked route |
| --- | --- | --- |
| Goals, active path | `Your goals / Review & reshape` and `New goal / Begin a fresh path` are separate cards. | The first opens the existing-goal workshop; the second opens new-goal creation. |
| Featured Quest | `Help, plans & writing` sits beside `Manage`. | It opens Room Guide, whose first three doors are Help for Today, Plans, and Journal. |
| Selected Daybook day | `PLAN QUEST` is distinct from `CLASS · EXAM · MORE`. | The first plans a one-off Quest; the second opens the existing calendar item chooser. |
| Journal page in read mode | `Keep this` is legible in the page header. | It saves the existing page to Keepsakes and changes to `Kept in Keepsakes`; the action also appears immediately after a newly written page is saved. |

The Android captures came from an installed debug APK built from this source
slice. The full-frame same-emulator pairs in
`../../2026-09-28/evidence-goals-choices.png` and
`../../2026-09-28/evidence-quest-doorway.png` show the visible change. Quest data
varied between captures; only the doorway placement and label are compared.
`../../2026-09-28/discoverability-phone-review.webp` collects the final resting
screens. `../../2026-09-28/evidence-goals-choices-fullres.png` preserves the
Goals pair at the Android capture's native 1080×2400 resolution on each side.

## Reflow and limits

Goals was rendered in active, empty, return, hard-day, narrow, large-text, and
2× text states. The Room Guide's Help/Plans/Journal quick actions were rendered
at 320×568 and 2× text, and the Daybook chooser at normal and narrow sizes.
Focused interaction tests cover the destination routes, Journal pin persistence,
and the Daybook split. On the frozen source, all 1,208 app tests passed, the
feature-on packet passed (28 tests, 1 expected skip), analysis found no issues,
and release web and Android debug builds succeeded. The installed APK was
used for the current Goals, Quest, and Guide captures.

The real iPhone's touch feel, sound, motion, and TestFlight processing remain
owner/device gates. Static captures and Android interaction do not settle them.
