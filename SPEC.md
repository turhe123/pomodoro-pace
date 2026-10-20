# PomodoroPace — specification

**Tagline:** A menu bar pomodoro timer with task labels, daily session counts and a gentle chime when each block ends.

**Category:** Timers & Reminders

**Inspired by (paid):** Be Focused Pro ($4.99 one-time)

**Frameworks:** SwiftUI, AppKit, UserNotifications, AVFoundation, ServiceManagement

**Donation URL (Support button):** https://ko-fi.com/leodavidai

## Spec

What the paid app does: Be Focused Pro is a long-standing Mac pomodoro timer that runs focus and break intervals, tracks a task list and shows progress in the menu bar. The pro upgrade costs about five dollars, and the app has many years of strong ratings in the Mac App Store and regular mentions in productivity roundups, so demand for a simple pomodoro tool remains steady.

Our clean-room feature set: configurable focus length, short break and long break, with a long break after a chosen number of focus blocks. A start, pause, skip and reset control. Optional task label per block, chosen from a short list of recent labels. A daily and weekly count of completed blocks with total focused minutes. A chime and a notification at the end of each block, and optional auto-start of the next block. The menu bar title shows the remaining time and a small colored dot for focus versus break. Roughly four hundred lines.

UI spec: MenuBarExtra in window style. The popover shows a large countdown ring, the current phase name, the task label field, and Start, Pause, Skip buttons. Below, a compact list shows today's completed blocks and a seven day bar chart drawn with simple SwiftUI shapes. A settings window includes durations, blocks until long break, auto-start toggles, sound picker, menu bar display style with time or icon only, and launch at login. Keyboard shortcuts inside the popover: Space to start or pause, S to skip, R to reset. Empty state: the history area says no sessions yet, start your first focus block.

Technical approach: a timer model is an ObservableObject storing the phase end date rather than counting ticks, so the display is correct after sleep. A Timer publisher fires each second to refresh the label. Notifications use UNUserNotificationCenter with authorization requested at first launch, and a sound plays through NSSound or AVAudioPlayer from the system sounds. History is a small Codable array saved as JSON in Application Support, keyed by day. Settings use AppStorage. Launch at login uses SMAppService mainApp. No special privacy permissions are required beyond notifications.

Edge cases: if the Mac sleeps during a block, compare the end date on wake and either complete the block or continue with the remaining time, as set by a preference. If notifications are denied, fall back to the chime and a flashing menu bar title, and show a hint in settings. Changing durations mid-block applies from the next block. Handle clock changes and time zone changes by using monotonic checks along with dates. Quitting during a block asks whether to discard it. Label history is capped to fifty entries, and old daily records beyond a year are pruned.
