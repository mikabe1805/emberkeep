"""Labeled sheet for the class-day import journey renders.

  python test/design_renders/import_sheet.py <frames dir> <out.png>

Bands follow the journey (way in, link and review, typing, edges), not the
clock: every frame is Sunday Oct 4 2026, 19:30, except I22 and I23 (Tuesday
Dec 22 2026, noon, after fall ends).
"""

import json
import os
import sys
import textwrap

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
FONTS = os.path.normpath(os.path.join(HERE, '..', '..', 'assets', 'google_fonts'))

CANVAS = (25, 18, 16)
TEXT_HI = (244, 234, 219)
TEXT_MID = (207, 194, 176)
TEXT_LO = (179, 165, 148)
HONEY = (224, 168, 101)

BANDS = [
    ('1  THE WAY IN, FROM PLANS', ['I01', 'I02', 'I03']),
    ('2  A CALENDAR LINK: PASTE, PICK, RESULT, REMINDERS', ['I04', 'I05', 'I06', 'I07', 'I07b', 'I08']),
    ('3  NO CALENDAR AT ALL: TYPE THEM IN (FROM THE ADD MENU)', ['I09a', 'I09', 'I10', 'I11']),
    ("4  EDGES: CANVAS, MIKA'S OWN FILE, TWO TERMS, A WEB PAGE, BUSY ONLY", ['I12', 'I13', 'I14', 'I15', 'I15b', 'I16', 'I17']),
    ('5  A 320 PT PHONE AT 130% TEXT', ['I18', 'I19', 'I20', 'I21']),
    ('6  WINTER BREAK: A FIRST CLASS TYPED ON DEC 22 STARTS NEXT SPRING', ['I22', 'I23']),
]


def font(name, size):
    return ImageFont.truetype(os.path.join(FONTS, name), size)


def main():
    directory, output = sys.argv[1], sys.argv[2]
    with open(os.path.join(directory, 'frames.json'), encoding='utf-8') as f:
        frames = {fr['file'].split('_')[0]: fr for fr in json.load(f)}

    fh, gap, cap_h, cols = 760, 28, 150, 5
    sample = Image.open(os.path.join(directory, next(iter(frames.values()))['file']))
    fw = round(sample.width * fh / sample.height)
    width = gap + cols * (fw + gap)
    height = 40 + 64 + 90
    for _, ids in BANDS:
        rows = (len(ids) + cols - 1) // cols
        height += 72 + rows * (fh + cap_h + gap)
    height += 20

    title_font = font('Inter-SemiBold.ttf', 46)
    sub_font = font('Inter-Regular.ttf', 23)
    band_font = font('JetBrainsMono-Bold.ttf', 28)
    id_font = font('JetBrainsMono-Bold.ttf', 21)
    surface_font = font('Inter-SemiBold.ttf', 21)
    note_font = font('Inter-Italic.ttf', 18)

    sheet = Image.new('RGB', (width, height), CANVAS)
    draw = ImageDraw.Draw(sheet)
    y = 40
    draw.text((gap, y), 'Add your classes: the import journey (build)', font=title_font, fill=TEXT_HI)
    y += 66
    for line in textwrap.wrap(
        'Room of Days, the real app (LifeRpgApp) rendered by flutter_tester at 393 x 852 pt @3x '
        '(I18 to I21: 320 x 568 pt @2x at 130% text) from the cdj-import branch. Sunday Oct 4 2026, 19:30 '
        '(I22 and I23: Tuesday Dec 22 2026, noon). '
        'Calendar samples are invented (a Central-time student, a Canvas feed, an Outlook calendar); '
        "I13 and I14 use Mika's real Fall 2026 Room of Days file. No sound, haptics or device fonts.",
        width=150,
    ):
        draw.text((gap, y), line, font=sub_font, fill=TEXT_LO)
        y += 32
    y += 26

    for title, ids in BANDS:
        draw.text((gap, y), title, font=band_font, fill=HONEY)
        draw.line((gap, y + 44, width - gap, y + 44), fill=(90, 70, 50), width=2)
        y += 72
        for start in range(0, len(ids), cols):
            x = gap
            for frame_id in ids[start:start + cols]:
                frame = frames[frame_id]
                img = Image.open(os.path.join(directory, frame['file'])).convert('RGB')
                img = img.resize((fw, fh), Image.LANCZOS)
                sheet.paste(img, (x, y))
                draw.rectangle((x - 1, y - 1, x + fw, y + fh), outline=(70, 55, 44))
                cy = y + fh + 10
                draw.text((x, cy), frame_id, font=id_font, fill=HONEY)
                cy += 29
                for line in textwrap.wrap(frame['surface'], width=34)[:2]:
                    draw.text((x, cy), line, font=surface_font, fill=TEXT_HI)
                    cy += 26
                for line in textwrap.wrap(frame.get('note', ''), width=40)[:2]:
                    draw.text((x, cy), line, font=note_font, fill=TEXT_MID)
                    cy += 22
                x += fw + gap
            y += fh + cap_h + gap

    sheet.save(output, optimize=True)
    print(f'{output}: {sheet.width}x{sheet.height}, {len(frames)} frames')


if __name__ == '__main__':
    main()
