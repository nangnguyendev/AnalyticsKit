# Changelog

## [1.0.0] - 2026-10-22

### Added
- `AnalyticsManager`: provider fan-out, Firebase-safe sanitizer, sessions, retention milestones, install cohorts, persisted state.
- Revenue: `trackPurchase` / `track(transaction:)` with trial, conversion, renewal, refund classification and de-duplication; `updateSubscriptionStatus` for cancel, reactivate, billing issue and expiry; paywall funnel events.
- Ads: `ad_impression` revenue, `total_ads_revenue_001` threshold event, request / load / opportunity / show / click / reward events.
- User properties for tier, monetization, payer status, LTV and impression buckets, sessions and cohorts.
- `AnalyticsKitFirebase`: `FirebaseAnalyticsProvider` for Firebase Analytics 13.x.
- `AnalyticsKitAdKit`: bridge from AdKit `AdEvent`s.
- Metrics guide with KPI formulas and BigQuery queries in `Docs/Metrics.md`.
- Example app `Examples/AnalyticsKitExample`.
