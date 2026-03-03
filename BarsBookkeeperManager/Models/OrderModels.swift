import Foundation

struct VendorContact: Codable, Identifiable {
    let id: String
    let vendor_name: String
    let email: String
    let phone: String?
    let notes: String?
    let created_at: String
    let updated_at: String
}

struct OrderItem: Codable {
    let skuId: String
    let name: String
    let unit: String
    let onHand: Double
    let recommendedQty: Double
    let runOutAt: String?
}

struct OrderDraft: Codable, Identifiable {
    let id: String
    let vendor_name: String
    let vendor_email: String?
    let status: OrderStatus
    let items: [OrderItem]
    let email_subject: String
    let email_body: String
    let ai_generated: Bool
    let sent_at: String?
    let response: String?
    let created_at: String
    let updated_at: String?
}

enum OrderStatus: String, Codable {
    case draft
    case pending_review
    case sent
    case confirmed
    case cancelled

    var displayName: String {
        switch self {
        case .draft: return "Draft"
        case .pending_review: return "Review"
        case .sent: return "Sent"
        case .confirmed: return "Confirmed"
        case .cancelled: return "Cancelled"
        }
    }
}

struct VendorsResponse: Codable {
    let vendors: [VendorContact]
}

struct OrdersResponse: Codable {
    let orders: [OrderDraft]
}

struct GenerateOrdersResponse: Codable {
    let orders: [OrderDraft]
    let urgentCount: Int?
    let standardCount: Int?
    let message: String?
    let qualityGate: ConductorQualitySnapshot?
}

struct SendOrderResponse: Codable {
    let orderId: String
    let vendorName: String
    let vendorEmail: String
    let subject: String
    let sentAt: String
    let demo: Bool
    let message: String
}

struct OrderUpdateResponse: Codable {
    let order: OrderDraft
}

struct VendorCreateResponse: Codable {
    let vendor: VendorContact
}
