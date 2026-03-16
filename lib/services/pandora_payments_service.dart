import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_keys.dart';

class PandoraPaymentResult {
  final bool success;
  final String? transactionReference;
  final String? status;
  final String? network;
  final String? errorMessage;

  PandoraPaymentResult({
    required this.success,
    this.transactionReference,
    this.status,
    this.network,
    this.errorMessage,
  });
}

class PandoraPaymentsService {
  static const String _baseUrl = 'https://api.pandorapayments.com/v1';

  /// Formats a Ugandan phone number to the required 256XXXXXXXXX format.
  static String formatNumber(String number) {
    // Remove spaces, hyphens, +
    number = number.replaceAll(RegExp(r'[\s\-\+]'), '');
    if (number.startsWith('0') && number.length == 10) {
      return '256${number.substring(1)}';
    }
    if (number.startsWith('256') && number.length == 12) {
      return number;
    }
    if (number.length == 9) {
      return '256$number';
    }
    return number;
  }

  /// Initiates a mobile money payment request.
  /// [amount]          - Amount in UGX
  /// [transactionRef]  - Your unique reference (use Firestore doc ID)
  /// [contact]         - Customer's number in 256XXXXXXXXX format
  /// [narrative]       - Description shown to the payer
  /// [callbackUrl]     - Webhook URL to receive status updates
  Future<PandoraPaymentResult> initiatePayment({
    required double amount,
    required String transactionRef,
    required String contact,
    required String narrative,
    required String callbackUrl,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/transactions/mobile-money'),
            headers: {
              'Content-Type': 'application/json',
              'X-API-Key': ApiKeys.pandoraPaymentsApiKey,
            },
            body: jsonEncode({
              'amount': amount.toInt(),
              'transaction_ref': transactionRef,
              'contact': contact,
              'narrative': narrative,
              'callback_url': callbackUrl,
            }),
          )
          .timeout(const Duration(seconds: 30));

      final json = jsonDecode(response.body) as Map<String, dynamic>;

      if (json['success'] == true) {
        final data = (json['data'] as List).first as Map<String, dynamic>;
        return PandoraPaymentResult(
          success: true,
          transactionReference: data['transaction_reference']?.toString(),
          status: data['status']?.toString(),
          network: data['network']?.toString(),
        );
      } else {
        final messages = (json['messages'] as List?)?.join(', ') ?? 'Payment failed';
        return PandoraPaymentResult(success: false, errorMessage: messages);
      }
    } on Exception catch (_) {
      return PandoraPaymentResult(
        success: false,
        errorMessage: 'Could not connect to payment service. Please check your internet connection.',
      );
    }
  }
}
