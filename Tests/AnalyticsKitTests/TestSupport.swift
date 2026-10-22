import Foundation
@testable import AnalyticsKit

final class TestClock: AnalyticsClock, @unchecked Sendable {
    var now: Date

    init(_ now: Date = Date(timeIntervalSince1970: 1_790_000_000)) {
        self.now = now
    }

    func advance(days: Int = 0, seconds: TimeInterval = 0) {
        now = now.addingTimeInterval(TimeInterval(days) * 86_400 + seconds)
    }
}

extension Calendar {
    static var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }
}

@MainActor
struct Harness {
    let clock = TestClock()
    let store = InMemoryAnalyticsStateStore()
    let provider = InMemoryAnalyticsProvider()
    let analytics: AnalyticsManager

    init(configuration: AnalyticsConfiguration = AnalyticsConfiguration()) {
        var configuration = configuration
        configuration.calendar = .utc
        configuration.observesAppLifecycle = false
        analytics = AnalyticsManager(configuration: configuration, providers: [provider], store: store, clock: clock)
    }

    func newSession(afterDays days: Int) {
        analytics.appDidEnterBackground()
        clock.advance(days: days)
        analytics.appDidBecomeActive()
    }
}

func subscription(
    _ id: String,
    original: String? = nil,
    product: String = "premium.monthly",
    price: Decimal = 9.99,
    trial: Bool = false,
    environment: PurchaseEnvironment = .production,
    revoked: Bool = false
) -> PurchaseRecord {
    PurchaseRecord(
        transactionID: id,
        originalTransactionID: original,
        productID: product,
        productType: .autoRenewable,
        price: trial ? 0 : price,
        currency: "USD",
        expirationDate: Date(timeIntervalSince1970: 1_790_000_000 + 30 * 86_400),
        isTrial: trial,
        isRevoked: revoked,
        environment: environment
    )
}
