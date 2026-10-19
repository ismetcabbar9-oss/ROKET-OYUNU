class_name MissileFlightSettings
extends Resource
## Bir füze türünün tüm uçuş hissi değerleri. Kodu değiştirmeden ince ayar için
## config/ altındaki .tres dosyaları düzenlenir. Açılar derece, süreler saniye, mesafeler metre.

@export_group("Dönüş")
## Tam girdide ulaşılabilecek en yüksek yunuslama (burun yukarı/aşağı) hızı.
@export_range(5.0, 360.0, 1.0, "suffix:°/s") var max_pitch_rate_deg: float = 65.0
## Tam girdide ulaşılabilecek en yüksek sapma (sağa/sola) hızı.
@export_range(5.0, 360.0, 1.0, "suffix:°/s") var max_yaw_rate_deg: float = 65.0
## Atalet: dönüş hızının hedefe yaklaşma katsayısı (1/s). Düşük = ağır, gecikmeli füze.
@export_range(0.1, 30.0, 0.1, "suffix:1/s") var turn_response: float = 3.0
## Azami hızdayken dönüş hızı çarpanı. <1 ise hızlı füze daha geniş döner.
@export_range(0.1, 1.0, 0.01) var high_speed_turn_multiplier: float = 0.75
## Girdi eğrisi üssü. >1 küçük joystick hareketlerini yumuşatır, hassas düzeltme sağlar.
@export_range(1.0, 3.0, 0.05) var input_curve_exponent: float = 1.4
## Burnun yatay düzleme göre çıkabileceği en büyük açı (dikey uçuşta kontrol kaybını önler).
@export_range(10.0, 89.0, 1.0, "suffix:°") var max_pitch_angle_deg: float = 80.0

@export_group("Yatış (görsel)")
## Tam sapma hızında füzenin dönüşe doğru yatma açısı.
@export_range(0.0, 90.0, 1.0, "suffix:°") var max_bank_deg: float = 40.0
## Yatışın hedef açıya yaklaşma katsayısı (1/s).
@export_range(0.1, 30.0, 0.1, "suffix:1/s") var bank_response: float = 5.0

@export_group("Hız ve itki")
@export_range(1.0, 200.0, 0.5, "suffix:m/s") var launch_speed: float = 30.0
@export_range(1.0, 400.0, 0.5, "suffix:m/s") var max_speed: float = 75.0
## Motor yanarken ileri ivme.
@export_range(0.0, 200.0, 0.5, "suffix:m/s²") var thrust: float = 28.0
## Doğrusal sürüklenme katsayısı (ivme = -drag * hız).
@export_range(0.0, 2.0, 0.01, "suffix:1/s") var drag: float = 0.3
## Tam dönüşte saniyede kaybedilen hız oranı (keskin dönüşleri cezalandırır).
@export_range(0.0, 2.0, 0.01, "suffix:1/s") var turn_speed_bleed: float = 0.25
## Bu hızın altına inilmez (füze havada durmaz).
@export_range(0.0, 100.0, 0.5, "suffix:m/s") var min_speed: float = 12.0

@export_group("Yerçekimi")
## 0 = yerçekimi yok, 1 = gerçek yerçekimi. Hem tırmanırken hız kaybı hem burun düşmesi.
@export_range(0.0, 2.0, 0.01) var gravity_scale: float = 0.35

@export_group("Sapma / titreşim")
## Dönüş hızına eklenen rastgele (ama düzgün) sapmanın genliği.
@export_range(0.0, 60.0, 0.1, "suffix:°/s") var wobble_strength_deg: float = 5.0
## Sapmanın ne kadar hızlı değiştiği.
@export_range(0.01, 10.0, 0.01, "suffix:Hz") var wobble_frequency: float = 0.7
## Sapma deseninin tohumu (aynı tohum = aynı uçuş, testler için).
@export var wobble_seed: int = 1337

@export_group("Yakıt ve ömür")
## Motorun itki ürettiği süre.
@export_range(0.0, 120.0, 0.1, "suffix:s") var fuel_seconds: float = 12.0
## Bu süreden sonra füze kendini imha eder.
@export_range(1.0, 300.0, 0.5, "suffix:s") var max_flight_seconds: float = 20.0
