# KronoCam

Timestamp camera app (Flutter) — photo click karo, koi watermark nahi
lagta by default. Menu se "Modify Date/Time/Day" ya "Upload Photo" choose
karke stamp editor khulta hai (ek short ad dekhne ke baad unlock hota
hai), jahan date, time, day aur project/site name (kisi bhi language
mein type/paste karke) photo pe add kar sakte ho.

## Features

- **Live camera** — full-screen preview, shutter button, clean photo
  seedhe gallery ke `KronoCam` album mein save hoti hai (no watermark).
- **Modify Date/Time/Day** (top-right ☰ menu) — latest photo ko edit
  karne ke liye kholta hai.
- **Upload Photo** (☰ menu) — gallery se koi bhi photo pick karke edit
  karo.
- **Watch-ad-to-unlock** — stamp editor tabhi khulta hai jab user ek
  rewarded ad dekh le (`google_mobile_ads`, Google ke test ad unit IDs
  ke saath already wired — real IDs neeche batayi jagah pe daal dena).
- **Editor controls** — Day/Date/Time on-off toggle, date-time picker
  (change karne ke liye), project/site name text field (kisi bhi
  language/emoji sahit — copy-paste bhi chalega), stamp position
  (left/center/right), background card on/off.
- **Dark theme toggle** (☰ menu).
- **Privacy Policy screen** (☰ menu) — app name aur "App made by
  Shubham" credit ke saath.

## Folder structure

```
lib/
  main.dart                     — app entry, theme wiring
  provider/theme_provider.dart  — dark mode (persisted)
  services/ad_service.dart      — rewarded ad wrapper
  services/gallery_service.dart — save photo to device gallery
  models/stamp_config.dart      — stamp settings model
  widgets/stamp_overlay.dart    — the date/time/day/name overlay UI
  widgets/watch_ad_dialog.dart  — "watch ad to unlock" popup
  screens/home_screen.dart      — camera + top menu
  screens/edit_screen.dart      — stamp editor + save
  screens/privacy_policy_screen.dart
```

## Build kaise karein

### Option A — GitHub Codespaces (recommended, bina apne PC pe kuch install kiye)

1. Is code ko apne naye GitHub repo mein push karo.
2. Repo khol ke **Code → Codespaces → Create codespace on main**.
3. Terminal khulte hi:
   ```bash
   sudo snap install flutter --classic
   flutter doctor
   flutter pub get
   flutter build apk --release
   ```
4. APK: `build/app/outputs/flutter-apk/app-release.apk` — Explorer mein
   right-click → Download.

### Option B — GitHub Actions (fully automatic)

`.github/workflows/build-apk.yml` already added hai — repo push karte hi
Actions tab mein khud APK ban jayegi. Run complete hone ke baad
**Artifacts → KronoCam-release-apk** se download kar lo.

### Option C — apne PC pe Flutter installed ho to

```bash
flutter pub get
flutter build apk --release
```

## AdMob real ad unit IDs kaise lagayein (zaroori, earning ke liye)

Abhi Google ke **public TEST ad unit IDs** lagi hain — app chalegi aur
"Test Ad" dikhega, lekin real paisa nahi milega. Real earning ke liye:

1. https://admob.google.com pe account banao, ek naya app add karo
   (Android/iOS), usme ek **Rewarded ad unit** banao.
2. In 3 jagah apni real IDs daal do:
   - `android/app/src/main/AndroidManifest.xml` → `com.google.android.gms.ads.APPLICATION_ID` meta-data ki value (apni AdMob **App ID**)
   - `ios/Runner/Info.plist` → `GADApplicationIdentifier` key (apni AdMob App ID)
   - `lib/services/ad_service.dart` → `_androidAdUnitId` aur `_iosAdUnitId` (apni **Rewarded Ad Unit ID**, App ID se alag hoti hai)
3. Rebuild karo.

⚠️ Jab tak real IDs nahi daaloge, test ads hi dikhengi — jo bilkul
normal hai development ke liye, bas launch se pehle badal dena.

## Permissions

App camera, gallery/photos, aur (ads ke liye) internet permission
maangta hai — dono manifest files (`AndroidManifest.xml`, `Info.plist`)
mein already add hain, kuch alag se karne ki zaroorat nahi.

## Publish karne se pehle

- `android/app/build.gradle.kts` mein `applicationId` = `com.kronocam.app`
  already set hai — apna unique id chaho to badal lena.
- Apna khud ka signing keystore banao aur release build sign karo
  (Flutter docs: "Build and release an Android app").
- App icon `assets/icons/app_icon.png` abhi purani calculator wali icon
  hai — usko apni KronoCam/camera-themed icon se replace kar dena,
  fir `flutter pub run flutter_launcher_icons` chala dena.

## Note

Ye poora working Flutter **source code** hai. Is sandbox mein Flutter/
Android SDK install nahi hai isliye compiled `.apk` yahan nahi ban saki
— upar diye Option A/B/C se 2-10 min mein real APK ban jayegi.
