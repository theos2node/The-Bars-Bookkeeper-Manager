import Foundation

struct OnHandItem: Codable, Identifiable {
    let sku_id: String
    let name: String
    let unit: String
    let category_name: String?
    let on_hand: Double
    let par_level: Double?
    let effective_weekly_par: Double?
    let lead_time_days: Int?
    let icon: String?

    var id: String { sku_id }

    var displayPar: Double? {
        effective_weekly_par ?? par_level
    }

    var statusLevel: StockStatus {
        guard let par = displayPar, par > 0 else { return .unknown }
        let ratio = on_hand / par
        if ratio <= 0 { return .out }
        if ratio < 0.3 { return .critical }
        if ratio < 0.7 { return .low }
        return .good
    }

    func withEffectiveWeeklyPar(_ value: Double) -> OnHandItem {
        OnHandItem(
            sku_id: sku_id,
            name: name,
            unit: unit,
            category_name: category_name,
            on_hand: on_hand,
            par_level: par_level,
            effective_weekly_par: value,
            lead_time_days: lead_time_days,
            icon: icon
        )
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
