# Roket Oyunu

Godot 4.7 ile Android için 3B füze yönlendirme oyunu (prototip).

## Gereksinimler
- Godot **4.7.x** (standart sürüm, .NET değil)
- Android export için: Android SDK + OpenJDK 17, Godot Android export şablonları

## Çalıştırma
Projeyi Godot'ta açıp F5. Masaüstünde kontrol: **WASD / ok tuşları** yönlendirme,
**Space** fırlatma, **Esc** duraklatma.

## Testler
```bash
godot --headless -s addons/gut/gut_cmdln.gd
```
(`.gutconfig.json` testleri `tests/unit/` altından toplar.)

## Proje yapısı
| Klasör | İçerik |
|---|---|
| `autoload/` | Global düğümler: `GameState`, `UserSettings` |
| `config/` | Oyun hissi / bölüm ayarları (`.tres` Resource) — kodu değiştirmeden ince ayar |
| `scripts/` | Tipli GDScript, alana göre alt klasörler |
| `scenes/` | Küçük, modüler sahneler |
| `assets/` | Modeller, dokular, sesler (bkz. `ASSETS.md`) |
| `tests/unit/` | GUT birim testleri |
| `tools/` | Geliştirme betikleri (Sketchfab indirici vb.) |

## Kodlama kuralları
- Tüm GDScript tipli yazılır; `untyped_declaration` uyarısı **hata** olarak ayarlıdır.
- Oyun hissini etkileyen her sayı bir `Resource` içinde durur, koda gömülmez.

## Gizli anahtarlar
`.env.example` dosyasını `.env` olarak kopyalayın. `.env` `.gitignore` içindedir; asla commit'lemeyin.
