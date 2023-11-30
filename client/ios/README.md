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
4. Set up backend, perhaps by [remixing the sample Glitch project](#remix-the-sample-backend-on-glitch)
5. [Request access](https://stripe.com/docs/issuing/cards/digital-wallets?platform=iOS#request-access)
7. In the `BuildSettings.xcconfig`, configure the following to match your backend:
   - `SAMPLE_PP_BACKEND_URL`
   - `SAMPLE_PP_BACKEND_USERNAME`
   - `SAMPLE_PP_BACKEND_PASSWORD`
   - See [remixing the sample Glitch project](#remix-the-sample-backend-on-glitch) for what these values should be if you use the provided sample backend.

### Deploy the iOS app

- The app must:
  - be registered with your Apple Developer account on App Store Connect
  - use a valid provisioning profile associated with the app bundle identifier and Apple Developer Team.
  - include the `com.apple.developer.payment-pass-provisioning` entitlement (see StripeIssuingExample.entitlements)
- [Remember](https://stripe.com/docs/issuing/cards/digital-wallets?platform=iOS#testing): The only way to test the end-to-end push provisioning flow is by distributing your app to real devices with TestFlight or the App Store.

### Remix the sample backend on Glitch

We provide a sample backend hosted on Glitch, allowing you to easily test an integration end-to-end.

1. [Open the Glitch project](https://glitch.com/edit/#!/stripe-push-provisioning-example-backend).
2. Click on "Remix", on the top right.
3. In your newly remixed Glitch project, open the `.env` file in the left sidebar.
4. Set your [Stripe livemode secret key](https://dashboard.stripe.com/apikeys) as the `STRIPE_SECRET_KEY` field in `.env`.
5. Set your [Stripe livemode cardholder ID](https://dashboard.stripe.com/issuing/cardholders) as the `CARDHOLDER_ID` field in `.env`.
6. Set the `USERNAME` and `PASSWORD` fields to values of your choice in `.env`.
7. Set the same values for `SAMPLE_PP_BACKEND_USERNAME` and `SAMPLE_PP_BACKEND_PASSWORD` in the `BuildSettings.xcconfig`.
8. Your backend implementation should now be running. You can see the logs by clicking on "Logs" in the bottom bar.
9. In Glitch, click "Share" then copy the "Live site" URL to use as the value for `SAMPLE_PP_BACKEND_URL` in the `BuildSettings.xcconfig`.

## Relevant documentation
- [Use digital wallets with Issuing](https://stripe.com/docs/issuing/cards/digital-wallets?platform=iOS)
- [PassKit Wallet APIs](https://developer.apple.com/documentation/passkit/wallet)
