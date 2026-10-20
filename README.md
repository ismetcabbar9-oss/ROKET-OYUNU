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
- Soldaki listeden rampayı seçin:
  - **Mobil TEL**: destek ayakları iner, hidrolik erektör füzeyi 50°'ye kaldırır (Kartal, Yıldırım).
  - **Eğik Ray**: beton kaideli ray 24°'ye kalkar, alçak ve hızlı çıkış (Şahin, Kartal).
  - **Dikey Silo**: kapak açılır, füze gazla tüpten atılır ("pof") ve havada ateşlenir (Şahin, Yıldırım).
  Seçili rampadan atılamayan füzeler soluk görünür; seçerseniz uyumlu rampaya geçilir.
- **FIRLAT** fırlatma dizisini başlatır: hazırlık → kaldırma → kilit → ateşleme, her aşama kendi
  sesi ve kamera çekimiyle. Dizi sırasında buton **ATLA** olur ve beklemeyi hızlandırır.
- Füze rampadan ayrılınca kamera arkasına geçer. Sol yarıda parmağınızı nereye koyarsanız joystick orada açılır.
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
Rampalar `config/launchers/<rampa>.tres` içinde: aşama süreleri, kaldırma/fırlatma açısı, soğuk
fırlatma hızı, efekt büyüklüğü, uyumlu füzeler ve her aşamanın kamera çekimi (rampaya göre konum).
Dönüş hızı, atalet (`turn_response`), sapma/titreşim (`wobble_*`), hız, itki, yakıt, yerçekimi,
kamera uzaklığı ve patlama büyüklüğü buradadır. Arazi biçimi: `config/terrain/valley_01.tres`
(değiştirdikten sonra araziyi yeniden üretin, aşağıya bakın).

## Ses
- Veri yolları: **Master** (sınırlayıcı) → **SFX**, **Ambient**, **UI**; kanyon/vadi yankısı **Canyon**
  veri yolunda (`default_bus_layout.tres`). Seviyeler `UserSettings` içinde (`sfx_volume`,
  `ambient_volume`, `ui_volume`; menü Faz 7'de).
- Füze sesi katmanlıdır (`MissileAudio`): ateşleme çatlaması → booster → sustainer → yakıt bitişi,
  üstüne hıza bağlı hava sürtünmesi; doppler açık. Füze başına ayarlar
  `config/missiles/<füze>.tres` → *Ses* grubunda.
- Patlamalar yakın/uzak iki katmanlıdır ve ses hızıyla gecikir (uzaktaki patlamanın gümlemesi sonra gelir).
- Ortam: esintili çöl rüzgârı, üs bölgelerinde jeneratör uğultusu, kanyon geçidinde ve sırtın
  ardındaki vadide yankı (`config/audio/valley_01_ambient.tres`).

## Proje yapısı
| Klasör | İçerik |
|---|---|
| `autoload/` | Global düğümler: `GameState`, `UserSettings` (kontrol modu, hassasiyet, ses) |
| `config/` | Oyun hissi ve bölüm ayarları (`.tres` Resource) |
| `scripts/missile/` | `MissileFlightModel` (saf uçuş fiziği), `Missile`, `MissileDefinition`, egzoz |
| `scripts/audio/` | `AmbientAudio` (rüzgâr, uğultu, yankı bölgeleri), `AmbientSoundSettings` |
| `scripts/launcher/` | `Launcher` (fırlatma dizisi), `LauncherDefinition`, `LauncherCameraShot`, `HydraulicRam` |
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

# Otomatik pilotla uçuş testi (füze no: 0 Şahin, 1 Kartal, 2 Yıldırım; rampa no: 0 TEL, 1 Ray, 2 Silo)
godot --headless --path . --fixed-fps 60 res://tools/godot/flight_test.tscn -- 1 /tmp/ucus "" 1 0

# Sahne nesnesi pişir: parçaları birleştir, ölçekle, tabanı zemine oturt, isteğe bağlı üçgen azalt
godot --headless --path . -s res://tools/godot/bake_prop.gd -- \
    res://assets/models/props/<isim>/model.gltf <isim> <boyut_m> <x|y|z|max> [--collision] [--tris=N]

# Üs yerleşimini yeniden kur (MultiMesh verisi için --headless DEĞİL, ekransızda xvfb-run)
xvfb-run godot --path . -s res://tools/godot/build_base_layout.gd -- \
    res://config/terrain/valley_01.tres res://scenes/levels/valley_01/base_layout.tscn res://assets/terrain/valley_01/layout

# Fırlatma rampası sahnelerini yeniden kur (scenes/launchers/, assets/models/launchers/)
godot --headless --path . -s res://tools/godot/build_launchers.gd

# Oyun seslerini gerçek kayıtlardan hazırla (Sonniss GDC + Kenney; bkz. ASSETS.md)
python3 tools/fetch_sonniss.py /tmp/ses_kaynak
python3 tools/make_sound_assets.py /tmp/ses_kaynak assets/audio/sfx

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
