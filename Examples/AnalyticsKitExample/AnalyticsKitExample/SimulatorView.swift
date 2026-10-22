import AnalyticsKit
import SwiftUI

struct SimulatorView: View {
    @EnvironmentObject private var analytics: AnalyticsManager
    @EnvironmentObject private var demo: DemoStore

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button("Next day (new session)", action: demo.nextDay)
                    Button("Run onboarding", action: demo.runOnboarding)
                } header: {
                    Text("User · simulated day \(demo.simulatedDay)")
                } footer: {
                    Text("Moving to day 1, 3, 7, 14 and 30 logs retention_d1 … retention_d30.")
                }

                Section("Subscriptions") {
                    Button("Start free trial", action: demo.startTrial)
                    Button("Renew / convert trial", action: demo.renewSubscription)
                    Button("Turn off auto-renew") { demo.updateSubscription(.active, autoRenew: false) }
                    Button("Turn auto-renew back on") { demo.updateSubscription(.active, autoRenew: true) }
                    Button("Billing issue") { demo.updateSubscription(.inBillingRetry, autoRenew: true) }
                    Button("Expire") { demo.updateSubscription(.expired, autoRenew: false) }
                }

                Section("One-time purchases") {
                    Button("Buy 500 coins (€4.99)", action: demo.buyCoins)
                    Button("Buy lifetime ($29.99)", action: demo.buyLifetime)
                    Button("Open paywall and cancel", action: demo.cancelPurchase)
                    Button("Refund last purchase", role: .destructive, action: demo.refundLast)
                }

                Section("Ads") {
                    Button("Show interstitial", action: demo.showInterstitial)
                    Button("Show rewarded", action: demo.showRewarded)
                    Button("Banner impression", action: demo.showBanner)
                    Button("Click ad", action: demo.clickAd)
                    Button("Ad blocked by frequency cap", action: demo.blockAd)
                    Button("No fill (load failed)", action: demo.missAd)
                }

                Section {
                    Button("Reset all data", role: .destructive, action: demo.resetAll)
                }
            }
            .navigationTitle("Simulate")
            .trackScreen("Simulator", analytics: analytics)
        }
    }
}
