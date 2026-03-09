import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/app_theme.dart';
import '../../models/user_model.dart';

/// East African countries with their dial codes
class EastAfricanCountry {
  final String name;
  final String code;
  final String dialCode;
  final String flag;
  final int phoneLength; // Expected phone number length without country code

  const EastAfricanCountry({
    required this.name,
    required this.code,
    required this.dialCode,
    required this.flag,
    required this.phoneLength,
  });
}

const List<EastAfricanCountry> eastAfricanCountries = [
  EastAfricanCountry(
    name: 'Uganda',
    code: 'UG',
    dialCode: '+256',
    flag: '🇺🇬',
    phoneLength: 9, // 7XXXXXXXX (without leading 0)
  ),
  EastAfricanCountry(
    name: 'Kenya',
    code: 'KE',
    dialCode: '+254',
    flag: '🇰🇪',
    phoneLength: 9, // 7XXXXXXXX (without leading 0)
  ),
  EastAfricanCountry(
    name: 'Tanzania',
    code: 'TZ',
    dialCode: '+255',
    flag: '🇹🇿',
    phoneLength: 9, // 7XXXXXXXX (without leading 0)
  ),
  EastAfricanCountry(
    name: 'Rwanda',
    code: 'RW',
    dialCode: '+250',
    flag: '🇷🇼',
    phoneLength: 9, // 7XXXXXXXX (without leading 0)
  ),
  EastAfricanCountry(
    name: 'Burundi',
    code: 'BI',
    dialCode: '+257',
    flag: '🇧🇮',
    phoneLength: 8, // 7XXXXXXX
  ),
  EastAfricanCountry(
    name: 'South Sudan',
    code: 'SS',
    dialCode: '+211',
    flag: '🇸🇸',
    phoneLength: 9, // 9XXXXXXXX
  ),
  EastAfricanCountry(
    name: 'DR Congo',
    code: 'CD',
    dialCode: '+243',
    flag: '🇨🇩',
    phoneLength: 9, // 9XXXXXXXX
  ),
];

class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  EastAfricanCountry _selectedCountry = eastAfricanCountries[0]; // Default to Uganda
  bool _isLoading = false;
  bool _codeSent = false;
  String? _verificationId;
  int? _resendToken;
  String? _errorMessage;
  ConfirmationResult? _confirmationResult; // For web phone auth

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  String get _fullPhoneNumber {
    String phone = _phoneController.text.trim();
    // Remove leading zero if user accidentally added it
    if (phone.startsWith('0')) {
      phone = phone.substring(1);
    }
    return '${_selectedCountry.dialCode}$phone';
  }

  Future<void> _sendOTP() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (kIsWeb) {
        // Web-specific phone authentication
        _confirmationResult = await _auth.signInWithPhoneNumber(
          _fullPhoneNumber,
        );
        
        setState(() {
          _verificationId = _confirmationResult?.verificationId;
          _codeSent = true;
          _isLoading = false;
        });
        
        _showSuccessSnackBar('Verification code sent to $_fullPhoneNumber');
      } else {
        // Mobile phone authentication (fallback)
        await _auth.verifyPhoneNumber(
          phoneNumber: _fullPhoneNumber,
          verificationCompleted: (PhoneAuthCredential credential) async {
            // Auto-verification on Android
            await _signInWithCredential(credential);
          },
          verificationFailed: (FirebaseAuthException e) {
            setState(() {
              _isLoading = false;
              _errorMessage = _getErrorMessage(e.code);
            });
          },
          codeSent: (String verificationId, int? resendToken) {
            setState(() {
              _verificationId = verificationId;
              _resendToken = resendToken;
              _codeSent = true;
              _isLoading = false;
            });
            _showSuccessSnackBar('Verification code sent to $_fullPhoneNumber');
          },
          codeAutoRetrievalTimeout: (String verificationId) {
            _verificationId = verificationId;
          },
          forceResendingToken: _resendToken,
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to send verification code. Please try again.';
      });
      print('Phone auth error: $e');
    }
  }

  Future<void> _verifyOTP() async {
    if (_otpController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter the verification code';
      });
      return;
    }

    if (_otpController.text.trim().length != 6) {
      setState(() {
        _errorMessage = 'Verification code must be 6 digits';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (kIsWeb && _confirmationResult != null) {
        // Web: Use ConfirmationResult to confirm
        final userCredential = await _confirmationResult!.confirm(_otpController.text.trim());
        final user = userCredential.user;
        if (user != null) {
          await _handleUserSignIn(user);
        }
      } else if (_verificationId != null) {
        // Mobile: Use credential
        final credential = PhoneAuthProvider.credential(
          verificationId: _verificationId!,
          smsCode: _otpController.text.trim(),
        );
        await _signInWithCredential(credential);
      } else {
        throw Exception('No verification session found');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Invalid verification code. Please try again.';
      });
    }
  }

  Future<void> _handleUserSignIn(User user) async {
    try {
      // Check if user exists in Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      if (!userDoc.exists) {
        // Create new user document for phone-authenticated users
        final newUser = UserModel(
          id: user.uid,
          email: '', // No email for phone auth users
          name: user.phoneNumber ?? 'User',
          phoneNumber: user.phoneNumber ?? _fullPhoneNumber,
          roles: [UserRole.customer],
          activeRole: UserRole.customer,
          isVerified: true, // Phone verified
          termsAccepted: true,
          termsAcceptedAt: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set(newUser.toJson());
      }
      
      if (mounted) {
        // Navigate to home
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to complete sign in. Please try again.';
      });
    }
  }

  Future<void> _signInWithCredential(PhoneAuthCredential credential) async {
    try {
      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;
      if (user != null) {
        await _handleUserSignIn(user);
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = _getErrorMessage(e.code);
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Sign in failed. Please try again.';
      });
    }
  }

  String _getErrorMessage(String code) {
    switch (code) {
      case 'invalid-phone-number':
        return 'Invalid phone number format. Please check and try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'invalid-verification-code':
        return 'Invalid verification code. Please try again.';
      case 'session-expired':
        return 'Verification session expired. Please request a new code.';
      case 'quota-exceeded':
        return 'SMS quota exceeded. Please try again later.';
      default:
        return 'An error occurred. Please try again.';
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _resetForm() {
    setState(() {
      _codeSent = false;
      _verificationId = null;
      _confirmationResult = null;
      _otpController.clear();
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign in with Phone'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Icon(
                      Icons.phone_android,
                      size: 80,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _codeSent ? 'Enter Verification Code' : 'Enter Your Phone Number',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _codeSent
                          ? 'We sent a 6-digit code to $_fullPhoneNumber'
                          : 'We\'ll send you a verification code to sign in',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    // Error message
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.red.shade700),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(color: Colors.red.shade700),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    if (!_codeSent) ...[
                      // Country selector
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<EastAfricanCountry>(
                            value: _selectedCountry,
                            isExpanded: true,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            borderRadius: BorderRadius.circular(12),
                            items: eastAfricanCountries.map((country) {
                              return DropdownMenuItem<EastAfricanCountry>(
                                value: country,
                                child: Row(
                                  children: [
                                    Text(
                                      country.flag,
                                      style: const TextStyle(fontSize: 24),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        country.name,
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                    ),
                                    Text(
                                      country.dialCode,
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (country) {
                              if (country != null) {
                                setState(() {
                                  _selectedCountry = country;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Phone number input
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'Phone Number',
                          hintText: 'e.g. 7XXXXXXXX',
                          helperText: 'Enter without the leading 0',
                          prefixIcon: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _selectedCountry.flag,
                                  style: const TextStyle(fontSize: 20),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _selectedCountry.dialCode,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  width: 1,
                                  height: 24,
                                  color: Colors.grey.shade300,
                                ),
                              ],
                            ),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your phone number';
                          }
                          // Remove leading zero for validation
                          String phone = value.trim();
                          if (phone.startsWith('0')) {
                            phone = phone.substring(1);
                          }
                          // Validate length based on country
                          final expectedLength = _selectedCountry.phoneLength;
                          if (phone.length < expectedLength - 1 || phone.length > expectedLength + 1) {
                            return 'Phone number should be around $expectedLength digits';
                          }
                          // Ensure only digits
                          if (!RegExp(r'^[0-9]+$').hasMatch(phone)) {
                            return 'Please enter numbers only';
                          }
                          return null;
                        },
                      ),
                    ] else ...[
                      // OTP input
                      TextFormField(
                        controller: _otpController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 8,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Verification Code',
                          hintText: '------',
                          counterText: '',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Resend code option
                      TextButton.icon(
                        onPressed: _isLoading ? null : _resetForm,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Change phone number or resend code'),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Action button
                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading
                            ? null
                            : (_codeSent ? _verifyOTP : _sendOTP),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(
                                _codeSent ? 'Verify Code' : 'Send Verification Code',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Info text
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue.shade700),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Standard SMS rates may apply. Message and data rates may vary.',
                              style: TextStyle(
                                color: Colors.blue.shade700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
