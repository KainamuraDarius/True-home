import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode, kIsWeb;
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
import 'services/auth_action_link_service.dart';
import 'models/property_model.dart';
import 'models/user_model.dart';
import 'screens/property/property_details_screen.dart';
import 'services/role_service.dart';

/// Customer/Agent app entry point
/// Build with: flutter build web --release
/// For admin panel, use main_admin.dart instead

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (!kIsWeb) {
    try {
      await FirebaseAppCheck.instance.activate(
        androidProvider: kDebugMode
            ? AndroidProvider.debug
            : AndroidProvider.playIntegrity,
        appleProvider: kDebugMode
            ? AppleProvider.debug
            : AppleProvider.appAttestWithDeviceCheckFallback,
      );
      await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);
    } catch (e) {
      print('Firebase App Check initialization error: $e');
    }
  }

  FirebaseStorage.instance.setMaxOperationRetryTime(
    const Duration(seconds: 12),
  );
  FirebaseStorage.instance.setMaxUploadRetryTime(const Duration(seconds: 20));

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
    _authActionLinkService = AuthActionLinkService(navigatorKey: _navigatorKey);
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
      child: Center(child: CircularProgressIndicator()),
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
                    if (userSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const LaunchLoadingScreen();
                    }
                    if (userSnapshot.hasData && userSnapshot.data!.exists) {
                      final userData =
                          userSnapshot.data!.data() as Map<String, dynamic>;
                      final userModel = UserModel.fromJson({
                        ...userData,
                        'id': userSnapshot.data!.id,
                      });
                      if (_hasAdminAccess(userModel)) {
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
                final userData =
                    userSnapshot.data!.data() as Map<String, dynamic>;
                final userModel = UserModel.fromJson({
                  ...userData,
                  'id': userSnapshot.data!.id,
                });

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
                            const Icon(
                              Icons.error_outline,
                              size: 64,
                              color: Colors.red,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Account Setup Incomplete',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Your account is missing required information.',
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () =>
                                  Navigator.of(context).pushAndRemoveUntil(
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const CustomerHomeScreen(),
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

                return _withInitialPropertyLink(
                  CustomerPortalEntry(user: userModel),
                );
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

bool _hasAdminAccess(UserModel user) {
  return user.activeRole == UserRole.admin ||
      user.roles.contains(UserRole.admin);
}

UserRole _preferredCustomerPortalRole(UserModel user) {
  if (user.activeRole != UserRole.admin) {
    return user.activeRole;
  }

  for (final role in user.roles) {
    if (role != UserRole.admin) {
      return role;
    }
  }

  return UserRole.customer;
}

class CustomerPortalEntry extends StatefulWidget {
  final UserModel user;

  const CustomerPortalEntry({super.key, required this.user});

  @override
  State<CustomerPortalEntry> createState() => _CustomerPortalEntryState();
}

class _CustomerPortalEntryState extends State<CustomerPortalEntry> {
  late final UserRole _targetRole;

  @override
  void initState() {
    super.initState();
    _targetRole = _preferredCustomerPortalRole(widget.user);

    if (_targetRole != widget.user.activeRole) {
      unawaited(_syncCustomerPortalRole());
    }
  }

  Future<void> _syncCustomerPortalRole() async {
    try {
      await RoleService().switchActiveRole(_targetRole);
    } catch (e) {
      debugPrint('Customer portal role sync failed: $e');
    }
  }

  Widget _buildPortalHome() {
    switch (_targetRole) {
      case UserRole.customer:
        return const CustomerHomeScreen();
      case UserRole.propertyAgent:
        return const AgentMainScreen();
      case UserRole.admin:
        return const WelcomeScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return _buildPortalHome();
  }
}

class InitialPropertyLinkHandler extends StatefulWidget {
  final Widget child;

  const InitialPropertyLinkHandler({super.key, required this.child});

  @override
  State<InitialPropertyLinkHandler> createState() =>
      _InitialPropertyLinkHandlerState();
}

class _InitialPropertyLinkHandlerState
    extends State<InitialPropertyLinkHandler> {
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

      final property = PropertyModel.fromJson({...data, 'id': propertyDoc.id});

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
