import Foundation

public struct AnalyticsConfiguration: Sendable {
    public var reportingCurrency: String
    public var exchangeRates: [String: Decimal]
    public var adRevenueThreshold: Decimal?
    public var adRevenueThresholdEventName: String
    public var retentionDays: Set<Int>
    public var sessionTimeout: TimeInterval
    public var ltvBuckets: [Decimal]
    public var sessionBuckets: [Int]
    public var impressionBuckets: [Int]
    public var countsSandboxRevenue: Bool
    public var lifetimeProductIDs: Set<String>
    public var observesAppLifecycle: Bool
    public var isLoggingEnabled: Bool
    public var calendar: Calendar

    public init(
        reportingCurrency: String = "USD",
        exchangeRates: [String: Decimal] = [:],
        adRevenueThreshold: Decimal? = 0.01,
        adRevenueThresholdEventName: String = "total_ads_revenue_001",
        retentionDays: Set<Int> = [1, 3, 7, 14, 30],
        sessionTimeout: TimeInterval = 30 * 60,
        ltvBuckets: [Decimal] = [0.1, 0.5, 1, 5, 20, 50, 100],
        sessionBuckets: [Int] = [1, 3, 7, 15, 30, 60],
        impressionBuckets: [Int] = [1, 10, 50, 100, 500, 1000],
        countsSandboxRevenue: Bool = false,
        lifetimeProductIDs: Set<String> = [],
        observesAppLifecycle: Bool = true,
        isLoggingEnabled: Bool = false,
        calendar: Calendar = .current
    ) {
        self.reportingCurrency = reportingCurrency.uppercased()
        self.exchangeRates = exchangeRates
        self.adRevenueThreshold = adRevenueThreshold
        self.adRevenueThresholdEventName = adRevenueThresholdEventName
        self.retentionDays = retentionDays
        self.sessionTimeout = sessionTimeout
        self.ltvBuckets = ltvBuckets.sorted()
        self.sessionBuckets = sessionBuckets.sorted()
        self.impressionBuckets = impressionBuckets.sorted()
        self.countsSandboxRevenue = countsSandboxRevenue
        self.lifetimeProductIDs = lifetimeProductIDs
        self.observesAppLifecycle = observesAppLifecycle
        self.isLoggingEnabled = isLoggingEnabled
        self.calendar = calendar
    }

    public func convertToReporting(_ amount: Decimal, currency: String) -> Decimal? {
        let code = currency.uppercased()
        if code == reportingCurrency { return amount }
        guard let rate = exchangeRates[code] else { return nil }
        return amount * rate
    }
}

public protocol AnalyticsClock: Sendable {
    var now: Date { get }
}

public struct SystemAnalyticsClock: AnalyticsClock {
    public init() {}
    public var now: Date { Date() }
}

public enum AnalyticsBucket {
    public static func label(for value: Decimal, edges: [Decimal]) -> String {
        guard value > 0 else { return "0" }
        var lower: Decimal = 0
        for edge in edges {
            if value < edge { return "\(format(lower))-\(format(edge))" }
            lower = edge
        }
        return "\(format(lower))+"
    }

    public static func label(for value: Int, edges: [Int]) -> String {
        guard value > 0 else { return "0" }
        var lower = 0
        for edge in edges {
            if value <= edge { return lower + 1 == edge ? "\(edge)" : "\(lower + 1)-\(edge)" }
            lower = edge
        }
        return "\(lower + 1)+"
    }

    private static func format(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).stringValue
    }
}
