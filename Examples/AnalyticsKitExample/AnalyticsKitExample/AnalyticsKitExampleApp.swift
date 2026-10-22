import AnalyticsKit
import AnalyticsKitFirebase
import SwiftUI

@main
struct AnalyticsKitExampleApp: App {
    @StateObject private var analytics: AnalyticsManager
    @StateObject private var log: InMemoryAnalyticsProvider
    @StateObject private var demo: DemoStore

    init() {
        let log = InMemoryAnalyticsProvider()
        let clock = DemoClock()
        var providers: [AnalyticsProvider] = [log, ConsoleAnalyticsProvider()]
        let isFirebaseConfigured = FirebaseAnalyticsProvider.configureFirebaseIfPossible()
        if isFirebaseConfigured { providers.append(FirebaseAnalyticsProvider()) }

        let analytics = AnalyticsManager(
            configuration: AnalyticsConfiguration(
                exchangeRates: ["EUR": 1.08, "GBP": 1.27],
                countsSandboxRevenue: true,
                lifetimeProductIDs: [DemoProduct.lifetime],
                isLoggingEnabled: true
            ),
            providers: providers,
            clock: clock
        )
        _analytics = StateObject(wrappedValue: analytics)
        _log = StateObject(wrappedValue: log)
        _demo = StateObject(wrappedValue: DemoStore(analytics: analytics, log: log, clock: clock, isFirebaseConfigured: isFirebaseConfigured))
    }

    var body: some Scene {
        WindowGroup {
            TabView {
                DashboardView()
                    .tabItem { Label("Dashboard", systemImage: "chart.bar") }
                SimulatorView()
                    .tabItem { Label("Simulate", systemImage: "play.circle") }
                EventLogView()
                    .tabItem { Label("Events", systemImage: "list.bullet.rectangle") }
            }
            .environmentObject(analytics)
            .environmentObject(log)
            .environmentObject(demo)
            .task { analytics.start() }
        }
    }
}
