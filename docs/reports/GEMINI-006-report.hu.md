# Fejlesztési Jelentés: GEMINI-006 – Mobilapp és Éles Webportál (hun01usar.hu) Supabase Integráció

**Projekt:** Rescue Platform – Mobil Kliens (`hunor-app`) és Webportál (`portal/`)  
**Dátum:** 2026-11-12  
**Státusz:** Elkészült és integrálva  

---

## 1. Célkitűzés

A mobilalkalmazás és az éles webportál (**https://hun01usar.hu**) összekapcsolása a közös Supabase adatbázison keresztül. A korábbi verziókban a mobilapp kizárólag offline mock adatokat vagy egy izolált teszt-staging szervert használt, így a tesztelők nem látták a weblapon felvitt valós HUNOR eseményeket, tagokat és riasztásokat.

---

## 2. Azonosított és Elhárított Problémák

1. **Gépelési hiba az éles Supabase végpontban (`lib/config.dart`):**
   - Eredeti cím: `https://embicteneumubwlqgfik.supabase.co` (`bwlqgfik` – elírás).
   - Helyes kanonikus cím: `https://embicteneumubwlqqfik.supabase.co` (`bwlqqfik`).
   - A `publishableKey` korábban üres alapértelmezett értéken volt, most beállításra került a weblappal megegyező éles publikus anon-kulcs (`sb_publishable_Vt7KtNGznwvPrDRr5VEn0Q_r-Z6sas1`).

2. **CI munkafolyamat konfiguráció (`.github/workflows/flutter-android.yml`):**
   - A workflow fájlban is javításra került az elgépelt URL és a korábbi placeholder kulcs.

---

## 3. Megvalósított Új Komponensek és Módosítások

### 3.1. Valós Supabase API Adapter (`lib/api/supabase_rescue_platform_api.dart`)
Megvalósításra került a teljes `RescuePlatformApi` interfész közvetlenül a Supabase PostgreSQL tábláira és Auth moduljára támaszkodva:
- **Autentikáció (`signInWithPassword`):** Közös bejelentkezés a portállal az `auth.users` táblán keresztül.
- **Saját profil (`getMyProfile`):** A `profiles` táblából olvassa ki a bejelentkezett tag adatait (név, rendfokozat, munkahely, beosztás, telefonszám).
- **Események és Naptár (`getEvents`, `getEvent`):** Az éles `events` táblából listázza a gyakorlatokat, képzéseket és bemutatókat időrendi sorrendben.
- **Esemény regisztráció és részvétel (`getEventRegistrationInfo`, `getMyEventParticipation`, `setMyEventParticipation`):** Az `event_participants` táblában rögzíti és szinkronizálja a tagok visszajelzéseit (`going` / `not_going`), amely azonnal megjelenik a portál jelenléti ívén.
- **Riasztási központ (`getAlerts`, `dispatchAlert`, `setMyAlertResponse`):** Az `alerts` és `alert_responses` táblákon keresztül valós idejű riasztásokat és tagi státuszválaszokat kezel.
- **Állománylista (`getMembers`):** Lekéri az állomány tagjait a `profiles`, `skills` és `availability` táblák összekapcsolásával.
- **Hírek (`getNews`, `getNewsItem`):** Támogatja a `news_posts` portálhírek megjelenítését.
- **Push értesítési tokenek (`registerMyInstallation`):** A `device_tokens` táblába menti a készülékek push tokenjeit.

### 3.2. Központi Állapotkezelő és Bejelentkezési Felület (`lib/services/app_store.dart`, `lib/views/login_page.dart`)
- Bővítve a `isSupabase` getterrel és a közvetlen Supabase Auth hívással.
- A bejelentkező képernyő vizuális jelzést ad: `HUNOR Rendszer · Éles Supabase összeköttetés`.
- A Mock gomb kizárólag mock módban látható, így a tesztelők a valódi fiókjukkal léphetnek be.

### 3.3. Belépési Pont és Módválasztó (`lib/main.dart`)
- Alapértelmezett API módként beállítva a `supabase` (`defaultValue: 'supabase'`).
- A `main()` indításakor lefut a `Supabase.initialize()`.
- Támogatott a `SupabaseThemeService` dinamikus témakezelése is.

### 3.4. GitHub Actions CI/CD Folyamat (`.github/workflows/flutter-ci.yml`)
- Frissítve az Android Debug APK építési lépés: a CI mostantól automatikusan a `rescue-platform-hunor-live-apk` csomagot generálja a tesztelők számára, közvetlenül az éles Supabase kapcsolattal.

---

## 4. Tesztelés és Ellenőrzés
- Új egységteszt csomag: `test/api/supabase_rescue_platform_api_test.dart`
- Meglévő biztonsági és guard tesztek (`test/api/release_config_guard_test.dart`) sértetlenek maradtak.
