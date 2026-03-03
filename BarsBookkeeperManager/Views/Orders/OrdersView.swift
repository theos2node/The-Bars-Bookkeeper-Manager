import SwiftUI

struct OrdersView: View {
    @EnvironmentObject private var authService: AuthService
    @Environment(\.colorScheme) private var colorScheme

    @State private var orders: [OrderDraft] = []
    @State private var vendors: [VendorContact] = []
    @State private var isLoading = true
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var searchQuery = ""
    @State private var selectedOrder: OrderDraft?
    @State private var statusFilter: OrderStatus?
    @State private var showVendorSheet = false
    @State private var sendingOrderId: String?
    @State private var qualityGate: ConductorQualitySnapshot?

    private var theme: AppTheme { AppTheme(colorScheme: colorScheme) }

    private var filteredOrders: [OrderDraft] {
        var result = orders

        if let filter = statusFilter {
            result = result.filter { $0.status == filter }
        }

        if !searchQuery.isEmpty {
            let query = searchQuery.lowercased()
            result = result.filter {
                $0.vendor_name.lowercased().contains(query) ||
                $0.email_subject.lowercased().contains(query)
            }
        }

        return result.sorted { ($0.created_at) > ($1.created_at) }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(theme.borderSubtle)
            if let qualityGate = qualityGate {
                QualityGateBanner(qualityGate: qualityGate, theme: theme, hideWhenPass: true)
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.top, AppSpacing.md)
            }

            if isLoading {
                LoadingView(message: "Loading orders...")
            } else if let errorMessage = errorMessage {
                EmptyStateView(icon: "exclamationmark.triangle", title: "Error", subtitle: errorMessage)
            } else {
                contentView
            }
        }
        .task { await loadData() }
        .sheet(isPresented: $showVendorSheet) {
            VendorSheet(vendors: $vendors, theme: theme)
                .environmentObject(authService)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Orders")
                    .font(AppTypography.titleMedium)
                    .foregroundColor(theme.textPrimary)

                Text("\(orders.count) orders, \(vendors.count) vendors")
                    .font(AppTypography.caption)
                    .foregroundColor(theme.textSecondary)
            }

            Spacer()

            HStack(spacing: AppSpacing.xs) {
                FilterPill(label: "All", isActive: statusFilter == nil, theme: theme) {
                    statusFilter = nil
                }
                FilterPill(label: "Draft", isActive: statusFilter == .draft, theme: theme) {
                    statusFilter = statusFilter == .draft ? nil : .draft
                }
                FilterPill(label: "Sent", isActive: statusFilter == .sent, theme: theme) {
                    statusFilter = statusFilter == .sent ? nil : .sent
                }
                FilterPill(label: "Confirmed", isActive: statusFilter == .confirmed, theme: theme) {
                    statusFilter = statusFilter == .confirmed ? nil : .confirmed
                }
            }

            SearchBar(text: $searchQuery, placeholder: "Search orders...")
                .frame(width: 240)

            Button {
                showVendorSheet = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "person.2")
                        .font(.system(size: 12))
                    Text("Vendors")
                        .font(AppTypography.captionMedium)
                }
                .foregroundColor(theme.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(theme.bgHover)
                .cornerRadius(AppRadius.sm)
            }
            .buttonStyle(.plain)

            if authService.isManager {
                Button {
                    Task { await generateOrders() }
                } label: {
                    HStack(spacing: 4) {
                        if isGenerating {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "sparkles")
                                .font(.system(size: 11))
                        }
                        Text("Generate Orders")
                            .font(AppTypography.captionMedium)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(theme.textLink)
                    .cornerRadius(AppRadius.sm)
                }
                .buttonStyle(.plain)
                .disabled(isGenerating)
            }
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.md)
    }

    // MARK: - Content

    private var contentView: some View {
        HStack(spacing: 0) {
            if filteredOrders.isEmpty {
                EmptyStateView(
                    icon: "cart",
                    title: "No orders",
                    subtitle: "Generate orders from your forecast predictions to get started."
                )
            } else {
                // Order list
                ScrollView {
                    LazyVStack(spacing: AppSpacing.sm) {
                        ForEach(filteredOrders) { order in
                            OrderCard(
                                order: order,
                                isSelected: selectedOrder?.id == order.id,
                                isSending: sendingOrderId == order.id,
                                theme: theme,
                                onSend: { await sendOrder(order.id) }
                            )
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    selectedOrder = order
                                }
                            }
                        }
                    }
                    .padding(AppSpacing.lg)
                }

                // Detail panel
                if let selected = selectedOrder {
                    Divider().background(theme.borderSubtle)

                    OrderDetailPanel(
                        order: selected,
                        theme: theme,
                        isSending: sendingOrderId == selected.id,
                        onSend: { await sendOrder(selected.id) }
                    )
                    .frame(width: 400)
                }
            }
        }
    }

    // MARK: - Actions

    private func loadData() async {
        guard let token = authService.token else { return }
        isLoading = true
        errorMessage = nil

        do {
            async let ordersTask = APIService.shared.fetchOrders(token: token)
            async let vendorsTask = APIService.shared.fetchVendors(token: token)
            async let qualityTask = APIService.shared.fetchConductorQualityLatest(token: token)
            orders = try await ordersTask
            vendors = try await vendorsTask
            qualityGate = try await qualityTask
        } catch {
            authService.handleAuthError(error)
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func generateOrders() async {
        guard let token = authService.token else { return }
        isGenerating = true

        do {
            let response = try await APIService.shared.generateOrders(token: token)
            orders.insert(contentsOf: response.orders, at: 0)
            if let returnedGate = response.qualityGate {
                qualityGate = returnedGate
            } else {
                qualityGate = try await APIService.shared.fetchConductorQualityLatest(token: token)
            }
        } catch {
            authService.handleAuthError(error)
            if error.localizedDescription == "quality_gate_blocked" {
                errorMessage = "Order generation blocked by quality gate. Resolve critical data quality cards first."
                qualityGate = try? await APIService.shared.fetchConductorQualityLatest(token: token)
            } else {
                errorMessage = error.localizedDescription
            }
        }
        isGenerating = false
    }

    private func sendOrder(_ orderId: String) async {
        guard let token = authService.token else { return }
        sendingOrderId = orderId

        do {
            _ = try await APIService.shared.sendOrder(token: token, orderId: orderId)
            await loadData()
        } catch {
            authService.handleAuthError(error)
        }
        sendingOrderId = nil
    }
}

// MARK: - Order Card

struct OrderCard: View {
    let order: OrderDraft
    let isSelected: Bool
    let isSending: Bool
    let theme: AppTheme
    let onSend: () async -> Void

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            // Vendor icon
            ZStack {
                RoundedRectangle(cornerRadius: AppRadius.sm)
                    .fill(theme.bgIcon)
                    .frame(width: 40, height: 40)

                Text(String(order.vendor_name.prefix(1)).uppercased())
                    .font(AppTypography.headline)
                    .foregroundColor(theme.textSecondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: AppSpacing.sm) {
                    Text(order.vendor_name)
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(theme.textPrimary)

                    orderStatusBadge
                }

                HStack(spacing: AppSpacing.md) {
                    Label {
                        Text("\(order.items.count) items")
                            .font(AppTypography.caption)
                    } icon: {
                        Image(systemName: "cube.box")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(theme.textSecondary)

                    if order.ai_generated {
                        Label {
                            Text("AI Generated")
                                .font(AppTypography.caption)
                        } icon: {
                            Image(systemName: "sparkles")
                                .font(.system(size: 11))
                        }
                        .foregroundColor(theme.textLink)
                    }

                    Text(formatDate(order.created_at))
                        .font(AppTypography.small)
                        .foregroundColor(theme.textTertiary)
                }
            }

            Spacer()

            // Send button for drafts
            if order.status == .draft || order.status == .pending_review {
                Button {
                    Task { await onSend() }
                } label: {
                    HStack(spacing: 4) {
                        if isSending {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 11))
                        }
                        Text("Send")
                            .font(AppTypography.captionMedium)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(theme.success)
                    .cornerRadius(AppRadius.sm)
                }
                .buttonStyle(.plain)
                .disabled(isSending)
            }
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .fill(isSelected ? theme.bgSecondary : theme.bgCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(theme.borderSubtle, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var orderStatusBadge: some View {
        let (text, color, bg) = statusColors(order.status)
        StatusBadge(text: text, color: color, bgColor: bg)
    }

    private func statusColors(_ status: OrderStatus) -> (String, Color, Color) {
        switch status {
        case .draft: return ("Draft", theme.textSecondary, theme.bgHover)
        case .pending_review: return ("Review", theme.warning, theme.warningSubtle)
        case .sent: return ("Sent", theme.textLink, theme.textLink.opacity(0.15))
        case .confirmed: return ("Confirmed", theme.success, theme.successSubtle)
        case .cancelled: return ("Cancelled", theme.error, theme.errorSubtle)
        }
    }

    private func formatDate(_ dateString: String) -> String {
        guard let date = ISO8601DateFormatter().date(from: dateString) else { return dateString }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Order Detail Panel

struct OrderDetailPanel: View {
    let order: OrderDraft
    let theme: AppTheme
    let isSending: Bool
    let onSend: () async -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                // Header
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text(order.vendor_name)
                        .font(AppTypography.titleSmall)
                        .foregroundColor(theme.textPrimary)

                    if let email = order.vendor_email {
                        Text(email)
                            .font(AppTypography.caption)
                            .foregroundColor(theme.textSecondary)
                    }
                }

                Divider().background(theme.borderSubtle)

                // Email preview
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("Email Preview")
                        .font(AppTypography.headline)
                        .foregroundColor(theme.textPrimary)

                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("Subject: \(order.email_subject)")
                            .font(AppTypography.captionMedium)
                            .foregroundColor(theme.textPrimary)

                        Text(order.email_body)
                            .font(AppTypography.caption)
                            .foregroundColor(theme.textSecondary)
                            .lineLimit(10)
                    }
                    .padding(AppSpacing.md)
                    .background(theme.bgCard)
                    .cornerRadius(AppRadius.md)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.md)
                            .stroke(theme.borderSubtle, lineWidth: 1)
                    )
                }

                Divider().background(theme.borderSubtle)

                // Items
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("Items (\(order.items.count))")
                        .font(AppTypography.headline)
                        .foregroundColor(theme.textPrimary)

                    ForEach(order.items, id: \.skuId) { item in
                        HStack {
                            Text(item.name)
                                .font(AppTypography.body)
                                .foregroundColor(theme.textPrimary)
                                .lineLimit(1)

                            Spacer()

                            Text("\(formatQuantity(item.recommendedQty)) \(item.unit)")
                                .font(AppTypography.captionMedium)
                                .foregroundColor(theme.textLink)
                        }
                        .padding(.vertical, 4)

                        if item.skuId != order.items.last?.skuId {
                            Divider().background(theme.borderSubtle)
                        }
                    }
                }

                // Send button
                if order.status == .draft || order.status == .pending_review {
                    Button {
                        Task { await onSend() }
                    } label: {
                        HStack {
                            if isSending {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "paperplane.fill")
                                    .font(.system(size: 14))
                                Text("Send Order")
                                    .font(AppTypography.bodyMedium)
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(theme.success)
                        .cornerRadius(AppRadius.sm)
                    }
                    .buttonStyle(.plain)
                    .disabled(isSending)
                }
            }
            .padding(AppSpacing.lg)
        }
        .background(theme.bgSurface)
    }

    private func formatQuantity(_ value: Double) -> String {
        if value == value.rounded() { return String(format: "%.0f", value) }
        return String(format: "%.1f", value)
    }
}
