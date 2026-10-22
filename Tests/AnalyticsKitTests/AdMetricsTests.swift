import XCTest
@testable import AnalyticsKit

@MainActor
final class AdMetricsTests: XCTestCase {
    private func impression(_ value: String, format: String = "interstitial") -> AdImpression {
        AdImpression(value: Decimal(string: value)!, currency: "USD", source: "AdMob Network", format: format, adUnitID: "unit", placement: "level_end", precision: "precise")
    }

    func testAdImpressionUsesFirebaseRevenueParameters() {
        let harness = Harness()
        harness.analytics.trackAdImpression(impression("0.004"))

        let event = harness.provider.last("ad_impression")
        XCTAssertEqual(event?[AnalyticsParameter.adPlatform], "AdMob")
        XCTAssertEqual(event?[AnalyticsParameter.adSource], "AdMob Network")
        XCTAssertEqual(event?[AnalyticsParameter.adFormat], "interstitial")
        XCTAssertEqual(event?[AnalyticsParameter.adUnitName], "unit")
        XCTAssertEqual(event?[AnalyticsParameter.value], 0.004)
        XCTAssertEqual(event?[AnalyticsParameter.currency], "USD")
    }

    func testRevenueThresholdEventFiresWhenAccumulated() {
        let harness = Harness()
        harness.analytics.trackAdImpression(impression("0.004"))
        harness.analytics.trackAdImpression(impression("0.004"))
        XCTAssertTrue(harness.provider.events(named: "total_ads_revenue_001").isEmpty)

        harness.analytics.trackAdImpression(impression("0.004"))
        let threshold = harness.provider.events(named: "total_ads_revenue_001")
        XCTAssertEqual(threshold.count, 1)
        XCTAssertEqual(threshold.first?[AnalyticsParameter.value]?.doubleValue ?? 0, 0.012, accuracy: 0.000001)
        XCTAssertEqual(harness.analytics.state.pendingAdRevenue, 0)
    }

    func testThresholdCanBeDisabled() {
        let harness = Harness(configuration: AnalyticsConfiguration(adRevenueThreshold: nil))
        harness.analytics.trackAdImpression(impression("1"))
        XCTAssertTrue(harness.provider.events(named: "total_ads_revenue_001").isEmpty)
    }

    func testAdLTVAndMonetizationProperties() {
        let harness = Harness()
        for _ in 0..<12 { harness.analytics.trackAdImpression(impression("0.02")) }

        let metrics = harness.analytics.metrics
        XCTAssertEqual(metrics.adImpressions, 12)
        XCTAssertEqual(metrics.adRevenue, Decimal(string: "0.24"))
        XCTAssertEqual(metrics.averageECPM, 20)
        XCTAssertEqual(harness.provider.userProperties[AnalyticsUserProperty.adLTVBucket], "0.1-0.5")
        XCTAssertEqual(harness.provider.userProperties[AnalyticsUserProperty.adImpressionBucket], "11-50")
        XCTAssertEqual(harness.provider.userProperties[AnalyticsUserProperty.monetization], "ads_only")

        harness.analytics.trackPurchase(subscription("1"))
        XCTAssertEqual(harness.provider.userProperties[AnalyticsUserProperty.monetization], "hybrid")
    }

    func testAdFunnelEvents() {
        let harness = Harness()
        let analytics = harness.analytics
        analytics.trackAdRequest(format: "rewarded", adUnitID: "unit")
        analytics.trackAdLoaded(format: "rewarded", adUnitID: "unit", latency: 1.2345)
        analytics.trackAdOpportunity(format: "rewarded", placement: "revive", outcome: .shown)
        analytics.trackAdShown(format: "rewarded", placement: "revive")
        analytics.trackAdClick(format: "rewarded", placement: "revive")
        analytics.trackAdReward(placement: "revive", type: "coins", amount: 10)
        analytics.trackAdOpportunity(format: "interstitial", placement: "level_end", outcome: .blocked(reason: "too_soon"))

        XCTAssertEqual(harness.provider.events.map(\.name), ["ad_request", "ad_load_success", "ad_opportunity", "ad_show", "ad_clicked", "ad_reward_earned", "ad_opportunity"])
        XCTAssertEqual(harness.provider.last("ad_load_success")?[AnalyticsParameter.latencyMs], 1235)
        XCTAssertEqual(harness.provider.last("ad_opportunity")?[AnalyticsParameter.result], "blocked")
        XCTAssertEqual(harness.provider.last("ad_opportunity")?[AnalyticsParameter.reason], "too_soon")
    }
}
