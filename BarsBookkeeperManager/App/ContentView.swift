import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var authService: AuthService
    @Environment(\.colorScheme) private var colorScheme

    private var theme: AppTheme { AppTheme(colorScheme: colorScheme) }

    var body: some View {
        Group {
            if authService.isAuthenticated {
                DashboardView()
                    .environment(\.appTheme, theme)
                    .transition(.opacity)
            } else {
                LoginView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authService.isAuthenticated)
        .preferredColorScheme(.dark) // Force dark mode
    }
}
