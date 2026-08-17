# Room of Days Visual Integrity Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the shared warm-background seams and replace the awkward full-height Today outline with a compact, accessible marker while preserving the candlelit visual system.

**Architecture:** Treat both defects at their shared rendering owners: `WarmBackground` for the canvas seams and the month-cell renderer for Today. Prove the seam source with a fixed A/B capture before removing only `_AmbientPlanesPainter`; retain the soft glow, authored page art, fireflies, and vignette. Keep month rows fixed at 62 px and expose full state through semantics while bounded grid metadata remains non-scaling.

**Tech Stack:** Flutter/Dart, `flutter_test`, render-boundary/golden visual tests, existing screenshot harness.

## Global Constraints

- Preserve `_Glow`, `_Fireflies`, the base vertical gradient, authored page art, and the vignette in `WarmBackground`.
- Remove `_AmbientPlanesPainter` only after a fixed A/B render demonstrates that disabling that painter removes the reported diagonal and center seams.
- Today uses one compact 28–30 px faceted brass marker around the numeral; `TODAY` remains in a separate reserved line.
- Selection is a quiet book-cloth wash. Today plus selection combines one wash and one marker, never two outlines.
- Week rows remain exactly 62 px and all seven columns remain equal.
- Month numerals and `TODAY` remain `TextScaler.noScaling`; the full date and state remain available in `Semantics` and selected-day detail scales normally.
- Do not edit or commit the user's existing dirty design/audit files.
- Every production change follows red-green-refactor and receives focused visual evidence.

---

### Task 1: Prove and remove the ambient polygon seams

**Files:**
- Create: `test/warm_background_visual_test.dart`
- Create: `test/goldens/warm_background_no_planes_430x932.png`
- Modify: `lib/widgets/glass.dart:116-152,235-328`
- Verify: `test/screenshots_test.dart:963-1030,1330-1365`

**Interfaces:**
- Consumes: `WarmBackground({required Widget child, String? themeId, Color? tint, bool reduceMotion = false})`.
- Produces: the same public `WarmBackground` API and layer order, without `_AmbientPlanesPainter`.

- [ ] **Step 1: Capture the current shared background and the painter-disabled A/B frame**

Use the fixed fixture below in `test/warm_background_visual_test.dart`; temporarily comment out only the `_AmbientPlanesPainter` `Positioned.fill` while generating the candidate golden, then restore `glass.dart` before the red run:

```dart
testWidgets('warm background has no hard ambient planes', (tester) async {
  tester.view.devicePixelRatio = 1;
  await tester.binding.setSurfaceSize(const Size(430, 932));
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.binding.setSurfaceSize(null);
  });
  await tester.pumpWidget(const MaterialApp(
    home: RepaintBoundary(
      child: WarmBackground(
        themeId: 'walnut',
        tint: Palette.streak,
        reduceMotion: true,
        child: SizedBox.expand(),
      ),
    ),
  ));
  await tester.pump();
  await expectLater(
    find.byType(WarmBackground),
    matchesGoldenFile('goldens/warm_background_no_planes_430x932.png'),
  );
});
```

Open both full-frame images and a 200% crop through the reported center and diagonal lines. Confirm the painter-disabled candidate removes those lines while the glow pools and vignette remain visible.

- [ ] **Step 2: Run the restored old implementation against the candidate golden**

Run: `flutter test test/warm_background_visual_test.dart`

Expected: FAIL with a golden pixel difference caused by the ambient planes.

- [ ] **Step 3: Remove only the polygon layer**

Delete the `Positioned.fill` that constructs `_AmbientPlanesPainter` and delete the now-unused `_AmbientPlanesPainter` class. Do not change the remaining `Stack` children or their order:

```dart
child: Stack(
  children: [
    Positioned(
      top: -70,
      left: -60,
      child: _Glow(color: _glow(theme.glows[0]), size: 320, phase: 0),
    ),
    Positioned(
      top: 200,
      right: -90,
      child: _Glow(color: _glow(theme.glows[1]), size: 280, phase: 0.35),
    ),
    Positioned(
      bottom: 40,
      left: -50,
      child: _Glow(color: _glow(theme.glows[2]), size: 260, phase: 0.6),
    ),
    Positioned(
      bottom: 240,
      right: 30,
      child: _Glow(color: _glow(theme.glows[3]), size: 180, phase: 0.85),
    ),
    Positioned.fill(child: _Fireflies(still: still || kIsWeb)),
    const Positioned.fill(
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.15,
              colors: [Color(0x00140C06), Color(0x3A140C06)],
              stops: [0.55, 1],
            ),
          ),
        ),
      ),
    ),
    child,
  ],
)
```

- [ ] **Step 4: Run the focused visual test**

Run: `flutter test test/warm_background_visual_test.dart`

Expected: PASS with zero golden difference.

- [ ] **Step 5: Capture Goals and Help for Today through the existing story**

Run: `flutter test test/screenshots_test.dart --dart-define=CAPTURE_STORE=true`

Inspect `04_goals_1290x2796` and `04b_momentum_kits_1290x2796` at full frame and 200% focused detail. Expected: no long hard diagonal/vertical lines; authored imagery, glow pools, vignette, and card translucency remain.

- [ ] **Step 6: Commit**

```powershell
git add lib/widgets/glass.dart test/warm_background_visual_test.dart test/goldens/warm_background_no_planes_430x932.png
git commit -m "fix: remove ambient background seams"
```

### Task 2: Replace the Today outline with a compact marker

**Files:**
- Modify: `lib/screens/calendar.dart:782-982`
- Modify: `test/academic_calendar_widget_test.dart`
- Modify: `test/academic_calendar_visual_test.dart`
- Create: `test/goldens/daybook_today_marker_430x932.png`

**Interfaces:**
- Consumes: `_MonthFolio(dayCell:)`, fixed 62 px week rows, `_MonthDayLoad`, existing date-cell semantics.
- Produces: keyed marker `ValueKey('month-today-marker-YYYY-MM-DD')`, keyed selected wash `ValueKey('month-selected-wash-YYYY-MM-DD')`, and keyed bounded label `ValueKey('month-today-label-YYYY-MM-DD')`.

- [ ] **Step 1: Write failing geometry and semantics tests**

Add a widget test with `Clock.freeze(DateTime.utc(2026, 8, 17, 12))`, month mode selected on 2026-08-17, a 320×568 surface, and 200% text. Assert literal behavior:

```dart
final marker = find.byKey(const ValueKey('month-today-marker-2026-08-17'));
expect(marker, findsOneWidget);
expect(tester.getSize(marker), const Size(30, 30));
expect(find.byKey(const ValueKey('month-today-label-2026-08-17')), findsOneWidget);
expect(find.byKey(const ValueKey('month-selected-wash-2026-08-17')), findsOneWidget);
expect(tester.takeException(), isNull);
expect(
  tester.getSemantics(find.text('17').first).label,
  contains('August 17, 2026, today'),
);
```

Also parameterize dates whose Today falls on each weekday and months with five and six displayed week rows; each pump must have no overflow exception.

- [ ] **Step 2: Run the focused old-code test**

Run: `flutter test test/academic_calendar_widget_test.dart --plain-name "today marker stays compact"`

Expected: FAIL because the new keyed 30×30 marker does not exist.

- [ ] **Step 3: Implement three bounded visual slots**

Refactor `_dayPlate` so the 43 px plate owns a selection wash plus a 30 px numeral slot and a separate 13 px weight/deadline slot. The Today border decorates only the 30×30 numeral container:

```dart
final keyDate = CivilDate.fromDateTime(date).toString();
return Container(
  key: isSelected ? ValueKey('month-selected-wash-$keyDate') : null,
  height: 43,
  margin: const EdgeInsets.all(1.5),
  decoration: isSelected
      ? facetedDecoration(
          cut: 7,
          gradient: LinearGradient(colors: [
            Palette.xpLight.withValues(alpha: 0.18),
            Palette.xp.withValues(alpha: 0.055),
          ]),
          borderColor: Palette.xpLight.withValues(alpha: 0.34),
        )
      : null,
  child: Column(children: [
    SizedBox(
      height: 30,
      child: Center(
        child: Container(
          key: isToday ? ValueKey('month-today-marker-$keyDate') : null,
          width: 30,
          height: 30,
          decoration: isToday
              ? facetedDecoration(
                  cut: 6,
                  gradient: const LinearGradient(
                    colors: [Color(0x36FFE4A1), Color(0x0FE7B66C)],
                  ),
                  borderColor: Palette.xp.withValues(alpha: 0.85),
                )
              : null,
          alignment: Alignment.center,
          child: Text(
            '$day',
            textScaler: TextScaler.noScaling,
            style: Type.numerals.copyWith(
              fontSize: 13,
              color: isToday
                  ? Palette.xp
                  : isSelected
                  ? Palette.textHi
                  : Palette.textMid,
            ),
          ),
        ),
      ),
    ),
    SizedBox(
      height: 13,
      child: load.weight == _MonthDayWeight.none
          ? null
          : Center(
              child: _MonthDayWeightMark(
                key: ValueKey('academic-month-weight-$keyDate'),
                weight: load.weight,
                hasDeadline: load.hasDeadline,
                deadlineKey: ValueKey('academic-month-deadline-$keyDate'),
              ),
            ),
    ),
  ]),
);
```

Keep the existing label outside `_dayPlate` in a fixed 12 px line, add the specified label key, and retain `TextScaler.noScaling`. Do not move the weight/deadline mark inside the Today marker.

- [ ] **Step 4: Run focused widget tests**

Run: `flutter test test/academic_calendar_widget_test.dart --plain-name "today marker stays compact"`

Expected: PASS for every weekday, five/six-row month, 320×568, and 200% text case.

- [ ] **Step 5: Add the visual regression**

Add a fixed month capture named `daybook today marker visual`; generate `test/goldens/daybook_today_marker_430x932.png`, restore the old `_dayPlate` once to verify the golden fails against its full-height outline, then restore the compact implementation and verify it passes.

Run: `flutter test test/academic_calendar_visual_test.dart --dart-define=CAPTURE_TODAY_MARKER=true`

Expected: PASS only with the compact marker implementation.

- [ ] **Step 6: Commit**

```powershell
git add lib/screens/calendar.dart test/academic_calendar_widget_test.dart test/academic_calendar_visual_test.dart test/goldens/daybook_today_marker_430x932.png
git commit -m "fix: keep the Today marker inside its calendar cell"
```

### Task 3: Visual-regression and static-analysis gate

**Files:**
- Verify: `lib/widgets/glass.dart`
- Verify: `lib/screens/calendar.dart`
- Verify: `test/warm_background_visual_test.dart`
- Verify: `test/academic_calendar_widget_test.dart`
- Verify: `test/academic_calendar_visual_test.dart`

**Interfaces:**
- Consumes: Tasks 1–2 final commits.
- Produces: verified visual slice ready for the neutral Daybook work.

- [ ] **Step 1: Run focused tests together**

Run: `flutter test test/warm_background_visual_test.dart test/academic_calendar_widget_test.dart test/academic_calendar_visual_test.dart`

Expected: all tests pass with no overflow or golden mismatch.

- [ ] **Step 2: Run static analysis on changed sources**

Run: `flutter analyze lib/widgets/glass.dart lib/screens/calendar.dart test/warm_background_visual_test.dart test/academic_calendar_widget_test.dart test/academic_calendar_visual_test.dart`

Expected: `No issues found!`

- [ ] **Step 3: Record fresh comparison evidence**

Open the old/new full-frame and focused-detail captures for Goals, Help for Today, and Plans. Record the comparison paths and the exact commands in the task report. Confirm Reduced Motion uses the same resting composition.

- [ ] **Step 4: Commit only if verification required a correction**

```powershell
git add lib/widgets/glass.dart lib/screens/calendar.dart test/warm_background_visual_test.dart test/academic_calendar_widget_test.dart test/academic_calendar_visual_test.dart test/goldens
git commit -m "test: lock visual integrity regressions"
```
