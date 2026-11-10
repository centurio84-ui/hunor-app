# Play belső tesztfrissítés – 1.0.1 (10002)

A projektvezető 2026-11-09-i külön engedélyével a Codex erre a konkrét feladatra módosítja a mobilkódot. Alap: Gemini PR #18 `06aa1455327748fade2fff687c6ab2dfb2c94667`; Android/aláírási referencia: korábban sikeres MADtech Play AAB, PR #17 `a5d970d59a6e275b0319decf06d839785af082d8`. A korábbi ágakat megőrizzük; nem merge-elünk.

- Az alkalmazás változatlan Play-azonosítója `hu.madtech.rescue`, meglévő aláírási titkokkal. Új kulcsot nem generálunk.
- Új verzió: **1.0.1 (10002)**; a korábbi, ismert 10001 verziókód újrafelhasználását a buildellenőrzés tiltja.
- Staging API: `https://xbcutdkqswfzkubkozng.supabase.co/functions/v1/rescue-platform-staging/v1`. Nincs éles HUNOR-belépés vagy adatkapcsolat.
- A friss Gemini esemény-/hírfunkciók megmaradnak. A 412 konfliktus nem tér vissza sikerként; a korábbi sikerüzenet ürül. Hiányzó/ismeretlen regisztráció és capability esetén a művelet tiltott. Az explicit kezdőcursor lapozáskor lecserélődik, nem duplázódik.
- Célzott modell-, API-, store- és widgettesztek: `test/widget/play_update_regressions_test.dart`.
- A korábbi, ellenőrzött release-eszközök és Flutter 3.47.9 újrahasznosítva; zárt Android namespace/applicationId/Activity, cleartext/backup tiltás, release-aláírás és tényleges AAB-manifest ellenőrzés.
- A meglévő Firebase-configot és a riasztási offline sort nem módosítjuk. A mobil push külön, későbbi feladat.

## Átadás és kiadási határ

A Google Play Release AAB Build workflow ezen az ágon kizárólag kézzel indítható és staging célra választható. A feladat aláírt AAB-artifactot és ellenőrzési bizonyítékot készít. **Google Play-feltöltést vagy publikálást nem végez**. Az AAB csak későbbi, külön jóváhagyás után kerülhet a meglévő alkalmazás belső tesztelési csatornájára. A régi alkalmazást és adatait nem töröljük.

A tényleges CI-, AAB- és aláírás-eredmények az ellenőrzés befejezése után kerülnek ide. A helyben futó 10 release-eszközteszt már sikeres; Flutter-ellenőrzés GitHub Actionsben szükséges, helyi SDK nincs beállítva.

## Ellenőrzött végeredmény – 2026-11-10

Az alkalmazáscsomag elkészült; **Google Play-feltöltés vagy publikálás nem történt**.

- Forrás: `f7eeca14fb0ab7a00ed1315d10e3aa082a8a9c5e`.
- [Sikeres aláírt AAB build](https://github.com/centurio84-ui/hunor-app/actions/runs/42680015882).
- [Sikeres általános Flutter CI](https://github.com/centurio84-ui/hunor-app/actions/runs/42680015843).
- Hibamentes analyze; **73/73 Flutter egység/widget teszt**, köztük 7 új célzott regresszió; **10/10 release-eszközteszt**.
- [AAB artifact](https://github.com/centurio84-ui/hunor-app/actions/runs/42680015882/artifacts/13703466122): `madtech-rescue-platform-staging-aab`.

### A tényleges fájl független helyi ellenőrzése

- Csomag: **hu.madtech.rescue**; versionName **1.0.1**, versionCode **10002**.
- Környezet: **staging**, a jóváhagyott elkülönített API-val. A CI buildparaméterei és a BUILDINFO egyeznek.
- Méret: 53178432 bájt.
- SHA-256: `e8a24ed412c99860d865dfa3a61f8c3bdf938a5c3d2a26f74ec83edeba64de0b`; a helyben kiszámított hash egyezik a CI-ével.
- ZIP CRC és Google bundletool validáció sikeres. A tényleges manifestben helyes package/verzió, INTERNET-jogosultság, nem debuggable release, backup/cleartext tiltás.
- Helyi JDK 17 jarsigner ellenőrzés sikeres; a publikus tanúsítvány SHA-256 értéke **egyezik a korábbi 10001 AAB upload-tanúsítványával**: `1657bd390ddd205adcab5e5e971dff63ba45f1a4b32c0861099ec415739c6bd3`. Új aláírókulcs nem készült; a CI-ben a meglévő keystore-egyezés is sikeres.
- Keystore/jks/key.properties nincs a csomagban. A tanúsítvány-ujjlenyomat publikus azonosító, nem titok.

Az első aláírt próbát a megtartott enforce-lockfile ellenőrzés állította meg. A Gemini lockjában hat Flutter SDK-hoz kötött csomag volt régebbi; kizárólag ezeket és az SDK alsó határát igazítottuk a korábban ellenőrzött 3.47.9-es release lockhoz. Alkalmazásfüggőségeket nem frissítettünk találomra. A második futásban az enforce-lockfile és a lock-diff ellenőrzés változatlanul sikeres.

A korábbi, elavult commit általános CI-je a friss commit érkezése után cancelled lett; a végső commit mindkét CI-je success. A formázási pipeline korábbról örökölt figyelmeztető módja nem minősül formázási megfelelés igazolásának; az analyze és a funkcionális tesztek sikeresek.

### Következő kiadási lépés

Ezt az **AAB-t** kell a már létező `hu.madtech.rescue` alkalmazás Google Play Console **belső tesztelési csatornájára** feltölteni, a szükséges külön jóváhagyás után. Nem kell új Play-alkalmazást létrehozni. Az AAB nem közvetlenül telefonra telepíthető APK. Az általános CI esetleges debug APK-ja nem helyettesíti a Play-frissítést; a Playből telepített alkalmazást és adatait ne töröljük.

A Play App Signing beállítását nem módosítottuk. A terjesztett frissítést a Google Play a meglévő alkalmazás aláírási rendjében adja ki. Tényleges Play Console-elfogadás és telefonos frissítési/megőrzési próba ebben a feladatban még nem történt; ezek a jóváhagyott feltöltés után ellenőrizhetők.

Telefonos ellenőrzés később: Play belső tesztfrissítés 1.0.1-re → meglévő fiktív staging belépés/session → friss eseményjelentkezés/visszavonás → hírek → offline/újracsatlakozás. Valós HUNOR-fiókot továbbra sem használunk a szintetikus stagingben.

### Gemini átadás

A mobilfejlesztés a konkrét engedélyezett átállítás után továbbra is a Gemini feladata. Ez a saját ág a Gemini PR #18 eredeti kódját őrzi meg alapként; az eredeti Gemini- és release-ágak nem módosultak. A további Play-tesztverzióknál ugyanez a package, meglévő aláírás, növekvő buildszám, explicit staging cél és aláírt AAB workflow legyen az alap. Új `hu.hunor.hunor_app` csomagot ne generáljunk Play-frissítésként.
