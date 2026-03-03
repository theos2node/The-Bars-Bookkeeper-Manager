import Foundation
import SwiftUI

@MainActor
final class AuthService: ObservableObject {
    static let shared = AuthService()

    @Published var isAuthenticated = false
    @Published var token: String?
    @Published var profile: ProfileResponse?
    @Published var isLoading = false

    private let tokenKey = "auth_token"

    private init() {
        if let savedToken = KeychainService.shared.read(key: tokenKey) {
            self.token = savedToken
            self.isAuthenticated = true
        }
    }

    func login(email: String, password: String) async throws {
        isLoading = true
        defer { isLoading = false }

        let response = try await APIService.shared.login(email: email, password: password)
        self.token = response.token
        KeychainService.shared.save(key: tokenKey, value: response.token)
        self.isAuthenticated = true

        try await loadProfile()
    }

    func loadProfile() async throws {
        guard let token = token else { return }
        do {
            let profileData = try await APIService.shared.fetchProfile(token: token)
            self.profile = profileData
        } catch let error as APIError {
            if case .unauthorized = error {
                logout()
            }
            throw error
        }
    }

    func logout() {
        token = nil
        profile = nil
        isAuthenticated = false
        KeychainService.shared.delete(key: tokenKey)
    }

    func handleAuthError(_ error: Error) {
        if let apiError = error as? APIError, case .unauthorized = apiError {
            logout()
        }
    }

    var userRole: String {
        profile?.user.role ?? "staff"
    }

    var isManager: Bool {
        userRole == "manager" || userRole == "owner"
    }

    var isOwner: Bool {
        userRole == "owner"
    }

    var displayName: String {
        profile?.user.display_name ?? profile?.user.email ?? "Manager"
    }

    var tenantName: String {
        profile?.tenant.name ?? "—"
    }
}
