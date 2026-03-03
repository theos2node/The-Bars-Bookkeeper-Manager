import SwiftUI
import UniformTypeIdentifiers
import VisionKit
import UIKit

struct DashboardView: View {
    @State private var selectedTab: SidebarTab = .inventory
    @EnvironmentObject private var authService: AuthService
    @Environment(\.colorScheme) private var colorScheme

    private var theme: AppTheme { AppTheme(colorScheme: colorScheme) }

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            SidebarView(selectedTab: $selectedTab)

            Divider()
                .background(theme.borderSubtle)

            // Main content
            ZStack {
                theme.bgPrimary.ignoresSafeArea()

                Group {
                    switch selectedTab {
                    case .inventory:
                        InventoryView()
                    case .requests:
                        RequestsView()
                    case .imports:
                        ImportsView()
                    case .predictions:
                        PredictionsView()
                    case .orders:
                        OrdersView()
                    case .settings:
                        SettingsView()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task {
            do {
                try await authService.loadProfile()
            } catch {
                // Profile load failed — handled in AuthService
            }
        }
    }
}

private enum ImportQueueStatus: String {
    case uploading
    case queued
    case pending
    case processing
    case needs_review
    case completed
    case failed

    var isInFlight: Bool {
        switch self {
        case .queued, .pending, .processing:
            return true
        default:
            return false
        }
    }

    var displayLabel: String {
        rawValue.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

private struct ImportQueueItem: Identifiable, Equatable {
    let id: String
    let fileName: String
    let sizeBytes: Int
    var importRunId: String?
    var status: ImportQueueStatus
    var error: String?
    var fileClassification: String?
    var documentDate: String?
    var updatedAt: Date
}

struct ImportsView: View {
    @EnvironmentObject private var authService: AuthService
    @Environment(\.colorScheme) private var colorScheme

    @State private var queue: [ImportQueueItem] = Self.loadPersistedQueue()
    @State private var errorMessage: String?
    @State private var isFileImporterPresented = false
    @State private var isScannerPresented = false

    private static let queueStorageKey = "bbk_manager_import_queue_v1"
    private static let maxPersistedItems = 200
    private static let maxQueueAge: TimeInterval = 60 * 60 * 24 * 14

    private let pollTimer = Timer.publish(every: 2.2, on: .main, in: .common).autoconnect()
    private var theme: AppTheme { AppTheme(colorScheme: colorScheme) }
    private var canImport: Bool { authService.isManager }

    private var inFlightItems: [ImportQueueItem] {
        queue.filter { $0.importRunId != nil && $0.status.isInFlight }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(theme.borderSubtle)
            content
        }
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: [.item, .folder],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                Task { await queuePickedFiles(urls) }
            case .failure(let error):
                let message = error.localizedDescription
                if message.localizedCaseInsensitiveContains("couldn’t be opened")
                    || message.localizedCaseInsensitiveContains("couldn't be opened")
                {
                    errorMessage = "That file package can’t be opened directly on iPadOS. Zip it first, then upload the .zip."
                } else {
                    errorMessage = message
                }
            }
        }
        .sheet(isPresented: $isScannerPresented) {
            DocumentScannerView(
                onScan: { pages in
                    isScannerPresented = false
                    Task { await queueScannedDocument(pages: pages) }
                },
                onCancel: { isScannerPresented = false },
                onError: { error in
                    isScannerPresented = false
                    errorMessage = error.localizedDescription
                }
            )
        }
        .onReceive(pollTimer) { _ in
            guard !inFlightItems.isEmpty else { return }
            Task { await refreshInFlightRuns() }
        }
        .onAppear {
            Task { await refreshInFlightRuns() }
        }
        .onChange(of: queue) { _, newValue in
            Self.persistQueue(newValue)
        }
    }

    private var header: some View {
        HStack(spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Imports")
                    .font(AppTypography.titleMedium)
                    .foregroundColor(theme.textPrimary)

                Text(queue.isEmpty ? "Import invoices, CSVs, PDFs, and scans" : "\(queue.count) file(s) queued")
                    .font(AppTypography.caption)
                    .foregroundColor(theme.textSecondary)
            }

            Spacer()

            Button {
                isFileImporterPresented = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "doc.badge.plus")
                    Text("Choose Files")
                }
                .font(AppTypography.captionMedium)
                .foregroundColor(theme.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(theme.bgHover)
                .cornerRadius(AppRadius.sm)
            }
            .buttonStyle(.plain)
            .disabled(!canImport)
            .opacity(canImport ? 1 : 0.5)

            Button {
                isScannerPresented = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "camera.viewfinder")
                    Text("Scan Document")
                }
                .font(AppTypography.captionMedium)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(theme.textLink)
                .cornerRadius(AppRadius.sm)
            }
            .buttonStyle(.plain)
            .disabled(!canImport || !VNDocumentCameraViewController.isSupported)
            .opacity((canImport && VNDocumentCameraViewController.isSupported) ? 1 : 0.5)

            Button {
                Task { await refreshAllRuns() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14))
                    .foregroundColor(theme.textSecondary)
                    .padding(8)
                    .background(theme.bgHover)
                    .cornerRadius(AppRadius.sm)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.md)
    }

    private var content: some View {
        VStack(spacing: 0) {
            if let errorMessage = errorMessage {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(theme.error)
                    Text(errorMessage)
                        .font(AppTypography.caption)
                        .foregroundColor(theme.error)
                    Spacer()
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.vertical, AppSpacing.sm)
                .background(theme.errorSubtle)
            }

            if !canImport && queue.isEmpty {
                EmptyStateView(
                    icon: "lock.fill",
                    title: "Manager access required",
                    subtitle: "Imports are available for manager or owner roles."
                )
            } else if queue.isEmpty {
                EmptyStateView(
                    icon: "tray.and.arrow.down",
                    title: "No imports yet",
                    subtitle: "Choose files or scan a paper document to start a data import."
                )
            } else {
                HStack(spacing: 0) {
                    Text("File")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Status")
                        .frame(width: 120, alignment: .leading)
                    Text("Details")
                        .frame(width: 340, alignment: .leading)
                }
                .font(AppTypography.smallMedium)
                .foregroundColor(theme.textTertiary)
                .textCase(.uppercase)
                .tracking(0.3)
                .padding(.horizontal, AppSpacing.lg)
                .padding(.vertical, 10)
                .background(theme.bgSecondary)

                Divider().background(theme.borderSubtle)

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(queue) { item in
                            ImportQueueRow(item: item, theme: theme)
                            Divider().background(theme.borderSubtle).padding(.leading, AppSpacing.lg)
                        }
                    }
                }
            }
        }
    }

    @MainActor
    private func queuePickedFiles(_ urls: [URL]) async {
        for url in urls {
            await queueFile(url: url, clientSource: "file_picker")
        }
    }

    @MainActor
    private func queueFile(url: URL, clientSource: String) async {
        let didStartAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])
            if values.isDirectory == true {
                errorMessage = "Folder/package uploads aren’t supported directly on iPadOS. Zip it first, then upload the .zip."
                return
            }

            let data = try Data(contentsOf: url)
            let ext = url.pathExtension.lowercased()
            let mimeType = UTType(filenameExtension: ext)?.preferredMIMEType ?? "application/octet-stream"
            await enqueueFileData(
                data: data,
                fileName: url.lastPathComponent,
                mimeType: mimeType,
                clientSource: clientSource
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func queueScannedDocument(pages: [UIImage]) async {
        guard !pages.isEmpty else { return }

        if let pdfData = makePDFData(from: pages) {
            await enqueueFileData(
                data: pdfData,
                fileName: "scan-\(scanTimestamp()).pdf",
                mimeType: "application/pdf",
                clientSource: "document_scanner"
            )
            return
        }

        if let imageData = pages[0].jpegData(compressionQuality: 0.92) {
            await enqueueFileData(
                data: imageData,
                fileName: "scan-\(scanTimestamp()).jpg",
                mimeType: "image/jpeg",
                clientSource: "document_scanner"
            )
        }
    }

    @MainActor
    private func enqueueFileData(data: Data, fileName: String, mimeType: String, clientSource: String) async {
        guard let token = authService.token else { return }
        let localId = UUID().uuidString

        queue.insert(
            ImportQueueItem(
                id: localId,
                fileName: fileName,
                sizeBytes: data.count,
                importRunId: nil,
                status: .uploading,
                error: nil,
                fileClassification: nil,
                documentDate: nil,
                updatedAt: Date()
            ),
            at: 0
        )

        do {
            let queued = try await APIService.shared.uploadImportFileFromData(
                token: token,
                source: "auto",
                fileName: fileName,
                mimeType: mimeType,
                data: data,
                metadata: ["clientSource": clientSource]
            )
            updateQueueItem(localId) { item in
                var updated = item
                updated.importRunId = queued.importRunId
                updated.status = .queued
                updated.updatedAt = Date()
                return updated
            }
        } catch {
            authService.handleAuthError(error)
            updateQueueItem(localId) { item in
                var updated = item
                updated.status = .failed
                updated.error = error.localizedDescription
                updated.updatedAt = Date()
                return updated
            }
        }
    }

    @MainActor
    private func refreshInFlightRuns() async {
        for item in inFlightItems {
            await refreshRun(for: item)
        }
    }

    @MainActor
    private func refreshAllRuns() async {
        let itemsWithRuns = queue.filter { $0.importRunId != nil }
        for item in itemsWithRuns {
            await refreshRun(for: item)
        }
    }

    @MainActor
    private func refreshRun(for item: ImportQueueItem) async {
        guard let token = authService.token, let runId = item.importRunId else { return }

        do {
            let run = try await APIService.shared.fetchImportRun(token: token, id: runId)
            updateQueueItem(item.id) { current in
                var updated = current
                updated.status = ImportQueueStatus(rawValue: run.status) ?? .failed
                updated.error = run.error
                updated.fileClassification = run.file_classification
                updated.documentDate = normalizeDateString(run.document_date)
                updated.updatedAt = Date()
                return updated
            }
        } catch {
            authService.handleAuthError(error)
            updateQueueItem(item.id) { current in
                var updated = current
                updated.error = error.localizedDescription
                updated.updatedAt = Date()
                return updated
            }
        }
    }

    @MainActor
    private func updateQueueItem(_ id: String, updater: (ImportQueueItem) -> ImportQueueItem) {
        guard let idx = queue.firstIndex(where: { $0.id == id }) else { return }
        queue[idx] = updater(queue[idx])
    }

    private func normalizeDateString(_ value: String?) -> String? {
        guard let value = value, !value.isEmpty else { return nil }
        if value.count >= 10 {
            return String(value.prefix(10))
        }
        return value
    }

    private func scanTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }

    private func makePDFData(from pages: [UIImage]) -> Data? {
        guard !pages.isEmpty else { return nil }

        let pdfData = NSMutableData()
        UIGraphicsBeginPDFContextToData(pdfData, .zero, nil)
        defer { UIGraphicsEndPDFContext() }

        for page in pages {
            let size = page.size.width > 0 && page.size.height > 0
                ? page.size
                : CGSize(width: 1024, height: 1365)
            let rect = CGRect(origin: .zero, size: size)
            UIGraphicsBeginPDFPageWithInfo(rect, nil)
            page.draw(in: rect)
        }

        return pdfData as Data
    }

    private static func dedupeAndTrim(_ queue: [ImportQueueItem]) -> [ImportQueueItem] {
        let now = Date()
        var seenImportRunIds = Set<String>()
        var output: [ImportQueueItem] = []

        for item in queue.sorted(by: { $0.updatedAt > $1.updatedAt }) {
            if now.timeIntervalSince(item.updatedAt) > maxQueueAge {
                continue
            }
            if let runId = item.importRunId, !runId.isEmpty {
                if seenImportRunIds.contains(runId) {
                    continue
                }
                seenImportRunIds.insert(runId)
            }
            output.append(item)
            if output.count >= maxPersistedItems {
                break
            }
        }

        return output
    }

    private struct PersistedQueueItem: Codable {
        let id: String
        let fileName: String
        let sizeBytes: Int
        let importRunId: String?
        let status: String
        let error: String?
        let fileClassification: String?
        let documentDate: String?
        let updatedAt: Date
    }

    private static func loadPersistedQueue() -> [ImportQueueItem] {
        guard let data = UserDefaults.standard.data(forKey: queueStorageKey) else {
            return []
        }
        guard let decoded = try? JSONDecoder().decode([PersistedQueueItem].self, from: data) else {
            return []
        }
        let mapped: [ImportQueueItem] = decoded.compactMap { row in
            guard let status = ImportQueueStatus(rawValue: row.status) else { return nil }
            return ImportQueueItem(
                id: row.id,
                fileName: row.fileName,
                sizeBytes: row.sizeBytes,
                importRunId: row.importRunId,
                status: status,
                error: row.error,
                fileClassification: row.fileClassification,
                documentDate: row.documentDate,
                updatedAt: row.updatedAt
            )
        }
        return dedupeAndTrim(mapped)
    }

    private static func persistQueue(_ queue: [ImportQueueItem]) {
        let normalized = dedupeAndTrim(queue)
        let payload = normalized.map { item in
            PersistedQueueItem(
                id: item.id,
                fileName: item.fileName,
                sizeBytes: item.sizeBytes,
                importRunId: item.importRunId,
                status: item.status.rawValue,
                error: item.error,
                fileClassification: item.fileClassification,
                documentDate: item.documentDate,
                updatedAt: item.updatedAt
            )
        }
        guard let data = try? JSONEncoder().encode(payload) else { return }
        UserDefaults.standard.set(data, forKey: queueStorageKey)
    }
}

private struct ImportQueueRow: View {
    let item: ImportQueueItem
    let theme: AppTheme

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.fileName)
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(1)
                Text(formatBytes(item.sizeBytes))
                    .font(AppTypography.small)
                    .foregroundColor(theme.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            statusPill
                .frame(width: 120, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                if let classification = item.fileClassification {
                    Text("Type: \(classification)")
                        .font(AppTypography.small)
                        .foregroundColor(theme.textSecondary)
                }
                if let date = item.documentDate {
                    Text("Document date: \(date)")
                        .font(AppTypography.small)
                        .foregroundColor(theme.textSecondary)
                }
                if let runId = item.importRunId {
                    Text("Run: \(runId)")
                        .font(AppTypography.small)
                        .foregroundColor(theme.textTertiary)
                }
                if let error = item.error {
                    Text(error)
                        .font(AppTypography.small)
                        .foregroundColor(theme.error)
                        .lineLimit(2)
                }
            }
            .frame(width: 340, alignment: .leading)
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, 10)
    }

    private var statusPill: some View {
        Text(item.status.displayLabel)
            .font(AppTypography.smallMedium)
            .foregroundColor(statusForeground)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(statusBackground)
            .cornerRadius(AppRadius.xs)
    }

    private var statusForeground: Color {
        switch item.status {
        case .completed: return theme.success
        case .needs_review: return theme.warning
        case .failed: return theme.error
        case .uploading, .queued, .pending, .processing: return theme.textSecondary
        }
    }

    private var statusBackground: Color {
        switch item.status {
        case .completed: return theme.successSubtle
        case .needs_review: return theme.warningSubtle
        case .failed: return theme.errorSubtle
        case .uploading, .queued, .pending, .processing: return theme.bgHover
        }
    }

    private func formatBytes(_ bytes: Int) -> String {
        if bytes <= 0 { return "0 B" }
        let units = ["B", "KB", "MB", "GB"]
        var value = Double(bytes)
        var index = 0
        while value >= 1024 && index < units.count - 1 {
            value /= 1024
            index += 1
        }
        return index == 0 ? "\(Int(value)) \(units[index])" : String(format: "%.1f %@", value, units[index])
    }
}

private struct DocumentScannerView: UIViewControllerRepresentable {
    let onScan: ([UIImage]) -> Void
    let onCancel: () -> Void
    let onError: (Error) -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        private let parent: DocumentScannerView

        init(parent: DocumentScannerView) {
            self.parent = parent
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.onCancel()
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            parent.onError(error)
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            var pages: [UIImage] = []
            for index in 0..<scan.pageCount {
                pages.append(scan.imageOfPage(at: index))
            }
            parent.onScan(pages)
        }
    }
}
