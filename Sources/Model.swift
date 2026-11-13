import Foundation

struct Tab: Identifiable, Equatable {
    let id: Int
    let window: Int
    let title: String
    let url: String
    var host: String { URL(string: url)?.host ?? url }
}

struct SwitchSession {
    let tabs: [Tab]
    private(set) var index: Int
    init(tabs: [Tab], backwards: Bool = false) {
        self.tabs = tabs
        index = tabs.isEmpty ? 0 : (backwards ? tabs.count - 1 : min(1, tabs.count - 1))
    }
    var selected: Tab? { tabs.indices.contains(index) ? tabs[index] : nil }
    mutating func step(_ delta: Int) {
        guard !tabs.isEmpty else { return }
        index = ((index + delta) % tabs.count + tabs.count) % tabs.count
    }
}

struct Recency {
    private(set) var ids: [Int] = []
    mutating func observe(_ id: Int) { ids.removeAll { $0 == id }; ids.insert(id, at: 0) }
    mutating func reconcile(_ tabs: [Tab]) {
        let live = Set(tabs.map(\.id))
        ids.removeAll { !live.contains($0) }
        for tab in tabs where !ids.contains(tab.id) { ids.append(tab.id) }
    }
    func ordered(_ tabs: [Tab], active: Int) -> [Tab] {
        let ranks = Dictionary(uniqueKeysWithValues: ids.enumerated().map { ($1, $0) })
        return tabs.sorted { a, b in
            if a.id == active { return b.id != active }
            if b.id == active { return false }
            return (ranks[a.id] ?? Int.max) < (ranks[b.id] ?? Int.max)
        }
    }
}
