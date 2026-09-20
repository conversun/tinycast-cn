import SwiftUI

/// Reading the coordinator here scopes Observation to the calendar label rather than either scene.
struct CalendarMenuBarLabel: View {
    let appName: String

    private var display: CalendarMenuBarDisplay { AppCore.shared.settings.calendarMenuBarDisplay }
    private var meeting: MeetingEvent? { AppCore.shared.calendarCoordinator.menuBarEvent }

    var body: some View {
        switch (display, meeting) {
        case (.disabled, _):
            EmptyView()
        case (.meetingIcon, let meeting?):
            icon(meeting.link?.provider.sfSymbol ?? "calendar", describing: meeting.title)
        case (.meetingTitle, let meeting?):
            HStack(spacing: Theme.Spacing.xs) {
                if let color = meeting.calendarColor {
                    Image(nsImage: color.menuBarDot).accessibilityHidden(true)
                }
                title(summary(for: meeting))
            }
        case (.meetingTitle, nil)
        where !AppCore.shared.calendarCoordinator.hasUpcomingMenuBarEvent:
            title("No upcoming events")
        case (_, nil):
            icon("calendar", describing: "no current meeting")
        }
    }

    private func icon(_ symbol: String, describing description: String) -> some View {
        Image(systemName: symbol).accessibilityLabel("\(appName): \(description)")
    }

    private func title(_ text: String) -> some View {
        Text(text).accessibilityLabel("\(appName): \(text)")
    }

    private func summary(for meeting: MeetingEvent) -> String {
        let countdown = UpcomingWindow.menuBarCountdown(
            for: meeting, now: AppCore.shared.meetingClock.now)
        return "\(MenuBarSummary.title(meeting.title)) • \(countdown)"
    }
}

/// Calendar actions only: the launcher item carries the app's menu, and neither repeats the other.
struct CalendarMenuBarMenu: View {
    var body: some View {
        if let meeting = AppCore.shared.calendarCoordinator.menuBarEvent {
            if meeting.link != nil {
                Button {
                    AppCore.shared.calendarCoordinator.join(meeting)
                } label: {
                    MeetingMenuLabel(title: String(localized: "Join \(meeting.title)"), color: meeting.calendarColor)
                }
            }
            Button {
                AppCore.shared.calendarCoordinator.openInCalendar(meeting)
            } label: {
                // Only the first item names the meeting, so only it carries the calendar bar.
                MeetingMenuLabel(
                    title: "Open in Calendar...".localizedUI,
                    color: meeting.link == nil ? meeting.calendarColor : nil)
            }
            Divider()
        }
        Button("My Schedule") { AppCore.shared.calendarCoordinator.showSchedule() }
        Button("Calendar Settings...") {
            AppCore.shared.settingsCoordinator.showSettings(tab: .calendar)
        }
    }
}

private struct MeetingMenuLabel: View {
    let title: String
    let color: MeetingEvent.CalendarColor?

    var body: some View {
        if let color {
            Label {
                Text(title)
            } icon: {
                Image(nsImage: color.menuBarBar)
            }
        } else {
            Text(title)
        }
    }
}

extension MeetingEvent.CalendarColor {
    fileprivate var menuBarDot: NSImage {
        swatch(NSSize(width: Theme.Size.colorDot, height: Theme.Size.colorDot))
    }

    fileprivate var menuBarBar: NSImage {
        swatch(
            NSSize(width: Theme.Size.calendarBarWidth, height: Theme.Size.menuBarCalendarBarHeight))
    }

    /// Not a template, so the status bar and its menu keep the colour instead of inking it.
    private func swatch(_ size: NSSize) -> NSImage {
        let image = NSImage(size: size, flipped: false) { rect in
            nsColor.setFill()
            let radius = min(rect.width, rect.height) / 2
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.isTemplate = false
        return image
    }
}
