# HUNOR iOS app

HUNOR belső iOS alkalmazás SwiftUI + Supabase alapon.

## Fejlesztési környezet

- Xcode
- Swift / SwiftUI
- iOS 17+
- Supabase
- GitHub repository: centurio84-ui/hunor-app

## Projekt generálása Macen

A repository tartalmazza a `project.yml` fájlt is. Ha XcodeGen telepítve van:

```bash
xcodegen generate
open HUNOR.xcodeproj
```

A `project.yml` automatikusan hozzáadja a Supabase Swift Package dependency-t.

Ha nem szeretnél XcodeGen-t használni, a forrásfájlok közvetlenül hozzáadhatók egy új SwiftUI iOS projekthez, majd Xcode-ban a Supabase Swift Package hozzáadható a GitHub repositoryból.

## Fontos

A Supabase publishable key kliensalkalmazásban használható. Secret/service-role kulcsot nem szabad az iOS alkalmazásba tenni.

## Fő funkciók

- HUNOR belépés
- taglista
- képességek
- elérhetőségi státusz
- közös eseménynaptár
- saját profil
- Supabase/PostgreSQL háttér
