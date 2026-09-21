# Owner direction — Quest-board feedback polish

Recorded 2026-09-18 from the current owner request and three attached phone
captures. This note is the repository-local source for a bounded polish pass;
it does not turn the screenshots into a permanent visual template.

## Current owner direction

> "got some feedback from my mom! there’s also some UI improvements to be made, like i don’t like how much the things in the middle of the screenshot blend together. be on the lookout for other opportunities for improvement too !"

The requested scope is therefore:

- honor the tester's report that an ordinary non-main Quest should not require
  a select/open step followed by a completion step;
- separate the Quest screen's middle status and utility controls so they no
  longer read as one undifferentiated band;
- make proportionate nearby improvements revealed by the same audit;
- add useful relationship-oriented goal starters based on the tester's examples
  without assuming that every keeper has a partner.

## Tester feedback visible in the attachments

The owner's mother wrote:

> "Also, I love the new design of the app, but I did like it better when you could just click once to check that something is done because I believe that if something can be done once then it shouldn’t take two clicks"

> "But I think it’s so cool. You should add goals like partner, for example send a message to my partner, or buy flowers, or make food etc"

When asked what she meant, she clarified:

> "No, I now press it and then have to check off"

The owner then identified the reported case as a non-main Quest:

> "ohhh got it if it’s not a main quest true"

## Attachment identity

- Photo 1: `DD0E3C677F366930B5CC610D368030056304129B284DE6A4385F03D3CB04DF9E`
- Photo 2: `5AB9D22FBF1535643BAE53BBE6648B8A5100CEA2A03B8A3F1FCDACB68CA31854`
- Photo 3: `D6F89A45BE4BD90983C70CE05DB597CF368B67FE1A77BF687870AFAAA67572B2`

The files arrived through Codex remote attachments under request
`01a0b646-69cc-7603-bdf5-4ee7e7cd35bd`. Their hashes preserve source
identity without copying a private message thread into the application bundle.

## Live-checkout clarification

The inspected release checkout already routes every ordinary featured and
compact `QuestCard` tap through the same canonical completion callback. The
compact row nevertheless ends in a chevron while only the featured card says
`MARK COMPLETE`. This pass treats that mismatch as the actionable defect: keep
the one-tap behavior, make it visually legible, and lock it with a regression.
Special Journal, timer, workout, and all-day Quests retain their explicit
authored flows.
