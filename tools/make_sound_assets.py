#!/usr/bin/env python3
"""Oyun seslerini gerçek kayıtlardan hazırlar: kesme, döngüleme (çapraz geçiş), katmanlama,
seviye eşitleme. Ses SENTEZLENMEZ; tüm kaynaklar kayıttır.

Kaynaklar: Sonniss #GameAudioGDC paketleri (telifsiz, ticari kullanım serbest, atıf gerekmez;
lisans: assets/licenses/sonniss_gdc_license.pdf) ve arayüz tıklaması için Kenney Impact Sounds (CC0).
Kaynak dosyaların tam listesi ve kütüphaneleri: ASSETS.md.

Kullanım:
  python3 tools/make_sound_assets.py <kaynak_klasörü> assets/audio/sfx
Kaynak klasöründe aşağıdaki SOURCES sözlüğündeki kısa adlarla .wav dosyaları bulunmalıdır
(tools/fetch_sonniss.py indirir).
(ffmpeg ve numpy gerektirir)
"""
import subprocess
import sys
from pathlib import Path

import numpy as np

RATE = 44100

# Kısa ad -> (Sonniss kütüphanesi, dosya adı)
SOURCES = {
    "fa18kill": ("Airborne Sound - Attack Aircraft Maneuvers", "Jet,Fighter,FA-18C,Hornet,Medium Distant,Climb,Right to High,Crest and Hold,Kill Engine,191.wav"),
    "f22": ("Airborne Sound - Variety 1 Sound Effects", "Jet,Fighter,F-22,Raptor,By,Slow,Crackle.wav"),
    "cf18rip": ("Airborne Sound - Jet Fighter Maneuvers", "Jet,Fighter,CF-18,Hornet,By,Slow,Rip to Whistle.wav"),
    "rpg": ("Pole Position - The Warfare 2 Library", "RPG - FIRING AND IMPACT - Through Car Roof Hit Metal - XY - MKH8040.wav"),
    "fwlaunch": ("InspectorJ - Essentials 03 Fireworks", "FRWKComr_InsJ_Fireworks_Launch_Close_01-03.wav"),
    "steam": ("Airborne Sound - Variety 1 Sound Effects", "Steam Blast,Tube or Pipe,Distant.wav"),
    "bz_mortar": ("BluezoneCorp - Detonation - Explosion", "Bluezone_BC0277_explosion_mortar_002_01.wav"),
    "bz_large": ("Bluezone - Tank - Explosion Sound Effects", "Bluezone_BC0271_explosion_outdoors_large_005.wav"),
    "sc_deep": ("Stefano Cremona - Explosions", "DeepExplosion02.wav"),
    "sc_far": ("Stefano Cremona - Explosions", "FarExplosion03.wav"),
    "tankmine": ("Pole Position - The Warfare 2 Library", "Tank Mine - EXPLOSION - Mounted on Metal Beam - DISTANT - AMBEO BLD.wav"),
    "wind_desert": ("Soundrangers - Wind", "wind_desert_01_60_loop.wav"),
    "hum_ac": ("Articulated Sounds - 100 Fans, HVAC, & Mechanical Drones", "FAN Outdoor AC Unit, Constant Blow Drone Noise, LOOP.wav"),
    "hyd_robot": ("Pole Position - Hydraulics & Pneumatics Library", "Robot_1_axle_1_speed_-1_MKH8060.wav"),
    "hyd_m6": ("Pole Position - Hydraulics & Pneumatics Library", "Machine_6_mono_06.wav"),
    "baydoor": ("Bottle Rocket Fx - Cyborg Collection", "Spacecraft_Bay Door_Lock Down_Large_01.wav"),
    "alarm_large": ("David Dumais Audio - Alarms Sound Fx Pack 1", "LargeAlarm5.2_Single_Slow_DDM_Loop.wav"),
    "kenney_click": ("Kenney - Impact Sounds (CC0)", "impactGeneric_light_001.ogg"),
}


def decode(path: Path, channels: int = 1) -> np.ndarray:
    raw = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", str(path), "-f", "f32le", "-ac", str(channels), "-ar", str(RATE), "-"],
        check=True, capture_output=True,
    ).stdout
    x = np.frombuffer(raw, np.float32).copy()
    return x.reshape(-1, channels) if channels > 1 else x


def encode(x: np.ndarray, path: Path, peak: float = 0.89, quality: int = 5) -> None:
    channels = 1 if x.ndim == 1 else x.shape[1]
    m = float(np.max(np.abs(x))) or 1.0
    data = (x / m * peak).astype(np.float32).tobytes()
    subprocess.run(
        ["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ac", str(channels), "-ar", str(RATE), "-i", "-",
         "-c:a", "libvorbis", "-q:a", str(quality), str(path)],
        input=data, check=True,
    )


def cut(x: np.ndarray, start: float, end: float) -> np.ndarray:
    return x[int(start * RATE):int(end * RATE)].copy()


def fade(x: np.ndarray, fade_in: float = 0.005, fade_out: float = 0.05) -> np.ndarray:
    x = x.copy()
    a, b = int(fade_in * RATE), int(fade_out * RATE)
    shape = (-1,) + (1,) * (x.ndim - 1)
    if a:
        x[:a] *= np.linspace(0.0, 1.0, a, dtype=np.float32).reshape(shape)
    if b:
        x[-b:] *= np.linspace(1.0, 0.0, b, dtype=np.float32).reshape(shape)
    return x


def loop(x: np.ndarray, crossfade: float) -> np.ndarray:
    """Sonu başa eşit güçte çapraz geçişle bindirir: kesintisiz döngü."""
    n = int(crossfade * RATE)
    t = np.linspace(0.0, 1.0, n, dtype=np.float32)
    shape = (-1,) + (1,) * (x.ndim - 1)
    out = x[: len(x) - n].copy()
    out[:n] = x[:n] * np.sqrt(t).reshape(shape) + x[len(x) - n:] * np.sqrt(1.0 - t).reshape(shape)
    return out


def norm(x: np.ndarray) -> np.ndarray:
    return x / (float(np.max(np.abs(x))) or 1.0)


def rms_norm(x: np.ndarray) -> np.ndarray:
    return x / (float(np.sqrt(np.mean(x ** 2))) or 1.0)


def lowpass(x: np.ndarray, cutoff: float) -> np.ndarray:
    """Kayıt üzerinde ton düzeltmesi (EQ): FFT ile yumuşak alçak geçiren."""
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1.0 / RATE)
    return np.fft.irfft(spec / (1.0 + (f / cutoff) ** 4), len(x)).astype(np.float32)


def resample(x: np.ndarray, speed: float) -> np.ndarray:
    n = int(len(x) / speed)
    return np.interp(np.arange(n) * speed, np.arange(len(x)), x).astype(np.float32)


def layer(*parts: tuple[np.ndarray, float, float]) -> np.ndarray:
    """(örnekler, başlangıç_sn, kazanç)"""
    n = max(int(s * RATE) + len(x) for x, s, _ in parts)
    out = np.zeros(n, np.float32)
    for x, s, g in parts:
        i = int(s * RATE)
        out[i:i + len(x)] += x * g
    return out


def build(src: Path, out: Path) -> None:
    w = {k: src / f"{k}.wav" for k in SOURCES if k != "kenney_click"}
    mono = {k: decode(p) for k, p in w.items() if k != "wind_desert"}

    # Motor: F/A-18 sabit tırmanış (booster), F-22 çıtırtılı art yakıcı (sustainer)
    encode(loop(cut(mono["fa18kill"], 6.0, 11.2), 0.4), out / "motor_booster_loop.ogg")
    encode(loop(cut(mono["f22"], 10.4, 14.2), 0.4), out / "motor_sustainer_loop.ogg")
    # Yakıt bitişi: F/A-18 motor kapatma anı
    encode(fade(cut(mono["fa18kill"], 17.6, 21.6), 0.02, 1.5), out / "burnout_sputter.ogg")
    # Hava sürtünmesi: CF-18 geçişinin ıslıklı yırtılma bölümü
    encode(loop(cut(mono["cf18rip"], 6.8, 10.8), 0.5), out / "air_rush_loop.ogg", 0.75)

    # Ateşleme çatlaması: RPG atışının ilk anı; rampa gürlemesi: RPG + havai fişek fırlatması
    rpg = cut(mono["rpg"], 0.2, 3.6)
    encode(fade(cut(mono["rpg"], 0.2, 1.3), 0.002, 0.4), out / "ignition_crack.ogg")
    encode(fade(layer((norm(rpg), 0.0, 1.0), (norm(mono["fwlaunch"]), 0.05, 0.8),
                      (norm(cut(mono["fa18kill"], 6.0, 10.0)) * np.linspace(1, 0, int(4.0 * RATE), dtype=np.float32), 0.15, 0.6)),
                0.002, 1.0), out / "ignition_roar.ogg")
    # Soğuk fırlatma: havan gümlemesi (boğuk) + buhar patlaması tıslaması
    pof = layer((lowpass(norm(mono["bz_mortar"]), 700.0), 0.0, 1.0),
                (fade(cut(mono["steam"], 0.25, 2.2), 0.01, 1.2), 0.02, 0.55))
    encode(fade(pof, 0.002, 0.5), out / "cold_launch_pof.ogg")

    # Patlamalar: yakın (Bluezone büyük açık alan + Stefano Cremona derin katman), uzak
    near = layer((norm(mono["bz_large"]), 0.0, 1.0), (lowpass(norm(mono["sc_deep"]), 400.0), 0.0, 0.6))
    encode(fade(cut(near, 0.0, 4.5), 0.002, 1.0), out / "explosion_large.ogg")
    far = layer((norm(mono["sc_far"]), 0.0, 1.0), (norm(cut(mono["tankmine"], 0.0, 6.0)), 0.0, 0.5))
    encode(fade(cut(far, 0.0, 5.0), 0.002, 1.5), out / "explosion_far.ogg")

    # Rampa mekanizması
    encode(loop(cut(mono["hyd_robot"], 7.1, 10.5), 0.3), out / "hydraulic_loop.ogg", 0.8)
    encode(fade(cut(mono["baydoor"], 0.1, 1.3), 0.002, 0.5), out / "lock_clunk.ogg")
    hatch = layer((fade(cut(mono["hyd_m6"], 0.3, 2.4), 0.05, 0.4), 0.0, 0.8),
                  (fade(cut(mono["baydoor"], 1.3, 3.8), 0.002, 1.0), 1.7, 1.0))
    encode(hatch, out / "hatch_open.ogg")
    alarm = cut(mono["alarm_large"], 0.0, 1.0)
    encode(fade(np.concatenate([alarm, alarm, alarm]), 0.002, 0.15), out / "launch_alarm.ogg", 0.6)

    # Ortam: çöl rüzgârı (kütüphanenin kendi 60 sn döngüsü, stereo), üs uğultusu (konumlu, mono)
    encode(decode(w["wind_desert"], 2), out / "desert_wind_loop.ogg", 0.6, 4)
    encode(loop(cut(mono["hum_ac"], 10.0, 22.0), 0.6), out / "base_hum_loop.ogg", 0.6)

    # Arayüz tıklaması (Kenney CC0)
    click = decode(src / "impactGeneric_light_001.ogg")
    encode(fade(click[: int(0.12 * RATE)], 0.0, 0.05), out / "ui_click.ogg", 0.6)
    print("Sesler hazırlandı:", out)


if __name__ == "__main__":
    build(Path(sys.argv[1]), Path(sys.argv[2]))
