import AppKit
import Combine
import SwiftUI

/// The kind of interval currently being timed.
enum Phase: String, Codable {
    case focus, shortBreak, longBreak

    var title: String {
        switch self {
        case .focus: return "Focus"
        case .shortBreak: return "Short Break"
        case .longBreak: return "Long Break"
        }
    }

    var color: Color { self == .focus ? .red : .green }
    var nsColor: NSColor { self == .focus ? .systemRed : .systemGreen }
}

/// Runs the pomodoro cycle. Deadlines are kept on a monotonic clock (which keeps counting
/// during sleep but ignores wall-clock and time zone changes); the wall-clock end date is derived from it.
@MainActor
final class TimerModel: ObservableObject {
    static let shared = TimerModel()

    enum RunState { case idle, running, paused }

    @Published private(set) var phase: Phase = .focus
    @Published private(set) var state: RunState = .idle
    @Published private(set) var remaining: TimeInterval = 0
    @Published private(set) var blockDuration: TimeInterval = 0
    @Published private(set) var completedInCycle = 0
    @Published private(set) var flashOn = false
    @Published var label = ""

    /// Wall-clock estimate of when the block ends (recomputed after clock changes).
    private(set) var endDate: Date?
    private var monoDeadline: UInt64 = 0
    private var sleepStartedAt: UInt64?
    private var flashUntil: UInt64 = 0
    private var cancellables = Set<AnyCancellable>()

    private init() {
        Prefs.registerDefaults()
        Timer.publish(every: 1, on: .main, in: .common).autoconnect()
            .sink { [weak self] _ in self?.tick() }
            .store(in: &cancellables)

        let ws = NSWorkspace.shared.notificationCenter
        ws.publisher(for: NSWorkspace.willSleepNotification)
            .sink { [weak self] _ in self?.sleepStartedAt = Self.now() }
            .store(in: &cancellables)
        ws.publisher(for: NSWorkspace.didWakeNotification)
            .sink { [weak self] _ in self?.handleWake() }
            .store(in: &cancellables)

        let nc = NotificationCenter.default
        Publishers.Merge3(nc.publisher(for: .NSSystemClockDidChange),
                          nc.publisher(for: .NSSystemTimeZoneDidChange),
                          nc.publisher(for: .NSCalendarDayChanged))
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.recomputeEndDate()
                HistoryStore.shared.refresh()
            }
            .store(in: &cancellables)
        tick()
    }

    /// Monotonic nanoseconds that include time spent asleep.
    private static func now() -> UInt64 { clock_gettime_nsec_np(CLOCK_MONOTONIC) }

    var displayRemaining: TimeInterval { state == .idle ? Prefs.duration(for: phase) : remaining }

    var progress: Double {
        let total = state == .idle ? Prefs.duration(for: phase) : blockDuration
        guard total > 0 else { return 0 }
        return 1 - displayRemaining / total
    }

    var timeString: String {
        let secs = Int(displayRemaining.rounded(.up))
        return String(format: "%02d:%02d", secs / 60, secs % 60)
    }

    // MARK: Controls

    func toggle() { state == .running ? pause() : start() }

    func start() {
        switch state {
        case .running: return
        case .idle:
            blockDuration = Prefs.duration(for: phase)  // settings changes apply from the next block
            remaining = blockDuration
            HistoryStore.shared.rememberLabel(label)
        case .paused: break
        }
        monoDeadline = Self.now() + UInt64(remaining * 1_000_000_000)
        state = .running
        flashUntil = 0
        recomputeEndDate()
    }

    func pause() {
        guard state == .running else { return }
        remaining = secondsLeft()
        state = .paused
        endDate = nil
    }

    func skip() { advance(recordCompletion: false) }

    func reset() {
        state = .idle
        endDate = nil
        remaining = Prefs.duration(for: phase)
    }

    /// Discards the in-progress block without recording it.
    func discard() { reset() }

    // MARK: Internals

    private func secondsLeft() -> TimeInterval {
        let n = Self.now()
        return n >= monoDeadline ? 0 : TimeInterval(monoDeadline - n) / 1_000_000_000
    }

    private func recomputeEndDate() {
        endDate = state == .running ? Date().addingTimeInterval(secondsLeft()) : nil
    }

    private func tick() {
        if flashUntil > 0 {
            if Self.now() < flashUntil { flashOn.toggle() } else { flashUntil = 0; flashOn = false }
        }
        guard state == .running else {
            objectWillChange.send()  // keeps the idle display in sync with settings
            return
        }
        remaining = secondsLeft()
        if remaining <= 0 { advance(recordCompletion: true) }
    }

    private func handleWake() {
        defer { sleepStartedAt = nil }
        guard state == .running, let slept = sleepStartedAt else { return }
        if Prefs.shouldPauseDuringSleep {
            // Continue with the time that was left when the Mac went to sleep.
            monoDeadline += Self.now() - slept
            recomputeEndDate()
        }
        tick()  // otherwise completes the block if its end passed while asleep
    }

    private func advance(recordCompletion: Bool) {
        let finished = phase
        if finished == .focus {
            if recordCompletion {
                let minutes = Int((blockDuration / 60).rounded())
                HistoryStore.shared.record(minutes: max(minutes, 1), label: label.trimmingCharacters(in: .whitespaces))
            }
            completedInCycle += 1
            phase = completedInCycle % Prefs.blocksBeforeLongBreak == 0 ? .longBreak : .shortBreak
        } else {
            if finished == .longBreak { completedInCycle = 0 }
            phase = .focus
        }
        state = .idle
        endDate = nil
        remaining = Prefs.duration(for: phase)

        if recordCompletion { announce(finished) }
        let auto = phase == .focus ? Prefs.shouldAutoStartFocus : Prefs.shouldAutoStartBreaks
        if auto && recordCompletion { start() }
    }

    private func announce(_ finished: Phase) {
        Chime.play()
        let body = finished == .focus ? "Time for a \(phase.title.lowercased())." : "Ready to focus again?"
        if Notifier.shared.isAuthorized {
            Notifier.shared.post(title: "\(finished.title) finished", body: body)
        } else {
            flashUntil = Self.now() + 12_000_000_000  // flash the menu bar title as a fallback
        }
    }
}
