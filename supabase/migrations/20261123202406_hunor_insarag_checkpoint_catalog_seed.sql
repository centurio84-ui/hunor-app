begin;

alter table public.insarag_checkpoint_catalog
  add column if not exists description_hu text,
  add column if not exists description_en text,
  drop constraint if exists insarag_checkpoint_catalog_category_check;

alter table public.insarag_checkpoint_catalog
  add constraint insarag_checkpoint_catalog_category_check
    check (category in ('ASR', 'SEARCH', 'RESCUE', 'MEDICAL', 'COORDINATION'));

-- Original exercise objectives adapted from the INSARAG IEC/R checklist
-- and the INSARAG Guidelines 2020, Volume II, Manual B, section 5.7.
-- https://insarag.org/guidance-notes/checklists/iec-2/
-- https://insarag.org/wp-content/uploads/2021/06/INSARAG20Guidelines20Vol20II2C20Man20B.pdf
-- HUNOR-* codes and default durations are local planning aids. They are
-- neither official checklist identifiers nor classification time limits.
with checkpoints (
  code, category, sort_order, title_hu, title_en,
  description_hu, description_en, default_duration_hours
) as (
  values
    ('HUNOR-ASR-1', 'ASR', 100,
     'ASR 1 – Nagy területű felmérés', 'ASR 1 – Wide-Area Assessment',
     'Készíts áttekintést az érintett területről, a megközelítési útvonalakról és a beavatkozás lehetséges prioritásairól.',
     'Summarize the affected area, access routes and possible response priorities.',
     1.0),
    ('HUNOR-ASR-2', 'ASR', 110,
     'ASR 2 – Kárhelyek felmérése és rangsorolása', 'ASR 2 – Worksite Triage Assessment',
     'Mérd fel a kijelölt szektor kárhelyeit, és a mentési esélyek, valamint a veszélyek alapján javasolj sorrendet.',
     'Assess worksites in the assigned sector and propose priorities based on rescue potential and hazards.',
     1.5),
    ('HUNOR-ASR-3', 'ASR', 120,
     'ASR 3 – Gyors kutatás-mentés', 'ASR 3 – Rapid Search and Rescue',
     'Végezz gyors kutatás-mentést a kijelölt kárhelyen, és rögzítsd a további beavatkozást igénylő pontokat.',
     'Conduct a rapid search and rescue operation at the assigned worksite and record locations needing follow-up.',
     2.0),
    ('HUNOR-ASR-4', 'ASR', 130,
     'ASR 4 – Teljes körű kutatás-mentés', 'ASR 4 – Full Search and Rescue',
     'Tervezd meg a kijelölt kárhely részletes átkutatását és a műszaki mentést. Dokumentáld az átvizsgált területeket.',
     'Plan a detailed search and technical rescue at the assigned worksite. Document the areas searched.',
     4.0),
    ('HUNOR-ASR-5', 'ASR', 140,
     'ASR 5 – Teljes lefedettségű kutatás és kiemelés', 'ASR 5 – Total Coverage Search and Recovery',
     'A gyakorlat irányításával egyeztetve dokumentáld a teljes kárhely átvizsgálását, a kiemelési feladatokat és a lezárást.',
     'Coordinate with exercise control to document full worksite coverage, recovery tasks and closeout.',
     6.0),

    ('HUNOR-SEARCH-01', 'SEARCH', 200,
     'Személyes kutatás és visszajelzés', 'Physical Search and Reporting',
     'Kutasd át a biztonságosan megközelíthető területeket. Jelentsd a lehetséges sérültpozíciókat és a még át nem vizsgált részeket.',
     'Search safely accessible areas. Report possible casualty locations and areas still to be checked.',
     0.75),
    ('HUNOR-SEARCH-02', 'SEARCH', 210,
     'Mentőkutyás kutatás', 'Canine Search',
     'Egyeztesd a keresési területet a kutyavezetővel, majd jelöld és add tovább a jelzések helyét a mentőegységnek.',
     'Agree the search area with the handler, then mark and report indication locations to the rescue element.',
     1.0),
    ('HUNOR-SEARCH-03', 'SEARCH', 220,
     'Műszeres vizuális kutatás', 'Visual Technical Search',
     'Használj keresőkamerát a kijelölt üregek ellenőrzésére. Rögzítsd, mit sikerült megerősíteni, és mi maradt bizonytalan.',
     'Use a search camera to inspect assigned voids. Record confirmed findings and remaining uncertainties.',
     0.75),
    ('HUNOR-SEARCH-04', 'SEARCH', 230,
     'Műszeres akusztikus kutatás', 'Acoustic Technical Search',
     'Egyeztess csendidőt, ellenőrizd a jelzéseket akusztikus eszközzel, és jelentsd a feltételezett helyet.',
     'Coordinate a quiet period, investigate indications with acoustic equipment and report the suspected location.',
     0.75),

    ('HUNOR-RESCUE-01', 'RESCUE', 300,
     'Szerkezeti stabilizálás és dúcolás', 'Structural Stabilization and Shoring',
     'A jóváhagyott gyakorlópályán értékeld a szerkezeti veszélyeket, és igazold a tervezett megtámasztás ellenőrzését a belépés előtt.',
     'Assess structural hazards on the approved exercise prop and verify the planned stabilization before entry.',
     1.5),
    ('HUNOR-RESCUE-02', 'RESCUE', 310,
     'Hozzáférési nyílás kialakítása vasbetonban', 'Reinforced-Concrete Breaching for Access',
     'A kijelölt gyakorlóelemen alakíts ki hozzáférést a mentési célhoz. Értékeld a sérült és a beavatkozók védelmét.',
     'Create rescue access through the designated training element. Assess protection of the casualty and responders.',
     2.0),
    ('HUNOR-RESCUE-03', 'RESCUE', 320,
     'Teher emelése és mozgatása', 'Load Lifting and Moving',
     'Hajts végre ellenőrzött tehermozgatást a hozzáférés megnyitásához. Egyeztesd a jelzéseket és a veszélyzóna határait.',
     'Carry out a controlled load movement to open an access route. Agree signals and hazard-area boundaries.',
     1.5),
    ('HUNOR-RESCUE-04', 'RESCUE', 330,
     'Sérült kimentése kötéltechnikával', 'Rope-Assisted Casualty Extrication',
     'Juttasd a szimulált sérültet biztonságos átadási pontra a kijelölt kötéltechnikai pályán, az egészségügyi egységgel együttműködve.',
     'Move the simulated casualty to a safe handover point on the designated rope-rescue station in coordination with the medical element.',
     1.5),

    ('HUNOR-MEDICAL-01', 'MEDICAL', 400,
     'Sérültvizsgálat és triázs', 'Casualty Assessment and Triage',
     'Mérd fel a szimulált sérülteket, jelöld a prioritásukat, és egyeztesd az ellátási és kimentési sorrendet.',
     'Assess simulated casualties, record their priorities and agree the order of treatment and extrication.',
     0.75),
    ('HUNOR-MEDICAL-02', 'MEDICAL', 410,
     'Egészségügyi ellátás szűk térben', 'Medical Care in Confined Space',
     'Szimuláld a beszorult sérült ellátását a hozzáféréstől a kimentésig. Hangold össze az ellátást és a sérült mozgatását a mentőegységgel.',
     'Simulate care for an entrapped casualty from first access through extrication. Coordinate care and movement with the rescue element.',
     1.5),
    ('HUNOR-MEDICAL-03', 'MEDICAL', 420,
     'Sérült kiürítése és átadása', 'Casualty Evacuation and Handover',
     'Egyeztesd a kiürítési útvonalat és az átadási pontot. Add át a sérült állapotát, az elvégzett ellátást és a további teendőket.',
     'Confirm the evacuation route and handover point. Communicate casualty status, care provided and outstanding needs.',
     0.75),
    ('HUNOR-MEDICAL-04', 'MEDICAL', 430,
     'Csapattag egészségügyi kiürítésének gyakorlása', 'Team Member Medical Evacuation Drill',
     'Gyakorold egy szimulált beteg vagy sérült csapattag kiürítésének megszervezését, az értesítési láncot és az átadást.',
     'Rehearse evacuation arrangements, notifications and handover for a simulated ill or injured team member.',
     1.0),

    ('HUNOR-COORD-01', 'COORDINATION', 500,
     'Fogadási és indulási központ (RDC)', 'Reception and Departure Centre (RDC)',
     'Gyakorold a beérkező csapat regisztrációját, képességeinek rögzítését és továbbirányítását az RDC-n keresztül.',
     'Rehearse arrival registration, capability reporting and onward routing through the exercise RDC.',
     0.75),
    ('HUNOR-COORD-02', 'COORDINATION', 510,
     'UCC-koordináció és feladatkiosztás', 'UCC Coordination and Tasking',
     'Egyeztesd a szektorok prioritásait, a csapatok feladatait és a jelentési rendet az USAR-koordinációs egységben.',
     'Agree sector priorities, team assignments and reporting arrangements in the USAR Coordination Cell.',
     1.0),
    ('HUNOR-COORD-03', 'COORDINATION', 520,
     'Kárhelyjelölés és műveleti jelentés', 'Worksite Marking and Operations Reporting',
     'Egyeztesd a kárhelyazonosítót és a helyszíni jelölést. Jelentsd az állapotot, a veszélyeket és a további feladatokat.',
     'Check the worksite identifier and field markings. Report status, hazards and remaining tasks.',
     0.5),
    ('HUNOR-COORD-04', 'COORDINATION', 530,
     'Egyeztetés a helyi veszélyhelyzet-kezelési hatósággal (LEMA)', 'Local Emergency Management Authority (LEMA) Liaison',
     'Egyeztesd a helyi hatóság prioritásait, a hozzáférési feltételeket és a nyitott kárhelyi feladatok átadását.',
     'Confirm local authority priorities, access arrangements and the handover of outstanding worksite actions.',
     0.75)
)
insert into public.insarag_checkpoint_catalog (
  code, category, sort_order, title, title_hu, title_en,
  description_hu, description_en, default_duration_hours
)
select code, category, sort_order, title_hu, title_hu, title_en,
       description_hu, description_en, default_duration_hours
from checkpoints
on conflict (code) do nothing;

commit;
