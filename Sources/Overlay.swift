import AppKit
import SwiftUI

final class OverlayState: ObservableObject {
    @Published var tabs: [Tab] = []
    @Published var selected = 0
    @Published var images: [Int: NSImage] = [:]
    @Published var message: String? = nil
}

struct SwitcherView: View {
    @ObservedObject var state: OverlayState
    var body: some View {
        VStack(spacing: 10) {
            if let message = state.message {
                Label(message, systemImage: "link").font(.system(size: 14, weight: .medium)).padding(12)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(Array(state.tabs.enumerated()), id: \.element.id) { index, tab in
                                VStack(alignment: .leading, spacing: 7) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 7).fill(Color(nsColor: .controlBackgroundColor))
                                        if let image = state.images[tab.id] {
                                            Image(nsImage: image).resizable().aspectRatio(contentMode: .fit)
                                        } else {
                                            VStack(spacing: 8) {
                                                Image(systemName: "globe").font(.system(size: 26, weight: .light))
                                                Text(tab.host).font(.system(size: 10)).lineLimit(1)
                                            }.foregroundStyle(.secondary).padding(8)
                                        }
                                    }.frame(width: 156, height: 100).clipShape(RoundedRectangle(cornerRadius: 7))
                                    Text(tab.title).font(.system(size: 11, weight: .medium)).lineLimit(1)
                                        .frame(width: 156, alignment: .leading)
                                }
                                .padding(7)
                                .background(index == state.selected ? Color(red: 0.88, green: 0.47, blue: 0.64).opacity(0.35) : .clear)
                                .clipShape(RoundedRectangle(cornerRadius: 11))
                                .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(index == state.selected ? Color(red: 0.86, green: 0.40, blue: 0.59) : .clear, lineWidth: 2))
                                .id(index)
                            }
                        }.padding(3)
                    }
                    .onChange(of: state.selected) { _, selection in proxy.scrollTo(selection, anchor: .center) }
                    .onAppear { proxy.scrollTo(state.selected, anchor: .center) }
                }
                HStack {
                    Text("最近使用").fontWeight(.medium)
                    Spacer()
                    Text("⇧ 反向   ·   esc 取消   ·   松开 ⌃ 切换")
                }.font(.system(size: 10)).foregroundStyle(.secondary).padding(.horizontal, 5)
            }
        }.padding(12)
    }
}

final class Overlay {
    let state = OverlayState()
    let panel: NSPanel
    init() {
        panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let material = NSVisualEffectView()
        material.material = .popover
        material.blendingMode = .behindWindow
        material.state = .active
        material.wantsLayer = true
        material.layer?.cornerRadius = 18
        material.layer?.masksToBounds = true
        let content = NSHostingView(rootView: SwitcherView(state: state))
        content.translatesAutoresizingMaskIntoConstraints = false
        material.addSubview(content)
        NSLayoutConstraint.activate([content.leadingAnchor.constraint(equalTo: material.leadingAnchor), content.trailingAnchor.constraint(equalTo: material.trailingAnchor), content.topAnchor.constraint(equalTo: material.topAnchor), content.bottomAnchor.constraint(equalTo: material.bottomAnchor)])
        panel.contentView = material
    }
    func show(session: SwitchSession, images: [Int: NSImage]) {
        state.message = nil
        state.tabs = session.tabs
        state.selected = session.index
        state.images = images
        present(width: min(CGFloat(session.tabs.count) * 180 + 24, 920), height: 190)
    }
    func present(width: CGFloat, height: CGFloat) {
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main!
        let area = screen.visibleFrame
        let w = min(width, area.width - 40)
        panel.setFrame(NSRect(x: area.midX - w / 2, y: area.midY - height / 2, width: w, height: height), display: true)
        panel.orderFrontRegardless()
    }
    func hide() { panel.orderOut(nil) }
}
