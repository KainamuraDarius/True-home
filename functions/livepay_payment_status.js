// LivePay Payment Status Proxy Cloud Function
const functions = require('firebase-functions');
const cors = require('cors');
const fetch = require('node-fetch');

const corsHandler = cors({ origin: true });

// Store your LivePay API key securely (do NOT expose in frontend)
const LIVEPAY_API_KEY =
  '7170587e00599bb9.17a2e62d7854d6582ee4fb156bd1ab66ca7c1f2d9e1f5298c2875158f328f32f';

// Your LivePay account number (find in your LivePay dashboard)
const LIVEPAY_ACCOUNT_NUMBER = process.env.LIVEPAY_ACCOUNT_NUMBER || '';

function normalizeStatusPayload(payload, transactionRef, requestSucceeded) {
  // If it already matches the format Flutter expects, return as-is
  if (
    payload &&
    typeof payload === 'object' &&
    Object.prototype.hasOwnProperty.call(payload, 'success') &&
    Array.isArray(payload.data)
  ) {
    return payload;
  }

  // LivePay returns a flat object for transaction-status, map it to the
  // { success, data: [{ status, amount, ... }] } shape the Flutter app expects.
  const status = (
    payload?.status ??
    payload?.transaction_status ??
    payload?.payment_status ??
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
        amount: payload?.amount ?? 0,
        transaction_charge: payload?.charge ?? payload?.transaction_charge ?? 0,
        completed_on:
          payload?.completed_at ??
          payload?.completed_on ??
          payload?.updated_at ??
          payload?.created_at ??
          null,
        transaction_reference:
          payload?.customer_reference ??
          payload?.internal_reference ??
          payload?.transaction_reference ??
          transactionRef,
      },
    ],
  };
}

exports.livePaymentStatus = functions.https.onRequest((req, res) => {
  corsHandler(req, res, async () => {
    // Only allow POST requests from app clients.
    if (req.method !== 'POST') {
      return res.status(405).send({ error: 'Method not allowed' });
    }

    const { transaction_ref, reference, account_number, currency } = req.body || {};
    const resolvedRef = reference || transaction_ref;
    const resolvedAccount = account_number || LIVEPAY_ACCOUNT_NUMBER;
    const resolvedCurrency = currency || 'UGX';

    if (!resolvedRef) {
      return res.status(400).send({ error: 'Missing transaction reference' });
    }

    try {
      // LivePay transaction-status is GET with query params
      const params = new URLSearchParams({
        reference: resolvedRef,
        currency: resolvedCurrency,
      });
      if (resolvedAccount) {
        params.set('accountNumber', resolvedAccount);
      }

      const statusUrl = `https://livepay.me/api/transaction-status?${params.toString()}`;
      console.log('[LivePaymentStatus] Checking:', statusUrl);

      const response = await fetch(statusUrl, {
        method: 'GET',
        headers: {
          'Authorization': `Bearer ${LIVEPAY_API_KEY}`,
          'Content-Type': 'application/json',
        },
      });

      const rawBody = await response.text();
      let parsedBody;

      try {
        parsedBody = JSON.parse(rawBody);
      } catch (parseError) {
        const preview =
          rawBody.length > 300 ? `${rawBody.substring(0, 300)}...` : rawBody;
        console.error('LivePay status returned non-JSON response', {
          status: response.status,
          preview,
        });

        return res.status(response.status).send({
          success: false,
          messages: ['Payment status service temporarily unavailable'],
          data: [
            {
              status: 'unknown',
              amount: 0,
              transaction_charge: 0,
              completed_on: null,
              transaction_reference: resolvedRef,
            },
          ],
        });
      }

      const success = response.ok;
      const normalized = normalizeStatusPayload(parsedBody, resolvedRef, success);
      console.log('[LivePaymentStatus] Normalized response:', JSON.stringify(normalized));

      return res.status(200).send(normalized);
    } catch (error) {
      console.error('[LivePaymentStatus] Error checking status:', error.message);
      return res.status(500).send({
        success: false,
        messages: ['Error checking payment status'],
        data: [
          {
            status: 'unknown',
            amount: 0,
            transaction_charge: 0,
            completed_on: null,
            transaction_reference: resolvedRef,
          },
        ],
      });
    }
  });
});
