# Roket Oyunu — Kademeli Geliştirme Planı v2

## Bağlam
Test alanı (kanyon vadisi, 3 füze, dokunmatik kontrol, kamera, efektler) GitHub'da çalışıyor.
Geri bildirim: füze hissi önde, çevre "idare eder" ama dağınık. Hedef: **çoğu Android cihazda
çalışan ama çok etkileyici, sürükleyici ve bağımlılık yapan** bir Play Store oyunu.
Kararlar: mekan = **çöl askerî üssü** (mevcut kanyon korunur), sesler = CC0/CC-BY **+ ticari
kullanıma izin veren telifsiz paketler**, füze isimleri = **kurgusal**, atmosfer = **bölüme özel
hazır ayarlar** (şafak/öğle/gün batımı/gece).

## Çalışma kuralları (tüm fazlar)
- **Her faz küçük ve kapalıdır:** sonunda oynanabilir sürüm + ekran görüntüleri + performans
  ölçümü + sizin tablette onayınız. Onay gelmeden sonraki faza geçilmez → çöpe giden iş olmaz.
- **Yeniden kullanılabilir sistem önce, içerik sonra:** her özellik bir `Resource` tanımı +
  küçük sahne olarak gelir (ör. `LauncherDefinition`, `TimeOfDayPreset`); içerik bunlarla çoğalır.
- **Lisans defteri:** her varlık `ASSETS.md`'de; CC-BY dışı lisans metinleri
  `assets/licenses/` altında saklanır. Yalnızca CC0, CC-BY 4.0 ve ticari kullanıma izin veren
  telifsiz paketler (lisans metni saklanarak). NC / ND / SA ve belirsiz lisans **yasak**.
  Gerçek marka, ulusal işaret ve gerçek silah isimleri kullanılmaz.
- **Mobil bütçe (orta-alt seviye cihaz, 60 FPS hedefi):** kare başına ≤ 150 draw call,
  ≤ 400 bin üçgen; sahne nesnesi ≤ 5 bin üçgen ve ≤ 2 malzeme; dokular ≤ 1024 px (küçükler 512);
  tekrarlanan nesneler `MultiMeshInstance3D`; gerçek zamanlı ışık sayısı sınırlı.
  Her faz sonunda `tools/godot/flight_test` ile draw call / üçgen raporu.
- Mevcut yapı korunur: `MissileFlightModel`, `Missile`, `ChaseCamera`, `TouchJoystick`,
  `TerrainShape` + `generate_terrain.gd`, `process_model.py`, `make_model_wrapper.gd`.

---

## Faz 1 — Düzenli çöl üssü (mekan v2)  ✅ tamamlandı, onaylandı
> Sonuç: en ağır görüş (rampa) 141 draw call / 344 bin üçgen; kanyon ~300 bin; 29 birim testi.
> Not: masaüstünde "soft" gölge filtresi bazı GPU'larda standart malzemeleri kararttı; proje
> genelinde Android varsayılanı olan "hard" filtreye sabitlendi (daha ucuz, her cihazda aynı).
**Amaç:** Kanyonun içine, gerçekçi ve "tasarlanmış" görünen bir üs: dağınık doğa değil,
yollar, beton zeminler, çitler, yapılar ile okunur bir mekan.

0. **Gereksiz dış alanı kaldır, sınırı ucuz yöntemle gizle (kamuflaj):**
   - Oyun alanı yalnızca uçulan koridor + hedef/üs bölgeleri kadar küçültülür (şu an 2×2 km'nin
     büyük kısmı ulaşılmayan dağ). Tam çözünürlüklü arazi sadece koridorda; vadi duvarlarının
     arkası düşük çözünürlüklü (16–32 m) tek parça "kabuk".
   - 14 km'lik uzak dağ halkası kaldırılır → yerine birkaç yüz üçgenlik **siluet kartı** (ufukta
     dağ sırası, sise gömülü) + HDRI ufku + yükseklik sisi/toz pusu. Uzak her şey gölge atmaz.
   - Görünmez sınır: koridor dışına/çok yükseğe çıkan füzeye "SINIR — geri dön" uyarısı, sonra
     kendini imha (ucuz, işlemci yormaz). Kamera uzak düzlemi ve parça görünürlük mesafeleri
     koridora göre kısılır.
   - Ölçüm: önce/sonra draw call ve üçgen (hedef: rampada bugünkü 568 bin → ≤ 300 bin).
1. **Arazi düzen verisi:** `TerrainShape`'e `flat_zones` (beton pist/üs alanları) ve
   `roads` (Curve3D yol koridorları, arazi yol boyunca düzleşir) eklenir. Arazi yeniden üretilir.
2. **Yol ve zemin sistemi:** yol ağı üretici (`tools/godot/generate_roads.gd`) — asfalt/toprak
   yol şerit ağları + kenar geçişi; beton pist plakaları. Poly Haven CC0 dokular (asfalt, beton).
3. **Model azaltma aracı:** `tools/godot/decimate_model.gd` (Godot'un LOD üreticisiyle ağır CC0
   modelleri mobil bütçeye indirir) — Poly Haven ve Sketchfab modellerini kullanılabilir kılar.
4. **Üs yerleşimi (iki bölge):**
   - *Fırlatma üssü (güney):* beton fırlatma pistleri, kontrol binası/kule, hangar, yakıt tankları,
     radar, kum torbaları, beton bariyerler, çit hattı, aydınlatma direkleri, park halinde araçlar.
   - *Hedef kompleksi (kuzey):* depo/komuta binaları, araç parkı, konteynerler, gözetleme kulesi,
     çitli avlu. (Bu fazda yıkılmaz; Faz 4'te yıkılabilir olur.)
   - Aradaki vadide yol, birkaç terk edilmiş araç, kaya ve kuru çalı serpiştirmesi (MultiMesh,
     yollara/pistlere girmeyen kurallarla).
5. **Kurgusal isimler:** füzeler yeniden adlandırılır (ör. Hasta → "Şahin", Storm Shadow →
   "Kartal", Fateh-110 → "Yıldırım"); `ASSETS.md`'de model kaynakları aynen kalır.
6. **Doğrulama:** rampa, uçuş, hedef kompleksi ekran görüntüleri + performans raporu; birim testleri
   (düz alanlar, yol koridorları, serpiştirme kuralları).

**Siz test edersiniz:** mekan hissi, okunabilirlik, FPS. Onay → Faz 2.

## Faz 2 — Fırlatma rampaları (mekanizma + ses + sinematik)  ✅ tamamlandı, tablet onayı bekleniyor
> Sonuç: 3 rampa (Mobil TEL, Eğik Ray, Dikey Silo), 18 kamera çekiminin en ağırı 143 draw call /
> 322 bin üçgen (`tools/godot/launcher_shot_report.tscn`); 36 birim testi. Otopilotla 6 füze-rampa
> eşleşmesinden 5'i hedefi vuruyor (Yıldırım–kanyon geçişi Faz 1'de de otopilot için çok dar).
> Not: arka planda üs yapıları görünen alçak çekimler bütçeyi aşıyordu (~200); çekimler yukarıdan
> ya da gökyüzüne bakacak biçimde ayarlandı.
- `LauncherDefinition` + `Launcher` sahnesi: hazırlık → kaldırma → kilitleme → ateşleme → bırakma
  aşamaları, her aşamanın animasyonu, sesi ve kamera çekimi.
- 3 tür: **mobil TEL kamyonu** (hidrolik ray kalkar), **sabit eğik ray rampası** (beton kaide),
  **dikey silo/VLS** (kapak açılır, soğuk fırlatma "pof" → havada ateşleme).
- Fırlatma efektleri: pist üzerinde egzoz bulutu, toz, yanık izi, kısa kamera sarsıntısı.
- Hangi füze hangi rampadan atılabilir (tanımda).

## Faz 3 — Roket sesleri v2
- Katmanlı motor sesi: ateşleme çatlaması, booster gürlemesi (döngü), sustainer, yakıt bitişi,
  hıza bağlı hava sürtünmesi/rüzgâr, kameraya göre geçiş (doppler).
- Ortam: çöl rüzgârı, üs uğultusu; kanyonda yankı bölgeleri (Area3D + reverb).
- Patlamalar: mesafeye göre ses gecikmesi (ses hızı), yakın/uzak katmanları.
- Kaynaklar: Sonniss GDC paketleri (lisans metni saklanır), Freesound CC0/CC-BY, Kenney CC0,
  gerekirse prosedürel üretim. Ses veri yolları (Master/SFX/Ortam/UI) + ayarlardan seviye.

## Faz 4 — Hedefler ve yıkım
- `Destructible` bileşeni: can, hasar alanı (patlama yarıçapı), sinyaller.
- Yapılar: sağlam → hasarlı → yıkık durumları + çöküş animasyonu (çökme/eğilme + toz) +
  az sayıda havuzlanmış enkaz gövdesi.
- Araçlar: patlayıp savrulma, yanan enkaz; ikincil patlamalar (yakıt tankı, mühimmat).
- Kalıcı yangın/duman, skor ve isabet geri bildirimi (yavaş çekim "kill-cam").

## Faz 5 — Atmosfer önayarları
- `TimeOfDayPreset` (güneş açısı/rengi, HDRI, sis, pozlama, ortam ışığı): şafak, öğle, gün batımı,
  gece. Gecede: pencere ışımaları, projektörler (sınırlı ışık + sahte ışık konileri), füze alevinin
  sahneyi aydınlatması. Her önayar için performans ölçümü.

## Faz 6 — Görev ve olay örgüsü (bağımlılık döngüsü)
- `MissionDefinition`: hedefler, süre, kısıtlar, olay tetikleyicileri.
- Olaylar: hareket eden konvoy, uçaksavar ateşi (izli mermilerden kaçış), son anda beliren hedef,
  rüzgâr/toz fırtınası.
- 60–120 sn'lik kısa görevler, yıldız puanı, tekrar oynama isteği, füze/rampa kilitleri.

## Faz 7 — Menüler, ilerleme, yayın hazırlığı
- Ana menü, görev seçimi, ayarlar (hassasiyet, ters eksen, ses, grafik kalitesi), krediler (CC-BY).
- Kayıt/ilerleme, Android export ayarları, düşük seviye cihaz testi (Compatibility renderer
  yedeği), Play Store hazırlığı.

---

## Doğrulama (her faz)
- GUT birim testleri (`godot --headless -s addons/gut/gut_cmdln.gd`) yeşil.
- Temiz klonda içe aktarma hatasız; otomatik pilot uçuşları (`tools/godot/flight_test.tscn`).
- Yazılımsal render ile ekran görüntüleri + draw call / üçgen raporu bütçe içinde.
- Commit + push geliştirme dalına; siz tablette deneyip onay verirsiniz.
