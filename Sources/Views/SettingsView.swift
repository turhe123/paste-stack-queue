import SwiftUI
import ServiceManagement
import ApplicationServices

/// Settings window: hotkeys, paste order, join delimiter, behaviours and launch at login.
struct SettingsView: View {
    @ObservedObject private var hotKeys = HotKeyManager.shared
    @AppStorage("order") private var order = "fifo"
    @AppStorage("delimiter") private var delimiter = "newline"
    @AppStorage("autoAdvance") private var autoAdvance = false
    @AppStorage("showHUD") private var showHUD = true
    @AppStorage("restoreClipboard") private var restoreClipboard = true
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?
    @State private var axTrusted = AXIsProcessTrusted()

    var body: some View {
        Form {
            Section("Hotkeys") {
                HotKeyRecorder(title: "Toggle queue mode", name: "toggleHotKey", fallback: .defaultToggle,
                               unavailable: hotKeys.isUnavailable(.toggle))
                HotKeyRecorder(title: "Paste next item", name: "pasteHotKey", fallback: .defaultPaste,
                               unavailable: hotKeys.isUnavailable(.pasteNext))
            }
            Section("Pasting") {
                Picker("Order", selection: $order) {
                    Text("First in, first out (FIFO)").tag("fifo")
                    Text("Last in, first out (LIFO)").tag("lifo")
                }
                Picker("Join delimiter", selection: $delimiter) {
                    Text("Newline").tag("newline")
                    Text("Comma").tag("comma")
                    Text("Tab").tag("tab")
                    Text("Space").tag("space")
                    Text("Semicolon").tag("semicolon")
                }
                Toggle("Auto-advance with Tab after each paste", isOn: $autoAdvance)
                Toggle("Restore original clipboard when the queue is empty", isOn: $restoreClipboard)
            }
            Section("General") {
                Toggle("Show HUD after copy and paste", isOn: $showHUD)
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in setLaunchAtLogin(enabled) }
                if let loginError {
                    Text(loginError).font(.caption).foregroundStyle(.red)
                }
                HStack {
                    Label(axTrusted ? "Accessibility access granted" : "Accessibility access needed for auto-paste",
                          systemImage: axTrusted ? "checkmark.shield" : "exclamationmark.shield")
                        .foregroundStyle(axTrusted ? Color.green : Color.orange)
                    Spacer()
                    if !axTrusted {
                        Button("Open Settings") {
                            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
                            axTrusted = AXIsProcessTrustedWithOptions(options)
                        }
                    }
                }
            }
            Section {
                HStack {
                    Text("PasteStackQueue is free and open source.").foregroundStyle(.secondary)
                    Spacer()
                    Button("Support / Donate ❤️") { Support.openDonate() }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            axTrusted = AXIsProcessTrusted()
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginError = nil
        } catch {
            loginError = "Could not update login item: \(error.localizedDescription)"
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}

/// Click-to-record control for one global hotkey, with an inline warning if it can't be registered.
private struct HotKeyRecorder: View {
    let title: String
    let name: String
    let fallback: HotKey
    let unavailable: Bool

    @State private var key: HotKey?
    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Button(recording ? "Type shortcut…" : (key ?? HotKey.load(name, fallback: fallback)).display) {
                    recording ? stop() : start()
                }
                .frame(minWidth: 110)
                Button("Reset") { apply(fallback) }.buttonStyle(.borderless)
            }
            if unavailable {
                Label("This shortcut is unavailable (used by another app). Choose a different one.",
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.caption).foregroundStyle(.orange)
            }
        }
        .onDisappear(perform: stop)
    }

    private func start() {
        recording = true
        HotKeyManager.shared.unregisterAll()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { stop(); return nil } // Escape cancels
            let mods = HotKey.carbonModifiers(from: event.modifierFlags)
            guard mods != 0 else { NSSound.beep(); return nil } // require at least one modifier
            apply(HotKey(keyCode: UInt32(event.keyCode), modifiers: mods))
            return nil
        }
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        if recording { HotKeyManager.shared.registerAll() }
        recording = false
    }

    private func apply(_ hotKey: HotKey) {
        hotKey.save(name)
        key = hotKey
        stop()
        HotKeyManager.shared.registerAll()
    }
}
