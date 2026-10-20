import Foundation

/// A single completed focus block.
struct Session: Codable, Identifiable, Hashable {
    var id = UUID()
    var end: Date
    var minutes: Int
    var label: String
}

/// All sessions completed on one calendar day (key format `yyyy-MM-dd`).
struct DayRecord: Codable {
    var day: String
    var sessions: [Session]
}

/// Persists completed blocks as JSON in Application Support and keeps a capped list of recent labels.
@MainActor
final class HistoryStore: ObservableObject {
    static let shared = HistoryStore()

    @Published private(set) var days: [DayRecord] = []
    @Published private(set) var recentLabels: [String] = []

    private let labelsKey = "recentLabels"
    private let fileURL: URL? = {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let dir = base.appendingPathComponent("PomodoroPace", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("history.json")
    }()

    private init() {
        recentLabels = UserDefaults.standard.stringArray(forKey: labelsKey) ?? []
        load()
        prune()
    }

    static func dayKey(for date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    func record(minutes: Int, label: String, at date: Date = Date()) {
        let session = Session(end: date, minutes: minutes, label: label)
        let key = Self.dayKey(for: date)
        if let i = days.firstIndex(where: { $0.day == key }) {
            days[i].sessions.append(session)
        } else {
            days.append(DayRecord(day: key, sessions: [session]))
        }
        rememberLabel(label)
        prune()
        save()
    }

    func rememberLabel(_ label: String) {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        recentLabels.removeAll { $0 == trimmed }
        recentLabels.insert(trimmed, at: 0)
        recentLabels = Array(recentLabels.prefix(50))
        UserDefaults.standard.set(recentLabels, forKey: labelsKey)
    }

    func sessions(on date: Date) -> [Session] {
        days.first { $0.day == Self.dayKey(for: date) }?.sessions ?? []
    }

    /// Sessions for the last seven days, oldest first.
    func lastSevenDays(from today: Date = Date()) -> [(date: Date, sessions: [Session])] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: today)
        return (0..<7).reversed().compactMap { offset in
            guard let d = cal.date(byAdding: .day, value: -offset, to: start) else { return nil }
            return (d, sessions(on: d))
        }
    }

    /// Forces SwiftUI to re-derive day groupings (e.g. after a time zone or day change).
    func refresh() { objectWillChange.send() }

    private func prune() {
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -365, to: Date()) else { return }
        let cutoffKey = Self.dayKey(for: cutoff)
        days.removeAll { $0.day < cutoffKey }
    }

    private func load() {
        guard let url = fileURL, let data = try? Data(contentsOf: url) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        days = (try? decoder.decode([DayRecord].self, from: data)) ?? []
    }

    private func save() {
        guard let url = fileURL else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        do {
            try encoder.encode(days).write(to: url, options: .atomic)
        } catch {
            NSLog("PomodoroPace: failed to save history: \(error.localizedDescription)")
        }
    }
}
