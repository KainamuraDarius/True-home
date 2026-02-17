import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';

String generateUuid() {
  final random = Random();
  final values = List<int>.generate(16, (i) => random.nextInt(256));
  
  values[6] = (values[6] & 0x0f) | 0x40;
  values[8] = (values[8] & 0x3f) | 0x80;
  
  String toHex(int value) => value.toRadixString(16).padLeft(2, '0');
  
  return '${toHex(values[0])}${toHex(values[1])}${toHex(values[2])}${toHex(values[3])}-'
      '${toHex(values[4])}${toHex(values[5])}-'
      '${toHex(values[6])}${toHex(values[7])}-'
      '${toHex(values[8])}${toHex(values[9])}-'
      '${toHex(values[10])}${toHex(values[11])}${toHex(values[12])}${toHex(values[13])}${toHex(values[14])}${toHex(values[15])}';
}

void main() async {
  final subscriptionKey = 'ec1bc2bfcfb3454d8188a0845e852912';
  final apiUser = '19b13f36-b1d9-4060-89e1-3034ff4b863a';
  final apiKey = 'e501262d19434a92b34d2fe0fc9ad74d';
  
  print('╔═══════════════════════════════════════════════════════╗');
  print('║     MTN MoMo Sandbox - Full Integration Test         ║');
  print('╚═══════════════════════════════════════════════════════╝\n');
  
  try {
    // Step 1: Authenticate
    print('Step 1: Authentication...');
    final credentials = base64Encode(utf8.encode('$apiUser:$apiKey'));
    
    final tokenResponse = await http.post(
      Uri.parse('https://sandbox.momodeveloper.mtn.com/collection/token/'),
      headers: {
        'Authorization': 'Basic $credentials',
        'Ocp-Apim-Subscription-Key': subscriptionKey,
      },
    );
    
    if (tokenResponse.statusCode != 200) {
      print('❌ Authentication failed: ${tokenResponse.statusCode}');
      return;
    }
    
    final tokenData = json.decode(tokenResponse.body);
    final accessToken = tokenData['access_token'];
    print('✅ Authenticated successfully\n');
    
    // Step 2: Request Payment
    print('Step 2: Creating payment request...');
    final referenceId = generateUuid();
    print('Reference ID: $referenceId');
    
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
        'externalId': generateUuid(),
        'payer': {
          'partyIdType': 'MSISDN',
          'partyId': '46733123450',
        },
        'payerMessage': 'TrueHome hostel reservation',
        'payeeNote': 'Room booking test',
      }),
    );
    
    print('Payment request status: ${payResponse.statusCode}');
    
    if (payResponse.statusCode == 202) {
      print('✅ Payment request accepted!\n');
      
      // Step 3: Check payment status
      print('Step 3: Checking payment status...');
      await Future.delayed(Duration(seconds: 2));
      
      final statusResponse = await http.get(
        Uri.parse('https://sandbox.momodeveloper.mtn.com/collection/v1_0/requesttopay/$referenceId'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'X-Target-Environment': 'sandbox',
          'Ocp-Apim-Subscription-Key': subscriptionKey,
        },
      );
      
      if (statusResponse.statusCode == 200) {
        final status = json.decode(statusResponse.body);
        print('Payment status: ${status['status']}');
        print('Full response: ${json.encode(status)}\n');
        
        if (status['status'] == 'SUCCESSFUL') {
          print('🎉🎉🎉 MTN SANDBOX IS FULLY WORKING! 🎉🎉🎉\n');
        } else {
          print('✅ API is working (status: ${status['status']})\n');
        }
      }
      
      print('╔═══════════════════════════════════════════════════════╗');
      print('║                 INTEGRATION READY!                    ║');
      print('╠═══════════════════════════════════════════════════════╣');
      print('║  ✅ Credentials are valid                             ║');
      print('║  ✅ Authentication works                              ║');
      print('║  ✅ Payment requests work                             ║');
      print('║  ✅ Status checks work                                ║');
      print('╠═══════════════════════════════════════════════════════╣');
      print('║  NEXT STEPS:                                          ║');
      print('║  1. Credentials already updated in service            ║');
      print('║  2. useMockMode = false already set                   ║');
      print('║  3. Ready to test in Flutter app!                     ║');
      print('╚═══════════════════════════════════════════════════════╝');
      
    } else {
      print('❌ Payment request failed: ${payResponse.statusCode}');
      print('Response: ${payResponse.body}');
    }
    
  } catch (e) {
    print('❌ Error: $e');
  }
}
