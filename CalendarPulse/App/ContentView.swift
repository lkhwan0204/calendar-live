import SwiftUI
import UIKit

struct ContentView: View {
    enum CalendarTab: String, CaseIterable, Identifiable {
        case all = "전체 일정"
        case important = "중요 일정"

        var id: String { rawValue }
    }

    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel = CalendarViewModel()
    @State private var calendarTab: CalendarTab = .all
    @State private var showAddEventSheet = false
    @State private var editingEvent: CalendarEvent?
    @State private var pendingDeleteEvent: CalendarEvent?
    @State private var showDeleteConfirm = false
    @State private var openSwipeRowID: String?

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    Text(viewModel.statusMessage)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)

                    if let event = viewModel.nextEvent {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .top) {
                                Text(event.title)
                                    .font(.title3.weight(.semibold))
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.85)
                                Spacer()
                                Button {
                                    viewModel.toggleImportant(event)
                                } label: {
                                    Image(systemName: viewModel.isImportant(event) ? "star.fill" : "star")
                                        .foregroundStyle(viewModel.isImportant(event) ? .yellow : .secondary)
                                }
                                .buttonStyle(.plain)
                            }

                            Text(event.calendarName)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Text(event.localizedStartDateText)
                                .font(.subheadline)

                            Text(event.countdownText)
                                .font(.headline)

                            Text(viewModel.isImportant(event) ? "중요 일정: Live Activity 3시간 전 시작" : "일반 일정: Live Activity 1시간 전 시작")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("캘린더")
                                .font(.headline)
                            Spacer()
                            Button {
                                showAddEventSheet = true
                            } label: {
                                Image(systemName: "plus")
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .frame(width: 30, height: 30)
                                    .background(Color(.tertiarySystemFill), in: Circle())
                            }
                            .buttonStyle(.plain)
                        }

                        Picker("탭", selection: $calendarTab) {
                            ForEach(CalendarTab.allCases) { tab in
                                Text(tab.rawValue).tag(tab)
                            }
                        }
                        .pickerStyle(.segmented)

                        if calendarTab == .all {
                            EventCalendarView(
                                selectedDate: $viewModel.selectedDate,
                                decoratedDateComponents: viewModel.eventDateComponents,
                                hasEvent: viewModel.hasEvent(on:)
                            )
                            .frame(maxWidth: .infinity)
                            .frame(height: 350)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .padding(.bottom, 8)
                            .onChange(of: viewModel.selectedDate) { date in
                                viewModel.updateSelectedDate(date)
                            }

                            if viewModel.dayEvents.isEmpty {
                                Text("선택한 날짜에 일정이 없습니다")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(viewModel.dayEvents, id: \.rowID) { event in
                                    eventRow(event)
                                }
                            }
                        } else {
                            Text("앞으로 30일 중요 일정")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            if viewModel.importantUpcomingEvents.isEmpty {
                                Text("중요로 체크된 일정이 없습니다")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(viewModel.importantUpcomingEvents, id: \.rowID) { event in
                                    eventRow(event)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                }
                .frame(maxWidth: .infinity, alignment: .top)
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
            }
            .navigationTitle("캘린더 라이브")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            viewModel.onAppear()
        }
        .onDisappear {
            viewModel.onDisappear()
        }
        .onChange(of: scenePhase) { newPhase in
            switch newPhase {
            case .active:
                viewModel.handleAppActive()
            case .background:
                viewModel.handleAppBackground()
            default:
                break
            }
        }
        .sheet(isPresented: $showAddEventSheet) {
            AddEventSheet(calendarOptions: viewModel.availableCalendars) { title, startDate, endDate, isAllDay, calendarID, notes in
                viewModel.createEvent(
                    title: title,
                    startDate: startDate,
                    endDate: endDate,
                    isAllDay: isAllDay,
                    calendarID: calendarID,
                    notes: notes
                )
            }
        }
        .sheet(item: $editingEvent) { event in
            AddEventSheet(existingEvent: event, calendarOptions: viewModel.availableCalendars) { title, startDate, endDate, isAllDay, calendarID, notes in
                viewModel.updateEvent(
                    event: event,
                    title: title,
                    startDate: startDate,
                    endDate: endDate,
                    isAllDay: isAllDay,
                    calendarID: calendarID,
                    notes: notes
                )
            }
        }
        .alert("일정을 삭제하시겠습니까?", isPresented: $showDeleteConfirm, presenting: pendingDeleteEvent) { event in
            Button("삭제", role: .destructive) {
                viewModel.deleteEvent(event)
                pendingDeleteEvent = nil
            }
            Button("취소", role: .cancel) {
                pendingDeleteEvent = nil
            }
        } message: { _ in
            Text("삭제한 일정은 되돌릴 수 없습니다.")
        }
    }

    private func eventRow(_ event: CalendarEvent) -> some View {
        SwipeableEventRow(
            rowID: event.rowID,
            openRowID: $openSwipeRowID,
            onTap: { editingEvent = event },
            onEdit: { editingEvent = event },
            onDelete: {
                pendingDeleteEvent = event
                showDeleteConfirm = true
            }
        ) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                    Text(event.calendarName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(event.localizedDateTimeRangeText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    viewModel.toggleImportant(event)
                } label: {
                    Image(systemName: viewModel.isImportant(event) ? "star.fill" : "star")
                        .foregroundStyle(viewModel.isImportant(event) ? .yellow : .secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
        }
    }
}

private struct AddEventSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(3600)
    @State private var isAllDay = false
    @State private var selectedCalendarID = ""
    @State private var notes = ""

    let calendarOptions: [CalendarListItem]
    let onSave: (String, Date, Date, Bool, String?, String?) -> Bool
    let titleText: String

    init(
        existingEvent: CalendarEvent? = nil,
        calendarOptions: [CalendarListItem],
        onSave: @escaping (String, Date, Date, Bool, String?, String?) -> Bool
    ) {
        self.calendarOptions = calendarOptions
        self.onSave = onSave
        self.titleText = existingEvent == nil ? "일정 추가" : "일정 수정"
        let existingCalendarID = existingEvent?.calendarID
        let selectableInitialCalendarID: String
        if let existingCalendarID, calendarOptions.contains(where: { $0.id == existingCalendarID }) {
            selectableInitialCalendarID = existingCalendarID
        } else {
            selectableInitialCalendarID = calendarOptions.first?.id ?? ""
        }
        _title = State(initialValue: existingEvent?.title == "제목 없음" ? "" : (existingEvent?.title ?? ""))
        _startDate = State(initialValue: existingEvent?.startDate ?? Date())
        _endDate = State(initialValue: existingEvent?.endDate ?? Date().addingTimeInterval(3600))
        _isAllDay = State(initialValue: existingEvent?.isAllDay ?? false)
        _selectedCalendarID = State(initialValue: selectableInitialCalendarID)
        _notes = State(initialValue: existingEvent?.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("기본 정보") {
                    TextField("제목", text: $title)
                    Toggle("종일", isOn: $isAllDay)
                }

                if !calendarOptions.isEmpty {
                    Section("캘린더") {
                        Picker("캘린더 선택", selection: $selectedCalendarID) {
                            ForEach(calendarOptions) { calendar in
                                Text(calendar.title).tag(calendar.id)
                            }
                        }
                    }
                }

                Section("시간") {
                    DatePicker("시작", selection: $startDate, displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute])
                    DatePicker("종료", selection: $endDate, in: startDate..., displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute])
                }
                .environment(\.locale, Locale(identifier: "ko_KR"))

                Section("메모") {
                    TextField("선택 입력", text: $notes, axis: .vertical)
                        .lineLimit(3...)
                }
            }
            .navigationTitle(titleText)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        let saved = onSave(
                            title,
                            startDate,
                            endDate,
                            isAllDay,
                            selectedCalendarID.isEmpty ? nil : selectedCalendarID,
                            notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes
                        )
                        if saved { dismiss() }
                    }
                }
            }
        }
    }
}

private struct SwipeableEventRow<Content: View>: View {
    private let maxOffset: CGFloat = 148
    private let tapFeedback = UIImpactFeedbackGenerator(style: .light)
    @State private var offset: CGFloat = 0
    @State private var isHorizontalDrag = false
    @State private var hasLockedDirection = false
    @State private var dragStartOffset: CGFloat = 0
    @State private var tapHighlight = false

    let rowID: String
    @Binding var openRowID: String?
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack(alignment: .trailing) {
            HStack(spacing: 8) {
                Button("수정") {
                    withAnimation(.easeOut(duration: 0.2)) { offset = 0 }
                    openRowID = nil
                    onEdit()
                }
                .font(.caption.weight(.semibold))
                .frame(width: 68, height: 36)
                .background(Color.blue.opacity(0.16), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                Button("삭제") {
                    withAnimation(.easeOut(duration: 0.2)) { offset = 0 }
                    openRowID = nil
                    onDelete()
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.red)
                .frame(width: 68, height: 36)
                .background(Color.red.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            content()
                .contentShape(Rectangle())
                .background(Color(.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.primary.opacity(tapHighlight && offset == 0 ? 0.12 : 0))
                )
                .animation(.easeOut(duration: 0.12), value: tapHighlight)
                .offset(x: offset)
                .onTapGesture {
                    if offset != 0 {
                        withAnimation(.easeOut(duration: 0.2)) { offset = 0 }
                        openRowID = nil
                    } else {
                        tapHighlight = true
                        tapFeedback.impactOccurred(intensity: 0.7)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                            tapHighlight = false
                            onTap()
                        }
                    }
                }
                .simultaneousGesture(
                DragGesture(minimumDistance: 18)
                    .onChanged { value in
                        let horizontal = abs(value.translation.width)
                        let vertical = abs(value.translation.height)

                        if !hasLockedDirection {
                            // Vertical scroll should win unless the user clearly drags sideways.
                            guard horizontal > 24, horizontal > vertical * 1.8 else {
                                return
                            }
                            hasLockedDirection = true
                            isHorizontalDrag = true
                            dragStartOffset = offset
                        }

                        openRowID = rowID
                        let proposed = dragStartOffset + value.translation.width
                        // Only right-to-left opens actions; left-to-right closes only if already open.
                        offset = min(0, max(-maxOffset, proposed))
                    }
                    .onEnded { value in
                        defer {
                            isHorizontalDrag = false
                            hasLockedDirection = false
                            dragStartOffset = offset
                        }
                        guard isHorizontalDrag else { return }
                        let shouldOpen = value.translation.width < -70 || value.predictedEndTranslation.width < -120
                        withAnimation(.easeOut(duration: 0.2)) {
                            offset = shouldOpen ? -maxOffset : 0
                        }
                        openRowID = shouldOpen ? rowID : nil
                    }
                )
        }
        .onChange(of: openRowID) { newValue in
            guard newValue != rowID, offset != 0 else { return }
            withAnimation(.easeOut(duration: 0.2)) { offset = 0 }
        }
    }
}
