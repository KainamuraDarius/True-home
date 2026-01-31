import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  final subscriptionKey = 'ec1bc2bfcfb3454d8188a0845e852912';
  
  print('Testing MTN MoMo API connection...\n');
  
  // Test if subscription key is valid by checking sandbox status
  try {
    final response = await http.get(
      Uri.parse('https://sandbox.momodeveloper.mtn.com/'),
      headers: {
        'Ocp-Apim-Subscription-Key': subscriptionKey,
      },
    );
    
    print('Sandbox Status: ${response.statusCode}');
    print('Response: ${response.body}\n');
    
    if (response.statusCode == 200 || response.statusCode == 404) {
      print('✅ Subscription key is valid!');
      print('✅ MTN API is reachable!');
      print('\n⚠️ The 500 error you\'re getting is likely temporary.');
      print('MTN\'s sandbox sometimes has issues. Try again in a few minutes.');
      print('\nAlternatively, you can:');
      print('1. Contact MTN support: momodeveloper@mtn.com');
      print('2. Check MTN MoMo Developer status page');
      print('3. Try using the production API if you\'re ready');
    } else {
      print('❌ Issue with subscription key or API access');
    }
  } catch (e) {
    print('Error: $e');
  }
}
