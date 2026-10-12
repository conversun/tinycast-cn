import Foundation

enum DictationIdleRelease: Int, CaseIterable, Identifiable, Sendable {
    case never = 0
    case oneMinute = 1
    case twoMinutes = 2
    case fiveMinutes = 5
    case tenMinutes = 10
    case fifteenMinutes = 15
    case twentyMinutes = 20
    case thirtyMinutes = 30
    case oneHour = 60

    var id: Self { self }
    var title: String {
        switch self {
        case .never: String(localized: "Never")
        case .oneMinute: String(localized: "1 minute")
        case .oneHour: String(localized: "1 hour")
        default: String(localized: "\(rawValue) minutes")
        }
    }
}
