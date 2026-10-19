import AppKit
import Carbon

/// A key code plus Carbon modifier mask, persisted in UserDefaults.
struct HotKey: Equatable {
    var keyCode: UInt32
    var modifiers: UInt32

    static let defaultToggle = HotKey(keyCode: UInt32(kVK_ANSI_C), modifiers: UInt32(controlKey | optionKey))
    static let defaultPaste = HotKey(keyCode: UInt32(kVK_ANSI_V), modifiers: UInt32(controlKey | optionKey))

    static func load(_ name: String, fallback: HotKey) -> HotKey {
        let d = UserDefaults.standard
        guard d.object(forKey: name + ".code") != nil else { return fallback }
        return HotKey(keyCode: UInt32(d.integer(forKey: name + ".code")), modifiers: UInt32(d.integer(forKey: name + ".mods")))
    }

    func save(_ name: String) {
        UserDefaults.standard.set(Int(keyCode), forKey: name + ".code")
        UserDefaults.standard.set(Int(modifiers), forKey: name + ".mods")
    }

    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var m = 0
        if flags.contains(.command) { m |= cmdKey }
        if flags.contains(.option) { m |= optionKey }
        if flags.contains(.control) { m |= controlKey }
        if flags.contains(.shift) { m |= shiftKey }
        return UInt32(m)
    }

    /// Human-readable form such as "⌃⌥V".
    var display: String {
        var s = ""
        if modifiers & UInt32(controlKey) != 0 { s += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { s += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { s += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { s += "⌘" }
        return s + (HotKey.keyNames[Int(keyCode)] ?? "Key \(keyCode)")
    }

    private static let keyNames: [Int: String] = {
        var names: [Int: String] = [
            kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Escape: "⎋", kVK_Delete: "⌫",
            kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
        ]
        let letters: [(Int, String)] = [
            (kVK_ANSI_A, "A"), (kVK_ANSI_B, "B"), (kVK_ANSI_C, "C"), (kVK_ANSI_D, "D"), (kVK_ANSI_E, "E"),
            (kVK_ANSI_F, "F"), (kVK_ANSI_G, "G"), (kVK_ANSI_H, "H"), (kVK_ANSI_I, "I"), (kVK_ANSI_J, "J"),
            (kVK_ANSI_K, "K"), (kVK_ANSI_L, "L"), (kVK_ANSI_M, "M"), (kVK_ANSI_N, "N"), (kVK_ANSI_O, "O"),
            (kVK_ANSI_P, "P"), (kVK_ANSI_Q, "Q"), (kVK_ANSI_R, "R"), (kVK_ANSI_S, "S"), (kVK_ANSI_T, "T"),
            (kVK_ANSI_U, "U"), (kVK_ANSI_V, "V"), (kVK_ANSI_W, "W"), (kVK_ANSI_X, "X"), (kVK_ANSI_Y, "Y"),
            (kVK_ANSI_Z, "Z"), (kVK_ANSI_0, "0"), (kVK_ANSI_1, "1"), (kVK_ANSI_2, "2"), (kVK_ANSI_3, "3"),
            (kVK_ANSI_4, "4"), (kVK_ANSI_5, "5"), (kVK_ANSI_6, "6"), (kVK_ANSI_7, "7"), (kVK_ANSI_8, "8"),
            (kVK_ANSI_9, "9"), (kVK_F1, "F1"), (kVK_F2, "F2"), (kVK_F3, "F3"), (kVK_F4, "F4"), (kVK_F5, "F5"),
            (kVK_F6, "F6"), (kVK_F7, "F7"), (kVK_F8, "F8"), (kVK_F9, "F9"), (kVK_F10, "F10"),
            (kVK_F11, "F11"), (kVK_F12, "F12"),
        ]
        for (code, name) in letters { names[code] = name }
        return names
    }()
}

/// Carbon C callback; forwards hotkey presses to the shared manager on the main thread.
private func hotKeyEventHandler(_ next: EventHandlerCallRef?, _ event: EventRef?, _ userData: UnsafeMutableRawPointer?) -> OSStatus {
    guard let event else { return OSStatus(eventNotHandledErr) }
    var hkID = EventHotKeyID()
    let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                   nil, MemoryLayout<EventHotKeyID>.size, nil, &hkID)
    guard status == noErr else { return status }
    DispatchQueue.main.async { HotKeyManager.shared.fire(id: hkID.id) }
    return noErr
}

/// Registers the two global Carbon hotkeys and reports ones that could not be registered.
final class HotKeyManager: ObservableObject {
    enum Action: UInt32 { case toggle = 1, pasteNext = 2 }

    static let shared = HotKeyManager()
    @Published private(set) var unavailable: Set<UInt32> = []
    var handler: ((Action) -> Void)?

    private var refs: [UInt32: EventHotKeyRef] = [:]
    private var installed = false
    private let signature: OSType = 0x50535155 // "PSQU"

    func registerAll() {
        register(.toggle, HotKey.load("toggleHotKey", fallback: .defaultToggle))
        register(.pasteNext, HotKey.load("pasteHotKey", fallback: .defaultPaste))
    }

    func unregisterAll() {
        for ref in refs.values { UnregisterEventHotKey(ref) }
        refs.removeAll()
    }

    func isUnavailable(_ action: Action) -> Bool { unavailable.contains(action.rawValue) }

    private func register(_ action: Action, _ key: HotKey) {
        installHandlerIfNeeded()
        if let old = refs.removeValue(forKey: action.rawValue) { UnregisterEventHotKey(old) }
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(key.keyCode, key.modifiers, EventHotKeyID(signature: signature, id: action.rawValue),
                                         GetApplicationEventTarget(), 0, &ref)
        if status == noErr, let ref {
            refs[action.rawValue] = ref
            unavailable.remove(action.rawValue)
        } else {
            unavailable.insert(action.rawValue)
        }
    }

    private func installHandlerIfNeeded() {
        guard !installed else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        installed = InstallEventHandler(GetApplicationEventTarget(), hotKeyEventHandler, 1, &spec, nil, nil) == noErr
    }

    fileprivate func fire(id: UInt32) {
        if let action = Action(rawValue: id) { handler?(action) }
    }
}
