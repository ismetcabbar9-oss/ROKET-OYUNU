#!/usr/bin/env python3
"""Efekt dokularını prosedürel olarak üretir (projeye özgü, lisans gerektirmez).

Kullanım: python3 tools/generate_fx_textures.py assets/textures/fx
Çıktılar: smoke_puff.png, fire_puff.png, glow_dot.png, scorch.png
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
    print("üretildi:", sorted(p.name for p in out.glob("*.png")))


if __name__ == "__main__":
    main()
