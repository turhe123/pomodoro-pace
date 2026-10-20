import SwiftUI

/// Preferences window: durations, cycle length, auto-start, sound, menu bar style and launch at login.
struct SettingsView: View {
    @AppStorage(Prefs.focusMinutes) private var focusMinutes = 25
    @AppStorage(Prefs.shortBreakMinutes) private var shortBreakMinutes = 5
    @AppStorage(Prefs.longBreakMinutes) private var longBreakMinutes = 15
    @AppStorage(Prefs.blocksUntilLong) private var blocksUntilLong = 4
    @AppStorage(Prefs.autoStartBreaks) private var autoStartBreaks = false
    @AppStorage(Prefs.autoStartFocus) private var autoStartFocus = false
    @AppStorage(Prefs.soundName) private var soundName = "Glass"
    @AppStorage(Prefs.menuBarStyle) private var menuBarStyle = MenuBarStyle.time.rawValue
    @AppStorage(Prefs.pauseDuringSleep) private var pauseDuringSleep = false
    @ObservedObject private var notifier = Notifier.shared
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var loginError: String?

    var body: some View {
        Form {
            Section("Durations") {
                Stepper("Focus: \(focusMinutes) min", value: $focusMinutes, in: 1...180)
                Stepper("Short break: \(shortBreakMinutes) min", value: $shortBreakMinutes, in: 1...60)
                Stepper("Long break: \(longBreakMinutes) min", value: $longBreakMinutes, in: 1...120)
                Stepper("Long break after \(blocksUntilLong) focus blocks", value: $blocksUntilLong, in: 1...12)
                Text("Changes apply from the next block.").font(.caption).foregroundStyle(.secondary)
            }

            Section("Behavior") {
                Toggle("Auto-start breaks", isOn: $autoStartBreaks)
                Toggle("Auto-start focus blocks", isOn: $autoStartFocus)
                Picker("If the Mac sleeps during a block", selection: $pauseDuringSleep) {
                    Text("Count sleep time (may complete the block)").tag(false)
                    Text("Continue with the remaining time").tag(true)
                }
            }

            Section("Alerts") {
                HStack {
                    Picker("Chime", selection: $soundName) {
                        ForEach(Prefs.systemSounds, id: \.self) { Text($0).tag($0) }
                    }
                    Button("Preview") { Chime.play(soundName) }
                        .disabled(soundName == "None")
                }
                if !notifier.isAuthorized {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Notifications are turned off", systemImage: "bell.slash")
                            .foregroundStyle(.orange)
                        Text("PomodoroPace will play the chime and flash the menu bar instead. To get banners, enable notifications for PomodoroPace in System Settings › Notifications.")
                            .font(.caption).foregroundStyle(.secondary)
                        Button("Open Notification Settings") {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    }
                }
            }

            Section("Menu Bar & Startup") {
                Picker("Menu bar shows", selection: $menuBarStyle) {
                    ForEach(MenuBarStyle.allCases) { Text($0.title).tag($0.rawValue) }
                }
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        guard newValue != LaunchAtLogin.isEnabled else { return }
                        loginError = LaunchAtLogin.set(newValue)
                        launchAtLogin = LaunchAtLogin.isEnabled
                    }
                if let loginError {
                    Text(loginError).font(.caption).foregroundStyle(.red)
                }
            }

            Section {
                HStack {
                    Text("PomodoroPace is free and open source.").foregroundStyle(.secondary)
                    Spacer()
                    Button("Support / Donate ❤️") { openDonationPage() }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear {
            NSApp.activate(ignoringOtherApps: true)
            notifier.refreshStatus()
            launchAtLogin = LaunchAtLogin.isEnabled
        }
    }
}
