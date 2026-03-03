import SwiftUI

struct SearchBar: View {
    @Binding var text: String
    var placeholder: String = "Search..."
    @Environment(\.colorScheme) private var colorScheme

    private var theme: AppTheme { AppTheme(colorScheme: colorScheme) }

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(theme.textTertiary)
                .font(.system(size: 14))

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(AppTypography.body)
                .foregroundColor(theme.textPrimary)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(theme.textTertiary)
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, 10)
        .background(theme.bgInput)
        .cornerRadius(AppRadius.sm)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.sm)
                .stroke(theme.borderSubtle, lineWidth: 1)
        )
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let text: String
    let color: Color
    let bgColor: Color

    var body: some View {
        Text(text)
            .font(AppTypography.smallMedium)
            .foregroundColor(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(bgColor)
            .cornerRadius(AppRadius.xs)
    }
}

// MARK: - Empty State

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    @Environment(\.colorScheme) private var colorScheme

    private var theme: AppTheme { AppTheme(colorScheme: colorScheme) }

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(theme.textTertiary)

            Text(title)
                .font(AppTypography.titleSmall)
                .foregroundColor(theme.textPrimary)

            Text(subtitle)
                .font(AppTypography.body)
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(AppSpacing.xl)
    }
}

// MARK: - Loading View

struct LoadingView: View {
    var message: String = "Loading..."
    @Environment(\.colorScheme) private var colorScheme

    private var theme: AppTheme { AppTheme(colorScheme: colorScheme) }

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.2)

            Text(message)
                .font(AppTypography.body)
                .foregroundColor(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    var count: Int? = nil
    @Environment(\.colorScheme) private var colorScheme

    private var theme: AppTheme { AppTheme(colorScheme: colorScheme) }

    var body: some View {
        HStack {
            Text(title)
                .font(AppTypography.headline)
                .foregroundColor(theme.textPrimary)

            if let count = count {
                Text("\(count)")
                    .font(AppTypography.captionMedium)
                    .foregroundColor(theme.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(theme.bgHover)
                    .cornerRadius(AppRadius.xs)
            }

            Spacer()
        }
    }
}
