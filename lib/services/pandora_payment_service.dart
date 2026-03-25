import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

/// Pandora Payments API Service
class PandoraPaymentService {
  static final PandoraPaymentService _instance =
      PandoraPaymentService._internal();

  factory PandoraPaymentService() => _instance;

  PandoraPaymentService._internal();

  // Use your deployed Firebase Cloud Function endpoint
  static const String _cloudFunctionUrl =
      'https://us-central1-truehome-9a244.cloudfunctions.net/pandoraPayment';
  static const String _callbackUrl =
      'https://us-central1-truehome-9a244.cloudfunctions.net/pandoraPaymentWebhook';

  // ============================================
  // API METHODS
  // ============================================

  /// Initiate a mobile money payment transaction
  /// This starts the payment process - user will receive USSD prompt or use their app
  Future<PaymentInitResponse> initiatePayment({
    required String phoneNumber,
    required double amount,
    required String transactionRef, // Your unique transaction reference
    required String narrative, // Description of transaction
  }) async {
    try {
      // Validate phone number format
      if (!_isValidUgandanPhoneNumber(phoneNumber)) {
        throw PaymentException(
          'Invalid phone number. Use format: 256XXXXXXXXX, +256XXXXXXXXX, or 0XXXXXXXXX',
        );
      }

      final normalizedPhone = _normalizePhoneNumber(phoneNumber);

      debugPrint('═══════════════════════════════════════');
      debugPrint('🔵 PANDORA PAYMENTS: Initiating Transaction');
      debugPrint('═══════════════════════════════════════');
      debugPrint('Phone: $normalizedPhone');
      debugPrint('Amount: UGX ${amount.toInt()}');
      debugPrint('Reference: $transactionRef');
      debugPrint('Narrative: $narrative');
      debugPrint('Callback: $_callbackUrl');
      debugPrint('═══════════════════════════════════════\n');

      // Prepare request body according to API documentation
      final requestBody = {
        'amount': amount.toInt(), // Amount in UGX
        'transaction_ref': transactionRef, // Unique transaction reference
        'contact': normalizedPhone, // Customer's mobile money number
        'narrative': narrative, // Description
        'callback_url': _callbackUrl, // Webhook URL for status updates
      };

      // Make API request with longer timeout (60 seconds)
      final response = await http
          .post(
            Uri.parse(_cloudFunctionUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 60));

      debugPrint('📡 Response Status: ${response.statusCode}');
      debugPrint('📡 Response Body: ${response.body}\n');

      final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;

      // Check if API call was successful
      if (response.statusCode == 200 && jsonResponse['success'] == true) {
        // Extract transaction data from response
        final transactionData =
            (jsonResponse['data'] as List?)?.first as Map<String, dynamic>?;

        if (transactionData != null) {
          return PaymentInitResponse(
            success: true,
            transactionId: transactionRef, // Use our transaction ref as ID
            transactionReference:
                transactionData['transaction_reference'] ?? transactionRef,
            status: transactionData['status'] ?? 'processing',
            amount: amount,
            message:
                'Payment initiated. User will receive payment prompt on their phone.',
            networkUsed: transactionData['network'] ?? 'MTN/Airtel',
            initiatedAt: transactionData['initiated_at'],
          );
        }
      }

      // Handle errors
      final errorMessage = jsonResponse['messages'] != null
          ? (jsonResponse['messages'] as List?)?.first ??
                'Payment initialization failed'
          : 'Payment initialization failed';

      throw PaymentException(errorMessage);
    } on PaymentException {
      rethrow;
    } catch (e) {
      debugPrint('❌ ERROR: $e\n');

      // Provide more specific error messages based on the error type
      String userMessage = e.toString();
      if (userMessage.contains('Failed host lookup')) {
        userMessage =
            'Cannot reach Pandora servers. Check your internet connection or try using a VPN.';
      } else if (userMessage.contains('SocketException')) {
        userMessage = 'Network error. Please check your WiFi/data connection.';
      } else if (userMessage.contains('timeout')) {
        userMessage =
            'Request timed out. Pandora servers may be slow. Try again.';
      } else if (userMessage.contains('401') ||
          userMessage.contains('Unauthorized')) {
        userMessage = 'API key invalid. Check your Pandora credentials.';
      } else if (userMessage.contains('400') ||
          userMessage.contains('Bad Request')) {
        userMessage = 'Invalid payment parameters. Contact support.';
      }

      throw PaymentException(userMessage);
    }
  }

  /// Check the status of a payment transaction
  /// Poll this endpoint to see if user has completed the payment
  Future<PaymentStatusResponse> checkPaymentStatus({
    required String transactionRef,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(
              'https://us-central1-truehome-9a244.cloudfunctions.net/pandoraPaymentStatus',
            ),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'transaction_ref': transactionRef}),
          )
          .timeout(const Duration(seconds: 30));

      debugPrint('🔎 Payment status HTTP ${response.statusCode}');
      debugPrint('🔎 Payment status headers: ${response.headers}');

      // Some proxies may return JSON payloads with non-JSON content-type headers.
      final contentType = (response.headers['content-type'] ?? '')
          .toLowerCase();
      final bodyText = response.body.trimLeft();
      final looksLikeJson =
          bodyText.startsWith('{') || bodyText.startsWith('[');
      if (!contentType.contains('application/json') && !looksLikeJson) {
        final bodyPreview = response.body.length > 240
            ? '${response.body.substring(0, 240)}...'
            : response.body;
        debugPrint('⚠️ Payment status non-JSON body: $bodyPreview');
        throw PaymentException(
          'Payment status service unavailable. Please try again later.',
        );
      }

      final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && jsonResponse['success'] == true) {
        final data =
            (jsonResponse['data'] as List?)?.first as Map<String, dynamic>?;
        if (data != null) {
          return PaymentStatusResponse(
            success:
                data['status'] == 'completed' ||
                data['status'] == 'success' ||
                data['status'] == 'paid',
            transactionId: transactionRef,
            status: data['status'] ?? 'processing',
            message: _getStatusMessage(data['status'] ?? ''),
            amount: double.tryParse(data['amount']?.toString() ?? '0') ?? 0,
            transactionCharge:
                double.tryParse(
                  data['transaction_charge']?.toString() ?? '0',
                ) ??
                0,
            completedOn: data['completed_on'],
          );
        }
      }

      final errorMessage = jsonResponse['messages'] != null
          ? (jsonResponse['messages'] as List?)?.first ??
                'Failed to check payment status'
          : 'Failed to check payment status';
      throw PaymentException(errorMessage);
    } on PaymentException {
      rethrow;
    } catch (e) {
      throw PaymentException('Error checking payment status: $e');
    }
  }

  /// Cancel a payment request (before user completes payment)
  /// Use this if payment needs to be cancelled
  Future<bool> cancelPayment({required String transactionRef}) async {
    try {
      debugPrint('🔵 PANDORA PAYMENTS: Cancelling Transaction');
      debugPrint('Reference: $transactionRef\n');

      // Not supported via the proxy Cloud Function yet
      throw PaymentException(
        'Canceling payment is not supported via the Cloud Function.',
      );
    } catch (e) {
      debugPrint('❌ ERROR: $e\n');
      return false;
    }
  }

  // ============================================
  // HELPER METHODS
  // ============================================

  /// Validate Uganda phone number in various formats
  /// Accepts: 256XXXXXXXXX, +256XXXXXXXXX, 0XXXXXXXXX
  bool _isValidUgandanPhoneNumber(String phoneNumber) {
    final cleaned = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');

    // Must be Uganda number (starting with 256 or 0) and have 10-13 total digits
    return RegExp(r'^(\+256|256|0)\d{9}$').hasMatch(cleaned);
  }

  /// Convert phone number to standard format: 256XXXXXXXXX
  String _normalizePhoneNumber(String phoneNumber) {
    var cleaned = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');

    // Remove + prefix
    cleaned = cleaned.replaceAll('+', '');

    // If starts with 0, replace with 256
    if (cleaned.startsWith('0')) {
      cleaned = '256${cleaned.substring(1)}';
    }

    // If doesn't have country code, assume Uganda
    if (!cleaned.startsWith('256')) {
      cleaned = '256$cleaned';
    }

    return cleaned;
  }

  /// Get user-friendly message for payment status
  String _getStatusMessage(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'success':
      case 'paid':
        return 'Payment completed successfully! ✅';
      case 'processing':
      case 'pending':
        return 'Payment is being processed. Please wait...';
      case 'failed':
      case 'declined':
        return 'Payment failed. Please try again.';
      case 'cancelled':
        return 'Payment was cancelled. You may have cancelled the prompt or failed to confirm your PIN.';
      case 'expired':
        return 'Payment request expired. You may have ignored the prompt or not confirmed your PIN in time.';
      case 'user_cancelled':
        return 'You cancelled the payment request or did not confirm your PIN.';
      case 'timeout':
        return 'Payment timed out. You may have ignored the prompt or not confirmed your PIN.';
      default:
        return 'Payment status: $status';
    }
  }
}

// ============================================
// RESPONSE MODELS
// ============================================

/// Response when initiating a new payment
class PaymentInitResponse {
  final bool success;
  final String transactionId; // Your internal transaction ID
  final String transactionReference; // Pandora's transaction reference
  final String status; // processing, completed, etc
  final double amount;
  final String message;
  final String networkUsed; // MTN, Airtel, etc
  final String? initiatedAt; // Timestamp

  PaymentInitResponse({
    required this.success,
    required this.transactionId,
    required this.transactionReference,
    required this.status,
    required this.amount,
    required this.message,
    required this.networkUsed,
    this.initiatedAt,
  });
}

/// Response when checking payment status
class PaymentStatusResponse {
  final bool success; // true if payment completed
  final String transactionId;
  final String status; // processing, completed, failed, etc
  final String message;
  final double amount;
  final double transactionCharge; // Pandora's fee
  final String? completedOn; // Timestamp of completion

  PaymentStatusResponse({
    required this.success,
    required this.transactionId,
    required this.status,
    required this.message,
    required this.amount,
    required this.transactionCharge,
    this.completedOn,
  });
}

/// Custom exception for payment errors
class PaymentException implements Exception {
  final String message;

  PaymentException(this.message);

  @override
  String toString() => message;
}
