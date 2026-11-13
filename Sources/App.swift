import AppKit
import ScreenCaptureKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    var status: NSStatusItem!
    var tap: CFMachPort?
    var timer: Timer?
    var snapshot: Snapshot?
    var recency = Recency()
    var session: SwitchSession?
    let overlay = Overlay()
    var thumbnails: [Int: NSImage] = [:]
    var capturedURLs: [Int: String] = [:]
    var captureBusy = false
    var stableSince = Date()
    var lastCapture = Date.distantPast
    var generation = 0
    var suppressed = Set<Int64>()
    var enabled = true
    var lastError = ""
    var helpVisible = false
    // Dependencies are replaceable in the in-process integration tests; no global key injection.
    var frontmostChrome = { NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.google.Chrome" }
    var readSnapshot: () throws -> Snapshot? = Chrome.snapshot
    var activateTab: (Tab) throws -> Void = Chrome.activate
    var readURL: () throws -> String = Chrome.currentURL
    var writeClipboard: (String) -> Void = { url in
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url, forType: .string)
    }
    var chromeFront: Bool { frontmostChrome() }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        status.button?.image = NSImage(systemSymbolName: "rectangle.on.rectangle", accessibilityDescription: "Tab Switcher Pro")
        let menu = NSMenu()
        for (title, action) in [("Tab Switcher Pro", #selector(showHelp)), ("启用 / 暂停快捷键", #selector(toggle)), ("授权辅助功能并重试", #selector(authorize)), ("启用缩略图（屏幕录制权限）", #selector(authorizeCapture)), ("状态与使用说明", #selector(showHelp)), ("退出", #selector(quit))] {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
            item.target = self
            menu.addItem(item)
        }
        status.menu = menu
        if CommandLine.arguments.contains("--render-preview") {
            let tabs = [Tab(id: 1, window: 1, title: "Designing a better browser", url: "https://arc.net"), Tab(id: 2, window: 1, title: "Tab Switcher Pro", url: "https://github.com"), Tab(id: 3, window: 1, title: "2027 年计算机科学考试大纲", url: "https://example.org")]
            overlay.show(session: SwitchSession(tabs: tabs), images: [:])
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                let view = self.overlay.panel.contentView!
                view.layoutSubtreeIfNeeded()
                if let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
                    view.cacheDisplay(in: view.bounds, to: bitmap)
                    try? bitmap.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: CommandLine.arguments.last!))
                }
                NSApp.terminate(nil)
            }
            return
        }
        installTap()
        timer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in self?.poll() }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            if !self.chromeFront { self.cancel() }
            else { self.poll() }
        }
        if CommandLine.arguments.contains("--preview") {
            let tabs = [Tab(id: 1, window: 1, title: "Designing a better browser", url: "https://arc.net"), Tab(id: 2, window: 1, title: "Tab Switcher Pro", url: "https://github.com"), Tab(id: 3, window: 1, title: "2027 年计算机科学考试大纲", url: "https://example.org")]
            overlay.show(session: SwitchSession(tabs: tabs), images: [:])
        } else if !UserDefaults.standard.bool(forKey: "introduced") {
            UserDefaults.standard.set(true, forKey: "introduced")
            showHelp()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showHelp()
        return true
    }

    @objc func quit() { NSApp.terminate(nil) }
    @objc func toggle() { enabled.toggle(); cancel(); status.button?.appearsDisabled = !enabled }
    @objc func authorize() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        installTap()
    }
    @objc func authorizeCapture() { _ = CGRequestScreenCaptureAccess() }
    @objc func showHelp() {
        guard !helpVisible else { return }
        helpVisible = true
        defer { helpVisible = false }
        let alert = NSAlert()
        alert.messageText = "Tab Switcher Pro"
        alert.informativeText = "⌃ Tab：最近使用顺序切换；松开 Control 确认\n⌃ ⇧ Tab：反向；Esc：取消\n⌘ ⌃ C：复制当前标签链接\n\n请在系统设置 → 隐私与安全性 → 辅助功能中启用本应用，然后点击菜单中的授权并重试。首次访问 Chrome 时允许自动化控制。缩略图需要单独授权屏幕录制。\n\n仅当前 Chrome 窗口。访问过的普通标签缓存预览；无痕窗口不截图。缓存只在内存，退出即清除。\n\n状态：\(tap == nil ? "快捷键尚未获得授权" : "快捷键已就绪")\n\(lastError)"
        alert.addButton(withTitle: "知道了")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
    func installTap() {
        guard tap == nil else { return }
        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
        tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: CGEventMask(mask), callback: { _, type, event, context in
            let app = Unmanaged<AppDelegate>.fromOpaque(context!).takeUnretainedValue()
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let tap = app.tap { CGEvent.tapEnable(tap: tap, enable: true) }
                app.cancel()
                return Unmanaged.passUnretained(event)
            }
            return app.handle(type, event) ? nil : Unmanaged.passUnretained(event)
        }, userInfo: Unmanaged.passUnretained(self).toOpaque())
        if let tap {
            CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0), .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }
    func handle(_ type: CGEventType, _ event: CGEvent) -> Bool {
        let code = event.getIntegerValueField(.keyboardEventKeycode)
        if type == .keyUp, suppressed.remove(code) != nil { return true }
        guard enabled, chromeFront else { return false }
        let flags = event.flags
        if type == .flagsChanged {
            if session != nil && !flags.contains(.maskControl) { commit() }
            return false
        }
        guard type == .keyDown else { return false }
        if code == 48, flags.contains(.maskControl), !flags.contains(.maskCommand), !flags.contains(.maskAlternate) {
            guard let snapshot, !snapshot.tabs.isEmpty else { return false }
            generation += 1
            if session == nil {
                session = SwitchSession(tabs: recency.ordered(snapshot.tabs, active: snapshot.active), backwards: flags.contains(.maskShift))
                let token = generation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
                    guard let self, self.generation == token, let session = self.session else { return }
                    self.overlay.show(session: session, images: self.thumbnails)
                }
            } else {
                session?.step(flags.contains(.maskShift) ? -1 : 1)
                if let session { overlay.show(session: session, images: thumbnails) }
            }
            suppressed.insert(code)
            return true
        }
        if session != nil && code == 53 { cancel(); suppressed.insert(code); return true }
        if code == 8, flags.contains(.maskCommand), flags.contains(.maskControl), !flags.contains(.maskAlternate), !flags.contains(.maskShift) {
            if event.getIntegerValueField(.keyboardEventAutorepeat) == 0 {
                DispatchQueue.main.async { [weak self] in self?.copyURL() }
            }
            suppressed.insert(code)
            return true
        }
        if session != nil { cancel() }
        return false
    }
    func cancel() { generation += 1; session = nil; overlay.hide() }
    func commit() {
        let tab = session?.selected
        cancel()
        guard let tab else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self, self.chromeFront else { return }
            do {
                guard let current = try self.readSnapshot(), current.window == tab.window else { return }
                try self.activateTab(tab)
                self.recency.observe(tab.id)
                self.poll()
            }
            catch { self.report(error) }
        }
    }
    func copyURL() {
        guard chromeFront else { return }
        do {
            let url = try readURL()
            guard !url.isEmpty else { return }
            writeClipboard(url)
            if session == nil {
                generation += 1
                let token = generation
                overlay.state.message = "链接已复制"
                overlay.present(width: 200, height: 62)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                    guard let self, self.generation == token else { return }; self.overlay.hide()
                }
            }
        } catch { report(error) }
    }
    func report(_ error: Error) { lastError = error.localizedDescription; status?.button?.toolTip = lastError }
    func poll() {
        guard enabled, chromeFront, session == nil, !CommandLine.arguments.contains("--preview") else { return }
        do {
            let next = try readSnapshot()
            if next?.active != snapshot?.active || next?.tabs != snapshot?.tabs { stableSince = Date() }
            snapshot = next
            guard let next else { thumbnails.removeAll(); capturedURLs.removeAll(); return }
            // Keep MRU across windows, but only offer the front window's tabs.
            recency.observe(next.active)
            // Bound retained state without dropping other windows on every poll.
            if recency.ids.count > 2000 { recency.reconcile(next.tabs) }
            let live = Set(next.tabs.map(\.id))
            thumbnails = thumbnails.filter { live.contains($0.key) }
            capturedURLs = capturedURLs.filter { live.contains($0.key) }
            for tab in next.tabs where capturedURLs[tab.id] != tab.url { thumbnails.removeValue(forKey: tab.id) }
            if next.incognito { thumbnails.removeAll(); return }
            if Date().timeIntervalSince(stableSince) > 0.55 && Date().timeIntervalSince(lastCapture) > 2 {
                capture(next)
            }
        } catch { snapshot = nil; report(error) }
    }
    func capture(_ source: Snapshot) {
        guard !captureBusy, CGPreflightScreenCaptureAccess(), !overlay.panel.isVisible else { return }
        captureBusy = true
        lastCapture = Date()
        Task { @MainActor in
            defer { captureBusy = false }
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
                let windowInfo = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] ?? []
                guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier, chromeFront,
                      let front = windowInfo.first(where: { ($0[kCGWindowOwnerPID as String] as? Int) == Int(pid) && ($0[kCGWindowLayer as String] as? Int) == 0 }),
                      let number = front[kCGWindowNumber as String] as? UInt32,
                      let window = content.windows.first(where: { $0.windowID == number }),
                      session == nil, !overlay.panel.isVisible,
                      let before = try readSnapshot(), before.active == source.active, before.window == source.window else { return }
                let config = SCStreamConfiguration()
                config.width = 480
                config.height = max(1, Int(480 * window.frame.height / max(1, window.frame.width)))
                config.showsCursor = false
                let image = try await SCScreenshotManager.captureImage(contentFilter: SCContentFilter(desktopIndependentWindow: window), configuration: config)
                guard chromeFront, session == nil, !overlay.panel.isVisible,
                      let after = try readSnapshot(), after.active == source.active, after.window == source.window,
                      after.tabs == source.tabs, !after.incognito else { return }
                thumbnails[source.active] = NSImage(cgImage: image, size: .zero)
                capturedURLs[source.active] = source.tabs.first(where: { $0.id == source.active })?.url
                if thumbnails.count > 80 { thumbnails.removeAll(); capturedURLs.removeAll() }
            } catch { report(error) }
        }
    }
}

#if !TESTING
@main
struct Main {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}

#endif
