# Firebase Setup Runbook

Sprint B3'te eklenen Firebase Analytics + Crashlytics entegrasyonu için dev
onboarding ve CI secret management rehberi.

---

## 1. Prerequisites

- **FlutterFire CLI:**
  ```bash
  dart pub global activate flutterfire_cli
  ```
- **Firebase CLI auth:**
  ```bash
  firebase login
  # veya firebase login:ci (CI token için)
  ```
- **Firebase Console access:** `crumbs-prod` (veya equivalent) project'e
  hsnbilici account'tan editor-level erişim
- **Flutter 3.41.5 FVM pinned** (CLAUDE.md §2)

---

## 2. Dev onboarding (fresh clone)

Yeni developer repo'yu clone ettiğinde:

```bash
cd Crumbs/
flutterfire configure --project=crumbs-prod
# Interactive prompt:
#   - Platform selection: iOS + Android (web/macOS/linux skip)
#   - Firebase project: crumbs-prod
# Generates (hepsi gitignored):
#   lib/firebase_options.dart
#   ios/Runner/GoogleService-Info.plist
#   ios/firebase_app_id_file.json
#   android/app/google-services.json

flutter pub get
flutter run  # Firebase init success → telemetry ready
```

**Doğrulama:** `flutter run` splash'ten ana ekrana geçiyor, `debugPrint`'te
`[FirebaseBootstrap]` init error YOKSA setup başarılı.

**Fail semptomları:**
- `UnimplementedError: lib/firebase_options.dart missing` → flutterfire
  configure hiç çalışmamış
- `firebase_crashlytics` dependency not found → `flutter pub get` eksik
- iOS "GoogleService-Info.plist not found" → flutterfire configure iOS
  seçilmemiş veya Xcode manual file reference eksik

---

## 3. Secret management (CI)

GitHub Actions `.github/workflows/ci.yml` fork-safe decode step kullanır. CI
secrets şu şekilde generate edilir:

### macOS

```bash
base64 -i lib/firebase_options.dart | pbcopy
# clipboard → GitHub Settings → Secrets → FIREBASE_OPTIONS_DART_B64

base64 -i ios/Runner/GoogleService-Info.plist | pbcopy
# → IOS_GOOGLE_SERVICE_INFO_PLIST_B64

base64 -i android/app/google-services.json | pbcopy
# → ANDROID_GOOGLE_SERVICES_JSON_B64
```

### Linux

```bash
base64 -w 0 lib/firebase_options.dart | xclip -selection clipboard
# Or stdout:
base64 -w 0 lib/firebase_options.dart
```

### GitHub secret ekleme

1. Repo → **Settings** → **Secrets and variables** → **Actions**
2. **New repository secret**
3. Name: `FIREBASE_OPTIONS_DART_B64`, Value: clipboard içeriği yapıştır
4. Tekrarla: `IOS_GOOGLE_SERVICE_INFO_PLIST_B64`,
   `ANDROID_GOOGLE_SERVICES_JSON_B64`

### Fork PR güvenliği

External fork PR'larda `secrets` erişimi yok → decode step
(`if: env.FIREBASE_OPTIONS_DART_B64 != ''`) atlanır → template throw +
`FirebaseBootstrap.initialize` try/catch yutar → `DebugLogger` fallback →
test'ler geçer. Secret fork'a sızmaz.

---

## 4. Privacy

- **`install_id`** — device-local anonymous UUID (v4). PII değil.
  `GameState.meta.installId`'de üretilir, cross-device save restore ile taşınır
  (anonymous identity, kullanıcı hesabı değil).
- **Crashlytics `setUserIdentifier(install_id)`** — anonymous identifier
  attachment, PII attach policy YOK.
- **Analytics event payload'ları** yalnız install_id + session_id + derived
  metrics (duration_ms, age_ms, skipped). Kullanıcı içerik (username, email,
  device name) toplanmaz.
- **Legal privacy policy draft** B4 kapsamında (Sprint C/D öncesi).

---

## 5. Crashlytics doğrulama (ilk setup)

> ⚠️ **KRİTİK: Bu runbook'un son adımı test button'ı silmek. Skip edersen
> production build'de "Test Crash" butonu ships olur — kullanıcı cihazında
> erişilebilir hard crash.**
>
> Gelecek prevention: B4'te `Settings > Developer` ekranı gelince bu button
> kalıcı `kDebugMode || const bool.fromEnvironment('CRASHLYTICS_TEST')`
> flag'i arkasında olacak. B3 kapsamında geçici button + manuel silme.

1. `lib/main.dart` `CrumbsApp.build` içine GEÇİCİ butoncuk ekle (örn. Home
   sayfasının üstüne floating):

   ```dart
   ElevatedButton(
     onPressed: () => FirebaseCrashlytics.instance.crash(),
     child: const Text('Test Crash'),
   )
   ```

2. Release build:

   ```bash
   flutter build ios --release
   flutter build apk --release
   ```

3. **Fiziksel cihazda** çalıştır, butona bas → app crash olur

4. Uygulamayı YENİDEN AÇ (crash report upload bir sonraki launch gerekli)

5. Firebase Console → **Crashlytics** → dashboard'da crash görünür (~5 dk
   gecikme; dashboard ilk 24h "not seen" gösterirse sample Cmd/Ctrl+Shift+R)

6. **Test butonunu `git checkout lib/main.dart` ile sil — BU ADIMI ATLAMA**

7. Doğrula: `git diff HEAD -- lib/main.dart` temiz (no leftover ElevatedButton)

Debug build'de `setCrashlyticsCollectionEnabled(false)` → collection disabled,
bu test release-only çalışır.

**Not:** Physical device önerilir. iOS simülatör / Android emulator
Crashlytics upload yapabilir ama Firebase docs platform-specific uyarıları var;
doğrulama garanti değil. Emülator'de görünmezse fiziksel cihazda yeniden dene.

---

## 6. Troubleshooting

| Sorun | Olası neden | Çözüm |
|---|---|---|
| `UnimplementedError: lib/firebase_options.dart missing` | flutterfire configure eksik veya CI secret decode edilememiş | Dev: `flutterfire configure`. CI: secret ekle + `env.FIREBASE_OPTIONS_DART_B64 != ''` log'da true olsun |
| Crashlytics'te rapor görünmüyor | `setCrashlyticsCollectionEnabled(false)` (debug build) veya ilk 24h propagation | Release build'de test et + 5 dk bekle + sample tekrar yükle |
| Firebase init hang | Network offline / Firebase platform plugin yükleme fail | `try/catch` zaten devreye girer, app devam eder (DebugLogger fallback); network kontrol et |
| iOS build fail "GoogleService-Info.plist not found" | flutterfire configure iOS seçmemiş veya Xcode project'e dosya ref eklememiş | `flutterfire configure --project=... --platforms=ios`; Xcode → Runner target → Build Phases → Copy Bundle Resources'a GoogleService-Info.plist ekle |
| Android build fail "google-services plugin not applied" | `android/app/build.gradle`'da `id "com.google.gms.google-services"` plugin eksik | flutterfire configure bunu otomatik eklemiş olmalı; manual edit gerekirse Firebase docs § "Android setup" |
| `firebase login` CLI auth expire | Firebase CLI token timeout (nadir) | `firebase logout && firebase login` tekrar auth |
| CI log'da `FIREBASE_OPTIONS_DART_B64 is unset` warning | Secret GitHub'a eklenmemiş veya PR external fork | Main repo PR → secret ekle (§3). Fork PR → expected behavior; template fallback devreye girer |

---

## Referanslar

- Firebase Flutter docs: https://firebase.flutter.dev/docs/overview
- FlutterFire CLI: https://firebase.flutter.dev/docs/cli
- Firebase Analytics event naming: https://firebase.google.com/docs/analytics/events
- Sprint B3 spec:
  `docs/superpowers/specs/2026-04-18-sprint-b3-telemetry-activation-design.md`
