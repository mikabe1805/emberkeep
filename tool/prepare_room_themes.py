"""Prepare Room of Days complete-room plates and lightweight shop previews.

The production contract is deliberately small: each room identity owns one
finished 1536 x 1024 painting. The app moves that intact plate as a single
overscanned camera, avoiding the seams and memory cost of reconstructing a
room from many optional furniture layers.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageOps


APP = Path(__file__).resolve().parents[1]
ROOMS = APP / "assets" / "rooms"
PREVIEWS = ROOMS / "previews"
SOURCE = APP / "design" / "source-assets" / "rooms"
FULL_SIZE = (1536, 1024)
PREVIEW_SIZE = (720, 480)

THEMES = {
    "wall_walnut": {
        "source": SOURCE / "wall_walnut-fireless-v3.png",
        "runtime": ROOMS / "wall_walnut-fireless-v3.webp",
        "preview": PREVIEWS / "wall_walnut-fireless-v3.webp",
    },
    "wall_conservatory": {
        "source": SOURCE / "themes" / "wall_conservatory-fireless-v2.png",
        "runtime": ROOMS / "wall_conservatory-fireless-v2.webp",
        "preview": PREVIEWS / "wall_conservatory-fireless-v2.webp",
    },
    "wall_archive": {
        "source": SOURCE / "themes" / "wall_archive-fireless-v2.png",
        "runtime": ROOMS / "wall_archive-fireless-v2.webp",
        "preview": PREVIEWS / "wall_archive-fireless-v2.webp",
    },
}


def _fit(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    return ImageOps.fit(
        image.convert("RGB"),
        size,
        method=Image.Resampling.LANCZOS,
        centering=(0.5, 0.5),
    )


def main() -> None:
    PREVIEWS.mkdir(parents=True, exist_ok=True)
    for theme_id, paths in THEMES.items():
        with Image.open(paths["source"]) as source:
            full = _fit(source, FULL_SIZE)
            full.save(paths["runtime"], "WEBP", quality=92, method=6)
            preview = full.resize(PREVIEW_SIZE, Image.Resampling.LANCZOS)
            preview_path = paths["preview"]
            preview.save(preview_path, "WEBP", quality=88, method=6)
            print(
                f"{theme_id}: {full.size} -> {paths['runtime'].name}; "
                f"preview={preview_path.name} {preview.size}"
            )


if __name__ == "__main__":
    main()
