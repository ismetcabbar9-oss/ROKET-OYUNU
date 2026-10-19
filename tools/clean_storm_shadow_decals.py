#!/usr/bin/env python3
"""Storm Shadow dokusundaki ulusal işaret/yazı çıkartmalarını siler (inpaint).

Kullanım: python3 tools/clean_storm_shadow_decals.py <girdi_baseColor> <çıktı>
Bölgeler 1024x1024 UV koordinatlarında verilir, dokunun boyutuna göre ölçeklenir.
"""
import sys

import cv2
import numpy as np

# (x0, y0, x1, y1) — 1024 uzayında çıkartma bölgeleri
REGIONS = [(105, 445, 695, 565), (250, 675, 640, 795)]


def main() -> None:
    src, dst = sys.argv[1], sys.argv[2]
    img = cv2.imread(src, cv2.IMREAD_COLOR)
    h, w = img.shape[:2]
    s = w / 1024.0
    mask = np.zeros((h, w), np.uint8)
    for x0, y0, x1, y1 in REGIONS:
        x0, y0, x1, y1 = (int(v * s) for v in (x0, y0, x1, y1))
        patch = img[y0:y1, x0:x1].astype(np.int32)
        background = np.median(patch.reshape(-1, 3), axis=0)
        diff = np.abs(patch - background).sum(axis=2)
        mask[y0:y1, x0:x1] = (diff > 45).astype(np.uint8) * 255
    mask = cv2.dilate(mask, np.ones((int(9 * s), int(9 * s)), np.uint8))
    out = cv2.inpaint(img, mask, int(6 * s), cv2.INPAINT_TELEA)
    cv2.imwrite(dst, out)
    print(f"temizlendi: {int(mask.sum() / 255)} piksel")


if __name__ == "__main__":
    main()
