# RevenueCat subscription rollout

The app integration is complete, but products and prices must also exist in
App Store Connect, Google Play Console, and the RevenueCat dashboard. Store
catalogs cannot be created from the mobile SDK.

## Product catalog

Create the following auto-renewing products on both stores. Google Play
RevenueCat identifiers use `<subscription-id>:<base-plan-id>` when base plans
are used. The amounts below are rollout placeholders; the store remains the
source of truth for the localized price shown to the customer.

| Product ID | Duration | India placeholder | International placeholder |
| --- | --- | ---: | ---: |
| `oneone_normal_in_monthly` | 1 month | ₹29 | India only |
| `oneone_normal_in_quarterly` | 3 months | ₹80 | India only |
| `oneone_normal_intl_monthly` | 1 month | International only | US $3 |
| `oneone_normal_intl_quarterly` | 3 months | International only | US $8 |
| `oneone_extreme_in_monthly` | 1 month | ₹59 | India only |
| `oneone_extreme_in_quarterly` | 3 months | ₹150 | India only |
| `oneone_extreme_intl_monthly` | 1 month | International only | US $9 |
| `oneone_extreme_intl_quarterly` | 3 months | International only | US $26 |

Create a RevenueCat entitlement named `OneOne_Pro`. Attach every product to
that entitlement. Create four offerings, each with only a monthly and a
three-month package:

| Offering ID | Products |
| --- | --- |
| `normal_india` | `oneone_normal_in_monthly`, `oneone_normal_in_quarterly` |
| `normal_international` | `oneone_normal_intl_monthly`, `oneone_normal_intl_quarterly` |
| `extreme_india` | `oneone_extreme_in_monthly`, `oneone_extreme_in_quarterly` |
| `extreme_international` | `oneone_extreme_intl_monthly`, `oneone_extreme_intl_quarterly` |

Publish a RevenueCat paywall for each offering. Prices displayed in that
paywall come from the active store product, never from constants in the app.
The app selects India using the current App Store/Play Store storefront and
selects the offering ID using Firebase Remote Config.

## App build configuration

Use RevenueCat **public platform SDK keys**, not secret REST API keys:

```sh
flutter run \
  --dart-define=ONE_ONE_BUILD_AUDIENCE=internal \
  --dart-define=ONE_ONE_REVENUECAT_ANDROID_API_KEY=goog_xxx \
  --dart-define=ONE_ONE_REVENUECAT_APPLE_API_KEY=appl_xxx
```

The Firebase UID is used as the RevenueCat App User ID, preserving access
across reinstalls and devices for the same signed-in account.

`ONE_ONE_BUILD_AUDIENCE` is a compile-time safety boundary:

- `internal`: may show redeem UI only when Remote Config also enables it;
- `public`: never shows or honors developer bypass access.

The default is `public`, including for missing or misspelled values. Production
CI should still pass `public` explicitly. Remote Config cannot turn an already
compiled public binary into an internal binary.

## Remote Config rollout

The source-controlled template is
`firebase/remote-config.template.json`. Publish it deliberately because a
Remote Config publish replaces the active template:

```sh
firebase remoteconfig:get -o /tmp/current-remote-config.json
firebase deploy --only remoteconfig
```

For an extreme rollout, publish these values together:

- `subscription_pricing_tier`: `extreme`
- `subscription_grace_period_days`: `7` or `14`
- `subscription_extreme_activated_at_ms`: the rollout time in UTC epoch ms
- `subscription_internal_trial_hours`: internal binary only; use `6` for the
  current short end-to-end test cycle

Setting an explicit activation timestamp gives every existing user the same
deadline. If it is left at `0`, each device falls back to the first time it
observes extreme mode. Offering IDs are separate Remote Config parameters, so
the dashboard catalog can be replaced without an app release. Real-time Remote
Config updates are activated while the app is running.

## Developer redeem codes

Developer access is account-bound and server-verified. No redeem code or hash
is shipped in the app.

1. Generate a high-entropy code (at least 20 random characters).
2. Normalize it to uppercase and store only its SHA-256 hash in the backend:

   ```sh
   printf %s 'YOUR-LONG-CODE' | tr '[:lower:]' '[:upper:]' | shasum -a 256
   ```

3. Put one or more comma-separated hashes in the deployment secret
   `SUBSCRIPTION_REDEEM_CODE_HASHES`.
4. Build with `ONE_ONE_BUILD_AUDIENCE=internal` and set
   `subscription_developer_redeem_enabled=true` in Remote Config.

The authenticated endpoint grants the Firebase custom claim
`oneOneDeveloper=true` and the app force-refreshes the ID token. Attempts are
rate-limited and codes are compared with constant-time hashes. To revoke a
developer, remove that claim in Firebase Admin/Auth; to stop new redemptions,
disable the Remote Config flag and rotate/remove the backend hashes.

Public binaries ignore both the developer claim and redeem flag even when an
operator accidentally leaves the Remote Config value enabled.

Do not use this flow as an alternative consumer payment method. It is for
approved internal team accounts; App Store and Play Store sandbox/test users
remain the preferred purchase-testing path.

## Verification checklist

- Android closed-track build can query both packages in every offering.
- iOS sandbox build can query both packages and restore purchases.
- Storefront `IN`/`IND` selects the India offering; other storefronts select
  international.
- Public/store binaries block every unsubscribed user; normal versus extreme
  selects pricing only. Internal binaries use the extreme-tier trial window.
- Internal extreme tier blocks only after the configured shared deadline.
- `OneOne_Pro` unlocks every distribution; `oneOneDeveloper` unlocks only an
  internal binary.
- Invalid codes return a generic error and rate-limit after five attempts.

References: [RevenueCat Flutter installation](https://www.revenuecat.com/docs/getting-started/installation/flutter),
[RevenueCat product configuration](https://www.revenuecat.com/docs/projects/configuring-products),
[Firebase Remote Config for Flutter](https://firebase.google.com/docs/remote-config/flutter/get-started),
[Firebase custom claims](https://firebase.google.com/docs/auth/admin/custom-claims).
