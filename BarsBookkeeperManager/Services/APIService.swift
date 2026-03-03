import Foundation

enum APIError: LocalizedError {
    case unauthorized
    case serverError(String)
    case networkError(Error)
    case decodingError(Error)
    case unknown

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Session expired. Please sign in again."
        case .serverError(let message):
            return message
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError:
            return "Unable to parse server response."
        case .unknown:
            return "An unexpected error occurred."
        }
    }
}

@MainActor
final class APIService: ObservableObject {
    static let shared = APIService()

    @Published var baseURL: String {
        didSet {
            UserDefaults.standard.set(baseURL, forKey: "api_base_url")
        }
    }

    private init() {
        self.baseURL = UserDefaults.standard.string(forKey: "api_base_url")
            ?? "https://barsbookkeeper.com/api"
    }

    private func makeURL(_ path: String, query: [String: String]? = nil) -> URL? {
        var urlString = "\(baseURL)\(path)"
        if let query = query, !query.isEmpty {
            let queryString = query.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
            urlString += "?\(queryString)"
        }
        return URL(string: urlString)
    }

    private func request<T: Decodable>(
        method: String = "GET",
        path: String,
        token: String? = nil,
        body: Encodable? = nil,
        query: [String: String]? = nil
    ) async throws -> T {
        guard let url = makeURL(path, query: query) else {
            throw APIError.serverError("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            request.httpBody = try JSONEncoder().encode(body)
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.unknown
        }

        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }

        if httpResponse.statusCode >= 400 {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw APIError.serverError(errorResponse.error)
            }
            throw APIError.serverError("Request failed with status \(httpResponse.statusCode)")
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    // MARK: - Auth

    struct LoginBody: Encodable {
        let email: String
        let password: String
    }

    func login(email: String, password: String) async throws -> AuthResponse {
        try await request(
            method: "POST",
            path: "/auth/login",
            body: LoginBody(email: email.trimmingCharacters(in: .whitespaces).lowercased(), password: password)
        )
    }

    // MARK: - Profile

    func fetchProfile(token: String) async throws -> ProfileResponse {
        try await request(path: "/me", token: token)
    }

    func updateProfile(token: String, displayName: String) async throws -> ProfileUpdateResponse {
        struct Body: Encodable { let displayName: String }
        return try await request(method: "PATCH", path: "/me", token: token, body: Body(displayName: displayName))
    }

    func updatePassword(token: String, currentPassword: String, newPassword: String) async throws -> OkResponse {
        struct Body: Encodable { let currentPassword: String; let newPassword: String }
        return try await request(method: "POST", path: "/me/password", token: token, body: Body(currentPassword: currentPassword, newPassword: newPassword))
    }

    func updateTenant(token: String, name: String) async throws -> TenantUpdateResponse {
        struct Body: Encodable { let name: String }
        return try await request(method: "PATCH", path: "/tenant", token: token, body: Body(name: name))
    }

    // MARK: - Inventory

    func fetchOnHand(token: String) async throws -> [OnHandItem] {
        let response: OnHandResponse = try await request(path: "/inventory/on-hand", token: token)
        return response.onHand
    }

    // MARK: - Requests

    func fetchRequests(token: String, status: String? = nil) async throws -> [StockRequest] {
        var query: [String: String]? = nil
        if let status = status { query = ["status": status] }
        let response: RequestsResponse = try await request(path: "/requests", token: token, query: query)
        return response.requests
    }

    func updateRequestStatus(token: String, id: String, status: String) async throws -> StockRequest {
        struct Body: Encodable { let status: String }
        let response: RequestUpdateResponse = try await request(
            method: "PATCH", path: "/requests/\(id)", token: token, body: Body(status: status)
        )
        return response.request
    }

    // MARK: - Forecasts

    func fetchForecastLatest(token: String) async throws -> ForecastResponse {
        try await request(path: "/inventory/forecast/latest", token: token, query: ["ensureFresh": "1"])
    }

    func runForecast(token: String, windowDays: Int = 30, horizonDays: Int = 14) async throws -> RunForecastResponse {
        struct Body: Encodable { let windowDays: Int; let horizonDays: Int }
        return try await request(method: "POST", path: "/inventory/forecast/run", token: token, body: Body(windowDays: windowDays, horizonDays: horizonDays))
    }

    // MARK: - Orders

    func fetchOrders(token: String, status: String? = nil) async throws -> [OrderDraft] {
        var query: [String: String]? = nil
        if let status = status { query = ["status": status] }
        let response: OrdersResponse = try await request(path: "/orders", token: token, query: query)
        return response.orders
    }

    func generateOrders(token: String) async throws -> GenerateOrdersResponse {
        try await request(method: "POST", path: "/orders/generate", token: token)
    }

    func sendOrder(token: String, orderId: String) async throws -> SendOrderResponse {
        try await request(method: "POST", path: "/orders/\(orderId)/send", token: token)
    }

    func updateOrder(token: String, orderId: String, emailSubject: String? = nil, emailBody: String? = nil, status: String? = nil) async throws -> OrderDraft {
        struct Body: Encodable { let emailSubject: String?; let emailBody: String?; let status: String? }
        let response: OrderUpdateResponse = try await request(
            method: "PATCH", path: "/orders/\(orderId)", token: token,
            body: Body(emailSubject: emailSubject, emailBody: emailBody, status: status)
        )
        return response.order
    }

    // MARK: - Vendors

    func fetchVendors(token: String) async throws -> [VendorContact] {
        let response: VendorsResponse = try await request(path: "/vendors", token: token)
        return response.vendors
    }

    func createVendor(token: String, vendorName: String, email: String, phone: String? = nil, notes: String? = nil) async throws -> VendorContact {
        struct Body: Encodable { let vendorName: String; let email: String; let phone: String?; let notes: String? }
        let response: VendorCreateResponse = try await request(
            method: "POST", path: "/vendors", token: token,
            body: Body(vendorName: vendorName, email: email, phone: phone, notes: notes)
        )
        return response.vendor
    }
}

// MARK: - Additional Response Types

struct ProfileUpdateResponse: Codable {
    let user: UserInfo
}

struct TenantUpdateResponse: Codable {
    let tenant: TenantInfo
}

struct OkResponse: Codable {
    let ok: Bool
}

struct RunForecastResponse: Codable {
    let runId: String
    let runAt: String
    let inserted: Int
}
