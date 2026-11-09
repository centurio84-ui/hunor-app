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
