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
                    case .inbox:
                        ConductorInboxView()
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
    var affectsInventory: Bool?
    var affectsForecast: Bool?
    var qualityGateStatus: String?
    var ingestStrategy: String?
    var evidenceScore: Double?
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
                affectsInventory: nil,
                affectsForecast: nil,
                qualityGateStatus: nil,
                ingestStrategy: nil,
                evidenceScore: nil,
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
                updated.affectsInventory = run.affects_inventory
                updated.affectsForecast = run.affects_forecast
                updated.qualityGateStatus = run.quality_gate_status
                updated.ingestStrategy = run.ingest_strategy
                updated.evidenceScore = run.evidence_score
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
        let affectsInventory: Bool?
        let affectsForecast: Bool?
        let qualityGateStatus: String?
        let ingestStrategy: String?
        let evidenceScore: Double?
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
                affectsInventory: row.affectsInventory,
                affectsForecast: row.affectsForecast,
                qualityGateStatus: row.qualityGateStatus,
                ingestStrategy: row.ingestStrategy,
                evidenceScore: row.evidenceScore,
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
                affectsInventory: item.affectsInventory,
                affectsForecast: item.affectsForecast,
                qualityGateStatus: item.qualityGateStatus,
                ingestStrategy: item.ingestStrategy,
                evidenceScore: item.evidenceScore,
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
                if let strategy = item.ingestStrategy {
                    Text("Ingest strategy: \(strategy)")
                        .font(AppTypography.small)
                        .foregroundColor(theme.textSecondary)
                }
                if let evidence = item.evidenceScore {
                    Text("Evidence score: \(String(format: "%.2f", evidence))")
                        .font(AppTypography.small)
                        .foregroundColor(theme.textSecondary)
                }
                if let gate = item.qualityGateStatus {
                    Text("Quality gate: \(gate)")
                        .font(AppTypography.small)
                        .foregroundColor(theme.textSecondary)
                }
                if let affectsInventory = item.affectsInventory {
                    Text("Affects inventory: \(affectsInventory ? "yes" : "no")")
                        .font(AppTypography.small)
                        .foregroundColor(theme.textSecondary)
                }
                if let affectsForecast = item.affectsForecast {
                    Text("Affects forecast: \(affectsForecast ? "yes" : "no")")
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

private enum ConductorCardFilter: String {
    case open = "open"
    case autoResolved = "auto_resolved"

    var label: String {
        switch self {
        case .open:
            return "Open"
        case .autoResolved:
            return "Auto-Resolved"
        }
    }
}

struct QualityGateBanner: View {
    let qualityGate: ConductorQualitySnapshot
    let theme: AppTheme
    var hideWhenPass: Bool = false

    private var status: String {
        qualityGate.status.lowercased()
    }

    private var foreground: Color {
        switch status {
        case "block": return theme.error
        case "warn": return theme.warning
        default: return theme.success
        }
    }

    private var background: Color {
        switch status {
        case "block": return theme.errorSubtle
        case "warn": return theme.warningSubtle
        default: return theme.successSubtle
        }
    }

    @ViewBuilder
    var body: some View {
        if !(hideWhenPass && status == "pass") {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("Quality Gate: \(qualityGate.status.uppercased())")
                    .font(AppTypography.captionMedium)
                    .foregroundColor(foreground)

                Text(
                    "Drift \(String(format: "%.4f", qualityGate.drift_ratio)) | Critical \(qualityGate.unresolved_critical) | High \(qualityGate.unresolved_high) | Medium \(qualityGate.unresolved_medium)"
                )
                .font(AppTypography.small)
                .foregroundColor(foreground)

                if !qualityGate.reasons.isEmpty {
                    Text(qualityGate.reasons.joined(separator: " • "))
                        .font(AppTypography.small)
                        .foregroundColor(foreground)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppSpacing.sm)
            .background(background)
            .cornerRadius(AppRadius.sm)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.sm)
                    .stroke(foreground.opacity(0.35), lineWidth: 1)
            )
        }
    }
}

struct ConductorInboxView: View {
    @EnvironmentObject private var authService: AuthService
    @Environment(\.colorScheme) private var colorScheme

    @State private var filter: ConductorCardFilter = .open
    @State private var cards: [ConductorCard] = []
    @State private var selectedCardId: String?
    @State private var actions: [ConductorCardAction] = []
    @State private var qualityGate: ConductorQualitySnapshot?
    @State private var isLoading = true
    @State private var isLoadingActions = false
    @State private var isMutating = false
    @State private var errorMessage: String?
    @State private var searchQuery = ""

    private var theme: AppTheme { AppTheme(colorScheme: colorScheme) }
    private var canManageInbox: Bool { authService.isManager }

    private var selectedCard: ConductorCard? {
        cards.first(where: { $0.id == selectedCardId })
    }

    private var filteredCards: [ConductorCard] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return cards }
        return cards.filter { card in
            card.title.lowercased().contains(query)
                || (card.summary?.lowercased().contains(query) ?? false)
                || card.card_type.lowercased().contains(query)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(theme.borderSubtle)

            if let qualityGate = qualityGate {
                QualityGateBanner(qualityGate: qualityGate, theme: theme, hideWhenPass: false)
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.top, AppSpacing.md)
            }

            if !canManageInbox {
                EmptyStateView(
                    icon: "lock.fill",
                    title: "Manager access required",
                    subtitle: "Conductor Inbox is available for manager or owner roles."
                )
            } else if isLoading {
                LoadingView(message: "Loading conductor inbox...")
            } else if let errorMessage = errorMessage {
                EmptyStateView(icon: "exclamationmark.triangle", title: "Error", subtitle: errorMessage)
            } else {
                content
            }
        }
        .task {
            await loadData()
        }
        .task(id: selectedCardId) {
            await loadActionsForSelection()
        }
        .onChange(of: filter) { _, _ in
            Task { await loadData() }
        }
    }

    private var header: some View {
        HStack(spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Conductor Inbox")
                    .font(AppTypography.titleMedium)
                    .foregroundColor(theme.textPrimary)
                Text("Open cards, auto-resolution feed, and replay controls")
                    .font(AppTypography.caption)
                    .foregroundColor(theme.textSecondary)
            }

            Spacer()

            HStack(spacing: AppSpacing.xs) {
                FilterPill(label: "Open", isActive: filter == .open, theme: theme) {
                    filter = .open
                }
                FilterPill(label: "Auto-Resolved", isActive: filter == .autoResolved, theme: theme) {
                    filter = .autoResolved
                }
            }

            SearchBar(text: $searchQuery, placeholder: "Search cards...")
                .frame(width: 240)

            Button {
                Task { await loadData() }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                    Text("Refresh")
                        .font(AppTypography.captionMedium)
                }
                .foregroundColor(theme.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(theme.bgHover)
                .cornerRadius(AppRadius.sm)
            }
            .buttonStyle(.plain)
            .disabled(isLoading || isMutating)
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.md)
    }

    private var content: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                HStack {
                    Text("\(filteredCards.count) card(s)")
                        .font(AppTypography.small)
                        .foregroundColor(theme.textTertiary)
                    Spacer()
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.vertical, AppSpacing.sm)
                .background(theme.bgSecondary)

                Divider().background(theme.borderSubtle)

                if filteredCards.isEmpty {
                    EmptyStateView(icon: "tray", title: "No cards", subtitle: "No conductor cards matched this filter.")
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredCards) { card in
                                ConductorCardRowView(
                                    card: card,
                                    isSelected: selectedCardId == card.id,
                                    theme: theme
                                )
                                .onTapGesture {
                                    selectedCardId = card.id
                                }
                                Divider().background(theme.borderSubtle).padding(.leading, AppSpacing.lg)
                            }
                        }
                    }
                }
            }
            .frame(width: 430)

            Divider().background(theme.borderSubtle)

            ConductorCardDetailPanel(
                card: selectedCard,
                actions: actions,
                theme: theme,
                isLoadingActions: isLoadingActions,
                isMutating: isMutating,
                onReplay: { await replaySelectedCard() },
                onResolve: { await updateSelectedCard(status: "resolved", resolution: "user_resolved") },
                onDismiss: { await updateSelectedCard(status: "dismissed", resolution: "user_dismissed") },
                onReopen: { await updateSelectedCard(status: "open", resolution: "reopened") }
            )
            .frame(maxWidth: .infinity)
        }
    }

    private func loadData() async {
        guard canManageInbox, let token = authService.token else { return }
        isLoading = true
        errorMessage = nil
        do {
            async let cardsTask = APIService.shared.fetchConductorCards(
                token: token,
                status: filter.rawValue,
                limit: 200
            )
            async let qualityTask = APIService.shared.fetchConductorQualityLatest(token: token)

            let fetchedCards = try await cardsTask
            let latestQuality = try await qualityTask
            cards = fetchedCards
            qualityGate = latestQuality

            if let selectedCardId, fetchedCards.contains(where: { $0.id == selectedCardId }) {
                self.selectedCardId = selectedCardId
            } else {
                self.selectedCardId = fetchedCards.first?.id
            }
        } catch {
            authService.handleAuthError(error)
            errorMessage = error.localizedDescription
            cards = []
            actions = []
            selectedCardId = nil
        }
        isLoading = false
    }

    private func loadActionsForSelection() async {
        guard canManageInbox, let token = authService.token, let selectedCardId else {
            actions = []
            return
        }
        isLoadingActions = true
        do {
            actions = try await APIService.shared.fetchConductorCardActions(token: token, cardId: selectedCardId)
        } catch {
            authService.handleAuthError(error)
            errorMessage = error.localizedDescription
            actions = []
        }
        isLoadingActions = false
    }

    private func updateSelectedCard(status: String, resolution: String) async {
        guard canManageInbox, let token = authService.token, let selectedCard else { return }
        isMutating = true
        do {
            _ = try await APIService.shared.updateConductorCard(
                token: token,
                cardId: selectedCard.id,
                status: status,
                resolution: resolution
            )
            await loadData()
            await loadActionsForSelection()
        } catch {
            authService.handleAuthError(error)
            errorMessage = error.localizedDescription
        }
        isMutating = false
    }

    private func replaySelectedCard() async {
        guard canManageInbox, let token = authService.token, let selectedCard else { return }
        isMutating = true
        do {
            _ = try await APIService.shared.replayConductorCard(token: token, cardId: selectedCard.id)
            await loadData()
            await loadActionsForSelection()
        } catch {
            authService.handleAuthError(error)
            errorMessage = error.localizedDescription
        }
        isMutating = false
    }
}

private struct ConductorCardRowView: View {
    let card: ConductorCard
    let isSelected: Bool
    let theme: AppTheme

    private var severityColor: Color {
        switch card.severity {
        case "critical":
            return theme.error
        case "high":
            return theme.warning
        case "medium":
            return theme.textLink
        default:
            return theme.textSecondary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack(spacing: AppSpacing.sm) {
                Text(card.title)
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(1)
                Spacer()
                Circle()
                    .fill(severityColor)
                    .frame(width: 8, height: 8)
            }

            Text("\(card.card_type) · \(card.severity) · \(card.status)")
                .font(AppTypography.small)
                .foregroundColor(theme.textTertiary)
                .lineLimit(1)

            if let summary = card.summary, !summary.isEmpty {
                Text(summary)
                    .font(AppTypography.small)
                    .foregroundColor(theme.textSecondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, 10)
        .background(isSelected ? theme.bgSecondary : Color.clear)
        .contentShape(Rectangle())
    }
}

private struct ConductorCardDetailPanel: View {
    let card: ConductorCard?
    let actions: [ConductorCardAction]
    let theme: AppTheme
    let isLoadingActions: Bool
    let isMutating: Bool
    let onReplay: () async -> Void
    let onResolve: () async -> Void
    let onDismiss: () async -> Void
    let onReopen: () async -> Void

    var body: some View {
        Group {
            if let card {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        Text(card.title)
                            .font(AppTypography.titleSmall)
                            .foregroundColor(theme.textPrimary)

                        Text("\(card.card_type) · \(card.severity) · confidence \(String(format: "%.2f", card.confidence))")
                            .font(AppTypography.caption)
                            .foregroundColor(theme.textSecondary)

                        if let summary = card.summary, !summary.isEmpty {
                            Text(summary)
                                .font(AppTypography.body)
                                .foregroundColor(theme.textSecondary)
                        }

                        actionButtons(card: card)

                        Divider().background(theme.borderSubtle)

                        Text("Card Detail")
                            .font(AppTypography.headline)
                            .foregroundColor(theme.textPrimary)
                        jsonBlock(card.detail.prettyPrinted)

                        Divider().background(theme.borderSubtle)

                        Text("Action Timeline")
                            .font(AppTypography.headline)
                            .foregroundColor(theme.textPrimary)

                        if isLoadingActions {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else if actions.isEmpty {
                            Text("No actions logged.")
                                .font(AppTypography.body)
                                .foregroundColor(theme.textTertiary)
                        } else {
                            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                                ForEach(actions) { action in
                                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                        Text("\(action.action_type) · \(action.actor_type)")
                                            .font(AppTypography.captionMedium)
                                            .foregroundColor(theme.textPrimary)
                                        Text(formatDate(action.created_at))
                                            .font(AppTypography.small)
                                            .foregroundColor(theme.textTertiary)
                                        jsonBlock(action.payload.prettyPrinted)
                                    }
                                    .padding(AppSpacing.sm)
                                    .background(theme.bgCard)
                                    .cornerRadius(AppRadius.sm)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: AppRadius.sm)
                                            .stroke(theme.borderSubtle, lineWidth: 1)
                                    )
                                }
                            }
                        }
                    }
                    .padding(AppSpacing.lg)
                }
            } else {
                EmptyStateView(icon: "list.bullet.rectangle", title: "Select a card", subtitle: "Choose a card to inspect details and actions.")
            }
        }
        .background(theme.bgSurface)
    }

    @ViewBuilder
    private func actionButtons(card: ConductorCard) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Button {
                Task { await onReplay() }
            } label: {
                Text("Replay Run")
                    .font(AppTypography.captionMedium)
                    .foregroundColor(theme.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(theme.bgHover)
                    .cornerRadius(AppRadius.sm)
            }
            .buttonStyle(.plain)
            .disabled(isMutating)

            Button {
                Task { await onResolve() }
            } label: {
                Text("Resolve")
                    .font(AppTypography.captionMedium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(theme.success)
                    .cornerRadius(AppRadius.sm)
            }
            .buttonStyle(.plain)
            .disabled(isMutating)

            Button {
                Task { await onDismiss() }
            } label: {
                Text("Dismiss")
                    .font(AppTypography.captionMedium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(theme.warning)
                    .cornerRadius(AppRadius.sm)
            }
            .buttonStyle(.plain)
            .disabled(isMutating)

            if card.status != "open" {
                Button {
                    Task { await onReopen() }
                } label: {
                    Text("Reopen")
                        .font(AppTypography.captionMedium)
                        .foregroundColor(theme.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(theme.bgHover)
                        .cornerRadius(AppRadius.sm)
                }
                .buttonStyle(.plain)
                .disabled(isMutating)
            }
        }
    }

    private func jsonBlock(_ text: String) -> some View {
        Text(text.isEmpty ? "{}" : text)
            .font(AppTypography.mono)
            .foregroundColor(theme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppSpacing.sm)
            .background(theme.bgCard)
            .cornerRadius(AppRadius.sm)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.sm)
                    .stroke(theme.borderSubtle, lineWidth: 1)
            )
    }

    private func formatDate(_ raw: String?) -> String {
        guard let raw, !raw.isEmpty else { return "—" }
        if let date = ISO8601DateFormatter().date(from: raw) {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
        return raw
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
