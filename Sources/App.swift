import SwiftUI

/// App entry point: a menu-bar-only app with a queue window and a Settings scene.
@main
struct PasteStackQueueApp: App {
    @StateObject private var controller = QueueController.shared

    var body: some Scene {
        MenuBarExtra {
            MenuView()
                .environmentObject(controller)
        } label: {
            MenuBarLabel(queueMode: controller.queueMode, count: controller.items.count)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(controller)
        }
    }
}

/// Menu bar icon: hollow when queue mode is off, filled with a count badge when on.
struct MenuBarLabel: View {
    let queueMode: Bool
    let count: Int

    var body: some View {
        if queueMode {
            HStack(spacing: 2) {
                Image(systemName: "square.stack.3d.down.forward.fill")
                Text("\(count)").monospacedDigit()
            }
        } else {
            Image(systemName: "square.stack.3d.down.forward")
        }
    }
}

/// Opens the project's donation page.
enum Support {
    static func openDonate() {
        NSWorkspace.shared.open(URL(string: "https://ko-fi.com/leodavidai")!)
    }
}
