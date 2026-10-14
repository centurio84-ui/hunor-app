# Gemini átadási jegyzet – Rescue API v0.1

**Kizárólag közös szerződéstervezet.** A [rescue-platform-openapi.yaml](rescue-platform-openapi.yaml) végpontjai nincsenek implementálva. A `.invalid` szervercím szándékosan nem működik. A projektvezető jóváhagyása előtt ne módosítsd az éles Netlify oldalt, ne futtass migrációt és ne kezdd el a következő fejlesztési fázist.

## Szókészlet és azonosítók

- `user.id`: globális Supabase Auth felhasználó.
- `organization.id`: mentőszervezet.
- `membership.id`: egy user tagsága egy szervezetben; **nem cserélhető fel a user UUID-jával**. A régi HUNOR member_id jelenleg user/profiles UUID; ezt adapternek kell majd leképeznie.
- `event.id`: szervezeti esemény; a riasztás ehhez kötött, külön életciklussal.
- `AlertRecipient.id`: konkrét meghívás és pozíció-slot. A régi nemet válaszoló/lecserélt meghívás megmarad.
- `RC`: szervezeti csapattagi pont; `LRC`: elkülönített lakossági játék. Egyik sem fizetési kredit.

## Lefedett felületek

| API-család | Tervezet |
|---|---|
| Auth | E-mail/jelszó session, refresh, aktuális session visszavonás |
| Profil | Saját minimális profil GET/PATCH, szervezeti saját tagság |
| Szervezetek | Saját szervezetek és részletek, jóváhagyott tagjegyzék |
| Események | Lista, részletek, létrehozás, módosítás |
| Részvétel | Saját eseményjelentkezés; gyakorlatnál participant/excon |
| Riasztás | Admin tervezet, admin dispatch, lista/részlet, admin címzettállapotok, lezárás |
| Nyugtázás/válasz | Saját emberi ack és külön going/not_going válasz |
| Rescue Coins | Saját vagy jogosult tagság egyenlege és naplótörténete; pontíró API nincs |

Összesen 20 útvonal és 26 művelet. A `/v1` prefix a szervercím része. Az OpenAPI 3.0.3-at a mobilos generátorokkal való kompatibilitás miatt javasoljuk, a végleges generátort még egyeztetni kell.

## Közös szabályok

1. **Jogellenőrzés:** ellenőrzött JWT + friss szervezeti tagság + műveleti jog + erőforrás tenant-ja. Más szervezet ID-ja 404, a már igazolt szervezetben hiányzó műveleti jog 403. A `x-required-permissions` szemantikai követelmény, nem kliensoldalon küldhető joglista.
2. **Riasztás csak admin:** events.manage jog önmagában nem alerts.issue. Kiadáskor minden feltétel újraellenőrzendő; a létrehozó created_by mezőt a szerver állítja.
3. **Szerveridő:** időpontok RFC3339 UTC, naptári megjelenítés a szervezet időzónájában; RC earned_on dátum, nem időpont.
4. **Lapozás:** limit 1–100 (alap25), aláírt átlátszatlan next_cursor. Kurzor tenant/actor/szűrő kötése, stabil rendezés és maximum visszakeresési tartomány. RC-nél ledger watermark biztosítja a lapok konzisztenciáját.
5. **Idempotencia:** szervezeti írások kötelező UUID Idempotency-Key fejléccel; hatókör actor+organization+operation+canonical body hash. 24 órás szerveroldali tárolás; azonos kulcs+eltérő törzs 409. Sikeres visszajátszás az eredeti státuszt/törzset adja, nem futtat mellékhatást. Auth kérésekre ez nem alkalmazandó. Ismétlés 24 óra után üzleti egyediségi korláttal is védett legyen, különösen dispatch/RC esetén.
6. **Verzió:** erős ETag `"vN"`; állapotot felülíró írásnál If-Match. Hiány:428, elavult:412. Idempotens visszajátszás ellenőrzése a már elavult If-Match elutasítása előtt történjen; új kérésekre a feltétel kötelező. Acknowledgement külön monotón, idempotens erőforrás, első szerveridővel.
7. **Nyugtázás ≠ részvétel:** külön ack gomb nem választ igent. Az igen/nem válasz implicit ack lehet. Készülék receipt automatikus háttérjel, nem emberi nyugtázás. pending állapotot a kliens ne értelmezze nemnek.
8. **Válaszok:** going = „Részt tudok venni”, not_going = „Nem tudok részt venni”. Saját tagságot a szerver származtatja, a kérésben nincs tetszőleges member_id. EXCON csak gyakorlat és érvényes jog. Helyettesített/lezárt/lejárt meghívásra válasz:409.
9. **Kézbesítés:** 202 csak tartós sorbaállítás; provider_accepted nem igazolt készülék- vagy emberi átvétel. Az admin UI ezt a négy állapotot külön jelenítse meg.
10. **Hibák:** egységes Error (`code`, biztonságos `message`, `request_id`, opcionális mezőhibák); nincs SQL-hiba, token, személyes rekord a válaszban. 429 Retry-After. Kliens idempotens újrapróbálkozás backoff-fal, lejárati ellenőrzéssel.
11. **Adatvédelem:** saját/profile/auth/riasztás válaszok no-store. Token/jelszó/push payload nem naplózható. Pushban ne legyen irat/egészségügy. A szervezeti jegyzék ne adjon át privát telefonszámot vagy e-mailt automatikusan.

## Jelenlegi elnevezések és javasolt leképezések

| Jelenlegi | Javasolt adapter | Megjegyzés |
|---|---|---|
| Supabase Auth signInWithPassword | POST /auth/sessions | Nem meglévő gateway; MFA/passkey még nincs a v0.1 szerződésben |
| profiles.id / member_roles.member_id | user_id → membership.id | Új szervezeti tagság szükséges, nem puszta mezőátnevezés |
| events / event_participants | events / participation/me | Mező-, életciklus- és EXCON jogosultság-egyeztetés kell |
| Régi alerts + available/unavailable | Nem közvetlenül kompatibilis | Broadcast táblák, nincs célszemély/ack; nem szabad vakon az új végpontra kötni |
| event_alert_campaigns / invitations | alerts / recipients / response | A webes célzott modell közelebb áll a tervhez, de önálló alert UUID és ack hiányzik |
| hunor_start_event_alert / hunor_respond_event_alert | dispatch / response adapter | Üzleti ellenőrzéseket meg kell tartani; saját új backend csak jóváhagyás után |
| hunor_rc dashboard + rc_transactions | balance / transactions | Ellenőrzött, csak olvasó DTO; belső kutatási adatok nem kerülnek át |

## Tudatosan későbbre hagyott szerződések

Szervezet létrehozás/provisioning és törlés; tagság jóváhagyás/admin szerepkiosztás; irat/egészségügyi mezők; eszközregisztráció és receipt capability; címzett-helyettesítés; RC írás/értékelés; billing; offline teljes változásfolyam; publikus vendég- és LRC API; MFA/passkey challenge. Ezeket az architektúra megnevezi, de a 26 művelet nem ígéri megvalósításukat. A helyettesítést a v0.1 admin UI csak a meglévő, ellenőrzött folyamaton végezheti, amíg nincs jóváhagyott külön szerződés.

## Következő közös döntési kör

A projektvezető és a Gemini fejlesztő review-ja: tenant/azonosítók, szerepek, ack-válasz szemantika, időzónák, tokenkezelés, idempotencia, verziózás, RC DTO és a szükséges későbbi végpontok. Ezt követően külön feladat staging integrációs és szervezeti izolációs teszttervvel. A YAML érvényessége nem jelent működő vagy biztonságos API implementációt.
