# CODEX-014 – Android staging tesztalkalmazás

## Rendeltetés

Ez kizárólag fiktív szervezetekkel használható Android tesztverzió. Nem kapcsolódik az éles HUNOR rendszerhez, nem küld valódi riasztást vagy push üzenetet. Kiindulása a változatlan GEMINI-005 PR #7 (`8517af94ec0c6f2b0a386f2cd348d87007f0ee0f`). A felméréskor GEMINI-006 ág és PR nem volt elérhető.

Ág: `codex/014-flutter-staging-integration`. A külön CODEX-014 workflow elemzést, Flutter-teszteket és Android Debug APK-t készít. A meglévő Gemini buildfolyamatok ezen az ágon nem készítenek párhuzamos mock/iOS kiadást.

## Letöltés és telepítés

1. GitHub → `centurio84-ui/hunor-app` → Actions → **CODEX-014 Android staging** → legutóbbi **sikeres** futás ezen az ágon.
2. Az Artifacts részből töltsd le a **rescue-platform-staging-android-debug** csomagot. GitHub-bejelentkezés szükséges lehet. Az artifact 14 napig őrződik; lejárat után új futás szükséges.
3. Csomagold ki: `app-debug.apk`, `SHA256SUMS.txt`. A hash-t hasonlítsd össze a futás eredményével.
4. Másold az APK-t Android telefonra, és nyisd meg. Ha a rendszer kéri, kizárólag a telepítéshez használt fájlkezelőnek/böngészőnek engedélyezd az alkalmazástelepítést, utána kapcsold vissza a tiltást. Android 6/API 23 vagy újabb szükséges.
5. Ez külön alkalmazásazonosítót használ: `hu.rescue.staging.hunor_app`. Debug aláírású tesztkiadás, nem Play Store termék. Más runneren készült debugkulcs esetén a régi tesztverziót előbb el kell távolítani; ezzel a helyi session és válaszsor is törlődik. Előtte szinkronizálj vagy tudatosan vesd el a várakozó válaszokat.

## Belépés

A bejelentkezőn **STAGING – kizárólag fiktív tesztfiókok** jelzés látszik. A staging APK-ban nincs mock gyorsbelépés és nincs beépített jelszó.

| Fiók | Tesztelhető hatókör |
|---|---|
| member@example.invalid | A fiktív szervezet |
| admin@example.invalid | A adminja; riasztáskiadás nincs bekötve |
| other@example.invalid | B fiktív szervezet |
| dual@example.invalid | A és B, szervezetváltás |
| revoked@example.invalid | Beléphet, de nincs jóváhagyott A-tagsága |

A jelszavakat a projektgazda adja át külön biztonságos csatornán. A CODEX-012 létrehozás helyi, védett hitelesítő állományában vannak; nem a GitHubon vagy az APK-ban. Éles felhasználói fiókot ne használj.

API base: `https://xbcutdkqswfzkubkozng.supabase.co/functions/v1/rescue-platform-staging/v1`.

## Ellenőrzési menet a telefonon

1. Belépés → saját profil, szervezet, események, tesztriasztások és RC egyenleg. A tag A fiktív kezdőegyenlege 120 RC.
2. A `dual` fiókkal válts szervezetet. A régi szervezet képernyőadatai azonnal ürülnek, és a másik tenant adatai töltődnek be.
3. Nyiss aktív tesztriasztást és adj részvételi választ. Szerveres 200 válasz után jelenik meg a megerősítés.
4. Előbb online töltsd be a riasztást (a szerver aktuális válaszverziója ekkor ismert). Kapcsold ki a hálózatot és adj választ. A felület **szerveres megerősítésre vár** állapotot mutat, nem kész szerveres mentést.
5. Kapcsold vissza a hálózatot és nyomj Szinkronizálást. Az aktív alkalmazás várakozó, nem blokkolt válaszait 30 másodpercenként és előtérbe visszatéréskor is próbálja küldeni. Ha nincs ilyen válasz, nincs automatikus lista-polling. Háttérben/bezárt appnál nincs garantált szinkronizálás.
6. Offline, korábban be nem töltött riasztásra nem talál ki verziót és nem ad hamis visszajelzést. Előbb online betöltés kell.
7. 409/412 esetén a sor blokkolódik és a kód látszik. Vizsgáld meg a szerver állapotát; az Elvetés csak a helyi sort törli, a már esetleg szerverre jutott választ nem vonja vissza. Új döntéshez frissítsd a listát, és adj új választ.
8. Kijelentkezéskor a helyi session, minden fiókhoz kötött válaszsor és cache törlődik. Offline logout helyben végleges, szerveres visszavonás csak elérhető hálózattal biztosítható. Másik belépéskor régi sor soha nem kerül másik fiók alá.

A CODEX-012 tesztriasztások hétnapos határidővel készültek. Lejáratkor a 409 helyes viselkedés; új staging fixture-t ellenőrzött külön műveletként lehet létrehozni. A szerver v0.2 `going` / `not_going` értékeket kap. A nyugtázást a szerver a részvételi válasz részeként is rögzíti; push receipt nincs bekötve.

## Biztonsági megvalósítás

- HTTPS és pontos staging URL engedélylista; HTTP, éles cím, átirányítás nem használható. Androidon cleartext és alkalmazásbackup tiltott.
- Tokenek és tartós válaszsor: `flutter_secure_storage`, Android Keystore-alapú titkosított tároló; iOS-en készülékhez kötött Keychain opció előkészítve. iOS build és fizikai iPhone-próba nem része ennek az átadásnak.
- Bearer token minden üzleti kérésnél. Egyszeres, összevont tokenfrissítés 401 után; sikertelen hitelesítéskor törlés, nincs mock fallback.
- A szerver ellenőrzi a sessiont, tagságot és jogosultságot. A kliens UI-szerepköre nem ad hozzáférést.
- A sor eleme user+organization+alert+eredeti version+UUID idempotency key+eredeti body. Bizonytalan hálózati válasz után ezek változatlanul mennek újra. Nem állítunk garantált egyszeri hálózati kézbesítést.
- 24 óra után nincs automatikus újraküldés új kulccsal. A session/szervezet generációs védelem elutasítja a későn visszaérkező régi kéréseket.
- Nincs DB-jelszó, service-role, cursor secret vagy tesztjelszó a kódban, a define-okban és a build artifactban.

Nem támogatott: valódi riasztáskiadás, push, profil/készség/riaszthatóság szerkesztése, esemény-CRUD és eseményjelentkezés. Stagingben ezek nem írhatnak hamis helyi sikert; a profil olvasható, az eseményeknél tájékoztató jelenik meg. A taglista nem helyettesítő mock adatokból áll: ebben az első tesztverzióban nincs staging taglistanézet.

## Reprodukálás

Flutter **3.35.7**, Java **17**. A workflow Android platformgenerálást, API 23 minimumot, HTTPS/backup szabályokat és APK checksumot tartalmaz.

```sh
flutter pub get
flutter analyze --no-fatal-infos
flutter test --reporter expanded
flutter build apk --debug --dart-define=RESCUE_API_MODE=staging --dart-define=RESCUE_API_BASE_URL=https://xbcutdkqswfzkubkozng.supabase.co/functions/v1/rescue-platform-staging/v1
```

A teljes Android shell előkészítést a `.github/workflows/staging-android.yml` szerint kell végrehajtani. Mock fejlesztői mód külön build: `--dart-define=RESCUE_API_MODE=mock`. A mód nem váltható át automatikusan hálózati hiba miatt. A szerződéses adaptertesztek izolált HTTP-helyettesítőt használnak; a sikeres fordítás nem helyettesíti a fenti fizikai telefonos átvételt.
