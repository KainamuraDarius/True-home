import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'firebase_options.dart';
import 'utils/app_theme.dart';
import 'screens/auth/welcome_screen.dart';
import 'screens/customer/customer_home_screen.dart';
import 'screens/owner/agent_main_screen.dart';
import 'screens/maintenance_screen.dart';
import 'services/preferences_service.dart';
import 'services/notification_service.dart';
import 'services/fcm_service.dart';
import 'services/maintenance_service.dart';

/// Customer/Agent app entry point
/// Build with: flutter build web --release
/// For admin panel, use main_admin.dart instead

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize local notifications (non-blocking)
  NotificationService.initialize().catchError((e) {
    print('Notification initialization error: $e');
  });
  
  // Initialize FCM in background (only on mobile, not web)
  if (!kIsWeb) {
    FCMService().initialize().catchError((e) {
      print('FCM initialization error: $e');
    });
  }
  
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  static MyAppState? of(BuildContext context) {
    return context.findAncestorStateOfType<MyAppState>();
  }

  @override
  State<MyApp> createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.light;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final theme = await PreferencesService.instance.getTheme();
    setState(() {
      _themeMode = theme == 'dark'
          ? ThemeMode.dark
          : theme == 'system'
              ? ThemeMode.system
              : ThemeMode.light;
    });
  }

  void changeTheme(ThemeMode themeMode) {
    setState(() {
      _themeMode = themeMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'True Home',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme.copyWith(
        scaffoldBackgroundColor: Colors.white,
      ),
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      home: const MaintenanceWrapper(),
    );
  }
}

class LaunchLoadingScreen extends StatelessWidget {
  const LaunchLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Colors.white,
      child: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

/// Wrapper that checks maintenance status before showing the app
class MaintenanceWrapper extends StatelessWidget {
  const MaintenanceWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return _MaintenanceWithSplash();
  }
}

class _MaintenanceWithSplash extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MaintenanceStatus>(
      stream: MaintenanceService().maintenanceStatusStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LaunchLoadingScreen();
        }

        final status = snapshot.data;

        // If maintenance is enabled, show maintenance screen
        if (status != null && status.isEnabled) {
          // Check if current user is admin and admins are allowed
          return StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, authSnapshot) {
              if (authSnapshot.hasData && status.allowAdmins) {
                // Check if user is admin
                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .doc(authSnapshot.data!.uid)
                      .get(),
                  builder: (context, userSnapshot) {
                    if (userSnapshot.connectionState == ConnectionState.waiting) {
                      return const LaunchLoadingScreen();
                    }
                    if (userSnapshot.hasData && userSnapshot.data!.exists) {
                      final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                      final role = userData['activeRole'] ?? userData['role'];
                      if (role == 'admin') {
                        return const AuthenticationWrapper();
                      }
                    }
                    return MaintenanceScreen(status: status);
                  },
                );
              }
              return MaintenanceScreen(status: status);
            },
          );
        }
        // No maintenance, show regular app
        return const AuthenticationWrapper();
      },
    );
  }
}

class AuthenticationWrapper extends StatelessWidget {
  const AuthenticationWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show loading while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LaunchLoadingScreen();
        }

        // User is logged in
        if (snapshot.hasData && snapshot.data != null) {
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(snapshot.data!.uid)
                .get(),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const LaunchLoadingScreen();
              }

              if (userSnapshot.hasError) {
                return const LaunchLoadingScreen();
              }

              if (userSnapshot.hasData && userSnapshot.data!.exists) {
                final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                
                // Get active role - support both old and new format
                String? activeRole;
                if (userData['activeRole'] != null) {
                  activeRole = userData['activeRole'] as String?;
                } else if (userData['role'] != null) {
                  // Old single role format
                  activeRole = userData['role'] as String?;
                }

                // Recover from partially-migrated profiles where activeRole is missing
                if (activeRole == null || activeRole.trim().isEmpty) {
                  final roles = userData['roles'];
                  if (roles is List && roles.isNotEmpty) {
                    activeRole = roles.first.toString();
                  }
                }

                // Check if role exists
                if (activeRole == null || activeRole.trim().isEmpty) {
                  // Keep session alive and route safely to customer flow.
                  return Scaffold(
                    body: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, size: 64, color: Colors.red),
                          const SizedBox(height: 16),
                          const Text(
                            'Account Setup Incomplete',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          const Text('Your account is missing required information.'),
                          const SizedBox(height: 16),
                          ElevatedButton(
                              onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(
                                  builder: (context) => const CustomerHomeScreen(),
                                ),
                                (route) => false,
                              ),
                              child: const Text('Back to Login'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // Route to appropriate dashboard based on active role
                switch (activeRole) {
                  case 'customer':
                    return const CustomerHomeScreen();
                  case 'propertyAgent':
                    return const AgentMainScreen();
                  default:
                    // Admin users should use the admin portal
                    if (activeRole == 'admin') {
                      return Scaffold(
                        body: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.admin_panel_settings, size: 64, color: Colors.orange),
                              const SizedBox(height: 16),
                              const Text(
                                'Admin Portal',
                                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              const Text('Please use the admin portal at:'),
                              const SizedBox(height: 8),
                              const SelectableText(
                                'https://truehome-admin.web.app',
                                style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton(
                                onPressed: () => FirebaseAuth.instance.signOut(),
                                child: const Text('Back to Login'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return const WelcomeScreen();
                }
              }

              // Keep auth session; profile may still be syncing/being created.
              return const WelcomeScreen();
            },
          );
        }

        // User not logged in: allow guest browsing for customer-facing flows.
        return const CustomerHomeScreen();
      },
    );
  }
}
