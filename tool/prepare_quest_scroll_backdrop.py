"""Build the Quest board's pre-softened scroll backdrop.

The live room remains a multi-plane scene with an animated fire. Once quest
cards climb over it, however, repeatedly blurring that entire scene is one of
the most expensive things a phone GPU can do. This script registers the same
authored layers once, softens the finished plate, and writes a small runtime
raster that can fade in during scroll without a live BackdropFilter.
"""

from pathlib import Path

from PIL import Image, ImageFilter


APP = Path(__file__).resolve().parents[1]
ROOMS = APP / "assets" / "rooms"
OUTPUT = ROOMS / "quest-depth-scroll-soft-v1.webp"
CANVAS = (1635, 962)


def main() -> None:
    room = Image.open(ROOMS / "quest-depth-base-v2.webp").convert("RGBA")
    if room.size != CANVAS:
        raise ValueError(f"unexpected Quest room camera: {room.size}")

    # Match QuestDepthRoom's actual painter order and use the middle authored
    # fire frame as a quiet representative glow beneath the softened veil.
    fire = Image.open(ROOMS / "quest-fire-b-v3.png").convert("RGBA")
    room.alpha_composite(fire, (1290, 470))
    for name in (
        "quest-depth-wall-v4.png",
        "quest-depth-furniture-v1.png",
        "quest-depth-foreground-v1.png",
    ):
        room.alpha_composite(Image.open(ROOMS / name).convert("RGBA"))

    # Radius is expressed in source pixels. At phone size this reads like the
    # former ~8 logical-pixel veil, while the downsample removes needless
    # decode and texture-upload cost.
    room = room.filter(ImageFilter.GaussianBlur(radius=22))
    target = (1024, round(1024 * CANVAS[1] / CANVAS[0]))
    room = room.convert("RGB").resize(target, Image.Resampling.LANCZOS)
    room.save(OUTPUT, "WEBP", quality=80, method=6)
    print(f"{OUTPUT} ({target[0]}x{target[1]})")


if __name__ == "__main__":
    main()
