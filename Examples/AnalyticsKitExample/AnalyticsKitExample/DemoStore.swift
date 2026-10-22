import AnalyticsKit
import Foundation

enum DemoProduct {
    static let monthly = "premium.monthly"
    static let lifetime = "premium.lifetime"
    static let coins = "coins.500"
}

final class DemoClock: AnalyticsClock, @unchecked Sendable {
    var offset: TimeInterval = 0
    var now: Date { Date().addingTimeInterval(offset) }
}

@MainActor
final class DemoStore: ObservableObject {
    @Published private(set) var subscriptionID: String?
    @Published private(set) var lastTransaction: PurchaseRecord?
    @Published private(set) var simulatedDay = 0

    let isFirebaseConfigured: Bool
    private let analytics: AnalyticsManager
    private let log: InMemoryAnalyticsProvider
    private let clock: DemoClock
    private var nextTransactionID = Int(Date().timeIntervalSince1970)

    init(analytics: AnalyticsManager, log: InMemoryAnalyticsProvider, clock: DemoClock, isFirebaseConfigured: Bool) {
        self.analytics = analytics
        self.log = log
        self.clock = clock
        self.isFirebaseConfigured = isFirebaseConfigured
    }

    func nextDay() {
        analytics.appDidEnterBackground()
        clock.offset += 86_400
        simulatedDay += 1
        analytics.appDidBecomeActive()
    }

    func runOnboarding() {
        ["welcome", "pick_goal", "notifications"].enumerated().forEach { index, name in
            analytics.trackOnboardingStep(index + 1, name: name)
        }
        analytics.trackOnboardingComplete()
    }

    func startTrial() {
        analytics.trackPaywallView("main", placement: "onboarding", variant: "a")
        analytics.trackPurchaseStart(productID: DemoProduct.monthly, placement: "onboarding")
        let id = makeID()
        record(PurchaseRecord(transactionID: id, productID: DemoProduct.monthly, productType: .autoRenewable, price: 0, currency: "USD", purchaseDate: clock.now, expirationDate: clock.now.addingTimeInterval(3 * 86_400), isTrial: true, offerType: "introductory", environment: .xcode, placement: "onboarding"))
        subscriptionID = id
        analytics.trackPaywallClose("main", placement: "onboarding", purchased: true)
    }

    func renewSubscription() {
        guard let subscriptionID else { return startPaidSubscription() }
        record(PurchaseRecord(transactionID: makeID(), originalTransactionID: subscriptionID, productID: DemoProduct.monthly, productType: .autoRenewable, price: 9.99, currency: "USD", purchaseDate: clock.now, expirationDate: clock.now.addingTimeInterval(30 * 86_400), environment: .xcode))
    }

    func startPaidSubscription() {
        let id = makeID()
        record(PurchaseRecord(transactionID: id, productID: DemoProduct.monthly, productType: .autoRenewable, price: 9.99, currency: "USD", purchaseDate: clock.now, expirationDate: clock.now.addingTimeInterval(30 * 86_400), environment: .xcode, placement: "settings"))
        subscriptionID = id
    }

    func updateSubscription(_ state: SubscriptionState, autoRenew: Bool) {
        guard let subscriptionID else { return }
        analytics.updateSubscriptionStatus(SubscriptionStatusRecord(productID: DemoProduct.monthly, originalTransactionID: subscriptionID, state: state, willAutoRenew: autoRenew))
    }

    func buyCoins() {
        record(PurchaseRecord(transactionID: makeID(), productID: DemoProduct.coins, productType: .consumable, price: 4.99, currency: "EUR", purchaseDate: clock.now, environment: .xcode, placement: "shop"))
    }

    func buyLifetime() {
        record(PurchaseRecord(transactionID: makeID(), productID: DemoProduct.lifetime, productType: .nonConsumable, price: 29.99, currency: "USD", purchaseDate: clock.now, environment: .xcode, placement: "paywall"))
    }

    func cancelPurchase() {
        analytics.trackPaywallView("main", placement: "settings")
        analytics.trackPurchaseStart(productID: DemoProduct.monthly, placement: "settings")
        analytics.trackPurchaseCancel(productID: DemoProduct.monthly, placement: "settings")
        analytics.trackPaywallClose("main", placement: "settings", purchased: false)
    }

    func refundLast() {
        guard var transaction = lastTransaction else { return }
        transaction.isRevoked = true
        analytics.trackPurchase(transaction)
    }

    func showInterstitial() {
        analytics.trackAdOpportunity(format: "interstitial", placement: "level_end", outcome: .shown)
        analytics.trackAdShown(format: "interstitial", placement: "level_end")
        analytics.trackAdImpression(randomImpression(format: "interstitial", placement: "level_end", range: 0.004...0.03))
    }

    func showRewarded() {
        analytics.trackAdOpportunity(format: "rewarded", placement: "double_coins", outcome: .shown)
        analytics.trackAdShown(format: "rewarded", placement: "double_coins")
        analytics.trackAdImpression(randomImpression(format: "rewarded", placement: "double_coins", range: 0.01...0.05))
        analytics.trackAdReward(placement: "double_coins", type: "coins", amount: 100)
    }

    func showBanner() {
        analytics.trackAdImpression(randomImpression(format: "banner", placement: "home", range: 0.0002...0.002))
    }

    func clickAd() {
        analytics.trackAdClick(format: "interstitial", placement: "level_end")
    }

    func blockAd() {
        analytics.trackAdOpportunity(format: "interstitial", placement: "level_end", outcome: .blocked(reason: "too_soon"))
    }

    func missAd() {
        analytics.trackAdRequest(format: "interstitial", adUnitID: "demo/interstitial")
        analytics.trackAdLoadFailed(format: "interstitial", adUnitID: "demo/interstitial", error: "No fill", latency: 2.4)
        analytics.trackAdOpportunity(format: "interstitial", placement: "level_end", outcome: .notReady)
    }

    func resetAll() {
        clock.offset = 0
        simulatedDay = 0
        subscriptionID = nil
        lastTransaction = nil
        log.reset()
        analytics.reset()
    }

    private func record(_ transaction: PurchaseRecord) {
        analytics.trackPurchase(transaction)
        lastTransaction = transaction
    }

    private func makeID() -> String {
        nextTransactionID += 1
        return String(nextTransactionID)
    }

    private func randomImpression(format: String, placement: String, range: ClosedRange<Double>) -> AdImpression {
        let value = (Decimal(Double.random(in: range)) * 1_000_000).rounded() / 1_000_000
        return AdImpression(value: value, currency: "USD", source: ["AdMob Network", "AppLovin", "Meta Audience Network"].randomElement(), format: format, adUnitID: "demo/\(format)", placement: placement, precision: "precise")
    }
}

private extension Decimal {
    func rounded() -> Decimal {
        var source = self
        var result = Decimal()
        NSDecimalRound(&result, &source, 0, .plain)
        return result
    }
}
