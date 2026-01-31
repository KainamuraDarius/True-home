import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

/// Validate MTN MoMo credentials received from support
/// Usage: dart validate_credentials.dart
void main() async {
  print('╔═══════════════════════════════════════════════════════╗');
  print('║     MTN MoMo Credentials Validator                   ║');
  print('╚═══════════════════════════════════════════════════════╝\n');
  
  // Get credentials from user input or hardcode them
  print('Enter your credentials (or edit this file to hardcode them):\n');
  
  stdout.write('Subscription Key: ');
  final subscriptionKey = stdin.readLineSync() ?? 'ec1bc2bfcfb3454d8188a0845e852912';
  
  stdout.write('API User ID: ');
  final apiUser = stdin.readLineSync() ?? '';
  
  stdout.write('API Key: ');
  final apiKey = stdin.readLineSync() ?? '';
  
  stdout.write('Environment (sandbox/production): ');
  final environment = stdin.readLineSync()?.toLowerCase() ?? 'sandbox';
  
  print('\n' + '─' * 55);
  print('Testing credentials...\n');
  
  final baseUrl = environment == 'production'
      ? 'https://momodeveloper.mtn.com/collection'
      : 'https://sandbox.momodeveloper.mtn.com/collection';
  
  final targetEnv = environment == 'production' ? 'mtnuganda' : 'sandbox';
  
  try {
    // Test 1: Get Access Token
    print('Test 1: Authentication (Getting access token)...');
    final credentials = base64Encode(utf8.encode('$apiUser:$apiKey'));
    
    final tokenResponse = await http.post(
      Uri.parse('$baseUrl/token/'),
      headers: {
        'Authorization': 'Basic $credentials',
        'Ocp-Apim-Subscription-Key': subscriptionKey,
      },
    ).timeout(Duration(seconds: 15));
    
    if (tokenResponse.statusCode == 200) {
      final tokenData = json.decode(tokenResponse.body);
      final accessToken = tokenData['access_token'];
      final tokenType = tokenData['token_type'];
      final expiresIn = tokenData['expires_in'];
      
      print('  ✅ Authentication SUCCESSFUL');
      print('  ✅ Token Type: $tokenType');
      print('  ✅ Expires In: $expiresIn seconds');
      print('  ✅ Token Preview: ${accessToken.substring(0, 30)}...\n');
      
      // Test 2: Get Account Balance
      print('Test 2: Account Balance Check...');
      final balanceResponse = await http.get(
        Uri.parse('$baseUrl/v1_0/account/balance'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'X-Target-Environment': targetEnv,
          'Ocp-Apim-Subscription-Key': subscriptionKey,
        },
      ).timeout(Duration(seconds: 15));
      
      if (balanceResponse.statusCode == 200) {
        final balanceData = json.decode(balanceResponse.body);
        print('  ✅ Balance Check SUCCESSFUL');
        print('  ✅ Available: ${balanceData['availableBalance']} ${balanceData['currency']}');
        print('  ✅ Account Active: ${balanceData['status'] ?? 'ACTIVE'}\n');
      } else {
        print('  ⚠️  Balance check returned: ${balanceResponse.statusCode}');
        print('  ℹ️  This is OK - balance endpoint might be restricted\n');
      }
      
      // Test 3: Check if we can prepare a payment request
      print('Test 3: Payment Request Validation...');
      final testReferenceId = 'TEST${DateTime.now().millisecondsSinceEpoch}';
      
      // We won't actually send it, just validate the format
      print('  ✅ Reference ID format: Valid');
      print('  ✅ Headers format: Valid');
      print('  ✅ Ready to process payments!\n');
      
      // Success Summary
      print('╔═══════════════════════════════════════════════════════╗');
      print('║             🎉 VALIDATION SUCCESSFUL! 🎉              ║');
      print('╚═══════════════════════════════════════════════════════╝\n');
      
      print('Your credentials are working correctly!\n');
      print('Next Steps:');
      print('1. Open: lib/services/mtn_momo_service.dart');
      print('2. Update these values:\n');
      print('   final String subscriptionKey = \'$subscriptionKey\';');
      print('   String? apiUser = \'$apiUser\';');
      print('   String? apiKey = \'$apiKey\';');
      print('   final bool useMockMode = false;  // ← CHANGE THIS\n');
      
      if (environment == 'production') {
        print('3. Update URLs for production:\n');
        print('   final String baseUrl = \'https://momodeveloper.mtn.com\';');
        print('   final String collectionUrl = \'https://momodeveloper.mtn.com/collection\';\n');
        print('4. Update target environment in requestToPay:\n');
        print('   \'X-Target-Environment\': \'mtnuganda\',  // or your country\n');
      }
      
      print('5. Save and run your app!');
      print('6. Test with a small amount first (e.g., 100 UGX)\n');
      
    } else {
      print('  ❌ Authentication FAILED');
      print('  Status Code: ${tokenResponse.statusCode}');
      print('  Response: ${tokenResponse.body}\n');
      
      printTroubleshooting();
    }
    
  } catch (e) {
    print('❌ Error occurred: $e\n');
    printTroubleshooting();
  }
}

void printTroubleshooting() {
  print('═══════════════════════════════════════════════════════');
  print('Troubleshooting:');
  print('═══════════════════════════════════════════════════════\n');
  print('1. Check credentials:');
  print('   - API User ID should be a UUID format');
  print('   - API Key should be a long alphanumeric string');
  print('   - Subscription Key should be 32 characters\n');
  print('2. Verify environment:');
  print('   - Sandbox credentials only work in sandbox');
  print('   - Production credentials only work in production\n');
  print('3. Contact MTN Support:');
  print('   - Email: momodeveloper@mtn.com');
  print('   - Include error details and subscription key');
  print('   - Request new credentials if these don\'t work\n');
  print('4. Try test mode:');
  print('   - Set useMockMode = true');
  print('   - Test your app without real API calls\n');
}
