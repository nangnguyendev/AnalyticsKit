import XCTest
@testable import AnalyticsKit

@MainActor
final class RevenueTests: XCTestCase {
    func testTrialConvertsThenRenews() {
        let harness = Harness()
        let analytics = harness.analytics

        XCTAssertEqual(analytics.trackPurchase(subscription("1", trial: true)), .trialStart)
        XCTAssertEqual(analytics.userTier, .trial)
        XCTAssertEqual(harness.provider.userProperties[AnalyticsUserProperty.isPayer], "false")

        XCTAssertEqual(analytics.trackPurchase(subscription("2", original: "1")), .trialConvert)
        XCTAssertEqual(analytics.userTier, .subscriber)
        XCTAssertEqual(harness.provider.last("trial_convert")?[AnalyticsParameter.value], 9.99)
        XCTAssertEqual(harness.provider.last("trial_convert")?[AnalyticsParameter.currency], "USD")

        XCTAssertEqual(analytics.trackPurchase(subscription("3", original: "1")), .subscriptionRenew)
        XCTAssertEqual(analytics.metrics.iapRevenue, Decimal(string: "19.98"))
        XCTAssertEqual(harness.provider.userProperties[AnalyticsUserProperty.isPayer], "true")
        XCTAssertEqual(harness.provider.userProperties[AnalyticsUserProperty.monetization], "iap_only")
        XCTAssertEqual(harness.provider.userProperties[AnalyticsUserProperty.iapLTVBucket], "5-20")
    }

    func testDuplicateTransactionsAreIgnored() {
        let harness = Harness()
        harness.analytics.trackPurchase(subscription("10"))

        XCTAssertEqual(harness.analytics.trackPurchase(subscription("10")), .duplicate)
        XCTAssertEqual(harness.provider.events(named: "subscription_start").count, 1)
        XCTAssertEqual(harness.analytics.metrics.iapRevenue, Decimal(string: "9.99"))
    }

    func testRefundRevokesAccessAndRevenue() {
        let harness = Harness()
        harness.analytics.trackPurchase(subscription("20"))

        XCTAssertEqual(harness.analytics.trackPurchase(subscription("20", revoked: true)), .refund)
        XCTAssertEqual(harness.analytics.trackPurchase(subscription("20", revoked: true)), .duplicate)
        XCTAssertEqual(harness.provider.events(named: "iap_refund").count, 1)
        XCTAssertEqual(harness.analytics.metrics.iapRevenue, 0)
        XCTAssertEqual(harness.analytics.userTier, .lapsed)
    }

    func testSandboxRevenueIsNotCountedByDefault() {
        let harness = Harness()
        harness.analytics.trackPurchase(subscription("30", environment: .sandbox))

        XCTAssertEqual(harness.provider.events(named: "subscription_start").count, 1)
        XCTAssertEqual(harness.provider.last("subscription_start")?[AnalyticsParameter.environment], "sandbox")
        XCTAssertEqual(harness.analytics.metrics.iapRevenue, 0)

        let counting = Harness(configuration: AnalyticsConfiguration(countsSandboxRevenue: true))
        counting.analytics.trackPurchase(subscription("30", environment: .sandbox))
        XCTAssertEqual(counting.analytics.metrics.iapRevenue, Decimal(string: "9.99"))
    }

    func testLifetimeAndConsumablePurchases() {
        let harness = Harness(configuration: AnalyticsConfiguration(lifetimeProductIDs: ["premium.lifetime"]))
        let coins = PurchaseRecord(transactionID: "40", productID: "coins.100", productType: .consumable, price: 0.99, currency: "USD", quantity: 3)
        let lifetime = PurchaseRecord(transactionID: "41", productID: "premium.lifetime", productType: .nonConsumable, price: 29.99, currency: "USD")

        XCTAssertEqual(harness.analytics.trackPurchase(coins), .iapPurchase)
        XCTAssertEqual(harness.analytics.userTier, .free)
        XCTAssertEqual(harness.analytics.trackPurchase(lifetime), .iapPurchase)
        XCTAssertEqual(harness.analytics.userTier, .lifetime)
        XCTAssertEqual(harness.analytics.metrics.iapRevenue, Decimal(string: "32.96"))
    }

    func testForeignCurrencyUsesExchangeRates() {
        let harness = Harness(configuration: AnalyticsConfiguration(exchangeRates: ["EUR": Decimal(string: "1.1")!]))
        harness.analytics.trackPurchase(PurchaseRecord(transactionID: "50", productID: "coins", productType: .consumable, price: 10, currency: "eur"))
        harness.analytics.trackPurchase(PurchaseRecord(transactionID: "51", productID: "coins", productType: .consumable, price: 100, currency: "VND"))

        XCTAssertEqual(harness.analytics.state.iapRevenue["EUR"], 10)
        XCTAssertEqual(harness.analytics.metrics.iapRevenue, 11)
    }

    func testSubscriptionStatusLifecycle() {
        let harness = Harness()
        let analytics = harness.analytics
        analytics.trackPurchase(subscription("60"))

        func status(_ state: SubscriptionState, autoRenew: Bool) -> SubscriptionStatusRecord {
            SubscriptionStatusRecord(productID: "premium.monthly", originalTransactionID: "60", state: state, willAutoRenew: autoRenew)
        }

        analytics.updateSubscriptionStatus(status(.active, autoRenew: false))
        analytics.updateSubscriptionStatus(status(.active, autoRenew: false))
        XCTAssertEqual(harness.provider.events(named: "subscription_cancel").count, 1)
        XCTAssertEqual(harness.provider.userProperties[AnalyticsUserProperty.autoRenew], "false")
        XCTAssertEqual(analytics.userTier, .subscriber)

        analytics.updateSubscriptionStatus(status(.active, autoRenew: true))
        XCTAssertEqual(harness.provider.events(named: "subscription_reactivate").count, 1)

        analytics.updateSubscriptionStatus(status(.inBillingRetry, autoRenew: true))
        XCTAssertEqual(harness.provider.events(named: "subscription_billing_issue").count, 1)
        XCTAssertEqual(analytics.userTier, .billingIssue)

        analytics.updateSubscriptionStatus(status(.expired, autoRenew: false))
        analytics.updateSubscriptionStatus(status(.expired, autoRenew: false))
        XCTAssertEqual(harness.provider.events(named: "subscription_expire").count, 1)
        XCTAssertEqual(analytics.userTier, .lapsed)
    }

    func testPaywallFunnel() {
        let harness = Harness()
        harness.analytics.trackPaywallView("main", placement: "onboarding", variant: "a")
        harness.analytics.trackPurchaseStart(productID: "premium.monthly", placement: "onboarding")
        harness.analytics.trackPurchaseCancel(productID: "premium.monthly", placement: "onboarding")
        harness.analytics.trackPaywallClose("main", placement: "onboarding", purchased: false)

        XCTAssertEqual(harness.provider.events.map(\.name), ["paywall_view", "purchase_start", "purchase_cancel", "paywall_close"])
        XCTAssertEqual(harness.provider.last("paywall_close")?[AnalyticsParameter.purchased], 0)
    }
}
