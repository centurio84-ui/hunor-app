# CODEX-001 – technikai audit

**Dátum:** 2026. október 14. · **Állapot:** felmérés, nem biztonsági tanúsítvány.

**Repo:** `centurio84-ui/hunor-app` (privát). **Vizsgált main commit:** `6b47f52f531ff00f20e6ea88b08a44047f8e0b74` (2026-09-20). **Munkaág:** `codex/initial-audit`.

## 1. Hatókör és bizonyítékok

- **R – repozitórium:** a rögzített commit teljes, nem csonkolt fája; mind az 50 fájl letöltve és Git blob SHA-1 alapján ellenőrizve. Teljes lista: [repository-inventory.md](repository-inventory.md).
- **L – élő, csak olvasott katalógus:** a weboldalhoz tartozó `embicteneumubwlqqfik` projekt táblái, oszlopai, RLS/policy/metaadatok, kiválasztott függvénydefiníciók, Edge Function forrás és security advisor. Tagok rekordjait, egészségügyi adatait, jelszavait és készüléktokenjeit nem kértük le.
- **W – nyilvános webes csomag:** `https://hun01usar.hu/index.html`, `supabase-app.js`, `manifest.webmanifest` HTTP GET. Mindhárom bájtra egyezett a helyi, korábban kiadott `20261014-birthday-alerts-9` csomaggal. Ez kiegészítő bizonyíték, **nem a repo része**.
- **C – CI:** a vizsgált main commit meglévő GitHub Actions eredményei; nem újrafuttatott készülékteszt.
- **J – javaslat:** az új architektúra és OpenAPI fájl teljes egészében tervezet, nem jelenlegi API.

Nem történt main-módosítás, Netlify-kiadás, adatbázis-írás vagy migráció, riasztás-/e-mail-küldés, fizetős szolgáltatás bekapcsolása. Az audit során a meglévő webhook-definícióban hitelesítő adat literálját találtuk; annak értékét sem ez a jelentés, sem a commit nem tartalmazza.

## 2. Komponensek

| Komponens | Igazolt állapot | Bizonyíték |
|---|---|---|
| Flutter Android/iOS | Dart UI, Provider állapotkezelés, Supabase Auth és közvetlen táblaműveletek, Firebase Messaging | `lib/`, `pubspec.yaml` |
| Korábbi natív iOS | SwiftUI, Supabase Swift SDK, közvetlen táblaműveletek, nyers APNs tokenregisztráció | `HUNORApp/`, `project.yml` |
| Backend a repóban | Hat SQL migráció, kilenc táblát leíró korai HUNOR séma, egy FCM küldő Edge Function | `supabase/` |
| Web a repóban | Nincs `web/`, HTML/JS webes alkalmazás, `netlify.toml`, `_headers`, `_redirects` vagy webes build | Teljes repo-fa |
| Élő web | Statikus HTML/CSS/JS, Supabase JS, PWA manifest és web-push service worker | W, külön kiadási csomag |
| Élő backend | A korai táblák mellett eseményriasztási meghívások, logisztika, chat, profilvédelem, belső RC és külön lakossági LRC | L |

A Flutter platformkönyvtárakból csak Firebase konfigurációk vannak verziózva. A workflow-k `flutter create` paranccsal generálják a többi Android/iOS projektfájlt. A SwiftUI alkalmazást a jelenlegi CI nem építi: az iOS nevű workflow is Fluttert épít.

## 3. Supabase, séma, hitelesítés

### 3.1 Konfigurációs eltérés – igazolt

A repo négy helyén `embicteneumubwlqgfik` szerepel: `lib/config.dart`, `HUNORApp/Services/Supabase.swift`, `supabase/config.toml`, az Android workflow. A HTTP-vel ellenőrzött webes kliens és az elérhető élő katalógus viszont **`embicteneumubwlqqfik`** projektet használ. Az eltérő projekt közvetlen katalóguslekérése jogosultsági hibával elutasult. **Nem igazolt, hogy létezik-e, vagy a mobilapp oda sikeresen be tud-e jelentkezni.** Nem javítottuk át automatikusan.

A Swift kliensben publishable kulcs van, ez önmagában nem szervertitok és nem helyettesíti az RLS-t. Az Android CI `placeholder` kulccsal készít debug APK-t; az iOS CI nem ad át Dart define kulcsot. A sikeres build ezért nem igazol működő belépést.

### 3.2 Repo séma – R

`001`: profiles, skills, availability, events, event_participants. `002`: member_roles és admin helper. `003–004`: alerts, alert_responses, majd priority → type átalakítás. `005–006`: device_tokens, iOS/Android platform.

- A személyazonosság `auth.users.id` → `profiles.id`; nincs külön szervezeti tagság.
- A role egy globális `member/admin` érték, `member_roles.member_id` az elsődleges kulcs.
- A megosztott SELECT szabályok több táblán `TO authenticated USING (true)` alakúak. Ez a repóban nem ellenőriz jóváhagyást vagy szervezetet.
- Saját módosításoknál `auth.uid()` feltételek; az admin műveletek `public.is_hunor_admin()` függvényt használnak. A helper SECURITY DEFINER, a repo nem tartalmaz explicit EXECUTE visszavonást hozzá.
- A migrációs készlet nem teljes környezetdefiníció: az API-grantok külön dokumentumban szerepelnek, nincs reprodukálható seed, migrációs teszt vagy helyi Auth/RLS tesztkörnyezet.

### 3.3 Élő rendszer – L, nem azonos a hat migrációval

A vizsgált public/private táblákon RLS be van kapcsolva. Az élő olvasási szabályok jóváhagyott tagot, admin/tagságkezelő jogot és több helyen webhelyzárat ellenőriznek. Az esemény piszkozatláthatósága és a webhelyzár **RESTRICTIVE** policy, tehát nem írják felül a megengedő SELECT szabályok.

A védett profiladatokhoz saját tag, admin és tagságkezelő férhet hozzá. A profil UPDATE nem teljes táblajog: csak kijelölt oszlopokra van grant, ezért az önmódosításból önmagában nem következik a membership_status átírása. Ez pozitív védelem. A frissen hozzáadott `county` nincs a lekért közvetlen UPDATE oszloplistában: a webes közvetlen profiles.update útvonal és a külön profil-RPC együttműködését külön integrációs teszttel kell ellenőrizni; az audit nem végzett profilmentést.

A jóváhagyás `private.handle_new_hunor_user` alapján `pending` állapotból indul; a kötelező megye metaadat validált, de szerepkör nem a felhasználó által módosítható metaadatból származik. Több friss RPC invoker wrapper → privát definer függvény mintát követ, üres search_path-tal és belső jogosultságellenőrzéssel.

Az élő public/private sémákban a vizsgált katalógus szerint **nincs organization_id vagy tenant_id oszlop**. Ezt a rendszert még nem lehet biztonságosan több szervezetként használni csupán egy választómező hozzáadásával.

## 4. Események, riasztások, Rescue Coins

| Funkció | Repo – kódból igazolt | Élő web/backend – kiegészítő bizonyíték |
|---|---|---|
| Bejelentkezés | E-mail/jelszó, sessionből induló AppStore | Webes Auth, jóváhagyás és friss jogellenőrző RPC-k |
| Események | CRUD, saját going/not_going upsert; admin UI | Több eseménytípus, participant/excon, beosztások, RC életciklus |
| Mobilos riasztás | `alerts` INSERT → webhook → FCM; available/unavailable válasz | A régi táblák és send-alert-push v1 még jelen vannak |
| Célzott webes riasztás | Nincs a repóban | campaign, invitation, push_delivery, meghívott saját válasza, helyettesítés; `hunor_start_event_alert`, `hunor_respond_event_alert` |
| Külön emberi nyugtázás | Nincs külön receipt/ack állapot | A célzott meghívás részvételi válasza van; az új API külön ack-ja **terv**, nem meglévő függvény |
| Rescue Coins | Nincs RC modell, UI, migráció vagy API | `public.hunor_rc` → `private.rc_api`, private.rc_transactions és kapcsolódó értékelés/jelenlét/szabály táblák |
| Lakossági LRC | Nincs a repóban | Külön private.lrc_* készlet és hunor-public-quiz Edge Function; nem a csapattagi RC |

Az élő célzott riasztás indítása admin ellenőrzést, eseménylejáratot, friss jóváhagyást/riaszthatóságot és profilbeosztást vizsgál; a kampányt és meghívásokat tranzakcióban rögzíti. Választ csak saját, még nem helyettesített meghívásra fogad. **Ezeket a katalógusból olvastuk, nem küldtünk éles riasztást.**

A belső RC már tartalmaz szerveroldali pontszámítást, igazolt jelenlétet, eseményjóváhagyást, egyedi `source_key`-t, szabálypillanatképet és korrekciós hivatkozást. A napló megváltoztathatatlanságát `rc_immutable` triggerfüggvény támogatja. Az egyenleg, történet, kompetenciák, értékelések, eseményfeladatok és kutatási export az akcióalapú `hunor_rc` kapun keresztül működnek. Teljes RC funkcionális újratesztelés ebben az auditban nem történt. A repo jelenleg nem képes ezeket új környezetre reprodukálni.

## 5. Netlify és üzemeltetés

A repóban nincs Netlify build/deploy konfiguráció vagy webes forrás. A korábban kiadott webes csomag kézi statikus kiadás; a nyilvános GET-ellenőrzés ezt a csomagot igazolta. A Netlify dashboardban tárolt beállítások, titkok, számlázás, domain/DNS és fiókjogok teljes auditja nem történt meg. A GitHub Actions két workflow-ja csak mobil buildet végez, Netlify-telepítést nem.

A nyilvános index és JS válaszokon HSTS és újraellenőrzést kérő cache header van; CSP, X-Content-Type-Options, Referrer-Policy, Permissions-Policy és X-Frame-Options nem szerepelt a megfigyelt válaszokban. A webes csomag sok inline scriptet/onclick kezelőt tartalmaz; szigorú CSP bevezetése előkészítést igényel. A Supabase JS CDN `@2` verziósávból érkezik, SRI nélkül; a függőség nem rögzített. A nagy, körülbelül 785 KB-os fő JS és a teljes adatlisták gyakori letöltése teljesítmény- és karbantartási kockázat.

## 6. Kockázati jegyzék

**P1:** a következő integráció előtt rendezendő. **P2:** tervezett javítás és teszt szükséges. Nem jelenti, hogy egy külső támadó kihasználását igazoltuk.

| ID | Prioritás / hatókör | Megállapítás és bizonyíték | Javasolt intézkedés – nem végrehajtva |
|---|---|---|---|
| A01 | P1 R/L/W | Eltérő Supabase projektcím; mobil repo nem az éles rendszer teljes forrása | Kanonikus projekt és környezetek jóváhagyása; web/backend baseline verziózás |
| A02 | P1 R/L | Nincs szervezeti adatleválasztás; globális role és user=member azonosság | Szervezeti tagság + minden üzleti sor tenant kulcsa, összetett FK és RLS |
| A03 | P1 R/L | send-alert-push minden device_tokens sort lekér; nem használ címzettlistát, aktív tagságot vagy riaszthatóságot | Célzott invitation/outbox alapú egyetlen riasztási folyamat; negatív hozzáférési tesztek |
| A04 | P1 R | Swift nyers APNs tokent ír; az Edge sender minden platformhoz FCM messages:send-et használ | Provider/token_type explicit kezelése; APNs sender vagy FCM-es kliens, készülékteszt |
| A05 | P1 R/L | Nincs webhook deduplikáció, lejáratellenőrzés és tartós retry a régi senderben; hét izolált probe igazolta a viselkedést | Atomi outbox, egyedi delivery kulcs, lease/backoff/dead-letter; ne tekintsük a 200 választ kézbesítésnek |
| A06 | P1 L | Webhook trigger hitelesítő adatot tartalmaz literálként; nem került a dokumentációba | Titokkezelési és hozzáférési felülvizsgálat; dedikált titoktár; szükség esetén tervezett rotáció külön engedéllyel |
| A07 | P2 R | A repo széles authenticated SELECT-jei nem ellenőriznek jóváhagyást; az élő policy-k ennél szigorúbbak | A migrációkat ne futtassák vakon élesben; baseline és negatív RLS tesztek |
| A08 | P2 R | signOut nem vonja vissza a készülékkötést; member_id,token egyediség több fiókhoz engedi ugyanazt a fizikai tokent | Eszköztelepítés-alapú tulajdonlás, kijelentkezéskor leválasztás, tokenrotáció |
| A09 | P2 R | Androidon nincs explicit permission kérés, foreground megjelenítés és hunor_alerts csatornalétrehozás; iOS capabilities/entitlements nem verziózott | Platformonkénti beállítás és valódi Android/iPhone teszt; OS hangkorlátok elfogadása |
| A10 | P2 R | Nincs realtime előfizetés vagy auth-state figyelés a mobil AppStore-ban; a „live” admin válasznézet loadData snapshot | Szűrt Realtime vagy kurzoros szinkron, resume/auth refresh kezelés, pagination |
| A11 | P2 R | Flutter nem tölti az expires_at mezőt; lezárt kártyán is felkínál választ; SQL válaszpolicy nem vizsgál aktív riasztást | Lejárat/lezárás/címzettség szerveroldali állapotgép |
| A12 | P2 R | Flutter készségcsere delete + insert külön kérés; részhiba adatvesztést okozhat. Kijelentkezéskor role/response mapek egy része megmarad | Tranzakciós parancs és teljes session-state ürítés, fiókváltási tesztek |
| A13 | P2 R/C | Egy widget smoke teszt; nem kap Provider-t, miközben a gyökér Consumer<AppStore>-t használ. CI nem futtat flutter test/analyze vagy RLS tesztet | Tesztfixture és automatizált ellenőrzés külön jóváhagyott fejlesztésben |
| A14 | P2 R/C | Nincs pubspec.lock/Package.resolved/Deno lock; verziósávok és lebegő stable Flutter, futáskor generált platformprojektek | Reprodukálható SDK/függőségek; review-zott lockfile és platformkonfiguráció |
| A15 | P2 W | Hiányzó megfigyelt böngészős védelmi headerek és nem rögzített CDN SDK | CSP bevezetési terv, csomagolt/rögzített függőségek, header tesztek |
| A16 | P2 GitHub | main branch metadata protected=false; ruleset részletezés 403 miatt nem elérhető | A rendelkezésre álló csomag keretein belüli review/merge kontroll jóváhagyása; nincs csomagváltás |
| A17 | P2 L | Auth leaked-password protection kikapcsolva az advisor szerint | Elérhetőség/költség vizsgálata és vezetői döntés; nem kapcsoltuk be |
| A18 | P2 R/L | FCM generic INVALID_ARGUMENT/404 token törlést okoz; átmeneti hibánál a handler HTTP 200-at ad | Csak bizonyítottan érvénytelen token deaktiválása; hibakategóriák, retry és audit |

Az élő advisor további 5, authenticated által hívható public SECURITY DEFINER függvényt jelzett. A három adminfüggvény belső admin-ellenőrzése és üres search_path-ja igazolt; ez **nem automatikusan jogosultságmegkerülés**. A két logisztikai függvény teljes akciószintű auditja külön feladat. A 17 „RLS enabled, no policy” INFO privát LRC/receipt táblákra vonatkozik; anon/authenticated közvetlen table joga nincs, ezért ez a vizsgált kapus elérés mellett szándékos deny-by-default lehet, nem bizonyított adatszivárgás.

Advisor háttér: [definer függvények](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable), [RLS policy nélkül](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy), [jelszóvédelem](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection).

## 7. Ellenőrzések és korlátok

A végrehajtott ellenőrzések, eredmények és reprodukálható parancsok: [verification.hu.md](verification.hu.md). Nincs „minden működik” következtetés a buildből. Nem futott Flutter/Swift készülékteszt, helyi Supabase-migráció, behatolásteszt vagy élő RLS szerepváltásos próba. A rendelkezésre álló Windows környezetben Flutter/Dart/Deno/Swift/Docker nem volt elérhető.

**Következő lépés:** a projektvezető hagyja jóvá a kanonikus backend/környezet döntését, a tenant modellt, az admin-riasztás folyamatát és az API-szerződés nyitott pontjait. Ezután külön feladatként staging baseline + szervezeti izolációs tesztek. E PR csak dokumentációt és auditsegédeket tartalmaz; további fejlesztés nem indult.
