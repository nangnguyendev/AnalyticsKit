import Foundation
import os
#if canImport(StoreKit)
import StoreKit
#endif

public struct AnalyticsConsent: Equatable, Sendable {
    public var analyticsStorage: Bool
    public var adStorage: Bool
    public var adUserData: Bool
    public var adPersonalization: Bool

    public init(analyticsStorage: Bool, adStorage: Bool, adUserData: Bool, adPersonalization: Bool) {
        self.analyticsStorage = analyticsStorage
        self.adStorage = adStorage
        self.adUserData = adUserData
        self.adPersonalization = adPersonalization
    }

    public static let granted = AnalyticsConsent(analyticsStorage: true, adStorage: true, adUserData: true, adPersonalization: true)
    public static let analyticsOnly = AnalyticsConsent(analyticsStorage: true, adStorage: false, adUserData: false, adPersonalization: false)
    public static let denied = AnalyticsConsent(analyticsStorage: false, adStorage: false, adUserData: false, adPersonalization: false)
}

@MainActor
public protocol AnalyticsProvider: AnyObject {
    var name: String { get }
    func log(_ event: AnalyticsEvent)
    func setUserProperty(_ value: String?, forName name: String)
    func setUserID(_ userID: String?)
    func setCollectionEnabled(_ enabled: Bool)
    func setConsent(_ consent: AnalyticsConsent)
    #if canImport(StoreKit)
    @available(iOS 15.0, macOS 12.0, *)
    func logStoreKitTransaction(_ transaction: Transaction)
    #endif
}

public extension AnalyticsProvider {
    func setCollectionEnabled(_ enabled: Bool) {}
    func setConsent(_ consent: AnalyticsConsent) {}
    #if canImport(StoreKit)
    @available(iOS 15.0, macOS 12.0, *)
    func logStoreKitTransaction(_ transaction: Transaction) {}
    #endif
}

@MainActor
public final class ConsoleAnalyticsProvider: AnalyticsProvider {
    public let name = "Console"
    private let logger = Logger(subsystem: "AnalyticsKit", category: "Console")

    public init() {}

    public func log(_ event: AnalyticsEvent) {
        logger.debug("event \(event.description, privacy: .public)")
    }

    public func setUserProperty(_ value: String?, forName name: String) {
        logger.debug("user property \(name, privacy: .public)=\(value ?? "nil", privacy: .public)")
    }

    public func setUserID(_ userID: String?) {
        logger.debug("user id \(userID ?? "nil", privacy: .private)")
    }
}

@MainActor
public final class InMemoryAnalyticsProvider: AnalyticsProvider, ObservableObject {
    public let name = "InMemory"
    @Published public private(set) var events: [AnalyticsEvent] = []
    @Published public private(set) var userProperties: [String: String] = [:]
    @Published public private(set) var userID: String?
    @Published public private(set) var isCollectionEnabled = true
    @Published public private(set) var consent: AnalyticsConsent?
    public let limit: Int

    public init(limit: Int = 500) {
        self.limit = limit
    }

    public func log(_ event: AnalyticsEvent) {
        events.append(event)
        if events.count > limit { events.removeFirst(events.count - limit) }
    }

    public func setUserProperty(_ value: String?, forName name: String) {
        userProperties[name] = value
    }

    public func setUserID(_ userID: String?) {
        self.userID = userID
    }

    public func setCollectionEnabled(_ enabled: Bool) {
        isCollectionEnabled = enabled
    }

    public func setConsent(_ consent: AnalyticsConsent) {
        self.consent = consent
    }

    public func events(named name: String) -> [AnalyticsEvent] {
        events.filter { $0.name == name }
    }

    public func last(_ name: String) -> AnalyticsEvent? {
        events.last { $0.name == name }
    }

    public func reset() {
        events.removeAll()
        userProperties.removeAll()
        userID = nil
    }
}
