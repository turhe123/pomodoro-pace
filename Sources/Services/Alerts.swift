import AppKit
import AVFoundation
import ServiceManagement
import UserNotifications

/// Posts end-of-block notifications and tracks whether the user allowed them.
@MainActor
final class Notifier: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = Notifier()

    @Published private(set) var isAuthorized = true

    func requestAuthorization() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            Task { @MainActor in Notifier.shared.isAuthorized = granted }
        }
    }

    func refreshStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let ok = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
            Task { @MainActor in Notifier.shared.isAuthorized = ok }
        }
    }

    func post(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if error != nil { Task { @MainActor in Notifier.shared.isAuthorized = false } }
        }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list])
    }
}

/// Plays the chosen system sound via AVAudioPlayer, falling back to NSSound.
@MainActor
enum Chime {
    private static var player: AVAudioPlayer?

    static func play(_ name: String = Prefs.sound) {
        guard name != "None" else { return }
        let url = URL(fileURLWithPath: "/System/Library/Sounds/\(name).aiff")
        if let p = try? AVAudioPlayer(contentsOf: url) {
            player = p
            p.volume = 0.7
            p.play()
        } else {
            NSSound(named: NSSound.Name(name))?.play()
        }
    }
}

/// Thin wrapper over `SMAppService.mainApp` for launch-at-login.
enum LaunchAtLogin {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    /// Returns an error message when the change fails, otherwise nil.
    static func set(_ enabled: Bool) -> String? {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            return nil
        } catch {
            return error.localizedDescription
        }
    }
}
