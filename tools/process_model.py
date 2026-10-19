#!/usr/bin/env python3
"""İndirilen bir glTF modelini mobil için hazırlayıp assets/ altına kopyalar.

- Dokuları en fazla --max-texture pikselde (varsayılan 1024) yeniden boyutlar.
- Opak renk dokularını JPEG'e çevirir (depo boyutu); normal/metal-pürüz PNG kalır.
- source.json'daki atıf bilgisini ATTRIBUTION.txt olarak yanına yazar.

Kullanım:
  python3 tools/process_model.py <tools/downloads/isim> <assets/models/hedef> [--max-texture 1024]
"""
from __future__ import annotations

import json
import shutil
import sys
from pathlib import Path

from PIL import Image


def _convert_texture(src: Path, dst_dir: Path, max_size: int, to_jpeg: bool) -> str:
    img = Image.open(src)
    if max(img.size) > max_size:
        scale = max_size / max(img.size)
        img = img.resize((max(1, round(img.width * scale)), max(1, round(img.height * scale))), Image.LANCZOS)
    has_alpha = img.mode in ("RGBA", "LA") and img.getchannel("A").getextrema()[0] < 255
    if to_jpeg and not has_alpha:
        name = src.stem + ".jpg"
        img.convert("RGB").save(dst_dir / name, quality=90, optimize=True)
    else:
        name = src.stem + ".png"
        img.save(dst_dir / name, optimize=True)
    return name


def process(src_dir: Path, dst_dir: Path, max_size: int) -> None:
    gltf_path = src_dir / "scene.gltf"
    gltf = json.loads(gltf_path.read_text(encoding="utf-8"))
    dst_dir.mkdir(parents=True, exist_ok=True)
    (dst_dir / "textures").mkdir(exist_ok=True)

    # Hangi görüntü hangi amaçla kullanılıyor? (renk dokuları JPEG olabilir)
    color_images: set[int] = set()
    for mat in gltf.get("materials", []):
        pbr = mat.get("pbrMetallicRoughness", {})
        for key in ("baseColorTexture",):
            if key in pbr:
                color_images.add(gltf["textures"][pbr[key]["index"]]["source"])
        if "emissiveTexture" in mat:
            color_images.add(gltf["textures"][mat["emissiveTexture"]["index"]]["source"])

    for index, image in enumerate(gltf.get("images", [])):
        src = src_dir / image["uri"]
        new_name = _convert_texture(src, dst_dir / "textures", max_size, index in color_images)
        image["uri"] = f"textures/{new_name}"
        image.pop("mimeType", None)

    for buffer in gltf.get("buffers", []):
        shutil.copy2(src_dir / buffer["uri"], dst_dir / buffer["uri"])

    (dst_dir / "model.gltf").write_text(json.dumps(gltf, indent=1), encoding="utf-8")

    meta = json.loads((src_dir / "source.json").read_text(encoding="utf-8"))
    (dst_dir / "ATTRIBUTION.txt").write_text(
        f"\"{meta['name']}\" by {meta['author']} ({meta['author_url']})\n"
        f"Source: {meta['url']}\nLicense: {meta['license']}\n"
        f"Changes: textures resized to <= {max_size}px for mobile.\n",
        encoding="utf-8",
    )
    total = sum(f.stat().st_size for f in dst_dir.rglob("*") if f.is_file())
    print(f"{dst_dir}: {total // 1024} KB")


def main() -> None:
    args = sys.argv[1:]
    max_size = 1024
    if "--max-texture" in args:
        i = args.index("--max-texture")
        max_size = int(args[i + 1])
        del args[i : i + 2]
    if len(args) != 2:
        sys.exit(__doc__)
    process(Path(args[0]), Path(args[1]), max_size)


if __name__ == "__main__":
    main()
