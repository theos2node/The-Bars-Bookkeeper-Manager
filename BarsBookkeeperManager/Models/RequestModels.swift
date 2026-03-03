import Foundation

struct StockRequest: Codable, Identifiable {
    let id: String
    let item_name: String
    let item_icon: String?
    let quantity: Double
    let unit: String
    let status: RequestStatus
    let requester: String
    let requested_at: String
    let resolved_at: String?

    var requestedDate: Date? {
        ISO8601DateFormatter().date(from: requested_at)
    }

    var formattedDate: String {
        guard let date = requestedDate else { return requested_at }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

enum RequestStatus: String, Codable, CaseIterable {
    case pending
    case accepted
    case denied
}

struct RequestsResponse: Codable {
    let requests: [StockRequest]
}

struct RequestUpdateResponse: Codable {
    let request: StockRequest
}
