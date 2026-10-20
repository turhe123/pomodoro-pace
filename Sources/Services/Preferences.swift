import Foundation

/// Central list of `@AppStorage` keys and typed accessors for reading preferences outside of views.
enum Prefs {
    static let focusMinutes = "focusMinutes"
    static let shortBreakMinutes = "shortBreakMinutes"
    static let longBreakMinutes = "longBreakMinutes"
    static let blocksUntilLong = "blocksUntilLong"
    static let autoStartBreaks = "autoStartBreaks"
    static let autoStartFocus = "autoStartFocus"
    static let soundName = "soundName"
    static let menuBarStyle = "menuBarStyle"
    static let pauseDuringSleep = "pauseDuringSleep"

    /// Built-in macOS sounds found in /System/Library/Sounds.
    static let systemSounds = ["Glass", "Ping", "Purr", "Hero", "Pop", "Tink", "Blow", "Bottle",
                               "Frog", "Funk", "Morse", "Submarine", "Sosumi", "Basso", "None"]

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            focusMinutes: 25, shortBreakMinutes: 5, longBreakMinutes: 15, blocksUntilLong: 4,
            autoStartBreaks: false, autoStartFocus: false, soundName: "Glass",
            menuBarStyle: MenuBarStyle.time.rawValue, pauseDuringSleep: false,
        ])
    }

    private static var defaults: UserDefaults { .standard }

    /// Configured length of a phase in seconds, clamped to a sane range.
    static func duration(for phase: Phase) -> TimeInterval {
        let key: String
        switch phase {
        case .focus: key = focusMinutes
        case .shortBreak: key = shortBreakMinutes
        case .longBreak: key = longBreakMinutes
        }
        return TimeInterval(min(max(defaults.integer(forKey: key), 1), 180) * 60)
    }

    static var blocksBeforeLongBreak: Int { max(defaults.integer(forKey: blocksUntilLong), 1) }
    static var shouldAutoStartBreaks: Bool { defaults.bool(forKey: autoStartBreaks) }
    static var shouldAutoStartFocus: Bool { defaults.bool(forKey: autoStartFocus) }
    static var sound: String { defaults.string(forKey: soundName) ?? "Glass" }
    static var shouldPauseDuringSleep: Bool { defaults.bool(forKey: pauseDuringSleep) }
}

/// How the menu bar item presents itself.
enum MenuBarStyle: String, CaseIterable, Identifiable {
    case time, iconOnly
    var id: String { rawValue }
    var title: String { self == .time ? "Time remaining" : "Icon only" }
}
