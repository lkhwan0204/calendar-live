import Foundation

@MainActor
final class ImportantEventStore {
    private let key = "calendarpulse.important_event_ids"
    private let defaults = UserDefaults.standard

    func all() -> Set<String> {
        Set(defaults.stringArray(forKey: key) ?? [])
    }

    func contains(_ id: String) -> Bool {
        all().contains(id)
    }

    func toggle(_ id: String) -> Bool {
        var ids = all()
        if ids.contains(id) {
            ids.remove(id)
        } else {
            ids.insert(id)
        }
        defaults.set(Array(ids), forKey: key)
        return ids.contains(id)
    }

    func remove(_ id: String) {
        var ids = all()
        ids.remove(id)
        defaults.set(Array(ids), forKey: key)
    }
}
