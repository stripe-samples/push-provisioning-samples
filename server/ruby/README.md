Example App Backend
====

This is a [Sinatra](http://www.sinatrarb.com/) webapp that you can use to test Stripe's example push provisioning apps.

This is intended for example purposes--it is not a production-ready implementation.

To deploy this for free on Glitch, visit https://glitch.com/edit/#!/stripe-push-provisioning-example-backend and click "Remix".

In your `.env` file in Glitch, set `STRIPE_SECRET_KEY` to your secret key. Find this at https://dashboard.stripe.com/apikeys (it'll look like `sk_live_****`). Then set `CARDHOLDER_ID`, which you can find at https://dashboard.stripe.com/issuing/cardholders (it'll look like `ich_...`).

Then, set `SAMPLE_PP_BACKEND_URL` in the example iOS/Android app to your Glitch Remix URL (it'll be in the format https://my-example-app.glitch.me).

Happy testing!

How to run locally
----

Follow the steps below to run locally.

0. Prerequisites

You will need a Stripe account in order to run the sample backend. Once you set up your account
and completed the [steps to get Issuing access](https://stripe.com/docs/issuing/cards/digital-wallets#request-access),
go to the Stripe developer dashboard to find your [API keys](https://dashboard.stripe.com/apikeys) and [cardholder ID](https://dashboard.stripe.com/issuing/cardholders).

To configure the app, copy the `.env.example` file into a file named `.env`:

```
cp .env.example .env
```
Fill in `.env` with your configuration:

```
# See https://dashboard.stripe.com/apikeys
STRIPE_SECRET_KEY=sk_live_...
# See https://dashboard.stripe.com/issuing/cardholders
CARDHOLDER_ID=ich_...
# These should match your client app config
USERNAME=...
PASSWORD=...
```

1. Install dependencies
```
RUBY_CFLAGS=-DUSE_FFI_CLOSURE_ALLOC # flag to build ruby 2.5.8 on M1 Macs \
  rbenv install 2.5.8
rbenv local 2.5.8
gem install bundler -v 2.3.26
bundle install
```

2. Run the application
```
bundle exec ruby server.rb
```

Basic smoke test
---
```
curl -u cardholder:password --basic http://localhost:4242/cards
```