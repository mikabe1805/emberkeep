# Open Door of Light — visual QA

**Scope:** review-only evidence for the owner-selected Room of Days master. No
shipping icon path was edited.

## Inputs

| Role | Path | Dimensions | SHA-256 |
| --- | --- | ---: | --- |
| Room of Days current icon | `web/icons/Icon-1024.png` | 1024 x 1024 | `9485E7C9ED54693323ED8CA9599D1170D9BECFB7C029E444D9BF7DC12F4D50BE` |
| Selected Open Door of Light | `C:\Users\mikus\.codex\generated_images\01a05a90-635c-79d1-a0be-a7961be2d8ba\exec-2b725571-6087-408d-aad8-4942a17f7209.png` | 1254 x 1254 | `2ABAC214582901D4456642D5D49CCA8E68DEA943C5B7E69C34F9AD13E1ED4524` |
| Room Notes current icon | `C:\Users\mikus\Downloads\experimentProject\room_notes\.worktrees\account-deletion-release\assets\branding\app_icon_master.png` | 1024 x 1024 | `C8F20DFC58EB8F095383EE6936C054F7BFB1A04F0807117EDB9E673CDBB7409F` |

## Evidence

- `contact-sheet-32-60-180-1024.png` — direct comparison at each requested size.
- `contact-sheet-platform-masks.png` — square, iOS rounded-square, Android circle, Android safe-area guide, and themed/grayscale treatments.

Both sheets were generated with the guarded `tool/build_icon_review.dart` tool,
whose output-dir validation excludes shipping icon paths, then opened and
visually inspected.

## Observed result

**Verdict: production-ready visually as-is; no targeted image edit recommended.**

- At 1024 and 180 px, the heavy walnut threshold, warm contained light, and
  dark surround are materially coherent with Room of Days' espresso, brass,
  and honey-light world. The light reads as an invitation rather than a flash.
- At 60 and 32 px, the icon compresses to a clear, singular doorway and warm
  opening. The room/threshold silhouette survives; there is no micro-detail
  turning into noise or visual ambiguity.
- Both iOS and Android circular treatments leave the full threshold and its
  focal light intact. The Android guide is close to the outer shoulders but
  does not cut the recognisable door or the opening, so its generous scale is
  earned rather than unsafe.
- The grayscale/themed treatment still reads as an open doorway due to the
  light/dark structural split; it does not depend only on gold color.
- Against the current Room of Days ledger, this sacrifices direct quest-row
  recognition for a more immediate, memorable threshold mark. That tradeoff is
  appropriate for the explicit owner selection and does not drift toward the
  Room Notes paper-and-ink identity: Room Notes remains a flat document/pen
  mark, while this remains spatial, deep, and light-led.

The remaining acceptance gate is owner/device feel in a real launcher beside
other installed apps. That is not a reason to redraw the master before a
propagation pass; it is the next verification layer after shipping derivatives
exist.
