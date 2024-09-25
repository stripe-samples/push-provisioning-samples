# Stripe Push Provisioning Sample App - iOS

## Purpose

This sample app demonstrates one way to
[Use digital wallets with Issuing](https://stripe.com/docs/issuing/cards/digital-wallets?platform=iOS)--specifically
how the [Check eligibility](https://stripe.com/docs/issuing/cards/digital-wallets?platform=iOS#check-eligibility),
[Provision a card](https://stripe.com/docs/issuing/cards/digital-wallets?platform=iOS#provision-a-card) and
[Update your backend](https://stripe.com/docs/issuing/cards/digital-wallets?platform=iOS#update-your-backend)
sections can be implemented.

## Setup

1. Clone this repository
2. Open the project in Xcode
3. Create a card using the Dashboard or API: https://stripe.com/docs/issuing/cards
4. [Request access](https://stripe.com/docs/issuing/cards/digital-wallets?platform=iOS#request-access)
5. In the `BuildSettings.xcconfig`, configure the following to match your backend:
   - `SAMPLE_PP_BACKEND_URL`
   - `SAMPLE_PP_BACKEND_USERNAME`
   - `SAMPLE_PP_BACKEND_PASSWORD`  
   See [the backend readme](../../server/ruby/README.md) for configuration details.

### Deploy the iOS app

- The app must:
  - be registered with your Apple Developer account on App Store Connect
  - use a valid provisioning profile associated with the app bundle identifier and Apple Developer Team.
  - include the `com.apple.developer.payment-pass-provisioning` entitlement (see StripeIssuingExample.entitlements)
- [Remember](https://stripe.com/docs/issuing/cards/digital-wallets?platform=iOS#testing): The only way to test the end-to-end push provisioning flow is by distributing your app to real devices with TestFlight or the App Store.

## Relevant documentation
- [Use digital wallets with Issuing](https://stripe.com/docs/issuing/cards/digital-wallets?platform=iOS)
- [PassKit Wallet APIs](https://developer.apple.com/documentation/passkit/wallet)
