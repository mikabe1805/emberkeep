"""Normalized source/build comparison sheets for the Room of Days design passes.

Every approved target is a 852x1846-class mobile raster; every production
capture is 1290x2796 (430x932 logical at DPR 3). Both share the same 0.462
aspect, so a comparison only needs a common height -- never a crop.

    python tool/visual_compare.py system     # five-screen contact sheet
    python tool/visual_compare.py focus      # focused control crops
    python tool/visual_compare.py review     # current product-state contact sheet
    python tool/visual_compare.py review-phone # compact handoff sheet
    python tool/visual_compare.py brand-review # old/new icon + store graphic
    python tool/visual_compare.py audit-phone # compact first-run/Me/Journal handoff
    python tool/visual_compare.py rooms       # approved Me target vs current build
    python tool/visual_compare.py rooms-phone # compact complete-room flow handoff
    python tool/visual_compare.py social-phone # Me, Circle, and visitor-profile handoff
    python tool/visual_compare.py my-space-cards-phone # card deck + arranger handoff
    python tool/visual_compare.py sharing-journal-phone # sharing/privacy/journal handoff
    python tool/visual_compare.py probe A B  # approved-target/current-build pair
    python tool/visual_compare.py evidence-pair TITLE LABEL_A A LABEL_B B

Output lands in design/comparisons/<stamp>/.
"""

from __future__ import annotations

import sys
from datetime import date
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

APP = Path(__file__).resolve().parents[1]
TARGET_STAMP = "2026-07-30"
OUTPUT_STAMP = date.today().isoformat()
TARGETS = APP / "design" / "visual-targets" / TARGET_STAMP
GOLDENS = APP / "test" / "goldens"
OUT = APP / "design" / "comparisons" / OUTPUT_STAMP

BG = (12, 10, 9)
INK = (218, 200, 172)


def _font(size: int) -> ImageFont.FreeTypeFont:
    for name in ("consola.ttf", "arial.ttf", "DejaVuSansMono.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default()


def _fit(path: Path, height: int) -> Image.Image:
    img = Image.open(path).convert("RGB")
    width = round(img.width * height / img.height)
    return img.resize((width, height), Image.LANCZOS)


def _column(title: str, path: Path, height: int, label_h: int) -> Image.Image:
    body = _fit(path, height)
    tile = Image.new("RGB", (body.width, height + label_h), BG)
    tile.paste(body, (0, label_h))
    draw = ImageDraw.Draw(tile)
    draw.text((2, 6), title, font=_font(15), fill=INK)
    return tile


def contact_sheet(pairs: list[tuple[str, Path, Path]], name: str, height: int = 1000) -> Path:
    label_h = 28
    gap = 22
    tiles: list[Image.Image] = []
    for title, target, build in pairs:
        tiles.append(_column(f"{title} - APPROVED TARGET", target, height, label_h))
        tiles.append(_column(f"{title} - CURRENT BUILD", build, height, label_h))

    per_row = 6
    rows = [tiles[i : i + per_row] for i in range(0, len(tiles), per_row)]
    row_w = [sum(t.width for t in r) + gap * (len(r) - 1) for r in rows]
    sheet_w = max(row_w) + gap * 2
    row_h = height + label_h
    sheet_h = len(rows) * row_h + gap * (len(rows) + 1) + 44

    sheet = Image.new("RGB", (sheet_w, sheet_h), BG)
    ImageDraw.Draw(sheet).text(
        (gap, 16), f"ROOM OF DAYS - APPROVED SYSTEM / {name.upper()}", font=_font(22), fill=INK
    )
    y = 44 + gap
    for row in rows:
        x = gap
        for tile in row:
            sheet.paste(tile, (x, y))
            x += tile.width + gap
        y += row_h + gap

    OUT.mkdir(parents=True, exist_ok=True)
    dest = OUT / f"{name}.png"
    sheet.save(dest)
    print(dest)
    return dest


def image_sheet(
    items: list[tuple[str, Path]],
    name: str,
    *,
    height: int = 720,
    per_row: int = 4,
    webp: bool = False,
) -> Path:
    """Build one labeled sheet from current production captures only."""
    label_h = 30
    gap = 18
    heading_h = 48
    tiles = [_column(title, path, height, label_h) for title, path in items]
    rows = [tiles[i : i + per_row] for i in range(0, len(tiles), per_row)]
    row_w = [sum(tile.width for tile in row) + gap * (len(row) - 1) for row in rows]
    sheet_w = max(row_w) + gap * 2
    row_h = height + label_h
    sheet_h = heading_h + sum(row_h for _ in rows) + gap * (len(rows) + 1)

    sheet = Image.new("RGB", (sheet_w, sheet_h), BG)
    ImageDraw.Draw(sheet).text(
        (gap, 15),
        "ROOM OF DAYS - CURRENT PRODUCTION REVIEW",
        font=_font(22),
        fill=INK,
    )
    y = heading_h + gap
    for row in rows:
        x = gap
        for tile in row:
            sheet.paste(tile, (x, y))
            x += tile.width + gap
        y += row_h + gap

    OUT.mkdir(parents=True, exist_ok=True)
    extension = "webp" if webp else "png"
    dest = OUT / f"{name}.{extension}"
    if webp:
        sheet.save(dest, "WEBP", quality=84, method=6)
    else:
        sheet.save(dest)
    print(dest)
    return dest


def crop_pair(
    title: str,
    target: Path,
    build: Path,
    box: tuple[float, float, float, float],
    height: int = 760,
    tags: tuple[str, str] = ("APPROVED TARGET", "CURRENT BUILD"),
) -> Image.Image:
    """`box` is a fractional (l, t, r, b) window shared by both rasters."""
    label_h = 26
    tiles = []
    for tag, path in zip(tags, (target, build)):
        img = Image.open(path).convert("RGB")
        l, t, r, b = box
        window = img.crop(
            (round(l * img.width), round(t * img.height), round(r * img.width), round(b * img.height))
        )
        scale = height / window.height
        window = window.resize((round(window.width * scale), height), Image.LANCZOS)
        tile = Image.new("RGB", (window.width, height + label_h), BG)
        tile.paste(window, (0, label_h))
        ImageDraw.Draw(tile).text((2, 5), f"{title} - {tag}", font=_font(14), fill=INK)
        tiles.append(tile)

    gap = 18
    out = Image.new(
        "RGB", (sum(t.width for t in tiles) + gap, max(t.height for t in tiles)), BG
    )
    x = 0
    for tile in tiles:
        out.paste(tile, (x, 0))
        x += tile.width + gap
    return out


def stack(images: list[Image.Image], name: str) -> Path:
    gap = 20
    width = max(i.width for i in images) + gap * 2
    height = sum(i.height for i in images) + gap * (len(images) + 1)
    sheet = Image.new("RGB", (width, height), BG)
    y = gap
    for img in images:
        sheet.paste(img, (gap, y))
        y += img.height + gap
    OUT.mkdir(parents=True, exist_ok=True)
    dest = OUT / f"{name}.png"
    sheet.save(dest)
    print(dest)
    return dest


def routine_sheet() -> Path:
    """Pair the selected two-panel routine art board with both phone renders."""
    source = Image.open(TARGETS / "routine-ledger-selected.png").convert("RGB")
    split = source.width // 2
    targets = [
        source.crop((0, 0, split, source.height)),
        source.crop((split, 0, source.width, source.height)),
    ]
    builds = [
        Image.open(GOLDENS / "routine_ledger_night_430x932.png").convert("RGB"),
        Image.open(GOLDENS / "routine_ledger_morning_430x932.png").convert("RGB"),
    ]
    moments = ["NIGHT CLOSE", "MORNING OPEN"]
    body_h = 820
    label_h = 30
    gap = 22
    rows: list[Image.Image] = []

    for moment, target, build in zip(moments, targets, builds):
        tiles: list[Image.Image] = []
        for tag, image in (("APPROVED ART BOARD", target), ("PHONE BUILD", build)):
            width = round(image.width * body_h / image.height)
            body = image.resize((width, body_h), Image.LANCZOS)
            tile = Image.new("RGB", (width, body_h + label_h), BG)
            tile.paste(body, (0, label_h))
            ImageDraw.Draw(tile).text(
                (3, 6), f"{moment} - {tag}", font=_font(15), fill=INK
            )
            tiles.append(tile)
        row = Image.new(
            "RGB",
            (sum(tile.width for tile in tiles) + gap, body_h + label_h),
            BG,
        )
        x = 0
        for tile in tiles:
            row.paste(tile, (x, 0))
            x += tile.width + gap
        rows.append(row)

    return stack(rows, "routine-ledger-target-vs-build")


def _detail_tile(
    title: str,
    tag: str,
    image: Image.Image,
    box: tuple[float, float, float, float],
    height: int = 420,
) -> Image.Image:
    left, top, right, bottom = box
    crop = image.crop(
        (
            round(left * image.width),
            round(top * image.height),
            round(right * image.width),
            round(bottom * image.height),
        )
    )
    width = round(crop.width * height / crop.height)
    body = crop.resize((width, height), Image.LANCZOS)
    tile = Image.new("RGB", (width, height + 28), BG)
    tile.paste(body, (0, 28))
    ImageDraw.Draw(tile).text(
        (3, 5), f"{title} - {tag}", font=_font(14), fill=INK
    )
    return tile


def routine_detail_sheet() -> Path:
    """Focused checks for night priority markers and morning lead hierarchy."""
    source = Image.open(TARGETS / "routine-ledger-selected.png").convert("RGB")
    split = source.width // 2
    night_target = source.crop((0, 0, split, source.height))
    morning_target = source.crop((split, 0, source.width, source.height))
    night_build = Image.open(
        GOLDENS / "routine_ledger_night_430x932.png"
    ).convert("RGB")
    morning_build = Image.open(
        GOLDENS / "routine_ledger_morning_430x932.png"
    ).convert("RGB")

    specs = [
        (
            "NIGHT PRIORITY MARKERS",
            night_target,
            (0.20, 0.59, 0.84, 0.80),
            night_build,
            (0.18, 0.49, 0.84, 0.60),
        ),
        (
            "MORNING BEGIN HERE",
            morning_target,
            (0.18, 0.20, 0.82, 0.57),
            morning_build,
            (0.12, 0.22, 0.87, 0.45),
        ),
    ]

    rows: list[Image.Image] = []
    gap = 18
    for title, target, target_box, build, build_box in specs:
        tiles = [
            _detail_tile(title, "APPROVED ART BOARD", target, target_box),
            _detail_tile(title, "PHONE BUILD", build, build_box),
        ]
        row = Image.new(
            "RGB",
            (sum(tile.width for tile in tiles) + gap, max(tile.height for tile in tiles)),
            BG,
        )
        x = 0
        for tile in tiles:
            row.paste(tile, (x, 0))
            x += tile.width + gap
        rows.append(row)
    return stack(rows, "routine-ledger-detail-target-vs-build")


def routine_phone_sheet() -> Path:
    """Phone-friendly two-up of the current night and morning bookends."""
    label_h = 34
    gap = 16
    screens = [
        ("NIGHT", GOLDENS / "routine_ledger_night_430x932.png"),
        ("MORNING", GOLDENS / "routine_ledger_morning_430x932.png"),
    ]
    tiles: list[Image.Image] = []
    for label, path in screens:
        screen = Image.open(path).convert("RGB")
        tile = Image.new("RGB", (screen.width, screen.height + label_h), BG)
        tile.paste(screen, (0, label_h))
        ImageDraw.Draw(tile).text((8, 8), label, font=_font(16), fill=INK)
        tiles.append(tile)

    sheet = Image.new(
        "RGB",
        (sum(tile.width for tile in tiles) + gap, max(tile.height for tile in tiles)),
        BG,
    )
    x = 0
    for tile in tiles:
        sheet.paste(tile, (x, 0))
        x += tile.width + gap

    OUT.mkdir(parents=True, exist_ok=True)
    dest = OUT / "routine-ledger-phone-after.webp"
    sheet.save(dest, "WEBP", quality=84, method=6)
    print(dest)
    return dest


SYSTEM = [
    ("QUESTS", TARGETS / "quest-selected-journal.png", GOLDENS / "store_01_quests_1290x2796.png"),
    ("ME", TARGETS / "me.png", GOLDENS / "store_02_keep_1290x2796.png"),
    ("GOALS", TARGETS / "goals.png", GOLDENS / "store_04_goals_1290x2796.png"),
    ("PLANS", TARGETS / "plans.png", GOLDENS / "store_05_planner_1290x2796.png"),
    ("JOURNAL", TARGETS / "journal.png", GOLDENS / "store_06_insights_1290x2796.png"),
]

REVIEW = [
    ("QUESTS - READY", GOLDENS / "store_01_quests_1290x2796.png"),
    ("QUESTS - MID SCROLL", GOLDENS / "store_01a_quests_scrolled_1290x2796.png"),
    ("QUESTS - WIND DOWN", GOLDENS / "store_01d_evening_close_1290x2796.png"),
    ("QUESTS - COMPLETE", GOLDENS / "store_02_reward_1290x2796.png"),
    ("ME", GOLDENS / "store_02_keep_1290x2796.png"),
    ("GOALS", GOLDENS / "store_04_goals_1290x2796.png"),
    ("PLANS", GOLDENS / "store_05_planner_1290x2796.png"),
    ("JOURNAL", GOLDENS / "store_06_insights_1290x2796.png"),
    ("QUEST DESK", GOLDENS / "store_01b_quest_desk_1290x2796.png"),
    ("TOP THREE", GOLDENS / "store_01c_top_three_1290x2796.png"),
    ("MOMENTUM KITS", GOLDENS / "store_04b_momentum_kits_1290x2796.png"),
    ("CAPACITY FLOW", GOLDENS / "store_04c_low_flame_1290x2796.png"),
    ("ACTIVE WORKOUT", GOLDENS / "store_10_workout_active_1290x2796.png"),
    ("NIGHT CLOSE", GOLDENS / "routine_ledger_night_430x932.png"),
    ("NIGHT PLANNER", GOLDENS / "routine_ledger_planner_430x932.png"),
    (
        "NIGHT - MANY EXPANDED",
        GOLDENS / "routine_ledger_night_many_expanded_430x932.png",
    ),
    ("MORNING OPEN", GOLDENS / "routine_ledger_morning_430x932.png"),
    ("NIGHT REFLECTIONS", GOLDENS / "store_11b_night_reflection_1290x2796.png"),
    ("FROM LAST NIGHT", GOLDENS / "store_12_morning_open_1290x2796.png"),
]

CURRENT_PASS = [
    ("QUESTS - READY", GOLDENS / "store_01_quests_1290x2796.png"),
    ("QUESTS - MID SCROLL", GOLDENS / "store_01a_quests_scrolled_1290x2796.png"),
    ("QUESTS - RESOLVING", GOLDENS / "store_02a_stitch_1290x2796.png"),
    ("QUESTS - RECEIPT", GOLDENS / "store_02_reward_1290x2796.png"),
    ("NIGHT CLOSE", GOLDENS / "routine_ledger_night_430x932.png"),
    ("MORNING OPEN", GOLDENS / "routine_ledger_morning_430x932.png"),
]

AUDIT_PASS = [
    ("WELCOME", GOLDENS / "store_audit_00_welcome_1290x2796.png"),
    ("TIME-AWARE NAME", GOLDENS / "store_audit_01_evening_name_1290x2796.png"),
    ("FRESH ME", GOLDENS / "store_audit_10_fresh_me_1290x2796.png"),
    ("ROOM IDENTITIES", GOLDENS / "store_audit_11_space_themes_1290x2796.png"),
    ("CONSERVATORY", GOLDENS / "store_audit_11b_conservatory_preview_1290x2796.png"),
    ("FRESH JOURNAL", GOLDENS / "store_audit_12_fresh_journal_1290x2796.png"),
    ("JOURNAL HUB", GOLDENS / "store_audit_13_empty_journal_hub_1290x2796.png"),
    ("CONTEXT EDITOR", GOLDENS / "store_audit_14_journal_editor_1290x2796.png"),
]

ROOM_THEME_PASS = [
    ("COMPLETE ROOM ON ME", GOLDENS / "store_audit_10_fresh_me_1290x2796.png"),
    (
        "CONSERVATORY + ARCHIVE",
        GOLDENS / "store_audit_11a_conservatory_choice_1290x2796.png",
    ),
    (
        "CONSERVATORY PREVIEW",
        GOLDENS / "store_audit_11b_conservatory_preview_1290x2796.png",
    ),
    (
        "ARCHIVE PREVIEW",
        GOLDENS / "store_audit_11c_archive_preview_1290x2796.png",
    ),
]

JOURNAL_PERFORMANCE_PASS = [
    ("QUEST COMPLETE", GOLDENS / "store_02_reward_1290x2796.png"),
    ("OPTIONAL ONE LINE", GOLDENS / "store_02c_quick_reflection_1290x2796.png"),
    (
        "ONE LINE WRITTEN",
        GOLDENS / "store_02d_quick_reflection_written_1290x2796.png",
    ),
    ("KEPT IN JOURNAL", GOLDENS / "store_02e_reflection_kept_1290x2796.png"),
    ("JOURNAL CONTEXT", GOLDENS / "store_07_journal_1290x2796.png"),
    ("NIGHT CLOSE", GOLDENS / "store_11_night_close_1290x2796.png"),
    ("NIGHT REFLECTIONS", GOLDENS / "store_11b_night_reflection_1290x2796.png"),
]

SOCIAL_PASS = [
    ("MY SPACE", GOLDENS / "store_02_keep_1290x2796.png"),
    ("YOUR CIRCLE", GOLDENS / "store_02b_hearth_circle_1290x2796.png"),
    (
        "GENERATED VISITOR ROOM",
        GOLDENS / "store_02c_visitor_room_1290x2796.png",
    ),
]

MY_SPACE_CARDS_PASS = [
    (
        "COMPOSED CARD DECK",
        GOLDENS / "store_14_my_space_cards_1290x2796.png",
    ),
    (
        "REORDER / HIDE / EDIT",
        GOLDENS / "store_14c_my_space_arranger_1290x2796.png",
    ),
]

SHARING_JOURNAL_PASS = [
    (
        "GENERATED VISITOR ROOM",
        GOLDENS / "store_02c_visitor_room_1290x2796.png",
    ),
    (
        "FIXED SUPPORT PICKER",
        GOLDENS / "store_02f_support_picker_1290x2796.png",
    ),
    (
        "PROMPT VS WRITING",
        GOLDENS / "store_13b_journal_quest_entry_1290x2796.png",
    ),
    (
        "LOOKING BACK - READ MODE",
        GOLDENS / "store_13c_journal_read_mode_1290x2796.png",
    ),
    (
        "LOCAL-ONLY SPACE CARDS",
        GOLDENS / "store_14c_my_space_arranger_1290x2796.png",
    ),
    (
        "MOTION-REACTIVE METAL",
        GOLDENS / "store_15_button_light_angles_1290x2100.png",
    ),
]

BRAND_PASS = [
    (
        "OLD PUBLIC MARK",
        APP / "assets" / "brand" / "morrowloom-icon-runtime-v2.webp",
    ),
    ("ROOM OF DAYS MARK", APP / "web" / "icons" / "Icon-1024.png"),
    (
        "GOOGLE PLAY FEATURE GRAPHIC",
        APP / "store-assets" / "google-play-feature-graphic-1024x500.png",
    ),
]

FOCUS = [
    ("QUEST CONTROL", SYSTEM[0][1], SYSTEM[0][2], (0.02, 0.50, 0.98, 0.73)),
    ("QUEST HUD", SYSTEM[0][1], SYSTEM[0][2], (0.02, 0.28, 0.98, 0.50)),
    ("ME BUILD", SYSTEM[1][1], SYSTEM[1][2], (0.02, 0.55, 0.98, 0.95)),
    ("GOALS RAIL", SYSTEM[2][1], SYSTEM[2][2], (0.02, 0.28, 0.98, 0.58)),
    ("PLANS CALENDAR", SYSTEM[3][1], SYSTEM[3][2], (0.02, 0.28, 0.98, 0.70)),
    ("JOURNAL", SYSTEM[4][1], SYSTEM[4][2], (0.02, 0.26, 0.98, 0.66)),
]


def main() -> None:
    mode = sys.argv[1] if len(sys.argv) > 1 else "system"
    if mode == "system":
        contact_sheet(SYSTEM, "system-target-vs-build")
    elif mode == "focus":
        stack([crop_pair(*f) for f in FOCUS], "focused-target-vs-build")
    elif mode == "review":
        image_sheet(REVIEW, "current-system-review")
    elif mode == "review-phone":
        image_sheet(
            REVIEW,
            "current-system-review-phone",
            height=520,
            per_row=2,
            webp=True,
        )
    elif mode == "brand-review":
        image_sheet(
            BRAND_PASS,
            "room-of-days-brand-review",
            height=500,
            per_row=2,
            webp=True,
        )
    elif mode == "current-pass-phone":
        image_sheet(
            CURRENT_PASS,
            "quest-and-routines-current-pass-phone",
            height=520,
            per_row=2,
            webp=True,
        )
    elif mode == "audit-phone":
        image_sheet(
            AUDIT_PASS,
            "first-run-me-journal-audit-phone",
            height=520,
            per_row=2,
            webp=True,
        )
    elif mode == "rooms":
        contact_sheet(
            [
                (
                    "ME COMPLETE ROOM",
                    TARGETS / "me.png",
                    GOLDENS / "store_audit_10_fresh_me_1290x2796.png",
                )
            ],
            "complete-room-target-vs-build",
            height=1200,
        )
    elif mode == "rooms-phone":
        image_sheet(
            ROOM_THEME_PASS,
            "complete-room-system-phone",
            height=520,
            per_row=2,
            webp=True,
        )
    elif mode == "journal-performance-phone":
        image_sheet(
            JOURNAL_PERFORMANCE_PASS,
            "journal-and-phone-performance-pass",
            height=520,
            per_row=2,
            webp=True,
        )
    elif mode == "social-phone":
        image_sheet(
            SOCIAL_PASS,
            "my-space-circle-visitor-pass",
            height=520,
            per_row=2,
            webp=True,
        )
    elif mode == "my-space-cards-phone":
        image_sheet(
            MY_SPACE_CARDS_PASS,
            "my-space-cards-phone",
            height=620,
            per_row=2,
            webp=True,
        )
    elif mode == "sharing-journal-phone":
        image_sheet(
            SHARING_JOURNAL_PASS,
            "sharing-journal-privacy-pass",
            height=520,
            per_row=2,
            webp=True,
        )
    elif mode == "quest":
        contact_sheet(
            [("QUESTS - READY", SYSTEM[0][1], SYSTEM[0][2])],
            "quests-target-vs-build",
            height=1200,
        )
    elif mode == "quest-detail":
        stack(
            [
                crop_pair(*FOCUS[0]),
                crop_pair(*FOCUS[1]),
            ],
            "quests-detail-target-vs-build",
        )
    elif mode == "probe":
        title, a, b = sys.argv[2], Path(sys.argv[3]), Path(sys.argv[4])
        box = tuple(float(v) for v in sys.argv[5:9]) if len(sys.argv) > 8 else (0, 0, 1, 1)
        stack([crop_pair(title, a, b, box)], f"probe-{title.lower().replace(' ', '-')}")
    elif mode == "evidence-pair":
        title, label_a, a, label_b, b = sys.argv[2:7]
        box = tuple(float(v) for v in sys.argv[7:11]) if len(sys.argv) > 10 else (0, 0, 1, 1)
        slug = title.lower().replace(" ", "-")
        stack(
            [
                crop_pair(
                    title,
                    Path(a),
                    Path(b),
                    box,
                    tags=(label_a.upper(), label_b.upper()),
                )
            ],
            f"evidence-{slug}",
        )
    elif mode == "routine":
        routine_sheet()
    elif mode == "routine-detail":
        routine_detail_sheet()
    elif mode == "routine-phone":
        routine_phone_sheet()
    else:
        raise SystemExit(f"unknown mode {mode}")


if __name__ == "__main__":
    main()
