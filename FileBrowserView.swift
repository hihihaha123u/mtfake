import SwiftUI
import UniformTypeIdentifiers
import QuickLook

struct FileItem: Identifiable {
    let url: URL
    var id: String { url.path }
    var isDirectory: Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
    }
    var size: Int64 {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        return Int64(values?.fileSize ?? 0)
    }
}

struct FileBrowserView: View {
    @State private var currentURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    @State private var items: [FileItem] = []
    @State private var showImporter = false
    @State private var showNewFolder = false
    @State private var folderName = ""
    @State private var editingItem: FileItem?
    @State private var previewURL: URL?
    @State private var textEditorURL: URL?
    @State private var textContent = ""
    @State private var alertMessage: String?
    @State private var renameItem: FileItem?
    @State private var renameValue = ""

    private var isRoot: Bool {
        currentURL.standardizedFileURL == FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].standardizedFileURL
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Image(systemName: "folder.fill")
                            .foregroundStyle(.blue)
                        VStack(alignment: .leading) {
                            Text(currentURL.lastPathComponent.isEmpty ? "Tệp của tôi" : currentURL.lastPathComponent)
                                .font(.headline)
                            Text("\(items.count) mục")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if items.isEmpty {
                    ContentUnavailableView("Thư mục trống", systemImage: "folder", description: Text("Nhập tệp hoặc tạo thư mục mới để bắt đầu."))
                } else {
                    Section("Nội dung") {
                        ForEach(items) { item in
                            Button {
                                if item.isDirectory {
                                    currentURL = item.url
                                    reload()
                                } else {
                                    open(item)
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: item.isDirectory ? "folder.fill" : icon(for: item.url))
                                        .foregroundStyle(item.isDirectory ? .blue : .secondary)
                                        .font(.title3)
                                        .frame(width: 28)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(item.url.lastPathComponent)
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)
                                        Text(item.isDirectory ? "Thư mục" : "\(ByteCountFormatter.string(fromByteCount: item.size, countStyle: .file)) • \(item.url.pathExtension.uppercased())")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if item.isDirectory {
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) { remove(item) } label: {
                                    Label("Xóa", systemImage: "trash")
                                }
                                Button { renameItem = item; renameValue = item.url.lastPathComponent } label: {
                                    Label("Đổi tên", systemImage: "pencil")
                                }.tint(.orange)
                            }
                            .contextMenu {
                                Button { copy(item) } label: { Label("Sao chép", systemImage: "doc.on.doc") }
                                Button { renameItem = item; renameValue = item.url.lastPathComponent } label: { Label("Đổi tên", systemImage: "pencil") }
                                Button(role: .destructive) { remove(item) } label: { Label("Xóa", systemImage: "trash") }
                            }
                        }
                    }
                }
            }
            .navigationTitle("MT File Manager")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        if !isRoot {
                            currentURL.deleteLastPathComponent()
                            reload()
                        }
                    } label: { Image(systemName: "arrow.left") }
                    .disabled(isRoot)
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Menu {
                        Button { showImporter = true } label: { Label("Nhập tệp", systemImage: "square.and.arrow.down") }
                        Button { showNewFolder = true } label: { Label("Tạo thư mục", systemImage: "folder.badge.plus") }
                        Button { reload() } label: { Label("Làm mới", systemImage: "arrow.clockwise") }
                    } label: { Image(systemName: "plus") }
                }
            }
            .onAppear(perform: reload)
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
                do {
                    let urls = try result.get()
                    for url in urls {
                        let access = url.startAccessingSecurityScopedResource()
                        defer { if access { url.stopAccessingSecurityScopedResource() } }
                        let destination = uniqueDestination(for: url.lastPathComponent)
                        try FileManager.default.copyItem(at: url, to: destination)
                    }
                    reload()
                } catch { alertMessage = error.localizedDescription }
            }
            .alert("Tạo thư mục", isPresented: $showNewFolder) {
                TextField("Tên thư mục", text: $folderName)
                Button("Hủy", role: .cancel) { folderName = "" }
                Button("Tạo") {
                    let name = folderName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !name.isEmpty {
                        do {
                            try FileManager.default.createDirectory(at: currentURL.appendingPathComponent(name), withIntermediateDirectories: false)
                            folderName = ""
                            reload()
                        } catch { alertMessage = error.localizedDescription }
                    }
                }
            }
            .alert("Đổi tên", isPresented: Binding(get: { renameItem != nil }, set: { if !$0 { renameItem = nil } })) {
                TextField("Tên mới", text: $renameValue)
                Button("Hủy", role: .cancel) { renameItem = nil }
                Button("Lưu") {
                    if let item = renameItem {
                        do {
                            let target = item.url.deletingLastPathComponent().appendingPathComponent(renameValue)
                            try FileManager.default.moveItem(at: item.url, to: target)
                            renameItem = nil
                            reload()
                        } catch { alertMessage = error.localizedDescription }
                    }
                }
            }
            .alert("Thông báo", isPresented: Binding(get: { alertMessage != nil }, set: { if !$0 { alertMessage = nil } })) {
                Button("Đóng", role: .cancel) { alertMessage = nil }
            } message: { Text(alertMessage ?? "") }
            .sheet(item: Binding(get: { textEditorURL.map(IdentifiedURL.init) }, set: { textEditorURL = $0?.url })) { wrapped in
                TextFileEditor(url: wrapped.url) { reload() }
            }
            .sheet(item: Binding(get: { previewURL.map(IdentifiedURL.init) }, set: { previewURL = $0?.url })) { wrapped in
                QuickLookPreview(url: wrapped.url)
            }
        }
    }

    private func reload() {
        do {
            let urls = try FileManager.default.contentsOfDirectory(at: currentURL, includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey], options: [.skipsHiddenFiles])
            items = urls.map(FileItem.init).sorted {
                if $0.isDirectory != $1.isDirectory { return $0.isDirectory }
                return $0.url.lastPathComponent.localizedCaseInsensitiveCompare($1.url.lastPathComponent) == .orderedAscending
            }
        } catch { alertMessage = error.localizedDescription }
    }

    private func open(_ item: FileItem) {
        let ext = item.url.pathExtension.lowercased()
        if ["txt", "json", "xml", "html", "css", "js", "md", "csv", "log", "swift", "plist", "yaml", "yml"].contains(ext) {
            textEditorURL = item.url
        } else {
            previewURL = item.url
        }
    }

    private func icon(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "jpg", "jpeg", "png", "gif", "heic", "webp": return "photo"
        case "pdf": return "doc.richtext"
        case "zip", "rar", "7z": return " архивbox"
        case "txt", "md", "json", "xml", "swift", "html": return "doc.text"
        default: return "doc"
        }
    }

    private func uniqueDestination(for name: String) -> URL {
        var candidate = currentURL.appendingPathComponent(name)
        let ext = candidate.pathExtension
        let base = candidate.deletingPathExtension().lastPathComponent
        var index = 1
        while FileManager.default.fileExists(atPath: candidate.path) {
            let next = ext.isEmpty ? "\(base) copy \(index)" : "\(base) copy \(index).\(ext)"
            candidate = currentURL.appendingPathComponent(next)
            index += 1
        }
        return candidate
    }

    private func copy(_ item: FileItem) {
        do {
            let destination = uniqueDestination(for: item.url.lastPathComponent)
            try FileManager.default.copyItem(at: item.url, to: destination)
            reload()
        } catch { alertMessage = error.localizedDescription }
    }

    private func remove(_ item: FileItem) {
        do {
            try FileManager.default.removeItem(at: item.url)
            reload()
        } catch { alertMessage = error.localizedDescription }
    }
}

struct IdentifiedURL: Identifiable {
    let url: URL
    var id: String { url.path }
}

struct TextFileEditor: View {
    let url: URL
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var content = ""
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            Group {
                if errorText == nil {
                    TextEditor(text: $content)
                        .font(.system(.body, design: .monospaced))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } else {
                    ContentUnavailableView("Không thể mở tệp", systemImage: "exclamationmark.triangle", description: Text(errorText ?? ""))
                }
            }
            .navigationTitle(url.lastPathComponent)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Đóng") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Lưu") {
                        do {
                            try content.write(to: url, atomically: true, encoding: .utf8)
                            onSave()
                            dismiss()
                        } catch { errorText = error.localizedDescription }
                    }
                    .disabled(errorText != nil)
                }
            }
            .onAppear {
                do { content = try String(contentsOf: url, encoding: .utf8) }
                catch { errorText = "Tệp không phải văn bản UTF-8 hoặc không thể đọc." }
            }
        }
    }
}

struct QuickLookPreview: UIViewControllerRepresentable {
    let url: URL
    func makeCoordinator() -> Coordinator { Coordinator(url: url) }
    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }
    func updateUIViewController(_ controller: QLPreviewController, context: Context) {}
    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL
        init(url: URL) { self.url = url }
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            url as NSURL
        }
    }
}
