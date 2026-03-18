import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  const apiKey = r'$argon2id$v=19$m=65536,t=4,p=3$TnZqZTdOWEd3enVxVHZyMw$Dvu0B/DsxqDfxoHzQKTgKLUeXZ242xJhooLf7sWUdOM';
  const apiUrl = 'https://api.pandora.co.ug/v1';
  const callbackUrl = 'https://us-central1-truehome-9a244.cloudfunctions.net/pandoraPaymentWebhook';

  print('🔍 Testing Pandora API with provided credentials...\n');
  print('API Key: ${apiKey.substring(0, 30)}...');
  print('Callback URL: $callbackUrl\n');

  // Test 1: Check API connectivity with Bearer token
  print('TEST 1: Checking API connectivity with Bearer token...');
  try {
    final response = await http.get(
      Uri.parse('$apiUrl/payment/status/test'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
    ).timeout(Duration(seconds: 5));

    print('Status Code: ${response.statusCode}');
    print('Response: ${response.body}\n');
    
    if (response.statusCode == 401) {
      print('❌ ERROR: Authorization failed (401)');
      print('   This means the API key format might be wrong for Bearer token auth\n');
    } else if (response.statusCode == 404) {
      print('✅ OK: Got 404 - API responded, authentication likely worked');
      print('   (404 is expected for test endpoint)\n');
    } else if (response.statusCode == 200) {
      print('✅ OK: Got 200 - API working!\n');
    }
  } catch (e) {
    print('❌ ERROR: $e\n');
  }

  // Test 2: Try test payment initiation
  print('TEST 2: Attempting payment initiation request...');
  try {
    final payload = {
      'amount': 1000,
      'phone': '256701234567',
      'externalId': 'test_${DateTime.now().millisecondsSinceEpoch}',
      'narration': 'Test Payment',
      'callbackUrl': callbackUrl,
    };

    final response = await http.post(
      Uri.parse('$apiUrl/payment/initiate'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    ).timeout(Duration(seconds: 5));

    print('Status Code: ${response.statusCode}');
    print('Response: ${response.body}\n');

    if (response.statusCode == 401) {
      print('❌ ERROR: Authorization failed (401)');
      print('   - API key might need formatting (e.g., add "Bearer " prefix)');
      print('   - Or this hash might be a password that needs different auth\n');
    } else if (response.statusCode == 400) {
      print('⚠️  BAD REQUEST (400)');
      print('   - Check if "phone", "amount", or other fields need formatting\n');
    } else if (response.statusCode == 200 || response.statusCode == 201) {
      print('✅ SUCCESS: Payment initiated!');
      print('   Your credentials are working correctly!\n');
    }
  } catch (e) {
    print('❌ ERROR: $e\n');
  }

  // Test 3: Check if hash needs to be used as Basic auth instead
  print('TEST 3: Trying Basic authentication (in case hash is password)...');
  try {
    final credentials = base64Encode(utf8.encode('api:$apiKey'));
    final response = await http.get(
      Uri.parse('$apiUrl/payment/status/test'),
      headers: {
        'Authorization': 'Basic $credentials',
        'Content-Type': 'application/json',
      },
    ).timeout(Duration(seconds: 5));

    print('Status Code: ${response.statusCode}');
    print('Response: ${response.body}\n');

    if (response.statusCode == 200 || response.statusCode == 404) {
      print('✅ POSSIBLE: Basic auth might work\n');
    }
  } catch (e) {
    print('❌ ERROR: $e\n');
  }

  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('NEXT STEPS:');
  print('1. Check your Pandora Dashboard for additional credentials');
  print('2. Look for fields like: API Key, Client ID, Secret Key, Merchant ID');
  print('3. Check confirmation emails from Pandora');
  print('4. Contact Pandora support with test results if needed');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
}
