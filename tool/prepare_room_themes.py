"""Prepare Morrowloom's complete-room plates and lightweight shop previews.

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
        "source": SOURCE / "wall_walnut-clean-v2.png",
        "runtime": ROOMS / "wall_walnut-clean-v2.webp",
    },
    "wall_conservatory": {
        "source": SOURCE / "themes" / "wall_conservatory-full-v1.png",
        "runtime": ROOMS / "wall_conservatory-v1.webp",
    },
    "wall_archive": {
        "source": SOURCE / "themes" / "wall_archive-full-v1.png",
        "runtime": ROOMS / "wall_archive-v1.webp",
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
            # The approved Writer's Hearth runtime predates this script and is
            # already production-compressed. Preserve it byte-for-byte; only
            # prepare the two new siblings here.
            if theme_id != "wall_walnut":
                full.save(paths["runtime"], "WEBP", quality=92, method=6)
            preview = full.resize(PREVIEW_SIZE, Image.Resampling.LANCZOS)
            preview_path = PREVIEWS / f"{theme_id}-v1.webp"
            preview.save(preview_path, "WEBP", quality=88, method=6)
            print(
                f"{theme_id}: {full.size} -> {paths['runtime'].name}; "
                f"preview={preview_path.name} {preview.size}"
            )


if __name__ == "__main__":
    main()
