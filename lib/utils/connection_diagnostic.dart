import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';

class ConnectionDiagnostic {
  static Future<Map<String, dynamic>> runDiagnostics() async {
    final results = <String, dynamic>{};
    
    // Test 1: Basic internet connectivity
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      results['internetConnected'] = result.isNotEmpty;
    } catch (e) {
      results['internetConnected'] = false;
      results['internetError'] = e.toString();
    }
    
    // Test 2: Can reach backend server
    try {
      final dio = Dio();
      final response = await dio.get(
        ApiConfig.baseUrl.replaceAll('/api', '/health'),
        options: Options(
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      ).timeout(const Duration(seconds: 10));
      
      results['serverReachable'] = true;
      results['serverStatus'] = response.statusCode;
    } catch (e) {
      results['serverReachable'] = false;
      results['serverError'] = e.toString();
    }
    
    // Test 3: DNS resolution
    try {
      final uri = Uri.parse(ApiConfig.baseUrl);
      if (uri.host != 'localhost' && uri.host != '10.0.2.2') {
        final addresses = await InternetAddress.lookup(uri.host)
            .timeout(const Duration(seconds: 5));
        results['dnsResolved'] = addresses.isNotEmpty;
      } else {
        results['dnsResolved'] = 'N/A (localhost)';
      }
    } catch (e) {
      results['dnsResolved'] = false;
      results['dnsError'] = e.toString();
    }
    
    results['baseUrl'] = ApiConfig.baseUrl;
    results['platform'] = Platform.operatingSystem;
    
    return results;
  }
  
  static void printDiagnostics(Map<String, dynamic> results) {
    debugPrint('╔════════════════════════════════════════╗');
    debugPrint('║   CONNECTION DIAGNOSTIC RESULTS        ║');
    debugPrint('╠════════════════════════════════════════╣');
    results.forEach((key, value) {
      debugPrint('║ $key: $value');
    });
    debugPrint('╚════════════════════════════════════════╝');
  }
  
  static String generateUserMessage(Map<String, dynamic> results) {
    if (results['internetConnected'] == false) {
      return 'No internet connection detected.\n\nPlease check your WiFi or mobile data and try again.';
    }
    
    if (results['serverReachable'] == false) {
      return 'Cannot connect to backend server.\n\n'
          'Server URL: ${results['baseUrl']}\n\n'
          'Possible solutions:\n'
          '• Make sure your backend server is running\n'
          '• Verify the server URL is correct\n'
          '• Check if firewall is blocking the connection\n'
          '• If using emulator, ensure you\'re using 10.0.2.2 instead of localhost\n\n'
          'Error: ${results['serverError']}';
    }
    
    return 'Connection issue detected. Please try again or contact support.';
  }
}
