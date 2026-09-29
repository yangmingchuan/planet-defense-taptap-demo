"""Pack existing 256px monster animation frames for NanoVG runtime sampling."""

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/image/monsters"
DEST = SOURCE / "battle-animation-atlas-v1.png"
KINDS = ("basic", "agile", "tank", "armored")
STATES = ("walk", "attack")
CELL = 256
COLS = 8
ROWS = 6


def main() -> None:
    atlas = Image.new("RGBA", (COLS * CELL, ROWS * CELL), (0, 0, 0, 0))
    index = 0
    for kind in KINDS:
        for state in STATES:
            for frame in range(1, 7):
                path = SOURCE / kind / state / f"{frame:02d}.png"
                with Image.open(path) as source:
                    image = source.convert("RGBA")
                    if image.size != (CELL, CELL):
                        raise ValueError(f"Unexpected frame size: {path}: {image.size}")
                    atlas.alpha_composite(image, ((index % COLS) * CELL, (index // COLS) * CELL))
                index += 1
    assert index == COLS * ROWS
    atlas.save(DEST, optimize=True)
    print(f"Packed {index} frames into {DEST} ({atlas.width}x{atlas.height})")


if __name__ == "__main__":
    main()
