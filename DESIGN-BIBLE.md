# Room of Days — Canonical Design Bible

Status: current visual and interaction canon, 2026-08-03.

This file explains both what Room of Days should look like and why the current
look works. It is the first authority for visual implementation. When an older
audit, prompt, mock, report, or historical code comment conflicts with it, use
this order:

1. the owner’s latest direct correction;
2. this design bible;
3. the selected targets in `design/visual-targets/2026-07-30/`;
4. current production captures and working behavior;
5. older audits and implementation history.

The selected targets are material, composition, and interaction sources—not
rigid posters. Preserve their authored world, hierarchy, and physical logic
while allowing live names, records, accessibility, and real days to reflow.

`../VISUAL-AUDIT.md` remains valuable as a diagnosis of the old fragmented
app. Its blanket prescriptions to remove every blur, gradient, glow, or soft
edge are superseded. The current system uses those effects selectively when
they belong to a light source, material, depth transition, or earned event.

## The feeling

Room of Days is a private room at night where real effort becomes visible. It
should feel intimate, useful, handcrafted, slightly enchanted, and expensive
in the way a beautiful book, a brass instrument, or a restrained luxury
product film feels expensive.

It is not a fantasy skin laid over a generic dashboard. It is not a game HUD
made from brown rectangles. It is not a solemn metaphor claiming to author the
user’s future.

The emotional order is:

1. the room or desk scene creates desire, calm, and a sense of place;
2. the one important action is unmistakable;
3. progress and live information are readable at a glance;
4. materials and motion make the action satisfying;
5. small details reward attention without demanding it.

## Why the current system works

The final look was not achieved by adding more ornament. It came together when
the following decisions began reinforcing one another:

1. **The world comes first.** Each primary screen opens inside one continuous
   candlelit room or desk composition instead of placing scenery behind a
   stack of unrelated cards.
2. **Materials have jobs.** Smoked glass holds live information, parchment
   holds reflective writing, leather holds ritual and memory, aged brass
   structures the interface, and luminous honey gold belongs to the one
   primary action.
3. **Every effect has a cause.** Fire may live because it emits light. Gold
   may catch a reflection because the phone, pointer, or scroll changed the
   implied viewing angle. Blur appears because content moved over a fixed
   scene.
4. **Depth preserves the painting.** The Quest room uses separately authored,
   registered planes with real scenery behind them. Whole plates elsewhere
   remain intact and overscanned. Nothing exposes a cut edge or duplicated
   chair, window, shelf, or wall.
5. **Authored art and live UI divide the work.** Raster art carries material,
   atmosphere, perspective, and physical ornament. Flutter carries names,
   dates, counts, accessibility, hit targets, and changing state.
6. **Physical details are semantically attached.** A ribbon emerges from the
   slot it marks; a clasp sits on the cover it closes; a section rule belongs
   to the page it divides. Floating badges and decorative scraps feel cheap
   even when their texture is beautiful.
7. **Composition is judged optically.** Controls align to the visible page,
   leather cover, printed rule, and focal path—not merely to a transparent
   bitmap bound or the mathematical center of the phone.

These are the durable mechanisms. Exact offsets and individual assets may
evolve as long as these relationships remain true.

## One world, five rooms

The primary navigation is:

`ME · QUESTS · GOALS · PLANS · JOURNAL`

- **Me** — the room you are making yours.
- **Quests** — what deserves your attention today.
- **Goals** — what you are building toward.
- **Plans** — your days, held in one place.
- **Journal** — what you noticed, and what changed.

Journal contains three internal lenses:

`ENTRIES · PATTERNS · CHRONICLE`

Patterns preserves the useful evidence previously filed under Insights.

All five destinations belong to the same building, time of night, palette,
light model, type family, and object culture. They may change camera distance
and foreground object, but they must never look like separate themes.

## The visual constitution

### 1. Environment before interface

- The first frame should read as a composed image at a distance.
- The scene establishes temperature and desire before the interface explains
  itself.
- UI surfaces borrow color and light from the world behind them.
- Empty space is authored atmosphere, not an excuse for a sourceless bloom.
- On short heights, reduce the scenic reveal before shrinking touch targets,
  clipping live content, or hiding the core loop.

### 2. One luminous action

Every screen gets at most one luminous honey-gold action. Everything else uses
aged brass, ink, quiet glass, parchment, or domain pigment.

The primary action may be richly finished, but it must remain calm at rest:

- a satin value ramp rather than a solid mustard fill;
- authored grain at a scale that remains material rather than noisy;
- a lit upper lip and shaded lower plane;
- one broad reflection;
- dark engraved copy;
- restrained depth and halo.

The primary action is a jewel, not a flashlight. A second bright button means
the hierarchy is already broken.

### 3. A beautiful parked still

Motion reveals construction; it cannot rescue a weak frame. With Reduce Motion
enabled, with the pointer parked, and before the first scroll, the screen must
already look finished.

### 4. Meaning before ornament

A decorative detail earns its place only if it:

- explains state or interaction;
- belongs to a physical object;
- strengthens the focal path;
- records accumulated history;
- distinguishes a domain without becoming a color block; or
- improves the emotional payoff of an earned moment.

If it does none of these, remove it.

## Material hierarchy

| Role | Material | Behavior |
| --- | --- | --- |
| World | walnut, plaster, stone, leather, paper, moonlit glass | continuous authored scene; owns atmosphere |
| Live information | smoke-black optical glass or dark book cloth | darker than the lit art; warm top lip; quiet lower rim |
| Reflection and memory | fibrous parchment | warm, imperfect, readable, fully contained by its rule |
| Structure | aged brass | low-luminance rims, medallions, rules, hardware, and seals |
| Primary action | satin honey gold | one broad responsive reflection; engraved dark label |
| Domain identity | six restrained pigments | icon, fine rail, small note, ribbon, or embedded prop |
| Completion | warm resolved metal and parchment | closed, weighty, calm; never green plastic |

### Canvas

- Near-black walnut and espresso, never neutral black or cold charcoal.
- Plum may deepen the night, but it cannot become a separate neon UI theme.
- The room should remain warmer and more alive near a real light source.

### Optical glass

- Darker than the scene behind it so the room remains the lit object.
- Carries a warm upper catch-light, a quiet interior gradient, and a recessed
  lower edge.
- Real backdrop blur is reserved for spatial overlap: fixed hero scenes,
  headers, docks, and content crossing the backdrop.
- A generic translucent grey card with a drop shadow is not Room of Days glass.

### Gold and brass

- Gold contains several values, grain, edge heat, and an under-plane.
- Resting hardware is aged brass, not bright yellow.
- Luminous honey belongs to the current primary action or freshly earned
  progress.
- The metal follows the screen’s one implied light field.
- Multiple traveling glints, constant sparkle, and near-white plastic peaks
  are forbidden.

### Parchment

- Warm, fibrous, imperfect, and optically inset from its frame.
- Text on parchment uses an ink voice and belongs to the photographed plane.
- Parchment is not a beige app card. It needs paper depth, edge wear, and
  breathing room.
- No live text or illustration may be visibly cut by the parchment crop.

### Domain color

- BODY, CARE, MIND, CRAFT, PEOPLE, and HOME keep one shared mapping everywhere.
- Domain pigment identifies; it does not fill the whole component.
- All six hues look like pigments under the same warm light.
- CRAFT always uses crossed maker tools. It must never read as a sparkle, sun,
  or unexplained ornament.

## Light

Room of Days has motivated light, not decorative brightness.

- Hearth, candle, lamp, moon, and dawn are legitimate sources.
- Highlights, cast warmth, and reflection direction should point back to one
  of them.
- The hearth is normally the warmest object in a night room.
- The moon can own a cool edge, but it cannot turn the interface cold.
- Glass and metal share one implied light direction across a screen.
- UI chrome must not outshine the focal action or the room’s real light source.

The older app felt fragmented partly because each widget invented its own
wedge, bloom, or highlight. Never solve a local card in isolation from the
screen’s light field.

## Depth and motion

### One input, two response speeds

Phone tilt, browser orientation, and desktop pointer movement are equivalent
viewing inputs. They feed one target, then split into:

- **camera response:** slower and heavier;
- **light response:** faster and more immediate.

The light may acknowledge the hand quickly. The room should feel like it has
mass. Scroll joins the same system instead of inventing an unrelated animation.

### Plane model

| Plane | Typical travel | Purpose |
| --- | ---: | --- |
| distant architecture / window | 1–3 px | stable world and horizon |
| wall objects / middle room | 2–5 px | modest spatial separation |
| desk / furniture / foreground | 4–8 px | nearest authored depth |
| intact hero plate without isolated layers | up to 8–14 px with overscan | camera drift only; no cut seams |
| embedded category vignette | 1–3 px | quiet life inside a card |
| glass or gold reflection | phase/angle, not object travel | responsive light above the material |
| labels, controls, hit targets | normal document flow | legibility and interaction stability |

These are restrained ranges, not targets to maximize.

### Scene integrity

- Use separately authored transparent planes only when each plane was created
  for the same registered camera and the far plate contains real scenery behind
  it.
- Never cut broad polygons from a finished painting and slide them around.
- If true layers do not exist, overscan and move the intact plate subtly.
- Transparent assets require halo, despill, edge, and registration checks at
  their real display size.
- Fire belongs to its firebox plane and must not drift with furniture.

### Scroll behavior

- Content moves in normal document flow over a fixed or slower scene.
- The scene gathers progressive softening and a small warm veil only after
  scrolling begins. This may be a registered pre-softened plate; it does not
  need to be a live backdrop blur.
- Foreground text, controls, and live art remain crisp.
- Scroll advances the same broad metal reflection used by tilt.
- At rest, do not leave an unnecessary blur layer resampling the scene.

### Autonomous, reactive, and event motion

| Motion class | Allowed examples | Rule |
| --- | --- | --- |
| Autonomous | fire, candle flame, a few embers, quiet weather | belongs to a living source; low frequency and low amplitude |
| Reactive | camera parallax, glass light, gold sheen, tiny vignette drift | moves only because tilt, pointer, touch, or scroll changed |
| Event | press compression, check resolution, reward receipt, level milestone | begins with user action; settles cleanly |
| Static | borders, labels, parked ornament, ordinary cards | does not perform for attention |

The interface does not sparkle on a timer.

### Performance and accessibility

- Coalesce sensor input and publish only visible changes. Camera and reflected
  light normally top out near 30 clean updates per second; a small-travel room
  may update more slowly than the cheaper reflection.
- Build and decode each illustrated primary destination on first visit, then
  keep it alive. Hidden destinations mute their tickers. Never start all five
  rooms, fires, and image decodes on the first Quest frame.
- Preserve perceived richness with authored frames and cadence, not display-
  rate rebuilds: global motes sit near 12 fps, Quest fire near 12 fps on web and
  20 fps natively, and routine fire near 18 fps.
- A large animated room must not sit under a live full-screen BackdropFilter
  during scroll. Use a registered pre-softened plate or a warm value veil,
  while keeping live content crisp and the resting room untouched.
- Me room identities decode as finished plates and move intact. The Quest
  backdrop may use a small registered layer stack, but it is never rebuilt or
  re-masked on every fire or parallax frame.
- Repaint boundaries isolate room, fire, and live material effects.
- Do not rebuild quest data or page structure on every sensor sample.
- Honor both the in-app Reduce Motion setting and the operating-system
  reduced-motion preference.
- Reduced Motion parks every layer on an intentionally composed still.

## Authored art and live UI

Room of Days deliberately uses a hybrid production model.

Authored raster art owns:

- room and desk atmosphere;
- painterly props and category vignettes;
- leather, page stacks, stitching, fibers, tarnish, and worn gilding;
- real physical ornaments such as a clasp, tray, ribbon, or section rule;
- registered fire frames and isolated room planes.

Flutter owns:

- quest names, dates, XP, counts, domains, and changing records;
- accessibility labels and text scaling;
- hit targets, focus, persistence, and real interaction;
- responsive reflow and long-content behavior;
- motion composition and light response.

Generated room masters must never contain live HUD, level, XP, currency,
name, or navigation text—even when a concept image does. Every selectable
room identity is a completed, coherent interior from its first frame. The
product never labels a finished painting as an empty shell or asks the user to
buy necessities before their space feels cared for. If a future feature truly
adds an object, its preview must show only that authored delta without leaking
neighboring objects from a final painting.

Never bake live copy into a production raster. Never replace authored physical
material with a flat procedural approximation merely because it is easier to
position. Conversely, do not use a whole generated mock as a screenshot-shaped
UI. Decompose the concept into the smallest physical assets that benefit from
authored detail, then rebuild the information layer live.

## Geometry and optical composition

### Register to the object, not the file

Transparent bounds, asymmetric shadows, page stacks, camera keystone, and
painted perspective mean the bitmap’s rectangle is rarely the visible object.

- Center a clasp on the visible cover or parchment, not the source image.
- Align live ink to the page’s inner printed rule, not to an axis-aligned box.
- When four photographed corners differ, use four-corner registration; one
  center rotation is not enough.
- Keep an optical inset from every inner line.
- Test transformed hit targets at the same tilt extremes as the art.

### Physical crossings

Nothing crosses an inner rule by accident. The only allowed crossings are
literal attached objects:

- a ribbon tail emerging from its selected slot;
- a clasp mounted on its cover;
- another physical piece whose attachment point is visible and meaningful.

A floating badge, bookmark, or cloth scrap is not made coherent by giving it a
better texture.

### Cross-state continuity

The same product moment in two states must feel remembered:

- night and morning share the same room camera and occupied ledger frame;
- a selected 1–2–3 order persists exactly;
- state may translate between materials when the context changes;
- the morning hierarchy can express rank one as restrained letterpress instead
  of duplicating a night ribbon where it no longer belongs.

Literal object-for-object copying is less important than preserving material
logic, semantic continuity, and comfortable flow.

## Type

| Typeface | Role |
| --- | --- |
| Fraunces | page names, quest names, goal names, meaningful numerals and dates |
| EB Garamond | physical ledger writing, page hierarchy, section rules, engraved clasp copy |
| JetBrains Mono | compact all-caps mechanics, metadata, controls, and technical labels |
| Inter | explanation, supporting copy, and controls outside physical paper/leather |

Rules:

- Page names are declarative: `GOALS`, not `Take on quests!`.
- Parchment and leather should not sound like a generic app through cold sans
  typography.
- Titles wrap naturally and never collide with XP, art, check controls, or
  trailing icons.
- Text may shrink only inside truly bounded metadata.
- Long live names get space, wrapping, or disclosure—not microscopic type.
- Ivory is the high value. Pure white is almost never needed.

## Shape and iconography

- Faceted and chamfered geometry is the shared instrument-like UI language.
- Borders use a warm top catch, aged-brass body, and darker under-edge.
- A medallion is reserved for identity, domain, or section anchoring; it is not
  a generic badge shape.
- Use one coherent icon family at practical optical weights.
- Do not invent decorative stars, suns, sparkles, or hand-drawn symbols when a
  clear existing icon already carries the meaning.
- Physical art may use organic silhouettes when the material demands it; it
  does not need to be forced into the UI’s faceted container shape.

## Spacing and density

- Use a 4 px base rhythm.
- Primary page gutters are 16 px.
- Major sections receive at least 18–24 px of breathing room.
- Cards need an optical inner inset in addition to their border thickness.
- The fixed dock owns a protected bottom inset; content must never be
  guillotined behind it.
- Avoid both extremes: dense screens clipped by the dock and short screens
  ending in an accidental third-page void.
- A real record may extend below the concept’s first frame. Preserve cadence
  instead of shrinking the whole page to impersonate a poster.

## Screen contracts

### Quests

- The earned room fills the upper first frame.
- XP and six domains sit on a darker optical-glass instrument panel.
- One Main Quest may be featured.
- Its category uses a soft, low-set painted vignette integrated into the card,
  never a category-sized color fill or sharp pasted thumbnail.
- The incomplete control is an open jeweler’s orbit: fine warm metal, dark
  center, and a small check-latch crossing the lower-right break.
- Completion closes and warms the orbit. It never becomes a green token.
- `MARK COMPLETE` is the one luminous action.
- Completion receipts occupy a protected readable rail, remain long enough to
  understand, and never cover XP, title, check control, or the next action.
- On scroll, quests rise over the room while the backdrop gathers depth and
  blur. The list itself stays crisp.

### Me

- The room is the identity hero, not a decorative banner above a dashboard.
- Glimmers, Change your space, sharing, milestones, and the six-domain build
  read as one composition.
- Every person begins in a complete, gorgeous room. Beauty is hospitality, not
  a progression gate and not another checklist.
- Glimmers unlock a small number of major, fully authored room identities.
  The Writer’s Hearth, Living Conservatory, and Moonlit Archive each replace
  the whole atmosphere—furniture, materials, silhouette, and light—as one
  coherent place.
- Every room can be previewed full-size before purchase. Buying an identity is
  permanent; switching among owned rooms is always free.
- Progress may leave a restrained keepsake later, but keepsakes are optional
  evidence of a life lived there. They never complete or rescue the room.
- Room plates move as intact, overscanned cameras. No independent furniture
  layer may tear, expose neighboring objects, or drift out of perspective.
- The tapestry remains a literal room object and level record, not everyday
  Quest chrome or a narrator.
- `My Space` is a person-authored deck beneath the room hero. About, Right now,
  Pinned moments, and This season may be reordered or hidden in a full-screen
  arranger without turning the Me page into a generic dashboard.
- The cards use distinct physical roles: book-cloth introduction, recessed goal
  plate, Journal shelf, and seasonal postcard. An empty This season is
  omitted so an existing save keeps the original three-card rhythm.
- About holds a short introduction, Right now holds up to three chosen goals,
  Pinned moments holds up to four Journal pages, and This season holds a short
  reflection with an optional photo selected from the Journal.
- A visitor page is private by default and has its own master door. Every card
  has an independent visitor audience choice, separate from whether the owner
  hides that card on their own page.
- Publishing the visitor page exposes the chosen name, selected card order, and
  only bounded content from those selected cards. About may share an intro,
  Right now up to three goals, Pinned moments up to four pinned excerpts, and
  This season its short reflection.
- Journal photos stay on the keeper's device by default. A keeper may separately
  allow one profile photo and one This season photo; only those selected images
  enter the bounded visitor-media path and each can be withdrawn independently.
  Unselected photos and writing, Journal identifiers, Quest details, streak
  history, and account data never enter a room payload.
- A six-character room code and its HTTPS invite link are bearer invitations.
  Collection listing stays forbidden, and every visit explains the boundary.
- A visited room can be kept in the trusted Circle only by an explicit action.
  Validation, loading, not-found, and retry states remain inside the room-code
  dialog so the person never waits on a blank screen.
- Keeping a room leaves one private, text-free receipt for its owner. One-way
  support remains fixed-copy and text-free; Circle is not an open chat surface.

### Goals

- The desk-and-folio view narrows the world toward intention.
- Goal cards may contain softened authored vignettes, but copy and progress
  remain dominant.
- Progress rails are recessed grooves, not luminous pills.
- The new-goal action is the one luminous plate.
- Support tools remain visibly secondary to the active promises.

### Plans

- The planner is a physical working surface, not an oversized generic calendar
  card.
- The selected date is unmistakable without filling every completed day.
- Domain marks preserve history at low visual weight.
- The selected day shows actual recurring and planned quests.
- Calendar, day details, and fixed dock share one vertical rhythm.

### Journal

- Journal combines writing, memory, and patterns without becoming an analytics
  dashboard.
- `ENTRIES · PATTERNS · CHRONICLE` remains stable.
- The Then & Now beat returns a former self to the user.
- Looking-back entries open as finished pages, not live text fields. A clear
  Edit action deliberately crosses from reading into writing; structured night
  entries return to their own structured editor.
- A guided prompt and the keeper's response must remain visibly distinct even
  when they share one persisted text block. Prompt styling never changes the
  stored words or silently rewrites the keeper's answer.
- Parchment and botanical detail are restrained physical context, not filler.
- Evidence and analytics remain useful beneath the personal entry hierarchy.
- Journal earns its place beside Notes by attaching the day's completed
  quests, goal threads, XP, build movement, energy, and streak context to a
  private page automatically. The writing remains primary; context is quiet,
  inspectable evidence rather than a form the user must maintain.
- A meaningful Quest completion may offer `KEEP ONE LINE · OPTIONAL`. It opens
  a ten-second capture, never a mandatory detour, and freezes the completed
  Quest plus the day's XP, domain, goal, build, streak, and energy evidence
  beside the line. The full editor remains available when the person wants a
  page rather than a sentence.
- An authored Journal Quest opens a dedicated, autosaving Journal page instead
  of behaving like an ordinary check-off. The Quest and page remain explicitly
  linked; this is a product behavior, not a guess based on the Quest title.
- Merely opening or leaving that page empty never completes the Quest and never
  awards its reward. Meaningful saved writing completes the linked Quest once
  when the person returns to Quests.
- Reopening the same Journal Quest on the same day resumes its existing linked
  page. It must not create duplicate drafts, duplicate entries, or a second
  completion reward.
- The night ledger may offer the same one-line door as its quiet secondary
  action. `CLOSE THE DAY` remains primary; writing neither blocks nor closes
  the ritual, and an existing line changes the invitation to `keep another
  line` rather than pretending the first was forgotten.

## Daily bookends: one ledger, two kinds of light

Morning and night are two visits to the same physical desk ledger from the
same room camera.

- **Night / Close the ledger** turns effort into a calm record: earned XP,
  domain movement, finished quests, an honest all-day check-in, and up to three
  choices for tomorrow. Closing the clasp ends the day.
- The completion total reflects the whole day. The page writes the first three
  finished quests and then offers an understated `and N more!`; opening it
  reveals the full scrollable record without shrinking names into metadata or
  stretching the leather shell beyond recognition.
- **Morning / Open the day** returns those three choices on warm parchment.
  Rank one receives one quiet printed line—`1 BEGIN HERE`—above the quest. Do
  not repeat it as a floating cloth tab or oversized plaque.
- Night selection order is saved as ranks 1–3. The numeral and quest remain
  legible inside each tray slot while a cloth ribbon emerges from that slot’s
  lower seam.
- Morning inherits the exact order as page hierarchy rather than carrying the
  physical night ribbon into a second, less coherent context.
- `LOW · STEADY · BRIGHT` is a private capacity lens, not a score. Low shelters
  a compassionate three without reducing rewards or using failure language.
- Live content belongs to the photographed page plane. Text, rules, planner
  rows, capacity controls, and footnotes maintain a measured optical inset.
- The room is the slow far plane, the ledger is nearer, and brass reflection
  answers the hand fastest.
- The hearth owns the sole continuous life. Reduced Motion parks it on a
  composed still.
- Both routines share leather, brass, type, sound, motion, camera, and occupied
  frame so the day feels remembered rather than newly themed.
- A one-line night reflection floats as a private book-cloth sheet above the
  dimmed ledger. It is not another section forced inside the printed page.

## Reward, sound, and touch

- The first response to a tap lands inside 100 ms.
- Press depth, the quiet tick, and selection haptic begin on raw pointer-down;
  the action still commits only after a valid tap. A scrolling finger cancels
  the pressed visual instead of firing the control.
- Navigation is a quiet wood/brass tick.
- Completion is a soft latch, a warm ember release, then a readable earned
  receipt.
- Completed controls settle into weight; they do not become bright green.
- Hearth ambience is optional, extremely low, looped cleanly, and never starts
  as a foreground sound.
- Music, if introduced, belongs to the world and defaults off until chosen.
- Haptics and sound support the visual event; muted phones lose no information.
- Full-screen spectacle is reserved for genuinely rare milestones.
- When a completion opens evidence or reflection, pause and hide the receipt
  so modal ink stays unobstructed and touchable. Resume the receipt afterward
  long enough to show the saved confirmation.

## Responsive and accessibility contract

- Preserve the core action and readable type before preserving scenic height.
- Stretch or reflow a physical surface before shrinking live content below a
  comfortable reading size.
- Test 430 × 932, a small 320 × 568 surface, and at least 1.3× text.
- Test long names, localized dates, empty states, many completions, expanded
  records, and the dock inset.
- Semantics, keyboard/focus behavior where applicable, and transformed hit
  targets remain live even when art uses perspective.
- Color never carries domain, selection, completion, or capacity meaning alone.
- Reduced Motion must preserve a complete, intentional still—not a half-frame
  or missing state.

## Anti-patterns

Do not ship:

- broad flat brown panels;
- solid mustard “gold”;
- green plastic completion tokens;
- generic glassmorphism detached from the room;
- arbitrary blur, bloom, halo, or light wedges with no source;
- multiple primary buttons or competing near-white objects;
- continuous sparkle, shimmer, or traveling flare loops;
- broad cutouts from a finished painting used as fake parallax;
- duplicated furniture, exposed crop edges, alpha halos, or moving seams;
- sharp high-resolution thumbnails pasted into soft card art;
- floating ornaments with no attachment or mechanical meaning;
- beautiful rasters with baked live text;
- cold modern type on parchment or leather;
- mathematical centering that is visibly off-center on the painted object;
- concept fidelity that makes real content cramped, clipped, tiny, or awkward;
- one polished top-level screen followed by older flat pushed flows;
- a screenshot path offered as proof without anyone opening the image.

## Visual definition of done

A visual pass is complete only when:

1. a fresh current-state capture exists for every affected surface;
2. each implementation is placed beside its approved source at the same state,
   viewport, and crop;
3. both the full frame and focused high-risk details are opened and inspected;
4. the resting, mid-scroll, completed, long-content, empty, narrow, large-text,
   and Reduced Motion states relevant to the change are checked;
5. no crop edge, painted seam, alpha halo, overlap, tiny text, cheap solid
   fill, detached ornament, or competing bright action remains;
6. motion has a cause, behaves smoothly, and parks on a beautiful still;
7. every visible primary action and all five destinations still work;
8. analysis, tests, and the release build pass in proportion to the change;
9. the user receives directly attached current images that remain visible on
   phone after the work message ends.

Follow `VISUAL-WORKFLOW.md` for the repeatable capture, comparison, and handoff
procedure.

## Current source set

- Selected five-screen targets:
  `design/visual-targets/2026-07-30/`
- Target generation rationale:
  `design/visual-targets/2026-07-30/GENERATION-RECORD.md`
- Selected routine target:
  `design/visual-targets/2026-07-30/routine-ledger-selected.png`
- Current system comparison:
  `design/comparisons/2026-07-30/system-target-vs-build.png`
- Current focused comparison:
  `design/comparisons/2026-07-30/focused-target-vs-build.png`
- Routine full and focused comparisons:
  `design/comparisons/2026-07-30/routine-ledger-target-vs-build.png` and
  `design/comparisons/2026-07-30/routine-ledger-detail-target-vs-build.png`
- Production asset records:
  `assets/pages/GENERATED-ASSETS.md`,
  `assets/quest/GENERATED-ASSETS.md`,
  `assets/rooms/GENERATED-ASSETS.md`, and
  `assets/routine/GENERATED-ASSETS.md`
- Historical implementation findings:
  `design-qa.md`
- Current Journal and phone-performance audit:
  `design/audits/2026-08-01/journal-performance-audit.md` and
  `design/comparisons/2026-08-01/journal-and-phone-performance-pass.webp`
- Current pre-TestFlight release audit:
  `design/audits/2026-08-03/pre-testflight-release-audit.md`
