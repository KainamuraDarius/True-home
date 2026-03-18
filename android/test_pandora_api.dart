import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  print('🔍 Testing Pandora Payment Gateway Credentials...\n');
  
  // ============================================
  // CONFIGURE YOUR PANDORA CREDENTIALS HERE
  // ============================================
  
  // Replace these with your Pandora sub-account credentials
  const String pandoraApiKey = 'YOUR_API_KEY_HERE';
  const String pandoraClientId = 'YOUR_CLIENT_ID_HERE';
  const String pandoraMerchantId = 'YOUR_MERCHANT_ID_HERE';
  const String pandoraApiUrl = 'https://api.pandora.co.ug/v1'; // Update with your API URL
  
  // If you have a hash instead, it might be a password that needs base64 encoding
  const String pandoraHash = r'$argon2id$v=19$m=65536,t=4,p=3$TnZqZTdOWEd3enVxVHZyMw$Dvu0B/DsxqDfxoHzQKTgKLUeXZ242xJhooLf7sWUdOM';
  
  print('Pandora API URL: $pandoraApiUrl');
  print('API Key: ${pandoraApiKey.substring(0, 10)}...');
  print('Client ID: $pandoraClientId');
  print('Merchant ID: $pandoraMerchantId\n');
  
  try {
    // Test 1: Basic API connectivity
    print('Test 1: Testing API connectivity...');
    
    final headers = {
      'Authorization': 'Bearer $pandoraApiKey',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    
    print('Headers: $headers\n');
    
    // Try a simple request - initiate payment
    print('Test 2: Attempting to initiate payment...');
    
    final paymentBody = {
      'merchantId': pandoraMerchantId,
      'amount': 20000,
      'currency': 'UGX',
      'customerPhoneNumber': '256774123456',
      'externalId': 'TEST_${DateTime.now().millisecondsSinceEpoch}',
      'description': 'Test payment to verify API',
      'callbackUrl': 'https://yourdomain.com/api/payment/callback',
      'returnUrl': 'https://yourdomain.com/payment/success',
    };
    
    print('Request body: ${jsonEncode(paymentBody)}\n');
    
    final response = await http.post(
      Uri.parse('$pandoraApiUrl/payment/initiate'),
      headers: headers,
      body: jsonEncode(paymentBody),
    ).timeout(const Duration(seconds: 10));
    
    print('Status Code: ${response.statusCode}');
    print('Response: ${response.body}\n');
    
    if (response.statusCode == 200 || response.statusCode == 201) {
      print('✅ SUCCESS! Pandora API is working!');
      final data = jsonDecode(response.body);
      print('Transaction ID: ${data['transactionId']}');
      print('Reference ID: ${data['referenceId']}');
      print('\n🎉 Your Pandora credentials are VALID!');
    } else if (response.statusCode == 401 || response.statusCode == 403) {
      print('❌ AUTHENTICATION ERROR');
      print('Possible issues:');
      print('- Invalid API Key');
      print('- Invalid Client ID');
      print('- Credentials not activated yet');
      print('- Wrong API URL');
      print('\n📝 Next steps:');
      print('1. Verify your credentials in Pandora dashboard');
      print('2. Make sure credentials are fully activated');
      print('3. Check if using correct API URL');
      print('4. Wait 5-10 minutes for new credentials to activate');
    } else if (response.statusCode == 400) {
      print('❌ BAD REQUEST');
      print('The request format might be wrong');
      print('Check the API documentation for correct payload format');
    } else if (response.statusCode >= 500) {
      print('❌ SERVER ERROR');
      print('Pandora API server might be experiencing issues');
      print('Try again in a few minutes');
    } else {
      print('❌ UNEXPECTED RESPONSE');
      print('Status: ${response.statusCode}');
    }
    
  } on http.ClientException catch (e) {
    print('❌ CONNECTION ERROR: $e');
    print('\nPossible issues:');
    print('- Pandora API server is unreachable');
    print('- Wrong API URL');
    print('- Internet connection issue');
  } catch (e) {
    print('❌ ERROR: $e');
  }
}
