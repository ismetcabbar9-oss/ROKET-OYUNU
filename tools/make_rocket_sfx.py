#!/usr/bin/env python3
"""Roket sesleri v2: katmanlı motor, hava sürtünmesi, ortam ve uzak patlama seslerini üretir.

Kullanım: python3 tools/make_rocket_sfx.py <kenney_sci-fi-sounds/Audio> <kenney_impact-sounds/Audio> assets/audio/sfx
Kaynaklar Kenney Sci-Fi Sounds 1.0 ve Impact Sounds 1.0 (CC0); geri kalanı prosedürel.
Döngüler FFT ile süzülmüş gürültüden üretilir: dairesel süzgeç sayesinde baş ve son kusursuz birleşir.
- motor_booster_loop.ogg   : booster gürlemesi (thrusterFire_000 + spaceEngineLarge_001 + kalın gürültü)
- motor_sustainer_loop.ogg : sustainer tıslaması (thrusterFire_003 + parlak gürültü)
- ignition_crack.ogg       : ateşleme çatlaması (explosionCrunch_002 + kıvılcım çıtırtıları)
- burnout_sputter.ogg      : yakıt bitişi: kesik kesik sönen motor (prosedürel)
- air_rush_loop.ogg        : hıza bağlı hava sürtünmesi (prosedürel)
- desert_wind_loop.ogg     : çöl rüzgârı, yavaş esintilerle (prosedürel)
- base_hum_loop.ogg        : üs jeneratör uğultusu (spaceEngineLow_002 + 50 Hz harmonikler)
- explosion_far.ogg        : uzak patlama: boğuk gümleme ve uzun yankı kuyruğu
- ui_click.ogg             : arayüz tıklaması (impactGeneric_light_001, kısaltılmış)
(ffmpeg ve numpy gerektirir)
"""
import subprocess
import sys
from pathlib import Path

import numpy as np

RATE = 44100
RNG = np.random.default_rng(20261021)


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


def n_of(seconds: float) -> int:
    return int(seconds * RATE)


def band(x: np.ndarray, low: float, high: float, slope: float = 1.0) -> np.ndarray:
    """FFT ile bant geçiren süzgeç (dairesel: döngüler için kusursuz). slope<1 yumuşak kenar."""
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1.0 / RATE)
    gain = np.ones_like(f)
    if low > 0:
        gain *= 1.0 / (1.0 + (low / np.maximum(f, 1.0)) ** (4 * slope))
    if high > 0:
        gain *= 1.0 / (1.0 + (f / high) ** (4 * slope))
    return np.fft.irfft(spec * gain, len(x)).astype(np.float32)


def noise(seconds: float) -> np.ndarray:
    return RNG.standard_normal(n_of(seconds)).astype(np.float32)


def periodic_lfo(n: int, cycles: int, phase: float = 0.0) -> np.ndarray:
    """Döngü boyunca tam sayıda tur atan yavaş salınım (0..1)."""
    t = np.arange(n) / n
    return (0.5 + 0.5 * np.sin(2 * np.pi * cycles * t + phase)).astype(np.float32)


def fit(x: np.ndarray, n: int) -> np.ndarray:
    """Kaynağı n örneğe döngüsel olarak tamamlar (çapraz geçişli)."""
    if len(x) >= n:
        return x[:n].copy()
    out = np.zeros(n, np.float32)
    fade = min(n_of(0.3), len(x) // 3)
    pos = 0
    ramp = np.linspace(0.0, 1.0, fade, dtype=np.float32)
    while pos < n:
        seg = x.copy()
        if pos > 0:
            seg[:fade] *= ramp
        if pos + len(seg) < n:
            seg[-fade:] *= ramp[::-1]
        end = min(pos + len(seg), n)
        out[pos:end] += seg[: end - pos]
        pos += len(seg) - fade
    return out


def make_loop(x: np.ndarray, fade_s: float) -> np.ndarray:
    fade = n_of(fade_s)
    loop = x[: len(x) - fade].copy()
    t = np.linspace(0.0, 1.0, fade, dtype=np.float32)
    loop[:fade] = x[:fade] * t + x[len(x) - fade:] * (1.0 - t)
    return loop


def resample(x: np.ndarray, speed: float) -> np.ndarray:
    n = int(len(x) / speed)
    return np.interp(np.arange(n) * speed, np.arange(len(x)), x).astype(np.float32)


def env(n: int, attack: float, release: float) -> np.ndarray:
    e = np.ones(n, np.float32)
    a, r = min(n_of(attack), n), min(n_of(release), n)
    if a:
        e[:a] = np.linspace(0.0, 1.0, a)
    if r:
        e[n - r:] *= np.linspace(1.0, 0.0, r)
    return e


def norm(x: np.ndarray) -> np.ndarray:
    return x / (float(np.max(np.abs(x))) or 1.0)


def booster(sci: Path) -> np.ndarray:
    n = n_of(4.0)
    thr = norm(fit(make_loop(decode(sci / "thrusterFire_000.ogg"), 0.6), n))
    eng = norm(fit(make_loop(resample(decode(sci / "spaceEngineLarge_001.ogg"), 0.7), 0.6), n))
    rumble = norm(band(noise(4.0), 30.0, 260.0)) * (0.75 + 0.25 * periodic_lfo(n, 7))
    crackle = norm(band(noise(4.0), 1500.0, 7000.0)) * (RNG.random(n) > 0.985).astype(np.float32)
    mix = thr * 0.8 + eng * 0.45 + rumble * 0.9 + band(crackle, 800.0, 9000.0) * 0.5
    return make_loop(mix, 0.25)


def sustainer(sci: Path) -> np.ndarray:
    n = n_of(4.0)
    thr = norm(fit(make_loop(resample(decode(sci / "thrusterFire_003.ogg"), 1.15), 0.6), n))
    hiss = norm(band(noise(4.0), 700.0, 3800.0, 0.7)) * (0.85 + 0.15 * periodic_lfo(n, 11))
    body = norm(band(noise(4.0), 90.0, 600.0))
    return make_loop(band(thr, 0.0, 5000.0) * 0.7 + hiss * 0.3 + body * 0.55, 0.25)


def ignition_crack(sci: Path) -> np.ndarray:
    crunch = decode(sci / "explosionCrunch_002.ogg")
    n = n_of(1.2)
    sparks = band(noise(1.2), 2500.0, 10000.0) * (RNG.random(n) > 0.992).astype(np.float32) * 6.0
    sparks *= np.exp(-np.arange(n) / RATE * 4.0).astype(np.float32)
    burst = band(noise(1.2), 200.0, 3000.0) * np.exp(-np.arange(n) / RATE * 9.0).astype(np.float32)
    out = np.zeros(max(len(crunch), n), np.float32)
    out[: len(crunch)] += norm(crunch)
    out[:n] += norm(burst) * 0.8 + sparks
    return out


def burnout() -> np.ndarray:
    # Sönen motor: giderek seyrekleşen ve zayıflayan öksürük patlamaları + tıslama
    total = n_of(1.8)
    out = np.zeros(total, np.float32)
    t = 0.0
    gap = 0.05
    level = 1.0
    while t < 1.4:
        n = n_of(0.07)
        pop = band(noise(0.07), 80.0, 1200.0) * np.exp(-np.arange(n) / RATE * 45.0).astype(np.float32)
        i = n_of(t)
        out[i:i + n] += norm(pop)[: max(0, min(n, total - i))] * level
        t += gap * (0.7 + 0.6 * RNG.random())
        gap *= 1.35
        level *= 0.8
    hiss = band(noise(1.8), 1500.0, 7000.0) * env(total, 0.01, 1.2) * np.exp(-np.arange(total) / RATE * 1.5).astype(np.float32)
    return out + norm(hiss) * 0.35


def air_rush() -> np.ndarray:
    n = n_of(5.0)
    rush = norm(band(noise(5.0), 250.0, 1800.0, 0.6))
    flutter = 0.8 + 0.2 * periodic_lfo(n, 13) * periodic_lfo(n, 5, 1.3)
    whistle = norm(band(noise(5.0), 2400.0, 3200.0, 2.0)) * 0.25
    return rush * flutter + whistle


def desert_wind() -> np.ndarray:
    n = n_of(16.0)
    low = norm(band(noise(16.0), 60.0, 500.0, 0.6))
    high = norm(band(noise(16.0), 600.0, 3000.0, 0.6))
    gust = 0.35 + 0.65 * (periodic_lfo(n, 3) * 0.6 + periodic_lfo(n, 5, 2.0) * 0.4)
    return low * (0.6 + 0.4 * gust) + high * gust * gust * 0.5


def base_hum(sci: Path) -> np.ndarray:
    n = n_of(6.0)
    eng = norm(fit(make_loop(resample(decode(sci / "spaceEngineLow_002.ogg"), 0.6), 0.6), n))
    t = np.arange(n) / RATE
    # 6 s'de tam sayıda periyot: 50 Hz ve harmonikleri kusursuz döner
    tone = sum(np.sin(2 * np.pi * 50.0 * k * t) / k for k in (1, 2, 3, 5)).astype(np.float32)
    rattle = norm(band(noise(6.0), 300.0, 1200.0)) * 0.15
    return make_loop(norm(band(eng, 40.0, 900.0)) * 0.6 + norm(tone) * 0.35 + rattle, 0.2)


def explosion_far(sci: Path) -> np.ndarray:
    boom = resample(decode(sci / "lowFrequency_explosion_000.ogg"), 0.7)
    n = n_of(4.5)
    out = np.zeros(n, np.float32)
    out[: len(boom)] += norm(band(boom, 0.0, 500.0))
    # Vadi duvarlarından dönen yankılar: gecikmiş, giderek boğuklaşan kopyalar
    for delay, gain, cut in ((0.35, 0.45, 400.0), (0.8, 0.3, 300.0), (1.4, 0.18, 220.0)):
        i = n_of(delay)
        echo = band(boom, 0.0, cut)
        m = min(len(echo), n - i)
        out[i:i + m] += norm(echo)[:m] * gain
    tail = band(noise(4.5), 25.0, 160.0) * np.exp(-np.arange(n) / RATE * 1.1).astype(np.float32)
    return out + norm(tail) * 0.35


def ui_click(imp: Path) -> np.ndarray:
    click = decode(imp / "impactGeneric_light_001.ogg")[: n_of(0.12)]
    return click * env(len(click), 0.0, 0.05)


def main() -> None:
    sci, imp, out = Path(sys.argv[1]), Path(sys.argv[2]), Path(sys.argv[3])
    out.mkdir(parents=True, exist_ok=True)
    encode(booster(sci), out / "motor_booster_loop.ogg")
    encode(sustainer(sci), out / "motor_sustainer_loop.ogg")
    encode(ignition_crack(sci), out / "ignition_crack.ogg")
    encode(burnout(), out / "burnout_sputter.ogg")
    encode(air_rush(), out / "air_rush_loop.ogg", 0.7)
    encode(desert_wind(), out / "desert_wind_loop.ogg", 0.6)
    encode(base_hum(sci), out / "base_hum_loop.ogg", 0.6)
    encode(explosion_far(sci), out / "explosion_far.ogg")
    encode(ui_click(imp), out / "ui_click.ogg", 0.6)
    print("Sesler üretildi:", out)


if __name__ == "__main__":
    main()
