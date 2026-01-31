import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';

class EmailVerificationService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Backend API URL - Update this with your backend server IP
  // For local testing: http://10.0.2.2:3000 (Android emulator)
  // For physical device: http://YOUR_COMPUTER_IP:3000
  static const String _backendUrl = 'http://192.168.0.133:3000';

  // Generate a 6-digit verification code
  String _generateCode() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  // Send verification code via backend server
  Future<void> sendVerificationCode(String email) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No user logged in');

      // Generate verification code
      final code = _generateCode();
      
      // Store code in Firestore with expiration (10 minutes)
      await _firestore.collection('verification_codes').doc(user.uid).set({
        'code': code,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': DateTime.now().add(const Duration(minutes: 10)),
        'attempts': 0,
      });

      // Send email via backend server
      try {
        final response = await http.post(
          Uri.parse('$_backendUrl/api/email/send-verification'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'email': email,
            'code': code,
          }),
        );

        if (response.statusCode == 200) {
          print('✅ Verification email sent to $email');
        } else {
          print('⚠️ Email send failed: ${response.body}');
          print('📧 Verification code (backup): $code');
        }
      } catch (emailError) {
        print('⚠️ Backend email error: $emailError');
        print('📧 Verification code (backup): $code');
      }
    } catch (e) {
      throw Exception('Failed to send verification code: $e');
    }
  }

  // Verify the code entered by user
  Future<bool> verifyCode(String email, String code) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No user logged in');

      // Get stored code from Firestore
      final doc = await _firestore.collection('verification_codes').doc(user.uid).get();
      
      if (!doc.exists) {
        throw Exception('No verification code found');
      }

      final data = doc.data()!;
      final storedCode = data['code'] as String;
      final expiresAt = (data['expiresAt'] as Timestamp).toDate();
      final attempts = data['attempts'] as int;

      // Check if code expired
      if (DateTime.now().isAfter(expiresAt)) {
        throw Exception('Verification code expired');
      }

      // Check max attempts (3 attempts)
      if (attempts >= 3) {
        throw Exception('Too many failed attempts. Request a new code.');
      }

      // Check if code matches
      if (storedCode != code) {
        // Increment attempts
        await _firestore.collection('verification_codes').doc(user.uid).update({
          'attempts': FieldValue.increment(1),
        });
        throw Exception('Invalid verification code');
      }

      // Code is valid - mark user as verified
      await _firestore.collection('users').doc(user.uid).update({
        'isVerified': true,
      });

      // Delete the verification code
      await _firestore.collection('verification_codes').doc(user.uid).delete();

      return true;
    } catch (e) {
      throw Exception('Verification failed: $e');
    }
  }

  // Resend verification code
  Future<void> resendCode(String email) async {
    await sendVerificationCode(email);
  }

  // Check if user email is verified
  Future<bool> isEmailVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    // Check in Firestore
    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (!doc.exists) return false;

    return doc.data()?['isVerified'] ?? false;
  }
}
