import Foundation
import SwiftUI
import Supabase

@MainActor
final class AppStore: ObservableObject {
    @Published var currentUser: Member
    @Published var members: [Member] = []
    @Published var events: [HUNOREvent] = []
    @Published var eventResponses: [UUID: String] = [:]
    @Published var eventParticipantCounts: [UUID: Int] = [:]
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?

    init() {
        self.currentUser = Member(id: UUID(), name: "", rank: "", workplace: "", position: "", phone: "", skills: [], status: .available)
        if supabase.auth.currentSession != nil {
            isAuthenticated = true
            Task { await loadData() }
        }
    }

    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        do {
            try await supabase.auth.signIn(email: email, password: password)
            isAuthenticated = true
            await loadData()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func signOut() async {
        do {
            try await supabase.auth.signOut()
            isAuthenticated = false
            members = []
            events = []
            eventResponses = [:]
            eventParticipantCounts = [:]
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadData() async {
        guard let session = supabase.auth.currentSession else { isAuthenticated = false; return }
        isLoading = true
        errorMessage = nil
        do {
            let userID = session.user.id
            let profiles: [ProfileRow] = try await supabase.from("profiles").select().execute().value
            let skills: [SkillRow] = try await supabase.from("skills").select().execute().value
            let availability: [AvailabilityRow] = try await supabase.from("availability").select().execute().value
            let dbEvents: [EventRow] = try await supabase.from("events").select().order("starts_at", ascending: true).execute().value
            let participants: [EventParticipantRow] = try await supabase.from("event_participants").select().eq("member_id", value: userID.uuidString).execute().value
            let allParticipants: [EventParticipantRow] = try await supabase.from("event_participants").select().eq("response", value: "going").execute().value

            let today = Calendar.current.startOfDay(for: .now)

            func activeAvailability(for memberID: UUID) -> AvailabilityRow? {
                availability
                    .filter {
                        $0.memberId == memberID &&
                        $0.startDate <= today &&
                        ($0.endDate == nil || $0.endDate! >= today)
                    }
                    .sorted { $0.startDate > $1.startDate }
                    .first
            }

            members = profiles.map { profile in
                let memberSkills = skills.filter { $0.memberId == profile.id }.map(\.name)
                let active = activeAvailability(for: profile.id)
                return Member(
                    id: profile.id,
                    name: profile.name,
                    rank: profile.rank ?? "",
                    workplace: profile.workplace ?? "",
                    position: profile.position ?? "",
                    phone: profile.phone ?? "",
                    skills: memberSkills,
                    status: AvailabilityStatus(databaseValue: active?.status)
                )
            }

            if let own = profiles.first(where: { $0.id == userID }) {
                let ownSkills = skills.filter { $0.memberId == own.id }.map(\.name)
                let active = activeAvailability(for: own.id)
                currentUser = Member(
                    id: own.id,
                    name: own.name,
                    rank: own.rank ?? "",
                    workplace: own.workplace ?? "",
                    position: own.position ?? "",
                    phone: own.phone ?? "",
                    skills: ownSkills,
                    status: AvailabilityStatus(databaseValue: active?.status)
                )
            }

            events = dbEvents.map { HUNOREvent(id: $0.id, title: $0.title, date: $0.startsAt, location: $0.location ?? "", details: $0.description ?? "") }
            eventResponses = Dictionary(uniqueKeysWithValues: participants.map { ($0.eventId, $0.response) })
            eventParticipantCounts = Dictionary(grouping: allParticipants, by: { $0.eventId }).mapValues { $0.count }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func updateStatus(_ status: AvailabilityStatus, startDate: Date? = nil, endDate: Date? = nil) {
        currentUser.status = status
        Task {
            do {
                let start = Calendar.current.startOfDay(for: startDate ?? .now)
                let end: Date?
                switch status {
                case .available:
                    end = start
                case .vacation, .training:
                    end = Calendar.current.startOfDay(for: endDate ?? start)
                case .sick, .unavailable:
                    end = endDate.map { Calendar.current.startOfDay(for: $0) }
                }
                try await supabase.from("availability")
                    .insert(AvailabilityInsert(memberId: currentUser.id, status: status.databaseValue, startDate: start, endDate: end))
                    .execute()
                await loadData()
            } catch { errorMessage = error.localizedDescription }
        }
    }

    func addSkill(_ skill: String) {
        let trimmed = skill.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !currentUser.skills.contains(trimmed) else { return }
        currentUser.skills.append(trimmed)
        Task {
            do {
                try await supabase.from("skills").insert(SkillInsert(memberId: currentUser.id, name: trimmed)).execute()
                await loadData()
            } catch { errorMessage = error.localizedDescription }
        }
    }

    func removeSkill(_ skill: String) {
        currentUser.skills.removeAll { $0 == skill }
        Task {
            do {
                try await supabase.from("skills").delete().eq("member_id", value: currentUser.id.uuidString).eq("name", value: skill).execute()
                await loadData()
            } catch { errorMessage = error.localizedDescription }
        }
    }

    func respondToEvent(_ eventID: UUID, going: Bool) {
        let response = going ? "going" : "not_going"
        eventResponses[eventID] = response
        Task {
            do {
                try await supabase.from("event_participants").upsert(
                    EventParticipantInsert(eventId: eventID, memberId: currentUser.id, response: response, respondedAt: .now),
                    onConflict: "event_id,member_id"
                ).execute()
                await loadData()
            } catch { errorMessage = error.localizedDescription }
        }
    }

    func eventResponse(for eventID: UUID) -> String? {
        eventResponses[eventID]
    }
}

private struct ProfileRow: Decodable {
    let id: UUID
    let name: String
    let rank: String?
    let workplace: String?
    let position: String?
    let phone: String?
}

private struct SkillRow: Decodable {
    let id: UUID
    let memberId: UUID
    let name: String
    enum CodingKeys: String, CodingKey { case id; case memberId = "member_id"; case name }
}

private struct AvailabilityRow: Decodable {
    let id: UUID
    let memberId: UUID
    let status: String
    let startDate: Date
    let endDate: Date?
    enum CodingKeys: String, CodingKey { case id; case memberId = "member_id"; case status; case startDate = "start_date"; case endDate = "end_date" }
}

private struct EventRow: Decodable {
    let id: UUID
    let title: String
    let location: String?
    let description: String?
    let startsAt: Date
    let endsAt: Date?
    enum CodingKeys: String, CodingKey { case id; case title; case location; case description; case startsAt = "starts_at"; case endsAt = "ends_at" }
}

private struct EventParticipantRow: Decodable {
    let eventId: UUID
    let memberId: UUID
    let response: String
    let respondedAt: Date?
    enum CodingKeys: String, CodingKey { case eventId = "event_id"; case memberId = "member_id"; case response; case respondedAt = "responded_at" }
}

private struct SkillInsert: Encodable {
    let memberId: UUID
    let name: String
    enum CodingKeys: String, CodingKey { case memberId = "member_id"; case name }
}

private struct AvailabilityInsert: Encodable {
    let memberId: UUID
    let status: String
    let startDate: Date
    let endDate: Date?
    enum CodingKeys: String, CodingKey { case memberId = "member_id"; case status; case startDate = "start_date"; case endDate = "end_date" }
}

private struct EventParticipantInsert: Encodable {
    let eventId: UUID
    let memberId: UUID
    let response: String
    let respondedAt: Date
    enum CodingKeys: String, CodingKey {
        case eventId = "event_id"
        case memberId = "member_id"
        case response
        case respondedAt = "responded_at"
    }
}

private extension AvailabilityStatus {
    init(databaseValue: String?) {
        switch databaseValue {
        case "vacation": self = .vacation
        case "sick": self = .sick
        case "training": self = .training
        case "unavailable": self = .unavailable
        default: self = .available
        }
    }

    var databaseValue: String {
        switch self {
        case .available: "available"
        case .vacation: "vacation"
        case .sick: "sick"
        case .training: "training"
        case .unavailable: "unavailable"
        }
    }
}
