import AppKit

/// One captured clipboard entry: plain text, file URLs, or a TIFF image.
struct QueueItem: Codable, Identifiable, Equatable {
    enum Kind: String, Codable { case text, files, image }

    var id = UUID()
    var kind: Kind
    var text: String = ""
    var paths: [String] = []
    var imageData: Data?

    /// Short single-line description shown in the menu (first 40 characters).
    var preview: String {
        let raw: String
        switch kind {
        case .text: raw = text
        case .files: raw = paths.map { ($0 as NSString).lastPathComponent }.joined(separator: ", ")
        case .image: raw = "Image (\(ByteCountFormatter.string(fromByteCount: Int64(imageData?.count ?? 0), countStyle: .file)))"
        }
        let flat = raw.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces)
        return flat.count > 40 ? String(flat.prefix(40)) + "…" : flat
    }

    var symbol: String {
        switch kind {
        case .text: return "text.alignleft"
        case .files: return "doc"
        case .image: return "photo"
        }
    }

    /// Text used when the queue is pasted joined; images are excluded (nil).
    var joinableText: String? {
        switch kind {
        case .text: return text
        case .files: return paths.joined(separator: " ")
        case .image: return nil
        }
    }

    /// Writes this item to the given pasteboard, replacing its contents.
    func write(to pb: NSPasteboard) {
        pb.clearContents()
        switch kind {
        case .text: pb.setString(text, forType: .string)
        case .files: pb.writeObjects(paths.map { URL(fileURLWithPath: $0) as NSURL })
        case .image: if let imageData { pb.setData(imageData, forType: .tiff) }
        }
    }
}

/// Mirrors the queue to a small JSON file in Application Support so a crash does not lose it.
enum QueueStorage {
    private static let ioQueue = DispatchQueue(label: "com.turhe123.pastestackqueue.storage", qos: .utility)
    private static var fileURL: URL? {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let dir = base.appendingPathComponent("PasteStackQueue", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("queue.json")
    }

    static func load() -> [QueueItem] {
        guard let url = fileURL, let data = try? Data(contentsOf: url),
              let items = try? JSONDecoder().decode([QueueItem].self, from: data) else { return [] }
        return items
    }

    static func save(_ items: [QueueItem]) {
        guard let url = fileURL else { return }
        ioQueue.async {
            if let data = try? JSONEncoder().encode(items) {
                try? data.write(to: url, options: .atomic)
            }
        }
    }
}
