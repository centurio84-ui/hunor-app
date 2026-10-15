# HUNOR – Dinamikus menükezelő

## Közös adatmodell és jogosultság

Kanonikus Supabase: `embicteneumubwlqqfik`. Tábla: `public.navigation_tabs`.
A kért hat mező szerepel benne; az új sorok `is_visible` alapértéke false. A 18 meglévő webes/mobilos menü és oktatási aloldal kezdetben true, hogy a jelenlegi funkciók elérhetők maradjanak.

Az authenticated szerep olvashatja a táblát. INSERT/UPDATE/DELETE csak a jóváhagyott tagságú, adatbázisban tárolt adminszereppel rendelkező személynek engedélyezett. Az UPDATE mind USING, mind WITH CHECK feltételt tartalmaz. Az anon nem kap táblajogot vagy RPC EXECUTE-jogot. A szerveroldali, paraméter nélküli `navigation_access_context()` adja vissza az aktuális felhasználó ellenőrzött admin/tagsági állapotát. A private segédfüggvény nem fogad másik felhasználóazonosítót, üres search_path-ot használ.

A kapcsoló megjelenítési és útvonal-beengedési szabály. A meglévő adat-RLS és szerepköri engedélyek változatlanul szükségesek; a rejtés nem kapcsolja le az adott modul backend API-ját.

## Web

Belépés után az admin oldalsávjában **Menük kezelése**, közvetlenül: `/#navigation-settings`.
Az oldal sort_order/id szerint listáz, mentés alatt letiltja az adott kapcsolót, és szerverhiba esetén visszaállítja a jelölést. A védett adminmenü nem kapcsolható ki saját maga elől.

Az oldalsáv a tárolt címeket és sorrendet használja. Adminnak a rejtett menün **Rejtett** jelzés jelenik meg. Tagnál rejtve van és a route guard nem indítja el a modul betöltését. Ha az admin egy megnyitott tagi modult elrejt, tájékoztató oldalra vált. Hiányzó beállítás vagy betöltési hiba esetén a tagi útvonal zárt marad.

Az Oktatás szülőkapcsoló az oktatási aloldalakat is lezárja. Az EXCON meglévő külön joga megmarad. A lebegő chat buborék és annak megnyitó függvénye is a Csapat chat kapcsolóját követi. Vendégoldal és nyilvános kvíz nem kér hitelesített menükonfigurációt.

A hash-alapú útvonalak és a közvetlen `/logistics` jellegű utak is támogatottak; a Netlify SPA fallback az API átirányítások után szerepel.

Realtime: teljes tábla, is_visible szerveroldali szűrés nélkül. A true→false változás ezért nem marad a szűrésen kívül. Újracsatlakozáskor, ablakfókuszkor és visszatéréskor új lekérdezés történik. Felhasználóváltás/kijelentkezés üríti a konfigurációt és lezárja az előfizetést. A saját szerepkör és tagsági állapot változása is új ellenőrzést indít.

## Flutter

Repo: `centurio84-ui/hunor-app`, ág: `gemini/navigation-toggles`, a HUNOR Supabase-alapú main változatból. A Gemini külön `gemini/004-flutter-mvp-ui` mock alkalmazását nem írja felül, és nem köt rá éles írási joggal.

Új model/controller, admin kapcsolólista és NavigationGate; MultiProvider-bekötés; named-route védelem; rendezett, szűrt Drawer/NavigationRail/Bottom Navigation. Csak a mobilon már megvalósított oldalak kerülnek a navigációba. Rejtett aktív route helyén a védőkomponens tájékoztatót renderel, a korábbi oldalt eltávolítva. 5-nél több elérhető mobilmenü esetén Drawer jelenik meg a zsúfolt alsó sáv helyett. Adminnál külön, mindig elérhető menükezelő van.

A hibás régi alapértelmezett Supabase-projektazonosítót a kanonikus azonosítóra javítja. A kliens kizárólag publishable kulcsot használ; titkos kulcs nincs a változtatásban. A meglévő Firebase-konfiguráció továbbra is szükséges a mobilalkalmazás indításához.

## Ellenőrzés és korlátok

- Web build és JavaScript szintaxis ellenőrzés sikeres.
- Supabase: 18 sor, 4 RLS-szabály, Realtime-publication tagság, anon EXECUTE tiltás ellenőrizve.
- Hitelesített admin szereppel olvasási ellenőrzés: 18 sor, is_admin=true, is_approved_member=true. A lekérdezés rollbackelt tranzakcióban történt, adatváltoztatás nélkül.
- A Supabase security advisor nem jelzett a navigation objektumokhoz tartozó találatot. A projekt meglévő private quiz-táblás és Auth-figyelmeztetéseit ez a feladat nem módosítja.
- Nem adtunk hozzá vagy futtattunk automatizált teszteket. Helyben nincs Flutter/Dart SDK; a mobilos fordítás és készülékes Realtime-ellenőrzés nem történt meg. Nem készült vagy települt APK/IPA, és nincs main-merge.

A tábla egyetlen HUNOR-telepítés globális menükonfigurációja a kért sémával. A későbbi több szervezetet kiszolgáló backendben szervezetenként külön konfiguráció és tenant-RLS szükséges, ez a tábla nem használható több szervezet közös, szervezetazonosító nélküli tárolójaként.

Források: [Supabase Flutter stream](https://supabase.com/docs/reference/dart/stream), [Postgres Changes](https://supabase.com/docs/guides/realtime/postgres-changes), [RLS](https://supabase.com/docs/guides/database/postgres/row-level-security).
