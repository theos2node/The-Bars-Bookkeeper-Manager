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
        guard var components = URLComponents(string: "\(baseURL)\(path)") else {
            return nil
        }
        if let query, !query.isEmpty {
            components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        return components.url
    }

    private func fallbackServerMessage(from data: Data, statusCode: Int) -> String {
        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return "Request failed with status \(statusCode)"
        }

        let error = String(describing: object["error"] ?? "")
        let detail = String(describing: object["detail"] ?? "")

        if !error.isEmpty && error != "nil" && !detail.isEmpty && detail != "nil" {
            return "\(error): \(detail)"
        }
        if !error.isEmpty && error != "nil" {
            return error
        }
        if !detail.isEmpty && detail != "nil" {
            return detail
        }
        return "Request failed with status \(statusCode)"
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
                let detail = errorResponse.detail?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !detail.isEmpty {
                    throw APIError.serverError("\(errorResponse.error): \(detail)")
                }
                throw APIError.serverError(errorResponse.error)
            }
            throw APIError.serverError(
                fallbackServerMessage(from: data, statusCode: httpResponse.statusCode)
            )
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

    // MARK: - Imports

    func uploadImportFile(
        token: String,
        source: String = "auto",
        fileName: String,
        mimeType: String,
        contentBase64: String,
        metadata: [String: String]? = nil
    ) async throws -> ImportQueueResponse {
        struct Body: Encodable {
            let source: String
            let fileName: String
            let mimeType: String
            let contentBase64: String
            let metadata: [String: String]?
        }

        return try await request(
            method: "POST",
            path: "/imports/upload",
            token: token,
            body: Body(
                source: source,
                fileName: fileName,
                mimeType: mimeType,
                contentBase64: contentBase64,
                metadata: metadata
            )
        )
    }

    func uploadImportFileFromData(
        token: String,
        source: String = "auto",
        fileName: String,
        mimeType: String,
        data: Data,
        metadata: [String: String]? = nil
    ) async throws -> ImportQueueResponse {
        do {
            struct InitiateBody: Encodable {
                let purpose: String
                let fileName: String
                let mimeType: String
                let sizeBytes: Int
                let metadata: [String: String]?
            }

            let initiated: UploadInitiateResponse = try await request(
                method: "POST",
                path: "/uploads/initiate",
                token: token,
                body: InitiateBody(
                    purpose: "data_import",
                    fileName: fileName,
                    mimeType: mimeType,
                    sizeBytes: data.count,
                    metadata: metadata
                )
            )

            guard let uploadURL = URL(string: initiated.uploadUrl) else {
                throw APIError.serverError("Invalid upload URL")
            }

            var uploadRequest = URLRequest(url: uploadURL)
            uploadRequest.httpMethod = "PUT"
            for (key, value) in initiated.headers {
                uploadRequest.setValue(value, forHTTPHeaderField: key)
            }
            if uploadRequest.value(forHTTPHeaderField: "Content-Type") == nil {
                uploadRequest.setValue(mimeType, forHTTPHeaderField: "Content-Type")
            }

            let (_, uploadResponse): (Data, URLResponse)
            do {
                (_, uploadResponse) = try await URLSession.shared.upload(for: uploadRequest, from: data)
            } catch {
                throw APIError.networkError(error)
            }

            guard let httpUploadResponse = uploadResponse as? HTTPURLResponse,
                  (200..<300).contains(httpUploadResponse.statusCode) else {
                throw APIError.serverError("Upload failed")
            }

            struct EmptyBody: Encodable {}
            let _: UploadCompleteResponse = try await request(
                method: "POST",
                path: "/uploads/\(initiated.uploadId)/complete",
                token: token,
                body: EmptyBody()
            )

            struct QueueBody: Encodable {
                let source: String
                let metadata: [String: String]?
            }

            return try await request(
                method: "POST",
                path: "/imports/uploads/\(initiated.uploadId)/queue",
                token: token,
                body: QueueBody(source: source, metadata: metadata)
            )
        } catch {
            let contentBase64 = data.base64EncodedString()
            return try await uploadImportFile(
                token: token,
                source: source,
                fileName: fileName,
                mimeType: mimeType,
                contentBase64: contentBase64,
                metadata: metadata
            )
        }
    }

    func fetchImportRun(token: String, id: String) async throws -> ImportRun {
        let response: ImportRunResponse = try await request(path: "/imports/runs/\(id)", token: token)
        return response.run
    }

    // MARK: - Conductor

    func fetchConductorCards(
        token: String,
        status: String? = nil,
        cardType: String? = nil,
        severity: String? = nil,
        limit: Int? = nil
    ) async throws -> [ConductorCard] {
        var query: [String: String] = [:]
        if let status, !status.isEmpty { query["status"] = status }
        if let cardType, !cardType.isEmpty { query["cardType"] = cardType }
        if let severity, !severity.isEmpty { query["severity"] = severity }
        if let limit { query["limit"] = String(limit) }
        let response: ConductorCardsResponse = try await request(
            path: "/conductor/cards",
            token: token,
            query: query.isEmpty ? nil : query
        )
        return response.cards
    }

    func fetchConductorCardActions(token: String, cardId: String) async throws -> [ConductorCardAction] {
        let response: ConductorCardActionsResponse = try await request(
            path: "/conductor/cards/\(cardId)/actions",
            token: token
        )
        return response.actions
    }

    func updateConductorCard(
        token: String,
        cardId: String,
        status: String,
        resolution: String? = nil
    ) async throws -> ConductorCard {
        struct Body: Encodable { let status: String; let resolution: String? }
        let response: ConductorCardResponse = try await request(
            method: "PATCH",
            path: "/conductor/cards/\(cardId)",
            token: token,
            body: Body(status: status, resolution: resolution)
        )
        return response.card
    }

    func replayConductorCard(token: String, cardId: String) async throws -> ConductorCardReplayResponse {
        struct EmptyBody: Encodable {}
        return try await request(
            method: "POST",
            path: "/conductor/cards/\(cardId)/replay",
            token: token,
            body: EmptyBody()
        )
    }

    func fetchConductorQualityLatest(token: String) async throws -> ConductorQualitySnapshot? {
        let response: ConductorQualityLatestResponse = try await request(
            path: "/conductor/quality/latest",
            token: token
        )
        return response.quality
    }

    func fetchConductorQualityHistory(token: String, limit: Int = 100) async throws -> [ConductorQualitySnapshot] {
        let response: ConductorQualityHistoryResponse = try await request(
            path: "/conductor/quality/history",
            token: token,
            query: ["limit": String(limit)]
        )
        return response.snapshots
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

struct ImportQueueResponse: Codable {
    let importRunId: String
    let jobId: String?
    let deduped: Bool?
}

struct ImportRunResponse: Codable {
    let run: ImportRun
}

struct ImportRun: Codable, Identifiable {
    let id: String
    let source: String
    let external_ref: String?
    let status: String
    let checksum: String?
    let error: String?
    let document_date: String?
    let file_classification: String?
    let affects_inventory: Bool?
    let affects_forecast: Bool?
    let quality_gate_status: String?
    let ingest_strategy: String?
    let evidence_score: Double?
    let started_at: String?
    let finished_at: String?
}

struct ConductorCardsResponse: Codable {
    let cards: [ConductorCard]
}

struct ConductorCardResponse: Codable {
    let card: ConductorCard
}

struct ConductorCardActionsResponse: Codable {
    let actions: [ConductorCardAction]
}

struct ConductorQualityLatestResponse: Codable {
    let quality: ConductorQualitySnapshot?
}

struct ConductorQualityHistoryResponse: Codable {
    let snapshots: [ConductorQualitySnapshot]
}

struct ConductorCardReplayResponse: Codable {
    let queued: Bool
    let importRunId: String?
    let reason: String?
}

struct ConductorCard: Codable, Identifiable {
    let id: String
    let import_run_id: String?
    let record_id: String?
    let source_issue_id: String?
    let card_type: String
    let severity: String
    let status: String
    let title: String
    let summary: String?
    let detail: JSONValue
    let confidence: Double
    let auto_action: String
    let resolution: String?
    let resolution_detail: JSONValue?
    let dedupe_key: String
    let created_at: String?
    let updated_at: String?
    let resolved_at: String?
}

struct ConductorCardAction: Codable, Identifiable {
    let id: String
    let card_id: String
    let actor_type: String
    let actor_id: String?
    let action_type: String
    let payload: JSONValue
    let created_at: String?
}

struct ConductorQualitySnapshot: Codable, Identifiable {
    let id: String
    let status: String
    let window_days: Int
    let drift_ratio: Double
    let unresolved_medium: Int
    let unresolved_high: Int
    let unresolved_critical: Int
    let metrics: JSONValue
    let reasons: [String]
    let trigger: String
    let created_at: String?
}

enum JSONValue: Codable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
            return
        }
        if let boolValue = try? container.decode(Bool.self) {
            self = .bool(boolValue)
            return
        }
        if let intValue = try? container.decode(Int.self) {
            self = .number(Double(intValue))
            return
        }
        if let doubleValue = try? container.decode(Double.self) {
            self = .number(doubleValue)
            return
        }
        if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
            return
        }
        if let objectValue = try? container.decode([String: JSONValue].self) {
            self = .object(objectValue)
            return
        }
        if let arrayValue = try? container.decode([JSONValue].self) {
            self = .array(arrayValue)
            return
        }

        throw DecodingError.typeMismatch(
            JSONValue.self,
            DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unsupported JSON value")
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }

    var prettyPrinted: String {
        let object: Any
        switch self {
        case .string(let value): object = value
        case .number(let value): object = value
        case .bool(let value): object = value
        case .object(let value): object = value.mapValues { $0.toJSONObject() }
        case .array(let value): object = value.map { $0.toJSONObject() }
        case .null: object = NSNull()
        }
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
              let output = String(data: data, encoding: .utf8) else {
            switch self {
            case .string(let value): return value
            case .number(let value): return String(value)
            case .bool(let value): return String(value)
            case .null: return "null"
            case .object, .array: return ""
            }
        }
        return output
    }

    private func toJSONObject() -> Any {
        switch self {
        case .string(let value):
            return value
        case .number(let value):
            return value
        case .bool(let value):
            return value
        case .object(let value):
            return value.mapValues { $0.toJSONObject() }
        case .array(let value):
            return value.map { $0.toJSONObject() }
        case .null:
            return NSNull()
        }
    }
}

struct UploadInitiateResponse: Codable {
    let uploadId: String
    let uploadUrl: String
    let headers: [String: String]
}

struct UploadCompleteResponse: Codable {
    let upload: UploadRecord
}

struct UploadRecord: Codable {
    let id: String
}
