import 'package:flutter/material.dart';
import 'dart:async';
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
import 'services/auth_service.dart';
import 'services/auth_action_link_service.dart';
import 'models/property_model.dart';
import 'screens/property/property_details_screen.dart';

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
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  late final AuthActionLinkService _authActionLinkService;

  @override
  void initState() {
    super.initState();
    _authActionLinkService = AuthActionLinkService(
      navigatorKey: _navigatorKey,
    );
    unawaited(_authActionLinkService.initialize());
    _loadTheme();
  }

  @override
  void dispose() {
    _authActionLinkService.dispose();
    super.dispose();
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
      navigatorKey: _navigatorKey,
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

  Widget _withInitialPropertyLink(Widget child) {
    return InitialPropertyLinkHandler(child: child);
  }

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
          final firebaseUser = snapshot.data!;
          if ((firebaseUser.email ?? '').isNotEmpty &&
              !firebaseUser.emailVerified) {
            return _withInitialPropertyLink(const UnverifiedEmailGateScreen());
          }

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
                  return _withInitialPropertyLink(
                    Scaffold(
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
                    ),
                  );
                }

                // Route to appropriate dashboard based on active role
                switch (activeRole) {
                  case 'customer':
                    return _withInitialPropertyLink(const CustomerHomeScreen());
                  case 'propertyAgent':
                    return _withInitialPropertyLink(const AgentMainScreen());
                  default:
                    // Admin users should use the admin portal
                    if (activeRole == 'admin') {
                      return _withInitialPropertyLink(
                        Scaffold(
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
                        ),
                      );
                    }
                    return _withInitialPropertyLink(const WelcomeScreen());
                }
              }

              // Keep auth session; profile may still be syncing/being created.
              return _withInitialPropertyLink(const WelcomeScreen());
            },
          );
        }

        // User not logged in: allow guest browsing for customer-facing flows.
        return _withInitialPropertyLink(const CustomerHomeScreen());
      },
    );
  }
}

class InitialPropertyLinkHandler extends StatefulWidget {
  final Widget child;

  const InitialPropertyLinkHandler({super.key, required this.child});

  @override
  State<InitialPropertyLinkHandler> createState() =>
      _InitialPropertyLinkHandlerState();
}

class _InitialPropertyLinkHandlerState extends State<InitialPropertyLinkHandler> {
  static bool _handledInitialPropertyLink = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openInitialPropertyIfNeeded();
    });
  }

  String? _initialPropertyIdFromUri() {
    final propertyId = Uri.base.queryParameters['propertyId']?.trim();
    if (propertyId != null && propertyId.isNotEmpty) {
      return propertyId;
    }

    final pathSegments = Uri.base.pathSegments
        .map((segment) => segment.trim())
        .where((segment) => segment.isNotEmpty)
        .toList();

    if (pathSegments.length >= 2 &&
        pathSegments.first.toLowerCase() == 'property') {
      return pathSegments[1];
    }

    return null;
  }

  Future<void> _openInitialPropertyIfNeeded() async {
    if (_handledInitialPropertyLink || !mounted) return;

    final propertyId = _initialPropertyIdFromUri();
    if (propertyId == null) return;

    _handledInitialPropertyLink = true;

    try {
      final propertyDoc = await FirebaseFirestore.instance
          .collection('properties')
          .doc(propertyId)
          .get();

      if (!mounted || !propertyDoc.exists) return;

      final data = propertyDoc.data();
      if (data == null) return;

      final isApproved =
          (data['status'] ?? '').toString() == PropertyStatus.approved.name;
      final isActive = data['isActive'] as bool? ?? true;

      if (!isApproved || !isActive) return;

      final property = PropertyModel.fromJson({
        ...data,
        'id': propertyDoc.id,
      });

      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => PropertyDetailsScreen(property: property),
        ),
      );
    } catch (e) {
      debugPrint('Failed to open initial property link: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class UnverifiedEmailGateScreen extends StatefulWidget {
  const UnverifiedEmailGateScreen({super.key});

  @override
  State<UnverifiedEmailGateScreen> createState() =>
      _UnverifiedEmailGateScreenState();
}

class _UnverifiedEmailGateScreenState extends State<UnverifiedEmailGateScreen> {
  final AuthService _authService = AuthService();
  bool _sending = false;

  Future<void> _resendVerificationEmail() async {
    setState(() {
      _sending = true;
    });

    try {
      await _authService.sendEmailVerification();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verification email sent. Check your inbox.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userEmail = FirebaseAuth.instance.currentUser?.email ?? '';
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.mark_email_unread_outlined,
                  size: 72,
                  color: Colors.orange,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Verify Your Email',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  userEmail.isEmpty
                      ? 'Please verify your email to continue.'
                      : 'We sent a verification link to\n$userEmail',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _sending ? null : _resendVerificationEmail,
                    child: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Resend Verification Email'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => FirebaseAuth.instance.signOut(),
                    child: const Text('Sign Out'),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () async {
                    await FirebaseAuth.instance.currentUser?.reload();
                    if (mounted) {
                      setState(() {});
                    }
                  },
                  child: const Text('I already verified, refresh'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
