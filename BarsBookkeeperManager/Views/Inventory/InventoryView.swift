import SwiftUI

struct InventoryView: View {
    @EnvironmentObject private var authService: AuthService
    @Environment(\.colorScheme) private var colorScheme

    @State private var items: [OnHandItem] = []
    @State private var searchQuery = ""
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedItem: OnHandItem?
    @State private var sortBy: SortOption = .name
    @State private var filterStatus: StockStatus?

    private var theme: AppTheme { AppTheme(colorScheme: colorScheme) }

    enum SortOption: String, CaseIterable {
        case name = "Name"
        case status = "Status"
        case quantity = "Quantity"
        case category = "Category"
    }

    private var filteredItems: [OnHandItem] {
        var result = items

        if !searchQuery.isEmpty {
            let query = searchQuery.lowercased()
            result = result.filter {
                $0.name.lowercased().contains(query) ||
                ($0.category_name?.lowercased().contains(query) ?? false)
            }
        }

        if let filterStatus = filterStatus {
            result = result.filter { $0.statusLevel == filterStatus }
        }

        switch sortBy {
        case .name:
            result.sort { $0.name.lowercased() < $1.name.lowercased() }
        case .status:
            result.sort { $0.statusLevel.sortOrder < $1.statusLevel.sortOrder }
        case .quantity:
            result.sort { $0.on_hand > $1.on_hand }
        case .category:
            result.sort { ($0.category_name ?? "zzz") < ($1.category_name ?? "zzz") }
        }

        return result
    }

    private var groupedByCategory: [(String, [OnHandItem])] {
        let dict = Dictionary(grouping: filteredItems) { $0.category_name ?? "Uncategorized" }
        return dict.sorted { $0.key < $1.key }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider().background(theme.borderSubtle)

            if isLoading {
                LoadingView(message: "Loading inventory...")
            } else if let errorMessage = errorMessage {
                EmptyStateView(
                    icon: "exclamationmark.triangle",
                    title: "Unable to load inventory",
                    subtitle: errorMessage
                )
            } else if items.isEmpty {
                EmptyStateView(
                    icon: "square.grid.2x2",
                    title: "No inventory items",
                    subtitle: "Items will appear here once inventory data is imported."
                )
            } else {
                contentView
            }
        }
        .task { await loadData() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Inventory")
                    .font(AppTypography.titleMedium)
                    .foregroundColor(theme.textPrimary)

                Text("\(items.count) items")
                    .font(AppTypography.caption)
                    .foregroundColor(theme.textSecondary)
            }

            Spacer()

            // Status filter pills
            HStack(spacing: AppSpacing.xs) {
                FilterPill(label: "All", isActive: filterStatus == nil, theme: theme) {
                    filterStatus = nil
                }
                FilterPill(label: "Low", isActive: filterStatus == .low, theme: theme) {
                    filterStatus = filterStatus == .low ? nil : .low
                }
                FilterPill(label: "Out", isActive: filterStatus == .out, theme: theme) {
                    filterStatus = filterStatus == .out ? nil : .out
                }
            }

            SearchBar(text: $searchQuery, placeholder: "Search inventory...")
                .frame(width: 280)

            // Sort picker
            Menu {
                ForEach(SortOption.allCases, id: \.self) { option in
                    Button {
                        sortBy = option
                    } label: {
                        HStack {
                            Text(option.rawValue)
                            if sortBy == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.arrow.down")
                    Text(sortBy.rawValue)
                }
                .font(AppTypography.caption)
                .foregroundColor(theme.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(theme.bgHover)
                .cornerRadius(AppRadius.sm)
            }

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
        .background(theme.bgPrimary)
    }

    // MARK: - Content

    private var contentView: some View {
        HStack(spacing: 0) {
            // Item list
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Text("Item")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("On Hand")
                        .frame(width: 100, alignment: .trailing)
                    Text("PAR")
                        .frame(width: 90, alignment: .trailing)
                    Text("Status")
                        .frame(width: 72, alignment: .center)
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
                    LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                        ForEach(groupedByCategory, id: \.0) { category, categoryItems in
                            Section {
                                ForEach(categoryItems) { item in
                                    InventoryRow(
                                        item: item,
                                        isSelected: selectedItem?.id == item.id,
                                        theme: theme
                                    )
                                    .onTapGesture {
                                        withAnimation(.easeInOut(duration: 0.15)) {
                                            selectedItem = item
                                        }
                                    }

                                    Divider().background(theme.borderSubtle).padding(.leading, AppSpacing.lg)
                                }
                            } header: {
                                HStack {
                                    Text(category)
                                        .font(AppTypography.smallMedium)
                                        .foregroundColor(theme.textTertiary)
                                        .textCase(.uppercase)
                                        .tracking(0.5)

                                    Spacer()

                                    Text("\(categoryItems.count)")
                                        .font(AppTypography.small)
                                        .foregroundColor(theme.textTertiary)
                                }
                                .padding(.horizontal, AppSpacing.lg)
                                .padding(.vertical, AppSpacing.sm)
                                .background(theme.bgSecondary)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)

            // Detail panel
            if let selected = selectedItem {
                Divider().background(theme.borderSubtle)

                InventoryDetailPanel(item: selected, theme: theme)
                    .frame(width: 340)
            }
        }
    }

    // MARK: - Data Loading

    private func loadData() async {
        guard let token = authService.token else { return }
        isLoading = true
        errorMessage = nil

        do {
            let onHandItems = try await APIService.shared.fetchOnHand(token: token)
            let forecastResponse = try? await APIService.shared.fetchForecastLatest(token: token)
            items = mergePredictionPar(into: onHandItems, forecasts: forecastResponse?.forecasts ?? [])
        } catch {
            authService.handleAuthError(error)
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func mergePredictionPar(into onHandItems: [OnHandItem], forecasts: [ForecastRow]) -> [OnHandItem] {
        var parBySku: [String: Double] = [:]
        for forecast in forecasts {
            if let par = forecast.effective_weekly_par ?? forecast.par_level {
                parBySku[forecast.sku_id] = par
            }
        }

        return onHandItems.map { item in
            guard let sharedPar = parBySku[item.sku_id] else { return item }
            return item.withEffectiveWeeklyPar(sharedPar)
        }
    }
}

// MARK: - Inventory Row

struct InventoryRow: View {
    let item: OnHandItem
    let isSelected: Bool
    let theme: AppTheme

    var body: some View {
        HStack(spacing: 0) {
            // Icon
            HStack(spacing: AppSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppRadius.sm)
                        .fill(theme.bgIcon)
                        .frame(width: 36, height: 36)

                    if let icon = item.icon, !icon.isEmpty {
                        Text(icon)
                            .font(.system(size: 18))
                    } else {
                        Text(String(item.name.prefix(1)).uppercased())
                            .font(AppTypography.captionMedium)
                            .foregroundColor(theme.textSecondary)
                    }
                }

                // Name & category
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(theme.textPrimary)
                        .lineLimit(1)

                    if let category = item.category_name {
                        Text(category)
                            .font(AppTypography.small)
                            .foregroundColor(theme.textTertiary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(formatQuantity(item.on_hand))
                .font(AppTypography.bodyMedium)
                .foregroundColor(theme.textPrimary)
                .frame(width: 100, alignment: .trailing)

            Group {
                if let par = item.displayPar {
                    Text(formatQuantity(par))
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(theme.textSecondary)
                } else {
                    Text("—")
                        .font(AppTypography.body)
                        .foregroundColor(theme.textTertiary)
                }
            }
            .frame(width: 90, alignment: .trailing)

            HStack {
                statusIndicator(for: item.statusLevel)
            }
            .frame(width: 72, alignment: .center)
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.sm + 2)
        .background(isSelected ? theme.bgSecondary : Color.clear)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func statusIndicator(for status: StockStatus) -> some View {
        Circle()
            .fill(statusColor(status))
            .frame(width: 8, height: 8)
    }

    private func statusColor(_ status: StockStatus) -> Color {
        switch status {
        case .good: return theme.success
        case .low: return theme.warning
        case .critical: return theme.error
        case .out: return theme.error
        case .unknown: return theme.textTertiary
        }
    }

    private func formatQuantity(_ value: Double) -> String {
        if value == value.rounded() {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }
}

// MARK: - Detail Panel

struct InventoryDetailPanel: View {
    let item: OnHandItem
    let theme: AppTheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                // Header
                HStack(spacing: AppSpacing.md) {
                    ZStack {
                        RoundedRectangle(cornerRadius: AppRadius.md)
                            .fill(theme.bgIcon)
                            .frame(width: 48, height: 48)

                        if let icon = item.icon, !icon.isEmpty {
                            Text(icon)
                                .font(.system(size: 24))
                        } else {
                            Text(String(item.name.prefix(1)).uppercased())
                                .font(AppTypography.headline)
                                .foregroundColor(theme.textSecondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name)
                            .font(AppTypography.titleSmall)
                            .foregroundColor(theme.textPrimary)

                        if let category = item.category_name {
                            Text(category)
                                .font(AppTypography.caption)
                                .foregroundColor(theme.textSecondary)
                        }
                    }
                }

                Divider().background(theme.borderSubtle)

                // Status
                statusBadge

                // Details grid
                VStack(spacing: AppSpacing.md) {
                    DetailRow(label: "On Hand", value: "\(formatQuantity(item.on_hand)) \(item.unit)", theme: theme)
                    DetailRow(label: "Par Level", value: item.displayPar.map { "\(formatQuantity($0)) \(item.unit)" } ?? "Not set", theme: theme)
                    DetailRow(label: "Lead Time", value: item.lead_time_days != nil ? "\(item.lead_time_days!) days" : "Not set", theme: theme)
                    DetailRow(label: "Unit", value: item.unit, theme: theme)
                }

                // Par level progress
                if let par = item.displayPar, par > 0 {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("Stock Level")
                            .font(AppTypography.captionMedium)
                            .foregroundColor(theme.textSecondary)

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(theme.bgHover)
                                    .frame(height: 8)

                                RoundedRectangle(cornerRadius: 4)
                                    .fill(barColor)
                                    .frame(width: min(geo.size.width * CGFloat(item.on_hand / par), geo.size.width), height: 8)
                            }
                        }
                        .frame(height: 8)

                        HStack {
                            Text("\(Int((item.on_hand / par) * 100))% of par")
                                .font(AppTypography.small)
                                .foregroundColor(theme.textTertiary)
                            Spacer()
                        }
                    }
                }
            }
            .padding(AppSpacing.lg)
        }
        .background(theme.bgSurface)
    }

    private var barColor: Color {
        switch item.statusLevel {
        case .good: return theme.success
        case .low: return theme.warning
        case .critical, .out: return theme.error
        case .unknown: return theme.textTertiary
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        let status = item.statusLevel
        HStack(spacing: AppSpacing.sm) {
            Circle()
                .fill(badgeColor(status))
                .frame(width: 8, height: 8)

            Text(status.rawValue)
                .font(AppTypography.captionMedium)
                .foregroundColor(badgeColor(status))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(badgeBg(status))
        .cornerRadius(AppRadius.sm)
    }

    private func badgeColor(_ status: StockStatus) -> Color {
        switch status {
        case .good: return theme.success
        case .low: return theme.warning
        case .critical, .out: return theme.error
        case .unknown: return theme.textTertiary
        }
    }

    private func badgeBg(_ status: StockStatus) -> Color {
        switch status {
        case .good: return theme.successSubtle
        case .low: return theme.warningSubtle
        case .critical, .out: return theme.errorSubtle
        case .unknown: return theme.bgHover
        }
    }

    private func formatQuantity(_ value: Double) -> String {
        if value == value.rounded() { return String(format: "%.0f", value) }
        return String(format: "%.1f", value)
    }
}

// MARK: - Detail Row

struct DetailRow: View {
    let label: String
    let value: String
    let theme: AppTheme

    var body: some View {
        HStack {
            Text(label)
                .font(AppTypography.caption)
                .foregroundColor(theme.textSecondary)
            Spacer()
            Text(value)
                .font(AppTypography.captionMedium)
                .foregroundColor(theme.textPrimary)
        }
    }
}

// MARK: - Filter Pill

struct FilterPill: View {
    let label: String
    let isActive: Bool
    let theme: AppTheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(AppTypography.captionMedium)
                .foregroundColor(isActive ? theme.textPrimary : theme.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isActive ? theme.bgSecondary : Color.clear)
                .cornerRadius(AppRadius.sm)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.sm)
                        .stroke(isActive ? theme.borderSubtle : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
