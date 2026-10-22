import AdKit
import AnalyticsKit
import AnalyticsKitAdKit
import XCTest

@MainActor
final class StubNetwork: AdNetwork {
    let name = "Stub"
    func start(audience: AdAudience, testDeviceIDs: [String]) async {}
    func loadFullScreenAd(_ format: AdFormat, adUnitID: String) async throws -> FullScreenAd {
        throw URLError(.notConnectedToInternet)
    }
    #if canImport(UIKit)
    func makeBannerAd(adUnitID: String) -> BannerAd { fatalError("unused") }
    #endif
}

@MainActor
final class AdKitBridgeTests: XCTestCase {
    private var provider: InMemoryAnalyticsProvider!
    private var analytics: AnalyticsManager!

    override func setUp() async throws {
        provider = InMemoryAnalyticsProvider()
        analytics = AnalyticsManager(
            configuration: AnalyticsConfiguration(observesAppLifecycle: false),
            providers: [provider],
            store: InMemoryAnalyticsStateStore()
        )
    }

    func testRevenueBecomesAdImpression() {
        let revenue = AdRevenue(value: 0.015, currencyCode: "USD", precision: .precise, format: .appOpen, placement: "app_open", adUnitID: "unit", adSourceName: "AppLovin")
        analytics.track(AdEvent.revenue(revenue))

        let event = provider.last("ad_impression")
        XCTAssertEqual(event?[AnalyticsParameter.adFormat], "app_open")
        XCTAssertEqual(event?[AnalyticsParameter.adSource], "AppLovin")
        XCTAssertEqual(event?[AnalyticsParameter.precision], "precise")
        XCTAssertEqual(event?[AnalyticsParameter.value], 0.015)
        XCTAssertEqual(provider.events(named: "total_ads_revenue_001").count, 1)
    }

    func testOpportunityOutcomes() {
        analytics.track(AdEvent.shown(.interstitial, placement: "level_end"))
        analytics.track(AdEvent.blocked(.interstitial, placement: "level_end", reason: .notLoaded))
        analytics.track(AdEvent.blocked(.interstitial, placement: "level_end", reason: .tooSoon(remaining: 20)))

        let results = provider.events(named: "ad_opportunity").compactMap { $0[AnalyticsParameter.result]?.stringValue }
        XCTAssertEqual(results, ["shown", "not_ready", "blocked"])
        XCTAssertEqual(provider.last("ad_opportunity")?[AnalyticsParameter.reason], "too_soon")
        XCTAssertEqual(provider.events(named: "ad_show").count, 1)
    }

    func testConsentAndTrackingBecomeUserProperties() {
        analytics.track(AdEvent.consentGathered(.obtained))
        analytics.track(AdEvent.trackingAuthorization(.denied))

        XCTAssertEqual(provider.userProperties["ad_consent"], "obtained")
        XCTAssertEqual(provider.userProperties["att_status"], "denied")
    }

    func testConnectKeepsExistingHandler() {
        let ads = AdManager(
            configuration: AdConfiguration(adUnitIDs: AdUnitIDs(), requestsTrackingAuthorization: false),
            network: StubNetwork(),
            store: InMemoryAdHistoryStore()
        )
        var forwarded = 0
        ads.eventHandler = { _ in forwarded += 1 }
        analytics.connect(ads)

        ads.eventHandler?(.clicked(.banner, placement: "banner"))
        ads.eventHandler?(.rewarded(AdReward(type: "coins", amount: 5), placement: "revive"))

        XCTAssertEqual(forwarded, 2)
        XCTAssertEqual(provider.events.map(\.name), ["ad_clicked", "ad_reward_earned"])
    }
}
