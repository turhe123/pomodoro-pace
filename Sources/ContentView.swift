import SwiftUI

/// The menu bar popover: countdown ring, controls, task label, today's blocks and a 7-day chart.
struct ContentView: View {
    @ObservedObject private var model = TimerModel.shared
    @ObservedObject private var history = HistoryStore.shared
    @FocusState private var labelFocused: Bool

    var body: some View {
        VStack(spacing: 14) {
            CountdownRing(progress: model.progress, color: model.phase.color, time: model.timeString,
                          phase: model.phase.title, paused: model.state == .paused)
                .frame(width: 170, height: 170)

            labelField
            controls
            Divider()
            HistorySection(history: history)
            Divider()
            footer
        }
        .padding(16)
        .frame(width: 320)
        .focusable()
        .focusEffectDisabled()
        .onKeyPress(.space) { handleKey { model.toggle() } }
        .onKeyPress("s") { handleKey { model.skip() } }
        .onKeyPress("r") { handleKey { model.reset() } }
    }

    /// Popover shortcuts are ignored while typing in the label field.
    private func handleKey(_ action: () -> Void) -> KeyPress.Result {
        guard !labelFocused else { return .ignored }
        action()
        return .handled
    }

    private var labelField: some View {
        HStack(spacing: 6) {
            TextField("What are you working on?", text: $model.label)
                .textFieldStyle(.roundedBorder)
                .focused($labelFocused)
                .onSubmit { labelFocused = false }
            Menu {
                if history.recentLabels.isEmpty {
                    Text("No recent labels")
                } else {
                    ForEach(history.recentLabels.prefix(10), id: \.self) { recent in
                        Button(recent) { model.label = recent }
                    }
                    Divider()
                    Button("Clear Label") { model.label = "" }
                }
            } label: {
                Image(systemName: "clock.arrow.circlepath")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Recent labels")
        }
    }

    private var controls: some View {
        HStack(spacing: 10) {
            Button { model.toggle() } label: {
                Label(model.state == .running ? "Pause" : "Start",
                      systemImage: model.state == .running ? "pause.fill" : "play.fill")
                    .frame(minWidth: 70)
            }
            .buttonStyle(.borderedProminent)
            .tint(model.phase.color)
            .help("Space")

            Button { model.skip() } label: { Label("Skip", systemImage: "forward.end.fill") }
                .help("S")
            Button { model.reset() } label: { Label("Reset", systemImage: "arrow.counterclockwise") }
                .help("R")
                .disabled(model.state == .idle)
        }
        .controlSize(.large)
    }

    private var footer: some View {
        HStack {
            SettingsLink { Image(systemName: "gearshape") }
                .help("Settings")
            Spacer()
            Button("Support / Donate ❤️") { openDonationPage() }
            Spacer()
            Button("Quit") { NSApp.terminate(nil) }
        }
        .buttonStyle(.borderless)
        .font(.callout)
    }
}

/// A large circular progress ring with the remaining time in the centre.
struct CountdownRing: View {
    let progress: Double
    let color: Color
    let time: String
    let phase: String
    let paused: Bool

    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.15), lineWidth: 12)
            Circle()
                .trim(from: 0, to: max(0.001, min(progress, 1)))
                .stroke(color, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.9), value: progress)
            VStack(spacing: 2) {
                Text(time)
                    .font(.system(size: 40, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text(paused ? "\(phase) · Paused" : phase)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// Today's completed blocks, daily/weekly totals and a seven-day bar chart.
struct HistorySection: View {
    @ObservedObject var history: HistoryStore

    var body: some View {
        let today = history.sessions(on: Date())
        let week = history.lastSevenDays()
        let weekSessions = week.flatMap(\.sessions)

        VStack(alignment: .leading, spacing: 10) {
            if weekSessions.isEmpty {
                Text("No sessions yet — start your first focus block.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 60)
            } else {
                HStack {
                    stat("Today", count: today.count, minutes: today.reduce(0) { $0 + $1.minutes })
                    Spacer()
                    stat("This week", count: weekSessions.count, minutes: weekSessions.reduce(0) { $0 + $1.minutes })
                }
                if !today.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(today.reversed()) { s in
                                HStack {
                                    Circle().fill(.red).frame(width: 6, height: 6)
                                    Text(s.label.isEmpty ? "Focus" : s.label).lineLimit(1)
                                    Spacer()
                                    Text("\(s.minutes)m · \(s.end.formatted(date: .omitted, time: .shortened))")
                                        .foregroundStyle(.secondary)
                                }
                                .font(.caption)
                            }
                        }
                    }
                    .frame(maxHeight: 80)
                }
                WeekChart(days: week)
            }
        }
    }

    private func stat(_ title: String, count: Int, minutes: Int) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text("\(count) block\(count == 1 ? "" : "s") · \(minutes) min").font(.callout.weight(.medium))
        }
    }
}

/// Seven vertical bars built from rounded rectangles, one per day.
struct WeekChart: View {
    let days: [(date: Date, sessions: [Session])]

    var body: some View {
        let maxCount = max(days.map(\.sessions.count).max() ?? 0, 1)
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                VStack(spacing: 3) {
                    Text("\(day.sessions.count)").font(.system(size: 9)).foregroundStyle(.secondary)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(index == days.count - 1 ? Color.red : Color.red.opacity(0.45))
                        .frame(height: max(3, 50 * CGFloat(day.sessions.count) / CGFloat(maxCount)))
                    Text(day.date.formatted(.dateTime.weekday(.narrow))).font(.system(size: 9))
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 80, alignment: .bottom)
    }
}
