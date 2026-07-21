// LivePay Mobile Money Payment Proxy Cloud Function
// Proxies payment initiation requests to LivePay Payments API
const functions = require('firebase-functions');
const cors = require('cors');
const fetch = require('node-fetch');

const corsHandler = cors({ origin: true });

// Store your LivePay API key securely (do NOT expose in frontend)
const LIVEPAY_API_KEY = '7170587e00599bb9.17a2e62d7854d6582ee4fb156bd1ab66ca7c1f2d9e1f5298c2875158f328f32f';

// Your LivePay account number (find in your LivePay dashboard)
const LIVEPAY_ACCOUNT_NUMBER = process.env.LIVEPAY_ACCOUNT_NUMBER || '';

exports.livePayment = functions.https.onRequest((req, res) => {
  corsHandler(req, res, async () => {
    // Only allow POST requests
    if (req.method !== 'POST') {
      return res.status(405).send({ error: 'Method not allowed' });
    }

    // Log incoming request
    console.log('[LivePayment] Incoming:', JSON.stringify(req.body));

    try {
      // Map incoming fields from the Flutter app to the LivePay API format
      const {
        amount,
        contact,           // phone number from Flutter app
        phoneNumber,       // alternative field name
        transaction_ref,   // reference from Flutter app
        reference,         // alternative field name
        narrative,         // description from Flutter app
        description,       // alternative field name
        account_number,    // LivePay account number (optional override)
        currency,          // currency (default UGX)
      } = req.body;

      const resolvedPhone = phoneNumber || contact;
      const resolvedRef = reference || transaction_ref;
      const resolvedDesc = description || narrative || 'Payment';
      const resolvedAccount = account_number || LIVEPAY_ACCOUNT_NUMBER;
      const resolvedCurrency = currency || 'UGX';

      // Validate required fields
      if (!resolvedPhone || !amount || !resolvedRef) {
        return res.status(400).send({
          success: false,
          error: 'Missing required fields',
          messages: ['Phone number, amount, and reference are required.']
        });
      }

      // Build request body matching LivePay API docs
      const apiBody = {
        phoneNumber: resolvedPhone,
        amount: parseInt(amount, 10),
        currency: resolvedCurrency,
        reference: resolvedRef,
        description: resolvedDesc,
      };

      // Only include accountNumber if we have one
      if (resolvedAccount) {
        apiBody.accountNumber = resolvedAccount;
      }

      console.log('[LivePayment] Sending to LivePay:', JSON.stringify(apiBody));

      const response = await fetch('https://livepay.me/api/collect-money', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${LIVEPAY_API_KEY}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(apiBody)
      });

      const data = await response.json();
      // Log outgoing response
      console.log('[LivePayment] Response status:', response.status);
      console.log('[LivePayment] Response body:', JSON.stringify(data));

      // If LivePay returns success, map it to the format Flutter expects
      if (response.status === 200 && data.success) {
        return res.status(200).send({
          success: true,
          data: [{
            transaction_reference: data.internal_reference || data.reference || resolvedRef,
            status: 'processing',
            network: data.network || 'MTN/Airtel',
            initiated_at: new Date().toISOString(),
          }],
          message: data.message || 'Collection request sent successfully',
        });
      }

      // Forward error from LivePay
      res.status(response.status).send({
        success: false,
        error: data.error || 'Payment initialization failed',
        messages: [data.error || data.message || 'Payment initialization failed'],
      });
    } catch (error) {
      console.error('[LivePayment] Error:', error);
      res.status(500).send({
        success: false,
        error: 'Internal server error',
        messages: [error.message || 'Internal server error'],
      });
    }
  });
});
