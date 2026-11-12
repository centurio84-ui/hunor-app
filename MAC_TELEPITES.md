# HUNOR Webportál & Mobilapp – macOS Átköltöztetési és Fejlesztői Útmutató

Ez a tároló (`hunor-app`) mostantól **mindkét rendszert** egy helyen tartalmazza:
1. **`portal/` mappa** – Az éles **https://hun01usar.hu** csapatportál teljes, legfrissebb forráskódja (`index.html`, `supabase-app.js`, EXCON értékelő, 4 jegyű PIN-kódos külsős beléptető, jogosultságkezelő, témák).
2. **`lib/`, `ios/`, `android/`, `supabase/` mappák** – A Flutter alapú HUNOR mobilalkalmazás (iOS és Android) és a Supabase adatbázis-migrációk.

---

## 1. Letöltés Mac-re (Git Clone)

Nyisd meg a **Terminal** alkalmazást a Mac-en, és futtasd:

```bash
git clone https://github.com/centurio84-ui/hunor-app.git
cd hunor-app
```

---

## 2. A Webportál (`portal/`) fejlesztése és élesítése Mac-en

### Helyi tesztelés böngészőben:
```bash
cd portal
python3 -m http.server 8080
```
Ezután nyisd meg a Safari vagy Chrome böngészőben: **`http://localhost:8080`**

### Élesítés a `https://hun01usar.hu` oldalra Mac-ről:
1. Hozz létre a `hunor-app` főmappájában egy `.netlify-token` nevű fájlt, amelybe bemásolod a Netlify tokenedet (vagy másold át a Windows gépről).
2. Futtasd a mellékelt Python élesítő szkriptet:
   ```bash
   python3 deploy_portal.py
   ```
   A szkript automatikusan ellenőrzi a módosult fájlokat a `portal/` mappában, és néhány másodperc alatt frissíti az éles **https://hun01usar.hu** weboldalt.

---

## 3. A Flutter Mobilapp (`iOS` / `Android`) fejlesztése Mac-en

### Szükséges eszközök telepítése Mac-en:
1. **Homebrew** (ha még nincs fent):
   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```
2. **Flutter SDK és CocoaPods telepítése:**
   ```bash
   brew install --cask flutter
   brew install cocoapods
   ```
3. **Xcode beállítása** (iOS szimulátorhoz és iPhone-ra telepítéshez):
   - Telepítsd az **Xcode**-ot a Mac App Store-ból, majd futtasd:
   ```bash
   sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
   sudo xcodebuild -runFirstLaunch
   ```

### Az App elindítása Mac-en:
```bash
flutter pub get
cd ios && pod install && cd ..
flutter run
```
