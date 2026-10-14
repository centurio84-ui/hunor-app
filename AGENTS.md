# Rescue Platform – AI Fejlesztői Irányelvek (AGENTS.md)

Ez a dokumentum rögzíti az AI-fejlesztő ügynökök (Gemini Antigravity, Codex, ChatGPT) együttműködési, biztonsági és fejlesztési szabályait a Rescue Platform projekten.

---

## 1. Projekt Áttekintés és Szerepkörök

A Rescue Platform egy több mentőszervezet által használható, SaaS-alapú műveletirányítási rendszer.

* **ChatGPT:** Átfogó rendszerarchitektúra, feladatok koordinálása, ellenőrzése.
* **Codex:** Webes felület, backend architektúra, OpenAPI szerződések és Supabase biztonsági audit.
* **Gemini Antigravity:** Flutter mobilalkalmazás (Android és iOS), mock API illesztés és UI/UX fejlesztés.
* **GitHub:** Az egyetlen hiteles információforrás (Single Source of Truth – feladatok, specifikációk, jelentések és PR-ek).
* **Supabase:** Központi adatbázis, jogosultságkezelés és autentikáció.

---

## 2. GitHub-alapú Együttműködés és Automatizáció

1. **Információcsere a repozitóriumokon keresztül:**
   * A feladatok leírását (`docs/tasks/`), a felületi/backend szerződéseket (`docs/reference/rescue-platform-openapi-*.yaml`) és a tesztmintákat (`test/fixtures/`) a GitHubról olvassuk.
   * A fejlesztési eredményeket a GitHubon kell dokumentálni (`docs/reports/` és Pull Request leírások).
2. **Külön fejlesztési ágak (Feature Branches):**
   * A `main` ágra közvetlenül commitolni vagy pusholni **szigorúan tilos**.
   * Minden feladat külön ágon történik: `gemini/<feladat-azonosító>`.
3. **Automatikus ellenőrzés és Draft PR:**
   * A kódmódosítások után az ügynök elvégzi az elérhető statikus ellenőrzéseket és egységteszteket.
   * A változtatásokat feltölti a saját távoli ágára, és **Draft Pull Requestet** hoz létre a `main` ág felé.
   * A Draft PR automatikusan futtatja a GitHub Actions CI ellenőrzéseket (`flutter analyze`, `flutter test`).

---

## 3. Biztonsági Szabályok és Korlátok

* **Éles rendszerek védelme:**
  * Az éles Supabase-adatbázist és a Netlify-weboldalt tilos önállóan módosítani.
  * Tilos éles migrációt vagy adatbázis-műveletet futtatni emberi jóváhagyás nélkül.
* **Titkok és adatok védelme:**
  * Tilos API-kulcsokat, service-role tokeneket vagy jelszavakat commitolni.
  * Tilos valós tagi vagy személyes adatokat használni mock vagy tesztadatként (kizárólag `@example.invalid` e-mailek és fiktív UUID-k engedélyezettek).
* **Multi-tenant biztonsági izoláció:**
  * A mentőszervezetek adatait (`organization_id`) szigorúan el kell különíteni.
  * Idegen szervezeti adat még hibaüzenetben sem szivároghat ki (idegen erőforrás lekérése `404 NOT_FOUND`).
  * Szervezetváltáskor a helyi gyorsítótár azonnali ürítése kötelező.

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
| Fizetős szolgáltatások igénybevétele | **Jóváhagyáshoz kötött** | Előzetes jóváhagyás szükséges. |
