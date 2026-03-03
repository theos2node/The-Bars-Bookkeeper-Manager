import SwiftUI

struct PredictionsView: View {
    @EnvironmentObject private var authService: AuthService
    @Environment(\.colorScheme) private var colorScheme

    @State private var forecasts: [ForecastRow] = []
    @State private var forecastRun: ForecastRun?
    @State private var isLoading = true
    @State private var isRunning = false
    @State private var errorMessage: String?
    @State private var searchQuery = ""
    @State private var selectedForecast: ForecastRow?
    @State private var statusFilter: PredictionStatus?

    private var theme: AppTheme { AppTheme(colorScheme: colorScheme) }

    private var filteredForecasts: [ForecastRow] {
        var result = forecasts

        if let filter = statusFilter {
            result = result.filter { $0.predictionStatus == filter }
        }

        if !searchQuery.isEmpty {
            let query = searchQuery.lowercased()
            result = result.filter {
                $0.name.lowercased().contains(query) ||
                ($0.category_name?.lowercased().contains(query) ?? false)
            }
        }

        // Sort: worst status first
        result.sort { a, b in
            if a.predictionStatus != b.predictionStatus {
                return statusOrder(a.predictionStatus) < statusOrder(b.predictionStatus)
            }
            return (a.daysUntilRunOut ?? 999) < (b.daysUntilRunOut ?? 999)
        }

        return result
    }

    private func statusOrder(_ status: PredictionStatus) -> Int {
        switch status {
        case .out: return 0
        case .low: return 1
        case .good: return 2
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(theme.borderSubtle)

            if isLoading {
                LoadingView(message: "Loading predictions...")
            } else if let errorMessage = errorMessage {
                EmptyStateView(icon: "exclamationmark.triangle", title: "Error", subtitle: errorMessage)
            } else if forecasts.isEmpty {
                EmptyStateView(
                    icon: "sparkles",
                    title: "No predictions available",
                    subtitle: "Run a forecast to generate predictions based on your inventory data."
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
                Text("Predictions")
                    .font(AppTypography.titleMedium)
                    .foregroundColor(theme.textPrimary)

                if let run = forecastRun {
                    Text("Last run: \(formatDate(run.run_at))")
                        .font(AppTypography.caption)
                        .foregroundColor(theme.textSecondary)
                } else {
                    Text("No forecast data")
                        .font(AppTypography.caption)
                        .foregroundColor(theme.textTertiary)
                }
            }

            Spacer()

            HStack(spacing: AppSpacing.xs) {
                FilterPill(label: "All", isActive: statusFilter == nil, theme: theme) {
                    statusFilter = nil
                }
                FilterPill(label: "Out", isActive: statusFilter == .out, theme: theme) {
                    statusFilter = statusFilter == .out ? nil : .out
                }
                FilterPill(label: "Low", isActive: statusFilter == .low, theme: theme) {
                    statusFilter = statusFilter == .low ? nil : .low
                }
                FilterPill(label: "Good", isActive: statusFilter == .good, theme: theme) {
                    statusFilter = statusFilter == .good ? nil : .good
                }
            }

            SearchBar(text: $searchQuery, placeholder: "Search predictions...")
                .frame(width: 260)

            if authService.isManager {
                Button {
                    Task { await runForecast() }
                } label: {
                    HStack(spacing: 4) {
                        if isRunning {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "play.fill")
                                .font(.system(size: 11))
                        }
                        Text("Run Forecast")
                            .font(AppTypography.captionMedium)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(theme.textLink)
                    .cornerRadius(AppRadius.sm)
                }
                .buttonStyle(.plain)
                .disabled(isRunning)
            }
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.md)
    }

    // MARK: - Content

    private var contentView: some View {
        HStack(spacing: 0) {
            // Forecast list
            ScrollView {
                LazyVStack(spacing: AppSpacing.sm) {
                    ForEach(filteredForecasts) { forecast in
                        PredictionRow(
                            forecast: forecast,
                            isSelected: selectedForecast?.id == forecast.id,
                            theme: theme
                        )
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedForecast = forecast
                            }
                        }
                    }
                }
                .padding(AppSpacing.lg)
            }

            // Detail panel
            if let selected = selectedForecast {
                Divider().background(theme.borderSubtle)

                PredictionDetailPanel(forecast: selected, theme: theme)
                    .frame(width: 380)
            }
        }
    }

    // MARK: - Data

    private func loadData() async {
        guard let token = authService.token else { return }
        isLoading = true
        errorMessage = nil

        do {
            let response = try await APIService.shared.fetchForecastLatest(token: token)
            forecasts = response.forecasts
            forecastRun = response.run
        } catch {
            authService.handleAuthError(error)
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func runForecast() async {
        guard let token = authService.token else { return }
        isRunning = true

        do {
            _ = try await APIService.shared.runForecast(token: token)
            // Wait briefly then reload
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await loadData()
        } catch {
            authService.handleAuthError(error)
            errorMessage = error.localizedDescription
        }
        isRunning = false
    }

    private func formatDate(_ dateString: String) -> String {
        guard let date = ISO8601DateFormatter().date(from: dateString) else { return dateString }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Prediction Row

struct PredictionRow: View {
    let forecast: ForecastRow
    let isSelected: Bool
    let theme: AppTheme

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            // Status indicator
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text(forecast.name)
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(1)

                if let category = forecast.category_name {
                    Text(category)
                        .font(AppTypography.small)
                        .foregroundColor(theme.textTertiary)
                }
            }

            Spacer()

            // On hand
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatQuantity(forecast.on_hand))
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(theme.textPrimary)
                Text("on hand")
                    .font(AppTypography.small)
                    .foregroundColor(theme.textTertiary)
            }

            // Days left
            VStack(alignment: .trailing, spacing: 2) {
                if let days = forecast.daysUntilRunOut {
                    Text(days < 1 ? "< 1" : "\(Int(days))")
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(days < 3 ? theme.error : theme.textPrimary)
                    Text("days left")
                        .font(AppTypography.small)
                        .foregroundColor(theme.textTertiary)
                } else {
                    Text("—")
                        .font(AppTypography.body)
                        .foregroundColor(theme.textTertiary)
                }
            }
            .frame(width: 70)

            // Order qty
            if let qty = forecast.recommended_order_qty, qty > 0 {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatQuantity(qty))
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(theme.textLink)
                    Text("order")
                        .font(AppTypography.small)
                        .foregroundColor(theme.textTertiary)
                }
                .frame(width: 60)
            }

            // Status badge
            statusBadge
                .frame(width: 56)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.md)
                .fill(isSelected ? theme.bgSecondary : theme.bgCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.md)
                .stroke(theme.borderSubtle, lineWidth: 1)
        )
    }

    private var statusColor: Color {
        switch forecast.predictionStatus {
        case .good: return theme.success
        case .low: return theme.warning
        case .out: return theme.error
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        let status = forecast.predictionStatus
        Text(status.rawValue)
            .font(AppTypography.smallMedium)
            .foregroundColor(statusColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(statusBgColor)
            .cornerRadius(AppRadius.xs)
    }

    private var statusBgColor: Color {
        switch forecast.predictionStatus {
        case .good: return theme.successSubtle
        case .low: return theme.warningSubtle
        case .out: return theme.errorSubtle
        }
    }

    private func formatQuantity(_ value: Double) -> String {
        if value == value.rounded() { return String(format: "%.0f", value) }
        return String(format: "%.1f", value)
    }
}

// MARK: - Prediction Detail Panel

struct PredictionDetailPanel: View {
    let forecast: ForecastRow
    let theme: AppTheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                // Header
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text(forecast.name)
                        .font(AppTypography.titleSmall)
                        .foregroundColor(theme.textPrimary)

                    if let category = forecast.category_name {
                        Text(category)
                            .font(AppTypography.caption)
                            .foregroundColor(theme.textSecondary)
                    }
                }

                Divider().background(theme.borderSubtle)

                // Key metrics
                HStack(spacing: AppSpacing.md) {
                    MetricCard(title: "On Hand", value: "\(formatQuantity(forecast.on_hand)) \(forecast.unit)", theme: theme)
                    MetricCard(title: "Daily Usage", value: "\(formatQuantity(forecast.avg_daily_usage)) \(forecast.unit)", theme: theme)
                }

                HStack(spacing: AppSpacing.md) {
                    MetricCard(title: "Run Out", value: forecast.formattedRunOut, theme: theme)
                    if let qty = forecast.recommended_order_qty {
                        MetricCard(title: "Order Qty", value: "\(formatQuantity(qty)) \(forecast.unit)", theme: theme)
                    }
                }

                Divider().background(theme.borderSubtle)

                // Forecast details
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Text("Forecast Details")
                        .font(AppTypography.headline)
                        .foregroundColor(theme.textPrimary)

                    DetailRow(label: "Smoothed Level", value: formatQuantity(forecast.smoothed_level), theme: theme)
                    DetailRow(label: "Trend Slope", value: String(format: "%.3f", forecast.trend_slope), theme: theme)
                    DetailRow(label: "Alpha", value: String(format: "%.2f", forecast.alpha), theme: theme)
                    DetailRow(label: "Shrink Rate", value: String(format: "%.1f%%", forecast.shrink_rate * 100), theme: theme)

                    if let par = forecast.par_level {
                        DetailRow(label: "Par Level", value: "\(formatQuantity(par)) \(forecast.unit)", theme: theme)
                    }

                    if let lead = forecast.lead_time_days {
                        DetailRow(label: "Lead Time", value: "\(lead) days", theme: theme)
                    }

                    if let weeklyPar = forecast.effective_weekly_par {
                        DetailRow(label: "Weekly PAR", value: formatQuantity(weeklyPar), theme: theme)
                    }
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

// MARK: - Metric Card

struct MetricCard: View {
    let title: String
    let value: String
    let theme: AppTheme

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(title)
                .font(AppTypography.small)
                .foregroundColor(theme.textTertiary)

            Text(value)
                .font(AppTypography.titleSmall)
                .foregroundColor(theme.textPrimary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.md)
        .background(theme.bgCard)
        .cornerRadius(AppRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.md)
                .stroke(theme.borderSubtle, lineWidth: 1)
        )
    }
}
