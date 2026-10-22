#if canImport(FirebaseAnalytics)
import AnalyticsKit
import FirebaseAnalytics
import FirebaseCore
import Foundation
import StoreKit

@MainActor
public final class FirebaseAnalyticsProvider: AnalyticsProvider {
    public let name = "Firebase"
    public var logsStoreKitTransactions: Bool

    @discardableResult
    public static func configureFirebaseIfPossible(bundle: Bundle = .main) -> Bool {
        if FirebaseApp.app() != nil { return true }
        guard let path = bundle.path(forResource: "GoogleService-Info", ofType: "plist"),
              let options = FirebaseOptions(contentsOfFile: path) else { return false }
        FirebaseApp.configure(options: options)
        return true
    }

    public init(logsStoreKitTransactions: Bool = true, sessionTimeout: TimeInterval? = nil) {
        self.logsStoreKitTransactions = logsStoreKitTransactions
        if let sessionTimeout { Analytics.setSessionTimeoutInterval(sessionTimeout) }
    }

    public var appInstanceID: String? { Analytics.appInstanceID() }

    public func log(_ event: AnalyticsEvent) {
        let parameters = event.parameters.mapValues(\.foundationValue)
        Analytics.logEvent(event.name, parameters: parameters.isEmpty ? nil : parameters)
    }

    public func setUserProperty(_ value: String?, forName name: String) {
        Analytics.setUserProperty(value, forName: name)
    }

    public func setUserID(_ userID: String?) {
        Analytics.setUserID(userID)
    }

    public func setCollectionEnabled(_ enabled: Bool) {
        Analytics.setAnalyticsCollectionEnabled(enabled)
    }

    public func setConsent(_ consent: AnalyticsConsent) {
        Analytics.setConsent([
            .analyticsStorage: consent.analyticsStorage ? .granted : .denied,
            .adStorage: consent.adStorage ? .granted : .denied,
            .adUserData: consent.adUserData ? .granted : .denied,
            .adPersonalization: consent.adPersonalization ? .granted : .denied
        ])
    }

    public func logStoreKitTransaction(_ transaction: Transaction) {
        guard logsStoreKitTransactions else { return }
        Analytics.logTransaction(transaction)
    }

    public func setDefaultParameters(_ parameters: [String: AnalyticsValue]?) {
        Analytics.setDefaultEventParameters(parameters?.mapValues(\.foundationValue))
    }

    public func initiateOnDeviceConversionMeasurement(emailAddress: String) {
        Analytics.initiateOnDeviceConversionMeasurement(emailAddress: emailAddress)
    }

    public func resetAnalyticsData() {
        Analytics.resetAnalyticsData()
    }
}
#endif
