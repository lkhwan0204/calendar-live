import Foundation

struct CalendarListItem: Identifiable, Equatable {
    let id: String
    let title: String
}

struct CalendarEvent: Identifiable, Equatable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let calendarID: String
    let calendarName: String
    let isAllDay: Bool
    let notes: String?
    
    var rowID: String {
        "\(id)|\(startDate.timeIntervalSince1970)|\(endDate.timeIntervalSince1970)|\(calendarName)|\(isAllDay)"
    }

    var countdownText: String {
        let interval = startDate.timeIntervalSinceNow
        if interval <= 0 {
            return "시작됨"
        }

        let minutes = Int(ceil(interval / 60))
        let hours = minutes / 60
        let remainingMinutes = minutes % 60

        if hours > 0 {
            return "\(hours)시간 \(remainingMinutes)분 후"
        }

        return "\(minutes)분 후"
    }

    var localizedStartDateText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy년 M월 d일 a h:mm"
        return formatter.string(from: startDate)
    }

    var localizedTimeRangeText: String {
        if isAllDay {
            return "종일"
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "a h:mm"
        let start = formatter.string(from: startDate)
        let end = formatter.string(from: endDate)
        return "\(start) - \(end)"
    }

    var localizedDateTimeRangeText: String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "ko_KR")
        dateFormatter.dateFormat = "yyyy년 M월 d일 EEEE"

        if isAllDay {
            return "\(dateFormatter.string(from: startDate)) · 종일"
        }

        return "\(dateFormatter.string(from: startDate)) · \(localizedTimeRangeText)"
    }
}
