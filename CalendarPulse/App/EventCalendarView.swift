import SwiftUI
import UIKit

struct EventCalendarView: UIViewRepresentable {
    @Binding var selectedDate: Date
    let decoratedDateComponents: [DateComponents]
    let hasEvent: (DateComponents) -> Bool

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.clipsToBounds = false

        let calendarView = UICalendarView()
        calendarView.translatesAutoresizingMaskIntoConstraints = false
        calendarView.calendar = Calendar.current
        calendarView.locale = Locale(identifier: "ko_KR")
        calendarView.delegate = context.coordinator

        let selection = UICalendarSelectionSingleDate(delegate: context.coordinator)
        calendarView.selectionBehavior = selection

        let selected = Calendar.current.dateComponents([.year, .month, .day], from: selectedDate)
        selection.setSelected(selected, animated: false)

        container.addSubview(calendarView)
        NSLayoutConstraint.activate([
            calendarView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            calendarView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            calendarView.topAnchor.constraint(equalTo: container.topAnchor),
            calendarView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        context.coordinator.selection = selection
        context.coordinator.calendarView = calendarView

        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.hasEvent = hasEvent

        let selected = Calendar.current.dateComponents([.year, .month, .day], from: selectedDate)
        context.coordinator.selection?.setSelected(selected, animated: false)
        context.coordinator.calendarView?.reloadDecorations(forDateComponents: decoratedDateComponents, animated: true)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(selectedDate: $selectedDate, hasEvent: hasEvent)
    }

    final class Coordinator: NSObject, UICalendarViewDelegate, UICalendarSelectionSingleDateDelegate {
        @Binding var selectedDate: Date
        var hasEvent: (DateComponents) -> Bool
        weak var selection: UICalendarSelectionSingleDate?
        weak var calendarView: UICalendarView?
        private let feedbackGenerator = UISelectionFeedbackGenerator()

        init(selectedDate: Binding<Date>, hasEvent: @escaping (DateComponents) -> Bool) {
            _selectedDate = selectedDate
            self.hasEvent = hasEvent
        }

        func dateSelection(_ selection: UICalendarSelectionSingleDate, didSelectDate dateComponents: DateComponents?) {
            guard let dateComponents,
                  let date = Calendar.current.date(from: dateComponents) else {
                return
            }
            feedbackGenerator.selectionChanged()
            selectedDate = date
        }

        func calendarView(_ calendarView: UICalendarView, decorationFor dateComponents: DateComponents) -> UICalendarView.Decoration? {
            guard hasEvent(dateComponents) else { return nil }
            return .default(color: .systemPink, size: .small)
        }

        func calendarView(
            _ calendarView: UICalendarView,
            didChangeVisibleDateComponentsFrom previousDateComponents: DateComponents
        ) {
            guard
                let visibleYear = calendarView.visibleDateComponents.year,
                let visibleMonth = calendarView.visibleDateComponents.month
            else {
                return
            }

            let calendar = Calendar.current
            let selectedComp = calendar.dateComponents([.year, .month, .day], from: selectedDate)

            if selectedComp.year == visibleYear, selectedComp.month == visibleMonth {
                return
            }

            var target = DateComponents()
            target.year = visibleYear
            target.month = visibleMonth
            target.day = 1
            guard let firstDayOfMonth = calendar.date(from: target),
                  let dayRange = calendar.range(of: .day, in: .month, for: firstDayOfMonth) else {
                return
            }

            let preferredDay = selectedComp.day ?? 1
            target.day = min(max(preferredDay, 1), dayRange.count)

            guard let newDate = calendar.date(from: target) else { return }
            selectedDate = newDate
            selection?.setSelected(target, animated: false)
        }
    }
}
