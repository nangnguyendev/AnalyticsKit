import Foundation

public struct AdImpression: Equatable, Sendable {
    public var value: Decimal
    public var currency: String
    public var platform: String
    public var source: String?
    public var format: String
    public var adUnitID: String
    public var placement: String?
    public var precision: String?

    public init(value: Decimal, currency: String, platform: String = "AdMob", source: String? = nil, format: String, adUnitID: String, placement: String? = nil, precision: String? = nil) {
        self.value = value
        self.currency = currency.uppercased()
        self.platform = platform
        self.source = source
        self.format = format
        self.adUnitID = adUnitID
        self.placement = placement
        self.precision = precision
    }
}

public enum AdOpportunityOutcome: Equatable, Sendable {
    case shown
    case notReady
    case blocked(reason: String)

    var result: String {
        switch self {
        case .shown: return "shown"
        case .notReady: return "not_ready"
        case .blocked: return "blocked"
        }
    }

    var reason: String? {
        if case .blocked(let reason) = self { return reason }
        return nil
    }
}

public enum PurchaseProductType: String, Codable, Sendable {
    case consumable
    case nonConsumable = "non_consumable"
    case autoRenewable = "auto_renewable"
    case nonRenewable = "non_renewable"
}

public enum PurchaseEnvironment: String, Codable, Sendable {
    case production
    case sandbox
    case xcode
}

public struct PurchaseRecord: Equatable, Sendable {
    public var transactionID: String
    public var originalTransactionID: String
    public var productID: String
    public var productType: PurchaseProductType
    public var price: Decimal
    public var currency: String
    public var quantity: Int
    public var purchaseDate: Date
    public var expirationDate: Date?
    public var isTrial: Bool
    public var offerType: String?
    public var isRevoked: Bool
    public var environment: PurchaseEnvironment
    public var placement: String?

    public init(
        transactionID: String,
        originalTransactionID: String? = nil,
        productID: String,
        productType: PurchaseProductType,
        price: Decimal,
        currency: String,
        quantity: Int = 1,
        purchaseDate: Date = Date(),
        expirationDate: Date? = nil,
        isTrial: Bool = false,
        offerType: String? = nil,
        isRevoked: Bool = false,
        environment: PurchaseEnvironment = .production,
        placement: String? = nil
    ) {
        self.transactionID = transactionID
        self.originalTransactionID = originalTransactionID ?? transactionID
        self.productID = productID
        self.productType = productType
        self.price = price
        self.currency = currency.uppercased()
        self.quantity = max(1, quantity)
        self.purchaseDate = purchaseDate
        self.expirationDate = expirationDate
        self.isTrial = isTrial
        self.offerType = offerType
        self.isRevoked = isRevoked
        self.environment = environment
        self.placement = placement
    }

    public var isRenewal: Bool { transactionID != originalTransactionID }
    public var revenue: Decimal { isTrial ? 0 : price * Decimal(quantity) }
}

public enum PurchaseKind: String, Equatable, Sendable {
    case iapPurchase
    case trialStart
    case subscriptionStart
    case subscriptionRenew
    case trialConvert
    case refund
    case duplicate
}

public enum SubscriptionState: String, Codable, Sendable {
    case active
    case expired
    case inGracePeriod = "grace_period"
    case inBillingRetry = "billing_retry"
    case revoked
}

public struct SubscriptionStatusRecord: Equatable, Sendable {
    public var productID: String
    public var originalTransactionID: String
    public var state: SubscriptionState
    public var willAutoRenew: Bool
    public var isTrial: Bool
    public var expirationDate: Date?

    public init(productID: String, originalTransactionID: String, state: SubscriptionState, willAutoRenew: Bool, isTrial: Bool = false, expirationDate: Date? = nil) {
        self.productID = productID
        self.originalTransactionID = originalTransactionID
        self.state = state
        self.willAutoRenew = willAutoRenew
        self.isTrial = isTrial
        self.expirationDate = expirationDate
    }
}

public enum UserTier: String, Codable, Sendable {
    case free
    case trial
    case subscriber
    case billingIssue = "billing_issue"
    case lapsed
    case lifetime
}

public enum Monetization: String, Sendable {
    case none
    case adsOnly = "ads_only"
    case iapOnly = "iap_only"
    case hybrid
}
