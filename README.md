# AnalyticsKit

![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)
![Platforms](https://img.shields.io/badge/platforms-iOS%2015+-blue.svg)
![SPM](https://img.shields.io/badge/SPM-compatible-brightgreen.svg)
![License](https://img.shields.io/badge/license-MIT-lightgrey.svg)

A Swift Package that sends the metrics you need to run an iOS product to Firebase Analytics: **revenue** (ads + in-app purchases + subscriptions), **users** (retention, cohorts, funnels, LTV segments) and **ad performance** (fill rate, show rate, eCPM, CTR).

- **`AnalyticsKit`**: the dependency-free core.
  - One `AnalyticsManager` that fans events out to any number of providers.
  - A sanitizer that enforces Firebase limits (names, reserved events, 25 parameters, value lengths).
  - Subscription lifecycle from StoreKit 2: trial start, conversion, renewal, cancel, billing issue, expiry, refund, with de-duplication.
  - Ad impression revenue with the GA4 `ad_impression` schema and a `total_ads_revenue_001` threshold event for tROAS bidding.
  - Sessions, D1/D3/D7/D14/D30 retention events, install cohorts.
  - LTV / tier / monetization user properties, persisted on device.
  - `InMemoryAnalyticsProvider` and `ConsoleAnalyticsProvider` for tests and debugging; `.trackScreen()` for SwiftUI.
- **`AnalyticsKitFirebase`**: provider for Firebase Analytics 13.x (events, user properties, consent, `logTransaction`).
- **`AnalyticsKitAdKit`**: one-line bridge from [AdKit](https://github.com/nangnguyendev/Ads) events.

See [Docs/Metrics.md](Docs/Metrics.md) for every event, the KPI formulas, the Firebase console setup and BigQuery queries.

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/nangnguyendev/AnalyticsKit.git", from: "1.0.0")
],
targets: [
    .target(name: "MyApp", dependencies: [
        .product(name: "AnalyticsKit", package: "AnalyticsKit"),
        .product(name: "AnalyticsKitFirebase", package: "AnalyticsKit"),
        .product(name: "AnalyticsKitAdKit", package: "AnalyticsKit")
    ])
]
```

Add `GoogleService-Info.plist` to the app target and `-ObjC` to *Other Linker Flags*.

## Usage

### 1. Start at launch

```swift
import AnalyticsKit
import AnalyticsKitFirebase

@main
struct MyApp: App {
    @StateObject private var analytics: AnalyticsManager

    init() {
        FirebaseAnalyticsProvider.configureFirebaseIfPossible()
        _analytics = StateObject(wrappedValue: AnalyticsManager(
            configuration: AnalyticsConfiguration(lifetimeProductIDs: ["premium.lifetime"]),
            providers: [FirebaseAnalyticsProvider()]
        ))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(analytics)
                .task { analytics.start() }
        }
    }
}
```

`start()` records the install date, starts a session, logs retention milestones and sets cohort / LTV user properties. A new session begins after 30 minutes in the background.

### 2. Ads (AdKit)

```swift
import AnalyticsKitAdKit

analytics.connect(ads)
```

Every `AdEvent` becomes `ad_impression` (with revenue), `ad_opportunity`, `ad_show`, `ad_clicked`, `ad_reward_earned`, `ad_load_success`/`ad_load_fail`, plus `ad_consent` and `att_status` user properties. Existing `eventHandler`s keep working.

Other ad SDKs use the generic API:

```swift
analytics.trackAdOpportunity(format: "interstitial", placement: "level_end", outcome: .notReady)
analytics.trackAdImpression(AdImpression(value: 0.012, currency: "USD", platform: "AppLovin", source: "Meta", format: "interstitial", adUnitID: unitID, placement: "level_end"))
```

### 3. Purchases (IAP / StoreKit 2)

```swift
iap.transactionHandler = { transaction in
    analytics.track(transaction: transaction, product: iap.product(for: transaction.productID), placement: currentPaywallPlacement)
}

await analytics.refreshSubscriptionStatuses(for: iap.subscriptions)
```

`track(transaction:)` classifies the transaction (`trial_start`, `subscription_start`, `trial_convert`, `subscription_renew`, `iap_purchase`, `iap_refund`), ignores duplicates, updates LTV / tier and forwards it to `Analytics.logTransaction` so GA4 counts the revenue. Call `refreshSubscriptionStatuses` on launch and foreground to catch cancellations, billing issues and expiries.

Funnel around the paywall:

```swift
analytics.trackPaywallView("main", placement: "onboarding", variant: "b")
analytics.trackPurchaseStart(productID: product.id, placement: "onboarding")
switch try await iap.purchase(product) {
case .cancelled: analytics.trackPurchaseCancel(productID: product.id, placement: "onboarding")
default: break
}
analytics.trackPaywallClose("main", placement: "onboarding", purchased: iap.isPremium)
```

### 4. Users

```swift
analytics.trackOnboardingStep(1, name: "welcome")
analytics.trackOnboardingComplete()
analytics.trackFeature("alarm_created", parameters: ["mission": "shake"])
analytics.setExperiment("paywall_copy", variant: "b")
analytics.setUserID(account.id)
analytics.setConsent(.analyticsOnly)

Text("Home").trackScreen("Home", analytics: analytics)
```

### 5. Local metrics

```swift
let metrics = analytics.metrics
metrics.totalRevenue
metrics.averageECPM
metrics.userTier
```

Useful for in-app decisions (e.g. stop showing interstitials to `subscriber` or high-LTV users) and debug screens.

## Configuration

| Option | Default | Meaning |
|---|---|---|
| `reportingCurrency` | `USD` | Currency for LTV properties and the threshold event |
| `exchangeRates` | `[:]` | Rates to the reporting currency; revenue in other currencies is ignored for LTV |
| `adRevenueThreshold` | `0.01` | Logs `adRevenueThresholdEventName` each time ad revenue reaches it; `nil` turns it off |
| `retentionDays` | `[1, 3, 7, 14, 30]` | Days that log `retention_dN` |
| `sessionTimeout` | 30 min | Background time that starts a new session |
| `ltvBuckets`, `sessionBuckets`, `impressionBuckets` | see source | Bucket edges for user properties |
| `countsSandboxRevenue` | `false` | Include sandbox / Xcode purchases in LTV |
| `lifetimeProductIDs` | `[]` | Non-consumables that make the user `lifetime` |

## Example app

`Examples/AnalyticsKitExample` simulates ads, purchases, subscription changes and day changes, and shows the metrics, user properties and event log live. It works without Firebase; add a `GoogleService-Info.plist` to see the events in DebugView. The project is generated with XcodeGen (`project.yml`).

## Tests

```sh
swift test
```

The tests cover the sanitizer, sessions and retention, purchase classification, refunds, subscription status changes, ad revenue and the AdKit bridge.

## License

MIT
