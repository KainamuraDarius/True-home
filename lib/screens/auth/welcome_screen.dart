import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:ui';
import '../../utils/app_theme.dart';
import 'login_screen.dart';
import 'role_selection_screen.dart';
import 'phone_login_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          // Background image
          image: const DecorationImage(
            image: AssetImage('assets/images/welcome_bg.jpg'),
            fit: BoxFit.cover, // Covers entire screen
            filterQuality: FilterQuality.high,
            opacity: 1.0, // Full opacity (0.0 - 1.0)
          ),
          // Fallback gradient if image doesn't load
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary.withOpacity(0.8),
              AppColors.primaryDark.withOpacity(0.9),
            ],
          ),
        ),
        child: Container(
          // Semi-transparent overlay for better text readability (optional)
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.1),
                Colors.black.withOpacity(0.2),
              ],
            ),
          ),
          child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bool isCompact = constraints.maxWidth < 380;
              final double logoSize = isCompact ? 112 : 140;
              final double cardRadius = isCompact ? 24 : 28;
              final double headingSize = isCompact ? 27 : 31;

              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(isCompact ? 18 : 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(height: constraints.maxHeight * 0.05),
                        // True Home Logo
                        Container(
                          width: logoSize,
                          height: logoSize,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(35),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Image.asset(
                            'assets/images/app_icon.png',
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.high,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: AppColors.primary,
                                child: const Icon(
                                  Icons.home_rounded,
                                  size: 80,
                                  color: Colors.white,
                                ),
                              );
                            },
                          ),
                        ),
                        SizedBox(height: isCompact ? 22 : 28),
                        // Glass-style card for copy and actions.
                        TweenAnimationBuilder<double>(
                          duration: const Duration(milliseconds: 700),
                          tween: Tween(begin: 0, end: 1),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) {
                            return Opacity(
                              opacity: value,
                              child: Transform.translate(
                                offset: Offset(0, 20 * (1 - value)),
                                child: child,
                              ),
                            );
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(cardRadius),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                              child: Container(
                                width: double.infinity,
                                padding: EdgeInsets.symmetric(
                                  horizontal: isCompact ? 18 : 22,
                                  vertical: isCompact ? 22 : 26,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(cardRadius),
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Colors.white.withOpacity(0.26),
                                      Colors.white.withOpacity(0.12),
                                    ],
                                  ),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.32),
                                    width: 1.1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 24,
                                      offset: const Offset(0, 12),
                                    ),
                                  ],
                                ),
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: IgnorePointer(
                                        child: AnimatedBuilder(
                                          animation: _shimmerController,
                                          builder: (context, child) {
                                            final double travel =
                                                constraints.maxWidth + 180;
                                            final double dx =
                                                (travel * _shimmerController.value) - 120;
                                            return Transform.translate(
                                              offset: Offset(dx, 0),
                                              child: Transform.rotate(
                                                angle: -0.35,
                                                child: Container(
                                                  width: isCompact ? 86 : 108,
                                                  decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                      begin: Alignment.centerLeft,
                                                      end: Alignment.centerRight,
                                                      colors: [
                                                        Colors.white.withOpacity(0),
                                                        Colors.white.withOpacity(0.17),
                                                        Colors.white.withOpacity(0),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: -42,
                                      right: -32,
                                      child: Container(
                                        width: 120,
                                        height: 120,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.white.withOpacity(0.12),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: -28,
                                      left: -26,
                                      child: Container(
                                        width: 90,
                                        height: 90,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.white.withOpacity(0.1),
                                        ),
                                      ),
                                    ),
                                    Column(
                                      children: [
                                        Text(
                                          'Welcome to True Home',
                                          style: TextStyle(
                                            fontSize: headingSize,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                            letterSpacing: 0.2,
                                            shadows: [
                                              Shadow(
                                                color: Colors.black.withOpacity(0.24),
                                                offset: const Offset(0, 2),
                                                blurRadius: 6,
                                              ),
                                            ],
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                        SizedBox(height: isCompact ? 12 : 14),
                                        Text(
                                          'Find trusted homes, faster. Buy, rent, or discover student living in one place.',
                                          style: TextStyle(
                                            fontSize: isCompact ? 15 : 16,
                                            color: Colors.white.withOpacity(0.96),
                                            height: 1.45,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                        SizedBox(height: isCompact ? 22 : 28),
                                        SizedBox(
                                          width: double.infinity,
                                          height: 56,
                                          child: ElevatedButton(
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => const RoleSelectionScreen(),
                                                ),
                                              );
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.white,
                                              foregroundColor: AppColors.primaryDark,
                                              elevation: 2,
                                              shadowColor: Colors.black.withOpacity(0.2),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(16),
                                              ),
                                            ),
                                            child: const Text(
                                              'Sign up with Email',
                                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                                            ),
                                          ),
                                        ),
                                        if (kIsWeb) ...[
                                          const SizedBox(height: 14),
                                          SizedBox(
                                            width: double.infinity,
                                            height: 56,
                                            child: ElevatedButton.icon(
                                              onPressed: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => const PhoneLoginScreen(),
                                                  ),
                                                );
                                              },
                                              icon: const Icon(Icons.phone_android, color: Colors.white),
                                              label: const Text(
                                                'Sign in with Phone',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.orange.withOpacity(0.9),
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(16),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 18),
                                        Wrap(
                                          alignment: WrapAlignment.center,
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          children: [
                                            Text(
                                              'Already have an account? ',
                                              style: TextStyle(
                                                color: Colors.white.withOpacity(0.94),
                                                fontSize: 15,
                                              ),
                                            ),
                                            TextButton(
                                              onPressed: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => const LoginScreen(),
                                                  ),
                                                );
                                              },
                                              style: TextButton.styleFrom(
                                                foregroundColor: Colors.white,
                                                padding: EdgeInsets.zero,
                                                minimumSize: const Size(0, 0),
                                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              ),
                                              child: const Text(
                                                'Login',
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.bold,
                                                  decoration: TextDecoration.underline,
                                                  decorationColor: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
              // Version
              Container(
                padding: const EdgeInsets.all(8),
                child: Text(
                  'v1.0.0',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
      ),
    );
  }
}
