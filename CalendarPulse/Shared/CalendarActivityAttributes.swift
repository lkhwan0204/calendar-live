import ActivityKit
import Foundation

struct CalendarActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var title: String
        var startDate: Date
        var calendarName: String
    }

    var eventID: String
}
