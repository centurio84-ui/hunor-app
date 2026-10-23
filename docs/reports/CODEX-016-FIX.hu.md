# CODEX-016-FIX – APK letöltés és LDPlayer

## Igazolt eredeti állapot

- Privát repó: centurio84-ui/hunor-app. A GitHub-bejelentkezés és olvasási jogosultság szükséges; egy nem bejelentkezett böngészőben a letöltés hibát adhat.
- CODEX-016 eredeti commit: 10a642b691aae795880b6379e2e9660d8776cfc3, sikeres build: https://github.com/centurio84-ui/hunor-app/actions/runs/39835025351 .
- Eredeti artifact: https://github.com/centurio84-ui/hunor-app/actions/runs/39835025351/artifacts/12451860035 . A vizsgálatkor érvényes; lejárat 2026. november 5. 20:02 CET. A 14 napos retention nem tartós kiadási hivatkozás.
- Hitelesített gh letöltés sikeres. Az APK SHA-256 értéke egyezik a build ellenőrzőösszegével: c4b1e2bad680a9360c4a61de84d8a7064230b84b1801e2c23e0d72775cdf3a1a.
- Hivatalos Android apksigner, aapt és ZIP CRC ellenőrzés: mindkét eredeti APK érvényes. Sikeres diagnosztikai futás: https://github.com/centurio84-ui/hunor-app/actions/runs/39977356980 . Az első jelentésparser-futás formátumhiba miatt sikertelen volt; a javított futás sikeres, nem az APK hibáját találtuk.

## Adatmegőrzést akadályozó aláíráskülönbség

| Tulajdonság | CODEX-014 | Eredeti CODEX-016 |
|---|---|---|
| applicationId | hu.rescue.staging.hunor_app | hu.rescue.staging.hunor_app |
| versionCode | 1 | 1 |
| tényleges minimum Android SDK | 24 | 24 |
| ABI | arm64-v8a, armeabi-v7a, x86_64 | arm64-v8a, armeabi-v7a, x86_64 |
| Aláíró cert SHA-256 | f71a4f9b5445637c7a31de23bbec3009a53e0733eb33d521d531068e568f1331 | 15e4c261338a9be92ae291e4959c18beab772ebe14afcb3cbddaaab707e2b728 |

Az aláíró eltérése miatt az eredeti CODEX-016 nem használható a CODEX-014 helyben frissítésére. Nem töröljük a régi alkalmazást, annak adatait vagy az emulátort. A külön csomag külön adattárat kap; a régi bejelentkezés és offline sor nem másolódik át automatikusan.

## Javítás

Külön tiszta CI-build ugyanarra a CODEX-016 alkalmazáskódra: applicationId hu.rescue.staging.hunor_app.codex016, név Rescue 016 Test, versionCode 16. Kizárólag a staging API-hoz kapcsolódik; nincs titkos kulcs a csomagban. A változás a CI-ben létrehozott Android-burkolatot érinti, az üzleti logika változatlan. A régi alkalmazás mellett telepíthető, eltávolítás nélkül. Nincs production build vagy éles telepítés.

## Letöltési figyelmeztetések: bizonyított és nem bizonyított

- Lejárt CODEX-016 artifact, sérült eredeti APK vagy hibás Android-aláírás a vizsgálatkor nem igazolódott.
- A felhasználó pontosította a Chrome üzenetét: „Veszélyes fájl” / „Veszélyes letöltés letiltva”. Ezt konkrét felhasználói hibajelzésként kezeljük; önálló Chrome-reprodukció és a Google belső besorolásának indoka nem áll rendelkezésre. Az ismeretlenül terjesztett APK kaphat reputációs figyelmeztetést, de ebben az esetben nem bizonyított, hogy csak erről van szó. Nem kezeljük automatikusan téves riasztásként. SmartScreen-blokk vagy konkrét Defender-fenyegetés nem igazolódott.
- A helyi Defender AntivirusEnabled és RealTimeProtectionEnabled értéke true volt. A célzott fájlvizsgálat hibával zárult (MpCmdRun 0x80508023); nem állítunk sikeres malware-vizsgálatot. Hash és Android-aláírás ellenőrzése nem helyettesít vírusellenőrzést.
- Nem kapcsoltunk ki védelmet, nem adtunk Defender-kivételt, nem használtunk jelszavas ZIP-et vagy hamis kiterjesztést. A gh letöltés a felhasználó által kért, hitelesített alternatíva; nem oldja fel vagy kapcsolja ki a Chrome tiltását.

## LDPlayer megfigyelés

Az LDPlayer9 példány elindult, de „System UI isn't responding” ablakot mutatott; az ADB-eszköz nem vált elérhetővé. Várakozás után az általunk indított lefagyott példányt a gyártó CLI-jével bezártuk, eltávolítás vagy adattörlés nélkül. Biztonsági/ADB-beállításokat nem lazítottunk. Ez önálló emulátorhiba, nem az APK aláírási hibájának következménye. A tényleges telepítési eredményt külön rögzítjük; nem állítjuk, hogy a metaadat-egyezés teljes emulátoros átvétel.

## Függőségek és buildbiztonság

Az eredeti CI-ben archivált tényleges pubspec.lock 105 hosted függőségét a hivatalos pub.dev verziómetaadataival és aktuális advisories végpontjával összevetettük. Mind a 105 archive_sha256 egyezik; nincs lekérdezési hiba, és az adott verziókra nincs aktív, közzétett érintettség. A lockfileban minden hosted csomag pub.dev-forrású. A vizsgálat nem natív Maven/Gradle audit és nem malware-mentességi igazolás. Reprodukálható segéd: tool/verify_pub_supply_chain.mjs; bemenet az adott build artifactjából származó lockfile.

A staging entrypoint explicit staging/mock adaptert választ; nincs Firebase/Supabase éles inicializálás a main függvényben. A bennmaradt legacy push service nem kap induláskori hívást. Nincs talált TLS tanúsítványellenőrzést kikapcsoló badCertificateCallback vagy letöltött kódot futtató Process.run a lib forrásokban. A manifest allowBackup=false és usesCleartextTraffic=false beállítást kap. Ezek célzott forrásellenőrzések, nem teljes programbiztonsági bizonyítékok.

A meglévő buildben: Flutter 3.35.7 rögzítve, pubspec.lock verziózott, artifacts SHA-256 mellékelve, jogosultság contents:read. Nem állítunk bájtra reprodukálható buildet: a debug kulcs futásonként változik, az ubuntu-latest és JDK 17 javítóverzió nincs teljesen rögzítve, az Android-burkolat generálódik és a GitHub Actions v4/v2 címkék mozgathatók. Jövőbeli kiadási fejlesztés: ellenőrzött SHA-ra rögzített Actions/SDK/Gradle, enforce-lockfile, natív dependency verification/SBOM, elkülönített és tartós tesztaláírás biztonságos titoktárral. A hiányosságok nem igazolnak fertőzést, de a teljes reprodukálhatósági állítást kizárják. Éles aláírókulcsot nem használunk és nem hoztunk létre.

## Hivatalos források

- [GitHub artifact letöltés és jogosultság](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/download-workflow-artifacts)
- [Chrome letöltési figyelmeztetések](https://support.google.com/chrome/answer/6261569?hl=hu)
- [Android APK-aláírás](https://source.android.com/docs/security/features/apksigning)
