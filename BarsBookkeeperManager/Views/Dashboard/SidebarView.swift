import SwiftUI

enum SidebarTab: String, CaseIterable, Identifiable {
    case inventory = "Inventory"
    case requests = "Requests"
    case imports = "Imports"
    case predictions = "Predictions"
    case orders = "Orders"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .inventory: return "square.grid.2x2"
        case .requests: return "doc.text"
        case .imports: return "tray.and.arrow.down"
        case .predictions: return "sparkles"
        case .orders: return "cart"
        case .settings: return "gearshape"
        }
    }
}

struct SidebarView: View {
    @Binding var selectedTab: SidebarTab
    @EnvironmentObject private var authService: AuthService
    @Environment(\.colorScheme) private var colorScheme

    private var theme: AppTheme { AppTheme(colorScheme: colorScheme) }

    var body: some View {
        VStack(spacing: 0) {
            // Brand header
            HStack(spacing: 10) {
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Bars Bookkeeper")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(theme.textPrimary)

                    Text(authService.tenantName)
                        .font(AppTypography.small)
                        .foregroundColor(theme.textSecondary)
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.md)
            .background(theme.bgPrimary)

            Divider()
                .background(theme.borderSubtle)

            // Navigation items
            ScrollView {
                VStack(spacing: AppSpacing.xs) {
                    ForEach(SidebarTab.allCases) { tab in
                        SidebarButton(
                            tab: tab,
                            isSelected: selectedTab == tab,
                            theme: theme
                        ) {
                            selectedTab = tab
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.sm)
                .padding(.top, AppSpacing.sm)
            }

            Spacer()

            Divider()
                .background(theme.borderSubtle)

            // User info & sign out
            VStack(spacing: AppSpacing.sm) {
                HStack(spacing: AppSpacing.sm) {
                    Circle()
                        .fill(theme.textLink.opacity(0.2))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Text(String(authService.displayName.prefix(1)).uppercased())
                                .font(AppTypography.captionMedium)
                                .foregroundColor(theme.textLink)
                        )

                    VStack(alignment: .leading, spacing: 1) {
                        Text(authService.displayName)
                            .font(AppTypography.captionMedium)
                            .foregroundColor(theme.textPrimary)
                            .lineLimit(1)

                        Text(authService.userRole.capitalized)
                            .font(AppTypography.small)
                            .foregroundColor(theme.textTertiary)
                    }

                    Spacer()
                }

                Button {
                    authService.logout()
                } label: {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 13))
                        Text("Sign Out")
                            .font(AppTypography.caption)
                    }
                    .foregroundColor(theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, AppSpacing.sm)
                    .padding(.horizontal, AppSpacing.sm)
                    .background(theme.bgHover.opacity(0.5))
                    .cornerRadius(AppRadius.sm)
                }
                .buttonStyle(.plain)
            }
            .padding(AppSpacing.md)
        }
        .frame(width: 240)
        .background(theme.bgPrimary)
    }
}

struct SidebarButton: View {
    let tab: SidebarTab
    let isSelected: Bool
    let theme: AppTheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: tab.icon)
                    .font(.system(size: 15))
                    .frame(width: 20)

                Text(tab.rawValue)
                    .font(AppTypography.bodyMedium)

                Spacer()
            }
            .foregroundColor(isSelected ? theme.textPrimary : theme.textSecondary)
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.sm)
                    .fill(isSelected ? theme.bgSecondary : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}
