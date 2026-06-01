#!/usr/bin/env python3
"""Generate the Aero Snap app icon family (primary + alternates).

Design philosophy: clean and minimal — solid background with a
centered three-capsule airplane silhouette. The primary uses system
blue (the in-app accent); each alternate matches one premium theme's
outer background so it visually belongs to the active theme.

Run:
    python3 tools/make_app_icon.py

Output:
    AeroSnap/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png        (primary)
    AeroSnap/Assets.xcassets/AppIconSkyBlue.appiconset/...              (alternates)
    AeroSnap/Assets.xcassets/AppIconPeachPink.appiconset/...
    AeroSnap/Assets.xcassets/AppIconDeepCharcoal.appiconset/...
    AeroSnap/Assets.xcassets/AppIconBlueberry.appiconset/...

Each appiconset's Contents.json is created (overwritten) so the
asset catalog references the freshly-generated PNG by filename.
"""
from __future__ import annotations
import json
from dataclasses import dataclass
from pathlib import Path
from PIL import Image, ImageDraw

SIZE = 1024
CENTER = SIZE // 2
ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "AeroSnap/Assets.xcassets"


@dataclass(frozen=True)
class IconVariant:
    """One icon in the family.

    appiconset = the folder name under Assets.xcassets (also the
    alternateIconName passed to UIApplication.setAlternateIconName).
    """
    appiconset: str
    background: tuple[int, int, int, int]
    plane_color: tuple[int, int, int, int]


# Primary uses iOS system blue (#0A84FF). Alternates use each premium
# theme's outer background hex from AppTheme.swift, with the airplane
# tinted to the theme's outerForeground color (white on light themes,
# warm ivory on dark themes) so the silhouette always reads cleanly.
WHITE = (255, 255, 255, 255)
IVORY = (245, 237, 224, 255)   # #F5EDE0 — matches AppTheme dark outerForeground

VARIANTS = [
    IconVariant("AppIcon.appiconset",              (0x0A, 0x84, 0xFF, 255), WHITE),
    IconVariant("AppIconSkyBlue.appiconset",       (0xC9, 0xD3, 0xDE, 255), WHITE),
    IconVariant("AppIconPeachPink.appiconset",     (0xEA, 0xC3, 0xB7, 255), WHITE),
    IconVariant("AppIconDeepCharcoal.appiconset",  (0x0A, 0x08, 0x08, 255), IVORY),
    IconVariant("AppIconBlueberry.appiconset",     (0x14, 0x1E, 0x2D, 255), IVORY),
]


def _capsule(draw: ImageDraw.ImageDraw,
             cx: int, cy: int, width: int, height: int,
             color: tuple[int, int, int, int]) -> None:
    draw.rounded_rectangle(
        [cx - width // 2, cy - height // 2,
         cx + width // 2, cy + height // 2],
        radius=height // 2,
        fill=color,
    )


def render(variant: IconVariant) -> Image.Image:
    """Render one icon. Same silhouette geometry across all variants;
    only the colors change."""
    img = Image.new("RGBA", (SIZE, SIZE), variant.background)
    plane = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(plane)
    cx = CENTER

    # Fuselage
    _capsule(draw, cx, CENTER + 12, 124, 778, variant.plane_color)
    # Wings
    _capsule(draw, cx, 540,         780, 138, variant.plane_color)
    # H-stab
    _capsule(draw, cx, 845,         320, 86,  variant.plane_color)

    img.alpha_composite(plane)
    return img


def write_appiconset(variant: IconVariant) -> Path:
    appiconset_dir = ASSETS / variant.appiconset
    appiconset_dir.mkdir(parents=True, exist_ok=True)

    # Filename derived from the appiconset (drop ".appiconset" suffix
    # and add "-1024.png") so file references stay deterministic.
    base = variant.appiconset.removesuffix(".appiconset")
    png_name = f"{base}-1024.png"

    img = render(variant)
    img.save(appiconset_dir / png_name, format="PNG", optimize=True)

    contents = {
        "images": [
            {
                "filename": png_name,
                "idiom": "universal",
                "platform": "ios",
                "size": "1024x1024",
            }
        ],
        "info": {"author": "xcode", "version": 1},
    }
    (appiconset_dir / "Contents.json").write_text(
        json.dumps(contents, indent=2) + "\n"
    )
    return appiconset_dir / png_name


def write_preview_imageset(variant: IconVariant) -> Path:
    """Also write the icon as a regular Image Set, so the in-app
    AppIconPickerSheet can render a preview thumbnail. The compiled
    appiconset PNGs live inside Assets.car and aren't accessible via
    UIImage(named:), so we need a parallel preview asset."""
    base = variant.appiconset.removesuffix(".appiconset")
    preview_dir = ASSETS / f"{base}Preview.imageset"
    preview_dir.mkdir(parents=True, exist_ok=True)

    png_name = f"{base}-1024.png"
    img = render(variant)
    img.save(preview_dir / png_name, format="PNG", optimize=True)

    contents = {
        "images": [
            {"filename": png_name, "idiom": "universal", "scale": "1x"},
            {"idiom": "universal", "scale": "2x"},
            {"idiom": "universal", "scale": "3x"},
        ],
        "info": {"author": "xcode", "version": 1},
    }
    (preview_dir / "Contents.json").write_text(
        json.dumps(contents, indent=2) + "\n"
    )
    return preview_dir / png_name


def main() -> None:
    for v in VARIANTS:
        out = write_appiconset(v)
        size_kb = out.stat().st_size // 1024
        print(f"[icon] {out.relative_to(ROOT)} ({size_kb} KB)")
        preview = write_preview_imageset(v)
        print(f"[icon] {preview.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
