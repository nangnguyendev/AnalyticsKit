import Foundation

public enum AnalyticsValue: Equatable, Sendable {
    case string(String)
    case int(Int)
    case double(Double)

    public init(_ decimal: Decimal) {
        self = .double(NSDecimalNumber(decimal: decimal).doubleValue)
    }

    public init(_ bool: Bool) {
        self = .int(bool ? 1 : 0)
    }

    public var foundationValue: Any {
        switch self {
        case .string(let value): return value
        case .int(let value): return NSNumber(value: value)
        case .double(let value): return NSNumber(value: value)
        }
    }

    public var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    public var doubleValue: Double? {
        switch self {
        case .string: return nil
        case .int(let value): return Double(value)
        case .double(let value): return value
        }
    }
}

extension AnalyticsValue: ExpressibleByStringLiteral, ExpressibleByIntegerLiteral, ExpressibleByFloatLiteral, ExpressibleByBooleanLiteral {
    public init(stringLiteral value: String) { self = .string(value) }
    public init(integerLiteral value: Int) { self = .int(value) }
    public init(floatLiteral value: Double) { self = .double(value) }
    public init(booleanLiteral value: Bool) { self.init(value) }
}

extension AnalyticsValue: CustomStringConvertible {
    public var description: String {
        switch self {
        case .string(let value): return "\"\(value)\""
        case .int(let value): return String(value)
        case .double(let value): return String(value)
        }
    }
}

public struct AnalyticsEvent: Equatable, Sendable {
    public var name: String
    public var parameters: [String: AnalyticsValue]

    public init(_ name: String, parameters: [String: AnalyticsValue?] = [:]) {
        self.name = name
        self.parameters = parameters.compactMapValues { $0 }
    }

    public subscript(parameter: String) -> AnalyticsValue? {
        parameters[parameter]
    }
}

extension AnalyticsEvent: CustomStringConvertible {
    public var description: String {
        let params = parameters.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: " ")
        return params.isEmpty ? name : "\(name) \(params)"
    }
}

public enum AnalyticsEventName {
    public static let screenView = "screen_view"
    public static let adImpression = "ad_impression"
    public static let tutorialBegin = "tutorial_begin"
    public static let tutorialComplete = "tutorial_complete"
    public static let signUp = "sign_up"
    public static let login = "login"

    public static let onboardingStep = "onboarding_step"
    public static let featureUsed = "feature_used"
    public static let retentionPrefix = "retention_d"

    public static let paywallView = "paywall_view"
    public static let paywallClose = "paywall_close"
    public static let purchaseStart = "purchase_start"
    public static let purchaseCancel = "purchase_cancel"
    public static let purchaseFail = "purchase_fail"
    public static let purchaseRestore = "purchase_restore"
    public static let iapPurchase = "iap_purchase"
    public static let iapRefund = "iap_refund"
    public static let trialStart = "trial_start"
    public static let trialConvert = "trial_convert"
    public static let subscriptionStart = "subscription_start"
    public static let subscriptionRenew = "subscription_renew"
    public static let subscriptionCancel = "subscription_cancel"
    public static let subscriptionReactivate = "subscription_reactivate"
    public static let subscriptionBillingIssue = "subscription_billing_issue"
    public static let subscriptionExpire = "subscription_expire"

    public static let adRequest = "ad_request"
    public static let adLoadSuccess = "ad_load_success"
    public static let adLoadFail = "ad_load_fail"
    public static let adOpportunity = "ad_opportunity"
    public static let adShow = "ad_show"
    public static let adShowFail = "ad_show_fail"
    public static let adClick = "ad_clicked"
    public static let adReward = "ad_reward_earned"

    public static func retention(day: Int) -> String { "\(retentionPrefix)\(day)" }
}

public enum AnalyticsParameter {
    public static let value = "value"
    public static let currency = "currency"
    public static let screenName = "screen_name"
    public static let screenClass = "screen_class"

    public static let adPlatform = "ad_platform"
    public static let adSource = "ad_source"
    public static let adFormat = "ad_format"
    public static let adUnitName = "ad_unit_name"
    public static let placement = "placement"
    public static let precision = "precision"
    public static let result = "result"
    public static let reason = "reason"
    public static let latencyMs = "latency_ms"
    public static let errorMessage = "error_message"
    public static let rewardType = "reward_type"
    public static let rewardAmount = "reward_amount"

    public static let productID = "product_id"
    public static let productType = "product_type"
    public static let price = "price"
    public static let transactionID = "transaction_id"
    public static let originalTransactionID = "original_transaction_id"
    public static let offerType = "offer_type"
    public static let environment = "environment"
    public static let paywallID = "paywall_id"
    public static let variant = "variant"
    public static let purchased = "purchased"
    public static let restoredCount = "restored_count"

    public static let step = "step"
    public static let stepName = "step_name"
    public static let feature = "feature"
    public static let method = "method"
    public static let day = "day"
    public static let sessionNumber = "session_number"
    public static let daysSinceInstall = "days_since_install"
}

public enum AnalyticsUserProperty {
    public static let userTier = "user_tier"
    public static let monetization = "monetization"
    public static let isPayer = "is_payer"
    public static let iapLTVBucket = "iap_ltv_bucket"
    public static let adLTVBucket = "ad_ltv_bucket"
    public static let totalLTVBucket = "total_ltv_bucket"
    public static let adImpressionBucket = "ad_impr_bucket"
    public static let sessionBucket = "session_bucket"
    public static let installCohort = "install_cohort"
    public static let installWeek = "install_week"
    public static let subscriptionProduct = "sub_product"
    public static let autoRenew = "sub_auto_renew"
    public static let trackingStatus = "att_status"
    public static let adConsent = "ad_consent"
    public static let experimentPrefix = "exp_"
}
