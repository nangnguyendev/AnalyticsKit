import Foundation

public extension AnalyticsManager {
    func trackAdRequest(format: String, adUnitID: String, placement: String? = nil) {
        track(AnalyticsEventName.adRequest, [
            AnalyticsParameter.adFormat: .string(format),
            AnalyticsParameter.adUnitName: .string(adUnitID),
            AnalyticsParameter.placement: placement.map(AnalyticsValue.string)
        ])
    }

    func trackAdLoaded(format: String, adUnitID: String? = nil, latency: TimeInterval? = nil) {
        track(AnalyticsEventName.adLoadSuccess, [
            AnalyticsParameter.adFormat: .string(format),
            AnalyticsParameter.adUnitName: adUnitID.map(AnalyticsValue.string),
            AnalyticsParameter.latencyMs: latency.map { .int(Int(($0 * 1000).rounded())) }
        ])
    }

    func trackAdLoadFailed(format: String, adUnitID: String? = nil, error: String, latency: TimeInterval? = nil) {
        track(AnalyticsEventName.adLoadFail, [
            AnalyticsParameter.adFormat: .string(format),
            AnalyticsParameter.adUnitName: adUnitID.map(AnalyticsValue.string),
            AnalyticsParameter.errorMessage: .string(error),
            AnalyticsParameter.latencyMs: latency.map { .int(Int(($0 * 1000).rounded())) }
        ])
    }

    func trackAdOpportunity(format: String, placement: String, outcome: AdOpportunityOutcome) {
        track(AnalyticsEventName.adOpportunity, [
            AnalyticsParameter.adFormat: .string(format),
            AnalyticsParameter.placement: .string(placement),
            AnalyticsParameter.result: .string(outcome.result),
            AnalyticsParameter.reason: outcome.reason.map(AnalyticsValue.string)
        ])
    }

    func trackAdShown(format: String, placement: String) {
        track(AnalyticsEventName.adShow, [
            AnalyticsParameter.adFormat: .string(format),
            AnalyticsParameter.placement: .string(placement)
        ])
    }

    func trackAdShowFailed(format: String, placement: String, error: String) {
        track(AnalyticsEventName.adShowFail, [
            AnalyticsParameter.adFormat: .string(format),
            AnalyticsParameter.placement: .string(placement),
            AnalyticsParameter.errorMessage: .string(error)
        ])
    }

    func trackAdClick(format: String, placement: String) {
        track(AnalyticsEventName.adClick, [
            AnalyticsParameter.adFormat: .string(format),
            AnalyticsParameter.placement: .string(placement)
        ])
    }

    func trackAdReward(placement: String, type: String, amount: Decimal) {
        track(AnalyticsEventName.adReward, [
            AnalyticsParameter.adFormat: "rewarded",
            AnalyticsParameter.placement: .string(placement),
            AnalyticsParameter.rewardType: .string(type),
            AnalyticsParameter.rewardAmount: AnalyticsValue(amount)
        ])
    }

    func trackAdImpression(_ impression: AdImpression) {
        track(AnalyticsEventName.adImpression, [
            AnalyticsParameter.adPlatform: .string(impression.platform),
            AnalyticsParameter.adSource: impression.source.map(AnalyticsValue.string),
            AnalyticsParameter.adFormat: .string(impression.format),
            AnalyticsParameter.adUnitName: .string(impression.adUnitID),
            AnalyticsParameter.placement: impression.placement.map(AnalyticsValue.string),
            AnalyticsParameter.precision: impression.precision.map(AnalyticsValue.string),
            AnalyticsParameter.value: AnalyticsValue(impression.value),
            AnalyticsParameter.currency: .string(impression.currency)
        ])

        state.adImpressions += 1
        if impression.value > 0 {
            state.adRevenue[impression.currency, default: 0] += impression.value
        }
        if let threshold = configuration.adRevenueThreshold, threshold > 0,
           let converted = configuration.convertToReporting(impression.value, currency: impression.currency) {
            state.pendingAdRevenue += converted
            if state.pendingAdRevenue >= threshold {
                track(configuration.adRevenueThresholdEventName, [
                    AnalyticsParameter.value: AnalyticsValue(state.pendingAdRevenue),
                    AnalyticsParameter.currency: .string(configuration.reportingCurrency)
                ])
                state.pendingAdRevenue = 0
            }
        }
        save()
        refreshMonetizationProperties()
    }
}
