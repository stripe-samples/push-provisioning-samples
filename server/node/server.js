const express = require('express');
const app = express();
// Replace if using a different env file or config
const env = require('dotenv').config({ path: './.env' });

const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY, {
  apiVersion: '2020-08-27',
  appInfo: { // For sample support and debugging, not required for production:
    name: "stripe-samples/push-provisioning",
    version: "0.0.1",
    url: "https://github.com/stripe-samples/push-provisioning"
  }
});

app.get('/', (req, res) => {
  res.status(200).send('Great, your backend is set up. Now you can configure the Stripe example apps to point here.');
});

// Given an authenticated user, look up their corresponding cardholder ID to get a list of the user's cards.
// See https://stripe.com/docs/api/issuing/cards/list
app.get('/cards', async (req, res) => {
  if (authenticate(req)) {
    try {
      const cardsResponse = await stripe.issuing.cards.list({
        cardholder: authenticatedCardholderId(req),
        limit: 10
      });
      const sanitizedCards = cardsResponse.data.map(card => {
        return {
          id: card.id,
          last4: card.last4,
          brand: card.brand,
          cardholder_name: card.cardholder.name,
          eligible_for_google_pay: card.status === 'active' && card.wallets.google_pay.eligible,
          eligible_for_apple_pay: card.status === 'active' && card.wallets.apple_pay.eligible,
          primary_account_identifier: card.wallets.primary_account_identifier
        };
      });
      res.status(200).json({ data: sanitizedCards });
    } catch (error) {
      res.status(404).send(`Error listing cards: ${error.message}`);
    }
  } else {
    res.status(401).send('Not authorized');
  }
});

// Create an ephemeral key for the given card ID.
// See https://stripe.com/docs/issuing/cards/digital-wallets?platform=iOS#update-your-backend
// See https://stripe.com/docs/issuing/cards/digital-wallets?platform=Android#update-your-backend
app.post('/ephemeral_keys', async (req, res) => {
  if (authenticate(req)) {
    try {
      const key = await stripe.ephemeralKeys.create(
        { issuing_card: req.body.card_id },
        { stripe_version: req.body.api_version }
      );
      res.status(200).json(key);
    } catch (error) {
      res.status(402).send(`Error creating ephemeral key: ${error.message}`);
    }
  } else {
    res.status(401).send('Not authorized');
  }
});

function authenticate(req) {
  return req.session.authenticated && req.session.cardholderId;
}

function authenticatedCardholderId(req) {
  const cardholderDB = {
    [`${env.USERNAME}-${env.PASSWORD}`]: env.CARDHOLDER_ID
  };
  return cardholderDB[req.headers.authorization.split(' ')[1]];
}

// Listens to all network interfaces. This allows any device on your
// network to connect.
app.listen(port, '0.0.0.0', () => {
  console.log(`Server running on port ${port}`);
});
