const cors = require('cors');
const { randomBytes } = require('crypto');
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
    maxPollDurationMs: 300000,
  });
}

function normalizePhoneNumber(phoneNumber) {
  let cleaned = String(phoneNumber || '').trim().replace(/\D/g, '');

  if (cleaned.startsWith('256256')) {
    cleaned = `256${cleaned.substring(6)}`;
  }

  if (cleaned.startsWith('2560')) {
    cleaned = `256${cleaned.substring(4)}`;
  }

  if (cleaned.startsWith('0')) {
    cleaned = `256${cleaned.substring(1)}`;
  } else if (!cleaned.startsWith('256') && cleaned.length === 9) {
    cleaned = `256${cleaned}`;
  }

  return cleaned.startsWith('256') ? cleaned : cleaned;
}

function isValidPaymentPhoneNumber(phoneNumber) {
  return /^2567\d{8}$/.test(String(phoneNumber || '').trim());
}

function normalizeCustomerName(name) {
  const trimmed = String(name || '').trim();
  return trimmed || 'True Home Customer';
}

function normalizeMetadata(metadata) {
  if (!metadata || typeof metadata !== 'object' || Array.isArray(metadata)) {
    return undefined;
  }

  const entries = Object.entries(metadata)
    .filter(([key, value]) => key && value != null)
    .map(([key, value]) => [key, String(value)]);

  return entries.length > 0 ? Object.fromEntries(entries) : undefined;
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

function getInitialPaymentMessage(status) {
  switch (String(status || '').toLowerCase()) {
    case 'processing':
    case 'pending':
      return 'Payment request sent successfully.';
    case 'successful':
    case 'success':
    case 'completed':
    case 'paid':
      return 'Payment completed successfully.';
    case 'failed':
      return 'The payment request was not accepted by the provider.';
    case 'cancelled':
      return 'The payment request was cancelled before completion.';
    default:
      return `Payment request returned status: ${status || 'unknown'}.`;
  }
}

function normalizeReference(reference) {
  const resolved = String(reference || '').trim();
  if (resolved.length >= 13 && resolved.length <= 15) {
    return resolved;
  }

  // Nylon requires references between 13 and 15 chars.
  return randomBytes(7).toString('hex');
}

function createTimeoutPromise(timeoutMs) {
  return new Promise((resolve) => {
    setTimeout(() => resolve(null), timeoutMs);
  });
}

async function waitForEarlyPaymentOutcome(payment, timeoutMs = 12000) {
  const settledOutcome = payment.wait().then((result) => ({
    outcome: result ? 'resolved' : 'settled_without_success',
    result,
  }));

  try {
    return await Promise.race([
      settledOutcome,
      createTimeoutPromise(timeoutMs),
    ]);
  } catch (error) {
    return {
      outcome: 'unexpected_error',
      error,
    };
  }
}

function resolvePaymentStatus(payment, earlyOutcome) {
  if (earlyOutcome?.outcome === 'resolved' && earlyOutcome.result?.status) {
    return String(earlyOutcome.result.status);
  }

  if (earlyOutcome?.outcome === 'settled_without_success') {
    return String(payment.status || 'failed');
  }

  if (
    earlyOutcome?.outcome === 'unexpected_error' &&
    earlyOutcome.error?.status
  ) {
    return String(earlyOutcome.error.status);
  }

  return String(payment.status || 'processing');
}

function resolveFailureMessage(status, error) {
  const parsed = error ? parseError(error?.message || String(error)) : null;
  if (parsed?.message) {
    return parsed.message;
  }
  return getInitialPaymentMessage(status);
}

function buildTransactionPayload({
  payment,
  reference,
  status,
  amount,
  currency,
  normalizedPhone,
  failureMessage,
  earlyOutcome,
}) {
  const result = earlyOutcome?.result;
  const transaction = result?.transaction || result || null;
  const providerTransactionId =
    transaction?.providerTransactionId ||
    transaction?.provider_transaction_id ||
    transaction?.providerReference ||
    transaction?.provider_reference ||
    null;
  const transactionId =
    transaction?.id ||
    payment?.id ||
    null;

  return {
    transaction_reference: payment.reference || reference,
    status: status || payment.status || 'processing',
    amount: Math.round(amount),
    currency,
    network: 'mobileMoney',
    normalized_phone: normalizedPhone,
    initiated_at: new Date().toISOString(),
    transaction_id: transactionId,
    provider_transaction_id: providerTransactionId,
    failure_detail: failureMessage || null,
    lifecycle_outcome: earlyOutcome?.outcome || 'timeout',
  };
}

function hasMaterializedTransaction(payload) {
  return Boolean(
    payload?.transaction_id ||
    payload?.provider_transaction_id,
  );
}

exports.nylonPayment = onRequest({
  secrets: [NYLONPAY_API_KEY, NYLONPAY_API_SECRET],
  invoker: 'public',
}, (req, res) => {
  corsHandler(req, res, async () => {
    if (req.method !== 'POST') {
      return res.status(405).send({ error: 'Method not allowed' });
    }

    const {
      amount,
      currency = 'UGX',
      transaction_ref,
      reference,
      narrative,
      description,
      contact,
      phoneNumber,
      customerName,
      customerEmail,
      customer,
      metadata,
    } = req.body || {};

    const resolvedReference = normalizeReference(transaction_ref || reference);
    const resolvedPhone = normalizePhoneNumber(
      contact || phoneNumber || customer?.phoneNumber,
    );
    const resolvedAmount = Number(amount);
    const resolvedDescription = String(
      narrative || description || 'True Home payment',
    ).trim();

    if (!resolvedReference) {
      return res.status(400).send({
        success: false,
        messages: ['Missing transaction reference.'],
      });
    }

    if (!Number.isFinite(resolvedAmount) || resolvedAmount <= 0) {
      return res.status(400).send({
        success: false,
        messages: ['Amount must be a positive number.'],
      });
    }

    if (!resolvedPhone) {
      return res.status(400).send({
        success: false,
        messages: ['Customer phone number is required.'],
      });
    }

    if (!isValidPaymentPhoneNumber(resolvedPhone)) {
      return res.status(400).send({
        success: false,
        messages: ['Customer phone number must be in the format +2567XXXXXXXX with no spaces.'],
      });
    }

    console.log('[NylonPayment] phone normalization:', {
      rawPhone: contact || phoneNumber || customer?.phoneNumber || null,
      normalizedPhone: resolvedPhone,
    });

    try {
      const nylonPay = createClient();
      const payment = await nylonPay.collectPayment({
        amount: Math.round(resolvedAmount),
        currency,
        description: resolvedDescription,
        method: 'mobileMoney',
        reference: resolvedReference,
        customer: {
          name: normalizeCustomerName(customerName || customer?.name),
          phoneNumber: resolvedPhone,
          email: customerEmail || customer?.email || undefined,
        },
        metadata: normalizeMetadata(metadata),
      });

      payment.on('processing', ({ transaction } = {}) => {
        console.log('[NylonPayment] processing:', {
          reference: transaction?.reference || payment.reference || resolvedReference,
          status: transaction?.status || payment.status,
        });
      });
      payment.on('success', ({ transaction } = {}) => {
        console.log('[NylonPayment] success:', {
          reference: transaction?.reference || payment.reference || resolvedReference,
          status: transaction?.status || 'successful',
          transactionId: transaction?.id,
        });
      });
      payment.on('failed', ({ error, transaction } = {}) => {
        console.log('[NylonPayment] failed:', {
          reference: transaction?.reference || payment.reference || resolvedReference,
          status: transaction?.status || payment.status || 'failed',
          message: error?.message || String(error || ''),
        });
      });
      payment.on('cancelled', ({ error, transaction } = {}) => {
        console.log('[NylonPayment] cancelled:', {
          reference: transaction?.reference || payment.reference || resolvedReference,
          status: transaction?.status || payment.status || 'cancelled',
          message: error?.message || String(error || ''),
        });
      });
      payment.on('error', (error) => {
        console.log('[NylonPayment] error:', {
          reference: payment.reference || resolvedReference,
          status: payment.status || 'error',
          message: error?.message || String(error || ''),
        });
      });

      const earlyOutcome = await waitForEarlyPaymentOutcome(payment);
      const resolvedStatus = resolvePaymentStatus(payment, earlyOutcome);
      const normalizedStatus = resolvedStatus.toLowerCase();
      const isAccepted = [
        'pending',
        'processing',
        'successful',
        'success',
        'completed',
        'paid',
      ].includes(normalizedStatus);
      const transactionPayload = buildTransactionPayload({
        payment,
        reference: resolvedReference,
        status: resolvedStatus,
        amount: resolvedAmount,
        currency,
        normalizedPhone: resolvedPhone,
        earlyOutcome,
      });
      const settledWithoutSuccess =
        earlyOutcome?.outcome === 'settled_without_success';
      const shouldTreatAsFailure =
        !isAccepted ||
        (settledWithoutSuccess && !hasMaterializedTransaction(transactionPayload));

      console.log('[NylonPayment] collectPayment result:', {
        reference: payment.reference || resolvedReference,
        status: resolvedStatus,
        earlyOutcome: earlyOutcome?.outcome || 'timeout',
        transactionId: transactionPayload.transaction_id,
        providerTransactionId: transactionPayload.provider_transaction_id,
      });

      if (shouldTreatAsFailure) {
        const failureMessage = resolveFailureMessage(
          resolvedStatus,
          earlyOutcome?.error,
        );
        transactionPayload.failure_detail = failureMessage;
        return res.status(200).send({
          success: false,
          messages: [failureMessage],
          data: [transactionPayload],
        });
      }

      return res.status(200).send({
        success: true,
        messages: [getInitialPaymentMessage(resolvedStatus)],
        data: [transactionPayload],
      });
    } catch (error) {
      console.error('[NylonPayment] Error:', error);
      const payload = errorResponse(error);
      const statusCode =
        payload.error?.category === 'validation' ? 400 :
        payload.error?.category === 'auth' ? 401 :
        payload.error?.category === 'rate_limit' ? 429 :
        payload.error?.category === 'timeout' ? 504 :
        500;
      return res.status(statusCode).send(payload);
    }
  });
});
