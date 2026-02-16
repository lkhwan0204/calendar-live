import Foundation
import UserNotifications

@MainActor
final class NotificationManager {
    private let center = UNUserNotificationCenter.current()
    private let identifierPrefix = "calendarpulse.event."

    func requestAccess() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    func scheduleReminders(for event: CalendarEvent, minutesBefore: Int = 30) async {
        let safeID = sanitizedIdentifier(event.id)
        let beforeID = "\(identifierPrefix)\(safeID).before"
        let startID = "\(identifierPrefix)\(safeID).start"

        center.removePendingNotificationRequests(withIdentifiers: [beforeID, startID])

        let now = Date()
        let beforeDate = event.startDate.addingTimeInterval(TimeInterval(-minutesBefore * 60))

        if beforeDate > now {
            await addRequest(
                id: beforeID,
                title: "곧 일정 시작",
                body: "\(event.title) 일정이 \(minutesBefore)분 뒤 시작됩니다.",
                date: beforeDate
            )
        }
    }

    func clearAllEventReminders() async {
        let pending = await pendingRequests()
        let ids = pending.map(\.identifier).filter { $0.hasPrefix(identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    private func addRequest(id: String, title: String, body: String, date: Date) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let triggerDate = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: date
        )

        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                center.add(request) { error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }
                    continuation.resume(returning: ())
                }
            }
        } catch {
            print("Failed to schedule notification: \(error.localizedDescription)")
        }
    }

    private func sanitizedIdentifier(_ raw: String) -> String {
        let allowed = CharacterSet.alphanumerics
        return raw.unicodeScalars
            .map { allowed.contains($0) ? Character($0) : "_" }
            .map(String.init)
            .joined()
    }

    private func pendingRequests() async -> [UNNotificationRequest] {
        await withCheckedContinuation { continuation in
            center.getPendingNotificationRequests { requests in
                continuation.resume(returning: requests)
            }
        }
    }
}
