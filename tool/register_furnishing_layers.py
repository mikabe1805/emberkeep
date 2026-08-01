"""Register isolated Walnut furnishings into the canonical 1536x1024 room.

Image generation supplies one carefully art-directed object per chroma-key
canvas. This deterministic step removes composition guesswork: every cutout is
cropped to its real alpha bounds, scaled without distortion, and placed in the
same room camera used by the empty, rug, and completed plates.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import date
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


APP = Path(__file__).resolve().parents[1]
CUTOUTS = (
    APP
    / "design"
    / "source-assets"
    / "rooms"
    / "furnishing-layers"
    / "cutouts"
)
REGISTERED = CUTOUTS.parent / "registered"
RUNTIME = APP / "assets" / "rooms"
CANVAS = (1536, 1024)
EMPTY_ROOM = APP / "design" / "source-assets" / "rooms" / "wall_walnut-empty-v3.png"


@dataclass(frozen=True)
class LayerSpec:
    source: str
    target: tuple[int, int, int, int]
    vertical_align: str = "bottom"


# target = left, top, width, height in the exact empty-room camera.
LAYERS: dict[str, LayerSpec] = {
    "cushion": LayerSpec("cushion-side-table-v1.png", (190, 535, 215, 250)),
    "plant": LayerSpec("plant-v1.png", (0, 525, 150, 365)),
    "candles": LayerSpec(
        "candles-candle-ledge-v1.png", (675, 300, 155, 235), "center"
    ),
    "lamp": LayerSpec("lamp-v1.png", (370, 335, 145, 430)),
    "garland": LayerSpec("garland-writing-desk-v1.png", (515, 485, 530, 315)),
    "shelf": LayerSpec("shelf-v1.png", (455, 105, 370, 390), "center"),
    "picture": LayerSpec(
        "picture-woven-dawn-v1.png", (825, 120, 175, 300), "center"
    ),
    "chair": LayerSpec("chair-armchair-v1.png", (0, 420, 390, 470)),
    "pet": LayerSpec("pet-desk-chair-v1.png", (625, 465, 225, 365)),
    "hearth": LayerSpec("hearth-v1.png", (1160, 445, 335, 255), "center"),
}


def _trim(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A")
    bbox = alpha.getbbox()
    if bbox is None:
        raise ValueError("cutout contains no visible pixels")
    left, top, right, bottom = bbox
    pad = 3
    return rgba.crop(
        (
            max(0, left - pad),
            max(0, top - pad),
            min(rgba.width, right + pad),
            min(rgba.height, bottom + pad),
        )
    )


def _register(
    spec: LayerSpec,
) -> tuple[Image.Image, Image.Image, tuple[int, int, int, int]]:
    subject = _trim(Image.open(CUTOUTS / spec.source))
    left, top, target_w, target_h = spec.target
    scale = min(target_w / subject.width, target_h / subject.height)
    size = (
        max(1, round(subject.width * scale)),
        max(1, round(subject.height * scale)),
    )
    subject = subject.resize(size, Image.Resampling.LANCZOS)

    x = left + (target_w - size[0]) // 2
    if spec.vertical_align == "center":
        y = top + (target_h - size[1]) // 2
    else:
        y = top + target_h - size[1]

    layer = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    layer.alpha_composite(subject, (x, y))
    return layer, subject, (x, y, size[0], size[1])


def main() -> None:
    REGISTERED.mkdir(parents=True, exist_ok=True)
    RUNTIME.mkdir(parents=True, exist_ok=True)
    review_items: list[tuple[str, Image.Image]] = []
    for furniture_id, spec in LAYERS.items():
        layer, runtime, placement = _register(spec)
        stem = f"wall_walnut-layer-{furniture_id}-v1"
        source_path = REGISTERED / f"{stem}.png"
        runtime_path = RUNTIME / f"{stem}.webp"
        layer.save(source_path, "PNG", optimize=True)
        # Runtime keeps only the tight final-size cutout. Decoding ten full
        # transparent 1536x1024 canvases would waste roughly 60 MB before the
        # room cache even began compositing them.
        runtime.save(runtime_path, "WEBP", lossless=True, method=6)
        review_items.append((furniture_id, layer.copy()))
        print(
            f"{furniture_id}: {source_path} -> {runtime_path}; "
            f"placement={placement}"
        )

    order = [
        "shelf",
        "picture",
        "candles",
        "lamp",
        "chair",
        "garland",
        "cushion",
        "plant",
        "pet",
        "hearth",
    ]
    by_id = dict(review_items)
    combined = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    for furniture_id in order:
        combined.alpha_composite(by_id[furniture_id])
    review_items.append(("all independent layers", combined))
    _write_review(review_items)


def _write_review(items: list[tuple[str, Image.Image]]) -> None:
    empty = Image.open(EMPTY_ROOM).convert("RGBA")
    tile_size = (768, 512)
    label_h = 28
    gap = 14
    columns = 2
    rows = (len(items) + columns - 1) // columns
    sheet = Image.new(
        "RGB",
        (
            columns * tile_size[0] + (columns + 1) * gap,
            rows * (tile_size[1] + label_h) + (rows + 1) * gap,
        ),
        (12, 10, 9),
    )
    draw = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype("consola.ttf", 18)
    except OSError:
        font = ImageFont.load_default()

    for index, (furniture_id, layer) in enumerate(items):
        composite = empty.copy()
        composite.alpha_composite(layer)
        composite = composite.convert("RGB").resize(tile_size, Image.Resampling.LANCZOS)
        column = index % columns
        row = index // columns
        x = gap + column * (tile_size[0] + gap)
        y = gap + row * (tile_size[1] + label_h + gap)
        draw.text((x + 4, y + 4), furniture_id.upper(), font=font, fill=(218, 200, 172))
        sheet.paste(composite, (x, y + label_h))

    output = APP / "design" / "comparisons" / date.today().isoformat()
    output.mkdir(parents=True, exist_ok=True)
    path = output / "furnishing-layer-registration.png"
    sheet.save(path, "PNG", optimize=True)
    print(path)


if __name__ == "__main__":
    main()
