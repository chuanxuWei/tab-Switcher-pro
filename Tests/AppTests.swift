import AppKit

@main @MainActor struct AppTests {
    static var checks = 0
    static func check(_ condition: @autoclosure () -> Bool, _ label: String) {
        checks += 1
        guard condition() else { fatalError("FAIL: \(label)") }
        print("PASS: \(label)")
    }
    static func pump(_ seconds: TimeInterval = 0.02) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
    static func key(_ app: AppDelegate, _ code: CGKeyCode, _ flags: CGEventFlags = [], type: CGEventType = .keyDown, repeatKey: Bool = false) -> Bool {
        let event = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: type == .keyDown)!
        event.flags = flags
        event.setIntegerValueField(.keyboardEventAutorepeat, value: repeatKey ? 1 : 0)
        return app.handle(type, event)
    }
    static func main() async {
        setbuf(stdout, nil)
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.accessory)
        let app = AppDelegate()
        let tabs = (1...3).map { Tab(id: $0, window: 7, title: "Test \($0)", url: "https://example.com/\($0)") }
        var current = Snapshot(tabs: tabs, active: 3, window: 7, incognito: false)
        var activated: [Int] = []
        var clipboard: [String] = []
        app.frontmostChrome = { true }
        app.readSnapshot = { current }
        app.activateTab = { tab in
            activated.append(tab.id)
            current = Snapshot(tabs: tabs, active: tab.id, window: 7, incognito: false)
        }
        app.readURL = { "https://example.com/actual?x=1#fragment" }
        app.writeClipboard = { clipboard.append($0) }
        app.snapshot = current
        tabs.forEach { app.recency.observe($0.id) }
        check(key(app, 48, .maskControl), "Control Tab intercepted")
        check(app.session?.selected?.id == 2, "first selection is previous tab")
        check(activated.isEmpty, "holding control does not activate Chrome tab")
        check(!app.overlay.panel.isVisible, "quick gesture avoids flash")
        check(key(app, 48, [], type: .keyUp), "matching key-up consumed")
        _ = key(app, 59, [], type: .flagsChanged)
        await pump()
        check(activated == [2], "release commits exactly once")
        _ = key(app, 48, .maskControl)
        _ = key(app, 59, [], type: .flagsChanged)
        await pump()
        check(activated == [2, 3], "second quick gesture toggles back")
        _ = key(app, 48, .maskControl)
        await pump(0.16)
        check(app.overlay.panel.isVisible, "held gesture shows overlay after delay")
        _ = key(app, 48, .maskControl)
        check(app.session?.selected?.id == 1, "repeated Tab advances frozen order")
        _ = key(app, 48, [.maskControl, .maskShift])
        check(app.session?.selected?.id == 2, "Shift reverses selection")
        _ = key(app, 53)
        check(app.session == nil && !app.overlay.panel.isVisible, "Escape cancels and hides")
        _ = key(app, 59, [], type: .flagsChanged)
        await pump()
        check(activated == [2, 3], "release after Escape does not activate")
        _ = key(app, 48, [.maskControl, .maskShift])
        check(app.session?.selected?.id == 1, "initial reverse picks last tab")
        app.cancel()
        _ = key(app, 48, .maskControl)
        check(!key(app, 0, .maskControl) && app.session == nil, "other key cancels but passes through")
        app.frontmostChrome = { false }
        check(!key(app, 48, .maskControl), "other applications untouched")
        app.frontmostChrome = { true }
        app.enabled = false
        check(!key(app, 48, .maskControl), "paused app passes Control Tab through")
        app.enabled = true
        check(!key(app, 48, [.maskControl, .maskCommand]), "Command Control Tab not hijacked")
        check(!key(app, 48, [.maskControl, .maskAlternate]), "Option Control Tab not hijacked")
        check(key(app, 8, [.maskControl, .maskCommand]), "copy shortcut intercepted")
        await pump()
        check(clipboard == ["https://example.com/actual?x=1#fragment"], "copy uses actual full URL")
        _ = key(app, 8, [.maskControl, .maskCommand], repeatKey: true)
        await pump()
        check(clipboard.count == 1, "copy auto-repeat ignored")
        app.readURL = { "" }; app.copyURL()
        check(clipboard.count == 1, "empty URL preserves clipboard")
        app.readURL = { throw NSError(domain: "test", code: -1743) }; app.copyURL()
        check(!app.lastError.isEmpty && clipboard.count == 1, "automation failure reported without clipboard loss")
        app.cancel()
        _ = key(app, 48, .maskControl)
        current = Snapshot(tabs: [], active: 99, window: 99, incognito: false)
        _ = key(app, 59, [], type: .flagsChanged)
        await pump()
        check(activated == [2, 3], "changed window prevents stale commit")
        current = Snapshot(tabs: tabs, active: 3, window: 7, incognito: false)
        app.activateTab = { _ in throw NSError(domain: "closed-tab", code: 1) }
        _ = key(app, 48, .maskControl)
        _ = key(app, 59, [], type: .flagsChanged)
        await pump()
        check(app.lastError.contains("closed-tab") && app.session == nil, "closed tab error ends session safely")
        app.readSnapshot = { throw NSError(domain: "denied", code: 1) }
        app.poll()
        check(app.snapshot == nil, "failed poll clears stale snapshot")
        check(!key(app, 48, .maskControl), "no snapshot preserves native shortcut")
        app.snapshot = Snapshot(tabs: [], active: 0, window: 7, incognito: false)
        check(!key(app, 48, .maskControl), "zero tabs preserves native shortcut")
        app.readSnapshot = { Snapshot(tabs: tabs, active: 3, window: 7, incognito: true) }
        app.thumbnails[3] = NSImage(size: NSSize(width: 20, height: 20))
        app.poll()
        check(app.thumbnails.isEmpty, "incognito clears preview cache")
        app.readSnapshot = { Snapshot(tabs: tabs, active: 3, window: 7, incognito: false) }
        app.thumbnails[99] = NSImage(size: NSSize(width: 20, height: 20))
        app.capturedURLs[99] = "https://closed.example"
        app.thumbnails[3] = NSImage(size: NSSize(width: 20, height: 20))
        app.capturedURLs[3] = "https://old.example"
        app.poll()
        check(app.thumbnails.isEmpty && app.capturedURLs[99] == nil, "closed and navigated tab thumbnails invalidated")
        app.readSnapshot = { nil }
        app.thumbnails[3] = NSImage(size: NSSize(width: 20, height: 20))
        app.poll()
        check(app.snapshot == nil && app.thumbnails.isEmpty && app.capturedURLs.isEmpty, "no Chrome windows clears previews and URL cache")
        app.snapshot = current
        app.readSnapshot = { current }
        app.status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        _ = key(app, 48, .maskControl)
        app.toggle()
        check(!app.enabled && app.session == nil && !app.overlay.panel.isVisible, "menu pause cancels active gesture")
        app.toggle()
        check(app.enabled, "menu resume re-enables handling")
        _ = key(app, 48, .maskControl)
        app.cancel()
        await pump(0.16)
        check(!app.overlay.panel.isVisible, "cancel invalidates delayed overlay callback")
        app.frontmostChrome = { false }
        app.readURL = { fatalError("must not access another app") }
        app.copyURL()
        check(clipboard.count == 1, "copy outside Chrome does not read or modify clipboard")
        app.cancel()
        print("PASS: \(checks) application integration checks (in-process; no OS event posting)")
    }
}
