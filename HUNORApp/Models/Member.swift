import Foundation

enum AvailabilityStatus: String, CaseIterable, Identifiable {
    case available = "Elérhető"
    case vacation = "Szabadságon"
    case sick = "Beteg"
    case training = "Képzésen"
    case unavailable = "Egyéb"

    var id: String { rawValue }
}

struct Member: Identifiable, Hashable {
    let id: UUID
    var name: String
    var rank: String
    var workplace: String
    var position: String
    var skills: [String]
    var status: AvailabilityStatus

    static let sampleMembers: [Member] = [
        Member(
            id: UUID(),
            name: "Kovács Péter",
            rank: "tűzoltó őrnagy",
            workplace: "Somogy Vármegyei Katasztrófavédelmi Igazgatóság",
            position: "HUNOR tag",
            skills: ["Kötéltechnikai mentés", "USAR", "Műszaki mentés"],
            status: .available
        ),
        Member(
            id: UUID(),
            name: "Nagy András",
            rank: "tűzoltó százados",
            workplace: "Fővárosi Katasztrófavédelmi Igazgatóság",
            position: "HUNOR tag",
            skills: ["Romkutatás", "Drónkezelés"],
            status: .vacation
        )
    ]
}
