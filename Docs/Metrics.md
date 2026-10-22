# Metrics guide

This page lists every event and user property AnalyticsKit sends, the KPIs you can build from them, and how to set up Firebase / GA4 / BigQuery so the numbers show up.

## 1. KPIs

### Revenue

| KPI | Formula | Source |
|---|---|---|
| Ad revenue | Σ `ad_impression.value` | `ad_impression` |
| IAP revenue (gross) | GA4 *Purchase revenue* (from `in_app_purchase`, logged by `Analytics.logTransaction`) | Firebase |
| IAP revenue (per event) | Σ `value` of `iap_purchase`, `subscription_start`, `trial_convert`, `subscription_renew` − Σ `iap_refund.value` | custom events |
| Total revenue | Ad revenue + IAP revenue | |
| ARPDAU | Total revenue of the day ÷ DAU | |
| ARPU / ARPPU | Revenue ÷ users, revenue ÷ paying users (`is_payer = true`) | |
| LTV Dn | Revenue per install cohort (`install_cohort`) up to day n ÷ installs in the cohort | BigQuery |
| Payer conversion | Users with `is_payer = true` ÷ users | user property |
| Refund rate | `iap_refund` count ÷ paid purchase count | |

### Subscriptions

| KPI | Formula |
|---|---|
| Paywall conversion | `purchase_start` ÷ `paywall_view` (same `placement`); paid events ÷ `paywall_view` |
| Purchase success rate | (`trial_start` + `subscription_start` + `iap_purchase`) ÷ `purchase_start` |
| Cancel at checkout | `purchase_cancel` ÷ `purchase_start` |
| Trial start rate | `trial_start` users ÷ new users |
| Trial → paid | `trial_convert` ÷ `trial_start` (cohort by trial start date) |
| Auto-renew off rate | `subscription_cancel` ÷ active subscribers |
| Involuntary churn | `subscription_billing_issue` ÷ active subscribers |
| Churn | `subscription_expire` ÷ active subscribers at period start |
| Active subscribers | users with `user_tier` in (`subscriber`, `trial`) |

### Users

| KPI | Formula |
|---|---|
| DAU / WAU / MAU | Firebase *Active users* (automatic) |
| Stickiness | DAU ÷ MAU |
| Retention D1/D3/D7/D14/D30 | users with `retention_dN` ÷ installs in the cohort, or Firebase *Retention* report |
| Sessions per user | Firebase `session_start` ÷ users; `session_bucket` for segmentation |
| Onboarding completion | `tutorial_complete` ÷ `tutorial_begin`; per-step drop-off with `onboarding_step.step` |
| Feature adoption | users with `feature_used` (by `feature`) ÷ active users |

### Ads

| KPI | Formula |
|---|---|
| Impressions per DAU | `ad_impression` count ÷ DAU (by `ad_format`) |
| eCPM | Σ `ad_impression.value` ÷ impressions × 1000 (by `ad_format`, `ad_source`, `placement`) |
| Fill rate | `ad_load_success` ÷ (`ad_load_success` + `ad_load_fail`) |
| Show rate | `ad_opportunity` with `result = shown` ÷ all `ad_opportunity` where `result != blocked` |
| Missed opportunities | `ad_opportunity` with `result = not_ready` (ad not loaded in time) |
| Policy blocks | `ad_opportunity` with `result = blocked`, by `reason` (frequency caps, grace period…) |
| CTR | `ad_clicked` ÷ `ad_impression` |
| Rewarded completion | `ad_reward_earned` ÷ rewarded `ad_show` |
| Load latency | avg / p90 of `ad_load_success.latency_ms` |
| Ad-only users | `monetization = ads_only` |
| Ads vs IAP cannibalisation | compare `iap_ltv_bucket` of users by `ad_impr_bucket` |

## 2. Event dictionary

| Event | When | Parameters |
|---|---|---|
| `screen_view` | screen appears (`.trackScreen`) | `screen_name`, `screen_class` |
| `tutorial_begin`, `onboarding_step`, `tutorial_complete` | onboarding | `step`, `step_name` |
| `sign_up`, `login` | account | `method` |
| `feature_used` | key feature used | `feature`, custom |
| `retention_d1` … `retention_d30` | first session on calendar day N after install | `day`, `session_number` |
| `paywall_view`, `paywall_close` | paywall shown / closed | `paywall_id`, `placement`, `variant`, `purchased` |
| `purchase_start`, `purchase_cancel`, `purchase_fail`, `purchase_restore` | checkout | `product_id`, `placement`, `error_message`, `restored_count` |
| `iap_purchase` | consumable / non-consumable / non-renewing | `product_id`, `product_type`, `value`, `currency`, `transaction_id`, `original_transaction_id`, `offer_type`, `environment`, `placement` |
| `trial_start` | first transaction of a free trial | same as above, `value = 0` |
| `subscription_start` | first paid transaction | same |
| `trial_convert` | first paid renewal after a trial | same |
| `subscription_renew` | later renewals | same |
| `iap_refund` | transaction revoked | same |
| `subscription_cancel`, `subscription_reactivate` | auto-renew turned off / on | `product_id`, `original_transaction_id`, `offer_type` |
| `subscription_billing_issue` | entered billing retry | same |
| `subscription_expire` | expired (trial or paid) | same |
| `ad_request`, `ad_load_success`, `ad_load_fail` | ad loading | `ad_format`, `ad_unit_name`, `latency_ms`, `error_message` |
| `ad_opportunity` | the app wanted to show a full-screen ad | `ad_format`, `placement`, `result` (`shown`, `not_ready`, `blocked`), `reason` |
| `ad_show`, `ad_show_fail` | full-screen ad presented / failed | `ad_format`, `placement`, `error_message` |
| `ad_impression` | paid impression (GA4 standard, counts as ad revenue) | `ad_platform`, `ad_source`, `ad_format`, `ad_unit_name`, `placement`, `precision`, `value`, `currency` |
| `ad_clicked` | ad click | `ad_format`, `placement` |
| `ad_reward_earned` | rewarded ad granted a reward | `placement`, `reward_type`, `reward_amount` |
| `total_ads_revenue_001` | every time accumulated ad revenue reaches $0.01 | `value`, `currency` |

`ad_click`, `ad_reward`, `in_app_purchase`, `session_start`, `first_open` and other Firebase reserved names are rejected by the sanitizer, which is why the ad events above use `ad_clicked` / `ad_reward_earned`.

Firebase already logs `first_open`, `session_start`, `user_engagement`, `app_remove`, `app_update`, `os_update` automatically. `in_app_purchase` comes from `Analytics.logTransaction` (StoreKit 2), which `FirebaseAnalyticsProvider` calls for every new transaction passed to `track(transaction:)`.

## 3. User properties

| Name | Values |
|---|---|
| `user_tier` | `free`, `trial`, `subscriber`, `billing_issue`, `lapsed`, `lifetime` |
| `monetization` | `none`, `ads_only`, `iap_only`, `hybrid` |
| `is_payer` | `true`, `false` |
| `iap_ltv_bucket`, `ad_ltv_bucket`, `total_ltv_bucket` | `0`, `0-0.1`, `0.1-0.5`, `0.5-1`, `1-5`, `5-20`, `20-50`, `50-100`, `100+` (reporting currency) |
| `ad_impr_bucket` | `0`, `1`, `2-10`, `11-50`, `51-100`, `101-500`, `501-1000`, `1001+` |
| `session_bucket` | `1`, `2-3`, `4-7`, `8-15`, `16-30`, `31-60`, `61+` |
| `install_cohort`, `install_week` | `2026-10-22`, `2026-W43` |
| `sub_product`, `sub_auto_renew` | product id, `true` / `false` |
| `att_status`, `ad_consent` | from AdKit (`authorized`, `denied`…; `obtained`, `not_required`…) |
| `exp_<name>` | A/B variant from `setExperiment` |

Firebase allows 25 user properties per project. AnalyticsKit uses 14, so keep experiments to a handful.

## 4. Firebase / GA4 setup

1. **Custom definitions** (GA4 ▸ Admin ▸ Custom definitions). Register the user properties above as *user-scoped* dimensions and these as *event-scoped*: `placement`, `ad_format`, `ad_source`, `result`, `reason`, `product_id`, `product_type`, `offer_type`, `paywall_id`, `variant`, `step`, `feature`, `environment`. Register `latency_ms`, `reward_amount` as custom metrics. Only registered parameters appear in reports (BigQuery always has them all).
2. **Key events**: mark `trial_start`, `subscription_start`, `trial_convert`, `iap_purchase`, `total_ads_revenue_001`, `retention_d1` as key events. Import them into Google Ads / Apple Search Ads tooling for value-based bidding (`total_ads_revenue_001` + `in_app_purchase` give tROAS a real value).
3. **Link AdMob** to the Firebase project so AdMob reports join with analytics. With AdKit's paid event handler, `ad_impression` reports impression-level revenue even for mediation networks.
4. **Link BigQuery** (Project settings ▸ Integrations ▸ BigQuery, daily + streaming export). Needed for cohort LTV and anything beyond the standard reports.
5. **Filter sandbox**: subscription events carry `environment`; filter `environment = "production"` in reports. AnalyticsKit leaves sandbox revenue out of LTV properties unless `countsSandboxRevenue` is on.
6. **DebugView**: run with `-FIRDebugEnabled` (already set in the example scheme).
7. **Consent**: call `analytics.setConsent(...)` after UMP / ATT. AdKit's bridge sets `ad_consent` and `att_status`.

## 5. BigQuery recipes

Replace `project.analytics_XXXX` with your dataset.

**ARPDAU by revenue source**

```sql
SELECT
  event_date,
  COUNT(DISTINCT user_pseudo_id) AS dau,
  SUM(IF(event_name = 'ad_impression', (SELECT value.double_value FROM UNNEST(event_params) WHERE key = 'value'), 0)) AS ad_revenue,
  SUM(IF(event_name = 'in_app_purchase', event_value_in_usd, 0)) AS iap_revenue,
  SAFE_DIVIDE(
    SUM(IF(event_name = 'ad_impression', (SELECT value.double_value FROM UNNEST(event_params) WHERE key = 'value'), 0))
    + SUM(IF(event_name = 'in_app_purchase', event_value_in_usd, 0)),
    COUNT(DISTINCT user_pseudo_id)) AS arpdau
FROM `project.analytics_XXXX.events_*`
WHERE _TABLE_SUFFIX BETWEEN FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)) AND FORMAT_DATE('%Y%m%d', CURRENT_DATE())
GROUP BY event_date
ORDER BY event_date
```

**eCPM, CTR by format and source**

```sql
WITH ads AS (
  SELECT
    event_name,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'ad_format') AS ad_format,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'ad_source') AS ad_source,
    (SELECT value.double_value FROM UNNEST(event_params) WHERE key = 'value') AS value
  FROM `project.analytics_XXXX.events_*`
  WHERE event_name IN ('ad_impression', 'ad_clicked')
    AND _TABLE_SUFFIX >= FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY))
)
SELECT
  ad_format,
  ad_source,
  COUNTIF(event_name = 'ad_impression') AS impressions,
  SUM(value) AS revenue,
  SAFE_DIVIDE(SUM(value), COUNTIF(event_name = 'ad_impression')) * 1000 AS ecpm,
  SAFE_DIVIDE(COUNTIF(event_name = 'ad_clicked'), COUNTIF(event_name = 'ad_impression')) AS ctr
FROM ads
GROUP BY ad_format, ad_source
ORDER BY revenue DESC
```

**Show rate per placement**

```sql
SELECT
  (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'placement') AS placement,
  COUNTIF((SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'result') = 'shown') AS shown,
  COUNTIF((SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'result') = 'not_ready') AS missed,
  SAFE_DIVIDE(
    COUNTIF((SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'result') = 'shown'),
    COUNTIF((SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'result') != 'blocked')) AS show_rate
FROM `project.analytics_XXXX.events_*`
WHERE event_name = 'ad_opportunity'
GROUP BY placement
```

**Cohort LTV D0–D30**

```sql
WITH installs AS (
  SELECT user_pseudo_id, MIN(PARSE_DATE('%Y%m%d', event_date)) AS install_date
  FROM `project.analytics_XXXX.events_*`
  WHERE event_name = 'first_open'
  GROUP BY user_pseudo_id
),
revenue AS (
  SELECT
    user_pseudo_id,
    PARSE_DATE('%Y%m%d', event_date) AS day,
    CASE
      WHEN event_name = 'ad_impression' THEN (SELECT value.double_value FROM UNNEST(event_params) WHERE key = 'value')
      WHEN event_name = 'in_app_purchase' THEN event_value_in_usd
    END AS usd
  FROM `project.analytics_XXXX.events_*`
  WHERE event_name IN ('ad_impression', 'in_app_purchase')
)
SELECT
  i.install_date,
  COUNT(DISTINCT i.user_pseudo_id) AS installs,
  SAFE_DIVIDE(SUM(IF(DATE_DIFF(r.day, i.install_date, DAY) = 0, r.usd, 0)), COUNT(DISTINCT i.user_pseudo_id)) AS ltv_d0,
  SAFE_DIVIDE(SUM(IF(DATE_DIFF(r.day, i.install_date, DAY) <= 7, r.usd, 0)), COUNT(DISTINCT i.user_pseudo_id)) AS ltv_d7,
  SAFE_DIVIDE(SUM(IF(DATE_DIFF(r.day, i.install_date, DAY) <= 30, r.usd, 0)), COUNT(DISTINCT i.user_pseudo_id)) AS ltv_d30
FROM installs i
LEFT JOIN revenue r USING (user_pseudo_id)
GROUP BY i.install_date
ORDER BY i.install_date DESC
```

**Trial → paid conversion**

```sql
SELECT
  FORMAT_DATE('%Y-%W', PARSE_DATE('%Y%m%d', event_date)) AS week,
  COUNT(DISTINCT IF(event_name = 'trial_start', (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'original_transaction_id'), NULL)) AS trials,
  COUNT(DISTINCT IF(event_name = 'trial_convert', (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'original_transaction_id'), NULL)) AS converted
FROM `project.analytics_XXXX.events_*`
WHERE event_name IN ('trial_start', 'trial_convert')
  AND (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'environment') = 'production'
GROUP BY week
ORDER BY week DESC
```
