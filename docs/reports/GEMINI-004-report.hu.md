# Fejlesztési Jelentés: GEMINI-004 – Rescue Platform Flutter MVP Felhasználói Felület
**Projekt:** Rescue Platform – Mobil Kliens (`hunor-app`)  
**Dátum:** 2026-10-14  
**Fejlesztési ág:** `gemini/004-flutter-mvp-ui`  
**Célág:** `main`  

---

## 1. Célkitűzés és Áttekintés

A Rescue Platform Flutter mobilalkalmazásának MVP szintű felhasználói felületének megvalósítása és összekapcsolása a korábban elkészített típusos `RescuePlatformApi` és `MockRescuePlatformApi` réteggel. 

A fejlesztés során az alkalmazás felkészült a több mentőszervezet (multi-tenancy) párhuzamos kezelésére, a szervezeti szintű adatelkülönítésre, az események és riasztások kezelésére, valamint a Rescue Coin (RC) egyenlegek megjelenítésére.

---

## 2. Megvalósított és Átdolgozott Komponensek

1. **Központi Állapotkezelés (`lib/services/app_store.dart`):**
   - Leválasztva a közvetlen Supabase hívásokról; a típusos `RescuePlatformApi` interfészt használja.
   - Kezeli a felhasználói profilt, az elérhető szervezeteket (`availableOrganizations`), az aktív szervezetet (`currentOrganization`) és az aktív tagságot (`currentMembership`).
   - Minden lekérdezés (`getEvents()`, `getAlerts()`, `getCoinBalance()`) szigorúan az aktív szervezet kontextusában fut.
   - **Kötelező cache-ürítés szervezetváltáskor és kijelentkezéskor:** A korábbi szervezethez tartozó riasztások, események és egyenlegek azonnal megsemmisülnek a memóriában.

2. **Alkalmazás Indítása és Belépési Pont (`lib/main.dart`):**
   - Beállítva a biztonságos mock mód, amely hálózati és éles Supabase-függőségek nélkül indítja el a Flutter klienst.

3. **Alkalmazás Keret és Navigáció (`lib/views/app_shell.dart`):**
   - Dinamikus fejléc az aktív szervezet kódjával és nevével (`[HUNOR]` / `[BMSZ]`).
   - Rescue Coin (RC) egyenlegjelző chip a jobb felső sarokban (`120 RC`).
   - Beépített navigáció a Szervezetválasztó képernyőhöz.

4. **Műszerfal (`lib/views/home_page.dart`):**
   - Aktív mentőszervezeti kártya tagsági státusszal és beosztással.
   - Rescue Coin egyenlegkártya főkönyvi verzióval.
   - Szervezetre szűrt aktív riasztási és eseményszámlálók.
   - A szervezet következő műveleti eseményének megjelenítése.

5. **Riasztási Felület (`lib/views/alerts_page.dart`):**
   - Kizárólag az aktív szervezethez tartozó riasztások listázása típusonként (Riasztás, Készenlét, Gyakorlat).
   - Riasztásra adott bevethetőségi válasz rögzítése (`Elérhető vagyok` / `Nem vagyok elérhető`) a mock API-n keresztül.
   - Lejárt riasztások kezelése (`ConflictException`).

6. **Eseménynaptár (`lib/views/calendar_page.dart`):**
   - Szervezetenként szűrt események időponttal, helyszínnel és részvételi visszajelzéssel.

7. **Profil Felület (`lib/views/profile_page.dart`):**
   - Tag adatai, szervezeti tagság státusza és jogosultságai.
   - Rescue Coins egyenleg.
   - Biztonságos kijelentkezés, amely azonnal törli a helyi gyorsítótárat.

8. **Bejelentkezési Felület (`lib/views/login_page.dart`):**
   - Tiszta, mock módot jelző felület "Gyors belépés (Mock fiók)" funkcióval.

---

## 3. Tesztelés és Ellenőrzés

* **Egység- és Widget-tesztek (`test/widget/mvp_ui_flow_test.dart`):**
  1. *Bejelentkezési folyamat:* Mock bejelentkezés, sikeres állapotváltás a főoldalra.
  2. *Cross-tenant UI izoláció:* Igazolva, hogy HUNOR szervezetben csak a HUNOR riasztások és események láthatók; BMSZ-re váltás után a gyorsítótár kiürül, és kizárólag a BMSZ adatai jelennek meg.
  3. *Riasztási válaszadás:* Modális ablakban leadott válasz rögzítése és állapota.
  4. *Kijelentkezési adatvédelem:* Kijelentkezéskor a szervezeti adatok teljes törlése.

* **Meglévő tesztcsomag (`test/api/rescue_platform_api_mock_test.dart`):**
  - A korábbi 12 API egységteszt változatlanul biztosítja az OpenAPI v0.2 szerződés betartását.

---

## 4. Fennmaradó Feladatok (Következő fázisok)

1. Valós hálózati `HttpRescuePlatformApi` illesztő megvalósítása a Codex által biztosított kanonikus backendhez.
2. Helyi titkosított tárolás (`flutter_secure_storage`) a hitelesítési tokenek perzisztálására.
3. Offline válaszsor (outbox / pending state) és hálózati visszatéréskori automatikus újraküldés.
4. Push értesítési tokenek valós regisztrációja a szervezetváltás és kijelentkezés eseményeihez kötve.
