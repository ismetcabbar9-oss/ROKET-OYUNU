#!/usr/bin/env python3
"""Fırlatma rampası seslerini Kenney CC0 paketlerinden ve prosedürel sentezden üretir.

Kullanım: python3 tools/make_launch_sfx.py <kenney_sci-fi-sounds/Audio> <kenney_impact-sounds/Audio> assets/audio/sfx
- launch_alarm.ogg      : iki tonlu uyarı kornası (prosedürel)
- hydraulic_loop.ogg    : hidrolik pompa uğultusu, kusursuz döngü (spaceEngineLow_000 + prosedürel vınlama)
- lock_clunk.ogg        : kilit pimi oturması (impactMetal_heavy_000 + impactPlate_heavy_001)
- hatch_open.ogg        : silo kapağı açılması (doorOpen_001 yavaşlatıldı + gövde gümlemesi)
- cold_launch_pof.ogg   : soğuk fırlatma "pof"u (lowFrequency_explosion_001 + gaz tıslaması)
- ignition_roar.ogg     : ateşleme çatlaması + gürleme (thrusterFire_002 + explosionCrunch_000)
(ffmpeg ve numpy gerektirir)
"""
import subprocess
import sys
from pathlib import Path

import numpy as np

RATE = 44100
RNG = np.random.default_rng(20261020)


def decode(path: Path) -> np.ndarray:
    raw = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", str(path), "-f", "f32le", "-ac", "1", "-ar", str(RATE), "-"],
        check=True, capture_output=True,
    ).stdout
    return np.frombuffer(raw, np.float32).copy()


def encode(samples: np.ndarray, path: Path, peak_level: float = 0.89) -> None:
    peak = float(np.max(np.abs(samples))) or 1.0
    data = (samples / peak * peak_level).astype(np.float32).tobytes()
    subprocess.run(
        ["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ac", "1", "-ar", str(RATE), "-i", "-",
         "-c:a", "libvorbis", "-q:a", "5", str(path)],
        input=data, check=True,
    )


def seconds(t: float) -> int:
    return int(t * RATE)


def lowpass(x: np.ndarray, cutoff: float) -> np.ndarray:
    """Tek kutuplu alçak geçiren süzgeç (iki kez uygulanır: 12 dB/oktav)."""
    a = np.exp(-2.0 * np.pi * cutoff / RATE)
    for _ in range(2):
        y = np.empty_like(x)
        acc = 0.0
        for i, v in enumerate(x):
            acc = (1.0 - a) * v + a * acc
            y[i] = acc
        x = y
    return x


def resample(x: np.ndarray, speed: float) -> np.ndarray:
    """Perdeyi ve süreyi birlikte değiştirir (speed < 1 = daha kalın ve uzun)."""
    n = int(len(x) / speed)
    return np.interp(np.arange(n) * speed, np.arange(len(x)), x).astype(np.float32)


def envelope(n: int, attack: float, release: float) -> np.ndarray:
    env = np.ones(n, np.float32)
    a, r = min(seconds(attack), n), min(seconds(release), n)
    if a:
        env[:a] = np.linspace(0.0, 1.0, a)
    if r:
        env[n - r:] *= np.linspace(1.0, 0.0, r)
    return env


def mix(*layers: tuple[np.ndarray, float, float]) -> np.ndarray:
    """(örnekler, başlangıç_sn, kazanç) katmanlarını toplar."""
    length = max(seconds(start) + len(s) for s, start, _ in layers)
    out = np.zeros(length, np.float32)
    for s, start, gain in layers:
        i = seconds(start)
        out[i:i + len(s)] += s * gain
    return out


def make_loop(x: np.ndarray, fade_s: float) -> np.ndarray:
    fade = seconds(fade_s)
    loop = x[: len(x) - fade].copy()
    t = np.linspace(0.0, 1.0, fade, dtype=np.float32)
    loop[:fade] = x[:fade] * t + x[len(x) - fade:] * (1.0 - t)
    return loop


def alarm() -> np.ndarray:
    # Üç kez yükselip alçalan iki tonlu korna; kare dalga + harmonik yumuşatma
    out = []
    for _ in range(3):
        for freq, dur in ((660.0, 0.36), (520.0, 0.36)):
            t = np.arange(seconds(dur)) / RATE
            tone = np.sign(np.sin(2 * np.pi * freq * t)) * 0.5 + np.sin(2 * np.pi * freq * 2 * t) * 0.2
            out.append((tone * envelope(len(t), 0.01, 0.03)).astype(np.float32))
        out.append(np.zeros(seconds(0.12), np.float32))
    return lowpass(np.concatenate(out), 3200.0)


def hydraulic(sci: Path) -> np.ndarray:
    engine = resample(decode(sci / "spaceEngineLow_000.ogg"), 0.8)
    t = np.arange(len(engine)) / RATE
    # Pompa vınlaması: hafif titreyen 180 Hz + 360 Hz
    whine = (np.sin(2 * np.pi * (180 * t + 2 * np.sin(2 * np.pi * 3 * t))) * 0.25
             + np.sin(2 * np.pi * 360 * t) * 0.08).astype(np.float32)
    hiss = lowpass(RNG.standard_normal(len(engine)).astype(np.float32), 1800.0) * 0.15
    return make_loop(lowpass(engine, 900.0) + whine + hiss, 0.5)


def clunk(imp: Path) -> np.ndarray:
    metal = resample(decode(imp / "impactMetal_heavy_000.ogg"), 0.75)
    plate = resample(decode(imp / "impactPlate_heavy_001.ogg"), 0.6)
    return mix((metal, 0.0, 1.0), (plate, 0.015, 0.8))


def hatch(sci: Path, imp: Path) -> np.ndarray:
    door = resample(decode(sci / "doorOpen_001.ogg"), 0.35)
    thud = resample(decode(imp / "impactPlate_heavy_001.ogg"), 0.5)
    grind = lowpass(RNG.standard_normal(len(door)).astype(np.float32), 500.0) * envelope(len(door), 0.2, 0.3) * 0.6
    return mix((door, 0.0, 1.0), (grind, 0.0, 1.0), (thud, len(door) / RATE - 0.1, 1.2))


def pof(sci: Path) -> np.ndarray:
    boom = lowpass(resample(decode(sci / "lowFrequency_explosion_001.ogg"), 0.7), 700.0)
    n = seconds(1.8)
    hiss = RNG.standard_normal(n).astype(np.float32)
    hiss = (hiss - lowpass(hiss, 1500.0)) * np.exp(-np.arange(n) / RATE * 2.2).astype(np.float32) * 0.35
    return mix((boom, 0.0, 1.0), (hiss, 0.02, 1.0))


def roar(sci: Path) -> np.ndarray:
    thruster = resample(decode(sci / "thrusterFire_002.ogg"), 0.8)
    thruster *= envelope(len(thruster), 0.05, 1.5)
    crack = decode(sci / "explosionCrunch_000.ogg")
    rumble = lowpass(resample(decode(sci / "lowFrequency_explosion_000.ogg"), 0.8), 400.0)
    return mix((thruster, 0.0, 1.0), (crack, 0.0, 0.9), (rumble, 0.0, 1.1))


def main() -> None:
    sci, imp, out = Path(sys.argv[1]), Path(sys.argv[2]), Path(sys.argv[3])
    out.mkdir(parents=True, exist_ok=True)
    encode(alarm(), out / "launch_alarm.ogg", 0.6)
    encode(hydraulic(sci), out / "hydraulic_loop.ogg", 0.7)
    encode(clunk(imp), out / "lock_clunk.ogg")
    encode(hatch(sci, imp), out / "hatch_open.ogg")
    encode(pof(sci), out / "cold_launch_pof.ogg")
    encode(roar(sci), out / "ignition_roar.ogg")
    print("Sesler üretildi:", out)


if __name__ == "__main__":
    main()
