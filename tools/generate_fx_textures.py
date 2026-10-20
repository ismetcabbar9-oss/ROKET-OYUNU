#!/usr/bin/env python3
"""Efekt dokularını prosedürel olarak üretir (projeye özgü, lisans gerektirmez).

Kullanım: python3 tools/generate_fx_textures.py assets/textures/fx
Çıktılar: smoke_puff.png, fire_puff.png, glow_dot.png, scorch.png, dry_shrub.png
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

SIZE = 128


def fractal_noise(size: int, seed: int, octaves: int = 5) -> np.ndarray:
    rng = np.random.default_rng(seed)
    out = np.zeros((size, size), np.float32)
    amp, total = 1.0, 0.0
    for o in range(octaves):
        cells = 4 * 2**o
        grid = rng.random((cells + 1, cells + 1)).astype(np.float32)
        grid[-1, :] = grid[0, :]
        grid[:, -1] = grid[:, 0]
        img = Image.fromarray((grid * 255).astype(np.uint8)).resize((size, size), Image.BICUBIC)
        out += np.asarray(img, np.float32) / 255.0 * amp
        total += amp
        amp *= 0.5
    return out / total


def radial(size: int) -> np.ndarray:
    y, x = np.mgrid[0:size, 0:size].astype(np.float32)
    c = (size - 1) / 2.0
    return np.sqrt((x - c) ** 2 + (y - c) ** 2) / c


def save_rgba(path: Path, rgb: np.ndarray, alpha: np.ndarray) -> None:
    rgba = np.dstack([np.clip(rgb, 0, 1), np.clip(alpha, 0, 1)])
    Image.fromarray((rgba * 255).astype(np.uint8), "RGBA").save(path, optimize=True)


def dry_shrub(size: int = 256, seed: int = 9) -> Image.Image:
    """Kuru çöl çalısı: tabandan yelpaze gibi açılan ince, gri-kahve dallar ve seyrek, soluk
    gri-yeşil yapraklar; kubbe biçimli ve tuvalin içinde kalır."""
    from PIL import ImageDraw
    rng = np.random.default_rng(seed)
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx, base = size / 2, size - 3

    def inside(x: float, y: float) -> bool:
        # Kubbe: (x, y) tabandaki merkeze göre elips içinde mi?
        return ((x - cx) / (size * 0.47)) ** 2 + ((base - y) / (size * 0.8)) ** 2 <= 1.0

    def branch(x: float, y: float, angle: float, length: float, width: float, depth: int) -> None:
        if depth == 0 or length < 3:
            return
        x2 = x + np.cos(angle) * length
        y2 = y - np.sin(angle) * length
        if not inside(x2, y2):
            return
        # Renkler doğrusal uzayda gerçekçi çöl çalısı yansıtıcılığına (~0.3) denk gelecek kadar açık
        tone = int(rng.integers(105, 130))
        d.line([(x, y), (x2, y2)], fill=(tone + 15, tone + 4, tone - 14, 255), width=max(1, int(round(width))))
        if depth <= 2 and rng.random() < 0.55:
            for _ in range(int(rng.integers(1, 3))):
                lx, ly = x2 + rng.normal(0, 2.5), y2 + rng.normal(0, 2.5)
                g = int(rng.integers(125, 150))
                d.ellipse([lx - 1.6, ly - 1.2, lx + 1.6, ly + 1.2], fill=(g, g + 6, g - 26, 255))
        for _ in range(int(rng.integers(2, 4))):
            branch(x2, y2, angle + rng.normal(0, 0.5), length * rng.uniform(0.62, 0.8), width * 0.72, depth - 1)

    for _ in range(16):
        a = np.pi / 2 + rng.uniform(-1.15, 1.15)
        branch(cx + rng.normal(0, 4), base, a, size * rng.uniform(0.12, 0.17), 3.2, 6)
    return img


def main() -> None:
    out = Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    r = radial(SIZE)

    # Duman: yumuşak kenarlı, içi bulutsu
    n = fractal_noise(SIZE, 1)
    mask = np.clip(1.0 - r, 0, 1) ** 1.4
    alpha = np.clip((n * 1.6 - 0.35) * mask * 1.8, 0, 1)
    shade = 0.75 + 0.25 * fractal_noise(SIZE, 2)
    save_rgba(out / "smoke_puff.png", np.dstack([shade] * 3), alpha)

    # Ateş: daha keskin, sıcak merkez
    n = fractal_noise(SIZE, 3)
    mask = np.clip(1.0 - r * 1.1, 0, 1) ** 1.2
    heat = np.clip(n * 1.4 * mask * 1.6, 0, 1)
    rgb = np.dstack([np.ones_like(heat), 0.35 + 0.6 * heat, 0.1 + 0.6 * heat**2])
    save_rgba(out / "fire_puff.png", rgb, np.clip(heat * 1.5, 0, 1))

    # Parıltı / kıvılcım: yumuşak nokta
    glow = np.clip(1.0 - r, 0, 1) ** 2.2
    save_rgba(out / "glow_dot.png", np.ones((SIZE, SIZE, 3), np.float32), glow)

    # Yanık izi (decal): koyu, düzensiz kenarlı leke
    big = 256
    rb = radial(big)
    n = fractal_noise(big, 4)
    edge = np.clip((1.0 - rb) * 1.5 + (n - 0.5) * 0.9, 0, 1)
    alpha = np.clip(edge * 1.4 - 0.2, 0, 1) ** 1.2
    tone = 0.05 + 0.12 * fractal_noise(big, 5)
    save_rgba(out / "scorch.png", np.dstack([tone, tone * 0.95, tone * 0.9]), alpha * 0.92)
    dry_shrub().save(out / "dry_shrub.png", optimize=True)
    print("üretildi:", sorted(p.name for p in out.glob("*.png")))


if __name__ == "__main__":
    main()
