import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;

void main() async {
  const apiKey = r'$argon2id$v=19$m=65536,t=4,p=3$TnZqZTdOWEd3enVxVHZyMw$Dvu0B/DsxqDfxoHzQKTgKLUeXZ242xJhooLf7sWUdOM';
  const apiUrl = 'https://api.pandorapayments.com/v1';
  const callbackUrl = 'https://us-central1-truehome-9a244.cloudfunctions.net/pandoraPaymentWebhook';

  print('═══════════════════════════════════════════════════════════');
  print('🔍 DETAILED DIAGNOSIS - X-API-Key METHOD');
  print('═══════════════════════════════════════════════════════════\n');

  print('API Key Details:');
  print('  Length: ${apiKey.length} characters');
  print('  Starts with: ${apiKey.substring(0, 20)}...');
  print('  Ends with: ...${apiKey.substring(apiKey.length - 20)}');
  print('  Contains \$: ${apiKey.contains('\$')}');
  print('  Type: argon2id hash\n');

  final requestBody = {
    'amount': 1000,
    'transaction_ref': 'DIAG_${DateTime.now().millisecondsSinceEpoch}',
    'contact': '256701234567',
    'narrative': 'Diagnostic test',
    'callback_url': callbackUrl,
  };

  print('Making X-API-Key request with 30 second timeout...\n');
  
  try {
    final stopwatch = Stopwatch()..start();
    
    final response = await http.post(
      Uri.parse('$apiUrl/transactions/mobile-money'),
      headers: {
        'Content-Type': 'application/json',
        'X-API-Key': apiKey,
      },
      body: jsonEncode(requestBody),
    ).timeout(const Duration(seconds: 30), onTimeout: () {
      stopwatch.stop();
      print('⏱️  REQUEST TIMED OUT after ${stopwatch.elapsedMilliseconds}ms');
      print('\nThis means:');
      print('  • Server accepted the X-API-Key header');
      print('  • But took too long to respond (possible issue on Pandora side)');
      print('  • Try increasing timeout or check if Pandora API is stable\n');
      throw TimeoutException('Request timed out after ${stopwatch.elapsedMilliseconds}ms');
    });

    stopwatch.stop();

    print('✅ Got response after ${stopwatch.elapsedMilliseconds}ms\n');
    print('Status: ${response.statusCode}');
    print('Headers: ${response.headers}');
    print('\nResponse Body:');
    try {
      final json = jsonDecode(response.body);
      print(jsonEncode(json).replaceAll(',', ',\n'));
    } catch (e) {
      print(response.body);
    }

    if (response.statusCode == 200) {
      print('\n✅ SUCCESS! API key works!');
    } else if (response.statusCode == 401) {
      print('\n❌ Authentication failed - wrong API key or format');
    } else {
      print('\n⚠️  Unexpected response code');
    }
  } catch (e) {
    print('Error: $e\n');
    print('Trying with URL-encoded header instead...\n');
    
    // Try with manual encoding
    try {
      final response = await http.post(
        Uri.parse('$apiUrl/transactions/mobile-money'),
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': apiKey,
        },
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 15));

      print('Status: ${response.statusCode}');
      print('Response: ${response.body}');
    } catch (e2) {
      print('Also failed: $e2');
    }
  }

  print('\n═══════════════════════════════════════════════════════════');
  print('If you still get timeouts, the issue might be:');
  print('  1. Pandora API server is slow/down');
  print('  2. Network connectivity to api.pandorapayments.com');
  print('  3. API key validation is taking too long\n');
  print('Try checking: https://api.pandorapayments.com/status');
  print('═══════════════════════════════════════════════════════════\n');
}
