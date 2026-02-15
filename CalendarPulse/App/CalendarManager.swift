import EventKit
import Foundation

@MainActor
final class CalendarManager {
    private let store = EKEventStore()

    func hasReadAccess() -> Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        if #available(iOS 17.0, *) {
            return status == .fullAccess || status == .authorized
        } else {
            return status == .authorized
        }
    }

    func requestAccess() async throws -> Bool {
        if #available(iOS 17.0, *) {
            return try await store.requestFullAccessToEvents()
        } else {
            return try await withCheckedThrowingContinuation { continuation in
                store.requestAccess(to: .event) { granted, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    func fetchNextEvent(withinHours hours: Int = 24) -> CalendarEvent? {
        let now = Date()
        guard let end = Calendar.current.date(byAdding: .hour, value: hours, to: now) else {
            return nil
        }

        let predicate = store.predicateForEvents(withStart: now, end: end, calendars: nil)
        let events = store.events(matching: predicate)
            .filter { !$0.isAllDay && $0.startDate > now }
            .sorted { $0.startDate < $1.startDate }

        guard let next = events.first else { return nil }

        let title = (next.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        return CalendarEvent(
            id: next.eventIdentifier,
            title: title.isEmpty ? "제목 없음" : title,
            startDate: next.startDate,
            endDate: next.endDate,
            calendarID: next.calendar.calendarIdentifier,
            calendarName: next.calendar.title,
            isAllDay: next.isAllDay,
            notes: next.notes
        )
    }

    func fetchEvents(on date: Date) -> [CalendarEvent] {
        let startOfDay = Calendar.current.startOfDay(for: date)
        guard let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) else {
            return []
        }

        let predicate = store.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        return store.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }
            .map { event in
                let title = (event.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                return CalendarEvent(
                    id: event.eventIdentifier.isEmpty ? "\(event.startDate.timeIntervalSince1970)-\(title)" : event.eventIdentifier,
                    title: title.isEmpty ? "제목 없음" : title,
                    startDate: event.startDate,
                    endDate: event.endDate,
                    calendarID: event.calendar.calendarIdentifier,
                    calendarName: event.calendar.title,
                    isAllDay: event.isAllDay,
                    notes: event.notes
                )
            }
    }

    func fetchUpcomingEvents(withinDays days: Int = 30) -> [CalendarEvent] {
        let now = Date()
        guard let end = Calendar.current.date(byAdding: .day, value: days, to: now) else {
            return []
        }

        let predicate = store.predicateForEvents(withStart: now, end: end, calendars: nil)
        return store.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }
            .map { event in
                let title = (event.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                return CalendarEvent(
                    id: event.eventIdentifier.isEmpty ? "\(event.startDate.timeIntervalSince1970)-\(title)" : event.eventIdentifier,
                    title: title.isEmpty ? "제목 없음" : title,
                    startDate: event.startDate,
                    endDate: event.endDate,
                    calendarID: event.calendar.calendarIdentifier,
                    calendarName: event.calendar.title,
                    isAllDay: event.isAllDay,
                    notes: event.notes
                )
            }
    }

    func fetchEventsForLiveActivity(withinHours hours: Int = 24) -> [CalendarEvent] {
        let now = Date()
        guard
            let start = Calendar.current.date(byAdding: .hour, value: -6, to: now),
            let end = Calendar.current.date(byAdding: .hour, value: hours, to: now)
        else {
            return []
        }

        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate)
            .filter { !$0.isAllDay }
            .sorted { $0.startDate < $1.startDate }
            .map { event in
                let title = (event.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                return CalendarEvent(
                    id: event.eventIdentifier.isEmpty ? "\(event.startDate.timeIntervalSince1970)-\(title)" : event.eventIdentifier,
                    title: title.isEmpty ? "제목 없음" : title,
                    startDate: event.startDate,
                    endDate: event.endDate,
                    calendarID: event.calendar.calendarIdentifier,
                    calendarName: event.calendar.title,
                    isAllDay: event.isAllDay,
                    notes: event.notes
                )
            }
    }

    func fetchEventDateComponents(pastDays: Int = 365, futureDays: Int = 365) -> [DateComponents] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard
            let start = calendar.date(byAdding: .day, value: -pastDays, to: today),
            let end = calendar.date(byAdding: .day, value: futureDays, to: today)
        else {
            return []
        }

        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        let events = store.events(matching: predicate)

        var seen = Set<String>()
        var components: [DateComponents] = []

        for event in events {
            let day = calendar.startOfDay(for: event.startDate)
            let comp = calendar.dateComponents([.year, .month, .day], from: day)
            let key = "\(comp.year ?? 0)-\(comp.month ?? 0)-\(comp.day ?? 0)"
            if seen.insert(key).inserted {
                components.append(comp)
            }
        }

        return components
    }

    func createEvent(
        title: String,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool,
        calendarID: String?,
        notes: String?
    ) throws {
        let event = EKEvent(eventStore: store)
        event.title = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "제목 없음" : title

        if isAllDay {
            let dayStart = Calendar.current.startOfDay(for: startDate)
            let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
            event.startDate = dayStart
            event.endDate = nextDay
            event.isAllDay = true
        } else {
            event.startDate = startDate
            event.endDate = endDate > startDate ? endDate : startDate.addingTimeInterval(3600)
            event.isAllDay = false
        }

        if let calendarID,
           let selectedCalendar = store.calendar(withIdentifier: calendarID),
           selectedCalendar.allowsContentModifications {
            event.calendar = selectedCalendar
        } else {
            event.calendar = store.defaultCalendarForNewEvents ?? store.calendars(for: .event).first
        }
        event.notes = notes
        try store.save(event, span: .thisEvent)
    }

    func updateEvent(
        eventID: String,
        title: String,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool,
        calendarID: String?,
        notes: String?
    ) throws {
        guard let event = store.event(withIdentifier: eventID) else {
            throw NSError(domain: "CalendarPulse", code: 404, userInfo: [NSLocalizedDescriptionKey: "수정할 일정을 찾을 수 없습니다"])
        }

        event.title = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "제목 없음" : title
        if isAllDay {
            let dayStart = Calendar.current.startOfDay(for: startDate)
            let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
            event.startDate = dayStart
            event.endDate = nextDay
            event.isAllDay = true
        } else {
            event.startDate = startDate
            event.endDate = endDate > startDate ? endDate : startDate.addingTimeInterval(3600)
            event.isAllDay = false
        }

        if let calendarID,
           let selectedCalendar = store.calendar(withIdentifier: calendarID),
           selectedCalendar.allowsContentModifications {
            event.calendar = selectedCalendar
        }
        event.notes = notes
        try store.save(event, span: .thisEvent)
    }

    func fetchWritableCalendars() -> [CalendarListItem] {
        store.calendars(for: .event)
            .filter { $0.allowsContentModifications }
            .map { CalendarListItem(id: $0.calendarIdentifier, title: $0.title) }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    func deleteEvent(eventID: String) throws {
        guard let event = store.event(withIdentifier: eventID) else {
            throw NSError(domain: "CalendarPulse", code: 404, userInfo: [NSLocalizedDescriptionKey: "삭제할 일정을 찾을 수 없습니다"])
        }
        try store.remove(event, span: .thisEvent)
    }
}
