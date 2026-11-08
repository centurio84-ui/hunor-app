# CODEX-015 – MADtech Android release jelentés

## Hatókör

Kizárólag a külön codex/madtech-rescue-release-015 ág módosult. A kiindulás a korábbi sikeres Gemini release 086caf4949841dd803f9d8319220e837e3d21da8. A main, éles honlap, Supabase, RLS és Google Play változatlan.

## Változások

- Android Gradle, manifest, Activity és strings: hu.madtech.rescue package/namespace, MADtech Rescue indítónév, meglévő biztonsági beállítások.
- Három Dart megjelenítési cím: MADtech Rescue Platform. Üzleti logika, API-, token-, jogosultság- és adatkezelés nem módosult.
- pubspec: 1.0.0+10001; a függőségek deklarációi változatlanok, a referenciafolyamat tényleges lockja rögzítve és enforce-lockfile ellenőrzéssel védve.
- Release workflow és ellenőrző eszközök: meglévő release kulcs, kriptográfiai és manifest-ellenőrzés, SHA-256 és buildinformációk. Nincs Play-feltöltési lépés.
- HTTP 504 letöltési hibák: ugyanazok a hivatalos Gradle/Kotlin fájlok GitHub release API-n keresztül, rögzített ellenőrzőösszegekkel. TLS/aláírás/hash-ellenőrzés nem lett kikapcsolva.

Részletes fájl- és konfigurációs audit: [CODEX-015-MADTECH.hu.md](../release/CODEX-015-MADTECH.hu.md).

## Korlátok és további teendők

- Valódi telefonos, bejelentkezési vagy staging API funkcionális próba ebben a kiadási feladatban nem történt.
- Az új package külön Android-alkalmazás; a régi telepítés és adatai megmaradnak, az új appba új bejelentkezés kell.
- A változatlan Firebase-konfiguráció még a régi hu.hunor.app kliensé. Aktív natív FCM nincs a vizsgált kódban; későbbi bekötéshez valódi hu.madtech.rescue Firebase-regisztráció kell. Nem helyettesítettük fiktív adatokkal.
- A Play Console-ban az új package számára külön adatlap, hu-HU alapnyelv és manuális Internal Testing feltöltés szükséges. A felhasználó szerint ezzel a package-dzsel még nem volt feltöltés.
- A Draft PR #17 main felé workflow add/add konfliktust tartalmaz, mivel a main régebbi. Nem merge-eltük és másik ágat nem írtunk felül. A kiadást a saját ág pontos commitján futó kézi Actions ellenőrzi.

Draft PR: https://github.com/centurio84-ui/hunor-app/pull/17

## Végleges ellenőrzött eredmény – 2026. november 8.

- Sikeres teljes futás: https://github.com/centurio84-ui/hunor-app/actions/runs/42503577454
- Fordított commit: f419219fb25a8543ce477dd2669ba6282572ee38. Az ezt követő jelentéscommit csak dokumentációt módosít.
- Artifact: https://github.com/centurio84-ui/hunor-app/actions/runs/42503577454/artifacts/13627335120
- Név: madtech-rescue-platform-staging-aab. GitHub-bejelentkezés és repóhozzáférés szükséges; a megőrzés 30 nap.
- Tényleges AAB: hu.madtech.rescue; MADtech Rescue; 1.0.0 (10001); staging.
- AAB SHA-256: 463bad8f26abb45947ad514b0ac4de794386f6bb07d8128b44cf616cd8ba62c7
- Upload tanúsítvány SHA-256: 1657bd390ddd205adcab5e5e971dff63ba45f1a4b32c0861099ec415739c6bd3. Egyezik a meglévő release keystore tanúsítványával ÉS a korábbi sikeres referencia-AAB aláírójával.

| Ellenőrzés | Eredmény |
|---|---|
| 9 release konfigurációs/negatív Python-teszt | Sikeres |
| pub get --enforce-lockfile és lock változatlansága | Sikeres |
| flutter analyze --no-fatal-infos | Sikeres kilépés; 20 info szintű stílusjelzés, 0 warning/error |
| Flutter unit/widget tesztek | 63 sikeres |
| Android release appbundle | Sikeres, 53.2 MB |
| ZIP-integritás, JAR kriptográfia | CI-ben és helyben sikeres |
| Mind a 410 aláírt payload-bejegyzés release cert egyezése | Sikeres; debug signer elutasítva |
| Google bundletool validate és valódi manifest | CI-ben és helyben sikeres |
| Letöltött AAB SHA-256 egyezése | Sikeres |
| Valódi telefonos / bejelentkezési / API működési próba | Nem futott ebben a feladatban |

A jarsigner self-signed upload cert, hiányzó nyilvános bizalmi lánc és timestamp miatt figyelmeztet; a kriptográfiai ellenőrzés ettől sikeres. Az explicit release-keystore egyezés külön ellenőrzött. Nem állítunk publikus CA-hitelesítést vagy időbélyegzést.

A GitHub runner a korábbi action-verziók Node 20/Java setup elavulásáról is figyelmeztetett; nem blokkolta a futást. Ezek frissítése külön karbantartásként végezhető, az elkészült AAB megváltoztatása nélkül.

### Letöltés és továbblépés

1. A fenti artifact linkjén a GitHub ZIP-et töltsd le, majd bontsd ki.
2. A ZIP-ben lévő app-release.aab és SHA256SUMS.txt együtt tartozik az ellenőrzött kiadáshoz.
3. Az AAB Google Play feltöltési csomag, nem közvetlenül telepíthető APK. Ebben a feladatban nem történt sem Play-feltöltés, sem publikálás.
4. A következő kézi lépés a megfelelő Play Console app Internal Testing kiadásának előkészítése, a fenti konfigurációs korlátok figyelembevételével.

A feladat lezárva: az ellenőrzött staging AAB letölthető. Nincs merge, production telepítés vagy adatbázis-módosítás.
