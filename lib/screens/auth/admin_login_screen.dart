import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';
import '../admin/admin_panel_screen.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  bool _obscurePassword = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        print('Attempting admin login with email: ${_emailController.text.trim()}');
        
        UserModel? user = await _authService.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

        print('Login successful, user active role: ${user?.activeRole}');

        if (user != null && mounted) {
          // Verify user has admin role
          if (!user.roles.contains(UserRole.admin)) {
            await _authService.signOut();
            _showErrorDialog(
              title: 'Access Denied',
              message: 'Your account does not have administrator privileges. Please contact the system administrator if you believe this is an error.',
              icon: Icons.block_rounded,
              iconColor: Colors.orange,
            );
            return;
          }

          // Navigate directly to admin panel, clearing all previous routes
          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const AdminPanelScreen()),
              (route) => false,
            );
          }
        }
      } catch (e) {
        print('Login error: $e');
        String errorMessage = e.toString().toLowerCase();
        
        // Parse error messages from AuthService exceptions
        if (errorMessage.contains('no user found') || 
            errorMessage.contains('user-not-found') || 
            errorMessage.contains('no user record')) {
          _handleAuthError('user-not-found');
        } else if (errorMessage.contains('incorrect password') || 
                   errorMessage.contains('wrong-password') || 
                   errorMessage.contains('invalid email or password') ||
                   errorMessage.contains('invalid-credential')) {
          _handleAuthError('wrong-password');
        } else if (errorMessage.contains('email address is invalid') || 
                   errorMessage.contains('invalid-email')) {
          _handleAuthError('invalid-email');
        } else if (errorMessage.contains('disabled') || 
                   errorMessage.contains('user-disabled')) {
          _handleAuthError('user-disabled');
        } else if (errorMessage.contains('too many') || 
                   errorMessage.contains('too-many-requests')) {
          _handleAuthError('too-many-requests');
        } else if (errorMessage.contains('network') || 
                   errorMessage.contains('connection')) {
          _handleAuthError('network-request-failed');
        } else if (errorMessage.contains('user data not found')) {
          _showErrorDialog(
            title: 'Account Not Setup',
            message: 'Your account exists but user data is missing. Please contact the administrator to set up your admin profile.',
            icon: Icons.person_off_rounded,
            iconColor: Colors.orange,
          );
        } else {
          // Show the actual error message for debugging
          _showErrorDialog(
            title: 'Login Failed',
            message: errorMessage.replaceAll('exception:', '').trim(),
            icon: Icons.error_outline_rounded,
            iconColor: Colors.red,
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  void _handleAuthError(String errorCode) {
    String title;
    String message;
    IconData icon;
    Color iconColor;

    switch (errorCode) {
      case 'user-not-found':
        title = 'Account Not Found';
        message = 'No administrator account exists with this email address. Please check your email and try again.';
        icon = Icons.person_off_rounded;
        iconColor = Colors.red;
        break;
      case 'wrong-password':
      case 'invalid-credential':
        title = 'Invalid Credentials';
        message = 'The email or password you entered is incorrect. Please check your credentials and try again.';
        icon = Icons.lock_outline_rounded;
        iconColor = Colors.red;
        break;
      case 'invalid-email':
        title = 'Invalid Email';
        message = 'The email address format is invalid. Please enter a valid email address.';
        icon = Icons.email_outlined;
        iconColor = Colors.orange;
        break;
      case 'user-disabled':
        title = 'Account Disabled';
        message = 'This administrator account has been disabled. Please contact the system administrator for assistance.';
        icon = Icons.block_rounded;
        iconColor = Colors.red;
        break;
      case 'too-many-requests':
        title = 'Too Many Attempts';
        message = 'Access to this account has been temporarily disabled due to many failed login attempts. Please try again later or reset your password.';
        icon = Icons.timer_off_rounded;
        iconColor = Colors.orange;
        break;
      case 'network-request-failed':
        title = 'Connection Error';
        message = 'Unable to connect to the server. Please check your internet connection and try again.';
        icon = Icons.wifi_off_rounded;
        iconColor = Colors.blue;
        break;
      default:
        title = 'Login Failed';
        message = 'An error occurred while signing in. Please try again.';
        icon = Icons.error_outline_rounded;
        iconColor = Colors.red;
    }

    if (mounted) {
      _showErrorDialog(
        title: title,
        message: message,
        icon: icon,
        iconColor: iconColor,
      );
    }
  }

  void _showErrorDialog({
    required String title,
    required String message,
    required IconData icon,
    required Color iconColor,
  }) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Container();
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        );
        return ScaleTransition(
          scale: curvedAnimation,
          child: FadeTransition(
            opacity: animation,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              contentPadding: const EdgeInsets.all(24),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animated Icon Container
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 500),
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: value,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: iconColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            icon,
                            size: 40,
                            color: iconColor,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1a1a2e),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0f3460),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Try Again',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWideScreen = size.width > 900;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF1a1a2e),
              const Color(0xFF16213e),
              const Color(0xFF0f3460),
            ],
          ),
        ),
        child: isWideScreen ? _buildWideLayout(size) : _buildNarrowLayout(size),
      ),
    );
  }

  Widget _buildWideLayout(Size size) {
    return Row(
      children: [
        // Left Panel - Branding
        Expanded(
          flex: 5,
          child: _buildBrandingPanel(),
        ),
        // Right Panel - Login Form
        Expanded(
          flex: 4,
          child: _buildLoginPanel(),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout(Size size) {
    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: size.height),
        child: Column(
          children: [
            // Top Branding (compact)
            Container(
              padding: const EdgeInsets.fromLTRB(24, 60, 24, 40),
              child: Column(
                children: [
                  _buildAnimatedLogo(size: 80),
                  const SizedBox(height: 20),
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: const Text(
                      'True Home Admin',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Login Form
            _buildLoginPanel(isNarrow: true),
          ],
        ),
      ),
    );
  }

  Widget _buildBrandingPanel() {
    return Container(
      padding: const EdgeInsets.all(48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAnimatedLogo(),
          const SizedBox(height: 40),
          FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'True Home',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                  const Text(
                    'Administration Portal',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w300,
                      color: Colors.white70,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 40),
                  Container(
                    width: 60,
                    height: 4,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade400, Colors.purple.shade400],
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 40),
                  _buildFeatureItem(
                    Icons.dashboard_rounded,
                    'Dashboard Analytics',
                    'Monitor platform metrics in real-time',
                  ),
                  const SizedBox(height: 20),
                  _buildFeatureItem(
                    Icons.people_rounded,
                    'User Management',
                    'Manage users, agents and permissions',
                  ),
                  const SizedBox(height: 20),
                  _buildFeatureItem(
                    Icons.home_work_rounded,
                    'Property Control',
                    'Review and approve property listings',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedLogo({double size = 100}) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.shade400,
              Colors.purple.shade500,
            ],
          ),
          borderRadius: BorderRadius.circular(size * 0.25),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.3),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Icon(
          Icons.admin_panel_settings_rounded,
          size: size * 0.55,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white70, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoginPanel({bool isNarrow = false}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: isNarrow
            ? const BorderRadius.vertical(top: Radius.circular(32))
            : null,
        boxShadow: isNarrow
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ]
            : null,
      ),
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isNarrow ? 24 : 48,
            vertical: isNarrow ? 40 : 0,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!isNarrow) ...[
                        const Text(
                          'Welcome Back',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1a1a2e),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Sign in to access the admin dashboard',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 48),
                      ],
                      // Email Field
                      _buildTextField(
                        controller: _emailController,
                        label: 'Email Address',
                        hint: 'admin@truehome.com',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your email';
                          }
                          if (!value.contains('@')) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      // Password Field
                      _buildTextField(
                        controller: _passwordController,
                        label: 'Password',
                        hint: '••••••••',
                        icon: Icons.lock_outline_rounded,
                        obscureText: _obscurePassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: Colors.grey.shade600,
                          ),
                          onPressed: () {
                            setState(() => _obscurePassword = !_obscurePassword);
                          },
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 32),
                      // Login Button
                      _buildLoginButton(),
                      const SizedBox(height: 32),
                      // Security Notice
                      _buildSecurityNotice(),
                      const SizedBox(height: 24),
                      // Footer
                      Center(
                        child: Text(
                          '© ${DateTime.now().year} True Home. All rights reserved.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1a1a2e),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          validator: validator,
          style: const TextStyle(fontSize: 16),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400),
            prefixIcon: Icon(icon, color: Colors.grey.shade600, size: 22),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF0f3460), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.red.shade400),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.red.shade400, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginButton() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF0f3460),
            const Color(0xFF16213e),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0f3460).withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _login,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
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
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.login_rounded, size: 22),
                  SizedBox(width: 12),
                  Text(
                    'Sign In',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildSecurityNotice() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.amber.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.shield_outlined,
              color: Colors.amber.shade800,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Secure Access',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.amber.shade900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'This portal is restricted to authorized administrators only.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.amber.shade800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
