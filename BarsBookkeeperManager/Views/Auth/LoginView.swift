import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var authService: AuthService
    @Environment(\.colorScheme) private var colorScheme

    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var theme: AppTheme { AppTheme(colorScheme: colorScheme) }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                theme.bgPrimary.ignoresSafeArea()

                HStack(spacing: 0) {
                    // Left panel — branding
                    brandingPanel
                        .frame(width: geo.size.width * 0.45)

                    // Right panel — login form
                    formPanel
                        .frame(width: geo.size.width * 0.55)
                }
            }
        }
    }

    // MARK: - Branding Panel

    private var brandingPanel: some View {
        ZStack {
            LinearGradient(
                colors: [
                    AppColors.Dark.bgPrimary,
                    AppColors.Dark.bgSecondary
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: AppSpacing.lg) {
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 132, height: 132)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 6)

                Text("Bars Bookkeeper")
                    .font(.system(size: 32, weight: .bold, design: .default))
                    .foregroundColor(.white)

                Text("Inventory management,\nforecasting & ordering\nfor your bar.")
                    .font(AppTypography.body)
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(AppSpacing.xxl)
        }
    }

    // MARK: - Form Panel

    private var formPanel: some View {
        ZStack {
            theme.bgSecondary

            VStack(spacing: 0) {
                Spacer()

                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    // Header
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("Welcome back")
                            .font(AppTypography.titleLarge)
                            .foregroundColor(theme.textPrimary)

                        Text("Please enter your details to sign in.")
                            .font(AppTypography.body)
                            .foregroundColor(theme.textSecondary)
                    }

                    // Form fields
                    VStack(spacing: AppSpacing.md) {
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            Text("Email address")
                                .font(AppTypography.captionMedium)
                                .foregroundColor(theme.textSecondary)

                            TextField("Enter your email", text: $email)
                                .textFieldStyle(.plain)
                                .font(AppTypography.body)
                                .padding(AppSpacing.md)
                                .background(theme.bgInput)
                                .cornerRadius(AppRadius.sm)
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppRadius.sm)
                                        .stroke(theme.borderSubtle, lineWidth: 1)
                                )
                                .textContentType(.emailAddress)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                        }

                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            Text("Password")
                                .font(AppTypography.captionMedium)
                                .foregroundColor(theme.textSecondary)

                            SecureField("Enter your password", text: $password)
                                .textFieldStyle(.plain)
                                .font(AppTypography.body)
                                .padding(AppSpacing.md)
                                .background(theme.bgInput)
                                .cornerRadius(AppRadius.sm)
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppRadius.sm)
                                        .stroke(theme.borderSubtle, lineWidth: 1)
                                )
                                .textContentType(.password)
                        }
                    }

                    // Error message
                    if let errorMessage = errorMessage {
                        HStack(spacing: AppSpacing.sm) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(theme.error)
                                .font(.system(size: 14))
                            Text(errorMessage)
                                .font(AppTypography.caption)
                                .foregroundColor(theme.error)
                        }
                    }

                    // Submit button
                    Button(action: handleLogin) {
                        HStack(spacing: AppSpacing.sm) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Text("Continue")
                                    .font(AppTypography.bodyMedium)
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 14, weight: .medium))
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: AppRadius.sm)
                                .fill(Color(hex: "#37352f"))
                        )
                    }
                    .disabled(isLoading || email.isEmpty || password.isEmpty)
                    .opacity(email.isEmpty || password.isEmpty ? 0.5 : 1)
                }
                .frame(maxWidth: 400)
                .padding(.horizontal, AppSpacing.xxl)

                Spacer()

                // Footer
                Text("Sign in with your Bars Bookkeeper account")
                    .font(AppTypography.small)
                    .foregroundColor(theme.textTertiary)
                    .padding(.bottom, AppSpacing.lg)
            }
        }
    }

    // MARK: - Actions

    private func handleLogin() {
        guard !email.isEmpty, !password.isEmpty else { return }
        isLoading = true
        errorMessage = nil

        Task {
            do {
                try await authService.login(email: email, password: password)
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}
