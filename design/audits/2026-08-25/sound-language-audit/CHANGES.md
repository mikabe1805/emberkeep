# Changes applied from the 2026-08-25 sound language audit

All runtime sounds used are existing phone-approved masters — **no new audio
was synthesized and nothing in `assets/sfx/room/` changed**. The byte-locks
still pin every master to its approved audition source. The remaining gate is
the owner's phone listen of the newly *wired* surfaces in context (which
approved sound plays where), not of any new sound.

## 1. Coverage wiring (17 surfaces, existing masters)

| Surface | File | Voice |
| --- | --- | --- |
| I HAVE A CODE | `lib/screens/discover_spaces.dart` `_enterCode` | glass (opens code dialog) |
| MANAGE HIDDEN SPACES | same, `_manageHidden` | glass |
| UNHIDE (hidden-spaces dialog) | same | glass |
| DONE (hidden-spaces dialog) | same | glass |
| COMMUNITY RULES & SAFETY | same, `_openCommunityRules` | plain clasp, open (leaves the app) |
| TRY AGAIN / LOOK AGAIN | same, `_DirectoryMessage` | plain clasp, open |
| Discover space card | same, `_DiscoverableSpaceCard` | parchment + open (page travel; was silent wood default) |
| PREVIEW PUBLIC VIEW | `lib/social.dart` | glass (matches COPY LINK/CODE siblings) |
| STOP SHARING (opens confirm) | same, `_stopSharing` | glass |
| STOP SHARING (confirm commit) | same | glass + place (the confirmed seat) |
| DONE (share sheet) | same | glass |
| Space arranger (EDIT SPACE / Choose cards) | `lib/screens/me.dart` `_personalizeSpace` | parchment (matches every other full-screen push in the file) |
| Change-name dialog open | same, `_changePlayerName` | glass |
| Save name (button + keyboard submit) | same | glass + place |
| Space-card hide/show toggle | same | glass |
| Note-picker checkbox | same | plain clasp, select |
| Share my space / Discover spaces / Visit a space links | same, `_SpaceLink` call sites | glass (sheet/dialog) / parchment (screen travel) |
| Daybook Close ×4 | `daybook_event_actions/add_choice_dialog/task_editor/event_editor.dart` | glass (dismissal convention) |
| USE MANUAL LOCATION INSTEAD | `daybook_place_fields.dart` | plain clasp, select |

Declines (Cancel, KEEP SHARING) stay silent per doctrine §10.6.

## 2. Routing fixes

- `discover-manage-own-listing` and `space-page-manage-discovery` declared
  `glass/open` — an unshipped lane that silently fell back to wood. Re-voiced
  as `glass/select` (shipped) with a comment; revisit if a `glass/open` lane
  is ever authored.
- Keepsake removal (`memory_cabinet.dart`) played brass on a non-gold muted
  control; now glass. Brass is gold-exclusive again app-wide.

## 3. Router: lane-aware take fold (`lib/audio.dart`)

`_shadedAsset` now tracks the last take per material lane and bumps on
collision, closing the ~21% identical-master repeat caused by folding five
walk variants onto three takes. Added a test-only `debugOnPlayAsset` probe at
the playback boundary to observe resolved paths.

## 4. Tests added (`test/interaction_sound_quality_test.dart`)

- `material lanes never replay the identical take back to back` — 42 paced
  shaded taps, no consecutive duplicates, all three takes participate.
- `every declared Pressable material/verb pair is a shipped lane` — repo-wide
  structural scan; unshipped declarations now fail CI.
- `social, discovery, and daybook surfaces wire their verbs` — source
  invariants for every wiring in §1, in the style of the existing
  architecture-invariant test; also pins brass out of `memory_cabinet.dart`.

## 5. Cleanup

- Deleted 20 dead Gen-1 wavs (`tap_*` ×15, `tick*` ×3, `complete.wav`,
  `hearth_room.wav`) — ~0.6 MB out of every build; runtime never read them.
  `sprite_assets_test.dart` list updated; provenance retained in
  `assets/sfx/SOURCES.md` (banner updated) and the study archives.
  `hearth.wav` deliberately kept pending the ambience decision.
- Deleted the stale `audit_sfx_context*.txt` grep dumps at the worktree root.

## 6. Docs

- `SOUND-DESIGN.md` §11 addendum: the audit, the repairs, and the previously
  unrecorded facts (fire_ignite/hearth 0.68 exception; ambience is a removed
  feature, not an unbuilt one).

## Open owner decisions

1. **Hearth ambience** — DESIGN-BIBLE.md still specs an optional loop;
   `hearth.wav` and its plumbing wait. Build it as a study, or delete the
   spec and the stub.
2. **`glass/open` lane** — two surfaces naturally want it; authoring it would
   let them return to their declared verb.

## Notification voice — selected and wired (2026-08-25)

The `room-notification-voice-v1` audition ran the same day; owner verdict:
"i think two knocks rising" → `knock-paced` selected. Wired byte-identical on
both platforms (`ios/Runner/knock_paced.wav` in the Xcode Resources phase +
`DarwinNotificationDetails(sound:)`; Android raw resource on the new
`emberkeep_reminders_v2` channel, old channel deleted at init since channels
bake their sound at creation), byte-locked by test. **Remaining gate:** a
real lock-screen delivery on the next TestFlight build; if either platform
balks at the 48 kHz/24-bit master, the fallback is a 16-bit conversion round
re-auditioned before shipping.
