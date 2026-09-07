# Room of Days — sound and finish

September 6, 2026. This record continues the approved Build 41 authored experience. `direction.md` contains the owner's exact music corrections; `finishing-source.json` binds the working source separately from the immutable Build 41 release.

## Result

The shared gold surface has a quieter champagne-honey face, a thinner rim, a subtle directional grain, and darker action text. Its existing press response stays intact. Goals and Quests retain the approved room, palette, Today’s three, recommended quests, and explicit goal review.

Three Goals metadata labels now use the 11sp minimum. Today’s three stacks its title and Change/Choose action on narrow screens or enlarged text rather than squeezing the title into word fragments. Full text scaling remains enabled.

Sound now acknowledges accepted changes: permission-declined reminder switches stay silent, a pending switch rejects reentry, and reselecting the current session-length filter or goal rung is silent. Completion still owns its full contact-to-outcome sequence; Focus and ordinary room music retain their separate settings and lifecycle behavior.

## Music decision

The first three studies and the external `The lamp is on` generation are set aside. None was added to the app's music assets. `Lamp left on` is a separate, original, written-score audition using the exact umbrella-brush instruments, bass, dark brush rhythm, and close room bus. Its 96-second form is A–A′–B–A. The first phrase starts within the first second; an 18-second excerpt is available.

The A/B page is `/umbrella-review-20260906/`: original umbrella-brush beside the new piece, plus identical app-interaction mixes at their natural levels. The old review URL leads to this comparison. `umbrella-new-theme/manifest.json` records the score, reproducible source, hashes, and technical checks. `browser-audition.json` records actual browser playback and its limits.

**Owner approved the new piece for the app:** “it sounds pretty good! you can add it to the app”. The exact auditioned `lamp-left-on.m4a` is now bundled, without reencoding or a gain change. The two compositions alternate; the original eight umbrella performances cycle within their composition. Existing 2.5-second crossfades connect them, and Focus retains its distinct meditation master. The root model cannot perceive audio in this session; the listening verdict is the owner's, while automated checks establish playback and integration behavior.

The integration check also found that the web music switch saved ON but waited for a subsequent tap to begin playback. Its explicit settings callback now retries playback after the controller accepts ON. Startup still respects browser gesture requirements; OFF retains its normal fade.

### Approved integration receipt

The historical approval hold is superseded for this specific piece by the owner's exact approval: “it sounds pretty good! you can add it to the app”. The approved AAC was copied unchanged from `umbrella-new-theme/lamp-left-on.m4a` to `assets/music/lamp-left-on.m4a`; both source and bundled asset resolve to SHA-256 `a1b84c0b850e03131e5a22269cac7aa2532ad6a0fce5a31dea21e17d40078cc3`.

Normal-room runtime has nine takes in two composition groups: umbrella takes 1–8 and `Lamp left on` as take 9. It alternates those compositions, while every umbrella take is sampled before an umbrella take repeats. Focus is unchanged and remains on its separate meditation master. A live local-browser observation captured an automatic umbrella take 07 → `Lamp left on` transition, with the new piece still advancing at 38.96 seconds.

The focused music run passed all 41 Flutter tests (`approved-music-tests.log`), analysis reported no issues (`approved-music-analysis.log`), and the release web build completed in 128.6 seconds (`approved-music-web-build.log`). The static worker source was copied into `build/web`; offline preparation and its freshness check passed with 296 files, 27.1 MiB core, and 25.9 MiB deferred (`approved-music-offline.log`). All six Node service-worker tests passed (`approved-music-worker-tests.log`).

The isolated local-browser check recorded one-tap starts for `take_05.m4a` and `lamp-left-on.m4a`, each advancing to 0.501333 seconds with a 96-second duration and no error. Turning music off restored the expected state, and the save remained intact except for `state.lastModified` (`approved-music-browser.log`). A cold native page-navigation cue also resolved at 0.112 seconds with `errors: []` (`approved-music-cold-load.log`).

Technical seam QC decoded all 16 directed 2.5-second linear crossfades between `Lamp left on` and takes 01–08. The 2.52-second transition windows peaked at 0.055773381, with no clipping. The largest boundary step was below the largest nearby ordinary waveform step at both ends of the crossfade (0.722141 start ratio; 0.728055 end ratio), so no introduced PCM discontinuity signature was found. This is signal-level evidence, not an automated claim about how the music sounds.

No signed release, TestFlight upload, or App Store submission occurred. These are isolated local-browser checks; signed-device and store-release behavior remain separate gates. `approved-music-integration.json` is the detailed receipt.

## Verification record

- The first broad run found 40 failures. Most referenced removed threshold controls, older uppercase labels, or a quest-title tap that now selects instead of completing. The repaired tests follow visible current actions and preserve actual state checks, including exact Quest identity, explicit plan acceptance, cancellation without mutation, completed history, and reversible rewards.
- The mastery screenshot fixture lacked the current EB Garamond font. After adding it, the rendered cards were inspected before updating those three expected images. The one calendar image change is confined to the intentional gold button finish.
- Live preview checks preserved the synthetic save apart from its expected `state.lastModified` update. The current gold finish was inspected on Goals and the chooser. This was an isolated browser profile, not an owner data migration or a physical-device test.
- Final full Flutter suite: **1,181 passed, zero failed**, in `full-regression-verified.log`. Final analysis reports no issues in `analyze-final.log`; the nine rendered journey checks pass in `working-render-final.log`. The six preview/offline-worker checks also pass. Failed or superseded logs remain historical evidence.
- Root and an independent agent inspected both final 320×568/2× headers and normal 430×932 renders. The enlarged headings retain whole words and full text scaling; the normal composition remains intact. The new `working_quests_field_320x568.png` capture scrolls to the actual changed header instead of hiding it below the initial viewport.
- The pre-integration release-mode web build passed (`web-final.log`). Its offline preparation and freshness check passed with **295 files, 27.1 MiB core and 24.8 MiB deferred**. Flutter retained local audition files across rebuilds; `prepare_web_offline.dart` explicitly excludes the local listening/refresh paths. That manifest contained no audition files. A web deployment must stage app files separately from this local review output. The later owner-approved music addition and fresh checks are recorded in `approved-music-integration.json`.
- The final offline exclusion change was checked with its actual retained preview files present, then with `--check`, targeted analysis, and 43 sound/music/privacy checks (`offline-exclusion-verification.log`); all pass. The final refreshed browser capture is `output/playwright/22-final-preview-goals.png`; the synthetic save again matches its pre-refresh value except `state.lastModified`.

## Release boundary

Lamp left on is selected for production with the owner's explicit approval. No new signed iOS archive, TestFlight upload, or public App Store submission has been performed in this pass. A release must bind a fresh, verified build number and the final reviewed source. The signed-device experience remains separate from owner listening, code, browser, and rendered-image checks.
