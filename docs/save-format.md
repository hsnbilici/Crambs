# Save Format — Teknik Spesifikasyon

**Proje:** Project Crumbs
**Kapsam:** Lokal save sistemi — MVP
**Kaynak:** PRD §7.8, §16.8, CLAUDE.md §8
**Güncelleme:** 2026-04-16

> Bu doküman CLAUDE.md §8'in operasyonel detayıdır. Çelişki varsa PRD kazanır.
> `GameState` içeriği bu dokümanda tanımlanmaz — bkz. PRD §7.1–7.7.
> Bulut kayıt, senkronizasyon ve çok oyunculu özellikler bu dokümana dahil değildir (post-MVP).

---

## 1. SaveEnvelope Şeması

### 1.1 Alan tablosu

| Alan          | Dart tipi    | JSON tipi | Açıklama                                              |
|---------------|--------------|-----------|-------------------------------------------------------|
| `version`     | `int`        | number    | Şema versiyonu. Her yapısal değişiklikte artar.       |
| `lastSavedAt` | `String`     | string    | ISO 8601 UTC timestamp (ör. `2026-04-16T10:30:00Z`). |
| `gameState`   | `GameState`  | object    | Oyun durumu — bkz. PRD §7.1–7.7.                     |
| `checksum`    | `String`     | string    | SHA-256 hex string — hesaplama kuralı §3'te.          |

### 1.2 JSON kodlama örneği

```json
{
  "version": 1,
  "lastSavedAt": "2026-04-16T10:30:00.000Z",
  "gameState": {
    "meta": { "...": "PRD §7.2" },
    "run": { "...": "PRD §7.3" },
    "inventory": {},
    "buildings": [],
    "upgrades": [],
    "research": { "...": "PRD §7.6" },
    "events": { "...": "PRD §7.7" },
    "achievements": [],
    "collections": [],
    "settings": {},
    "telemetry": {},
    "save": {}
  },
  "checksum": "a3f1c2d9e4b7658af1234567890abcdef0123456789abcdef0123456789abcde"
}
```

### 1.3 Dart tipleri (kaynak: `lib/core/save/`)

Aşağıdaki tipler bu dokümana göre yazılacaktır; Dart kaynak kodu ayrı bir task'ta üretilir.

| Dart sınıfı      | Sorumluluğu                                                    |
|------------------|----------------------------------------------------------------|
| `SaveEnvelope`   | JSON envelope'ı temsil eder; encode/decode yönetir.           |
| `GameState`      | Tüm alt state ağacını barındırır — PRD §7.1'e tam uyar.       |
| `SaveRepository` | Disk I/O, atomik yazma, rotasyon — yalnızca `lib/core/save/`. |
| `SaveMigrator`   | Versiyon zincirini yönetir, migration'ları sırayla çalıştırır.|
| `SaveChecksum`   | Kanonik JSON üretimi ve SHA-256 hesabı.                       |

---

## 2. Dosya Konumu ve İsimlendirme

### 2.1 Dosya yolları

| Amaç              | Yol                                                             | MVP? |
|-------------------|-----------------------------------------------------------------|------|
| Birincil save     | `{documentsDir}/crumbs_save.json`                              | Evet |
| Yedek (bir nesil) | `{documentsDir}/crumbs_save.json.bak`                          | Evet |
| Manuel slot       | `{documentsDir}/crumbs_save_manual.json`                       | Hayır¹ |
| Geçici yazma      | `{documentsDir}/crumbs_save.json.tmp`                          | Evet |

¹ Manuel slot formatı MVP'de hazır; export/import UI'ı post-MVP.

`{documentsDir}` = `getApplicationDocumentsDirectory()` (`path_provider` paketi).

### 2.2 Kurallar

- Uygulama her zaman birincil path'e yazar; başka path'e doğrudan yazılmaz.
- `.tmp` dosyası yazmadan önce oluşturulur; başarılı fsync sonrası atomik rename ile yerini alır.
- `.bak` dosyası her başarılı yazmadan önce mevcut birincil dosyadan oluşturulur.
- Manuel slot format açısından birincil slot ile birebir aynı şemayı izler.

---

## 3. Checksum Algoritması

### 3.1 Algoritma seçimi: SHA-256

Gerekçe:

- `package:crypto` Flutter'da resmi olarak desteklenir, ek bağımlılık gerekmez.
- Mobil cihazda hesaplama maliyeti ihmal edilebilir (< 1 ms, ~10 KB JSON için).
- Kazara bozulma tespiti için kriptografik güç fazlasıyla yeterli; save güvenliği MVP hedefi değildir.

### 3.2 Kapsam

Checksum şu alanların kanonik JSON'ını kapsar:

```text
{ version, lastSavedAt, gameState }
```

`checksum` alanı **kapsam dışında** tutulur.

### 3.3 Kanonizasyon kuralları

| Kural                        | Değer                         |
|------------------------------|-------------------------------|
| Anahtar sıralama             | Alfabetik (tüm iç nesnelerde) |
| Boşluk (whitespace)          | Yok                           |
| Karakter kodlaması           | UTF-8                         |
| Sayı biçimi                  | JSON varsayılanı (bilimsel notasyon yok) |
| Null alanlar                 | Dahil edilir, atlanmaz        |

Örnek kanonik girdi (kısaltılmış):

```text
{"gameState":{...},"lastSavedAt":"2026-04-16T10:30:00.000Z","version":1}
```

### 3.4 Checksum akışı

```text
kanonize({ version, lastSavedAt, gameState })
  → UTF-8 bytes
  → sha256(bytes)
  → hex string (lowercase)
  → envelope.checksum alanına yaz
```

---

## 4. Okuma Akışı

```text
crumbs_save.json dosyasını oku
  │
  ├─ Okunamadı / bulunamadı
  │     └─► crumbs_save.json.bak'ı dene  (§4.1)
  │
  ├─ JSON parse hatası
  │     └─► crumbs_save.json.bak'ı dene  (§4.1)
  │
  ├─ Checksum yanlış
  │     └─► crumbs_save.json.bak'ı dene  (§4.1)
  │
  └─ Checksum doğru
        │
        ├─ version > appVersion  →  SaveLoadResult.refusedFutureVersion(...)
        ├─ version == appVersion →  SaveLoadResult.ok(state)
        └─ version < appVersion  →  migration zincirini çalıştır  (§6)
                                        └─► SaveLoadResult.ok(migratedState)
```

### 4.1 Yedek yükleme

```text
crumbs_save.json.bak dosyasını oku
  ├─ Başarılı + checksum doğru →  SaveLoadResult.recovered(state, reason)
  └─ Başarısız                  →  SaveLoadResult.fresh(reason)
```

### 4.2 Sürüm uyumsuzluğu

| Durum                        | Sonuç                                            |
|------------------------------|--------------------------------------------------|
| `stored.version == appVersion` | Normal yükleme                                |
| `stored.version < appVersion`  | Migration zinciri (§6), ardından ok             |
| `stored.version > appVersion`  | `refusedFutureVersion` — kullanıcıya mesaj göster, yükleme durdurulur |

---

## 5. Yazma Akışı

```text
1. crumbs_save.json  →  crumbs_save.json.bak  (rotate)
2. gameState'i seri hale getir
3. checksum hesapla (§3)
4. SaveEnvelope JSON'ını oluştur
5. crumbs_save.json.tmp'ye yaz
6. fsync
7. rename(.tmp → crumbs_save.json)  ← atomik
```

> **Adım 1 atlanmamalıdır.** `.bak` rotasyonu atomik rename'den önce gerçekleşir.
> Rename başarısız olursa `SaveRepository` `.tmp` dosyasını siler; birincil dosya bozulmadan kalır.

### 5.1 Yazma hız sınırı (throttle)

| Kural                              | Değer                |
|------------------------------------|----------------------|
| Minimum yazma aralığı (normal)     | 5 saniye             |
| Force-flush olayları               | Prestige, bina/upgrade satın alma, research tamamlanma, uygulama arka plana alınması (`AppLifecycleState.paused`) |
| Force-flush gecikme limiti         | Yok — olayda anında tetiklenir |

Normal oyun tick'leri throttle'a tabidir; kritik olaylar kuyruğu atlayarak doğrudan yazar.

---

## 6. Migration Politikası

### 6.1 Dosya sözleşmesi

Her versiyon geçişi için tek bir migration dosyası:

```text
lib/core/save/migrations/v{N}_to_v{N+1}.dart
```

Örnek: `v1_to_v2.dart`, `v2_to_v3.dart`.

### 6.2 Zincir çalışması

Yüklenen save `vN`, uygulama `vM` bekliyorsa (N < M):

```text
migrate(save, N→N+1) → migrate(result, N+1→N+2) → … → migrate(result, M-1→M)
```

Her adım bir öncekinin çıktısını alır. Zincir `SaveMigrator` sınıfı tarafından yönetilir.

### 6.3 Zorunlu kurallar

| Kural              | Açıklama                                                                           |
|--------------------|------------------------------------------------------------------------------------|
| **İdempotentlik**  | Aynı migration aynı save'e iki kez uygulanırsa sonuç değişmez.                   |
| **Yıkıcı olmama**  | Kaldırılan alan bir sonraki versiyona `_archived` namespace'de taşınır; son kaldırma bir versiyon sonraya ertelenir. |
| **Unit test**      | Her migration dosyasının yanında `v{N}_to_v{N+1}_test.dart` bulunmak zorundadır. Fixture: pre-migration JSON dosyası. |
| **Bağımsızlık**    | Bir migration başka migration'ın iç mantığına bağımlı olamaz.                    |

### 6.4 `_archived` örneği

`v2` içinde `tapBonus` alanı kaldırılıyorsa:

```text
v2_to_v3 migration:
  - gameState._archived.tapBonus = gameState.run.tapBonus
  - gameState.run.tapBonus silinir

v3_to_v4 migration:
  - gameState._archived.tapBonus silinir (kalıcı temizlik)
```

---

## 7. Geriye Dönük Uyumluluk Kuralları

| Değişiklik türü               | Versiyon bump? | Migration gerekli? | Notlar                                         |
|-------------------------------|----------------|--------------------|------------------------------------------------|
| Yeni alan, güvenli default    | Hayır          | Hayır              | Eksik alan default ile doldurulur (null-safe)  |
| Alan kaldırma                 | Evet           | Evet               | `_archived` kuralı (§6.3) uygulanır            |
| Alan yeniden adlandırma       | Evet           | Evet               | Eski ad `_archived`'a taşınır, yeni ad yazılır |
| Anlam/birim değişikliği       | Evet           | Evet               | Dönüşüm migration içinde yapılır               |
| Salt yeniden sıralama / format | Hayır         | Hayır              | Kanonik JSON sıralaması deterministiktir       |

> **Kural:** Yalnızca yeni alan ekliyorsan versiyon bumplama. Bunların dışındaki her değişiklik versiyon bump gerektirir.

---

## 8. Hata Sınıflandırması

Okuma akışı uygulama katmanına aşağıdaki sealed result tiplerinden birini döner:

| Tip                                              | Ne zaman döner                                                        |
|--------------------------------------------------|-----------------------------------------------------------------------|
| `SaveLoadResult.ok(GameState state)`             | Birincil dosya sağlıklı yüklendi; gerekirse migration uygulandı.     |
| `SaveLoadResult.recovered(GameState state, String reason)` | Birincil bozuktu, yedek dosyadan yüklendi. UI'ya uyarı gösterilmeli. |
| `SaveLoadResult.fresh(String reason)`            | Hem birincil hem yedek okunamadı. Fresh state başlatılır.            |
| `SaveLoadResult.refusedFutureVersion(int storedVersion, int appVersion)` | Save, uygulamadan daha yeni bir şemaya ait. Yükleme reddedilir, kullanıcıya mesaj gösterilir. |

`reason` alanı hata logu ve kullanıcı mesajı için ham metni taşır; UI katmanı bunu yerelleştirir.

---

## 9. Test Gereksinimleri

Aşağıdaki test senaryoları zorunludur. Test dosyaları `test/core/save/` altında yaşar.
Detaylı test matrisi için bkz. `docs/test-plan.md`.

| Senaryo                               | Test türü      | Açıklama                                                                |
|---------------------------------------|----------------|-------------------------------------------------------------------------|
| Migration round-trip                  | Unit           | Her `vN → vN+1` migration'ı fixture save ile test edilir; çıktı beklenen şemaya uyar. |
| Migration idempotentlik               | Unit           | Aynı migration iki kez uygulandığında çıktı değişmez.                  |
| Checksum tamper tespiti               | Unit           | `gameState` alanı değiştirildikten sonra checksum doğrulaması başarısız olur. |
| Atomik yazma kesilmesi                | Integration    | `.tmp` dosyası varken process öldürülür; birincil dosya bozulmamış kalır. |
| Gelecek versiyon reddi                | Unit           | `stored.version > appVersion` ise `refusedFutureVersion` döner.        |
| Yedekten kurtarma                     | Unit           | Birincil checksum yanlış, yedek sağlıklı → `recovered` döner.          |
| Fresh state (her iki dosya da bozuk)  | Unit           | Her iki dosya da okunamaz → `fresh` döner, oyun sıfırdan başlar.       |
| Versiyon zinciri (N → M, N+2 < M)    | Unit           | Ara migration'lar sırayla çalışır, sonuç geçerli `vM` save'dir.        |

---

## 10. Bu Dokümandaki Kapsam Dışılar

| Konu                              | Nerede bulunur               |
|-----------------------------------|------------------------------|
| `GameState` alan detayları        | PRD §7.1–7.7                 |
| Ekonomi formülleri                | `docs/economy.md` |
| UX akışları (hata ekranı metni)   | `docs/ux-flows.md` |
| Telemetri olayları                | `docs/telemetry.md` |
| Dart kaynak kodu                  | `lib/core/save/` (ayrı task) |
| Bulut kayıt / senkronizasyon      | MVP dışı — PRD §13           |
| Çok oyunculu / leaderboard        | MVP dışı — PRD §13           |
