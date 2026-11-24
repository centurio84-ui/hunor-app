begin;

-- 1. Szektorok (kijelolt palyak): induljon uresen, szerkesztheto nevvel, ICMS nevvel es leirassal
drop trigger if exists add_default_exercise_sectors on public.exercises;

do $$
declare
  is_gen text;
begin
  select is_generated into is_gen
  from information_schema.columns
  where table_schema = 'public'
    and table_name = 'exercise_sectors'
    and column_name = 'name';
  if is_gen = 'ALWAYS' then
    execute 'alter table public.exercise_sectors alter column name drop expression';
  end if;
end $$;

alter table public.exercise_sectors
  alter column name set not null,
  add column if not exists icms_name text not null default '',
  add column if not exists description text not null default '';

grant select, delete,
  insert (exercise_id, number, name, icms_name, description),
  update (name, icms_name, description)
  on public.exercise_sectors to authenticated;

drop function if exists public.create_planning_sector(uuid);
drop function if exists public.create_planning_sector(uuid, text, text, text);

create function public.create_planning_sector(
  p_exercise_id uuid,
  p_name text default null,
  p_icms_name text default '',
  p_description text default ''
)
returns setof public.exercise_sectors
language plpgsql
volatile
security invoker
set search_path = ''
as $$
declare
  v_next integer;
  v_name text;
begin
  if not exists (select 1 from public.exercises where id = p_exercise_id) then
    raise exception 'Exercise not found' using errcode = 'P0002';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_exercise_id::text, 0)
  );

  select coalesce(max(number), 0) + 1 into v_next
  from public.exercise_sectors
  where exercise_id = p_exercise_id;

  v_name := nullif(btrim(coalesce(p_name, '')), '');
  if v_name is null then
    v_name := 'ROM ' || v_next::text;
  end if;

  return query
    insert into public.exercise_sectors (exercise_id, number, name, icms_name, description)
    values (
      p_exercise_id,
      v_next,
      v_name,
      btrim(coalesce(p_icms_name, '')),
      btrim(coalesce(p_description, ''))
    )
    returning *;
end;
$$;

revoke all on function public.create_planning_sector(uuid, text, text, text)
  from public, anon, authenticated;
grant execute on function public.create_planning_sector(uuid, text, text, text)
  to authenticated;

-- 2. INSARAG IEC/R teljes katalogus (4-16. szekcio, magyarul, elore megadott ido nelkul)
do $$
declare
  c record;
begin
  for c in
    select conname
    from pg_constraint
    where conrelid = 'public.insarag_checkpoint_catalog'::regclass
      and contype = 'c'
      and pg_get_constraintdef(oid) ilike '%category%'
  loop
    execute format('alter table public.insarag_checkpoint_catalog drop constraint %I', c.conname);
  end loop;
end $$;

alter table public.insarag_checkpoint_catalog
  add column if not exists clarification_hu text,
  add column if not exists is_active boolean not null default true;

-- Korabbi 21 roviditett minta-tetel inaktivalasa (FK-biztosan, torles nelkul)
update public.insarag_checkpoint_catalog
set is_active = false
where code like 'HUNOR-%';

insert into public.insarag_checkpoint_catalog (
  code, title, title_hu, title_en, category, default_duration_hours, clarification_hu, sort_order, is_active
) values
  ('INSARAG-4.1.1', '4.1.1 Vezetés (Management) – INSARAG szerinti felépítés', '4.1.1 Vezetés (Management) – INSARAG szerinti felépítés', 'USAR team organisation: Management', '4', null, 'A USAR csapat szervezeti felépítése az INSARAG irányelvek szerint a vezetés területén.', 100, true),
  ('INSARAG-4.1.2', '4.1.2 Kutatás (Search) – INSARAG szerinti felépítés', '4.1.2 Kutatás (Search) – INSARAG szerinti felépítés', 'USAR team organisation: Search', '4', null, 'A USAR csapat szervezeti felépítése az INSARAG irányelvek szerint a kutatás területén.', 101, true),
  ('INSARAG-4.1.3', '4.1.3 Mentés (Rescue) – INSARAG szerinti felépítés', '4.1.3 Mentés (Rescue) – INSARAG szerinti felépítés', 'USAR team organisation: Rescue', '4', null, 'A USAR csapat szervezeti felépítése az INSARAG irányelvek szerint a mentés területén.', 102, true),
  ('INSARAG-4.1.4', '4.1.4 Logisztika (Logistics) – INSARAG szerinti felépítés', '4.1.4 Logisztika (Logistics) – INSARAG szerinti felépítés', 'USAR team organisation: Logistics', '4', null, 'A USAR csapat szervezeti felépítése az INSARAG irányelvek szerint a logisztika területén.', 103, true),
  ('INSARAG-4.1.5', '4.1.5 Egészségügy (Medical) – INSARAG szerinti felépítés', '4.1.5 Egészségügy (Medical) – INSARAG szerinti felépítés', 'USAR team organisation: Medical', '4', null, 'A USAR csapat szervezeti felépítése az INSARAG irányelvek szerint az egészségügy területén.', 104, true),
  ('INSARAG-4.2', '4.2 Elegendő személyi állomány a folyamatos munkavégzéshez', '4.2 Elegendő személyi állomány a folyamatos munkavégzéshez', 'Sufficient personnel to work continuously', '4', null, 'Light: 12 óra/nap, 1 helyszín, 5 nap (ASR 3). Medium: 24 óra/nap, 1 helyszín, 7 nap. Heavy: 24 óra/nap, 2 helyszín párhuzamosan, 10 nap.', 105, true),
  ('INSARAG-4.3', '4.3 Minimum 2:1 létszám-redundancia (keresőkutyákkal együtt)', '4.3 Minimum 2:1 létszám-redundancia (keresőkutyákkal együtt)', 'Minimum redundancy ratio of 2:1 including search dogs', '4', null, 'Minden bevetett beosztáshoz tartalék fő/K9 szükséges (pl. 1 mérnökhöz összesen 2, 4 kutyához összesen 8 a teljes állományban).', 106, true),
  ('INSARAG-5.1', '5.1 Önellátási képesség a bevetés teljes időtartamára', '5.1 Önellátási képesség a bevetés teljes időtartamára', 'Ability to be self-sufficient for duration of deployment', '5', null, 'Elegendő ivó- és használati víz, élelmiszer és gyógyszer. Raktárszemlén igazolandó; terepre elég a gyakorlathoz szükséges mennyiség.', 107, true),
  ('INSARAG-5.2', '5.2 Pénzügyi önellátás a bevetés ideje alatt', '5.2 Pénzügyi önellátás a bevetés ideje alatt', 'Ability to be financially self-sufficient', '5', null, 'Üzemanyag, szállítás, faanyag és műveleti anyagok finanszírozása az érintett országban.', 108, true),
  ('INSARAG-5.3', '5.3 Felszereléskészlet figyelése, karbantartása és kalibrálása', '5.3 Felszereléskészlet figyelése, karbantartása és kalibrálása', 'System to monitor and maintain equipment cache', '5', null, 'Bevetés előtt és alatt is naprakész karbantartás, érvényes kalibrációs és felülvizsgálati tanúsítványok.', 109, true),
  ('INSARAG-6.1', '6.1 Nemzetközi környezetre felkészítő specifikus képzés (mind az 5 komponens)', '6.1 Nemzetközi környezetre felkészítő specifikus képzés (mind az 5 komponens)', 'Specific training for international environment', '6', null, 'Képzési rendszer áttekintése angol összefoglalóval, külső tagokra is kiterjedve (K9, EÜ, mérnökök).', 110, true),
  ('INSARAG-6.1.1', '6.1.1 INSARAG, kulturális, etikai, magatartási kódex (IFRC) és OCHA humanitárius elvek', '6.1.1 INSARAG, kulturális, etikai, magatartási kódex (IFRC) és OCHA humanitárius elvek', 'INSARAG Awareness, Cultural Awareness, Ethics, Code of Conduct, OCHA Humanitarian Principles', '6', null, 'A minősítők ellenőrzik az OCHA humanitárius alapelvekre vonatkozó képzési programot.', 111, true),
  ('INSARAG-6.1.2', '6.1.2 Biztonság és védelem – UN DSS BSAFE', '6.1.2 Biztonság és védelem – UN DSS BSAFE', 'Safety & Security – UN DSS BSAFE', '6', null, 'Preferált az UN-DSS online képzés; eltérés esetén előzetes egyeztetés a Titkársággal.', 112, true),
  ('INSARAG-6.1.3', '6.1.3 Megfelelő számú angolul beszélő, olvasó és író UC személyzet', '6.1.3 Megfelelő számú angolul beszélő, olvasó és író UC személyzet', 'Sufficient personnel for UC activities able to speak, read and write English', '6', null, 'Minden RDC-ben és UCC-ben dolgozó UC tag funkcionális angol nyelvtudással rendelkezzen.', 113, true),
  ('INSARAG-6.1.4', '6.1.4 UC módszertanban és ICMS használatban képzett személyzet', '6.1.4 UC módszertanban és ICMS használatban képzett személyzet', 'Sufficient personnel trained in UC methodology', '6', null, 'Light: min. 1 fő, Medium: min. 2 fő, Heavy: min. 4 fő UC személyzet ICMS ismerettel.', 114, true),
  ('INSARAG-6.2', '6.2 Folyamatos készségfenntartó és szinten tartó képzési program', '6.2 Folyamatos készségfenntartó és szinten tartó képzési program', 'Continuous skills maintenance program', '6', null, 'Bevetések, éves gyakorlatok és korábbi IEC/R jelentések tanulságaira épülő képzés, angol összefoglalóval.', 115, true),
  ('INSARAG-6.3', '6.3 Aktív részvétel INSARAG tevékenységekben és gyakorlatokban', '6.3 Aktív részvétel INSARAG tevékenységekben és gyakorlatokban', 'Evidence of active participation in INSARAG-related activities', '6', null, 'INSARAG találkozókon és gyakorlatokon való részvétel igazolása a POE anyagban.', 116, true),
  ('INSARAG-6.4', '6.4 Személyi képzési nyilvántartások naprakész vezetése', '6.4 Személyi képzési nyilvántartások naprakész vezetése', 'USAR team personnel training records updated and maintained', '6', null, 'Minden csapattag képzési nyilvántartása frissítve és karbantartva.', 117, true),
  ('INSARAG-7.1', '7.1 Kommunikációs eszközök megléte és üzemeltetése (nem csak mobiltelefon)', '7.1 Kommunikációs eszközök megléte és üzemeltetése (nem csak mobiltelefon)', 'Ability to communicate (not solely reliant on mobile phone)', '7', null, 'A gyakorlat első 3 órájában a csapat nem támaszkodhat kizárólag mobiltelefon-alapú kommunikációra.', 118, true),
  ('INSARAG-7.1.1', '7.1.1 Belső kommunikáció és rádiók klónozása frekvenciaváltáshoz', '7.1.1 Belső kommunikáció és rádiók klónozása frekvenciaváltáshoz', 'Internal communication & radio cloning', '7', null, 'Csapattagok közötti kommunikáció; rádiók átprogramozása/klónozása érkezés után.', 119, true),
  ('INSARAG-7.1.2', '7.1.2 Külső kommunikáció (RDC, UCC/SCC és LEMA)', '7.1.2 Külső kommunikáció (RDC, UCC/SCC és LEMA)', 'External communication with RDC, UCC/SCC and LEMA', '7', null, 'Megbízható külső kapcsolat az RDC, UCC/SCC és LEMA irányába.', 120, true),
  ('INSARAG-7.1.3', '7.1.3 Nemzetközi kommunikáció a hazai háttértámogató csoporttal', '7.1.3 Nemzetközi kommunikáció a hazai háttértámogató csoporttal', 'International communication with home country base support team', '7', null, 'Folyamatos összeköttetés a hazai háttértámogató központtal.', 121, true),
  ('INSARAG-7.2', '7.2 GPS technológia és térképkészítő szoftver használata', '7.2 GPS technológia és térképkészítő szoftver használata', 'Use of GPS technology to produce maps', '7', null, 'GPS eszközök és szoftver alkalmazása a műveletek térképezéséhez.', 122, true),
  ('INSARAG-8.1', '8.1 USAR csapat személyi jegyzéke (Personnel Manifest – angolul)', '8.1 USAR csapat személyi jegyzéke (Personnel Manifest – angolul)', 'USAR Team Personnel Manifest', '8', null, 'Név, születési dátum, útlevélszám, lejárat angolul. Előre legyártott névsor nem fogadható el.', 123, true),
  ('INSARAG-8.2', '8.2 USAR Team Fact Sheet (2 nyomtatott + 1 elektronikus példány)', '8.2 USAR Team Fact Sheet (2 nyomtatott + 1 elektronikus példány)', 'USAR Team Fact Sheet', '8', null, 'Kitöltött USAR Team Fact Sheet 2 nyomtatott és 1 elektronikus példányban.', 124, true),
  ('INSARAG-8.3', '8.3 Vészhelyzeti kapcsolattartók adatai', '8.3 Vészhelyzeti kapcsolattartók adatai', 'Emergency contacts details of USAR team', '8', null, 'Hozzáférés a bevetett tagok személyes vészhelyzeti elérhetőségeihez hazai háttéren vagy helyszínen keresztül.', 125, true),
  ('INSARAG-8.4', '8.4 Felszerelési jegyzék (Equipment Manifest) funkciók szerint, angolul', '8.4 Felszerelési jegyzék (Equipment Manifest) funkciók szerint, angolul', 'Equipment Manifest including communications equipment', '8', null, 'Dobozcímkézés (kód, súly, térfogat), leltár, rakodási terv; min. 2 nyomtatott + 1 elektronikus példány angolul.', 126, true),
  ('INSARAG-8.5', '8.5 Veszélyes áru nyilatkozat (Shippers Declaration – IATA DGR)', '8.5 Veszélyes áru nyilatkozat (Shippers Declaration – IATA DGR)', 'Shippers Declarations for Dangerous Goods (DGR)', '8', null, 'Angol nyelvű IATA nyilatkozat polgári gépre, vagy nemzeti katonai szabvány katonai légi szállításra.', 127, true),
  ('INSARAG-8.6', '8.6 Ellenőrzött szerek / kábító hatású gyógyszerek jegyzéke (angolul)', '8.6 Ellenőrzött szerek / kábító hatású gyógyszerek jegyzéke (angolul)', 'Manifest of Controlled Substances (e.g. medications)', '8', null, 'Külön aláírt lista (pl. morfin-szulfát) az EÜ felelős aláírásával, min. 2 nyomtatott + 1 elektronikus példányban.', 128, true),
  ('INSARAG-8.7', '8.7 ICT / Kommunikációs eszközök adatbázisa (angolul)', '8.7 ICT / Kommunikációs eszközök adatbázisa (angolul)', 'Database of ICT/Communications equipment', '8', null, 'Rádiók, mobiltelefonok, műholdas eszközök típusa, sorozatszáma, frekvenciatartománya; 2 nyomtatott + 1 elektronikus példány.', 129, true),
  ('INSARAG-8.8.1', '8.8.1 Útlevelek (min. 6 hónap érvényesség, 2 üres oldal)', '8.8.1 Útlevelek (min. 6 hónap érvényesség, 2 üres oldal)', 'Passport validity and copies', '8', null, 'Min. 6 hónap érvényesség, 2 üres oldal; 2 nyomtatott és 1 elektronikus másolat.', 130, true),
  ('INSARAG-8.8.2', '8.8.2 Vízumügyintézési eljárás és igazolványképek', '8.8.2 Vízumügyintézési eljárás és igazolványképek', 'Visa process and passport photos', '8', null, 'Igazolványképek minden taghoz és eljárás a bevetés előtti vízumkövetelmények tisztázására.', 131, true),
  ('INSARAG-8.8.3', '8.8.3 Kötelező védőoltások listája', '8.8.3 Kötelező védőoltások listája', 'List of required vaccinations', '8', null, 'Az EÜ vezetés és a hazai egészségügyi hatóságok által meghatározott oltási lista.', 132, true),
  ('INSARAG-8.8.4', '8.8.4 Védőoltási nyilvántartás (WHO oltási könyv)', '8.8.4 Védőoltási nyilvántartás (WHO oltási könyv)', 'Record of required vaccinations (WHO Certificate)', '8', null, 'WHO nemzetközi oltási bizonyítvány vagy nemzeti egyenértékű igazolás minden tagnál.', 133, true),
  ('INSARAG-8.8.5', '8.8.5 Egészségügyi személyzet érvényes működési engedélyei (angol összefoglalóval)', '8.8.5 Egészségügyi személyzet érvényes működési engedélyei (angol összefoglalóval)', 'Valid medical practice documentation', '8', null, 'Minden EÜ szakember érvényes engedélyének másolata, szükség esetén angol magyarázó összefoglalóval.', 134, true),
  ('INSARAG-8.8.6', '8.8.6 Keresőkutyák nemzetközi állategészségügyi és utazási okmányai', '8.8.6 Keresőkutyák nemzetközi állategészségügyi és utazási okmányai', 'Valid search dog health certificates', '8', null, 'Minden ki- és belépési állatorvosi igazolás ellenőrizve (Heavy esetén kötelező).', 135, true),
  ('INSARAG-8.8.7', '8.8.7 Keresőkutyák mikrochipje / tetoválása és kézi leolvasó', '8.8.7 Keresőkutyák mikrochipje / tetoválása és kézi leolvasó', 'Search dog microchip / tattoo & reader', '8', null, 'A mikrochip-leolvasót az egyik kutyavezető kézipoggyászban viszi az azonnali vámellenőrzéshez.', 136, true),
  ('INSARAG-8.8.8', '8.8.8 Nemzetközi bevetési biztosítási mechanizmus', '8.8.8 Nemzetközi bevetési biztosítási mechanizmus', 'Insurance mechanism for international response', '8', null, 'Állami csapatoknál a munkáltatói átfogó fedezet elegendő, külső biztosító igazolása nem szükséges.', 137, true),
  ('INSARAG-9.1', '9.1 Riasztási és mobilizációs rendszer teljes létszám feltöltésére', '9.1 Riasztási és mobilizációs rendszer teljes létszám feltöltésére', 'System to mobilise sufficient USAR team members', '9', null, 'A csapat struktúrájában szereplő összes beosztás feltöltésének képessége.', 138, true),
  ('INSARAG-9.2', '9.2 Létszámhiány azonnali pótlása (2:1 arány alapján)', '9.2 Létszámhiány azonnali pótlása (2:1 arány alapján)', 'System to fill staffing shortages (2:1 ratio)', '9', null, 'Személyi és K9 hiány azonnali pótlása a 2:1 tartalékállományból.', 139, true),
  ('INSARAG-9.3', '9.3 Kiindulási pontra érkezés riasztástól számított 10 órán belül (gyakorlaton 6 óra)', '9.3 Kiindulási pontra érkezés riasztástól számított 10 órán belül (gyakorlaton 6 óra)', 'Arrive at point of departure within 10 hours (6h in exercise)', '9', null, 'IEC/R gyakorlattervezésnél 6 órás időkeretre sűrítve.', 140, true),
  ('INSARAG-9.4', '9.4 USAR Team Fact Sheet kitöltése és feltöltése VO-ra és ICMS-be', '9.4 USAR Team Fact Sheet kitöltése és feltöltése VO-ra és ICMS-be', 'USAR Team Fact Sheet uploaded on VO and ICMS', '9', null, 'Fact Sheet feltöltése a Virtual OSOCC és az ICMS felületre.', 141, true),
  ('INSARAG-9.5.1', '9.5.1 Bevetés előtti eligazítás: Aktuális helyzet és épületszerkezeti jellemzők', '9.5.1 Bevetés előtti eligazítás: Aktuális helyzet és épületszerkezeti jellemzők', 'Pre-deployment briefing: Current situation & structural characteristics', '9', null, 'INSARAG Affected Area sablon alapján a hazai háttércsoport elemzéséből.', 142, true),
  ('INSARAG-9.5.2', '9.5.2 Bevetés előtti eligazítás: Kulturális szempontok', '9.5.2 Bevetés előtti eligazítás: Kulturális szempontok', 'Pre-deployment briefing: Culture', '9', null, 'Helyi kulturális sajátosságok és viselkedési normák ismertetése.', 143, true),
  ('INSARAG-9.5.3', '9.5.3 Bevetés előtti eligazítás: Időjárás és tengerszint feletti magasság', '9.5.3 Bevetés előtti eligazítás: Időjárás és tengerszint feletti magasság', 'Pre-deployment briefing: Weather and altitude', '9', null, 'Éghajlati, időjárási és magassági tényezők ismertetése.', 144, true),
  ('INSARAG-9.5.4', '9.5.4 Bevetés előtti eligazítás: Biztonság, védelem és veszélyek (pl. Hazmat)', '9.5.4 Bevetés előtti eligazítás: Biztonság, védelem és veszélyek (pl. Hazmat)', 'Pre-deployment briefing: Safety, security & hazards (Hazmat)', '9', null, 'Biztonsági helyzet és potenciális veszélyforrások (pl. veszélyes anyagok).', 145, true),
  ('INSARAG-9.5.5', '9.5.5 Bevetés előtti eligazítás: Csapattagok vészhelyzeti evakuálása', '9.5.5 Bevetés előtti eligazítás: Csapattagok vészhelyzeti evakuálása', 'Pre-deployment briefing: Emergency evacuation of team members', '9', null, 'Vészhelyzeti kimenekítési eljárás ismertetése.', 146, true),
  ('INSARAG-9.5.6', '9.5.6 Bevetés előtti eligazítás: Egészségügyi kockázatok és jóllét (K9-cel)', '9.5.6 Bevetés előtti eligazítás: Egészségügyi kockázatok és jóllét (K9-cel)', 'Pre-deployment briefing: Health risks & wellbeing including search dogs', '9', null, 'Egészségügyi kockázatok és jólléti szempontok a személyzetre és a keresőkutyákra.', 147, true),
  ('INSARAG-9.5.7', '9.5.7 Bevetés előtti eligazítás: Különleges vagy szokatlan szempontok', '9.5.7 Bevetés előtti eligazítás: Különleges vagy szokatlan szempontok', 'Pre-deployment briefing: Special or unusual considerations', '9', null, 'Minden egyéb különleges műveleti vagy környezeti szempont.', 148, true),
  ('INSARAG-9.6', '9.6 Indulás előtti egészségügyi szűrés (szabványos adatlapon)', '9.6 Indulás előtti egészségügyi szűrés (szabványos adatlapon)', 'Pre-deployment medical screening', '9', null, 'Alkalmasság, oltások és személyes gyógyszerek ellenőrzése aktiválás után, indulás előtt, külön adatlapon.', 149, true),
  ('INSARAG-9.7', '9.7 Keresőkutyák indulás előtti állatorvosi szűrése és mikrochip ellenőrzés', '9.7 Keresőkutyák indulás előtti állatorvosi szűrése és mikrochip ellenőrzés', 'Pre-deployment veterinary screening of search dogs', '9', null, 'Képzett személy végzi aktiválás után, indulás előtt, mikrochip leolvasással.', 150, true),
  ('INSARAG-9.8', '9.8 Ellenőrzött gyógyszerek biztonságos felügyeleti lánca (Chain of Control)', '9.8 Ellenőrzött gyógyszerek biztonságos felügyeleti lánca (Chain of Control)', 'Secure chain of control for restricted medications', '9', null, 'Szigorú tárolás, készletnyilvántartás, kiadás, selejtezés és beadás pontos dokumentálása.', 151, true),
  ('INSARAG-9.9', '9.9 Frissített helyzetkép követése utazás közben (in-transit)', '9.9 Frissített helyzetkép követése utazás közben (in-transit)', 'Monitor updated disaster info while in-transit', '9', null, 'Útközben (pl. tankolási megállónál) helyzetkép, RDC, LEMA, BoO és kapcsolattartók friss elérése.', 152, true),
  ('INSARAG-10.1', '10.1 Műveleti bázis (BoO) helyszínének kijelölése LEMA-val egyeztetve', '10.1 Műveleti bázis (BoO) helyszínének kijelölése LEMA-val egyeztetve', 'Select suitable site for BOO in conjunction with LEMA', '10', null, 'Elsőként érkező csapatként közvetlen egyeztetés LEMA-val, rugalmas elrendezési terv, megosztható terület.', 153, true),
  ('INSARAG-10.2.1', '10.2.1 BoO munkaterület: USAR vezetés (Management)', '10.2.1 BoO munkaterület: USAR vezetés (Management)', 'BOO workspace: USAR management', '10', null, 'Dedikált vezetési munkaterület a bázison.', 154, true),
  ('INSARAG-10.2.2', '10.2.2 BoO munkaterület: Szállás a személyzetnek és tárolás a felszerelésnek', '10.2.2 BoO munkaterület: Szállás a személyzetnek és tárolás a felszerelésnek', 'BOO workspace: Shelter for personnel and equipment', '10', null, 'Megfelelő elhelyezés a tagoknak és eszközöknek.', 155, true),
  ('INSARAG-10.2.3', '10.2.3 BoO biztonság és tűzvédelem, üzemanyag-tárolás, beléptetés', '10.2.3 BoO biztonság és tűzvédelem, üzemanyag-tárolás, beléptetés', 'BOO workspace: Safety and security', '10', null, 'Tűzmegelőzés/jelzés/oltás, üzemanyag és dohányzóhely elhelyezése, beléptetés és létszámkövetés.', 156, true),
  ('INSARAG-10.2.4', '10.2.4 BoO munkaterület: Kommunikációs központ', '10.2.4 BoO munkaterület: Kommunikációs központ', 'BOO workspace: Communications', '10', null, 'Híradó és kommunikációs munkahely kialakítása.', 157, true),
  ('INSARAG-10.2.5', '10.2.5 BoO: Dedikált egészségügyi ellátóhely (személyzet + K9)', '10.2.5 BoO: Dedikált egészségügyi ellátóhely (személyzet + K9)', 'BOO: Dedicated medical treatment area', '10', null, 'Külön ellátóhely a csapattagok és a keresőkutyák számára.', 158, true),
  ('INSARAG-10.2.6', '10.2.6 BoO: Dedikált egészségügyi elkülönítő (izolációs terület)', '10.2.6 BoO: Dedikált egészségügyi elkülönítő (izolációs terület)', 'BOO: Dedicated medical isolation area', '10', null, 'Elkülönített terület fertőző betegség gyanúja esetére.', 159, true),
  ('INSARAG-10.2.7', '10.2.7 BoO: Étkező, élelmiszer- és ivóvíz-tárolás higiéniája', '10.2.7 BoO: Étkező, élelmiszer- és ivóvíz-tárolás higiéniája', 'BOO: Food and water storage and mess area', '10', null, 'Étkező, valamint élelmiszer- és víztároló helyek alkalmassága és higiéniája.', 160, true),
  ('INSARAG-10.2.8', '10.2.8 BoO: Víztisztítás (ivóvíz, tisztálkodás, mentesítés)', '10.2.8 BoO: Víztisztítás (ivóvíz, tisztálkodás, mentesítés)', 'BOO: Water purification for consumption and decontamination', '10', null, 'Víztisztító berendezés felállítása és üzemeltetése a gyakorlat alatt (szükség esetén kiegészíthető).', 161, true),
  ('INSARAG-10.2.9', '10.2.9 BoO: Szaniter, meleg vizes zuhanyzók, kézmosók és tábori WC', '10.2.9 BoO: Szaniter, meleg vizes zuhanyzók, kézmosók és tábori WC', 'BOO: Sanitation and hygiene', '10', null, 'Megfelelő arányú WC/zuhany/kézmosó, meleg folyóvíz a BoO-n, tábori WC minden kárhelyen.', 162, true),
  ('INSARAG-10.2.10', '10.2.10 BoO: Keresőkutya terület (pihenés, futtatás, szükséglet)', '10.2.10 BoO: Keresőkutya terület (pihenés, futtatás, szükséglet)', 'BOO: Search dog area', '10', null, 'Kutyák jólléti területe (lehet a BoO határán kívül is). Heavy esetén kötelező.', 163, true),
  ('INSARAG-10.2.11', '10.2.11 BoO: Felszerelés karbantartó és javító műhely', '10.2.11 BoO: Felszerelés karbantartó és javító műhely', 'BOO: Equipment maintenance and repair area', '10', null, 'Dedikált karbantartó és javító részleg.', 164, true),
  ('INSARAG-10.2.12', '10.2.12 BoO: Hulladékkezelés (általános, szürkevíz, biológiai veszélyes)', '10.2.12 BoO: Hulladékkezelés (általános, szürkevíz, biológiai veszélyes)', 'BOO: Waste management', '10', null, 'LEMA-val egyeztetett hulladékkezelési terv mindhárom hulladéktípusra.', 165, true),
  ('INSARAG-10.2.13', '10.2.13 BoO: Mentesítés (csizmamosó + Piszkos/Tiszta átmeneti zóna)', '10.2.13 BoO: Mentesítés (csizmamosó + Piszkos/Tiszta átmeneti zóna)', 'BOO: Decontamination (boot-wash & Dirty/Clean zone)', '10', null, 'Bejáratnál csizmamosó; piszkos/tiszta átöltöző zóna a bázisra belépés előtt.', 166, true),
  ('INSARAG-11.1', '11.1 Írásos Akciótervek (Plans of Action) folyamatos vezetése és frissítése', '11.1 Írásos Akciótervek (Plans of Action) folyamatos vezetése és frissítése', 'Written Plans of Action continuously updated', '11', null, 'Taktikai, kommunikációs, szállítási tervek, eligazítások és értekezletek írásos rögzítése.', 167, true),
  ('INSARAG-11.2', '11.2 Tervezés: Kommunikációs terv (elérhetőségek, frekvenciák, e-mailek)', '11.2 Tervezés: Kommunikációs terv (elérhetőségek, frekvenciák, e-mailek)', 'Planning: Communications plan', '11', null, 'Kapcsolattartók, rádiófrekvenciák, telefonszám- és e-mail listák.', 168, true),
  ('INSARAG-11.3', '11.3 Tervezés: Egészségügyi kiürítési terv (MEDEVAC – helyi kórház/EMT)', '11.3 Tervezés: Egészségügyi kiürítési terv (MEDEVAC – helyi kórház/EMT)', 'Planning: Medical evacuation', '11', null, 'Súlyosan sérült, beteg vagy elhunyt csapattag kimenekítése kárhelyről/BoO-ról helyi kórházba/EMT-be.', 169, true),
  ('INSARAG-11.4', '11.4 Tervezés: Egészségügyi hazaszállítási terv (Repatriation)', '11.4 Tervezés: Egészségügyi hazaszállítási terv (Repatriation)', 'Planning: Medical repatriation', '11', null, 'Súlyosan sérült/beteg/elhunyt tag hazaszállítása az érintett ország minimális terhelésével.', 170, true),
  ('INSARAG-11.5', '11.5 Tervezés: Műveleti terv (kárhely-kiosztás és műszakciklus)', '11.5 Tervezés: Műveleti terv (kárhely-kiosztás és műszakciklus)', 'Planning: Operations plan', '11', null, 'Munkaterület-kiosztás és taktikai terv az adott műveleti ciklusra.', 171, true),
  ('INSARAG-11.6', '11.6 Tervezés: Biztonsági és védelmi terv (BoO és kárhely evakuálás)', '11.6 Tervezés: Biztonsági és védelmi terv (BoO és kárhely evakuálás)', 'Planning: Safety and security plan', '11', null, 'Beleértve a BoO és a munkaterületek vészhelyzeti kiürítését.', 172, true),
  ('INSARAG-11.7', '11.7 Tervezés: Logisztikai terv (BoO és kárhelyek támogatása)', '11.7 Tervezés: Logisztikai terv (BoO és kárhelyek támogatása)', 'Planning: Logistics plan', '11', null, 'Logisztikai ellátás biztosítása a bázisra és a munkaterületekre.', 173, true),
  ('INSARAG-11.8', '11.8 Tervezés: Szállítási terv (országba és országon belül)', '11.8 Tervezés: Szállítási terv (országba és országon belül)', 'Planning: Transportation plan', '11', null, 'Szállítás szervezése az érintett országba, onnan haza és országon belül.', 174, true),
  ('INSARAG-12.1', '12.1 RDC, UCC vagy SCC felállítása és üzemeltetése', '12.1 RDC, UCC vagy SCC felállítása és üzemeltetése', 'Trained staff & equipment to operate RDC, UCC or SCC', '12', null, 'Több USAR csapat fogadásának szimulálása (Light: 1 fő, Medium: 2 fő, Heavy: 4 fő).', 175, true),
  ('INSARAG-12.2', '12.2 Kötelező INSARAG űrlapok helyes alkalmazása', '12.2 Kötelező INSARAG űrlapok helyes alkalmazása', 'Correctly utilise required INSARAG forms', '12', null, 'Műveletek során az előírt INSARAG nyomtatványok pontos használata.', 176, true),
  ('INSARAG-12.3', '12.3 RDC irányítása INSARAG sablonokkal (ICMS + papír backup)', '12.3 RDC irányítása INSARAG sablonokkal (ICMS + papír backup)', 'RDC utilises INSARAG templates (ICMS + hard copy backup)', '12', null, 'ICMS mellett papír alapú tartalék sablonok internetkimaradás esetére.', 177, true),
  ('INSARAG-12.4', '12.4 UCC/SCC irányítása INSARAG sablonokkal (ICMS + papír backup)', '12.4 UCC/SCC irányítása INSARAG sablonokkal (ICMS + papír backup)', 'UCC/SCC utilises INSARAG templates (ICMS + hard copy backup)', '12', null, 'ICMS mellett papír alapú tartalék sablonok és megjelenítés internetkimaradás esetére.', 178, true),
  ('INSARAG-12.5', '12.5 Kezdő egyeztetés a LEMA-val (LEMA irodában, nem reptéren)', '12.5 Kezdő egyeztetés a LEMA-val (LEMA irodában, nem reptéren)', 'Initial meeting with LEMA at LEMA office', '12', null, 'USAR csapat és UCC képviselők első találkozója a LEMA irodában.', 179, true),
  ('INSARAG-12.6', '12.6 UCC/SCC koordinációs eligazítások tervezése és megtartása', '12.6 UCC/SCC koordinációs eligazítások tervezése és megtartása', 'UCC/SCC plans and conducts coordination briefings', '12', null, 'ASR2 és kárhely-jelentések elemzése, priorizálás és csapatok feladattal való ellátása.', 180, true),
  ('INSARAG-12.7', '12.7 Adatszolgáltatás az UCC felé az ICMS rendszeren keresztül', '12.7 Adatszolgáltatás az UCC felé az ICMS rendszeren keresztül', 'Submit data to UCC using ICMS', '12', null, 'Papír vagy elektronikus adatgyűjtés és beküldés az ICMS-be.', 181, true),
  ('INSARAG-12.8', '12.8 Részvétel az UCC koordinációs értekezletein és feladatok beépítése', '12.8 Részvétel az UCC koordinációs értekezletein és feladatok beépítése', 'Attend UCC coordination briefings', '12', null, 'Képviselő jelenléte minden UCC eligazításon, feladatok beépítése a műveleti tervbe.', 182, true),
  ('INSARAG-12.9', '12.9 UCC jelentési utasításainak követése', '12.9 UCC jelentési utasításainak követése', 'Follow UCC reporting instructions', '12', null, 'Az UCC jelentési rendjének pontos betartása.', 183, true),
  ('INSARAG-13.1', '13.1 Felmérő csoport (Assessment Team) felállítása, felszerelése és eligazítása', '13.1 Felmérő csoport (Assessment Team) felállítása, felszerelése és eligazítása', 'Established assessment team and equipment', '13', null, 'ASR2, veszélyfelismerés (gáz/áram), EÜ támogatás, opcionális K9; híradó, ICMS, biztonsági, EÜ felszerelés és fejadag.', 184, true),
  ('INSARAG-13.2', '13.2 ASR2 végrehajtása és több forrásból történő adatgyűjtés (pl. helyiek)', '13.2 ASR2 végrehajtása és több forrásból történő adatgyűjtés (pl. helyiek)', 'Conduct ASR2 using range of sources', '13', null, 'Kijelölt szektor felmérése, helyi lakosok kikérdezése és információgyűjtés.', 185, true),
  ('INSARAG-13.3', '13.3 Épületszerkezeti állapotfelmérés statikus / képzett szakemberrel', '13.3 Épületszerkezeti állapotfelmérés statikus / képzett szakemberrel', 'Structural assessments with structural engineering expertise', '13', null, 'Statikus/építőmérnök, vagy szerkezetfelmérésre kiképzett személyzet által.', 186, true),
  ('INSARAG-13.4', '13.4 Veszély- és kockázatfelmérés (EÜ, környezeti, biztonsági) és jelentés LEMA-nak', '13.4 Veszély- és kockázatfelmérés (EÜ, környezeti, biztonsági) és jelentés LEMA-nak', 'Hazard/risk assessments disseminated to LEMA via UCC', '13', null, 'Azonosított veszélyek továbbítása az UCC-n keresztül a LEMA felé.', 187, true),
  ('INSARAG-13.5', '13.5 INSARAG Jelölési Rendszer (Marking System) helyes használata ASR2 alatt', '13.5 INSARAG Jelölési Rendszer (Marking System) helyes használata ASR2 alatt', 'Correctly utilise INSARAG Marking System during ASR2', '13', null, 'Szabványos INSARAG kárhely-jelölések alkalmazása.', 188, true),
  ('INSARAG-13.6', '13.6 ASR2 eredmények összegyűjtése és megküldése az UCC/LEMA részére', '13.6 ASR2 eredmények összegyűjtése és megküldése az UCC/LEMA részére', 'Collect and send ASR2 results to UCC/LEMA', '13', null, 'Felmérési eredmények továbbítása az UCC/LEMA felé.', 189, true),
  ('INSARAG-14.1', '14.1 Együttműködés más USAR csapatokkal', '14.1 Együttműködés más USAR csapatokkal', 'Cooperate with other USAR teams', '14', null, 'Együttműködés bemutatása második csapattal vagy forgatókönyvbe épített injektek révén.', 190, true),
  ('INSARAG-14.2', '14.2 Kutató felszerelések kivitele a műveleti kárhelyekre', '14.2 Kutató felszerelések kivitele a műveleti kárhelyekre', 'Take search equipment to operational worksites', '14', null, 'Elérhető információk alapján megfelelő kutató eszközök telepítése.', 191, true),
  ('INSARAG-14.3', '14.3 Mentő felszerelések kivitele a műveleti kárhelyekre', '14.3 Mentő felszerelések kivitele a műveleti kárhelyekre', 'Take rescue equipment to site of operations', '14', null, 'Elérhető információk alapján megfelelő mentő eszközök telepítése.', 192, true),
  ('INSARAG-14.4', '14.4 Egészségügyi és betegkihozó felszerelések kivitele a kárhelyre', '14.4 Egészségügyi és betegkihozó felszerelések kivitele a kárhelyre', 'Take medical and patient extrication equipment to worksite', '14', null, 'Elérhető információk alapján EÜ és kimenekítő felszerelések kivitele.', 193, true),
  ('INSARAG-14.5.1', '14.5.1 Kárhely biztonsági terv (kordon, depó, gyülekezési pont, létszámkövetés)', '14.5.1 Kárhely biztonsági terv (kordon, depó, gyülekezési pont, létszámkövetés)', 'Implement site safety plan before starting USAR operations', '14', null, 'Kordon, eszközdepó, vészhelyzeti gyülekezési pont és létszámkövetés kialakítása.', 194, true),
  ('INSARAG-14.5.2', '14.5.2 Kárhelyi durva mentesítés (betonpor/iszap lemosása BoO előtt)', '14.5.2 Kárhelyi durva mentesítés (betonpor/iszap lemosása BoO előtt)', 'Worksite gross decontamination capability', '14', null, 'Ruházat, bakancs és eszközök letisztítása/lemosása a BoO-ra való visszatérés előtt.', 195, true),
  ('INSARAG-14.5.3', '14.5.3 Tábori WC biztosítása a műveleti kárhelyen', '14.5.3 Tábori WC biztosítása a műveleti kárhelyen', 'Field toilet available at the worksite', '14', null, 'Tábori WC elhelyezése minden aktív munkaterületen.', 196, true),
  ('INSARAG-14.5.4', '14.5.4 Kárhelyi eszközkezelési rendszer (biztonság, visszagyűjtés, tisztítás)', '14.5.4 Kárhelyi eszközkezelési rendszer (biztonság, visszagyűjtés, tisztítás)', 'Equipment management system at worksite', '14', null, 'Folyamatos eszközfelügyelet, használat utáni visszagyűjtés, terepi tisztítás és karbantartás.', 197, true),
  ('INSARAG-14.6.1', '14.6.1 Folyamatos személyi létszámkövetés (Accountability Board)', '14.6.1 Folyamatos személyi létszámkövetés (Accountability Board)', 'Track personnel at all times', '14', null, 'BoO-ból való kilépés, kárhelyi és egyéb mozgások folyamatos követése.', 198, true),
  ('INSARAG-14.6.2', '14.6.2 Evakuálás és gyülekezési ponton létszámellenőrzés (BoO + kárhely)', '14.6.2 Evakuálás és gyülekezési ponton létszámellenőrzés (BoO + kárhely)', 'Conduct evacuation and personnel accountability check', '14', null, 'EXCON injekt alapján mind a BoO, mind a munkaterületek evakuálásának megfigyelése.', 199, true),
  ('INSARAG-14.6.3', '14.6.3 Egyéni védőeszközök (PPE) helyzetnek megfelelő viselése', '14.6.3 Egyéni védőeszközök (PPE) helyzetnek megfelelő viselése', 'Wear personal protective equipment (PPE)', '14', null, 'Sisak, kesztyű, szem-, hallás- és légzésvédelem, védőbakancs + speciális PPE (pl. lángvágás, láncfűrész).', 200, true),
  ('INSARAG-14.6.4', '14.6.4 Biztonsági tiszt (Safety Officer) kijelölése műveletek alatt', '14.6.4 Biztonsági tiszt (Safety Officer) kijelölése műveletek alatt', 'Safety officer assigned during USAR operations', '14', null, 'Rotálható beosztás a mentőcsoporton belül, de minden műveletnél ki kell jelölni.', 201, true),
  ('INSARAG-14.6.5', '14.6.5 INSARAG Jelzőrendszer (Signalling System) helyes alkalmazása', '14.6.5 INSARAG Jelzőrendszer (Signalling System) helyes alkalmazása', 'Correctly utilise INSARAG Signalling system', '14', null, 'Szabványos hang- és fényjelzések (evakuálás, csend, folytatás) helyes használata.', 202, true),
  ('INSARAG-14.6.6', '14.6.6 Épületmozgás-figyelő (monitoring) rendszer alkalmazása', '14.6.6 Épületmozgás-figyelő (monitoring) rendszer alkalmazása', 'Building monitoring system in place', '14', null, 'Elektronikus és/vagy nem elektronikus mozgásfigyelő eszközök használata a romon.', 203, true),
  ('INSARAG-14.7.1', '14.7.1 INSARAG Jelölési Rendszer frissítése a kárhely befejezésekor', '14.7.1 INSARAG Jelölési Rendszer frissítése a kárhely befejezésekor', 'Update INSARAG Marking System upon completion', '14', null, 'Kárhely befejezését követően a szabványos jelölések pontos lezárása.', 204, true),
  ('INSARAG-14.8.1', '14.8.1 Hatékony és koordinált kutatási módszerek', '14.8.1 Hatékony és koordinált kutatási módszerek', 'Effective and coordinated search methods', '14', null, 'Kutatási stratégia integrálása a vezetési és mentési elemekkel.', 205, true),
  ('INSARAG-14.8.2', '14.8.2 Fizikai kutatás: vonalban kutatás és hívás-hallgatózás (Line & Hail)', '14.8.2 Fizikai kutatás: vonalban kutatás és hívás-hallgatózás (Line & Hail)', 'Physical Search: line and hail', '14', null, 'Minden minősítési szinten kötelező; Heavy csapatnál K9 + fizikai + technikai együtt.', 206, true),
  ('INSARAG-14.8.3', '14.8.3 Technikai kutatás: keresőkamerák', '14.8.3 Technikai kutatás: keresőkamerák', 'Technical Search: cameras', '14', null, 'Light, Medium és Heavy szinten kötelező.', 207, true),
  ('INSARAG-14.8.4', '14.8.4 Technikai kutatás: szeizmikus és akusztikus eszközök', '14.8.4 Technikai kutatás: szeizmikus és akusztikus eszközök', 'Technical Search: seismic and acoustic devices', '14', null, 'Light, Medium és Heavy szinten kötelező.', 208, true),
  ('INSARAG-14.8.5', '14.8.5 Keresőkutyás (K9) kutatás romok alatt (min. 4 keresés, nappal/éjjel)', '14.8.5 Keresőkutyás (K9) kutatás romok alatt (min. 4 keresés, nappal/éjjel)', 'Search dogs locate victims under rubble', '14', null, 'Min. 4 kutyás keresés eltérő körülmények között (nappal/éjjel). Heavy szinten kötelező.', 209, true),
  ('INSARAG-14.9.1', '14.9.1 Vasbeton áttörés fej felett (függőlegesen felfelé, 200 mm)', '14.9.1 Vasbeton áttörés fej felett (függőlegesen felfelé, 200 mm)', 'Penetrate reinforced concrete vertically overhead (200mm)', '14', null, '200 mm vastag vasbeton áttörése üregbe, minden szinten.', 210, true),
  ('INSARAG-14.9.2', '14.9.2 Vasbeton áttörés oldalirányban üregbe (200 mm)', '14.9.2 Vasbeton áttörés oldalirányban üregbe (200 mm)', 'Penetrate reinforced concrete laterally (200mm)', '14', null, '200 mm vastag vasbeton oldalsó áttörése, minden szinten.', 211, true),
  ('INSARAG-14.9.3', '14.9.3 Vasbeton áttörés lefelé „dirty” (szennyezett) technikával (200 mm)', '14.9.3 Vasbeton áttörés lefelé „dirty” (szennyezett) technikával (200 mm)', 'Penetrate reinforced concrete vertically below – dirty technique (200mm)', '14', null, '200 mm vasbeton áttörése lefelé, minden szinten.', 212, true),
  ('INSARAG-14.9.4', '14.9.4 Vasbeton áttörés lefelé „clean” (tiszta) technikával (200 mm)', '14.9.4 Vasbeton áttörés lefelé „clean” (tiszta) technikával (200 mm)', 'Penetrate reinforced concrete vertically below – clean technique (200mm)', '14', null, 'Medium és Heavy szinten kötelező (200 mm).', 213, true),
  ('INSARAG-14.9.5', '14.9.5 Vasbeton oszlop vagy gerenda átvágása (Medium 300mm / Heavy 450mm)', '14.9.5 Vasbeton oszlop vagy gerenda átvágása (Medium 300mm / Heavy 450mm)', 'Cut reinforced concrete column or beam', '14', null, 'Forgatókönyvbe integrálva! Medium: 300 mm (12 mm vas), Heavy: 450 mm (18 mm vas).', 214, true),
  ('INSARAG-14.9.6', '14.9.6 Tömör fagerenda átvágása (Light 200mm / Medium-Heavy 300mm)', '14.9.6 Tömör fagerenda átvágása (Light 200mm / Medium-Heavy 300mm)', 'Cut solid timber', '14', null, 'Forgatókönyvbe integrálva! Light: 200 mm, Medium/Heavy: 300 mm.', 215, true),
  ('INSARAG-14.9.7', '14.9.7 Fémlemez átvágása (Light 3mm / Medium 10mm / Heavy 20mm)', '14.9.7 Fémlemez átvágása (Light 3mm / Medium 10mm / Heavy 20mm)', 'Cut metal plate', '14', null, 'Forgatókönyvbe integrálva! Light: 3 mm, Medium: 10 mm, Heavy: 20 mm.', 216, true),
  ('INSARAG-14.9.8', '14.9.8 Szerkezeti acélgerenda (I/H-tartó) átvágása (2x, min. 1 szűk tér + meleg vágás)', '14.9.8 Szerkezeti acélgerenda (I/H-tartó) átvágása (2x, min. 1 szűk tér + meleg vágás)', 'Cut structural steel beam (diagonal >45° & horizontal, hot metal cutting)', '14', null, 'Medium: 127×76 mm; Heavy: 260×102 mm (6,5/10 mm). 1 ferde (>45°), 1 vízszintes; min. 1 szűk térben és min. 1 meleg fémvágással.', 217, true),
  ('INSARAG-14.10.1', '14.10.1 Emelés és mozgatás: Pneumatikus emelőpárnák (Medium 1t / Heavy 2,5t)', '14.10.1 Emelés és mozgatás: Pneumatikus emelőpárnák (Medium 1t / Heavy 2,5t)', 'Lifting and Moving: Pneumatic equipment', '14', null, 'Fokozatos alátámasztás (cribbing) és stabilizálás emelés közben! Medium: 1 MT, Heavy: 2,5 MT.', 218, true),
  ('INSARAG-14.10.2', '14.10.2 Emelés és mozgatás: Hidraulikus eszközök (Light/Med 1t / Heavy 2,5t)', '14.10.2 Emelés és mozgatás: Hidraulikus eszközök (Light/Med 1t / Heavy 2,5t)', 'Lifting and Moving: Hydraulic equipment', '14', null, 'Fokozatos alátámasztás és stabilizálás! Light/Medium: 1 MT, Heavy: 2,5 MT.', 219, true),
  ('INSARAG-14.10.3', '14.10.3 Emelés és mozgatás: Csörlők (Light/Med 1t / Heavy 2,5t)', '14.10.3 Emelés és mozgatás: Csörlők (Light/Med 1t / Heavy 2,5t)', 'Lifting and Moving: Winches', '14', null, 'Kötözés hevederekkel/láncokkal húzáshoz; előregyártott emelőfülek nem használhatók!', 220, true),
  ('INSARAG-14.10.4', '14.10.4 Daruzási műveletek: 5,0 tonnás teher (min. 2 daruzás)', '14.10.4 Daruzási műveletek: 5,0 tonnás teher (min. 2 daruzás)', 'Crane operations: load of 5.0 MT (min. 2 lifts)', '14', null, 'Kötözés és darukezelő irányítása egyeztetett jelzésekkel (előregyártott fülek tilosak), min. 2 emelés.', 221, true),
  ('INSARAG-14.11.1', '14.11.1 Dúcolási kockázatértékelés és terv készítése (csavarozás/rögzítés)', '14.11.1 Dúcolási kockázatértékelés és terv készítése (csavarozás/rögzítés)', 'Shoring risk assessment and plan', '14', null, 'Forgatókönyvbe integrálva; teher felvétele, átadása, elosztása, kötések és keresztmerevítés.', 222, true),
  ('INSARAG-14.11.2', '14.11.2 Dúcolás: Vágóállomás (Cut Station) kialakítása veszélyzónán kívül', '14.11.2 Dúcolás: Vágóállomás (Cut Station) kialakítása veszélyzónán kívül', 'Establish cut station outside danger zone', '14', null, 'Megfelelő szerszámokkal felszerelt szabóállomás biztonságos zónában.', 223, true),
  ('INSARAG-14.11.3', '14.11.3 Dúcolás: Előszerelés veszélyzónán kívül, végső beépítés belül', '14.11.3 Dúcolás: Előszerelés veszélyzónán kívül, végső beépítés belül', 'Construct shores outside danger zone', '14', null, 'Minimális veszélyzónában töltött idő a végső összeállításhoz.', 224, true),
  ('INSARAG-14.11.4', '14.11.4 Dúcolás: Aládúcolás és kiékelés (Cribbing and wedging)', '14.11.4 Dúcolás: Aládúcolás és kiékelés (Cribbing and wedging)', 'Cribbing and wedging when lifting/stabilising loads', '14', null, 'Teheremelés és stabilizálás alatti szakszerű alátámasztás.', 225, true),
  ('INSARAG-14.11.5', '14.11.5 Dúcolás: Ablak- / ajtónyílás stabilizálása', '14.11.5 Dúcolás: Ablak- / ajtónyílás stabilizálása', 'Window/door stabilisation', '14', null, 'Nyílászárók szakszerű megerősítése.', 226, true),
  ('INSARAG-14.11.6', '14.11.6 Dúcolás: Függőleges stabilizálás (Vertical shoring)', '14.11.6 Dúcolás: Függőleges stabilizálás (Vertical shoring)', 'Vertical stabilisation', '14', null, 'Medium és Heavy szinten kötelező.', 227, true),
  ('INSARAG-14.11.7', '14.11.7 Dúcolás: Ferde/támasztó stabilizálás (Diagonal / Raker shoring)', '14.11.7 Dúcolás: Ferde/támasztó stabilizálás (Diagonal / Raker shoring)', 'Diagonal stabilisation', '14', null, 'Medium és Heavy szinten kötelező.', 228, true),
  ('INSARAG-14.11.8', '14.11.8 Dúcolás: Vízszintes stabilizálás (Horizontal shoring)', '14.11.8 Dúcolás: Vízszintes stabilizálás (Horizontal shoring)', 'Horizontal stabilisation', '14', null, 'Medium és Heavy szinten kötelező.', 229, true),
  ('INSARAG-14.11.9', '14.11.9 Dúcolások és alátámasztások folyamatos ellenőrzése (utórengések után is)', '14.11.9 Dúcolások és alátámasztások folyamatos ellenőrzése (utórengések után is)', 'Monitoring of shores and cribbing', '14', null, 'Folyamatos felügyelet és utánhúzás különösen utórengések után.', 230, true),
  ('INSARAG-14.12.1', '14.12.1 Kötéltechnika: Kockázatértékelés és műveleti terv', '14.12.1 Kötéltechnika: Kockázatértékelés és műveleti terv', 'Rope-Work: Risk assessment and plan', '14', null, 'Nemzeti/helyi szabványok szerinti előzetes tervezés.', 231, true),
  ('INSARAG-14.12.2', '14.12.2 Kötéltechnika: Függőleges emelés és eresztés (min. 10 m, élő imitátor)', '14.12.2 Kötéltechnika: Függőleges emelés és eresztés (min. 10 m, élő imitátor)', 'Vertical raising and lowering operation (min. 10m)', '14', null, 'Szimulált „élő” sérült függőleges emelése vagy eresztése legalább 10 méter magasságban.', 232, true),
  ('INSARAG-14.12.3', '14.12.3 Kötéltechnika: Ferde kötélpálya / traverz rendszer (min. 10 m szintkülönbség)', '14.12.3 Kötéltechnika: Ferde kötélpálya / traverz rendszer (min. 10 m szintkülönbség)', 'Traversing system (min. 10m height difference)', '14', null, 'Medium és Heavy szinten kötelező: élő imitátor átjuttatása magas pontról alacsonyra.', 233, true),
  ('INSARAG-14.13.1', '14.13.1 Szűk tér: Kockázatértékelés behatolás előtt', '14.13.1 Szűk tér: Kockázatértékelés behatolás előtt', 'Confined Space: Risk assessment prior to entry', '14', null, 'Behatolás előtti átfogó kockázatértékelés.', 234, true),
  ('INSARAG-14.13.2', '14.13.2 Szűk tér: Biztonságos munkavégzés (PPE, híradó, dúcolás, légfigyelés, szellőztetés)', '14.13.2 Szűk tér: Biztonságos munkavégzés (PPE, híradó, dúcolás, légfigyelés, szellőztetés)', 'Safely conduct operations in confined spaces', '14', null, 'PPE, kommunikáció, dúcolás, légtér-monitorozás és szellőztetés összehangoltan.', 235, true),
  ('INSARAG-14.13.3', '14.13.3 Szűk tér: Vészhelyzeti kimenekítési eljárás behatolás előtt', '14.13.3 Szűk tér: Vészhelyzeti kimenekítési eljárás behatolás előtt', 'Emergency evacuation procedure before confined space entry', '14', null, 'Előre kidolgozott gyors mentési/evakuálási terv.', 236, true),
  ('INSARAG-14.13.4', '14.13.4 Szűk tér: Biztonsági eligazítás behatolás előtt', '14.13.4 Szűk tér: Biztonsági eligazítás behatolás előtt', 'Safety briefing before confined space entry', '14', null, 'Minden behatoló tag előzetes biztonsági eligazítása.', 237, true),
  ('INSARAG-14.13.5', '14.13.5 Szűk tér: Ki- és belépők nyilvántartása (Accountability Board)', '14.13.5 Szűk tér: Ki- és belépők nyilvántartása (Accountability Board)', 'Personnel accountability tracking entering/exiting confined space', '14', null, 'Pontos nyilvántartás a szűk térbe belépő és kilépő személyekről.', 238, true),
  ('INSARAG-14.13.6', '14.13.6 Szűk tér: Folyamatos légtérmérés (gázérzékelőkkel)', '14.13.6 Szűk tér: Folyamatos légtérmérés (gázérzékelőkkel)', 'Continuous air monitoring during confined space operations', '14', null, 'Folyamatos atmoszféra-ellenőrzés a teljes művelet alatt.', 239, true),
  ('INSARAG-14.13.7', '14.13.7 Szűk tér: Légkezelés és szellőztetés (pozitív/negatív nyomású)', '14.13.7 Szűk tér: Légkezelés és szellőztetés (pozitív/negatív nyomású)', 'Air management system (ventilation) in confined space', '14', null, 'Hordozható szellőztető berendezés üzemeltetése szűk téri munkánál.', 240, true),
  ('INSARAG-14.14.1', '14.14.1 Egészségügy: Megelőző és alapellátás a csapattagoknak a teljes bevetés alatt', '14.14.1 Egészségügy: Megelőző és alapellátás a csapattagoknak a teljes bevetés alatt', 'Medical: Preventative and primary care to the team', '14', null, 'Saját állomány folyamatos egészségügyi ellátása.', 241, true),
  ('INSARAG-14.14.2', '14.14.2 Egészségügy: Napi fizikai és mentális állapot/jóllét monitorozás', '14.14.2 Egészségügy: Napi fizikai és mentális állapot/jóllét monitorozás', 'Health and Welfare Monitoring and Treatment', '14', null, 'Csapattagok fizikai és mentális állapotának napi ellenőrzése.', 242, true),
  ('INSARAG-14.14.3', '14.14.3 Egészségügy: 17 USAR/szűk téri EÜ kompetencia (triázs, légút, vérzés, crush, égés stb.)', '14.14.3 Egészségügy: 17 USAR/szűk téri EÜ kompetencia (triázs, légút, vérzés, crush, égés stb.)', 'USAR & confined space medical competencies (17 items)', '14', null, 'Triázs, állapotfelmérés, monitorozás, légút, lélegeztetés, vérzéscsillapítás, rögzítés, vénabiztosítás, fájdalomcsillapítás/szedálás, folyadék, antibiotikum, amputáció, hővédelem, gerincrögzítés, crush, égés.', 243, true),
  ('INSARAG-14.14.4', '14.14.4 Egészségügy: Sérült egyéni védőeszközökkel való ellátása szűk térben', '14.14.4 Egészségügy: Sérült egyéni védőeszközökkel való ellátása szűk térben', 'PPE applied to patient during confined space operations', '14', null, 'Szem-, légzés- és hallásvédelem, szükség esetén sisak/arcvédelem a sérültnek.', 244, true),
  ('INSARAG-14.14.5', '14.14.5 Egészségügy: Terepi amputáció szimulálása szűk térben', '14.14.5 Egészségügy: Terepi amputáció szimulálása szűk térben', 'Field amputation in collapsed structure environment', '14', null, 'Medium és Heavy szinten kötelező: felső vagy alsó végtag szimulált amputációja szűk térben.', 245, true),
  ('INSARAG-14.14.6', '14.14.6 Egészségügy: Crush-szindrómás sérült ellátása szűk térben', '14.14.6 Egészségügy: Crush-szindrómás sérült ellátása szűk térben', 'Treat patient with crush syndrome in collapsed structure', '14', null, 'Crush-szindróma gyakorlati ellátásának bemutatása szűk térben.', 246, true),
  ('INSARAG-14.14.7', '14.14.7 Egészségügy: Sürgősségi állatorvosi ellátás (K9) BoO-n és kárhelyen', '14.14.7 Egészségügy: Sürgősségi állatorvosi ellátás (K9) BoO-n és kárhelyen', 'Emergency veterinary care for search dogs', '14', null, 'Állatorvos, képzett kutyavezető vagy EÜ tag által a BoO-n és a kárhelyeken. Heavy szinten kötelező.', 247, true),
  ('INSARAG-14.14.8', '14.14.8 Egészségügy: Súlyosan sérült/beteg/elhunyt csapattag kezelése (EXCON injekt)', '14.14.8 Egészségügy: Súlyosan sérült/beteg/elhunyt csapattag kezelése (EXCON injekt)', 'Managing serious injury, illness or fatality amongst team members', '14', null, 'Gyakorlattervbe épített injekt a csapattag sérülés/evakuálás protokolljának ellenőrzésére.', 248, true),
  ('INSARAG-14.14.9', '14.14.9 Egészségügy: INSARAG Betegellátási Lap (Patient Treatment Form) használata', '14.14.9 Egészségügy: INSARAG Betegellátási Lap (Patient Treatment Form) használata', 'Utilise INSARAG Patient Treatment Form', '14', null, 'Egy példány átadása a befogadó egészségügyi intézménynek.', 249, true),
  ('INSARAG-14.14.10', '14.14.10 Egészségügy: Ellátott sérültek és csapattagok összesítő nyilvántartása', '14.14.10 Egészségügy: Ellátott sérültek és csapattagok összesítő nyilvántartása', 'Maintain summary of patients treated', '14', null, 'Belső nyilvántartás mind a sérült civilekről, mind az ellátott csapattagokról.', 250, true),
  ('INSARAG-15.1', '15.1 Demobilizációs terv megléte', '15.1 Demobilizációs terv megléte', 'USAR team has a demobilisation plan', '15', null, 'Strukturált kivonulási és hazatelepülési terv.', 251, true),
  ('INSARAG-15.2', '15.2 Kivonulás egyeztetése az UCC/LEMA és RDC szervekkel (EXCON injekt)', '15.2 Kivonulás egyeztetése az UCC/LEMA és RDC szervekkel (EXCON injekt)', 'Coordinate departure with UCC/LEMA and RDC', '15', null, 'Gyakorlattervbe épített injekt a kivonulási koordináció bemutatására.', 252, true),
  ('INSARAG-15.3', '15.3 Felszerelési jegyzék módosítása a felhasznált/adományozott tételek alapján', '15.3 Felszerelési jegyzék módosítása a felhasznált/adományozott tételek alapján', 'Adjust equipment manifest based on used/donated items', '15', null, 'Jegyzék pontos frissítése a visszaszállítandó készlethez.', 253, true),
  ('INSARAG-15.4', '15.4 USAR Team Fact Sheet frissítése demobilizációs adatokkal (UCC felé)', '15.4 USAR Team Fact Sheet frissítése demobilizációs adatokkal (UCC felé)', 'Update USAR Team Factsheet with Demobilisation info', '15', null, 'Kitöltött demobilizációs űrlap megküldése az UCC részére.', 254, true),
  ('INSARAG-15.5', '15.5 Egyeztetés a helyi/diplomáciai képviselővel a kivonulásról (EXCON injekt)', '15.5 Egyeztetés a helyi/diplomáciai képviselővel a kivonulásról (EXCON injekt)', 'Consult with in-country representative regarding departure', '15', null, 'Gyakorlattervbe épített injekt a hazai képviselővel való egyeztetésre.', 255, true),
  ('INSARAG-15.6', '15.6 Státusz frissítése VO-n és ICMS-ben demobilizációra', '15.6 Státusz frissítése VO-n és ICMS-ben demobilizációra', 'Update status on VO and ICMS to demobilising', '15', null, 'Demobilizációs státusz beállítása mindkét rendszerben.', 256, true),
  ('INSARAG-15.7', '15.7 INSARAG Mission Summary Report elkészítése és leadása az UCC-nek', '15.7 INSARAG Mission Summary Report elkészítése és leadása az UCC-nek', 'Complete and submit INSARAG Mission Summary Report to UCC', '15', null, 'Összefoglaló küldetésjelentés leadása indulás előtt.', 257, true),
  ('INSARAG-15.8', '15.8 Mentési fázis zárása után UCC átadás-átvétel OSOCC/LEMA részére', '15.8 Mentési fázis zárása után UCC átadás-átvétel OSOCC/LEMA részére', 'UCC handover for OSOCC / LEMA', '15', null, 'Kárhely-, kimenekítési, demobilizációs és küldetésjelentések, OMT, térképek, fotók átadása.', 258, true),
  ('INSARAG-16.1', '16.1 Saját kiképzett EXCON állomány a terepgyakorlat tervezésére és levezetésére', '16.1 Saját kiképzett EXCON állomány a terepgyakorlat tervezésére és levezetésére', 'Own trained EXCON element to design, set up and run exercises', '16', null, 'A fogadó szervezetnek saját EXCON elemmel kell rendelkeznie közös gyakorlatnál is.', 259, true),
  ('INSARAG-16.2', '16.2 EXCON szimuláció futtatása a VO Simulation Tab-on és ICMS-ben (+ papír backup)', '16.2 EXCON szimuláció futtatása a VO Simulation Tab-on és ICMS-ben (+ papír backup)', 'EXCON sets up and runs simulation on VO & ICMS', '16', null, 'VO és ICMS használata minden fázisban, internetkimaradás esetén papír sablonokkal.', 260, true),
  ('INSARAG-16.3', '16.3 Folyamatosan fejlődő, 36 órás, realisztikus integrált gyakorlatterv', '16.3 Folyamatosan fejlődő, 36 órás, realisztikus integrált gyakorlatterv', '36-hour constantly evolving exercise with integrated scenarios', '16', null, 'Taktikai döntéshozatalt, injekteket, ASR2-t, kárhely-priorizálást és kockázatértékelést igénylő terv.', 261, true),
  ('INSARAG-16.4', '16.4 Minősítők (Classifiers) és INSARAG Titkárság képviselőjének logisztikai támogatása', '16.4 Minősítők (Classifiers) és INSARAG Titkárság képviselőjének logisztikai támogatása', 'Sponsoring organisation provides support for classifiers & Secretariat', '16', null, 'Megfelelő feltételek és támogatás biztosítása a minősítő csapat számára.', 262, true)
on conflict (code) do update set
  title = excluded.title,
  title_hu = excluded.title_hu,
  title_en = excluded.title_en,
  category = excluded.category,
  default_duration_hours = null,
  clarification_hu = excluded.clarification_hu,
  sort_order = excluded.sort_order,
  is_active = true;

commit;
