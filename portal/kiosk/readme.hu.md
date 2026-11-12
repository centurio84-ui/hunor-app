# Rendezvényes kvíz – 100 új tétel

Fejlesztési ág: `codex/010-event-quiz-bank`. Verzió: `20261016-event-bank-1`.

## Elkészült

Az első melléklet fesztiválos 20 kérdését és a második melléklet négy kategóriájának 80 kérdését együtt dolgoztuk fel. Az importáló nem futtatja a beillesztett JavaScriptet: kizárólag az ismert mezőkkel rendelkező kérdésobjektumokat olvassa be JSON-ként, és ellenőrzi a darabszámot, azonosítókat, válaszindexeket és a módonként szükséges kérdéskészletet.

| Téma | Új tétel |
|---|---:|
| Extrém időjárás | 20 |
| Túlélési alapismeretek | 20 |
| Katasztrófavédelmi mítoszok | 20 |
| HUNOR és USAR | 20 |
| Fesztivál- és tömegrendezvény-biztonság | 20 |

A korábbi 32 kioszkkérdés szövege, válaszai és helyes válaszai megmaradtak; témacímkét kaptak. A fejlesztési kioszk összesen **132** tételből dolgozik. A **106 kérdéses szerveroldali online bank változatlan**: oda ebben a körben nem importáltunk és nem írtunk Supabase-adatot.

A felhasználó külön témát és külön 5/8/10 kérdéses módot választ. A Vegyes beállítás minden témából sorsolhat. A gyerekmód egyszerűbb, külön jelölt részhalmazból választ; az intervenciós elsősegélykérdések nem kerültek ebbe a módba. Minden témában elegendő kérdés van mindhárom módhoz.

Az igaz–hamis tételeknek két válasza van. A válaszlehetőségből kivettük a megoldást eláruló zárójeles magyarázatot; az csak a válasz utáni visszajelzésben látszik. A helyes index a válaszok keverése után is az eredeti állításhoz kötődik. Az időzítők, a pontozás és az alaphelyzetbe állítás változatlan; a témaválasztó is visszaáll Vegyesre.

## Tartalmi pontosítás

70 tételt pontosítottunk vagy forrással/magyarázattal egészítettünk ki. Példák: villámvédelem sátor és árok helyett biztonságos épületben/járműben; CO-gyanúnál a kijutás elsőbbsége; orrvérzésnél az orr puha része; égési sérülés 20 perces vízhűtése; kullancs egyenletes eltávolítása; eszméletlenségnél normális légzés ellenőrzése; füstös folyosó és elektromos berendezés veszélyei. HUNOR-nál javítottuk az angol névfeloldást és több technikai, jelölési, illetve időablakra vonatkozó túlzó állítást.

Az egyenként átnézhető változat az `event-quiz-review.hu.md` dokumentum: minden tételnél kérdés, válaszok, helyes válasz, magyarázat és forrás/ellenőrzési kiindulópont található; a módosítottaknál az eredeti megfogalmazás is látszik. Nem állítunk független vagy teljes körű szakértői validálást. Egyes általános hivatkozások további ellenőrzést igényelnek; a Ready.gov két oldala a webes lekéréskor nem volt hozzáférhető. A gyerekmód életkori megfelelőségét is a szakmai tartalommal együtt kell áttekinteni.

## Állapot

A forráskód és a helyi előnézet elkészült. Az új tételek `awaiting-professional-approval` jelölést kaptak; ez dokumentációs állapot, a fejlesztési nézet játszható velük. Az éles oldalon továbbra is a korábban publikált kérdések és arculat vannak. A javított 100 tétel szakmai jóváhagyása és a konkrét csomag publikálási engedélye előtt nem élesítjük ezt a változatot, a korábbi kérdésbank indulási feltételeivel összhangban.

Build: `node tools/build.mjs`. Az import újrafuttatható duplikálás nélkül: `python tools/import-event-quiz.py`. A beillesztett fájlok helyi elérési útja az importálóban van; más gépen ezeket át kell adni vagy módosítani. Az importjelentés: `event-quiz-import.json`. Új tesztet nem írtunk és automatizált tesztcsomagot nem futtattunk.

## Szakmai és publikálási jóváhagyás
2026-10-16: a felhasználó a javított 100 tételt szakmailag jóváhagyta, és kérte a csomag feltöltését és élesítését. Ez tulajdonosi szakmai jóváhagyás; független validálást nem állítunk.
