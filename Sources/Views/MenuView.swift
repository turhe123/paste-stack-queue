import SwiftUI

/// Contents of the menu bar window: queue mode toggle, reorderable queue list and commands.
struct MenuView: View {
    @EnvironmentObject private var controller: QueueController
    @Environment(\.openSettings) private var openSettings
    @AppStorage("order") private var order = "fifo"

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: Binding(get: { controller.queueMode }, set: { controller.setQueueMode($0) })) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Queue Mode").font(.headline)
                    Text("\(controller.items.count) item(s) · \(order == "lifo" ? "LIFO" : "FIFO")")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)

            Divider()

            if controller.items.isEmpty {
                Text("Queue is empty")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 60)
            } else {
                List {
                    ForEach(Array(controller.items.enumerated()), id: \.element.id) { index, item in
                        QueueRow(item: item, position: index + 1, isNext: index == controller.nextIndex) {
                            controller.remove(item)
                        }
                    }
                    .onMove { controller.move(from: $0, to: $1) }
                }
                .listStyle(.plain)
                .frame(height: min(CGFloat(controller.items.count) * 28 + 8, 280))
                Text("Drag to reorder").font(.caption2).foregroundStyle(.tertiary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 2) {
                MenuButton("Paste All Joined", symbol: "text.append") {
                    NSApp.hide(nil) // close the window so the previous app receives the paste
                    controller.pasteAllJoined()
                }
                    .disabled(controller.items.isEmpty)
                MenuButton("Clear Queue", symbol: "trash") { controller.clear() }
                    .disabled(controller.items.isEmpty)
                MenuButton("Settings…", symbol: "gearshape") {
                    NSApp.activate(ignoringOtherApps: true)
                    openSettings()
                }
                MenuButton("Support / Donate ❤️", symbol: "heart") { Support.openDonate() }
                MenuButton("Quit PasteStackQueue", symbol: "power") { NSApp.terminate(nil) }
            }
        }
        .padding(12)
        .frame(width: 320)
    }
}

/// A single queued item; the next item to paste is marked with an arrow.
private struct QueueRow: View {
    let item: QueueItem
    let position: Int
    let isNext: Bool
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Group {
                if isNext {
                    Image(systemName: "arrow.right").foregroundStyle(Color.accentColor)
                } else {
                    Text("\(position)").foregroundStyle(.secondary)
                }
            }
            .font(.caption.monospacedDigit())
            .frame(width: 22)
            Image(systemName: item.symbol).foregroundStyle(.secondary)
            Text(item.preview).lineLimit(1).fontWeight(isNext ? .semibold : .regular)
            Spacer()
            Button(action: onDelete) { Image(systemName: "xmark.circle.fill") }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .help("Remove from queue")
        }
        .contextMenu { Button("Delete", role: .destructive, action: onDelete) }
    }
}

/// A full-width, menu-like button row.
private struct MenuButton: View {
    let title: String
    let symbol: String
    let action: () -> Void

    init(_ title: String, symbol: String, action: @escaping () -> Void) {
        self.title = title
        self.symbol = symbol
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .padding(.vertical, 3)
    }
}
