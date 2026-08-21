# What's New rendered evidence

Fresh renders for the one-time Room of Days release screen live here. Regenerate them with:

```powershell
flutter test --update-goldens --dart-define=CAPTURE_GOLDENS=true test/whats_new_screen_test.dart
```

The evidence set covers the normal 430 x 932 phone canvas and the top and scrolled states of a 320 x 568 phone at 2x text with Reduce Motion enabled.

## Inspection result

- The 430 x 932 render keeps the complete release card and the single gold action visible without scrolling.
- The 2x-text render preserves the headline, version, release content, close control, and action without clipping or overflow; the content becomes an ordinary vertical scroll.
- The close control stays available while the release content scrolls, and the final action has a full-width touch target.
- The release screen stays inside the approved warm espresso, honey glass, brass, and parchment visual system. No new asset or visual direction was introduced.

`whats_new_phone_review.webp` is the compact three-state review sheet. These are source renders for the next candidate; they are not evidence that an existing signed build contains the feature.
