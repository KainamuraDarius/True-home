// API Keys configuration
// This file contains sensitive API keys and should NOT be committed to git
// Add this file to .gitignore

class ApiKeys {
  // ImgBB API Key - Get yours from https://api.imgbb.com/
  static const String imgbbApiKey = '9596a17703bd962709d2dcfa63b3b0fa';

  // PandoraPayments API Key
  // Get your key from your PandoraPayments dashboard and replace the placeholder below.
  // NEVER share this key publicly or commit it to version control.
  static const String pandoraPaymentsApiKey =
      r'$argon2id$v=19$m=65536,t=4,p=3$TnZqZTdOWEd3enVxVHZyMw$Dvu0B/DsxqDfxoHzQKTgKLUeXZ242xJhooLf7sWUdOM';

  // Webhook URL: Firebase Cloud Function that receives payment status updates.
  // After deploying the Cloud Function (functions/index.js), update this to your
  // real function URL, e.g. https://us-central1-truehome-9a244.cloudfunctions.net/pandoraPaymentWebhook
  static const String pandoraCallbackUrl =
      'https://us-central1-truehome-9a244.cloudfunctions.net/pandoraPaymentWebhook';
}
