import Foundation

public enum AnalyticsLimits {
    public static let maxEventNameLength = 40
    public static let maxParameterNameLength = 40
    public static let maxParameterStringLength = 100
    public static let maxParametersPerEvent = 25
    public static let maxUserPropertyNameLength = 24
    public static let maxUserPropertyValueLength = 36
    public static let maxUserIDLength = 256

    public static let reservedPrefixes = ["firebase_", "google_", "ga_"]

    public static let reservedEventNames: Set<String> = [
        "ad_activeview", "ad_click", "ad_exposure", "ad_query", "ad_reward", "adunit_exposure",
        "app_background", "app_clear_data", "app_exception", "app_remove", "app_store_refund",
        "app_store_subscription_cancel", "app_store_subscription_convert", "app_store_subscription_renew",
        "app_update", "app_upgrade", "dynamic_link_app_open", "dynamic_link_app_update",
        "dynamic_link_first_open", "error", "first_open", "first_visit", "in_app_purchase",
        "notification_dismiss", "notification_foreground", "notification_open", "notification_receive",
        "os_update", "session_start", "session_start_with_rollout", "user_engagement"
    ]

    public static let reservedUserPropertyNames: Set<String> = [
        "first_open_after_install", "first_open_time", "first_visit_time", "last_deep_link_referrer", "user_id"
    ]
}

public struct AnalyticsSanitizer: Sendable {
    public init() {}

    public func sanitize(_ event: AnalyticsEvent, issues: inout [String]) -> AnalyticsEvent? {
        guard let name = identifier(event.name, maxLength: AnalyticsLimits.maxEventNameLength, issues: &issues) else { return nil }
        if AnalyticsLimits.reservedEventNames.contains(name) {
            issues.append("event \(name) is reserved by Firebase and was dropped")
            return nil
        }

        var parameters: [String: AnalyticsValue] = [:]
        for (key, value) in event.parameters.sorted(by: { $0.key < $1.key }) {
            guard let cleanKey = identifier(key, maxLength: AnalyticsLimits.maxParameterNameLength, issues: &issues) else { continue }
            if parameters.count == AnalyticsLimits.maxParametersPerEvent {
                issues.append("event \(name) has more than \(AnalyticsLimits.maxParametersPerEvent) parameters, dropped \(cleanKey)")
                continue
            }
            parameters[cleanKey] = clamp(value, issues: &issues, context: "\(name).\(cleanKey)")
        }

        var clean = AnalyticsEvent(name)
        clean.parameters = parameters
        return clean
    }

    public func sanitizeUserProperty(name: String, value: String?, issues: inout [String]) -> (name: String, value: String?)? {
        guard let cleanName = identifier(name, maxLength: AnalyticsLimits.maxUserPropertyNameLength, issues: &issues) else { return nil }
        if AnalyticsLimits.reservedUserPropertyNames.contains(cleanName) {
            issues.append("user property \(cleanName) is reserved by Firebase and was dropped")
            return nil
        }
        guard let value else { return (cleanName, nil) }
        if value.count > AnalyticsLimits.maxUserPropertyValueLength {
            issues.append("user property \(cleanName) value truncated to \(AnalyticsLimits.maxUserPropertyValueLength) characters")
            return (cleanName, String(value.prefix(AnalyticsLimits.maxUserPropertyValueLength)))
        }
        return (cleanName, value)
    }

    public func identifier(_ raw: String, maxLength: Int, issues: inout [String]) -> String? {
        var scalars = raw.unicodeScalars.map { scalar -> Character in
            let isAllowed = scalar.isASCII && (CharacterSet.alphanumerics.contains(scalar) || scalar == "_")
            return isAllowed ? Character(scalar) : "_"
        }
        while let first = scalars.first, !(first.isLetter && first.isASCII) {
            scalars.removeFirst()
        }
        var name = String(scalars)
        if name.isEmpty {
            issues.append("name \"\(raw)\" is empty after cleanup and was dropped")
            return nil
        }
        for prefix in AnalyticsLimits.reservedPrefixes where name.lowercased().hasPrefix(prefix) {
            issues.append("name \(name) uses reserved prefix \(prefix) and was dropped")
            return nil
        }
        if name.count > maxLength {
            name = String(name.prefix(maxLength))
            issues.append("name \(raw) truncated to \(name)")
        } else if name != raw {
            issues.append("name \(raw) renamed to \(name)")
        }
        return name
    }

    private func clamp(_ value: AnalyticsValue, issues: inout [String], context: String) -> AnalyticsValue {
        switch value {
        case .string(let string) where string.count > AnalyticsLimits.maxParameterStringLength:
            issues.append("\(context) truncated to \(AnalyticsLimits.maxParameterStringLength) characters")
            return .string(String(string.prefix(AnalyticsLimits.maxParameterStringLength)))
        case .double(let double) where !double.isFinite:
            issues.append("\(context) is not finite, replaced with 0")
            return .double(0)
        default:
            return value
        }
    }
}
