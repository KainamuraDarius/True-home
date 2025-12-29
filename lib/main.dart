import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'utils/app_theme.dart';
import 'screens/auth/welcome_screen.dart';
import 'screens/customer/customer_home_screen.dart';
import 'screens/owner/owner_dashboard_screen.dart';
import 'screens/manager/manager_dashboard_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'services/preferences_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
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
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      home: const AuthenticationWrapper(),
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
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
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
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              if (userSnapshot.hasData && userSnapshot.data!.exists) {
                final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                final role = userData['role'] as String?;

                // Check if role exists
                if (role == null) {
                  // User has no role assigned, sign out
                  FirebaseAuth.instance.signOut();
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
                            onPressed: () {
                              // Navigate back to welcome
                            },
                            child: const Text('Back to Login'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // Route to appropriate dashboard based on role
                switch (role) {
                  case 'customer':
                    return const CustomerHomeScreen();
                  case 'propertyOwner':
                    return const OwnerDashboardScreen();
                  case 'propertyManager':
                    return const ManagerDashboardScreen();
                  case 'admin':
                    return const AdminDashboardScreen();
                  default:
                    return const WelcomeScreen();
                }
              }

              // User data not found, log out and show welcome screen
              FirebaseAuth.instance.signOut();
              return const WelcomeScreen();
            },
          );
        }

        // User is not logged in
        return const WelcomeScreen();
      },
    );
  }
}
