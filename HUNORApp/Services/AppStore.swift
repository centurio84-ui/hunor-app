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
    @Published var eventParticipantNames: [UUID: [String]] = [:]
    @Published var currentUserRole: MemberRole = .member
    @Published var memberRoles: [UUID: MemberRole] = [:]
    @Published var alerts: [HUNORAlert] = []
    @Published var alertResponses: [UUID: String] = [:]
    @Published var alertResponseCounts: [UUID: [String: Int]] = [:]
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
            eventParticipantNames = [:]
            alerts = []
            alertResponses = [:]
            alertResponseCounts = [:]
            currentUserRole = .member
            memberRoles = [:]
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
            let roles: [RoleRow] = try await supabase.from("member_roles").select().execute().value
            memberRoles = Dictionary(uniqueKeysWithValues: roles.map { ($0.memberId, $0.role == "admin" ? .admin : .member) })
            currentUserRole = memberRoles[userID] ?? .member

            let participants: [EventParticipantRow] = try await supabase.from("event_participants").select().eq("member_id", value: userID.uuidString).execute().value
            let allParticipants: [EventParticipantRow] = try await supabase.from("event_participants").select().eq("response", value: "going").execute().value
            let dbAlerts: [AlertRow] = try await supabase.from("alerts").select().order("created_at", ascending: false).execute().value
            let dbAlertResponses: [AlertResponseRow] = try await supabase.from("alert_responses").select().execute().value

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
            let profileNames = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0.name) })
            eventParticipantNames = Dictionary(grouping: allParticipants, by: { $0.eventId }).mapValues { rows in rows.compactMap { profileNames[$0.memberId] }.sorted() }
            alerts = dbAlerts.map { HUNORAlert(id: $0.id, title: $0.title, message: $0.message, type: $0.type, status: $0.status, createdAt: $0.createdAt, expiresAt: $0.expiresAt) }
            alertResponses = Dictionary(uniqueKeysWithValues: dbAlertResponses.filter { $0.memberId == userID }.map { ($0.alertId, $0.response) })
            alertResponseCounts = Dictionary(grouping: dbAlertResponses, by: { $0.alertId }).mapValues { rows in
                Dictionary(grouping: rows, by: { $0.response }).mapValues { $0.count }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func createAlert(title: String, message: String, type: String, expiresAt: Date? = nil) {
        Task {
            do {
                try await supabase.from("alerts").insert(
                    AlertInsert(title: title, message: message, type: type, status: "active", createdBy: currentUser.id, expiresAt: expiresAt)
                ).execute()
                await loadData()
            } catch { errorMessage = error.localizedDescription }
        }
    }

    func closeAlert(_ alertID: UUID) {
        Task {
            do {
                try await supabase.from("alerts")
                    .update(AlertStatusUpdate(status: "closed"))
                    .eq("id", value: alertID.uuidString)
                    .execute()
                await loadData()
            } catch { errorMessage = error.localizedDescription }
        }
    }

    func respondToAlert(_ alertID: UUID, available: Bool) {
        let response = available ? "available" : "unavailable"
        alertResponses[alertID] = response
        Task {
            do {
                try await supabase.from("alert_responses").upsert(
                    AlertResponseInsert(alertId: alertID, memberId: currentUser.id, response: response),
                    onConflict: "alert_id,member_id"
                ).execute()
                await loadData()
            } catch { errorMessage = error.localizedDescription }
        }
    }

    func createEvent(title: String, date: Date, location: String, details: String) {
        Task {
            do {
                try await supabase.from("events").insert(
                    EventInsert(title: title, location: location, description: details, startsAt: date)
                ).execute()
                await loadData()
            } catch { errorMessage = error.localizedDescription }
        }
    }

    func updateEvent(_ eventID: UUID, title: String, date: Date, location: String, details: String) {
        Task {
            do {
                try await supabase.from("events")
                    .update(EventUpdate(title: title, location: location, description: details, startsAt: date))
                    .eq("id", value: eventID.uuidString)
                    .execute()
                await loadData()
            } catch { errorMessage = error.localizedDescription }
        }
    }

    func deleteEvent(_ eventID: UUID) {
        Task {
            do {
                try await supabase.from("events").delete().eq("id", value: eventID.uuidString).execute()
                await loadData()
            } catch { errorMessage = error.localizedDescription }
        }
    }

    func updateMember(_ member: Member, name: String, rank: String, workplace: String, position: String, phone: String) {
        Task {
            do {
                try await supabase.from("profiles")
                    .update(ProfileUpdate(name: name, rank: rank, workplace: workplace, position: position, phone: phone))
                    .eq("id", value: member.id.uuidString)
                    .execute()
                await loadData()
            } catch { errorMessage = error.localizedDescription }
        }
    }

    func updateMemberRole(_ memberID: UUID, role: MemberRole) {
        Task {
            do {
                try await supabase.from("member_roles")
                    .upsert(RoleUpdate(memberId: memberID, role: role.rawValue), onConflict: "member_id")
                    .execute()
                await loadData()
            } catch { errorMessage = error.localizedDescription }
        }
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

private struct ProfileUpdate: Encodable {
    let name: String
    let rank: String
    let workplace: String
    let position: String
    let phone: String
}

private struct RoleUpdate: Encodable {
    let memberId: UUID
    let role: String
    enum CodingKeys: String, CodingKey { case memberId = "member_id"; case role }
}

private struct RoleRow: Decodable {
    let memberId: UUID
    let role: String
    enum CodingKeys: String, CodingKey { case memberId = "member_id"; case role }
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

private struct AlertRow: Decodable {
    let id: UUID
    let title: String
    let message: String
    let type: String
    let status: String
    let createdAt: Date
    let expiresAt: Date?
    enum CodingKeys: String, CodingKey {
        case id, title, message, type, status
        case createdAt = "created_at"
        case expiresAt = "expires_at"
    }
}

private struct AlertResponseRow: Decodable {
    let alertId: UUID
    let memberId: UUID
    let response: String
    enum CodingKeys: String, CodingKey {
        case alertId = "alert_id"
        case memberId = "member_id"
        case response
    }
}

private struct AlertInsert: Encodable {
    let title: String
    let message: String
    let priority: String
    let status: String
    let createdBy: UUID
    let expiresAt: Date?
    enum CodingKeys: String, CodingKey {
        case title, message, type, status
        case createdBy = "created_by"
        case expiresAt = "expires_at"
    }
}

private struct AlertStatusUpdate: Encodable {
    let status: String
}

private struct AlertResponseInsert: Encodable {
    let alertId: UUID
    let memberId: UUID
    let response: String
    enum CodingKeys: String, CodingKey {
        case alertId = "alert_id"
        case memberId = "member_id"
        case response
    }
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

private struct EventInsert: Encodable {
    let title: String
    let location: String
    let description: String
    let startsAt: Date
    enum CodingKeys: String, CodingKey {
        case title
        case location
        case description
        case startsAt = "starts_at"
    }
}

private struct EventUpdate: Encodable {
    let title: String
    let location: String
    let description: String
    let startsAt: Date
    enum CodingKeys: String, CodingKey {
        case title
        case location
        case description
        case startsAt = "starts_at"
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
