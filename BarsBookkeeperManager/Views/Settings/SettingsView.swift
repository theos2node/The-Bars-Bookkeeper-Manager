import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var authService: AuthService
    @Environment(\.colorScheme) private var colorScheme

    @State private var displayName = ""
    @State private var tenantName = ""
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var apiBaseURL = ""
    @State private var isSaving = false
    @State private var isChangingPassword = false
    @State private var successMessage: String?
    @State private var errorMessage: String?
    @State private var selectedSection: SettingsSection = .account

    private var theme: AppTheme { AppTheme(colorScheme: colorScheme) }

    enum SettingsSection: String, CaseIterable, Identifiable {
        case account = "Account"
        case connection = "Connection"
        case about = "About"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .account: return "person.circle"
            case .connection: return "link"
            case .about: return "info.circle"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Settings")
                    .font(AppTypography.titleMedium)
                    .foregroundColor(theme.textPrimary)
                Spacer()
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, AppSpacing.md)

            Divider().background(theme.borderSubtle)

            HStack(spacing: 0) {
                // Settings sidebar
                VStack(spacing: AppSpacing.xs) {
                    ForEach(SettingsSection.allCases) { section in
                        Button {
                            selectedSection = section
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: section.icon)
                                    .font(.system(size: 15))
                                    .frame(width: 20)
                                Text(section.rawValue)
                                    .font(AppTypography.bodyMedium)
                                Spacer()
                            }
                            .foregroundColor(selectedSection == section ? theme.textPrimary : theme.textSecondary)
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: AppRadius.sm)
                                    .fill(selectedSection == section ? theme.bgSecondary : Color.clear)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
                .frame(width: 200)
                .padding(AppSpacing.md)

                Divider().background(theme.borderSubtle)

                // Content
                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.xl) {
                        switch selectedSection {
                        case .account:
                            accountSection
                        case .connection:
                            connectionSection
                        case .about:
                            aboutSection
                        }
                    }
                    .padding(AppSpacing.xl)
                    .frame(maxWidth: 600, alignment: .leading)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear {
            displayName = authService.profile?.user.display_name ?? ""
            tenantName = authService.profile?.tenant.name ?? ""
            apiBaseURL = APIService.shared.baseURL
        }
    }

    // MARK: - Account Section

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xl) {
            // Profile
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text("Profile")
                    .font(AppTypography.headline)
                    .foregroundColor(theme.textPrimary)

                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Display Name")
                        .font(AppTypography.captionMedium)
                        .foregroundColor(theme.textSecondary)

                    HStack(spacing: AppSpacing.sm) {
                        TextField("Display name", text: $displayName)
                            .textFieldStyle(.plain)
                            .font(AppTypography.body)
                            .padding(AppSpacing.sm + 2)
                            .background(theme.bgInput)
                            .cornerRadius(AppRadius.sm)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppRadius.sm)
                                    .stroke(theme.borderSubtle, lineWidth: 1)
                            )

                        Button {
                            Task { await saveDisplayName() }
                        } label: {
                            Text(isSaving ? "Saving..." : "Save")
                                .font(AppTypography.captionMedium)
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(theme.textLink)
                                .cornerRadius(AppRadius.sm)
                        }
                        .buttonStyle(.plain)
                        .disabled(isSaving)
                    }
                }

                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Email")
                        .font(AppTypography.captionMedium)
                        .foregroundColor(theme.textSecondary)

                    Text(authService.profile?.user.email ?? "—")
                        .font(AppTypography.body)
                        .foregroundColor(theme.textPrimary)
                        .padding(AppSpacing.sm + 2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(theme.bgHover.opacity(0.5))
                        .cornerRadius(AppRadius.sm)
                }

                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Role")
                        .font(AppTypography.captionMedium)
                        .foregroundColor(theme.textSecondary)

                    Text(authService.userRole.capitalized)
                        .font(AppTypography.body)
                        .foregroundColor(theme.textPrimary)
                        .padding(AppSpacing.sm + 2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(theme.bgHover.opacity(0.5))
                        .cornerRadius(AppRadius.sm)
                }
            }

            Divider().background(theme.borderSubtle)

            // Tenant
            if authService.isOwner {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Text("Organization")
                        .font(AppTypography.headline)
                        .foregroundColor(theme.textPrimary)

                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("Tenant Name")
                            .font(AppTypography.captionMedium)
                            .foregroundColor(theme.textSecondary)

                        HStack(spacing: AppSpacing.sm) {
                            TextField("Organization name", text: $tenantName)
                                .textFieldStyle(.plain)
                                .font(AppTypography.body)
                                .padding(AppSpacing.sm + 2)
                                .background(theme.bgInput)
                                .cornerRadius(AppRadius.sm)
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppRadius.sm)
                                        .stroke(theme.borderSubtle, lineWidth: 1)
                                )

                            Button {
                                Task { await saveTenantName() }
                            } label: {
                                Text("Save")
                                    .font(AppTypography.captionMedium)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(theme.textLink)
                                    .cornerRadius(AppRadius.sm)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Divider().background(theme.borderSubtle)
            }

            // Change Password
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text("Change Password")
                    .font(AppTypography.headline)
                    .foregroundColor(theme.textPrimary)

                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Current Password")
                        .font(AppTypography.captionMedium)
                        .foregroundColor(theme.textSecondary)
                    SecureField("Current password", text: $currentPassword)
                        .textFieldStyle(.plain)
                        .font(AppTypography.body)
                        .padding(AppSpacing.sm + 2)
                        .background(theme.bgInput)
                        .cornerRadius(AppRadius.sm)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.sm)
                                .stroke(theme.borderSubtle, lineWidth: 1)
                        )
                }

                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("New Password")
                        .font(AppTypography.captionMedium)
                        .foregroundColor(theme.textSecondary)
                    SecureField("New password", text: $newPassword)
                        .textFieldStyle(.plain)
                        .font(AppTypography.body)
                        .padding(AppSpacing.sm + 2)
                        .background(theme.bgInput)
                        .cornerRadius(AppRadius.sm)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.sm)
                                .stroke(theme.borderSubtle, lineWidth: 1)
                        )
                }

                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Confirm New Password")
                        .font(AppTypography.captionMedium)
                        .foregroundColor(theme.textSecondary)
                    SecureField("Confirm password", text: $confirmPassword)
                        .textFieldStyle(.plain)
                        .font(AppTypography.body)
                        .padding(AppSpacing.sm + 2)
                        .background(theme.bgInput)
                        .cornerRadius(AppRadius.sm)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.sm)
                                .stroke(theme.borderSubtle, lineWidth: 1)
                        )
                }

                Button {
                    Task { await changePassword() }
                } label: {
                    Text(isChangingPassword ? "Changing..." : "Change Password")
                        .font(AppTypography.captionMedium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(theme.textLink)
                        .cornerRadius(AppRadius.sm)
                }
                .buttonStyle(.plain)
                .disabled(currentPassword.isEmpty || newPassword.isEmpty || newPassword != confirmPassword || isChangingPassword)
                .opacity(currentPassword.isEmpty || newPassword.isEmpty || newPassword != confirmPassword ? 0.5 : 1)
            }

            // Status messages
            if let successMessage = successMessage {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(theme.success)
                    Text(successMessage)
                        .font(AppTypography.caption)
                        .foregroundColor(theme.success)
                }
            }

            if let errorMessage = errorMessage {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(theme.error)
                    Text(errorMessage)
                        .font(AppTypography.caption)
                        .foregroundColor(theme.error)
                }
            }

            Divider().background(theme.borderSubtle)

            // Sign out
            Button {
                authService.logout()
            } label: {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 14))
                    Text("Sign Out")
                        .font(AppTypography.bodyMedium)
                }
                .foregroundColor(theme.error)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(theme.errorSubtle)
                .cornerRadius(AppRadius.sm)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Connection Section

    private var connectionSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xl) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text("API Connection")
                    .font(AppTypography.headline)
                    .foregroundColor(theme.textPrimary)

                Text("Configure the server URL for the Bars Bookkeeper API. This should match your existing web deployment.")
                    .font(AppTypography.caption)
                    .foregroundColor(theme.textSecondary)

                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Base URL")
                        .font(AppTypography.captionMedium)
                        .foregroundColor(theme.textSecondary)

                    HStack(spacing: AppSpacing.sm) {
                        TextField("https://barsbookkeeper.com/api", text: $apiBaseURL)
                            .textFieldStyle(.plain)
                            .font(AppTypography.mono)
                            .padding(AppSpacing.sm + 2)
                            .background(theme.bgInput)
                            .cornerRadius(AppRadius.sm)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppRadius.sm)
                                    .stroke(theme.borderSubtle, lineWidth: 1)
                            )
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)

                        Button {
                            APIService.shared.baseURL = apiBaseURL
                            showSuccess("API URL updated")
                        } label: {
                            Text("Save")
                                .font(AppTypography.captionMedium)
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(theme.textLink)
                                .cornerRadius(AppRadius.sm)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xl) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text("Bars Bookkeeper Manager")
                    .font(AppTypography.headline)
                    .foregroundColor(theme.textPrimary)

                Text("iPad companion app for Bars Bookkeeper — the inventory management, forecasting, and ordering platform for bars and restaurants.")
                    .font(AppTypography.body)
                    .foregroundColor(theme.textSecondary)

                VStack(spacing: AppSpacing.sm) {
                    DetailRow(label: "Version", value: "1.0.0", theme: theme)
                    DetailRow(label: "Platform", value: "iPad (Landscape)", theme: theme)
                    DetailRow(label: "Minimum iOS", value: "17.0", theme: theme)
                }
            }
        }
    }

    // MARK: - Actions

    private func saveDisplayName() async {
        guard let token = authService.token else { return }
        isSaving = true
        clearMessages()

        do {
            _ = try await APIService.shared.updateProfile(token: token, displayName: displayName)
            try await authService.loadProfile()
            showSuccess("Display name updated")
        } catch {
            authService.handleAuthError(error)
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }

    private func saveTenantName() async {
        guard let token = authService.token else { return }
        clearMessages()

        do {
            _ = try await APIService.shared.updateTenant(token: token, name: tenantName)
            try await authService.loadProfile()
            showSuccess("Organization name updated")
        } catch {
            authService.handleAuthError(error)
            errorMessage = error.localizedDescription
        }
    }

    private func changePassword() async {
        guard let token = authService.token else { return }
        guard newPassword == confirmPassword else {
            errorMessage = "Passwords don't match"
            return
        }
        isChangingPassword = true
        clearMessages()

        do {
            _ = try await APIService.shared.updatePassword(token: token, currentPassword: currentPassword, newPassword: newPassword)
            currentPassword = ""
            newPassword = ""
            confirmPassword = ""
            showSuccess("Password changed successfully")
        } catch {
            authService.handleAuthError(error)
            errorMessage = error.localizedDescription
        }
        isChangingPassword = false
    }

    private func showSuccess(_ message: String) {
        successMessage = message
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            successMessage = nil
        }
    }

    private func clearMessages() {
        successMessage = nil
        errorMessage = nil
    }
}
