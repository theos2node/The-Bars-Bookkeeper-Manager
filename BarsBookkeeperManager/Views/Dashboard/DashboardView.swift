import SwiftUI

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
