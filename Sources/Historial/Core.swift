import AppKit
import Foundation

struct ClipEntry: Identifiable, Codable, Sendable {
    enum Kind: String, Codable, Sendable {
        case text
        case image
        case files
    }

    let id: UUID
    let kind: Kind
    let createdAt: Date
    let sourceBundleID: String?
    let text: String?
    let imageData: Data?
    let filePaths: [String]

    init(
        id: UUID = UUID(),
        kind: Kind,
        createdAt: Date = Date(),
        sourceBundleID: String? = nil,
        text: String? = nil,
        imageData: Data? = nil,
        filePaths: [String] = []
    ) {
        self.id = id
        self.kind = kind
        self.createdAt = createdAt
        self.sourceBundleID = sourceBundleID
        self.text = text
        self.imageData = imageData
        self.filePaths = filePaths
    }

    var previewText: String {
        switch kind {
        case .text:
            return text ?? ""
        case .image:
            return ""
        case .files:
            return filePaths.map { URL(fileURLWithPath: $0).lastPathComponent }.joined(separator: ", ")
        }
    }

    func hasSameContent(as other: ClipEntry) -> Bool {
        kind == other.kind && text == other.text && imageData == other.imageData && filePaths == other.filePaths
    }
}

@MainActor
final class HistoryStore: NSObject, ObservableObject {
    static let shared = HistoryStore()

    @Published private(set) var entries: [ClipEntry] = []
    @Published var isPaused = false {
        didSet { save() }
    }
    @Published var maxItems = 100 {
        didSet {
            if maxItems < 1 { maxItems = 1 }
            trimAndSave()
        }
    }
    /// Zero means entries never expire automatically.
    @Published var expiryDays = 30 {
        didSet {
            if expiryDays < 0 { expiryDays = 0 }
            trimAndSave()
        }
    }
    @Published var excludedBundleIDs: [String] = [] {
        didSet { save() }
    }
    @Published private(set) var statusMessageKey: String?

    private struct Snapshot: Codable, Sendable {
        var entries: [ClipEntry]
        var isPaused: Bool
        var maxItems: Int
        var expiryDays: Int
        var excludedBundleIDs: [String]
    }

    private let pasteboard = NSPasteboard.general
    private let saveQueue = DispatchQueue(label: "Historial.save", qos: .utility)
    private let storageURL: URL
    private var observedChangeCount: Int
    private var monitor: Timer?
    private var isLoading = false
    private var lastPrunedAt = Date()
    private var isObservingAppActivation = false
    private var lastFrontmostBundleID: String?
    private var activatedBundleIDsSinceLastCheck: Set<String> = []
    private var focusChangedSinceLastCheck = false
    private var unknownAppActivatedSinceLastCheck = false

    override init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        storageURL = support.appendingPathComponent("Historial", isDirectory: true)
            .appendingPathComponent("history.json", isDirectory: false)
        observedChangeCount = NSPasteboard.general.changeCount
        super.init()
        load()
        trimAndSave()
    }

    func startMonitoring() {
        guard monitor == nil else { return }
        // Record changes after launch without importing the user's preexisting clipboard.
        observedChangeCount = pasteboard.changeCount
        lastFrontmostBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        activatedBundleIDsSinceLastCheck.removeAll()
        focusChangedSinceLastCheck = false
        unknownAppActivatedSinceLastCheck = false
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appDidActivate(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        isObservingAppActivation = true
        monitor = Timer.scheduledTimer(
            timeInterval: 0.4,
            target: self,
            selector: #selector(checkPasteboard),
            userInfo: nil,
            repeats: true
        )
        monitor?.tolerance = 0.1
    }

    func stopMonitoring() {
        monitor?.invalidate()
        monitor = nil
        if isObservingAppActivation {
            NSWorkspace.shared.notificationCenter.removeObserver(
                self,
                name: NSWorkspace.didActivateApplicationNotification,
                object: nil
            )
            isObservingAppActivation = false
        }
    }

    func markOwnPasteboardChange() {
        observedChangeCount = pasteboard.changeCount
    }

    func clearHistory() {
        entries.removeAll()
        statusMessageKey = nil
        save()
    }

    @discardableResult
    func restore(_ entry: ClipEntry) -> Bool {
        guard entries.contains(where: { $0.id == entry.id }) else {
            statusMessageKey = "status.missingEntry"
            return false
        }
        statusMessageKey = nil

        if entry.kind == .files && (entry.filePaths.isEmpty ||
            !entry.filePaths.allSatisfy({ FileManager.default.fileExists(atPath: $0) })) {
            statusMessageKey = "status.missingFiles"
            return false
        }

        let restored: Bool
        pasteboard.clearContents()
        switch entry.kind {
        case .text:
            restored = entry.text.map { pasteboard.setString($0, forType: .string) } ?? false
        case .image:
            if let data = entry.imageData, let image = NSImage(data: data) {
                restored = pasteboard.writeObjects([image])
            } else {
                restored = false
            }
        case .files:
            restored = pasteboard.writeObjects(entry.filePaths.map { NSURL(fileURLWithPath: $0) })
        }
        markOwnPasteboardChange()
        if restored { statusMessageKey = nil }
        else { statusMessageKey = "status.restoreFailed" }
        return restored
    }

    @objc private func checkPasteboard() {
        if Date().timeIntervalSince(lastPrunedAt) > 60 {
            lastPrunedAt = Date()
            trimAndSave()
        }
        let count = pasteboard.changeCount
        let currentBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let possibleSources = activatedBundleIDsSinceLastCheck
            .union([lastFrontmostBundleID, currentBundleID].compactMap { $0 })
        let focusChanged = focusChangedSinceLastCheck || currentBundleID != lastFrontmostBundleID
        let sourceUnknown = unknownAppActivatedSinceLastCheck || currentBundleID == nil || lastFrontmostBundleID == nil
        lastFrontmostBundleID = currentBundleID
        activatedBundleIDsSinceLastCheck.removeAll()
        focusChangedSinceLastCheck = false
        unknownAppActivatedSinceLastCheck = false
        guard count != observedChangeCount else { return }
        observedChangeCount = count
        guard !isPaused else { return }

        if !excludedBundleIDs.isEmpty {
            let excluded = Set(excludedBundleIDs)
            // NSPasteboard does not expose the source application. If focus changed
            // while the board changed, attribution is uncertain, so drop the item.
            guard !focusChanged, !sourceUnknown,
                  possibleSources.isDisjoint(with: excluded) else { return }
        }
        guard let entry = captureCurrentPasteboard(sourceBundleID: currentBundleID) else {
            statusMessageKey = "status.captureFailed"
            return
        }

        // Re-copying an item makes it recent while avoiding duplicate rows.
        statusMessageKey = nil
        entries.removeAll { $0.hasSameContent(as: entry) }
        entries.insert(entry, at: 0)
        trimAndSave()
    }

    @objc private func appDidActivate(_ notification: Notification) {
        focusChangedSinceLastCheck = true
        if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
           let bundleID = app.bundleIdentifier {
            activatedBundleIDsSinceLastCheck.insert(bundleID)
        } else {
            unknownAppActivatedSinceLastCheck = true
        }
    }

    private func captureCurrentPasteboard(sourceBundleID: String?) -> ClipEntry? {
        if let objects = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [NSURL] {
            let paths = objects.compactMap { object -> String? in
                let url = object as URL
                return url.isFileURL ? url.path : nil
            }
            if !paths.isEmpty {
                return ClipEntry(kind: .files, sourceBundleID: sourceBundleID, filePaths: paths)
            }
        }

        if let imageData = pngDataFromPasteboard() {
            return ClipEntry(kind: .image, sourceBundleID: sourceBundleID, imageData: imageData)
        }

        if let copiedText = pasteboard.string(forType: .string) {
            return ClipEntry(kind: .text, sourceBundleID: sourceBundleID, text: copiedText)
        }
        return nil
    }

    private func pngDataFromPasteboard() -> Data? {
        if let png = pasteboard.data(forType: .png), NSImage(data: png) != nil {
            return png
        }
        guard let image = NSImage(pasteboard: pasteboard),
              let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }

    private func trimAndSave() {
        if expiryDays > 0 {
            let cutoff = Date().addingTimeInterval(-Double(expiryDays) * 86_400)
            entries.removeAll { $0.createdAt < cutoff }
        }
        if entries.count > maxItems { entries.removeLast(entries.count - maxItems) }
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: storageURL),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        isLoading = true
        entries = snapshot.entries
        isPaused = snapshot.isPaused
        maxItems = max(1, snapshot.maxItems)
        expiryDays = max(0, snapshot.expiryDays)
        excludedBundleIDs = snapshot.excludedBundleIDs
        isLoading = false
    }

    private func save() {
        guard !isLoading else { return }
        let snapshot = Snapshot(
            entries: entries,
            isPaused: isPaused,
            maxItems: maxItems,
            expiryDays: expiryDays,
            excludedBundleIDs: excludedBundleIDs
        )
        let url = storageURL
        saveQueue.async {
            do {
                try FileManager.default.createDirectory(
                    at: url.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                let data = try JSONEncoder().encode(snapshot)
                try data.write(to: url, options: .atomic)
            } catch {
                Task { @MainActor [weak self] in
                    self?.statusMessageKey = "status.saveFailed"
                }
            }
        }
    }
}
