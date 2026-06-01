#!/usr/bin/env python3
"""Generate the Aero Snap app icon (1024x1024 PNG).

Design philosophy: clean and minimal, matching the in-app onboarding
hero — solid accent-blue background with a centered white airplane
silhouette (top-down view, nose pointing up). The silhouette is
hand-tuned to read at 60pt (Spotlight) without losing detail and at
180pt (Home Screen) without looking sparse.

Run:
    python3 tools/make_app_icon.py

Output:
    AeroSnap/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png
"""
from __future__ import annotations
from pathlib import Path
from PIL import Image, ImageDraw

SIZE = 1024
CENTER = SIZE // 2
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "AeroSnap/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"

# Same hex as the in-app .accentColor / blue tile in OnboardingView.
# This is the iOS system blue at 100% saturation — sits in the same
# tonal family as ICD Snap / DOT Snap's accent so the Snap series
# reads as a single visual family on the Home Screen.
ACCENT = (10, 132, 255, 255)   # #0A84FF (system blue, dark-mode tuned)
WHITE  = (255, 255, 255, 255)


def _capsule(draw: ImageDraw.ImageDraw,
             cx: int, cy: int, width: int, height: int,
             color: tuple[int, int, int, int]) -> None:
    """Draw a horizontal pill (rounded rect with radius = height/2)
    centered at (cx, cy). The fuselage uses the same primitive rotated
    by swapping width/height."""
    draw.rounded_rectangle(
        [cx - width // 2, cy - height // 2,
         cx + width // 2, cy + height // 2],
        radius=height // 2,
        fill=color,
    )


def render() -> Image.Image:
    """Compose the airplane silhouette from three centered capsules.

    Capsules (= rounded rectangles with radius = half the short side)
    join each other without visible seams — every endpoint is a clean
    semicircle, so wherever they overlap the union reads as one
    continuous white shape.

      - fuselage: vertical capsule, nose at top / tail at bottom
      - wings:    horizontal capsule, centered slightly above midline
      - h-stab:   smaller horizontal capsule near the tail

    Proportions are tuned by eye for the 1024×1024 master:
    airplane spans ~76% width / ~76% height, comfortably inside
    Apple's ~80% icon safe area.
    """
    img = Image.new("RGBA", (SIZE, SIZE), ACCENT)

    # Offscreen alpha layer for the silhouette so the composite is
    # anti-aliased cleanly against the solid bg.
    plane = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(plane)
    cx = CENTER

    # Fuselage — long vertical capsule. Top rounded end is the nose,
    # bottom rounded end is the tail cone.
    fuse_w, fuse_h = 124, 778
    fuse_cy = CENTER + 12   # nudge down so wings sit above the midline
    _capsule(draw, cx, fuse_cy, fuse_w, fuse_h, WHITE)

    # Wings — wide horizontal capsule across the fuselage.
    wing_w, wing_h = 780, 138
    wing_cy = 540
    _capsule(draw, cx, wing_cy, wing_w, wing_h, WHITE)

    # H-stab — smaller horizontal capsule near the tail.
    stab_w, stab_h = 320, 86
    stab_cy = 845
    _capsule(draw, cx, stab_cy, stab_w, stab_h, WHITE)

    img.alpha_composite(plane)
    return img


def main() -> None:
    OUT.parent.mkdir(parents=True, exist_ok=True)
    img = render()
    img.save(OUT, format="PNG", optimize=True)
    print(f"[icon] wrote {OUT.relative_to(ROOT)} ({OUT.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    main()
