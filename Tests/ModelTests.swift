import Foundation

@main struct ModelTests {
    static func main() {
        let tabs = (1...4).map { Tab(id: $0, window: 10, title: "Tab \($0)", url: "https://example.com/\($0)") }
        var history = Recency()
        history.reconcile(tabs)
        history.observe(2); history.observe(4); history.observe(1)
        assert(history.ordered(tabs, active: 1).map(\.id) == [1, 4, 2, 3])
        var session = SwitchSession(tabs: history.ordered(tabs, active: 1))
        assert(session.selected?.id == 4, "First Tab picks previous, not current")
        history.observe(3)
        assert(session.tabs.map(\.id) == [1, 4, 2, 3], "Order must freeze during gesture")
        session.step(1); assert(session.selected?.id == 2)
        session.step(2); assert(session.selected?.id == 1)
        session.step(-1); assert(session.selected?.id == 3)
        assert(SwitchSession(tabs: tabs, backwards: true).selected?.id == 4)
        var empty = SwitchSession(tabs: []); empty.step(-1); assert(empty.selected == nil)
        var single = SwitchSession(tabs: [tabs[0]]); single.step(1); assert(single.selected?.id == 1)
        history.reconcile([tabs[0], tabs[3]])
        assert(Set(history.ids) == [1, 4], "Closed tabs removed")
        history.observe(4); history.observe(4); assert(history.ids == [4, 1])
        history.observe(1)
        let first = SwitchSession(tabs: history.ordered(tabs, active: 1)).selected!
        history.observe(first.id)
        let second = SwitchSession(tabs: history.ordered(tabs, active: first.id)).selected!
        assert(first.id == 4 && second.id == 1, "Quick gestures toggle last two tabs")
        let otherWindow = Tab(id: 99, window: 20, title: "Other", url: "chrome://settings")
        history.observe(otherWindow.id)
        assert(!history.ordered(tabs, active: 1).contains(otherWindow))
        for count in 1...40 {
            var cycle = SwitchSession(tabs: Array(repeating: tabs[0], count: count))
            for _ in 0..<count { cycle.step(1) }
            assert(cycle.index == min(1, count - 1))
            cycle.step(-1001)
            assert(cycle.index >= 0 && cycle.index < count)
        }
        print("PASS: MRU, frozen selection, forward/backward wrap, cancellation-safe model, empty/single, closed tabs, quick toggle, window isolation, 40 cycle sizes")
    }
}
