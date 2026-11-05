#!/usr/bin/env python3
"""Generate the flick brand SVGs into .github/brand/ (stdlib only).

    python3 media/brand.py            # writes wordmark-*, flick-mark-*, social.svg
    python3 media/brand.py --sub tui  # same, social card subtitled for a sibling repo

Everything is drawn from the design tokens in docs/CONTRACTS.md: a 5x7
dot-matrix FLICK_, the pivot letter (L, the ORP of a five-letter word) in the
one accent, reader guide rails with accent notches above and below the pivot,
and a blinking accent cursor. No fonts are embedded in the marks, so they look
identical everywhere; the social card uses the monospace stack for its copy
and is meant to be rasterised (see docs/media.md). Spec: docs/brand.md.
"""
from __future__ import annotations

import argparse
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / ".github" / "brand"

# warm neutrals + the `paper` accent (CONTRACTS.md -> Design tokens)
LIGHT = {"ink": "#1A1512", "dim": "#8C8378", "line": "#E7E1D6", "accent": "#D8342B", "bg": "#F5F2EA"}
DARK = {"ink": "#F2EDE5", "dim": "#807769", "line": "#241F18", "accent": "#F53B30", "bg": "#0C0A08"}
MONO = "ui-monospace, 'JetBrains Mono', 'Cascadia Mono', 'SF Mono', Menlo, Consolas, monospace"

GLYPHS = {
    "F": ["11111", "10000", "10000", "11110", "10000", "10000", "10000"],
    "L": ["10000", "10000", "10000", "10000", "10000", "10000", "11111"],
    "I": ["01110", "00100", "00100", "00100", "00100", "00100", "01110"],
    "C": ["01110", "10001", "10000", "10000", "10000", "10001", "01110"],
    "K": ["10001", "10010", "10100", "11000", "10100", "10010", "10001"],
    "_": ["00000", "00000", "00000", "00000", "00000", "00000", "11111"],
}
WORD = "FLICK_"
PIVOT = 1  # ORP of a 5-letter word is its 2nd letter (CONTRACTS.md -> ORP rule)
CURSOR = 5

BLINK = (
    "<style>.cur{animation:blink 1.06s steps(1) infinite}"
    "@keyframes blink{50%{opacity:0}}"
    "@media (prefers-reduced-motion: reduce){.cur{animation:none}}</style>"
)


def f(n: float) -> str:
    return f"{n:.2f}".rstrip("0").rstrip(".")


def dots(x0: float, y0: float, pitch: float, r: float, pal: dict) -> tuple[str, float]:
    """Dot-matrix FLICK_; returns (svg fragment, x of the pivot letter's centre)."""
    groups = []
    for i, ch in enumerate(WORD):
        colour = pal["accent"] if i in (PIVOT, CURSOR) else pal["ink"]
        cls = ' class="cur"' if i == CURSOR else ""
        circles = []
        for row, bits in enumerate(GLYPHS[ch]):
            for col, bit in enumerate(bits):
                if bit == "1":
                    cx = x0 + (i * 6 + col) * pitch + pitch / 2
                    cy = y0 + row * pitch + pitch / 2
                    circles.append(f'<circle cx="{f(cx)}" cy="{f(cy)}" r="{f(r)}"/>')
        groups.append(f'<g fill="{colour}"{cls}>{"".join(circles)}</g>')
    pivot_x = x0 + (PIVOT * 6 + 2) * pitch + pitch / 2
    return "".join(groups), pivot_x


def rails(x1: float, x2: float, top: float, bottom: float, px: float, notch: float, w: float, pal: dict) -> str:
    """Reader guide rails (hairlines) with accent notches pointing at the pivot."""
    return (
        f'<g fill="{pal["dim"]}" opacity=".6">'
        f'<rect x="{f(x1)}" y="{f(top)}" width="{f(x2 - x1)}" height="{f(w / 2)}"/>'
        f'<rect x="{f(x1)}" y="{f(bottom)}" width="{f(x2 - x1)}" height="{f(w / 2)}"/></g>'
        f'<g fill="{pal["accent"]}">'
        f'<rect x="{f(px - w / 2)}" y="{f(top - notch / 2)}" width="{f(w)}" height="{f(notch)}"/>'
        f'<rect x="{f(px - w / 2)}" y="{f(bottom - notch / 2)}" width="{f(w)}" height="{f(notch)}"/></g>'
    )


def wordmark(pal: dict) -> str:
    pitch, r, pad = 8, 3.1, 4
    w, h = pad * 2 + 35 * pitch, 100
    body, px = dots(pad, 22, pitch, r, pal)
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" width="{w}" height="{h}" '
        f'role="img" aria-label="flick">{BLINK}'
        f'{rails(pad, w - pad, 6, 94, px, 10, 2, pal)}{body}</svg>\n'
    )


def mark(pal: dict) -> str:
    # "· · | · ·" on the reader stage: a word, its pivot, the two notches.
    ink, acc = pal["ink"], pal["accent"]
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32" width="32" height="32" '
        'role="img" aria-label="flick">'
        f'<g fill="{ink}"><rect x="1" y="3" width="30" height="1.5"/><rect x="1" y="27.5" width="30" height="1.5"/>'
        '<circle cx="4.5" cy="19" r="2"/><circle cx="10" cy="19" r="2"/>'
        '<circle cx="22" cy="19" r="2"/><circle cx="27.5" cy="19" r="2"/></g>'
        f'<g fill="{acc}"><rect x="15" y="0" width="2" height="7"/><rect x="15" y="25" width="2" height="7"/>'
        '<rect x="14" y="9" width="4" height="12"/></g></svg>\n'
    )


def social(sub: str) -> str:
    pal = DARK
    W, H = 1280, 640
    pitch, r = 22, 8.4
    x0 = (W - 35 * pitch) / 2
    body, px = dots(x0, 183, pitch, r, pal)
    name = "flick" + (f"-{sub}" if sub else "")
    tag = {
        "": "self-hosted RSVP speed reading — PDFs, EPUBs, your read-later pile",
        "backend": "the reading engine + API server — Rust, one SQLite file",
        "web": "the reference web client — Svelte 5, guest-first",
        "admin": "the operator panel — analytics, users, announcements",
        "tui": "RSVP speed reading in your terminal — one word at a time",
    }.get(sub, "part of flick — self-hosted RSVP speed reading")
    label = lambda x, y, s, fill, anchor="start", size=18, extra="": (  # noqa: E731
        f'<text x="{x}" y="{y}" fill="{fill}" font-family="{MONO}" font-size="{size}" '
        f'text-anchor="{anchor}" letter-spacing="{size * 0.18:.1f}"{extra}>{s}</text>'
    )
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}" '
        f'role="img" aria-label="{name} — read it in a flick">'
        '<defs><pattern id="grid" width="18" height="18" patternUnits="userSpaceOnUse">'
        f'<circle cx="9" cy="9" r="1" fill="{pal["ink"]}" opacity=".05"/></pattern></defs>'
        f'<rect width="{W}" height="{H}" fill="{pal["bg"]}"/><rect width="{W}" height="{H}" fill="url(#grid)"/>'
        f'<rect x="40" y="40" width="{W - 80}" height="{H - 80}" fill="none" stroke="{pal["line"]}" stroke-width="2"/>'
        + label(80, 100, "ONE WORD AT A TIME", pal["dim"])
        + label(W - 80, 100, f'<tspan fill="{pal["accent"]}">0350</tspan> WPM', pal["dim"], "end")
        + rails(80, W - 80, 140, 380, px, 22, 4, pal)
        + body
        + label(W / 2, 452, "read it in a flick", pal["ink"], "middle", 40, ' font-weight="700"')
        + label(W / 2, 498, tag, pal["dim"], "middle", 20)
        + label(80, 560, "myflick.app", pal["accent"], "start", 20)
        + label(W - 80, 560, f"{name} · AGPL-3.0 · one more", pal["dim"], "end", 20)
        + "</svg>\n"
    )


def main() -> None:
    ap = argparse.ArgumentParser(description="Generate the flick brand SVGs.")
    ap.add_argument("--sub", default="", help="sibling repo suffix for the social card (backend, web, admin, tui)")
    ap.add_argument("--out", type=Path, default=OUT)
    a = ap.parse_args()
    a.out.mkdir(parents=True, exist_ok=True)
    files = {
        "wordmark-light.svg": wordmark(LIGHT),
        "wordmark-dark.svg": wordmark(DARK),
        "flick-mark-light.svg": mark(LIGHT),
        "flick-mark-dark.svg": mark(DARK),
        "social.svg": social(a.sub),
    }
    for name, svg in files.items():
        (a.out / name).write_text(svg, encoding="utf-8")
        print(f"wrote {a.out / name}")


if __name__ == "__main__":
    main()
