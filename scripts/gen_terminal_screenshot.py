#!/usr/bin/env python3
"""Generate terminal-style PNG screenshots from a JSON spec.

Usage:
    python scripts/gen_terminal_screenshot.py <spec.json> [--out output/screenshots/<slug>]

Spec format (JSON):
    {
      "slug": "my-sprint-2026-07-13",
      "screenshots": [
        {
          "filename": "01-wave-dispatch.png",
          "title": "bash — sprint wave dispatch",
          "lines": [
            {"text": "Sprint — my-sprint", "color": "white"},
            {"text": "  agentes — 3 parallel", "color": "cyan"},
            {"text": "", "color": ""},
            {"text": "$ git push origin main", "color": "muted"},
            {"text": "feat/my-sprint merged.", "color": "green"}
          ]
        }
      ]
    }

Colors: white, text, cyan, blue, green, yellow, red, lavender, muted
Output: saves PNGs to --out dir (default: output/screenshots/<slug>/)
"""
import json
import sys
import os
import textwrap
from pathlib import Path

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    print("ERROR: Pillow not installed. Run: pip install Pillow")
    sys.exit(1)

# Catppuccin Mocha palette
PALETTE = {
    "bg":       "#1e1e2e",
    "titlebar": "#181825",
    "border":   "#45475a",
    "btclose":  "#f38ba8",
    "btmin":    "#f9e2af",
    "btmax":    "#a6e3a1",
    "white":    "#ffffff",
    "text":     "#cdd6f4",
    "cyan":     "#89dceb",
    "blue":     "#89b4fa",
    "green":    "#a6e3a1",
    "yellow":   "#f9e2af",
    "red":      "#f38ba8",
    "lavender": "#b4befe",
    "muted":    "#585b70",
}

VALID_SOURCE_TYPES = frozenset({
    "ctx_session",
    "git_output",
    "codex_review",
    "mongodb_pipeline",
    "test_log",
    "explicit_author",
})


def validate_spec(spec: dict) -> None:
    """Validate provenance fields. Raises ValueError on violation.

    Every non-blank line must have source_type from VALID_SOURCE_TYPES.
    Every screenshot must have image_type.
    """
    for shot in spec.get("screenshots", []):
        filename = shot.get("filename", "unknown")
        if "image_type" not in shot:
            raise ValueError(
                f"Screenshot '{filename}' missing required field 'image_type'. "
                f"Use 'reconstructed_terminal_summary'."
            )
        for i, line in enumerate(shot.get("lines", [])):
            if not line.get("text"):
                continue
            if "source_type" not in line:
                raise ValueError(
                    f"Screenshot '{filename}' line {i} (text='{line.get('text', '')[:40]}') "
                    f"missing 'source_type'. Valid: {sorted(VALID_SOURCE_TYPES)}"
                )
            if line["source_type"] not in VALID_SOURCE_TYPES:
                raise ValueError(
                    f"Screenshot '{filename}' line {i} has unknown source_type "
                    f"'{line['source_type']}'. Valid: {sorted(VALID_SOURCE_TYPES)}"
                )

W = 860
PAD = 24
LINE_H = 20
FONT_SZ = 13


def load_font(size: int = FONT_SZ) -> ImageFont.FreeTypeFont:
    candidates = [
        "C:/Windows/Fonts/Consolas.ttf",
        "C:/Windows/Fonts/cour.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationMono-Regular.ttf",
    ]
    for path in candidates:
        try:
            return ImageFont.truetype(path, size)
        except Exception:
            pass
    return ImageFont.load_default()


def char_width(font) -> int:
    try:
        bb = font.getbbox("M")
        return max(bb[2] - bb[0], 1)
    except Exception:
        return 8


def expand_lines(lines_spec: list[dict], max_chars: int) -> list[tuple[str, str]]:
    """Wrap long lines; continued lines use muted color."""
    out: list[tuple[str, str]] = []
    for item in lines_spec:
        text = item.get("text", "")
        color = PALETTE.get(item.get("color", "text"), PALETTE["text"])
        if not text:
            out.append(("", ""))
            continue
        wrapped = textwrap.wrap(text, max_chars) or [""]
        for i, wl in enumerate(wrapped):
            out.append((wl, color if i == 0 else PALETTE["muted"]))
    return out


def make_image(title: str, lines_spec: list[dict]) -> Image.Image:
    font = load_font()
    cw = char_width(font)
    max_chars = (W - PAD * 2) // cw

    rows = expand_lines(lines_spec, max_chars)
    total_h = len(rows) * LINE_H + PAD * 2 + 36

    img = Image.new("RGB", (W, total_h), PALETTE["bg"])
    d = ImageDraw.Draw(img)

    # Title bar
    d.rectangle([0, 0, W, 35], fill=PALETTE["titlebar"])
    for i, c in enumerate([PALETTE["btclose"], PALETTE["btmin"], PALETTE["btmax"]]):
        cx = 18 + i * 22
        d.ellipse([cx - 6, 11, cx + 6, 23], fill=c)
    try:
        tw = d.textlength(title, font=font)
    except Exception:
        tw = len(title) * cw
    d.text(((W - tw) / 2, 10), title, font=font, fill=PALETTE["text"])

    y = 36 + PAD
    for text, color in rows:
        if text and color:
            d.text((PAD, y), text, font=font, fill=color)
        y += LINE_H

    d.rectangle([0, 0, W - 1, total_h - 1], outline=PALETTE["border"])
    return img


def run(spec_path: str, out_dir: str | None = None) -> list[str]:
    with open(spec_path, encoding="utf-8") as f:
        spec = json.load(f)

    validate_spec(spec)

    slug = spec.get("slug", "sprint")
    repo_root = Path(__file__).parent.parent
    if out_dir:
        dest = Path(out_dir)
    else:
        dest = repo_root / "output" / "screenshots" / slug

    dest.mkdir(parents=True, exist_ok=True)

    saved: list[str] = []
    for shot in spec.get("screenshots", []):
        filename = shot.get("filename", f"screenshot-{len(saved)+1}.png")
        title = shot.get("title", "bash")
        lines = shot.get("lines", [])

        img = make_image(title, lines)
        path = dest / filename
        img.save(str(path))
        print(f"  saved: {path}")
        saved.append(str(path))

    return saved


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Generate terminal-style PNG screenshots.")
    parser.add_argument("spec", help="Path to JSON spec file")
    parser.add_argument("--out", default=None, help="Output directory (default: output/screenshots/<slug>)")
    args = parser.parse_args()

    print(f"\nGenerating screenshots from: {args.spec}")
    paths = run(args.spec, args.out)
    print(f"\n{len(paths)} screenshot(s) saved.")
    for p in paths:
        print(f"  {p}")
