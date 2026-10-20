#!/usr/bin/env python3
"""tools/make_sound_assets.py'nin kullandığı kaynak kayıtları indirir.

Sonniss #GameAudioGDC paketlerinin archive.org yansısındaki zip'lerden yalnızca gereken dosyalar
çekilir (archive.org zip içinden tek dosya verir; paketin tamamı onlarca GB'dir).
Kullanım: python3 tools/fetch_sonniss.py <hedef_klasör>
"""
import json
import subprocess
import sys
import urllib.parse
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from make_sound_assets import SOURCES  # noqa: E402

ITEM = "sonniss.com-gdc-game-audio-bundles"
KENNEY = "https://kenney.nl/media/pages/assets/impact-sounds/87b4ddecda-1677589768/kenney_impact-sounds.zip"


def listing() -> dict[str, str]:
    """Paketteki tüm ses dosyaları: kütüphane/dosya -> indirme adresi."""
    meta = subprocess.run(["curl", "-sSL", f"https://archive.org/metadata/{ITEM}"], capture_output=True, check=True).stdout
    zips = [f["name"] for f in json.loads(meta)["files"] if f["name"].endswith(".zip")]
    found: dict[str, str] = {}
    for z in zips:
        html = subprocess.run(["curl", "-sSL", f"https://archive.org/download/{ITEM}/{urllib.parse.quote(z)}/"],
                              capture_output=True).stdout.decode(errors="ignore")
        for part in html.split('href="')[1:]:
            href = part.split('"', 1)[0]
            if ".zip/" not in href or "__MACOSX" in href:
                continue
            inner = urllib.parse.unquote(href.split(".zip/", 1)[1])
            key = "/".join(inner.split("/")[-2:])
            found.setdefault(key, "https:" + href if href.startswith("//") else href)
    return found


def main() -> None:
    out = Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    files = listing()
    for short, (library, name) in SOURCES.items():
        if library.startswith("Kenney"):
            continue
        url = files.get(f"{library}/{name}")
        if url is None:
            sys.exit(f"Bulunamadı: {library}/{name}")
        subprocess.run(["curl", "-sSL", "-o", str(out / f"{short}.wav"), url], check=True)
        print("indirildi:", short)
    subprocess.run(["curl", "-sSL", "-o", str(out / "kenney_impact.zip"), KENNEY], check=True)
    subprocess.run(["unzip", "-o", "-j", "-q", str(out / "kenney_impact.zip"), "Audio/impactGeneric_light_001.ogg", "-d", str(out)], check=True)


if __name__ == "__main__":
    main()
