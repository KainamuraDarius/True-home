import 'dart:io';
import 'package:flutter/foundation.dart';

class ConnectionTest {
  static Future<Map<String, dynamic>> testConnections() async {
    final results = <String, dynamic>{};
    
    // Test 1: Internet connectivity
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      results['internet'] = result.isNotEmpty;
    } catch (e) {
      results['internet'] = false;
      results['internetError'] = e.toString();
    }
    
    // Test 2: Check if running on emulator
    results['isEmulator'] = !kReleaseMode;
    
    return results;
  }
  
  static void printResults(Map<String, dynamic> results) {
    debugPrint('=== Connection Test Results ===');
    results.forEach((key, value) {
      debugPrint('$key: $value');
    });
    debugPrint('==============================');
  }
}
