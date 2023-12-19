# Stripe Push Provisioning Sample App - Android

## Purpose

This sample app demonstrates one way to
[Use digital wallets with Issuing](https://stripe.com/docs/issuing/cards/digital-wallets?platform=Android)--specifically
how the [Update your app](https://stripe.com/docs/issuing/cards/digital-wallets?platform=Android#update-your-app)
and [Update your backend](https://stripe.com/docs/issuing/cards/digital-wallets?platform=Android#update-your-backend)
sections can be implemented.

## Setup

1. Clone this repository
2. Open the project in Android Studio
3. Create a card using the Dashboard or API: https://stripe.com/docs/issuing/cards
4. Set up backend, perhaps by [remixing the sample Glitch project](#remix-the-sample-backend-on-glitch)
5. [Request access](https://stripe.com/docs/issuing/cards/digital-wallets?platform=Android#request-access)
6. Download Google's [private SDK](https://developers.google.com/pay/issuers/apis/push-provisioning/android/releases)
7. Unarchive it to the `./tapandpay_sdk/` directory, (sibling of  `app`), so, you will have a directory structure like `./tapandpay_sdk/com/google/android/gms/...` from the root of the Gradle project.
8. In the `gradle.properties`, configure the following to match your backend:
   - `SAMPLE_PP_BACKEND_URL`
   - `SAMPLE_PP_BACKEND_USERNAME`
   - `SAMPLE_PP_BACKEND_PASSWORD`
   - See [remixing the sample Glitch project](#remix-the-sample-backend-on-glitch) for what these values should be if you use the provided sample backend.
   - If `SAMPLE_PP_BACKEND_URL` doesn't start with `https://`, you'll likely need set `SAMPLE_PP_BACKEND_USES_CLEAR_TEXT_TRAFFIC` to `true` to [configure your app to allow cleartext traffic](https://stackoverflow.com/a/50834600/272132), but please be **careful about doing this for production** builds.
9. Open the Gradle project inside Android Studio and let the Gradle sync complete.

### Deploy the android app

- The app must be signed with a certificate that was [added to an allowlist](https://developers.google.com/pay/issuers/apis/push-provisioning/android/allowlist#allowlisting_internal_builds_of_your_app) by Google.
- Changes to the signing configuration may require a gradle sync and uninstall + reinstall of the app.
- [Remember](https://stripe.com/docs/issuing/cards/digital-wallets?platform=Android#testapp): All testing must be done in live mode, with live Issuing cards, and on physical devices (not emulators).

### Remix the sample backend on Glitch

We provide a sample backend hosted on Glitch, allowing you to easily test an integration end-to-end.

1. [Open the Glitch project](https://glitch.com/edit/#!/stripe-push-provisioning-example-backend).
2. Click on "Remix", on the top right.
3. In your newly remixed Glitch project, open the `.env` file in the left sidebar.
4. Set your [Stripe livemode secret key](https://dashboard.stripe.com/apikeys) as the `STRIPE_SECRET_KEY` field in `.env`.
5. Set your [Stripe livemode cardholder ID](https://dashboard.stripe.com/issuing/cardholders) as the `CARDHOLDER_ID` field in `.env`.
6. Set the `USERNAME` and `PASSWORD` fields to values of your choice in `.env`.
7. Set the same values for `SAMPLE_PP_BACKEND_USERNAME` and `SAMPLE_PP_BACKEND_PASSWORD` in the `gradle.properties`.
8. Your backend implementation should now be running. You can see the logs by clicking on "Logs" in the bottom bar.
9. In Glitch, click "Share" then copy the "Live site" URL to use as the value for `SAMPLE_PP_BACKEND_URL` in the `gradle.properties`.

## Relevant documentation
- [Use digital wallets with Issuing](https://stripe.com/docs/issuing/cards/digital-wallets?platform=Android)
- [Android Push Provisioning API](https://developers.google.com/pay/issuers/apis/push-provisioning/android)
- [Test Cases](https://developers.google.com/pay/issuers/apis/push-provisioning/android/test-cases)
