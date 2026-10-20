# Varlıklar ve Lisanslar

Bu projede yalnızca **CC0** veya **CC-BY 4.0** lisanslı, indirilebilir varlıklar kullanılır.
CC-BY varlıkların atfı oyun içindeki "Krediler" ekranında da gösterilecektir (menü adımı).
Her modelin klasöründe ayrıca `ATTRIBUTION.txt` bulunur.
Oyunda gerçek ürün/silah isimleri ve ulusal işaretler kullanılmaz: füzeler kurgusal isimlerle
(Şahin, Kartal, Yıldırım) gösterilir; aşağıdaki "Varlık" sütunu yalnızca **kaynak modelin** adıdır.

## 3B modeller (Sketchfab, CC-BY 4.0)

| Varlık (kaynak adı → oyundaki adı) | Dosya yolu | Yazar | Kaynak | Lisans | Değişiklik |
|---|---|---|---|---|---|
| Missile FATEH 110 → Yıldırım | `assets/models/missiles/yildirim/` | [Mehdi Shahsavan](https://sketchfab.com/ahmagh2e) | [Sketchfab](https://sketchfab.com/3d-models/missile-fateh-110-5da58f2682aa4d07bd030fc5f77652a0) | CC-BY 4.0 | Dokular 1024 px'e küçültüldü |
| Hasta Missile → Şahin | `assets/models/missiles/sahin/` | [pocolov](https://sketchfab.com/pocolov) | [Sketchfab](https://sketchfab.com/3d-models/hasta-missile-dcc71b2bf0eb4ce78d0815abe14b39ae) | CC-BY 4.0 | Dokular küçültüldü; kapalı-kanat varyantı ve gömülü alev gizlendi |
| Storm Shadow → Kartal | `assets/models/missiles/kartal/` | [Viktor_](https://sketchfab.com/Viktor.Zhuravlev) | [Sketchfab](https://sketchfab.com/3d-models/storm-shadow-ukraine-d1ad04ce964f46dd9cbac6a64cd19b1b) | CC-BY 4.0 | Dokular küçültüldü; ulusal işaret/yazı çıkartmaları silindi |
| Shaanxi SX2190 Missile Launcher | `assets/models/props/launcher_truck/` | [Muhamad Mirza Arrafi](https://sketchfab.com/MirzaArrafiERV_45) | [Sketchfab](https://sketchfab.com/3d-models/shaanxi-sx2190-missile-launcher-a3cb343f3bf8486c8a0482df5b753c38) | CC-BY 4.0 | Dokular küçültüldü; üzerindeki füze gizlendi |
| Bunker | `assets/models/props/bunker/` | [Uragan27](https://sketchfab.com/Uragan27) | [Sketchfab](https://sketchfab.com/3d-models/bunker-e9f9830ac06c4193b79043d9327a7a69) | CC-BY 4.0 | Dokular 1024 px'e küçültüldü |

## Dokular ve gökyüzü (Poly Haven, CC0)

| Varlık | Dosya yolu | Yazar | Kaynak | Lisans |
|---|---|---|---|---|
| Kloofendal 48d Partly Cloudy (Pure Sky) HDRI, 2k | `assets/textures/sky/` | Greg Zaal, Jarod Guest | [Poly Haven](https://polyhaven.com/a/kloofendal_48d_partly_cloudy_puresky) | CC0 |
| Sandy Gravel 02 (1k) | `assets/textures/terrain/sandy_gravel_02_*` | Dario Barresi | [Poly Haven](https://polyhaven.com/a/sandy_gravel_02) | CC0 |
| Dry Ground Rocks (1k) | `assets/textures/terrain/dry_ground_rocks_*` | Rob Tuytel | [Poly Haven](https://polyhaven.com/a/dry_ground_rocks) | CC0 |
| Asphalt 02 (1k) | `assets/textures/surfaces/asphalt_02_*` | Rob Tuytel | [Poly Haven](https://polyhaven.com/a/asphalt_02) | CC0 |
| Concrete Floor 02 (1k) | `assets/textures/surfaces/concrete_floor_02_*` | Rob Tuytel | [Poly Haven](https://polyhaven.com/a/concrete_floor_02) | CC0 |
| Gravel Road (1k) | `assets/textures/surfaces/gravel_road_*` | Amal Kumar | [Poly Haven](https://polyhaven.com/a/gravel_road) | CC0 |
| Cliff Side (1k) | `assets/textures/terrain/cliff_side_*` | James Ray Cock, Jenelle van Heerden, Dario Barresi | [Poly Haven](https://polyhaven.com/a/cliff_side) | CC0 |

## Sesler (Kenney, CC0)

| Varlık | Dosya yolu | Kaynak | Lisans | Değişiklik |
|---|---|---|---|---|
| Sci-Fi Sounds 1.0 — `thrusterFire_000` | `assets/audio/sfx/rocket_motor_loop.ogg` | [kenney.nl](https://kenney.nl/assets/sci-fi-sounds) | CC0 | Kusursuz döngü için çapraz geçiş (`tools/make_sfx.py`) |
| Sci-Fi Sounds 1.0 — `lowFrequency_explosion_000` + `explosionCrunch_004` | `assets/audio/sfx/explosion_large.ogg` | [kenney.nl](https://kenney.nl/assets/sci-fi-sounds) | CC0 | İki ses katmanlandı (`tools/make_sfx.py`) |

## Projeye özgü (üretilmiş) varlıklar

| Varlık | Dosya yolu | Üreten |
|---|---|---|
| Arazi ağları, çarpışma haritası, yol/plaka ağları, ufuk silueti | `assets/terrain/valley_01/` | `tools/godot/generate_terrain.gd` |
| Efekt dokuları (duman, ateş, kıvılcım, yanık izi) | `assets/textures/fx/` | `tools/generate_fx_textures.py` |

## Geliştirme araçları (oyuna dahil edilmez)

| Varlık | Dosya yolu | Lisans |
|---|---|---|
| GUT (Godot Unit Test) 9.7.1 | `addons/gut/` | MIT — Butch Wesley, [GitHub](https://github.com/bitwes/Gut) |
