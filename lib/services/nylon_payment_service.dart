import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Payment service backed by Firebase Functions.
/// The current backend provider is Nylon Pay.
class NylonPaymentService {
  static final NylonPaymentService _instance = NylonPaymentService._internal();

  factory NylonPaymentService() => _instance;

  NylonPaymentService._internal();

  // These point to the new 2nd gen Firebase Function names.
  static const String _cloudFunctionUrl =
      'https://us-central1-truehome-9a244.cloudfunctions.net/nylonPayment';
  static const String _statusFunctionUrl =
      'https://us-central1-truehome-9a244.cloudfunctions.net/nylonPaymentStatus';

  Future<PaymentInitResponse> initiatePayment({
    required String phoneNumber,
    required double amount,
    required String transactionRef,
    required String narrative,
  }) async {
    try {
      if (!_isValidUgandanPhoneNumber(phoneNumber)) {
        throw PaymentException(
          'Invalid phone number. Use format: +2567XXXXXXXX with no spaces.',
        );
      }

      final normalizedPhone = _normalizePhoneNumber(phoneNumber);

      debugPrint('=== PAYMENT: initiating transaction ===');
      debugPrint('Phone: $normalizedPhone');
      debugPrint('Amount: UGX ${amount.toInt()}');
      debugPrint('Reference: $transactionRef');
      debugPrint('Narrative: $narrative');
      debugPrint('======================================');

      final requestBody = {
        'amount': amount.toInt(),
        'transaction_ref': transactionRef,
        'contact': normalizedPhone,
        'narrative': narrative,
      };

      final response = await http
          .post(
            Uri.parse(_cloudFunctionUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 60));

      debugPrint('Payment response status: ${response.statusCode}');
      debugPrint('Payment response body: ${response.body}');

      final jsonResponse = _decodeJsonResponse(
        response,
        serviceName: 'payment',
      );

      if (response.statusCode == 200 && jsonResponse['success'] == true) {
        final transactionData =
            (jsonResponse['data'] as List?)?.first as Map<String, dynamic>?;

        if (transactionData != null) {
          debugPrint(
            'Payment trace: transactionId=${transactionData['transaction_id']}, '
            'providerTransactionId=${transactionData['provider_transaction_id']}, '
            'lifecycle=${transactionData['lifecycle_outcome']}, '
            'normalizedPhone=${transactionData['normalized_phone']}',
          );
          return PaymentInitResponse(
            success: true,
            transactionId: transactionRef,
            transactionReference:
                transactionData['transaction_reference'] ?? transactionRef,
            status: transactionData['status'] ?? 'processing',
            amount: amount,
            message:
                'Payment initiated. User will receive payment prompt on their phone.',
            networkUsed: transactionData['network'] ?? 'mobileMoney',
            initiatedAt: transactionData['initiated_at'],
            nylonTransactionId: transactionData['transaction_id']?.toString(),
            providerTransactionId: transactionData['provider_transaction_id']
                ?.toString(),
            failureDetail: transactionData['failure_detail']?.toString(),
            lifecycleOutcome: transactionData['lifecycle_outcome']?.toString(),
            normalizedPhone: transactionData['normalized_phone']?.toString(),
          );
        }
      }

      final errorMessage = jsonResponse['messages'] != null
          ? (jsonResponse['messages'] as List?)?.first ??
                'Payment initialization failed'
          : 'Payment initialization failed';

      final transactionData =
          (jsonResponse['data'] as List?)?.first as Map<String, dynamic>?;
      final status = transactionData?['status']
          ?.toString()
          .toLowerCase()
          .trim();
      if (transactionData != null) {
        debugPrint(
          'Payment failure trace: transactionId=${transactionData['transaction_id']}, '
          'providerTransactionId=${transactionData['provider_transaction_id']}, '
          'detail=${transactionData['failure_detail']}, '
          'lifecycle=${transactionData['lifecycle_outcome']}, '
          'normalizedPhone=${transactionData['normalized_phone']}',
        );
      }
      if (status == 'failed') {
        throw PaymentException(
          'The payment request was not accepted by the provider. Please confirm the phone number and mobile money account, then try again.',
        );
      }

      throw PaymentException(errorMessage.toString());
    } on PaymentException {
      rethrow;
    } catch (e) {
      debugPrint('Payment initiation error: $e');

      String userMessage = e.toString();
      if (userMessage.contains('Failed host lookup')) {
        userMessage =
            'We could not reach the payment service. Please check your connection and try again.';
      } else if (userMessage.contains('SocketException')) {
        userMessage =
            'There was a network problem while contacting the payment service. Please try again.';
      } else if (userMessage.contains('timeout')) {
        userMessage =
            'The payment request took too long to respond. Please wait a moment and try again.';
      } else if (userMessage.contains('401') ||
          userMessage.contains('Unauthorized')) {
        userMessage =
            'The payment service could not verify this request. Please try again shortly.';
      } else if (userMessage.contains('400') ||
          userMessage.contains('Bad Request')) {
        userMessage =
            'Some payment details were not accepted. Please review them and try again.';
      }

      throw PaymentException(userMessage);
    }
  }

  Future<PaymentStatusResponse> checkPaymentStatus({
    required String transactionRef,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(_statusFunctionUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'transaction_ref': transactionRef}),
          )
          .timeout(const Duration(seconds: 30));

      debugPrint('Payment status HTTP ${response.statusCode}');
      debugPrint('Payment status headers: ${response.headers}');
      final jsonResponse = _decodeJsonResponse(
        response,
        serviceName: 'payment status',
      );

      if (response.statusCode == 200 && jsonResponse['success'] == true) {
        final data =
            (jsonResponse['data'] as List?)?.first as Map<String, dynamic>?;
        if (data != null) {
          return PaymentStatusResponse(
            success: _isSuccessStatus(data['status']?.toString() ?? ''),
            transactionId: transactionRef,
            status: data['status'] ?? 'processing',
            message: _getStatusMessage(data['status'] ?? ''),
            amount: double.tryParse(data['amount']?.toString() ?? '0') ?? 0,
            transactionCharge:
                double.tryParse(
                  data['transaction_charge']?.toString() ?? '0',
                ) ??
                0,
            completedOn: data['completed_on'] ?? data['updated_at'],
          );
        }
      }

      final errorMessage = jsonResponse['messages'] != null
          ? (jsonResponse['messages'] as List?)?.first ??
                'Failed to check payment status'
          : 'Failed to check payment status';
      throw PaymentException(errorMessage.toString());
    } on PaymentException {
      rethrow;
    } catch (e) {
      final message = e.toString();
      if (message.contains('403')) {
        throw PaymentException(
          'The payment status service is not available right now. Please try again shortly.',
        );
      }
      throw PaymentException(
        'We could not confirm the payment status right now. Please try again shortly.',
      );
    }
  }

  Future<bool> cancelPayment({required String transactionRef}) async {
    try {
      debugPrint('PAYMENT: cancelling transaction');
      debugPrint('Reference: $transactionRef');

      throw PaymentException(
        'Canceling payment is not supported via the Cloud Function.',
      );
    } catch (e) {
      debugPrint('Payment cancel error: $e');
      return false;
    }
  }

  bool _isValidUgandanPhoneNumber(String phoneNumber) {
    final normalized = _normalizePhoneNumber(phoneNumber);
    return RegExp(r'^\+2567\d{8}$').hasMatch(normalized);
  }

  String _normalizePhoneNumber(String phoneNumber) {
    var cleaned = phoneNumber.replaceAll(RegExp(r'\D'), '');

    if (cleaned.startsWith('256256')) {
      cleaned = '256${cleaned.substring(6)}';
    }

    if (cleaned.startsWith('2560')) {
      cleaned = '256${cleaned.substring(4)}';
    }

    if (cleaned.startsWith('0')) {
      cleaned = '256${cleaned.substring(1)}';
    }

    if (!cleaned.startsWith('256')) {
      cleaned = '256$cleaned';
    }

    if (cleaned.startsWith('2567') && cleaned.length == 12) {
      return '+$cleaned';
    }

    return '+$cleaned';
  }

  bool _isSuccessStatus(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'success':
      case 'successful':
      case 'paid':
        return true;
      default:
        return false;
    }
  }

  Map<String, dynamic> _decodeJsonResponse(
    http.Response response, {
    required String serviceName,
  }) {
    final contentType = (response.headers['content-type'] ?? '').toLowerCase();
    final bodyText = response.body.trimLeft();
    final looksLikeJson = bodyText.startsWith('{') || bodyText.startsWith('[');

    if (!contentType.contains('application/json') && !looksLikeJson) {
      final bodyPreview = response.body.length > 240
          ? '${response.body.substring(0, 240)}...'
          : response.body;
      debugPrint('$serviceName non-JSON body: $bodyPreview');
      throw PaymentException(
        _messageForHttpFailure(
          response.statusCode,
          fallback:
              'The $serviceName service returned an unexpected response. Please try again later.',
        ),
      );
    }

    try {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } on FormatException {
      throw PaymentException(
        'The $serviceName service returned an unreadable response. Please try again later.',
      );
    }
  }

  String _messageForHttpFailure(int statusCode, {required String fallback}) {
    switch (statusCode) {
      case 400:
        return 'The payment request details were invalid. Please review and try again.';
      case 401:
        return 'The payment service could not verify this request. Please try again shortly.';
      case 403:
        return 'The payment service is not available yet. Please redeploy the Firebase functions, then try again.';
      case 404:
        return 'The payment service could not be found. Please confirm the latest Firebase functions are deployed.';
      case 429:
        return 'The payment service is busy right now. Please wait a moment and try again.';
      case 500:
      case 502:
      case 503:
      case 504:
        return 'The payment service is temporarily unavailable. Please try again shortly.';
      default:
        return fallback;
    }
  }

  String _getStatusMessage(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'success':
      case 'successful':
      case 'paid':
        return 'Payment completed successfully!';
      case 'processing':
      case 'pending':
        return 'Your payment is still being processed. Please wait a moment.';
      case 'failed':
      case 'declined':
        return 'The payment did not go through. Please try again.';
      case 'cancelled':
        return 'The payment was cancelled before it was completed.';
      case 'expired':
        return 'The payment request expired before it was completed.';
      case 'user_cancelled':
        return 'The payment request was cancelled before confirmation.';
      case 'timeout':
        return 'The payment took too long to complete. Please try again.';
      default:
        return 'Payment status: $status';
    }
  }
}

class PaymentInitResponse {
  final bool success;
  final String transactionId;
  final String transactionReference;
  final String status;
  final double amount;
  final String message;
  final String networkUsed;
  final String? initiatedAt;
  final String? nylonTransactionId;
  final String? providerTransactionId;
  final String? failureDetail;
  final String? lifecycleOutcome;
  final String? normalizedPhone;

  PaymentInitResponse({
    required this.success,
    required this.transactionId,
    required this.transactionReference,
    required this.status,
    required this.amount,
    required this.message,
    required this.networkUsed,
    this.initiatedAt,
    this.nylonTransactionId,
    this.providerTransactionId,
    this.failureDetail,
    this.lifecycleOutcome,
    this.normalizedPhone,
  });
}

class PaymentStatusResponse {
  final bool success;
  final String transactionId;
  final String status;
  final String message;
  final double amount;
  final double transactionCharge;
  final String? completedOn;

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

class PaymentException implements Exception {
  final String message;

  PaymentException(this.message);

  @override
  String toString() => message;
}
