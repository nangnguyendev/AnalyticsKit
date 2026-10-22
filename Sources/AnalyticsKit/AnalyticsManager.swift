import Foundation
import os
#if canImport(UIKit)
import UIKit
#endif

public struct AnalyticsMetrics: Equatable, Sendable {
    public var currency: String
    public var adRevenue: Decimal
    public var iapRevenue: Decimal
    public var adImpressions: Int
    public var sessionCount: Int
    public var activeDayCount: Int
    public var daysSinceInstall: Int
    public var userTier: UserTier
    public var monetization: Monetization

    public var totalRevenue: Decimal { adRevenue + iapRevenue }
    public var averageECPM: Decimal { adImpressions == 0 ? 0 : adRevenue / Decimal(adImpressions) * 1000 }
}

@MainActor
public final class AnalyticsManager: ObservableObject {
    @Published public internal(set) var state: AnalyticsState
    @Published public private(set) var userTier: UserTier = .free
    @Published public private(set) var isStarted = false

    public let configuration: AnalyticsConfiguration
    public private(set) var providers: [AnalyticsProvider]

    public var eventHandler: ((AnalyticsEvent) -> Void)?
    public var issueHandler: ((String) -> Void)?

    private let store: AnalyticsStateStore
    private let clock: AnalyticsClock
    private let sanitizer = AnalyticsSanitizer()
    private let logger = Logger(subsystem: "AnalyticsKit", category: "AnalyticsManager")
    private var backgroundedAt: Date?
    private var lifecycleTasks: [Task<Void, Never>] = []

    public init(
        configuration: AnalyticsConfiguration = AnalyticsConfiguration(),
        providers: [AnalyticsProvider],
        store: AnalyticsStateStore = UserDefaultsAnalyticsStateStore(),
        clock: AnalyticsClock = SystemAnalyticsClock()
    ) {
        self.configuration = configuration
        self.providers = providers
        self.store = store
        self.clock = clock
        self.state = store.load()
        self.userTier = computeTier()
    }

    deinit {
        lifecycleTasks.forEach { $0.cancel() }
    }

    public func add(_ provider: AnalyticsProvider) {
        providers.append(provider)
    }

    public func start() {
        guard !isStarted else { return }
        isStarted = true
        if state.installDate == nil { state.installDate = clock.now }
        beginSession()
        refreshUserProperties()
        if configuration.observesAppLifecycle { observeLifecycle() }
    }

    public func appDidEnterBackground() {
        backgroundedAt = clock.now
    }

    public func appDidBecomeActive() {
        guard isStarted, let backgroundedAt else { return }
        self.backgroundedAt = nil
        if clock.now.timeIntervalSince(backgroundedAt) >= configuration.sessionTimeout {
            beginSession()
        }
    }

    public var metrics: AnalyticsMetrics {
        AnalyticsMetrics(
            currency: configuration.reportingCurrency,
            adRevenue: reportingTotal(state.adRevenue),
            iapRevenue: reportingTotal(state.iapRevenue),
            adImpressions: state.adImpressions,
            sessionCount: state.sessionCount,
            activeDayCount: state.activeDayCount,
            daysSinceInstall: daysSinceInstall(),
            userTier: userTier,
            monetization: monetization()
        )
    }

    public func reset() {
        state = AnalyticsState()
        state.installDate = clock.now
        store.save(state)
        userTier = computeTier()
        refreshUserProperties()
    }

    public func track(_ event: AnalyticsEvent) {
        var issues: [String] = []
        let clean = sanitizer.sanitize(event, issues: &issues)
        report(issues)
        guard let clean else { return }
        if configuration.isLoggingEnabled { logger.debug("\(clean.description, privacy: .public)") }
        providers.forEach { $0.log(clean) }
        eventHandler?(clean)
    }

    public func track(_ name: String, _ parameters: [String: AnalyticsValue?] = [:]) {
        track(AnalyticsEvent(name, parameters: parameters))
    }

    public func setUserID(_ userID: String?) {
        let clean = userID.map { String($0.prefix(AnalyticsLimits.maxUserIDLength)) }
        providers.forEach { $0.setUserID(clean) }
    }

    public func setUserProperty(_ value: String?, forName name: String) {
        var issues: [String] = []
        let clean = sanitizer.sanitizeUserProperty(name: name, value: value, issues: &issues)
        report(issues)
        guard let clean else { return }
        providers.forEach { $0.setUserProperty(clean.value, forName: clean.name) }
    }

    public func setExperiment(_ experiment: String, variant: String?) {
        setUserProperty(variant, forName: AnalyticsUserProperty.experimentPrefix + experiment)
    }

    public func setTrackingStatus(_ status: String) {
        setUserProperty(status, forName: AnalyticsUserProperty.trackingStatus)
    }

    public func setAdConsent(_ status: String) {
        setUserProperty(status, forName: AnalyticsUserProperty.adConsent)
    }

    public func setConsent(_ consent: AnalyticsConsent) {
        providers.forEach { $0.setConsent(consent) }
    }

    public func setCollectionEnabled(_ enabled: Bool) {
        providers.forEach { $0.setCollectionEnabled(enabled) }
    }

    public func trackScreen(_ name: String, screenClass: String? = nil) {
        track(AnalyticsEventName.screenView, [
            AnalyticsParameter.screenName: .string(name),
            AnalyticsParameter.screenClass: .string(screenClass ?? name)
        ])
    }

    public func trackOnboardingStep(_ step: Int, name: String) {
        if step == 1 { track(AnalyticsEventName.tutorialBegin) }
        track(AnalyticsEventName.onboardingStep, [
            AnalyticsParameter.step: .int(step),
            AnalyticsParameter.stepName: .string(name)
        ])
    }

    public func trackOnboardingComplete() {
        track(AnalyticsEventName.tutorialComplete)
    }

    public func trackSignUp(method: String) {
        track(AnalyticsEventName.signUp, [AnalyticsParameter.method: .string(method)])
    }

    public func trackLogin(method: String) {
        track(AnalyticsEventName.login, [AnalyticsParameter.method: .string(method)])
    }

    public func trackFeature(_ feature: String, parameters: [String: AnalyticsValue?] = [:]) {
        var parameters = parameters
        parameters[AnalyticsParameter.feature] = .string(feature)
        track(AnalyticsEventName.featureUsed, parameters)
    }

    private func beginSession() {
        state.sessionCount += 1
        let day = daysSinceInstall()
        if state.lastActiveDay != day {
            state.activeDayCount += 1
            state.lastActiveDay = day
        }
        if configuration.retentionDays.contains(day), !state.loggedRetentionDays.contains(day) {
            state.loggedRetentionDays.insert(day)
            track(AnalyticsEventName.retention(day: day), [
                AnalyticsParameter.day: .int(day),
                AnalyticsParameter.sessionNumber: .int(state.sessionCount)
            ])
        }
        save()
        setUserProperty(AnalyticsBucket.label(for: state.sessionCount, edges: configuration.sessionBuckets), forName: AnalyticsUserProperty.sessionBucket)
    }

    func daysSinceInstall() -> Int {
        guard let install = state.installDate else { return 0 }
        let calendar = configuration.calendar
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: install), to: calendar.startOfDay(for: clock.now)).day ?? 0
        return max(0, days)
    }

    func refreshUserProperties() {
        if let install = state.installDate {
            let calendar = configuration.calendar
            let date = calendar.dateComponents([.year, .month, .day], from: install)
            let week = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: install)
            setUserProperty(String(format: "%04d-%02d-%02d", date.year ?? 0, date.month ?? 0, date.day ?? 0), forName: AnalyticsUserProperty.installCohort)
            setUserProperty(String(format: "%04d-W%02d", week.yearForWeekOfYear ?? 0, week.weekOfYear ?? 0), forName: AnalyticsUserProperty.installWeek)
        }
        setUserProperty(AnalyticsBucket.label(for: state.sessionCount, edges: configuration.sessionBuckets), forName: AnalyticsUserProperty.sessionBucket)
        refreshMonetizationProperties()
    }

    func refreshMonetizationProperties() {
        let ad = reportingTotal(state.adRevenue)
        let iap = reportingTotal(state.iapRevenue)
        setUserProperty(userTier.rawValue, forName: AnalyticsUserProperty.userTier)
        setUserProperty(monetization().rawValue, forName: AnalyticsUserProperty.monetization)
        setUserProperty(iap > 0 ? "true" : "false", forName: AnalyticsUserProperty.isPayer)
        setUserProperty(AnalyticsBucket.label(for: ad, edges: configuration.ltvBuckets), forName: AnalyticsUserProperty.adLTVBucket)
        setUserProperty(AnalyticsBucket.label(for: iap, edges: configuration.ltvBuckets), forName: AnalyticsUserProperty.iapLTVBucket)
        setUserProperty(AnalyticsBucket.label(for: ad + iap, edges: configuration.ltvBuckets), forName: AnalyticsUserProperty.totalLTVBucket)
        setUserProperty(AnalyticsBucket.label(for: state.adImpressions, edges: configuration.impressionBuckets), forName: AnalyticsUserProperty.adImpressionBucket)
    }

    func reportingTotal(_ amounts: [String: Decimal]) -> Decimal {
        amounts.reduce(Decimal(0)) { total, entry in
            total + (configuration.convertToReporting(entry.value, currency: entry.key) ?? 0)
        }
    }

    func monetization() -> Monetization {
        let hasAds = state.adRevenue.values.contains { $0 > 0 }
        let hasIAP = state.iapRevenue.values.contains { $0 > 0 }
        switch (hasAds, hasIAP) {
        case (true, true): return .hybrid
        case (true, false): return .adsOnly
        case (false, true): return .iapOnly
        case (false, false): return .none
        }
    }

    func computeTier() -> UserTier {
        if state.hasLifetimeAccess { return .lifetime }
        let subscriptions = state.subscriptions.values
        let hasAccess: (SubscriptionSnapshot) -> Bool = { [clock] snapshot in
            guard snapshot.state == .active || snapshot.state == .inGracePeriod else { return false }
            guard let expiration = snapshot.expirationDate else { return true }
            return expiration > clock.now
        }
        if subscriptions.contains(where: { hasAccess($0) && !$0.isTrial }) { return .subscriber }
        if subscriptions.contains(where: { hasAccess($0) && $0.isTrial }) { return .trial }
        if subscriptions.contains(where: { $0.state == .inBillingRetry }) { return .billingIssue }
        if !subscriptions.isEmpty { return .lapsed }
        return .free
    }

    func updateTier() {
        let tier = computeTier()
        guard tier != userTier else { return }
        userTier = tier
        setUserProperty(tier.rawValue, forName: AnalyticsUserProperty.userTier)
    }

    func save() {
        store.save(state)
    }

    var now: Date { clock.now }

    private func report(_ issues: [String]) {
        guard !issues.isEmpty else { return }
        for issue in issues {
            logger.warning("\(issue, privacy: .public)")
            issueHandler?(issue)
        }
    }

    private func observeLifecycle() {
        #if canImport(UIKit) && !os(watchOS)
        let center = NotificationCenter.default
        lifecycleTasks.append(Task { [weak self] in
            for await _ in center.notifications(named: UIApplication.didEnterBackgroundNotification) {
                self?.appDidEnterBackground()
            }
        })
        lifecycleTasks.append(Task { [weak self] in
            for await _ in center.notifications(named: UIApplication.didBecomeActiveNotification) {
                self?.appDidBecomeActive()
            }
        })
        #endif
    }
}
