import 'package:url_launcher/url_launcher.dart';

class UrlLauncherService {
  // Make a phone call
  static Future<void> makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      throw Exception('Could not launch phone dialer');
    }
  }

  // Send SMS
  static Future<void> sendSMS(String phoneNumber, {String? message}) async {
    final Uri launchUri = Uri(
      scheme: 'sms',
      path: phoneNumber,
      queryParameters: message != null ? {'body': message} : null,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      throw Exception('Could not launch SMS');
    }
  }

  // Send WhatsApp message
  static Future<void> sendWhatsApp(String phoneNumber, {String? message}) async {
    // Remove any special characters and spaces
    String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    
    final Uri launchUri = Uri.parse(
      'https://wa.me/$cleanNumber${message != null ? '?text=${Uri.encodeComponent(message)}' : ''}',
    );
    
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri, mode: LaunchMode.externalApplication);
    } else {
      throw Exception('Could not launch WhatsApp');
    }
  }

  // Send email
  static Future<void> sendEmail(
    String email, {
    String? subject,
    String? body,
  }) async {
    final Uri launchUri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: {
        if (subject != null) 'subject': subject,
        if (body != null) 'body': body,
      },
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      throw Exception('Could not launch email client');
    }
  }

  // Open URL
  static Future<void> openUrl(String url) async {
    final Uri launchUri = Uri.parse(url);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri, mode: LaunchMode.externalApplication);
    } else {
      throw Exception('Could not open URL');
    }
  }

  // Open Google Maps with location
  static Future<void> openMaps(double latitude, double longitude) async {
    final Uri launchUri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri, mode: LaunchMode.externalApplication);
    } else {
      throw Exception('Could not open maps');
    }
  }

  // Share text
  static Future<void> shareText(String text) async {
    // This will be handled by share_plus package in the UI layer
    throw UnimplementedError('Use share_plus package in the UI layer');
  }
}
