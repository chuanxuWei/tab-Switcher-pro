import AppKit

struct Snapshot {
    let tabs: [Tab]
    let active: Int
    let window: Int
    let incognito: Bool
}

enum Chrome {
    static func run(_ source: String) throws -> NSAppleEventDescriptor {
        var error: NSDictionary?
        let value = NSAppleScript(source: source)!.executeAndReturnError(&error)
        if let error { throw NSError(domain: "Chrome", code: 1, userInfo: [NSLocalizedDescriptionKey: error.description]) }
        return value
    }
    static func snapshot() throws -> Snapshot? {
        let result = try run("""
        tell application "Google Chrome"
            if (count of windows) = 0 then return {}
            set w to front window
            set rows to {}
            repeat with t in tabs of w
                set end of rows to {id of t, title of t, URL of t}
            end repeat
            return {id of w, id of active tab of w, mode of w, rows}
        end tell
        """)
        guard result.numberOfItems == 4,
              let rows = result.atIndex(4) else { return nil }
        let window = Int(result.atIndex(1)!.int32Value)
        var tabs: [Tab] = []
        if rows.numberOfItems > 0 {
            for i in 1...rows.numberOfItems {
                guard let row = rows.atIndex(i), row.numberOfItems == 3 else { continue }
                tabs.append(Tab(id: Int(row.atIndex(1)!.int32Value), window: window,
                                title: row.atIndex(2)?.stringValue ?? "Untitled", url: row.atIndex(3)?.stringValue ?? ""))
            }
        }
        return Snapshot(tabs: tabs, active: Int(result.atIndex(2)!.int32Value), window: window,
                        incognito: result.atIndex(3)?.stringValue == "incognito")
    }
    static func activate(_ tab: Tab) throws {
        // Resolve by stable tab ID again: tab positions may change while the switcher is open.
        _ = try run("""
        tell application "Google Chrome"
            set w to window id \(tab.window)
            repeat with i from 1 to count of tabs of w
                if id of tab i of w = \(tab.id) then
                    set active tab index of w to i
                    return true
                end if
            end repeat
            error "The selected tab was closed."
        end tell
        """)
    }
    static func currentURL() throws -> String {
        try run("tell application \"Google Chrome\" to get URL of active tab of front window").stringValue ?? ""
    }
}
