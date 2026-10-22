import AnalyticsKit
import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var analytics: AnalyticsManager
    @EnvironmentObject private var log: InMemoryAnalyticsProvider
    @EnvironmentObject private var demo: DemoStore

    var body: some View {
        let metrics = analytics.metrics
        NavigationStack {
            List {
                Section("Revenue (\(metrics.currency))") {
                    MetricRow("Total LTV", money(metrics.totalRevenue))
                    MetricRow("IAP revenue", money(metrics.iapRevenue))
                    MetricRow("Ad revenue", money(metrics.adRevenue))
                    MetricRow("Ad impressions", "\(metrics.adImpressions)")
                    MetricRow("Average eCPM", money(metrics.averageECPM))
                }
                Section("User") {
                    MetricRow("Tier", metrics.userTier.rawValue)
                    MetricRow("Monetization", metrics.monetization.rawValue)
                    MetricRow("Sessions", "\(metrics.sessionCount)")
                    MetricRow("Active days", "\(metrics.activeDayCount)")
                    MetricRow("Days since install", "\(metrics.daysSinceInstall)")
                    MetricRow("Retention events", analytics.state.loggedRetentionDays.sorted().map { "D\($0)" }.joined(separator: ", "))
                }
                Section("User properties") {
                    ForEach(log.userProperties.sorted { $0.key < $1.key }, id: \.key) { key, value in
                        MetricRow(key, value)
                    }
                }
                Section {
                    MetricRow("Firebase", demo.isFirebaseConfigured ? "Connected" : "Not configured")
                } footer: {
                    Text(demo.isFirebaseConfigured
                         ? "Events are sent to Firebase. Open DebugView in the Firebase console to watch them live."
                         : "Add GoogleService-Info.plist to the example target to send events to Firebase. Events are still recorded locally.")
                }
            }
            .navigationTitle("Metrics")
            .trackScreen("Dashboard", analytics: analytics)
        }
    }

    private func money(_ value: Decimal) -> String {
        value.formatted(.number.precision(.fractionLength(2...4)))
    }
}

struct MetricRow: View {
    let title: String
    let value: String

    init(_ title: String, _ value: String) {
        self.title = title
        self.value = value
    }

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}
