#!/usr/bin/env python3
"""Dokulardaki ulusal işaretleri ve gerçek silah adı yazılarını siler (inpaint).

Oyunda gerçek marka, ulusal işaret ve silah isimleri kullanılmaz (docs/PLAN.md). Bölgeler kaynak
dokunun piksel koordinatlarıdır; bölge içinde arka plandan belirgin ayrılan pikseller maskelenir ve
çevreden doldurulur. Normal ve metal-pürüz haritaları da aynı maskeyle düzleştirilir (kabartma izi kalmasın).

Kullanım: python3 tools/clean_decals.py <model_klasörü>
Temizlenecek dokular aşağıdaki JOBS tablosundadır (indirilen model klasörü adına göre).
"""
import sys
from pathlib import Path

import cv2
import numpy as np

# klasör -> [(renk dokusu, [ (x0, y0, x1, y1), ... ]), ...]
JOBS = {
    "neptune": [("textures/Rocket_baseColor.png", [(1660, 260, 2640, 1290)])],
    "fattah": [("textures/default_baseColor.png", [(1700, 3520, 2620, 3780), (1780, 3930, 2060, 3990), (1340, 3890, 1790, 4096)])],
    "kh38": [("textures/1db0a800-e29e-4773-98f3-76ff6773b53f_baseColor.jpeg", [(625, 715, 750, 752), (622, 908, 742, 945)])],
}
THRESHOLD = 40


def clean(model_dir: Path) -> None:
    for texture, regions in JOBS[model_dir.name]:
        path = model_dir / texture
        img = cv2.imread(str(path), cv2.IMREAD_COLOR)
        mask = np.zeros(img.shape[:2], np.uint8)
        for x0, y0, x1, y1 in regions:
            patch = img[y0:y1, x0:x1].astype(np.int32)
            background = np.median(patch.reshape(-1, 3), axis=0)
            diff = np.abs(patch - background).sum(axis=2)
            mask[y0:y1, x0:x1] = (diff > THRESHOLD).astype(np.uint8) * 255
        grow = max(3, img.shape[1] // 512)
        mask = cv2.dilate(mask, np.ones((grow * 2 + 1, grow * 2 + 1), np.uint8))
        cv2.imwrite(str(path), cv2.inpaint(img, mask, grow * 2, cv2.INPAINT_TELEA))
        # Aynı malzemenin normal / metal-pürüz haritalarında kabartma izini de düzleştir
        for suffix in ("normal", "metallicRoughness"):
            for other in path.parent.glob(path.stem.replace("baseColor", suffix) + ".*"):
                aux = cv2.imread(str(other), cv2.IMREAD_COLOR)
                if aux is not None and aux.shape[:2] == img.shape[:2]:
                    cv2.imwrite(str(other), cv2.inpaint(aux, mask, grow * 2, cv2.INPAINT_TELEA))
        print(f"{texture}: {int(mask.sum() / 255)} piksel temizlendi")


if __name__ == "__main__":
    clean(Path(sys.argv[1]))
