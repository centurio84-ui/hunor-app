# Rescue 016 Test – Windows + LDPlayer

## Letöltés

1. Lépj be a GitHubra azzal a fiókkal, amely hozzáfér a privát hunor-app repóhoz.
2. Nyisd meg a [CODEX-016 tesztkiadást](https://github.com/centurio84-ui/hunor-app/releases/tag/codex016-test-20261023).
3. Az **Assets** résznél töltsd le a **Rescue-Platform-CODEX016-Test.apk** fájlt. Ez már az APK, nem kell kicsomagolni. A Source code ZIP nem telepíthető alkalmazás.

A tesztkiadás a privát repóban marad. Az Actions-artifacttal ellentétben a Release-eszköznek nincs a buildben beállított 14 napos artifact-lejárata; a kiadás visszavonható vagy törölhető.

## Telepítés – a régi alkalmazás megmarad

1. Indítsd el az LDPlayer 9-et, és várd meg az Android kezdőképernyőt.
2. A jobb oldali eszköztáron kattints az **APK telepítése** ikonra. Az LDPlayer megfelelő verzióiban a **Ctrl+3** is ezt nyitja meg.
3. Válaszd ki a letöltött **Rescue-Platform-CODEX016-Test.apk** fájlt.
4. Telepítés után a **Rescue 016 Test** ikont nyisd meg. A régi **hunor_app** alkalmazást ne töröld.
5. Az új alkalmazásban külön jelentkezz be a kapott **fiktív staging tesztfiókkal**. Ne az éles HUNOR-fiókot használd. A régi app belépése és adatai nem kerülnek át.

Ez külön tesztalkalmazás, nem a régi fölé települő frissítés. Csomagazonosító: **hu.rescue.staging.hunor_app.codex016**. Minimum Android 7.0 / SDK 24; x86_64 és ARM támogatás. A tényleges LDPlayer-állapotot az ellenőrzési jelentés tartalmazza.

## Ha blokkolja a letöltést

- Ne kapcsold ki a Chrome Safe Browsingot, a Defendert vagy a SmartScreent. „Veszélyes fájl” esetén ne hagyd figyelmen kívül automatikusan a jelzést.
- **404 / Not found / nincs jogosultság:** először ellenőrizd a GitHub-belépést és a privát repóhoz való hozzáférést. A privát APK-link önmagában nem ad hozzáférést.
- **Biztonsági figyelmeztetés:** jegyezd fel a pontos szöveget. A figyelmeztetés típusa nélkül nem állapítható meg az oka. A hash/aláírás nem igazolja önmagában a malware-mentességet.
- Biztonságos alternatíva a repóhoz már hitelesített GitHub CLI letöltése, változatlan védelem mellett. Technikai segítő használhatja: `gh release download codex016-test-20261023 --repo centurio84-ui/hunor-app --pattern Rescue-Platform-CODEX016-Test.apk`. Ez nem old fel Chrome-figyelmeztetést. A helyben már letöltött és ellenőrzött példányból programozás nélkül telepíthetsz.

## Ha az LDPlayer nem válaszol

„System UI isn't responding” esetén ne távolítsd el a régi alkalmazást vagy az emulátorpéldányt. Először normál módon zárd be, majd indítsd újra az LDPlayert. Ha a hiba visszatér, az emulátor állapotát kell rendezni a telepítés előtt. Nem szükséges a Windows biztonsági védelmének kikapcsolása.

## Opcionális ADB-telepítés, kizárólag ellenőrzött APK-val

Ez csak akkor használható, ha az aláírás/hash ellenőrzése megfelelő, a biztonsági jelentés nem jelez nyitott malware-problémát, és az LDPlayer működő ADB-eszközként elérhető. Ha továbbra is „veszélyes fájl” jelzés van vagy a vizsgálat nem fejeződött be, ne használd a figyelmeztetés megkerülésére.

PowerShellben először:

```powershell
& "C:\LDPlayer\LDPlayer9\adb.exe" devices
```

Ha a listán az `emulator-5554` mellett `device` áll, a külön tesztcsomag telepíthető:

```powershell
& "C:\LDPlayer\LDPlayer9\adb.exe" -s emulator-5554 install -r "$env:USERPROFILE\Downloads\Rescue-Platform-CODEX016-Test.apk"
```

Más eszközazonosító esetén azt kell megadni. Üres lista, `offline` vagy `unauthorized` esetén állj meg; ne oldj fel hálózati ADB-t és ne módosíts Windows-biztonsági beállításokat emiatt. Siker esetén a válasz `Success`. `INSTALL_FAILED_UPDATE_INCOMPATIBLE` esetén ne töröld a régi appot: ellenőrizni kell, hogy valóban a külön CODEX016-Test APK-t választottad-e. A parancs nem tartalmaz eltávolítást vagy adattörlést.

## Ellenőrzőösszeg

A kiadás **SHA256SUMS.txt** fájljában szerepel a pontos SHA-256 érték. Windows PowerShellben opcionálisan ellenőrizhető:

```powershell
Get-FileHash "$env:USERPROFILE\Downloads\Rescue-Platform-CODEX016-Test.apk" -Algorithm SHA256
```

Az APK-aláírás és a csomagazonosító ellenőrzésének eredménye az **APK-SIGNATURE.txt** és **APK-PACKAGE.txt** fájlban található. A debug aláírás tesztelésre készült, nem Play Áruház-kiadás.
