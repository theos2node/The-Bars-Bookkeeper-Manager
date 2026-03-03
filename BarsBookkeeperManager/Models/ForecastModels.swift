import Foundation

struct ForecastRun: Codable {
    let id: String
    let run_at: String
    let horizon_days: Int
    let window_days: Int
}

struct ForecastRow: Codable, Identifiable {
    let id: String
    let sku_id: String
    let name: String
    let unit: String
    let par_level: Double?
    let lead_time_days: Int?
    let on_hand: Double
    let avg_daily_usage: Double
    let smoothed_level: Double
    let trend_slope: Double
    let alpha: Double
    let shrink_rate: Double
    let target_level: Double?
    let reference_weekly_par: Double?
    let learned_weekly_par: Double?
    let effective_weekly_par: Double?
    let par_period_days: Int?
    let run_out_at: String?
    let recommended_order_qty: Double?
    let category_name: String?

    var predictionStatus: PredictionStatus {
        if on_hand <= 0 { return .out }
        guard avg_daily_usage > 0 else { return .good }
        let daysLeft = on_hand / avg_daily_usage
        if daysLeft <= 2 { return .out }
        if daysLeft <= 5 { return .low }
        return .good
    }

    var daysUntilRunOut: Double? {
        guard avg_daily_usage > 0 else { return nil }
        return on_hand / avg_daily_usage
    }

    var runOutDate: Date? {
        guard let dateStr = run_out_at else { return nil }
        return ISO8601DateFormatter().date(from: dateStr)
    }

    var formattedRunOut: String {
        guard let date = runOutDate else { return "—" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

enum PredictionStatus: String {
    case good = "Good"
    case low = "Low"
    case out = "Out"
}

struct ForecastResponse: Codable {
    let run: ForecastRun?
    let forecasts: [ForecastRow]
    let qualityGate: ConductorQualitySnapshot?
}
