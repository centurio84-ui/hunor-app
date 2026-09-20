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
    var phone: String
    var skills: [String]
    var status: AvailabilityStatus
}
