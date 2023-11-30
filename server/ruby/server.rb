require 'sinatra'
require 'sinatra/reloader'
require 'stripe'
require 'dotenv'
require 'json'
require 'encrypted_cookie'

# Replace if using a different env file or config
# Copy the .env.example in the root into a .env file in this folder.
Dotenv.load

# For sample support and debugging, not required for production:
Stripe.set_app_info(
  'stripe-samples/push-provisioning',
  version: '0.0.1',
  url: 'https://github.com/stripe-samples/push-provisioning'
)
Stripe.api_key = ENV['STRIPE_SECRET_KEY']

set :port, 4242

# Listens to all network interfaces. This allows any device on your network to connect.
set :bind, '0.0.0.0'

$stdout.sync = true # Get puts to show up in heroku logs

use Rack::Session::EncryptedCookie,
    secret: 'replace_me_with_a_real_secret_key' # Actually use something secret here!

get '/' do
  status 200
  return log_info('Great, your backend is set up. Now you can configure the Stripe example apps to point here.')
end

# Given an authenticated user, look up their corresponding cardholder ID to get a list of the user's cards.
# See https://stripe.com/docs/api/issuing/cards/list
get '/cards' do
  authenticate!
  begin
    cards_response = Stripe::Issuing::Card.list(
      {
        cardholder: authenticated_cardholder_id,
        limit: 10
      }
    )
    sanitized_cards = cards_response.data.map do |card|
      {
        id: card.id,
        last4: card.last4,
        brand: card.brand,
        cardholder_name: card.cardholder.name,
        eligible_for_google_pay: card.status == 'active' && card.wallets.google_pay.eligible,
        eligible_for_apple_pay: card.status == 'active' && card.wallets.apple_pay.eligible,
        primary_account_identifier: card.wallets.primary_account_identifier   # nullable
      }
    end
  rescue KeyError, Stripe::StripeError => e
    status 404
    return log_info("Error listing cards: #{e.message}")
  end

  content_type :json
  status 200
  # TODO: Warn users against caching PAI, cache can be stale for the initial value prior to the first provision.
  {data: sanitized_cards}.to_json
end

# Create an ephemeral key for the given card ID.
# See https://stripe.com/docs/issuing/cards/digital-wallets?platform=iOS#update-your-backend
# See https://stripe.com/docs/issuing/cards/digital-wallets?platform=Android#update-your-backend
post '/ephemeral_keys' do
  authenticate!
  begin
    # TODO: Ideally the ephemeral key supports only certain operations (e.g. a key meant for push provisioning can't
    #   be used to change the pin).
    key = Stripe::EphemeralKey.create(
      { issuing_card: params['card_id'] },
      { stripe_version: params['api_version'] }
    )
  rescue Stripe::StripeError => e
    status 402
    return log_info("Error creating ephemeral key: #{e.message}")
  end

  content_type :json
  status 200
  key.to_json
end

helpers do
  def authenticate!
    return if authenticated?

    headers['WWW-Authenticate'] = 'Basic realm="Restricted Area"'
    halt 401, "Not authorized\n"
  end

  def authenticated?
    @auth ||= Rack::Auth::Basic::Request.new(request.env)
    @auth.provided? and @auth.basic? and @auth.credentials and !authenticated_cardholder_id.nil?
    # TODO: show 2FA check (potentially for a subset of endpoints), more relevant for apple
  end

  # A more realistic version of this may involve using the authenticated user to look up a corresponding cardholder ID.
  # See https://stripe.com/docs/issuing/cards#create-cardholder
  def authenticated_cardholder_id
    cardholder_db = {
      [ENV["USERNAME"], ENV['PASSWORD']] => ENV['CARDHOLDER_ID']
    }
    cardholder_db[@auth.credentials]
  end

  def log_info(message)
    puts "\n#{message}\n\n"
    message
  end
end
