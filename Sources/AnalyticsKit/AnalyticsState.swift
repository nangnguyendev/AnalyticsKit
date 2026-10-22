import Foundation

public struct SubscriptionSnapshot: Codable, Equatable, Sendable {
    public var productID: String
    public var isTrial: Bool
    public var state: SubscriptionState
    public var willAutoRenew: Bool?
    public var expirationDate: Date?
}

public struct AnalyticsState: Codable, Equatable, Sendable {
    public var installDate: Date?
    public var sessionCount = 0
    public var activeDayCount = 0
    public var lastActiveDay: Int?
    public var loggedRetentionDays: Set<Int> = []
    public var adRevenue: [String: Decimal] = [:]
    public var iapRevenue: [String: Decimal] = [:]
    public var pendingAdRevenue: Decimal = 0
    public var adImpressions = 0
    public var processedTransactions: [String] = []
    public var subscriptions: [String: SubscriptionSnapshot] = [:]
    public var hasLifetimeAccess = false

    public init() {}

    static let processedTransactionLimit = 1000

    mutating func markProcessed(_ key: String) {
        processedTransactions.append(key)
        if processedTransactions.count > Self.processedTransactionLimit {
            processedTransactions.removeFirst(processedTransactions.count - Self.processedTransactionLimit)
        }
    }

    func hasProcessed(_ key: String) -> Bool {
        processedTransactions.contains(key)
    }
}

public protocol AnalyticsStateStore: AnyObject {
    func load() -> AnalyticsState
    func save(_ state: AnalyticsState)
}

public final class UserDefaultsAnalyticsStateStore: AnalyticsStateStore {
    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String = "AnalyticsKit.state") {
        self.defaults = defaults
        self.key = key
    }

    public func load() -> AnalyticsState {
        guard let data = defaults.data(forKey: key),
              let state = try? JSONDecoder().decode(AnalyticsState.self, from: data) else { return AnalyticsState() }
        return state
    }

    public func save(_ state: AnalyticsState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: key)
    }
}

public final class InMemoryAnalyticsStateStore: AnalyticsStateStore {
    public var state: AnalyticsState

    public init(state: AnalyticsState = AnalyticsState()) {
        self.state = state
    }

    public func load() -> AnalyticsState { state }
    public func save(_ state: AnalyticsState) { self.state = state }
}
