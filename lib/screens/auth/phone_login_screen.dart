import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'dart:async';
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

class _PhoneLoginScreenState extends State<PhoneLoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final List<TextEditingController> _otpControllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  EastAfricanCountry _selectedCountry = eastAfricanCountries[0]; // Default to Uganda
  bool _isLoading = false;
  bool _codeSent = false;
  String? _verificationId;
  int? _resendToken;
  String? _errorMessage;
  ConfirmationResult? _confirmationResult; // For web phone auth
  
  // Timer for resend
  Timer? _resendTimer;
  int _resendCountdown = 0;
  
  // Animation
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _otpFocusNodes) {
      node.dispose();
    }
    _resendTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }
  
  String get _otpCode => _otpControllers.map((c) => c.text).join();

  void _startResendTimer() {
    _resendCountdown = 60;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown > 0) {
        setState(() => _resendCountdown--);
      } else {
        timer.cancel();
      }
    });
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
        // Web-specific phone authentication (Firebase handles reCAPTCHA automatically)
        _confirmationResult = await _auth.signInWithPhoneNumber(
          _fullPhoneNumber,
        );
        
        setState(() {
          _verificationId = _confirmationResult?.verificationId;
          _codeSent = true;
          _isLoading = false;
        });
        
        _startResendTimer();
        _animationController.reset();
        _animationController.forward();
        // Focus the first OTP field after transition
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _otpFocusNodes[0].requestFocus();
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
            _startResendTimer();
            _animationController.reset();
            _animationController.forward();
            // Focus the first OTP field after transition
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _otpFocusNodes[0].requestFocus();
            });
            _showSuccessSnackBar('Verification code sent to $_fullPhoneNumber');
          },
          codeAutoRetrievalTimeout: (String verificationId) {
            _verificationId = verificationId;
          },
          forceResendingToken: _resendToken,
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = _getErrorMessage(e.code);
      });
      debugPrint('Phone auth FirebaseAuthException: ${e.code} - ${e.message}');
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to send verification code. Please try again.';
      });
      debugPrint('Phone auth error: $e');
    }
  }

  Future<void> _verifyOTP() async {
    final code = _otpCode;
    if (code.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter the verification code';
      });
      return;
    }

    if (code.length != 6) {
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
        final userCredential = await _confirmationResult!.confirm(code);
        final user = userCredential.user;
        if (user != null) {
          await _handleUserSignIn(user);
        }
      } else if (_verificationId != null) {
        // Mobile: Use credential
        final credential = PhoneAuthProvider.credential(
          verificationId: _verificationId!,
          smsCode: code,
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
      case 'operation-not-allowed':
        return 'Phone authentication is not enabled for this region. Please contact support.';
      case 'invalid-app-credential':
        return 'Verification failed. Please refresh the page and try again.';
      case 'captcha-check-failed':
        return 'reCAPTCHA verification failed. Please try again.';
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
      for (var controller in _otpControllers) {
        controller.clear();
      }
      _errorMessage = null;
    });
    _resendTimer?.cancel();
    _resendCountdown = 0;
    _animationController.reset();
    _animationController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary,
              AppColors.primary.withOpacity(0.8),
              const Color(0xFF1a1a2e),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom App Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                    ),
                    const Expanded(
                      child: Text(
                        'Phone Verification',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 48), // Balance the back button
                  ],
                ),
              ),
              
              // Main Content
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 420),
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 30,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Animated Icon
                                Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        AppColors.primary.withOpacity(0.1),
                                        Colors.orange.withOpacity(0.1),
                                      ],
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _codeSent ? Icons.sms_outlined : Icons.phone_android,
                                    size: 50,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                
                                // Title
                                Text(
                                  _codeSent ? 'Verify Your Number' : 'Enter Your Phone',
                                  style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1a1a2e),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                
                                // Subtitle
                                Text(
                                  _codeSent
                                      ? 'Enter the 6-digit code sent to\n$_fullPhoneNumber'
                                      : 'We\'ll send you a verification code',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                    height: 1.5,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 32),
                                
                                // Error Message
                                if (_errorMessage != null) ...[
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.red.shade50,
                                          Colors.red.shade100.withOpacity(0.5),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.red.shade200),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.red.shade100,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.error_outline,
                                            color: Colors.red.shade700,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            _errorMessage!,
                                            style: TextStyle(
                                              color: Colors.red.shade700,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                ],
                                
                                if (!_codeSent) ...[
                                  // Country Selector
                                  _buildCountrySelector(),
                                  const SizedBox(height: 16),
                                  
                                  // Phone Input
                                  _buildPhoneInput(),
                                ] else ...[
                                  // OTP Input Boxes
                                  _buildOtpInput(),
                                  const SizedBox(height: 24),
                                  
                                  // Resend Timer
                                  _buildResendSection(),
                                ],
                                
                                const SizedBox(height: 32),
                                
                                // Action Button
                                _buildActionButton(),
                                
                                const SizedBox(height: 24),
                                
                                // Info Section
                                _buildInfoSection(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCountrySelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showCountryPicker(),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  _selectedCountry.flag,
                  style: const TextStyle(fontSize: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedCountry.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1a1a2e),
                        ),
                      ),
                      Text(
                        _selectedCountry.dialCode,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down,
                  color: Colors.grey.shade600,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCountryPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Select Country',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: eastAfricanCountries.length,
                itemBuilder: (context, index) {
                  final country = eastAfricanCountries[index];
                  final isSelected = country == _selectedCountry;
                  return ListTile(
                    leading: Text(
                      country.flag,
                      style: const TextStyle(fontSize: 28),
                    ),
                    title: Text(
                      country.name,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? AppColors.primary : null,
                      ),
                    ),
                    trailing: Text(
                      country.dialCode,
                      style: TextStyle(
                        color: isSelected ? AppColors.primary : Colors.grey.shade600,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    selected: isSelected,
                    onTap: () {
                      setState(() => _selectedCountry = country);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneInput() {
    return TextFormField(
      controller: _phoneController,
      keyboardType: TextInputType.phone,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        letterSpacing: 1,
      ),
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(10),
      ],
      decoration: InputDecoration(
        labelText: 'Phone Number',
        hintText: '7XX XXX XXX',
        floatingLabelBehavior: FloatingLabelBehavior.always,
        prefixIcon: Container(
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
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 1,
                height: 28,
                color: Colors.grey.shade300,
              ),
            ],
          ),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.red),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your phone number';
        }
        String phone = value.trim();
        if (phone.startsWith('0')) {
          phone = phone.substring(1);
        }
        final expectedLength = _selectedCountry.phoneLength;
        if (phone.length < expectedLength - 1 || phone.length > expectedLength + 1) {
          return 'Phone number should be around $expectedLength digits';
        }
        if (!RegExp(r'^[0-9]+$').hasMatch(phone)) {
          return 'Please enter numbers only';
        }
        return null;
      },
    );
  }

  Widget _buildOtpInput() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(6, (index) {
        return SizedBox(
          width: 50,
          height: 60,
          child: TextFormField(
            controller: _otpControllers[index],
            focusNode: _otpFocusNodes[index],
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 1,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1a1a2e),
            ),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              counterText: '',
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
              filled: true,
              fillColor: _otpControllers[index].text.isNotEmpty
                  ? AppColors.primary.withOpacity(0.1)
                  : Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: _otpControllers[index].text.isNotEmpty
                      ? AppColors.primary
                      : Colors.grey.shade300,
                  width: _otpControllers[index].text.isNotEmpty ? 2 : 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
            onChanged: (value) {
              setState(() {}); // Refresh to update styling
              if (value.isNotEmpty && index < 5) {
                _otpFocusNodes[index + 1].requestFocus();
              }
              if (value.isEmpty && index > 0) {
                _otpFocusNodes[index - 1].requestFocus();
              }
              // Auto-verify when all 6 digits entered
              if (_otpCode.length == 6) {
                _verifyOTP();
              }
            },
          ),
        );
      }),
    );
  }

  Widget _buildResendSection() {
    return Column(
      children: [
        if (_resendCountdown > 0) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.timer_outlined, size: 18, color: Colors.grey.shade600),
              const SizedBox(width: 8),
              Text(
                'Resend code in ${_resendCountdown}s',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ] else ...[
          TextButton.icon(
            onPressed: _isLoading
                ? null
                : () {
                    _resetForm();
                    // Auto re-send
                    Future.delayed(const Duration(milliseconds: 300), () {
                      if (mounted) _sendOTP();
                    });
                  },
            icon: const Icon(Icons.refresh),
            label: const Text('Resend Code'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
            ),
          ),
        ],
        const SizedBox(height: 8),
        TextButton(
          onPressed: _isLoading ? null : _resetForm,
          child: Text(
            'Change Phone Number',
            style: TextStyle(
              color: Colors.grey.shade600,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : (_codeSent ? _verifyOTP : _sendOTP),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _codeSent ? 'Verify & Sign In' : 'Send Verification Code',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _codeSent ? Icons.check_circle_outline : Icons.arrow_forward,
                    size: 20,
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildInfoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.info_outline,
              color: Colors.orange.shade700,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _codeSent
                  ? 'Didn\'t receive the code? Check your SMS inbox or try resending.'
                  : 'Standard SMS rates may apply. Make sure your number is correct.',
              style: TextStyle(
                color: Colors.orange.shade800,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
