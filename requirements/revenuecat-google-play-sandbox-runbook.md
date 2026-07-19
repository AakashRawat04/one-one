# RevenueCat + Google Play sandbox runbook (Android)

This checklist reflects the code on branch
`nudge-consolidation-bulati-hai-magar-jane-ka-nahi`. Dashboard items cannot be
verified from source, so they remain unchecked until confirmed in the relevant
console.

## Already done in code

- [x] `purchases_flutter` and `purchases_ui_flutter` are included (currently
  `^10.4.1`).
- [x] Android declares `com.android.vending.BILLING`.
- [x] RevenueCat receives the authenticated Firebase UID as `appUserID`.
- [x] Android and Apple public SDK keys are supplied through dart defines; no
  RevenueCat secret key is embedded.
- [x] The entitlement gate checks the exact case-sensitive entitlement ID
  `OneOne_Pro`.
- [x] Customer-info updates refresh the root entitlement gate.
- [x] RevenueCat Paywalls are presented with the offering selected by Remote
  Config and the Play storefront country.
- [x] Restore Purchases is available on the blocker.
- [x] Customer Center support exists in `RevenueCatService`.
- [x] Remote Config controls normal/extreme pricing, the internal validation
  grace period, rollout timestamp, and all four offering IDs.
- [x] Internal redeem codes are validated by the authenticated backend, stored
  only as SHA-256 hashes, rate-limited, and granted as a Firebase custom claim.
- [x] Public binaries fail closed when subscription initialization cannot be
  verified.
- [x] Public binaries hard-gate all unsubscribed users regardless of whether
  Remote Config selects normal or extreme pricing. The tier selects the
  offering; it does not weaken the public entitlement gate.
- [x] Redeem access now requires **both**
  `ONE_ONE_BUILD_AUDIENCE=internal` and Remote Config
  `subscription_developer_redeem_enabled=true`. Public is the compile-time
  default and ignores the Remote Config redeem flag.
- [x] Internal builds support a Remote Config controlled short test window via
  `subscription_internal_trial_hours` (default six hours). Public builds ignore
  grace windows for access enforcement and hard-gate on entitlement.

## Still needed in code / release automation

- [ ] Wire `RevenueCatService.presentCustomerCenter()` to a "Manage
  subscription" row in Settings if account management is required in-app.
- [ ] Add CI/release commands that always pass
  `--dart-define=ONE_ONE_BUILD_AUDIENCE=public` for Play production, even though
  omitted/invalid values already fail closed to public.
- [ ] Add an internal-track command that explicitly passes
  `--dart-define=ONE_ONE_BUILD_AUDIENCE=internal`.
- [ ] Supply the Android **public SDK key** at build time with
  `ONE_ONE_REVENUECAT_ANDROID_API_KEY=goog_...`.
- [x] Public production uses an immediate hard entitlement gate. Internal
  builds alone use the extreme-tier activation timestamp and short trial.

## RevenueCat dashboard

### Project and Android app

- [ ] Create/select the Treebowl / One-One RevenueCat project.
- [ ] Add a Google Play app whose package name is exactly
  `app.oneone.one_one_app`.
- [ ] Copy that app's `goog_...` **public SDK key** into the Android build
  environment. Never use an `sk_...` secret key in Flutter.
- [ ] Upload Google Play service-account credentials under the RevenueCat
  Google Play app settings.
- [ ] Confirm RevenueCat's credential validator reports valid access for the
  subscriptions, in-app products/monetization, and financial/order APIs.
  RevenueCat notes that new credentials can take up to 36 hours to validate.
- [ ] Configure Google Real-time Developer Notifications/Pub/Sub so renewals,
  cancellations, grace period, and billing retry reach RevenueCat promptly.

### Products, entitlement, offerings, and paywalls

- [ ] Import every active Google Play **base plan** into RevenueCat. RevenueCat
  products map to Play base plans and normally appear as
  `<subscription-id>:<base-plan-id>`.
- [ ] Create the case-sensitive entitlement `OneOne_Pro`.
- [ ] Attach all eight monthly/quarterly normal/extreme India/international
  RevenueCat products to `OneOne_Pro`.
- [ ] Create these exact offering IDs because they are the app defaults:
  - [ ] `normal_india`
  - [ ] `normal_international`
  - [ ] `extreme_india`
  - [ ] `extreme_international`
- [ ] Put exactly one monthly and one three-month package in each offering.
- [ ] Use standard RevenueCat package identifiers (`$rc_monthly` and a custom
  quarterly package, or two clearly named custom packages) consistently.
- [ ] Build and publish a RevenueCat Paywall for every offering.
- [ ] Verify each paywall's purchase buttons reference packages from its own
  offering and that Restore Purchases is available.
- [ ] Use the Sandbox Data toggle to verify test transactions and entitlement
  activation for the Firebase UID shown as the RevenueCat App User ID.
- [ ] Webhooks are optional for the current client-side entitlement gate. Add a
  signed webhook only if the backend needs its own subscription ledger,
  analytics, or server-side authorization decisions.

### Known product-ID mismatch to resolve

The app hardcodes **offering IDs**, not Play product IDs. The older rollout
document lists bare IDs such as `oneone_normal_in_monthly`, while current Google
Play subscriptions require a subscription plus an active base plan and
RevenueCat maps products to those base plans. Therefore a bare ID is not enough
to verify dashboard alignment.

Choose one catalog convention and use it in both Play and RevenueCat. A compact
recommended catalog is:

| RevenueCat product identifier | Offering | Billing period |
| --- | --- | --- |
| `oneone_normal_in:monthly` | `normal_india` | P1M |
| `oneone_normal_in:quarterly` | `normal_india` | P3M |
| `oneone_normal_intl:monthly` | `normal_international` | P1M |
| `oneone_normal_intl:quarterly` | `normal_international` | P3M |
| `oneone_extreme_in:monthly` | `extreme_india` | P1M |
| `oneone_extreme_in:quarterly` | `extreme_india` | P3M |
| `oneone_extreme_intl:monthly` | `extreme_international` | P1M |
| `oneone_extreme_intl:quarterly` | `extreme_international` | P3M |

If the eight previously documented IDs already exist as eight separate Play
subscriptions, keep them, create an active base plan on each, and import the
resulting `<existing-subscription-id>:<base-plan-id>` identifiers. Do not rename
an activated Play product merely to match this recommendation.

## Google Play Console

### App and billing prerequisites

- [ ] The Play app package is exactly `app.oneone.one_one_app`.
- [ ] Complete the required developer/merchant payments profile, agreements,
  tax and banking setup. Store products may not load when required commercial
  agreements are incomplete.
- [ ] Complete the minimum app-content and store-listing requirements required
  to publish an internal/closed test release.
- [ ] Upload a signed AAB containing the Billing permission to an internal or
  closed testing track.
- [ ] Confirm the uploaded build's version code is new and its package name is
  unchanged. Play App Signing may use a different signing certificate from the
  local upload key; RevenueCat product lookup primarily depends on package and
  Play distribution, while Firebase/Google sign-in must contain all applicable
  SHA certificates.
- [ ] Make the testing release available in the tester's country/region.

### Subscriptions and base plans

- [ ] Create the four recommended subscriptions above, or confirm the eight
  existing subscription IDs that will be retained.
- [ ] Create active, auto-renewing P1M and P3M base plans as required by the
  chosen catalog.
- [ ] Configure India and international regional availability deliberately.
  Play base plans support per-region prices; do not rely on the device locale.
- [ ] Set placeholder prices to the agreed normal/extreme amounts, then review
  Play's generated regional prices and taxes.
- [ ] Activate every base plan. Draft/inactive plans will not appear in
  RevenueCat offerings on-device.
- [ ] Configure Play renewal grace period/account hold separately from the
  app's demand-based Remote Config grace period; they solve different problems.
- [ ] Offers/free trials are optional. Do not confuse the app's internal
  six-hour blocker test window with a Play subscription free trial (Play free
  trials have their own store rules and sandbox timing).

### Sandbox testers

- [ ] Add each test Google account under Play Console **License testing**.
- [ ] Add the same accounts to the chosen internal/closed track tester list.
- [ ] Open the track opt-in URL while signed into the tester account and accept
  the invitation.
- [ ] Install the build from Google Play at least once. For sideloaded debug
  builds, the package must still match and the account must be a license tester.
- [ ] Use one primary Play account on the device while diagnosing sandbox
  purchases; the account that downloaded the app is normally charged.
- [ ] Confirm the purchase sheet says it is a test purchase and offers Google's
  test payment instruments. Otherwise stop—a real charge is possible.
- [ ] Test monthly purchase, quarterly purchase, restore after reinstall/login,
  cancellation, renewal, declined renewal, grace period, account hold, and
  expiration. Google accelerates sandbox renewals (approximately five minutes
  for monthly and ten minutes for three-month plans, up to six renewals).

## Remote Config and build matrix

### Internal/dev paywall

- [ ] Build with `ONE_ONE_BUILD_AUDIENCE=internal`.
- [ ] Set `subscription_pricing_tier=extreme`.
- [ ] Set `subscription_extreme_activated_at_ms` to the current UTC epoch ms.
- [ ] Set `subscription_internal_trial_hours=6`.
- [ ] Set `subscription_developer_redeem_enabled=true`.
- [ ] Put one or more SHA-256 code hashes in backend secret
  `SUBSCRIPTION_REDEEM_CODE_HASHES` and redeploy the backend.
- [ ] Verify purchase, restore, valid redeem, invalid redeem/rate limit, and the
  blocker appearing after the short trial.

### Public/store paywall

- [ ] Build with `ONE_ONE_BUILD_AUDIENCE=public` (also the source default).
- [ ] Set `subscription_developer_redeem_enabled=false` as defense in depth.
- [ ] Verify that deliberately setting the flag true still does **not** display
  redeem UI in the public binary and does not honor a developer claim.
- [ ] Verify an active `OneOne_Pro` entitlement unlocks the app.
- [ ] Verify both `normal` and `extreme` Remote Config values keep an
  unsubscribed public user blocked while selecting the matching offering.
- [ ] Verify an unsubscribed user cannot bypass an enforced blocker by closing
  the RevenueCat paywall, going offline, or causing subscription initialization
  to fail.

## Current blockers until dashboards are confirmed

- [ ] No Android RevenueCat `goog_...` key is stored in source, so a build made
  without the required dart define cannot initialize RevenueCat.
- [ ] Source cannot prove that the Play products/base plans are active or that
  RevenueCat imported them.
- [ ] Source cannot prove that `OneOne_Pro`, the four offerings, and their
  paywalls exist with exact case-sensitive identifiers.
- [ ] Source cannot prove Google service credentials or RTDN are valid in
  RevenueCat.
- [ ] Source cannot prove Remote Config has been published; the checked-in
  template is not automatically the live template.

## Primary references

- RevenueCat Google Play service credentials:
  https://www.revenuecat.com/docs/service-credentials/creating-play-service-credentials
- RevenueCat Google Play product/base-plan setup:
  https://www.revenuecat.com/docs/getting-started/entitlements/android-products
- RevenueCat Android sandbox testing:
  https://www.revenuecat.com/docs/test-and-launch/sandbox/google-play-store
- RevenueCat Paywalls:
  https://www.revenuecat.com/docs/tools/paywalls
- Google Play Billing testing:
  https://developer.android.com/google/play/billing/test
- Google Play subscription/base-plan model:
  https://support.google.com/googleplay/android-developer/answer/12154973
- Firebase Remote Config parameters and conditions:
  https://firebase.google.com/docs/remote-config/parameters
