import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  const apiKey = r'$argon2id$v=19$m=65536,t=4,p=3$TnZqZTdOWEd3enVxVHZyMw$Dvu0B/DsxqDfxoHzQKTgKLUeXZ242xJhooLf7sWUdOM';
  const apiUrl = 'https://api.pandorapayments.com/v1';
  const callbackUrl = 'https://us-central1-truehome-9a244.cloudfunctions.net/pandoraPaymentWebhook';

  print('═══════════════════════════════════════════════════════════');
  print('🔍 PANDORA PAYMENTS API TEST');
  print('═══════════════════════════════════════════════════════════\n');

  try {
    print('📝 Payment Parameters:');
    print('  API URL: $apiUrl');
    print('  API Key (first 50 chars): ${apiKey.substring(0, 50)}...');
    print('  Callback URL: $callbackUrl\n');

    // Prepare request
    final requestBody = {
      'amount': 1000,
      'transaction_ref': 'TEST_${DateTime.now().millisecondsSinceEpoch}',
      'contact': '256701234567',
      'narrative': 'Test payment from TrueHome app',
      'callback_url': callbackUrl,
    };

    print('📤 Sending POST request to: $apiUrl/transactions/mobile-money\n');
    print('📋 Request Body:');
    print(jsonEncode(requestBody)
        .split(',')
        .join(',\n  ')
        .replaceFirst('{', '{\n  ')
        .replaceAll('}', '\n}\n'));

    print('🔐 Headers:');
    print('  Content-Type: application/json');
    print('  X-API-Key: $apiKey\n');

    // Make request
    final response = await http.post(
      Uri.parse('$apiUrl/transactions/mobile-money'),
      headers: {
        'Content-Type': 'application/json',
        'X-API-Key': apiKey,
      },
      body: jsonEncode(requestBody),
    ).timeout(const Duration(seconds: 30));

    print('═══════════════════════════════════════════════════════════');
    print('📥 RESPONSE\n');
    print('Status Code: ${response.statusCode}\n');

    print('Response Body:');
    try {
      final jsonResponse = jsonDecode(response.body);
      print(jsonEncode(jsonResponse).split(',').join(',\n').replaceFirst('{', '{\n').replaceAll('}', '\n}'));
    } catch (e) {
      print(response.body);
    }

    print('\n═══════════════════════════════════════════════════════════');

    if (response.statusCode == 200) {
      print('✅ SUCCESS! Payment initiation worked!\n');
      print('Next steps:');
      print('  1. Check your phone for payment prompt');
      print('  2. Complete payment using your mobile money app');
      print('  3. Check app to see if reservation is confirmed\n');
    } else if (response.statusCode == 401) {
      print('❌ AUTHENTICATION FAILED (401)\n');
      print('Possible issues:');
      print('  1. API key is incorrect or invalid');
      print('  2. API key format is wrong (check if it needs "Bearer" prefix)');
      print('  3. API key has expired\n');
      print('Action: Check your Pandora dashboard for correct credentials\n');
    } else if (response.statusCode == 400) {
      print('❌ BAD REQUEST (400)\n');
      print('Possible issues:');
      print('  1. Phone number format is wrong');
      print('  2. Missing or invalid parameters');
      print('  3. Amount format is wrong\n');
      print('Action: Check error message above for details\n');
    } else if (response.statusCode == 429) {
      print('⚠️  RATE LIMIT EXCEEDED (429)\n');
      print('You\'ve made too many requests. Wait a minute before trying again.\n');
    } else if (response.statusCode == 500) {
      print('❌ SERVER ERROR (500)\n');
      print('Pandora server is having issues. Try again later.\n');
    } else {
      print('⚠️  UNEXPECTED RESPONSE (${response.statusCode})\n');
      print('Check error details above.\n');
    }

    print('═══════════════════════════════════════════════════════════\n');
  } catch (e) {
    print('❌ ERROR: $e\n');
    print('═══════════════════════════════════════════════════════════\n');
  }
}
