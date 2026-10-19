import AppKit
import SwiftUI

/// Shows a small, non-activating floating message near the top of the screen for two seconds.
final class HUD {
    static let shared = HUD()

    private var panel: NSPanel?
    private var generation = 0

    func show(_ message: String, symbol: String = "square.stack.3d.down.forward.fill") {
        guard UserDefaults.standard.object(forKey: "showHUD") as? Bool ?? true else { return }
        let panel = self.panel ?? makePanel()
        self.panel = panel

        let host = NSHostingView(rootView: HUDView(message: message, symbol: symbol))
        let size = host.fittingSize
        panel.contentView = host
        if let screen = NSScreen.main {
            let vf = screen.visibleFrame
            panel.setFrame(NSRect(x: vf.midX - size.width / 2, y: vf.maxY - size.height - 24,
                                  width: size.width, height: size.height), display: true)
        }
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { $0.duration = 0.15; panel.animator().alphaValue = 1 }

        generation += 1
        let current = generation
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self, self.generation == current else { return }
            NSAnimationContext.runAnimationGroup({ $0.duration = 0.3; panel.animator().alphaValue = 0 },
                                                 completionHandler: {
                if self.generation == current { panel.orderOut(nil) }
            })
        }
    }

    private func makePanel() -> NSPanel {
        let p = NSPanel(contentRect: .zero, styleMask: [.nonactivatingPanel, .borderless], backing: .buffered, defer: true)
        p.level = .statusBar
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.ignoresMouseEvents = true
        p.hidesOnDeactivate = false
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        return p
    }
}

/// The SwiftUI content of the HUD capsule.
private struct HUDView: View {
    let message: String
    let symbol: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
            Text(message).fontWeight(.semibold)
        }
        .font(.system(size: 14))
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.15)))
        .padding(6)
    }
}
