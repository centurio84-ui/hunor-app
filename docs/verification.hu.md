# CODEX-001 – ellenőrzési jegyzőkönyv

2026-10-14 · Forrás: main `6b47f52f531ff00f20e6ea88b08a44047f8e0b74`. Az audit a jelenlegi viselkedést méri; a talált hibákat nem javítja ebben a PR-ban.

## Ebben az auditban végrehajtva

| Ellenőrzés | Eredmény | Mit igazol / mit nem |
|---|---|---|
| Teljes GitHub fájafa és 50 fájl Git blob hash | 50/50 egyezés | A vizsgált snapshot az adott commité; nem a teljes Git-történet titokvizsgálata |
| OpenAPI 3.0.3 validátor | Sikeres | A YAML szerkezete érvényes; nincs működő API tesztelve |
| Offline szerződés- és sémaellenőrzések | **134 sikeres ellenőrzés**, 20 útvonal, 26 művelet, 32 séma | Szervezeti útvonal, Bearer védelem leírása, admin dispatch jog, idempotencia/If-Match dokumentálás, helyes és hibás példák; nem tényleges tenant RLS |
| Régi send-alert-push izolált probe | **7 ellenőrzés sikeres** | 2 elvárt szűrés és 5 igazolt hiányosság; „sikeres” itt nem a hibás küldő biztonságosságát jelenti |
| Élő Supabase katalógus SELECT + advisor | Olvasás sikeres a webes projekten | RLS bekapcsolás, policy mód, függvény/grant/constraint bizonyíték; nincs DML vagy migráció |
| Repo szerinti másik projekt katalógusa | Jogosultsági hibával elutasult | A projekt létezése és működése nem állapítható meg ebből |
| Élő webes HTTP GET | 3×HTTP200; index/JS/manifest bájtra egyezik a helyi release9-cel | A kiegészítő webforrás eredete és headerek; nincs Netlify módosítás |
| RLS, trigger, szerverforrás statikus review | Kockázatok dokumentálva | Nem szerepváltásos/adatkiolvasásos penetrációs teszt |

Az OpenAPI példák között a szerepkör tömeges átadása, a más tag nevében küldött riasztási válasz, a hibás enum, az üres profilpatch és az LRC/RC keverése elutasított. Ez a **séma** viselkedése; a még nem létező implementációból nem következik automatikusan.

## A hét push probe

A Node 24.19.0 futtató a változatlan TypeScript kódot típuseltávolítással, izolált környezetben töltötte be. **Minden hálózati és adatbázis-kérés mockolt.** A `withSupabase` middleware helyettesített, tehát annak secret-hitelesítését ez a teszt nem igazolja és nem cáfolja. Nem használt valódi Firebase privát kulcsot, készüléktokent vagy éles célszemélyt.

1. Closed riasztás nem indít küldést.
2. Más tábla webhookja nem indít küldést.
3. Az aktív riasztás minden eltárolt fixture eszközt megcéloz, címzettségi/tagsági szűrő nélkül.
4. Régen lejárt, de active riasztás ugyanúgy küld.
5. Ugyanazon webhook ismétlése megismétli a küldéseket.
6. Generic INVALID_ARGUMENT válasz esetén a handler tokeneket törölne; csak mockolt törlés történt.
7. Minden provider-kérés 503 hibája mellett is HTTP200/sent0 a handler válasza; nincs benne tartós újrapróbálkozás.

## Meglévő CI eredmények – csak megtekintve

- [Flutter Android build, 35519037478](https://github.com/centurio84-ui/hunor-app/actions/runs/35519037478): success, a vizsgált main commiton, 2026-09-20.
- [Flutter iOS Simulator build, 35519037473](https://github.com/centurio84-ui/hunor-app/actions/runs/35519037473): success, ugyanazon commiton, 2026-09-20.

Ezek debug APK / aláírás nélküli simulator build eredmények. A workflow-k nem futtatnak `flutter test`, `flutter analyze`, adatbázistesztet vagy fizikai eszköztesztet. A sikeres build nem igazolja a placeholder/hiányzó backend kulcsokkal történő belépést vagy a telefonos push-t. A docs PR saját automatikus checkjeinek állapota a PR Checks részében látható; a fenti eredmények nem azok.

## Nem futott

Flutter widget teszt, Dart analyze, Swift/Xcode build, fizikai Android/iPhone push teszt, helyi Supabase reset/migráció, teljes RC/e-mail/kvíz regresszió, szervezeti cross-tenant dinamikus teszt, jelszópróba, éles riasztás vagy webes űrlapmentés. Flutter/Dart/Deno/Swift/Docker nem állt rendelkezésre a vizsgált Windows környezet PATH-ján. A meglévő widget teszt Provider fixture-hiánya statikus megállapítás, nem lefuttatott hibaeredmény.

## Reprodukálható, helyi ellenőrzés

Ezek a dokumentációs segédek nem telepítenek backend szolgáltatást és nem hívnak éles végpontot. A függőségek elkülönített virtuális környezetbe telepítendők; az alkalmazás dependency készletét nem módosítják.

```text
python -m venv .audit-venv
# Aktiváld a saját rendszerednek megfelelő módon a virtuális környezetet.
python -m pip install -r docs/audit-tools/requirements.txt
python docs/audit-tools/verify_contract.py
node docs/audit-tools/probe_push.mjs
```

Az első két eszközfüggőség rögzített, a validátor tranzitív csomagjai nincsenek itt teljesen lockolva; ez auditsegéd, nem alkalmazás release-készlet. Node24 szükséges a probe típuseltávolító API-jához, amely kísérleti figyelmeztetést adhat. A futtatás nem érinti a Supabase/Netlify állapotát.

## Következő fázis kötelező tesztmátrixa – még nem végrehajtva

SzervezetA/B, többes tagság, pending/suspended/revoked, admin/editor/member/EXCON; közvetlen REST/RPC/Storage/Realtime; hamis tenant/FK/actor; lejárt session/jogváltozás; dupla dispatch és idempotencia body mismatch; párhuzamos válasz/helyettesítés; offline lejárt válasz; provider átmeneti/végleges hiba; nyers APNs/FCM típus; RC duplikált forrás és korrekció; két szervezet egyenlegszivárgása; migráció/restore/rollback. Csak vezetői jóváhagyás után, elkülönített környezetben.
