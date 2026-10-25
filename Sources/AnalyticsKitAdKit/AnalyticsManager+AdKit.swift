import AdKit
import AnalyticsKit
import Foundation

public extension AnalyticsManager {
    func track(_ event: AdEvent, platform: String = "AdMob") {
        switch event {
        case .consentGathered(let status):
            setAdConsent(status.rawValue)
        case .trackingAuthorization(let status):
            setTrackingStatus(status.rawValue)
        case .started, .dismissed:
            break
        case .loaded(let format):
            trackAdLoaded(format: format.analyticsName)
        case .loadFailed(let format, let message):
            trackAdLoadFailed(format: format.analyticsName, error: message)
        case .shown(let format, let placement):
            trackAdOpportunity(format: format.analyticsName, placement: placement, outcome: .shown)
            trackAdShown(format: format.analyticsName, placement: placement)
        case .clicked(let format, let placement):
            trackAdClick(format: format.analyticsName, placement: placement)
        case .rewarded(let reward, let placement):
            trackAdReward(placement: placement, type: reward.type, amount: reward.amount)
        case .blocked(let format, let placement, let reason):
            trackAdOpportunity(format: format.analyticsName, placement: placement, outcome: reason.opportunityOutcome)
        case .revenue(let revenue):
            trackAdImpression(AdImpression(revenue: revenue, platform: platform))
        }
    }

    func connect(_ ads: AdManager, platform: String = "AdMob") {
        let previous = ads.eventHandler
        ads.eventHandler = { [weak self] event in
            previous?(event)
            self?.track(event, platform: platform)
        }
    }
}

public extension AdImpression {
    init(revenue: AdRevenue, platform: String = "AdMob") {
        self.init(
            value: revenue.value,
            currency: revenue.currencyCode,
            platform: platform,
            source: revenue.adSourceName,
            format: revenue.format.analyticsName,
            adUnitID: revenue.adUnitID,
            placement: revenue.placement.isEmpty ? nil : revenue.placement,
            precision: revenue.precision.rawValue
        )
    }
}

public extension AdFormat {
    var analyticsName: String {
        switch self {
        case .banner: return "banner"
        case .interstitial: return "interstitial"
        case .rewarded: return "rewarded"
        case .appOpen: return "app_open"
        case .native: return "native"
        }
    }
}

public extension AdBlockReason {
    var analyticsCode: String {
        switch self {
        case .adFree: return "ad_free"
        case .consentRequired: return "consent_required"
        case .noAdUnit: return "no_ad_unit"
        case .notLoaded: return "not_loaded"
        case .alreadyPresenting: return "already_presenting"
        case .suppressed: return "suppressed"
        case .newUserGrace: return "new_user_grace"
        case .sessionStartDelay: return "session_start_delay"
        case .tooSoon: return "too_soon"
        case .cooldownAfterRewarded: return "cooldown_rewarded"
        case .cooldownAfterAppOpen: return "cooldown_app_open"
        case .triggerInterval: return "trigger_interval"
        case .sessionCap: return "session_cap"
        case .hourlyCap: return "hourly_cap"
        case .dailyCap: return "daily_cap"
        case .appOpenDisabled: return "app_open_disabled"
        case .coldStartDisabled: return "cold_start_disabled"
        case .notEnoughSessions: return "not_enough_sessions"
        case .backgroundTooShort: return "background_too_short"
        }
    }

    var opportunityOutcome: AdOpportunityOutcome {
        self == .notLoaded ? .notReady : .blocked(reason: analyticsCode)
    }
}
