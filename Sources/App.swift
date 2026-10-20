import AppKit
import SwiftUI

/// App entry point: a window-style menu bar extra plus a Settings scene.
@main
struct PomodoroPaceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @ObservedObject private var model = TimerModel.shared
    @AppStorage(Prefs.menuBarStyle) private var menuBarStyle = MenuBarStyle.time.rawValue

    var body: some Scene {
        MenuBarExtra {
            ContentView()
        } label: {
            MenuBarLabel(model: model, style: MenuBarStyle(rawValue: menuBarStyle) ?? .time)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
        }
    }
}

/// The status item content: a colored phase dot and either the remaining time or an icon.
struct MenuBarLabel: View {
    @ObservedObject var model: TimerModel
    let style: MenuBarStyle

    var body: some View {
        HStack(spacing: 4) {
            if model.state != .idle {
                Image(nsImage: Self.dot(model.phase.nsColor))
            }
            if model.flashOn {
                Text("⏰ Done!")
            } else if style == .time && model.state != .idle {
                Text(model.timeString).monospacedDigit()
            } else {
                Image(systemName: model.state == .paused ? "pause.circle" : "timer")
            }
        }
    }

    /// Non-template image so the dot keeps its color in the menu bar.
    static func dot(_ color: NSColor) -> NSImage {
        let image = NSImage(size: NSSize(width: 8, height: 8), flipped: false) { rect in
            color.setFill()
            NSBezierPath(ovalIn: rect).fill()
            return true
        }
        image.isTemplate = false
        return image
    }
}

/// Requests notification permission at launch and confirms before quitting mid-block.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            _ = TimerModel.shared
            Notifier.shared.requestAuthorization()
        }
    }

    @MainActor
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard TimerModel.shared.state != .idle else { return .terminateNow }
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Discard the current block?"
        alert.informativeText = "A \(TimerModel.shared.phase.title.lowercased()) block is in progress. Quitting will discard it."
        alert.addButton(withTitle: "Discard & Quit")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            TimerModel.shared.discard()
            return .terminateNow
        }
        return .terminateCancel
    }
}

/// Opens the donation page.
func openDonationPage() {
    NSWorkspace.shared.open(URL(string: "https://ko-fi.com/leodavidai")!)
}
