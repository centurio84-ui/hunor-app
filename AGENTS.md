# Rescue Platform – AI Fejlesztői Irányelvek (AGENTS.md)

Ez a dokumentum rögzíti az AI-fejlesztő ügynökök (Gemini Antigravity, Codex, ChatGPT) együttműködési, biztonsági és fejlesztési szabályait a Rescue Platform projekten.

---

## 1. Projekt Áttekintés és Szerepkörök

A Rescue Platform egy több mentőszervezet által használható, SaaS-alapú műveletirányítási rendszer.

* **ChatGPT:** Rendszerarchitektúra, átfogó projektvezetés, feladatkoordináció és ellenőrzés.
* **Codex:** Webes felület, backend architektúra, OpenAPI szerződések és Supabase biztonsági audit.
* **Gemini Antigravity:** Flutter mobilalkalmazás (Android és iOS), API illesztés és UI/UX fejlesztés.
* **GitHub:** Az elsődleges és hiteles közös információforrás (Single Source of Truth – feladatok, specifikációk, jelentések és PR-ek).
* **Supabase:** Központi adatbázis, RLS jogosultságkezelés és autentikáció.

---

## 2. GitHub-alapú Fejlesztési Munkafolyamat

1. **GitHub mint elsődleges információforrás:**
   * A feladatok leírását (`docs/tasks/`), a backend szerződéseket (`docs/reference/rescue-platform-openapi-*.yaml`) és a tesztmintákat (`test/fixtures/`) a GitHub repozitóriumból olvassuk.
   * A fejlesztési eredményeket és a tesztek futási állapotát a GitHubon dokumentáljuk (`docs/reports/` és Pull Request leírások).
2. **Külön fejlesztési ágak (Feature Branches):**
   * A `main` ágra közvetlenül commitolni vagy pusholni **szigorúan tilos**.
   * Minden feladat külön ágon történik: `gemini/<feladat-azonosító>`.
3. **Automatikus ellenőrzés és Draft PR:**
   * A kódmódosítások után az ügynök elvégzi az elérhető statikus ellenőrzéseket és egységteszteket.
   * A változtatásokat feltölti a saját távoli ágára, és **Draft Pull Requestet** hoz létre a `main` ág felé.
   * A Draft PR automatikusan elindítja a GitHub Actions CI ellenőrzést (`flutter analyze`, `flutter test`).

---

## 3. Biztonsági Szabályok és Korlátok

* **Éles rendszerek védelme:**
  * Az éles Supabase-adatbázist és a Netlify-weboldalt tilos önállóan módosítani.
  * Tilos éles migrációt vagy adatbázis-műveletet futtatni emberi jóváhagyás nélkül.
* **Titkok és személyes adatok védelme:**
  * Tilos API-kulcsokat, service-role tokeneket vagy jelszavakat commitolni.
  * Tilos valós személyes adatokat használni mock vagy tesztadatként (kizárólag `@example.invalid` e-mailek és fiktív azonosítók engedélyezettek).
* **Szervezetek közötti adatizoláció (Multi-tenancy):**
  * A mentőszervezetek adatait (`organization_id`) kötelező szigorúan elszeparálni.
  * Idegen szervezeti adat még hibaüzenetben sem szivároghat ki (más szervezet erőforrása `404 NOT_FOUND`).
  * Szervezetváltáskor a helyi gyorsítótár (cache) azonnali és teljes ürítése kötelező.

---

## 4. Döntési és Jóváhagyási Mátrix

| Művelet típusa | AI Ügynök Jogosultsága | Szükséges lépés |
|---|---|---|
| Helyi fájlolvasás, elemzés, tervezés | **Önálló** | Nem szükséges külön engedély. |
| Kódírás, új modellek, mock adapterek | **Önálló** | Saját fejlesztési ágon végezve. |
| Helyi tesztelés és statikus ellenőrzés | **Önálló** | Automatikusan lefut. |
| Helyi commit és push saját ágra | **Önálló** | Szigorúan a `gemini/*` ágon. |
| Draft PR létrehozása a GitHubon | **Önálló** | Nem merge-elhető vázlatként. |
| PR összevonása (Merge) a `main` ágba | **Jóváhagyáshoz kötött** | Csak emberi felülvizsgálat után. |
| Éles Supabase, Auth, Netlify módosítás | **Jóváhagyáshoz kötött** | Kifejezett felhasználói parancsra. |
| Fizetős szolgáltatások indítása | **Jóváhagyáshoz kötött** | Előzetes jóváhagyás szükséges. |
