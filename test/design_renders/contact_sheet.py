"""Labeled contact sheet for a folder rendered with class_day_harness.dart.

Reads <dir>/frames.json (written by FrameSheet.writeManifest), groups frames
into bands by their clock time, scales every frame to the same height, and
captions each with its id, time, surface and note.

  python test/design_renders/contact_sheet.py <dir> <out.png> \
      --title "..." --subtitle "..." [--height 700] [--columns 7]
"""

import argparse
import json
import os
import textwrap
from datetime import datetime

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
FONTS = os.path.normpath(os.path.join(HERE, '..', '..', 'assets', 'google_fonts'))

CANVAS = (25, 18, 16)
CARD = (42, 33, 29)
TEXT_HI = (244, 234, 219)
TEXT_MID = (207, 194, 176)
TEXT_LO = (179, 165, 148)
HONEY = (224, 168, 101)


def font(name, size):
    return ImageFont.truetype(os.path.join(FONTS, name), size)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('directory')
    parser.add_argument('output')
    parser.add_argument('--title', default='Room of Days renders')
    parser.add_argument('--subtitle', default='')
    parser.add_argument('--height', type=int, default=700)
    parser.add_argument('--columns', type=int, default=7)
    parser.add_argument(
        '--order',
        default='',
        help='comma-separated frame id letters giving the band order, '
        'for example B,C,D,A,F,G; otherwise bands run by clock time',
    )
    args = parser.parse_args()

    with open(os.path.join(args.directory, 'frames.json'), encoding='utf-8') as f:
        frames = json.load(f)

    bands = {}
    for frame in frames:
        bands.setdefault(frame['at'], []).append(frame)
    order = sorted(bands, key=lambda at: datetime.fromisoformat(at))
    if args.order:
        letters = [part.strip() for part in args.order.split(',')]

        def rank(at):
            firsts = [fr['file'][0] for fr in bands[at]]
            hits = [letters.index(c) for c in firsts if c in letters]
            return min(hits) if hits else len(letters)

        order = sorted(order, key=rank)

    fh = args.height
    gap = 26
    cap_h = 172
    title_font = font('Inter-SemiBold.ttf', 46)
    sub_font = font('Inter-Regular.ttf', 24)
    band_font = font('JetBrainsMono-Bold.ttf', 30)
    id_font = font('JetBrainsMono-Bold.ttf', 20)
    surface_font = font('Inter-SemiBold.ttf', 20)
    note_font = font('Inter-Italic.ttf', 17)

    # Every frame shares one width at this height (they are all phone frames).
    sample = Image.open(os.path.join(args.directory, frames[0]['file']))
    fw = round(sample.width * fh / sample.height)
    cols = args.columns
    width = gap + cols * (fw + gap)

    layout = []  # (band title, rows of frames)
    height = 40 + 60 + 40 + 30
    for at in order:
        items = sorted(bands[at], key=lambda fr: fr['file'])
        rows = [items[i:i + cols] for i in range(0, len(items), cols)]
        layout.append((items[0]['when'], rows))
        height += 70 + len(rows) * (fh + cap_h + gap)
    height += 30

    sheet = Image.new('RGB', (width, height), CANVAS)
    draw = ImageDraw.Draw(sheet)
    y = 40
    draw.text((gap, y), args.title, font=title_font, fill=TEXT_HI)
    y += 64
    if args.subtitle:
        draw.text((gap, y), args.subtitle, font=sub_font, fill=TEXT_LO)
    y += 56

    for when, rows in layout:
        draw.text((gap, y), when.upper(), font=band_font, fill=HONEY)
        draw.line((gap, y + 46, width - gap, y + 46), fill=(90, 70, 50), width=2)
        y += 70
        for row in rows:
            x = gap
            for frame in row:
                img = Image.open(os.path.join(args.directory, frame['file'])).convert('RGB')
                img = img.resize((fw, fh), Image.LANCZOS)
                sheet.paste(img, (x, y))
                draw.rectangle((x - 1, y - 1, x + fw, y + fh), outline=(70, 55, 44))
                cy = y + fh + 10
                stem = frame['file'].rsplit('.', 1)[0].split('_')
                frame_id = stem[0]
                if len(stem) > 1 and stem[-1][:1] == 'p' and stem[-1][1:].isdigit():
                    frame_id += ' ' + stem[-1]
                draw.text((x, cy), frame_id, font=id_font, fill=HONEY)
                cy += 28
                for line in textwrap.wrap(frame['surface'], width=30)[:2]:
                    draw.text((x, cy), line, font=surface_font, fill=TEXT_HI)
                    cy += 25
                for line in textwrap.wrap(frame.get('note', ''), width=36)[:3]:
                    draw.text((x, cy), line, font=note_font, fill=TEXT_MID)
                    cy += 21
                x += fw + gap
            y += fh + cap_h + gap

    sheet.save(args.output, optimize=True)
    print(f'{args.output}: {sheet.width}x{sheet.height}, {len(frames)} frames')


if __name__ == '__main__':
    main()
