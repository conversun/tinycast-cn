import Foundation

/// Which meeting is worth showing, and whether it is time. Every clock read is an injected `now`.
struct UpcomingWindow: Sendable {
    let leadMinutes: Int

    private var lead: TimeInterval { TimeInterval(leadMinutes * 60) }

    /// The one place the rule lives, so card, chord, schedule and launcher cannot drift.
    static func agenda(from events: [MeetingEvent], now: Date) -> [MeetingEvent] {
        events
            .filter { !$0.isAllDay && !$0.isDeclined && $0.end > now }
            .sorted { $0.start < $1.start }
    }

    /// The grace period never outlives the meeting, so a stand-up clears at its end.
    func carded(from events: [MeetingEvent], now: Date) -> MeetingEvent? {
        Self.agenda(from: events, now: now).first {
            $0.link != nil && now >= $0.start - lead && now < min($0.start + lead, $0.end)
        }
    }

    /// Answers the card first, so the chord always joins what is on screen.
    func joinable(from events: [MeetingEvent], now: Date) -> MeetingEvent? {
        if let carded = carded(from: events, now: now) { return carded }
        let linked = Self.agenda(from: events, now: now).filter { $0.link != nil }
        return linked.first { $0.isInProgress(now: now) } ?? linked.first { $0.start > now }
    }

    static func countdown(to start: Date, now: Date) -> String {
        let delta = start.timeIntervalSince(now)
        if delta > 0 { return "in \(duration(delta, rounding: .up))" }
        return "Now"
    }

    /// A row's pill: only a meeting under way or starting within the hour earns one.
    static func rowCountdown(for event: MeetingEvent, now: Date) -> String? {
        if event.isInProgress(now: now) { return "Now" }
        let delta = event.start.timeIntervalSince(now)
        guard delta > 0, delta <= 60 * 60 else { return nil }
        return countdown(to: event.start, now: now)
    }

    /// The menu bar names the time left once a meeting has been underway for five minutes.
    static func menuBarCountdown(for event: MeetingEvent, now: Date) -> String {
        if now < event.start { return countdown(to: event.start, now: now) }
        if now < event.start.addingTimeInterval(5 * 60) { return "Now" }
        if now < event.end { return "\(duration(event.end.timeIntervalSince(now), rounding: .down)) left" }
        return "Now"
    }

    private static func duration(
        _ interval: TimeInterval, rounding: FloatingPointRoundingRule
    ) -> String {
        let minutes = max(1, Int((interval / 60).rounded(rounding)))
        guard minutes > 60 else { return "\(minutes) min" }
        let hours = max(1, Int((Double(minutes) / 60).rounded()))
        return "\(hours) hr"
    }
}
