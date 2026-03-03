import Foundation

struct OnHandItem: Codable, Identifiable {
    let sku_id: String
    let name: String
    let unit: String
    let category_name: String?
    let on_hand: Double
    let par_level: Double?
    let lead_time_days: Int?
    let icon: String?

    var id: String { sku_id }

    var statusLevel: StockStatus {
        guard let par = par_level, par > 0 else { return .unknown }
        let ratio = on_hand / par
        if ratio <= 0 { return .out }
        if ratio < 0.3 { return .critical }
        if ratio < 0.7 { return .low }
        return .good
    }
}

enum StockStatus: String {
    case good = "Good"
    case low = "Low"
    case critical = "Critical"
    case out = "Out"
    case unknown = "—"

    var sortOrder: Int {
        switch self {
        case .out: return 0
        case .critical: return 1
        case .low: return 2
        case .good: return 3
        case .unknown: return 4
        }
    }
}

struct OnHandResponse: Codable {
    let onHand: [OnHandItem]
}

struct SkuItem: Codable, Identifiable {
    let id: String
    let name: String
    let unit: String
    let category_id: String?
    let par_level: Double?
    let lead_time_days: Int?
    let icon: String?
    let created_at: String?
}
