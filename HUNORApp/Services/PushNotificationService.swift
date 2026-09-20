import Foundation
import UserNotifications
import UIKit
import Supabase

@MainActor
final class PushNotificationService: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = PushNotificationService()

    private var pendingToken: String?

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func requestAuthorizationAndRegister() {
        Task {
            let granted = try? await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .badge, .sound]
            )

            guard granted == true else { return }

            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    func saveDeviceToken(_ token: String) {
        guard !token.isEmpty else { return }

        if supabase.auth.currentSession == nil {
            pendingToken = token
            return
        }

        Task {
            await upsertDeviceToken(token)
        }
    }

    func registerPendingTokenIfNeeded() {
        guard let token = pendingToken else { return }
        pendingToken = nil

        Task {
            await upsertDeviceToken(token)
        }
    }

    private func upsertDeviceToken(_ token: String) async {
        guard let userID = supabase.auth.currentSession?.user.id else {
            pendingToken = token
            return
        }

        do {
            try await supabase.from("device_tokens")
                .upsert(
                    DeviceTokenInsert(
                        memberId: userID,
                        token: token,
                        platform: "ios",
                        updatedAt: .now
                    ),
                    onConflict: "member_id,token"
                )
                .execute()
        } catch {
            pendingToken = token
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        // A későbbi verzióban innen közvetlenül a riasztás részleteire navigálunk.
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        PushNotificationService.shared.requestAuthorizationAndRegister()
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        PushNotificationService.shared.saveDeviceToken(token)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        // A regisztráció később újrapróbálható.
    }
}

private struct DeviceTokenInsert: Encodable {
    let memberId: UUID
    let token: String
    let platform: String
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case memberId = "member_id"
        case token
        case platform
        case updatedAt = "updated_at"
    }
}
