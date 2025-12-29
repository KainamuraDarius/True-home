import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkUtils {
  static Future<bool> hasInternetConnection() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        return false;
      }
      
      // Actually check if we can reach a server
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
  
  static String getErrorMessage(dynamic error) {
    if (error is SocketException) {
      return 'No internet connection. Please check your network settings.';
    } else if (error is TimeoutException) {
      return 'Connection timeout. The server is taking too long to respond.';
    } else if (error is HttpException) {
      return 'Server error. Please try again later.';
    } else if (error is FormatException) {
      return 'Invalid response from server.';
    }
    return error.toString();
  }
}
