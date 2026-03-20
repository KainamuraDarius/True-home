// Pandora Mobile Money Payment Proxy Cloud Function
// Proxies payment initiation requests to Pandora Payments API
const functions = require('firebase-functions');
const cors = require('cors');
const fetch = require('node-fetch');

const corsHandler = cors({ origin: true });

// Store your Pandora API key securely (do NOT expose in frontend)
const PANDORA_API_KEY = 'pk_live_35aa5d8d019945f6d918ed216b3d223820295f803d7d0ce76425c36e37f1ea8b';

exports.pandoraPayment = functions.https.onRequest((req, res) => {
  corsHandler(req, res, async () => {
    // Only allow POST requests
    if (req.method !== 'POST') {
      return res.status(405).send({ error: 'Method not allowed' });
    }

    // Log incoming request
    console.log('[PandoraPayment] Incoming:', JSON.stringify(req.body));

    try {
      const response = await fetch('https://api.pandorapayments.com/v1/transactions/mobile-money', {
        method: 'POST',
        headers: {
          'X-API-Key': PANDORA_API_KEY,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(req.body)
      });

      const data = await response.json();
      // Log outgoing response
      console.log('[PandoraPayment] Response:', JSON.stringify(data));
      res.status(response.status).send(data);
    } catch (error) {
      console.error('[PandoraPayment] Error:', error);
      res.status(500).send({ error: 'Internal server error' });
    }
  });
});
