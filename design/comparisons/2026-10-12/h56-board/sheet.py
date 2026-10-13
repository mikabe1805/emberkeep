"""Before / after sheets for the h56 board pass.

Frames come from test/design_renders/h56_board_render_test.dart (393 x 852 at
3x, the real app). The "before" frames are in _before/ (build 55's code), the
"after" frames beside this file.

    python sheet.py            # writes SHEET-*.png next to this file
"""

import os
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.abspath(__file__))
W = 380  # one frame's width in the sheet


def load(path):
    return Image.open(os.path.join(ROOT, path)).convert("RGB")


def thumb(path, crop=None, w=W):
    im = load(path)
    if crop:
        im = im.crop(crop)
    h = round(im.height * w / im.width)
    return im.resize((w, h), Image.LANCZOS)


def font(size):
    for name in ("arial.ttf", "segoeui.ttf", "DejaVuSans.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except Exception:
            continue
    return ImageFont.load_default()


TITLE = font(26)
LABEL = font(17)
SMALL = font(14)

INK = (24, 18, 16)
HONEY = (236, 214, 170)
SOFT = (200, 180, 150)
BEFORE = (214, 150, 120)
AFTER = (160, 200, 150)


def sheet(title, rows, out):
    """rows: list of (caption, [(tag, label, image)])."""
    gap = 18
    pad = 26
    cap_h = 30
    lab_h = 24
    width = pad * 2
    for _, cells in rows:
        width = max(
            width,
            pad * 2 + sum(im.width for _, _, im in cells) + gap * (len(cells) - 1),
        )
    height = pad + 44
    for _, cells in rows:
        height += cap_h + lab_h + max(im.height for _, _, im in cells) + gap + 10
    canvas = Image.new("RGB", (width, height), INK)
    d = ImageDraw.Draw(canvas)
    d.text((pad, pad - 6), title, fill=HONEY, font=TITLE)
    y = pad + 44
    for caption, cells in rows:
        d.text((pad, y), caption, fill=HONEY, font=LABEL)
        y += cap_h
        x = pad
        for tag, label, im in cells:
            colour = BEFORE if tag == "before" else AFTER
            d.text((x, y), f"{tag.upper()}  {label}", fill=colour, font=SMALL)
            canvas.paste(im, (x, y + lab_h))
            d.rectangle(
                [x - 1, y + lab_h - 1, x + im.width, y + lab_h + im.height],
                outline=(70, 56, 46),
            )
            x += im.width + gap
        y += lab_h + max(im.height for _, _, im in cells) + gap + 10
    out_path = os.path.join(ROOT, out)
    canvas.save(out_path)
    print(out, canvas.size)


def pair(name, label_before="build 55", label_after="now"):
    return [
        ("before", label_before, thumb(f"_before/{name}.png")),
        ("after", label_after, thumb(f"{name}.png")),
    ]


def main():
    # 1. What he saw: the evening Doorway and the board, 11:37 at night.
    sheet(
        "Room of Days h56: his 11:37 PM screens, before and after",
        [
            (
                "The Doorway, both attended, the music on, then the board (BOARD)",
                pair("N_doorway_1137pm") + pair("N_board_1137pm"),
            ),
        ],
        "SHEET-1-his-evening.png",
    )

    # 2. By day: the class card, the board, the work under the HUD.
    sheet(
        "Room of Days h56: by day (Tuesday 12:30), before and after",
        [
            (
                "The Doorway card, then the board at rest",
                pair("M_doorway") + pair("M_board"),
            ),
            (
                "The board scrolled 200 pt: the work climbing under the HUD",
                pair("M_board_scrolled"),
            ),
        ],
        "SHEET-2-by-day.png",
    )

    # 3. The light follows the clock; the evening card at 21:00; Saturday.
    sheet(
        "Room of Days h56: the light, the evening, a day with no classes",
        [
            (
                "11:37 in the MORNING after the last class: midday window, evening card",
                pair("L_doorway_1137am") + pair("L_board_1137am"),
            ),
            (
                "21:00, no music",
                pair("E_doorway_2100") + pair("E_board_2100"),
            ),
            (
                "Saturday: the card with Today's three, then BOARD",
                pair("S_doorway") + pair("S_board"),
            ),
        ],
        "SHEET-3-clock-evening-saturday.png",
    )

    # 4. Large text and the invitation.
    sheet(
        "Room of Days h56: 130% text, and nothing chosen",
        [
            (
                "130% text: the card and the board",
                pair("T_doorway_130") + pair("T_board_130"),
            ),
            (
                "130% text, the evening with the music on; and nothing chosen (the invitation)",
                pair("T_evening_130") + pair("S_doorway_choose"),
            ),
        ],
        "SHEET-4-large-text.png",
    )

    # 4b. Short phones and the kept day.
    sheet(
        "Room of Days h56: short phones, and the day kept",
        [
            (
                "375 x 667: the card, then the board (it overlapped the HUD)",
                pair("P375_doorway") + pair("P375_board"),
            ),
            (
                "320 x 568 at 130%: the card, then the board (it overlapped the HUD)",
                pair("P320_doorway") + pair("P320_board"),
            ),
            (
                "Saturday 21:00, tonight closed: the card, then the board resting",
                pair("R_doorway_closed") + pair("R_board_closed"),
            ),
        ],
        "SHEET-4b-short-phones-and-kept.png",
    )

    # 5. Details, full size: the foot of the glass, before and after.
    foot = (0, 1480, 1179, 2160)
    sheet(
        "The glass's foot, before and after (cropped from the 3x frames)",
        [
            (
                "Evening, the music on: the card at rest",
                [
                    ("before", "build 55", thumb("_before/N_doorway_1137pm.png", crop=foot, w=560)),
                    ("after", "now", thumb("N_doorway_1137pm.png", crop=foot, w=560)),
                ],
            ),
            (
                "By day: the class card's foot",
                [
                    ("before", "build 55", thumb("_before/M_doorway.png", crop=foot, w=560)),
                    ("after", "now", thumb("M_doorway.png", crop=foot, w=560)),
                ],
            ),
        ],
        "SHEET-5-the-foot.png",
    )


if __name__ == "__main__":
    sys.exit(main())
