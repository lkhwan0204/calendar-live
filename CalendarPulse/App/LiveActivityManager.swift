import ActivityKit
import Foundation

@MainActor
final class LiveActivityManager {
    func syncActivities(with events: [CalendarEvent]) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            return
        }

        var uniqueEvents: [String: CalendarEvent] = [:]
        for event in events {
            uniqueEvents[event.id] = event
        }

        let activities = Activity<CalendarActivityAttributes>.activities
        var keptActivityByEventID: [String: Activity<CalendarActivityAttributes>] = [:]

        for activity in activities {
            let eventID = activity.attributes.eventID
            if keptActivityByEventID[eventID] == nil {
                keptActivityByEventID[eventID] = activity
                continue
            }

            if #available(iOS 16.2, *) {
                await activity.end(nil, dismissalPolicy: .immediate)
            } else {
                await activity.end(using: activity.contentState, dismissalPolicy: .immediate)
            }
        }

        for (eventID, activity) in keptActivityByEventID where uniqueEvents[eventID] == nil {
            if #available(iOS 16.2, *) {
                await activity.end(nil, dismissalPolicy: .immediate)
            } else {
                await activity.end(using: activity.contentState, dismissalPolicy: .immediate)
            }
            keptActivityByEventID.removeValue(forKey: eventID)
        }

        for event in uniqueEvents.values {
            let state = CalendarActivityAttributes.ContentState(
                title: event.title,
                startDate: event.startDate,
                calendarName: event.calendarName
            )

            if let existing = keptActivityByEventID[event.id] {
                if existing.contentState != state {
                    await existing.update(using: state)
                }
                continue
            }

            do {
                if #available(iOS 16.2, *) {
                    _ = try Activity.request(
                        attributes: CalendarActivityAttributes(eventID: event.id),
                        content: .init(state: state, staleDate: event.endDate),
                        pushType: nil
                    )
                } else {
                    _ = try Activity.request(
                        attributes: CalendarActivityAttributes(eventID: event.id),
                        contentState: state,
                        pushType: nil
                    )
                }
            } catch {
                print("Failed to start activity: \(error.localizedDescription)")
            }
        }
    }

    func startOrUpdateActivity(with event: CalendarEvent) async {
        await syncActivities(with: [event])
    }

    func endActivity() async {
        let activities = Activity<CalendarActivityAttributes>.activities
        for activity in activities {
            if #available(iOS 16.2, *) {
                await activity.end(nil, dismissalPolicy: .immediate)
            } else {
                await activity.end(using: activity.contentState, dismissalPolicy: .immediate)
            }
        }
    }
}
