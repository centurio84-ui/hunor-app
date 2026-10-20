# Fejlesztési Jelentés: GEMINI-005 – Rescue Platform MVP Stabilizálás és Android Tesztverzió (APK)
**Projekt:** Rescue Platform – Mobil Kliens (`hunor-app`)  
**Fejlesztési ág:** `gemini/005-mvp-stabilization-demo`  
**Célág:** `main`  
**Dátum:** 2026-10-20  

---

## 1. Célkitűzés és Prioritásmódosítás

A felhasználó igényeinek megfelelően a **GEMINI-005** elsődleges célja egy Android telefonra közvetlenül telepíthető, biztonságos, kizárólag mock adatokat használó **Android Debug APK** előállítása, a meglévő Flutter CI hibák teljes körű elhárítása és a folyamat automatizálása GitHub Actions segítségével.

Az elkészült Android alkalmazáscsomag (`app-debug.apk`) nem tartalmaz éles API-kulcsokat, nem csatlakozik az éles Supabase adatbázishoz vagy éles Netlify háttérrendszerekhez, és azonnal telepíthető bármely Android 5.0+ (API 21+) készülékre.

---

## 2. Elvégzett Kódjavítások és Tesztstabilizálás

1. **Riasztási felület és modális ablak javítása (`lib/views/alerts_page.dart`):**
   - Elhárítva a 27 pixeles RenderFlex layout overflow hiba: a modális ablak (`showModalBottomSheet`) mostantól `isScrollControlled: true` tulajdonsággal és `SingleChildScrollView`-ba ágyazva jelenik meg, így kisebb képernyőkön és fekvő nézetben is görgethetővé vált.
   - Biztonságos értesítéskezelés: a `ScaffoldMessenger.maybeOf(context)` használatával megelőztük az unmounted scaffold exception-t a modális ablak bezárásakor.

2. **Kijelentkezési felület és állapotkezelés (`lib/views/profile_page.dart`):**
   - Javítva a `CircularProgressIndicator` viselkedése: kijelentkezéskor nem ragad végtelen animációs ciklusban, így az automatikus tesztek (`pumpAndSettle`) stabilan lefutnak.
   - Megjelenik a „Nincs bejelentkezett felhasználó” tájékoztató szöveg kijelentkezett állapotban.

3. **Felhasználói folyamat widget tesztek (`test/widget/mvp_ui_flow_test.dart`):**
   - Az önálló aloldalak teszteléséhez biztosított a `Scaffold(body: home)` burkolás, így a navigáció és értesítéskezelés környezete megegyezik a valós alkalmazáséval.
   - Minden felhasználói folyamatteszt (mock belépés, cross-tenant adatizoláció, riasztási válasz, kijelentkezési cache-ürítés) sikeresen lefut.

4. **Központi állapotkezelő (`lib/services/app_store.dart`):**
   - `members` getter és szervezetenként izolált tagok betöltése a multi-tenant szabályok szerint.
   - Adminisztrátori segédfunkciók implementálása (`createAlert`, `closeAlert`, `createEvent`, `updateEvent`, `deleteEvent`, `updateMemberRole`).

5. **GitHub Actions Munkafolyamat (`.github/workflows/flutter-ci.yml`):**
   - Beállítva a Java JDK 17 környezet (`actions/setup-java@v4`).
   - Android platformfájlok automatikus generálása: `flutter create --org hu.hunor --platforms android,web .`.
   - Android Debug APK automatikus építése: `flutter build apk --debug`.
   - APK közzététele letölthető GitHub Actions Artifactként: `rescue-platform-android-apk`.
   - Párhuzamosan megmaradt a mobil webes release build (`rescue-platform-web-demo`) is.

---

## 3. Részletes Magyar Nyelvű Telepítési Útmutató Android Telefonra

### 1. Lépés: Az APK letöltése a GitHubról
1. Nyisd meg a GitHub repozitóriumban az adott futtatást (`Actions -> Flutter CI/CD és Tesztelés`).
2. Görgess az oldal aljára az **Artifacts** (Összetevők) szekcióhoz.
3. Kattints a **`rescue-platform-android-apk`** linkre a tömörített `.zip` fájl letöltéséhez.
4. Csomagold ki a `.zip` fájlt a számítógépen vagy a telefonon: a benne található telepítőfájl neve: **`app-debug.apk`**.

### 2. Lépés: Az APK átvitele Android telefonra (ha PC-n töltötted le)
* **Közvetlen letöltés:** A GitHub mobil böngészőjéből közvetlenül a telefonra is letölthető.
* **Vagy átküldés:** Másold át USB-kábellel a telefon „Letöltések” (Downloads) mappájába, vagy töltsd fel Google Drive-ra / küldd el privát üzenetben.

### 3. Lépés: Ismeretlen forrásból származó alkalmazások engedélyezése
Mivel ez egy belső fejlesztői tesztverzió (nem a Google Play Áruházból származik), az Android rendszert engedélyezni kell a telepítéshez:
1. Koppints az `app-debug.apk` fájlra a telefon fájlkezelőjében (vagy a böngésző Letöltések listájában).
2. Ha a rendszer figyelmeztetést dob fel: *„Biztonsági okokból a telefon nem telepíthet ismeretlen alkalmazásokat ebből a forrásból”*:
   - Nyomd meg a **Beállítások** (Settings) gombot a felugró ablakban.
   - Kapcsold be az **„Alkalmazások engedélyezése ebből a forrásból”** (Allow from this source) kapcsolót.
   - Lépj vissza egyet.

### 4. Lépés: Telepítés és megnyitás
1. Nyomd meg a **Telepítés** (Install) gombot.
2. Ha a Google Play Protect rákérdez: válaszd a **„Telepítés mindenképpen”** (Install anyway) lehetőséget (a debug tanúsítvány belső tesztelésre szolgál).
3. A telepítés után nyomd meg a **Megnyitás** (Open) gombot.
4. A telefon alkalmazáslistájában és kezdőképernyőjén megjelenik a **Rescue Platform** ikon.

---

## 4. Kipróbálható Tesztfunkciók (Mock Módban)

A telepített alkalmazás azonnal használható internetkapcsolat nélkül is:

1. **Bejelentkezés:**
   - Nyomd meg a **„Gyors belépés (Mock fiók)”** gombot.
   - Automatikusan belépsz Kovács Péter profiljával a HUNOR Mentőszervezetbe.
2. **Kezdőlap és Rescue Coins:**
   - Megjelenik a műszerfal, az aktuális beosztás és a **120 RC** egyenleg.
3. **Multi-tenant Szervezetváltás:**
   - Koppints a fejlécben a `[HUNOR]` feliratra vagy nyisd meg a jobb felső menüt -> Szervezetválasztó.
   - Válts át a **Barlangi Mentőszolgálat (BMSZ)** szervezetre.
   - Figyeld meg az adatizolációt: a HUNOR adatai azonnal kiürülnek, és betöltődnek a barlangi mentőesemények és riasztások.
4. **Riasztási válaszadás:**
   - Nyisd meg a Riasztások menüt, kattints a riasztásra, majd válaszolj: *„Elérhető vagyok”* vagy *„Nem vagyok elérhető”*.
5. **Kijelentkezés és gyorsítótár-ürítés:**
   - A Profil oldalon nyomd meg a *„Kijelentkezés és gyorsítótár ürítése”* gombot. Minden helyi adat törlődik.

---

## 5. Biztonsági Ellenőrzés és Megfelelőség

- **Éles rendszerek védelme:** Az alkalmazás kizárólag a `MockRescuePlatformApi` osztályt példányosítja, hálózati kéréseket az éles Supabase adatbázis (`embicteneumubwlqqfik`) vagy az éles Netlify honlap (`hun01usar.hu`) felé nem indít.
- **Titkok és kulcsok:** Az APK forráskódja nem tartalmaz éles titkos API kulcsokat, adatbázis-jelszavakat vagy éles felhasználói adatokat.
- **Verziókezelés:** Minden módosítás a `gemini/005-mvp-stabilization-demo` fejlesztési ágon található, a `main` ág érintetlen.
