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
    "rcjet1": ("Pole Position - RC Jet", "RC_Jet_Viggen_AJ36_t1_Ext_Start_Ignition_Idle_Blast_Static_on_Ground_Off_Bursts_Right_DPA4062.wav"),
    "pulsejet": ("Pole Position - The Pulse Jet Snowmobile", "Pulse Jet Snowmobile, t2, Ext, By, Distant, Holophone.wav"),
    "gripen": ("Double Trouble Audio - Tanks and Jet", "TAJ - Jas Gripen Repeated Flyover [XY Stereo]-005.wav"),
    "ct114": ("Airborne Sound - Attack Aircraft Maneuvers", "Jet,Fighter,CT-114,Tutor,Snowbird,Squad,Medium Distant,Climb,Starburst,Big,Slow,191.wav"),
    "airliner": ("Pole Position - The Aircraft Ambient Library", "Jet - Airliner - Fly - By - Overhead - Distant - Some Leaves and Wind - CMC6.wav"),
    "f16contact": ("Sound Ex Machina - F16 Maneuvers", "F-16 pass by (Contact mic, ORTF) 03.wav"),
    "f16over": ("Sound Ex Machina - F16 Maneuvers", "F-16 Jet Fighter passing by overhead and vanishing into the horizon 03.wav"),
    "how_c1": ("Airborne Sound - Battlefield Howitzers", "Howitzer,M101,C1,105 mm,Distant,Right Side,Shot,Pound,Thick.wav"),
    "how_c3": ("Airborne Sound - Battlefield Howitzers", "Howitzer,M101,C3,105 mm,Distant,Right Side,Shot,Explode,Crack,Sweetener.wav"),
    "og_expl8": ("Olivier Girardot - Guns & Explosions", "Explosion 8.wav"),
    "og_quake": ("Olivier Girardot - Guns & Explosions", "Earthquake 3 - Big.wav"),
    "bz_urban": ("BluezoneCorp - Detonation - Explosion", "Bluezone_BC0277_explosion_urban_004_02.wav"),
    "bz_drone": ("BluezoneCorp - Combat Drone", "Bluezone_BC0288_combat_drone_weapon_explosion_004.wav"),
    "bz_quake": ("BluezoneCorp - Alien Tripod", "Bluezone_BC0292_alien_tripod_debris_rock_collapse_earthquake_rumble_large_005.wav"),
    "dd_nuke": ("DavidDumais - Explosion SFX Pack", "EXPLDsgn_Nuclear Explosion 07_DDUMAIS_NONE.wav"),
    "sc_big": ("Stefano Cremona - Explosions", "BigExplosion02.wav"),
    "ca_mortar": ("Coll Anderson - Guns", "EFX EXT Mortar Explosion 08.wav"),
    "kenney_click": ("Kenney - Impact Sounds (CC0)", "impactGeneric_light_001.ogg"),
}

# Füze başına motor ve patlama. Motor: (kaynak, başlangıç_sn, bitiş_sn), döngülenir.
# Patlama katmanları: [(kaynak, başlangıç, bitiş, kazanç, alçak_geçiren_Hz | 0), ...]
MISSILES = {
    "sahin": {"booster": ("rcjet1", 56.5, 62.5), "sustainer": ("rcjet1", 30.0, 36.0),
              "near": [("bz_mortar", 0.0, 2.6, 1.0, 0)], "far": [("how_c3", 0.0, 2.8, 1.0, 0)]},
    "kartal": {"booster": ("f16contact", 21.5, 25.5), "sustainer": ("airliner", 19.0, 27.0),
               "near": [("og_expl8", 0.0, 7.5, 1.0, 0)], "far": [("how_c1", 0.0, 4.4, 1.0, 0)]},
    "yildirim": {"booster": ("fa18kill", 6.0, 11.2), "sustainer": ("f22", 10.4, 14.2),
                 "near": [("bz_large", 0.0, 3.5, 1.0, 0), ("sc_deep", 0.0, 4.5, 0.6, 400)],
                 "far": [("sc_far", 0.0, 3.5, 1.0, 0), ("tankmine", 0.0, 5.0, 0.5, 0)]},
    "mizrak": {"booster": ("ct114", 10.5, 14.5), "sustainer": ("pulsejet", 40.0, 46.0),
               "near": [("bz_urban", 0.0, 4.0, 1.0, 0)], "far": [("tankmine", 0.0, 6.0, 1.0, 0)]},
    "tufan": {"booster": ("f16contact", 41.0, 46.0), "sustainer": ("f16over", 10.0, 17.0),
              "near": [("dd_nuke", 0.0, 9.0, 1.0, 0), ("sc_big", 0.0, 6.0, 0.6, 300)],
              "far": [("og_quake", 1.0, 11.0, 1.0, 0), ("bz_quake", 0.0, 5.7, 0.6, 0)]},
    "simsek": {"booster": ("f16over", 2.5, 5.5), "sustainer": ("cf18rip", 10.0, 13.5),
               "near": [("sc_big", 0.0, 6.0, 1.0, 0)], "far": [("sc_big", 0.0, 7.0, 1.0, 450)]},
    "dogan": {"booster": ("gripen", 12.5, 16.5), "sustainer": ("gripen", 22.0, 27.0),
              "near": [("bz_drone", 0.0, 2.8, 1.0, 0)], "far": [("ca_mortar", 0.2, 2.4, 1.0, 600)]},
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

    # Füze başına motor döngüleri ve yakın/uzak patlamalar
    (out / "missiles").mkdir(exist_ok=True)
    for name, spec in MISSILES.items():
        for part in ("booster", "sustainer"):
            key, t0, t1 = spec[part]
            encode(loop(cut(mono[key], t0, t1), 0.4), out / "missiles" / f"{name}_{part}.ogg")
        for dist in ("near", "far"):
            layers = []
            for key, t0, t1, gain, cutoff in spec[dist]:
                x = norm(cut(mono[key], t0, t1))
                layers.append((lowpass(x, cutoff) if cutoff else x, 0.0, gain))
            encode(fade(layer(*layers), 0.002, 1.2), out / "missiles" / f"{name}_explosion_{dist}.ogg")
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
