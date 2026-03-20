// Pandora Payment Status Proxy Cloud Function
// This function proxies status check requests to the Pandora Payments API
const functions = require('firebase-functions');
const cors = require('cors');
const fetch = require('node-fetch');

const corsHandler = cors({ origin: true });

// Store your Pandora API key securely (do NOT expose in frontend)
const PANDORA_API_KEY = 'pk_live_35aa5d8d019945f6d918ed216b3d223820295f803d7d0ce76425c36e37f1ea8b';

exports.pandoraPaymentStatus = functions.https.onRequest((req, res) => {
  corsHandler(req, res, async () => {
    // Only allow POST requests
    if (req.method !== 'POST') {
      return res.status(405).send({ error: 'Method not allowed' });
    }

    const { transaction_ref } = req.body;
    if (!transaction_ref) {
      return res.status(400).send({ error: 'Missing transaction_ref' });
    }

    try {
      // Pandora Payments API endpoint for status check (replace with actual endpoint if different)
      const response = await fetch('https://api.pandorapayments.com/v1/transactions/status', {
        method: 'POST',
        headers: {
          'X-API-Key': PANDORA_API_KEY,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ transaction_ref })
      });

      const data = await response.json();
      res.status(response.status).send(data);
    } catch (error) {
      console.error('Pandora Payment Status Error:', error);
      res.status(500).send({ error: 'Internal server error' });
    }
  });
});
