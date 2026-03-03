import SwiftUI

struct RequestsView: View {
    @EnvironmentObject private var authService: AuthService
    @Environment(\.colorScheme) private var colorScheme

    @State private var requests: [StockRequest] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var searchQuery = ""
    @State private var statusFilter: RequestStatus? = .pending
    @State private var processingIds: Set<String> = []

    private var theme: AppTheme { AppTheme(colorScheme: colorScheme) }

    private var filteredRequests: [StockRequest] {
        var result = requests

        if let filter = statusFilter {
            result = result.filter { $0.status == filter }
        }

        if !searchQuery.isEmpty {
            let query = searchQuery.lowercased()
            result = result.filter {
                $0.item_name.lowercased().contains(query) ||
                $0.requester.lowercased().contains(query)
            }
        }

        return result
    }

    private var pendingCount: Int {
        requests.filter { $0.status == .pending }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(theme.borderSubtle)

            if isLoading {
                LoadingView(message: "Loading requests...")
            } else if let errorMessage = errorMessage {
                EmptyStateView(icon: "exclamationmark.triangle", title: "Error", subtitle: errorMessage)
            } else if filteredRequests.isEmpty {
                EmptyStateView(
                    icon: "doc.text",
                    title: statusFilter == .pending ? "All clear, no requests yet" : "No requests found",
                    subtitle: statusFilter == .pending ? "You're all caught up." : "Stock requests from staff will appear here."
                )
            } else {
                requestsList
            }
        }
        .task { await loadData() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Requests")
                    .font(AppTypography.titleMedium)
                    .foregroundColor(theme.textPrimary)

                if pendingCount > 0 {
                    Text("\(pendingCount) pending")
                        .font(AppTypography.caption)
                        .foregroundColor(theme.warning)
                } else {
                    Text("All caught up")
                        .font(AppTypography.caption)
                        .foregroundColor(theme.textSecondary)
                }
            }

            Spacer()

            // Status filter
            HStack(spacing: AppSpacing.xs) {
                FilterPill(label: "Pending", isActive: statusFilter == .pending, theme: theme) {
                    statusFilter = statusFilter == .pending ? nil : .pending
                }
                FilterPill(label: "Accepted", isActive: statusFilter == .accepted, theme: theme) {
                    statusFilter = statusFilter == .accepted ? nil : .accepted
                }
                FilterPill(label: "Denied", isActive: statusFilter == .denied, theme: theme) {
                    statusFilter = statusFilter == .denied ? nil : .denied
                }
                FilterPill(label: "All", isActive: statusFilter == nil, theme: theme) {
                    statusFilter = nil
                }
            }

            SearchBar(text: $searchQuery, placeholder: "Search requests...")
                .frame(width: 260)

            Button {
                Task { await loadData() }
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

    // MARK: - Requests List

    private var requestsList: some View {
        ScrollView {
            LazyVStack(spacing: AppSpacing.sm) {
                ForEach(filteredRequests) { request in
                    RequestCard(
                        request: request,
                        isProcessing: processingIds.contains(request.id),
                        theme: theme,
                        onAccept: { await handleAction(id: request.id, status: "accepted") },
                        onDeny: { await handleAction(id: request.id, status: "denied") }
                    )
                }
            }
            .padding(AppSpacing.lg)
        }
    }

    // MARK: - Actions

    private func loadData() async {
        guard let token = authService.token else { return }
        isLoading = true
        errorMessage = nil

        do {
            requests = try await APIService.shared.fetchRequests(token: token)
        } catch {
            authService.handleAuthError(error)
            if shouldTreatAsNoRequests(error) {
                requests = []
                errorMessage = nil
            } else {
                errorMessage = error.localizedDescription
            }
        }
        isLoading = false
    }

    private func shouldTreatAsNoRequests(_ error: Error) -> Bool {
        guard let apiError = error as? APIError else { return false }

        switch apiError {
        case .serverError(let message):
            let normalized = message.lowercased()
            return normalized.contains("request failed with status 404")
                || normalized.contains("requests_fetch_failed")
                || normalized.contains("request_not_found")
                || normalized.contains("no requests")
        default:
            return false
        }
    }

    private func handleAction(id: String, status: String) async {
        guard let token = authService.token else { return }
        processingIds.insert(id)

        do {
            let updated = try await APIService.shared.updateRequestStatus(token: token, id: id, status: status)
            if let index = requests.firstIndex(where: { $0.id == id }) {
                requests[index] = updated
            }
        } catch {
            authService.handleAuthError(error)
        }
        processingIds.remove(id)
    }
}

// MARK: - Request Card

struct RequestCard: View {
    let request: StockRequest
    let isProcessing: Bool
    let theme: AppTheme
    let onAccept: () async -> Void
    let onDeny: () async -> Void

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: AppRadius.sm)
                    .fill(theme.bgIcon)
                    .frame(width: 40, height: 40)

                if let icon = request.item_icon, !icon.isEmpty {
                    Text(icon)
                        .font(.system(size: 20))
                } else {
                    Image(systemName: "doc.text")
                        .foregroundColor(theme.textSecondary)
                }
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: AppSpacing.sm) {
                    Text(request.item_name)
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(theme.textPrimary)

                    statusBadge
                }

                HStack(spacing: AppSpacing.md) {
                    Label {
                        Text("\(formatQuantity(request.quantity)) \(request.unit)")
                            .font(AppTypography.caption)
                    } icon: {
                        Image(systemName: "cube.box")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(theme.textSecondary)

                    Label {
                        Text(request.requester)
                            .font(AppTypography.caption)
                    } icon: {
                        Image(systemName: "person")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(theme.textSecondary)

                    Text(request.formattedDate)
                        .font(AppTypography.small)
                        .foregroundColor(theme.textTertiary)
                }
            }

            Spacer()

            // Actions for pending requests
            if request.status == .pending {
                HStack(spacing: AppSpacing.sm) {
                    if isProcessing {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Button {
                            Task { await onDeny() }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 12, weight: .medium))
                                Text("Deny")
                                    .font(AppTypography.captionMedium)
                            }
                            .foregroundColor(theme.error)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(theme.errorSubtle)
                            .cornerRadius(AppRadius.sm)
                        }
                        .buttonStyle(.plain)

                        Button {
                            Task { await onAccept() }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .medium))
                                Text("Accept")
                                    .font(AppTypography.captionMedium)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(theme.success)
                            .cornerRadius(AppRadius.sm)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(AppSpacing.md)
        .background(theme.bgCard)
        .cornerRadius(AppRadius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(theme.borderSubtle, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch request.status {
        case .pending:
            StatusBadge(text: "Pending", color: theme.warning, bgColor: theme.warningSubtle)
        case .accepted:
            StatusBadge(text: "Accepted", color: theme.success, bgColor: theme.successSubtle)
        case .denied:
            StatusBadge(text: "Denied", color: theme.error, bgColor: theme.errorSubtle)
        }
    }

    private func formatQuantity(_ value: Double) -> String {
        if value == value.rounded() { return String(format: "%.0f", value) }
        return String(format: "%.1f", value)
    }
}
