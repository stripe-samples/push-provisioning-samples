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
4. [Request access](https://stripe.com/docs/issuing/cards/digital-wallets?platform=Android#request-access)
5. Download Google's [private SDK](https://developers.google.com/pay/issuers/apis/push-provisioning/android/releases)
6. Unarchive it to the `./tapandpay_sdk/` directory, (sibling of  `app`), so, you will have a directory structure like `./tapandpay_sdk/com/google/android/gms/...` from the root of the Gradle project.
7. In the `gradle.properties`, configure the following to match your backend:
   - `SAMPLE_PP_BACKEND_URL`
   - `SAMPLE_PP_BACKEND_USERNAME`
   - `SAMPLE_PP_BACKEND_PASSWORD`
   - See [the backend readme](../../server/ruby/README.md) for configuration details.
   - If `SAMPLE_PP_BACKEND_URL` doesn't start with `https://`, you'll likely need set `SAMPLE_PP_BACKEND_USES_CLEAR_TEXT_TRAFFIC` to `true` to [configure your app to allow cleartext traffic](https://stackoverflow.com/a/50834600/272132), but please be **careful about doing this for production** builds.
8. Open the Gradle project inside Android Studio and let the Gradle sync complete.

### Deploy the android app

- This will address `Could not get unknown property 'SIGNING_KEYSTORE'`
- The app must be signed with a certificate that was [added to an allowlist](https://developers.google.com/pay/issuers/apis/push-provisioning/android/allowlist#allowlisting_internal_builds_of_your_app) by Google.
- This means the [default debug keystore setup done by Android Studio](https://developer.android.com/studio/publish/app-signing#debug-mode) will *not* work since it's different on everyone's dev machine.
- Instead, set up the app signing configuration with a shared keystore available to anyone on your team who needs to create debug builds of the app.
  1. Create a debug signing keystore. You can [use Android Studio to do this the same as for a release keystore](https://developer.android.com/studio/publish/app-signing#generate-key)
  2. Copy your keystore to the app `app/` directory (e.g. `app/issuing-android-push-provisioning-keystore.jks`)
  - In `gradle.properties` set `SIGNING_KEYSTORE` to the filename of the keystore (e.g. `issuing-android-push-provisioning-keystore.jks`)
  3. Also in `gradle.properties` set `SIGNING_KEY_ALIAS` and `SIGNING_PASSWORD` to the same values from the above keystore creation step.
  4. Securely share this keystore and key info with anyone on your team who needs to create debug builds of the app.
- Changes to the signing configuration may require a gradle sync and uninstall + reinstall of the app.
- [Remember](https://stripe.com/docs/issuing/cards/digital-wallets?platform=Android#testapp): All testing must be done in live mode, with live Issuing cards, and on physical devices (not emulators).


## Relevant documentation
- [Use digital wallets with Issuing](https://stripe.com/docs/issuing/cards/digital-wallets?platform=Android)
- [Android Push Provisioning API](https://developers.google.com/pay/issuers/apis/push-provisioning/android)
- [Test Cases](https://developers.google.com/pay/issuers/apis/push-provisioning/android/test-cases)
