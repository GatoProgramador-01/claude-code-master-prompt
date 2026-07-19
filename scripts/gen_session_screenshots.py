#!/usr/bin/env python3
"""Universal session screenshot generator for Claude Code sprints.

Usage:
    python scripts/gen_session_screenshots.py <spec.json>

Saves PNGs to ~/.ctx/screenshots/<slug>/ and writes manifest.json.
Requires: pip install Pillow
"""
from __future__ import annotations

import io
import json
import pathlib
import subprocess
import sys
from datetime import datetime, timezone
from typing import Any

from PIL import Image, ImageDraw, ImageFont

_COLORS: dict[str, tuple[int, int, int]] = {
    "bg":       (30,  30,  46),
    "titlebar": (24,  24,  37),
    "text":     (205, 214, 244),
    "white":    (255, 255, 255),
    "cyan":     (137, 220, 235),
    "blue":     (137, 180, 250),
    "green":    (166, 227, 161),
    "yellow":   (249, 226, 175),
    "red":      (243, 139, 168),
    "lavender": (180, 190, 254),
    "muted":    (88,  91,  112),
}

_FONT_PATHS = [
    r"C:\Windows\Fonts\consolas.ttf",
    r"C:\Windows\Fonts\consola.ttf",
    "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf",
    "/System/Library/Fonts/Supplemental/Courier New.ttf",
]


def _load_font(size: int) -> Any:
    for p in _FONT_PATHS:
        if pathlib.Path(p).exists():
            try:
                return ImageFont.truetype(p, size)
            except Exception:
                pass
    return ImageFont.load_default()


def _heuristic_color(line: str) -> str:
    lower = line.lower()
    if line.startswith("PS ") or line.startswith("$ ") or line.startswith("C:\\"):
        return "muted"
    if ("passed" in lower or "success" in lower or "ok" in lower) and "failed" not in lower:
        return "green"
    if "failed" in lower or "error" in lower or "exception" in lower:
        return "red"
    if "warning" in lower:
        return "yellow"
    return "text"


def _run_command(entry: dict[str, Any]) -> list[tuple[str, str]]:
    args: list[str] = entry["args"]
    cwd: str | None = entry.get("cwd")
    max_lines: int = entry.get("max_lines", 50)
    timeout: int = entry.get("timeout", 30)
    try:
        proc = subprocess.run(
            args,
            cwd=cwd,
            capture_output=True,
            text=True,
            timeout=timeout,
        )
        raw = (proc.stdout + proc.stderr).rstrip()
        lines = raw.splitlines()[:max_lines]
    except subprocess.TimeoutExpired:
        lines = [f"[command timed out after {timeout}s: {' '.join(args)}]"]
    except FileNotFoundError as exc:
        lines = [f"[command not found: {exc}]"]
    except Exception as exc:
        lines = [f"[command failed: {exc}]"]
    return [(line, _heuristic_color(line)) for line in lines]


def _manual_lines(entry: dict[str, Any]) -> list[tuple[str, str]]:
    return [(ln["text"], ln.get("color", "text")) for ln in entry.get("lines", [])]


def _render_png(lines: list[tuple[str, str]], title: str, width: int = 860) -> bytes:
    font_size = 18
    line_h = font_size + 8
    title_bar_h = 50
    pad_x = 30
    pad_y = 20
    height = max(title_bar_h + pad_y + len(lines) * line_h + pad_y, 200)

    img = Image.new("RGB", (width, height), _COLORS["bg"])
    draw = ImageDraw.Draw(img)

    draw.rectangle([0, 0, width, title_bar_h], fill=_COLORS["titlebar"])
    for i, rgb in enumerate([(255, 95, 86), (255, 189, 46), (39, 201, 63)]):
        bx = 20 + i * 20
        draw.ellipse([bx - 6, title_bar_h // 2 - 6, bx + 6, title_bar_h // 2 + 6], fill=rgb)

    title_font = _load_font(14)
    body_font = _load_font(font_size)
    draw.text((80, title_bar_h // 2 - 8), title, fill=_COLORS["muted"], font=title_font)

    y = title_bar_h + pad_y
    for text, color_key in lines:
        rgb = _COLORS.get(color_key, _COLORS["text"])
        draw.text((pad_x, y), text, fill=rgb, font=body_font)
        y += line_h

    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return buf.getvalue()


def main() -> None:
    if len(sys.argv) < 2:
        print("Usage: gen_session_screenshots.py <spec.json>", file=sys.stderr)
        sys.exit(1)

    spec_path = pathlib.Path(sys.argv[1])
    if not spec_path.exists():
        print(f"Spec file not found: {spec_path}", file=sys.stderr)
        sys.exit(1)

    spec: dict[str, Any] = json.loads(spec_path.read_text(encoding="utf-8"))
    slug: str = spec["slug"]
    project: str = spec.get("project", "")

    out_dir = pathlib.Path.home() / ".ctx" / "screenshots" / slug
    out_dir.mkdir(parents=True, exist_ok=True)

    manifest_paths: list[dict[str, Any]] = []

    for entry in spec.get("screenshots", []):
        filename: str = entry["filename"]
        title: str = entry.get("title", "bash")
        entry_type: str = entry.get("type", "manual")

        lines = _run_command(entry) if entry_type == "command" else _manual_lines(entry)

        png_bytes = _render_png(lines, title)
        out_path = out_dir / filename
        out_path.write_bytes(png_bytes)
        print(f"  wrote {out_path}")

        manifest_paths.append({
            "filename": filename,
            "path": str(out_path),
            "alt": entry.get("alt", ""),
            "caption": entry.get("caption", ""),
        })

    manifest: dict[str, Any] = {
        "slug": slug,
        "created_at": datetime.now(timezone.utc).isoformat(),
        "project": project,
        "paths": manifest_paths,
    }
    manifest_path = out_dir / "manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print(f"  manifest -> {manifest_path}")
    print(f"\nDone. {len(manifest_paths)} screenshot(s) in {out_dir}")
    print(f"\nTo use with medium-agent-factory:")
    print(f"  python -m app.cli --topic '...' --ctx-screenshots {slug}")


if __name__ == "__main__":
    main()
