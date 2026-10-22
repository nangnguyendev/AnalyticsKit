#if canImport(StoreKit)
import Foundation
import StoreKit

@available(iOS 15.0, macOS 12.0, *)
public extension PurchaseRecord {
    init(transaction: Transaction, product: Product? = nil, placement: String? = nil) {
        let price = transaction.price ?? product?.price ?? 0
        let isIntroductory = transaction.offerType == .introductory
        self.init(
            transactionID: String(transaction.id),
            originalTransactionID: String(transaction.originalID),
            productID: transaction.productID,
            productType: PurchaseProductType(transaction.productType),
            price: price,
            currency: Self.currencyCode(transaction: transaction, product: product),
            quantity: transaction.purchasedQuantity,
            purchaseDate: transaction.purchaseDate,
            expirationDate: transaction.expirationDate,
            isTrial: isIntroductory && price == 0,
            offerType: transaction.offerType.map(Self.offerName),
            isRevoked: transaction.revocationDate != nil,
            environment: Self.environment(of: transaction),
            placement: placement
        )
    }

    private static func currencyCode(transaction: Transaction, product: Product?) -> String {
        if #available(iOS 16.0, macOS 13.0, *), let currency = transaction.currency {
            return currency.identifier
        }
        return product?.priceFormatStyle.currencyCode ?? "USD"
    }

    private static func environment(of transaction: Transaction) -> PurchaseEnvironment {
        if #available(iOS 16.0, macOS 13.0, *) {
            switch transaction.environment {
            case .production: return .production
            case .xcode: return .xcode
            default: return .sandbox
            }
        }
        switch transaction.environmentStringRepresentation.lowercased() {
        case "production": return .production
        case "xcode": return .xcode
        default: return .sandbox
        }
    }

    private static func offerName(_ type: Transaction.OfferType) -> String {
        switch type {
        case .introductory: return "introductory"
        case .promotional: return "promotional"
        case .code: return "code"
        default: return "other"
        }
    }
}

@available(iOS 15.0, macOS 12.0, *)
extension PurchaseProductType {
    init(_ type: Product.ProductType) {
        switch type {
        case .consumable: self = .consumable
        case .nonConsumable: self = .nonConsumable
        case .autoRenewable: self = .autoRenewable
        default: self = .nonRenewable
        }
    }
}

@available(iOS 15.0, macOS 12.0, *)
public extension SubscriptionStatusRecord {
    init?(status: Product.SubscriptionInfo.Status) {
        guard case .verified(let transaction) = status.transaction,
              case .verified(let renewal) = status.renewalInfo else { return nil }
        let state: SubscriptionState
        switch status.state {
        case .subscribed: state = .active
        case .inGracePeriod: state = .inGracePeriod
        case .inBillingRetryPeriod: state = .inBillingRetry
        case .revoked: state = .revoked
        default: state = .expired
        }
        self.init(
            productID: transaction.productID,
            originalTransactionID: String(transaction.originalID),
            state: state,
            willAutoRenew: renewal.willAutoRenew,
            isTrial: transaction.offerType == .introductory && (transaction.price ?? 0) == 0,
            expirationDate: transaction.expirationDate
        )
    }
}

@available(iOS 15.0, macOS 12.0, *)
public extension AnalyticsManager {
    @discardableResult
    func track(transaction: Transaction, product: Product? = nil, placement: String? = nil) -> PurchaseKind {
        let kind = trackPurchase(PurchaseRecord(transaction: transaction, product: product, placement: placement))
        if kind != .duplicate {
            providers.forEach { $0.logStoreKitTransaction(transaction) }
        }
        return kind
    }

    func refreshSubscriptionStatuses(for products: [Product]) async {
        var seen: Set<String> = []
        for product in products where product.type == .autoRenewable {
            guard let group = product.subscription?.subscriptionGroupID, seen.insert(group).inserted,
                  let statuses = try? await product.subscription?.status else { continue }
            for status in statuses {
                if let record = SubscriptionStatusRecord(status: status) {
                    updateSubscriptionStatus(record)
                }
            }
        }
    }
}
#endif
