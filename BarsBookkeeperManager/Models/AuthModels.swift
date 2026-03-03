import Foundation

struct AuthResponse: Codable {
    let token: String
}

struct ProfileResponse: Codable {
    let user: UserInfo
    let tenant: TenantInfo
}

struct UserInfo: Codable {
    let id: String
    let email: String
    let role: String
    let display_name: String?
}

struct TenantInfo: Codable {
    let id: String
    let name: String
}

struct ErrorResponse: Codable {
    let error: String
}
