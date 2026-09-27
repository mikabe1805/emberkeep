# Goals return: study-to-build translation card

## Judged state

- **Study:** `study.png`, a generated 430 × 932 active-Goals return concept.
- **Build:** `../../test/goldens/goals_personal_index_active_430x932.png`, the
  current Flutter golden with the same active apartment Goal and current Quest.
- **Job:** return to one active Goal, identify the next concrete Quest, then
  either open it, review the Goal, review today's three, or make the action
  smaller without the page becoming a dashboard.

The study is a composition and material probe. It is not a pixel target and it
does not prove interaction, large-text behavior, motion, sound, or device feel.

## Translation promises

| Promise from the study | Build translation | Status |
| --- | --- | --- |
| One room owns the whole frame; the kitchen arch is the warm destination behind the commitment. | `GoalWorldBackdrop` retains the continuous room and arch behind the active Goal surface. | retained |
| The active Goal reads as one tactile, dark book-cloth object rather than a stack of generic cards. | The active return surface uses the production `goals-return-bookcloth-v1.png` treatment as one continuous folio through focus, today's three, other goals, and support. | retained |
| One current Quest is the clear next action; alternate routes stay quiet. | The current Quest and `Open Quest` lead the card. Today's three, Review goal, and Make this smaller remain subordinate text actions. | retained |
| The room and content share a convincing desk relationship. | The build anchors the card low over the room and preserves live, reflowing text and hit targets. | adapted |
| Workshop and New goal are present but do not compete with the current commitment. | They remain small header doors above the action surface. | retained |

## Known source deviation

`study.png` invents a large centered foreground desk and a close, leather-bound
folio that is **not present in the canonical runtime room art**. The build must
not crop, manufacture, or imply that desk as if it exists in the canonical
`GoalRoomTravelBackdrop` scene (`goals-threshold-room-v1.webp` and its related
room plates).

The valid translation is the study's relationship: one grounded dark material
folio in a warm room, with the arch and room edge giving it place. The folio
continues through the active commitment, today's field, other goals, and
support instead of breaking into nested cards. It is not exact visual fidelity.
Any claim of exact source fidelity would be false until the canonical room art
contains that foreground object or a separately approved asset supplies it.

## First-slice pass criteria

At the same 430 × 932 active-Goal state, inspect study and build side by side:

1. `GoalRoomTravelBackdrop` keeps the arch and room legible before the folio
   becomes a floating overlay.
2. The Goal title and current Quest are readable before every support route.
3. `Open Quest` is the only luminous action.
4. Today, review, smaller-action, other-goal, and support routes remain inside
   the same folio without becoming a second band of cards.
5. The build does not present the invented desk as canonical room geometry.

If the fifth point is violated, mark the study relationship as lost rather than
adding fabricated furniture to force a match.

## Evidence still required after code

The implementation pass must recapture the active, empty, hard-day,
support-open, selected-field, dense-scroll, narrow large-text, and Reduced
Motion states. It must exercise Open Quest, review/cancel today's three,
Review goal, Make this smaller, Workshop, and New goal. A physical-phone check
remains necessary for thumb hierarchy, scroll cadence, haptics, and OLED value
separation.
