import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'utils/app_theme.dart';
import 'screens/auth/admin_login_screen.dart';
import 'screens/admin/admin_panel_screen.dart';
import 'services/preferences_service.dart';

/// Admin-only entry point for True Home Admin Panel
/// Build with: flutter build web --release -t lib/main_admin.dart
/// Deploy with: firebase deploy --only hosting:truehome-admin

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(const AdminApp());
}

class AdminApp extends StatefulWidget {
  const AdminApp({super.key});

  static AdminAppState? of(BuildContext context) {
    return context.findAncestorStateOfType<AdminAppState>();
  }

  @override
  State<AdminApp> createState() => AdminAppState();
}

class AdminAppState extends State<AdminApp> {
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
      title: 'True Home Admin',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      home: const AdminAuthWrapper(),
    );
  }
}

class AdminAuthWrapper extends StatelessWidget {
  const AdminAuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show loading while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading Admin Panel...'),
                ],
              ),
            ),
          );
        }

        // User is logged in - verify they are admin
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
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Verifying admin access...'),
                      ],
                    ),
                  ),
                );
              }

              if (userSnapshot.hasData && userSnapshot.data!.exists) {
                final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                
                // Get active role
                String? activeRole = userData['activeRole'] as String? ?? 
                                     userData['role'] as String?;

                // Only allow admin role
                if (activeRole == 'admin') {
                  return const AdminPanelScreen();
                }

                // Not an admin - sign out and show error
                FirebaseAuth.instance.signOut();
                return Scaffold(
                  body: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.block, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        const Text(
                          'Access Denied',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text('This portal is for administrators only.'),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () {
                            // Trigger rebuild to show login
                            FirebaseAuth.instance.signOut();
                          },
                          icon: const Icon(Icons.login),
                          label: const Text('Back to Login'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              // User data not found
              FirebaseAuth.instance.signOut();
              return const AdminLoginScreen();
            },
          );
        }

        // Not logged in - show admin login
        return const AdminLoginScreen();
      },
    );
  }
}
