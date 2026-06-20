const cors = require('cors');
const { onRequest } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const { createNylonPay, parseError } = require('@nile-squad/nylonpay-ts');

const corsHandler = cors({ origin: true });

const NYLONPAY_API_KEY = defineSecret('NYLONPAY_API_KEY');
const NYLONPAY_API_SECRET = defineSecret('NYLONPAY_API_SECRET');

function getNylonPayCredentials() {
  const apiKey = NYLONPAY_API_KEY.value() || '';
  const apiSecret = NYLONPAY_API_SECRET.value() || '';

  if (!apiKey || !apiSecret) {
    throw new Error(
      'Nylon Pay credentials are missing. Set Firebase secrets `NYLONPAY_API_KEY` and `NYLONPAY_API_SECRET` and bind them to this function.',
    );
  }

  return { apiKey, apiSecret };
}

function createClient() {
  const { apiKey, apiSecret } = getNylonPayCredentials();
  return createNylonPay({
    apiKey,
    apiSecret,
    timeoutMs: 30000,
    maxRetries: 3,
  });
}

function getStatusMessage(status) {
  switch (String(status || '').toLowerCase()) {
    case 'successful':
    case 'completed':
    case 'success':
    case 'paid':
      return 'Payment completed successfully!';
    case 'processing':
    case 'pending':
      return 'Payment is being processed. Please wait...';
    case 'failed':
      return 'Payment failed. Please try again.';
    case 'cancelled':
      return 'Payment was cancelled.';
    default:
      return `Payment status: ${status}`;
  }
}

function errorResponse(error) {
  const parsed = parseError(typeof error === 'string' ? error : error?.message || 'Unknown payment error');
  return {
    success: false,
    messages: [parsed.message],
    error: {
      category: parsed.category,
      retryable: parsed.retryable ?? false,
    },
  };
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function getStatusWithRetry(nylonPay, transactionRef) {
  const maxAttempts = 4;

  for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
    const result = await nylonPay.getStatus({ reference: transactionRef });
    if (result.isOk) {
      return result;
    }

    const payload = errorResponse(result.error);
    const isNotFound = payload.error?.category === 'not_found';
    if (!isNotFound || attempt === maxAttempts) {
      return result;
    }

    console.log('[NylonPaymentStatus] status not found yet, retrying', {
      reference: transactionRef,
      attempt,
    });
    await sleep(3500);
  }

  return nylonPay.getStatus({ reference: transactionRef });
}

exports.nylonPaymentStatus = onRequest({
  secrets: [NYLONPAY_API_KEY, NYLONPAY_API_SECRET],
  invoker: 'public',
}, (req, res) => {
  corsHandler(req, res, async () => {
    if (req.method !== 'POST') {
      return res.status(405).send({ error: 'Method not allowed' });
    }

    const transactionRef = String(
      req.body?.transaction_ref || req.body?.reference || '',
    ).trim();

    if (!transactionRef) {
      return res.status(400).send({
        success: false,
        messages: ['Missing transaction reference.'],
      });
    }

    try {
      const nylonPay = createClient();
      const result = await getStatusWithRetry(nylonPay, transactionRef);

      if (!result.isOk) {
        const payload = errorResponse(result.error);
        const statusCode =
          payload.error?.category === 'validation' ? 400 :
          payload.error?.category === 'auth' ? 401 :
          payload.error?.category === 'not_found' ? 404 :
          payload.error?.category === 'rate_limit' ? 429 :
          payload.error?.category === 'timeout' ? 504 :
          500;
        return res.status(statusCode).send(payload);
      }

      const status = result.value.status;
      return res.status(200).send({
        success: status === 'successful',
        messages: [getStatusMessage(status)],
        data: [
          {
            status,
            amount: result.value.amount,
            currency: result.value.currency,
            completed_on: result.value.updatedAt,
            updated_at: result.value.updatedAt,
            transaction_reference: result.value.reference,
          },
        ],
      });
    } catch (error) {
      console.error('[NylonPaymentStatus] Error:', error);
      const payload = errorResponse(error);
      const statusCode =
        payload.error?.category === 'validation' ? 400 :
        payload.error?.category === 'auth' ? 401 :
        payload.error?.category === 'not_found' ? 404 :
        payload.error?.category === 'rate_limit' ? 429 :
        payload.error?.category === 'timeout' ? 504 :
        500;
      return res.status(statusCode).send(payload);
    }
  });
});
