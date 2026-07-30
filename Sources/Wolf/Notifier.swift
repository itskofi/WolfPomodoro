import AppKit
import UserNotifications

/// Local notifications with graceful degradation: if the bundle is not signed in a way
/// macOS accepts, or the user denied access, we simply stay silent instead of erroring.
final class Notifier {
    private var authorized = false

    func requestAuthorization() {
        guard Bundle.main.bundleIdentifier != nil else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            self.authorized = granted
        }
    }

    func notify(title: String, body: String) {
        guard authorized else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    func playSound(named name: String) {
        NSSound(named: name)?.play()
    }
}
