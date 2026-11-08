# MADtech Rescue Platform – Android release előkészítés (CODEX-015)

## Hatókör és kiindulás

A projektvezető külön utasítása engedélyezi ezt a korlátozott mobilos márkázási és kiadási feladatot. Külön ág: codex/madtech-rescue-release-015. A sikeres referencia: gemini/rescue-release-002, 086caf4949841dd803f9d8319220e837e3d21da8, Actions run 42457857056. Ennek működő API-, jogosultság-, esemény-, hír-, téma- és tokenkezelése marad a kiindulás.

A main ág korábbi mobilállapotot tartalmaz. A main felé kért PR emiatt a referencia release-ág korábbi, még nem merge-elt változásait is mutatja. A jelen feladat saját commitjai kizárólag az itt felsorolt márkázást, Android-konfigurációt, teszteket és kiadási ellenőrzést adják hozzá; másik ág nem lett felülírva vagy merge-elve.

## Azonosítók és fájlok

- Google Play név: MADtech Rescue Platform; telefonos név: MADtech Rescue.
- Package ID és namespace: hu.madtech.rescue.
- Márka: MADtech; anyamárka: MAD – Moldován András Division; termék: Rescue Platform.
- Verzió: 1.0.0+10001. Az internal testing feltöltés előtti versionCode-ütközést a Play Console-ban ellenőrizni kell; ebből a feladatból nem történik Play-feltöltés.
- Belső Flutter package: hunor_app (változatlan).
- Android app/build.gradle.kts: explicit package/namespace, meglévő minSdk23/targetSdk36 és release signing. Debug aláírás nem helyettesítheti a release kulcsot.
- AndroidManifest.xml, MainActivity.kt, values/strings.xml: alkalmazásnév és teljesen minősített új Activity; backup=false, cleartext=false és internetjog megmarad.
- A flutter create továbbra is előállítja a hiányzó platformhéjat. A verziókezelt natív fájlokat használja; a tool/release/check_android_branding.py utána ellenőrzi az eredményt. Kizárólag az ismert, változatlan generált extra MainActivity-stub távolítható el; egyedi natív kód esetén leáll.
- Dart: csak MaterialApp-title, bejelentkezési cím és a szervezetnév hiányában mutatott fallback márkanév változik. Az üzleti kód, API-k, modellek, Supabase-konfiguráció és jogosultságok változatlanok.
- pubspec: leírás és verzió; a deklarált függőségek változatlanok. A lockfile a referenciafolyamat ténylegesen feloldott állapotára rögzítve, az alábbi diagnosztika szerint. Magyar felületi szövegek megmaradnak. A Play-adatlap alapnyelvét kézzel hu-HU-ra kell állítani; az Android launcher neve nem módosítja automatikusan a Console adatlapját.

## Release workflow

A meglévő Google Play Release AAB Build workflow kézi staging/production bemeneteit megtartja. Kizárólag staging futtatás engedélyezett ebben a feladatban. A production mód továbbra is jóváhagyott külön API-címet igényel, nincs staging/mock fallback; a korábban beépített, még nem jóváhagyott production adaptert elutasító Dart-guard változatlan. Ez a kiadás nem production-kész mobilalkalmazás.

Flutter: a sikeres referencia 3.47.9 verziójára rögzítve. JDK17. pub get --enforce-lockfile, analyze --no-fatal-infos (a referencia szabálya), flutter test és release appbundle build fut. A GitHub Secrets értékei a lépések környezetében maradnak, shell forrásba interpolált titkok és naplózott kulcsok nélkül. Új release kulcs nem készül.

Ellenőrzések: unzip integritás; jarsigner kriptográfiai ellenőrzés; JDK JarFile-ellenőrzés minden aláírandó bejegyzésen, a tényleges aláíró leaf cert byte-pontos összevetése a release keystore tanúsítványával; Android Debug tanúsítvány tiltása; lejárati ellenőrzés. A self-signed upload cert PKI-figyelmeztetése nem egyenlő hibás JAR-aláírással. A részletes JSON külön rögzíti a fingerprintet és az ellenőrzési eredményt.

Google bundletool 1.18.3, hivatalos release, rögzített SHA-256: a099cfa1543f55593bc2ed16a70a7c67fe54b1747bb7301f37fdfd6d91028e29. A bundle validate és a tényleges AAB manifest dump alapján a package, Activity, versionCode, versionName, backup/cleartext/debuggable ellenőrzött.

Artifact: madtech-rescue-platform-staging-aab. Tartalma: app-release.aab, SHA256SUMS.txt, BUILDINFO.json, SIGNATURE-VERIFICATION.json, jarsigner-verification.txt és AndroidManifest.verified.xml. Keystore, key.properties, jelszó nem kerül artifactba. A signing fájlok az always cleanup lépésben törlődnek a runneren.

## Firebase, OAuth és API-audit

A meglévő google-services.json a hunor-b2776 projekt hu.hunor.app Android-kliensét írja le. Nem írtuk át a package_name mezőt: ez nem regisztrálna valódi új Firebase-alkalmazást. A fájl változatlan. A jelenlegi lib/ nem importál vagy inicializál Firebase-t, és a PushNotificationService jelenlegi implementációja mock. A release referencia workflow generált Kotlin Android-héja nem kapcsolt be Google Services Gradle plugint. Nem állítjuk, hogy natív FCM működik ebben a kiadásban, és nem kapcsoltunk ki működő FCM-t.

FCM/Google szolgáltatás későbbi aktiválásához a Firebase tulajdonosnak hu.madtech.rescue package ID-val valódi Android-appot kell regisztrálnia ugyanabban vagy jóváhagyott másik projektben, a megfelelő google-services.json-t biztosítania, és szükség szerint az upload/Play App Signing tanúsítványok SHA-1/SHA-256 lenyomatait felvennie. Google OAuth nincs aktívan használatban a vizsgált Dart-kódban. Jelenlegi deep link/callback nincs a release Android-manifestben; újat nem találtunk ki. A meglévő staging HTTPS API, tokenvault és jogosultságkezelés változatlan.

Az új applicationId új Android-appnak számít: nem frissíti helyben a korábbi hu.hunor.* telepítést, és annak adatait nem törli. Az új app új sandboxot/secure storage-t kap, új bejelentkezés szükséges. A Play Console-ban külön appbejegyzés kell ehhez a package ID-hoz; a korábbi csomagnév kiadása nem nevezhető át erre frissítésként.

## Ellenőrzési állapot

Helyben a kilenc Python release-konfigurációs/negatív teszt és a Java verifier JDK17 fordítása sikeres. Flutter SDK nincs a Windows PATH-on; a valós pub/analyze/test/AAB vizsgálatot a GitHub Actions végzi. Az eredményeket a build végén frissítjük; a folyamat elindítása még nem sikeres AAB-bizonyíték.

Nem futott valódi bejelentkezési/API-/telefonos teszt, nem változott adatbázis, RLS, éles rendszer vagy Google Play-beállítás. Nincs automatikus merge vagy Play-feltöltés.

## Hivatkozások

- Android applicationId és namespace: https://developer.android.com/build/configure-app-module
- Flutter Android kiadás: https://docs.flutter.dev/deployment/android
- Rögzített bundletool: https://github.com/google/bundletool/releases/tag/1.18.3

### Gradle-letöltési hiba kezelése

A 42467663319 run első két próbája a fordítás előtt HTTP 504 hibát kapott a Gradle 9.3.1 all disztribúció GitHub-letöltésére. A kiadás ezért a változatlan 9.3.1 verzió hivatalos bin disztribúcióját rögzíti (b266d5ff6b90eada6dc3b20cb090e3731302e553a27c5d3e4df1f0d76beaff06). A CI curl újrapróbálással tölti le, SHA-256-tal ellenőrzi, majd csak a hash-azonos helyi archívumot adja a wrappernek. TLS- és hash-ellenőrzés nem lett kikapcsolva. A forrásban továbbra is a hivatalos HTTPS URL marad; a file URL csak az ideiglenes runneren keletkezik. A flutter create --no-pub után enforce-lockfile és git diff ellenőrzi, hogy a pubspec.lock sem változik.

### További ellenőrzési bizonyítékok

A felhasználó megerősítette, hogy hu.madtech.rescue csomagnév alatt még nem volt Play-feltöltés, ezért az 10001 buildszám marad. A referenciából letöltött AAB SHA-256-ja egyezik a korábbi futásban közölt fd0557dd67dd1a80b5874120606553f8f7dfa36c04795ec6c36c5ba19318e50a értékkel. Nyilvános upload tanúsítványának SHA-256-ja: 1657bd390ddd205adcab5e5e971dff63ba45f1a4b32c0861099ec415739c6bd3.

A Java verifier helyi kriptográfiai pozitív tesztje a referencia-AAB-val sikeres. Ehhez kizárólag a referencia nyilvános tanúsítványából készült lokális certificate-only teszttárat használtam, privát kulcs vagy új aláírókulcs nélkül. A reference archívum fiktív módosított másolatával a negatív próba sikeres: az ellenőrző a digest-eltérést elutasította. A módosított tesztarchívum nem kiadási artifact.

A main felé a GitHub jelenleg kizárólag .github/workflows/release-aab.yml add/add konfliktust jelez. A main három eltérő commitja csak ezt a fájlt érinti. A PR Draft marad; nem hajtottam végre merge-et vagy másik ág felülírását. A teljes release-teszt a saját commit kézi Actions-futtatásában fut, nem feltételezett PR-ellenőrzésként.

### Lockfile-eltérés és reprodukálható javítás

A régi forrás-lock 109 csomagot rögzített, miközben a referencia release workflow a platformgenerálás utáni pub get során 114 csomagot használt. Ezt a szigorú --enforce-lockfile leplezte le: a korábbi folyamat észrevétlenül feloldotta a fájlt a build közben. A 42468667995 titkok nélküli diagnosztika reprodukálta a sikeres referencia sorrendjét és kiadta az aktuális 114 csomagos lockot. A korábbi referencia naplójában megjelenő, ellenőrizhető csomagverziók közül egy sem tér el. A teljes korábbi runtime lock nem volt a régi artifact része, ezért nem állítjuk, hogy 114/114 korábbi verziót közvetlenül visszaolvastunk.

A tényleges feloldott lock most verziókezelt; a meglévő pubspec függőségdeklarációkat nem írtuk át. A flutter create --no-pub körül a forrás-lock mentése/visszaállítása történik, majd pub get --enforce-lockfile és git diff --exit-code ellenőrzi a változatlanságot. Az ideiglenes diagnosztikai workflow a vizsgálat után eltávolítva. A változásfüggő funkciókat az eredeti teljes Flutter-tesztsorral újra ellenőrzi a végső release build.

A 42468823682 futásban minden teszt és a zárolt függőségek ellenőrzése sikeres; a Kotlin 2.2.21 compiler letöltése HTTP 504-et kapott. Az azonos hivatalos JetBrains JAR előtöltése SHA-256 és Maven Central SHA-1 ellenőrzéssel történik a Gradle tartalomcímzett gyorsítótárába. Verzió és repository-jogosultság nem változik.

A 42503133653 futás tényleges fordítási hibát mutatott: az AGP 9 alatt a legacy kotlin-android/kotlinOptions már elutasított. A konfiguráció a használt Flutter 3.47.9 hivatalos sablonját követve beépített Kotlinra és compilerOptions JVM_17-re vált; minSdk/targetSdk, signing és üzleti kód változatlan. Forrás: https://github.com/flutter/flutter/blob/3.47.9/packages/flutter_tools/templates/app/android-kotlin.tmpl/app/build.gradle.kts.tmpl
