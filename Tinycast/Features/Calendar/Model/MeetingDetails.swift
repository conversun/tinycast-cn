import Foundation

/// What only the details page shows, read on demand so the agenda snapshot stays small.
struct MeetingDetails: Equatable, Sendable {
    let meetingID: MeetingEvent.ID
    let location: String?
    let notes: String?
    let attendees: [Attendee]

    init(meetingID: MeetingEvent.ID, location: String?, notes: String?, attendees: [Attendee]) {
        self.meetingID = meetingID
        self.location = location.flatMap(Self.nonBlank)
        self.notes = notes.flatMap(Self.plainText(fromNotes:))
        self.attendees = attendees.filter(\.isOrganizer) + attendees.filter { !$0.isOrganizer }
    }

    /// Some servers store a description as HTML; the page shows its text, never its markup.
    static func plainText(fromNotes notes: String) -> String? {
        guard notes.contains(/(?i)<\/?(?:a|b|i|u|p|br|div|span|strong|em|ul|ol|li)\b[^>]*>/)
        else { return nonBlank(notes) }
        let text =
            notes
            .replacing(/(?i)(?:<br\s*\/?>|<\/(?:p|div|li)>)/, with: "\n")
            .replacing(/(?i)<li\b[^>]*>/, with: "• ")
            .replacing(/<[^>]+>/, with: "")
            .replacing("&nbsp;", with: " ")
            .replacing("&lt;", with: "<")
            .replacing("&gt;", with: ">")
            .replacing("&quot;", with: "\"")
            .replacing("&#39;", with: "'")
            .replacing("&amp;", with: "&")
            .replacing(/\n{3,}/, with: "\n\n")
        return nonBlank(text)
    }

    private static func nonBlank(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

extension MeetingDetails {
    struct Attendee: Hashable, Sendable {
        enum Response: Sendable {
            case accepted
            case tentative
            case declined
            case pending
        }

        let name: String
        let response: Response
        let isOrganizer: Bool
    }
}
