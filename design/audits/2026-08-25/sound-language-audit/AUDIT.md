# SOUND LANGUAGE AUDIT — 2026-08-25 (build 1.0.4+33)

A full review of the audio system: the language it speaks, how faithfully the
code speaks it, and where it should improve next. Sources: `lib/audio.dart` +
`test/interaction_sound_quality_test.dart` (full reads), a call-site sweep of
`lib/` (~244 sounding sites across 52 files), full git history (219 commits),
every `LISTENING-RESULT.md`, the asset tree (144 files, 2.64 MB), the synthesis
tools, and every owner quote about sound recoverable from local transcripts.

**Confidence markers:** ✅ verified first-hand this session · ◑ verified by a
sweep agent with file:line citation (sampled and re-checked) · 💡 design
synthesis / recommendation · ⚠️ gap — could not be observed.

---

## 1. What you're attempting to achieve — in your own words

The goal, reconstructed only from verbatim owner statements:

- *"not polished and expensive like i like"* — the standing bar: sound should
  read **polished and expensive**, never *"like a popping bubbles stim toy"*
  (2026-08-21).
- *"my biggest thing is when im clicking around i want the interactable
  surfaces to feel like different "textures" of sound and interaction"*
  (2026-08-21) — **material follows surface**.
- *"i hate the way the audio stuff sounds right now. i think it's computer
  generated which is why it sounds so harsh and not nice"* (Gen-1 era) —
  nothing may read as harsh, synthetic, or stock.
- *"i do like it when the sound changes notes as you keep clicking around for
  diversity and making tapping around more fun"* — later settled as: plain
  variation by default, melody as a rare easter egg (*"i guess this is a fun
  easter egg though so im cool with keeping it in"*).
- *"im not looking for stone on stone sound system, more so the satisfying
  'dak' of clicking something with weight to it"* — materials are felt weight,
  never Foley realism.

✅ The system SOUND-DESIGN.md describes — one imagined mechanism, one contact
master, one modal body bank, one subliminal room, one pentatonic field, verbs ×
materials × events — is a faithful formalization of those quotes. The language
itself is sound (sic). This audit found no reason to change the grammar; what
it found is places where the app has stopped *speaking* it.

## 2. What is genuinely working

- ✅ **Implementation matches doctrine unusually closely.** The 18 ms duplicate
  gate, the 1/0.93/0.93/0.885 rapid ladder, the 140/430 ms reward suppression,
  the Paired Return machine (4 paced actions → D5-A5-E5-D5, once per screen,
  90 s cooldown), and the pointer-down bob=haptic=sound contract are all real
  in `lib/audio.dart` / `widgets/pressable.dart`, at the documented numbers.
- ✅ **All 122 shipped Room masters are byte-identical to their approved
  audition sources right now** (re-hashed programmatically; 122/122, including
  the pinned SHA-256 on the completion composite). The ship-what-was-approved
  rule is not aspirational — it holds.
- ◑ **Rituals are fully voiced** — `routine_flows.dart` is one of the most
  instrumented files in the app (12 call sites). Night/morning are not a gap.
- ✅ **Platform behavior is respectful**: iOS `.ambient` (mixes with the user's
  music, respects the silent switch), Android takes no audio focus. The app
  never evicts Spotify — a real "expensive app" behavior most apps get wrong.
- ◑ **The material map is mostly on-doctrine** where it exists: slate on
  commit chips and day chips, parchment on page travel, glass on translucent
  switches/dialogs, brass on gold CTAs.

## 3. Places for improvement, ranked

### A. The newest screens don't speak the language — coverage regressed (highest impact)

Your own standing rule (DESIGN-BIBLE.md, since build 26): *"New interactive
surfaces wire their interaction verb before they ship. The daybook shipped with
~20 silent tappable rows, which read as deadness, not restraint."* Builds
30–33 (2026-08-23→25) then shipped the social/discovery feature set with
**zero commits touching `audio.dart` or `pressable.dart`** and zero listening
studies. Result:

- ✅ `screens/discover_spaces.dart` contains **no `Sfx.` call at all**. Its two
  `Pressable`s sound (as fallback wood), but every direct-wired control is
  silent: "I HAVE A CODE" (`:436`), "MANAGE HIDDEN SPACES" (`:451`),
  "COMMUNITY RULES & SAFETY" (`:467`), the manage-hidden dialog's UNHIDE/DONE,
  the error-state "TRY AGAIN".
- ◑ `social.dart`: "PREVIEW PUBLIC VIEW" is silent while its siblings COPY
  LINK / COPY CODE each hand-wire glass (`:1211`, `:1228`) — proof the pattern
  is remember-it-yourself, and one author forgot. The entire STOP SHARING flow
  (including its confirm) is silent.
- ✅ `screens/me.dart`: `_personalizeSpace` (`:214-234`) pushes the full-screen
  arranger with no sound, while every other full-screen push in the same file
  plays parchment first. ◑ Also silent: the space-card hide/show toggle
  (`:931`), the entire "Change your name" flow (`:61`, `:2156`).
- ✅◑ **The daybook Close button is silent four separate times** —
  `daybook_task_editor.dart:162` (✅ read first-hand), `daybook_event_actions
  .dart:280`, `daybook_add_choice_dialog.dart:38`, `daybook_event_editor
  .dart:490` (◑). Same affordance, same omission, four files — the exact
  "keeps shipping silent" failure mode, recurring after it was named.

17 silent-but-interactive sites were individually traced and confirmed (the
sweep prioritized post-build-26 surfaces; it did not exhaustively clear all
~890 raw `onTap`/`onPressed` occurrences — ⚠️ more may exist in older code).
Deliberate silences (Cancel/KEEP SHARING/decline buttons) were checked against
doctrine §10.6 and correctly excluded.

💡 **This is the single highest-leverage fix and needs no new synthesis** —
every silent surface above maps onto an existing verb/material. One wiring
pass restores the newest, most outward-facing screens to the same world as the
rest of the app. 💡 The durable fix is structural, not one more sweep: the
sanctioned path is `Pressable` (which cannot ship silent); consider a lint or
test that flags bare `TextButton`/`IconButton`/`InkWell` in screens the way
`interaction_sound_quality_test.dart` already greps for other invariants, so
the rule enforces itself instead of relying on authors remembering.

### B. Three routing bugs — the code declares one texture, the phone plays another

1. ✅ **Declared-but-inert glass, twice.** `discover_spaces.dart:553-554` and
   `me.dart:4065-4066` declare `material: glass, interactionSound: open` — but
   `glass/open` is not a shipped lane (`audio.dart:405-415`), so `_shadedAsset`
   silently falls back to wood every time. The code reads glass; the phone
   never says it.
2. ✅ **Brass on non-gold.** `memory_cabinet.dart:342,350` plays brass on the
   remove-keepsake control — a muted `Palette.textLo` icon, no gold anywhere.
   Doctrine: *"Gold only = brass — if brass played on non-gold it would stop
   meaning precious."* (Compare `goal_detail.dart:571-579`, where the delete-arm
   correctly pairs brass with `honeyGradient`.)
3. ◑ **Off-convention wood.** `_DiscoverableSpaceCard` (`discover_spaces
   .dart:716`) opens a new screen as wood while every comparable open-a-page
   site in the app uses parchment.

💡 Fix 2 and 3 are one-line material swaps. Fix 1 is a decision: either ship a
`glass/open` lane (see D) or re-declare those two sites as `glass/select`,
which is shipped and semantically close.

### C. The no-repeat guarantee silently breaks on material lanes (~21% of pairs)

✅ Verified by arithmetic on the shipped tables. The router guarantees no two
consecutive *ordinary variants* repeat (`audio.dart:151-154`), but material
lanes have only 3 takes, and `_shadedAsset` folds variants via
`(variant-1) % 3 + 1` (`:672`). Walking the actual cycle
(1,3,2,4,2,5,3,1,4,5,2,3,5,1), three of fourteen consecutive pairs — 2→5,
1→4, 5→2 — collapse onto the **same take**, so two consecutive taps on the
same material lane play the byte-identical file about 21% of the time.
Repetition is, per your own doctrine, "the loudest machine tell there is" —
and it re-enters exactly on the textured surfaces the system exists to
distinguish. (Wood, 5 takes, is unaffected; Paired Return is unaffected.)

💡 Fix options, cheapest first: (a) make the fold lane-aware — track the last
*take per lane* and bump on collision (pure router change, testable in
`InteractionSoundRouter` with no new audio); (b) render takes 4-5 for the nine
lanes through the existing study pipeline so the fold becomes the identity.
(a) ships in an afternoon and preserves byte-locks.

### D. The material grammar is still half-shipped — and the code is already asking for more

◑ Shipped lanes: slate/{select,navigate,place}, page/{navigate,open},
glass/{select,place}, brass/{select,place} — 9 of 20 combinations. The
fallback design is correct ("the axis can grow lane by lane"), but two real
call sites already declare the unshipped `glass/open` (§B.1), which is the
signal it's time to grow. 💡 Suggested next lane batch, by observed demand:
`glass/open` (two waiting call sites), `page/select` (tab retaps inside page
contexts), `slate/open`. Each is a normal study → phone verdict → byte-lock
cycle through `author_room_material_shading_study.py`.

### E. The hearth is visually alive and acoustically dead — an abandoned stub either way

- ◑ The fire animates continuously (`widgets/living_hearth_fire.dart`) but no
  looping/ambient audio infrastructure exists anywhere (no `ReleaseMode.loop`,
  nothing). ✅ **Correction found during repairs:** ambience is a *removed*
  feature, not a never-built one — `tool/prepare_web_offline.dart:277-279`
  says "Continuous room ambience was removed on every platform. Keep the old
  loop asset out of new offline releases so stale clients cannot fetch it."
  `hearth_room.wav` was that loop.
- ✅ `hearth.wav` is preloaded into memory every launch, has a volume entry
  (0.68) and a suppression entry, and has **zero call sites**. It's plumbing
  for a cue that nothing fires.
- ◑ DESIGN-BIBLE.md explicitly specs the missing half: *"Hearth ambience is
  optional, extremely low, looped cleanly, and never starts as a foreground
  sound."* SOUND-DESIGN.md never mentions ambience at all.

💡 This is a fork you should decide deliberately: **either** author the
optional hearth-ambience loop as a study (it's the one place the world could
breathe continuously, opt-in, off by default per doctrine) **or** delete the
`hearth` plumbing and the spec line so the system stops carrying a dead limb.
⚠️ No owner statement about ambience exists anywhere in the searchable corpus
— this is a genuine open question only you can answer. (Note: any loop would
also need lifecycle handling the router currently doesn't have — see H.)

### F. The one sound users hear most is the only one nobody designed

◑ Reminder notifications play the **stock OS notification sound** on both
platforms (`platform/notifications_native.dart:142-151` passes no `sound:`).
Neither doctrine doc even considers the dimension — "notification" appears
only as an anti-pattern adjective. For a habit app, the reminder ping is
plausibly the highest-frequency sound in the whole product, and it currently
speaks someone else's language. 💡 A short, quiet cue from the room's own
world (the accepted-contact + a low field note, exported to the platform
formats) would extend "one imagined mechanism" to the moment the app taps the
user on the shoulder — the exact inverse of every other sound, and arguably
the most "expensive-feeling" upgrade left. Worth a study; also worth an
explicit decision to *keep* stock, if that's the call — either way it should
be a decision, not a default.

### G. Dead weight shipping in every build

- ✅◑ **20 orphaned Gen-1 wavs still bundle**: `tap_{wood,stone,parchment,
  brass,glass}_1-3.wav` (15), `tick.wav`, `tick_warm.wav`, `tick_lift.wav`,
  `complete.wav`, `hearth_room.wav`. All confirmed unreachable — the `tick*`/
  `complete` *names* are live but intercepted and rerouted to Room masters
  before any file lookup; the files themselves are never read.
  (`hearth_room.wav` is even test-enforced dead.) ~0.6 MB of the 2.64 MB sfx
  bundle is corpse.
- ◑ Minor router debt: the `0.55` default-volume branch (`audio.dart:390`) is
  unreachable under current call sites; `hearth` preloads for nothing (§E).
- ✅ Two stale grep dumps sit at the worktree root (`audit_sfx_context.txt`,
  `audit_sfx_context_current.txt`), both pre-dating the texture ship and the
  entire discovery feature — misleading as inventories; delete or regenerate.

💡 One cleanup commit: delete the orphan wavs (SOURCES.md already labels them
"archived provenance only" — the provenance text stays, the bytes go),
delete or archive the stale dumps, and either wire or remove `hearth`.

### H. Lifecycle and cold-start edges (lower priority, real)

- ◑ Any tap before `init()` finishes — and every first-play of a sound whose
  pool failed — takes a slow one-shot `AudioPlayer` path (`audio.dart:612-622`):
  async decode instead of the warm pool. On web there is no eager preload at
  all, by design. Pool-load failures are swallowed silently and degrade to the
  slow path forever.
- ◑ Nothing re-asserts the audio-session category on app resume (no
  `WidgetsBindingObserver` in `audio.dart`); if the OS reclaims the session,
  the `.ambient` contract is never re-applied. ⚠️ Not confirmed as a live bug
  — depends on plugin internals; flagged as an unobserved property.
- ◑ Haptics have no independent toggle (sound off ≠ haptics off), and haptic-
  only touch points exist outside `Pressable` (e.g. `me.dart:6905`). The
  settings surface is a single boolean; whether that's enough is a taste call.

### I. Process and doctrine drift (cheap to fix, protects everything else)

- ◑ **No `LISTENING-RESULT.md` exists after 2026-08-21**, yet shipped sound
  behavior changed on 2026-08-22 (the build-29 completion-causality split,
  recorded only as an inline DESIGN-BIBLE note) — the process SOUND-DESIGN.md
  §9 declares wasn't followed for its own most recent change.
- ◑ Two 2026-08-20 studies were informally rejected in SOUND-DESIGN.md prose
  but never got verdict files; two more (`click-weight-finish-v1`,
  `weighted-click-system-v1`) are genuinely abandoned open loops.
- ✅◑ SOUND-DESIGN.md's own gaps: it never mentions `fire_ignite`/`hearth`/
  ambience/music at all; the hearth/fire 0.68 runtime attenuation is an
  undocumented exception to "masters play at 1.0"; the material take-fold
  (§C) contradicts its "no two consecutive taps are identical files" claim;
  material-lane durations are not test-pinned (ordinary and Paired Return
  are). 💡 A half-page addendum keeps the doc honest as the record of truth.
- ◑ One loudness thread worth a conscious close: the 2026-08-20 phone verdict
  said *"the volume is off it's pretty quiet even though i'm on full volume"*;
  the RMS ladder was designed afterward and the final ship verdict was *"it
  sounds wonderful!"* — INFERRED resolved, but no verdict ever re-addressed
  loudness by name. ⚠️ One phone listen against another app at equal volume
  would close it with evidence.

## 4. What this audit could not see

- ⚠️ **The ChatGPT conversation history is unreachable** — no local export
  exists (checked Downloads/Documents for `conversations.json`, chatgpt
  exports, zips). If sound discussions live there, exporting them
  (ChatGPT → Settings → Data controls → Export) would let them be folded in.
- ⚠️ The searchable local corpus contains sound talk from essentially **one
  conversation thread** (2026-08-21) plus the older Codex-era quotes already
  in SOUND-DESIGN.md/MIKA.md. Desires about music and ambience are stated
  **nowhere** — §E and §F are open questions, not inferred preferences.
- ⚠️ Nothing here was listened to on a phone this session. Every claim is
  code/bytes/history-level; the byte-locks guarantee the phone still plays
  exactly what you approved on 2026-08-21, but any *new* judgment (loudness
  vs. other apps, how the silent discovery screens actually feel) still needs
  your ear.

## 5. Suggested order of work

1. **Wiring pass** over discovery/social/daybook silent surfaces + the three
   routing fixes (§A, §B) — no new audio, restores the language everywhere.
2. **Lane-aware take fold** in the router (§C, option a) — kills the ~21%
   identical-repeat on textured surfaces.
3. **Self-enforcing coverage** — extend the invariant test to flag bare
   sound-less buttons in screens (§A) so this never regresses again.
4. **Decide the two open questions** — hearth ambience (build or delete, §E)
   and the notification voice (author or consciously keep stock, §F).
5. **Cleanup commit** — orphan wavs, stale dumps, dead router branches (§G).
6. **Doctrine addendum + verdict hygiene** (§I) — then grow lanes by demand
   (`glass/open` first, §D).
