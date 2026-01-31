import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';

void main() async {
  final subscriptionKey = 'ec1bc2bfcfb3454d8188a0845e852912';
  
  print('🔄 Trying Alternative MTN Setup Methods...\n');
  
  // Try 1: Different UUID format
  print('Attempt 1: Using standard UUID...');
  await tryCreateUser(subscriptionKey, generateUuid(), 'webhook.site');
  
  // Try 2: Simpler UUID
  print('\nAttempt 2: Using simpler UUID...');
  await tryCreateUser(subscriptionKey, generateSimpleUuid(), 'webhook.site');
  
  // Try 3: Without callback
  print('\nAttempt 3: Without callback host...');
  await tryCreateUser(subscriptionKey, generateUuid(), null);
  
  // Try 4: Using their example UUID format
  print('\nAttempt 4: Using MTN example format...');
  await tryCreateUser(subscriptionKey, '00000000-0000-0000-0000-000000000000', 'webhook.site');
  
  // Try 5: Check account info
  print('\nAttempt 5: Checking account status...');
  await checkAccountStatus(subscriptionKey);
  
  print('\n❌ All attempts failed. MTN sandbox is definitely down.');
  print('\n📧 RECOMMENDED ACTION:');
  print('Email: momodeveloper@mtn.com');
  print('Subject: "Urgent - Sandbox API User Creation Failing"');
  print('Body: "All attempts to create API user return 500 error."');
  print('      "Subscription Key: $subscriptionKey"');
  print('      "Please provide credentials manually or fix sandbox."');
}

Future<void> tryCreateUser(String subscriptionKey, String uuid, String? callback) async {
  try {
    final body = callback == null 
        ? {} 
        : {'providerCallbackHost': callback};
    
    final response = await http.post(
      Uri.parse('https://sandbox.momodeveloper.mtn.com/v1_0/apiuser'),
      headers: {
        'X-Reference-Id': uuid,
        'Ocp-Apim-Subscription-Key': subscriptionKey,
        'Content-Type': 'application/json',
      },
      body: json.encode(body),
    ).timeout(Duration(seconds: 10));
    
    print('  UUID: ${uuid.substring(0, 20)}...');
    print('  Response: ${response.statusCode}');
    
    if (response.statusCode == 201) {
      print('  ✅ SUCCESS! User created!');
      await Future.delayed(Duration(seconds: 2));
      await getApiKey(subscriptionKey, uuid);
      return;
    } else if (response.statusCode == 409) {
      print('  ⚠️  User already exists! Trying to get key...');
      await getApiKey(subscriptionKey, uuid);
      return;
    } else {
      print('  ❌ Failed: ${response.body.substring(0, 100)}');
    }
  } catch (e) {
    print('  ❌ Error: $e');
  }
}

Future<void> getApiKey(String subscriptionKey, String userId) async {
  try {
    final response = await http.post(
      Uri.parse('https://sandbox.momodeveloper.mtn.com/v1_0/apiuser/$userId/apikey'),
      headers: {
        'Ocp-Apim-Subscription-Key': subscriptionKey,
      },
    ).timeout(Duration(seconds: 10));
    
    print('  API Key Response: ${response.statusCode}');
    
    if (response.statusCode == 201) {
      final data = json.decode(response.body);
      print('\n🎉🎉🎉 SUCCESS! 🎉🎉🎉');
      print('API User: $userId');
      print('API Key: ${data['apiKey']}');
      print('\nUpdate lib/services/mtn_momo_service.dart with these!');
    } else {
      print('  ❌ Key failed: ${response.body.substring(0, 100)}');
    }
  } catch (e) {
    print('  ❌ Key error: $e');
  }
}

Future<void> checkAccountStatus(String subscriptionKey) async {
  try {
    final response = await http.get(
      Uri.parse('https://sandbox.momodeveloper.mtn.com/collection/v1_0/accountbalance'),
      headers: {
        'Ocp-Apim-Subscription-Key': subscriptionKey,
      },
    ).timeout(Duration(seconds: 10));
    
    print('  Status Code: ${response.statusCode}');
    if (response.statusCode == 401 || response.statusCode == 403) {
      print('  ✅ Subscription key is valid (needs auth)');
    } else {
      print('  Response: ${response.body}');
    }
  } catch (e) {
    print('  Error: $e');
  }
}

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

String generateSimpleUuid() {
  final random = Random();
  return '${random.nextInt(999999).toString().padLeft(6, '0')}-'
         '${random.nextInt(9999).toString().padLeft(4, '0')}-'
         '${random.nextInt(9999).toString().padLeft(4, '0')}-'
         '${random.nextInt(9999).toString().padLeft(4, '0')}-'
         '${random.nextInt(100000000).toString().padLeft(8, '0')}${random.nextInt(10000).toString().padLeft(4, '0')}';
}
