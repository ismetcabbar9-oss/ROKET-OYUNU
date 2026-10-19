#!/usr/bin/env python3
"""Sketchfab varlık arama/indirme aracı.

Anahtar SKETCHFAB_API_TOKEN ortam değişkeninden ya da proje kökündeki .env
dosyasından okunur; hiçbir dosyaya yazılmaz, ekrana basılmaz.
Yalnızca indirilebilir ve CC0 / CC-BY lisanslı modeller kabul edilir.

Kullanım:
  python3 tools/sketchfab_fetch.py search "cruise missile" [--count 24]
  python3 tools/sketchfab_fetch.py info <uid>
  python3 tools/sketchfab_fetch.py download <uid> <isim>
      -> tools/downloads/<isim>/ altına glTF açar (git dışı) ve atıf bilgisini
         source.json'a yazar (ASSETS.md'ye işlenmek üzere).
"""
from __future__ import annotations

import io
import json
import os
import sys
import urllib.parse
import urllib.request
import zipfile
from pathlib import Path

API = "https://api.sketchfab.com/v3"
ROOT = Path(__file__).resolve().parent.parent
DOWNLOADS = ROOT / "tools" / "downloads"
ALLOWED_LICENSES = {"cc0": "CC0 1.0", "by": "CC-BY 4.0"}


def _token() -> str:
    token = os.environ.get("SKETCHFAB_API_TOKEN", "").strip()
    env_file = ROOT / ".env"
    if not token and env_file.exists():
        for line in env_file.read_text(encoding="utf-8").splitlines():
            key, _, value = line.partition("=")
            if key.strip() == "SKETCHFAB_API_TOKEN":
                token = value.strip().strip('"').strip("'")
    if not token:
        sys.exit("SKETCHFAB_API_TOKEN bulunamadı (.env veya ortam değişkeni).")
    return token


def _get_json(url: str, auth: bool = False) -> dict:
    req = urllib.request.Request(url)
    if auth:
        req.add_header("Authorization", f"Token {_token()}")
    with urllib.request.urlopen(req, timeout=60) as resp:
        return json.load(resp)


def license_slug(model: dict) -> str:
    lic = model.get("license") or {}
    label = (lic.get("label") or lic.get("slug") or "").lower()
    if "cc0" in label or "public domain" in label:
        return "cc0"
    # Yalnızca saf CC-BY; NonCommercial / NoDerivs / ShareAlike varyantları reddedilir.
    if label in ("cc attribution", "by"):
        return "by"
    return label


def cmd_search(query: str, count: int = 24) -> None:
    for lic in ALLOWED_LICENSES:
        params = urllib.parse.urlencode(
            {"type": "models", "downloadable": "true", "license": lic, "q": query, "count": count}
        )
        data = _get_json(f"{API}/search?{params}")
        for m in data.get("results", []):
            print(f"{m['uid']} | {lic:3} | faces={m.get('faceCount')} | likes={m.get('likeCount')} | {m['name']} | {m['user']['username']}")


def cmd_info(uid: str) -> dict:
    model = _get_json(f"{API}/models/{uid}")
    print(json.dumps(
        {
            "name": model["name"],
            "author": model["user"]["displayName"],
            "profile": model["user"]["profileUrl"],
            "url": model["viewerUrl"],
            "license": (model.get("license") or {}).get("label"),
            "downloadable": model.get("isDownloadable"),
            "faces": model.get("faceCount"),
            "vertices": model.get("vertexCount"),
        },
        ensure_ascii=False,
        indent=2,
    ))
    return model


def cmd_download(uid: str, name: str) -> None:
    model = _get_json(f"{API}/models/{uid}")
    slug = license_slug(model)
    if slug not in ALLOWED_LICENSES:
        sys.exit(f"Reddedildi: lisans '{(model.get('license') or {}).get('label')}' CC0/CC-BY değil.")
    if not model.get("isDownloadable"):
        sys.exit("Reddedildi: model indirilebilir değil.")

    links = _get_json(f"{API}/models/{uid}/download", auth=True)
    gltf = links.get("gltf")
    if not gltf:
        sys.exit(f"glTF arşivi yok: {list(links)}")
    with urllib.request.urlopen(gltf["url"], timeout=300) as resp:
        payload = resp.read()

    dest = DOWNLOADS / name
    dest.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(io.BytesIO(payload)) as archive:
        for member in archive.namelist():
            target = (dest / member).resolve()
            if not str(target).startswith(str(dest.resolve())):
                sys.exit(f"Güvensiz arşiv yolu: {member}")
        archive.extractall(dest)

    meta = {
        "uid": uid,
        "name": model["name"],
        "author": model["user"]["displayName"],
        "author_url": model["user"]["profileUrl"],
        "url": model["viewerUrl"],
        "license": ALLOWED_LICENSES[slug],
    }
    (dest / "source.json").write_text(json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"İndirildi: {dest} ({len(payload) // 1024} KB) — {meta['name']} / {meta['author']} / {meta['license']}")


def main() -> None:
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    cmd = sys.argv[1]
    if cmd == "search":
        count = int(sys.argv[4]) if len(sys.argv) > 4 and sys.argv[3] == "--count" else 24
        cmd_search(sys.argv[2], count)
    elif cmd == "info":
        cmd_info(sys.argv[2])
    elif cmd == "download" and len(sys.argv) >= 4:
        cmd_download(sys.argv[2], sys.argv[3])
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
