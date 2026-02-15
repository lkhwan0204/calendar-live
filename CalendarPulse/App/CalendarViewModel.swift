import Combine
import EventKit
import Foundation

@MainActor
final class CalendarViewModel: ObservableObject {
    enum PermissionState {
        case unknown
        case granted
        case denied
        case failed(String)
    }

    @Published var permissionState: PermissionState = .unknown
    @Published var nextEvent: CalendarEvent?
    @Published var statusMessage: String = "권한 확인 필요"
    @Published var selectedDate: Date = Date()
    @Published var dayEvents: [CalendarEvent] = []
    @Published var importantUpcomingEvents: [CalendarEvent] = []
    @Published var eventDateComponents: [DateComponents] = []
    @Published var availableCalendars: [CalendarListItem] = []

    private let calendarManager = CalendarManager()
    private let liveActivityManager = LiveActivityManager()
    private let notificationManager = NotificationManager()
    private let importantEventStore = ImportantEventStore()
    private var refreshCancellable: AnyCancellable?
    private var importantIDs: Set<String>
    private var didRequestInitialPermission = false
    private var refreshTick = 0
    private var lastReminderEventID: String?
    private var lastReminderStartDate: Date?
    private var eventStoreChangedObserver: NSObjectProtocol?
    private var lastEventStoreRefreshAt: Date = .distantPast

    init() {
        importantIDs = importantEventStore.all()
        permissionState = calendarManager.hasReadAccess() ? .granted : .unknown
        if case .granted = permissionState {
            statusMessage = "권한 이미 허용됨"
            refreshAvailableCalendars()
            refreshSelectedDateEvents()
            refreshImportantUpcomingEvents()
            refreshEventDateComponents()
        }
    }

    func requestCalendarPermission() async {
        do {
            let granted = try await calendarManager.requestAccess()
            permissionState = granted ? .granted : .denied
            statusMessage = granted ? "캘린더 권한 허용됨" : "캘린더 권한이 거부되었습니다"
            if granted {
                _ = try? await notificationManager.requestAccess()
                refreshAvailableCalendars()
                refreshNextEventAndLiveActivity()
                refreshSelectedDateEvents()
                refreshImportantUpcomingEvents()
                refreshEventDateComponents()
                startAutoRefresh()
                startObservingEventStoreChanges()
            } else {
                dayEvents = []
                importantUpcomingEvents = []
                eventDateComponents = []
                stopAutoRefresh()
                stopObservingEventStoreChanges()
            }
        } catch {
            permissionState = .failed(error.localizedDescription)
            statusMessage = "권한 요청 실패: \(error.localizedDescription)"
        }
    }

    func refreshNextEventAndLiveActivity() {
        let now = Date()
        let next = calendarManager.fetchNextEvent(withinHours: 24)
        nextEvent = next

        if next == nil {
            statusMessage = "24시간 내 예정 일정이 없습니다"
        } else {
            statusMessage = "다음 일정"
        }

        let activityCandidates = calendarManager.fetchEventsForLiveActivity(withinHours: 24)
            .filter { event in
                let secondsUntilStart = event.startDate.timeIntervalSince(now)
                let secondsUntilEnd = event.endDate.timeIntervalSince(now)
                let liveActivityStartSeconds = isImportant(event) ? 10800.0 : 3600.0
                return secondsUntilStart <= liveActivityStartSeconds && secondsUntilEnd > 0
            }

        Task {
            if activityCandidates.isEmpty {
                await liveActivityManager.endActivity()
            } else {
                await liveActivityManager.syncActivities(with: activityCandidates)
            }

            if let next {
                let shouldRescheduleReminder = next.id != lastReminderEventID || next.startDate != lastReminderStartDate
                if shouldRescheduleReminder {
                    await notificationManager.scheduleReminders(for: next, minutesBefore: 120)
                    lastReminderEventID = next.id
                    lastReminderStartDate = next.startDate
                }
            } else {
                await notificationManager.clearAllEventReminders()
                lastReminderEventID = nil
                lastReminderStartDate = nil
            }
        }
    }

    func onAppear() {
        switch permissionState {
        case .granted:
            refreshAvailableCalendars()
            refreshNextEventAndLiveActivity()
            refreshSelectedDateEvents()
            refreshImportantUpcomingEvents()
            refreshEventDateComponents()
            startAutoRefresh()
            startObservingEventStoreChanges()
        case .unknown:
            guard !didRequestInitialPermission else { return }
            didRequestInitialPermission = true
            Task { await requestCalendarPermission() }
        default:
            break
        }
    }

    func onDisappear() {
        stopAutoRefresh()
        stopObservingEventStoreChanges()
    }

    func handleAppActive() {
        guard case .granted = permissionState else { return }
        refreshAvailableCalendars()
        refreshNextEventAndLiveActivity()
        refreshSelectedDateEvents()
        refreshImportantUpcomingEvents()
        refreshEventDateComponents()
        startAutoRefresh()
        startObservingEventStoreChanges()
    }

    func handleAppBackground() {
        stopAutoRefresh()
        stopObservingEventStoreChanges()
    }

    func updateSelectedDate(_ date: Date) {
        selectedDate = date
        refreshSelectedDateEvents()
    }

    func createEvent(
        title: String,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool,
        calendarID: String?,
        notes: String?
    ) -> Bool {
        guard case .granted = permissionState else {
            statusMessage = "캘린더 권한이 필요합니다"
            return false
        }

        do {
            try calendarManager.createEvent(
                title: title,
                startDate: startDate,
                endDate: endDate,
                isAllDay: isAllDay,
                calendarID: calendarID,
                notes: notes
            )
            statusMessage = "다음 일정"
            refreshNextEventAndLiveActivity()
            refreshSelectedDateEvents()
            refreshImportantUpcomingEvents()
            refreshEventDateComponents()
            return true
        } catch {
            statusMessage = "일정 저장 실패: \(error.localizedDescription)"
            return false
        }
    }

    func updateEvent(
        event: CalendarEvent,
        title: String,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool,
        calendarID: String?,
        notes: String?
    ) -> Bool {
        guard case .granted = permissionState else {
            statusMessage = "캘린더 권한이 필요합니다"
            return false
        }

        do {
            try calendarManager.updateEvent(
                eventID: event.id,
                title: title,
                startDate: startDate,
                endDate: endDate,
                isAllDay: isAllDay,
                calendarID: calendarID,
                notes: notes
            )
            statusMessage = "다음 일정"
            refreshNextEventAndLiveActivity()
            refreshSelectedDateEvents()
            refreshImportantUpcomingEvents()
            refreshEventDateComponents()
            return true
        } catch {
            statusMessage = "일정 수정 실패: \(error.localizedDescription)"
            return false
        }
    }

    func deleteEvent(_ event: CalendarEvent) {
        guard case .granted = permissionState else {
            statusMessage = "캘린더 권한이 필요합니다"
            return
        }

        do {
            try calendarManager.deleteEvent(eventID: event.id)
            importantIDs.remove(event.id)
            importantEventStore.remove(event.id)
            statusMessage = "일정 삭제됨"
            refreshNextEventAndLiveActivity()
            refreshSelectedDateEvents()
            refreshImportantUpcomingEvents()
            refreshEventDateComponents()
        } catch {
            statusMessage = "일정 삭제 실패: \(error.localizedDescription)"
        }
    }

    func isImportant(_ event: CalendarEvent) -> Bool {
        importantIDs.contains(event.id)
    }

    func hasEvent(on dateComponents: DateComponents) -> Bool {
        let key = keyFor(dateComponents)
        return eventDateComponents.contains { keyFor($0) == key }
    }

    func toggleImportant(_ event: CalendarEvent) {
        let nowImportant = importantEventStore.toggle(event.id)
        if nowImportant {
            importantIDs.insert(event.id)
        } else {
            importantIDs.remove(event.id)
        }

        if nextEvent?.id == event.id {
            refreshNextEventAndLiveActivity()
        }
        refreshImportantUpcomingEvents()
    }

    private func refreshSelectedDateEvents() {
        guard case .granted = permissionState else {
            dayEvents = []
            return
        }
        dayEvents = calendarManager.fetchEvents(on: selectedDate)
    }

    private func refreshImportantUpcomingEvents() {
        guard case .granted = permissionState else {
            importantUpcomingEvents = []
            return
        }
        importantUpcomingEvents = calendarManager.fetchUpcomingEvents(withinDays: 30)
            .filter { isImportant($0) }
    }

    private func refreshEventDateComponents() {
        guard case .granted = permissionState else {
            eventDateComponents = []
            return
        }
        eventDateComponents = calendarManager.fetchEventDateComponents(pastDays: 365, futureDays: 365)
    }

    private func refreshAvailableCalendars() {
        guard case .granted = permissionState else {
            availableCalendars = []
            return
        }
        availableCalendars = calendarManager.fetchWritableCalendars()
    }

    private func startAutoRefresh() {
        guard refreshCancellable == nil else { return }
        refreshCancellable = Timer.publish(every: 180, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    self.refreshTick += 1
                    self.refreshNextEventAndLiveActivity()
                    if self.refreshTick % 3 == 0 {
                        self.refreshSelectedDateEvents()
                        self.refreshImportantUpcomingEvents()
                        self.refreshEventDateComponents()
                    }
                }
            }
    }

    private func stopAutoRefresh() {
        refreshCancellable?.cancel()
        refreshCancellable = nil
        refreshTick = 0
    }

    private func keyFor(_ dateComponents: DateComponents) -> String {
        "\(dateComponents.year ?? 0)-\(dateComponents.month ?? 0)-\(dateComponents.day ?? 0)"
    }

    private func startObservingEventStoreChanges() {
        guard eventStoreChangedObserver == nil else { return }

        eventStoreChangedObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.handleEventStoreChanged()
            }
        }
    }

    private func stopObservingEventStoreChanges() {
        guard let observer = eventStoreChangedObserver else { return }
        NotificationCenter.default.removeObserver(observer)
        eventStoreChangedObserver = nil
    }

    private func handleEventStoreChanged() {
        let now = Date()
        guard now.timeIntervalSince(lastEventStoreRefreshAt) > 0.8 else { return }
        lastEventStoreRefreshAt = now

        refreshNextEventAndLiveActivity()
        refreshAvailableCalendars()
        refreshSelectedDateEvents()
        refreshImportantUpcomingEvents()
        refreshEventDateComponents()
    }
}
