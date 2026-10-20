# Roket Oyunu

Godot 4.7 ile Android için 3B füze yönlendirme oyunu (prototip). Oyuncu füzeyi fırlatır ve uçuş
boyunca dokunmatik joystick ya da cihazı eğerek (jiroskop) kendisi yönlendirir.

## Tablette çalıştırma
1. Tablete **Godot 4.7.x** editörünü kurun (Play Store veya godotengine.org, standart sürüm).
2. GitHub'da bu dalın sayfasından **Code → Download ZIP** ile projeyi indirip bir klasöre açın.
3. Godot'ta **Import** ile klasördeki `project.godot` dosyasını seçin. İlk açılışta varlıklar içe
   aktarılır (birkaç dakika sürebilir).
4. ▶ (Çalıştır) ile test alanı açılır.

> Proje **Mobile** renderer kullanır (Vulkan). Tablet Vulkan desteklemiyorsa
> Proje Ayarları → Rendering → Renderer → **Compatibility** seçin.

## Test alanı: nasıl oynanır
- Sağdaki listeden füzeyi seçin: **Şahin** (çevik), **Kartal** (dengeli), **Yıldırım** (ağır ve hızlı).
- **FIRLAT** ile fırlatın. Sol yarıda parmağınızı nereye koyarsanız joystick orada açılır.
- Hedef bölgesi kuzeyde, vadinin sonunda (sığınaklar). Yolda vadiyi kesen bir sırt var:
  ya üstünden aşın (hız kaybedersiniz) ya da sağ taraftaki dar **kanyondan** geçin.
- Uçuş sırasında **PATLAT** füzeyi havada imha eder.
- Vadi koridorunun dışına ya da çok yükseğe çıkarsanız **SINIR** uyarısı çıkar; 3 saniyede
  geri dönmezseniz füze kendini imha eder.
- Sağ üstteki **Kontrol** butonu joystick ↔ jiroskop arasında geçiş yapar; jiroskopta
  **Kalibre et** o anki tutuşu "düz uçuş" kabul eder (fırlatırken de otomatik kalibre edilir).
- Masaüstü editörde fare ile dokunma taklit edilir (sürükle = joystick).

## Oyun hissini ayarlama (kod değiştirmeden)
Her füzenin tüm değerleri tek dosyada: `config/missiles/<füze>.tres` (Godot'ta çift tıklayın).
Dönüş hızı, atalet (`turn_response`), sapma/titreşim (`wobble_*`), hız, itki, yakıt, yerçekimi,
kamera uzaklığı ve patlama büyüklüğü buradadır. Arazi biçimi: `config/terrain/valley_01.tres`
(değiştirdikten sonra araziyi yeniden üretin, aşağıya bakın).

## Proje yapısı
| Klasör | İçerik |
|---|---|
| `autoload/` | Global düğümler: `GameState`, `UserSettings` (kontrol modu, hassasiyet, ses) |
| `config/` | Oyun hissi ve bölüm ayarları (`.tres` Resource) |
| `scripts/missile/` | `MissileFlightModel` (saf uçuş fiziği), `Missile`, `MissileDefinition`, egzoz |
| `scripts/input/` | `SteerInput` tabanı, dokunmatik ve jiroskop girdileri |
| `scripts/camera/` | `ChaseCamera` (takip, arazi çarpışması, sarsıntı) |
| `scripts/ui/` | Çoklu dokunmatik joystick/butonlar, HUD |
| `scripts/level/` | Test alanı akışı |
| `scripts/world/` | `TerrainShape` (arazi yükseklik fonksiyonu) |
| `scenes/` | Küçük, modüler sahneler |
| `shaders/` | Arazi ve motor alevi shader'ları |
| `assets/` | Modeller, dokular, sesler, üretilmiş arazi (bkz. `ASSETS.md`) |
| `tests/unit/` | GUT birim testleri |
| `tools/` | Geliştirme araçları (oyuna dahil değil) |

## Geliştirici araçları
```bash
# Birim testleri
godot --headless -s addons/gut/gut_cmdln.gd

# Araziyi yeniden üret (config/terrain/valley_01.tres değiştikten sonra)
godot --headless --path . -s res://tools/godot/generate_terrain.gd -- \
    res://config/terrain/valley_01.tres res://assets/terrain/valley_01 res://materials/terrain/terrain_valley.tres

# Otomatik pilotla uçuş testi (füze no: 0 Şahin, 1 Kartal, 2 Yıldırım)
godot --headless --path . --fixed-fps 60 res://tools/godot/flight_test.tscn -- 1 /tmp/ucus

# Sketchfab'den model ara / indir (yalnızca CC0 ve CC-BY kabul edilir)
python3 tools/sketchfab_fetch.py search "missile"
python3 tools/sketchfab_fetch.py download <uid> <isim>
python3 tools/process_model.py tools/downloads/<isim> assets/models/<klasör>/<isim>
```

## Kodlama kuralları
- Tüm GDScript tipli yazılır; `untyped_declaration` uyarısı **hata** olarak ayarlıdır.
- Oyun hissini etkileyen her sayı bir `Resource` içinde durur, koda gömülmez.
- Mobil öncelikli: çoklu dokunmatik, düşük draw call, 1024 px dokular, LOD'lu arazi.

## Gizli anahtarlar
`.env.example` dosyasını `.env` olarak kopyalayın (`SKETCHFAB_API_TOKEN`). `.env` `.gitignore`
içindedir; asla commit'lemeyin.
