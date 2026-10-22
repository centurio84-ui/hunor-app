# CODEX-016 – mobil jogosultsági szerződés és RC-befagyasztás

Állapot: fejlesztési jelölt, nem éles kiadás. Alap: CODEX-014 `38626ef85816e3166a9d72a32ce3b37338342195`. A korábbi APK és ága megmarad.

## Változások

- A staging adapter a külön `GET /organizations/{org}/capabilities/me` végpont szerveres `allowed_actions` értékeit olvassa. A DTO szervezethez, tagsághoz és `permissions_version` értékhez kötött. Ismeretlen verzió/művelet vagy nem boolean érték tiltást jelent.
- Az admin UI nem következtethet a nyers `admin` permissionből. A backend minden parancsnál továbbra is önállóan ellenőriz; az itteni modell kizárólag megjelenítési korlát.
- A jelenleg telepített CODEX-013 API-n a végpont még hiányzik. Kizárólag a 404 ad kompatibilitási eredményt: a tagi olvasás működik, adminművelet nem engedélyeződik. 401/403 és más hibák nem esnek ebbe a visszaesésbe.
- Kijelentkezés és szervezetváltás törli a capability állapotot, a függő lekérés generáció-/tenantellenőrzött.
- RC nem jelenik meg a fejlécen, főoldalon vagy profilon, és az indulás nem kér egyenleget. A legacy `getCoinBalance`, DTO, mock adatok és API-teszt megmaradtak. Nincs adattörlés, pontozási vagy jutalmazási fejlesztés.

## Futtatás és ellenőrzés

A meglévő `.github/workflows/staging-android.yml` végzi a Flutter analyze/test ellenőrzést és a külön Android Debug APK buildet. Régi párhuzamos workflow-k ezen az ágon nem indulnak. Helyi Flutter SDK nem áll rendelkezésre; a tényleges CI-eredményt és artifactot a PR mutatja.

Tesztbővítés: DTO scope/version, ismeretlen jog/verzió, szöveges `true` elutasítása, régi API 404-kompatibilitás, 403 nem rejtése, RC végpontot nem kérő betöltés és RC-t nem mutató widget. A meglévő offline/riasztási és tenant tesztek megmaradtak.

## Telepítési határ

Az új backend végpont külön backend PR-ben szerepel, még nincs stagingre telepítve. A mobil új APK-ja a régi staginggel is tagi módban használható. Éles HUNOR, Supabase, Netlify, valódi riasztás és push változatlan. Eseményjelentkezés, hírkezelés és platform-szuperadmin még nincs megvalósítva; ezek nem kapnak hamis sikerjelzést.

A mobil ágnév a repository AGENTS.md által előírt `gemini/*` névteret követi; a munka CODEX-016 feladat.
