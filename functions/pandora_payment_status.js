// Pandora Payment Status Proxy Cloud Function
const functions = require('firebase-functions');
const cors = require('cors');
const fetch = require('node-fetch');

const corsHandler = cors({ origin: true });

// Store your Pandora API key securely (do NOT expose in frontend)
const PANDORA_API_KEY =
  'pk_live_35aa5d8d019945f6d918ed216b3d223820295f803d7d0ce76425c36e37f1ea8b';

function normalizeStatusPayload(payload, transactionRef, requestSucceeded) {
  if (
    payload &&
    typeof payload === 'object' &&
    Object.prototype.hasOwnProperty.call(payload, 'success') &&
    Array.isArray(payload.data)
  ) {
    return payload;
  }

  const firstDataItem = Array.isArray(payload?.data) ? payload.data[0] : null;
  const source =
    firstDataItem && typeof firstDataItem === 'object' ? firstDataItem : payload;

  const status = (
    source?.status ??
    source?.transaction_status ??
    source?.payment_status ??
    'processing'
  )
    .toString()
    .toLowerCase();

  return {
    success: Boolean(requestSucceeded),
    messages: payload?.messages ??
      [
        payload?.message ??
          (requestSucceeded
            ? 'Payment status fetched successfully.'
            : 'Failed to fetch payment status.'),
      ],
    data: [
      {
        status,
        amount: source?.amount ?? source?.transaction_amount ?? 0,
        transaction_charge: source?.transaction_charge ?? source?.charge ?? 0,
        completed_on:
          source?.completed_on ??
          source?.completed_at ??
          source?.updated_at ??
          source?.created_at ??
          null,
        transaction_reference:
          source?.transaction_reference ??
          source?.transaction_ref ??
          transactionRef,
      },
    ],
  };
}

exports.pandoraPaymentStatus = functions.https.onRequest((req, res) => {
  corsHandler(req, res, async () => {
    // Only allow POST requests from app clients.
    if (req.method !== 'POST') {
      return res.status(405).send({ error: 'Method not allowed' });
    }

    const { transaction_ref } = req.body || {};
    if (!transaction_ref) {
      return res.status(400).send({ error: 'Missing transaction_ref' });
    }

    try {
      // Based on integration notes: status endpoint is GET /transactions/{ref}
      const statusUrl = `https://api.pandorapayments.com/v1/transactions/${encodeURIComponent(transaction_ref)}`;
      const response = await fetch(statusUrl, {
        method: 'GET',
        headers: {
          'X-API-Key': PANDORA_API_KEY,
          Accept: 'application/json',
        },
      });

      const rawBody = await response.text();
      let parsedBody;

      try {
        parsedBody = JSON.parse(rawBody);
      } catch (parseError) {
        const preview =
          rawBody.length > 300 ? `${rawBody.substring(0, 300)}...` : rawBody;
        console.error('Pandora status returned non-JSON response', {
          status: response.status,
          preview,
        });

        return res.status(response.status).send({
          success: false,
          messages: [
            `Pandora status endpoint returned non-JSON response (HTTP ${response.status}).`,
          ],
        });
      }

      const normalized = normalizeStatusPayload(
        parsedBody,
        transaction_ref,
        response.ok
      );
      return res.status(response.status).send(normalized);
    } catch (error) {
      console.error('Pandora Payment Status Error:', error);
      return res.status(500).send({
        success: false,
        messages: ['Internal server error while checking payment status.'],
      });
    }
  });
});
