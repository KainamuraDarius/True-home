import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  const apiKey = r'$argon2id$v=19$m=65536,t=4,p=3$TnZqZTdOWEd3enVxVHZyMw$Dvu0B/DsxqDfxoHzQKTgKLUeXZ242xJhooLf7sWUdOM';
  const apiUrl = 'https://api.pandorapayments.com/v1';
  const callbackUrl = 'https://us-central1-truehome-9a244.cloudfunctions.net/pandoraPaymentWebhook';

  print('═══════════════════════════════════════════════════════════');
  print('🔍 TESTING DIFFERENT AUTHENTICATION METHODS');
  print('═══════════════════════════════════════════════════════════\n');

  final requestBody = {
    'amount': 1000,
    'transaction_ref': 'TEST_${DateTime.now().millisecondsSinceEpoch}',
    'contact': '256701234567',
    'narrative': 'Test payment from TrueHome app',
    'callback_url': callbackUrl,
  };

  // Method 1: X-API-Key header (original)
  print('METHOD 1: X-API-Key header');
  print('─────────────────────────────────────────────────────────\n');
  try {
    final response = await http.post(
      Uri.parse('$apiUrl/transactions/mobile-money'),
      headers: {
        'Content-Type': 'application/json',
        'X-API-Key': apiKey,
      },
      body: jsonEncode(requestBody),
    ).timeout(const Duration(seconds: 10));

    print('Status: ${response.statusCode}');
    print('Response: ${response.body}\n');
  } catch (e) {
    print('Error: $e\n');
  }

  // Method 2: Bearer token
  print('METHOD 2: Bearer token (Authorization header)');
  print('─────────────────────────────────────────────────────────\n');
  try {
    final response = await http.post(
      Uri.parse('$apiUrl/transactions/mobile-money'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode(requestBody),
    ).timeout(const Duration(seconds: 10));

    print('Status: ${response.statusCode}');
    print('Response: ${response.body}\n');
  } catch (e) {
    print('Error: $e\n');
  }

  // Method 3: Base64 encoded in X-API-Key
  print('METHOD 3: Base64 encoded API key in X-API-Key');
  print('─────────────────────────────────────────────────────────\n');
  try {
    final encoded = base64Encode(utf8.encode(apiKey));
    final response = await http.post(
      Uri.parse('$apiUrl/transactions/mobile-money'),
      headers: {
        'Content-Type': 'application/json',
        'X-API-Key': encoded,
      },
      body: jsonEncode(requestBody),
    ).timeout(const Duration(seconds: 10));

    print('Status: ${response.statusCode}');
    print('Response: ${response.body}\n');
  } catch (e) {
    print('Error: $e\n');
  }

  // Method 4: API key in body
  print('METHOD 4: API key as parameter in request body');
  print('─────────────────────────────────────────────────────────\n');
  try {
    final bodyWithKey = {
      ...requestBody,
      'api_key': apiKey,
    };

    final response = await http.post(
      Uri.parse('$apiUrl/transactions/mobile-money'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode(bodyWithKey),
    ).timeout(const Duration(seconds: 10));

    print('Status: ${response.statusCode}');
    print('Response: ${response.body}\n');
  } catch (e) {
    print('Error: $e\n');
  }

  // Method 5: Query parameter
  print('METHOD 5: API key as query parameter');
  print('─────────────────────────────────────────────────────────\n');
  try {
    final response = await http.post(
      Uri.parse('$apiUrl/transactions/mobile-money?api_key=$apiKey'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode(requestBody),
    ).timeout(const Duration(seconds: 10));

    print('Status: ${response.statusCode}');
    print('Response: ${response.body}\n');
  } catch (e) {
    print('Error: $e\n');
  }

  print('═══════════════════════════════════════════════════════════');
  print('✅ Test completed. Check which method returned status 200');
  print('═══════════════════════════════════════════════════════════\n');
}
