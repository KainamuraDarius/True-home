import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  // Credentials from setup
  final subscriptionKey = 'ec1bc2bfcfb3454d8188a0845e852912';
  final apiUser = '19b13f36-b1d9-4060-89e1-3034ff4b863a';
  final apiKey = 'e501262d19434a92b34d2fe0fc9ad74d';
  
  print('🔍 Testing MTN MoMo Credentials...\n');
  print('Subscription Key: $subscriptionKey');
  print('API User: $apiUser');
  print('API Key: $apiKey\n');
  
  try {
    // Test 1: Get Access Token
    print('Test 1: Getting access token...');
    final credentials = base64Encode(utf8.encode('$apiUser:$apiKey'));
    
    final tokenResponse = await http.post(
      Uri.parse('https://sandbox.momodeveloper.mtn.com/collection/token/'),
      headers: {
        'Authorization': 'Basic $credentials',
        'Ocp-Apim-Subscription-Key': subscriptionKey,
      },
    );
    
    print('Status: ${tokenResponse.statusCode}');
    print('Response: ${tokenResponse.body}\n');
    
    if (tokenResponse.statusCode == 200) {
      final data = json.decode(tokenResponse.body);
      print('✅ SUCCESS! Access token received');
      print('Token: ${data['access_token'].substring(0, 20)}...\n');
      
      // Test 2: Try a requestToPay call
      print('Test 2: Testing requestToPay...');
      final accessToken = data['access_token'];
      final referenceId = '${DateTime.now().millisecondsSinceEpoch}-test-${(1000 + (9999 - 1000) * 0.5).toInt()}';
      
      final payResponse = await http.post(
        Uri.parse('https://sandbox.momodeveloper.mtn.com/collection/v1_0/requesttopay'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'X-Reference-Id': referenceId,
          'X-Target-Environment': 'sandbox',
          'Ocp-Apim-Subscription-Key': subscriptionKey,
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'amount': '100',
          'currency': 'EUR',
          'externalId': '123456',
          'payer': {
            'partyIdType': 'MSISDN',
            'partyId': '46733123450',
          },
          'payerMessage': 'Test payment',
          'payeeNote': 'Test',
        }),
      );
      
      print('Payment Status: ${payResponse.statusCode}');
      if (payResponse.statusCode == 202) {
        print('✅ Payment request accepted!\n');
        print('🎉 MTN Sandbox is FULLY WORKING!\n');
        print('═══════════════════════════════════════');
        print('You can now use real MTN MoMo payments!');
        print('Set useMockMode = false in your service');
        print('═══════════════════════════════════════');
      } else {
        print('Response: ${payResponse.body}');
      }
    } else {
      print('❌ Authentication failed');
      print('This might be because credentials need a few minutes to activate.');
      print('Wait 5-10 minutes and try again.\n');
    }
    
  } catch (e) {
    print('❌ Error: $e');
  }
}
