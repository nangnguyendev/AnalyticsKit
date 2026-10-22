import Foundation

public extension AnalyticsManager {
    func trackPaywallView(_ paywallID: String, placement: String, variant: String? = nil) {
        track(AnalyticsEventName.paywallView, [
            AnalyticsParameter.paywallID: .string(paywallID),
            AnalyticsParameter.placement: .string(placement),
            AnalyticsParameter.variant: variant.map(AnalyticsValue.string)
        ])
    }

    func trackPaywallClose(_ paywallID: String, placement: String, purchased: Bool) {
        track(AnalyticsEventName.paywallClose, [
            AnalyticsParameter.paywallID: .string(paywallID),
            AnalyticsParameter.placement: .string(placement),
            AnalyticsParameter.purchased: AnalyticsValue(purchased)
        ])
    }

    func trackPurchaseStart(productID: String, placement: String? = nil) {
        track(AnalyticsEventName.purchaseStart, [
            AnalyticsParameter.productID: .string(productID),
            AnalyticsParameter.placement: placement.map(AnalyticsValue.string)
        ])
    }

    func trackPurchaseCancel(productID: String, placement: String? = nil) {
        track(AnalyticsEventName.purchaseCancel, [
            AnalyticsParameter.productID: .string(productID),
            AnalyticsParameter.placement: placement.map(AnalyticsValue.string)
        ])
    }

    func trackPurchaseFail(productID: String, error: String, placement: String? = nil) {
        track(AnalyticsEventName.purchaseFail, [
            AnalyticsParameter.productID: .string(productID),
            AnalyticsParameter.errorMessage: .string(error),
            AnalyticsParameter.placement: placement.map(AnalyticsValue.string)
        ])
    }

    func trackRestore(restoredCount: Int) {
        track(AnalyticsEventName.purchaseRestore, [AnalyticsParameter.restoredCount: .int(restoredCount)])
    }

    @discardableResult
    func trackPurchase(_ record: PurchaseRecord) -> PurchaseKind {
        if record.isRevoked { return trackRefund(record) }
        guard !state.hasProcessed(record.transactionID) else { return .duplicate }
        state.markProcessed(record.transactionID)

        let kind = classify(record)
        let name: String
        switch kind {
        case .trialStart: name = AnalyticsEventName.trialStart
        case .subscriptionStart: name = AnalyticsEventName.subscriptionStart
        case .subscriptionRenew: name = AnalyticsEventName.subscriptionRenew
        case .trialConvert: name = AnalyticsEventName.trialConvert
        default: name = AnalyticsEventName.iapPurchase
        }
        track(name, purchaseParameters(record, value: record.revenue))

        if countsRevenue(record), record.revenue > 0 {
            state.iapRevenue[record.currency, default: 0] += record.revenue
        }
        if record.productType == .autoRenewable {
            let previous = state.subscriptions[record.originalTransactionID]
            state.subscriptions[record.originalTransactionID] = SubscriptionSnapshot(
                productID: record.productID,
                isTrial: record.isTrial,
                state: .active,
                willAutoRenew: previous?.willAutoRenew ?? true,
                expirationDate: record.expirationDate
            )
        } else if record.productType == .nonConsumable, configuration.lifetimeProductIDs.contains(record.productID) {
            state.hasLifetimeAccess = true
        }
        save()
        updateTier()
        refreshMonetizationProperties()
        if record.productType == .autoRenewable {
            setUserProperty(record.productID, forName: AnalyticsUserProperty.subscriptionProduct)
        }
        return kind
    }

    func updateSubscriptionStatus(_ status: SubscriptionStatusRecord) {
        let previous = state.subscriptions[status.originalTransactionID]
        let parameters: [String: AnalyticsValue?] = [
            AnalyticsParameter.productID: .string(status.productID),
            AnalyticsParameter.originalTransactionID: .string(status.originalTransactionID),
            AnalyticsParameter.offerType: status.isTrial ? "free_trial" : nil
        ]

        if let previous {
            let stillHasAccess = status.state == .active || status.state == .inGracePeriod
            if previous.willAutoRenew != false, !status.willAutoRenew, stillHasAccess {
                track(AnalyticsEventName.subscriptionCancel, parameters)
            } else if previous.willAutoRenew == false, status.willAutoRenew, stillHasAccess {
                track(AnalyticsEventName.subscriptionReactivate, parameters)
            }
            if status.state == .inBillingRetry, previous.state != .inBillingRetry {
                track(AnalyticsEventName.subscriptionBillingIssue, parameters)
            }
            if status.state == .expired, previous.state != .expired, previous.state != .revoked {
                track(AnalyticsEventName.subscriptionExpire, parameters)
            }
        }

        state.subscriptions[status.originalTransactionID] = SubscriptionSnapshot(
            productID: status.productID,
            isTrial: status.isTrial,
            state: status.state,
            willAutoRenew: status.willAutoRenew,
            expirationDate: status.expirationDate ?? previous?.expirationDate
        )
        save()
        updateTier()
        setUserProperty(status.willAutoRenew ? "true" : "false", forName: AnalyticsUserProperty.autoRenew)
        setUserProperty(status.productID, forName: AnalyticsUserProperty.subscriptionProduct)
    }

    private func trackRefund(_ record: PurchaseRecord) -> PurchaseKind {
        let key = "refund:\(record.transactionID)"
        guard !state.hasProcessed(key) else { return .duplicate }
        state.markProcessed(key)
        if !state.hasProcessed(record.transactionID) { state.markProcessed(record.transactionID) }

        track(AnalyticsEventName.iapRefund, purchaseParameters(record, value: record.revenue))

        if countsRevenue(record), record.revenue > 0 {
            let current = state.iapRevenue[record.currency, default: 0]
            state.iapRevenue[record.currency] = max(0, current - record.revenue)
        }
        if record.productType == .autoRenewable, var snapshot = state.subscriptions[record.originalTransactionID] {
            snapshot.state = .revoked
            state.subscriptions[record.originalTransactionID] = snapshot
        } else if record.productType == .nonConsumable, configuration.lifetimeProductIDs.contains(record.productID) {
            state.hasLifetimeAccess = false
        }
        save()
        updateTier()
        refreshMonetizationProperties()
        return .refund
    }

    private func classify(_ record: PurchaseRecord) -> PurchaseKind {
        guard record.productType == .autoRenewable else { return .iapPurchase }
        let previous = state.subscriptions[record.originalTransactionID]
        if !record.isRenewal, previous == nil {
            return record.isTrial ? .trialStart : .subscriptionStart
        }
        if previous?.isTrial == true, !record.isTrial {
            return .trialConvert
        }
        if previous == nil, record.isTrial {
            return .trialStart
        }
        return .subscriptionRenew
    }

    private func countsRevenue(_ record: PurchaseRecord) -> Bool {
        record.environment == .production || configuration.countsSandboxRevenue
    }

    private func purchaseParameters(_ record: PurchaseRecord, value: Decimal) -> [String: AnalyticsValue?] {
        [
            AnalyticsParameter.productID: .string(record.productID),
            AnalyticsParameter.productType: .string(record.productType.rawValue),
            AnalyticsParameter.value: AnalyticsValue(value),
            AnalyticsParameter.currency: .string(record.currency),
            AnalyticsParameter.transactionID: .string(record.transactionID),
            AnalyticsParameter.originalTransactionID: .string(record.originalTransactionID),
            AnalyticsParameter.offerType: record.offerType.map(AnalyticsValue.string) ?? (record.isTrial ? "free_trial" : nil),
            AnalyticsParameter.environment: .string(record.environment.rawValue),
            AnalyticsParameter.placement: record.placement.map(AnalyticsValue.string)
        ]
    }
}
