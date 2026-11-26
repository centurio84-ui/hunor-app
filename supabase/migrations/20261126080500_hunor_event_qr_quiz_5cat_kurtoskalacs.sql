-- ============================================================================
-- EVENT-BASED QR QUIZ SYSTEM (5 CATEGORIES, 98 QUESTIONS, KÜRTŐSKALÁCS COUPONS)
-- ============================================================================
BEGIN;

-- ============================================================================
-- 1. KVÍZ KÉRDÉSEK TÁBLA ÉS KATEGÓRIA OSZLOP (quiz_questions)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.quiz_questions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  question text NOT NULL,
  options jsonb NOT NULL,
  correct_index int NOT NULL,
  explanation text NOT NULL DEFAULT '',
  category text NOT NULL DEFAULT 'altalanos',
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.quiz_questions
  ADD COLUMN IF NOT EXISTS category text NOT NULL DEFAULT 'altalanos';

CREATE INDEX IF NOT EXISTS idx_quiz_questions_category
  ON public.quiz_questions(category);

ALTER TABLE public.quiz_questions ENABLE ROW LEVEL SECURITY;

GRANT SELECT ON public.quiz_questions TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON public.quiz_questions TO authenticated;

DROP POLICY IF EXISTS "Public read quiz questions" ON public.quiz_questions;
CREATE POLICY "Public read quiz questions" ON public.quiz_questions
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Authenticated manage quiz questions" ON public.quiz_questions;
CREATE POLICY "Authenticated manage quiz questions" ON public.quiz_questions
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- Ha a quiz_questions táblában még nincsenek meg az alap 'altalanos' kérdések (58 db), töltsük fel:
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.quiz_questions WHERE category = 'altalanos') THEN
    INSERT INTO public.quiz_questions (question, options, correct_index, explanation, category)
    VALUES
    ('Füstöt észlelsz a lakás folyosóján. Mi a legfontosabb?', '["Biztonságos útvonalon menekülni és a 112-t hívni.", "Előbb összeszedni az értéktárgyakat.", "Kinyitni minden ajtót, hogy kiszellőzzön."]'::jsonb, 0, 'Csak biztonságosan járható útvonalon menekülj. Sűrű füsttel telt lépcsőházba ne lépj be. Ha a kijutás veszélyes, csukd be az ajtót, hívd a 112-t, és jelezd, hol vagy; kövesd a tűzoltók utasításait.', 'altalanos'),
    ('Miért kell füstben lehetőleg alacsonyan haladni?', '["Mert a padlón mindig friss levegő van.", "A hő és a füst jellemzően felfelé terjed.", "Mert így gyorsabb a futás."]'::jsonb, 1, 'Alacsonyabban általában kedvezőbbek a körülmények, de a füst ott is mérgező lehet.', 'altalanos'),
    ('Mit teszel, ha egy edényben ég a főzőolaj?', '["Hideg vizet öntesz rá.", "Az égő edényt kiviszed az erkélyre.", "Ha biztonságos, elzárod a hőt és megfelelő fedővel letakarod; vizet nem öntesz rá."]'::jsonb, 2, 'Az égő olajra öntött víz súlyos lángfellobbanást okozhat. Veszély esetén távolodj el és hívd a 112-t.', 'altalanos'),
    ('Mit ellenőrzöl menekülés előtt egy zárt ajtónál?', '["Óvatosan ellenőrzöd, nem forró-e az ajtó; forró ajtót nem nyitsz ki.", "Azonnal feltéped, hogy gyorsabban kijuss.", "Vizet öntesz a kilincsre és belépsz."]'::jsonb, 0, 'A forró ajtót ne nyisd ki. A nem forró ajtó sem garantál füstmentes útvonalat. Ha nincs biztonságos kijárat, csukott ajtó mögül hívd a 112-t és jelezd a tartózkodási helyedet.', 'altalanos'),
    ('Mire jó az otthoni füstérzékelő?', '["Automatikusan elolt minden tüzet.", "Korán jelezheti a füstöt és időt adhat a menekülésre.", "Kiváltja a menekülési tervet."]'::jsonb, 1, 'A korai figyelmeztetés életmentő lehet; az érzékelőt rendszeresen ellenőrizni kell.', 'altalanos'),
    ('Mit teszel, ha egy lítiumakkumulátoros eszköz füstöl és sziszeg?', '["Megfogod és zsebre teszed.", "Közelről beleszagolsz, mi ég.", "Eltávolodsz a füsttől, másokat is biztonságba juttatsz, és 112-t hívsz."]'::jsonb, 2, 'A sérült akkumulátor mérgező gázokat bocsáthat ki, és újra meggyulladhat.', 'altalanos'),
    ('Mit teszel, ha menekülés közben biztonságosan magad mögött becsukhatod az ajtót?', '["Becsukod, ezzel lassíthatod a tűz és a füst terjedését.", "Mindig nyitva hagyod a huzat miatt.", "Kiékeled teljesen nyitott helyzetben."]'::jsonb, 0, 'A zárt ajtó lassíthatja a tűz és a füst továbbterjedését.', 'altalanos'),
    ('Miért fontos a családi menekülési terv?', '["Csak a biztosító miatt.", "Mindenki előre tudhatja, merre juthat ki és hol találkozzatok.", "Hogy tűz esetén előbb dokumentumokat keressetek."]'::jsonb, 1, 'A kijáratok és menekülési útvonalak előzetes ismerete csökkenti a bizonytalanságot.', 'altalanos'),
    ('Mit jelent az elzárkózás veszélyesanyag-felhő esetén?', '["Azonnal autóba ülni és a felhő felé indulni.", "Az ablakokat kitárni a szellőzéshez.", "Védett épületben maradni, a nyílászárókat bezárni és követni az utasításokat."]'::jsonb, 2, 'Veszélyesanyag-felhőnél a külső levegő bejutását kell csökkenteni a hatósági tájékoztatásnak megfelelően.', 'altalanos'),
    ('Mit kell tenni elzárkózáskor a külső levegőt beszívó klímával?', '["Kikapcsolni a külső levegőt bejuttató szellőztetést.", "Maximális fokozatra kapcsolni.", "Ablakot nyitni mellé."]'::jsonb, 0, 'A külső levegő bejuttatása szennyező anyagokat hozhat az épületbe.', 'altalanos'),
    ('Mi a különbség kitelepítés és kimenekítés között?', '["Nincs különbség, mindkettő ugyanaz.", "A kitelepítés szervezetten tervezhető, a kimenekítés közvetlen veszély miatt sürgős.", "A kitelepítés mindig önkéntes túrázás."]'::jsonb, 1, 'A polgári védelem külön kezeli az előre tervezhető és a sürgős lakóhelyelhagyást.', 'altalanos'),
    ('Melyik a legfontosabb összeállítás egy hosszabb kitelepítésre?', '["Csak televízió és játékkonzol.", "Nehéz, csak kézben vihető berendezések.", "Okmányok, gyógyszerek, víz, tartós étel, megfelelő ruházat és alapvető higiéniai eszközök."]'::jsonb, 2, 'A csomag legyen személyre szabott, könnyen hordozható, és igazodjon a hatóság tájékoztatásához.', 'altalanos'),
    ('Miért praktikus hátizsákban vinni a veszélyhelyzeti csomagot?', '["Szabadon maradnak a kezeid mozgáshoz és segítségnyújtáshoz.", "Mert minden hátizsák vízhatlan.", "Mert így több száz kilót vihetsz."]'::jsonb, 0, 'A könnyen hordozható csomag különösen fontos gyalogos mozgásnál.', 'altalanos'),
    ('Mit tegyél, ha hivatalosan elrendelik a kitelepítést?', '["Várj napokat további magyarázat nélkül.", "Kövesd a kijelölt útvonalat és az illetékesek utasításait.", "Indulj ellenkező irányba ismeretlen úton."]'::jsonb, 1, 'A szervezett mozgás és a tájékoztatás követése fontos az életvédelemhez.', 'altalanos'),
    ('Mire kell gondolni különösen a veszélyhelyzeti csomag tervezésekor?', '["Csak a felnőttek irataira.", "Arra, hogy mindenki ugyanazt a méretű ruhát kapja.", "Gyermekek, idősek és tartós betegek sajátos szükségleteire."]'::jsonb, 2, 'A személyes szükségletek, gyógyszerek és segédeszközök nélkülözhetetlenek lehetnek.', 'altalanos'),
    ('Mikor szellőztess egy veszélyesanyag-felhő miatti elzárkózás után?', '["Ha a hatósági tájékoztatás szerint elmúlt a veszély.", "Az első szirénaszó alatt.", "Amikor a felhő a ház elé ér."]'::jsonb, 0, 'A szellőztetés idejét a helyi utasítások és a veszély elmúlása határozza meg.', 'altalanos'),
    ('Hosszabb áramszünet alatt mit tegyél a hűtőszekrény ajtajával?', '["Percenként nyitogasd.", "Lehetőleg tartsd csukva.", "Hagyd kitárva, hogy felmelegedjen."]'::jsonb, 1, 'A hűtő ajtajának csukva tartása lassítja a felmelegedést. Egy előzőleg megfelelően hűtött, zárva tartott hűtő nagyjából 4 órán át tarthatja biztonságosan hidegen az ételt. Hosszabb kimaradásnál a hőmérséklet és az élelmiszer típusa alapján kell dönteni; kóstolással ne ellenőrizd a biztonságot.', 'altalanos'),
    ('Hol szabad működtetni egy benzinmotoros áramfejlesztőt?', '["Zárt garázsban, nyitott belső ajtó mellett.", "A nappaliban nyitott ablakkal.", "Kizárólag a szabadban, legalább 6 méterre az épülettől, ajtóktól, ablakoktól és szellőzőktől távol, a kipufogót az épülettől elfelé fordítva."]'::jsonb, 2, 'Az áramfejlesztő kipufogógáza életveszélyes szén-monoxidot tartalmaz. Garázsban vagy más zárt térben nyitott ajtó mellett sem működtethető. A gyártó ennél nagyobb távolságot is előírhat.', 'altalanos'),
    ('Mivel NEM szabad fűteni áramszünetkor?', '["Beltérben használt kerti grillsütővel vagy gáztűzhellyel.", "Biztonságosan alkalmazott, erre tervezett fűtőberendezéssel.", "Megfelelő meleg ruházattal és takaróval."]'::jsonb, 0, 'Az égéstermékek és a szén-monoxid mérgezést okozhatnak.', 'altalanos'),
    ('Erős gázszagot észlelsz a lakásban. Mi a biztonságos reakció?', '["Kapcsold fel sorban a villanyokat.", "Ne kapcsolj elektromos készüléket; ha biztonságos, zárd el a gázt, hagyd el a helyet és kintről kérj segítséget.", "Gyújts gyufát a szivárgás kereséséhez."]'::jsonb, 1, 'Ne működtess kapcsolót, ne húzz ki dugót, és ne telefonálj a gázszagú térben. A gázt csak saját veszélyeztetésed nélkül zárd el. Hagyd el a helyet, és biztonságos távolságból hívd a gázszolgáltatót vagy közvetlen veszélyben a 112-t.', 'altalanos'),
    ('Miért kell áramszünetkor a fontos egészségügyi eszközökre is tervezni?', '["Mert az eszközök mind örökké akkumulátorról működnek.", "Mert csak internet nélkül használhatók.", "Mert egyes orvosi eszközök és gyógyszerek áramellátást vagy hűtést igényelnek."]'::jsonb, 2, 'Életfontosságú eszköz esetén előre kidolgozott tartalék áramellátási és ellátási terv szükséges.', 'altalanos'),
    ('Miért érdemes a nem életfenntartó, érzékeny elektronikus készülékeket kihúzni áramszünetben?', '["A visszatérő áramellátáskor fellépő túlfeszültség elleni védelem miatt.", "Hogy gyorsabban jöjjön vissza az áram.", "Mert a dugó mindig felrobban áram nélkül."]'::jsonb, 0, 'A hálózat visszakapcsolásakor fellépő túlfeszültség károsíthatja az érzékeny berendezéseket. Orvosi, életfenntartó eszközöknél az előre egyeztetett ellátási tervet kövesd.', 'altalanos'),
    ('A szén-monoxid-érzékelő CO-veszélyjelzést ad. Mit teszel?', '["Biztosan csak lemerült a telefon.", "Potenciális életveszélyt: biztonságosan hagyd el az épületet, és kérj segítséget.", "Azt, hogy ki kell kapcsolni minden riasztót és aludni."]'::jsonb, 1, 'A CO színtelen, szagtalan és életveszélyes. Menj biztonságos helyre, kérj segítséget, és ne térj vissza a veszélyes térbe hibát keresni. Az elem- vagy készülékhiba-jelzéseket a gyártói útmutató különíti el a CO-riasztástól.', 'altalanos'),
    ('Mit érdemes kéznél tartani váratlan áramszünetre?', '["Csak gyertyát felügyelet nélkül.", "Egy kizárólag hálózatról működő telefont.", "Feltöltött mobiltelefont, powerbankot, elemlámpát és elemes rádiót."]'::jsonb, 2, 'Az önálló energiaforrás és a hiteles tájékoztatás elérése alapvető.', 'altalanos'),
    ('Nagy hóban elakadsz egy elhagyatott úton. Mi az elsődleges?', '["Segítséget kérsz és megadod a helyzeted; ha a járműnél nem fenyeget közvetlen veszély, ott maradsz védett helyen.", "Vakon elindulni gyalog a hóviharba.", "Elrejteni az autót a keresők elől."]'::jsonb, 0, 'Erős hóviharban a jármű védelmet adhat és könnyebben megtalálható; közvetlen veszély esetén más döntés szükséges.', 'altalanos'),
    ('Miért kell a kipufogót szabaddá tenni, mielőtt a havas úton járatod a motort?', '["Hogy hangosabban szóljon a motor.", "Az utastérbe jutó szén-monoxid-mérgezés elkerüléséhez.", "Hogy gyorsabban fogyjon az üzemanyag."]'::jsonb, 1, 'A hó eltömítheti a kipufogót, és a kipufogógáz visszajuthat a járműbe.', 'altalanos'),
    ('Melyik felszereléscsomag a leghasznosabb hosszú téli útra?', '["Csak strandpapucs és naptej.", "Csak egy extra autóillatosító.", "Takaró, meleg ruha, víz, tartós étel, lámpa, hólapát és feltöltött telefon."]'::jsonb, 2, 'A magyar rendőrség is hangsúlyozza az úti és téli vészfelszerelés fontosságát.', 'altalanos'),
    ('Melyikre érdemes figyelni téli indulás előtt?', '["Időjárás, útviszonyok, abroncsok, akkumulátor és világítás.", "Csak az autórádió hangerőre.", "Csak az üléskárpitra."]'::jsonb, 0, 'A technikai állapot és a tájékozódás csökkentheti az elakadási és baleseti kockázatot.', 'altalanos'),
    ('Hóviharban elakadt autót látsz. Mit tegyél?', '["Azonnal megállsz az úttest közepén.", "Biztonságos helyről felméred, kell-e segítség, és szükség esetén 112-t hívsz.", "Figyelmen kívül hagyod minden körülmények között."]'::jsonb, 1, 'Saját biztonságod elsődleges; a bajba jutók helyét és állapotát pontosan jelezd a segélyhívón.', 'altalanos'),
    ('Meghibásodás miatt biztonságosan megálltál az út szélén. Mi segítheti a láthatóságot?', '["Kikapcsolt világítás minden helyzetben.", "Az autó sárral való lefedése.", "Vészvillogó és jól látható jelzés, a körülményeknek megfelelően."]'::jsonb, 2, 'A vészvillogó és a körülményeknek megfelelő elakadásjelzés figyelmeztethet másokat. A jelzés kihelyezése ne sodorjon új veszélybe. Autópályán a járműben várakozás helyett a szalagkorláton kívüli védett hely lehet szükséges; kövesd a helyszíni útmutatást.', 'altalanos'),
    ('Elakadás közben hogyan csökkentheted a kihűlés kockázatát?', '["Száraz, réteges ruházattal, takaróval és szükség esetén szakszerű segítségkéréssel.", "Alkoholfogyasztással a felmelegedéshez.", "Nedves ruhában maradva."]'::jsonb, 0, 'A kihűlés megelőzéséhez a száraz ruházat és a hőveszteség csökkentése fontos.', 'altalanos'),
    ('Hóviharban, biztonságos helyen várakozva mi igaz a fűtés céljából járatott motorra?', '["Órákon át folyamatosan járhat, zárt ablakok mellett.", "Csak korlátozott ideig járjon, szabad kipufogó és megfelelő szellőzés mellett; ez sem helyettesíti a segítségkérést.", "A CO-érzékelő megléte feleslegessé teszi a kipufogó ellenőrzését."]'::jsonb, 1, 'A hóviharban várakozó járműnél az NWS rövid, szakaszos motorjáratást javasol, például óránként körülbelül 10 percet. A kipufogó legyen szabad, és biztosítani kell a szellőzést. Ez nem általános biztonsági garancia: CO-kockázat vagy más közvetlen veszély esetén kérj sürgős segítséget.', 'altalanos'),
    ('Mit kell tenni, ha lakott területen hirtelen, rendkívül erős szélvihar (orkán) tör ki az utcán?', '["Bújjak el egy nagy fa alatt, mert az véd a széltől.", "Maradjak távol a fáktól, vezetékektől és leeső tárgyaktól; biztonságos útvonalon menjek stabil épületbe.", "Feküdjek le laposan az út közepére."]'::jsonb, 1, 'Kerüld a leszakadó ágakat és tárgyakat. Ne állj meg sérült épületrész alatt; keress biztonságos menedéket.', 'altalanos'),
    ('Mit jelent a HungaroMet piros figyelmeztetése magas középhőmérséklet miatt?', '["Csak annyit, hogy érdemes napszemüveget venni.", "Kiemelten veszélyes hőséget jelez; csökkenteni kell a megterhelést, hűvös helyet keresni és követni a hivatalos tájékoztatást.", "Azt, hogy éjszaka fagyveszély várható."]'::jsonb, 1, 'A meteorológiai figyelmeztetés és az egészségügyi hőségriasztás külön rendszer. Nem azonos a szociális ellátás vörös kódjával.', 'altalanos'),
    ('Hogyan kell védekezni villámárvizek (hirtelen lezúduló nagy esők miatti áradások) esetén?', '["Le kell menni a mélygarázsba megnézni az autót.", "Minél gyorsabban el kell jutni a magasabban fekvő, biztonságos területekre, és kerülni kell az aluljárókat, pincéket.", "Be kell úszni az áradó vízbe."]'::jsonb, 1, 'Minél gyorsabban el kell jutni a magasabban fekvő, biztonságos területekre, és kerülni kell az aluljárókat, pincéket.', 'altalanos'),
    ('Mi a teendő, ha autózás közben hatalmas jégeső lep meg?', '["Teljes gázzal továbbhajtani, hogy mielőbb átérjünk rajta.", "Lassítani, majd ha lehetséges, a forgalmat nem akadályozó biztonságos helyen megállni, távol fáktól és vezetékektől.", "Kiugrani a kocsiból és kézzel védeni a szélvédőt."]'::jsonb, 1, 'Ne állj meg forgalmi sávban vagy híd alatt úgy, hogy másokat veszélyeztetsz. Maradj a járműben, amíg biztonságosan tovább lehet indulni.', 'altalanos'),
    ('Mit jelent a másodfokú (narancs) riasztás zivatar és felhőszakadás esetén?', '["Semmi különös, ez egy átlagos nyári nap.", "Fokozott veszélyt jelez; figyelni kell a friss előrejelzéseket és felkészülni a heves időjárás hatásaira.", "Országos kijárási tilalom lép életbe."]'::jsonb, 1, 'A narancssárga jelzés veszélyes időjárást jelez, de önmagában nem jelent kijárási tilalmat.', 'altalanos'),
    ('Hová menj, ha túrázás közben meghallod a mennydörgést?', '["Magas fa teteje vagy egy magányos fa töve.", "Mielőbb zárt, stabil épületbe vagy zárt, keménytetős autóba; a fa, sátor és árok nem biztosít villámvédelmet.", "Feküdjünk hanyatt a fűben."]'::jsonb, 1, 'Szabadban nincs villámbiztos hely. A guggolás nem teszi biztonságossá a helyzetet.', 'altalanos'),
    ('Mi az elsődleges veszélyforrás egy tartós, heves téli hófúvás (blizzard) során?', '["A túl sok fagylalt.", "A kihűlés (hipotermia), a magányos utakon elakadás és a fűtés/áramkimaradás.", "A leégett napozókrém."]'::jsonb, 1, 'A kihűlés (hipotermia), a magányos utakon elakadás és a fűtés/áramkimaradás.', 'altalanos'),
    ('Mit kell tenni, ha lakóhelyeden hirtelen bekövetkező, extrém vihar miatt elmegy az áram és a fűtés?', '["Nyitva hagyni az összes ablakot, hogy szellőzzön a lakás.", "Meleg ruhát ölteni, lezárni a kihűlő helyiségeket, és bekapcsolni az elemes rádiót a friss információkért.", "Befűteni a nappaliban egy nyitott gázsütővel."]'::jsonb, 1, 'Öltözz melegen, tartsd meg a hőt és figyeld a hivatalos híreket. Beltérben ne használj kültéri égésű eszközt vagy áramfejlesztőt.', 'altalanos'),
    ('Mit jelez a meteorológiában a ''szupercella'' kifejezés?', '["Egy óriási felhőkarcolót Budapesten.", "Tartósan forgó feláramlással rendelkező zivatart; jégesőt, károkozó szelet és néha tornádót okozhat.", "Egy speciális időjárás-előrejelző műholdat."]'::jsonb, 1, 'Nem minden szupercella okoz tornádót. A veszélyjelzéseket kell követni, nem egy felhő látványából dönteni.', 'altalanos'),
    ('Mi a teendő erdőtűz esetén, ha észreveszed a lángokat a kirándulás során?', '["Megpróbálni elfújni a tüzet.", "Biztonságos útvonalon távolodni a tűztől és füsttől, 112-t hívni, majd követni a mentők utasításait.", "Fotózni egy szelfit a lángok előtt."]'::jsonb, 1, 'A szél és a terep gyorsan változtathatja a tűz terjedését; egyetlen általános irányszabály nem garantál menekülést.', 'altalanos'),
    ('Mely tünetek utalhatnak hőgutára?', '["Hidegrázás és fogvacogás.", "Nagyon magas testhőmérséklet, zavartság, rossz koordináció, eszméletvesztés; a bőr lehet száraz vagy verejtékes.", "Fokozott energiaszint és öröm."]'::jsonb, 1, 'Hőguta gyanújánál azonnali segélyhívás és hűtés szükséges. Ne várj arra, hogy magától rendeződjön.', 'altalanos'),
    ('Mi a helyes döntés, ha elöntött útszakaszhoz érsz autóval?', '["Maradj benne üvöltve, amíg el nem apad.", "Ne hajts a vízbe; fordulj vissza és keress más útvonalat. Ha csapdába kerültél, kérj segítséget a 112-n.", "Nyiss ablakot és kezdj el horgászni."]'::jsonb, 1, 'Ne alapozd a biztonságot a kerék vagy küszöb magasságára. A víz mélysége, sodrása és az út állapota kívülről nem ítélhető meg.', 'altalanos'),
    ('Hogyan védekezzünk az UV-sugárzás ellen nyári napokon szabadtéren?', '["Ne igyunk vizet napközben.", "Árnyék, megfelelő ruházat, fejfedő, napszemüveg és megfelelő fényvédő; erős UV idején kerülni kell a tűző napot.", "Feküdjünk ki délben a napra kendő nélkül."]'::jsonb, 1, 'Árnyék, megfelelő ruházat, fejfedő, napszemüveg és megfelelő fényvédő; erős UV idején kerülni kell a tűző napot.', 'altalanos'),
    ('Mi a teendő szén-monoxid mérgezés gyanúja esetén otthon?', '["Gyújtsunk gyertyát, hogy lássunk.", "Azonnal kijutni a friss levegőre, másokat is figyelmeztetni és biztonságos helyről 112-t hívni.", "Igyunk egy pohár hideg vizet és aludjunk tovább."]'::jsonb, 1, 'Ne késleltesd a kijutást a berendezés keresésével vagy szellőztetéssel, és ne menj vissza a veszélyes térbe.', 'altalanos'),
    ('Mi a lakosság feladata súlyos időjárási veszélyjelzéskor?', '["Bezárja az összes boltot és bankot.", "Figyelni a hivatalos tájékoztatást, kerülni a felesleges utazást és követni a hatóságok utasításait.", "Szünetelteti az internetet."]'::jsonb, 1, 'A meteorológiai piros jelzés és a szociális vörös kód nem azonos. Az intézkedések az adott eseménytől függnek.', 'altalanos'),
    ('Mikor kell figyelni a heves zivatarok veszélyére Magyarországon?', '["December és január", "Különösen a meleg évszakban, de mindig az aktuális hivatalos veszélyjelzés alapján.", "Október és november"]'::jsonb, 1, 'A naptári hónap önmagában nem zárja ki a heves zivatar lehetőségét.', 'altalanos'),
    ('Melyik tünet utalhat kezdődő kihűlésre?', '["Izzadás és fáradtság.", "Remegés, hideg bőr és romló kézügyesség; súlyosbodáskor zavartság és beszédzavar is jelentkezhet.", "Magas vérnyomás."]'::jsonb, 1, 'A hipotermia kihűlést jelent, nem eleve halált. Súlyos gyanú esetén 112 és kíméletes védelem a további hővesztéstől.', 'altalanos'),
    ('Mi a helyes eljárás, ha fagyos időben beszakad valaki alatt a jég a tavon?', '["Rohanva odafutni a lék szélére.", "Hívni a 112-t; a partról nyújtott biztonságos segítséget keresni, a bizonytalan jégre nem kimenni.", "Kiabálni vele, hogy ússzon ki."]'::jsonb, 1, 'A hason csúszás sem garantálja a jég teherbírását. Ne válj második áldozattá.', 'altalanos'),
    ('Mi az a ''száraz villám''?', '["Olyan villámcsapás, ami vízből indul ki.", "Olyan villámlással járó zivatarjelenség, amikor kevés vagy semennyi eső nem jut a felszínre; tüzet is okozhat.", "Egy internetes mém."]'::jsonb, 1, 'Az eső hiánya nem zárja ki a villámcsapást. Az erdőtüzek okai területenként eltérnek; nem állítjuk, hogy mindenütt ez a fő ok.', 'altalanos'),
    ('Mit kell tenni erős földrengés alatt zárt térben?', '["Rohanni az erkélyre és leugrani.", "Leguggolni, fedezékbe húzódni és kapaszkodni; védeni a fejet, kerülni az ablakokat és a liftet.", "Liftbe szállni és gyorsan lemenni."]'::jsonb, 1, 'Stabil asztal alatt védd a fejed, és kapaszkodj. Ne rohanj a rázkódás közben a kijárathoz.', 'altalanos'),
    ('Mit tartalmazzon egy jól összeállított 72 órás vészhelyzeti hátizsák (Bug-out bag)?', '["Csak divatos ruhákat és egy tabletet.", "Ivóvizet, tartós élelmiszert, elsősegélycsomagot, zseblámpát, elemes rádiót, iratmásolatot és gyógyszereket.", "Játékokat és konzolokat."]'::jsonb, 1, 'Ivóvizet, tartós élelmiszert, elsősegélycsomagot, zseblámpát, elemes rádiót, iratmásolatot és gyógyszereket.', 'altalanos'),
    ('Hogyan kell vízhez jutni a vadonban, ha kifogytál az ivóvízből?', '["Bármilyen álló pocsolyából nyugodtan inni.", "Lehetőleg ismert biztonságos ivóvizet keresni; a természetes vizet megfelelő módszerrel kezelni, nem a tisztaságára hagyatkozni.", "Tengervizet inni a szomjúság ellen."]'::jsonb, 1, 'A forralás a kórokozók ellen segíthet, de a vegyi szennyeződést nem távolítja el. Nem minden szűrő távolít el minden kórokozót.', 'altalanos'),
    ('Mit tegyél jelentős külső vérzés esetén, ha a helyszín biztonságos?', '["Leülni és sírni.", "Erős, közvetlen nyomást gyakorolni a sebre tiszta kötszerrel, segítséget hívni és követni a 112 utasításait.", "Lefotózni a sebet Instagramra."]'::jsonb, 1, 'Az elsődleges cél a vérveszteség csökkentése. Beékelődött tárgyat nem húzunk ki; körülötte alkalmazunk nyomást.', 'altalanos'),
    ('Hogyan jelölheted meg a tartózkodási helyedet, ha segítséget vársz a mentőktől az erdőben?', '["Elégetni az összes fát.", "Síppal, zseblámpával vagy jól látható ruhával jelezni, és a helyzetedet megadni a segélyhívásban.", "Csendben megbújni a bokrok között."]'::jsonb, 1, 'Jelzés céljából se gyújts tüzet, ha az veszélyes vagy tiltott; a fény és hang biztonságosabb jelzőeszköz lehet.', 'altalanos'),
    ('Mi a helyes öltözködési elv túrázáskor vagy hűvös időben (a hagyma-elv)?', '["Egyetlen vastag bundakabát viselése póló nélkül.", "Réteges öltözködés: nedvességelvezető alsó réteg, hőtartó középső réteg és szél-/vízálló külső héj.", "Minél kevesebb ruha, hogy eddzük a testet."]'::jsonb, 1, 'Réteges öltözködés: nedvességelvezető alsó réteg, hőtartó középső réteg és szél-/vízálló külső héj.', 'altalanos'),
    ('Melyik eszköz a leghasznosabb tájékozódáshoz, ha lemerült a telefonod GPS-e?', '["Egy kockás füzet.", "Analóg tájoló (kompassz) és papíralapú térkép.", "Egy darab faág."]'::jsonb, 1, 'Analóg tájoló (kompassz) és papíralapú térkép.', 'altalanos');
  END IF;
END
$$;

-- ============================================================================
-- 2. RENDEZVÉNY KVÍZEK TÁBLA (quiz_events)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.quiz_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text UNIQUE NOT NULL,
  title text NOT NULL,
  selected_categories text[] NOT NULL DEFAULT ARRAY['altalanos'],
  question_count int NOT NULL DEFAULT 10,
  min_score int NOT NULL DEFAULT 8,
  staff_pin text NOT NULL DEFAULT '1234',
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.quiz_events
  ADD COLUMN IF NOT EXISTS selected_categories text[] NOT NULL DEFAULT ARRAY['altalanos'];

ALTER TABLE public.quiz_events
  ALTER COLUMN min_score SET DEFAULT 8;

ALTER TABLE public.quiz_events
  DROP CONSTRAINT IF EXISTS quiz_events_question_count_check;

ALTER TABLE public.quiz_events
  ADD CONSTRAINT quiz_events_question_count_check CHECK (question_count BETWEEN 1 AND 200);

-- ============================================================================
-- 3. RENDEZVÉNY KITÖLTÉSEK ÉS KÜRTŐSKALÁCS KUPONOK (quiz_event_submissions)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.quiz_event_submissions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id uuid NOT NULL REFERENCES public.quiz_events(id) ON DELETE CASCADE,
  device_hash text NOT NULL,
  started_at timestamptz NOT NULL DEFAULT now(),
  completed_at timestamptz,
  score int,
  reward_code text UNIQUE,
  is_redeemed boolean NOT NULL DEFAULT false,
  UNIQUE(event_id, device_hash)
);

CREATE INDEX IF NOT EXISTS idx_quiz_event_submissions_event_id
  ON public.quiz_event_submissions(event_id);

-- RLS (Row Level Security) és jogosultságok
ALTER TABLE public.quiz_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quiz_event_submissions ENABLE ROW LEVEL SECURITY;

GRANT SELECT ON public.quiz_events TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON public.quiz_events TO authenticated;

GRANT SELECT, INSERT, UPDATE ON public.quiz_event_submissions TO anon, authenticated;
GRANT DELETE ON public.quiz_event_submissions TO authenticated;

-- Korábbi szűkítő policy-k eltávolítása, ha léteztek
DROP POLICY IF EXISTS quiz_events_admin_all ON public.quiz_events;
DROP POLICY IF EXISTS quiz_event_submissions_admin_all ON public.quiz_event_submissions;

-- Bárki olvashatja az eseményeket (vendég QR-kódos megnyitáshoz)
DROP POLICY IF EXISTS "Public read active quiz events" ON public.quiz_events;
CREATE POLICY "Public read active quiz events" ON public.quiz_events
  FOR SELECT USING (true);

-- Belépett szervezők teljes körűen kezelhetik az eseményeket
DROP POLICY IF EXISTS "Authenticated manage quiz events" ON public.quiz_events;
CREATE POLICY "Authenticated manage quiz events" ON public.quiz_events
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- Vendégek rögzíthetik és frissíthetik a saját kitöltésüket, szervezők mindent látnak
DROP POLICY IF EXISTS "Public insert quiz submissions" ON public.quiz_event_submissions;
CREATE POLICY "Public insert quiz submissions" ON public.quiz_event_submissions
  FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Public select quiz submissions" ON public.quiz_event_submissions;
CREATE POLICY "Public select quiz submissions" ON public.quiz_event_submissions
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Public update quiz submissions" ON public.quiz_event_submissions;
CREATE POLICY "Public update quiz submissions" ON public.quiz_event_submissions
  FOR UPDATE USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Authenticated delete quiz submissions" ON public.quiz_event_submissions;
CREATE POLICY "Authenticated delete quiz submissions" ON public.quiz_event_submissions
  FOR DELETE TO authenticated USING (true);

-- Biztonságos eseménytörlő RPC (a hozzátartozó kitöltésekkel együtt törli a kiválasztott eseményt)
CREATE OR REPLACE FUNCTION public.delete_quiz_event(p_event_id uuid)
RETURNS boolean
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_deleted uuid;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'UNAUTHORIZED' USING ERRCODE = '42501';
  END IF;

  DELETE FROM public.quiz_events
  WHERE id = p_event_id
  RETURNING id INTO v_deleted;

  RETURN v_deleted IS NOT NULL;
END;
$$;

REVOKE ALL ON FUNCTION public.delete_quiz_event(uuid) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.delete_quiz_event(uuid) TO authenticated;

-- ============================================================================
-- 4. 40 ÚJ KVÍZKÉRDÉS BETÖLTÉSE (4 ÚJ KATEGÓRIÁBAN, DUPLIKÁCIÓMENTESEN)
-- ============================================================================
INSERT INTO public.quiz_questions (question, options, correct_index, explanation, category)
SELECT v.question, v.options, v.correct_index, v.explanation, v.category
FROM (
  VALUES
    ('Hány lakástűz köthető évente Magyarországon az adventi koszorúkhoz a katasztrófavédelem adatai szerint?', '["Kevesebb mint 5", "Átlagosan 50–70 eset", "Több mint 500 eset"]'::jsonb, 1, 'Évente átlagosan 50–70 lakástűz indul ki adventi koszorúról, jellemzően felügyelet nélkül hagyott gyertya vagy hiányzó alátét miatt.', 'advent'),
    ('Mire kell mindenképpen figyelni az adventi koszorú elhelyezésekor?', '["Közvetlenül a függöny elé tegyük", "Tűzálló alátétre helyezzük, és legyen alatta fém gyertyatartó tüske", "Csak műanyag tálcára szabad tenni"]'::jsonb, 1, 'A leégő kanóc átégetheti a száraz koszorúalapot; a fém gyertyatartó tüske és a nem éghető alátét megakadályozza a tűz továbbterjedését.', 'advent'),
    ('Mi a legfontosabb szabály, ha elhagyod azt a helyiséget, ahol ég az adventi gyertya?', '["Csak akkor kell elfújni, ha 1 óránál tovább vagy távol", "Mindig fújd el a gyertyát, még akkor is, ha csak pár percre mész ki", "Elég, ha becsukod a szobaajtót"]'::jsonb, 1, 'Egy kiszáradt koszorú másodpercek alatt lángra kaphat, ezért nyílt lángot soha nem szabad őrizetlenül hagyni.', 'advent'),
    ('Milyen távolságra kell elhelyezni az égő gyertyát a függönytől, terítőtől vagy más éghető anyagtól?', '["Legalább 10 cm-re", "Legalább 50–100 cm-re, biztonságos távolságra", "Nincs távolsági szabály, ha víz van a közelben"]'::jsonb, 1, 'A huzat vagy a levegő áramlása könnyen a lángba sodorhatja a függönyt, a papírszalvétát vagy a száraz gallyakat.', 'advent'),
    ('Mit tegyél, ha a kiszáradt adventi koszorú vagy a terítő meggyullad?', '["Próbáld meg kézzel lesöpörni az asztalról", "Takard le egy vastag, nedves textíliával vagy használj tűzoltó készüléket", "Nyisd ki az összes ablakot, hogy kimenjen a füst"]'::jsonb, 1, 'A letakarás elzárja az oxigént a tűztől, míg az ablaknyitás huzatot kelt és táplálja a lángokat.', 'advent'),
    ('Mire figyelj a karácsonyi fényfüzérek vásárlásakor és használatakor?', '["Olcsó, jelöletlen piaci füzért is nyugodtan használhatsz kültéren", "Csak magyar nyelvű használati utasítással és CE jelöléssel ellátott terméket vegyél, és éjszakára húzd ki", "A megtört vezetékeket elég celluxszal leragasztani"]'::jsonb, 1, 'A hibás, túlmelegedő égősorok zárlatot okoznak; beltéri fényfüzért pedig szigorúan tilos kültéren használni.', 'advent'),
    ('Mi a biztonságos megoldás kisgyermekes vagy háziállatos háztartásban gyertyagyújtás helyett?', '["Magas polcra tett hagyományos teamécses", "LED-es elemes gyertya vagy mécses használata", "Illatgyertya üvegpohárban a dohányzóasztalon"]'::jsonb, 1, 'Egy kíváncsi háziállat egyetlen mozdulattal leverheti az égő gyertyát – a LED-es gyertya teljesen tűzbiztos.', 'advent'),
    ('Használható-e csillagszóró a karácsonyfán vagy az adventi koszorú felett?', '["Igen, ha vizes vödör van a fa mellett", "Nem, a csillagszóró 1000–1600 °C-os szikrái azonnal meggyújtják a száraz tűleveleket", "Igen, de csak egyszerre egy darab"]'::jsonb, 1, 'A csillagszóró szikrája rendkívül forró, a száraz fenyőág pedig szinte robbanásszerűen, másodpercek alatt lángra kap tőle.', 'advent'),
    ('Hogyan kell elhelyezni a karácsonyfát a lakásban tűzvédelmi szempontból?', '["Közvetlenül a radiátor vagy a kandalló mellé", "Hőforrástól (kályhától, radiátortól) és menekülési útvonaltól (bejárati ajtótól) távol", "A nappali közepén, hosszabbító kábelekkel körbevéve"]'::jsonb, 1, 'A fűtőtestek kiszárítják a fát, ami így sokkal gyúlékonyabbá válik; az ajtó közelében álló égő fa pedig elzárhatja a menekülési utat.', 'advent'),
    ('Mit ne tegyél SOHA, ha a konyhában az ünnepi sütés-főzés közben meggyullad a forró olaj a serpenyőben?', '["Ne önts rá vizet!", "Ne tegyél rá fém fedőt", "Ne kapcsold le a tűzhelyet"]'::jsonb, 0, 'A víz az égő olajba öntve azonnal gőzzé válik, és hatalmas tűzgömbként szétveti a lángoló zsiradékot – fedővel kell elfojtani.', 'advent'),
    ('Mit jelent a meteorológiai szolgálat által kiadott „vörös” (harmadfokú) riasztás hófúvás vagy ónos eső esetén?', '["Csak a teherautóknak tilos közlekedni", "Halaszthatatlan utazáson kívül senki ne induljon útnak, mert a közlekedés életveszélyes", "Csak hólánccal lehet behajtani a városokba"]'::jsonb, 1, 'A legmagasabb, piros fokozatú riasztásnál a közlekedési infrastruktúra megbénulhat, és az elakadt járművek mentése is akadályozott.', 'teli_idojaras'),
    ('Mit tegyél elsőként, ha autóddal hótorlaszban elakadsz a lakott területen kívül?', '["Indulj el gyalog a hóviharban a legközelebbi falu felé", "Maradj a járműben, kapcsold be a vészvillogót, és hívd a 112-t", "Engedd le a gumiabroncsok nyomását"]'::jsonb, 1, 'A jármű védelmet nyújt a szél és a kihűlés ellen, és a mentőegységek is sokkal könnyebben megtalálják, mint egy gyalogost a hóviharban.', 'teli_idojaras'),
    ('Mire kell kiemelten figyelni, ha a hóban elakadt autóban járatod a motort a fűtés miatt?', '["Semmire, a modern autók teljesen biztonságosak", "Rendszeresen ellenőrizd és tisztítsd meg a kipufogócsövet a hótól, és résnyire húzd le az ablakot", "Kapcsold be a belső levegőkeringtetést és zárd le teljesen az ablakokat"]'::jsonb, 1, 'A hóval eltömődött kipufogóból a szén-monoxid visszaáramlik az utastérbe, ami percek alatt halálos mérgezést okozhat.', 'teli_idojaras'),
    ('Milyen alapvető felszerelést érdemes télen az autóban tartani egy váratlan elakadás esetére?', '["Csak egy jégkaparót és tartalék ablaktörlőt", "Meleg takarót, tartalék ruhát, elemlámpát, feltöltött powerbankot, ivóvizet és energiadús élelmet", "Nyári hűtőtáskát és napernyőt"]'::jsonb, 1, 'Hótorlasz vagy útlezárás esetén akár órákat is várakozni kell a mentésre, amikor a testhő megtartása és a telefon feltöltöttsége életmentő.', 'teli_idojaras'),
    ('Mit jelent a szociális ellátórendszerben elrendelt „Vörös kód”?', '["Áramszünet várható az országban", "Extrém hideg miatt minden szociális intézmény köteles befogadni a hajléktalan vagy bajba jutott embereket", "Tilos szabadtéren tüzet gyújtani"]'::jsonb, 1, 'A Vörös kód figyelmezteti a társadalmat a rendkívüli hidegre, és kötelezővé teszi a krízisellátást minden fenntartó számára.', 'teli_idojaras'),
    ('Mi a helyes teendő, ha közterületen egy kihűlés veszélyének kitett, magatehetetlen embert látsz?', '["Adj neki alkoholt, hogy átmelegedjen", "Azonnal hívd a 112-t, és ha biztonságos, maradj vele a mentők kiérkezéséig", "Takard be hóval, mert az szigetel"]'::jsonb, 1, 'Az alkohol tágítja a perifériás ereket, így valójában gyorsítja a test hővesztését és a kihűlést.', 'teli_idojaras'),
    ('Mi a legfontosabb szabály, ha befagyott természetes víz (tó, folyó, csatorna) jegére lépnél?', '["Ha a jég vastagabb 2 cm-nél, már biztonságos", "Csak kijelölt, hatóságilag engedélyezett helyen és nappal szabad a jégre menni; folyóvíz jegére soha", "Ha többen mentek egyszerre, biztonságosabb"]'::jsonb, 1, 'A folyók és csatornák jege az áramlás miatt kiszámíthatatlanul vékonyodik, és a jég alá szorulás szinte azonnal végzetes.', 'teli_idojaras'),
    ('Mit tegyél, ha beszakad alattad a jég?', '["Próbálj azonnal felfelé kapaszkodni a jég peremére a könyököddel", "Hasalj rá a jégre, terjeszd szét a súlyodat, és hason csúszva kússz vissza arra, amerről jöttél", "Merülj le a jég alá és keress másik léket"]'::jsonb, 1, 'A jég széle letörik, ha függőlegesen próbálsz kimászni; hason fekve oszlik el a testsúly, és arra a legbiztosabb a jég, amerre korábban elbírt.', 'teli_idojaras'),
    ('Hogyan közlekedj gyalogosan és autóval ónos eső idején?', '["A megszokott sebességgel, csak nagyobb követési távolsággal", "Ónos esőben a jégréteg miatt még a téli gumi és a sózás sem véd azonnal – csak végszükség esetén indulj el, nagyon lassan", "A bicikliút ilyenkor biztonságosabb, mint a járda"]'::jsonb, 1, 'Az ónos eső azonnal tükörjéggé fagy a hideg burkolaton, amin a járművek irányíthatatlanná válnak.', 'teli_idojaras'),
    ('Hogyan előzheted meg a vízvezetékek elfagyását fűtetlen nyaralóban vagy melléképületben?', '["Hagyj égve egy villanykörtét a fürdőszobában", "Zárd el a főcsapot, és víztelenítsd a teljes csőhálózatot, valamint a bojlert", "Tekerd körbe a csöveket újságpapírral"]'::jsonb, 1, 'A megfagyó víz térfogata megnő, így szétrepeszti a csöveket és a szerelvényeket, ami olvadáskor súlyos vízkárt okoz.', 'teli_idojaras'),
    ('Mi a különbség a hagyományos folyami árvíz és a villámárvíz között?', '["Nincs különbség, csak a víz színe más", "A villámárvíz heves felhőszakadás után percek vagy órák alatt, előjelzés nélkül csap le, főleg domb- és hegyvidéken", "A villámárvíz kizárólag télen alakul ki"]'::jsonb, 1, 'A villámárvizek rendkívül gyors lefolyásúak és nagy sodrásúak, ezért a menekülésre és a védekezésre csupán percek állnak rendelkezésre.', 'arviz_belviz'),
    ('Milyen magasságú vízborítás képes már elsodorni egy felnőtt embert áramló árvíz esetén?', '["Csak a mellkasig érő víz", "Már 15–20 cm-es gyorsan áramló víz is ledönthet a lábadról", "Legalább 1 méteres víz szükséges hozzá"]'::jsonb, 1, 'A mozgó víztömeg ereje hatalmas: már bokáig-lábszárközépig érő sodrás is könnyen elsodor egy felnőttet.', 'arviz_belviz'),
    ('Mikor válik irányíthatatlanná és sodródik el egy személyautó elárasztott útszakaszon?', '["Csak ha a tetőig ér a víz", "Már 30–50 cm-es áramló víz felúszást okoz és elsodorja a járművet", "Soha, az autó súlya megtartja az úton"]'::jsonb, 1, 'Soha ne hajts be elárasztott útszakaszra vagy aluljáróba: az úttest alámosódhat, a felhajtóerő pedig felemeli az autót.', 'arviz_belviz'),
    ('Mi az elsődleges teendő az épület közműveivel, ha az ingatlant árvíz vagy betörő belvíz fenyegeti?', '["Minden lámpát fel kell kapcsolni, hogy jól lássunk", "Áramtalanítani kell a főkapcsolónál, valamint el kell zárni a gáz- és vízcsapot", "Be kell kapcsolni a szivattyút a víz alatt álló pincében"]'::jsonb, 1, 'A víz és az elektromosság találkozása életveszélyes áramütést okoz; áramtalanítás előtt tilos a vízbe lépni.', 'arviz_belviz'),
    ('Hogyan kell helyesen rakni a homokzsákokat védmű építésekor?', '["Függőlegesen egymás mellé állítva", "Kötésben (mint a téglafalat), a zsákok száját a vízfolyás irányával ellentétesen behajtva, és megtaposva", "Csak félig megtöltve, egymásra dobálva"]'::jsonb, 1, 'A kötésben rakott, kb. kétharmadig töltött és jól tömörített zsákok zárnak vízzáróan, és nem csúsznak szét a víznyomás alatt.', 'arviz_belviz'),
    ('Miért veszélyes az árvíz levonulása után azonnal visszatérni a megrongálódott épületbe hatósági engedély nélkül?', '["Mert még vizes a padló", "Az átázott falak és alapok statikailag meggyengülhettek, és fertőzésveszélyes szennyvíz maradt vissza", "Mert nincs térerő"]'::jsonb, 1, 'A víz alámoshatja az alapozást és a közművezetékeket; a visszaköltözést statikai és közegészségügyi ellenőrzésnek kell megelőznie.', 'arviz_belviz'),
    ('Mit tegyél az ivóvízzel és az élelmiszerekkel elöntéssel érintett területen?', '["Forralás nélkül is fogyasztható a csapvíz", "Csak palackozott vagy hatóságilag bevizsgált ivóvizet fogyassz, és dobd ki az árvízzel érintkezett élelmiszert", "Elég megmosni a zöldségeket a kerti kútból"]'::jsonb, 1, 'Az árvíz emésztőgödröket és vegyszertárolókat is elönthet, így a vezetékes és kútvíz is súlyosan szennyeződhet.', 'arviz_belviz'),
    ('Hogyan védekezhetsz otthonodban a csatornarendszeren keresztül visszatorlódó szennyvíz ellen árvíz idején?', '["Semmit nem lehet tenni", "Visszacsapó szelep beépítésével, illetve a padlóösszefolyók ideiglenes lezárásával, lesúlyozásával", "Folyamatos vízengedéssel a csapokból"]'::jsonb, 1, 'A megemelkedett vízszint a csatornahálózaton át a pincékben és földszinti helyiségekben törhet fel, ha nincs visszacsapó szelep.', 'arviz_belviz'),
    ('Mit vigyél magaddal mindenképp, ha a hatóságok elrendelik a lakóhelyed kitelepítését (evakuálását)?', '["Csak a tévét és a konyhai kisgépeket", "Személyi okmányokat, rendszeresen szedett gyógyszereket, ivóvizet, meleg ruhát és feltöltött telefont", "Csak a lakáskulcsot"]'::jsonb, 1, 'A kész előre összekészített vészhelyzeti csomag (túlélőcsomag) percekkel rövidíti le az elindulást, és biztosítja az ellátást a befogadóhelyen.', 'arviz_belviz'),
    ('Mi a belvíz fő jellemzője és kialakulásának oka?', '["A hegyekből lezúduló sárlavina", "Síkvidéki területeken a telített talaj, az olvadó hó és a csapadék miatt a felszínen összegyűlő, elszivárogni nem tudó víz", "A tengeri dagály"]'::jsonb, 1, 'A belvíz lassabban alakul ki, mint a villámárvíz, de hetekig tartó elöntéssel áztatja alá az épületeket és teszi tönkre a termést.', 'arviz_belviz'),
    ('Szabad-e belterületen (kertben) avart és kerti zöldhulladékot égetni Magyarországon?', '["Igen, bármikor korlátozás nélkül", "Alapesetben tilos, kivéve ha a helyi önkormányzat rendelete meghatározott napokon kifejezetten engedélyezi", "Csak vasárnap délután szabad"]'::jsonb, 1, 'Az országos szabályozás tiltja a belterületi avarégetést; kizárólag ott és akkor szabad, ahol ezt helyi önkormányzati rendelet szabályozza.', 'szabadteri_tuz'),
    ('Mit jelent az Országos Tűzgyújtási Tilalom elrendelése?', '["Csak a lakásban tilos gyertyát gyújtani", "Tilos tüzet gyújtani az erdőkben, fásításokban és azok 200 méteres körzetében – még a kijelölt tűzrakóhelyeken is", "Csak szalonnasütésre vonatkozik"]'::jsonb, 1, 'Fokozott tűzveszély idején a kijelölt erdei tűzrakóhelyek használata is szigorúan tilos a száraz aljnövényzet miatt.', 'szabadteri_tuz'),
    ('Mekkora bírsággal sújtható, aki megszegi a tűzgyújtási tilalmat vagy gondatlanságból szabadtéri tüzet okoz?', '["Csak szóbeli figyelmeztetés jár érte", "Akár 100 000 és 3 000 000 Ft közötti tűzvédelmi bírsággal, plusz a tűzoltás költségeivel", "Maximum 5 000 Ft helyszíni bírsággal"]'::jsonb, 1, 'A szabadtéri tüzek hatalmas természeti és anyagi kárt okoznak, ezért a hatóság magas bírságot szab ki, és behajtja a vonulási költségeket is.', 'szabadteri_tuz'),
    ('Mire kell figyelni, ha a saját kertedben grillezel vagy bográcsozol?', '["Elég, ha a tűz meggyújtása után bemész a házba", "A tüzet soha nem szabad őrizetlenül hagyni, és mindig legyen kéznél oltóanyag (pl. vödör víz, kerti slag vagy homok)", "Szeles időben még jobban ég a parázs, olyankor érdemes"]'::jsonb, 1, 'Egyetlen hirtelen széllökés is parazsat fújhat a száraz fűbe vagy a szomszédos tujasorba – az azonnali oltóanyag életmentő.', 'szabadteri_tuz'),
    ('Hogyan kell helyesen eloltani a szabadtéri tüzet a program végén?', '["Elég rárúgni egy kis száraz füvet", "Bő vízzel vagy földdel teljesen le kell hűteni a parazsat, amíg már egyáltalán nem füstöl és nem izzik", "Meg kell várni, amíg magától kialszik másnapra"]'::jsonb, 1, 'A hamu alatt megbújó parázs órákkal később, a szél feltámadásával újra lángra lobbanhat.', 'szabadteri_tuz'),
    ('Miért különösen veszélyes a tavaszi száraz fű és nádas felgyújtása (tarlóégetés)?', '["Mert füstös lesz a ruha", "A száraz növényzetben a tűz futótűzként, akár 30–40 km/h sebességgel terjed, és pillanatok alatt elérheti a lakóházakat és erdőket", "Mert elriasztja a madarakat"]'::jsonb, 1, 'A tarló- és nádaségetés tilos és életveszélyes: a szélirány megváltozása a tűzgyújtót is körbezárhatja.', 'szabadteri_tuz'),
    ('Miért okozhat erdőtüzet egy eldobott üvegpalack vagy üvegszilánk a természetben?', '["Mert megvágja az állatokat", "A napsugarakat összegyűjtve nagyítóként (gyújtólencseként) működik, és meggyújtja a száraz avart", "Mert vegyi reakcióba lép az esővízzel"]'::jsonb, 1, 'Az üvegben megtörő napfény könnyedén eléri a száraz levelek és fűszálak gyulladási hőmérsékletét.', 'szabadteri_tuz'),
    ('Hogyan szabad megszabadulni a cigarettacsikktől autóban vagy kirándulás közben?', '["Ki kell dobni az autó ablakán az út szélére", "Csak teljesen elnyomva, hamutartóban vagy zárt fém tárolóban szabad elhelyezni – soha ne dobd el a természetben", "Elég a cipőtalppal rálépni az erdei ösvényen"]'::jsonb, 1, 'Az út menti száraz gaz és az erdei avar az eldobott, még parázsló csikkektől gyullad meg leggyakrabban.', 'szabadteri_tuz'),
    ('Mit tegyél azonnal, ha szabadtéri tüzet (füstöt vagy lángokat) észlelsz a határban vagy az erdőben?', '["Menj közel és készíts videót a közösségi médiára", "Távolodj el biztonságos irányba (széliránnyal szemben vagy oldalirányba), és azonnal hívd a 112-t a pontos helyszín megadásával", "Próbáld meg egyedül megállítani a több méteres lángfalat"]'::jsonb, 1, 'A gyors jelzés kulcsfontosságú, hogy a tűzoltók még a tűz továbbterjedése előtt beavatkozhassanak.', 'szabadteri_tuz'),
    ('Hogyan teheted tűzbiztosabbá a házad környékét tavasszal és nyáron?', '["Hagyj magasra nőtt száraz gazt a kerítés mellett", "Tartsd rendben és nyírd rendszeresen a füvet az épület körül, távolítsd el a száraz gallyakat és az ereszcsatornában felgyűlt avart", "Tárolj tűzifát közvetlenül a nyitott terasz alatt"]'::jsonb, 1, 'Az épület körüli védőzóna megakadályozza, hogy egy esetleges szomszédos vegetációtűz átterjedjen a tetőszerkezetre.', 'szabadteri_tuz')
) AS v(question, options, correct_index, explanation, category)
WHERE NOT EXISTS (
  SELECT 1 FROM public.quiz_questions q WHERE q.question = v.question
);

NOTIFY pgrst, 'reload schema';

COMMIT;
