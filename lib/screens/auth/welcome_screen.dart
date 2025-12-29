import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import 'login_screen.dart';
import 'role_selection_screen.dart';
import 'admin_login_screen.dart';
import '../admin/create_admin_account.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  int _tapCount = 0;
  int _setupTapCount = 0;
  DateTime? _lastTapTime;
  DateTime? _lastSetupTapTime;

  void _onLogoTap() {
    final now = DateTime.now();
    
    // Reset counter if more than 2 seconds since last tap
    if (_lastTapTime != null && now.difference(_lastTapTime!) > const Duration(seconds: 2)) {
      _tapCount = 0;
    }
    
    _lastTapTime = now;
    _tapCount++;

    if (_tapCount >= 7) {
      _tapCount = 0;
      // Navigate to admin login
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const AdminLoginScreen(),
        ),
      );
    }
  }

  void _onSetupTap() {
    final now = DateTime.now();
    
    // Reset counter if more than 2 seconds since last tap
    if (_lastSetupTapTime != null && now.difference(_lastSetupTapTime!) > const Duration(seconds: 2)) {
      _setupTapCount = 0;
    }
    
    _lastSetupTapTime = now;
    _setupTapCount++;

    if (_setupTapCount >= 5) {
      _setupTapCount = 0;
      // Navigate to create admin account screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const CreateAdminAccountScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              // True Home Logo with hidden admin tap
              GestureDetector(
                onTap: _onLogoTap,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(40),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(40),
                    child: Image.asset(
                      'assets/images/true_home_logo.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: AppColors.primary,
                          child: const Icon(
                            Icons.home_rounded,
                            size: 100,
                            color: Colors.white,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              // Welcome Text
              const Text(
                'Welcome to True Home',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              // Description
              Text(
                'We build trust, quality and a stronger future. Find your perfect place to call home - rentals, condos, and student hostels.',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              // Sign Up with Email Button
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
                  child: const Text(
                    'Sign up with Email',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Already have an account
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Already have an account? ',
                    style: TextStyle(
                      color: AppColors.textSecondary,
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
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Login',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Hidden admin setup access (tap 5 times)
              GestureDetector(
                onTap: _onSetupTap,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    'v1.0.0',
                    style: TextStyle(
                      color: AppColors.textLight,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
