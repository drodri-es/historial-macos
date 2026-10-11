import AppKit
import Carbon
import SwiftUI
import UniformTypeIdentifiers

struct HotkeyPreference: Codable, Equatable, Sendable {
    var keyCode: UInt32
    var modifiers: UInt32

    static let `default` = HotkeyPreference(keyCode: 9, modifiers: UInt32(optionKey))
    static let standard = HotkeyPreference.default

    @MainActor var displayText: String {
        var parts: [String] = []
        if modifiers & UInt32(controlKey) != 0 { parts.append("⌃") }
        if modifiers & UInt32(optionKey) != 0 { parts.append("⌥") }
        if modifiers & UInt32(shiftKey) != 0 { parts.append("⇧") }
        if modifiers & UInt32(cmdKey) != 0 { parts.append("⌘") }
        let keys: [UInt32: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            31: "O", 32: "U", 34: "I", 35: "P", 37: "L", 38: "J", 40: "K",
            45: "N", 46: "M", 49: LocalizationStore.shared.text("hotkey.space")
        ]
        return parts.joined() + (keys[keyCode] ?? LocalizationStore.shared.text("hotkey.key", keyCode))
    }
}

struct HistoryPanel: View {
    @ObservedObject private var language = LocalizationStore.shared
    @ObservedObject var store: HistoryStore
    let onSelect: (ClipEntry) -> Void
    let hotkey: HotkeyPreference
    let onHotkeyChange: (HotkeyPreference) -> Void
    let onOpenSettings: () -> Void

    @State private var query = ""
    @State private var selectedIndex = 0
    @State private var confirmClear = false

    private var filteredEntries: [ClipEntry] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return store.entries }
        return store.entries.filter { entry in
            let typeName: String
            switch entry.kind {
            case .text: typeName = language.text("kind.text")
            case .image: typeName = language.text("kind.image")
            case .files: typeName = language.text("kind.file")
            }
            return entry.previewText.localizedCaseInsensitiveContains(trimmed)
                || entry.filePaths.contains { $0.localizedCaseInsensitiveContains(trimmed) }
                || typeName.localizedCaseInsensitiveContains(trimmed)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            searchField
            if let message = store.statusMessageKey {
                Label(language.text(message), systemImage: "exclamationmark.circle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 8)
            }
            if filteredEntries.isEmpty {
                emptyState
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 3) {
                            ForEach(filteredEntries.indices, id: \.self) { index in
                                let entry = filteredEntries[index]
                                Button {
                                    onSelect(entry)
                                } label: {
                                    EntryRow(entry: entry, selected: index == selectedIndex)
                                }
                                .buttonStyle(.plain)
                                .id(entry.id)
                            }
                        }
                        .padding(8)
                    }
                    .onChange(of: selectedIndex) { _, newIndex in
                        guard filteredEntries.indices.contains(newIndex) else { return }
                        withAnimation(.easeOut(duration: 0.12)) {
                            proxy.scrollTo(filteredEntries[newIndex].id, anchor: .center)
                        }
                    }
                }
            }
            Divider()
            footer
        }
        .frame(width: 410, height: 510)
        .background(Color(nsColor: .windowBackgroundColor))
        .environment(\.locale, Locale(identifier: language.languageCode))
        .onChange(of: query) { _, _ in selectedIndex = 0 }
        .onChange(of: store.entries.count) { _, _ in
            selectedIndex = min(selectedIndex, max(0, filteredEntries.count - 1))
        }
        .confirmationDialog(language.text("clear.title"), isPresented: $confirmClear) {
            Button(language.text("clear.confirm"), role: .destructive) { store.clearHistory() }
            Button(language.text("clear.cancel"), role: .cancel) { }
        } message: {
            Text(verbatim: language.text("clear.message"))
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.on.clipboard.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.tint)
            Text(verbatim: language.text("panel.title"))
                .font(.headline)
            Spacer()
            Text("\(store.entries.count)")
                .foregroundStyle(.secondary)
                .font(.caption.monospacedDigit())
            Button {
                store.isPaused.toggle()
            } label: {
                Label(store.isPaused ? language.text("panel.resume") : language.text("panel.pause"),
                      systemImage: store.isPaused ? "play.fill" : "pause.fill")
            }
            .labelStyle(.iconOnly)
            .help(store.isPaused ? language.text("panel.resume") : language.text("panel.pause"))
            Button(action: onOpenSettings) {
                Image(systemName: "gearshape")
            }
            .help(language.text("panel.settings"))
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var searchField: some View {
        HistorySearchField(text: $query, placeholder: language.text("search.placeholder"), onUp: {
            selectedIndex = max(0, selectedIndex - 1)
        }, onDown: {
            selectedIndex = min(max(0, filteredEntries.count - 1), selectedIndex + 1)
        }, onSubmit: {
            if filteredEntries.indices.contains(selectedIndex) {
                onSelect(filteredEntries[selectedIndex])
            }
        })
        .frame(height: 28)
        .accessibilityLabel(language.text("search.accessibility"))
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: query.isEmpty ? "doc.on.clipboard" : "magnifyingglass")
                .font(.system(size: 29))
                .foregroundStyle(.tertiary)
            Text(verbatim: query.isEmpty ? language.text("empty.noCopies") : language.text("empty.noResults"))
                .font(.headline)
            Text(verbatim: query.isEmpty ? language.text("empty.copyHint") : language.text("empty.searchHint"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if query.isEmpty {
                Text(verbatim: language.text("empty.permissionHint"))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 45)
                    .padding(.top, 7)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            if store.isPaused {
                Label(language.text("footer.paused"), systemImage: "pause.circle.fill")
                    .foregroundStyle(.orange)
            } else {
                Text(verbatim: language.text("footer.keyboard"))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(language.text("footer.clearAll")) { confirmClear = true }
                .disabled(store.entries.isEmpty)
            Button(language.text("footer.quit")) { NSApp.terminate(nil) }
        }
        .font(.caption)
        .buttonStyle(.borderless)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

private struct EntryRow: View {
    @ObservedObject private var language = LocalizationStore.shared
    let entry: ClipEntry
    let selected: Bool

    var body: some View {
        HStack(spacing: 11) {
            preview
                .frame(width: 39, height: 39)
                .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 7))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 6) {
                    Text(kindName)
                    Text("·")
                    Text(entry.createdAt, style: .relative)
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(selected ? Color.accentColor.opacity(0.14) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 9))
        .contentShape(Rectangle())
        .accessibilityLabel("\(kindName): \(title)")
    }

    private var title: String {
        switch entry.kind {
        case .text: return entry.previewText.replacingOccurrences(of: "\n", with: " ")
        case .image: return language.text("kind.image")
        case .files:
            let names = entry.filePaths.map { URL(fileURLWithPath: $0).lastPathComponent }
            return names.joined(separator: ", ")
        }
    }

    private var kindName: String {
        switch entry.kind {
        case .text: return language.text("kind.text")
        case .image: return language.text("kind.image")
        case .files: return entry.filePaths.count == 1 ? language.text("kind.file") : language.text("kind.files", entry.filePaths.count)
        }
    }

    @ViewBuilder
    private var preview: some View {
        switch entry.kind {
        case .text:
            Image(systemName: "text.alignleft")
                .font(.system(size: 19))
                .foregroundStyle(.secondary)
        case .image:
            if let data = entry.imageData, let image = NSImage(data: data) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 39, height: 39)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 7))
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 19))
                    .foregroundStyle(.secondary)
            }
        case .files:
            if let path = entry.filePaths.first {
                Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                    .resizable()
                    .scaledToFit()
                    .padding(5)
            } else {
                Image(systemName: "doc")
                    .font(.system(size: 19))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// The search field owns keyboard navigation so its text editor cannot consume
/// the arrow and Return keys before the history list sees them.
private struct HistorySearchField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let onUp: () -> Void
    let onDown: () -> Void
    let onSubmit: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> SearchField {
        let field = SearchField()
        field.placeholderString = placeholder
        field.delegate = context.coordinator
        field.onUp = onUp
        field.onDown = onDown
        field.onSubmit = onSubmit
        return field
    }

    func updateNSView(_ field: SearchField, context: Context) {
        context.coordinator.parent = self
        if field.stringValue != text { field.stringValue = text }
        if field.placeholderString != placeholder { field.placeholderString = placeholder }
        field.onUp = onUp
        field.onDown = onDown
        field.onSubmit = onSubmit
    }

    final class Coordinator: NSObject, NSSearchFieldDelegate {
        var parent: HistorySearchField

        init(_ parent: HistorySearchField) { self.parent = parent }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSSearchField else { return }
            parent.text = field.stringValue
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            guard let field = control as? SearchField else { return false }
            switch commandSelector {
            case #selector(NSTextView.moveUp(_:)):
                field.onUp?()
            case #selector(NSTextView.moveDown(_:)):
                field.onDown?()
            case #selector(NSTextView.insertNewline(_:)),
                 #selector(NSTextView.insertNewlineIgnoringFieldEditor(_:)):
                field.onSubmit?()
            default:
                return false
            }
            return true
        }
    }

    final class SearchField: NSSearchField {
        var onUp: (() -> Void)?
        var onDown: (() -> Void)?
        var onSubmit: (() -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            window?.makeFirstResponder(self)
        }

        override func keyDown(with event: NSEvent) {
            if !event.modifierFlags.intersection([.command, .control, .option]).isEmpty {
                super.keyDown(with: event)
                return
            }
            switch event.keyCode {
            case 126: onUp?()
            case 125: onDown?()
            case 36, 76: onSubmit?()
            default: super.keyDown(with: event)
            }
        }
    }
}

struct SettingsPanel: View {
    @ObservedObject private var language = LocalizationStore.shared
    @ObservedObject var store: HistoryStore
    let hotkey: HotkeyPreference
    let onHotkeyChange: (HotkeyPreference) -> Void

    @State private var isRecording = false
    @State private var bundleIDInput = ""
    @State private var confirmClear = false

    var body: some View {
        Form {
            Section(language.text("settings.howTo")) {
                Text(verbatim: language.text("settings.howToInstructions", hotkey.displayText))
                Text(verbatim: language.text("settings.howToPermissions"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section(language.text("settings.language")) {
                Picker(language.text("settings.languagePicker"), selection: $language.selection) {
                    Text(verbatim: language.text("settings.languageSystem")).tag(AppLanguage.system)
                    Text(verbatim: language.text("settings.languageEnglish")).tag(AppLanguage.english)
                    Text(verbatim: language.text("settings.languageSpanish")).tag(AppLanguage.spanish)
                }
            }

            Section(language.text("settings.shortcut")) {
                HStack {
                    Text(verbatim: language.text("settings.showHistory"))
                    Spacer()
                    if isRecording {
                        ShortcutCaptureView { preference in
                            isRecording = false
                            onHotkeyChange(preference)
                        }
                        .frame(width: 1, height: 1)
                        Text(verbatim: language.text("settings.pressShortcut"))
                            .foregroundStyle(.secondary)
                        Button(language.text("clear.cancel")) { isRecording = false }
                    } else {
                        Text(hotkey.displayText)
                            .font(.system(.body, design: .monospaced))
                        Button(language.text("settings.change")) { isRecording = true }
                    }
                }
                Text(verbatim: language.text("settings.shortcutHint"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(language.text("settings.history")) {
                Stepper(language.text("settings.maxEntries", store.maxItems), value: $store.maxItems, in: 10...1000, step: 10)
                Picker(language.text("settings.expiry"), selection: $store.expiryDays) {
                    Text(verbatim: language.text("settings.never")).tag(0)
                    Text(verbatim: language.text("settings.oneDay")).tag(1)
                    Text(verbatim: language.text("settings.sevenDays")).tag(7)
                    Text(verbatim: language.text("settings.thirtyDays")).tag(30)
                    Text(verbatim: language.text("settings.ninetyDays")).tag(90)
                }
                Toggle(language.text("panel.pause"), isOn: $store.isPaused)
            }

            Section(language.text("settings.excludedApps")) {
                Text(verbatim: language.text("settings.exclusionHint"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    TextField(language.text("settings.bundlePlaceholder"), text: $bundleIDInput)
                        .onSubmit(addBundleID)
                    Button(language.text("settings.add")) { addBundleID() }
                        .disabled(bundleIDInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Button(language.text("settings.chooseApp")) { chooseApplication() }
                }
                ForEach(store.excludedBundleIDs, id: \.self) { bundleID in
                    HStack {
                        Text(bundleID)
                            .textSelection(.enabled)
                        Spacer()
                        Button {
                            store.excludedBundleIDs.removeAll { $0 == bundleID }
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .help(language.text("settings.removeExclusion"))
                    }
                }
            }

            Section(language.text("settings.localData")) {
                HStack {
                    Text(verbatim: language.text("settings.savedCount", store.entries.count))
                    Spacer()
                    Button(language.text("settings.clearHistory")) { confirmClear = true }
                        .disabled(store.entries.isEmpty)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 530)
        .environment(\.locale, Locale(identifier: language.languageCode))
        .confirmationDialog(language.text("clear.title"), isPresented: $confirmClear) {
            Button(language.text("clear.confirm"), role: .destructive) { store.clearHistory() }
            Button(language.text("clear.cancel"), role: .cancel) { }
        } message: {
            Text(verbatim: language.text("clear.message"))
        }
    }

    private func addBundleID() {
        let id = bundleIDInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty, !store.excludedBundleIDs.contains(id) else { return }
        store.excludedBundleIDs.append(id)
        bundleIDInput = ""
    }

    private func chooseApplication() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsOtherFileTypes = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = language.text("openPanel.exclude")
        guard panel.runModal() == .OK,
              let url = panel.url,
              let id = Bundle(url: url)?.bundleIdentifier,
              !store.excludedBundleIDs.contains(id) else { return }
        store.excludedBundleIDs.append(id)
    }
}

private struct ShortcutCaptureView: NSViewRepresentable {
    let onCapture: (HotkeyPreference) -> Void

    func makeNSView(context: Context) -> CaptureNSView {
        let view = CaptureNSView()
        view.onCapture = onCapture
        return view
    }

    func updateNSView(_ view: CaptureNSView, context: Context) {
        view.onCapture = onCapture
    }

    final class CaptureNSView: NSView {
        var onCapture: ((HotkeyPreference) -> Void)?
        override var acceptsFirstResponder: Bool { true }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            window?.makeFirstResponder(self)
        }

        override func keyDown(with event: NSEvent) {
            let flags = event.modifierFlags
            var modifiers: UInt32 = 0
            if flags.contains(.command) { modifiers |= UInt32(cmdKey) }
            if flags.contains(.option) { modifiers |= UInt32(optionKey) }
            if flags.contains(.control) { modifiers |= UInt32(controlKey) }
            if flags.contains(.shift) { modifiers |= UInt32(shiftKey) }
            guard modifiers & (UInt32(cmdKey) | UInt32(optionKey) | UInt32(controlKey)) != 0,
                  event.keyCode != 53 else {
                NSSound.beep()
                return
            }
            onCapture?(HotkeyPreference(keyCode: UInt32(event.keyCode), modifiers: modifiers))
        }
    }
}
