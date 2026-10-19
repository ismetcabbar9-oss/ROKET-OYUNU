#!/usr/bin/env python3
"""Kenney Sci-Fi Sounds (CC0) kaynaklarından oyun seslerini üretir.

Kullanım: python3 tools/make_sfx.py <kenney_sci-fi-sounds/Audio> assets/audio/sfx
- rocket_motor_loop.ogg : thrusterFire_000, çapraz geçişle kusursuz döngü
- explosion_large.ogg   : lowFrequency_explosion_000 + explosionCrunch_004 katmanı
(ffmpeg gerektirir)
"""
import subprocess
import sys
from pathlib import Path

import numpy as np

RATE = 44100


def decode(path: Path) -> np.ndarray:
    raw = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", str(path), "-f", "f32le", "-ac", "1", "-ar", str(RATE), "-"],
        check=True, capture_output=True,
    ).stdout
    return np.frombuffer(raw, np.float32).copy()


def encode(samples: np.ndarray, path: Path) -> None:
    peak = float(np.max(np.abs(samples))) or 1.0
    data = (samples / peak * 0.89).astype(np.float32).tobytes()
    subprocess.run(
        ["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ac", "1", "-ar", str(RATE), "-i", "-",
         "-c:a", "libvorbis", "-q:a", "5", str(path)],
        input=data, check=True,
    )


def main() -> None:
    src, out = Path(sys.argv[1]), Path(sys.argv[2])
    out.mkdir(parents=True, exist_ok=True)

    motor = decode(src / "thrusterFire_000.ogg")
    fade = int(0.6 * RATE)
    loop = motor[: len(motor) - fade].copy()
    t = np.linspace(0.0, 1.0, fade, dtype=np.float32)
    loop[:fade] = motor[:fade] * t + motor[len(motor) - fade:] * (1.0 - t)
    encode(loop, out / "rocket_motor_loop.ogg")

    boom = decode(src / "lowFrequency_explosion_000.ogg")
    crunch = decode(src / "explosionCrunch_004.ogg")
    length = max(len(boom), len(crunch))
    mix = np.zeros(length, np.float32)
    mix[: len(boom)] += boom * 1.0
    mix[: len(crunch)] += crunch * 0.7
    encode(mix, out / "explosion_large.ogg")
    print("üretildi:", sorted(p.name for p in out.glob("*.ogg")))


if __name__ == "__main__":
    main()
